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
import CryptoKit
import SecurityInterface
import SwiftUI

/* The You and Account pages: how others see you on this server, and
 logging in to your account there (password, login key, certificate) */

/// What's wrong with fields shows once Save found something; before, only for what was typed
final class ServerPropertiesFieldErrors: ObservableObject
{
	@Published var showsAll = false
	@Published private var edited: Set<String> = []

	func edit(_ field: String)
	{
		edited.insert(field)
	}

	func shown(_ error: String?, for field: String) -> String?
	{
		((showsAll || edited.contains(field)) ? error : nil)
	}
}

/// The first word of a field, as nicknames and usernames are read
fileprivate func firstWord(_ value: String) -> String
{
	String(value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first ?? "")
}

fileprivate func trimmed(_ value: String) -> String
{
	value.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// A row that shows or hides the section under it, for what few people need
struct ServerPropertiesMoreRow: View
{
	@Binding var isExpanded: Bool

	var body: some View
	{
		Button {
			withAnimation {
				isExpanded.toggle()
			}
		} label: {
			HStack {
				Text(ServerPropertiesText("spp-more"))

				Spacer()

				Image(systemName: "chevron.right")
					.font(.callout.weight(.semibold))
					.foregroundStyle(.secondary)
					.rotationEffect(.degrees(isExpanded ? 90 : 0))
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

// MARK: - You

@objc(TDCServerPropertiesYouPane)
final class ServerPropertiesYouPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var nickname = ""
	@Published var alternateNicknames = ""
	@Published var awayNickname = ""
	@Published var realName = ""
	@Published var username = ""

	let errors = ServerPropertiesFieldErrors()

	override func load(from config: IRCClientConfig)
	{
		nickname = ((config.nickname.isEmpty == false) ? config.nickname : TPCPreferences.defaultNickname())

		alternateNicknames = config.alternateNicknames.joined(separator: " ")

		awayNickname = (config.awayNickname ?? "")

		realName = ((config.realName.isEmpty == false) ? config.realName : TPCPreferences.defaultRealName())

		username = ((config.username.isEmpty == false) ? config.username : TPCPreferences.defaultUsername())
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.nickname = firstWord(nickname)
		config.username = firstWord(username)
		config.realName = trimmed(realName)

		config.awayNickname = firstWord(awayNickname)

		var nicknames: [String] = []

		for nickname in alternateNicknames.split(whereSeparator: { $0.isWhitespace }).map(String.init) where nicknames.contains(nickname) == false {
			nicknames.append(nickname)
		}

		config.alternateNicknames = nicknames
	}

	override var hasInvalidField: Bool
	{
		(nicknameError != nil || alternateNicknamesError != nil || awayNicknameError != nil || realNameError != nil || usernameError != nil)
	}

	override func showInvalidField()
	{
		errors.showsAll = true
	}

	func binding(_ keyPath: ReferenceWritableKeyPath<ServerPropertiesYouPane, String>, field: String) -> Binding<String>
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

	var nicknameError: String?
	{
		let value = firstWord(nickname)

		if (value.isEmpty) {
			return LocalizedKey("BasicLanguage[fo8-1h]")
		} else if ((value as NSString).isHostmaskNickname == false) {
			return LocalizedKey("CommonErrors[och-j5]")
		}

		return nil
	}

	var alternateNicknamesError: String?
	{
		for nickname in alternateNicknames.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
			if ((nickname as NSString).isHostmaskNickname == false) {
				return ServerPropertiesText("spp-you-e1", nickname)
			}
		}

		return nil
	}

	var awayNicknameError: String?
	{
		let value = firstWord(awayNickname)

		if (value.isEmpty == false && (value as NSString).isHostmaskNickname == false) {
			return LocalizedKey("CommonErrors[och-j5]")
		}

		return nil
	}

	var realNameError: String?
	{
		let value = trimmed(realName)

		if (value.isEmpty) {
			return LocalizedKey("BasicLanguage[fo8-1h]")
		} else if (value.rangeOfCharacter(from: .newlines) != nil) {
			return ServerPropertiesText("agy-bp")
		}

		return nil
	}

	var usernameError: String?
	{
		let value = firstWord(username)

		if (value.isEmpty) {
			return LocalizedKey("BasicLanguage[fo8-1h]")
		} else if ((value as NSString).isHostmaskUsername == false) {
			return ServerPropertiesText("8iw-q8")
		}

		return nil
	}
}

struct YouPage: View
{
	@ObservedObject var pane: ServerPropertiesYouPane
	@ObservedObject var errors: ServerPropertiesFieldErrors

	@State private var showsMore = false

	init(pane: ServerPropertiesYouPane)
	{
		self.pane = pane
		self.errors = pane.errors
	}

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .you)
			}

			Section {
				ServerPropertiesField(title: ServerPropertiesText("spp-you-nick"),
									  help: ServerPropertiesText("spp-you-nickh"),
									  error: errors.shown(pane.nicknameError, for: "nickname")) {
					TextField(ServerPropertiesText("spp-you-nick"), text: pane.binding(\.nickname, field: "nickname"))
				}

				ServerPropertiesField(title: ServerPropertiesText("spp-you-alt"),
									  help: ServerPropertiesText("spp-you-alth"),
									  error: errors.shown(pane.alternateNicknamesError, for: "alternates")) {
					TextField(ServerPropertiesText("spp-you-alt"), text: pane.binding(\.alternateNicknames, field: "alternates"), prompt: Text(ServerPropertiesText("spp-optional")))
				}

				ServerPropertiesField(title: ServerPropertiesText("spp-you-away"),
									  help: ServerPropertiesText("spp-you-awayh"),
									  error: errors.shown(pane.awayNicknameError, for: "away")) {
					TextField(ServerPropertiesText("spp-you-away"), text: pane.binding(\.awayNickname, field: "away"), prompt: Text(ServerPropertiesText("spp-optional")))
				}
			}

			Section {
				ServerPropertiesField(title: ServerPropertiesText("spp-you-real"),
									  help: ServerPropertiesText("spp-you-realh"),
									  error: errors.shown(pane.realNameError, for: "realName")) {
					TextField(ServerPropertiesText("spp-you-real"), text: pane.binding(\.realName, field: "realName"))
				}
			}

			Section {
				ServerPropertiesMoreRow(isExpanded: $showsMore)
			}

			if (showsMore) {
				Section {
					ServerPropertiesField(title: ServerPropertiesText("spp-you-user"),
										  help: ServerPropertiesText("spp-you-userh"),
										  error: errors.shown(pane.usernameError, for: "username")) {
						TextField(ServerPropertiesText("spp-you-user"), text: pane.binding(\.username, field: "username"))
					}
				}
			}
		}
		.formStyle(.grouped)
		.onAppear {
			/* What's wrong in it is out of sight otherwise */
			if (errors.showsAll && pane.usernameError != nil) {
				showsMore = true
			}
		}
	}
}

// MARK: - Client Certificate

/// A client certificate chosen from the Keychain (Server Properties, the
/// bouncer sheets): its Keychain reference, or nil when none was chosen.
/// Without any, an alert says so, with the help on making one.
func ChooseClientCertificate() -> Data?
{
	let query: [CFString: Any] = [
		kSecClass: kSecClassIdentity,
		kSecMatchLimit: kSecMatchLimitAll,
		kSecReturnRef: true
	]

	var result: CFTypeRef?

	SecItemCopyMatching(query as CFDictionary, &result)

	guard let identities = result as? [Any], identities.isEmpty == false else {
		TDCAlert.alert(withMessage: ServerPropertiesText("489-hG"),
					   title: ServerPropertiesText("pmk-os"),
					   defaultButton: LocalizedKey("Prompts[c7s-dq]"),
					   alternateButton: nil,
					   otherButton: ServerPropertiesText("3ju-lo")) { (response, _, _) in
			if (response == .other) {
				OpenLink.open(string: TXWebsiteClientCertificates, inBackground: false)
			}
		}

		return nil
	}

	let panel = SFChooseIdentityPanel.shared()!

	panel.setInformativeText(ServerPropertiesText("mi4-fd"))
	panel.setAlternateButtonTitle(LocalizedKey("Prompts[qso-2g]"))

	let response = panel.runModal(forIdentities: identities, message: ServerPropertiesText("6wq-i4"))

	guard response == NSApplication.ModalResponse.OK.rawValue,
		  let identity = panel.identity()?.takeUnretainedValue() else {
		return nil
	}

	return TLOKeychain.reference(forClientCertificateIdentity: identity)
}

// MARK: - Account

@objc(TDCServerPropertiesAccountPane)
final class ServerPropertiesAccountPane: TDCServerPropertiesPane, ObservableObject
{
	@Published var password = ""
	@Published var nickServHost = ""
	@Published private(set) var knownNickServHost: String?
	@Published var waitsForLogin = false
	@Published var warnsAboutChannels = true

	/* The configuration's values until saved: nil leaves the Keychain as it is, empty removes the key */
	@Published private(set) var loginKeyValue: String?
	@Published private(set) var certificateReference: Data?
	{
		didSet {
			certificate = Self.certificate(forReference: certificateReference)
		}
	}

	/* nil without one, or when it is no longer in the Keychain */
	@Published private(set) var certificate: Certificate?

	@objc weak var serverPane: TDCServerPropertiesSecuredConnection?

	private var choosingCertificate = false

	override func load(from config: IRCClientConfig)
	{
		password = (config.nicknamePassword ?? "")

		nickServHost = (config.nickServHost ?? "")

		knownNickServHost = IRCClient.knownNickServHost(forServerAddress: config.serverList.first?.serverAddress)

		waitsForLogin = config.autojoinWaitsForNickServ

		warnsAboutChannels = (config.hideAutojoinDelayedWarnings == false)

		loginKeyValue = config.saslECDSAKey

		certificateReference = config.identityClientSideCertificate
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.nicknamePassword = trimmed(password)

		let host = trimmed(nickServHost)

		config.nickServHost = ((host.isEmpty == false) ? host : nil)

		config.autojoinWaitsForNickServ = waitsForLogin

		config.hideAutojoinDelayedWarnings = (warnsAboutChannels == false)

		/* Written to (or removed from) the Keychain when the configuration is saved */
		config.saslECDSAKey = loginKeyValue

		config.identityClientSideCertificate = certificateReference
	}

	override func closeChildSheets()
	{
		if (choosingCertificate) {
			NSApp.stopModal(withCode: .cancel)
		}
	}

	private var window: NSWindow?
	{
		propertiesSheet?.sheet
	}

	/* Waiting for a login that can't happen */
	var hasNothingToLogInWith: Bool
	{
		(trimmed(password).isEmpty && loginKey == nil && certificateReference == nil)
	}

	// MARK: Login key

	var loginKey: IRCSASLECDSAKey?
	{
		guard let value = loginKeyValue, value.isEmpty == false else {
			return nil
		}

		return IRCSASLECDSAKey.key(storedValue: value)
	}

	private func setLoginKey(_ key: IRCSASLECDSAKey?)
	{
		loginKeyValue = (key?.storedValue ?? "")
	}

	/* The old key is gone once the sheet is saved: the network must be given the new one */
	private func confirmReplacingLoginKey(title: String, button: String, then replace: @escaping () -> Void)
	{
		guard loginKey != nil, let window = window else {
			replace()

			return
		}

		TDCAlert.alertSheet(with: window,
							body: ServerPropertiesText("ek1-r1"),
							title: title,
							defaultButton: button,
							alternateButton: LocalizedKey("Prompts[qso-2g]"),
							otherButton: nil) { (response, _, _) in
			if (response != .default) {
				return
			}

			/* After this alert has left the sheet */
			DispatchQueue.main.async(execute: replace)
		}
	}

	func generateLoginKey()
	{
		confirmReplacingLoginKey(title: ServerPropertiesText("ek1-r0"), button: ServerPropertiesText("ek1-r2")) {
			self.setLoginKey(IRCSASLECDSAKey.generatedKey())
		}
	}

	func importLoginKey()
	{
		confirmReplacingLoginKey(title: ServerPropertiesText("ek1-r0"), button: ServerPropertiesText("ek1-r2")) {
			guard let window = self.window else {
				return
			}

			let panel = NSOpenPanel()

			panel.canChooseDirectories = false
			panel.canChooseFiles = true
			panel.allowsMultipleSelection = false

			panel.message = ServerPropertiesText("ek1-i0")

			panel.beginSheetModal(for: window) { (response) in
				guard response == .OK, let url = panel.url else {
					return
				}

				if let pem = try? String(contentsOf: url, encoding: .utf8), let key = IRCSASLECDSAKey.key(pem: pem) {
					self.setLoginKey(key)

					return
				}

				DispatchQueue.main.async {
					TDCAlert.alertSheet(with: window,
										body: ServerPropertiesText("ek1-i2"),
										title: ServerPropertiesText("ek1-i1", url.lastPathComponent),
										defaultButton: LocalizedKey("Prompts[c7s-dq]"),
										alternateButton: nil,
										otherButton: nil)
				}
			}
		}
	}

	func removeLoginKey()
	{
		confirmReplacingLoginKey(title: ServerPropertiesText("ek1-x0"), button: ServerPropertiesText("ek1-x2")) {
			self.setLoginKey(nil)
		}
	}

	func copyToPasteboard(_ string: String)
	{
		let pasteboard = NSPasteboard.general

		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
	}

	// MARK: Certificate

	struct Certificate
	{
		let name: String
		let fingerprints: [(name: String, value: String)]
	}

	static func certificate(forReference reference: Data?) -> Certificate?
	{
		guard let reference = reference,
			  let identity = TLOKeychain.copyClientCertificateIdentity(forReference: reference) else {
			return nil
		}

		var certificateRef: SecCertificate?

		guard SecIdentityCopyCertificate(identity, &certificateRef) == errSecSuccess, let certificate = certificateRef else {
			return nil
		}

		var commonName: CFString?

		guard SecCertificateCopyCommonName(certificate, &commonName) == errSecSuccess, let name = commonName as String?, name.isEmpty == false else {
			return nil
		}

		let data = (SecCertificateCopyData(certificate) as Data)

		func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8
		{
			digest.map { String(format: "%02X", $0) }.joined()
		}

		return Certificate(name: name, fingerprints: [
			("SHA-512", hex(SHA512.hash(data: data))),
			("SHA-256", hex(SHA256.hash(data: data))),
			("SHA-1", hex(Insecure.SHA1.hash(data: data))),
			("MD5", hex(Insecure.MD5.hash(data: data)))
		])
	}

	var certificateMissing: Bool
	{
		(certificateReference != nil && certificate == nil)
	}

	func removeCertificate()
	{
		certificateReference = nil
	}

	func chooseCertificate()
	{
		choosingCertificate = true

		let chosenReference = ChooseClientCertificate()

		choosingCertificate = false

		guard let reference = chosenReference else {
			return
		}

		certificateReference = reference

		/* A client certificate is only sent on a secured connection */
		serverPane?.turnOnSecuredConnection()
	}
}

struct AccountPage: View
{
	@ObservedObject var pane: ServerPropertiesAccountPane

	@State private var showsMore = false

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .account)
			}

			Section {
				ServerPropertiesField(title: ServerPropertiesText("spp-acc-pass"),
									  help: ServerPropertiesText("spp-acc-passh"),
									  error: nil) {
					SecureField(ServerPropertiesText("spp-acc-pass"), text: $pane.password, prompt: Text(ServerPropertiesText("spp-optional")))
				}
			}

			Section {
				SettingToggle(title: ServerPropertiesText("spp-acc-wait"), help: ServerPropertiesText("spp-acc-waith"), isOn: $pane.waitsForLogin)

				if (pane.waitsForLogin) {
					SettingToggle(title: ServerPropertiesText("spp-acc-warn"), help: ServerPropertiesText("spp-acc-warnh"), isOn: $pane.warnsAboutChannels)
				}
			} footer: {
				if (pane.waitsForLogin && pane.hasNothingToLogInWith) {
					Label(ServerPropertiesText("spp-acc-nothing"), systemImage: "exclamationmark.triangle.fill")
						.foregroundStyle(.orange)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}

			Section {
				ServerPropertiesMoreRow(isExpanded: $showsMore)
			}

			if (showsMore) {
				Section {
					LoginKeyRows(pane: pane)
				}

				Section {
					CertificateRows(pane: pane)
				}

				Section {
					ServerPropertiesField(title: ServerPropertiesText("spp-acc-host"),
										  help: ServerPropertiesText("spp-acc-hosth"),
										  error: nil) {
						TextField(ServerPropertiesText("spp-acc-host"), text: $pane.nickServHost, prompt: Text(verbatim: (pane.knownNickServHost ?? "services.example.net")))
					}
				}
			}
		}
		.formStyle(.grouped)
		.onAppear {
			/* Something is set in there: show it */
			if (pane.loginKey != nil || pane.certificateReference != nil || pane.nickServHost.isEmpty == false) {
				showsMore = true
			}
		}
	}
}

struct LoginKeyRows: View
{
	@ObservedObject var pane: ServerPropertiesAccountPane

	var body: some View
	{
		let key = pane.loginKey

		LabeledContent {
			HStack(spacing: 8) {
				if let key = key {
					Text(key.publicKey)
						.font(.callout.monospaced())
						.lineLimit(1)
						.truncationMode(.middle)
						.textSelection(.enabled)
						.frame(maxWidth: 160, alignment: .trailing)
				} else {
					Text(ServerPropertiesText("ek1-n0"))
						.foregroundStyle(.secondary)
				}

				Menu {
					Button(ServerPropertiesText("spp-acc-key-new")) {
						pane.generateLoginKey()
					}

					Button(ServerPropertiesText("spp-acc-key-import")) {
						pane.importLoginKey()
					}

					Divider()

					Button(ServerPropertiesText("spp-acc-key-copy")) {
						pane.copyToPasteboard(key?.publicKey ?? "")
					}
					.disabled(key == nil)

					Button(ServerPropertiesText("spp-acc-key-cmd")) {
						pane.copyToPasteboard("/msg NickServ SET PUBKEY \(key?.publicKey ?? "")")
					}
					.disabled(key == nil)

					Divider()

					Button(ServerPropertiesText("spp-acc-key-remove")) {
						pane.removeLoginKey()
					}
					.disabled(key == nil)
				} label: {
					Text(ServerPropertiesText("spp-acc-key-menu"))
				}
				.fixedSize()
			}
		} label: {
			SettingLabel(title: ServerPropertiesText("spp-acc-key"), help: ServerPropertiesText("spp-acc-keyh"))
		}
	}
}

struct CertificateRows: View
{
	@ObservedObject var pane: ServerPropertiesAccountPane

	var body: some View
	{
		let certificate = pane.certificate

		LabeledContent {
			HStack(spacing: 8) {
				if let certificate = certificate {
					Text(certificate.name)
				} else {
					Text(ServerPropertiesText(pane.certificateMissing ? "c3r-m1" : "ek1-n0"))
						.foregroundStyle(pane.certificateMissing ? .orange : .secondary)
				}

				Button(ServerPropertiesText("spp-acc-cert-choose")) {
					pane.chooseCertificate()
				}

				if (pane.certificateReference != nil) {
					Button(ServerPropertiesText("spp-acc-cert-remove")) {
						pane.removeCertificate()
					}
				}
			}
		} label: {
			SettingLabel(title: ServerPropertiesText("spp-acc-cert"), help: ServerPropertiesText("spp-acc-certh"))
		}

		if let certificate = certificate {
			ForEach(certificate.fingerprints, id: \.name) { (fingerprint) in
				LabeledContent {
					HStack(spacing: 8) {
						Text(fingerprint.value)
							.font(.callout.monospaced())
							.lineLimit(1)
							.truncationMode(.middle)
							.textSelection(.enabled)
							.frame(maxWidth: 200, alignment: .trailing)

						Button(ServerPropertiesText("spp-acc-cert-copy")) {
							pane.copyToPasteboard("/msg NickServ cert add \(fingerprint.value)")
						}
						.help(ServerPropertiesText("spp-acc-cert-copyh"))
					}
				} label: {
					Text(fingerprint.name)
						.foregroundStyle(.secondary)
				}
			}
		}
	}
}
