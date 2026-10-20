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
 the servers (the first on the Server page, the others on Fallback
 Servers) and when to connect. Typing a known network's name or one of its servers fills in
 its port and security (a server is saved as typed, the same either way); typing something else gives back what was there
 before. A ws:// or wss:// address holds the port and security itself. */
@objc(TDCServerPropertiesServerPane)
final class ServerPropertiesServerPane: TDCServerPropertiesPane, ObservableObject, TDCServerPropertiesSecuredConnection
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
	@Published private(set) var primaryServer: IRCServer?
	@Published var fallbackServers: [ServerPropertiesFallbackServer] = []
	@Published private var forgottenHosts: [String] = [] // forgotten on Save

	/* Errors show once Save found one; before, only for what was typed */
	@Published var showsAllErrors = false
	@Published private var editedFields: Set<String> = []

	let fallbackErrors = ServerPropertiesFieldErrors()

	let networkList = IRCNetworkList()

	private var lastAddressValue: String?
	private var previousPrimaryServer: IRCServer?

	// MARK: - Loading and saving

	override func load(from config: IRCClientConfig)
	{
		name = config.connectionName

		autoConnect = config.autoConnect
		autoReconnect = config.autoReconnect
		reconnectAfterWake = config.autoSleepModeDisconnect

		primaryServer = config.serverList.first

		fallbackServers = config.serverList.dropFirst().map { ServerPropertiesFallbackServer(server: $0) }

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

		if let server = primaryServer {
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

	/* The servers to save: empty fallback servers are left out */
	var serverList: [IRCServer]
	{
		var servers: [IRCServer] = []

		if let primaryServer = primaryServer {
			servers.append(primaryServer)
		}

		servers.append(contentsOf: fallbackServers.compactMap(\.server))

		return servers
	}

	/* The fields show the first server; a new server connects securely */
	private func loadPrimaryServer()
	{
		guard let server = primaryServer else {
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

	/* The first server follows the fields */
	private func rebuildPrimaryServer()
	{
		let server = ((primaryServer?.mutableCopy() as? IRCServerMutable) ?? IRCServerMutable())

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

		primaryServer = (server.copy() as! IRCServer)
	}

	// MARK: - Fallback servers

	/* A new one connects securely, as a new server does */
	func addFallbackServer() -> UUID
	{
		var server = ServerPropertiesFallbackServer()

		server.port = String(IRCConnectionDefaultSecureServerPort)
		server.secure = true

		fallbackServers.append(server)

		return server.id
	}

	func removeFallbackServer(_ id: UUID)
	{
		fallbackServers.removeAll { $0.id == id }
	}

	func moveFallbackServer(withId serverId: String, to id: UUID)
	{
		guard let fromIndex = fallbackServers.firstIndex(where: { $0.id.uuidString == serverId }),
			  let toIndex = fallbackServers.firstIndex(where: { $0.id == id }),
			  fromIndex != toIndex else {
			return
		}

		fallbackServers.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: ((toIndex > fromIndex) ? (toIndex + 1) : toIndex))
	}

	func moveFallbackServer(_ id: UUID, by offset: Int)
	{
		guard let index = fallbackServers.firstIndex(where: { $0.id == id }) else {
			return
		}

		let newIndex = (index + offset)

		guard newIndex >= 0, newIndex < fallbackServers.count else {
			return
		}

		fallbackServers.swapAt(index, newIndex)
	}

	/* It goes to the Server page, and the server there takes its place */
	func makeMainServer(_ id: UUID)
	{
		guard let index = fallbackServers.firstIndex(where: { $0.id == id }),
			  let server = fallbackServers[index].server else {
			NSSound.beep()

			return
		}

		if let primaryServer = primaryServer {
			fallbackServers[index] = ServerPropertiesFallbackServer(server: primaryServer)
		} else {
			fallbackServers.remove(at: index)
		}

		primaryServer = server

		previousPrimaryServer = nil

		loadPrimaryServer()

		lastAddressValue = addressValue
	}

	/* A row being removed is still drawn once: it keeps its last values */
	func fallbackBinding<Value>(_ server: ServerPropertiesFallbackServer, _ keyPath: WritableKeyPath<ServerPropertiesFallbackServer, Value>, field: String) -> Binding<Value>
	{
		Binding {
			(self.fallbackServers.first(where: { $0.id == server.id }) ?? server)[keyPath: keyPath]
		} set: { (value) in
			guard let index = self.fallbackServers.firstIndex(where: { $0.id == server.id }) else {
				return
			}

			self.fallbackServers[index][keyPath: keyPath] = value

			self.fallbackErrors.edit("\(server.id)-\(field)")
		}
	}

	var hasInvalidFallbackServer: Bool
	{
		fallbackServers.contains { $0.addressError != nil || $0.portError != nil }
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

/// A fallback server as edited on its page: the address as typed (a
/// WebSocket address too), and the server it came from, for what isn't
/// edited here
struct ServerPropertiesFallbackServer: Identifiable
{
	let id = UUID()

	var address = ""
	var port = ""
	var secure = false
	var password = ""

	private var original: IRCServer?

	init()
	{
	}

	init(server: IRCServer)
	{
		address = (server.webSocketAddress ?? server.serverAddress)
		port = String(server.serverPort)
		secure = server.prefersSecuredConnection
		password = (server.serverPassword ?? "")

		original = server
	}

	/* A secure connection is usually on 6697, a plain one on 6667 */
	var secureSwitchingPort: Bool
	{
		get {
			secure
		}
		set {
			secure = newValue

			let portValue = port.trimmingCharacters(in: .whitespacesAndNewlines)

			if (newValue && portValue == "6667") {
				port = "6697"
			} else if (newValue == false && portValue == "6697") {
				port = "6667"
			}
		}
	}

	private var addressValue: String
	{
		String(address.split(whereSeparator: { $0.isWhitespace }).first ?? "")
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

	/* Without an address it isn't saved */
	var addressError: String?
	{
		let value = addressValue

		if (value.isEmpty || webSocketAddress != nil || (value as NSString).isValidInternetAddress) {
			return nil
		}

		return LocalizedKey("CommonErrors[yyx-l3]")
	}

	var portError: String?
	{
		if (addressValue.isEmpty || webSocketAddress != nil) {
			return nil
		}

		if ((port.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).isValidInternetPort == false) {
			return LocalizedKey("CommonErrors[l0c-nb]")
		}

		return nil
	}

	var server: IRCServer?
	{
		let value = addressValue

		if (value.isEmpty) {
			return nil
		}

		let server = ((original?.mutableCopy() as? IRCServerMutable) ?? IRCServerMutable())

		if let webSocket = webSocketAddress {
			server.serverAddress = webSocket.host
			server.serverPort = webSocket.port

			server.prefersSecuredConnection = webSocket.secure

			server.webSocketPath = webSocket.path
		} else {
			server.serverAddress = value.lowercased()
			server.serverPort = UInt16(clamping: Int(port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)

			server.prefersSecuredConnection = secure

			server.webSocketPath = nil
		}

		server.serverPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

		return (server.copy() as! IRCServer)
	}

	/* How the list shows it */
	var summary: String
	{
		let value = addressValue

		if (webSocketAddress != nil) {
			return value
		}

		if (value.isEmpty) {
			return ServerPropertiesText("spp-fb-new")
		}

		return (value.lowercased() + ":" + port.trimmingCharacters(in: .whitespacesAndNewlines))
	}

	var isSecure: Bool
	{
		(webSocketAddress?.secure ?? secure)
	}
}

/// The Fallback Servers page's place in the sheet: the list itself is
/// the Server pane's, which loads and saves it
@objc(TDCServerPropertiesFallbackServersPane)
final class ServerPropertiesFallbackServersPane: TDCServerPropertiesPane
{
	@objc weak var serverPane: ServerPropertiesServerPane?

	override var hasInvalidField: Bool
	{
		(serverPane?.hasInvalidFallbackServer ?? false)
	}

	override func showInvalidField()
	{
		serverPane?.fallbackErrors.showsAll = true
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
	@ObservedObject var errors: ServerPropertiesFieldErrors

	/* The one whose fields show under it */
	@State private var openServer: UUID?

	init(pane: ServerPropertiesServerPane)
	{
		self.pane = pane
		self.errors = pane.fallbackErrors
	}

	private var mainServerSummary: String
	{
		guard let server = pane.primaryServer, server.serverAddress.isEmpty == false else {
			return ServerPropertiesText("spp-fb-nomain")
		}

		return (server.webSocketAddress ?? "\(server.serverAddress):\(server.serverPort)")
	}

	var body: some View
	{
		let servers = pane.fallbackServers

		Form {
			Section {
				ServerPropertiesPageHeader(page: .fallbackServers)
			}

			Section {
				LabeledContent {
					if (pane.primaryServer?.prefersSecuredConnection ?? false) {
						FallbackServerLock()
					}
				} label: {
					SettingLabel(title: mainServerSummary, help: ServerPropertiesText("spp-fb-first"))
				}
			}

			Section {
				ForEach(servers) { (server) in
					FallbackServerRow(pane: pane, server: server, isOpen: openBinding(server.id))
						.draggable(server.id.uuidString) {
							Text(server.summary)
						}
						.dropDestination(for: String.self) { (serverIds, _) in
							guard let serverId = serverIds.first else {
								return false
							}

							pane.moveFallbackServer(withId: serverId, to: server.id)

							return true
						}
						.contextMenu {
							Button(ServerPropertiesText("spp-fb-main")) {
								pane.makeMainServer(server.id)
							}
							.disabled(server.server == nil)

							Divider()

							Button(ServerPropertiesText("spp-move-up")) {
								pane.moveFallbackServer(server.id, by: -1)
							}
							.disabled(server.id == servers.first?.id)

							Button(ServerPropertiesText("spp-move-down")) {
								pane.moveFallbackServer(server.id, by: 1)
							}
							.disabled(server.id == servers.last?.id)

							Divider()

							Button(ServerPropertiesText("spp-fb-remove")) {
								pane.removeFallbackServer(server.id)
							}
						}

					if (openServer == server.id) {
						FallbackServerFields(pane: pane, errors: errors, server: server)
					}
				}

				if (servers.isEmpty) {
					Text(ServerPropertiesText("spp-fb-none"))
						.foregroundStyle(.secondary)
				}

				Button {
					withAnimation {
						openServer = pane.addFallbackServer()
					}
				} label: {
					Label(ServerPropertiesText("spp-fb-add"), systemImage: "plus.circle.fill")
				}
				.buttonStyle(.borderless)
			} footer: {
				Text(ServerPropertiesText("spp-fb-note"))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.formStyle(.grouped)
		.onChange(of: errors.showsAll) { (_, showsAll) in
			/* Save found something: open the first server with a problem */
			if (showsAll), let server = pane.fallbackServers.first(where: { $0.addressError != nil || $0.portError != nil }) {
				openServer = server.id
			}
		}
		.onAppear {
			if (errors.showsAll), let server = pane.fallbackServers.first(where: { $0.addressError != nil || $0.portError != nil }) {
				openServer = server.id
			}
		}
	}

	private func openBinding(_ id: UUID) -> Binding<Bool>
	{
		Binding {
			openServer == id
		} set: { (isOpen) in
			withAnimation {
				openServer = (isOpen ? id : nil)
			}
		}
	}
}

struct FallbackServerLock: View
{
	var body: some View
	{
		Image(systemName: "lock.fill")
			.font(.callout)
			.foregroundStyle(.secondary)
			.help(ServerPropertiesText("spp-fb-secure"))
			.accessibilityLabel(ServerPropertiesText("spp-fb-secure"))
	}
}

/// A fallback server: a click shows its fields under it
struct FallbackServerRow: View
{
	@ObservedObject var pane: ServerPropertiesServerPane
	let server: ServerPropertiesFallbackServer
	@Binding var isOpen: Bool

	var body: some View
	{
		HStack(spacing: 8) {
			Button {
				isOpen.toggle()
			} label: {
				HStack(spacing: 8) {
					Image(systemName: "chevron.right")
						.font(.callout.weight(.semibold))
						.foregroundStyle(.secondary)
						.rotationEffect(.degrees(isOpen ? 90 : 0))

					Text(server.summary)
						.foregroundStyle((server.server == nil) ? .secondary : .primary)

					if (server.isSecure) {
						FallbackServerLock()
					}

					if (server.addressError != nil || server.portError != nil) {
						Image(systemName: "exclamationmark.triangle.fill")
							.font(.callout)
							.foregroundStyle(.red)
					}

					Spacer()
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.accessibilityHint(ServerPropertiesText("spp-fb-edit"))

			ServerPropertiesRowButton(symbol: "minus.circle.fill", help: ServerPropertiesText("spp-fb-remove")) {
				pane.removeFallbackServer(server.id)
			}
		}
	}
}

/// What a fallback server is set to, under its row
struct FallbackServerFields: View
{
	@ObservedObject var pane: ServerPropertiesServerPane
	@ObservedObject var errors: ServerPropertiesFieldErrors
	let server: ServerPropertiesFallbackServer

	private func shown(_ error: String?, _ field: String) -> String?
	{
		errors.shown(error, for: "\(server.id)-\(field)")
	}

	var body: some View
	{
		let isWebSocket = (server.webSocketAddress != nil)

		Group {
			ServerPropertiesField(title: ServerPropertiesText("spp-srv-addr"),
								  help: ServerPropertiesText("spp-fb-addrh"),
								  error: shown(server.addressError, "address")) {
				TextField(ServerPropertiesText("spp-srv-addr"), text: pane.fallbackBinding(server, \.address, field: "address"), prompt: Text(verbatim: "irc.example.com"))
			}

			ServerPropertiesField(title: ServerPropertiesText("spp-srv-port"),
								  help: (isWebSocket ? ServerPropertiesText("spp-srv-wsh") : nil),
								  error: shown(server.portError, "port")) {
				TextField(ServerPropertiesText("spp-srv-port"), text: pane.fallbackBinding(server, \.port, field: "port"))
					.frame(width: 80)
			}
			.disabled(isWebSocket)

			SettingToggle(title: ServerPropertiesText("spp-srv-tls"), isOn: pane.fallbackBinding(server, \.secureSwitchingPort, field: "secure"))
				.disabled(isWebSocket)

			ServerPropertiesField(title: ServerPropertiesText("spp-srv-pass"), error: nil) {
				SecureField(ServerPropertiesText("spp-srv-pass"), text: pane.fallbackBinding(server, \.password, field: "password"), prompt: Text(ServerPropertiesText("spp-optional")))
			}
		}
		.padding(.leading, 20)
	}
}
