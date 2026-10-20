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
import UniformTypeIdentifiers

/* The Server and Fallback Servers pages: the connection's name and icon,
 the servers (the first is the one on the Server page) and when to
 connect. Typing a known network's name or one of its servers fills in
 its port and security (a server is saved as typed, the same either way); typing something else gives back what was there
 before. A ws:// or wss:// address holds the port and security itself. */
@objc(TDCServerPropertiesServerPane)
final class ServerPropertiesServerPane: TDCServerPropertiesPane, ObservableObject, TDCServerPropertiesSecuredConnection, TDCServerEndpointListSheetDelegate
{
	@Published var name = ""
	@Published private(set) var address = "" // as typed: a network's name, a server or a WebSocket address
	@Published private(set) var port = ""
	@Published private(set) var secure = false
	@Published private(set) var password = ""
	@Published var autoConnect = false
	@Published var autoReconnect = false
	@Published var reconnectAfterWake = false
	@Published private(set) var customIcon: Data?
	@Published private(set) var serverList: [IRCServer] = []
	@Published private var forgottenHosts: [String] = [] // forgotten on Save

	/* Errors show once Save found one; before, only for what was typed */
	@Published var showsAllErrors = false
	@Published private var editedFields: Set<String> = []

	let networkList = IRCNetworkList()

	private var lastAddressValue: String?
	private var previousPrimaryServer: IRCServer?
	private var endpointSheet: TDCServerEndpointListSheet?

	// MARK: - Loading and saving

	override func load(from config: IRCClientConfig)
	{
		name = config.connectionName

		autoConnect = config.autoConnect
		autoReconnect = config.autoReconnect
		reconnectAfterWake = config.autoSleepModeDisconnect

		serverList = config.serverList

		loadPrimaryServer()

		customIcon = config.customIcon
	}

	override func save(toConfig config: IRCClientConfigMutable)
	{
		config.connectionName = name.trimmingCharacters(in: .whitespacesAndNewlines)

		config.autoConnect = autoConnect
		config.autoReconnect = autoReconnect
		config.autoSleepModeDisconnect = reconnectAfterWake

		config.serverList = serverList

		config.customIcon = customIcon

		let policies = IRCStrictTransportSecurity.sharedPolicies

		for host in forgottenHosts {
			policies.removePolicy(forHost: host)
		}
	}

	override var hasInvalidField: Bool
	{
		(nameError != nil || addressError != nil || portError != nil)
	}

	override func showInvalidField()
	{
		showsAllErrors = true
	}

	override func closeChildSheets()
	{
		endpointSheet?.close()
	}

	// MARK: - Fields

	var nameBinding: Binding<String>
	{
		Binding {
			self.name
		} set: { (value) in
			self.name = value
			self.editedFields.insert("name")
		}
	}

	var addressBinding: Binding<String>
	{
		Binding {
			self.address
		} set: { (value) in
			self.setAddress(value)
		}
	}

	var portBinding: Binding<String>
	{
		Binding {
			self.port
		} set: { (value) in
			self.port = value
			self.editedFields.insert("port")

			self.rebuildPrimaryServer()
		}
	}

	var secureBinding: Binding<Bool>
	{
		Binding {
			self.secure
		} set: { (value) in
			self.setSecure(value)
		}
	}

	var passwordBinding: Binding<String>
	{
		Binding {
			self.password
		} set: { (value) in
			self.password = value

			self.rebuildPrimaryServer()
		}
	}

	func chooseNetwork(_ network: IRCNetwork)
	{
		setAddress(network.networkName)
	}

	private func setAddress(_ value: String)
	{
		address = value

		editedFields.insert("address")

		fillInKnownNetwork()

		if let webSocket = webSocketAddress {
			port = String(webSocket.port)
			secure = webSocket.secure
		}

		rebuildPrimaryServer()
	}

	/* A secure connection is usually on 6697, a plain one on 6667 */
	private func setSecure(_ value: Bool)
	{
		secure = value

		let portValue = port.trimmingCharacters(in: .whitespacesAndNewlines)

		if (value && portValue == "6667") {
			port = "6697"
		} else if (value == false && portValue == "6697") {
			port = "6667"
		}

		rebuildPrimaryServer()
	}

	func turnOnSecuredConnection()
	{
		if (secure) {
			return
		}

		setSecure(true)
	}

	// MARK: - Address

	private var trimmedAddress: String
	{
		address.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/* A network from the list keeps its whole name; anything else is its first word */
	var addressValue: String
	{
		let trimmed = trimmedAddress

		if (networkList.networkNamed(trimmed) != nil) {
			return trimmed
		}

		return String(trimmed.split(whereSeparator: { $0.isWhitespace }).first ?? "")
	}

	var webSocketAddress: (host: String, port: UInt16, secure: Bool, path: String)?
	{
		var host: NSString?
		var path: NSString?
		var port: UInt16 = 0
		var secure: ObjCBool = false

		guard IRCServer.parseWebSocketAddress(addressValue, host: &host, port: &port, secure: &secure, path: &path),
			  let host = host, let path = path else {
			return nil
		}

		return (host as String, port, secure.boolValue, path as String)
	}

	var isWebSocket: Bool
	{
		(webSocketAddress != nil)
	}

	/* A known network's name or server fills in its port and security; leaving
	 it gives back the values from before it was chosen */
	private func fillInKnownNetwork()
	{
		let value = addressValue

		if (value == lastAddressValue) {
			return
		}

		lastAddressValue = value

		guard let network = (networkList.networkNamed(value) ?? networkList.network(withServerAddress: value)) else {
			restorePreviousPrimaryServer()

			return
		}

		rememberPrimaryServer()

		port = String(network.serverPort)

		secure = network.prefersSecuredConnection
	}

	private func rememberPrimaryServer()
	{
		/* Not between two known networks */
		if (previousPrimaryServer != nil) {
			return
		}

		if let server = serverList.first {
			previousPrimaryServer = server

			return
		}

		let server = IRCServerMutable()

		server.serverPort = UInt16(clamping: Int(port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)

		server.prefersSecuredConnection = secure

		previousPrimaryServer = server
	}

	private func restorePreviousPrimaryServer()
	{
		guard let server = previousPrimaryServer else {
			return
		}

		port = String(server.serverPort)

		secure = server.prefersSecuredConnection

		previousPrimaryServer = nil
	}

	// MARK: - Servers

	/* The fields show the first server; a new server connects securely */
	private func loadPrimaryServer()
	{
		guard let server = serverList.first else {
			address = ""
			port = String(IRCConnectionDefaultSecureServerPort)
			secure = true
			password = ""

			return
		}

		if let webSocketAddress = server.webSocketAddress {
			address = webSocketAddress
		} else if let network = networkList.network(withServerAddress: server.serverAddress) {
			address = network.networkName
		} else {
			address = server.serverAddress
		}

		port = String(server.serverPort)

		secure = server.prefersSecuredConnection

		password = (server.serverPassword ?? "")
	}

	/* The first server follows the fields (not while the list is edited in its sheet) */
	private func rebuildPrimaryServer()
	{
		if (endpointSheet != nil) {
			return
		}

		let server = ((serverList.first?.mutableCopy() as? IRCServerMutable) ?? IRCServerMutable())

		let value = addressValue

		if let webSocket = webSocketAddress {
			server.serverAddress = webSocket.host
			server.serverPort = webSocket.port

			server.prefersSecuredConnection = webSocket.secure

			server.webSocketPath = webSocket.path
		} else {
			if let network = networkList.networkNamed(value) {
				server.serverAddress = network.serverAddress
			} else {
				server.serverAddress = value.lowercased()
			}

			server.serverPort = UInt16(clamping: Int(port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)

			server.prefersSecuredConnection = secure

			server.webSocketPath = nil
		}

		server.serverPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

		var servers = serverList

		if (servers.isEmpty) {
			servers.append(server.copy() as! IRCServer)
		} else {
			servers[0] = (server.copy() as! IRCServer)
		}

		serverList = servers
	}

	func editServers()
	{
		guard let window = propertiesSheet?.sheet else {
			return
		}

		let sheet = TDCServerEndpointListSheet(window: window)

		sheet.delegate = self

		sheet.start(withServerList: serverList)

		endpointSheet = sheet
	}

	func serverEndpointListSheet(_ ender: TDCServerEndpointListSheet, onOk serverList: [IRCServer])
	{
		self.serverList = serverList

		loadPrimaryServer()
	}

	func serverEndpointListSheetWillClose(_ sender: TDCServerEndpointListSheet)
	{
		endpointSheet = nil
	}

	// MARK: - Errors

	private func shows(_ field: String) -> Bool
	{
		(showsAllErrors || editedFields.contains(field))
	}

	var nameError: String?
	{
		let value = name.trimmingCharacters(in: .whitespacesAndNewlines)

		if (value.isEmpty) {
			return LocalizedKey("BasicLanguage[fo8-1h]")
		} else if (value.rangeOfCharacter(from: .newlines) != nil) {
			return LocalizedKey("CommonErrors[gas-v8]")
		}

		return nil
	}

	var addressError: String?
	{
		let value = addressValue

		if (value.isEmpty) {
			return LocalizedKey("BasicLanguage[fo8-1h]")
		} else if (networkList.networkNamed(value) == nil && (value as NSString).isValidInternetAddress == false && isWebSocket == false) {
			return LocalizedKey("CommonErrors[yyx-l3]")
		}

		return nil
	}

	var portError: String?
	{
		if (isWebSocket) {
			return nil
		}

		if ((port.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).isValidInternetPort == false) {
			return LocalizedKey("CommonErrors[l0c-nb]")
		}

		return nil
	}

	var shownNameError: String?
	{
		shows("name") ? nameError : nil
	}

	var shownAddressError: String?
	{
		shows("address") ? addressError : nil
	}

	var shownPortError: String?
	{
		shows("port") ? portError : nil
	}

	// MARK: - Strict transport security

	private var serverHosts: [String]
	{
		var hosts: [String] = []

		for server in serverList {
			let host = server.serverAddress.lowercased()

			if (host.isEmpty == false && hosts.contains(host) == false) {
				hosts.append(host)
			}
		}

		return hosts
	}

	/* Whether a server told Textual to connect only securely, and until when */
	var strictTransportSecurityNotice: String?
	{
		let policies = IRCStrictTransportSecurity.sharedPolicies

		for host in serverHosts where forgottenHosts.contains(host) == false {
			guard let expiry = policies.expiry(forHost: host) else {
				continue
			}

			let expiryString = DateFormatter.localizedString(from: expiry, dateStyle: .medium, timeStyle: .none)

			return ServerPropertiesText("sts-l1", policies.port(forHost: host), expiryString)
		}

		return nil
	}

	/* What /sts clear does, on Save like every other change */
	func forgetStrictTransportSecurity()
	{
		for host in serverHosts where forgottenHosts.contains(host) == false {
			forgottenHosts.append(host)
		}
	}

	// MARK: - Icon

	/* What the server list will show: the chosen icon, else the network's own (draft/ICON) */
	var shownIcon: NSImage?
	{
		if let customIcon = customIcon {
			return NSImage(data: customIcon)
		}

		return propertiesSheet?.client?.networkProvidedIcon
	}

	var iconNote: String
	{
		if (customIcon != nil) {
			return ServerPropertiesText("icn-n1")
		} else if (propertiesSheet?.client?.networkProvidedIcon != nil) {
			return ServerPropertiesText("icn-n2")
		}

		return ServerPropertiesText("icn-n3")
	}

	func removeIcon()
	{
		customIcon = nil
	}

	func setIcon(imageData data: Data, fileName: String?)
	{
		if let iconData = IRCClient.customIconData(fromImageData: data) {
			customIcon = iconData

			return
		}

		guard let fileName = fileName, let window = propertiesSheet?.sheet else {
			NSSound.beep()

			return
		}

		TDCAlert.alertSheet(with: window,
							body: ServerPropertiesText("icn-e2"),
							title: ServerPropertiesText("icn-e1", fileName),
							defaultButton: LocalizedKey("Prompts[c7s-dq]"),
							alternateButton: nil,
							otherButton: nil)
	}

	func chooseIcon()
	{
		guard let window = propertiesSheet?.sheet else {
			return
		}

		let panel = NSOpenPanel()

		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false

		panel.allowedContentTypes = [.image]

		panel.message = ServerPropertiesText("icn-m1")

		panel.beginSheetModal(for: window) { (response) in
			guard response == .OK, let url = panel.url else {
				return
			}

			/* After the panel is gone, so an alert can take its place */
			DispatchQueue.main.async {
				let data = ((try? Data(contentsOf: url)) ?? Data())

				self.setIcon(imageData: data, fileName: url.lastPathComponent)
			}
		}
	}
}

// MARK: - Server page

struct ServerPage: View
{
	@ObservedObject var pane: ServerPropertiesServerPane

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .server)
			}

			Section {
				ServerPropertiesField(title: ServerPropertiesText("spp-srv-name"),
									  help: ServerPropertiesText("spp-srv-nameh"),
									  error: pane.shownNameError) {
					TextField(ServerPropertiesText("spp-srv-name"), text: pane.nameBinding)
				}

				LabeledContent {
					ServerIconRow(pane: pane)
				} label: {
					SettingLabel(title: ServerPropertiesText("icn-a1"), help: ServerPropertiesText("spp-srv-iconh"))
				}
			}

			Section {
				ServerPropertiesField(title: ServerPropertiesText("spp-srv-addr"),
									  help: ServerPropertiesText("spp-srv-addrh"),
									  error: pane.shownAddressError) {
					HStack(spacing: 6) {
						TextField(ServerPropertiesText("spp-srv-addr"), text: pane.addressBinding, prompt: Text(verbatim: "irc.example.com"))

						Menu {
							ForEach(pane.networkList.listOfNetworks, id: \.networkName) { (network) in
								Button(network.networkName) {
									pane.chooseNetwork(network)
								}
							}
						} label: {
							Text(ServerPropertiesText("spp-srv-networks"))
						}
						.menuStyle(.borderlessButton)
						.fixedSize()
					}
				}

				ServerPropertiesField(title: ServerPropertiesText("spp-srv-port"),
									  help: (pane.isWebSocket ? ServerPropertiesText("spp-srv-wsh") : nil),
									  error: pane.shownPortError) {
					TextField(ServerPropertiesText("spp-srv-port"), text: pane.portBinding)
						.frame(width: 80)
				}
				.disabled(pane.isWebSocket)

				SettingToggle(title: ServerPropertiesText("spp-srv-tls"), help: ServerPropertiesText("spp-srv-tlsh"), isOn: pane.secureBinding)
					.disabled(pane.isWebSocket)

				if let notice = pane.strictTransportSecurityNotice {
					LabeledContent {
						Button(ServerPropertiesText("sts-b1")) {
							pane.forgetStrictTransportSecurity()
						}
					} label: {
						SettingLabel(title: notice)
					}
				}

				ServerPropertiesField(title: ServerPropertiesText("spp-srv-pass"),
									  help: ServerPropertiesText("spp-srv-passh"),
									  error: nil) {
					SecureField(ServerPropertiesText("spp-srv-pass"), text: pane.passwordBinding, prompt: Text(ServerPropertiesText("spp-optional")))
				}
			}

			Section(ServerPropertiesText("spp-srv-h2")) {
				SettingToggle(title: ServerPropertiesText("spp-srv-c1"), isOn: $pane.autoConnect)

				SettingToggle(title: ServerPropertiesText("spp-srv-c2"), isOn: $pane.autoReconnect)

				SettingToggle(title: ServerPropertiesText("spp-srv-c3"), help: ServerPropertiesText("spp-srv-c3h"), isOn: $pane.reconnectAfterWake)
			}
		}
		.formStyle(.grouped)
	}
}

/// A field with its name and explanation on the left, and what's wrong with its value under it
struct ServerPropertiesField<Field: View>: View
{
	let title: String
	var help: String? = nil
	let error: String?
	@ViewBuilder let field: () -> Field

	var body: some View
	{
		LabeledContent {
			VStack(alignment: .trailing, spacing: 4) {
				field()
					.labelsHidden()

				if let error = error {
					Text(error)
						.font(.callout)
						.foregroundStyle(.red)
						.multilineTextAlignment(.trailing)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		} label: {
			SettingLabel(title: title, help: help)
		}
	}
}

struct ServerIconRow: View
{
	@ObservedObject var pane: ServerPropertiesServerPane

	var body: some View
	{
		HStack(spacing: 10) {
			VStack(alignment: .trailing, spacing: 4) {
				HStack(spacing: 8) {
					Button(ServerPropertiesText("icn-b1")) {
						pane.chooseIcon()
					}

					Button(ServerPropertiesText("icn-b2")) {
						pane.removeIcon()
					}
					.disabled(pane.customIcon == nil)
				}

				Text(pane.iconNote)
					.font(.callout)
					.foregroundStyle(.secondary)
			}

			ServerIconWell(pane: pane)
				.frame(width: 40, height: 40)
				.help(ServerPropertiesText("icn-t1"))
		}
	}
}

/// The icon, which takes a picture dropped or pasted on it, and Delete
struct ServerIconWell: NSViewRepresentable
{
	@ObservedObject var pane: ServerPropertiesServerPane

	func makeCoordinator() -> Coordinator
	{
		Coordinator(pane: pane)
	}

	func makeNSView(context: Context) -> NSImageView
	{
		let well = NSImageView()

		well.imageFrameStyle = .grayBezel
		well.imageScaling = .scaleProportionallyUpOrDown
		well.isEditable = true

		well.target = context.coordinator
		well.action = #selector(Coordinator.wellChanged(_:))

		well.setAccessibilityLabel(ServerPropertiesText("icn-a1"))

		return well
	}

	func updateNSView(_ well: NSImageView, context: Context)
	{
		well.image = pane.shownIcon
	}

	final class Coordinator: NSObject
	{
		let pane: ServerPropertiesServerPane

		init(pane: ServerPropertiesServerPane)
		{
			self.pane = pane
		}

		@objc func wellChanged(_ sender: NSImageView)
		{
			guard let data = sender.image?.tiffRepresentation else {
				pane.removeIcon()

				return
			}

			pane.setIcon(imageData: data, fileName: nil)
		}
	}
}

// MARK: - Fallback Servers page

struct FallbackServersPage: View
{
	@ObservedObject var pane: ServerPropertiesServerPane

	private func describe(_ server: IRCServer) -> String
	{
		if let webSocketAddress = server.webSocketAddress {
			return webSocketAddress
		}

		return "\(server.serverAddress):\(server.serverPort)"
	}

	var body: some View
	{
		Form {
			Section {
				ServerPropertiesPageHeader(page: .fallbackServers)
			}

			Section {
				ForEach(Array(pane.serverList.enumerated()), id: \.offset) { (index, server) in
					LabeledContent {
						if (server.prefersSecuredConnection) {
							Image(systemName: "lock.fill")
								.foregroundStyle(.secondary)
								.help(ServerPropertiesText("spp-fb-secure"))
						}
					} label: {
						SettingLabel(title: describe(server),
									 help: ((index == 0) ? ServerPropertiesText("spp-fb-first") : nil))
					}
				}

				if (pane.serverList.count < 2) {
					Text(ServerPropertiesText("spp-fb-none"))
						.foregroundStyle(.secondary)
				}
			} footer: {
				HStack {
					Text(ServerPropertiesText("spp-fb-note"))
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)

					Spacer()

					Button(ServerPropertiesText("spp-fb-edit")) {
						pane.editServers()
					}
				}
			}
		}
		.formStyle(.grouped)
	}
}
