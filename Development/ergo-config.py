#!/usr/bin/env python3
#
# Turns Ergo's default.yaml into the configuration of the local test server:
# loopback only, a services host that the NickServ check can be tested with,
# and no fakelag (so floods arrive as fast as they are sent).

import sys

source, destination = sys.argv[1], sys.argv[2]

config = open(source).read()

replacements = [
	('    name: ErgoTest\n', '    name: TextualDev\n'),
	('    name: ergo.test\n', '    name: irc.textual.test\n'),
	('        ":6697":\n', '        "127.0.0.1:6697":\n'),
	('    #override-services-hostname: "example.network"\n', '    override-services-hostname: "services.textual.test"\n'),
	('fakelag:\n    # whether to enforce fakelag\n    enabled: true\n', 'fakelag:\n    # whether to enforce fakelag\n    enabled: false\n'),
]

for old, new in replacements:
	if config.count(old) != 1:
		sys.exit(f"ergo-config.py: expected exactly one {old.strip()!r} in {source}")

	config = config.replace(old, new)

open(destination, 'w').write(config)
