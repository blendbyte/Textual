#!/usr/bin/env python3
#
# A minimal IRC server on 127.0.0.1 that plays one scenario to the client
# that connects, for cases a real server won't produce. It logs every line
# in both directions and ends with a RESULT line saying whether the client
# behaved correctly.
#
# Usage: Development/dev scripted <scenario> [--port 6680]
#        Development/dev scripted --list

import argparse
import asyncio
import datetime
import os
import ssl
import sys
import time

SERVER = "scripted.textual.test"
SERVICES_HOST = "services.textual.test"

# The local Ergo server's self-signed certificate (Development/dev server start)
# Ergo's certificate, from the data folder of Development/dev
CERTIFICATE_DIRECTORY = os.path.join(os.environ.get("TEXTUAL_DEV_DATA") or os.path.expanduser("~/Library/Application Support/Textual Development"), "ergo")

# Textual Dev saves into ~/Downloads unless a download folder is set
DOWNLOADS = os.path.expanduser("~/Downloads")


def log(direction, line):
	print(f"{time.strftime('%H:%M:%S')} {direction} {line[:300]}{'…' if len(line) > 300 else ''}", flush=True)


class Client:
	def __init__(self, reader, writer):
		self.reader = reader
		self.writer = writer
		self.nickname = "*"
		self.received = []  # lines from the client after registration

	async def send(self, line):
		log(">>", line)
		self.writer.write((line + "\r\n").encode())
		await self.writer.drain()

	async def send_raw(self, data):
		log(">>", f"<{len(data)} bytes without a line break>")
		self.writer.write(data)
		await self.writer.drain()

	async def read_line(self):
		try:
			data = await self.reader.readline()
		except ConnectionResetError:
			return None
		if not data:
			return None
		line = data.decode(errors="replace").rstrip("\r\n")
		log("<<", line)
		return line

	async def register(self):
		user_received = False

		while self.nickname == "*" or not user_received:
			line = await self.read_line()
			if line is None:
				return False

			command, _, rest = line.partition(" ")
			command = command.upper()

			if command == "CAP" and rest.startswith("LS"):
				await self.send(f":{SERVER} CAP * LS :")
			elif command == "NICK":
				self.nickname = rest.lstrip(":")
			elif command == "USER":
				user_received = True

		await self.welcome()

		return True

	async def register_with_capabilities(self, capabilities, server_name=SERVER):
		"""Register like a CAP 302 server that offers capabilities (one LS line)
		and acknowledges whatever the client requests."""
		seen = set()

		while True:
			line = await self.read_line()
			if line is None:
				return False

			command, _, rest = line.partition(" ")
			command = command.upper()
			seen.add(command)

			if command == "CAP" and rest.upper().startswith("LS"):
				await self.send(f":{server_name} CAP * LS :{capabilities}")
			elif command == "CAP" and rest.upper().startswith("REQ"):
				requested = rest.split(" ", 1)[1].lstrip(":")
				await self.send(f":{server_name} CAP * ACK :{requested}")
			elif command == "CAP" and rest.upper().startswith("END"):
				if "NICK" in seen and "USER" in seen:
					break
			elif command == "NICK":
				self.nickname = rest.lstrip(":")

		await self.welcome()

		return True

	async def welcome(self):
		for line in [
			f":{SERVER} 001 {self.nickname} :Welcome to the scripted test server",
			f":{SERVER} 002 {self.nickname} :Your host is {SERVER}",
			f":{SERVER} 003 {self.nickname} :This server was created today",
			f":{SERVER} 004 {self.nickname} {SERVER} scripted io bklov",
			f":{SERVER} 005 {self.nickname} CHANTYPES=# PREFIX=(ov)@+ NETWORK=TextualScripted :are supported by this server",
			f":{SERVER} 422 {self.nickname} :MOTD File is missing",
		]:
			await self.send(line)

	async def collect(self, seconds):
		"""Answer PINGs and JOINs and record what the client sends for a while."""
		end = time.monotonic() + seconds

		while (remaining := end - time.monotonic()) > 0:
			try:
				line = await asyncio.wait_for(self.read_line(), remaining)
			except asyncio.TimeoutError:
				break

			if line is None:
				return False

			self.received.append(line)

			command, _, rest = line.partition(" ")
			command = command.upper()

			if command == "PING":
				await self.send(f":{SERVER} PONG {SERVER} {rest}")
			elif command == "JOIN":
				channel = rest.split(" ")[0].lstrip(":")
				await self.send(f":{self.nickname}!user@client.textual.test JOIN {channel}")
				await self.send(f":{SERVER} 353 {self.nickname} = {channel} :{self.nickname}")
				await self.send(f":{SERVER} 366 {self.nickname} {channel} :End of /NAMES list.")

		return True

	def sent(self, predicate):
		return [line for line in self.received if predicate(line)]

	async def is_alive(self, token):
		"""PING the client and wait for its PONG."""
		await self.send(f"PING :{token}")

		end = time.monotonic() + 5

		while (remaining := end - time.monotonic()) > 0:
			count = len(self.received)

			if not await self.collect(min(remaining, 0.5)):
				return False

			if any(line.upper().startswith("PONG") and token in line for line in self.received[count:]):
				return True

		return False


class Events:
	"""Connections after the first one, for scenarios that make the client reconnect."""
	reconnected = None
	reconnected_with_tls = None


def result(passed, message):
	print(f"RESULT: {'PASS' if passed else 'FAIL'}: {message}", flush=True)


# MARK: - Scenarios

async def scenario_idle(client):
	"""Register the client and keep the connection open (Ctrl-C to stop)."""
	while await client.collect(3600):
		pass


async def scenario_nickserv_spoof(client):
	"""NickServ asks to identify: first from the services host (trusted on first use
	and saved as the NickServ Host), then from another host (refused), then from the
	services host again. Within 8 seconds of connecting, run
	"Development/dev config nicknamePassword=test"."""
	await client.collect(8)

	notice = "This nickname is registered. Please choose a different nickname, or identify via /msg NickServ identify <password>."
	identify = lambda line: line.upper().startswith("PRIVMSG NICKSERV ") and "IDENTIFY" in line.upper()

	await client.send(f":NickServ!NickServ@{SERVICES_HOST} NOTICE {client.nickname} :{notice}")
	await client.collect(3)

	result(len(client.sent(identify)) == 1, f"first NickServ ({SERVICES_HOST}) trusted: password sent")

	# Textual waits for NickServ's answer before it would identify again
	await client.send(f":NickServ!NickServ@{SERVICES_HOST} NOTICE {client.nickname} :You are now identified for {client.nickname}.")
	await client.collect(2)

	await client.send(f":NickServ!NickServ@attacker.test NOTICE {client.nickname} :{notice}")
	await client.collect(3)

	result(len(client.sent(identify)) == 1, "no password sent to NickServ from attacker.test")

	await client.send(f":NickServ!NickServ@{SERVICES_HOST} NOTICE {client.nickname} :{notice}")
	await client.collect(3)

	result(len(client.sent(identify)) == 2, f"password sent again to NickServ from {SERVICES_HOST}")


async def scenario_long_line(client):
	"""The server sends 70 KiB without a line break; the client must disconnect."""
	await client.collect(2)

	await client.send_raw(b"A" * (70 * 1024))

	still_connected = await client.collect(5)
	result(not still_connected, "client disconnected after 64 KiB without a line break")


async def scenario_ctcp_flood(client):
	"""20 CTCP VERSION queries from one host and one to a channel: at most 2 replies
	to that host, none to the channel, and another host still gets an answer."""
	await client.send(f":{client.nickname}!user@client.textual.test JOIN #flood")
	await client.collect(2)

	await client.send(":flooder!f@flood.test PRIVMSG #flood :\x01VERSION\x01")
	await client.collect(1)

	channel_replies = client.sent(lambda line: line.upper().startswith("NOTICE FLOODER ") and "\x01" in line)
	result(len(channel_replies) == 0, "no reply to a CTCP query sent to a channel")

	for _ in range(20):
		await client.send(f":flooder!f@flood.test PRIVMSG {client.nickname} :\x01VERSION\x01")

	# Replies pass through the client's own flood control, so wait for stragglers
	await client.collect(15)

	replies = client.sent(lambda line: line.upper().startswith("NOTICE FLOODER ") and "\x01" in line)
	result(len(replies) <= 2, f"{len(replies)} of 20 private CTCP queries from one host answered (limit 2 per host per 10 seconds)")

	await client.send(f":friend!f@friend.test PRIVMSG {client.nickname} :\x01VERSION\x01")
	await client.collect(5)

	result(len(client.sent(lambda line: line.upper().startswith("NOTICE FRIEND ") and "\x01" in line)) == 1, "another host still gets an answer")


async def scenario_malformed(client):
	"""Malformed PREFIX values, lines without a prefix, and messages whose channel name
	contains a no-break space or a tab. The client must stay connected, and #real must
	show only the legitimate message."""
	await client.collect(1)

	for value in ["(ov", "ov)@+", ")(ov@+", "(ov)@"]:
		await client.send(f":{SERVER} 005 {client.nickname} PREFIX={value} :are supported by this server")

	result(await client.is_alive("prefix"), "connected after malformed PREFIX values")

	await client.send(f"NOTICE {client.nickname} :Notice without a prefix")
	await client.send(f"PRIVMSG {client.nickname} :Message without a prefix")

	result(await client.is_alive("no-prefix"), "connected after lines without a prefix")

	await client.send(f":{client.nickname}!user@client.textual.test JOIN #real")
	await client.collect(1)

	await client.send(":friend!f@friend.test PRIVMSG #real :legit message")
	await client.send(":spoof!s@spoof.test PRIVMSG #real\u00a0x :SPOOFED via no-break space")
	await client.send(":spoof!s@spoof.test PRIVMSG #real\tx :SPOOFED via tab")

	result(await client.is_alive("spoof"), "connected after channel names with a no-break space or tab")
	print("CHECK: #real shows 'legit message' and no SPOOFED line", flush=True)


async def scenario_redirect_tls(client):
	"""(TLS) The server redirects the client (RPL_REDIR 010) to port+1; the client
	must reconnect there with TLS."""
	await client.collect(1)

	await client.send(f":{SERVER} 010 {client.nickname} 127.0.0.1 {Events.redirect_port} :Please use this server")

	try:
		await asyncio.wait_for(Events.reconnected.wait(), 15)
	except asyncio.TimeoutError:
		result(False, "client reconnected after the redirect")
		return

	result(Events.reconnected_with_tls, "redirected connection uses TLS")


async def scenario_conn_tls(client):
	"""(TLS) Run "Development/dev input /conn 127.0.0.1" while this waits; the client
	must come back to this TLS port."""
	await client.collect(1)

	print("WAITING: run Development/dev input /conn 127.0.0.1", flush=True)

	try:
		await asyncio.wait_for(Events.reconnected.wait(), 60)
	except asyncio.TimeoutError:
		result(False, "client reconnected to this TLS port after /CONN")
		return

	result(True, "client reconnected to this TLS port after /CONN")


async def scenario_links(client):
	"""Joins #links and posts links with safe and unsafe schemes, then stays connected
	(Ctrl-C to stop). Only http(s), ftp, irc(s), mailto and textual may become links."""
	await client.send(f":{client.nickname}!user@client.textual.test JOIN #links")
	await client.collect(1)

	for text in ["safe https://example.com/page and ircs://irc.libera.chat/#textual",
				 "unsafe javascript:alert(document.domain) and data:text/html,hello and file:///etc/hosts",
				 "ask first: mailto:someone@example.com and textual://activate-license/TEST-KEY-1234",
				 "the build was deployed (matches the highlight keyword deploy(ed)? used to test regular expressions)"]:
		await client.send(f":friend!f@friend.test PRIVMSG #links :{text}")

	while await client.collect(3600):
		pass


# MARK: - DCC
#
# Start Textual Dev so that it downloads offers automatically and announces 127.0.0.1:
#   Development/dev start "-File Transfers -> File Transfer Request Reply Action" 3 \
#     "-File Transfers -> File Transfer IP Address Detection Method" 2 \
#     "-File Transfers -> File Transfer Manually Entered IP Address" 127.0.0.1 \
#     "-File Transfers -> File Transfer Requests Use Reverse DCC" YES

DCC_ADDRESS = (127 << 24) | 1  # 127.0.0.1 as DCC writes it


def ctcp(text):
	return f"\x01{text}\x01"


class DCCSender:
	"""The peer side of a DCC SEND: the client connects and receives data[start:stop]."""

	def __init__(self, data, start=0, stop=None):
		self.data = data
		self.start = start
		self.stop = stop
		self.connections = 0
		self.acks = []
		self.done = asyncio.Event()

	async def listen(self, port):
		self.server = await asyncio.start_server(self.handle, "127.0.0.1", port)

	async def handle(self, reader, writer):
		self.connections += 1

		writer.write(self.data[self.start:self.stop])
		await writer.drain()

		# Stopping early simulates a broken transfer
		if self.stop is not None:
			await asyncio.sleep(0.5)
		else:
			try:
				while True:
					ack = await asyncio.wait_for(reader.readexactly(4), 5)
					self.acks.append(int.from_bytes(ack, "big"))
			except (asyncio.TimeoutError, asyncio.IncompleteReadError, ConnectionResetError):
				pass

		writer.close()
		self.done.set()

	def close(self):
		self.server.close()


class DCCReceiver:
	"""The peer side of a reverse DCC SEND: the client connects and sends the file."""

	def __init__(self, expected):
		self.expected = expected
		self.connections = 0
		self.received = 0
		self.done = asyncio.Event()

	async def listen(self, port):
		self.server = await asyncio.start_server(self.handle, "127.0.0.1", port)

	async def handle(self, reader, writer):
		self.connections += 1

		try:
			while self.received < self.expected:
				chunk = await asyncio.wait_for(reader.read(65536), 10)

				if not chunk:
					break

				self.received += len(chunk)

				writer.write((self.received & 0xFFFFFFFF).to_bytes(4, "big"))
				await writer.drain()
		except (asyncio.TimeoutError, ConnectionResetError):
			pass

		writer.close()
		self.done.set()

	def close(self):
		self.server.close()


async def wait_while_collecting(client, event, seconds):
	end = time.monotonic() + seconds

	while not event.is_set() and (remaining := end - time.monotonic()) > 0:
		if not await client.collect(min(remaining, 0.5)):
			return


def remove_downloads(*names):
	for name in names:
		path = os.path.join(DOWNLOADS, name)

		if os.path.exists(path):
			os.remove(path)


async def scenario_dcc_receive(client):
	"""(DCC) alice offers a 200 KB file; it arrives complete."""
	name = "textual-dev-dcc-receive.bin"
	remove_downloads(name)

	await client.collect(1)

	data = os.urandom(200_000)
	peer = DCCSender(data)
	await peer.listen(Events.dcc_port)

	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port} {len(data)}')}")
	await wait_while_collecting(client, peer.done, 15)
	peer.close()

	path = os.path.join(DOWNLOADS, name)
	saved = open(path, "rb").read() if os.path.exists(path) else b""

	result(saved == data, f"{len(saved)} of {len(data)} bytes saved, identical to what was sent")

	remove_downloads(name)


async def scenario_dcc_oversized(client):
	"""(DCC) alice announces 1000 bytes but sends 5000; only 1000 are written."""
	name = "textual-dev-dcc-oversized.bin"
	remove_downloads(name)

	await client.collect(1)

	peer = DCCSender(os.urandom(5000))
	await peer.listen(Events.dcc_port)

	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port} 1000')}")
	await wait_while_collecting(client, peer.done, 15)
	peer.close()

	path = os.path.join(DOWNLOADS, name)
	size = os.path.getsize(path) if os.path.exists(path) else -1

	result(size == 1000, f"saved {size} bytes of an announced 1000 (5000 were sent)")

	remove_downloads(name)


async def scenario_dcc_dotfile(client):
	"""(DCC) alice offers ".textual-dev-dotfile"; it is saved as "_.textual-dev-dotfile"."""
	remove_downloads(".textual-dev-dotfile", "_.textual-dev-dotfile")

	await client.collect(1)

	peer = DCCSender(b"0123456789")
	await peer.listen(Events.dcc_port)

	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND .textual-dev-dotfile {DCC_ADDRESS} {Events.dcc_port} 10')}")
	await wait_while_collecting(client, peer.done, 15)
	peer.close()

	result(not os.path.exists(os.path.join(DOWNLOADS, ".textual-dev-dotfile")) and
		   os.path.exists(os.path.join(DOWNLOADS, "_.textual-dev-dotfile")), "saved as _.textual-dev-dotfile, no dotfile created")

	remove_downloads(".textual-dev-dotfile", "_.textual-dev-dotfile")


async def scenario_dcc_resume_foreign(client):
	"""(DCC) A file of the offered name exists but isn't Textual's partial download:
	no RESUME (which would append to it and reveal its size); a new file is saved."""
	name = "textual-dev-foreign.txt"
	remove_downloads(name, "textual-dev-foreign_1.txt")

	foreign = b"this file belongs to someone else\n"
	open(os.path.join(DOWNLOADS, name), "wb").write(foreign)

	await client.collect(1)

	data = os.urandom(100)
	peer = DCCSender(data)
	await peer.listen(Events.dcc_port)

	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port} {len(data)}')}")
	await wait_while_collecting(client, peer.done, 15)
	peer.close()

	resumes = client.sent(lambda line: "DCC RESUME" in line.upper())

	result(len(resumes) == 0, "no DCC RESUME for a file Textual didn't download")
	result(open(os.path.join(DOWNLOADS, name), "rb").read() == foreign, "the existing file is unchanged")
	result(os.path.exists(os.path.join(DOWNLOADS, "textual-dev-foreign_1.txt")), "the download was saved as textual-dev-foreign_1.txt")

	remove_downloads(name, "textual-dev-foreign_1.txt")


async def scenario_dcc_resume_own(client):
	"""(DCC) alice's transfer breaks after 400 of 1000 bytes; her new offer resumes it.
	mallory's ACCEPT for the same port (with a wrong position) must be ignored."""
	name = "textual-dev-resume.bin"
	remove_downloads(name)

	await client.collect(1)

	data = os.urandom(1000)
	offer = f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port} {len(data)}')}"

	broken = DCCSender(data, stop=400)
	await broken.listen(Events.dcc_port)
	await client.send(offer)
	await wait_while_collecting(client, broken.done, 15)
	broken.close()
	await client.collect(2)

	path = os.path.join(DOWNLOADS, name)
	result(os.path.exists(path) and os.path.getsize(path) == 400, "the broken download stopped at 400 bytes")

	peer = DCCSender(data, start=400)
	await peer.listen(Events.dcc_port)

	count = len(client.received)
	await client.send(offer)
	await client.collect(2)

	resumes = [line for line in client.received[count:] if "DCC RESUME" in line.upper()]
	result(len(resumes) == 1 and " 400" in resumes[0], "the new offer is answered with DCC RESUME at 400")

	await client.send(f":mallory!m@evil.test PRIVMSG {client.nickname} :{ctcp(f'DCC ACCEPT {name} {Events.dcc_port} 1')}")
	await client.collect(1)
	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC ACCEPT {name} {Events.dcc_port} 400')}")

	await wait_while_collecting(client, peer.done, 15)
	peer.close()

	saved = open(path, "rb").read() if os.path.exists(path) else b""

	result(saved == data, f"resumed to {len(saved)} of {len(data)} bytes, identical to what was sent (mallory's ACCEPT ignored)")

	remove_downloads(name)


async def scenario_dcc_reverse_send(client):
	"""(DCC) alice sends a file, then run "Development/dev send alice ~/Downloads/textual-dev-send.bin"
	when asked. mallory answers the reverse DCC offer first; the file must go to alice only."""
	name = "textual-dev-send.bin"
	remove_downloads(name)

	await client.collect(1)

	# The sandbox only opens files Textual saved itself (or the user picked)
	data = os.urandom(50_000)
	peer = DCCSender(data)
	await peer.listen(Events.dcc_port)
	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port} {len(data)}')}")
	await wait_while_collecting(client, peer.done, 15)
	peer.close()
	await client.collect(1)

	print(f"WAITING: run Development/dev send alice ~/Downloads/{name}", flush=True)

	offer = None
	end = time.monotonic() + 60

	while offer is None and time.monotonic() < end:
		count = len(client.received)

		if not await client.collect(0.5):
			break

		for line in client.received[count:]:
			if line.upper().startswith("PRIVMSG ALICE ") and "DCC SEND" in line.upper():
				offer = line

	if offer is None:
		result(False, "Textual offered the file to alice")
		remove_downloads(name)
		return

	# DCC SEND <name> <address> 0 <size> <token>
	fields = offer.split("\x01")[1].split()
	size, token = fields[-2], fields[-1]

	result(fields[-3] == "0" and token.isdigit() and int(token) > 9999, f"reverse offer with port 0 and an unguessable token ({token})")

	mallory = DCCReceiver(int(size))
	await mallory.listen(Events.dcc_port)
	alice = DCCReceiver(int(size))
	await alice.listen(Events.dcc_port + 1)

	await client.send(f":mallory!m@evil.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port} {size} {token}')}")
	await client.collect(2)
	await client.send(f":alice!a@peer.test PRIVMSG {client.nickname} :{ctcp(f'DCC SEND {name} {DCC_ADDRESS} {Events.dcc_port + 1} {size} {token}')}")

	await wait_while_collecting(client, alice.done, 15)
	mallory.close()
	alice.close()

	result(mallory.connections == 0, "nothing was sent to mallory")
	result(alice.received == len(data), f"alice received {alice.received} of {len(data)} bytes")

	remove_downloads(name)


async def scenario_fin(client):
	"""Send a few channel lines and an ERROR, then close the connection at once
	(FIN right behind the data). Textual Dev must show every line, including the
	ERROR, and then treat the connection as closed instead of hanging."""
	await client.collect(2)

	channel = "#fin"

	await client.send(f":{client.nickname}!user@client.textual.test JOIN {channel}")

	for number in range(1, 6):
		await client.send(f":friend!f@friend.test PRIVMSG {channel} :line {number} before the server closes")

	await client.send("ERROR :Closing Link: scripted test server is closing the connection")

	result(True, "sent 5 lines and an ERROR, then closed; check #fin shows all of them and the server shows as disconnected")


async def scenario_pong_priority(client):
	"""After registering, send 30 lines at once, e.g. Development/dev input
	--channel '#flood' "$(seq -f 'line %g' 30)". When the third PRIVMSG arrives,
	the server PINGs; with flood control on, the PONG must arrive within 2 seconds,
	ahead of the PRIVMSGs still queued."""
	await client.send(f":{client.nickname}!user@client.textual.test JOIN #flood")

	privmsgs = 0
	ping_sent_at = None
	end = time.monotonic() + 120

	while time.monotonic() < end:
		try:
			line = await asyncio.wait_for(client.read_line(), 1)
		except asyncio.TimeoutError:
			continue

		if line is None:
			result(False, "connection closed")
			return

		upper = line.upper()

		if upper.startswith("PRIVMSG"):
			privmsgs += 1

			if privmsgs == 3 and ping_sent_at is None:
				ping_sent_at = time.monotonic()
				await client.send("PING :priority-check")
		elif upper.startswith("PONG") and "priority-check" in line:
			delay = time.monotonic() - ping_sent_at
			result(delay < 2, f"PONG after {delay:.2f} s, with {privmsgs} PRIVMSGs received so far")
			return
		elif upper.startswith("PING"):
			await client.send(f":{SERVER} PONG {SERVER} {line[5:]}")

	result(False, "no PONG within two minutes")


async def scenario_cap_ls(client):
	"""Negotiate capabilities like a CAP 302 server: a two-line LS that offers
	sasl, SASL PLAIN, then CAP NEW after registration. Give the server a NickServ
	password first (Development/dev config nicknamePassword=secret connect=1).
	Textual Dev must send one REQ after the last LS line, CAP END only once SASL
	is done, and nothing but a REQ for the NEW capability after registration."""
	problems = []
	seen = set()

	async def next_line(seconds=5):
		try:
			return await asyncio.wait_for(client.read_line(), seconds)
		except asyncio.TimeoutError:
			return None

	while not {"CAP", "NICK", "USER"} <= seen:
		line = await next_line()
		if line is None:
			result(False, "no CAP LS, NICK and USER")
			return
		command, _, rest = line.partition(" ")
		seen.add(command.upper())
		if command.upper() == "NICK":
			client.nickname = rest.lstrip(":")

	await client.send(f":{SERVER} CAP * LS * :multi-prefix batch sasl=PLAIN,EXTERNAL")

	early = await next_line(1.5)
	if early is not None:
		problems.append(f"sent before the last LS line: {early}")

	await client.send(f":{SERVER} CAP * LS :server-time away-notify draft/unknown")

	request = early if early and early.upper().startswith("CAP REQ") else await next_line()
	if request is None or not request.upper().startswith("CAP REQ"):
		result(False, f"expected CAP REQ, got {request}")
		return
	wanted = request.split(":", 1)[1].split()
	for capability in ["multi-prefix", "batch", "sasl", "server-time", "away-notify"]:
		if capability not in wanted:
			problems.append(f"{capability} not requested")
	if "draft/unknown" in wanted:
		problems.append("requested an unknown capability")

	await client.send(f":{SERVER} CAP {client.nickname} ACK :{' '.join(wanted)}")

	line = await next_line()
	if line != "AUTHENTICATE PLAIN":
		result(False, f"expected AUTHENTICATE PLAIN, got {line}")
		return

	await client.send("AUTHENTICATE +")

	line = await next_line()
	if line is None or not line.startswith("AUTHENTICATE "):
		result(False, f"expected the SASL credentials, got {line}")
		return

	stray = await next_line(1.5)
	if stray is not None:
		problems.append(f"sent before SASL finished: {stray}")

	await client.send(f":{SERVER} 900 {client.nickname} {client.nickname}!user@client.textual.test {client.nickname} :You are now logged in as {client.nickname}")
	await client.send(f":{SERVER} 903 {client.nickname} :SASL authentication successful")

	line = await next_line()
	if line != "CAP END":
		result(False, f"expected CAP END after SASL, got {line}; {problems}")
		return

	await client.welcome()
	await client.collect(2)

	await client.send(f":{SERVER} CAP {client.nickname} NEW :chghost")

	start = len(client.received)
	await client.collect(2)
	after = client.received[start:]

	if "CAP REQ :chghost" not in after and "CAP REQ chghost" not in after:
		problems.append(f"no REQ for the NEW capability: {after}")

	await client.send(f":{SERVER} CAP {client.nickname} ACK :chghost")

	start = len(client.received)
	await client.collect(2)
	if any(line.upper().startswith("CAP END") for line in client.received[start:]):
		problems.append("CAP END after registration")

	result(not problems, "; ".join(problems) or "one REQ after the last LS line, END after SASL, NEW requested after registration without END")


async def scenario_protocol_fixes(client):
	"""Lines that exercise protocol fixes (plan 6.3), checked in Textual Dev:
	#pf must list 4 users (a NAMES line starting with a known nickname used to
	drop the rest); a ZNC buffextras nickname change prints in #pf; a nested
	batch's lines print (nested first, then outer); a batch that never closes
	prints its line after about 60 seconds; "You are now an IRC operator" is
	shown twice, because -o in between clears the operator state."""
	if not await client.register_with_capabilities("batch", server_name="irc.znc.in"):
		result(False, "registration failed")
		return

	nick = client.nickname
	channel = "#pf"

	await client.send(f":{nick}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {nick} = {channel} :@{nick} friend1")
	await client.send(f":{SERVER} 353 {nick} = {channel} :friend1 friend2 friend3")
	await client.send(f":{SERVER} 366 {nick} {channel} :End of /NAMES list.")
	await client.collect(2)

	await client.send(f":*buffextras!buffextras@znc.in PRIVMSG {channel} :friend3!f@friend.test is now known as friend3b")
	await client.collect(1)

	await client.send(f":{SERVER} BATCH +outer example.test/outer")
	await client.send(f"@batch=outer :{SERVER} BATCH +inner example.test/inner")
	await client.send(f"@batch=inner :friend1!f@friend.test PRIVMSG {channel} :nested batch line")
	await client.send(f"@batch=outer :friend2!f@friend.test PRIVMSG {channel} :outer batch line")
	await client.send(f"@batch=outer :{SERVER} BATCH -inner")
	await client.send(f":{SERVER} BATCH -outer")
	await client.collect(1)

	await client.send(f":{SERVER} BATCH +stuck example.test/stuck")
	await client.send(f"@batch=stuck :friend1!f@friend.test PRIVMSG {channel} :line of a batch that never closes")

	await client.send(f":{SERVER} 381 {nick} :You are now an IRC operator")
	await client.send(f":{nick} MODE {nick} :-o")
	await client.send(f":{SERVER} 381 {nick} :You are now an IRC operator")

	await client.collect(75)

	result(True, "sent; check #pf (4 users, friend3b, both batch lines, the stuck line after ~60 s) and the console (operator message twice)")


async def scenario_ison_split(client):
	"""Answer the ISON requests Textual Dev sends for its open queries: open
	many queries with long nicknames first (e.g. 45 of 12 characters with
	Development/dev input). Every ISON line must stay under 512 bytes, a long
	list must be split, and each line is answered with every second nickname
	online; those queries become active, the others inactive."""
	start = time.monotonic()
	rounds = []
	current = []

	while time.monotonic() - start < 100:
		try:
			line = await asyncio.wait_for(client.read_line(), 1)
		except asyncio.TimeoutError:
			if current:
				rounds.append(current)
				current = []
			continue

		if line is None:
			break

		upper = line.upper()

		if upper.startswith("PING"):
			await client.send(f":{SERVER} PONG {SERVER} {line[5:]}")
		elif upper.startswith("ISON "):
			current.append(line)
			nicknames = line[5:].lstrip(":").split()
			online = " ".join(nicknames[::2])
			await client.send(f":{SERVER} 303 {client.nickname} :{online}")

	if current:
		rounds.append(current)

	too_long = [line for round in rounds for line in round if len((line + "\r\n").encode()) > 512]
	split = [round for round in rounds if len(round) > 1]

	result(bool(rounds) and not too_long and bool(split),
		f"{len(rounds)} ISON rounds, line counts {[len(round) for round in rounds]}, longest {max((len(line) for round in rounds for line in round), default=0)} bytes, {len(too_long)} over 512")


async def scenario_casemapping(client):
	"""Nicknames compare under CASEMAPPING (rfc1459 when the server doesn't
	say): NAMES lists Nick[A], then nick{a} leaves and NICK{B} joins. #cm must
	end with 2 users (Textual Dev and NICK{B}): nick{a} is the same user as
	Nick[A] under rfc1459."""
	nick = client.nickname
	channel = "#cm"

	await client.send(f":{nick}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {nick} = {channel} :@{nick} Nick[A]")
	await client.send(f":{SERVER} 366 {nick} {channel} :End of /NAMES list.")
	await client.collect(2)

	await client.send(f":nick{{a}}!a@friend.test PART {channel} :leaving under another case")
	await client.send(f":NICK{{B}}!b@friend.test JOIN {channel}")

	await client.collect(30)

	result(True, "sent; #cm must list 2 users (Textual Dev and NICK{B})")


async def scenario_channel_lookup(client):
	"""Channel and query lookups follow CASEMAPPING (also when it changes) and
	query renames, and highlights follow the current nickname. Afterwards:
	#Chan[1] shows messages 1, 4 and 6 but not 3; 6 is a highlight, 5 isn't
	(it names the old nickname); there is one query, Robert, with message 2
	and "after rename", and no separate robert query."""
	nick = client.nickname
	new_nick = "Renamed"
	channel = "#Chan[1]"

	await client.send(f":{nick}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {nick} = {channel} :@{nick} friend")
	await client.send(f":{SERVER} 366 {nick} {channel} :End of /NAMES list.")
	await client.collect(2)

	await client.send(":friend!f@friend.test PRIVMSG #chan{1} :1 sent to #chan{1}, the same channel under rfc1459")
	await client.send(f":Bob!b@friend.test PRIVMSG {nick} :2 before rename")
	await client.collect(2)

	await client.send(":Bob!b@friend.test NICK Robert")
	await client.collect(1)
	await client.send(f":robert!b@friend.test PRIVMSG {nick} :after rename")
	await client.collect(1)

	await client.send(f":{SERVER} 005 {nick} CASEMAPPING=ascii :are supported by this server")
	await client.send(":friend!f@friend.test PRIVMSG #chan{1} :3 sent to #chan{1} under ascii, must not show")
	await client.send(":friend!f@friend.test PRIVMSG #CHAN[1] :4 sent to #CHAN[1] under ascii")
	await client.collect(1)

	await client.send(f":{nick}!user@client.textual.test NICK {new_nick}")
	await client.collect(1)
	await client.send(f":friend!f@friend.test PRIVMSG {channel} :5 {nick}: the old nickname, no highlight")
	await client.send(f":friend!f@friend.test PRIVMSG {channel} :6 {new_nick}: the new nickname, a highlight")

	await client.collect(30)

	result(True, "sent; check #Chan[1] and the Robert query")


async def scenario_standard_replies(client):
	"""FAIL, WARN and NOTE (standard-replies). Afterwards: #sr shows reply 1
	(its context names the channel); the console shows replies 2, 3 and 4
	(4 has a code no client knows) without a "*"; the malformed reply 5 shows
	nowhere."""
	nick = client.nickname
	channel = "#sr"

	await client.send(f":{nick}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {nick} = {channel} :@{nick}")
	await client.send(f":{SERVER} 366 {nick} {channel} :End of /NAMES list.")
	await client.collect(2)

	await client.send(f":{SERVER} FAIL PRIVMSG CANNOT_SEND {channel} :1 Your message could not be delivered")
	await client.send(f":{SERVER} WARN REHASH CERTS_EXPIRED :2 Certificate [xyz] has expired")
	await client.send(f":{SERVER} NOTE * OPER_MESSAGE :3 The server will restart soon")
	await client.send(f":{SERVER} FAIL CHATHISTORY TEXTUAL_UNKNOWN_CODE LATEST somewhere :4 A code Textual doesn't know")
	await client.send(f":{SERVER} FAIL ONLY_TWO :5 malformed, must not show")

	await client.collect(30)

	result(True, "sent; check #sr and the console")


async def scenario_sts(client):
	"""strict-transport-security; connect to irc://localhost:6680 (a host name:
	policies never apply to IP addresses). Every plaintext connection is offered
	sts=port=6681 and must reconnect with TLS to 6681, which offers
	sts=duration=300 and stays connected. A policy is kept only when the
	certificate is validated; then the next connection goes straight to 6681.
	Runs for ten minutes."""
	pass


async def run_sasl_scram(client, variant):
	"""Shared by the sasl-scram scenarios: offers sasl=PLAIN,SCRAM-SHA-512 and
	runs the server side of SCRAM-SHA-512 for the user "scramuser" with the
	password "textual-scram" (set them in Textual first)."""
	import base64, hashlib, hmac as hmac_module

	username, password = "scramuser", "textual-scram"
	salt = os.urandom(300)  # makes the server-first longer than 400 base64 characters
	iterations = 4096
	nickname = "*"
	state = "start"
	parts = []
	auth = {}
	outcome = []

	async def send_authenticate(payload):
		encoded = base64.b64encode(payload.encode()).decode()
		chunks = [encoded[i:i + 400] for i in range(0, len(encoded), 400)] or [""]
		for chunk in chunks:
			await client.send(f"AUTHENTICATE {chunk or '+'}")
		if len(chunks[-1]) == 400:
			await client.send("AUTHENTICATE +")

	while True:
		line = await client.read_line()
		if line is None:
			break

		command, _, rest = line.partition(" ")
		command = command.upper()

		if command == "CAP" and rest.upper().startswith("LS"):
			await client.send(f":{SERVER} CAP * LS :sasl=PLAIN,SCRAM-SHA-512")
		elif command == "CAP" and rest.upper().startswith("REQ"):
			await client.send(f":{SERVER} CAP * ACK :{rest.split(' ', 1)[1].lstrip(':')}")
		elif command == "NICK":
			nickname = rest.lstrip(":")
			client.nickname = nickname
		elif command == "CAP" and rest.upper().startswith("END"):
			outcome.append("CAP END")
			break
		elif command == "AUTHENTICATE":
			data = rest.strip()

			if state == "start" and data == "SCRAM-SHA-512":
				if variant == "fallback":
					await client.send(f":{SERVER} 904 {nickname} :SASL authentication failed")
					state = "expect-plain"
				else:
					await client.send("AUTHENTICATE +")
					state = "client-first"
			elif state == "expect-plain":
				outcome.append(f"after 904: {data}")
				if data == "PLAIN":
					await client.send("AUTHENTICATE +")
					state = "plain"
				else:
					break
			elif state == "plain":
				fields = base64.b64decode(data).split(b"\0")
				if fields[-1].decode() == password:
					await client.send(f":{SERVER} 900 {nickname} {nickname}!u@h {username} :You are now logged in as {username}")
					await client.send(f":{SERVER} 903 {nickname} :SASL authentication successful")
					outcome.append("PLAIN accepted")
				else:
					await client.send(f":{SERVER} 904 {nickname} :SASL authentication failed")
			elif state == "client-first":
				parts.append("" if data == "+" else data)
				if len(data) == 400:
					continue
				message = base64.b64decode("".join(parts)).decode(); parts.clear()
				bare = message[3:]
				attributes = dict(item.split("=", 1) for item in bare.split(","))
				nonce = attributes["r"] + base64.b64encode(os.urandom(18)).decode()
				server_first = f"r={nonce},s={base64.b64encode(salt).decode()},i={iterations}"
				auth.update(bare=bare, server_first=server_first, nonce=nonce, user=attributes["n"])
				await send_authenticate(server_first)
				state = "client-final"
			elif state == "client-final":
				parts.append("" if data == "+" else data)
				if len(data) == 400:
					continue
				message = base64.b64decode("".join(parts)).decode(); parts.clear()
				without_proof, _, proof = message.rpartition(",p=")
				salted = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, iterations)
				client_key = hmac_module.new(salted, b"Client Key", hashlib.sha512).digest()
				stored_key = hashlib.sha512(client_key).digest()
				auth_message = f"{auth['bare']},{auth['server_first']},{without_proof}".encode()
				signature = hmac_module.new(stored_key, auth_message, hashlib.sha512).digest()
				expected_proof = bytes(a ^ b for a, b in zip(client_key, signature))
				valid = (auth["user"] == username and base64.b64decode(proof) == expected_proof and without_proof == f"c=biws,r={auth['nonce']}")
				outcome.append(f"proof {'valid' if valid else 'INVALID'}")
				server_key = hmac_module.new(salted, b"Server Key", hashlib.sha512).digest()
				server_signature = hmac_module.new(server_key, auth_message, hashlib.sha512).digest()
				if variant == "badsig":
					server_signature = bytes(64)
				await send_authenticate("v=" + base64.b64encode(server_signature).decode())
				state = "server-final"
			elif state == "server-final":
				outcome.append(f"after server-final: {data}")
				if data == "+":
					await client.send(f":{SERVER} 900 {nickname} {nickname}!u@h {username} :You are now logged in as {username}")
					await client.send(f":{SERVER} 903 {nickname} :SASL authentication successful")
				elif data == "*":
					await client.send(f":{SERVER} 906 {nickname} :SASL authentication aborted")
				state = "done"
			elif state == "done" and data == "PLAIN":
				outcome.append("PLAIN after the abort")

	print(f"CHECK: {outcome}", flush=True)

	if variant == "badsig":
		result(outcome == ["proof valid", "after server-final: *", "CAP END"],
			"the client aborted on the wrong server signature and didn't fall back to PLAIN")
	elif variant == "fallback":
		result(outcome == ["after 904: PLAIN", "PLAIN accepted", "CAP END"], "the client fell back to PLAIN after 904")
	else:
		result(outcome == ["proof valid", "after server-final: +", "CAP END"],
			"SCRAM-SHA-512 with a long server-first, the server signature checked and the final + sent")

	if "CAP END" in outcome:
		await client.welcome()
		await client.collect(30)


async def scenario_sasl_scram(client):
	"""SCRAM-SHA-512 (set username=scramuser nicknamePassword=textual-scram):
	the server-first is longer than 400 characters (reassembly), the proof must
	be valid, the client must check the server signature and send the final +."""
	await run_sasl_scram(client, "ok")


async def scenario_sasl_scram_fallback(client):
	"""SCRAM-SHA-512 fails with 904 (an account without SCRAM credentials): the
	client must try PLAIN next and log in with it."""
	await run_sasl_scram(client, "fallback")


async def scenario_sasl_scram_badsig(client):
	"""The server sends a wrong signature: the client must abort (AUTHENTICATE *)
	and must not fall back to PLAIN with the password."""
	await run_sasl_scram(client, "badsig")


async def scenario_chathistory(client):
	"""draft/chathistory without ZNC playback. Connection 1: #ch gets line 1
	(msgid m1), then the server drops the connection. Connection 2 (the
	reconnect): after the client joins #ch it must send CHATHISTORY LATEST #ch
	msgid=m1; the batch holds line 1 again, line 2 (missed) and line 3 (our own,
	sent from another client). #ch must show 1 once, then 2 and 3, without a
	notification. Runs for five minutes."""
	pass


async def scenario_utf8only(client):
	"""UTF8ONLY (set the server's primary encoding to Latin-1 first, e.g. config
	primaryEncoding=5). The server advertises UTF8ONLY and NETWORK=UTF8\\x20Test;
	#u gets line 1 with a Latin-1 byte (must show "caf" + U+FFFD + " x") and
	line 2 in UTF-8. Then type "café ☃" in #u: it must arrive as UTF-8."""
	nick = client.nickname
	await client.send(f":{SERVER} 005 {nick} UTF8ONLY NETWORK=UTF8\\x20Test :are supported by this server")
	await client.send(f":{nick}!user@client.textual.test JOIN #u")
	await client.send(f":{SERVER} 353 {nick} = #u :@{nick} gina")
	await client.send(f":{SERVER} 366 {nick} #u :End of /NAMES list.")
	await client.collect(1)
	await client.send_raw(b":gina!g@friend.test PRIVMSG #u :1 caf\xe9 x\r\n")
	await client.send(":gina!g@friend.test PRIVMSG #u :2 caf\u00e9 \u2713 in UTF-8")

	print("WAITING: type caf\u00e9 \u2603 in #u", flush=True)
	end = time.monotonic() + 120
	while time.monotonic() < end:
		try:
			data = await asyncio.wait_for(client.reader.readline(), 1)
		except asyncio.TimeoutError:
			continue
		if not data:
			break
		if data.startswith(b"PING"):
			await client.send(":" + SERVER + " PONG " + SERVER + " " + data[5:].decode(errors="replace").strip())
		if data.startswith(b"PRIVMSG #u"):
			log("<<", f"raw bytes: {data!r}")
			try:
				text = data.decode("utf-8")
			except UnicodeDecodeError:
				result(False, f"the client sent non-UTF-8 bytes: {data!r}")
				return
			result("caf\u00e9 \u2603" in text, f"the client's line arrived as UTF-8: {text.strip()!r}")
			await client.collect(30)
			return
	result(False, "no line from the client")


async def scenario_silent(client):
	"""Accept the connection and never answer (not even a TLS handshake): connect
	with ircs:// or irc:// and Textual Dev must give up after 30 seconds."""
	pass


SCENARIOS = {
	"idle": scenario_idle,
	"links": scenario_links,
	"nickserv-spoof": scenario_nickserv_spoof,
	"long-line": scenario_long_line,
	"ctcp-flood": scenario_ctcp_flood,
	"malformed": scenario_malformed,
	"redirect-tls": scenario_redirect_tls,
	"conn-tls": scenario_conn_tls,
	"dcc-receive": scenario_dcc_receive,
	"dcc-oversized": scenario_dcc_oversized,
	"dcc-dotfile": scenario_dcc_dotfile,
	"dcc-resume-foreign": scenario_dcc_resume_foreign,
	"dcc-resume-own": scenario_dcc_resume_own,
	"dcc-reverse-send": scenario_dcc_reverse_send,
	"fin": scenario_fin,
	"pong-priority": scenario_pong_priority,
	"silent": scenario_silent,
	"cap-ls": scenario_cap_ls,
	"protocol-fixes": scenario_protocol_fixes,
	"ison-split": scenario_ison_split,
	"casemapping": scenario_casemapping,
	"channel-lookup": scenario_channel_lookup,
	"standard-replies": scenario_standard_replies,
	"sts": scenario_sts,
	"sasl-scram": scenario_sasl_scram,
	"chathistory": scenario_chathistory,
	"utf8only": scenario_utf8only,
	"sasl-scram-fallback": scenario_sasl_scram_fallback,
	"sasl-scram-badsig": scenario_sasl_scram_badsig,
}

# Scenarios that register the client themselves
OWN_REGISTRATION_SCENARIOS = {"cap-ls", "protocol-fixes", "sasl-scram", "sasl-scram-fallback", "sasl-scram-badsig"}

TLS_SCENARIOS = {"redirect-tls", "conn-tls"}


async def run_chathistory_scenario(port):
	capabilities = "batch server-time message-tags draft/chathistory"
	connections = 0

	def stamp(seconds_ago):
		moment = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=seconds_ago)
		return moment.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (moment.microsecond // 1000)

	async def handle(reader, writer):
		nonlocal connections
		connections += 1
		number = connections
		client = Client(reader, writer)

		if not await client.register_with_capabilities(capabilities):
			writer.close()
			return

		nick = client.nickname

		if number == 1:
			await client.send(f":{nick}!user@client.textual.test JOIN #ch")
			await client.send(f":{SERVER} 353 {nick} = #ch :{nick} gina")
			await client.send(f":{SERVER} 366 {nick} #ch :End of /NAMES list.")
			await client.collect(1)
			stamps["line1"] = stamp(0)
			await client.send(f"@msgid=m1;time={stamps['line1']} :gina!g@friend.test PRIVMSG #ch :1 seen live before the drop")
			await client.collect(2)
			log("<<", "dropping the connection")
			writer.close()
			return

		requested = None
		end = time.monotonic() + 30

		while time.monotonic() < end:
			try:
				line = await asyncio.wait_for(client.read_line(), 1)
			except asyncio.TimeoutError:
				continue
			if line is None:
				break
			command, _, rest = line.partition(" ")
			command = command.upper()
			if command == "PING":
				await client.send(f":{SERVER} PONG {SERVER} {rest}")
			elif command == "JOIN":
				await client.send(f":{nick}!user@client.textual.test JOIN #ch")
				await client.send(f":{SERVER} 353 {nick} = #ch :{nick} gina")
				await client.send(f":{SERVER} 366 {nick} #ch :End of /NAMES list.")
			elif command == "CHATHISTORY":
				requested = line
				await client.send(f":{SERVER} BATCH +h1 chathistory #ch")
				await client.send(f"@batch=h1;msgid=m1;time={stamps['line1']} :gina!g@friend.test PRIVMSG #ch :1 seen live before the drop")
				await client.send(f"@batch=h1;msgid=m2;time={stamp(0)} :gina!g@friend.test PRIVMSG #ch :2 missed while disconnected")
				await client.send(f"@batch=h1;msgid=m3;time={stamp(0)} :{nick}!user@client.textual.test PRIVMSG #ch :3 my own line from another client")
				await client.send(f":{SERVER} BATCH -h1")
				break

		result(requested == "CHATHISTORY LATEST #ch msgid=m1 100", f"request after the rejoin: {requested!r}")
		await client.collect(240)
		writer.close()

	stamps = {}
	server = await asyncio.start_server(handle, "127.0.0.1", port)
	print(f"Scenario 'chathistory' waiting on irc://127.0.0.1:{port}", flush=True)
	await asyncio.sleep(300)
	server.close()


async def run_sts_scenario(port):
	tls_port = port + 1

	tls_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
	tls_context.load_cert_chain(os.path.join(CERTIFICATE_DIRECTORY, "fullchain.pem"),
								os.path.join(CERTIFICATE_DIRECTORY, "privkey.pem"))

	async def plaintext(reader, writer):
		client = Client(reader, writer)
		log("<<", "plaintext connection: offering sts=port=%d" % tls_port)
		if await client.register_with_capabilities(f"sts=port={tls_port}"):
			await client.collect(10)
			result(False, "the client stayed on plaintext after the sts offer")
		else:
			result(True, "the client left the plaintext connection after the sts offer")
		writer.close()

	async def secure(reader, writer):
		client = Client(reader, writer)
		log("<<", "TLS connection: offering sts=duration=300")
		result(True, "the client connected with TLS on %d" % tls_port)
		if await client.register_with_capabilities("sts=duration=300 server-time"):
			while await client.collect(3600):
				pass
		writer.close()

	servers = [await asyncio.start_server(plaintext, "127.0.0.1", port),
			   await asyncio.start_server(secure, "127.0.0.1", tls_port, ssl=tls_context)]

	print(f"Scenario 'sts' waiting on irc://localhost:{port} (TLS on {tls_port})", flush=True)

	await asyncio.sleep(600)

	for server in servers:
		server.close()


async def main():
	parser = argparse.ArgumentParser(description="Scripted IRC server for testing Textual Dev")
	parser.add_argument("scenario", nargs="?", choices=SCENARIOS.keys())
	parser.add_argument("--port", type=int, default=6680)
	parser.add_argument("--tls", action="store_true", help="use TLS (always on for the TLS scenarios)")
	parser.add_argument("--list", action="store_true", help="list the scenarios")
	arguments = parser.parse_args()

	if arguments.list or arguments.scenario is None:
		for name, function in SCENARIOS.items():
			print(f"{name}: {' '.join(function.__doc__.split())}")
		return

	scenario = SCENARIOS[arguments.scenario]
	finished = asyncio.Event()

	use_tls = arguments.tls or arguments.scenario in TLS_SCENARIOS
	tls_context = None

	if use_tls:
		tls_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
		tls_context.load_cert_chain(os.path.join(CERTIFICATE_DIRECTORY, "fullchain.pem"),
									os.path.join(CERTIFICATE_DIRECTORY, "privkey.pem"))

	Events.reconnected = asyncio.Event()
	Events.redirect_port = arguments.port + 1
	Events.dcc_port = arguments.port + 10
	connections = 0

	async def handle(reader, writer):
		nonlocal connections
		connections += 1

		if connections > 1:
			Events.reconnected_with_tls = use_tls
			Events.reconnected.set()
			writer.close()
			return

		if arguments.scenario == "silent":
			log("<<", "connection accepted; staying silent for two minutes")
			await asyncio.sleep(120)
			writer.close()
			finished.set()
			return

		client = Client(reader, writer)

		if arguments.scenario in OWN_REGISTRATION_SCENARIOS:
			await scenario(client)
		elif await client.register():
			await scenario(client)

		writer.close()
		finished.set()

	async def handle_redirect(reader, writer):
		# Plain TCP: a TLS client starts with a handshake record (0x16)
		try:
			first = await asyncio.wait_for(reader.read(1), 5)
		except asyncio.TimeoutError:
			first = b""

		log("<<", f"redirected connection starts with {first.hex() or 'nothing'}")

		Events.reconnected_with_tls = (first == b"\x16")
		Events.reconnected.set()
		writer.close()

	if arguments.scenario == "sts":
		await run_sts_scenario(arguments.port)
		return

	if arguments.scenario == "chathistory":
		await run_chathistory_scenario(arguments.port)
		return

	servers = [await asyncio.start_server(handle, "127.0.0.1", arguments.port, ssl=tls_context)]

	if arguments.scenario == "redirect-tls":
		servers.append(await asyncio.start_server(handle_redirect, "127.0.0.1", Events.redirect_port))

	scheme = "ircs" if use_tls else "irc"
	print(f"Scenario '{arguments.scenario}' waiting on {scheme}://127.0.0.1:{arguments.port}", flush=True)

	await finished.wait()

	for server in servers:
		server.close()


if __name__ == "__main__":
	try:
		asyncio.run(main())
	except KeyboardInterrupt:
		sys.exit(0)
