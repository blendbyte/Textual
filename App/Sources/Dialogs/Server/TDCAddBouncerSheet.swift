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

/* The Add Bouncer sheet, in the look of Server Properties: where and who
 (address, port, TLS, the bouncer's own login), then a check shown line by
 line while a short connection (IRCBouncerProbe) logs in, recognises soju or
 ZNC and reads the networks, then the networks to add, all ticked. Nothing
 is saved before "Add". The menu controller opens it and does the adding. */

/// A string of the Add Bouncer sheet (TDCAddBouncerSheet.strings)
func AddBouncerText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCAddBouncerSheet[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Model

final class AddBouncerModel: NSObject, ObservableObject, IRCBouncerProbeDelegate
{
	enum Page
	{
		case login
		case check
		case networks
	}

	/// A network of the bouncer, ticked to be added (or linked, when added by hand before)
	struct NetworkRow: Identifiable
	{
		let network: IRCBouncerNetwork
		let existingClient: IRCClient?
		var isChosen: Bool

		var id: String { network.networkIdentifier }

		/// Linked to this bouncer already (not added by hand)
		var isLinked: Bool { existingClient?.config.bouncerAccountIdentifier != nil }
	}

	@Published var page = Page.login

	@Published var address = ""
	@Published var port = "6697"
	@Published var username = ""
	@Published var password = ""

	@Published var prefersSecuredConnection = true
	{
		didSet {
			/* The usual port for the other choice, unless one of its own was typed */
			if (prefersSecuredConnection && port == "6667") {
				port = "6697"
			} else if (prefersSecuredConnection == false && port == "6697") {
				port = "6667"
			}
		}
	}

	/* Log in with the password, or a client certificate from the Keychain
	 (set up on the bouncer with the password, once) */
	@Published var logsInWithCertificate = false
	{
		didSet {
			/* A client certificate is only sent on a secured connection */
			if logsInWithCertificate {
				prefersSecuredConnection = true
			}
		}
	}

	@Published var certificateReference: Data?

	@Published var rows: [NetworkRow] = []
	@Published var connectsNow = true
	@Published var checksForChanges = true

	@Published private(set) var probe: IRCBouncerProbe?

	weak var window: NSWindow?

	var close: () -> Void = {}

	/* Opened to link servers added by hand: they're ticked */
	var linksServersAddedByHand = false

	/* A bouncer host to sign up with, under the login */
	var hostingOfferURL: URL?

	private let existingClient: (IRCBouncerNetwork, IRCBouncerAccount) -> IRCClient?
	private let add: (IRCBouncerAccount, [IRCBouncerNetwork], [String: IRCClient], Bool) -> Void
	private let addAsServer: (String, UInt16, Bool) -> Void

	init(existingClient: @escaping (IRCBouncerNetwork, IRCBouncerAccount) -> IRCClient?,
		 add: @escaping (IRCBouncerAccount, [IRCBouncerNetwork], [String: IRCClient], Bool) -> Void,
		 addAsServer: @escaping (String, UInt16, Bool) -> Void)
	{
		self.existingClient = existingClient
		self.add = add
		self.addAsServer = addAsServer

		super.init()
	}

	var trimmedAddress: String
	{
		address.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	var portNumber: UInt16?
	{
		guard let number = UInt16(port.trimmingCharacters(in: .whitespaces)), number > 0 else {
			return nil
		}

		return number
	}

	var canConnect: Bool
	{
		(trimmedAddress.isEmpty == false && portNumber != nil && username.trimmingCharacters(in: .whitespaces).isEmpty == false &&
		 (logsInWithCertificate == false || certificateReference != nil))
	}

	var certificateName: String?
	{
		ServerPropertiesAccountPane.certificate(forReference: certificateReference)?.name
	}

	func chooseCertificate()
	{
		if let reference = ChooseClientCertificate() {
			certificateReference = reference
		}
	}

	var chosenCount: Int
	{
		rows.filter(\.isChosen).count
	}

	/// What was typed, and what the check found
	private func account() -> IRCBouncerAccountMutable
	{
		let account = IRCBouncerAccountMutable()

		account.serverAddress = trimmedAddress
		account.serverPort = (portNumber ?? 6697)
		account.prefersSecuredConnection = prefersSecuredConnection
		account.username = username.trimmingCharacters(in: .whitespaces)
		account.password = ((password.isEmpty) ? nil : password)
		account.identityClientSideCertificate = ((logsInWithCertificate) ? certificateReference : nil)
		account.kind = (probe?.kind ?? .unknown)
		account.checksForNetworkChanges = checksForChanges

		/* Trusted in the check: its networks don't ask again */
		account.trustedServerCertificate = probe?.trustedCertificate

		/* What the check found about the certificate */
		switch (probe?.certificateLogin ?? .none) {
			case .works:
				account.password = nil // not kept: the certificate logs in
			case .unsupported:
				account.identityClientSideCertificate = nil
			default:
				break
		}

		return account
	}

	func connect()
	{
		guard canConnect else {
			return
		}

		probe?.delegate = nil
		probe?.cancel()

		let newProbe = IRCBouncerProbe(account: account())

		newProbe.delegate = self

		probe = newProbe

		page = .check

		newProbe.start()
	}

	func bouncerProbeDidChange(_ changedProbe: IRCBouncerProbe)
	{
		guard changedProbe === probe else {
			return
		}

		objectWillChange.send()

		/* An untrusted certificate is shown at once: some bouncers hang up within seconds */
		if changedProbe.wantsCertificateTrust, let window = window {
			changedProbe.trustCertificate(in: window)
		}

		if (changedProbe.finished && changedProbe.error == IRCBouncerProbeError.none) {
			showNetworks()
		}
	}

	private func showNetworks()
	{
		let account = self.account()

		rows = (probe?.networkList?.networks ?? []).map { (network) in
			let client = existingClient(network, account)

			let addedByHand = (client != nil && client?.config.bouncerAccountIdentifier == nil)

			return NetworkRow(network: network, existingClient: client, isChosen: (client == nil || (addedByHand && linksServersAddedByHand)))
		}

		page = .networks
	}

	func back()
	{
		probe?.delegate = nil
		probe?.cancel()
		probe = nil

		page = .login
	}

	func cancel()
	{
		probe?.delegate = nil
		probe?.cancel()

		close()
	}

	func trustCertificate()
	{
		guard let window = window else {
			return
		}

		probe?.trustCertificate(in: window)
	}

	func addAsNormalServer()
	{
		cancel()

		addAsServer(trimmedAddress, (portNumber ?? 6667), prefersSecuredConnection)
	}

	func addNetworks()
	{
		let chosen = rows.filter(\.isChosen)

		guard chosen.isEmpty == false else {
			return
		}

		var linkedClients: [String: IRCClient] = [:]

		for row in chosen {
			if let client = row.existingClient {
				linkedClients[row.id] = client
			}
		}

		let account = self.account()

		close()

		add(account, chosen.map(\.network), linkedClients, connectsNow)
	}
}

// MARK: - Sheet

@objc(TDCAddBouncerSheet)
final class AddBouncerSheet: NSObject
{
	/* Kept until the sheet closes */
	private static var openSheets: [AddBouncerSheet] = []

	@objc let window: NSWindow

	private let model: AddBouncerModel

	@objc(initWithExistingClient:add:addAsServer:)
	init(existingClient: @escaping (IRCBouncerNetwork, IRCBouncerAccount) -> IRCClient?,
		 add: @escaping (IRCBouncerAccount, [IRCBouncerNetwork], [String: IRCClient], Bool) -> Void,
		 addAsServer: @escaping (String, UInt16, Bool) -> Void)
	{
		model = AddBouncerModel(existingClient: existingClient, add: add, addAsServer: addAsServer)

		window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: AddBouncerView.width, height: AddBouncerView.height),
						  styleMask: [.titled],
						  backing: .buffered,
						  defer: true)

		window.isReleasedWhenClosed = false

		window.title = AddBouncerText("ab-title")

		window.contentViewController = NSHostingController(rootView: AddBouncerView(model: model))

		model.window = window

		super.init()

		model.close = { [weak self] in
			self?.end()
		}
	}

	/* The first step filled in (servers added by hand, a setup link) */
	@objc(fillInAddress:port:secured:username:password:)
	func fillIn(address: String, port: UInt16, secured: Bool, username: String, password: String?)
	{
		model.address = address
		model.prefersSecuredConnection = secured // before the port: it changes a usual one
		model.port = String(port)
		model.username = username
		model.password = (password ?? "")
	}

	/* Offered for linking: servers added by hand are ticked in the last step */
	@objc var linksServersAddedByHand: Bool
	{
		get { model.linksServersAddedByHand }
		set { model.linksServersAddedByHand = newValue }
	}

	/* "No bouncer yet?" under the login (the direct build only) */
	@objc var hostingOfferURL: URL?
	{
		get { model.hostingOfferURL }
		set { model.hostingOfferURL = newValue }
	}

	@objc(beginInWindow:)
	func begin(in parentWindow: NSWindow)
	{
		Self.openSheets.append(self)

		parentWindow.beginSheet(window)
	}

	private func end()
	{
		window.sheetParent?.endSheet(window)

		window.orderOut(nil)

		Self.openSheets.removeAll { $0 === self }
	}
}

// MARK: - Pages

struct AddBouncerView: View
{
	static let width: CGFloat = 540
	static let height: CGFloat = 540

	@ObservedObject var model: AddBouncerModel

	var body: some View
	{
		VStack(spacing: 0) {
			switch (model.page) {
				case .login:
					AddBouncerLoginPage(model: model)
				case .check:
					AddBouncerCheckPage(model: model)
				case .networks:
					AddBouncerNetworksPage(model: model)
			}
		}
		.frame(width: Self.width, height: Self.height)
	}
}

/// The ⇄ icon, a title and a line under it, as a page's header
struct AddBouncerHeader: View
{
	let title: String
	let subtitle: String

	var body: some View
	{
		VStack(spacing: 6) {
			Image(systemName: "arrow.left.arrow.right")
				.font(.system(size: 22, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: 48, height: 48)
				.background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .systemBlue).gradient))
				.padding(.bottom, 4)
				.accessibilityHidden(true)

			Text(title)
				.font(.title.weight(.semibold))
				.multilineTextAlignment(.center)

			Text(subtitle)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 10)
	}
}

/// The buttons under a page
struct AddBouncerButtons<Content: View>: View
{
	@ViewBuilder let content: () -> Content

	var body: some View
	{
		VStack(spacing: 0) {
			Divider()

			HStack {
				content()
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 14)
		}
	}
}

struct AddBouncerLoginPage: View
{
	@ObservedObject var model: AddBouncerModel

	@FocusState private var addressFocused: Bool

	var body: some View
	{
		Form {
			Section {
				AddBouncerHeader(title: AddBouncerText("ab-1-t"), subtitle: AddBouncerText("ab-1-s"))
			}

			Section {
				ServerPropertiesField(title: AddBouncerText("ab-addr"), error: nil) {
					TextField(AddBouncerText("ab-addr"), text: $model.address, prompt: Text(verbatim: "bnc.example.com"))
						.focused($addressFocused)
				}

				ServerPropertiesField(title: AddBouncerText("ab-port"), error: nil) {
					TextField(AddBouncerText("ab-port"), text: $model.port, prompt: Text(verbatim: "6697"))
				}

				SettingToggle(title: AddBouncerText("ab-tls"), isOn: $model.prefersSecuredConnection)

				ServerPropertiesField(title: AddBouncerText("ab-user"), error: nil) {
					TextField(AddBouncerText("ab-user"), text: $model.username, prompt: Text(verbatim: "dan"))
				}

				Picker(AddBouncerText("ab-with"), selection: $model.logsInWithCertificate) {
					Text(AddBouncerText("ab-with-p")).tag(false)
					Text(AddBouncerText("ab-with-c")).tag(true)
				}

				if model.logsInWithCertificate {
					BouncerCertificateRow(name: model.certificateName, hasReference: (model.certificateReference != nil)) {
						model.chooseCertificate()
					}
				}

				ServerPropertiesField(title: AddBouncerText("ab-pass"), error: nil) {
					SecureField(AddBouncerText("ab-pass"), text: $model.password, prompt: ((model.logsInWithCertificate) ? Text(AddBouncerText("ab-pass-c")) : nil))
				}
			} footer: {
				SettingFooter(text: AddBouncerText((model.logsInWithCertificate) ? "ab-1-nc" : "ab-1-n"))
			}

			if let offerURL = model.hostingOfferURL,
			   let offer = try? AttributedString(markdown: AddBouncerText("ab-zh", offerURL.absoluteString)) {
				Section {
					Text(offer)
						.foregroundStyle(.secondary)
				}
			}
		}
		.formStyle(.grouped)
		.onAppear {
			addressFocused = true
		}

		AddBouncerButtons {
			Spacer()

			Button(AddBouncerText("ab-b-cancel")) {
				model.cancel()
			}
			.keyboardShortcut(.cancelAction)

			Button(AddBouncerText("ab-b-connect")) {
				model.connect()
			}
			.keyboardShortcut(.defaultAction)
			.disabled(model.canConnect == false)
		}
	}
}

/// "Certificate: name [Choose…]" for a bouncer's certificate login
struct BouncerCertificateRow: View
{
	let name: String?
	let hasReference: Bool // chosen, but maybe gone from the Keychain
	let choose: () -> Void

	var body: some View
	{
		LabeledContent {
			HStack(spacing: 8) {
				if let name = name {
					Text(name)
				} else {
					Text(AddBouncerText((hasReference) ? "ab-cert-gone" : "ab-cert-none"))
						.foregroundStyle(hasReference ? Color.orange : Color.secondary)
				}

				Button(AddBouncerText("ab-cert-choose"), action: choose)
			}
		} label: {
			Text(AddBouncerText("ab-cert"))
		}
	}
}

/// One line of the check: done, going on, or failed
struct AddBouncerCheckLine: View
{
	enum State
	{
		case done
		case working
		case failed
	}

	let state: State
	let text: String

	var body: some View
	{
		HStack(spacing: 8) {
			Group {
				switch (state) {
					case .done:
						Image(systemName: "checkmark.circle.fill")
							.foregroundStyle(.green)
					case .working:
						ProgressView()
							.controlSize(.small)
					case .failed:
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.red)
				}
			}
			.frame(width: 18)
			.accessibilityHidden(true)

			Text(text)

			Spacer()
		}
		.accessibilityElement(children: .combine)
	}
}

struct AddBouncerCheckPage: View
{
	@ObservedObject var model: AddBouncerModel

	var body: some View
	{
		let probe = model.probe
		let error = (probe?.error ?? IRCBouncerProbeError.none)
		let failed = (error != IRCBouncerProbeError.none)

		Form {
			Section {
				AddBouncerHeader(title: AddBouncerText("ab-2-t", model.trimmedAddress), subtitle: AddBouncerText("ab-2-s"))
			}

			Section {
				ForEach(Array(lines(probe, error: error).enumerated()), id: \.offset) { (_, line) in
					line
				}
			}

			if failed {
				Section {
					VStack(alignment: .leading, spacing: 6) {
						Text(errorText(error, loggedIn: (probe?.isLoggedIn ?? false)))
							.fixedSize(horizontal: false, vertical: true)

						if let detail = probe?.errorDetail, detail.isEmpty == false {
							Text(AddBouncerText(((error == .cannotConnect) ? "ab-e-det" : "ab-e-said"), detail))
								.font(.callout)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
		.formStyle(.grouped)

		AddBouncerButtons {
			Button(AddBouncerText("ab-b-back")) {
				model.back()
			}
			.keyboardShortcut(.cancelAction)

			Spacer()

			switch (error) {
				case .certificateNotTrusted:
					Button(AddBouncerText("ab-b-cert")) {
						model.trustCertificate()
					}
					.keyboardShortcut(.defaultAction)
				case .notABouncer:
					Button(AddBouncerText("ab-b-server")) {
						model.addAsNormalServer()
					}
					.keyboardShortcut(.defaultAction)
				default:
					Button(AddBouncerText("ab-b-retry")) {
						model.connect()
					}
					.keyboardShortcut(.defaultAction)
					.disabled(failed == false)
			}
		}
	}

	private func lines(_ probe: IRCBouncerProbe?, error: IRCBouncerProbeError) -> [AddBouncerCheckLine]
	{
		guard let probe = probe else {
			return []
		}

		var lines: [AddBouncerCheckLine] = []

		let username = model.username.trimmingCharacters(in: .whitespaces)

		/* Connected */
		if probe.isConnected {
			lines.append(AddBouncerCheckLine(state: .done, text: AddBouncerText((probe.isSecured) ? "ab-c-sec" : "ab-c-nsec")))
		} else if (error == .cannotConnect || error == .timedOut || error == .certificateNotTrusted || error == .closed) {
			lines.append(AddBouncerCheckLine(state: .failed, text: AddBouncerText("ab-c-nconn")))

			return lines
		} else {
			lines.append(AddBouncerCheckLine(state: .working, text: AddBouncerText("ab-c-cing", model.trimmedAddress)))

			return lines
		}

		/* Logged in */
		if probe.isLoggedIn {
			lines.append(AddBouncerCheckLine(state: .done, text: AddBouncerText("ab-c-lin", username)))
		} else if (error == .notABouncer) {
			lines.append(AddBouncerCheckLine(state: .failed, text: AddBouncerText("ab-c-nbnc")))

			return lines
		} else if (error != .none) {
			lines.append(AddBouncerCheckLine(state: .failed, text: AddBouncerText("ab-c-lno")))

			return lines
		} else {
			lines.append(AddBouncerCheckLine(state: .working, text: AddBouncerText("ab-c-ling", username)))

			return lines
		}

		/* Which bouncer */
		switch (probe.kind) {
			case .soju:
				if let version = probe.bouncerVersion, version.isEmpty == false, version.lowercased() != "soju" {
					lines.append(AddBouncerCheckLine(state: .done, text: AddBouncerText("ab-c-sojuv", version)))
				} else {
					lines.append(AddBouncerCheckLine(state: .done, text: AddBouncerText("ab-c-soju")))
				}
			case .ZNC:
				lines.append(AddBouncerCheckLine(state: .done, text: AddBouncerText("ab-c-znc")))
			default:
				break
		}

		/* The networks */
		let networksRead = ((probe.finished && error == .none) || probe.certificateLogin == .settingUp)

		if networksRead {
			lines.append(AddBouncerCheckLine(state: .done, text: AddBouncerText("ab-c-rin")))
		} else {
			lines.append(AddBouncerCheckLine(state: ((error == .none) ? .working : .failed), text: AddBouncerText("ab-c-ring")))
		}

		/* The certificate, registered and then tried alone */
		if (probe.certificateLogin == .settingUp) {
			lines.append(AddBouncerCheckLine(state: .working, text: AddBouncerText("ab-c-certing")))
		}

		return lines
	}

	private func errorText(_ error: IRCBouncerProbeError, loggedIn: Bool) -> String
	{
		let address = model.trimmedAddress
		let port = String(model.portNumber ?? 0)

		switch (error) {
			case .cannotConnect:
				return AddBouncerText("ab-e-conn", address, port)
			case .timedOut:
				if loggedIn {
					return AddBouncerText("ab-e-list", address)
				}

				return AddBouncerText("ab-e-time", address, port)
			case .certificateNotTrusted:
				return AddBouncerText("ab-e-cert", address)
			case .wrongLogin:
				/* The certificate alone, which the bouncer may not know yet */
				if (model.logsInWithCertificate && model.password.isEmpty) {
					return AddBouncerText("ab-e-certlogin")
				}

				return AddBouncerText("ab-e-login")
			case .notABouncer:
				return AddBouncerText("ab-e-nbnc", address)
			default:
				return AddBouncerText("ab-e-clsd")
		}
	}
}

struct AddBouncerNetworksPage: View
{
	@ObservedObject var model: AddBouncerModel

	/* What the check found about the certificate login */
	private var certificateNote: (text: String, symbol: String, works: Bool)?
	{
		guard model.logsInWithCertificate else {
			return nil
		}

		switch (model.probe?.certificateLogin ?? .none) {
			case .works:
				return (AddBouncerText("ab-3-cok"), "checkmark.seal", true)
			case .unsupported:
				return (AddBouncerText("ab-3-cno", model.trimmedAddress), "exclamationmark.triangle.fill", false)
			default:
				return nil
		}
	}

	var body: some View
	{
		Form {
			Section {
				AddBouncerHeader(title: title, subtitle: subtitle)
			}

			Section {
				if model.rows.isEmpty {
					Text(AddBouncerText("ab-3-none"))
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				ForEach($model.rows) { $row in
					AddBouncerNetworkRow(row: $row)
				}
			}

			Section {
				SettingToggle(title: AddBouncerText("ab-now"), isOn: $model.connectsNow)

				SettingToggle(title: AddBouncerText("ab-notify"), isOn: $model.checksForChanges)
			} footer: {
				SettingFooter(text: AddBouncerText("ab-3-n"))
			}

			if let note = certificateNote {
				Section {
					Label(note.text, systemImage: note.symbol)
						.foregroundStyle(note.works ? Color.primary : Color.orange)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
		.formStyle(.grouped)

		AddBouncerButtons {
			Button(AddBouncerText("ab-b-back")) {
				model.back()
			}
			.keyboardShortcut(.cancelAction)

			Spacer()

			if model.rows.isEmpty {
				Button(AddBouncerText("ab-b-refresh")) {
					model.connect()
				}
				.keyboardShortcut(.defaultAction)
			} else {
				Button(addTitle) {
					model.addNetworks()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(model.chosenCount == 0)
			}
		}
	}

	private var title: String
	{
		switch (model.rows.count) {
			case 0:
				return AddBouncerText("ab-3-t0")
			case 1:
				return AddBouncerText("ab-3-t1")
			default:
				return AddBouncerText("ab-3-tn", NumberFormatter.localizedString(from: NSNumber(value: model.rows.count), number: .decimal))
		}
	}

	private var subtitle: String
	{
		let kind = ((model.probe?.kind == .ZNC) ? "ZNC" : "soju")

		return AddBouncerText("ab-3-s", kind, model.trimmedAddress)
	}

	private var addTitle: String
	{
		let count = model.chosenCount

		switch (count) {
			case 0:
				return AddBouncerText("ab-b-add0")
			case 1:
				return AddBouncerText("ab-b-add1")
			default:
				return AddBouncerText("ab-b-addn", NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal))
		}
	}
}

/// A network with its tick, its host and nickname (or that it is in Textual already), and its state
struct AddBouncerNetworkRow: View
{
	@Binding var row: AddBouncerModel.NetworkRow

	var body: some View
	{
		let network = row.network

		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Toggle(network.name, isOn: $row.isChosen)
				.toggleStyle(.checkbox)
				.labelsHidden()
				.disabled(row.isLinked)

			VStack(alignment: .leading, spacing: 2) {
				Text(network.name)

				Text(detail)
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer()

			Text(state)
				.font(.callout)
				.foregroundStyle(.secondary)
		}
		.contentShape(Rectangle())
		.onTapGesture {
			if (row.isLinked == false) {
				row.isChosen.toggle()
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isButton)
	}

	private var detail: String
	{
		if row.isLinked {
			return AddBouncerText("ab-3-in")
		}

		if row.existingClient != nil {
			return AddBouncerText("ab-3-hand")
		}

		let attributes = row.network.attributes

		return [attributes["host"], attributes["nickname"]].compactMap { $0 }.filter { $0.isEmpty == false }.joined(separator: " · ")
	}

	private var state: String
	{
		switch (row.network.state) {
			case "connected":
				return AddBouncerText("ab-3-st-c")
			case "connecting":
				return AddBouncerText("ab-3-st-cing")
			case "disconnected":
				return AddBouncerText("ab-3-st-d")
			default:
				return (row.network.state ?? "")
		}
	}
}
