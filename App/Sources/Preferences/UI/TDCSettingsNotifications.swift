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

/* Settings › Notifications: what Textual tells you about, and how. Each kind
 of event opens a page of its own. */

/// What one kind of event does, read from its preference keys
struct NotificationEventOptions
{
	let event: Int

	private func key(_ category: String) -> String
	{
		TDCSettingsBridge.notificationKey(forEvent: event, category: category)
	}

	var enabledKey: String { key("Enabled") }
	var soundKey: String { key("Sound") }
	var bounceKey: String { key("Bounce Dock Icon") }
	var bounceRepeatedlyKey: String { key("Bounce Dock Icon Repeatedly") }
	var speakKey: String { key("Speak") }
	var awayKey: String { key("Disable While Away") }

	private var defaults: UserDefaults { TPCPreferencesUserDefaults.shared() }

	/* No sound is stored as nothing or as "None" */
	var sound: String?
	{
		let sound = defaults.string(forKey: soundKey)

		if (sound == nil || sound!.isEmpty || sound == "None") {
			return nil
		}

		return sound
	}

	/// "Notification · Glass · Dock", or "Off"
	var summary: String
	{
		var parts: [String] = []

		if (defaults.bool(forKey: enabledKey)) {
			parts.append(SettingsText("set-not-sn"))
		}

		if let sound = sound {
			parts.append(sound)
		}

		if (defaults.bool(forKey: bounceKey)) {
			parts.append(SettingsText("set-not-sd"))
		}

		if (defaults.bool(forKey: speakKey)) {
			parts.append(SettingsText("set-not-ss"))
		}

		return (parts.isEmpty ? SettingsText("set-not-so") : parts.joined(separator: " · "))
	}

	var symbol: String
	{
		switch event {
			case 1000: return "at"
			case 1001: return "envelope.badge"
			case 1002: return "number"
			case 1003: return "megaphone"
			case 1004: return "envelope"
			case 1005: return "envelope.open"
			case 1006: return "xmark.circle"
			case 1007: return "plus.bubble"
			case 1008: return "bolt.horizontal"
			case 1009: return "bolt.slash"
			case 1010: return "person.crop.circle"
			case 1011: return "arrow.up.doc"
			case 1012: return "arrow.down.doc"
			case 1013, 1014: return "exclamationmark.triangle"
			case 1015: return "tray.and.arrow.down"
			case 1016: return "arrow.right"
			case 1017: return "arrow.left"
			case 1018: return "rectangle.portrait.and.arrow.right"
			default: return "bell"
		}
	}
}

struct NotificationsSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	var body: some View
	{
		let privateBadge = store.bool("DisplayDockBadges")
		let allBadge = store.bool("DisplayPublicMessageCountInDockBadge")

		/* None, unread private messages, or everything unread */
		let dockBadge = Binding<Int>(get: {
			((privateBadge.wrappedValue == false) ? 0 : ((allBadge.wrappedValue) ? 2 : 1))
		}, set: { (value) in
			allBadge.wrappedValue = (value == 2)
			privateBadge.wrappedValue = (value != 0)
		})

		let onlySelection = store.bool("OnlySpeakNotificationsForSelection")

		Form {
			Section {
				SettingsPageHeader(section: .notifications)
			}

			Section {
				NotificationSample()
			}

			ForEach(Array(TDCSettingsBridge.notificationEventGroups.enumerated()), id: \.offset) { (index, group) in
				Section {
					ForEach(group.map { $0.intValue }, id: \.self) { (event) in
						let options = NotificationEventOptions(event: event)

						NavigationLink(value: SettingsSubpage.notificationEvent(event)) {
							HStack(spacing: 10) {
								Image(systemName: options.symbol)
									.foregroundStyle(.secondary)
									.frame(width: 20)

								Text(TDCSettingsBridge.title(forNotificationEvent: event))

								Spacer()

								Text(options.summary)
									.foregroundStyle(.secondary)
									.lineLimit(1)
							}
						}
					}
				} header: {
					if (index == 0) {
						Text(SettingsText("set-not-h1"))
					}
				} footer: {
					if (index == 0) {
						SettingFooter(text: SettingsText("set-not-h1h"))
					}
				}
			}

			Section(SettingsText("set-not-h2")) {
				SettingToggle(title: SettingsText("set-not-f"), help: SettingsText("set-not-fh"),
							  isOn: store.bool("PostNotificationsWhileInFocus"))

				SettingToggle(title: SettingsText("set-not-m"), help: SettingsText("set-not-mh"),
							  isOn: store.bool("Notifications -> Highlights When Muted"))

				Picker(selection: dockBadge) {
					Text(SettingsText("set-not-d0")).tag(0)
					Text(SettingsText("set-not-d1")).tag(1)
					Text(SettingsText("set-not-d2")).tag(2)
				} label: {
					SettingLabel(title: SettingsText("set-not-d"), help: SettingsText("set-not-dh"))
				}
			}

			Section {
				SettingToggle(title: SettingsText("set-not-v1"), help: SettingsText("set-not-v1h"),
							  isOn: onlySelection)

				/* Only the channel you look at is spoken: its name goes without saying */
				let channelName = store.bool("NotificationType -> Public Message -> Speak Channel Name")

				SettingToggle(title: SettingsText("set-not-v2"),
							  isOn: Binding(get: { channelName.wrappedValue && onlySelection.wrappedValue == false },
											set: { channelName.wrappedValue = $0 }))
					.disabled(onlySelection.wrappedValue)

				SettingToggle(title: SettingsText("set-not-v3"),
							  isOn: store.bool("NotificationType -> Public Message -> Speak Nickname"))
			} header: {
				Text(SettingsText("set-not-h3"))
			} footer: {
				SettingFooter(text: SettingsText("set-not-h3h"))
			}
		}
	}
}

/// One kind of event: Settings › Notifications › Highlight
struct NotificationEventPage: View
{
	let event: Int

	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	private static let noSound = ""

	var body: some View
	{
		let options = NotificationEventOptions(event: event)
		let title = TDCSettingsBridge.title(forNotificationEvent: event)

		let sound = Binding<String>(get: {
			(options.sound ?? Self.noSound)
		}, set: { (value) in
			store.string(options.soundKey).wrappedValue = ((value == Self.noSound) ? "None" : value)

			if (value != Self.noSound) {
				TDCSettingsBridge.playAlertSound(value)
			}
		})

		let bounce = store.bool(options.bounceKey)
		let bounceRepeatedly = store.bool(options.bounceRepeatedlyKey)

		/* No, once, or until you switch to Textual */
		let dock = Binding<Int>(get: {
			((bounce.wrappedValue == false) ? 0 : ((bounceRepeatedly.wrappedValue) ? 2 : 1))
		}, set: { (value) in
			bounceRepeatedly.wrappedValue = (value == 2)
			bounce.wrappedValue = (value != 0)
		})

		let sounds = TDCSettingsBridge.alertSounds

		Form {
			Section {
				SettingToggle(title: SettingsText("set-not-e1"), help: SettingsText("set-not-e1h"),
							  isOn: store.bool(options.enabledKey))

				Picker(selection: sound) {
					Text(SettingsText("set-not-e2n")).tag(Self.noSound)

					Divider()

					ForEach((sounds.contains(sound.wrappedValue) || sound.wrappedValue == Self.noSound) ? sounds : (sounds + [sound.wrappedValue]), id: \.self) { (name) in
						Text(name).tag(name)
					}
				} label: {
					SettingLabel(title: SettingsText("set-not-e2"), help: SettingsText("set-not-e2h"))
				}

				Picker(selection: dock) {
					Text(SettingsText("set-not-e30")).tag(0)
					Text(SettingsText("set-not-e31")).tag(1)
					Text(SettingsText("set-not-e32")).tag(2)
				} label: {
					SettingLabel(title: SettingsText("set-not-e3"))
				}

				SettingToggle(title: SettingsText("set-not-e4"), help: SettingsText("set-not-e4h"),
							  isOn: store.bool(options.speakKey))

				SettingToggle(title: SettingsText("set-not-e5"), help: SettingsText("set-not-e5h"),
							  isOn: store.bool(options.awayKey))
			} header: {
				VStack(alignment: .leading, spacing: 3) {
					Text(title)
						.font(.title2.weight(.semibold))
						.foregroundStyle(.primary)
						.settingsPageTitle(model: model)

					Text(SettingsText("set-not-el"))
						.foregroundStyle(.secondary)
				}
				.padding(.bottom, 6)
			}
		}
		.formStyle(.grouped)
		.navigationTitle(title)
	}
}

/// A notification as the Mac shows it
struct NotificationSample: View
{
	var body: some View
	{
		HStack(alignment: .top, spacing: 10) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 34, height: 34)

			VStack(alignment: .leading, spacing: 2) {
				HStack {
					Text(SettingsText("set-not-x1"))
						.fontWeight(.semibold)

					Spacer()

					Text(SettingsText("set-not-x3"))
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Text(SettingsText("set-not-x2"))
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}
		}
		.font(.system(size: 12))
		.padding(12)
		.frame(maxWidth: 360)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
		.shadow(color: .black.opacity(0.12), radius: 6, y: 2)
		.frame(maxWidth: .infinity)
		.padding(.vertical, 6)
		.accessibilityElement(children: .combine)
	}
}
