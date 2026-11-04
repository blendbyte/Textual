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
