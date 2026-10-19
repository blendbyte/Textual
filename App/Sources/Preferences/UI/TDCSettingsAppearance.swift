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

/* Settings › Appearance (12.11 S2): light or dark, the style with previews,
 Chat or Classic, the font, and the window */

struct SettingsStyle: Identifiable
{
	let name: String
	let location: Int
	let displayName: String
	let bundled: Bool

	var id: String { "\(location)/\(name)" }

	/// One line about a style Textual comes with
	var summary: String?
	{
		guard bundled else {
			return nil
		}

		let summary = SettingsText("set-sty-\(name)")

		return (summary.hasPrefix("set-sty-") ? nil : summary)
	}
}

struct AppearanceSettings: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel
	@Environment(\.colorScheme) private var colorScheme

	private var styles: [SettingsStyle]
	{
		TDCSettingsBridge.styles.map {
			SettingsStyle(name: ($0["name"] as? String ?? ""),
						  location: ($0["location"] as? Int ?? 0),
						  displayName: ($0["displayName"] as? String ?? ""),
						  bundled: ($0["bundled"] as? Bool ?? false))
		}
	}

	private var selectedStyle: SettingsStyle?
	{
		styles.first { $0.id == selectedStyleID }
	}

	private var selectedStyleID: String?
	{
		TDCSettingsBridge.styles.first { ($0["selected"] as? Bool) == true }.map { "\($0["location"] as? Int ?? 0)/\($0["name"] as? String ?? "")" }
	}

	var body: some View
	{
		let appearance = store.integer("Appearance")
		let groupingStyle = store.value(get: { TDCSettingsBridge.messageGroupingStyle() }, set: { TDCSettingsBridge.setMessageGroupingStyle($0, in: model.window) })
		let arrangement = store.integer("ChannelViewArrangement")

		Form {
			Section {
				SettingsPageHeader(section: .appearance)
			}

			Section {
				HStack(spacing: 18) {
					ForEach([0, 1, 2], id: \.self) { value in
						SettingsChoiceCard(title: SettingsText("set-app-a\(value)"), selected: (appearance.wrappedValue == value)) {
							WindowSketch(kind: value)
						} action: {
							appearance.wrappedValue = value
						}
					}
				}
				.padding(.vertical, 6)
			}

			Section {
				/* The style is chosen on a page of its own: the cards are big */
				NavigationLink(value: SettingsSubpage.styles) {
					HStack(spacing: 12) {
						if let style = selectedStyle {
							StylePreviewImage(style: style, dark: (colorScheme == .dark))
								.frame(width: 120, height: 64)
								.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
								.overlay {
									RoundedRectangle(cornerRadius: 6, style: .continuous)
										.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
								}

							VStack(alignment: .leading, spacing: 2) {
								Text(style.displayName)

								Text(style.summary ?? SettingsText("set-app-own"))
									.font(.callout)
									.foregroundStyle(.secondary)
									.fixedSize(horizontal: false, vertical: true)
							}
						} else {
							Text(SettingsText("set-app-h1"))
						}
					}
					.padding(.vertical, 2)
				}

				if let chosen = TDCSettingsBridge.settingsChosenByStyle {
					Label(SettingsText("set-app-c", chosen), systemImage: "info.circle")
						.foregroundStyle(.secondary)
				}
			} header: {
				Text(SettingsText("set-app-h1"))
			}

			Section {
				HStack(spacing: 18) {
					SettingsChoiceCard(title: SettingsText("g7d-n1"), selected: (groupingStyle.wrappedValue == 1)) {
						ChatSketch(grouped: true)
					} action: {
						groupingStyle.wrappedValue = 1
					}

					SettingsChoiceCard(title: SettingsText("g7d-n2"), selected: (groupingStyle.wrappedValue == 0)) {
						ChatSketch(grouped: false)
					} action: {
						groupingStyle.wrappedValue = 0
					}
				}
				.padding(.vertical, 6)

				Text(SettingsText((groupingStyle.wrappedValue == 1) ? "set-app-d1" : "set-app-d0"))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if (groupingStyle.wrappedValue == 1 && TDCSettingsBridge.styleSupportsChatDisplay == false) {
					Label(SettingsText("set-app-du"), systemImage: "exclamationmark.triangle")
						.foregroundStyle(.orange)
				}
			} header: {
				Text(SettingsText("set-app-h2"))
			}

			Section(SettingsText("set-app-h3")) {
				LabeledContent {
					HStack {
						if (TDCSettingsBridge.fontIsSystemFont == false && TDCSettingsBridge.fontChosenByStyle == false) {
							Button(SettingsText("set-app-fs")) {
								store.objectWillChange.send()

								TDCSettingsBridge.useSystemFont()
							}
						}

						Button(SettingsText("set-app-fc")) {
							TDCSettingsBridge.chooseFont()
						}
						.disabled(TDCSettingsBridge.fontChosenByStyle)
					}
				} label: {
					SettingLabel(title: SettingsText("set-app-f", TDCSettingsBridge.fontDescription),
								 help: SettingsText(TDCSettingsBridge.fontChosenByStyle ? "set-app-fhs" : "set-app-fh"))
				}

				SettingToggle(title: SettingsText("set-app-r"), help: SettingsText("set-app-rh"),
							  isOn: store.bool("RightToLeftTextFormatting"))
			}

			Section(SettingsText("set-app-h4")) {
				SettingToggle(title: SettingsText("set-app-t"), help: SettingsText("set-app-th"),
							  isOn: store.value(get: { TPCPreferencesUserDefaults.shared().bool(forKey: "DisableSidebarTranslucency") == false },
												set: { TPCPreferencesUserDefaults.shared().set(($0 == false), forKey: "DisableSidebarTranslucency"); TDCSettingsBridge.preferenceChanged(forKey: "DisableSidebarTranslucency") }))

				VStack(alignment: .leading, spacing: 10) {
					SettingLabel(title: SettingsText("set-app-l"), help: SettingsText("set-app-lh"))

					HStack(spacing: 18) {
						SettingsChoiceCard(title: SettingsText("set-app-l0"), selected: (arrangement.wrappedValue == 0), height: 64) {
							ArrangementSketch(sideBySide: false)
						} action: {
							arrangement.wrappedValue = 0
						}

						SettingsChoiceCard(title: SettingsText("set-app-l1"), selected: (arrangement.wrappedValue == 1), height: 64) {
							ArrangementSketch(sideBySide: true)
						} action: {
							arrangement.wrappedValue = 1
						}

						Spacer()
					}
				}
				.padding(.vertical, 4)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .TVCMainWindowDidReloadTheme)) { _ in
			store.objectWillChange.send()
		}
		.onReceive(NotificationCenter.default.publisher(for: .TDCSettingsBridgeStylePreviewsDidChange)) { _ in
			store.objectWillChange.send()
		}
		.onAppear {
			TDCSettingsBridge.startTakingStylePreviews()
		}
	}
}

/// All styles as cards: Settings › Appearance › Style
struct StylePickerPage: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel
	@Environment(\.colorScheme) private var colorScheme

	var body: some View
	{
		let styles = TDCSettingsBridge.styles.map {
			SettingsStyle(name: ($0["name"] as? String ?? ""),
						  location: ($0["location"] as? Int ?? 0),
						  displayName: ($0["displayName"] as? String ?? ""),
						  bundled: ($0["bundled"] as? Bool ?? false))
		}

		let selectedID = TDCSettingsBridge.styles.first { ($0["selected"] as? Bool) == true }.map { "\($0["location"] as? Int ?? 0)/\($0["name"] as? String ?? "")" }

		Form {
			Section {
				LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
					ForEach(styles) { style in
						StyleCard(style: style,
								  selected: (style.id == selectedID),
								  dark: (colorScheme == .dark)) {
							store.objectWillChange.send()

							TDCSettingsBridge.selectStyleNamed(style.name, location: style.location)
						}
					}
				}
				.padding(.vertical, 6)

				if let chosen = TDCSettingsBridge.settingsChosenByStyle {
					Label(SettingsText("set-app-c", chosen), systemImage: "info.circle")
						.foregroundStyle(.secondary)
				}
			} header: {
				VStack(alignment: .leading, spacing: 3) {
					Text(SettingsText("set-app-h1"))
						.font(.title2.weight(.semibold))
						.foregroundStyle(.primary)
						.settingsPageTitle(model: model)

					Text(SettingsText("set-app-pl"))
						.foregroundStyle(.secondary)
				}
				.padding(.bottom, 6)
			}

			Section {
				LabeledContent {
					Button(SettingsText("set-app-sb")) {
						if let window = model.window {
							TDCSettingsBridge.openStyleFiles(in: window)
						}
					}
				} label: {
					SettingLabel(title: SettingsText("set-app-s"), help: SettingsText("set-app-sh"))
				}
			}
		}
		.formStyle(.grouped)
		.navigationTitle(SettingsText("set-app-h1"))
		.onReceive(NotificationCenter.default.publisher(for: .TVCMainWindowDidReloadTheme)) { _ in
			store.objectWillChange.send()
		}
		.onReceive(NotificationCenter.default.publisher(for: .TDCSettingsBridgeStylePreviewsDidChange)) { _ in
			store.objectWillChange.send()
		}
	}
}

/// A style's picture: the left part, enlarged, so the lines can be read
struct StylePreviewImage: View
{
	let style: SettingsStyle
	let dark: Bool

	var body: some View
	{
		if let image = TDCSettingsBridge.preview(forStyleNamed: style.name, location: style.location, dark: dark) {
			GeometryReader { geometry in
				/* Bundled pictures are wider (600 for 460 points of chat) */
				let width = (geometry.size.width * (style.bundled ? 1.6 : 1.25))
				let height = (width * (image.size.height / max(1, image.size.width)))

				Image(nsImage: image)
					.resizable()
					.frame(width: width, height: height)
					.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
			}
		} else {
			/* A style of one's own before it was used */
			VStack(spacing: 6) {
				Image(systemName: "paintbrush.pointed")
					.font(.title2)

				Text(SettingsText("set-app-np"))
					.font(.caption)
			}
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Color.primary.opacity(0.05))
		}
	}
}

// MARK: - Cards

/// A choice shown as a picture with its name under it, ringed when chosen
struct SettingsChoiceCard<Picture: View>: View
{
	let title: String
	let selected: Bool
	var height: CGFloat = 78
	@ViewBuilder let picture: () -> Picture
	let action: () -> Void

	var body: some View
	{
		Button(action: action) {
			VStack(spacing: 6) {
				picture()
					.frame(height: height)
					.frame(maxWidth: .infinity)
					.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
					.overlay {
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.strokeBorder((selected ? Color.accentColor : Color.primary.opacity(0.12)), lineWidth: (selected ? 3 : 1))
					}

				Text(title)
					.font(.callout.weight(selected ? .semibold : .regular))
					.foregroundStyle(selected ? Color.primary : Color.secondary)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.frame(maxWidth: 160)
	}
}

/// A style: its picture, name and one line about it
struct StyleCard: View
{
	let style: SettingsStyle
	let selected: Bool
	let dark: Bool
	let action: () -> Void

	var body: some View
	{
		Button(action: action) {
			VStack(alignment: .leading, spacing: 5) {
				StylePreviewImage(style: style, dark: dark)
				.frame(height: 104)
				.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
				.overlay {
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.strokeBorder((selected ? Color.accentColor : Color.primary.opacity(0.12)), lineWidth: (selected ? 3 : 1))
				}

				Text(style.displayName)
					.font(.callout.weight(.semibold))
					.padding(.top, 2)

				Text(style.summary ?? SettingsText("set-app-own"))
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Sketches

/// A small window: like the Mac (half light, half dark), light, or dark
struct WindowSketch: View
{
	let kind: Int

	private func window(dark: Bool) -> some View
	{
		let background = (dark ? Color(white: 0.16) : Color(white: 0.98))
		let sidebar = (dark ? Color(white: 0.24) : Color(white: 0.88))
		let line = (dark ? Color(white: 0.42) : Color(white: 0.72))

		return HStack(spacing: 0) {
			sidebar.frame(width: 26)

			VStack(alignment: .leading, spacing: 6) {
				Capsule().fill(line).frame(width: 46, height: 5)
				Capsule().fill(line).frame(width: 62, height: 5)
				Capsule().fill(Color.accentColor.opacity(0.8)).frame(width: 34, height: 5)
				Capsule().fill(line).frame(width: 54, height: 5)
			}
			.padding(.leading, 9)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		}
		.background(background)
	}

	var body: some View
	{
		switch kind {
			case 1: window(dark: false)
			case 2: window(dark: true)
			default:
				ZStack {
					window(dark: false)

					window(dark: true)
						.mask(alignment: .trailing) {
							Rectangle().frame(maxWidth: .infinity).padding(.leading, 70)
						}
				}
		}
	}
}

/// A few lines of chat: grouped under names (Chat) or a name on each line (Classic)
struct ChatSketch: View
{
	let grouped: Bool

	@Environment(\.colorScheme) private var colorScheme

	var body: some View
	{
		let text = Color.primary.opacity(0.75)
		let faint = Color.secondary.opacity(0.7)
		let alice = Color(nsColor: .systemRed)
		let bob = Color(nsColor: .systemGreen)

		VStack(alignment: .leading, spacing: 2) {
			if (grouped) {
				HStack(spacing: 4) { Text("alice").bold().foregroundStyle(alice); Text("14:03").foregroundStyle(faint) }
				Text("morning everyone!").foregroundStyle(text)
				Text("how’s it going?").foregroundStyle(text)
				HStack(spacing: 4) { Text("bob").bold().foregroundStyle(bob); Text("14:05").foregroundStyle(faint) }
					.padding(.top, 3)
				Text("great, thanks").foregroundStyle(text)
			} else {
				HStack(spacing: 3) { Text("14:03").foregroundStyle(faint); Text("<alice>").foregroundStyle(alice); Text("morning everyone!").foregroundStyle(text) }
				HStack(spacing: 3) { Text("14:03").foregroundStyle(faint); Text("<alice>").foregroundStyle(alice); Text("how’s it going?").foregroundStyle(text) }
				HStack(spacing: 3) { Text("14:05").foregroundStyle(faint); Text("<bob>").foregroundStyle(bob); Text("great, thanks").foregroundStyle(text) }
			}
		}
		.font(.system(size: 9))
		.lineLimit(1)
		.padding(8)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background((colorScheme == .dark) ? Color(white: 0.13) : Color.white)
	}
}

/// Two channels in the window: stacked or side by side
struct ArrangementSketch: View
{
	let sideBySide: Bool

	var body: some View
	{
		let pane = RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.14))

		Group {
			if (sideBySide) {
				HStack(spacing: 4) { pane; pane }
			} else {
				VStack(spacing: 4) { pane; pane }
			}
		}
		.padding(7)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.primary.opacity(0.04))
	}
}
