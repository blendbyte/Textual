# What's new in Textual 8

Textual 8 keeps a searchable archive of your conversations and adds replies, reactions, link cards and windows for single channels. It works with bouncers directly and has a new Settings window and first-launch setup.

## Highlights

- **Search over all past messages.** A message archive keeps what you receive, for a year by default. ⌘F searches the current channel and ⇧⌘F every server.
- **Mentions.** Every highlight from every network in one window (⌃5). Click one to go to the message.
- **Scrollback without an end.** Scrolling up past the saved lines continues into the archive.
- **Replies, reactions and deleted messages.** On networks that support them, you can answer a specific message, react to it, or delete your own.
- **Pop-out windows.** Drag a channel, private message or server console out of the server list. It gets its own window, input field and member list.
- **Bouncers.** Add a ZNC or soju bouncer once, and its networks become servers in one go.
- **Link cards.** Links to YouTube, GitHub, Wikipedia, Bluesky, Spotify and other sites show a card with a title and picture.
- **File uploads.** Paste or drop a file and send its link, through the network's upload service or your own upload address.
- **A Chat display and a new style.** Names sit above messages, grouped by sender, and Lumen is the new style for new installs.
- **New Settings and setup.** Settings looks like System Settings, with live samples. You can rerun the setup from Help › Setup Assistant….

## Chat view

- Choose Chat or Classic, and Compact, Standard or Roomy spacing, in Settings › Appearance.
- Joins, parts and quits in a row collapse into one line, and each kind of event can be shown, dimmed or hidden. A netsplit is one line per channel.
- A message the server refuses stays visible, dimmed, with "Not sent:", the reason, and Resend and Delete.
- ⌥↑ moves into the messages for keyboard use: R replies, E reacts, Delete deletes.
- You can see who is typing. Others can see you type too, unless you turn off "Let others see when I'm typing" in Settings › Typing.
- A private message's topic bar lists the channels you share with that person.
- Joining big channels and displaying busy ones is faster.

## Message archive and search

- Narrow a search with `"exact words"`, `from:`, `in:`, `before:`, `after:`, `during:`, `has:link` and `mentions:me`.
- A result older than the scrollback opens in its conversation from the archive, even for a channel you've since deleted.
- Settings › History sets the keep period, from 14 days to forever, or turns the archive off. Textual asks before anything is deleted.
- A server or channel can be left out in its properties, and Import… adds your old text logs.

## Inline previews

- Cards cover YouTube, Vimeo, Dailymotion, X, xkcd, GitHub, Reddit, Wikipedia, Bluesky, Spotify, SoundCloud, Bandcamp and Giphy. Other web pages show their title, description and picture.
- Settings › Previews turns each service on or off, and can limit previews by site.
- Images open in their own window. YouTube videos do too, in YouTube's privacy-enhanced player.
- Previews use HTTPS only, so links to plain-HTTP media are no longer previewed. They go through your server's proxy and never reach addresses on your local network.
- New installs show previews. After a Textual 7 import, they stay off unless you had them on.

## Bouncers

- Server › Add Bouncer… checks the login step by step and lists the bouncer's networks to add.
- View › Group Servers by Bouncer puts each bouncer's networks under a heading you can fold, drag, connect or disconnect.
- Edit Bouncer… changes the address or login for all its networks, and can log in with a certificate instead of keeping your password.
- Textual tells you when networks are added to or removed from your bouncer. It never adds or removes networks there; certificate login sets up one certificate on the bouncer, and only when you choose it.

## IRCv3

These depend on the network. Where a network doesn't pass on replies or reactions, the console says so once and the buttons aren't offered.

- `draft/chathistory`: fetches messages you missed while disconnected.
- `draft/event-playback`: also shows the joins, parts and topic changes you missed.
- `draft/read-marker`: shares what you've read with your other clients.
- `+reply`, `+draft/react`: replies and reactions.
- `draft/message-redaction`: deletes a message for everyone.
- `draft/multiline`: sends several lines as one message.
- `labeled-response`: shows a command's answer in the window where you typed it.
- `draft/FILEHOST`: uploads files to the network.
- `draft/ICON`: shows the network's logo.
- `draft/account-registration`: creates an account with `/register` and `/verify`.
- `draft/pre-away`: keeps you away across a dropped connection.
- `account-notify`, `extended-join`, `setname`: keep accounts and real names up to date.
- STS: keeps a server on encrypted connections once it has asked for them.
- SASL SCRAM and ECDSA-NIST256P-CHALLENGE: log in without sending your password, or with a key.

## Input field

- ⇧↩ starts a new line. Each channel keeps its own unsent text when you switch away.
- Suggestions open while you type `@`, `#`, `/` and `:` for nicknames, channels, commands and emoji.
- Markdown turns `**bold**`, `_italic_`, `` `code` `` and `||spoiler||` into IRC formatting. ⌥⇧↩ sends a message exactly as typed.
- Suggestions and Markdown are on for new installs and off after a Textual 7 import.
- The long-paste warning offers Send as Link, and `/alias` creates your own commands.

## Windows

- A unified title bar: the server list's and member list's color runs up into it, for everyone.
- ⌘D finds menu commands as well as channels.
- The Browse Channels and File Transfers windows are rebuilt and say in plain words what they're doing.
- VoiceOver reads more of both lists.

## Settings

- Settings, Server Properties and Channel Properties share one look, with an explanation under each setting.
- Mute a channel, conversation or network with one click or `/mute`. Muting every sound is now `/mute all`.
- Highlight words can be limited to certain channels or people and have their own sound. A message naming 5 or more people no longer counts as a highlight, and you can change the number.
- Spoken notifications use the voice and rate in System Settings and no longer wait for other apps to finish speaking.
- The Caffeine extension is now a built-in setting: "Keep the Mac awake while connected" in Settings › General. Your choice carries over.

## Connections and security

- Servers can be reached at `ws://` and `wss://` addresses.
- HTTPS proxies are supported, and HTTP proxies can have a login. A failed proxy is never bypassed.
- Your NickServ password goes only to the network's services.

## Setup

- Newcomers get a short explanation of IRC and suggested networks by interest and language. Everyone else gets the whole list, with search.
- Notifications are explained before macOS asks about them.

## Upgrading from Textual 7

**Download Textual 8 from textualapp.com.** Textual 7 can't update itself to Textual 8. You need macOS 14 or later, on Apple silicon or Intel.

**Importing.** At first launch, or later with File › Import Settings from Textual 7…, Textual brings over your settings, servers, scrollback, styles, extensions and license. Older versions and the Mac App Store version can be imported too. Your style, font and other choices stay as they were.

Not imported: inline media modules, OTR keys (Textual offers to save a copy) and AppleScripts (Textual shows you where they are). You may need to choose your transcript and download folders again.

**Your license.** A Textual 7 license gets you an upgrade. It doesn't register Textual 8 by itself. The licensing server decides whether your upgrade is free or at a reduced price. A free upgrade takes one click. A paid one opens in your browser, and the emailed link activates it. A Textual 7 purchase from the Mac App Store doesn't get an upgrade price.

**Keychain prompts.** macOS treats Textual 8 as a new app, so it may ask more than once for each saved password. Enter your Mac's login password and choose Always Allow, which avoids repeats.

**Textual 7 stays as it was.** The import changes nothing in Textual 7, and both versions run side by side. Its data stays until you choose File › Remove Textual 7 Data…, offered only after an import where nothing failed or was kept back. One exception: clearing a saved password in Textual 8 also removes Textual 7's copy where macOS allows it.

## Licensing

- A license key works on 2 Macs at a time.
- Activations don't expire. Textual checks about once a month, and only a confirmed answer that the Mac was freed or the key revoked ends the license on that Mac. No network or a server outage changes nothing.
- To move a license, deactivate one Mac in Textual › Manage License…. If both Macs are in use, Textual lists them and moves the key from the one you choose, up to twice in 30 days. That Mac returns to the trial.
- Textual copied to a new Mac, or moved with Migration Assistant, activates there with the same key by itself while the key has a Mac free.
- Each Mac gets one 30-day trial, with no account and no card.
- Lost your key? It's in your purchase email. If you upgraded, entering your Textual 7 key shows it again. Otherwise, use Contact Support in Manage License.

## Removed

- **OTR.** End-to-end encrypted private messages through OTR are gone, because its libraries were no longer maintained. Nothing else about your connection changes: it stays encrypted with TLS. `/umsg`, `/ume` and `/unotice` are gone with it.
- **Blowfish (FiSH).** Removed because it is not secure.
- **Old Blowfish and Wiki-style Link Parser extensions.** They aren't loaded or installed. Textual says so once and offers to move them to the Trash.
- **SOCKS4 proxies.** Existing ones are tried as SOCKS5.
- **`.mediaPlugin` add-on modules.** Previews are built in, and others aren't loaded. Textual offers to move any it finds to the Trash.
- **The Textual Extras installer and `/getscripts`.** Without a script, `/np` and `/spotify` now go to the server.
- **The Highlight List, the Find pop-up and the old Preferences window.** Replaced by Mentions, the search panel and Settings.
- **The three buttons left of the input field.** Each is in the menus.
- **Textual 7's preview limit settings.** Replaced by Settings › Previews.
- **Previews from some services**, including those that are gone or only answer over plain HTTP, such as TwitPic and Instagram.

## Fixes

- Crashes from a far-future timestamp, a `JOIN` with no channel name, a malformed `PREFIX`, a `WALLOPS` with no text and a damaged server list.
- Scrollback is no longer lost when macOS clears its caches, when it can't be opened at launch, when a save fails on a full disk, or when a chat view crashes.
- Busy channels keep following new lines, and scrolling up no longer pulls you back to the bottom.
- Channel views no longer stay blank with many servers and channels.
- On macOS 27, lines loaded while scrolling no longer arrive shuffled or twice.
- Passwords and channel keys no longer get lost when saving.
- Quitting no longer waits forever on a server or a save.
- File transfers no longer hang on a file of the same name.
