/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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
import Combine
import Network
import SwiftUI

/* Where to chat: for newcomers an interest and a language leading to a few
 suggestions, for everyone else the whole list; both can add a bouncer. Nothing
 is created here: the servers wait until the main window exists. */

// MARK: - Model

/// A network or address someone picked
struct SetupServer: Identifiable
{
	let id: String
	let name: String
	let host: String
	let port: UInt16
	let tls: Bool

	/* nil: typed or pasted */
	let network: AtlasNetwork?

	/* From a pasted irc:// link */
	var linkChannels: [String] = []

	/* Typed without a port: TLS first, then the usual plain port */
	var triesPlainPort = false

	init(network: AtlasNetwork)
	{
		id = network.id
		name = network.name
		host = network.host
		port = network.port
		tls = network.tls
		self.network = network
	}

	init(host: String, port: UInt16, tls: Bool, channels: [String] = [])
	{
		id = "address \(host.lowercased()):\(port)"
		name = host
		self.host = host
		self.port = port
		self.tls = tls
		self.network = nil
		linkChannels = channels
	}

	/* Known ahead of connecting; an address is tested instead */
	var warning: SetupServerWarning?
	{
		guard let network = network else {
			return (tls ? nil : .notEncrypted)
		}

		if (network.tls == false) {
			return .notEncrypted
		}

		return (network.connectsSecurely ? nil : .certificate)
	}
}

enum SetupServerWarning
{
	case notEncrypted
	case certificate
}

/// The login for an account someone already has
struct SetupAccount
{
	var enabled = false
	var name = ""
	var password = ""
}

/// A bouncer from Add Bouncer's sheet, added once there are clients to link
struct SetupPendingBouncer
{
	let account: IRCBouncerAccount
	let networks: [IRCBouncerNetwork]
	let connect: Bool
}

final class SetupServersModel: ObservableObject
{
	/* Every list comes from this, so a fresh feed updates them in place */
	var feed: AtlasFeed?
	{
		AtlasFeedStore.shared.feed
	}

	private var feedObserver: AnyCancellable?

	@Published var tag = ""
	@Published var showsAllTags = false
	@Published var language = "" // empty: any

	/* Filled in on the whole list */
	@Published var search = ""
	@Published var filterLanguage = ""
	@Published var filterTag = ""
	@Published var sortsByName = false

	/* Newcomers' channels come from their interest; the whole list has none */
	@Published var isNewcomer = true

	@Published private(set) var picked: [SetupServer] = []
	@Published var focusID: String?
	@Published private var channelChoices: [String: Bool] = [:]

	/* Asked before picking it */
	@Published var pendingWarning: SetupServer?

	@Published var nickname = ""
	@Published var realName = ""
	@Published var accounts: [String: SetupAccount] = [:]

	@Published private(set) var bouncers: [SetupPendingBouncer] = []

	/* Those whose connection check the user went on from */
	private var checkedIDs: Set<String> = []

	init()
	{
		let preferred = NSUserName()

		nickname = (preferred.isHostmaskNickname ? preferred : TPCPreferences.defaultNickname())

		feedObserver = AtlasFeedStore.shared.objectWillChange.sink { [weak self] in
			self?.objectWillChange.send()
		}

		language = (feed?.language(preferred: Locale.preferredLanguages) ?? "")

		tag = (feed?.tagChoices.first?.tag ?? "")
	}

	// MARK: Newcomers

	var tagChoices: [AtlasTag]
	{
		let choices = (feed?.tagChoices ?? [])

		guard showsAllTags == false else {
			return choices
		}

		var shown = Array(choices.prefix(Self.tagsShownAtFirst))

		/* The one chosen under More stays in view */
		if let chosen = choices.first(where: { $0.tag == tag }), shown.contains(where: { $0.tag == tag }) == false, shown.isEmpty == false {
			shown[shown.count - 1] = chosen
		}

		return shown
	}

	static let tagsShownAtFirst = 9

	var hasMoreTags: Bool
	{
		((feed?.tagChoices.count ?? 0) > Self.tagsShownAtFirst)
	}

	/// Every language some network speaks, those most networks speak first
	var languages: [String]
	{
		var counts: [String: Int] = [:]

		for network in (feed?.networks ?? []) {
			for code in network.languages {
				counts[Self.primaryLanguage(code), default: 0] += 1
			}
		}

		return counts.keys.sorted { (counts[$0] ?? 0, $1) > (counts[$1] ?? 0, $0) }
	}

	private static func primaryLanguage(_ code: String) -> String
	{
		String(code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "").lowercased()
	}

	var suggestions: AtlasSuggestions
	{
		(feed?.suggestions(tag: tag, language: (language.isEmpty ? nil : language))
			?? AtlasSuggestions(networks: [], matchesLanguage: true))
	}

	/// What's picked follows what's shown: nothing connects that the user can't see
	func enterSuggestions()
	{
		isNewcomer = true

		let shown = suggestions.networks

		picked = picked.filter { (server) in
			shown.contains { $0.id == server.id }
		}

		if (picked.isEmpty), let first = shown.first {
			picked = [SetupServer(network: first)]
		}

		if (shown.contains { $0.id == focusID } == false) {
			focusID = shown.first?.id
		}
	}

	func starters(on network: AtlasNetwork) -> [AtlasStarterChannel]
	{
		let current = suggestions

		/* Nothing in that language here anyway: don't hide all its channels too */
		let channelLanguage = ((current.matchesLanguage && language.isEmpty == false) ? language : nil)

		return (feed?.starterChannels(network: network, tag: tag, language: channelLanguage) ?? [])
	}

	private func choiceKey(_ network: AtlasNetwork, _ channel: AtlasChannel) -> String
	{
		"\(network.id) \(channel.name)"
	}

	func isTicked(_ starter: AtlasStarterChannel, on network: AtlasNetwork) -> Bool
	{
		(channelChoices[choiceKey(network, starter.channel)] ?? starter.ticked)
	}

	func setTicked(_ ticked: Bool, _ starter: AtlasStarterChannel, on network: AtlasNetwork)
	{
		channelChoices[choiceKey(network, starter.channel)] = ticked
	}

	// MARK: The whole list

	var filteredNetworks: [AtlasNetwork]
	{
		let query = search.trimmingCharacters(in: .whitespacesAndNewlines)

		let tagNames = Dictionary((feed?.tags ?? []).map { ($0.tag, $0.name) }, uniquingKeysWith: { first, _ in first })

		let matching = (feed?.networks ?? []).filter { (network) in
			if (filterLanguage.isEmpty == false && network.languages.contains(where: { Self.primaryLanguage($0) == filterLanguage }) == false) {
				return false
			}

			if (filterTag.isEmpty == false && network.tags.contains(filterTag) == false) {
				return false
			}

			if (query.isEmpty) {
				return true
			}

			let words = ([network.name, network.description, network.host] + network.tags.compactMap { tagNames[$0] })

			return words.contains { $0.localizedCaseInsensitiveContains(query) }
		}

		if (sortsByName) {
			return matching.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
		}

		return matching.sorted { ($0.users ?? -1) > ($1.users ?? -1) }
	}

	/// What's in the search field, when it reads as an address or a link and no network matches
	var typedServer: SetupServer?
	{
		let typed = search.trimmingCharacters(in: .whitespacesAndNewlines)

		guard typed.rangeOfCharacter(from: CharacterSet(charactersIn: ".:/")) != nil, filteredNetworks.isEmpty else {
			return nil
		}

		if let link = IRCProtocolLink(string: typed), (link.scheme == "irc" || link.scheme == "ircs"), link.host.isEmpty == false {
			return SetupServer(host: link.host, port: link.port, tls: link.secure, channels: link.channels)
		}

		let parts = typed.split(separator: ":", omittingEmptySubsequences: false)

		guard parts.count <= 2, let host = parts.first.map(String.init), host.contains("."), host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, host.contains("/") == false else {
			return nil
		}

		if (parts.count == 2) {
			guard let port = UInt16(parts[1]), port > 0 else {
				return nil
			}

			return SetupServer(host: host, port: port, tls: (port == 6697 || port == 7000 || port == 9999))
		}

		var server = SetupServer(host: host, port: 6697, tls: true)

		server.triesPlainPort = true

		return server
	}

	// MARK: Picking

	func isPicked(_ id: String) -> Bool
	{
		picked.contains { $0.id == id }
	}

	func toggle(_ server: SetupServer)
	{
		/* The tick is all the keyboard reaches of a row: the panel follows it */
		if (server.network != nil) {
			focusID = server.id
		}

		if (isPicked(server.id)) {
			picked.removeAll { $0.id == server.id }

			return
		}

		if (server.warning != nil) {
			pendingWarning = server

			return
		}

		picked.append(server)
	}

	func useAnyway(_ server: SetupServer)
	{
		pendingWarning = nil

		if (isPicked(server.id) == false) {
			picked.append(server)
		}
	}

	/// A typed address that only answered without TLS
	func replace(_ id: String, with server: SetupServer)
	{
		guard let index = picked.firstIndex(where: { $0.id == id }) else {
			return
		}

		picked[index] = server
	}

	func addBouncer(_ bouncer: SetupPendingBouncer)
	{
		/* The same bouncer and login again: the networks chosen now */
		bouncers.removeAll { (pending) in
			(pending.account.serverAddress.caseInsensitiveCompare(bouncer.account.serverAddress) == .orderedSame
				&& pending.account.serverPort == bouncer.account.serverPort
				&& pending.account.username.caseInsensitiveCompare(bouncer.account.username) == .orderedSame)
		}

		bouncers.append(bouncer)
	}

	func addTyped(_ server: SetupServer)
	{
		if (isPicked(server.id) == false) {
			picked.append(server)
		}

		search = ""
	}

	// MARK: Your name

	var nicknameIsValid: Bool
	{
		nickname.trimmingCharacters(in: .whitespacesAndNewlines).isHostmaskNickname
	}

	func channels(for server: SetupServer) -> [String]
	{
		guard let network = server.network else {
			return server.linkChannels
		}

		guard isNewcomer else {
			return Array(network.channels.prefix(1).map(\.name))
		}

		return starters(on: network).filter { isTicked($0, on: network) }.map(\.channel.name)
	}

	func account(_ id: String) -> Binding<SetupAccount>
	{
		Binding(get: { [weak self] in
			(self?.accounts[id] ?? SetupAccount())
		}, set: { [weak self] (value) in
			self?.accounts[id] = value
		})
	}

	// MARK: Making them

	func configuration(for server: SetupServer) -> IRCClientConfig
	{
		let serverMutable = IRCServerMutable()

		serverMutable.serverAddress = server.host
		serverMutable.serverPort = server.port
		serverMutable.prefersSecuredConnection = server.tls

		let config = IRCClientConfigMutable()

		config.connectionName = server.name
		config.serverList = [serverMutable.copy() as! IRCServer]
		config.autoConnect = true
		config.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

		let name = realName.trimmingCharacters(in: .whitespacesAndNewlines)

		if (name.isEmpty == false) {
			config.realName = name
		}

		if let account = accounts[server.id], account.enabled {
			let login = account.name.trimmingCharacters(in: .whitespacesAndNewlines)

			if (login.isEmpty == false) {
				config.username = login
			}

			if (account.password.isEmpty == false) {
				config.nicknamePassword = account.password
			}
		}

		config.channelList = channels(for: server).map { IRCChannelConfig.seed(withName: $0) }

		return (config.copy() as! IRCClientConfig)
	}

	func noteChecked()
	{
		checkedIDs = Set(picked.map(\.id))
	}

	/// Once the main window exists. Bouncers logged in when they were added.
	func createEverything(onlyChecked: Bool)
	{
		var selectsServer = true

		for server in picked where (onlyChecked == false || checkedIDs.contains(server.id)) {
			let config = configuration(for: server)

			/* No channel to go to: what's there to browse is the next best thing */
			TDCSettingsBridge.addServer(with: config, browsesChannels: config.channelList.isEmpty, selects: selectsServer)

			selectsServer = false
		}

		for bouncer in bouncers {
			TDCSettingsBridge.addBouncer(with: bouncer.account, networks: bouncer.networks, connect: bouncer.connect)
		}

		picked = []
		bouncers = []
	}
}

// MARK: - Connection check

/// One short connection per server, so that nobody lands on a dead address.
/// No IRC is spoken and nothing is sent.
final class SetupConnectionCheck: ObservableObject, Identifiable
{
	enum State
	{
		case checking
		case encrypted
		case notEncrypted
		case certificateProblem
		case noAnswer
	}

	struct Line: Identifiable
	{
		let id: String
		var server: SetupServer
		var state = State.checking
	}

	@Published private(set) var lines: [Line]

	private var connections: [NWConnection] = []
	private var attempts: [String: Int] = [:]

	private static let timeout: TimeInterval = 10

	init(servers: [SetupServer])
	{
		lines = servers.map { Line(id: $0.id, server: $0) }
	}

	var isFinished: Bool
	{
		lines.contains { $0.state == .checking } == false
	}

	var hasProblem: Bool
	{
		lines.contains { $0.state == .noAnswer || $0.state == .certificateProblem }
	}

	/// Those that answered only on the plain port. One that didn't answer at all
	/// stays as typed: encrypted is never given up without an answer.
	var replacements: [(id: String, server: SetupServer)]
	{
		lines.filter { $0.id != $0.server.id && $0.state == .notEncrypted }.map { ($0.id, $0.server) }
	}

	func start()
	{
		for line in lines {
			connect(lineID: line.id, to: line.server)
		}
	}

	func cancel()
	{
		connections.forEach { $0.cancel() }

		connections = []

		attempts = [:]
	}

	private func connect(lineID: String, to server: SetupServer)
	{
		guard let port = NWEndpoint.Port(rawValue: server.port) else {
			finish(lineID, .noAnswer)

			return
		}

		let attempt = ((attempts[lineID] ?? 0) + 1)

		attempts[lineID] = attempt

		let connection = NWConnection(host: NWEndpoint.Host(server.host),
									  port: port,
									  using: (server.tls ? NWParameters(tls: NWProtocolTLS.Options()) : .tcp))

		connections.append(connection)

		connection.stateUpdateHandler = { [weak self, weak connection] (state) in
			DispatchQueue.main.async {
				guard let self = self, self.attempts[lineID] == attempt else {
					return
				}

				switch state {
					case .ready:
						self.finish(lineID, (server.tls ? .encrypted : .notEncrypted))

						connection?.cancel()
					case .failed(let error), .waiting(let error):
						if case .tls = error {
							self.finish(lineID, .certificateProblem)
						} else {
							self.noAnswer(lineID, from: server)
						}

						connection?.cancel()
					default:
						break
				}
			}
		}

		connection.start(queue: .global(qos: .userInitiated))

		DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) { [weak self, weak connection] in
			guard let self = self, self.attempts[lineID] == attempt else {
				return
			}

			self.noAnswer(lineID, from: server)

			connection?.cancel()
		}
	}

	private func noAnswer(_ lineID: String, from server: SetupServer)
	{
		guard server.triesPlainPort, let index = lines.firstIndex(where: { $0.id == lineID }), lines[index].state == .checking else {
			finish(lineID, .noAnswer)

			return
		}

		let plain = SetupServer(host: server.host, port: 6667, tls: false)

		lines[index].server = plain

		connect(lineID: lineID, to: plain)
	}

	private func finish(_ id: String, _ state: State)
	{
		guard let index = lines.firstIndex(where: { $0.id == id }), lines[index].state == .checking else {
			return
		}

		lines[index].state = state

		attempts[id] = nil
	}
}

struct SetupConnectionCheckSheet: View
{
	@ObservedObject var check: SetupConnectionCheck

	let goBack: () -> Void
	let goOn: () -> Void

	var body: some View
	{
		VStack(alignment: .leading, spacing: 10) {
			Text(SetupText("sa-sc-title"))
				.font(.headline)

			Text(SetupText("sa-sc-lead"))
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			SetupGroup {
				ForEach(Array(check.lines.enumerated()), id: \.element.id) { (offset, line) in
					row(line, divider: (offset > 0))
				}
			}

			HStack {
				Spacer()

				Button(SetupText("sa-b-back")) {
					check.cancel()

					goBack()
				}

				Button(check.hasProblem ? SetupText("sa-sc-anyway") : SetupText("sa-b-continue")) {
					check.cancel()

					goOn()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(check.isFinished == false)
			}
			.controlSize(.large)
		}
		.padding(20)
		.frame(width: 420)
		.onAppear {
			check.start()
		}
	}

	private func row(_ line: SetupConnectionCheck.Line, divider: Bool) -> some View
	{
		VStack(spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			HStack(spacing: 10) {
				symbol(line.state)
					.frame(width: 18)

				VStack(alignment: .leading, spacing: 1) {
					Text(verbatim: line.server.name)

					Text(text(line.state))
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
		}
	}

	@ViewBuilder
	private func symbol(_ state: SetupConnectionCheck.State) -> some View
	{
		switch state {
			case .checking:
				ProgressView()
					.controlSize(.small)
			case .encrypted:
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.accessibilityHidden(true)
			default:
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
					.accessibilityHidden(true)
		}
	}

	private func text(_ state: SetupConnectionCheck.State) -> String
	{
		switch state {
			case .checking: return SetupText("sa-sc-checking")
			case .encrypted: return SetupText("sa-sc-ok")
			case .notEncrypted: return SetupText("sa-sc-plain")
			case .certificateProblem: return SetupText("sa-sc-cert")
			case .noAnswer: return SetupText("sa-sc-none")
		}
	}
}

// MARK: - Shared pieces

/// "Network data from IRC Atlas, CC BY 4.0", as the feed's licence asks
struct SetupAttribution: View
{
	@ObservedObject var model: SetupServersModel

	var body: some View
	{
		HStack(spacing: 0) {
			Text(verbatim: SetupText("sa-sa-from") + " ")

			Button(model.feed?.attribution ?? "IRC Atlas") {
				if let url = URL(string: "https://www.ircatlas.org") {
					NSWorkspace.shared.open(url)
				}
			}
			.buttonStyle(.link)

			Text(verbatim: ", CC BY 4.0")
		}
		.font(.caption)
		.foregroundStyle(.secondary)
		.padding(.top, 8)
	}
}

/// The links under each way of choosing
struct SetupServerLinks: View
{
	let setup: SetupModel
	let switchTitle: String?
	let switchAction: (() -> Void)?

	var body: some View
	{
		HStack(spacing: 18) {
			if let switchTitle = switchTitle, let switchAction = switchAction {
				Button(switchTitle, action: switchAction)
			}

			Button(SetupText("sa-sa-bouncer")) {
				setup.openBouncerSheet()
			}
		}
		.buttonStyle(.link)
		.padding(.top, 10)
	}
}

private func setupPeople(_ count: Int) -> String
{
	guard count >= 1000 else {
		return String(count)
	}

	let thousands = (Double(count) / 1000)

	return ((count >= 10000) ? "\(Int(thousands.rounded()))k" : String(format: "%.1fk", thousands))
}

func setupLanguageName(_ code: String) -> String
{
	(Locale.current.localizedString(forLanguageCode: code) ?? code)
}

/// About the network the pointer last chose
struct SetupNetworkPanel: View
{
	let network: AtlasNetwork?

	var body: some View
	{
		VStack(alignment: .leading, spacing: 7) {
			if let network = network {
				Text(verbatim: network.name)
					.fontWeight(.semibold)

				Text(verbatim: network.description)

				line(SetupText("sa-sp-size"), size(network))

				if (network.languages.isEmpty == false) {
					line(SetupText("sa-sp-lang"), network.languages.map(setupLanguageName).joined(separator: ", "))
				}

				line(SetupText("sa-sp-conn"), connection(network))
				line(SetupText("sa-sp-acct"), (network.sasl ? SetupText("sa-sp-acct-y") : SetupText("sa-sp-acct-n")))

				if let website = network.websiteURL {
					Button(SetupText("sa-sp-web")) {
						NSWorkspace.shared.open(website)
					}
					.buttonStyle(.link)
				}
			} else {
				Text(SetupText("sa-sp-none-t"))
					.fontWeight(.semibold)

				Text(SetupText("sa-sp-none-d"))
			}
		}
		.font(.callout)
		.fixedSize(horizontal: false, vertical: true)
		.padding(10)
		.frame(width: 230, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
	}

	private func line(_ title: String, _ value: String) -> some View
	{
		(Text(title).fontWeight(.semibold) + Text(verbatim: " " + value))
	}

	private func size(_ network: AtlasNetwork) -> String
	{
		guard let users = network.users else {
			return SetupText("sa-sp-size-u")
		}

		guard let channels = network.channelCount else {
			return SetupText("sa-sp-size-1", setupPeople(users))
		}

		return SetupText("sa-sp-size-2", setupPeople(users), setupPeople(channels))
	}

	private func connection(_ network: AtlasNetwork) -> String
	{
		if (network.tls == false) {
			return SetupText("sa-sp-conn-p")
		}

		return (network.connectsSecurely ? SetupText("sa-sp-conn-s") : SetupText("sa-sp-conn-c"))
	}
}

/// A square tick, as in a list of things to take along
struct SetupTick: View
{
	let ticked: Bool
	let label: String
	let action: () -> Void

	var body: some View
	{
		Toggle(isOn: Binding(get: { ticked }, set: { _ in action() })) {
			EmptyView()
		}
		.toggleStyle(.checkbox)
		.labelsHidden()
		.accessibilityLabel(label)
	}
}

/// "Use Anyway" for a network that isn't encrypted or whose certificate is wrong
private struct SetupWarningModifier: ViewModifier
{
	@ObservedObject var model: SetupServersModel

	func body(content: Content) -> some View
	{
		content.alert(title, isPresented: Binding(get: { model.pendingWarning != nil },
												  set: { if ($0 == false) { model.pendingWarning = nil } }),
					  presenting: model.pendingWarning) { (server) in
			Button(SetupText("sa-sw-no"), role: .cancel) {
				model.pendingWarning = nil
			}
			.keyboardShortcut(.defaultAction)

			Button(SetupText("sa-sw-yes")) {
				model.useAnyway(server)
			}
		} message: { (server) in
			Text((server.warning == .certificate) ? SetupText("sa-sw-cert-d") : SetupText("sa-sw-plain-d"))
		}
	}

	private var title: String
	{
		guard let server = model.pendingWarning else {
			return ""
		}

		return ((server.warning == .certificate) ? SetupText("sa-sw-cert-t", server.name) : SetupText("sa-sw-plain-t", server.name))
	}
}

// MARK: - Your interests

struct SetupInterestsStep: View
{
	let setup: SetupModel

	@ObservedObject var model: SetupServersModel

	private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-si-title"), lead: SetupText("sa-si-lead")) {
				SetupSymbol(symbol: "globe", color: .teal)
			}

			LazyVGrid(columns: columns, spacing: 8) {
				ForEach(model.tagChoices, id: \.tag) { (choice) in
					tile(choice)
				}
			}

			if (model.hasMoreTags) {
				Button(model.showsAllTags ? SetupText("sa-si-less") : SetupText("sa-si-more")) {
					model.showsAllTags.toggle()
				}
				.buttonStyle(.link)
				.padding(.top, 8)
			}

			SetupGroup {
				SetupControlRow(divider: false, title: SetupText("sa-si-lang-t"), text: SetupText("sa-si-lang-d")) {
					Picker(selection: $model.language) {
						Text(SetupText("sa-si-lang-any")).tag("")

						Divider()

						ForEach(model.languages, id: \.self) { (code) in
							Text(verbatim: setupLanguageName(code)).tag(code)
						}
					} label: {
						EmptyView()
					}
					.labelsHidden()
					.fixedSize()
				}
			}
			.padding(.top, 12)

			SetupServerLinks(setup: setup, switchTitle: SetupText("sa-sa-all")) {
				setup.showAllNetworks()
			}

			SetupAttribution(model: model)
		}
	}

	private func tile(_ choice: AtlasTag) -> some View
	{
		let chosen = (choice.tag == model.tag)

		return Button {
			model.tag = choice.tag
		} label: {
			VStack(spacing: 2) {
				Text(verbatim: choice.name)
					.fontWeight(.medium)
					.foregroundStyle(chosen ? Color.white : Color.primary)

				Text(SetupText((choice.networks.count == 1) ? "sa-si-count-1" : "sa-si-count", choice.networks.count))
					.font(.caption)
					.foregroundStyle(chosen ? Color.white.opacity(0.85) : Color.secondary)
			}
			.frame(maxWidth: .infinity, minHeight: 46)
			.contentShape(Rectangle())
			.background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(chosen ? Color.accentColor : Color.primary.opacity(0.06)))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(chosen ? .isSelected : [])
	}
}

// MARK: - Good places to start

struct SetupSuggestionsStep: View
{
	let setup: SetupModel

	@ObservedObject var model: SetupServersModel

	var body: some View
	{
		let current = model.suggestions

		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-sg-title"), lead: SetupText("sa-sg-lead")) {
				SetupSymbol(symbol: "globe", color: .teal)
			}

			if (current.matchesLanguage == false && current.networks.isEmpty == false) {
				Text(SetupText("sa-sg-other", tagName, setupLanguageName(model.language)))
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.bottom, 8)
			}

			HStack(alignment: .top, spacing: 12) {
				SetupGroup {
					if (current.networks.isEmpty) {
						SetupTextRow(divider: false, title: SetupText("sa-sg-none-t"), text: SetupText("sa-sg-none-d"))
					}

					ForEach(Array(current.networks.enumerated()), id: \.element.id) { (offset, network) in
						row(network, divider: (offset > 0))
					}
				}

				SetupNetworkPanel(network: current.networks.first { $0.id == model.focusID })
			}

			SetupServerLinks(setup: setup, switchTitle: SetupText("sa-sa-all")) {
				setup.showAllNetworks()
			}

			SetupAttribution(model: model)
		}
		.modifier(SetupWarningModifier(model: model))
	}

	private var tagName: String
	{
		(model.feed?.tags.first { $0.tag == model.tag }?.name ?? "")
	}

	private func row(_ network: AtlasNetwork, divider: Bool) -> some View
	{
		let picked = model.isPicked(network.id)

		return VStack(alignment: .leading, spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			HStack(alignment: .top, spacing: 8) {
				SetupTick(ticked: picked, label: network.name) {
					model.toggle(SetupServer(network: network))
				}

				VStack(alignment: .leading, spacing: 2) {
					Text(verbatim: network.name)
						.fontWeight(.medium)

					Text(verbatim: network.description)
						.font(.callout)
						.foregroundStyle(.secondary)
						.lineLimit(2)

					if (picked) {
						channels(on: network)
					}
				}

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.contentShape(Rectangle())
			.background((model.focusID == network.id) ? Color.primary.opacity(0.05) : Color.clear)
			.onTapGesture {
				model.focusID = network.id
			}
		}
	}

	private func channels(on network: AtlasNetwork) -> some View
	{
		let starters = model.starters(on: network)

		return VStack(alignment: .leading, spacing: 5) {
			if (starters.isEmpty) {
				Text(SetupText("sa-sg-nochan"))
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			ForEach(starters, id: \.channel.name) { (starter) in
				HStack(alignment: .top, spacing: 6) {
					SetupTick(ticked: model.isTicked(starter, on: network), label: starter.channel.name) {
						model.setTicked(model.isTicked(starter, on: network) == false, starter, on: network)
					}

					VStack(alignment: .leading, spacing: 1) {
						Text(verbatim: starter.channel.name)
							.font(.system(.callout, design: .monospaced))

						Text(verbatim: starter.channel.reason)
							.font(.caption)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
		.padding(.top, 4)
	}
}

// MARK: - All networks

struct SetupNetworksStep: View
{
	let setup: SetupModel

	@ObservedObject var model: SetupServersModel

	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText(setup.isAddingToImported ? "sa-sl-title-a" : "sa-sl-title"),
						lead: SetupText(setup.isAddingToImported ? ((setup.path == .again) ? "sa-sl-lead-r" : "sa-sl-lead-a") : "sa-sl-lead")) {
				SetupSymbol(symbol: "globe", color: .teal)
			}

			TextField(SetupText("sa-sl-search"), text: $model.search)
				.textFieldStyle(.roundedBorder)

			filters
				.padding(.vertical, 8)

			HStack(alignment: .top, spacing: 12) {
				list

				SetupNetworkPanel(network: model.feed?.networks.first { $0.id == model.focusID })
			}

			SetupServerLinks(setup: setup,
							 switchTitle: (setup.isAddingToImported ? nil : SetupText("sa-sa-help")),
							 switchAction: (setup.isAddingToImported ? nil : { setup.showInterests() }))

			SetupAttribution(model: model)
		}
		.modifier(SetupWarningModifier(model: model))
	}

	private var filters: some View
	{
		HStack(spacing: 8) {
			Picker(selection: $model.filterLanguage) {
				Text(SetupText("sa-si-lang-any")).tag("")

				Divider()

				ForEach(model.languages, id: \.self) { (code) in
					Text(verbatim: setupLanguageName(code)).tag(code)
				}
			} label: {
				EmptyView()
			}
			.labelsHidden()
			.fixedSize()

			Picker(selection: $model.filterTag) {
				Text(SetupText("sa-sl-anytag")).tag("")

				Divider()

				ForEach(model.feed?.tagChoices ?? [], id: \.tag) { (choice) in
					Text(verbatim: choice.name).tag(choice.tag)
				}
			} label: {
				EmptyView()
			}
			.labelsHidden()
			.fixedSize()

			Spacer()

			Picker(selection: $model.sortsByName) {
				Text(SetupText("sa-sl-largest")).tag(false)
				Text(SetupText("sa-sl-az")).tag(true)
			} label: {
				EmptyView()
			}
			.labelsHidden()
			.fixedSize()
		}
	}

	private var list: some View
	{
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 0) {
				if let typed = model.typedServer {
					typedRow(typed)
				}

				let networks = model.filteredNetworks

				if (networks.isEmpty && model.typedServer == nil) {
					Text(SetupText("sa-sl-nothing"))
						.font(.callout)
						.foregroundStyle(.secondary)
						.padding(10)
				}

				ForEach(pickedAddresses) { (server) in
					addressRow(server)
				}

				ForEach(networks, id: \.id) { (network) in
					row(network)

					Divider()
						.padding(.horizontal, 10)
				}
			}
		}
		.frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
		.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
		.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
	}

	private var pickedAddresses: [SetupServer]
	{
		model.picked.filter { $0.network == nil }
	}

	private func typedRow(_ server: SetupServer) -> some View
	{
		Button {
			model.addTyped(server)
		} label: {
			HStack(spacing: 8) {
				Image(systemName: "plus.circle.fill")
					.foregroundStyle(Color.accentColor)
					.accessibilityHidden(true)

				VStack(alignment: .leading, spacing: 1) {
					Text(SetupText("sa-sl-typed", server.host))

					Text(SetupText("sa-sl-typed-d"))
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private func addressRow(_ server: SetupServer) -> some View
	{
		HStack(spacing: 8) {
			SetupTick(ticked: true, label: server.name) {
				model.toggle(server)
			}

			Text(verbatim: "\(server.host):\(server.port)")

			Spacer(minLength: 0)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
	}

	private func row(_ network: AtlasNetwork) -> some View
	{
		HStack(spacing: 8) {
			SetupTick(ticked: model.isPicked(network.id), label: network.name) {
				model.toggle(SetupServer(network: network))
			}

			VStack(alignment: .leading, spacing: 1) {
				Text(verbatim: network.name)
					.fontWeight(.medium)

				Text(verbatim: network.description)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer(minLength: 4)

			if let users = network.users {
				Text(verbatim: setupPeople(users))
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			securityBadge(network)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 5)
		.contentShape(Rectangle())
		.background((model.focusID == network.id) ? Color.primary.opacity(0.05) : Color.clear)
		.onTapGesture {
			model.focusID = network.id
		}
	}

	@ViewBuilder
	private func securityBadge(_ network: AtlasNetwork) -> some View
	{
		if (network.connectsSecurely) {
			Image(systemName: "lock.fill")
				.font(.caption)
				.foregroundStyle(.secondary)
				.accessibilityLabel(SetupText("sa-sl-secure"))
		} else {
			Text((network.tls == false) ? SetupText("sa-sl-plain") : SetupText("sa-sl-cert"))
				.font(.caption)
				.foregroundStyle(.orange)
		}
	}
}

// MARK: - Your name

struct SetupYourNameStep: View
{
	@ObservedObject var model: SetupServersModel

	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-sy-title"), lead: SetupText("sa-sy-lead")) {
				SetupSymbol(symbol: "person.fill", color: .indigo)
			}

			HStack(alignment: .top, spacing: 12) {
				SetupGroup {
					SetupControlRow(divider: false, title: SetupText("sa-sy-nick-t"), text: SetupText("sa-sy-nick-d")) {
						TextField("", text: $model.nickname)
							.textFieldStyle(.roundedBorder)
							.frame(width: 130)
							.labelsHidden()
					}

					SetupControlRow(title: SetupText("sa-sy-real-t"), text: SetupText("sa-sy-real-d")) {
						TextField(SetupText("sa-sy-real-p"), text: $model.realName)
							.textFieldStyle(.roundedBorder)
							.frame(width: 130)
							.labelsHidden()
					}

					ForEach(model.picked.filter { $0.network?.sasl == true }) { (server) in
						accountRow(server)
					}
				}

				panel
			}
		}
	}

	private func accountRow(_ server: SetupServer) -> some View
	{
		let account = model.account(server.id)

		return VStack(spacing: 0) {
			SetupControlRow(title: SetupText("sa-sy-acct-t", server.name), text: SetupText("sa-sy-acct-d")) {
				Toggle("", isOn: account.enabled)
					.toggleStyle(.switch)
					.labelsHidden()
			}

			if (account.wrappedValue.enabled) {
				HStack(spacing: 8) {
					TextField(SetupText("sa-sy-acct-n"), text: account.name)
						.textFieldStyle(.roundedBorder)

					SecureField(SetupText("sa-sy-acct-p"), text: account.password)
						.textFieldStyle(.roundedBorder)
				}
				.padding(.horizontal, 10)
				.padding(.bottom, 8)
			}
		}
	}

	private var panel: some View
	{
		VStack(alignment: .leading, spacing: 7) {
			Text(SetupText("sa-sy-need-t"))
				.fontWeight(.semibold)

			Text(SetupText("sa-sy-need-d1"))
			Text(SetupText("sa-sy-need-d2"))

			if let first = model.picked.first(where: { $0.network?.registrationURL != nil }), let url = first.network?.registrationURL {
				Button(SetupText("sa-sy-create", first.name)) {
					NSWorkspace.shared.open(url)
				}
				.buttonStyle(.link)
			} else {
				Text(SetupText("sa-sy-later"))
			}

			Text(SetupText("sa-sy-start"))
				.fontWeight(.semibold)
				.padding(.top, 4)

			ForEach(model.picked) { (server) in
				let channels = model.channels(for: server)

				(Text(verbatim: server.name + ": ").fontWeight(.medium)
					+ Text(channels.isEmpty ? SetupText("sa-sy-browse") : channels.joined(separator: ", ")))
			}
		}
		.font(.callout)
		.fixedSize(horizontal: false, vertical: true)
		.padding(10)
		.frame(width: 230, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
	}
}

// MARK: - Your servers (after an import)

struct SetupImportedServersStep: View
{
	let setup: SetupModel

	@ObservedObject var model: SetupServersModel

	let imported: [String]

	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-sv-title"), lead: SetupText((setup.path == .again) ? "sa-sv-lead-r" : "sa-sv-lead")) {
				SetupSymbol(symbol: "server.rack", color: .teal)
			}

			SetupGroup {
				ForEach(Array(imported.enumerated()), id: \.offset) { (offset, line) in
					row(line, added: false, divider: (offset > 0))
				}

				ForEach(model.picked) { (server) in
					row(server.name, added: true, divider: true)
				}

				ForEach(Array(model.bouncers.enumerated()), id: \.offset) { (_, bouncer) in
					row(bouncer.account.serverAddress, added: true, divider: true)
				}
			}

			HStack(spacing: 18) {
				Button(SetupText("sa-sv-add")) {
					setup.addToImported()
				}

				Button(SetupText("sa-sa-bouncer")) {
					setup.openBouncerSheet()
				}
			}
			.buttonStyle(.link)
			.padding(.top, 10)
		}
	}

	private func row(_ line: String, added: Bool, divider: Bool) -> some View
	{
		VStack(spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			HStack(spacing: 8) {
				Image(systemName: added ? "plus.circle.fill" : "checkmark.circle.fill")
					.foregroundStyle(added ? Color.accentColor : Color.green)
					.accessibilityHidden(true)

				VStack(alignment: .leading, spacing: 1) {
					Text(verbatim: line)

					if (added) {
						Text(SetupText("sa-sv-now"))
							.font(.callout)
							.foregroundStyle(.secondary)
					}
				}

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
		}
	}
}
