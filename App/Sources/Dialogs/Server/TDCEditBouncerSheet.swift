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

/* The Edit Bouncer sheet: the account's name (its heading in the server list),
 address, port, TLS and login, where a change reaches every network (connected
 ones reconnect); its networks, with Add for those not in Textual; whether to
 tell about changes; Remove Bouncer…. The networks come from a connected
 network of the bouncer, otherwise from a short check (IRCBouncerProbe). */

// MARK: - Model

final class EditBouncerModel: NSObject, ObservableObject, IRCBouncerProbeDelegate
{
	let account: IRCBouncerAccount

	@Published var name: String
	@Published var address: String
	@Published var port: String
	@Published var prefersSecuredConnection: Bool
	@Published var username: String
	@Published var password = "" // empty: unchanged
	@Published var checksForChanges: Bool

	/* Log in with the password, or a client certificate (set up on Save) */
	@Published var logsInWithCertificate: Bool
	{
		didSet {
			/* A client certificate is only sent on a secured connection */
			if logsInWithCertificate {
				prefersSecuredConnection = true
			}
		}
	}

	@Published var certificateReference: Data?

	/* Registering the certificate on the bouncer before saving */
	@Published private(set) var settingUpCertificate = false

	private var setupProbe: IRCBouncerProbe?
	private var accountBeingSetUp: IRCBouncerAccountMutable?

	/* The bouncer's certificate when trusted in this sheet's checks: kept in the account */
	private var trustedCertificate: Data?

	@Published private(set) var networks: [IRCBouncerNetwork]?
	@Published private(set) var networksError: String?
	@Published private(set) var addedNetworks: Set<String> = []

	private var probe: IRCBouncerProbe?

	weak var window: NSWindow?

	var close: () -> Void = {}

	/* Opened to add networks (the notice of new ones): their list in view */
	var showsNetworksFirst = false

	private let existingClient: (IRCBouncerNetwork, IRCBouncerAccount) -> IRCClient?
	private let save: (IRCBouncerAccount) -> Void
	private let addNetwork: (IRCBouncerNetwork) -> Void
	private let remove: (Bool) -> Void

	init(account: IRCBouncerAccount,
		 networks knownNetworks: IRCBouncerNetworkList?,
		 existingClient: @escaping (IRCBouncerNetwork, IRCBouncerAccount) -> IRCClient?,
		 save: @escaping (IRCBouncerAccount) -> Void,
		 addNetwork: @escaping (IRCBouncerNetwork) -> Void,
		 remove: @escaping (Bool) -> Void)
	{
		self.account = account
		self.existingClient = existingClient
		self.save = save
		self.addNetwork = addNetwork
		self.remove = remove

		name = (account.name ?? "")
		address = account.serverAddress
		port = String(account.serverPort)
		prefersSecuredConnection = account.prefersSecuredConnection
		username = account.username
		checksForChanges = account.checksForNetworkChanges
		certificateReference = account.identityClientSideCertificate
		logsInWithCertificate = (account.identityClientSideCertificate != nil)

		super.init()

		if let knownNetworks = knownNetworks {
			networks = knownNetworks.networks
		} else {
			loadNetworks()
		}
	}

	var kindName: String
	{
		((account.kind == .ZNC) ? "ZNC" : "soju")
	}

	var portNumber: UInt16?
	{
		guard let number = UInt16(port.trimmingCharacters(in: .whitespaces)), number > 0 else {
			return nil
		}

		return number
	}

	var canSave: Bool
	{
		(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
		 portNumber != nil &&
		 username.trimmingCharacters(in: .whitespaces).isEmpty == false &&
		 (logsInWithCertificate == false || certificateReference != nil) &&
		 settingUpCertificate == false)
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

	/* The certificate logs in already: no password is kept */
	var logsInWithCertificateAlone: Bool
	{
		(account.identityClientSideCertificate != nil && account.password == nil)
	}

	/// A short check with the saved login, when no network of the bouncer is connected
	private func loadNetworks()
	{
		let newProbe = IRCBouncerProbe(account: account)

		newProbe.delegate = self

		probe = newProbe

		newProbe.start()
	}

	func bouncerProbeDidChange(_ changedProbe: IRCBouncerProbe)
	{
		if (changedProbe === setupProbe) {
			if changedProbe.wantsCertificateTrust, let window = window {
				changedProbe.trustCertificate(in: window)
			}

			if changedProbe.finished {
				certificateSetUpFinished(changedProbe)
			}

			return
		}

		guard changedProbe === probe else {
			return
		}

		if changedProbe.wantsCertificateTrust, let window = window {
			changedProbe.trustCertificate(in: window)
		}

		guard changedProbe.finished else {
			return
		}

		if (changedProbe.error == IRCBouncerProbeError.none) {
			trustedCertificate = changedProbe.trustedCertificate

			networks = (changedProbe.networkList?.networks ?? [])
		} else {
			networksError = (changedProbe.errorDetail ?? AddBouncerText("ab-e-clsd"))
		}

		probe = nil
	}

	func isInTextual(_ network: IRCBouncerNetwork) -> Bool
	{
		(addedNetworks.contains(network.networkIdentifier) || existingClient(network, account) != nil)
	}

	func add(_ network: IRCBouncerNetwork)
	{
		addNetwork(network)

		addedNetworks.insert(network.networkIdentifier)
	}

	func cancel()
	{
		probe?.delegate = nil
		probe?.cancel()

		setupProbe?.delegate = nil
		setupProbe?.cancel()

		close()
	}

	func saveChanges()
	{
		guard canSave, let updated = account.mutableCopy() as? IRCBouncerAccountMutable else {
			return
		}

		let trimmedName = name.trimmingCharacters(in: .whitespaces)

		updated.name = ((trimmedName.isEmpty) ? nil : trimmedName)
		updated.serverAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
		updated.serverPort = (portNumber ?? account.serverPort)
		updated.prefersSecuredConnection = prefersSecuredConnection
		updated.username = username.trimmingCharacters(in: .whitespaces)
		updated.checksForNetworkChanges = checksForChanges

		if (password.isEmpty == false) {
			updated.password = password
		}

		if logsInWithCertificate {
			/* A new certificate, or one not set up yet (the password still
			 logs in): registered on the bouncer first */
			let certificateChanged = (certificateReference != account.identityClientSideCertificate)

			if (certificateChanged || updated.password != nil) {
				updated.identityClientSideCertificate = certificateReference

				setUpCertificate(for: updated)

				return
			}
		} else if (account.identityClientSideCertificate != nil) {
			/* Back to the password, which must be there */
			guard (updated.password ?? "").isEmpty == false else {
				showAlert(AddBouncerText("eb-c-pass"))

				return
			}

			updated.identityClientSideCertificate = nil
		}

		finishSaving(updated)
	}

	private func finishSaving(_ updated: IRCBouncerAccountMutable)
	{
		if let trusted = trustedCertificate {
			updated.trustedServerCertificate = trusted
		}

		probe?.delegate = nil
		probe?.cancel()

		close()

		save(updated)
	}

	private func showAlert(_ text: String, then: (() -> Void)? = nil)
	{
		guard let window = window else {
			return
		}

		let alert = NSAlert()

		alert.messageText = text

		alert.beginSheetModal(for: window) { (_) in
			then?()
		}
	}

	/* The certificate is registered with the password, then tried alone */
	private func setUpCertificate(for updated: IRCBouncerAccountMutable)
	{
		guard (updated.password ?? "").isEmpty == false else {
			showAlert(AddBouncerText("eb-c-need"))

			return
		}

		let newProbe = IRCBouncerProbe(account: updated)

		newProbe.delegate = self

		setupProbe = newProbe
		accountBeingSetUp = updated

		settingUpCertificate = true

		newProbe.start()
	}

	/* What went wrong, as the Add Bouncer sheet says it */
	private func reason(of failedProbe: IRCBouncerProbe, for updated: IRCBouncerAccount) -> String
	{
		let address = updated.serverAddress
		let port = String(updated.serverPort)

		switch (failedProbe.error) {
			case .cannotConnect:
				return AddBouncerText("ab-e-conn", address, port)
			case .timedOut:
				return AddBouncerText("ab-e-time", address, port)
			case .certificateNotTrusted:
				return AddBouncerText("ab-e-cert", address)
			case .wrongLogin:
				return AddBouncerText("ab-e-login")
			case .notABouncer:
				return AddBouncerText("ab-e-nbnc", address)
			default:
				return AddBouncerText("ab-e-clsd")
		}
	}

	private func certificateSetUpFinished(_ finishedProbe: IRCBouncerProbe)
	{
		settingUpCertificate = false

		setupProbe = nil

		guard let updated = accountBeingSetUp else {
			return
		}

		accountBeingSetUp = nil

		if let trusted = finishedProbe.trustedCertificate {
			trustedCertificate = trusted
		}

		if (finishedProbe.error != IRCBouncerProbeError.none) {
			var text = AddBouncerText("eb-c-fail", account.displayName) + " " + reason(of: finishedProbe, for: updated)

			if let detail = finishedProbe.errorDetail, detail.isEmpty == false {
				text += "\n\n" + AddBouncerText(((finishedProbe.error == .cannotConnect) ? "ab-e-det" : "ab-e-said"), detail)
			}

			showAlert(text)

			return
		}

		switch (finishedProbe.certificateLogin) {
			case .works:
				updated.password = "" // removed from the Keychain: the certificate logs in

				finishSaving(updated)
			default:
				/* Not taken: the password stays, without the certificate */
				updated.identityClientSideCertificate = nil

				showAlert(AddBouncerText("ab-3-cno", account.serverAddress)) { [weak self] in
					self?.finishSaving(updated)
				}
		}
	}

	func confirmRemoval()
	{
		guard let window = window else {
			return
		}

		let alert = NSAlert()

		alert.messageText = AddBouncerText("eb-r-t", account.displayName)
		alert.informativeText = AddBouncerText("eb-r-b")

		alert.addButton(withTitle: AddBouncerText("eb-r-keep"))
		alert.addButton(withTitle: AddBouncerText("eb-r-all"))
		alert.addButton(withTitle: AddBouncerText("ab-b-cancel"))

		alert.beginSheetModal(for: window) { [weak self] (response) in
			guard let self = self else {
				return
			}

			switch (response) {
				case .alertFirstButtonReturn:
					self.close()
					self.remove(true)
				case .alertSecondButtonReturn:
					self.close()
					self.remove(false)
				default:
					break
			}
		}
	}
}

// MARK: - Sheet

@objc(TDCEditBouncerSheet)
final class EditBouncerSheet: NSObject
{
	/* Kept until the sheet closes */
	private static var openSheets: [EditBouncerSheet] = []

	@objc let window: NSWindow

	private let model: EditBouncerModel

	@objc(initWithAccount:networks:existingClient:save:addNetwork:remove:)
	init(account: IRCBouncerAccount,
		 networks: IRCBouncerNetworkList?,
		 existingClient: @escaping (IRCBouncerNetwork, IRCBouncerAccount) -> IRCClient?,
		 save: @escaping (IRCBouncerAccount) -> Void,
		 addNetwork: @escaping (IRCBouncerNetwork) -> Void,
		 remove: @escaping (Bool) -> Void)
	{
		model = EditBouncerModel(account: account, networks: networks, existingClient: existingClient, save: save, addNetwork: addNetwork, remove: remove)

		window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: EditBouncerView.width, height: EditBouncerView.height),
						  styleMask: [.titled],
						  backing: .buffered,
						  defer: true)

		window.isReleasedWhenClosed = false

		window.title = AddBouncerText("eb-title")

		window.contentViewController = NSHostingController(rootView: EditBouncerView(model: model))

		model.window = window

		super.init()

		model.close = { [weak self] in
			self?.end()
		}
	}

	@objc var showsNetworksFirst: Bool
	{
		get { model.showsNetworksFirst }
		set { model.showsNetworksFirst = newValue }
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

// MARK: - Page

struct EditBouncerView: View
{
	static let width: CGFloat = 540
	static let height: CGFloat = 600

	private static let networksSection = "networks"

	@ObservedObject var model: EditBouncerModel

	var body: some View
	{
		VStack(spacing: 0) {
			ScrollViewReader { scrollView in
				Form {
					Section {
						AddBouncerHeader(title: model.account.displayName,
										 subtitle: AddBouncerText("eb-sub", model.kindName, model.account.serverAddress, model.account.username))
					}

					Section {
						ServerPropertiesField(title: AddBouncerText("eb-name"), help: AddBouncerText("eb-nameh"), error: nil) {
							TextField(AddBouncerText("eb-name"), text: $model.name, prompt: Text(verbatim: model.account.serverAddress))
						}
					}

					Section {
						ServerPropertiesField(title: AddBouncerText("ab-addr"), error: nil) {
							TextField(AddBouncerText("ab-addr"), text: $model.address)
						}

						ServerPropertiesField(title: AddBouncerText("ab-port"), error: nil) {
							TextField(AddBouncerText("ab-port"), text: $model.port)
						}

						SettingToggle(title: AddBouncerText("ab-tls"), isOn: $model.prefersSecuredConnection)

						ServerPropertiesField(title: AddBouncerText("ab-user"), error: nil) {
							TextField(AddBouncerText("ab-user"), text: $model.username)
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
							SecureField(AddBouncerText("ab-pass"), text: $model.password, prompt: Text(AddBouncerText(passwordPrompt)))
						}
					} footer: {
						SettingFooter(text: AddBouncerText((model.logsInWithCertificate) ? "eb-1-nc" : "eb-1-n"))
					}

					Section(AddBouncerText("eb-net-h")) {
						networkRows
					}
					.id(Self.networksSection)

					Section {
						SettingToggle(title: AddBouncerText("ab-notify"), isOn: $model.checksForChanges)
					}
				}
				.formStyle(.grouped)
				.onAppear {
					guard model.showsNetworksFirst else {
						return
					}

					/* Once the form has its rows */
					DispatchQueue.main.async {
						scrollView.scrollTo(Self.networksSection, anchor: .top)
					}
				}
			}

			AddBouncerButtons {
				Button(AddBouncerText("eb-b-remove")) {
					model.confirmRemoval()
				}

				Spacer()

				Button(AddBouncerText("ab-b-cancel")) {
					model.cancel()
				}
				.keyboardShortcut(.cancelAction)

				if model.settingUpCertificate {
					ProgressView()
						.controlSize(.small)
						.accessibilityLabel(AddBouncerText("ab-c-certing"))
				}

				Button(AddBouncerText("eb-b-save")) {
					model.saveChanges()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(model.canSave == false)
			}
		}
		.frame(width: Self.width, height: Self.height)
	}

	/* Unchanged; with the certificate alone there's none to change: one
	 only to set a new certificate up, or to go back to the password */
	private var passwordPrompt: String
	{
		if model.logsInWithCertificateAlone {
			return ((model.logsInWithCertificate) ? "ab-pass-c" : "eb-pass-n")
		}

		return "eb-pass-p"
	}

	@ViewBuilder
	private var networkRows: some View
	{
		if let networks = model.networks {
			if networks.isEmpty {
				Text(AddBouncerText("eb-net-none"))
					.foregroundStyle(.secondary)
			}

			ForEach(networks, id: \.networkIdentifier) { (network) in
				LabeledContent {
					if model.isInTextual(network) {
						Text(AddBouncerText("eb-net-in"))
							.foregroundStyle(.secondary)
					} else {
						Button(AddBouncerText("eb-b-add")) {
							model.add(network)
						}
					}
				} label: {
					SettingLabel(title: network.name, help: state(of: network))
				}
			}
		} else if let error = model.networksError {
			Text(AddBouncerText("eb-net-fail", error))
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		} else {
			HStack(spacing: 8) {
				ProgressView()
					.controlSize(.small)

				Text(AddBouncerText("eb-net-load"))
					.foregroundStyle(.secondary)
			}
		}
	}

	private func state(of network: IRCBouncerNetwork) -> String
	{
		switch (network.state) {
			case "connected":
				return AddBouncerText("ab-3-st-c")
			case "connecting":
				return AddBouncerText("ab-3-st-cing")
			case "disconnected":
				return AddBouncerText("ab-3-st-d")
			default:
				return (network.state ?? "")
		}
	}
}
