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

/* The pages of the Settings window (12.11) */

// MARK: - General

struct GeneralSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .general)
			}

			if (TDCSettingsBridge.updatesAvailable) {
				Section {
					Picker(selection: store.value(get: { TDCSettingsBridge.updateMode }, set: { TDCSettingsBridge.updateMode = $0 })) {
						Text(SettingsText("set-gen-u0")).tag(0)
						Text(SettingsText("set-gen-u1")).tag(1)
						Text(SettingsText("set-gen-u2")).tag(2)
					} label: {
						SettingLabel(title: SettingsText("set-gen-u"), help: SettingsText("set-gen-uh"))
					}

					SettingToggle(title: SettingsText("set-gen-b"), help: SettingsText("set-gen-bh"),
								  isOn: store.bool("ReceiveBetaUpdates", then: { TDCSettingsBridge.betaUpdatesChanged() }))
				}
			}

			Section(SettingsText("set-gen-h1")) {
				SettingToggle(title: SettingsText("set-gen-q"), help: SettingsText("set-gen-qh"),
							  isOn: store.bool("ConfirmApplicationQuit"))

				SettingToggle(title: SettingsText("set-gen-a"), help: SettingsText("set-gen-ah"),
							  isOn: store.value(get: { TDCSettingsBridge.preventSleepWhileConnected }, set: { TDCSettingsBridge.preventSleepWhileConnected = $0 }))

				SettingToggle(title: SettingsText("set-gen-s"), help: SettingsText("set-gen-sh"),
							  isOn: store.bool("SetAwayOnScreenSleep"))

				SettingToggle(title: SettingsText("set-gen-l"), help: SettingsText("set-gen-lh"),
							  isOn: store.bool("OpenClickedLinksInBackgroundBrowser"))
			}

			Section(SettingsText("set-gen-h2")) {
				Picker(selection: store.integer("Keyboard -> Command+W Key Action")) {
					Text(SettingsText("set-gen-w0")).tag(0)
					Text(SettingsText("set-gen-w1")).tag(1)
					Text(SettingsText("set-gen-w2")).tag(2)
					Text(SettingsText("set-gen-w3")).tag(3)
				} label: {
					SettingLabel(title: SettingsText("set-gen-w"))
				}

				SettingToggle(title: SettingsText("set-gen-c"), help: SettingsText("set-gen-ch"),
							  isOn: store.bool("CopyTextSelectionOnMouseUp"))
			}
		}
	}
}

// MARK: - Lists

struct ListsSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	/// Two preferences as one choice: nothing, the first, or both
	private func doubleClick(_ first: String, _ second: String) -> Binding<Int>
	{
		store.value(get: {
			let defaults = TPCPreferencesUserDefaults.shared()

			if (defaults.bool(forKey: second)) {
				return 2
			}

			return (defaults.bool(forKey: first) ? 1 : 0)
		}, set: { choice in
			let defaults = TPCPreferencesUserDefaults.shared()

			defaults.set((choice >= 1), forKey: first)
			defaults.set((choice == 2), forKey: second)
		})
	}

	private static let modeColors: [(String, String)] = [
		("set-lst-m1", "User List Mode Badge Colors -> +y"),
		("set-lst-m2", "User List Mode Badge Colors -> +q"),
		("set-lst-m3", "User List Mode Badge Colors -> +a"),
		("set-lst-m4", "User List Mode Badge Colors -> +o"),
		("set-lst-m5", "User List Mode Badge Colors -> +h"),
		("set-lst-m6", "User List Mode Badge Colors -> +v"),
		("set-lst-m7", "User List Mode Badge Colors -> no mode")
	]

	private static let unreadHighlightColor = "Server List Unread Message Count Badge Colors -> Highlight"

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .lists)
			}

			Section(SettingsText("set-lst-h1")) {
				SettingToggle(title: SettingsText("set-lst-s"), help: SettingsText("set-lst-sh"),
							  isOn: store.value(get: { TDCSettingsBridge.keepChannelListSorted }, set: { TDCSettingsBridge.keepChannelListSorted = $0 }))

				Picker(SettingsText("set-lst-d1"), selection: doubleClick("ServerListDoubleClickConnectServer", "ServerListDoubleClickDisconnectServer")) {
					Text(SettingsText("set-lst-n")).tag(0)
					Text(SettingsText("set-lst-d1a")).tag(1)
					Text(SettingsText("set-lst-d1b")).tag(2)
				}

				Picker(SettingsText("set-lst-d2"), selection: doubleClick("ServerListDoubleClickJoinChannel", "ServerListDoubleClickLeaveChannel")) {
					Text(SettingsText("set-lst-n")).tag(0)
					Text(SettingsText("set-lst-d2a")).tag(1)
					Text(SettingsText("set-lst-d2b")).tag(2)
				}

				SettingToggle(title: SettingsText("set-lst-v"), help: SettingsText("set-lst-vh"),
							  isOn: store.bool("ChannelNavigationIsServerSpecific"))

				ColorPicker(selection: store.color(Self.unreadHighlightColor), supportsOpacity: false) {
					SettingLabel(title: SettingsText("set-lst-u"), help: SettingsText("set-lst-uh"))
				}
			}

			Section(SettingsText("set-lst-h2")) {
				Picker(SettingsText("set-lst-d3"), selection: store.integer("UserListDoubleClickAction")) {
					Text(SettingsText("set-lst-d3a")).tag(200)
					Text(SettingsText("set-lst-d3b")).tag(100)
					Text(SettingsText("set-lst-d3c")).tag(300)
				}

				SettingToggle(title: SettingsText("set-lst-t"), help: SettingsText("set-lst-th"),
							  isOn: store.bool("MemberListSortFavorsServerStaff"))
			}

			Section {
				ForEach(Self.modeColors, id: \.1) { (title, key) in
					ColorPicker(SettingsText(title), selection: store.color(key), supportsOpacity: false)
				}
			} header: {
				Text(SettingsText("set-lst-h3"))
			} footer: {
				HStack {
					Text(SettingsText("set-lst-mh"))
						.foregroundStyle(.secondary)

					Spacer()

					Button(SettingsText("set-reset")) {
						store.objectWillChange.send()

						TDCSettingsBridge.resetMemberListColors()

						TDCSettingsBridge.setColor(nil, forKey: Self.unreadHighlightColor)
					}
				}
			}
		}
	}
}

// MARK: - Servers

struct ServersSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	private func seconds(_ value: Double) -> String
	{
		(value == 1) ? SettingsText("set-srv-s1") : SettingsText("set-srv-sn", value.formatted(.number.precision(.fractionLength(0...1))))
	}

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .servers)
			}

			Section {
				TextField(SettingsText("set-srv-i1"), text: store.string("DefaultIdentity -> Nickname"), prompt: Text(SettingsText("set-optional")))
				TextField(SettingsText("set-srv-i2"), text: store.string("DefaultIdentity -> AwayNickname"), prompt: Text(SettingsText("set-optional")))
				TextField(SettingsText("set-srv-i3"), text: store.string("DefaultIdentity -> Username"), prompt: Text(SettingsText("set-optional")))
				TextField(SettingsText("set-srv-i4"), text: store.string("DefaultIdentity -> Realname"), prompt: Text(SettingsText("set-optional")))
			} header: {
				Text(SettingsText("set-srv-h1"))
			} footer: {
				Text(SettingsText("set-srv-ih"))
					.foregroundStyle(.secondary)
			}

			Section(SettingsText("set-srv-h2")) {
				SettingToggle(title: SettingsText("set-srv-j"), isOn: store.bool("AutojoinChannelOnInvite"))

				SettingToggle(title: SettingsText("set-srv-k"), isOn: store.bool("RejoinChannelOnLocalKick"))

				let afterIdentifying = store.double("AutojoinDelayAfterIdentification")

				Stepper(value: afterIdentifying, in: 0...10, step: 0.5) {
					SettingLabel(title: ((afterIdentifying.wrappedValue == 0) ? SettingsText("set-srv-w10") : SettingsText("set-srv-w1", seconds(afterIdentifying.wrappedValue))),
								 help: SettingsText("set-srv-w1h"))
				}

				let betweenJoins = store.double("AutojoinDelayBetweenChannelJoins")

				Stepper(value: betweenJoins, in: 0.5...10, step: 0.5) {
					SettingLabel(title: SettingsText("set-srv-w2", seconds(betweenJoins.wrappedValue)), help: SettingsText("set-srv-w2h"))
				}

				let awayTracking = store.integer("TrackUserAwayStatusMaximumChannelSize")

				Stepper(value: awayTracking, in: 0...2000, step: 50) {
					SettingLabel(title: ((awayTracking.wrappedValue == 0) ? SettingsText("set-srv-a0") : SettingsText("set-srv-a", awayTracking.wrappedValue)),
								 help: SettingsText("set-srv-ah"))
				}
			}

			Section(SettingsText("set-srv-h3")) {
				SettingToggle(title: SettingsText("set-srv-c"), help: SettingsText("set-srv-ch"),
							  isOn: store.bool("ReplyUnignoredExternalCTCPRequests"))
			}
		}
	}
}

// MARK: - Commands

struct AliasRow: Identifiable
{
	let id = UUID()
	var name: String
	var commands: String
}

struct CommandsSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	@State private var aliases: [AliasRow] = TDCSettingsBridge.aliases.map { AliasRow(name: $0[0], commands: $0[1]) }

	private func saveAliases()
	{
		TDCSettingsBridge.aliases = aliases.map { [$0.name, $0.commands] }
	}

	private static let allServerCommands: [(String, String)] = [
		("/amsg, /ame", "ApplyCommandToAllConnections -> amsg"),
		("/away", "ApplyCommandToAllConnections -> away"),
		("/nick", "ApplyCommandToAllConnections -> nick"),
		("/clearall", "ApplyCommandToAllConnections -> clearall")
	]

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .commands)
			}

			Section {
				ForEach($aliases) { $alias in
					HStack(spacing: 8) {
						TextField(SettingsText("set-cmd-an"), text: $alias.name, prompt: Text(SettingsText("set-cmd-anp")))
							.labelsHidden()
							.frame(width: 110)
							.onChange(of: alias.name) { _, _ in saveAliases() }

						TextField(SettingsText("set-cmd-ac"), text: $alias.commands, prompt: Text(SettingsText("set-cmd-acp")))
							.labelsHidden()
							.onChange(of: alias.commands) { _, _ in saveAliases() }

						if (alias.name.isEmpty == false && TDCSettingsBridge.isValidAliasName(alias.name) == false) {
							Image(systemName: "exclamationmark.triangle.fill")
								.foregroundStyle(.orange)
								.help(SettingsText("set-cmd-ai"))
						}

						Button {
							aliases.removeAll { $0.id == alias.id }

							saveAliases()
						} label: {
							Image(systemName: "minus.circle.fill")
								.foregroundStyle(.secondary)
						}
						.buttonStyle(.plain)
						.help(SettingsText("set-cmd-ar"))
					}
				}

				Button {
					aliases.append(AliasRow(name: "", commands: ""))
				} label: {
					Label(SettingsText("set-cmd-aa"), systemImage: "plus.circle.fill")
				}
				.buttonStyle(.borderless)
			} header: {
				Text(SettingsText("set-cmd-h1"))
			} footer: {
				Text(SettingsText("set-cmd-ah"))
					.foregroundStyle(.secondary)
			}

			Section(SettingsText("set-cmd-h2")) {
				SettingToggle(title: SettingsText("set-cmd-m"), help: SettingsText("set-cmd-mh"),
							  isOn: store.bool("FocusSelectionOnMessageCommandExecution"))

				Picker(selection: store.value(get: { TDCSettingsBridge.noticeDestination }, set: { TDCSettingsBridge.noticeDestination = $0 })) {
					Text(SettingsText("set-cmd-n0")).tag(0)
					Text(SettingsText("set-cmd-n1")).tag(1)
					Text(SettingsText("set-cmd-n2")).tag(2)
				} label: {
					SettingLabel(title: SettingsText("set-cmd-n"), help: SettingsText("set-cmd-nh"))
				}

				LabeledContent {
					VStack(alignment: .leading, spacing: 4) {
						ForEach(Self.allServerCommands, id: \.1) { (title, key) in
							Toggle(title, isOn: store.bool(key))
								.toggleStyle(.checkbox)
						}
					}
				} label: {
					SettingLabel(title: SettingsText("set-cmd-e"), help: SettingsText("set-cmd-eh"))
				}
			}

			Section(SettingsText("set-cmd-h3")) {
				TextField(SettingsText("set-cmd-k"), text: store.string("ChannelOperatorDefaultLocalization -> Kick Reason"))

				Picker(SettingsText("set-cmd-b"), selection: store.integer("DefaultBanCommandHostmaskFormat")) {
					Text(SettingsText("set-cmd-b0")).tag(0)
					Text(SettingsText("set-cmd-b1")).tag(1)
					Text(SettingsText("set-cmd-b2")).tag(2)
					Text(SettingsText("set-cmd-b3")).tag(3)
				}
			}

			Section {
				TextField(SettingsText("set-cmd-o1"), text: store.string("IRCopDefaultLocalizaiton -> Kill Reason"))
				TextField(SettingsText("set-cmd-o2"), text: store.string("IRCopDefaultLocalizaiton -> G:Line Reason"))
				TextField(SettingsText("set-cmd-o3"), text: store.string("IRCopDefaultLocalizaiton -> Shun Reason"))
			} header: {
				Text(SettingsText("set-cmd-h4"))
			} footer: {
				Text(SettingsText("set-cmd-oh"))
					.foregroundStyle(.secondary)
			}
		}
	}
}

// MARK: - Files

struct FilesSettings: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	private static let addressMethodKey = "File Transfers -> File Transfer IP Address Detection Method"

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .files)
			}

			Section(SettingsText("set-fil-h1")) {
				LabeledContent(SettingsText("set-fil-d")) {
					Menu {
						Button(SettingsText("set-fil-dc")) {
							if let window = model.window {
								TDCSettingsBridge.chooseDownloadFolder(in: window) { store.objectWillChange.send() }
							}
						}

						Button(SettingsText("set-fil-da")) {
							store.objectWillChange.send()

							TDCSettingsBridge.clearDownloadFolder()
						}
					} label: {
						if let url = TDCSettingsBridge.downloadFolderURL {
							Label(url.lastPathComponent, systemImage: "folder")
						} else {
							Text(SettingsText("set-fil-da"))
						}
					}
					.fixedSize()
				}

				Picker(SettingsText("set-fil-r"), selection: store.integer("File Transfers -> File Transfer Request Reply Action")) {
					Text(SettingsText("set-fil-r2")).tag(2)
					Text(SettingsText("set-fil-r3")).tag(3)
					Text(SettingsText("set-fil-r1")).tag(1)
				}

				SettingToggle(title: SettingsText("set-fil-a"), isOn: store.bool("File Transfers -> Idle System Sleep Prevented During File Transfer"))
			}

			Section(SettingsText("set-fil-h2")) {
				LabeledContent {
					Button(TDCSettingsBridge.uploadDestinationName == nil ? SettingsText("set-fil-us") : SettingsText("set-fil-uc")) {
						if let window = model.window {
							TDCSettingsBridge.editUploadDestination(in: window) { store.objectWillChange.send() }
						}
					}
				} label: {
					SettingLabel(title: (TDCSettingsBridge.uploadDestinationName ?? SettingsText("set-fil-un")), help: SettingsText("set-fil-uh"))
				}

				SettingToggle(title: SettingsText("set-fil-p"), help: SettingsText("set-fil-ph"),
							  isOn: store.value(get: { TDCSettingsBridge.sendsLongPastesToPasteService }, set: { TDCSettingsBridge.sendsLongPastesToPasteService = $0 }))
			}

			Section {
				let method = store.integer(Self.addressMethodKey)

				Picker(selection: method) {
					Text(SettingsText("set-fil-i3")).tag(3)
					Text(SettingsText("set-fil-i1")).tag(1)
					Text(SettingsText("set-fil-i4")).tag(4)
					Text(SettingsText("set-fil-i2")).tag(2)
				} label: {
					SettingLabel(title: SettingsText("set-fil-i"), help: SettingsText("set-fil-ih"))
				}

				if (method.wrappedValue == 2) {
					TextField(SettingsText("set-fil-im"), text: store.string("File Transfers -> File Transfer Manually Entered IP Address"), prompt: Text("192.0.2.1"))
				}

				LabeledContent(SettingsText("set-fil-o")) {
					HStack(spacing: 6) {
						TextField("", value: store.value(get: { TDCSettingsBridge.fileTransferPortRangeStart }, set: { TDCSettingsBridge.fileTransferPortRangeStart = $0 }), format: .number.grouping(.never))
							.labelsHidden()
							.textFieldStyle(.roundedBorder)
							.frame(width: 64)

						Text(verbatim: "–")

						TextField("", value: store.value(get: { TDCSettingsBridge.fileTransferPortRangeEnd }, set: { TDCSettingsBridge.fileTransferPortRangeEnd = $0 }), format: .number.grouping(.never))
							.labelsHidden()
							.textFieldStyle(.roundedBorder)
							.frame(width: 64)
					}
				}

				SettingToggle(title: SettingsText("set-fil-v"), help: SettingsText("set-fil-vh"),
							  isOn: store.bool("File Transfers -> File Transfer Requests Use Reverse DCC"))
			} header: {
				Text(SettingsText("set-fil-h3"))
			} footer: {
				Text(SettingsText("set-fil-h3h"))
					.foregroundStyle(.secondary)
			}
		}
	}
}

// MARK: - Extensions

struct PluginPaneView: NSViewRepresentable
{
	let index: Int

	func makeNSView(context: Context) -> NSView
	{
		let container = NSView()

		if let pane = TDCSettingsBridge.pluginPaneView(at: UInt(index)) {
			pane.removeFromSuperview()

			pane.translatesAutoresizingMaskIntoConstraints = false

			container.addSubview(pane)

			NSLayoutConstraint.activate([
				pane.topAnchor.constraint(equalTo: container.topAnchor),
				pane.centerXAnchor.constraint(equalTo: container.centerXAnchor),
				pane.widthAnchor.constraint(equalToConstant: pane.frame.width),
				pane.heightAnchor.constraint(equalToConstant: pane.frame.height)
			])
		}

		return container
	}

	func updateNSView(_ nsView: NSView, context: Context)
	{
	}
}

struct ExtensionsSettings: View
{
	private let paneTitles = TDCSettingsBridge.pluginPaneTitles
	private let commands = TDCSettingsBridge.addonCommands

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .extensions)
			}

			if (paneTitles.isEmpty == false) {
				Section(SettingsText("set-ext-h1")) {
					ForEach(Array(paneTitles.enumerated()), id: \.offset) { (index, title) in
						NavigationLink(title) {
							ScrollView {
								PluginPaneView(index: index)
									.frame(minHeight: 400)
									.padding()
							}
							.navigationTitle(title)
						}
					}
				}
			}

			Section {
				if (commands.isEmpty) {
					Text(SettingsText("set-ext-n"))
						.foregroundStyle(.secondary)
				} else {
					Text(commands.map { "/" + $0 }.joined(separator: "  "))
						.textSelection(.enabled)
				}

				LabeledContent {
					Button(SettingsText("set-ext-o")) {
						TDCSettingsBridge.openAddonsFolder()
					}
				} label: {
					SettingLabel(title: SettingsText("set-ext-f"), help: SettingsText("set-ext-fh"))
				}
			} header: {
				Text(SettingsText("set-ext-h2"))
			}
		}
	}
}

// MARK: - Advanced

struct AdvancedSettings: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	private static let visibleLimits = [0, 500, 1000, 2500, 5000, 10000, 15000]

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: .advanced)
			}

			Section(SettingsText("set-adv-h1")) {
				LabeledContent {
					Button(SettingsText("set-adv-ce")) {
						if let window = model.window {
							TDCSettingsBridge.editCustomStyleSheet(in: window)
						}
					}
				} label: {
					SettingLabel(title: SettingsText("set-adv-c"), help: SettingsText("set-adv-ch"))
				}

				SettingToggle(title: SettingsText("set-adv-r"), help: SettingsText("set-adv-rh"),
							  isOn: store.bool("AutomaticallyReloadCustomThemesWhenTheyChange"))
			}

			Section(SettingsText("set-adv-h2")) {
				let limit = store.value(get: { TDCSettingsBridge.scrollbackVisibleLimit }, set: { TDCSettingsBridge.scrollbackVisibleLimit = $0 })

				Picker(selection: limit) {
					ForEach((Self.visibleLimits.contains(limit.wrappedValue) ? Self.visibleLimits : (Self.visibleLimits + [limit.wrappedValue])), id: \.self) { value in
						Text((value == 0) ? SettingsText("set-adv-vd") : value.formatted()).tag(value)
					}
				} label: {
					SettingLabel(title: SettingsText("set-adv-v"), help: SettingsText("set-adv-vh"))
				}
			}
		}
	}
}

// MARK: - Not rebuilt yet

/// A section whose page isn't rebuilt yet: its settings open in the old Preferences window
struct LegacySettings: View
{
	let section: SettingsSection

	private var panes: [(String, Int)]
	{
		switch section {
			case .appearance: return [("set-old-style", 106), ("set-old-interface", 105)]
			case .messages: return [("set-old-style", 106), ("set-old-incoming", 108003)]
			case .typing: return [("set-old-controls", 107)]
			case .notifications: return [("set-old-notifications", 103)]
			case .highlights: return [("set-old-highlights", 104)]
			case .previews: return [("set-old-previews", 108006)]
			case .history: return [("set-old-history", 110), ("set-old-behavior", 102)]
			default: return []
		}
	}

	var body: some View
	{
		Form {
			Section {
				SettingsPageHeader(section: section)
			}

			Section {
				Text(SettingsText("set-old-n"))
					.foregroundStyle(.secondary)

				ForEach(panes, id: \.1) { (title, tag) in
					LabeledContent(SettingsText(title)) {
						Button(SettingsText("set-old-o")) {
							TDCSettingsBridge.showLegacyPreferencesPane(withTag: tag)
						}
					}
				}
			}
		}
	}
}
