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
		self.registration_lines = []  # lines from the client until registration
		self.isupport_extra = ""  # more ISUPPORT tokens for the welcome

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

			self.registration_lines.append(line)

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
			f":{SERVER} 005 {self.nickname} CHANTYPES=# PREFIX=(ov)@+ NETWORK=TextualScripted {self.isupport_extra}".rstrip() + " :are supported by this server",
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
				for channel in rest.split(" ")[0].lstrip(":").split(","):
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


async def scenario_review_crashes(client):
	"""Review fixes, group 1. Connect with Development/dev connect
	'irc://127.0.0.1:6680/%23ok,%23x%0D%0APRIVMSG%20NickServ%20:hijacked': the link's
	second channel hides a line break and must be dropped, so the client joins #ok
	and never messages NickServ. Then a WALLOPS without text (crashed the client)
	and a normal one, which must show in the console."""
	await client.collect(4)

	result(len(client.sent(lambda line: "NICKSERV" in line.upper())) == 0, "no line from the link's hidden command")
	result(len(client.sent(lambda line: line.upper().startswith("JOIN") and "#OK" in line.upper())) >= 1, "joined #ok from the link")

	await client.send(":irc.textual.test WALLOPS")
	await client.send(":irc.textual.test WALLOPS :A normal WALLOPS after the empty one")

	still_connected = await client.collect(4)
	result(still_connected, "client still connected after a WALLOPS without text")

	while await client.collect(3600):
		pass


async def scenario_review_irc(client):
	"""Review fixes, group 3. Set AutojoinChannelOnInvite to YES before starting
	Textual Dev. Registers with echo-message, server-time and message-tags. Checked
	here: invites to "0" and "#a,0" are not joined, "#invited" is. To look at: alice
	left #r's member list (QUIT without a reason), carol's line (empty time= tag)
	shows today's time, the query "bob" is now "Bob". Then type /smsg dave secret
	and /msg nick@server hi: the server echoes them and no query may open."""
	if not await client.register_with_capabilities("echo-message server-time message-tags"):
		return

	nick = client.nickname
	await client.send(f":{nick}!user@client.textual.test JOIN #r")
	await client.send(f":{SERVER} 353 {nick} = #r :@{nick} alice bob carol")
	await client.send(f":{SERVER} 366 {nick} #r :End of /NAMES list.")
	await client.collect(2)

	await client.send(":alice!a@friend.test QUIT")
	await client.send("@time= :carol!c@friend.test PRIVMSG #r :this line has an empty time tag and must show today's time")
	await client.send(f":bob!b@friend.test PRIVMSG {nick} :hi from bob, this query must become Bob")
	await client.collect(2)
	await client.send(":bob!b@friend.test NICK Bob")
	await client.send(f":Bob!b@friend.test PRIVMSG {nick} :now I am Bob")
	result(await client.is_alive("quit"), "still connected after a QUIT without a reason")

	await client.send(f":inviter!i@friend.test INVITE {nick} 0")
	await client.send(f":inviter!i@friend.test INVITE {nick} :#a,0")
	await client.send(f":inviter!i@friend.test INVITE {nick} #invited")
	await client.collect(4)

	joined = [line.split(" ")[1].lstrip(":").split(",") for line in client.received if line.upper().startswith("JOIN ")]
	result(not any("0" in targets for targets in joined), "no JOIN 0 from an invite")
	result(any("#invited" in targets for targets in joined), "an invite to #invited was joined")

	print("WAITING: type /smsg dave secret and /msg nick@server hi", flush=True)
	end = time.monotonic() + 600
	while (remaining := end - time.monotonic()) > 0:
		try:
			line = await asyncio.wait_for(client.read_line(), remaining)
		except asyncio.TimeoutError:
			break
		if line is None:
			break
		command, _, rest = line.partition(" ")
		if command.upper() == "PING":
			await client.send(f":{SERVER} PONG {SERVER} {rest}")
		elif command.upper() in ("PRIVMSG", "NOTICE"):
			await client.send(f":{nick}!user@client.textual.test {line}")


async def scenario_review_view(client):
	"""Review fixes, group 4 (import the two review filters first). The console
	must not show the 004 line ("scripted io bklov"): a filter saved with the
	numeric "4". In #v: alice's line with "&local" shows it once (not "&amp;local");
	the stranger's "spam" line (not in the member list) and alice's line of a's
	ending in b (the filter's slow pattern) are hidden; the copy line copies as
	"&lt;b&gt;"; the last line shows."""
	nick = client.nickname
	await client.send(f":{SERVER} 005 {nick} CHANTYPES=#& :are supported by this server")
	await client.send(f":{nick}!user@client.textual.test JOIN #v")
	await client.send(f":{SERVER} 353 {nick} = #v :@{nick} alice")
	await client.send(f":{SERVER} 366 {nick} #v :End of /NAMES list.")
	await client.collect(2)

	await client.send(":alice!a@friend.test PRIVMSG #v :hello, see &local and #v")
	await client.send(":stranger!s@elsewhere.test PRIVMSG #v :spam from someone outside the member list")
	await client.send(":alice!a@friend.test PRIVMSG #v :" + "a" * 40 + "b")
	await client.send(":alice!a@friend.test PRIVMSG #v :copy me: &lt;b&gt;")
	await client.send(":alice!a@friend.test PRIVMSG #v :the last line, after the hidden ones")

	while await client.collect(3600):
		pass


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


async def scenario_znc_disconnect(client):
	"""Looks like ZNC (its CAP replies come from irc.znc.in), lets the client
	join #znc, then *status says the IRC side disconnected, in German (ZNC's
	LANGUAGE setting): ZNC Additions must mark #znc as no longer joined. Join
	#znc within 6 seconds."""
	if not await client.register_with_capabilities("znc.in/self-message", server_name="irc.znc.in"):
		return

	await client.collect(6)

	result(len(client.sent(lambda line: line.upper().startswith("JOIN #ZNC"))) >= 1, "client joined #znc")

	await client.send(f":*status!znc@znc.in PRIVMSG {client.nickname} :IRC-Verbindung getrennt. Verbinde erneut...")
	await client.collect(3)

	print("-- now check in Textual: #znc is shown as not joined")

	while await client.collect(3600):
		pass


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
				if variant in ("badsig", "badsig-success"):
					server_signature = bytes(64)
				if variant == "noproof":
					# Success without ever sending the server signature
					await client.send(f":{SERVER} 900 {nickname} {nickname}!u@h {username} :You are now logged in as {username}")
					await client.send(f":{SERVER} 903 {nickname} :SASL authentication successful")
					state = "done"
					continue
				await send_authenticate("v=" + base64.b64encode(server_signature).decode())
				state = "server-final"
			elif state == "server-final":
				outcome.append(f"after server-final: {data}")
				if data == "+":
					await client.send(f":{SERVER} 900 {nickname} {nickname}!u@h {username} :You are now logged in as {username}")
					await client.send(f":{SERVER} 903 {nickname} :SASL authentication successful")
				elif data == "*" and variant == "badsig-success":
					# Ignores the abort and claims success
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
	elif variant == "badsig-success":
		result(outcome == ["proof valid", "after server-final: *"],
			"the client disconnected when the server answered its abort with success")
	elif variant == "noproof":
		result(outcome == ["proof valid"],
			"the client disconnected when the server reported success without its signature")
	elif variant == "fallback":
		result(outcome == ["after 904: PLAIN", "PLAIN accepted", "CAP END"], "the client fell back to PLAIN after 904")
	else:
		result(outcome == ["proof valid", "after server-final: +", "CAP END"],
			"SCRAM-SHA-512 with a long server-first, the server signature checked and the final + sent")

	if "CAP END" in outcome:
		await client.welcome()
		await client.collect(30)


def p256_verify(public_key, digest, signature):
	"""ECDSA P-256 verification of a DER signature over digest (taken as the hash, as
	Atheme does with the challenge); public_key is compressed. Plain Python: the VM's
	Python has no crypto package."""
	p = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
	n = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
	b = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b
	g = (0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296,
		0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5)

	def add(first, second):
		if first is None:
			return second
		if second is None:
			return first
		if first[0] == second[0] and (first[1] + second[1]) % p == 0:
			return None
		if first == second:
			slope = (3 * first[0] * first[0] - 3) * pow(2 * first[1], -1, p) % p
		else:
			slope = (second[1] - first[1]) * pow(second[0] - first[0], -1, p) % p
		x = (slope * slope - first[0] - second[0]) % p
		return (x, (slope * (first[0] - x) - first[1]) % p)

	def multiply(k, point):
		total = None
		while k:
			if k & 1:
				total = add(total, point)
			point = add(point, point)
			k >>= 1
		return total

	x = int.from_bytes(public_key[1:], "big")
	y = pow((x * x * x - 3 * x + b) % p, (p + 1) // 4, p)
	if (y & 1) != (public_key[0] & 1):
		y = p - y

	try:
		if signature[0] != 0x30 or signature[2] != 0x02:
			return False
		r_length = signature[3]
		r = int.from_bytes(signature[4:4 + r_length], "big")
		offset = 4 + r_length
		if signature[offset] != 0x02:
			return False
		s = int.from_bytes(signature[offset + 2:offset + 2 + signature[offset + 1]], "big")
	except IndexError:
		return False

	if not (0 < r < n and 0 < s < n):
		return False

	w = pow(s, -1, n)
	point = add(multiply(int.from_bytes(digest, "big") * w % n, g), multiply(r * w % n, (x, y)))
	return point is not None and point[0] % n == r


async def run_sasl_ecdsa(client, variant):
	"""Shared by the sasl-ecdsa scenarios: offers sasl=PLAIN,ECDSA-NIST256P-CHALLENGE
	and runs Atheme's side of it for the account "ecdsauser", whose registered key is the
	one in ~/ecdsa/k.pem (import it in Textual, set username=ecdsauser). "wrongkey": the
	account has another key, so the signature fails with 904 and PLAIN must follow."""
	import base64

	username = "ecdsauser"
	registered_key = base64.b64decode("A2D+1LolWp0xyWHrdMY1bWjASbiSO2H6bOZpYi5g8p+2")
	if variant == "wrongkey":
		registered_key = base64.b64decode("A2sX0fLhLEJH+Lzm5WOkQPJ3A32BLeszoPShOUXYmMKW")  # the generator
	nickname = "*"
	state = "start"
	challenge = b""
	outcome = []

	while True:
		line = await client.read_line()
		if line is None:
			break

		command, _, rest = line.partition(" ")
		command = command.upper()

		if command == "CAP" and rest.upper().startswith("LS"):
			await client.send(f":{SERVER} CAP * LS :sasl=PLAIN,ECDSA-NIST256P-CHALLENGE")
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

			if state == "start":
				outcome.append(f"mechanism {data}")
				await client.send("AUTHENTICATE +")
				state = "plain" if data == "PLAIN" else "account"
			elif state == "account":
				account = base64.b64decode(data).decode()
				outcome.append(f"account {account}")
				challenge = os.urandom(32)
				await client.send(f"AUTHENTICATE {base64.b64encode(challenge).decode()}")
				state = "signature"
			elif state == "signature":
				valid = p256_verify(registered_key, challenge, base64.b64decode(data))
				outcome.append(f"signature {'valid' if valid else 'invalid'}")
				if valid:
					await client.send(f":{SERVER} 900 {nickname} {nickname}!u@h {username} :You are now logged in as {username}")
					await client.send(f":{SERVER} 903 {nickname} :SASL authentication successful")
				else:
					await client.send(f":{SERVER} 904 {nickname} :SASL authentication failed")
				state = "start"
			elif state == "plain":
				fields = base64.b64decode(data).split(b"\0")
				outcome.append(f"PLAIN as {fields[1].decode()}")
				await client.send(f":{SERVER} 900 {nickname} {nickname}!u@h {username} :You are now logged in as {username}")
				await client.send(f":{SERVER} 903 {nickname} :SASL authentication successful")
				state = "done"

	print(f"CHECK: {outcome}", flush=True)

	mechanism = "mechanism ECDSA-NIST256P-CHALLENGE"
	if variant == "wrongkey":
		result(outcome == [mechanism, f"account {username}", "signature invalid", "mechanism PLAIN", f"PLAIN as {username}", "CAP END"],
			"the signature from the wrong key failed with 904 and the client logged in with PLAIN next")
	else:
		result(outcome == [mechanism, f"account {username}", "signature valid", "CAP END"],
			"ECDSA-NIST256P-CHALLENGE first: the account name, then a signature the registered key verifies")

	if "CAP END" in outcome:
		await client.welcome()
		await client.collect(30)


async def scenario_sasl_ecdsa(client):
	"""ECDSA-NIST256P-CHALLENGE (import ~/ecdsa/k.pem as the login key, set
	username=ecdsauser): tried before PLAIN, account name then a valid signature."""
	await run_sasl_ecdsa(client, "ok")


async def scenario_sasl_ecdsa_wrongkey(client):
	"""The account has another key: 904, then PLAIN (set a nicknamePassword too)."""
	await run_sasl_ecdsa(client, "wrongkey")


async def scenario_sasl_scram(client):
	"""SCRAM-SHA-512 (set username=scramuser nicknamePassword=textual-scram):
	the server-first is longer than 400 characters (reassembly), the proof must
	be valid, the client must check the server signature and send the final +."""
	await run_sasl_scram(client, "ok")


async def scenario_sasl_scram_fallback(client):
	"""SCRAM-SHA-512 fails with 904 (an account without SCRAM credentials): the
	client must try PLAIN next and log in with it."""
	await run_sasl_scram(client, "fallback")


async def scenario_sasl_scram_badsig_success(client):
	"""Wrong server signature; the client aborts, the server answers 903 anyway:
	the client must disconnect instead of counting itself logged in."""
	await run_sasl_scram(client, "badsig-success")


async def scenario_sasl_scram_noproof(client):
	"""The server answers the client-final with 903 and never proves it knows the
	password: the client must disconnect instead of finishing registration."""
	await run_sasl_scram(client, "noproof")


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


async def scenario_event_playback(client):
	"""draft/event-playback and draft/pre-away (E4 9.19). Connection 1: #ch with
	gina, bob, dave and erin, line 1 (msgid m1); say "drop" (after /away, to
	test pre-away) and the server drops the connection. Connection 2: AWAY before
	CAP END is noted; the CHATHISTORY batch holds line 1 again, an event from
	before the drop, the client's own JOIN, events from the gap (carol joins, bob
	parts, dave quits, erin is now erin2, the topic, +o, a kick), line 2 (missed)
	and an event after the request. Only the gap's events and line 2 must show;
	the member list stays NAMES' (no carol). Runs for five minutes."""
	pass


async def scenario_network_icon(client):
	"""Network icon (9.19 E): the welcome names draft/ICON (Ergo's GitHub picture,
	with {size}). Say "other" anywhere for a 005 naming another icon (IRCv3's),
	"plain" for one with an http:// address (ignored, the icon stays). Connect to
	a scenario without an icon (e.g. bots) to see it removed. Stays connected."""
	client.isupport_extra = "draft/ICON=https://github.com/ergochat.png?size={size}"

	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	await client.send(f":{me}!user@client.textual.test JOIN #icons")
	await client.send(f":{SERVER} 353 {me} = #icons :{me} alice")
	await client.send(f":{SERVER} 366 {me} #icons :End of /NAMES list.")

	seen = 0

	while await client.collect(1):
		for line in client.received[seen:]:
			command, _, rest = line.partition(" ")
			if command.upper() != "PRIVMSG":
				continue
			if rest.endswith(" :other"):
				await client.send(f":{SERVER} 005 {me} draft/ICON=https://github.com/ircv3.png?size={{size}} :are supported by this server")
			elif rest.endswith(" :plain"):
				await client.send(f":{SERVER} 005 {me} draft/ICON=http://example.com/icon.png :are supported by this server")
		seen = len(client.received)


async def scenario_websocket(client):
	"""WebSocket (9.14), on ws://127.0.0.1:<port>: the path picks the subprotocol
	(any: the client's first choice; /text: text.ircv3.net; /none: none;
	/missing: HTTP 404). #ws with alice. Say "latin" for a line in Latin-1
	(binary only), "close" for a close frame. Each connection ends with a RESULT
	line: messages in the agreed frame type, none with a line ending. Runs until
	stopped."""
	pass


async def scenario_sasl_new(client):
	"""SASL 3.2 (set nicknamePassword=textual-new first): registration without
	sasl; two seconds later the server sends CAP NEW :sasl=PLAIN. The client
	must request it and log in with PLAIN (AUTHENTICATE after registration).
	Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	await client.collect(2)
	await client.send(f":{SERVER} CAP {me} NEW :sasl=PLAIN,EXTERNAL")

	authenticated = False
	seen = 0

	while await client.collect(1):
		for line in client.received[seen:]:
			command, _, rest = line.partition(" ")
			command = command.upper()
			if command == "CAP" and rest.upper().startswith("REQ"):
				await client.send(f":{SERVER} CAP {me} ACK :{rest.split(' ', 1)[1].lstrip(':')}")
			elif command == "AUTHENTICATE" and rest == "PLAIN":
				await client.send("AUTHENTICATE +")
			elif command == "AUTHENTICATE" and rest not in ("PLAIN", "*", "+"):
				import base64
				try:
					parts = base64.b64decode(rest).split(b"\0")
				except Exception:
					parts = []
				ok = len(parts) == 3 and parts[2] == b"textual-new"
				result(ok, f"PLAIN after registration with {parts[1:2]!r}")
				if ok:
					await client.send(f":{SERVER} 900 {me} {me}!user@client.textual.test {parts[1].decode()} :You are now logged in as {parts[1].decode()}")
					await client.send(f":{SERVER} 903 {me} :SASL authentication successful")
					authenticated = True
				else:
					await client.send(f":{SERVER} 904 {me} :SASL authentication failed")
		seen = len(client.received)


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


async def scenario_whox(client):
	"""WHOX: the server advertises WHOX; after Textual joins #wx it must send
	"WHO #wx %tcuhnfar,152" within a few seconds (no plain WHO). The 354 answer
	makes bob away (G) with the real name "Bob from WHOX" and the account
	bobsaccount, and carl here without an account."""
	nick = client.nickname
	await client.send(f":{SERVER} 005 {nick} WHOX :are supported by this server")
	await client.send(f":{nick}!user@client.textual.test JOIN #wx")
	await client.send(f":{SERVER} 353 {nick} = #wx :@{nick} bob carl")
	await client.send(f":{SERVER} 366 {nick} #wx :End of /NAMES list.")

	requested = None
	end = time.monotonic() + 20
	while time.monotonic() < end and requested is None:
		try:
			line = await asyncio.wait_for(client.read_line(), 1)
		except asyncio.TimeoutError:
			continue
		if line is None:
			break
		if line.upper().startswith("PING"):
			await client.send(f":{SERVER} PONG {SERVER} {line[5:]}")
		elif line.upper().startswith("WHO "):
			requested = line

	if requested == "WHO #wx %tcuhnfar,152":
		await client.send(f":{SERVER} 354 {nick} 152 #wx ~bob friend.test bob G bobsaccount :Bob from WHOX")
		await client.send(f":{SERVER} 354 {nick} 152 #wx ~carl friend.test carl H 0 :Carl from WHOX")
		await client.send(f":{SERVER} 354 {nick} 152 #wx ~u client.textual.test {nick} H@ 0 :Textual User")
		await client.send(f":{SERVER} 315 {nick} #wx :End of /WHO list.")

	result(requested == "WHO #wx %tcuhnfar,152", f"request after the join: {requested!r}")
	await client.collect(120)


async def scenario_styles(client):
	"""A showcase of every kind of line for checking the styles: #styles gets yesterday's
	lines (a date change, through server-time), then messages from several people, a
	mention of you, formatting and colours, an action, notices, joins, parts, quits,
	nickname, mode and topic changes, a kick, a long line, links and an image link
	(turn on inline media to see it), and alice sends you a private message. In the Chat
	display, alice's, dave_'s and eve's lines close together share one name. Type a few
	lines of your own too. Stays connected (Ctrl-C to stop)."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#styles"

	def at(minutes_ago):
		stamp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=minutes_ago)
		return "@time=" + stamp.strftime("%Y-%m-%dT%H:%M:%S.000Z") + " "

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 332 {me} {channel} :Style showcase \x02bold\x02 \x034red\x03 and a link https://www.textualapp.com")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice +bob carl dave_ eve")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	lines = [
		(1500, ":alice!a@alice.test PRIVMSG #styles :This line is from yesterday (date change below)"),
		(1440, ":bob!b@bob.test PRIVMSG #styles :Still yesterday"),
		(30, ":alice!a@alice.test PRIVMSG #styles :Good morning, everyone"),
		(29, ":alice!a@alice.test PRIVMSG #styles :A second line from alice right after the first"),
		(28, ":bob!b@bob.test PRIVMSG #styles :Morning! Different nicknames get different colours"),
		(27, f":carl!c@carl.test PRIVMSG #styles :{me}: this line mentions you and should be a highlight"),
		(26, ":dave_!d@dave.test PRIVMSG #styles :\x02bold\x02 \x1ditalic\x1d \x1funderline\x1f \x1estrikethrough\x1e \x11monospace\x11 \x16reverse\x16 \x0fplain"),
		(25, ":dave_!d@dave.test PRIVMSG #styles :\x034red \x033green \x0312blue \x038,1yellow on black\x03 \x0400FF88hex colour\x0f done"),
		(25, ":dave_!d@dave.test PRIVMSG #styles :Palette: " + " ".join(f"\x03{n:02d}{n}\x03" for n in range(16))),
		(24, ":eve!e@eve.test PRIVMSG #styles :\x01ACTION waves at the channel\x01"),
		(23, ":ChanServ!services@services.textual.test NOTICE #styles :A notice to the channel"),
		(22, ":frank!f@frank.test JOIN #styles"),
		(21, ":frank!f@frank.test PART #styles :Leaving with a reason"),
		(20, ":grace!g@grace.test JOIN #styles"),
		(19, ":grace!g@grace.test QUIT :Quit: see you later"),
		(18, ":bob!b@bob.test NICK :robert"),
		(17, ":alice!a@alice.test MODE #styles +v carl"),
		(16, ":alice!a@alice.test MODE #styles +b *!*@spam.test"),
		(15, ":alice!a@alice.test TOPIC #styles :A new topic with \x1ditalics\x1d"),
		(14, ":heidi!h@heidi.test JOIN #styles"),
		(13, ":alice!a@alice.test KICK #styles heidi :Kicked with a reason"),
		(12, ":carl!c@carl.test PRIVMSG #styles :" + " ".join(["A long line that has to wrap across several rows of the chat view to show how the style handles it."] * 4)),
		(11, ":robert!b@bob.test PRIVMSG #styles :Links: https://www.textualapp.com and #styles and ircs://irc.libera.chat/#textual"),
		(10, ":eve!e@eve.test PRIVMSG #styles :An image link: https://www.textualapp.com/textual-light.jpg"),
		(9, ":eve!e@eve.test PRIVMSG #styles :Emoji and other scripts: 🎉 ✓ 日本語 русский العربية"),
		(3, ":eve!e@eve.test PRIVMSG #styles :Six minutes after my last line, so the Chat display shows my name again"),
	]

	for minutes_ago, line in lines:
		await client.send(at(minutes_ago) + line)

	await client.send(f":alice!a@alice.test PRIVMSG {me} :A private message from alice")
	await client.send(f":alice!a@alice.test NOTICE {me} :A private notice from alice")

	while await client.collect(3600):
		pass


async def scenario_collapse(client):
	"""Joins, parts, quits and nickname changes for checking how runs of them collapse:
	#collapse gets a few minutes of lines first (two runs, a single join, a kick between
	events), then live events every two seconds that join the run at the bottom, a
	message, and a run that ends the scenario. Stays connected (Ctrl-C to stop)."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#collapse"

	def at(minutes_ago):
		stamp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=minutes_ago)
		return "@time=" + stamp.strftime("%Y-%m-%dT%H:%M:%S.000Z") + " "

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	lines = [
		(10, ":alice!a@alice.test PRIVMSG #collapse :Three joins and a quit follow: one summary line"),
		(9, ":carl!c@carl.test JOIN #collapse"),
		(9, ":dave!d@dave.test JOIN #collapse"),
		(9, ":erin!e@erin.test JOIN #collapse"),
		(8, ":carl!c@carl.test QUIT :Quit: bye"),
		(7, ":bob!b@bob.test PRIVMSG #collapse :A single join follows: shown as it is"),
		(7, ":frank!f@frank.test JOIN #collapse"),
		(6, ":alice!a@alice.test PRIVMSG #collapse :A nickname change, a part and a join, then a kick between two joins"),
		(6, ":dave!d@dave.test NICK :david"),
		(6, ":erin!e@erin.test PART #collapse :Leaving"),
		(5, ":gina!g@gina.test JOIN #collapse"),
		(5, ":hank!h@hank.test JOIN #collapse"),
		(5, ":alice!a@alice.test KICK #collapse hank :No"),
		(5, ":ivan!i@ivan.test JOIN #collapse"),
		(5, ":bob!b@bob.test PRIVMSG #collapse :A join and a nickname change: named, as up to three events are"),
		(5, ":olga!o@olga.test JOIN #collapse"),
		(5, ":olga!o@olga.test NICK :olga_"),
		(4, ":bob!b@bob.test PRIVMSG #collapse :Live events follow every two seconds"),
	]

	for minutes_ago, line in lines:
		await client.send(at(minutes_ago) + line)

	live = [
		":jane!j@jane.test JOIN #collapse",
		":kyle!k@kyle.test JOIN #collapse",
		":jane!j@jane.test QUIT :Ping timeout",
		":kyle!k@kyle.test NICK :kyle_",
		":alice!a@alice.test PRIVMSG #collapse :A message ends that run",
		":lena!l@lena.test JOIN #collapse",
		":mike!m@mike.test JOIN #collapse",
		":nora!n@nora.test JOIN #collapse",
	]

	for line in live:
		await asyncio.sleep(2)
		await client.send(line)

	while await client.collect(3600):
		pass


async def scenario_query_info(client):
	"""Private messages show the channels you share in their topic bar:
	you are in #one and #two; alice (in both) and bob (in neither) message you.
	Then, ten seconds apart: alice leaves #two (struck through), bob joins #one,
	alice comes back to #two, changes nickname to alicia, and quits (all
	struck through). A query you open yourself (/query dave) has the bar too.
	Stays connected (Ctrl-C to stop)."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	for channel, members in (("#one", f"{me} @alice dave"), ("#two", f"{me} alice carol")):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{members}")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	await client.collect(2)

	await client.send(f":alice!a@alice.test PRIVMSG {me} :Hi, we share two channels")
	await client.send(f":bob!b@bob.test PRIVMSG {me} :Hello from someone you share no channels with")

	# Then, ten seconds apart, the bars follow along
	changes = [
		":alice!a@alice.test PART #two :brb",  # alice: #two struck through
		":bob!b@bob.test JOIN #one",  # bob: #one
		":alice!a@alice.test JOIN #two",  # alice: #two back
		":alice!a@alice.test NICK :alicia",  # the query becomes alicia, the bar stays
		":alicia!a@alice.test QUIT :Quit: bye",  # alicia: both struck through
	]

	for line in changes:
		await asyncio.sleep(10)
		await client.send(line)

	while await client.collect(3600):
		pass


async def scenario_media(client):
	"""Real links for inline media (turn previews on; the VM needs internet):
	#media gets a JPEG, a PNG, a WebP, an image behind a redirect, a plain-HTTP
	image (never previewed), an MP4 video (first frame until played), an Imgur
	clip (plays like a GIF), an xkcd comic, and cards for YouTube, Vimeo,
	Dailymotion and X. Stays connected (Ctrl-C to stop)."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#media"

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	links = [
		("alice", "JPEG: https://www.textualapp.com/textual-light.jpg"),
		("bob", "PNG with transparency: https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png"),
		("alice", "WebP: https://www.gstatic.com/webp/gallery/1.webp"),
		("bob", "Behind a redirect: https://picsum.photos/600/400.jpg"),
		("alice", "Plain HTTP, never previewed: http://www.gstatic.com/webp/gallery/2.webp"),
		("bob", "Video, first frame until played: https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4"),
		("alice", "Clip, plays like a GIF: https://i.imgur.com/A61SaA1.gifv"),
		("bob", "xkcd: https://xkcd.com/927/"),
		("alice", "YouTube: https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
		("bob", "YouTube short link with a start time: https://youtu.be/jNQXAC9IVRw?t=5"),
		("alice", "Vimeo: https://vimeo.com/76979871"),
		("bob", "Dailymotion: https://www.dailymotion.com/video/xbmufdm"),
		("alice", "X post: https://x.com/jack/status/20"),
		("bob", "Same on twitter.com: https://twitter.com/jack/status/20"),
	]

	for sender, text in links:
		await client.send(f":{sender}!{sender[0]}@{sender}.test PRIVMSG {channel} :{text}")
		await asyncio.sleep(0.5)

	while await client.collect(3600):
		pass


async def scenario_services(client):
	"""Preview cards for the services added in E2.3 (turn previews on; the VM
	needs internet): #services gets GitHub (repository, issue, pull request,
	commit), Reddit, Wikipedia (English, German, mobile), Bluesky, Spotify,
	SoundCloud, Bandcamp and Giphy links. Stays connected (Ctrl-C to stop)."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#services"

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	links = [
		("alice", "GitHub repository: https://github.com/Codeux-Software/Textual"),
		("bob", "GitHub issue: https://github.com/Codeux-Software/Textual/issues/1"),
		("alice", "GitHub pull request: https://github.com/apple/swift/pull/1"),
		("bob", "GitHub commit: https://github.com/torvalds/linux/commit/1da177e4c3f41524e886b7f1b8a0c1fc7321cac2"),
		("alice", "Reddit: https://www.reddit.com/r/IAmA/comments/z1c9z/i_am_barack_obama_president_of_the_united_states/"),
		("bob", "Wikipedia: https://en.wikipedia.org/wiki/Internet_Relay_Chat"),
		("alice", "Wikipedia in German, mobile site: https://de.m.wikipedia.org/wiki/Internet_Relay_Chat"),
		("bob", "Bluesky: https://bsky.app/profile/bsky.app/post/3l6oveex3ii2l"),
		("alice", "Spotify: https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT"),
		("bob", "SoundCloud: https://soundcloud.com/forss/flickermood"),
		("alice", "Bandcamp: https://radiohead.bandcamp.com/album/in-rainbows"),
		("bob", "Giphy: https://giphy.com/gifs/bentuber-3o7aCSPqXE5C6T8tBC"),
	]

	for sender, text in links:
		await client.send(f":{sender}!{sender[0]}@{sender}.test PRIVMSG {channel} :{text}")
		await asyncio.sleep(0.5)

	while await client.collect(3600):
		pass


async def scenario_pages(client):
	"""Web page cards and audio (E2.4; turn previews on; the VM needs
	internet): #pages gets pages with Open Graph tags, one with only a title,
	a GitHub page no GitHub card covers, an image link without an extension,
	MP3 and Ogg audio, a PDF and a plain HTTP page (both stay links). Stays
	connected (Ctrl-C to stop)."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#pages"

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	links = [
		("alice", "Open Graph page: https://developer.mozilla.org/en-US/docs/Web/HTML"),
		("bob", "Another: https://www.apple.com/macos/"),
		("alice", "Libera: https://libera.chat/"),
		("bob", "Only a title: https://example.com/"),
		("alice", "A GitHub page without its own card: https://github.com/features/actions"),
		("bob", "An image without an extension: https://picsum.photos/id/237/600/400"),
		("alice", "MP3: https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
		("bob", "Ogg: https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg"),
		("alice", "A PDF stays a link: https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"),
		("bob", "Plain HTTP stays a link: http://neverssl.com/"),
	]

	for sender, text in links:
		await client.send(f":{sender}!{sender[0]}@{sender}.test PRIVMSG {channel} :{text}")
		await asyncio.sleep(0.5)

	while await client.collect(3600):
		pass


async def scenario_previews(client):
	"""One of every kind of preview (turn previews on; the VM needs internet):
	#previews gets images, video, clips, audio, every service card, a web page
	card, a title-only page and links that stay links. Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#previews"

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	links = [
		("alice", "Image (JPEG): https://www.textualapp.com/textual-light.jpg"),
		("bob", "Image (PNG, transparent): https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png"),
		("alice", "Image (WebP): https://www.gstatic.com/webp/gallery/1.webp"),
		("bob", "Image without an extension: https://picsum.photos/id/237/600/400"),
		("alice", "Video (MP4): https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4"),
		("bob", "Clip (Imgur): https://i.imgur.com/A61SaA1.gifv"),
		("alice", "Clip (Giphy): https://giphy.com/gifs/bentuber-3o7aCSPqXE5C6T8tBC"),
		("bob", "Audio (MP3): https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
		("alice", "Audio (Ogg): https://upload.wikimedia.org/wikipedia/commons/c/c8/Example.ogg"),
		("bob", "xkcd: https://xkcd.com/927/"),
		("alice", "YouTube: https://www.youtube.com/watch?v=jNQXAC9IVRw"),
		("bob", "Vimeo: https://vimeo.com/76979871"),
		("alice", "Dailymotion: https://www.dailymotion.com/video/xbmufdm"),
		("bob", "X: https://x.com/jack/status/20"),
		("alice", "Bluesky: https://bsky.app/profile/bsky.app/post/3l6oveex3ii2l"),
		("bob", "Reddit: https://www.reddit.com/r/IAmA/comments/z1c9z/i_am_barack_obama_president_of_the_united_states/"),
		("alice", "GitHub repository: https://github.com/blendbyte/Textual"),
		("bob", "GitHub pull request: https://github.com/apple/swift/pull/1"),
		("alice", "Wikipedia: https://en.wikipedia.org/wiki/Internet_Relay_Chat"),
		("bob", "Spotify: https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT"),
		("alice", "SoundCloud: https://soundcloud.com/forss/flickermood"),
		("bob", "Bandcamp: https://radiohead.bandcamp.com/album/in-rainbows"),
		("alice", "Any web page: https://developer.mozilla.org/en-US/docs/Web/HTML"),
		("bob", "A page with only a title: https://example.com/"),
		("alice", "Stays a link (PDF): https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"),
		("bob", "Stays a link (plain HTTP): http://neverssl.com/"),
	]

	for sender, text in links:
		await client.send(f":{sender}!{sender[0]}@{sender}.test PRIVMSG {channel} :{text}")
		await asyncio.sleep(0.5)

	while await client.collect(3600):
		pass


async def scenario_previews_short(client):
	"""A few kinds of preview for comparing styles (turn previews on; the VM
	needs internet): an image, a clip, audio, xkcd, a video card and a page
	card in #previews. Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname
	channel = "#previews"

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")
	await client.collect(1)

	links = [
		("alice", "Image: https://picsum.photos/id/237/600/400"),
		("bob", "Audio: https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
		("alice", "xkcd: https://xkcd.com/927/"),
		("bob", "Video card: https://www.youtube.com/watch?v=jNQXAC9IVRw"),
		("alice", "Page card: https://en.wikipedia.org/wiki/Internet_Relay_Chat"),
	]

	for sender, text in links:
		await client.send(f":{sender}!{sender[0]}@{sender}.test PRIVMSG {channel} :{text}")
		await asyncio.sleep(0.5)

	while await client.collect(3600):
		pass


async def scenario_drafts(client):
	"""Drafts per channel (10.11): #one and #two, a private message from alice
	and typing notifications allowed (message-tags), so the log shows the
	client's +typing TAGMSGs (vm-dev scripted log). Stays connected."""
	if not await client.register_with_capabilities("server-time message-tags"):
		return

	me = client.nickname

	for channel in ("#one", "#two"):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	await client.collect(1)

	await client.send(f":alice!a@alice.test PRIVMSG {me} :hi, a private message")

	while await client.collect(3600):
		pass


async def scenario_mute(client):
	"""One-click mute (E3): #one and #two. Saying "go" anywhere makes the server
	wait 5 seconds (time to switch to another app), then bob talks in #one and
	#two, alice mentions the client in #one and carol sends a private message.
	Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	for channel in ("#one", "#two"):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob carol")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	round = 0
	seen = 0

	while await client.collect(1):
		said = [line for line in client.received[seen:] if line.upper().startswith("PRIVMSG ") and line.endswith(" :go")]
		seen = len(client.received)

		if not said:
			continue

		if not await client.collect(5):
			return

		seen = len(client.received)
		round += 1

		await client.send(f":bob!b@bob.test PRIVMSG #one :plain message {round} in #one")
		await client.send(f":bob!b@bob.test PRIVMSG #two :plain message {round} in #two")
		await client.send(f":alice!a@alice.test PRIVMSG #one :{me}: highlight {round} in #one")
		await client.send(f":carol!c@carol.test PRIVMSG {me} :private message {round} from carol")


async def scenario_sorting(client):
	"""Per-channel formatting and a channel list kept sorted (10.10): the server
	joins #zulu, #alpha and #mike in that order, coloured lines arrive in #alpha
	and #mike, and zoe and bob send private messages. Saying "go" anywhere:
	zoe becomes abby, the server joins #bravo, and #alpha, #mike and #bravo get
	another coloured line. Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	async def join(channel):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob zoe")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	def coloured(channel, round):
		return f":alice!a@alice.test PRIVMSG {channel} :\x02bold\x02 \x034red\x03 \x0312blue\x03 \x1ditalic\x1d line {round} in {channel}"

	for channel in ("#zulu", "#alpha", "#mike"):
		await join(channel)

	await client.collect(1)

	for channel in ("#alpha", "#mike"):
		await client.send(coloured(channel, 1))

	await client.send(f":zoe!z@zoe.test PRIVMSG {me} :hi from zoe")
	await client.send(f":bob!b@bob.test PRIVMSG {me} :hi from bob")

	round = 1
	seen = 0

	while await client.collect(1):
		said = [line for line in client.received[seen:] if line.upper().startswith("PRIVMSG ") and line.endswith(" :go")]
		seen = len(client.received)

		if not said:
			continue

		round += 1

		if round == 2:
			await client.send(":zoe!z@zoe.test NICK :abby")
			await join("#bravo")

		for channel in ("#alpha", "#mike", "#bravo"):
			await client.send(coloured(channel, round))


async def scenario_events(client):
	"""Event messages per kind (E1): #events with alice, bob, carol, dave and erin,
	away-notify on. Saying "go" anywhere sends one of each kind: joins, a part, a
	quit, a nickname change, two people away and back, a mode
	change, a topic change and a kick, then a message; "go" again repeats it
	(new joiners each time). Stays connected."""
	if not await client.register_with_capabilities("server-time away-notify"):
		return

	me = client.nickname
	channel = "#events"

	await client.send(f":{me}!user@client.textual.test JOIN {channel}")
	await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob carol dave erin")
	await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	round = 0
	seen = 0

	while await client.collect(1):
		said = [line for line in client.received[seen:] if line.upper().startswith("PRIVMSG ") and line.endswith(" :go")]
		seen = len(client.received)

		if not said:
			continue

		round += 1

		for line in [
			f":frank{round}!f@frank.test JOIN {channel}",
			f":gina{round}!g@gina.test JOIN {channel}",
			f":carol!c@carol.test PART {channel} :bye",
			f":dave!d@dave.test QUIT :gone",
			f":erin!e@erin.test NICK :erin{round}",
			f":alice!a@alice.test AWAY :lunch",
			f":bob!b@bob.test AWAY :brb",
			f":alice!a@alice.test AWAY",
			f":alice!a@alice.test MODE {channel} +v frank{round}",
			f":alice!a@alice.test TOPIC {channel} :Topic number {round}",
			f":alice!a@alice.test KICK {channel} gina{round} :out",
			f":alice!a@alice.test PRIVMSG {channel} :a real message, round {round}",
			f":bob!b@bob.test AWAY",
			f":carol!c@carol.test JOIN {channel}",
			f":dave!d@dave.test JOIN {channel}",
		]:
			await client.send(line)


async def scenario_labels(client):
	"""labeled-response (9.17): #one and #two, batch and labeled-response offered.
	Labeled commands are answered 3 seconds late, so the window can be changed
	in between: WHOIS (a labeled batch), WHO and NAMES (batches, the old Hidden
	Responses), VERSION (one labeled line), JOIN (at once: the join and its
	NAMES list, which aren't printed raw), anything else ACK. Stays connected."""
	if not await client.register_with_capabilities("batch labeled-response server-time"):
		return

	me = client.nickname

	for channel in ("#one", "#two"):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	batches = 0

	async def answer(label, lines, delay):
		nonlocal batches
		await asyncio.sleep(delay)
		if len(lines) == 1:
			await client.send(f"@label={label} {lines[0]}")
			return
		batches += 1
		token = f"lr{batches}"
		await client.send(f"@label={label} :{SERVER} BATCH +{token} labeled-response")
		for line in lines:
			await client.send(f"@batch={token} {line}")
		await client.send(f":{SERVER} BATCH -{token}")

	seen = 0

	while await client.collect(0.5):
		for line in client.received[seen:]:
			if not line.startswith("@"):
				continue
			tags, _, rest = line.partition(" ")
			label = dict(tag.split("=", 1) for tag in tags[1:].split(";") if "=" in tag).get("label")
			if not label:
				continue
			command, _, params = rest.partition(" ")
			command = command.upper()
			target = params.split(" ")[0].lstrip(":")

			if command == "WHOIS":
				lines = [f":{SERVER} 311 {me} {target} {target[0]} {target}.test * :{target.capitalize()} Example",
						 f":{SERVER} 312 {me} {target} {SERVER} :Scripted test server",
						 f":{SERVER} 318 {me} {target} :End of /WHOIS list."]
				asyncio.create_task(answer(label, lines, 3))
			elif command == "WHO":
				lines = [f":{SERVER} 352 {me} {target} a alice.test {SERVER} alice H@ :0 Alice",
						 f":{SERVER} 352 {me} {target} b bob.test {SERVER} bob H :0 Bob",
						 f":{SERVER} 315 {me} {target} :End of /WHO list."]
				asyncio.create_task(answer(label, lines, 3))
			elif command == "NAMES":
				lines = [f":{SERVER} 353 {me} = {target} :{me} @alice bob",
						 f":{SERVER} 366 {me} {target} :End of /NAMES list."]
				asyncio.create_task(answer(label, lines, 3))
			elif command == "VERSION":
				asyncio.create_task(answer(label, [f":{SERVER} 351 {me} scripted-1.0 {SERVER} :Scripted test server"], 3))
			elif command == "JOIN":
				lines = [f":{me}!user@client.textual.test JOIN {target}",
						 f":{SERVER} 353 {me} = {target} :{me} carol",
						 f":{SERVER} 366 {me} {target} :End of /NAMES list."]
				asyncio.create_task(answer(label, lines, 0))
			else:
				asyncio.create_task(answer(label, [f":{SERVER} ACK"], 0))
		seen = len(client.received)


async def scenario_multiline(client):
	"""draft/multiline (9.16): #one and #two with batch, labeled-response,
	echo-message and draft/multiline (max-bytes=4096, max-lines=10) offered.
	The client's multiline batches are echoed as batches; alice sends a
	multi-line message with a joined piece. "go" in #one repeats alice's.
	Stays connected."""
	if not await client.register_with_capabilities("batch echo-message server-time draft/multiline=max-bytes=4096,max-lines=10"):
		return

	me = client.nickname

	for channel in ("#one", "#two"):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	count = 0

	async def alice_multiline():
		nonlocal count
		count += 1
		await client.send(f"@msgid=alice{count} :alice!a@alice.test BATCH +a{count} draft/multiline #one")
		await client.send(f"@batch=a{count} :alice!a@alice.test PRIVMSG #one :Here is a list:")
		await client.send(f"@batch=a{count} :alice!a@alice.test PRIVMSG #one :- first item")
		await client.send(f"@batch=a{count} :alice!a@alice.test PRIVMSG #one :- second item, which is long and ")
		await client.send(f"@batch=a{count};draft/multiline-concat :alice!a@alice.test PRIVMSG #one :continues on the same line")
		await client.send(f"@batch=a{count} :alice!a@alice.test PRIVMSG #one :")
		await client.send(f"@batch=a{count} :alice!a@alice.test PRIVMSG #one :That's all, {me}.")
		await client.send(f":alice!a@alice.test BATCH -a{count}")

	await client.collect(1)
	await alice_multiline()

	open_batches = {}
	seen = 0

	while await client.collect(0.5):
		for line in client.received[seen:]:
			tags = ""
			rest = line
			if line.startswith("@"):
				tags, _, rest = line.partition(" ")
			parts = rest.split(" ")
			command = parts[0].upper() if parts else ""
			tagdict = dict((t.split("=", 1) + [""])[:2] for t in tags[1:].split(";")) if tags else {}

			if command == "BATCH" and parts[1].startswith("+") and len(parts) > 3 and parts[2] == "draft/multiline":
				open_batches[parts[1][1:]] = {"target": parts[3], "lines": [], "label": tagdict.get("label")}
			elif command == "BATCH" and parts[1].startswith("-"):
				batch = open_batches.pop(parts[1][1:], None)
				if batch:
					count += 1
					label = f"label={batch['label']};" if batch["label"] else ""
					await client.send(f"@{label}msgid=me{count} :{me}!user@client.textual.test BATCH +e{count} draft/multiline {batch['target']}")
					for btags, bline in batch["lines"]:
						await client.send(f"@batch=e{count}{btags} :{me}!user@client.textual.test {bline}")
					await client.send(f":{SERVER} BATCH -e{count}")
			elif "batch" in tagdict and tagdict["batch"] in open_batches:
				concat = ";draft/multiline-concat" if "draft/multiline-concat" in tagdict else ""
				open_batches[tagdict["batch"]]["lines"].append((concat, rest))
			elif command == "PRIVMSG" and rest.endswith(" :go"):
				await alice_multiline()
			elif command in ("PRIVMSG", "NOTICE"):
				await client.send(f":{me}!user@client.textual.test {rest}")
		seen = len(client.received)


async def scenario_bots(client):
	"""Bot mode, netsplit/netjoin and channel-context (9.19 B): BOT=B, message-tags
	and batch. #one with helpbot (a bot: WHO flag B, bot tag), alice and 6 others.
	"go" anywhere: helpbot talks in #one (bot tag) and answers privately with
	+channel-context=#one; a stranger not in #one sends a private message claiming
	#one (shown as a query); a netsplit batch takes 6 people, a netjoin brings 4
	back. Stays connected."""
	if not await client.register_with_capabilities("batch message-tags server-time"):
		return

	me = client.nickname
	others = ["user1", "user2", "user3", "user4", "user5", "user6"]

	await client.send(f":{SERVER} 005 {me} BOT=B WHOX EXTBAN=$,ARar ACCOUNTEXTBAN=R :are supported by this server")
	await client.send(f":{me}!user@client.textual.test JOIN #one")
	await client.send(f":{SERVER} 353 {me} = #one :{me} @alice helpbot " + " ".join(others))
	await client.send(f":{SERVER} 366 {me} #one :End of /NAMES list.")

	seen = 0

	while await client.collect(1):
		for line in client.received[seen:]:
			command, _, rest = line.partition(" ")
			if command.upper() == "WHO" and rest.startswith("#one"):
				token = "0"
				if "%" in rest and "," in rest:
					token = rest.rsplit(",", 1)[1]
				for nick, flags, account in [("alice", "H@", "alice"), ("helpbot", "HB", "helpbot")] + [(o, "H", "0") for o in others] + [(me, "H", "0")]:
					await client.send(f":{SERVER} 354 {me} {token} #one {nick} {nick}.test {nick} {flags} {account} :{nick.capitalize()}")
				await client.send(f":{SERVER} 315 {me} #one :End of /WHO list.")
			elif command.upper() == "PRIVMSG" and rest.endswith(" :go"):
				await client.send(f"@bot :helpbot!h@helpbot.test PRIVMSG #one :Type !help for the list of commands.")
				await client.send(f"@bot;+channel-context=#one :helpbot!h@helpbot.test NOTICE {me} :Commands: !help, !rules, !seen <nick>")
				await client.send(f"@+channel-context=#one :stranger!s@stranger.test PRIVMSG {me} :I am not in #one but say I am")
				await client.send(f":{SERVER} BATCH +ns1 netsplit irc1.test irc2.test")
				for o in others:
					await client.send(f"@batch=ns1 :{o}!{o[0]}@{o}.test QUIT :irc1.test irc2.test")
				await client.send(f":{SERVER} BATCH -ns1")
				await asyncio.sleep(2)
				await client.send(f":{SERVER} BATCH +nj1 netjoin irc1.test irc2.test")
				for o in others[:4]:
					await client.send(f"@batch=nj1 :{o}!{o[0]}@{o}.test JOIN #one")
				await client.send(f":{SERVER} BATCH -nj1")
		seen = len(client.received)


async def scenario_register(client):
	"""Account registration (9.19 D): draft/account-registration with
	email-required and custom-account-name, standard-replies. REGISTER for
	"alice" fails (ACCOUNT_EXISTS); any other account needs verification: VERIFY
	with code 123456 succeeds and logs in (900), any other code fails
	(INVALID_CODE). Stays connected."""
	if not await client.register_with_capabilities("draft/account-registration=email-required,custom-account-name standard-replies"):
		return

	me = client.nickname
	seen = 0

	while await client.collect(1):
		for line in client.received[seen:]:
			command, _, rest = line.partition(" ")
			params = rest.split(" ")
			if command.upper() == "REGISTER" and len(params) >= 3:
				account = me if params[0] == "*" else params[0]
				if account.lower() == "alice":
					await client.send(f":{SERVER} FAIL REGISTER ACCOUNT_EXISTS {account} :Account already exists")
				else:
					await client.send(f":{SERVER} REGISTER VERIFICATION_REQUIRED {account} :Account created, pending verification; a code was sent to {params[1]}")
			elif command.upper() == "VERIFY" and len(params) >= 2:
				account, code = params[0], params[1].lstrip(":")
				if code == "123456":
					await client.send(f":{SERVER} VERIFY SUCCESS {account} :Account successfully registered")
					await client.send(f":{SERVER} 900 {me} {me}!user@client.textual.test {account} :You are now logged in as {account}")
				else:
					await client.send(f":{SERVER} FAIL VERIFY INVALID_CODE {account} :Invalid verification code")
		seen = len(client.received)


async def scenario_keywords(client):
	"""Highlight keyword limits (E3): #one and #two. Saying "go" anywhere makes
	the server wait 5 seconds (time to switch to another app), then send lines
	for keywords limited to a server, a channel and a person: "deploy" (whole
	server), "deploybot" (excluded), "release" (#one only), "build" (alice
	only). Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	for channel in ("#one", "#two"):
		await client.send(f":{me}!user@client.textual.test JOIN {channel}")
		await client.send(f":{SERVER} 353 {me} = {channel} :{me} @alice bob")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	round = 0
	seen = 0

	while await client.collect(1):
		said = [line for line in client.received[seen:] if line.upper().startswith("PRIVMSG ") and line.endswith(" :go")]
		seen = len(client.received)

		if not said:
			continue

		if not await client.collect(5):
			return

		seen = len(client.received)
		round += 1

		await client.send(f":bob!b@bob.test PRIVMSG #one :{round}: the deploy is done (highlight)")
		await client.send(f":bob!b@bob.test PRIVMSG #one :{round}: deploybot restarted (no highlight)")
		await client.send(f":bob!b@bob.test PRIVMSG #two :{round}: release notes are out (no highlight)")
		await client.send(f":bob!b@bob.test PRIVMSG #one :{round}: release is tagged (highlight)")
		await client.send(f":alice!a@alice.test PRIVMSG #one :{round}: build failed (highlight, own sound)")
		await client.send(f":bob!b@bob.test PRIVMSG #one :{round}: build passed (no highlight)")


async def scenario_mass(client):
	"""Mass highlights (E3, 10.14): #one with alice, bob, carol, dave, eve and
	frank. Saying "go" anywhere makes the server wait 5 seconds (time to switch
	to another app), then send a line naming the client and 3 others (a
	highlight), one naming the client and 4 others (5 people: not a highlight)
	and a plain mention. Stays connected."""
	if not await client.register_with_capabilities("server-time"):
		return

	me = client.nickname

	await client.send(f":{me}!user@client.textual.test JOIN #one")
	await client.send(f":{SERVER} 353 {me} = #one :{me} @alice bob carol dave eve frank")
	await client.send(f":{SERVER} 366 {me} #one :End of /NAMES list.")

	round = 0
	seen = 0

	while await client.collect(1):
		said = [line for line in client.received[seen:] if line.upper().startswith("PRIVMSG ") and line.endswith(" :go")]
		seen = len(client.received)

		if not said:
			continue

		if not await client.collect(5):
			return

		seen = len(client.received)
		round += 1

		await client.send(f":alice!a@alice.test PRIVMSG #one :{round}: {me}, bob, carol, dave: lunch? (4 people: highlight)")
		await client.send(f":frank!f@frank.test PRIVMSG #one :{round}: {me} bob carol dave eve free coins at example.test (5 people: no highlight)")
		await client.send(f":bob!b@bob.test PRIVMSG #one :{round}: {me}: are you there? (highlight)")


async def scenario_accounts(client):
	"""Account markers (10.2): account-notify, extended-join and WHOX. #acc: the
	WHOX answer has alice and carl logged in, bob and dave not. #noinfo: its
	WHO is never answered, so nothing is known there. Saying "go" anywhere:
	bob logs in, carl logs out, eve joins logged in and frank joins logged out
	(extended-join). "go2": grace joins logged in; "go3": henry (logged in) and ivy (not)
	join one after the other. Stays connected."""
	if not await client.register_with_capabilities("account-notify extended-join server-time"):
		return

	me = client.nickname

	await client.send(f":{SERVER} 005 {me} WHOX :are supported by this server")

	for channel, names in (("#acc", f"@{me} alice bob carl dave"), ("#noinfo", f"@{me} alice bob")):
		await client.send(f":{me}!user@client.textual.test JOIN {channel} * :Textual User")
		await client.send(f":{SERVER} 353 {me} = {channel} :{names}")
		await client.send(f":{SERVER} 366 {me} {channel} :End of /NAMES list.")

	accounts = {"alice": "alice", "bob": "0", "carl": "carl", "dave": "0"}

	seen = 0

	while await client.collect(1):
		lines = client.received[seen:]
		seen = len(client.received)

		for line in lines:
			if line.upper().startswith("WHO #ACC"):
				for nick, account in accounts.items():
					await client.send(f":{SERVER} 354 {me} 152 #acc ~{nick} {nick}.test {nick} H {account} :{nick.capitalize()}")
				await client.send(f":{SERVER} 354 {me} 152 #acc ~u client.textual.test {me} H@ 0 :Textual User")
				await client.send(f":{SERVER} 315 {me} #acc :End of /WHO list.")

			if line.upper().startswith("PRIVMSG ") and line.endswith(" :go"):
				accounts.update({"bob": "bob", "carl": "0", "eve": "eve", "frank": "0"})

				await client.send(":bob!~bob@bob.test ACCOUNT bob")
				await client.send(":carl!~carl@carl.test ACCOUNT *")
				await client.send(":eve!~eve@eve.test JOIN #acc eve :Eve")
				await client.send(":frank!~frank@frank.test JOIN #acc * :Frank")

			if line.upper().startswith("PRIVMSG ") and line.endswith(" :go2"):
				accounts.update({"grace": "grace"})

				await client.send(":grace!~grace@grace.test JOIN #acc grace :Grace")

			if line.upper().startswith("PRIVMSG ") and line.endswith(" :go3"):
				accounts.update({"henry": "henry", "ivy": "0"})

				await client.send(":henry!~henry@henry.test JOIN #acc henry :Henry")
				await client.send(":ivy!~ivy@ivy.test JOIN #acc * :Ivy")


async def scenario_legacy_accounts(client):
	"""Account markers on a legacy network (10.2), like QuakeNet: WHOX but no
	IRCv3 capabilities. #legacy: the WHOX answer has alice and carl logged in,
	bob not. Saying "go" anywhere: bob logs in (nothing tells the client) and
	dave joins (a plain JOIN, account unknown); both show at the next WHO,
	which Textual sends every 2 minutes. Stays connected."""
	if not await client.register_with_capabilities(""):
		return

	me = client.nickname

	await client.send(f":{SERVER} 005 {me} WHOX :are supported by this server")

	await client.send(f":{me}!user@client.textual.test JOIN #legacy")
	await client.send(f":{SERVER} 353 {me} = #legacy :@{me} alice bob carl")
	await client.send(f":{SERVER} 366 {me} #legacy :End of /NAMES list.")

	accounts = {"alice": "alice", "bob": "0", "carl": "carl"}

	seen = 0

	while await client.collect(1):
		lines = client.received[seen:]
		seen = len(client.received)

		for line in lines:
			if line.upper().startswith("WHO #LEGACY"):
				for nick, account in accounts.items():
					await client.send(f":{SERVER} 354 {me} 152 #legacy ~{nick} {nick}.test {nick} H {account} :{nick.capitalize()}")
				await client.send(f":{SERVER} 354 {me} 152 #legacy ~u client.textual.test {me} H@ 0 :Textual User")
				await client.send(f":{SERVER} 315 {me} #legacy :End of /WHO list.")

			if line.upper().startswith("PRIVMSG ") and line.endswith(" :go"):
				accounts.update({"bob": "bob", "dave": "0"})

				await client.send(":dave!~dave@dave.test JOIN #legacy")


async def scenario_silent(client):
	"""Accept the connection and never answer (not even a TLS handshake): connect
	with ircs:// or irc:// and Textual Dev must give up after 30 seconds."""
	pass


SCENARIOS = {
	"styles": scenario_styles,
	"collapse": scenario_collapse,
	"query-info": scenario_query_info,
	"media": scenario_media,
	"services": scenario_services,
	"pages": scenario_pages,
	"previews": scenario_previews,
	"previews-short": scenario_previews_short,
	"drafts": scenario_drafts,
	"sorting": scenario_sorting,
	"events": scenario_events,
	"labels": scenario_labels,
	"bots": scenario_bots,
	"network-icon": scenario_network_icon,
	"websocket": scenario_websocket,
	"register": scenario_register,
	"multiline": scenario_multiline,
	"mute": scenario_mute,
	"keywords": scenario_keywords,
	"mass": scenario_mass,
	"accounts": scenario_accounts,
	"legacy-accounts": scenario_legacy_accounts,
	"idle": scenario_idle,
	"review-crashes": scenario_review_crashes,
	"review-irc": scenario_review_irc,
	"review-view": scenario_review_view,
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
	"znc-disconnect": scenario_znc_disconnect,
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
	"event-playback": scenario_event_playback,
	"sasl-new": scenario_sasl_new,
	"utf8only": scenario_utf8only,
	"whox": scenario_whox,
	"sasl-scram-fallback": scenario_sasl_scram_fallback,
	"sasl-scram-badsig": scenario_sasl_scram_badsig,
	"sasl-scram-noproof": scenario_sasl_scram_noproof,
	"sasl-scram-badsig-success": scenario_sasl_scram_badsig_success,
	"sasl-ecdsa": scenario_sasl_ecdsa,
	"sasl-ecdsa-wrongkey": scenario_sasl_ecdsa_wrongkey,
}

# Scenarios that register the client themselves
OWN_REGISTRATION_SCENARIOS = {"styles", "collapse", "query-info", "media", "services", "pages", "previews", "previews-short", "drafts", "sorting", "events", "labels", "multiline", "sasl-new", "bots", "network-icon", "register", "mute", "keywords", "mass", "accounts", "legacy-accounts", "znc-disconnect", "cap-ls", "protocol-fixes", "sasl-scram", "sasl-scram-fallback", "sasl-scram-badsig", "sasl-scram-noproof", "sasl-scram-badsig-success", "review-irc", "sasl-ecdsa", "sasl-ecdsa-wrongkey"}

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


async def run_event_playback_scenario(port):
	capabilities = "batch server-time message-tags draft/chathistory draft/event-playback draft/pre-away"
	connections = 0
	moments = {}

	def stamp_at(moment):
		return moment.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (moment.microsecond // 1000)

	def now():
		return datetime.datetime.now(datetime.timezone.utc)

	async def join(client, nick):
		await client.send(f":{nick}!user@client.textual.test JOIN #ch")
		await client.send(f":{SERVER} 353 {nick} = #ch :{nick} @gina bob dave erin")
		await client.send(f":{SERVER} 366 {nick} #ch :End of /NAMES list.")

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
			await join(client, nick)
			await client.collect(1)
			moments["line1"] = now()
			await client.send(f"@msgid=m1;time={stamp_at(moments['line1'])} :gina!g@friend.test PRIVMSG #ch :1 seen live before the drop")
			seen = 0
			while await client.collect(1):
				said = [line for line in client.received[seen:] if line.upper().startswith("PRIVMSG ") and line.endswith(" :drop")]
				seen = len(client.received)
				if said:
					break
			moments["early"] = now() - datetime.timedelta(seconds=1)
			moments["drop"] = now()
			log("<<", "dropping the connection")
			writer.close()
			return

		result(any(line.upper().startswith("AWAY") for line in client.registration_lines), "AWAY sent before registration ended (pre-away)")

		end = time.monotonic() + 60
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
				await join(client, nick)
			elif command == "CHATHISTORY":
				gap = moments["drop"] + datetime.timedelta(milliseconds=300)
				def at(offset):
					return stamp_at(gap + datetime.timedelta(milliseconds=offset))
				await client.send(f":{SERVER} BATCH +h1 chathistory #ch")
				await client.send(f"@batch=h1;msgid=m1;time={stamp_at(moments['line1'])} :gina!g@friend.test PRIVMSG #ch :1 seen live before the drop")
				await client.send(f"@batch=h1;msgid=e0;time={stamp_at(moments['early'])} :early!e@early.test JOIN #ch")
				await client.send(f"@batch=h1;msgid=e1;time={at(0)} :carol!c@carol.test JOIN #ch")
				await client.send(f"@batch=h1;msgid=e2;time={at(10)} :bob!b@bob.test PART #ch :bye")
				await client.send(f"@batch=h1;msgid=e3;time={at(20)} :dave!d@dave.test QUIT :gone home")
				await client.send(f"@batch=h1;msgid=e4;time={at(30)} :erin!e@erin.test NICK :erin2")
				await client.send(f"@batch=h1;msgid=e5;time={at(40)} :gina!g@friend.test TOPIC #ch :Topic set while you were away")
				await client.send(f"@batch=h1;msgid=e6;time={at(50)} :gina!g@friend.test MODE #ch +o carol")
				await client.send(f"@batch=h1;msgid=e7;time={at(60)} :gina!g@friend.test KICK #ch carol :no reason")
				await client.send(f"@batch=h1;msgid=m2;time={at(70)} :gina!g@friend.test PRIVMSG #ch :2 missed while disconnected")
				await client.send(f"@batch=h1;msgid=e8;time={at(80)} :{nick}!user@client.textual.test JOIN #ch")
				await client.send(f"@batch=h1;msgid=e9;time={stamp_at(now() + datetime.timedelta(seconds=5))} :frank!f@frank.test JOIN #ch")
				await client.send(f":{SERVER} BATCH -h1")
				break

		await client.collect(240)
		writer.close()

	server = await asyncio.start_server(handle, "127.0.0.1", port)
	print(f"Scenario 'event-playback' waiting on irc://127.0.0.1:{port}", flush=True)
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


# WebSocket (9.14): a hand-written server side of RFC 6455, enough for one client

class WebSocketClient(Client):
	"""A Client whose lines travel as WebSocket messages: one line per message,
	without CR LF. Records the frame type of every message and any line ending."""

	def __init__(self, reader, writer, subprotocol):
		super().__init__(reader, writer)
		self.subprotocol = subprotocol
		self.opcodes = set()
		self.line_endings = 0
		self.closed_by_client = False

	async def send(self, line, raw=None):
		data = raw if raw is not None else line.encode()
		opcode = 0x2 if self.subprotocol == "binary.ircv3.net" else 0x1
		log(">>", line if raw is None else f"{line} <{data.hex()}>")
		await self.send_frame(opcode, data)

	async def send_frame(self, opcode, data):
		header = bytes([0x80 | opcode])
		if len(data) < 126:
			header += bytes([len(data)])
		elif len(data) < 65536:
			header += bytes([126]) + len(data).to_bytes(2, "big")
		else:
			header += bytes([127]) + len(data).to_bytes(8, "big")
		self.writer.write(header + data)
		await self.writer.drain()

	async def read_frame(self):
		try:
			first, second = await self.reader.readexactly(2)
			length = second & 0x7f
			if length == 126:
				length = int.from_bytes(await self.reader.readexactly(2), "big")
			elif length == 127:
				length = int.from_bytes(await self.reader.readexactly(8), "big")
			mask = await self.reader.readexactly(4) if second & 0x80 else b""
			payload = await self.reader.readexactly(length)
		except (asyncio.IncompleteReadError, ConnectionResetError):
			return None, None
		if mask:
			payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
		return first & 0x0f, payload

	async def read_line(self):
		while True:
			opcode, payload = await self.read_frame()
			if opcode is None:
				return None
			if opcode == 0x8:
				self.closed_by_client = True
				log("<<", "close frame")
				return None
			if opcode == 0x9:
				await self.send_frame(0xa, payload)
				continue
			if opcode in (0x1, 0x2):
				break
		self.opcodes.add("binary" if opcode == 0x2 else "text")
		if payload.endswith(b"\n") or payload.endswith(b"\r"):
			self.line_endings += 1
		try:
			line = payload.decode()
		except UnicodeDecodeError:
			line = payload.decode(errors="replace") + f" <not UTF-8: {payload.hex()}>"
		log("<<", line)
		return line


async def websocket_handshake(reader, writer):
	"""Answers the HTTP upgrade. The path decides: /missing is 404, /text agrees
	to text.ircv3.net only, /none to no subprotocol; anything else to the
	client's first choice. Returns the subprotocol ("" for none), or None."""
	import base64
	import hashlib

	request = b""
	while b"\r\n\r\n" not in request:
		chunk = await reader.read(4096)
		if not chunk:
			return None
		request += chunk

	lines = request.decode(errors="replace").split("\r\n")
	path = lines[0].split(" ")[1] if len(lines[0].split(" ")) > 1 else "/"
	headers = {}
	for line in lines[1:]:
		name, _, value = line.partition(":")
		headers[name.strip().lower()] = value.strip()

	offered = [item.strip() for item in headers.get("sec-websocket-protocol", "").split(",") if item.strip()]
	log("<<", f"GET {path}, subprotocols offered: {', '.join(offered) or 'none'}")

	if path == "/missing":
		writer.write(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
		await writer.drain()
		log(">>", "HTTP 404")
		return None

	if path == "/text":
		chosen = "text.ircv3.net" if "text.ircv3.net" in offered else ""
	elif path == "/none":
		chosen = ""
	else:
		chosen = offered[0] if offered else ""

	accept = base64.b64encode(hashlib.sha1((headers.get("sec-websocket-key", "") + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
	response = f"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n"
	if chosen:
		response += f"Sec-WebSocket-Protocol: {chosen}\r\n"
	writer.write((response + "\r\n").encode())
	await writer.drain()
	log(">>", f"101, subprotocol {chosen or 'none'}")
	return chosen


async def run_websocket_scenario(port):
	"""See scenario_websocket."""
	finished = asyncio.Event()

	async def handle(reader, writer):
		subprotocol = await websocket_handshake(reader, writer)
		if subprotocol is None:
			writer.close()
			return

		client = WebSocketClient(reader, writer, subprotocol)

		if not await client.register_with_capabilities("server-time"):
			writer.close()
			return

		me = client.nickname
		await client.send(f":{me}!user@client.textual.test JOIN #ws")
		await client.send(f":{SERVER} 353 {me} = #ws :{me} alice")
		await client.send(f":{SERVER} 366 {me} #ws :End of /NAMES list.")
		await client.send(f":alice!a@alice.test PRIVMSG #ws :Hello over WebSocket ({subprotocol or 'no subprotocol'})")

		seen = 0
		while await client.collect(1):
			for line in client.received[seen:]:
				command, _, rest = line.partition(" ")
				if command.upper() != "PRIVMSG":
					continue
				if rest.endswith(" :latin"):
					await client.send(":alice!a@alice.test PRIVMSG #ws :caf\u00e9 (Latin-1)", raw=":alice!a@alice.test PRIVMSG #ws :caf\xe9 (Latin-1)".encode("latin-1"))
				elif rest.endswith(" :close"):
					log(">>", "close frame (1000)")
					await client.send_frame(0x8, (1000).to_bytes(2, "big") + b"bye")
			seen = len(client.received)

		expected = {"binary.ircv3.net": {"binary"}, "text.ircv3.net": {"text"}, "": {"text"}}[subprotocol]
		passed = client.opcodes <= expected and client.line_endings == 0
		print(f"RESULT: {'PASS' if passed else 'FAIL'} (subprotocol {subprotocol or 'none'}; client sent {', '.join(sorted(client.opcodes)) or 'nothing'} messages; {client.line_endings} with a line ending)", flush=True)
		writer.close()

	server = await asyncio.start_server(handle, "127.0.0.1", port)
	print(f"Scenario 'websocket' waiting on ws://127.0.0.1:{port} (/text, /none, /missing)", flush=True)
	await finished.wait()


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

	if arguments.scenario == "event-playback":
		await run_event_playback_scenario(arguments.port)
		return

	if arguments.scenario == "websocket":
		await run_websocket_scenario(arguments.port)
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
