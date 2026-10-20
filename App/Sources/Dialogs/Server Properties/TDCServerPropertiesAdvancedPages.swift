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

/* The Advanced pages: commands after connecting, the connection itself
 (addresses, text encoding, staying connected, flood control), security,
 the proxy, uploads and ZNC */

// MARK: - When Connected

@objc(TDCServerPropertiesWhenConnectedPane)
final class ServerPropertiesWhenConnectedPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var commands = ""
	@Published var invisible = false

	override func load(from config: IRCClientConfig)
	{
		commands = config.loginCommands.joined(separator: "\n")

		invisible = config.setInvisibleModeOnConnect
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		var lines: [String] = []

		for line in commands.components(separatedBy: .newlines) {
			let trimmed = line.trimmingCharacters(in: .whitespaces)

			if (trimmed.isEmpty == false) {
				lines.append(trimmed)
			}
		}

		config.loginCommands = lines

		config.setInvisibleModeOnConnect = invisible
	}
}

struct WhenConnectedPage: View
{
	@ObservedObject var pane: ServerPropertiesWhenConnectedPane

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .whenConnected)
			}

			Section {
				VStack(alignment: .leading, spacing: 8) {
					SettingLabel(title: ServerPropertiesText("spp-cmd-list"), help: ServerPropertiesText("spp-cmd-listh"))

					TextEditor(text: $pane.commands)
						.font(.system(size: 13).monospaced())
						.scrollContentBackground(.hidden)
						.padding(4)
						.frame(minHeight: 120)
						.background(Color(nsColor: .textBackgroundColor))
						.overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor)))
						.clipShape(RoundedRectangle(cornerRadius: 5))
						.accessibilityLabel(ServerPropertiesText("spp-cmd-list"))
				}
			}

			Section {
				SettingToggle(title: ServerPropertiesText("spp-cmd-invis"), help: ServerPropertiesText("spp-cmd-invish"), isOn: $pane.invisible)
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - Connection

/// A text encoding in the menus
struct ServerPropertiesEncoding: Hashable
{
	let value: UInt
	let title: String

	/* UTF-8, then the usual ones (Unicode, Western, Central European), then
	 the others, each kind in a group of its own */
	static let groups: [[ServerPropertiesEncoding]] = {
		let encodings = NSString.supportedStringEncodings(withTitle: false)

		let utf8Title = String.localizedName(of: .utf8)

		var groups = [[ServerPropertiesEncoding(value: String.Encoding.utf8.rawValue, title: utf8Title)]]

		let favored = ["Unicode", "Western", "Central European"]

		let titles = encodings.keys.sorted().filter { $0 != utf8Title }

		for favoredFirst in [true, false] {
			var previousKind: String?

			for title in titles {
				guard let range = title.range(of: " ("), range.lowerBound > title.startIndex,
					  let value = encodings[title] else {
					continue
				}

				let kind = String(title[..<range.lowerBound])

				if (favored.contains(kind) != favoredFirst) {
					continue
				}

				if (kind != previousKind) {
					groups.append([])

					previousKind = kind
				}

				groups[groups.count - 1].append(ServerPropertiesEncoding(value: value.uintValue, title: title))
			}
		}

		return groups
	}()

	/* One that isn't in the menus, set before */
	static func groups(with value: UInt) -> [[ServerPropertiesEncoding]]
	{
		if (groups.contains { $0.contains { $0.value == value } }) {
			return groups
		}

		return (groups + [[ServerPropertiesEncoding(value: value, title: String.localizedName(of: String.Encoding(rawValue: value)))]])
	}
}

@objc(TDCServerPropertiesConnectionPane)
final class ServerPropertiesConnectionPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var addressType = IRCConnectionAddressType.default
	@Published var primaryEncoding = String.Encoding.utf8.rawValue
	@Published var fallbackEncoding = String.Encoding.isoLatin1.rawValue
	@Published var checksWhenQuiet = true
	@Published var disconnectsWhenQuiet = false
	@Published var disconnectsOnNetworkChange = false
	@Published var floodControlMessages: UInt = 6
	@Published var floodControlInterval: UInt = 2

	/* Only saved when chosen: saving it also forgets the old "prefers IPv4" setting */
	private var addressTypeChanged = false

	static let floodControlMessageChoices: [UInt] = [1, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 60]
	static let floodControlIntervalChoices: [UInt] = [1, 2, 3, 4, 5, 10, 15, 20, 30, 60]

	var addressTypeBinding: Binding<IRCConnectionAddressType>
	{
		Binding {
			self.addressType
		} set: { (value) in
			self.addressType = value

			self.addressTypeChanged = true
		}
	}

	override func load(from config: IRCClientConfig)
	{
		addressType = config.addressType

		primaryEncoding = config.primaryEncoding
		fallbackEncoding = config.fallbackEncoding

		checksWhenQuiet = config.performPongTimer
		disconnectsWhenQuiet = config.performDisconnectOnPongTimer
		disconnectsOnNetworkChange = config.performDisconnectOnReachabilityChange

		floodControlMessages = config.floodControlMaximumMessages
		floodControlInterval = config.floodControlDelayTimerInterval
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		if (addressTypeChanged) {
			config.setAddressTypeChosenByUser(addressType)
		}

		config.primaryEncoding = primaryEncoding
		config.fallbackEncoding = fallbackEncoding

		config.performPongTimer = checksWhenQuiet
		config.performDisconnectOnPongTimer = disconnectsWhenQuiet
		config.performDisconnectOnReachabilityChange = disconnectsOnNetworkChange

		config.floodControlMaximumMessages = floodControlMessages
		config.floodControlDelayTimerInterval = floodControlInterval
	}
}

struct ConnectionPage: View
{
	@ObservedObject var pane: ServerPropertiesConnectionPane

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .connection)
			}

			Section {
				Picker(selection: pane.addressTypeBinding) {
					Text(ServerPropertiesText("spp-con-ip0")).tag(IRCConnectionAddressType.default)
					Text(ServerPropertiesText("spp-con-ip4")).tag(IRCConnectionAddressType.v4)
					Text(ServerPropertiesText("spp-con-ip6")).tag(IRCConnectionAddressType.v6)
				} label: {
					SettingLabel(title: ServerPropertiesText("spp-con-ip"), help: ServerPropertiesText("spp-con-iph"))
				}
			}

			Section(ServerPropertiesText("spp-con-h2")) {
				ServerPropertiesEncodingPicker(title: ServerPropertiesText("spp-con-enc"), help: ServerPropertiesText("spp-con-ench"), selection: $pane.primaryEncoding)

				ServerPropertiesEncodingPicker(title: ServerPropertiesText("spp-con-fb"), help: ServerPropertiesText("spp-con-fbh"), selection: $pane.fallbackEncoding)
			}

			Section(ServerPropertiesText("spp-con-h3")) {
				SettingToggle(title: ServerPropertiesText("spp-con-ping"), help: ServerPropertiesText("spp-con-pingh"), isOn: $pane.checksWhenQuiet)

				SettingToggle(title: ServerPropertiesText("spp-con-timeout"), help: ServerPropertiesText("spp-con-timeouth"), isOn: $pane.disconnectsWhenQuiet)

				SettingToggle(title: ServerPropertiesText("spp-con-reach"), help: ServerPropertiesText("spp-con-reachh"), isOn: $pane.disconnectsOnNetworkChange)
			}

			Section {
				SettingValuePicker(title: ServerPropertiesText("spp-con-fl1"), help: ServerPropertiesText("spp-con-fl1h"),
								   selection: $pane.floodControlMessages, values: ServerPropertiesConnectionPane.floodControlMessageChoices) { (value) in
					((value == 1) ? ServerPropertiesText("spp-con-fl1-1") : ServerPropertiesText("spp-con-fl1-n", value))
				}

				SettingValuePicker(title: ServerPropertiesText("spp-con-fl2"),
								   selection: $pane.floodControlInterval, values: ServerPropertiesConnectionPane.floodControlIntervalChoices) { (value) in
					((value == 1) ? ServerPropertiesText("spp-con-fl2-1") : ServerPropertiesText("spp-con-fl2-n", value))
				}
			} header: {
				Text(ServerPropertiesText("spp-con-h4"))
			} footer: {
				Text(ServerPropertiesText("spp-con-fln"))
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
	}
}

struct ServerPropertiesEncodingPicker: View
{
	let title: String
	let help: String
	@Binding var selection: UInt

	var body: some View
	{
		let groups = ServerPropertiesEncoding.groups(with: selection)

		Picker(selection: $selection) {
			ForEach(Array(groups.enumerated()), id: \.offset) { (index, group) in
				if (index > 0) {
					Divider()
				}

				ForEach(group, id: \.self) { (encoding) in
					Text(encoding.title).tag(encoding.value)
				}
			}
		} label: {
			SettingLabel(title: title, help: help)
		}
	}
}

// MARK: - Security

@objc(TDCServerPropertiesSecurityPane)
final class ServerPropertiesSecurityPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var validatesCertificate = true
	@Published var cipherSuites = RCMCipherSuiteCollection.default

	/* The servers, for what they asked about secure connections */
	@objc weak var serverPane: ServerPropertiesServerPane?

	static let cipherSuiteChoices: [RCMCipherSuiteCollection] = [.default, .mozilla2017, .mozilla2015, .none]

	static func title(of cipherSuites: RCMCipherSuiteCollection) -> String
	{
		ServerPropertiesText("spp-sec-c\(cipherSuites.rawValue)")
	}

	override func load(from config: IRCClientConfig)
	{
		validatesCertificate = config.validateServerCertificateChain

		cipherSuites = config.cipherSuites
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.validateServerCertificateChain = validatesCertificate

		config.cipherSuites = cipherSuites
	}

	func showCipherSuites()
	{
		guard let window = propertiesSheet?.sheet else {
			return
		}

		let descriptions = RCMSecureTransport.descriptions(forCipherListCollection: cipherSuites, withProtocol: true)

		let alert = NSAlert()

		alert.messageText = ServerPropertiesText("spp-sec-lt", Self.title(of: cipherSuites))
		alert.informativeText = ServerPropertiesText("spp-sec-lb", descriptions.joined(separator: "\n"))

		alert.addButton(withTitle: LocalizedKey("Prompts[c7s-dq]"))

		alert.beginSheetModal(for: window)
	}
}

struct SecurityPage: View
{
	@ObservedObject var pane: ServerPropertiesSecurityPane
	@ObservedObject var serverPane: ServerPropertiesServerPane

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .security)
			}

			Section {
				SettingToggle(title: ServerPropertiesText("spp-sec-valid"), help: ServerPropertiesText("spp-sec-validh"), isOn: $pane.validatesCertificate)

				LabeledContent {
					HStack(spacing: 8) {
						Picker(ServerPropertiesText("spp-sec-ciph"), selection: $pane.cipherSuites) {
							ForEach(ServerPropertiesSecurityPane.cipherSuiteChoices, id: \.self) { (cipherSuites) in
								Text(ServerPropertiesSecurityPane.title(of: cipherSuites)).tag(cipherSuites)
							}
						}
						.labelsHidden()
						.fixedSize()

						Button(ServerPropertiesText("spp-sec-show")) {
							pane.showCipherSuites()
						}
						.disabled(pane.cipherSuites == .none)
					}
				} label: {
					SettingLabel(title: ServerPropertiesText("spp-sec-ciph"), help: ServerPropertiesText("spp-sec-ciphh"))
				}
			}

			if let notice = serverPane.strictTransportSecurityNotice {
				Section {
					LabeledContent {
						Button(ServerPropertiesText("sts-b1")) {
							serverPane.forgetStrictTransportSecurity()
						}
					} label: {
						SettingLabel(title: notice, help: ServerPropertiesText("spp-sec-stsh"))
					}
				}
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - Proxy

@objc(TDCServerPropertiesProxyPane)
final class ServerPropertiesProxyPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var proxyType = IRCConnectionProxyType.none
	@Published var address = ""
	@Published var port = ""
	@Published var username = ""
	@Published var password = ""

	let errors = ServerPropertiesFieldErrors()

	static let typeChoices: [IRCConnectionProxyType] = [.none, .automatic, .socks5, .HTTP, .HTTPS, .tor]

	static func title(of proxyType: IRCConnectionProxyType) -> String
	{
		ServerPropertiesText("spp-prx-t\(proxyType.rawValue)")
	}

	/* SOCKS5 and HTTP(S) CONNECT proxies are given an address, a port and
	 optionally a username and password */
	var takesAddress: Bool
	{
		(proxyType == .socks5 || proxyType == .HTTP || proxyType == .HTTPS)
	}

	override func load(from config: IRCClientConfig)
	{
		/* SOCKS4 is no longer supported: it is SOCKS5 now */
		proxyType = ((config.proxyType == .socks4) ? .socks5 : config.proxyType)

		address = (config.proxyAddress ?? "")
		port = String(config.proxyPort)
		username = (config.proxyUsername ?? "")
		password = (config.proxyPassword ?? "")
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.proxyType = proxyType

		config.proxyAddress = firstWord(address).lowercased()

		config.proxyPort = (UInt16(port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? IRCConnectionDefaultProxyPort)

		config.proxyUsername = firstWord(username)
		config.proxyPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	override var hasInvalidField: Bool
	{
		(addressError != nil || portError != nil)
	}

	override func showInvalidField()
	{
		errors.showsAll = true
	}

	func binding(_ keyPath: ReferenceWritableKeyPath<ServerPropertiesProxyPane, String>, field: String) -> Binding<String>
	{
		Binding {
			self[keyPath: keyPath]
		} set: { (value) in
			self[keyPath: keyPath] = value

			self.errors.edit(field)
		}
	}

	private func firstWord(_ value: String) -> String
	{
		String(value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first ?? "")
	}

	var addressError: String?
	{
		if (takesAddress && (firstWord(address) as NSString).isValidInternetAddress == false) {
			return ServerPropertiesText("tlo-b6")
		}

		return nil
	}

	/* Empty: the usual port */
	var portError: String?
	{
		let value = port.trimmingCharacters(in: .whitespacesAndNewlines)

		if (takesAddress && value.isEmpty == false && (value as NSString).isValidInternetPort == false) {
			return LocalizedKey("CommonErrors[l0c-nb]")
		}

		return nil
	}

	/* Network → (the current service) Details → Proxies */
	func openProxySettings()
	{
		if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension?Proxies") {
			NSWorkspace.shared.open(url)
		}
	}
}

struct ProxyPage: View
{
	@ObservedObject var pane: ServerPropertiesProxyPane
	@ObservedObject var errors: ServerPropertiesFieldErrors

	init(pane: ServerPropertiesProxyPane)
	{
		self.pane = pane
		self.errors = pane.errors
	}

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .proxy)
			}

			Section {
				Picker(selection: $pane.proxyType) {
					ForEach(ServerPropertiesProxyPane.typeChoices, id: \.self) { (proxyType) in
						Text(ServerPropertiesProxyPane.title(of: proxyType)).tag(proxyType)
					}
				} label: {
					SettingLabel(title: ServerPropertiesText("spp-prx-type"))
				}

				if (pane.takesAddress) {
					ServerPropertiesField(title: ServerPropertiesText("spp-srv-addr"),
										  error: errors.shown(pane.addressError, for: "address")) {
						TextField(ServerPropertiesText("spp-srv-addr"), text: pane.binding(\.address, field: "address"), prompt: Text(verbatim: "proxy.example.com"))
					}

					ServerPropertiesField(title: ServerPropertiesText("spp-srv-port"),
										  error: errors.shown(pane.portError, for: "port")) {
						TextField(ServerPropertiesText("spp-srv-port"), text: pane.binding(\.port, field: "port"), prompt: Text(verbatim: String(IRCConnectionDefaultProxyPort)))
							.frame(width: 80)
					}

					ServerPropertiesField(title: ServerPropertiesText("spp-prx-user"), error: nil) {
						TextField(ServerPropertiesText("spp-prx-user"), text: $pane.username, prompt: Text(ServerPropertiesText("spp-optional")))
					}

					ServerPropertiesField(title: ServerPropertiesText("spp-prx-pass"), error: nil) {
						SecureField(ServerPropertiesText("spp-prx-pass"), text: $pane.password, prompt: Text(ServerPropertiesText("spp-optional")))
					}
				} else if (pane.proxyType == .automatic) {
					LabeledContent {
						Button(ServerPropertiesText("spp-prx-open")) {
							pane.openProxySettings()
						}
					} label: {
						SettingLabel(title: ServerPropertiesText("spp-prx-auto"))
					}
				} else if (pane.proxyType == .tor) {
					Text(ServerPropertiesText("spp-prx-tor"))
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			} footer: {
				Text(ServerPropertiesText("spp-prx-note"))
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - Uploads

/* Where files go on this network if it offers no uploads: the
 address in Settings, none, or this server's own */
@objc(TDCServerPropertiesUploadsPane)
final class ServerPropertiesUploadsPane: TDCServerPropertiesPane, ObservableObject
{
	@Published private(set) var mode = IRCClientUploadDestinationMode.default
	@Published private(set) var ownDestination: TLOUploadDestination?

	static let modeChoices: [IRCClientUploadDestinationMode] = [.default, .off, .own]

	var modeBinding: Binding<IRCClientUploadDestinationMode>
	{
		Binding {
			self.mode
		} set: { (value) in
			self.mode = value

			/* Its own, but none yet: set it up now */
			if (value == .own && self.ownDestination == nil) {
				self.editOwnDestination()
			}
		}
	}

	override func load(from config: IRCClientConfig)
	{
		if let propertyList = config.uploadDestination {
			ownDestination = TLOUploadDestination(propertyList: propertyList, secretsIdentifier: config.uniqueIdentifier)
		} else {
			ownDestination = nil
		}

		mode = config.uploadDestinationMode

		if (mode.rawValue > IRCClientUploadDestinationMode.own.rawValue || (mode == .own && ownDestination == nil)) {
			mode = .default
		}
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		/* The tokens go to the Keychain now, the rest with the server */
		if let ownDestination = ownDestination {
			ownDestination.saveSecrets(withIdentifier: config.uniqueIdentifier)

			config.uploadDestination = ownDestination.propertyList
		} else {
			TLOUploadDestination.removeSecrets(withIdentifier: config.uniqueIdentifier)

			config.uploadDestination = nil
		}

		config.uploadDestinationMode = ((mode == .own && ownDestination == nil) ? .default : mode)
	}

	func editOwnDestination()
	{
		guard let window = propertiesSheet?.sheet else {
			return
		}

		TDCUploadDestinationSheet.edit(ownDestination, in: window, showsHideOption: false) { (destination) in
			self.ownDestination = destination

			/* Removed: back to the one in Settings */
			if (destination == nil) {
				self.mode = .default
			}
		}
	}
}

struct UploadsPage: View
{
	@ObservedObject var pane: ServerPropertiesUploadsPane

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .uploads)
			}

			Section {
				Picker(selection: pane.modeBinding) {
					Text(ServerPropertiesText("upl-m1")).tag(IRCClientUploadDestinationMode.default)
					Text(ServerPropertiesText("upl-m2")).tag(IRCClientUploadDestinationMode.off)
					Text(ServerPropertiesText("upl-m3")).tag(IRCClientUploadDestinationMode.own)
				} label: {
					SettingLabel(title: ServerPropertiesText("spp-upl-mode"), help: ServerPropertiesText("upl-n1"))
				}

				if (pane.mode == .own) {
					LabeledContent {
						Button(ServerPropertiesText((pane.ownDestination != nil) ? "upl-b1" : "upl-b2")) {
							pane.editOwnDestination()
						}
					} label: {
						SettingLabel(title: (pane.ownDestination?.name ?? ServerPropertiesText("upl-o1")))
					}
				}
			}
		}
		.formStyle(.grouped)
	}
}

// MARK: - ZNC

@objc(TDCServerPropertiesZNCPane)
final class ServerPropertiesZNCPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var leavesJoiningToZNC = false
	@Published var quietPlayback = false
	@Published var playsBackOnlyMissed = false

	override func load(from config: IRCClientConfig)
	{
		leavesJoiningToZNC = config.zncIgnoreConfiguredAutojoin
		quietPlayback = config.zncIgnorePlaybackNotifications
		playsBackOnlyMissed = config.zncOnlyPlaybackLatest
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.zncIgnoreConfiguredAutojoin = leavesJoiningToZNC
		config.zncIgnorePlaybackNotifications = quietPlayback
		config.zncOnlyPlaybackLatest = playsBackOnlyMissed
	}
}

struct ZNCPage: View
{
	@ObservedObject var pane: ServerPropertiesZNCPane

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .znc)
			}

			Section {
				SettingToggle(title: ServerPropertiesText("spp-znc-join"), help: ServerPropertiesText("spp-znc-joinh"), isOn: $pane.leavesJoiningToZNC)

				SettingToggle(title: ServerPropertiesText("spp-znc-quiet"), help: ServerPropertiesText("spp-znc-quieth"), isOn: $pane.quietPlayback)

				SettingToggle(title: ServerPropertiesText("spp-znc-missed"), help: ServerPropertiesText("spp-znc-missedh"), isOn: $pane.playsBackOnlyMissed)
			} footer: {
				Text(ServerPropertiesText("spp-znc-note"))
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
	}
}
