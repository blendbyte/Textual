#!/usr/bin/env python3
#
# A local IRC server with busy, made-up channels, for screenshots (the App
# Store listing, release notes): an hour of history, operators and voiced
# members, people away, replies, reactions, someone typing, a mention and a
# private message, a picture and a link, then a few live messages a minute.
# The people and what they say are invented.
#
# Usage: showcase-irc-server.py [--nick alex]
#        Libera.Chat on 127.0.0.1:6690, OFTC on 127.0.0.1:6691 (plain)

import argparse
import asyncio
import datetime
import itertools
import random

NICK = "alex"

# Unsplash licence (free to use, no attribution needed), served by Lorem Picsum
PHOTO = "https://fastly.picsum.photos/id/1015/1600/1067.jpg?hmac=KcEKhxeliVc8ubKOh05esbmHkJYvmfGYwn6iVZi7OTU"

NETWORKS = {
	6690: {
		"network": "Libera.Chat",
		"server": "tungsten.libera.chat",
		"channels": {
			"#macdev": {
				"topic": "Mac and iOS development · SwiftUI, AppKit, Xcode · be kind, paste long code to a pastebin",
				"members": {"mira": "@", "kenji": "@", "theo": "+", "priya": "", "jonas": "", "nadia": "", "lucas": "", "sofia": "",
							"ben": "", "ava": "", "omar": "", "lena": "", "felix": "", "chloe": "", "raj": "", "emma_k": "", "sam": "",
							"yuki": "", "noah": "", "iris": "", "hugo": "", "maya": "", "leo": "", "zoe": "", "arjun": "", "elif": ""},
				"away": {"lena", "noah", "hugo", "zoe"},
				"history": [
					("priya", "is anyone else seeing Xcode index forever on a fresh clone?"),
					("theo", "delete DerivedData and give it a minute, mine settles after the first build"),
					("priya", "that did it, thanks"),
					("jonas", "SwiftUI question: what do you use for a sidebar that remembers its width?"),
					("kenji", "NavigationSplitView with columnVisibility and a SceneStorage for the width works well"),
					("jonas", "nice, I'll try that"),
					("nadia", "just shipped our first Mac app to TestFlight 🎉", "launch"),
					("mira", "congrats! what does it do?", None, "launch"),
					("nadia", "a tiny menu bar app that keeps an eye on build times"),
					("nadia", "it tells you when a build suddenly gets slower than usual"),
					("lucas", "@nadia send the link, I want it"),
					("sofia", "Swift 6 strict concurrency finally clicked for me this week"),
					("sofia", "the trick was moving all the UI state into one @MainActor model"),
					("felix", "same, once you treat actors as little islands it gets much easier"),
					("ben", "anyone using the new Observation macros with AppKit views?"),
					("kenji", "yes, withObservationTracking around the update method, works fine"),
					("ava", "the release notes for the latest Swift are worth a read: https://www.swift.org/blog/"),
					("mira", "alex: did the build with the crash fix help on your side?", "mention"),
					("omar", "Instruments' new hangs view saved me an afternoon today"),
					("chloe", "how do you all name your feature flags?"),
					("raj", "verbs: enablesFoo, showsBar. reads nicely in code"),
					("theo", "+1, and keep them in one place so they're easy to remove later"),
					("theo", "we put ours in a single enum, the compiler finds every use"),
				],
				"live": [
					("priya", "did anyone try the new Xcode beta on a big project yet?"),
					("kenji", "builds feel a bit faster here, previews too"),
					("emma_k", "what's the cleanest way to show a sheet from an NSWindow in SwiftUI?"),
					("felix", "an NSHostingController as the sheet's content works well"),
					("yuki", "TIL you can option-click a symbol for its quick help"),
					("sam", "coffee break, back in 10"),
					("jonas", "the sidebar width trick works, thanks kenji"),
					("arjun", "anyone going to the meetup next week?"),
				],
				"typing": "mira",
				"crowd": 64,
				"reactions": [("launch", "🎉", ["lucas", "kenji", "sofia"]), ("launch", "🚀", ["priya"]), ("mention", "👀", ["theo"])],
			},
			"#photography": {
				"topic": "Photography · gear, edits, critique · share your shots",
				"members": {"elif": "@", "maya": "+", "leo": "", "iris": "", "hugo": "", "ava": "", "omar": "", "zoe": "", "raj": ""},
				"away": {"hugo"},
				"history": [
					("maya", "went hiking at sunrise, the light was unreal"),
					("maya", PHOTO, "photo"),
					("leo", "wow, that river!", None, "photo"),
					("iris", "what lens was that?"),
					("maya", "35mm, f/8, one exposure"),
					("elif", "the colours are lovely, barely any editing needed"),
				],
				"live": [
					("leo", "anyone tried the new film simulation presets?"),
					("iris", "I'm going back there next weekend"),
				],
				"reactions": [("photo", "😍", ["leo", "iris", "elif"])],
			},
		},
		"query": ("mira", "hey! are you coming to the meetup on Thursday?"),
	},
	6691: {
		"network": "OFTC",
		"server": "helix.oftc.net",
		"channels": {
			"#coffee": {
				"topic": "Coffee: brewing, beans, gear · no judgement for instant",
				"members": {"lena": "@", "ben": "+", "chloe": "", "sam": "", "yuki": "", "arjun": "", "noah": ""},
				"away": {"noah"},
				"history": [
					("ben", "dialled in a new Ethiopian, tastes like blueberries"),
					("chloe", "light roast? what ratio?"),
					("ben", "1:16 on a V60, 3 minutes"),
					("sam", "I'm still on the AeroPress, can't beat it for travel"),
					("lena", "the inverted method or standard?"),
				],
				"live": [
					("yuki", "my grinder finally arrived ☕️"),
					("arjun", "what did you get?"),
				],
				"reactions": [],
			},
			"#travel": {
				"topic": "Travel tips and stories · where are you headed?",
				"members": {"iris": "@", "omar": "", "zoe": "", "felix": "", "maya": "", "leo": ""},
				"away": set(),
				"history": [
					("omar", "booked trains across Japan for spring, any tips?"),
					("zoe", "get an IC card on your phone, it works on almost everything"),
					("felix", "and Kyoto early in the morning before the crowds"),
				],
				"live": [
					("iris", "Lisbon in October was perfect weather"),
				],
				"reactions": [],
			},
		},
		"query": None,
	},
}

def channel(topic, staff, history, live=(), reactions=(), crowd=0, away=()):
	members = dict(staff)
	return {"topic": topic, "members": members, "away": set(away), "history": list(history), "live": list(live),
			"reactions": list(reactions), "crowd": crowd}


MORE_CHANNELS = {
	6690: {
		"#swift": channel("Swift · the language, packages and tools · swift.org", {"felix": "@", "sofia": "+", "omar": "+"}, [
			("sofia", "is there a nice way to make a result builder for menus?"),
			("felix", "yes, look at how ViewBuilder does buildEither, it's surprisingly small"),
			("ravi", "macros are great but the compile times hurt a bit"),
			("felix", "keep them in their own package, helps a lot"),
		], [("ravi", "anyone tried typed throws in a real project yet?")], crowd=38, away=("tess", "piotr")),
		"#design": channel("Design: UI, type, colour · critique welcome", {"chloe": "@", "maya": ""}, [
			("chloe", "does this icon read well at 16 pt?"),
			("maya", "the inner shape gets lost, try a thicker stroke"),
			("ines", "+1, and a touch more contrast on the dark variant"),
		], [("ines", "SF Symbols has a new set of variable icons, worth a look")], crowd=24, away=("ola",)),
		"#astronomy": channel("Astronomy · clear skies! · share your night shots", {"elif": "@"}, [
			("elif", "Jupiter is really bright this week, look east after sunset"),
			("kai", "got the moons with plain binoculars yesterday"),
			("nora", "that's the best feeling"),
		], [("kai", "clouds tonight again 😩")], crowd=19),
		"#gamedev": channel("Game development · engines, art, jams", {"leo": "@", "sam": "+"}, [
			("sam", "our jam game has 200 players now 🎮"),
			("leo", "well deserved, the art style is great"),
		], [("leo", "the next jam theme is 'tiny worlds'")], crowd=31, away=("bram",)),
	},
	6691: {
		"#homelab": channel("Homelab · servers, networks, blinkenlights", {"noah": "@", "raj": "+"}, [
			("raj", "moved everything to a tiny fanless box, power bill thanks me"),
			("noah", "which one?"),
			("raj", "an N100 with 32 GB, runs all my containers"),
			("tobi", "nice, how's the idle draw?"),
			("raj", "about 7 W"),
		], [("tobi", "backups first, then the fun stuff")], crowd=27, away=("vera",)),
		"#books": channel("Books · what are you reading? · no spoilers without warning", {"iris": "@"}, [
			("iris", "finished Piranesi last night, what a book"),
			("zoe", "one of my favourites, the house!"),
		], [("zoe", "starting a sci-fi stretch next")], crowd=16),
		"#running": channel("Running · training, races, gear", {"ben": "@"}, [
			("ben", "first 10K under 50 minutes this morning 🏃"),
			("mila", "congrats!! what was your plan?"),
		], [("mila", "rest days count as training too")], reactions=(), crowd=14),
	},
}

CROWD = ["ravi", "tess", "piotr", "ines", "ola", "kai", "nora", "bram", "tobi", "vera", "mila", "anouk", "jules", "linh", "marek",
		 "sana", "teo", "hana", "otto", "aiko", "ruben", "dina", "elio", "freya", "gus", "ilse", "joel", "kira", "lars", "mei",
		 "nils", "oona", "pablo", "quinn", "rosa", "sven", "tara", "ugo", "vik", "wren", "xavi", "yara", "zeno", "abby", "bao",
		 "cleo", "dev", "eva", "finn", "gabi", "henk", "ivy", "jana", "karl", "luca", "mona", "nate", "olli", "pia", "rami",
		 "sol", "tim", "uma", "vito", "wim", "yoel", "zara", "ada", "bo", "cyra", "dag", "esme", "fynn", "gwen", "hal", "ida"]

for port, extra in MORE_CHANNELS.items():
	NETWORKS[port]["channels"].update(extra)

# Fuller member lists: the named people, then a crowd from the pool
for port, network in NETWORKS.items():
	for number, (name, chan) in enumerate(network["channels"].items()):
		wanted = chan.get("crowd") or len(chan["members"]) + 12
		pool = CROWD[number * 7:] + CROWD[:number * 7]
		for nick in pool:
			if len(chan["members"]) >= wanted + len([n for n in chan["members"] if chan["members"][n]]):
				break
			chan["members"].setdefault(nick, "")
		for sender, *rest in chan["history"] + chan["live"]:
			chan["members"].setdefault(sender, "")
		chan.setdefault("reactions", [])

CAPABILITIES = ["server-time", "message-tags", "multi-prefix", "echo-message", "away-notify", "account-notify",
				"extended-join", "account-tag", "batch", "draft/multiline=max-bytes=4096,max-lines=24"]

# Not logged in to an account: the member list marks them (account markers)
NOT_LOGGED_IN = {"ava", "lucas", "emma_k", "yuki", "sam", "ines", "kai", "tobi", "mila", "bram", "ola", "nate"}
NOT_LOGGED_IN.update(CROWD[3::5])

BOTS = {"heidi"}

# #macdev gets a bot, a multi-line message and a run of joins and leaves
MACDEV = NETWORKS[6690]["channels"]["#macdev"]
MACDEV["members"]["heidi"] = ""
MACDEV["members"]["pia"] = ""
MACDEV["members"]["rami"] = ""
MACDEV["history"][6:6] = [
	("heidi", "📦 swift-format 601.0.0 was released · https://github.com/swiftlang/swift-format/releases"),
	("*join", "ivy"), ("*join", "nate"), ("*part", "pia"), ("*join", "olli"), ("*quit", "rami"),
]
MACDEV["history"][12:12] = [
	("kenji", ["here's roughly what I use:", "", "@SceneStorage(\"sidebarWidth\") private var width = 220.0", "", "NavigationSplitView {", "    Sidebar().frame(minWidth: width)", "} detail: {", "    Detail()", "}"]),
]

msgids = itertools.count(1000)


def utc(dt):
	return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def host(nick):
	return f"{nick}!~{nick}@user/{nick}"


class Session:
	def __init__(self, reader, writer, config, nick):
		self.reader = reader
		self.writer = writer
		self.config = config
		self.nick = nick
		self.caps = set()
		self.registered = False

	async def send(self, line):
		self.writer.write((line + "\r\n").encode())
		await self.writer.drain()

	def tags(self, extra=None, when=None):
		parts = []
		if "server-time" in self.caps:
			parts.append("time=" + utc(when or datetime.datetime.now(datetime.timezone.utc)))
		if "message-tags" in self.caps and extra:
			parts.extend(extra)
		return ("@" + ";".join(parts) + " ") if parts else ""

	def sender_tags(self, nick):
		extra = []
		if "account-tag" in self.caps and nick not in NOT_LOGGED_IN:
			extra.append(f"account={nick}")
		if nick in BOTS:
			extra.append("bot")
		return extra

	async def numeric(self, code, text):
		await self.send(f":{self.config['server']} {code} {self.nick} {text}")

	async def welcome(self):
		net = self.config["network"]
		await self.numeric("001", f":Welcome to the {net} Internet Relay Chat Network {self.nick}")
		await self.numeric("002", f":Your host is {self.config['server']}")
		await self.numeric("003", ":This server was created a while ago")
		await self.numeric("004", f"{self.config['server']} showcase iosw bklmnopstv")
		await self.numeric("005", f"NETWORK={net} WHOX BOT=B CHANTYPES=# PREFIX=(ov)@+ CHANMODES=b,k,l,imnpst CASEMAPPING=rfc1459 NICKLEN=30 :are supported by this server")
		await self.numeric("375", f":- {self.config['server']} Message of the Day -")
		await self.numeric("372", f":- Welcome to {net}.")
		await self.numeric("376", ":End of /MOTD command.")
		self.registered = True
		await self.join_all()
		asyncio.create_task(self.live())

	async def join_all(self):
		now = datetime.datetime.now(datetime.timezone.utc)
		for name, channel in self.config["channels"].items():
			if "extended-join" in self.caps:
				await self.send(f":{host(self.nick)} JOIN {name} {self.nick} :Alex")
			else:
				await self.send(f":{host(self.nick)} JOIN {name}")
			await self.numeric("332", f"{name} :{channel['topic']}")
			await self.numeric("333", f"{name} {list(channel['members'])[0]} {int(now.timestamp()) - 86400 * 40}")
			joiners = {entry[1] for entry in channel["history"] if entry[0] == "*join"}
			names = " ".join(prefix + nick for nick, prefix in channel["members"].items() if nick not in joiners)
			await self.numeric("353", f"= {name} :{self.nick} {names}")
			await self.numeric("366", f"{name} :End of /NAMES list.")
			await self.history(name, channel, now)
		query = self.config.get("query")
		if query:
			sender, text = query
			await self.send(f"{self.tags(['msgid=q1'], now - datetime.timedelta(minutes=2))}:{host(sender)} PRIVMSG {self.nick} :{text}")

	async def history(self, name, channel, now):
		history = channel["history"]
		start = now - datetime.timedelta(minutes=len(history) * 3 + 5)
		labels = {}
		for index, entry in enumerate(history):
			sender, text = entry[0], entry[1]
			label = entry[2] if len(entry) > 2 else None
			reply_to = entry[3] if len(entry) > 3 else None
			msgid = f"m{next(msgids)}"
			if label:
				labels[label] = msgid
			when = start + datetime.timedelta(minutes=index * 3, seconds=random.randint(0, 50))
			if sender.startswith("*"):
				await self.event(name, sender[1:], text, when)
				continue
			if isinstance(text, list):
				await self.multiline(name, sender, text, when)
				continue
			extra = [f"msgid={msgid}"] + self.sender_tags(sender)
			if reply_to and reply_to in labels:
				extra += [f"+reply={labels[reply_to]}", f"+draft/reply={labels[reply_to]}"]
			await self.send(f"{self.tags(extra, when)}:{host(sender)} PRIVMSG {name} :{text}")
		for label, emoji, people in channel["reactions"]:
			if label not in labels:
				continue
			for person in people:
				extra = [f"+draft/react={emoji}", f"+draft/reply={labels[label]}", f"+reply={labels[label]}", f"msgid=m{next(msgids)}"]
				await self.send(f"{self.tags(extra, now - datetime.timedelta(minutes=1))}:{host(person)} TAGMSG {name}")

	async def event(self, name, kind, nick, when):
		tags = self.tags(self.sender_tags(nick), when)
		if kind == "join":
			if "extended-join" in self.caps:
				account = "*" if nick in NOT_LOGGED_IN else nick
				await self.send(f"{tags}:{host(nick)} JOIN {name} {account} :{nick.capitalize()}")
			else:
				await self.send(f"{tags}:{host(nick)} JOIN {name}")
		elif kind == "part":
			await self.send(f"{tags}:{host(nick)} PART {name} :See you")
		elif kind == "quit":
			await self.send(f"{tags}:{host(nick)} QUIT :Quit: Leaving")

	async def multiline(self, name, sender, lines, when):
		if "draft/multiline" not in self.caps or "batch" not in self.caps:
			for line in lines:
				if line:
					await self.send(f"{self.tags(self.sender_tags(sender), when)}:{host(sender)} PRIVMSG {name} :{line}")
			return
		reference = f"ml{next(msgids)}"
		extra = [f"msgid=m{next(msgids)}"] + self.sender_tags(sender)
		await self.send(f"{self.tags(extra, when)}:{host(sender)} BATCH +{reference} draft/multiline {name}")
		for line in lines:
			await self.send(f"@batch={reference} :{host(sender)} PRIVMSG {name} :{line}")
		await self.send(f":{host(sender)} BATCH -{reference}")

	async def live(self):
		queue = [(name, line) for name, channel in self.config["channels"].items() for line in channel["live"]]
		random.shuffle(queue)
		await asyncio.sleep(20)
		for name, (sender, text) in queue:
			if self.writer.is_closing():
				return
			channel = self.config["channels"][name]
			typing = channel.get("typing")
			if typing and "message-tags" in self.caps:
				await self.send(f"@+typing=active :{host(typing)} TAGMSG {name}")
			await self.send(f"{self.tags([f'msgid=m{next(msgids)}'] + self.sender_tags(sender))}:{host(sender)} PRIVMSG {name} :{text}")
			await asyncio.sleep(random.randint(25, 50))
		# Someone keeps typing in the busiest channel, for the shots
		while not self.writer.is_closing():
			for name, channel in self.config["channels"].items():
				typing = channel.get("typing")
				if typing and "message-tags" in self.caps:
					await self.send(f"@+typing=active :{host(typing)} TAGMSG {name}")
			await asyncio.sleep(4)

	async def who(self, target, whox):
		channel = self.config["channels"].get(target)
		if channel is None:
			await self.numeric("315", f"{target} :End of /WHO list.")
			return
		people = [(self.nick, "", False)] + [(nick, prefix, nick in channel["away"]) for nick, prefix in channel["members"].items()
											   if nick not in ("pia", "rami")]
		for nick, prefix, away in people:
			flags = ("G" if away else "H") + ("B" if nick in BOTS else "") + prefix
			if whox:
				account = "0" if nick in NOT_LOGGED_IN else nick
				await self.numeric("354", f"152 {target} ~{nick} user/{nick} {nick} {flags} {account} :{nick.capitalize()}")
			else:
				await self.numeric("352", f"{target} ~{nick} user/{nick} {self.config['server']} {nick} {flags} :0 {nick.capitalize()}")
		await self.numeric("315", f"{target} :End of /WHO list.")

	async def run(self):
		while True:
			data = await self.reader.readline()
			if not data:
				return
			line = data.decode(errors="replace").rstrip("\r\n")
			if line.startswith("@"):
				line = line.split(" ", 1)[1] if " " in line else ""
			parts = line.split(" ")
			command = parts[0].upper()
			if command == "CAP":
				sub = parts[1].upper() if len(parts) > 1 else ""
				if sub == "LS":
					await self.send(f":{self.config['server']} CAP * LS :{' '.join(CAPABILITIES)}")
				elif sub == "REQ":
					wanted = line.split(":", 1)[1].split() if ":" in line else parts[2:]
					names = [c.split("=", 1)[0] for c in CAPABILITIES]
					granted = [c for c in wanted if c in names]
					self.caps.update(granted)
					await self.send(f":{self.config['server']} CAP * ACK :{' '.join(granted)}")
				elif sub == "END" and not self.registered and self.nick:
					await self.welcome()
			elif command == "NICK":
				pass  # the showcase nickname, whatever the client asks for
			elif command == "USER":
				if not self.caps and not self.registered:
					pass
			elif command == "PING":
				await self.send(f":{self.config['server']} PONG {self.config['server']} :{parts[-1].lstrip(':')}")
			elif command == "MODE":
				pass  # no "Mode is +nt" line in the shots
			elif command == "WHO" and len(parts) > 1:
				await self.who(parts[1], len(parts) > 2 and parts[2].startswith("%"))
			elif command in ("PRIVMSG", "NOTICE") and "echo-message" in self.caps:
				await self.send(f"{self.tags([f'msgid=m{next(msgids)}'])}:{host(self.nick)} {line}")
			elif command == "QUIT":
				return


async def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--nick", default=NICK)
	arguments = parser.parse_args()

	async def handler_for(port):
		async def handle(reader, writer):
			session = Session(reader, writer, NETWORKS[port], arguments.nick)
			try:
				await session.run()
			except (ConnectionResetError, BrokenPipeError):
				pass
			writer.close()
		return await asyncio.start_server(handle, "127.0.0.1", port)

	servers = [await handler_for(port) for port in NETWORKS]
	print("Showcase: " + ", ".join(f"{NETWORKS[p]['network']} on 127.0.0.1:{p}" for p in NETWORKS), flush=True)
	await asyncio.gather(*(server.serve_forever() for server in servers))


if __name__ == "__main__":
	asyncio.run(main())
