/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
* Copyright (c) 2018 - 2020 Codeux Software, LLC & respective contributors.
*       Please see Acknowledgements.pdf for additional information.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
*
*  * Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
*  * Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution.
*  * Neither the name of Textual, "Codeux Software, LLC", nor the
*    names of its contributors may be used to endorse or promote products
*    derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
* ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
* OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
* HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
* SUCH DAMAGE.
*
*********************************************************************** */

import AppKit
import SwiftUI

/* Settings › Messages: how lines look in the chat, with a sample
 on top that follows every choice */

private let timestampFormatKey = "Theme -> Timestamp Format"
private let nicknameFormatKey = "Theme -> Nickname Format"

/* The kinds of events, in the order of TPCEventKind */
let SettingsEventKeys = [
	"Event Display -> Joins",
	"Event Display -> Parts",
	"Event Display -> Quits",
	"Event Display -> Nickname Changes",
	"Event Display -> Away Changes",
	"Event Display -> Kicks",
	"Event Display -> Mode Changes",
	"Event Display -> Topic Changes"
]

private let collapseEventsKey = "Event Display -> Collapse"

/* Show, dim or hide (TPCEventDisplay); anything else reads as show */
private func eventDisplay(_ kind: Int) -> Int
{
	let value = TPCPreferencesUserDefaults.shared().integer(forKey: SettingsEventKeys[kind])

	return ((0...2).contains(value) ? value : 0)
}

/* The name of a kind of event, without the colon the old pane had */
func SettingsEventKindName(_ kind: Int) -> String
{
	SettingsText("evt-k\(kind)").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
}

/// A nickname as a format shows it: %n the name (%-9n padded), %@ the status symbol
func SettingsFormattedNickname(_ format: String, nickname: String, symbol: String) -> String
{
	var result = ""

	var characters = Substring(format)

	while let marker = characters.firstIndex(of: "%") {
		result += characters[..<marker]

		characters = characters[characters.index(after: marker)...]

		if (characters.first == "@") {
			result += symbol

			characters = characters.dropFirst()

			continue
		}

		let leftAligned = (characters.first == "-")

		if (leftAligned) {
			characters = characters.dropFirst()
		}

		let digits = characters.prefix { $0.isNumber }

		characters = characters.dropFirst(digits.count)

		if (characters.first == "n") {
			let width = (Int(digits) ?? 0)

			let padding = String(repeating: " ", count: max(0, (width - nickname.count)))

			result += (leftAligned ? (nickname + padding) : (padding + nickname))

			characters = characters.dropFirst()
		} else {
			result += "%"
		}
	}

	result += characters

	return result
}

// MARK: - Page

struct MessagesSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	/* The clock part of the time format; brackets around it are kept */
	private static let timePresets = ["%H:%M", "%H:%M:%S", "%-I:%M %p"]

	private static let classicNamePresets = ["<%@%n>", "<%n>", "%@%n:", "%n:"]
	private static let chatNamePresets = ["%@%n", "%n"]

	private static let custom = "custom"

	@State private var editingCustomTime = false
	@State private var editingCustomName = false

	private var grouped: Bool
	{
		(TDCSettingsBridge.messageGroupingStyle() == 1)
	}

	private func storeEventDisplay(_ display: Int, kinds: [Int])
	{
		store.objectWillChange.send()

		for kind in kinds {
			TPCPreferencesUserDefaults.shared().set(display, forKey: SettingsEventKeys[kind])
		}

		TDCSettingsBridge.preferenceChanged(forKey: SettingsEventKeys[kinds[0]])
	}

	var body: some View
	{
		let timeFormat = store.string(timestampFormatKey)
		let nicknameFormat = store.string(nicknameFormatKey)

		let bracketed = (timeFormat.wrappedValue.hasPrefix("[") && timeFormat.wrappedValue.hasSuffix("]") && timeFormat.wrappedValue.count >= 2)
		let timeCore = (bracketed ? String(timeFormat.wrappedValue.dropFirst().dropLast()) : timeFormat.wrappedValue)

		let timeChoice = Binding<String>(get: {
			((Self.timePresets.contains(timeCore) && editingCustomTime == false) ? timeCore : Self.custom)
		}, set: { (choice) in
			if (choice == Self.custom) {
				editingCustomTime = true
			} else {
				editingCustomTime = false

				timeFormat.wrappedValue = (bracketed ? "[\(choice)]" : choice)
			}
		})

		let namePresets = (grouped ? Self.chatNamePresets : Self.classicNamePresets)

		let nameChoice = Binding<String>(get: {
			((namePresets.contains(nicknameFormat.wrappedValue) && editingCustomName == false) ? nicknameFormat.wrappedValue : Self.custom)
		}, set: { (choice) in
			if (choice == Self.custom) {
				editingCustomName = true
			} else {
				editingCustomName = false

				nicknameFormat.wrappedValue = choice
			}
		})

		let timeChosenByStyle = TDCSettingsBridge.timestampFormatChosenByStyle
		let nameChosenByStyle = TDCSettingsBridge.nicknameFormatChosenByStyle

		let generalEvents = Binding<Int>(get: {
			let displays = Set([0, 1, 2].map { eventDisplay($0) })

			return ((displays.count == 1) ? displays.first! : -1)
		}, set: { (display) in
			storeEventDisplay(display, kinds: [0, 1, 2])
		})

		Form {
			Section {
				SettingsPageHeader(section: .messages)
			}

			Section {
				MessagesSample(grouped: grouped,
							   timeFormat: timeFormat.wrappedValue,
							   nicknameFormat: nicknameFormat.wrappedValue,
							   colors: (store.bool("DisableRemoteNicknameColorHashing").wrappedValue == false),
							   inlineSymbols: store.bool("ConversationTrackingIncludesUserModeSymbol").wrappedValue,
							   dateChanges: store.bool("DisplayEventInLogView -> Date Changes").wrappedValue,
							   marker: store.bool("AutomaticallyAddScrollbackMarker").wrappedValue,
							   plainText: store.bool("RemoveIRCTextFormatting").wrappedValue,
							   events: [eventDisplay(0), eventDisplay(1), eventDisplay(2)],
							   collapse: store.bool(collapseEventsKey).wrappedValue)
			}

			Section(SettingsText("set-mes-h1")) {
				Picker(selection: timeChoice) {
					ForEach(Self.timePresets, id: \.self) { (preset) in
						Text(TDCSettingsBridge.sampleTime(withFormat: (bracketed ? "[\(preset)]" : preset), offset: 41) ?? preset).tag(preset)
					}

					Divider()

					Text(SettingsText("set-mes-tc")).tag(Self.custom)
				} label: {
					SettingLabel(title: SettingsText("set-mes-t"),
								 help: (timeChosenByStyle ? SettingsText("set-app-c", SettingsText("set-app-ct")) : nil))
				}
				.disabled(timeChosenByStyle)

				if (timeChoice.wrappedValue == Self.custom && timeChosenByStyle == false) {
					SettingsFormatField(title: SettingsText("set-mes-tf"), help: SettingsText("set-mes-tfh"), text: timeFormat)
				}

				Picker(selection: nameChoice) {
					ForEach(namePresets, id: \.self) { (preset) in
						Text(SettingsFormattedNickname(preset, nickname: "alice", symbol: "@")).tag(preset)
					}

					Divider()

					Text(SettingsText("set-mes-tc")).tag(Self.custom)
				} label: {
					SettingLabel(title: SettingsText("set-mes-n"),
								 help: (nameChosenByStyle ? SettingsText("set-app-c", SettingsText("set-app-cn")) : SettingsText("set-mes-nh")))
				}
				.disabled(nameChosenByStyle)

				if (nameChoice.wrappedValue == Self.custom && nameChosenByStyle == false) {
					SettingsFormatField(title: SettingsText("set-mes-nf"), help: SettingsText("set-mes-nfh"), text: nicknameFormat)
				}

				SettingToggle(title: SettingsText("set-mes-c"), help: SettingsText("set-mes-ch"),
							  isOn: Binding(get: { store.bool("DisableRemoteNicknameColorHashing").wrappedValue == false },
											set: { store.bool("DisableRemoteNicknameColorHashing").wrappedValue = ($0 == false) }))

				/* Names in messages are only marked while nicknames are colored */
				let colors = (store.bool("DisableRemoteNicknameColorHashing").wrappedValue == false)

				SettingToggle(title: SettingsText("set-mes-s"), help: SettingsText(colors ? "set-mes-sh" : "set-mes-shc"),
							  isOn: store.bool("ConversationTrackingIncludesUserModeSymbol"))
					.disabled(colors == false)

				SettingToggle(title: SettingsText("set-mes-d"), help: SettingsText("set-mes-dh"),
							  isOn: store.bool("DisplayEventInLogView -> Date Changes"))

				SettingToggle(title: SettingsText("set-mes-m"), help: SettingsText("set-mes-mh"),
							  isOn: store.bool("AutomaticallyAddScrollbackMarker"))
			}

			Section(SettingsText("set-mes-h2")) {
				LabeledContent {
					SettingsEventDisplayPicker(selection: generalEvents)
				} label: {
					SettingLabel(title: SettingsText("set-mes-e"),
								 help: SettingsText((generalEvents.wrappedValue == -1) ? "set-mes-ehm" : "set-mes-eh"))
				}

				SettingToggle(title: SettingsText("set-mes-ec"), help: SettingsText("set-mes-ech"),
							  isOn: store.bool(collapseEventsKey))

				NavigationLink(value: SettingsSubpage.events) {
					SettingLabel(title: SettingsText("set-mes-eo"), help: MessagesEventsPage.summary)
				}
			}

			Section(SettingsText("set-mes-h3")) {
				SettingToggle(title: SettingsText("set-mes-f"), help: SettingsText("set-mes-fh"),
							  isOn: store.bool("RemoveIRCTextFormatting"))

				SettingToggle(title: SettingsText("set-mes-z"), help: SettingsText("set-mes-zh"),
							  isOn: store.bool("AutomaticallyFilterUnicodeTextSpam"))

				SettingToggle(title: SettingsText("set-mes-o"), help: SettingsText("set-mes-oh"),
							  isOn: store.bool("DisplayServerMessageOfTheDayOnConnect"))
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .TVCMainWindowDidReloadTheme)) { _ in
			store.objectWillChange.send()
		}
	}
}

/// A format typed in: saved on Return or when the field is left, not while typing
/// (each change redraws the chat)
struct SettingsFormatField: View
{
	let title: String
	let help: String
	let text: Binding<String>

	@State private var draft = ""
	@FocusState private var focused: Bool

	var body: some View
	{
		LabeledContent {
			TextField("", text: $draft)
				.textFieldStyle(.roundedBorder)
				.font(.body.monospaced())
				.frame(width: 180)
				.focused($focused)
				.onSubmit(save)
				.onChange(of: focused) { _, isFocused in
					if (isFocused == false) {
						save()
					}
				}
		} label: {
			SettingLabel(title: title, help: help)
		}
		.onAppear {
			draft = text.wrappedValue
		}
		.onDisappear(perform: save)
	}

	private func save()
	{
		let format = draft.trimmingCharacters(in: .whitespaces)

		if (format.isEmpty || format == text.wrappedValue) {
			return
		}

		text.wrappedValue = format
	}
}

// MARK: - Events

/// Show, dim or hide, side by side
struct SettingsEventDisplayPicker: View
{
	let selection: Binding<Int>

	var body: some View
	{
		Picker("", selection: selection) {
			Text(SettingsText("evt-d0")).tag(0)
			Text(SettingsText("evt-d1")).tag(1)
			Text(SettingsText("evt-d2")).tag(2)
		}
		.labelsHidden()
		.pickerStyle(.segmented)
		.fixedSize()
	}
}

/// Every kind of event: Settings › Messages › Other events
struct MessagesEventsPage: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	/* What the kinds besides joins, parts and quits do, in a line */
	static var summary: String
	{
		let kinds = Array(3..<SettingsEventKeys.count)

		let dimmed = kinds.filter { eventDisplay($0) == 1 }.map { SettingsEventKindName($0).lowercased() }
		let hidden = kinds.filter { eventDisplay($0) == 2 }.map { SettingsEventKindName($0).lowercased() }

		var parts: [String] = []

		if (hidden.isEmpty == false) {
			parts.append(SettingsText("set-mes-esh", ListFormatter.localizedString(byJoining: hidden)))
		}

		if (dimmed.isEmpty == false) {
			parts.append(SettingsText("set-mes-esd", ListFormatter.localizedString(byJoining: dimmed)))
		}

		return (parts.isEmpty ? SettingsText("set-mes-esa") : parts.joined(separator: " · "))
	}

	var body: some View
	{
		Form {
			Section {
				ForEach(0..<SettingsEventKeys.count, id: \.self) { (kind) in
					LabeledContent(SettingsEventKindName(kind)) {
						SettingsEventDisplayPicker(selection: Binding(get: { eventDisplay(kind) }, set: { store.integer(SettingsEventKeys[kind]).wrappedValue = $0 }))
					}
				}
			} header: {
				VStack(alignment: .leading, spacing: 3) {
					Text(SettingsText("set-mes-ep"))
						.font(.title2.weight(.semibold))
						.foregroundStyle(.primary)
						.settingsPageTitle(model: model)

					Text(SettingsText("set-mes-epl"))
						.foregroundStyle(.secondary)
				}
				.padding(.bottom, 6)
			} footer: {
				Text(SettingsText("evt-n1"))
					.foregroundStyle(.secondary)
			}

			Section {
				SettingToggle(title: SettingsText("set-mes-ec"), help: SettingsText("set-mes-ech"),
							  isOn: store.bool(collapseEventsKey))
			}
		}
		.formStyle(.grouped)
		.navigationTitle(SettingsText("set-mes-ep"))
	}
}

// MARK: - Sample

/// A few lines of a channel, as the chat shows them with the choices made
struct MessagesSample: View
{
	let grouped: Bool
	let timeFormat: String
	let nicknameFormat: String
	let colors: Bool
	let inlineSymbols: Bool
	let dateChanges: Bool
	let marker: Bool
	let plainText: Bool
	let events: [Int] // joins, parts, quits: show, dim, hide
	let collapse: Bool

	@Environment(\.colorScheme) private var colorScheme

	private struct Person
	{
		let nickname: String
		let symbol: String
		let color: Color
	}

	private let alice = Person(nickname: "alice", symbol: "@", color: Color(nsColor: .systemOrange))
	private let bob = Person(nickname: "bob", symbol: "+", color: Color(nsColor: .systemGreen))
	private let carol = Person(nickname: "carol", symbol: "", color: Color(nsColor: .systemPurple))

	private func time(_ offset: TimeInterval) -> String
	{
		let format = ((timeFormat.isEmpty) ? "%H:%M" : timeFormat)

		return (TDCSettingsBridge.sampleTime(withFormat: format, offset: offset) ?? "")
	}

	private func color(_ person: Person) -> Color
	{
		(colors ? person.color : .primary)
	}

	private func name(_ person: Person) -> String
	{
		SettingsFormattedNickname(nicknameFormat, nickname: person.nickname, symbol: person.symbol)
	}

	/* The events between alice and bob: who, and how each kind is shown */
	private var eventLines: [(text: String, dimmed: Bool)]
	{
		let all: [(kind: Int, text: String)] = [
			(0, SettingsText("set-mes-x4", "dave")),
			(0, SettingsText("set-mes-x4", "erin")),
			(1, SettingsText("set-mes-x5", "gary")),
			(2, SettingsText("set-mes-x6", "frank"))
		]

		let shown = all.filter { events[$0.kind] != 2 }

		if (shown.isEmpty) {
			return []
		}

		if (collapse == false) {
			return shown.map { ($0.text, (events[$0.kind] == 1)) }
		}

		/* One line: "dave and erin joined, gary left, frank quit" */
		var parts: [String] = []

		let joined = shown.filter { $0.kind == 0 }.count

		if (joined == 2) {
			parts.append(SettingsText("set-mes-x7", ListFormatter.localizedString(byJoining: ["dave", "erin"])))
		}

		parts += shown.filter { $0.kind != 0 }.map { $0.text }

		return [(parts.joined(separator: ", "), shown.allSatisfy { events[$0.kind] == 1 })]
	}

	private func message(_ person: Person, offset: TimeInterval, _ body: Text) -> some View
	{
		Group {
			if (grouped) {
				VStack(alignment: .leading, spacing: 1) {
					HStack(spacing: 6) {
						Text(name(person)).bold().foregroundStyle(color(person))

						Text(time(offset)).font(.system(size: 10)).foregroundStyle(.secondary)
					}

					body
				}
				.padding(.top, 4)
			} else {
				(Text(time(offset) + " ").foregroundStyle(.secondary) +
				 Text(name(person) + " ").foregroundStyle(color(person)) +
				 body)
			}
		}
	}

	var body: some View
	{
		let newBuild: Text = (plainText ?
							  Text(SettingsText("set-mes-x9")) :
							  Text(SettingsText("set-mes-x9")).bold().foregroundStyle(Color(nsColor: .systemBlue)))

		/* Names in messages are only marked while nicknames are colored */
		let mentioned = Text(((colors && inlineSymbols) ? alice.symbol : "") + alice.nickname).foregroundStyle(color(alice))

		VStack(alignment: .leading, spacing: 3) {
			if (dateChanges) {
				HStack(spacing: 8) {
					VStack { Divider() }
					Text(SettingsText("set-mes-x1")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
					VStack { Divider() }
				}
				.padding(.bottom, 2)
			}

			message(alice, offset: 0, Text(SettingsText("set-mes-x2")))

			ForEach(Array(eventLines.enumerated()), id: \.offset) { (_, line) in
				Group {
					if (grouped) {
						Text(line.text)
					} else {
						Text(time(25) + " ").foregroundStyle(.secondary) + Text(line.text)
					}
				}
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.opacity(line.dimmed ? 0.45 : 1)
			}

			if (marker) {
				HStack(spacing: 6) {
					Rectangle().fill(Color(nsColor: .systemRed)).frame(height: 1)

					Text(SettingsText("set-mes-x3")).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(nsColor: .systemRed))
				}
				.padding(.vertical, 2)
			}

			message(bob, offset: 152, Text(SettingsText("set-mes-x8")) + newBuild + Text("?"))

			message(carol, offset: 180, Text(SettingsText("set-mes-x10")) + mentioned + Text(SettingsText("set-mes-x11")))
		}
		.font(.system(size: 12))
		.lineLimit(1)
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .topLeading)
		.background((colorScheme == .dark) ? Color(white: 0.11) : Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
		}
		.animation(.easeInOut(duration: 0.15), value: [dateChanges, marker, collapse, grouped])
		.accessibilityElement(children: .combine)
		.accessibilityLabel(SettingsText("set-mes-xa"))
	}
}
