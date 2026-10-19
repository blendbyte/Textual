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

/* Settings › Typing: the field where you write, suggestions and shortcuts */

struct TypingSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	/* What goes after a name completed at the start of a message, used as
	 it is: with the space */
	private static let suffixes = [": ", ", ", ""]

	/* Exactly as Tab completion writes it; with none, a space */
	private static func example(_ suffix: String) -> String
	{
		("alice" + (suffix.isEmpty ? " " : suffix) + "hi")
	}

	/* The kinds of suggestions, in the order of their keys */
	private static let suggestionKeys = [
		"Input Completion -> Nicknames",
		"Input Completion -> Channels",
		"Input Completion -> Commands",
		"Input Completion -> Emoji"
	]

	var body: some View
	{
		let fontSize = store.integer("Main Input Text Field -> Font Size")
		let suffix = store.string("Keyboard -> Tab Key Completion Suffix")

		Form {
			Section {
				SettingsPageHeader(section: .typing)
			}

			Section {
				TypingSample(textSize: fontSize.wrappedValue,
							 suggestions: store.bool(Self.suggestionKeys[0]).wrappedValue)
			}

			Section {
				ForEach(0..<Self.suggestionKeys.count, id: \.self) { (kind) in
					SettingToggle(title: SettingsText("set-typ-s\(kind)"), isOn: store.bool(Self.suggestionKeys[kind]))
				}
			} header: {
				Text(SettingsText("set-typ-h1"))
			} footer: {
				Text(SettingsText("set-typ-sh"))
					.foregroundStyle(.secondary)
			}

			Section {
				SettingToggle(title: SettingsText("set-typ-md"), help: SettingsText("set-typ-mdh"),
							  isOn: store.bool("Input -> Markdown Formatting"))

				Picker(selection: store.integer("Keyboard -> Tab Key Action")) {
					Text(SettingsText("set-typ-t0")).tag(0)
					Text(SettingsText("set-typ-t1")).tag(1)
					Text(SettingsText("set-typ-t2")).tag(100)
				} label: {
					SettingLabel(title: SettingsText("set-typ-t"))
				}

				SettingValuePicker(title: SettingsText("set-typ-a"), help: SettingsText("set-typ-ah", Self.example(suffix.wrappedValue)),
								   selection: suffix, values: Self.suffixes) { (value) in
					switch value {
						case ": ": return SettingsText("set-typ-a0")
						case ", ": return SettingsText("set-typ-a1")
						case "": return SettingsText("set-typ-a2")
						default: return "“\(value)”"
					}
				}
			}

			Section(SettingsText("set-typ-h2")) {
				LabeledContent {
					Picker("", selection: fontSize) {
						Text(SettingsText("set-typ-f1")).tag(1)
						Text(SettingsText("set-typ-f2")).tag(2)
						Text(SettingsText("set-typ-f3")).tag(3)
						Text(SettingsText("set-typ-f4")).tag(4)
					}
					.labelsHidden()
					.pickerStyle(.segmented)
					.fixedSize()
				} label: {
					SettingLabel(title: SettingsText("set-typ-f"))
				}

				SettingToggle(title: SettingsText("set-typ-sp"), isOn: store.bool("TextFieldAutomaticSpellCheck"))

				SettingToggle(title: SettingsText("set-typ-gr"), isOn: store.bool("TextFieldAutomaticGrammarCheck"))

				SettingToggle(title: SettingsText("set-typ-ac"), isOn: store.bool("TextFieldAutomaticSpellCorrection"))

				SettingToggle(title: SettingsText("set-typ-hi"), help: SettingsText("set-typ-hih"),
							  isOn: store.bool("SaveInputHistoryPerSelection"))

				SettingToggle(title: SettingsText("set-typ-b"), help: SettingsText("set-typ-bh"),
							  isOn: store.bool("DisableMainWindowSegmentedController"))
			}

			Section(SettingsText("set-typ-h3")) {
				SettingToggle(title: SettingsText("set-typ-cr"), help: SettingsText("set-typ-crh"),
							  isOn: store.bool("CommandReturnSendsMessageAsAction"))

				SettingToggle(title: SettingsText("set-typ-ce"), help: SettingsText("set-typ-ceh"),
							  isOn: store.bool("ControlEnterSendsMessage"))

				SettingToggle(title: SettingsText("set-typ-n"), help: SettingsText("set-typ-nh"),
							  isOn: store.value(get: { TDCSettingsBridge.sendTypingNotifications },
												set: { TDCSettingsBridge.sendTypingNotifications = $0 }))
			}
		}
	}
}

/// The input field with its suggestion list, at the chosen text size
struct TypingSample: View
{
	let textSize: Int
	let suggestions: Bool

	@Environment(\.colorScheme) private var colorScheme

	private var fontSize: CGFloat
	{
		switch textSize {
			case 2: return 15
			case 3: return 17
			case 4: return 20
			default: return 13
		}
	}

	var body: some View
	{
		VStack(alignment: .leading, spacing: 6) {
			if (suggestions) {
				VStack(alignment: .leading, spacing: 0) {
					ForEach(["alice", "alexander", "alfie_"], id: \.self) { (name) in
						Text(name)
							.padding(.horizontal, 8)
							.padding(.vertical, 3)
							.frame(maxWidth: .infinity, alignment: .leading)
							.foregroundStyle((name == "alice") ? Color.white : Color.primary)
							.background((name == "alice") ? Color.accentColor : Color.clear,
										in: RoundedRectangle(cornerRadius: 4, style: .continuous))
					}
				}
				.font(.system(size: 12))
				.padding(4)
				.frame(width: 150)
				.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
				.shadow(color: .black.opacity(0.15), radius: 4, y: 1)
				.padding(.leading, 34)
			}

			HStack(spacing: 0) {
				Text(SettingsText("set-typ-x1"))
					.foregroundStyle(.secondary)

				Text("@al")

				Rectangle()
					.fill(Color.accentColor)
					.frame(width: 1.5, height: (fontSize + 2))
					.padding(.leading, 1)

				Spacer()
			}
			.font(.system(size: fontSize))
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.background((colorScheme == .dark) ? Color(white: 0.11) : Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
			}
		}
		.padding(.vertical, 4)
		.animation(.easeInOut(duration: 0.15), value: suggestions)
		.animation(.easeInOut(duration: 0.15), value: textSize)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(SettingsText("set-typ-xa"))
	}
}
