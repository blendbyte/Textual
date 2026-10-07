#!/usr/bin/env python3
#
# A minimal SOCKS5 or HTTP CONNECT proxy on 127.0.0.1 for testing Textual Dev's
# proxy support. It logs every request (and whether the client sent a host name
# or an address) and relays the connection.
#
#   test-proxy.py socks5 [--port 1080] [--auth user:password] [--map host=address …]
#   test-proxy.py http   [--port 8080] [--auth user:password] [--map host=address …]
#
# macOS connects to loopback addresses directly even when a proxy is set, so
# point the server at a made-up name and map it, e.g. --map irc.proxy.test=127.0.0.1
# (this also shows that the proxy, not the Mac, resolves the name).

import argparse
import asyncio
import base64
import socket
import struct
import sys


def log(message):
	print(message, flush=True)


async def relay(reader, writer):
	try:
		while True:
			data = await reader.read(65536)

			if not data:
				break

			writer.write(data)

			await writer.drain()
	except (ConnectionResetError, BrokenPipeError):
		pass
	finally:
		try:
			writer.close()
		except Exception:
			pass


HOST_MAP = {}


async def connect_and_relay(client_reader, client_writer, host, port):
	host = HOST_MAP.get(host, host)

	upstream_reader, upstream_writer = await asyncio.open_connection(host, port)

	await asyncio.gather(relay(client_reader, upstream_writer), relay(upstream_reader, client_writer))


class Socks5:
	def __init__(self, auth):
		self.auth = auth

	async def handle(self, reader, writer):
		try:
			version, method_count = struct.unpack("!BB", await reader.readexactly(2))
			methods = await reader.readexactly(method_count)

			if version != 5:
				log(f"refused: not SOCKS5 (version {version})")
				writer.close()
				return

			wanted = 0x02 if self.auth else 0x00

			if wanted not in methods:
				log(f"refused: client offered methods {list(methods)}, need {wanted}")
				writer.write(b"\x05\xff")
				writer.close()
				return

			writer.write(bytes([5, wanted]))

			if self.auth:
				_, user_length = struct.unpack("!BB", await reader.readexactly(2))
				user = (await reader.readexactly(user_length)).decode()
				password_length = (await reader.readexactly(1))[0]
				password = (await reader.readexactly(password_length)).decode()

				if f"{user}:{password}" != self.auth:
					log(f"refused: wrong credentials {user!r}")
					writer.write(b"\x01\x01")
					writer.close()
					return

				log(f"authenticated as {user!r}")
				writer.write(b"\x01\x00")

			_, command, _, address_type = struct.unpack("!BBBB", await reader.readexactly(4))

			if address_type == 3:
				host = (await reader.readexactly((await reader.readexactly(1))[0])).decode()
				kind = "host name"
			elif address_type == 1:
				host = socket.inet_ntop(socket.AF_INET, await reader.readexactly(4))
				kind = "IPv4 address"
			else:
				host = socket.inet_ntop(socket.AF_INET6, await reader.readexactly(16))
				kind = "IPv6 address"

			port = struct.unpack("!H", await reader.readexactly(2))[0]

			log(f"SOCKS5 CONNECT {host}:{port} ({kind})")

			writer.write(b"\x05\x00\x00\x01" + bytes(4) + bytes(2))

			await connect_and_relay(reader, writer, host, port)
		except (asyncio.IncompleteReadError, ConnectionResetError, OSError) as error:
			log(f"connection ended: {error}")


class HTTPConnect:
	def __init__(self, auth):
		self.auth = auth

	async def handle(self, reader, writer):
		try:
			header = await reader.readuntil(b"\r\n\r\n")
			lines = header.decode(errors="replace").split("\r\n")
			method, target, _ = lines[0].split(" ", 2)

			if method != "CONNECT":
				log(f"refused: {method}")
				writer.write(b"HTTP/1.1 405 Method Not Allowed\r\n\r\n")
				writer.close()
				return

			if self.auth:
				expected = "Basic " + base64.b64encode(self.auth.encode()).decode()
				given = [line.split(":", 1)[1].strip() for line in lines[1:] if line.lower().startswith("proxy-authorization:")]

				if expected not in given:
					log("asking for credentials")
					writer.write(b"HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic realm=\"test\"\r\nContent-Length: 0\r\n\r\n")
					await writer.drain()
					writer.close()
					return

				log("authenticated")

			host, port = target.rsplit(":", 1)

			log(f"HTTP CONNECT {host}:{port}")

			writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")

			await connect_and_relay(reader, writer, host.strip("[]"), int(port))
		except (asyncio.IncompleteReadError, asyncio.LimitOverrunError, ConnectionResetError, OSError, ValueError) as error:
			log(f"connection ended: {error}")


async def main():
	parser = argparse.ArgumentParser(description="Test proxy for Textual Dev")
	parser.add_argument("type", choices=["socks5", "http"])
	parser.add_argument("--port", type=int)
	parser.add_argument("--auth", help="user:password")
	parser.add_argument("--map", action="append", default=[], help="host=address")
	arguments = parser.parse_args()

	for mapping in arguments.map:
		host, address = mapping.split("=", 1)
		HOST_MAP[host] = address

	port = arguments.port or (1080 if arguments.type == "socks5" else 8080)

	proxy = Socks5(arguments.auth) if arguments.type == "socks5" else HTTPConnect(arguments.auth)

	server = await asyncio.start_server(proxy.handle, "127.0.0.1", port)

	log(f"{arguments.type} proxy on 127.0.0.1:{port}" + (" (credentials required)" if arguments.auth else ""))

	async with server:
		await server.serve_forever()


if __name__ == "__main__":
	try:
		asyncio.run(main())
	except KeyboardInterrupt:
		sys.exit(0)
