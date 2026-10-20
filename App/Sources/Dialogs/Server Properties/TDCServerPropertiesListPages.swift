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

/* The Channels, People and Messages pages: channels to join, people to
 ignore or track, and what's said when you leave and what's kept */

/// A small button in a row, as an icon
struct ServerPropertiesRowButton: View
{
	let symbol: String
	let help: String
	let action: () -> Void

	var body: some View
	{
		Button(action: action) {
			Image(systemName: symbol)
				.foregroundStyle(.secondary)
		}
		.buttonStyle(.plain)
		.help(help)
	}
}

// MARK: - Channels

@objc(TDCServerPropertiesChannelsPane)
final class ServerPropertiesChannelsPane: TDCServerPropertiesPane, ObservableObject, TDCChannelPropertiesSheetDelegate
{
	/* Channels and queries: only the channels are shown, the queries are kept where they are */
	@Published private(set) var allConfigs: [IRCChannelConfig] = []

	/* Whether a channel has a key: read from the Keychain once per channel */
	private var hasKeyCache: [String: Bool] = [:]

	private var childSheet: TDCChannelPropertiesSheet?

	var channels: [IRCChannelConfig]
	{
		allConfigs.filter { $0.type == .channel }
	}

	override func load(from config: IRCClientConfig)
	{
		allConfigs = config.channelList
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.channelList = allConfigs
	}

	override func closeChildSheets()
	{
		childSheet?.close()
	}

	func hasKey(_ config: IRCChannelConfig) -> Bool
	{
		if let hasKey = hasKeyCache[config.uniqueIdentifier] {
			return hasKey
		}

		let hasKey = ((config.secretKey ?? "").isEmpty == false)

		hasKeyCache[config.uniqueIdentifier] = hasKey

		return hasKey
	}

	func joinsBinding(_ config: IRCChannelConfig) -> Binding<Bool>
	{
		Binding {
			config.autoJoin
		} set: { (value) in
			guard let changed = config.mutableCopy() as? IRCChannelConfigMutable else {
				return
			}

			changed.autoJoin = value

			self.replace(config, with: (changed.copy() as! IRCChannelConfig))
		}
	}

	private func replace(_ config: IRCChannelConfig, with newConfig: IRCChannelConfig)
	{
		guard let index = allConfigs.firstIndex(where: { $0 === config }) else {
			return
		}

		allConfigs[index] = newConfig
	}

	/* The channels in a new order, in the places channels had: queries stay put */
	private func setChannels(_ newChannels: [IRCChannelConfig])
	{
		var remaining = newChannels[...]

		allConfigs = allConfigs.map { (config) in
			((config.type == .channel) ? (remaining.popFirst() ?? config) : config)
		}
	}

	/* A channel dragged onto another goes in its place, the other one down (or up) */
	func move(channelWithId channelId: String, to config: IRCChannelConfig)
	{
		var newChannels = channels

		guard let fromIndex = newChannels.firstIndex(where: { $0.uniqueIdentifier == channelId }),
			  let toIndex = newChannels.firstIndex(where: { $0 === config }),
			  fromIndex != toIndex else {
			return
		}

		newChannels.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: ((toIndex > fromIndex) ? (toIndex + 1) : toIndex))

		setChannels(newChannels)
	}

	func move(_ config: IRCChannelConfig, by offset: Int)
	{
		var newChannels = channels

		guard let index = newChannels.firstIndex(where: { $0 === config }) else {
			return
		}

		let newIndex = (index + offset)

		guard newIndex >= 0, newIndex < newChannels.count else {
			return
		}

		newChannels.swapAt(index, newIndex)

		setChannels(newChannels)
	}

	func remove(_ config: IRCChannelConfig)
	{
		allConfigs.removeAll { $0 === config }
	}

	/* A new channel (nil) or one to edit, in Channel Properties */
	func edit(_ config: IRCChannelConfig?)
	{
		guard let window = propertiesSheet?.sheet else {
			return
		}

		let sheet: TDCChannelPropertiesSheet

		if let config = config {
			sheet = TDCChannelPropertiesSheet(config: config)

			sheet.window = window
		} else {
			sheet = TDCChannelPropertiesSheet(window: window)
		}

		sheet.delegate = self

		sheet.start()

		childSheet = sheet
	}

	func channelPropertiesSheet(_ sender: TDCChannelPropertiesSheet, onOk config: IRCChannelConfig)
	{
		let index = allConfigs.firstIndex { $0.uniqueIdentifier == config.uniqueIdentifier }

		/* A new channel with the name of one in the list made two entries for it */
		if (index == nil && allConfigs.contains(where: { $0.channelName.caseInsensitiveCompare(config.channelName) == .orderedSame })) {
			NSSound.beep()

			return
		}

		/* Its key may have changed */
		hasKeyCache[config.uniqueIdentifier] = nil

		if let index = index {
			allConfigs[index] = config
		} else {
			allConfigs.append(config)
		}
	}

	func channelPropertiesSheetWillClose(_ sender: TDCChannelPropertiesSheet)
	{
		childSheet = nil
	}
}

struct ChannelsPage: View
{
	@ObservedObject var pane: ServerPropertiesChannelsPane

	var body: some View
	{
		let channels = pane.channels

		Form {
			Section {
				ServerPropertiesPageHeader(page: .channels)
			}

			Section {
				ForEach(channels, id: \.uniqueIdentifier) { (channel) in
					HStack(spacing: 8) {
						Toggle(ServerPropertiesText("spp-chn-join"), isOn: pane.joinsBinding(channel))
							.toggleStyle(.checkbox)
							.labelsHidden()
							.help(ServerPropertiesText("spp-chn-join"))

						Text(channel.channelName)
							.foregroundStyle(channel.autoJoin ? .primary : .secondary)

						if (pane.hasKey(channel)) {
							Image(systemName: "lock.fill")
								.font(.callout)
								.foregroundStyle(.secondary)
								.help(ServerPropertiesText("spp-chn-key"))
						}

						Spacer()

						ServerPropertiesRowButton(symbol: "info.circle", help: ServerPropertiesText("spp-chn-edit")) {
							pane.edit(channel)
						}

						ServerPropertiesRowButton(symbol: "minus.circle.fill", help: ServerPropertiesText("spp-chn-remove")) {
							pane.remove(channel)
						}
					}
					.contentShape(Rectangle())
					.draggable(channel.uniqueIdentifier) {
						Text(channel.channelName)
					}
					.dropDestination(for: String.self) { (channelIds, _) in
						guard let channelId = channelIds.first else {
							return false
						}

						pane.move(channelWithId: channelId, to: channel)

						return true
					}
					.contextMenu {
						Button(ServerPropertiesText("spp-chn-edit")) {
							pane.edit(channel)
						}

						Divider()

						Button(ServerPropertiesText("spp-move-up")) {
							pane.move(channel, by: -1)
						}
						.disabled(channel === channels.first)

						Button(ServerPropertiesText("spp-move-down")) {
							pane.move(channel, by: 1)
						}
						.disabled(channel === channels.last)

						Divider()

						Button(ServerPropertiesText("spp-chn-remove")) {
							pane.remove(channel)
						}
					}
				}

				Button {
					pane.edit(nil)
				} label: {
					Label(ServerPropertiesText("spp-chn-add"), systemImage: "plus.circle.fill")
				}
				.buttonStyle(.borderless)
			} footer: {
				SettingFooter(text: ServerPropertiesText("spp-chn-note"))
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - People

@objc(TDCServerPropertiesPeoplePane)
final class ServerPropertiesPeoplePane: TDCServerPropertiesPane, ObservableObject, TDCAddressBookSheetDelegate
{
	@Published private(set) var entries: [IRCAddressBookEntry] = []

	private var childSheet: TDCAddressBookSheet?

	override func load(from config: IRCClientConfig)
	{
		entries = config.ignoreList
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.ignoreList = entries
	}

	override func closeChildSheets()
	{
		childSheet?.close()
	}

	func entries(ofType type: IRCAddressBookEntryType) -> [IRCAddressBookEntry]
	{
		entries.filter { $0.entryType == type }
	}

	private func show(_ sheet: TDCAddressBookSheet)
	{
		guard let window = propertiesSheet?.sheet else {
			return
		}

		sheet.delegate = self

		sheet.window = window

		sheet.start()

		childSheet = sheet
	}

	func add(_ type: IRCAddressBookEntryType)
	{
		show(TDCAddressBookSheet(forNewEntryOf: type))
	}

	/* From the sheet's start: an ignore for someone in the member list */
	@objc(addIgnoreEntryWithHostmask:)
	func addIgnoreEntry(hostmask: String?)
	{
		guard let hostmask = hostmask else {
			add(.ignore)

			return
		}

		show(TDCAddressBookSheet(config: IRCAddressBookEntry.newIgnore(forHostmask: hostmask)))
	}

	@objc(editEntry:)
	func edit(_ entry: IRCAddressBookEntry)
	{
		show(TDCAddressBookSheet(config: entry))
	}

	func remove(_ entry: IRCAddressBookEntry)
	{
		entries.removeAll { $0 === entry }
	}

	func addressBookSheet(_ sender: TDCAddressBookSheet, onOk config: IRCAddressBookEntry)
	{
		if let index = entries.firstIndex(where: { $0.uniqueIdentifier == config.uniqueIdentifier }) {
			entries[index] = config
		} else {
			entries.append(config)
		}
	}

	func addressBookSheetWillClose(_ sender: TDCAddressBookSheet)
	{
		childSheet = nil
	}

	/* What an ignore hides, in a few words */
	func summary(of entry: IRCAddressBookEntry) -> String
	{
		let parts: [(Bool, String)] = [
			(entry.ignorePublicMessages, "spp-ppl-i1"),
			(entry.ignorePrivateMessages, "spp-ppl-i2"),
			(entry.ignoreNoticeMessages, "spp-ppl-i3"),
			(entry.ignoreClientToClientProtocol, "spp-ppl-i4"),
			((entry.ignorePublicMessageHighlights || entry.ignorePrivateMessageHighlights), "spp-ppl-i5"),
			(entry.ignoreGeneralEventMessages, "spp-ppl-i6"),
			(entry.ignoreFileTransferRequests, "spp-ppl-i7"),
			(entry.ignoreInlineMedia, "spp-ppl-i8")
		]

		let ignored = parts.filter { $0.0 }.map { ServerPropertiesText($0.1) }

		if (ignored.isEmpty) {
			return ServerPropertiesText("spp-ppl-i0")
		} else if (ignored.count == parts.count) {
			return ServerPropertiesText("spp-ppl-ia")
		}

		let summary = ListFormatter.localizedString(byJoining: ignored)

		return (summary.prefix(1).uppercased() + summary.dropFirst())
	}
}

struct PeoplePage: View
{
	@ObservedObject var pane: ServerPropertiesPeoplePane

	@ViewBuilder
	private func rows(_ entries: [IRCAddressBookEntry], symbol: String, summary: @escaping (IRCAddressBookEntry) -> String?) -> some View
	{
		ForEach(entries, id: \.uniqueIdentifier) { (entry) in
			HStack(spacing: 8) {
				Image(systemName: symbol)
					.foregroundStyle(.secondary)
					.frame(width: 18)

				SettingLabel(title: entry.hostmask, help: summary(entry))

				Spacer()

				ServerPropertiesRowButton(symbol: "info.circle", help: ServerPropertiesText("spp-ppl-edit")) {
					pane.edit(entry)
				}

				ServerPropertiesRowButton(symbol: "minus.circle.fill", help: ServerPropertiesText("spp-ppl-remove")) {
					pane.remove(entry)
				}
			}
			.contentShape(Rectangle())
			.onTapGesture(count: 2) {
				pane.edit(entry)
			}
			.contextMenu {
				Button(ServerPropertiesText("spp-ppl-edit")) {
					pane.edit(entry)
				}

				Button(ServerPropertiesText("spp-ppl-remove")) {
					pane.remove(entry)
				}
			}
		}
	}

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .people)
			}

			Section {
				rows(pane.entries(ofType: .ignore), symbol: "eye.slash") { (entry) in
					pane.summary(of: entry)
				}

				Button {
					pane.add(.ignore)
				} label: {
					Label(ServerPropertiesText("spp-ppl-addi"), systemImage: "plus.circle.fill")
				}
				.buttonStyle(.borderless)
			} header: {
				Text(ServerPropertiesText("spp-ppl-h1"))
			} footer: {
				SettingFooter(text: ServerPropertiesText("spp-ppl-n1"))
			}

			Section {
				rows(pane.entries(ofType: .userTracking), symbol: "bell") { (_) in
					nil
				}

				Button {
					pane.add(.userTracking)
				} label: {
					Label(ServerPropertiesText("spp-ppl-addt"), systemImage: "plus.circle.fill")
				}
				.buttonStyle(.borderless)
			} header: {
				Text(ServerPropertiesText("spp-ppl-h2"))
			} footer: {
				SettingFooter(text: ServerPropertiesText("spp-ppl-n2"))
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - Messages

@objc(TDCServerPropertiesMessagesPane)
final class ServerPropertiesMessagesPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var leavingMessage = ""
	@Published var sleepLeavingMessage = ""
	@Published var keepsInArchive = true

	/* Messages of this server in the archive: Delete needs some */
	@Published private(set) var archivedCount = 0

	private var serverId: String?
	private var serverName = ""

	let errors = ServerPropertiesFieldErrors()

	static let maximumLength = 390

	override func load(from config: IRCClientConfig)
	{
		leavingMessage = config.normalLeavingComment
		sleepLeavingMessage = config.sleepModeLeavingComment

		keepsInArchive = (config.excludedFromArchive == false)

		serverId = config.uniqueIdentifier
		serverName = config.connectionName

		countArchivedMessages()
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.normalLeavingComment = leavingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
		config.sleepModeLeavingComment = sleepLeavingMessage.trimmingCharacters(in: .whitespacesAndNewlines)

		config.excludedFromArchive = (keepsInArchive == false)
	}

	override var hasInvalidField: Bool
	{
		(error(for: leavingMessage) != nil || error(for: sleepLeavingMessage) != nil)
	}

	override func showInvalidField()
	{
		errors.showsAll = true
	}

	func binding(_ keyPath: ReferenceWritableKeyPath<ServerPropertiesMessagesPane, String>, field: String) -> Binding<String>
	{
		Binding {
			self[keyPath: keyPath]
		} set: { (value) in
			self[keyPath: keyPath] = value

			self.errors.edit(field)
		}
	}

	func error(for message: String) -> String?
	{
		let value = message.trimmingCharacters(in: .whitespacesAndNewlines)

		if (value.rangeOfCharacter(from: .newlines) != nil) {
			return LocalizedKey("CommonErrors[gas-v8]")
		} else if (value.count > Self.maximumLength) {
			return LocalizedKey("CommonErrors[2cb-af]", Self.maximumLength)
		}

		return nil
	}

	/* While the archive is off there's nothing to leave out */
	var archiveIsOn: Bool
	{
		(TPCPreferences.messageArchiveKeepPeriod != .off)
	}

	private func countArchivedMessages()
	{
		guard let serverId = serverId else {
			return
		}

		TLOMessageArchive.shared().countMessages(ofServer: serverId, inView: nil) { (count) in
			DispatchQueue.main.async {
				self.archivedCount = Int(count)
			}
		}
	}

	func deleteArchivedMessages()
	{
		guard let serverId = serverId, let window = propertiesSheet?.sheet else {
			return
		}

		let alert = NSAlert()

		alert.alertStyle = .warning
		alert.messageText = ServerPropertiesText("arc-d1", serverName)
		alert.informativeText = ServerPropertiesText("arc-d2", NumberFormatter.localizedString(from: NSNumber(value: archivedCount), number: .decimal))

		alert.addButton(withTitle: ServerPropertiesText("arc-d3"))
		alert.addButton(withTitle: LocalizedKey("Prompts[qso-2g]"))

		alert.buttons.first?.hasDestructiveAction = true

		alert.beginSheetModal(for: window) { (response) in
			if (response != .alertFirstButtonReturn) {
				return
			}

			TLOMessageArchive.shared().deleteMessages(ofServer: serverId, inView: nil) {
				self.countArchivedMessages()
			}
		}
	}
}

struct MessagesPage: View
{
	@ObservedObject var pane: ServerPropertiesMessagesPane
	@ObservedObject var errors: ServerPropertiesFieldErrors

	init(pane: ServerPropertiesMessagesPane)
	{
		self.pane = pane
		self.errors = pane.errors
	}

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .messages)
			}

			Section {
				ServerPropertiesField(title: ServerPropertiesText("spp-msg-leave"),
									  help: ServerPropertiesText("spp-msg-leaveh"),
									  error: errors.shown(pane.error(for: pane.leavingMessage), for: "leave")) {
					TextField(ServerPropertiesText("spp-msg-leave"), text: pane.binding(\.leavingMessage, field: "leave"), prompt: Text(ServerPropertiesText("spp-optional")))
				}

				ServerPropertiesField(title: ServerPropertiesText("spp-msg-sleep"),
									  help: ServerPropertiesText("spp-msg-sleeph"),
									  error: errors.shown(pane.error(for: pane.sleepLeavingMessage), for: "sleep")) {
					TextField(ServerPropertiesText("spp-msg-sleep"), text: pane.binding(\.sleepLeavingMessage, field: "sleep"), prompt: Text(ServerPropertiesText("spp-optional")))
				}
			}

			Section {
				SettingToggle(title: ServerPropertiesText("arc-c1"),
							  help: (pane.archiveIsOn ? ServerPropertiesText("spp-msg-arch") : ServerPropertiesText("spp-msg-archoff")),
							  isOn: $pane.keepsInArchive)
					.disabled(pane.archiveIsOn == false)

				LabeledContent {
					Button(ServerPropertiesText("arc-b1")) {
						pane.deleteArchivedMessages()
					}
					.disabled(pane.archivedCount == 0)
				} label: {
					SettingLabel(title: ServerPropertiesText("spp-msg-count", NumberFormatter.localizedString(from: NSNumber(value: pane.archivedCount), number: .decimal)))
				}
			} header: {
				Text(ServerPropertiesText("spp-msg-h2"))
			}
		}
		.formStyle(.grouped)
	}
}
