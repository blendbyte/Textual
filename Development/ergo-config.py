#!/usr/bin/env python3
#
# Turns Ergo's default.yaml into the configuration of the local test server:
# loopback only, a services host that the NickServ check can be tested with,
# no fakelag (so floods arrive as fast as they are sent), and WebSocket
# listeners (ws://127.0.0.1:8097, wss://127.0.0.1:8098) for 9.14.

import sys

source, destination = sys.argv[1], sys.argv[2]

config = open(source).read()

replacements = [
	('    name: ErgoTest\n', '    name: TextualDev\n'),
	('    name: ergo.test\n', '    name: irc.textual.test\n'),
	('        ":6697":\n', '        "127.0.0.1:6697":\n'),
	('    #override-services-hostname: "example.network"\n', '    override-services-hostname: "services.textual.test"\n'),
	('fakelag:\n    # whether to enforce fakelag\n    enabled: true\n', 'fakelag:\n    # whether to enforce fakelag\n    enabled: false\n'),
	('        # Example of a WebSocket listener:\n',
	 '        "127.0.0.1:8097":\n            websocket: true\n'
	 '        "127.0.0.1:8098":\n            websocket: true\n            tls:\n                cert: fullchain.pem\n                key: privkey.pem\n\n'
	 '        # Example of a WebSocket listener:\n'),
]

for old, new in replacements:
	if config.count(old) != 1:
		sys.exit(f"ergo-config.py: expected exactly one {old.strip()!r} in {source}")

	config = config.replace(old, new)

open(destination, 'w').write(config)
