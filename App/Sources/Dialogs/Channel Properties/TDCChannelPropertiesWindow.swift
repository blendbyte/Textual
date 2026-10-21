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

/* The Channel Properties sheet's window, in the look of Settings: one page
 with the channel, how it notifies you, its messages and the archive, and
 what's rarely needed under More. The sheet (TDCChannelPropertiesSheet)
 opens it and hands the edited configuration on. */

/// A string of the Channel Properties sheet (TDCChannelPropertiesSheet.strings)
func ChannelPropertiesText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCChannelPropertiesSheet[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

/// What the channel alerts you about: muted is Nothing, without
/// pushNotifications only highlights are left
enum ChannelPropertiesNotify: Int
{
	case asInSettings
	case onlyHighlights
	case nothing
}

/// Previews in this channel: inlineMediaEnabled and inlineMediaDisabled
enum ChannelPropertiesPreviews: Int
{
	case asInSettings
	case show
	case hide
}

// MARK: - Model

final class ChannelPropertiesModel: ObservableObject
{
	let config: IRCChannelConfigMutable

	let isNew: Bool

	private weak var client: IRCClient?

	weak var window: NSWindow?

	@Published var name = ""
	@Published var key = ""
	@Published var label = ""
	@Published var autoJoin = true
	@Published var notify = ChannelPropertiesNotify.asInSettings
	@Published var showsUnreadCount = true
	@Published var previews = ChannelPropertiesPreviews.asInSettings
	@Published var formatting = IRCChannelFormatting.global
	@Published var mentionsAreHighlights = true
	@Published var showsEvents = true
	@Published var keepsInArchive = true
	@Published var topic = ""
	@Published var modes = ""

	/* Events with alerts of their own here, as chosen or saved */
	@Published var customEvents: Set<UInt> = []

	@Published private(set) var archivedCount = 0

	let errors = ServerPropertiesFieldErrors()

	static let events: [TXNotificationType] = [.highlight, .channelMessage, .channelNotice, .userJoined, .userParted]

	init(config: IRCChannelConfigMutable, client: IRCClient?)
	{
		self.config = config
		self.client = client

		isNew = config.channelName.isEmpty

		load()

		countArchivedMessages()
	}

	private func load()
	{
		name = config.channelName
		key = (config.secretKey ?? "")
		label = (config.label ?? "")

		autoJoin = config.autoJoin

		if (config.muted) {
			notify = .nothing
		} else {
			notify = ((config.pushNotifications) ? .asInSettings : .onlyHighlights)
		}

		showsUnreadCount = config.showTreeBadgeCount

		/* Both set, as the old sheet allowed: the one that changes something now */
		if (config.inlineMediaEnabled && config.inlineMediaDisabled) {
			previews = ((TPCPreferences.showInlineMedia()) ? .hide : .show)
		} else if (config.inlineMediaDisabled) {
			previews = .hide
		} else if (config.inlineMediaEnabled) {
			previews = .show
		} else {
			previews = .asInSettings
		}

		formatting = config.formatting

		mentionsAreHighlights = (config.ignoreHighlights == false)
		showsEvents = (config.ignoreGeneralEventMessages == false)
		keepsInArchive = (config.excludedFromArchive == false)

		topic = (config.defaultTopic ?? "")
		modes = (config.defaultModes ?? "")

		for event in Self.events where hasOwnAlerts(event) {
			customEvents.insert(event.rawValue)
		}
	}

	/* Writes the page into the configuration; false while something can't be saved */
	func apply() -> Bool
	{
		if (hasInvalidField) {
			errors.showsAll = true

			return false
		}

		if (isNew) {
			config.channelName = firstWord(name)
		}

		config.secretKey = firstWord(key)
		config.label = label.trimmingCharacters(in: .whitespacesAndNewlines)

		config.autoJoin = autoJoin

		switch notify {
			case .asInSettings:
				config.muted = false
				config.pushNotifications = true
			case .onlyHighlights:
				config.muted = false
				config.pushNotifications = false
			case .nothing:
				config.muted = true
		}

		config.showTreeBadgeCount = showsUnreadCount

		config.inlineMediaEnabled = (previews == .show)
		config.inlineMediaDisabled = (previews == .hide)

		config.formatting = formatting

		config.ignoreHighlights = (mentionsAreHighlights == false)
		config.ignoreGeneralEventMessages = (showsEvents == false)
		config.excludedFromArchive = (keepsInArchive == false)

		config.defaultTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
		config.defaultModes = modes.trimmingCharacters(in: .whitespacesAndNewlines)

		return true
	}

	func binding(_ keyPath: ReferenceWritableKeyPath<ChannelPropertiesModel, String>, field: String) -> Binding<String>
	{
		Binding {
			self[keyPath: keyPath]
		} set: { (value) in
			/* A field with the keyboard focus sets what it has: not an edit */
			if (self[keyPath: keyPath] == value) {
				return
			}

			self[keyPath: keyPath] = value

			self.errors.edit(field)
		}
	}

	private func firstWord(_ value: String) -> String
	{
		String(value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first ?? "")
	}

	// MARK: Errors

	var hasInvalidField: Bool
	{
		(nameError != nil || keyError != nil)
	}

	var nameError: String?
	{
		if (isNew == false) {
			return nil
		}

		let value = firstWord(name)

		if (value.isEmpty) {
			return LocalizedKey("BasicLanguage[fo8-1h]")
		}

		let isChannelName: Bool

		if let client = client {
			isChannelName = (value as NSString).isChannelName(on: client)
		} else {
			isChannelName = (value as NSString).isChannelName
		}

		return ((isChannelName) ? nil : ChannelPropertiesText("1nd-7x"))
	}

	/* A key is one word: the JOIN command has nowhere for a space */
	var keyError: String?
	{
		let value = key.trimmingCharacters(in: .whitespacesAndNewlines)

		if (value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil) {
			return ChannelPropertiesText("cp-key-e1")
		}

		return nil
	}

	/* The network says how long a key may be */
	var keyNote: String?
	{
		guard let client = client else {
			return nil
		}

		let maximumLength = client.supportInfo.maximumKeyLength

		if (maximumLength == 0 || key.trimmingCharacters(in: .whitespacesAndNewlines).count <= maximumLength) {
			return nil
		}

		return ChannelPropertiesText("cp-key-n1", client.networkNameAlt, maximumLength)
	}

	// MARK: Text

	var title: String
	{
		((isNew) ? ChannelPropertiesText("cp-title-new") : config.channelName)
	}

	var subtitle: String?
	{
		client?.name
	}

	var notifyHelp: String
	{
		switch notify {
			case .asInSettings: return ChannelPropertiesText("cp-ntf-h0")
			case .onlyHighlights: return ChannelPropertiesText("cp-ntf-h1")
			case .nothing: return ChannelPropertiesText("cp-ntf-h2")
		}
	}

	var previewsDefault: String
	{
		ChannelPropertiesText((TPCPreferences.showInlineMedia()) ? "cp-pre-on" : "cp-pre-off")
	}

	var formattingDefault: String
	{
		ChannelPropertiesText((TPCPreferences.removeAllFormatting()) ? "fmt-p2" : "fmt-p3")
	}

	// MARK: Alerts

	/* Any of its options set for this channel */
	private func hasOwnAlerts(_ event: TXNotificationType) -> Bool
	{
		(config.sound(forEvent: event) != nil ||
		 config.notificationEnabled(forEvent: event) != .mixed ||
		 config.bounceDockIcon(forEvent: event) != .mixed ||
		 config.bounceDockIconRepeatedly(forEvent: event) != .mixed ||
		 config.speakEvent(event) != .mixed ||
		 config.disabledWhileAway(forEvent: event) != .mixed)
	}

	func customBinding(_ event: TXNotificationType) -> Binding<Bool>
	{
		Binding {
			self.customEvents.contains(event.rawValue)
		} set: { (custom) in
			withAnimation {
				if (custom) {
					self.customEvents.insert(event.rawValue)

					return
				}

				self.customEvents.remove(event.rawValue)

				/* Back to Settings: its own options go */
				self.config.setSound(nil, forEvent: event)
				self.config.setNotificationEnabled(.mixed, forEvent: event)
				self.config.setBounceDockIcon(.mixed, forEvent: event)
				self.config.setBounceDockIconRepeatedly(.mixed, forEvent: event)
				self.config.setEventIsSpoken(.mixed, forEvent: event)
				self.config.setDisabledWhileAway(.mixed, forEvent: event)
			}
		}
	}

	/* An option: this channel's value, else the one in Settings */
	private func option(_ value: NSControl.StateValue, else globalValue: Bool) -> Bool
	{
		((value == .mixed) ? globalValue : (value == .on))
	}

	private func state(_ value: Bool) -> NSControl.StateValue
	{
		((value) ? .on : .off)
	}

	func showsNotificationBinding(_ event: TXNotificationType) -> Binding<Bool>
	{
		Binding {
			self.option(self.config.notificationEnabled(forEvent: event), else: TPCPreferences.notificationEnabled(forEvent: event))
		} set: { (value) in
			self.objectWillChange.send()

			self.config.setNotificationEnabled(self.state(value), forEvent: event)
		}
	}

	func speaksBinding(_ event: TXNotificationType) -> Binding<Bool>
	{
		Binding {
			self.option(self.config.speakEvent(event), else: TPCPreferences.speakEvent(event))
		} set: { (value) in
			self.objectWillChange.send()

			self.config.setEventIsSpoken(self.state(value), forEvent: event)
		}
	}

	func quietWhileAwayBinding(_ event: TXNotificationType) -> Binding<Bool>
	{
		Binding {
			self.option(self.config.disabledWhileAway(forEvent: event), else: TPCPreferences.disabledWhileAway(forEvent: event))
		} set: { (value) in
			self.objectWillChange.send()

			self.config.setDisabledWhileAway(self.state(value), forEvent: event)
		}
	}

	/* No, once, or until you switch to Textual */
	func dockBinding(_ event: TXNotificationType) -> Binding<Int>
	{
		Binding {
			let bounces = self.option(self.config.bounceDockIcon(forEvent: event), else: TPCPreferences.bounceDockIcon(forEvent: event))
			let repeatedly = self.option(self.config.bounceDockIconRepeatedly(forEvent: event), else: TPCPreferences.bounceDockIconRepeatedly(forEvent: event))

			return ((bounces == false) ? 0 : ((repeatedly) ? 2 : 1))
		} set: { (value) in
			self.objectWillChange.send()

			self.config.setBounceDockIcon(self.state(value != 0), forEvent: event)
			self.config.setBounceDockIconRepeatedly(self.state(value == 2), forEvent: event)
		}
	}

	static let noSound = ""

	/* "None" stored is no sound; nothing stored is the one in Settings */
	private static func soundName(_ value: String?) -> String
	{
		guard let value = value, value.isEmpty == false, value != "None" else {
			return noSound
		}

		return value
	}

	func soundBinding(_ event: TXNotificationType) -> Binding<String>
	{
		Binding {
			Self.soundName(self.config.sound(forEvent: event) ?? TPCPreferences.sound(forEvent: event))
		} set: { (value) in
			self.objectWillChange.send()

			self.config.setSound(((value == Self.noSound) ? "None" : value), forEvent: event)

			if (value != Self.noSound) {
				TDCSettingsBridge.playAlertSound(value)
			}
		}
	}

	// MARK: Archive

	/* While the archive is off there's nothing to leave out */
	var archiveIsOn: Bool
	{
		(TPCPreferences.messageArchiveKeepPeriod != .off)
	}

	/* Left out with its whole server */
	var serverIsExcludedFromArchive: Bool
	{
		(client?.config.excludedFromArchive ?? false)
	}

	var archiveHelp: String
	{
		if (archiveIsOn == false) {
			return ChannelPropertiesText("cp-arc-off")
		} else if (serverIsExcludedFromArchive) {
			return ChannelPropertiesText("cp-arc-srv")
		}

		return ChannelPropertiesText("cp-arc-h")
	}

	private func countArchivedMessages()
	{
		guard isNew == false else {
			return
		}

		TLOMessageArchive.shared().countMessages(ofServer: nil, inView: config.uniqueIdentifier) { (count) in
			DispatchQueue.main.async {
				self.archivedCount = Int(count)
			}
		}
	}

	/* At once, after asking: not undone by Cancel */
	func deleteArchivedMessages()
	{
		guard let window = window else {
			return
		}

		let viewId = config.uniqueIdentifier

		let alert = NSAlert()

		alert.alertStyle = .warning
		alert.messageText = ChannelPropertiesText("arc-d1", config.channelName)
		alert.informativeText = ChannelPropertiesText("arc-d2", NumberFormatter.localizedString(from: NSNumber(value: archivedCount), number: .decimal))

		alert.addButton(withTitle: ChannelPropertiesText("arc-d3"))
		alert.addButton(withTitle: LocalizedKey("Prompts[qso-2g]"))

		alert.buttons.first?.hasDestructiveAction = true

		alert.beginSheetModal(for: window) { (response) in
			if (response != .alertFirstButtonReturn) {
				return
			}

			TLOMessageArchive.shared().deleteMessages(ofServer: nil, inView: viewId) {
				self.countArchivedMessages()
			}
		}
	}
}

// MARK: - Window

@objc(TDCChannelPropertiesWindow)
final class ChannelPropertiesWindow: NSObject
{
	@objc let window: NSWindow

	private let model: ChannelPropertiesModel

	@objc(initWithConfig:client:save:cancel:)
	init(config: IRCChannelConfigMutable, client: IRCClient?, save: @escaping () -> Void, cancel: @escaping () -> Void)
	{
		model = ChannelPropertiesModel(config: config, client: client)

		window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: ChannelPropertiesView.width, height: ChannelPropertiesView.height),
						  styleMask: [.titled],
						  backing: .buffered,
						  defer: true)

		window.isReleasedWhenClosed = false

		window.title = ChannelPropertiesText("cp-title")

		window.contentViewController = NSHostingController(rootView: ChannelPropertiesView(model: model, save: save, cancel: cancel))

		model.window = window

		super.init()
	}

	/* Into the configuration; false while something can't be saved (shown under it) */
	@objc func applyChanges() -> Bool
	{
		model.apply()
	}
}

// MARK: - Page

struct ChannelPropertiesView: View
{
	static let width: CGFloat = 560
	static let height: CGFloat = 620

	@ObservedObject var model: ChannelPropertiesModel
	@ObservedObject var errors: ServerPropertiesFieldErrors

	let save: () -> Void
	let cancel: () -> Void

	@State private var showsMore = false

	init(model: ChannelPropertiesModel, save: @escaping () -> Void, cancel: @escaping () -> Void)
	{
		self.model = model
		self.errors = model.errors
		self.save = save
		self.cancel = cancel
	}

	var body: some View
	{
		VStack(spacing: 0) {
			Form {
				Section {
					ChannelPropertiesHeader(title: model.title, subtitle: model.subtitle)
				}

				channelSection

				notificationsSection

				if (model.notify != .nothing) {
					alertsSection
				}

				messagesSection

				archiveSection

				Section {
					ServerPropertiesMoreRow(isExpanded: $showsMore)
				}

				if (showsMore) {
					emptyChannelSection
				}
			}
			.formStyle(.grouped)

			Divider()

			HStack {
				Spacer()

				Button(ServerPropertiesText("spp-b-cancel")) {
					cancel()
				}
				.keyboardShortcut(.cancelAction)

				Button(ServerPropertiesText("spp-b-save")) {
					save()
				}
				.keyboardShortcut(.defaultAction)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 14)
		}
		.frame(width: Self.width, height: Self.height)
	}

	private var channelSection: some View
	{
		Section {
			ServerPropertiesField(title: ChannelPropertiesText("cp-name"),
								  help: ((model.isNew) ? ChannelPropertiesText("cp-nameh") : nil),
								  error: errors.shown(model.nameError, for: "name")) {
				TextField(ChannelPropertiesText("cp-name"), text: model.binding(\.name, field: "name"), prompt: Text(verbatim: "#example"))
			}
			.disabled(model.isNew == false)

			ServerPropertiesField(title: ChannelPropertiesText("cp-key"),
								  help: (model.keyNote ?? ChannelPropertiesText("cp-keyh")),
								  error: errors.shown(model.keyError, for: "key")) {
				SecureField(ChannelPropertiesText("cp-key"), text: model.binding(\.key, field: "key"), prompt: Text(ServerPropertiesText("spp-optional")))
			}

			ServerPropertiesField(title: ChannelPropertiesText("cp-label"),
								  help: ChannelPropertiesText("cp-labelh"),
								  error: nil) {
				TextField(ChannelPropertiesText("cp-label"), text: $model.label, prompt: Text(ServerPropertiesText("spp-optional")))
			}

			SettingToggle(title: ChannelPropertiesText("cp-join"), help: ChannelPropertiesText("cp-joinh"), isOn: $model.autoJoin)
		}
	}

	private var notificationsSection: some View
	{
		Section(ChannelPropertiesText("cp-ntf-h")) {
			Picker(selection: $model.notify) {
				Text(ChannelPropertiesText("cp-ntf-0")).tag(ChannelPropertiesNotify.asInSettings)
				Text(ChannelPropertiesText("cp-ntf-1")).tag(ChannelPropertiesNotify.onlyHighlights)
				Text(ChannelPropertiesText("cp-ntf-2")).tag(ChannelPropertiesNotify.nothing)
			} label: {
				SettingLabel(title: ChannelPropertiesText("cp-ntf"), help: model.notifyHelp)
			}

			SettingToggle(title: ChannelPropertiesText("cp-badge"), help: ChannelPropertiesText("cp-badgeh"), isOn: $model.showsUnreadCount)
		}
	}

	private var alertsSection: some View
	{
		Section {
			ForEach(ChannelPropertiesModel.events, id: \.rawValue) { (event) in
				Picker(selection: model.customBinding(event)) {
					Text(ChannelPropertiesText("cp-alt-0")).tag(false)
					Text(ChannelPropertiesText("cp-alt-1")).tag(true)
				} label: {
					SettingLabel(title: TDCSettingsBridge.title(forNotificationEvent: Int(event.rawValue)))
				}

				if (model.customEvents.contains(event.rawValue)) {
					ChannelPropertiesEventOptions(model: model, event: event)
				}
			}
		} header: {
			Text(ChannelPropertiesText("cp-alt-h"))
		} footer: {
			SettingFooter(text: ChannelPropertiesText("cp-alt-n"))
		}
	}

	private var messagesSection: some View
	{
		Section(ChannelPropertiesText("cp-msg-h")) {
			Picker(selection: $model.previews) {
				Text(ChannelPropertiesText("cp-same", model.previewsDefault)).tag(ChannelPropertiesPreviews.asInSettings)

				Divider()

				Text(ChannelPropertiesText("cp-pre-on")).tag(ChannelPropertiesPreviews.show)
				Text(ChannelPropertiesText("cp-pre-off")).tag(ChannelPropertiesPreviews.hide)
			} label: {
				SettingLabel(title: ChannelPropertiesText("cp-pre"), help: ChannelPropertiesText("cp-preh"))
			}

			Picker(selection: $model.formatting) {
				Text(ChannelPropertiesText("cp-same", model.formattingDefault)).tag(IRCChannelFormatting.global)

				Divider()

				Text(ChannelPropertiesText("fmt-p3")).tag(IRCChannelFormatting.show)
				Text(ChannelPropertiesText("fmt-p2")).tag(IRCChannelFormatting.remove)
			} label: {
				SettingLabel(title: ChannelPropertiesText("cp-fmt"), help: ChannelPropertiesText("cp-fmth"))
			}

			SettingToggle(title: ChannelPropertiesText("cp-hil"), help: ChannelPropertiesText("cp-hilh"), isOn: $model.mentionsAreHighlights)

			SettingToggle(title: ChannelPropertiesText("cp-evt"), help: ChannelPropertiesText("cp-evth"), isOn: $model.showsEvents)
		}
	}

	private var archiveSection: some View
	{
		Section(ChannelPropertiesText("cp-arc-t")) {
			SettingToggle(title: ChannelPropertiesText("arc-c1"), help: model.archiveHelp, isOn: $model.keepsInArchive)
				.disabled(model.archiveIsOn == false)

			if (model.isNew == false) {
				LabeledContent {
					Button(ChannelPropertiesText("arc-b1")) {
						model.deleteArchivedMessages()
					}
					.disabled(model.archivedCount == 0)
				} label: {
					SettingLabel(title: ChannelPropertiesText("cp-arc-n", NumberFormatter.localizedString(from: NSNumber(value: model.archivedCount), number: .decimal)))
				}
			}
		}
	}

	private var emptyChannelSection: some View
	{
		Section {
			ServerPropertiesField(title: ChannelPropertiesText("cp-topic"), error: nil) {
				TextField(ChannelPropertiesText("cp-topic"), text: $model.topic, prompt: Text(ServerPropertiesText("spp-optional")), axis: .vertical)
					.lineLimit(1...4)
			}

			ServerPropertiesField(title: ChannelPropertiesText("cp-modes"), help: ChannelPropertiesText("cp-modesh"), error: nil) {
				TextField(ChannelPropertiesText("cp-modes"), text: $model.modes, prompt: Text(verbatim: "+nt"))
			}
		} header: {
			Text(ChannelPropertiesText("cp-empty-h"))
		} footer: {
			SettingFooter(text: ChannelPropertiesText("cp-empty-n"))
		}
	}
}

/// The channel's name and server, as a page's header
struct ChannelPropertiesHeader: View
{
	let title: String
	let subtitle: String?

	var body: some View
	{
		VStack(spacing: 6) {
			Image(systemName: "number")
				.font(.system(size: 26, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 48, height: 48)
				.background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .systemGreen).gradient))
				.padding(.bottom, 4)
				.accessibilityHidden(true)

			Text(title)
				.font(.title.weight(.semibold))

			if let subtitle = subtitle {
				Text(subtitle)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 10)
	}
}

/// An event's own alerts here, as on its page in Settings › Notifications
struct ChannelPropertiesEventOptions: View
{
	@ObservedObject var model: ChannelPropertiesModel
	let event: TXNotificationType

	var body: some View
	{
		let sound = model.soundBinding(event)
		let sounds = TDCSettingsBridge.alertSounds

		Group {
			SettingToggle(title: SettingsText("set-not-e1"), isOn: model.showsNotificationBinding(event))

			Picker(selection: sound) {
				Text(SettingsText("set-not-e2n")).tag(ChannelPropertiesModel.noSound)

				Divider()

				ForEach((sounds.contains(sound.wrappedValue) || sound.wrappedValue == ChannelPropertiesModel.noSound) ? sounds : (sounds + [sound.wrappedValue]), id: \.self) { (name) in
					Text(name).tag(name)
				}
			} label: {
				SettingLabel(title: SettingsText("set-not-e2"))
			}

			Picker(selection: model.dockBinding(event)) {
				Text(SettingsText("set-not-e30")).tag(0)
				Text(SettingsText("set-not-e31")).tag(1)
				Text(SettingsText("set-not-e32")).tag(2)
			} label: {
				SettingLabel(title: SettingsText("set-not-e3"))
			}

			SettingToggle(title: SettingsText("set-not-e4"), isOn: model.speaksBinding(event))

			SettingToggle(title: SettingsText("set-not-e5"), isOn: model.quietWhileAwayBinding(event))
		}
		.padding(.leading, 20)
	}
}
