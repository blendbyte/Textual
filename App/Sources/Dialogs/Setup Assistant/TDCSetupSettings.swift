/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
* Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

/* The choices of the setup window. Each is written as it is made, so the
 window itself and its pictures follow, and closing keeps what was chosen.
 After an import every choice starts on the imported value. */

// MARK: - Look

enum SetupDisplay
{
	case chat
	case classic
}

final class SetupLookModel: ObservableObject
{
	private static let themeKey = "Theme -> Name"
	private static let fontNameKey = "Theme -> Font Name"
	static let fontSizeKey = "Theme -> Font Size"

	static let spacingKey = "Theme -> Message Spacing"

	private static let nicknameFormatKey = "Theme -> Nickname Format"
	private static let timestampFormatKey = "Theme -> Timestamp Format"

	/* The style we suggest, and the system font that comes with it */
	static let recommendedStyle = "Lumen"
	private static let recommendedFontSize = 13.0

	let upgrade: Bool

	@Published private(set) var display: SetupDisplay
	@Published private(set) var themeName: String?

	/* Textual 7's, to go back to */
	let importedThemeName: String?
	private let importedFontName: String?
	private let importedFontSize: Double
	private let importedGroupingStyle: Int
	private let importedNicknameFormat: Any?
	private let importedTimestampFormat: Any?

	/* For the question when someone chose their own time and name formats */
	private weak var window: NSWindow?

	private var defaults: TPCPreferencesUserDefaults
	{
		TPCPreferencesUserDefaults.shared()
	}

	init(upgrade: Bool, window: NSWindow?)
	{
		let defaults = TPCPreferencesUserDefaults.shared()

		self.upgrade = upgrade
		self.window = window

		let themeName = defaults.string(forKey: Self.themeKey)

		self.themeName = themeName

		importedThemeName = themeName
		importedFontName = defaults.string(forKey: Self.fontNameKey)
		importedFontSize = defaults.double(forKey: Self.fontSizeKey)
		importedGroupingStyle = TDCSettingsBridge.messageGroupingStyle()
		importedNicknameFormat = defaults.object(forKey: Self.nicknameFormatKey)
		importedTimestampFormat = defaults.object(forKey: Self.timestampFormatKey)

		display = ((importedGroupingStyle == 1) ? .chat : .classic)

		if (upgrade == false) {
			choose(display: .chat)
		}
	}

	/* A style may only have the Classic display */
	var chosenStyleHasChat: Bool
	{
		guard let style = selectedStyle?.settingsStyle else {
			return true
		}

		return TDCSettingsBridge.styleSupportsChatDisplayNamed(style.name, location: style.location)
	}

	var styles: [SetupStyle]
	{
		let all = TDCSettingsBridge.styles.map { SetupStyle(entry: $0) }

		/* Ours first, then theirs, then the others as Settings lists them */
		return all.sorted { first, second in
			rank(of: first) < rank(of: second)
		}
	}

	private func rank(of style: SetupStyle) -> Int
	{
		if (isRecommended(style)) {
			return 0
		}

		return (isTheirs(style) ? 1 : 2)
	}

	func isRecommended(_ style: SetupStyle) -> Bool
	{
		(style.settingsStyle.bundled && style.settingsStyle.name == Self.recommendedStyle)
	}

	func isTheirs(_ style: SetupStyle) -> Bool
	{
		(upgrade && style.filename == importedThemeName)
	}

	func isSelected(_ style: SetupStyle) -> Bool
	{
		(style.filename == themeName)
	}

	/* Lumen brings the new look along. After an import, any other style keeps
	 the imported font and display, and their own style all of what they had. */
	func choose(style: SetupStyle)
	{
		TDCSettingsBridge.selectStyleNamed(style.settingsStyle.name, location: style.settingsStyle.location)

		themeName = defaults.string(forKey: Self.themeKey)

		guard upgrade else {
			choose(display: (chosenStyleHasChat ? .chat : .classic))

			return
		}

		if (isRecommended(style)) {
			defaults.set(nil, forKey: Self.fontNameKey)
			defaults.set(Self.recommendedFontSize, forKey: Self.fontSizeKey)

			choose(display: .chat)
		} else {
			restoreImportedFontAndDisplay()

			if (chosenStyleHasChat == false && display == .chat) {
				choose(display: .classic)
			}
		}
	}

	func choose(display: SetupDisplay)
	{
		self.display = display

		TDCSettingsBridge.setMessageGroupingStyle(((display == .chat) ? 1 : 0), in: window)
	}

	private func restoreImportedFontAndDisplay()
	{
		defaults.set(importedFontName, forKey: Self.fontNameKey)
		defaults.set(importedFontSize, forKey: Self.fontSizeKey)

		/* As it was, without asking about the formats */
		TDCSettingsBridge.setMessageGroupingStyle(importedGroupingStyle, in: nil)

		defaults.set(importedNicknameFormat, forKey: Self.nicknameFormatKey)
		defaults.set(importedTimestampFormat, forKey: Self.timestampFormatKey)

		display = ((importedGroupingStyle == 1) ? .chat : .classic)
	}

	/// Use Recommended or Keep Everything
	func applyRecommended()
	{
		if (upgrade) {
			defaults.set(importedThemeName, forKey: Self.themeKey)

			themeName = importedThemeName

			restoreImportedFontAndDisplay()
		} else {
			defaults.set(nil, forKey: Self.themeKey)
			defaults.set(nil, forKey: Self.fontNameKey)

			themeName = defaults.string(forKey: Self.themeKey)

			choose(display: .chat)

			defaults.set(Self.recommendedFontSize, forKey: Self.fontSizeKey)
			defaults.set(1, forKey: Self.spacingKey)
			defaults.set(0, forKey: "Appearance")

			TDCSettingsBridge.preferenceChanged(forKey: "Appearance")
		}

		objectWillChange.send()
	}

	/// The chat's font at this size, for the samples
	func chatFont(size: Double) -> Font
	{
		if let name = defaults.string(forKey: Self.fontNameKey), name.hasPrefix(".") == false, name.hasPrefix("-") == false {
			return .custom(name, size: size)
		}

		return .system(size: size)
	}

	/// The chosen style
	var selectedStyle: SetupStyle?
	{
		styles.first { isSelected($0) }
	}

	/// The bundled styles follow the spacing setting; someone's own may not
	var styleFollowsSpacing: Bool
	{
		(selectedStyle?.settingsStyle.bundled ?? true)
	}
}

/// A style as Settings lists it, with the value it's saved under
struct SetupStyle: Identifiable
{
	let settingsStyle: SettingsStyle
	let filename: String

	var id: String { settingsStyle.id }

	init(entry: [String: Any])
	{
		settingsStyle = SettingsStyle(name: (entry["name"] as? String ?? ""),
									  location: (entry["location"] as? Int ?? 0),
									  displayName: (entry["displayName"] as? String ?? ""),
									  bundled: (entry["bundled"] as? Bool ?? false))

		filename = (entry["filename"] as? String ?? "")
	}
}

struct SetupStyleStep: View
{
	@ObservedObject var model: SetupLookModel

	@Environment(\.colorScheme) private var colorScheme

	var body: some View
	{
		VStack(spacing: 8) {
			SetupHeader(title: SetupText("sa-y-title"), lead: (model.upgrade ? SetupText("sa-y-lead-u") : SetupText("sa-y-lead"))) {
				SetupSymbol(symbol: "paintbrush.fill", color: .purple)
			}

			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), alignment: .leading, spacing: 12) {
				ForEach(model.styles) { style in
					card(style)
				}
			}
		}
	}

	private func card(_ style: SetupStyle) -> some View
	{
		let selected = model.isSelected(style)

		return Button {
			model.choose(style: style)
		} label: {
			VStack(alignment: .leading, spacing: 3) {
				StylePreviewImage(style: style.settingsStyle, dark: (colorScheme == .dark))
					.frame(height: 82)
					.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
					.overlay {
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.strokeBorder((selected ? Color.accentColor : Color.primary.opacity(0.12)), lineWidth: (selected ? 3 : 1))
					}
					.padding(.bottom, 2)

				HStack(spacing: 5) {
					Text(style.settingsStyle.displayName)
						.font(.callout.weight(.semibold))

					if (model.isRecommended(style)) {
						badge(SetupText("sa-y-rec"), color: .accentColor)
					}

					if (model.isTheirs(style)) {
						badge(SetupText("sa-y-yours"), color: .secondary)
					}
				}

				Text(style.settingsStyle.summary ?? SettingsText("set-app-own"))
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(2)
					.fixedSize(horizontal: false, vertical: true)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
	}

	private func badge(_ text: String, color: Color) -> some View
	{
		Text(text)
			.font(.system(size: 9.5, weight: .semibold))
			.foregroundStyle(color)
			.padding(.horizontal, 4)
			.padding(.vertical, 1)
			.overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.6), lineWidth: 1))
	}
}

/// Text sizes, as Settings' menus do: the current size is in the menu too
private let setupTextSizes: [(size: Double, name: String)] = [
	(12, "sa-l-s12"),
	(13, "sa-l-s13"),
	(15, "sa-l-s15"),
	(17, "sa-l-s17")
]

struct SetupLookStep: View
{
	@ObservedObject var model: SetupLookModel
	@ObservedObject private var store = SettingsStore.shared

	@Environment(\.colorScheme) private var colorScheme

	var body: some View
	{
		VStack(spacing: 14) {
			SetupHeader(title: SetupText("sa-l-title"), lead: SetupText("sa-l-lead")) {
				SetupSymbol(symbol: "text.bubble.fill", color: .blue)
			}

			if (model.chosenStyleHasChat) {
				HStack(alignment: .top, spacing: 16) {
					card(.chat, title: SetupText("sa-l-chat"), text: SetupText("sa-l-chat-d")) {
						sample(grouped: true)
					}

					card(.classic, title: SetupText("sa-l-classic"), text: SetupText("sa-l-classic-d")) {
						sample(grouped: false)
					}
				}
			} else {
				card(.classic, title: SetupText("sa-l-classic"), text: SetupText("sa-l-classic-only")) {
					sample(grouped: false)
				}
				.frame(maxWidth: 320)
			}

			SetupGroup {
				SetupControlRow(divider: false, title: SetupText("sa-l-ap-t"), text: SetupText("sa-l-ap-d")) {
					Picker("", selection: store.integer("Appearance")) {
						ForEach([0, 1, 2], id: \.self) { value in
							Text(SettingsText("set-app-a\(value)")).tag(value)
						}
					}
					.pickerStyle(.segmented)
					.labelsHidden()
					.fixedSize()
				}

				SetupControlRow(title: SetupText("sa-l-size-t"), text: SetupText("sa-l-size-d")) {
					Picker("", selection: store.double(SetupLookModel.fontSizeKey)) {
						let current = store.double(SetupLookModel.fontSizeKey).wrappedValue

						if (setupTextSizes.contains { $0.size == current } == false) {
							Text(SetupText("sa-l-sother", Int(current))).tag(current)
						}

						ForEach(setupTextSizes, id: \.size) { entry in
							Text(SetupText(entry.name)).tag(entry.size)
						}
					}
					.labelsHidden()
					.fixedSize()
				}

				if (model.styleFollowsSpacing) {
					SetupControlRow(title: SetupText("sa-l-sp-t"), text: SetupText("sa-l-sp-d")) {
						Picker("", selection: store.integer(SetupLookModel.spacingKey)) {
							Text(SetupText("sa-l-sp0")).tag(0)
							Text(SetupText("sa-l-sp1")).tag(1)
							Text(SetupText("sa-l-sp2")).tag(2)
						}
						.pickerStyle(.segmented)
						.labelsHidden()
						.fixedSize()
					}
				}
			}
		}
	}

	/* Follows the text size and spacing below; Choose a style shows the styles themselves */
	private func sample(grouped: Bool) -> some View
	{
		SetupMessagesSample(grouped: grouped,
							font: model.chatFont(size: store.double(SetupLookModel.fontSizeKey).wrappedValue),
							spacing: store.integer(SetupLookModel.spacingKey).wrappedValue)
	}

	private func card<Picture: View>(_ display: SetupDisplay, title: String, text: String, @ViewBuilder picture: @escaping () -> Picture) -> some View
	{
		let selected = (model.display == display)

		return Button {
			model.choose(display: display)
		} label: {
			VStack(spacing: 6) {
				picture()
					.frame(height: 150)
					.frame(maxWidth: .infinity)
					.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
					.overlay {
						RoundedRectangle(cornerRadius: 9, style: .continuous)
							.strokeBorder((selected ? Color.accentColor : Color.primary.opacity(0.12)), lineWidth: (selected ? 3 : 1))
					}

				Text(title)
					.fontWeight(selected ? .semibold : .regular)

				Text(text)
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.frame(maxWidth: .infinity)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(title + ", " + text)
		.accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
	}
}

/// A few lines of chat in the chosen font and spacing: names above the
/// messages (Chat), or a time and name on every line (Classic)
struct SetupMessagesSample: View
{
	let grouped: Bool
	let font: Font
	let spacing: Int

	@Environment(\.colorScheme) private var colorScheme

	/* Between lines, and more where the speaker changes */
	private var lineGap: CGFloat
	{
		[CGFloat(1), 3, 6][min(max(spacing, 0), 2)]
	}

	var body: some View
	{
		/* Pinned to the top: lines that don't fit are cut off at the bottom */
		Color.clear.overlay(alignment: .topLeading) {
			lines
		}
		.background((colorScheme == .dark) ? Color(white: 0.13) : Color.white)
		.clipped()
	}

	private var lines: some View
	{
		VStack(alignment: .leading, spacing: lineGap) {
			if (grouped) {
				header("alice", .blue, "19:03")
				message("Good morning, everyone")
				message("A second line from alice")
				header("bob", .pink, "19:04")
					.padding(.top, (lineGap * 2))
				message("Morning!")
				header("carol", .green, "19:05")
					.padding(.top, (lineGap * 2))
				message("anyone tried the new build?")
			} else {
				line("19:03", "alice", .blue, "Good morning, everyone")
				line("19:03", "alice", .blue, "A second line from alice")
				line("19:04", "bob", .pink, "Morning!")
				line("19:05", "carol", .green, "anyone tried the new build?")
				line("19:05", "bob", .pink, "yes, works here")
				line("19:06", "alice", .blue, "great, thanks")
				line("19:06", "carol", .green, "see you later")
			}
		}
		.font(font)
		.lineLimit(1)
		.padding(10)
	}

	private func header(_ name: String, _ color: Color, _ time: String) -> some View
	{
		HStack(spacing: 5) {
			Text(name).fontWeight(.semibold).foregroundStyle(color)
			Text(time).foregroundStyle(.secondary)
		}
	}

	private func message(_ text: String) -> some View
	{
		Text(text).foregroundStyle(.primary.opacity(0.85))
	}

	private func line(_ time: String, _ name: String, _ color: Color, _ text: String) -> some View
	{
		HStack(spacing: 5) {
			Text(time).foregroundStyle(.secondary)
			Text(name).fontWeight(.semibold).foregroundStyle(color)
			Text(text).foregroundStyle(.primary.opacity(0.85))
		}
	}
}

/// A title with an explanation under it and a control beside it
struct SetupControlRow<Control: View>: View
{
	var divider = true
	let title: String
	let text: String
	@ViewBuilder let control: () -> Control

	var body: some View
	{
		VStack(spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
					Text(title)

					Text(text)
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				control()
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
		}
	}
}

// MARK: - Chat, Privacy and updates

/// What the rows of these steps change, and how to go back
final class SetupChoicesModel
{
	private static let eventKeys = ["Event Display -> Joins", "Event Display -> Parts", "Event Display -> Quits",
									"Event Display -> Nickname Changes", "Event Display -> Kicks", "Event Display -> Mode Changes",
									"Event Display -> Collapse"]
	static let completionKeys = ["Input Completion -> Nicknames", "Input Completion -> Channels", "Input Completion -> Commands", "Input Completion -> Emoji"]
	static let markdownKey = "Input -> Markdown Formatting"
	static let placementKey = "InputFieldPlacement"
	static let arrangementKey = "ChannelViewArrangement"
	static let previewsKey = "DisplayEventInLogView -> Inline Media"
	static let cardsKey = "InlineMediaWebPageCards"
	static let archiveKey = "Message Archive -> Keep Period"
	static let checksKey = "SUEnableAutomaticChecks"
	static let installsKey = "SUAutomaticallyUpdate"

	private static var allKeys: [String]
	{
		eventKeys + completionKeys + [markdownKey, placementKey, arrangementKey, previewsKey, cardsKey, archiveKey, checksKey, installsKey]
	}

	let upgrade: Bool

	/* As they were when these steps first showed: what Textual 7 had, after an import */
	private let stored: [String: Any]
	private let storedEvents: Int

	private var defaults: TPCPreferencesUserDefaults
	{
		TPCPreferencesUserDefaults.shared()
	}

	init(upgrade: Bool)
	{
		self.upgrade = upgrade

		let defaults = TPCPreferencesUserDefaults.shared()

		var stored: [String: Any] = [:]

		for key in Self.allKeys {
			if let value = defaults.object(forKey: key) {
				stored[key] = value
			}
		}

		self.stored = stored

		storedEvents = Int(TPCPreferences.generalEventDisplay().rawValue)
	}

	/// Keep Everything goes back to what was imported; Use Recommended to what a new install starts with, which is what's stored until something is chosen
	func applyRecommended()
	{
		for key in Self.allKeys {
			defaults.set(stored[key], forKey: key)
		}
	}

	// MARK: What Textual 7 had

	private func storedInteger(_ key: String) -> Int
	{
		(stored[key] as? NSNumber)?.intValue ?? 0
	}

	private func storedBool(_ key: String) -> Bool
	{
		(stored[key] as? NSNumber)?.boolValue ?? false
	}

	private func onOff(_ value: Bool) -> String
	{
		SetupText(value ? "sa-v-on" : "sa-v-off")
	}

	var importedEvents: String
	{
		SetupText("sa-c-ev\(storedEvents)")
	}

	var importedSuggestions: String
	{
		onOff(Self.completionKeys.contains { storedBool($0) })
	}

	var importedMarkdown: String
	{
		onOff(storedBool(Self.markdownKey))
	}

	var importedPlacement: String
	{
		SetupText("sa-c-inp\(storedInteger(Self.placementKey))")
	}

	var importedArrangement: String
	{
		SetupText("sa-c-arr\(storedInteger(Self.arrangementKey))")
	}

	var importedPreviews: String
	{
		onOff(storedBool(Self.previewsKey))
	}
}

/// One row of these steps: its control on the left, what it does on the right
struct SetupExplainedRow: Identifiable
{
	let id: String
	let title: String
	let help: String
	var isNew = false
	var was: String?
	let control: AnyView
	let sample: AnyView
	let explanation: [String]
}

/// Rows on the left; the selected one's example and explanation on the right
struct SetupExplainedRows: View
{
	let rows: [SetupExplainedRow]

	@State private var selectedID: String?

	private var selected: SetupExplainedRow?
	{
		rows.first { $0.id == selectedID } ?? rows.first
	}

	var body: some View
	{
		HStack(alignment: .top, spacing: 14) {
			SetupGroup {
				ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
					rowView(row, divider: (index > 0))
				}
			}

			if let row = selected {
				VStack(alignment: .leading, spacing: 8) {
					row.sample
						.frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
						.background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(nsColor: .textBackgroundColor)))
						.overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))

					Text(row.title)
						.fontWeight(.semibold)
						.padding(.top, 2)

					ForEach(row.explanation, id: \.self) { paragraph in
						Text(paragraph)
							.font(.callout)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.padding(10)
				.frame(width: 250, alignment: .leading)
				.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
				.accessibilityElement(children: .combine)
			}
		}
		/* The same height for every row, so the step doesn't move as they are clicked */
		.frame(height: 330, alignment: .top)
	}

	private func rowView(_ row: SetupExplainedRow, divider: Bool) -> some View
	{
		VStack(spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			HStack(spacing: 10) {
				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 5) {
						Text(row.title)

						if (row.isNew) {
							Text(SetupText("sa-v-new"))
								.font(.system(size: 9.5, weight: .bold))
								.foregroundStyle(Color.accentColor)
						}
					}

					Text(row.help)
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)

					if let was = row.was {
						Text(SetupText("sa-v-was", was))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				row.control
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.contentShape(Rectangle())
			.background((selected?.id == row.id) ? Color.accentColor.opacity(0.13) : Color.clear)
			.simultaneousGesture(TapGesture().onEnded { selectedID = row.id })
		}
	}
}

struct SetupChatStep: View
{
	let model: SetupChoicesModel

	@ObservedObject private var store = SettingsStore.shared

	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-c-title"), lead: SetupText("sa-c-lead")) {
				SetupSymbol(symbol: "text.bubble.fill", color: .blue)
			}

			SetupExplainedRows(rows: [eventsRow, suggestionsRow, markdownRow, placementRow, arrangementRow])
		}
	}

	private var upgrade: Bool { model.upgrade }

	private var events: Binding<Int>
	{
		store.value(get: {
			Int(TPCPreferences.generalEventDisplay().rawValue)
		}, set: { value in
			TPCPreferences.setGeneralEventDisplay(TXGeneralEventDisplay(rawValue: UInt(value)) ?? .collapse)
		})
	}

	private var suggestions: Binding<Bool>
	{
		store.value(get: {
			SetupChoicesModel.completionKeys.contains { TPCPreferencesUserDefaults.shared().bool(forKey: $0) }
		}, set: { value in
			for key in SetupChoicesModel.completionKeys {
				TPCPreferencesUserDefaults.shared().set(value, forKey: key)
			}
		})
	}

	private var eventsRow: SetupExplainedRow
	{
		let choice = events.wrappedValue

		return SetupExplainedRow(id: "events",
								 title: SetupText("sa-c-ev-t"),
								 help: SetupText("sa-c-ev-d"),
								 was: (upgrade ? model.importedEvents : nil),
								 control: AnyView(Picker("", selection: events) {
									Text(SetupText("sa-c-ev0")).tag(0)
									Text(SetupText("sa-c-ev1")).tag(1)
									Text(SetupText("sa-c-ev2")).tag(2)
								 }
								 .pickerStyle(.segmented).labelsHidden().fixedSize()),
								 sample: AnyView(SetupEventsSample(choice: choice)),
								 explanation: [SetupText("sa-c-ev-x1"), SetupText("sa-c-ev-x2")])
	}

	private var suggestionsRow: SetupExplainedRow
	{
		let on = suggestions.wrappedValue

		return SetupExplainedRow(id: "suggestions",
								 title: SetupText("sa-c-sug-t"),
								 help: SetupText("sa-c-sug-d"),
								 isNew: true,
								 was: (upgrade ? model.importedSuggestions : nil),
								 control: AnyView(Toggle("", isOn: suggestions).toggleStyle(.switch).labelsHidden().controlSize(.small)),
								 sample: AnyView(SetupSuggestionsSample(on: on)),
								 explanation: [SetupText("sa-c-sug-x1")])
	}

	private var markdownRow: SetupExplainedRow
	{
		let binding = store.bool(SetupChoicesModel.markdownKey)
		let on = binding.wrappedValue

		return SetupExplainedRow(id: "markdown",
								 title: SetupText("sa-c-md-t"),
								 help: SetupText("sa-c-md-d"),
								 isNew: true,
								 was: (upgrade ? model.importedMarkdown : nil),
								 control: AnyView(Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden().controlSize(.small)),
								 sample: AnyView(SetupMarkdownSample(on: on)),
								 explanation: [SetupText("sa-c-md-x1"), SetupText("sa-c-md-x2")])
	}

	private var placementRow: SetupExplainedRow
	{
		let binding = store.integer(SetupChoicesModel.placementKey)
		let chatOnly = (binding.wrappedValue == 1)

		return SetupExplainedRow(id: "placement",
								 title: SetupText("sa-c-inp-t"),
								 help: SetupText("sa-c-inp-d"),
								 was: (upgrade ? model.importedPlacement : nil),
								 control: AnyView(Picker("", selection: binding) {
									Text(SetupText("sa-c-inp0")).tag(0)
									Text(SetupText("sa-c-inp1")).tag(1)
								 }
								 .labelsHidden().fixedSize()),
								 sample: AnyView(InputFieldSketch(underChatOnly: chatOnly).frame(height: 100).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))),
								 explanation: [SetupText("sa-c-inp-x1")])
	}

	private var arrangementRow: SetupExplainedRow
	{
		let binding = store.integer(SetupChoicesModel.arrangementKey)
		let sideBySide = (binding.wrappedValue == 1)

		return SetupExplainedRow(id: "arrangement",
								 title: SetupText("sa-c-arr-t"),
								 help: SetupText("sa-c-arr-d"),
								 was: (upgrade ? model.importedArrangement : nil),
								 control: AnyView(Picker("", selection: binding) {
									Text(SetupText("sa-c-arr0")).tag(0)
									Text(SetupText("sa-c-arr1")).tag(1)
								 }
								 .labelsHidden().fixedSize()),
								 sample: AnyView(ArrangementSketch(sideBySide: sideBySide).frame(height: 100).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))),
								 explanation: [SetupText("sa-c-arr-x1")])
	}
}

struct SetupPrivacyStep: View
{
	let model: SetupChoicesModel

	@ObservedObject private var store = SettingsStore.shared

	private static let keepPeriods = [-1, 14, 30, 90, 180, 365, 730, 0]

	/* Debug builds have no Sparkle but show the row, so it can be looked at */
	private var showsUpdates: Bool
	{
#if DEBUG
		true
#else
		TDCSettingsBridge.updatesAvailable
#endif
	}

	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-p-title"), lead: SetupText("sa-p-lead")) {
				SetupSymbol(symbol: "hand.raised.fill", color: .gray)
			}

			SetupExplainedRows(rows: rows)
		}
	}

	private var rows: [SetupExplainedRow]
	{
		var rows = [previewsRow]

		if (store.bool(SetupChoicesModel.previewsKey).wrappedValue) {
			rows.append(cardsRow)
		}

		rows.append(archiveRow)

		if (showsUpdates) {
			rows.append(updatesRow)
		}

		return rows
	}

	private var previewsRow: SetupExplainedRow
	{
		let binding = store.bool(SetupChoicesModel.previewsKey)
		let on = binding.wrappedValue

		return SetupExplainedRow(id: "previews",
								 title: SetupText("sa-p-prev-t"),
								 help: SetupText("sa-p-prev-d"),
								 was: (model.upgrade ? model.importedPreviews : nil),
								 control: AnyView(Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden().controlSize(.small)),
								 sample: AnyView(SetupPreviewSample(on: on)),
								 explanation: [SetupText("sa-p-prev-x1"), SetupText("sa-p-prev-x2")])
	}

	private var cardsRow: SetupExplainedRow
	{
		let binding = store.bool(SetupChoicesModel.cardsKey)
		let on = binding.wrappedValue

		return SetupExplainedRow(id: "cards",
								 title: SetupText("sa-p-card-t"),
								 help: SetupText("sa-p-card-d"),
								 control: AnyView(Toggle("", isOn: binding).toggleStyle(.switch).labelsHidden().controlSize(.small)),
								 sample: AnyView(SetupCardSample(on: on)),
								 explanation: [SetupText("sa-p-card-x1")])
	}

	private var archiveRow: SetupExplainedRow
	{
		let binding = store.integer(SetupChoicesModel.archiveKey)

		return SetupExplainedRow(id: "archive",
								 title: SetupText("sa-p-arc-t"),
								 help: SetupText("sa-p-arc-d"),
								 isNew: true,
								 control: AnyView(Picker("", selection: binding) {
									ForEach(Self.keepPeriods, id: \.self) { period in
										Text(TDCSettingsBridge.title(forMessageArchiveKeepPeriod: period)).tag(period)
									}
								 }
								 .labelsHidden().fixedSize()),
								 sample: AnyView(SetupArchiveSample(off: (binding.wrappedValue == -1))),
								 explanation: [SetupText("sa-p-arc-x1")])
	}

	/* Sparkle reads these when it starts, after setup; it has them from here on */
	private var updateMode: Binding<Int>
	{
		store.value(get: {
			let defaults = TPCPreferencesUserDefaults.shared()

			if ((defaults.object(forKey: SetupChoicesModel.checksKey) as? NSNumber)?.boolValue == false) {
				return 2
			}

			return (defaults.bool(forKey: SetupChoicesModel.installsKey) ? 0 : 1)
		}, set: { mode in
			let defaults = TPCPreferencesUserDefaults.shared()

			defaults.set((mode != 2), forKey: SetupChoicesModel.checksKey)
			defaults.set((mode == 0), forKey: SetupChoicesModel.installsKey)
		})
	}

	private var updatesRow: SetupExplainedRow
	{
		let binding = updateMode

		return SetupExplainedRow(id: "updates",
								 title: SetupText("sa-p-upd-t"),
								 help: SetupText("sa-p-upd-d"),
								 control: AnyView(Picker("", selection: binding) {
									Text(SettingsText("set-gen-u0")).tag(0)
									Text(SettingsText("set-gen-u1")).tag(1)
									Text(SettingsText("set-gen-u2")).tag(2)
								 }
								 .labelsHidden().frame(width: 130)),
								 sample: AnyView(SetupUpdatesSample(mode: binding.wrappedValue)),
								 explanation: [SetupText("sa-p-upd-x1")])
	}
}

// MARK: - Samples

private struct SetupSampleName: View
{
	let name: String
	let color: Color
	var time = "12:04"

	var body: some View
	{
		HStack(spacing: 5) {
			Text(name).fontWeight(.semibold).foregroundStyle(color)
			Text(time).foregroundStyle(.secondary).font(.system(size: 10))
		}
	}
}

struct SetupEventsSample: View
{
	let choice: Int

	var body: some View
	{
		VStack(alignment: .leading, spacing: 2) {
			SetupSampleName(name: "alice", color: .blue)
			Text("anyone tried the new build?")

			if (choice == 0) {
				Group {
					Text("→ carol joined")
					Text("← dave left")
					Text("← erin quit (timeout)")
				}
				.foregroundStyle(.secondary)
			} else if (choice == 1) {
				Text(SetupText("sa-c-ev-sample"))
					.foregroundStyle(.secondary)
			}

			SetupSampleName(name: "bob", color: .pink, time: "12:05")
				.padding(.top, 3)
			Text("yes, works here")
		}
		.font(.system(size: 11))
		.padding(8)
	}
}

struct SetupSuggestionsSample: View
{
	let on: Bool

	var body: some View
	{
		VStack(alignment: .leading, spacing: 5) {
			Text("thanks @al")

			if (on) {
				VStack(alignment: .leading, spacing: 0) {
					Text("alice")
						.padding(.horizontal, 6)
						.padding(.vertical, 1)
						.frame(maxWidth: .infinity, alignment: .leading)
						.foregroundStyle(.white)
						.background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor))

					Text("alan_w").padding(.horizontal, 6).padding(.vertical, 1)
					Text("alfred").padding(.horizontal, 6).padding(.vertical, 1)
				}
				.padding(3)
				.background(RoundedRectangle(cornerRadius: 6).fill(.background).shadow(radius: 2))
			} else {
				Text(SetupText("sa-c-sug-off"))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.font(.system(size: 11))
		.padding(8)
	}
}

struct SetupMarkdownSample: View
{
	let on: Bool

	var body: some View
	{
		VStack(alignment: .leading, spacing: 2) {
			Text(SetupText("sa-c-md-you")).foregroundStyle(.secondary).font(.system(size: 10))
			Text(verbatim: "this is **really** nice").font(.system(size: 11, design: .monospaced))
			Text(SetupText("sa-c-md-see")).foregroundStyle(.secondary).font(.system(size: 10)).padding(.top, 5)

			if (on) {
				(Text("this is ") + Text("really").bold() + Text(" nice"))
			} else {
				Text(verbatim: "this is **really** nice")
			}
		}
		.font(.system(size: 11))
		.padding(8)
	}
}

struct SetupPreviewSample: View
{
	let on: Bool

	var body: some View
	{
		VStack(alignment: .leading, spacing: 2) {
			SetupSampleName(name: "alice", color: .blue)
			Text(verbatim: "https://example.com/sunset.jpg").foregroundStyle(Color.accentColor)

			if (on) {
				RoundedRectangle(cornerRadius: 5)
					.fill(LinearGradient(colors: [.orange, .pink, .indigo], startPoint: .leading, endPoint: .trailing))
					.frame(height: 40)
					.padding(.top, 3)
					.accessibilityHidden(true)
			}
		}
		.font(.system(size: 11))
		.padding(8)
	}
}

struct SetupCardSample: View
{
	let on: Bool

	var body: some View
	{
		VStack(alignment: .leading, spacing: 3) {
			Text(verbatim: "https://example.com/news/story").foregroundStyle(Color.accentColor)

			if (on) {
				VStack(alignment: .leading, spacing: 1) {
					Text(SetupText("sa-p-card-s1")).fontWeight(.semibold)
					Text(SetupText("sa-p-card-s2")).foregroundStyle(.secondary)
				}
				.padding(6)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(RoundedRectangle(cornerRadius: 5).fill(.quinary))
			}
		}
		.font(.system(size: 11))
		.padding(8)
	}
}

struct SetupArchiveSample: View
{
	let off: Bool

	var body: some View
	{
		Group {
			if (off) {
				Text(SetupText("sa-p-arc-off"))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			} else {
				VStack(alignment: .leading, spacing: 3) {
					Label(SetupText("sa-p-arc-s1"), systemImage: "magnifyingglass")
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(RoundedRectangle(cornerRadius: 5).fill(.quinary))

					Text(SetupText("sa-p-arc-s2")).foregroundStyle(.secondary).font(.system(size: 10)).padding(.top, 3)
					Text(SetupText("sa-p-arc-s3"))
				}
			}
		}
		.font(.system(size: 11))
		.padding(8)
	}
}

struct SetupUpdatesSample: View
{
	let mode: Int

	var body: some View
	{
		VStack(alignment: .leading, spacing: 3) {
			Text(SetupText((mode == 2) ? "sa-p-upd-s2" : "sa-p-upd-s")).fontWeight(.semibold)
			Text(SetupText("sa-p-upd-s\(mode)d")).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
		}
		.font(.system(size: 11))
		.padding(8)
	}
}
