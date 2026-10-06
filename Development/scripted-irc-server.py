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
import os
import ssl
import sys
import time

SERVER = "scripted.textual.test"
SERVICES_HOST = "services.textual.test"

# The local Ergo server's self-signed certificate (Development/dev server start)
CERTIFICATE_DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".tmp", "dev", "ergo")


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

		for line in [
			f":{SERVER} 001 {self.nickname} :Welcome to the scripted test server",
			f":{SERVER} 002 {self.nickname} :Your host is {SERVER}",
			f":{SERVER} 003 {self.nickname} :This server was created today",
			f":{SERVER} 004 {self.nickname} {SERVER} scripted io bklov",
			f":{SERVER} 005 {self.nickname} CHANTYPES=# PREFIX=(ov)@+ NETWORK=TextualScripted :are supported by this server",
			f":{SERVER} 422 {self.nickname} :MOTD File is missing",
		]:
			await self.send(line)

		return True

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
	"""NickServ asks to identify: with no NickServ Host known, from a wrong host, and
	from the services host. Within 8 seconds of connecting, run
	"Development/dev config nicknamePassword=test"; when asked, run
	"Development/dev config nickServHost=services.textual.test"."""
	await client.collect(8)

	notice = "This nickname is registered. Please choose a different nickname, or identify via /msg NickServ identify <password>."
	identify = lambda line: line.upper().startswith("PRIVMSG NICKSERV ") and "IDENTIFY" in line.upper()

	await client.send(f":NickServ!NickServ@{SERVICES_HOST} NOTICE {client.nickname} :{notice}")
	await client.collect(3)

	result(len(client.sent(identify)) == 0, "no password sent while this server's NickServ host is unknown")

	print("WAITING: run Development/dev config nickServHost=services.textual.test", flush=True)
	await client.collect(8)

	await client.send(f":NickServ!NickServ@attacker.test NOTICE {client.nickname} :{notice}")
	await client.collect(3)

	result(len(client.sent(identify)) == 0, "no password sent to NickServ from attacker.test")

	await client.send(f":NickServ!NickServ@{SERVICES_HOST} NOTICE {client.nickname} :{notice}")
	await client.collect(3)

	result(len(client.sent(identify)) == 1, f"password sent once to NickServ from {SERVICES_HOST}")


async def scenario_long_line(client):
	"""The server sends 70 KiB without a line break; the client must disconnect."""
	await client.collect(2)

	await client.send_raw(b"A" * (70 * 1024))

	still_connected = await client.collect(5)
	result(not still_connected, "client disconnected after 64 KiB without a line break")


async def scenario_ctcp_flood(client):
	"""20 CTCP VERSION queries to the client and one to a channel; at most 5 replies."""
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
	result(len(replies) <= 5, f"{len(replies)} of 20 private CTCP queries answered (limit 5 per 10 seconds)")


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


SCENARIOS = {
	"idle": scenario_idle,
	"nickserv-spoof": scenario_nickserv_spoof,
	"long-line": scenario_long_line,
	"ctcp-flood": scenario_ctcp_flood,
	"malformed": scenario_malformed,
	"redirect-tls": scenario_redirect_tls,
	"conn-tls": scenario_conn_tls,
}

TLS_SCENARIOS = {"redirect-tls", "conn-tls"}


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
	connections = 0

	async def handle(reader, writer):
		nonlocal connections
		connections += 1

		if connections > 1:
			Events.reconnected_with_tls = use_tls
			Events.reconnected.set()
			writer.close()
			return

		client = Client(reader, writer)

		if await client.register():
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
