#!/usr/bin/env python3
#
# A local IRC server with busy, made-up channels, for screenshots (the App
# Store listing, release notes): an hour of history, operators and voiced
# members, people away, replies, reactions, someone typing, a mention and a
# private message, a picture and a link, then a few live messages a minute.
# The people and what they say are invented.
#
# Usage: showcase-irc-server.py [--nick alex] [--still] [--listen <address>]...
#        Libera.Chat on 127.0.0.1:6690, OFTC on 127.0.0.1:6691, hackint on
#        127.0.0.1:6692 (plain). --still sends no new messages after the
#        history (someone keeps typing), so shots taken a while apart match.
#        --listen adds an address to 127.0.0.1, such as a VM's local-network
#        address for a Mac taking the screenshots.

import argparse
import asyncio
import datetime
import itertools
import random

NICK = "alex"

STILL = False

# Unsplash licence (free to use, no attribution needed), served by Lorem Picsum
PHOTO = "https://fastly.picsum.photos/id/1015/1600/1067.jpg?hmac=KcEKhxeliVc8ubKOh05esbmHkJYvmfGYwn6iVZi7OTU"

NETWORKS = {
	6690: {
		"network": "Libera.Chat",
		"server": "tungsten.libera.chat",
		"icon": "https://libera.chat/favicon.ico",
		"channels": {
			"#macdev": {
				"topic": "Mac and iOS development · SwiftUI, AppKit, Xcode · be kind, paste long code to a pastebin",
				# The whole list (70 with alex): who joins and quits below is in it too
				"members": {"mira": "@", "kenji": "@", "nullptr": "@", "alice": "+", "theo_": "+", "priya": "+", "felix": "+",
							"RelBot": "+", "mdlog": "+",
							"nadia": "", "jonas": "", "sofia": "", "omar": "", "lucas": "", "ben": "", "yuki": "", "arjun": "",
							"elif": "", "raj": "", "maya": "", "iris": "", "leo": "", "ines": "", "tess": "", "marek": "", "hana": "",
							"chloe": "", "sam__": "", "hugo_": "", "wren_": "", "rosa_": "", "lars__": "", "tobi|work": "",
							"ravi|work": "", "ilse|work": "", "dani|away": "", "petra|away": "", "kai^": "", "^ash": "", "gus^": "",
							"zoe92": "", "jt88": "", "mk2": "", "ola7": "", "t0m": "", "sv3n": "", "ByteHerder": "", "LateCommit": "",
							"MossyRock": "", "KernelPanda": "", "kqueue": "", "mkdir": "", "dyld": "", "plutil": "", "kevent": "",
							"jules[m]": "", "hannah-k[m]": "", "Guest48213": "", "emma_k": "", "fynn": "",
							"vik": "", "dag": "", "bo": "", "pk": "", "ndrw": "", "cwebb": "", "jkl": "", "xvi": "", "irina__": "", "lowpass": ""},
				"complete": True,
				"away": {"hugo_", "dani|away", "petra|away", "tess", "lars__", "MossyRock", "sv3n", "yuki", "elif", "hana",
						 "bo", "dag", "cwebb", "jkl", "t0m", "rosa_", "kai^", "hannah-k[m]"},
				# The first ones are from yesterday evening: a day line above today's
				"yesterday": 5,
				# Bursts seconds apart; ("*pause", minutes) between them
				"history": [
					("sofia", "anyone around to look at a crash log?"),
					("felix", "sure, gist it"),
					("sofia", "nvm found it. force unwrap in the menu code 🙈"),
					("theo_", "the classic"),
					("kenji", "night all"),
					("priya", "anyone else getting xcode stuck on \"indexing\" forever on a fresh clone? cleaned the build folder, restarted xcode, rebooted, still sitting there after 20 min"),
					("theo_", "nuke DerivedData and give it a minute"),
					("theo_", "settles after the first build here"),
					("priya", "yep that did it, ty"),
					("*pause", 11),
					("RelBot", "📦 swift-format 601.0.0 released · https://github.com/swiftlang/swift-format/releases"),
					("*pause", 8),
					("jonas", "swiftui q: how do you get a sidebar to remember its width?"),
					("jonas", "NavigationSplitView forgets it every launch"),
					("kenji", "SceneStorage, roughly:"),
					("kenji", "@SceneStorage(\"sidebarWidth\") private var width = 220.0"),
					("kenji", "NavigationSplitView {"),
					("kenji", "    Sidebar().frame(minWidth: width)"),
					("mira", "kenji: topic 👆"),
					("kenji", "yeah yeah, sorry"),
					("kenji", "https://gist.github.com/310e941eb13c22750d0308c2dd7815ac"),
					("jonas", "perfect, thx"),
					("*pause", 6),
					("sofia", "swift 6 strict concurrency finally clicked for me this week"),
					("sofia", "moved all the ui state into one @MainActor model and the warnings just went away"),
					("nadia", "just shipped our first mac app to testflight 🎉", "launch"),
					("felix", "sofia: yeah once you treat actors as little islands it gets easy"),
					("dyld", "meanwhile i'm at 312 Sendable warnings 🙃"),
					("alice", "dyld: the getting started guide has a decent concurrency section now https://www.swift.org/getting-started/"),
					("alice", "congrats!! what does it do?", None, "launch"),
					("nadia", "tiny menu bar app that watches your build times"),
					("nadia", "pings you when a build is suddenly way slower than usual"),
					("nadia", "caught a 40% regresion from one macro last week"),
					("nadia", "s/regresion/regression/"),
					("lucas", "nadia: link? want it"),
					("nadia", "lucas: https://cdn.imgpile.com/f/PhmxPYA.webp"),
					("nadia", "testflight link's still stuck in beta review, will post it when it clears"),
					("*pause", 5),
					("*join", "mkdir"), ("*join", "jules[m]"), ("*quit", "zoe92"), ("*join", "Guest48213"),
					("*pause", 3),
					("mira", "alex: did the build with the crash fix help on your side?", "mention"),
					("*pause", 4),
					("omar", "instruments' new hangs view saved me an afternoon today"),
					("nullptr", "same, found a sync file read on the main thread in like 5 min"),
				],
				"live": [
					("priya", "anyone tried the new xcode beta on a big project yet?"),
					("kenji", "builds feel a bit faster here, previews too"),
				],
				"typing": "alice",
				"reactions": [("launch", "👍", ["kenji", "lucas"]), ("launch", "🎉", ["sofia"]), ("mention", "👀", ["theo_"])],
			},
			"#textual": {
				"topic": "Textual, the IRC client for macOS · https://www.textualapp.com · Textual 8 betas: see GitHub",
				"members": {"vesper": "@", "ines": "", "kai^": "", "plutil": "", "hana": ""},
				"away": {"hana"},
				"history": [
					("kai^", "is the old timestamp format still in 8? can't find it"),
					("ines", "Settings → Style → Timestamp, it moved"),
				],
				"live": [],
				"crowd": 41,
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
		"icon": "https://www.oftc.net/img/favicon.ico",
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
			("tess", "anyone using swift-testing for the non-ui stuff yet?"),
			("piotr", "moved a whole package over last month"),
			("piotr", "parameterized tests alone were worth it"),
			("tess", "did it run fine next to the old XCTest ones?"),
			("piotr", "yep, same target even"),
			("tess", "great, trying it tomorrow"),
			("*pause", 14),
			("omar", "turned on default main actor isolation for the app target yesterday and about half of my concurrency warnings just disappeared, no other code changes"),
			("felix", "it does a lot of the work for ui code"),
			("omar", "keeping the packages strict though"),
			("sofia", "same here"),
			("*pause", 9),
			("ravi", "macros are great but the compile times hurt a bit"),
			("felix", "keep them in their own package, helps a lot"),
			("ravi", "they are, it's building swift-syntax that takes forever"),
			("omar", "yeah, clean builds are the worst part"),
			("*pause", 12),
			("sofia", "is there a nice way to make a result builder for menus?"),
			("felix", "yes, look at how ViewBuilder does buildIf and buildEither, it's surprisingly little code once you see the whole thing in one file"),
			("sofia", "oh that's way less code than i expected"),
			("*pause", 7),
			("sofia", "where are the ~Copyable rules written up? the book barely covers them"),
			("alice", "sofia: SE-0390, long but clear https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md"),
			("sofia", "thanks, that's the one i was looking for"),
			("omar", "consuming and borrowing only clicked for me after reading that one"),
		], [("ravi", "anyone tried typed throws in a real project yet?")], crowd=38, away=("tess", "piotr")),
		"#design": channel("Design: UI, type, colour · critique welcome", {"chloe": "@", "maya": "", "alice": ""}, [
			("ines", "morning! anyone have a favourite tool for colour palettes?"),
			("maya", "plain grid of swatches in a sketch file, every time"),
			("ola", "same, and check contrast in both appearances right away"),
			("alice", "this one's good for that https://webaim.org/resources/contrastchecker/"),
			("ines", "oh nice, bookmarked"),
			("*pause", 14),
			("maya", "anyone redone a mac app icon for the big sur style yet?"),
			("maya", "the rounded rect grid is stricter than i expected"),
			("chloe", "textual did, the PR has every size from 16 to 1024"),
			("chloe", "https://github.com/blendbyte/Textual/pull/558"),
			("maya", "oh that's a good reference, thx"),
			("ines", "the 16px one still reads, nice"),
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
	6692: {
		"#electronics": channel("Electronics · soldering, PCBs, scopes · show your builds", {"bram": "@", "kira": "+"}, [
			("kira", "finally fixed the ground loop on my bench supply"),
			("bram", "what was it?"),
			("kira", "the scope and the supply shared a bad power strip"),
			("joel", "the cheapest strips are always the culprit"),
		], [("joel", "new soldering tip arrived, the fine one")], crowd=22),
		"#hackint": channel("hackint · https://hackint.org · be excellent to each other", {"nox": "@"}, [
			("fiete", "the tor address changed? my bouncer can't connect since yesterday"),
			("nox", "no, but one onion server is down for maintenance, try the other one"),
			("fiete", "that was it, thanks"),
		], crowd=34),
		"#retro": channel("Retro computing · old machines, new tricks", {"otto": "@"}, [
			("otto", "got a 1989 laptop booting again, new caps and a CF card"),
			("linh", "pictures or it didn't happen!"),
		], [("linh", "anyone have spare floppy drive belts?")], crowd=15),
	},
	6691: {
		"#oftc": channel("OFTC support · https://www.oftc.net/ · ask your question and stay around, staff answer when they can", {"tjf": "@"}, [
			("rook_", "is there a way to get a cloak for a project?"),
			("tjf", "yes, have the project lead mail us, details are on the website"),
		], crowd=58, away=("tjf",)),
		"#homelab": channel("Homelab · servers, networks, blinkenlights", {"noah": "@", "raj": "+"}, [
			("raj", "moved everything to a tiny fanless box, power bill thanks me"),
			("noah", "which one?"),
			("raj", "an N100 with 32 GB, runs all my containers"),
			("tobi", "nice, how's the idle draw?"),
			("raj", "about 7 W"),
			("*pause", 9),
			("noah", "what's everyone doing for offsite backups these days"),
			("alice", "restic to a storage box, nightly from a systemd timer"),
			("alice", "docs are really good: https://restic.readthedocs.io/"),
			("noah", "ty, trying it this weekend"),
			("*pause", 6),
			("tobi", "alex: you had the same box, right? what idle draw do you get?"),
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

NETWORKS[6692] = {"network": "hackint", "server": "irc.hackint.org", "icon": "https://www.ircatlas.org/images/networks/hackint.webp",
				  "channels": {}, "query": None}

for port, extra in MORE_CHANNELS.items():
	NETWORKS[port]["channels"].update(extra)

# Fuller member lists: the named people, then a crowd from the pool
for port, network in NETWORKS.items():
	for number, (name, chan) in enumerate(network["channels"].items()):
		wanted = chan.get("crowd") or len(chan["members"]) + 12
		if chan.get("complete"):
			wanted = 0
		pool = CROWD[number * 7:] + CROWD[:number * 7]
		for nick in pool:
			if len(chan["members"]) >= wanted + len([n for n in chan["members"] if chan["members"][n]]):
				break
			chan["members"].setdefault(nick, "")
		for sender, *rest in chan["history"] + chan["live"]:
			if not sender.startswith("*"):  # joins, parts and quits name the person second
				chan["members"].setdefault(sender, "")
		chan.setdefault("reactions", [])

CAPABILITIES = ["server-time", "message-tags", "multi-prefix", "echo-message", "away-notify", "account-notify",
				"extended-join", "account-tag", "batch", "draft/multiline=max-bytes=4096,max-lines=24"]

# Not logged in to an account: the member list marks them (account markers)
NOT_LOGGED_IN = {"ava", "lucas", "emma_k", "yuki", "sam", "ines", "kai", "tobi", "mila", "bram", "ola", "nate",
				 "Guest48213", "jt88", "kevent", "xvi"}
NOT_LOGGED_IN.update(CROWD[3::5])

BOTS = {"RelBot", "mdlog"}

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
		icon = f" draft/ICON={self.config['icon']}" if self.config.get("icon") else ""
		await self.numeric("005", f"NETWORK={net} WHOX BOT=B CHANTYPES=# PREFIX=(ov)@+ CHANMODES=b,k,l,imnpst CASEMAPPING=rfc1459 NICKLEN=30{icon} :are supported by this server")
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
		earlier = channel.get("yesterday", 0)
		start = now - datetime.timedelta(minutes=(len(history) - earlier) * 3 + 5)
		# With pauses: messages a few seconds apart, the same spacing every run
		bursts = None
		if any(entry[0] == "*pause" for entry in history):
			pace = random.Random(name)
			bursts, elapsed = {}, 0
			for index, entry in enumerate(history[earlier:], earlier):
				if entry[0] == "*pause":
					elapsed += entry[1] * 60 + pace.randint(0, 40)
				else:
					elapsed += pace.choice((3, 6, 9, 14, 22, 35, 50))
					bursts[index] = elapsed
			start = now - datetime.timedelta(seconds=elapsed + 100)
		# The night before, up to a few minutes before midnight (local time)
		midnight = now.astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
		evening = (min(start, midnight) - datetime.timedelta(minutes=earlier * 4 + 6)).astimezone(datetime.timezone.utc)
		labels = {}
		for index, entry in enumerate(history):
			sender, text = entry[0], entry[1]
			if sender == "*pause":
				continue
			label = entry[2] if len(entry) > 2 else None
			reply_to = entry[3] if len(entry) > 3 else None
			msgid = f"m{next(msgids)}"
			if label:
				labels[label] = msgid
			if index < earlier:
				when = evening + datetime.timedelta(minutes=index * 4, seconds=random.randint(0, 50))
			elif bursts is not None:
				when = start + datetime.timedelta(seconds=bursts[index])
			else:
				when = start + datetime.timedelta(minutes=(index - earlier) * 3, seconds=random.randint(0, 50))
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
		if STILL:
			queue = []
		random.shuffle(queue)
		await asyncio.sleep(0 if STILL else 20)
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
		gone = {entry[1] for entry in channel["history"] if entry[0] in ("*part", "*quit")}
		people = [(self.nick, "", False)] + [(nick, prefix, nick in channel["away"]) for nick, prefix in channel["members"].items()
											   if nick not in gone]
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
	parser.add_argument("--still", action="store_true")
	parser.add_argument("--listen", action="append", default=[])
	arguments = parser.parse_args()

	global STILL
	STILL = arguments.still

	async def handler_for(port):
		async def handle(reader, writer):
			session = Session(reader, writer, NETWORKS[port], arguments.nick)
			try:
				await session.run()
			except (ConnectionResetError, BrokenPipeError):
				pass
			writer.close()
		return await asyncio.start_server(handle, ["127.0.0.1"] + arguments.listen, port)

	servers = [await handler_for(port) for port in NETWORKS]
	addresses = "/".join(["127.0.0.1"] + arguments.listen)
	print("Showcase: " + ", ".join(f"{NETWORKS[p]['network']} on {addresses}:{p}" for p in NETWORKS), flush=True)
	await asyncio.gather(*(server.serve_forever() for server in servers))


if __name__ == "__main__":
	asyncio.run(main())
