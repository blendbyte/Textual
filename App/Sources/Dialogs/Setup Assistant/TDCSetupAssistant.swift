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
import QuartzCore
import Combine
import SwiftUI

/* The window that sets Textual up at first launch: one window before the main
 window, a step at a time, in the look of Settings. */

/// A string of the setup window (TDCSetupAssistant.strings)
func SetupText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCSetupAssistant[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Model

enum SetupStep
{
	case welcome
	case howIRCWorks
	case importing
	case style
	case look
	case chat
	case privacy
	case notifications
	case interests
	case suggestions
	case networks
	case yourName
	case importedServers
	case license
	case done
}

enum SetupPath
{
	case newInstall
	case upgrade // Textual 7 or an earlier version was found
	case importOnly // File > Import Settings from Textual 7…
	case serversOnly // no servers yet, from the main window
	case again // Help > Setup Assistant…: on today's settings, with the main window open
}

final class SetupModel: ObservableObject
{
	@Published private(set) var path: SetupPath
	@Published private(set) var step = SetupStep.welcome

	/* From Welcome: new to IRC gets the introduction */
	private var newToIRC = true

	let notifications = NotificationPermission()

	/* Made when the question of where to chat comes near; preferences are loaded by then */
	private(set) var serversModel: SetupServersModel?
	private var serversObserver: AnyCancellable?

	/* Newcomers get an interest and suggestions, others the whole list */
	@Published private var helpsChoose = true

	/* After an import: the whole list, going back to Your servers */
	@Published private(set) var isAddingToImported = false

	@Published var connectionCheck: SetupConnectionCheck?

	/* Closed before the end, only what passed the connection check is created */
	private(set) var reachedEnd = false

	private(set) var importedServers: [String] = []

	/* Nil where there is nothing to do: the App Store build, or already licensed */
	private(set) var licenseModel: LicenseWindowModel?
	private var licenseObserver: AnyCancellable?
	private var checkedTextual7License = false

	/* Made when its step first shows: preferences are loaded and imported by then */
	private(set) var lookModel: SetupLookModel?
	private(set) var choicesModel: SetupChoicesModel?

	let importModel: ImportModel?

	/* Before anything reads settings; an import replaces them first */
	var loadPreferences: (() -> Void)?

	weak var window: NSWindow?

	var finish: (() -> Void)?
	var finishWithoutImport: (() -> Void)?

	/* What the window shows now, for its transitions */
	var stepIdentity: String
	{
		"\(path) \(step)"
	}

	init(path: SetupPath, importModel: ImportModel? = nil)
	{
		self.path = path
		self.importModel = importModel

	}

	/// Where the steps that don't begin at Welcome begin, once there's a window
	func begin()
	{
		switch path {
			case .serversOnly:
				helpsChoose = TPCPreferencesUserDefaults.shared().bool(forKey: Self.newToIRCKey)

				prepareServers()

				serversModel?.isNewcomer = helpsChoose

				move(to: (helpsChoose ? .interests : .networks))
			case .again:
				helpsChoose = false

				move(to: .style)
			default:
				break
		}
	}

	private static let newToIRCKey = "Setup Assistant -> New to IRC"
	private static let archiveExplainedKey = "Setup Assistant -> Explained Message Archive"

	/* The privacy step explains the archive. Whoever skips it hears of it once. */
	static var shouldExplainArchive: Bool
	{
		(TPCPreferencesUserDefaults.shared().bool(forKey: archiveExplainedKey) == false && TPCPreferences.messageArchiveKeepPeriod != .off)
	}

	static func noteArchiveExplained()
	{
		TPCPreferencesUserDefaults.shared().set(true, forKey: archiveExplainedKey)
	}

	/* Settings start where they are, rather than on what a new install gets */
	var keepsCurrentSettings: Bool
	{
		(path == .upgrade || path == .again)
	}

	private func prepareServers()
	{
		guard serversModel == nil else {
			return
		}

		let model = SetupServersModel()

		serversModel = model

		/* Which steps are left depends on what's picked */
		serversObserver = model.objectWillChange.sink { [weak self] in
			self?.objectWillChange.send()
		}

		if (keepsCurrentSettings) {
			let saved = TDCSettingsBridge.savedServerSummaries()

			importedServers = saved.map { (server) in
				let name = ((server["name"] as? String) ?? "")
				let channels = ((server["channels"] as? Int) ?? 0)

				return ((channels == 1) ? SetupText("sa-sv-line-1", name) : SetupText("sa-sv-line", name, channels))
			}

			if let nickname = saved.first?["nickname"] as? String, nickname.isEmpty == false {
				model.nickname = nickname
			}

			model.isNewcomer = false
		}
	}

	private static let settingsSteps: [SetupStep] = [.style, .look, .chat, .privacy]

	private var choosingSteps: [SetupStep]
	{
		let hasPicked = (serversModel?.picked.isEmpty == false)

		return ((helpsChoose ? [.interests, .suggestions] : [.networks]) + (hasPicked ? [.yourName] : []))
	}

	private var licenseSteps: [SetupStep]
	{
		((licenseModel != nil) ? [.license] : [])
	}

	var steps: [SetupStep]
	{
		switch path {
			case .newInstall:
				return ((newToIRC ? [.welcome, .howIRCWorks] : [.welcome]) + Self.settingsSteps + [.notifications] + choosingSteps + licenseSteps + [.done])
			case .upgrade:
				return ([.welcome, .importing] + Self.settingsSteps + [.notifications, .importedServers] + (isAddingToImported ? [.networks] : []) + licenseSteps + [.done])
			case .again:
				let servers: [SetupStep] = (importedServers.isEmpty ? choosingSteps : ([.importedServers] + (isAddingToImported ? [.networks] : [])))

				return (Self.settingsSteps + [.notifications] + servers + [.done])
			case .serversOnly:
				return choosingSteps
			case .importOnly:
				return [.welcome, .importing]
		}
	}

	func start(newToIRC: Bool)
	{
		self.newToIRC = newToIRC

		helpsChoose = newToIRC

		/* For the empty state, if they skip choosing a network */
		TPCPreferencesUserDefaults.shared().set(newToIRC, forKey: Self.newToIRCKey)

		goForward()
	}

	/// Textual 7 was found, but the user begins with an empty Textual: not offered again (the menu item still works)
	func startFresh()
	{
		TPCLegacyImport.markOffered()

		loadPreferences?()

		path = .newInstall
	}

	func startImport()
	{
		importModel?.begin()

		step = .importing
	}

	func leaveImportAccess()
	{
		importModel?.stopUsingGroupFolder()

		step = .welcome
	}

	func goForward()
	{
		/* An address typed and not yet added is what Continue means */
		if (step == .networks), let servers = serversModel, let typed = servers.typedServer {
			servers.addTyped(typed)
		}

		/* Everything picked answers first, or says why not */
		if (step == .yourName || (step == .networks && isAddingToImported)), let servers = serversModel, servers.picked.isEmpty == false {
			connectionCheck = SetupConnectionCheck(servers: servers.picked)

			return
		}

		goForwardWithoutChecking()
	}

	func finishCheck(goingOn: Bool)
	{
		if (goingOn), let check = connectionCheck {
			for replacement in check.replacements {
				serversModel?.replace(replacement.id, with: replacement.server)
			}

			serversModel?.noteChecked()
		}

		connectionCheck = nil

		if (goingOn) {
			goForwardWithoutChecking()
		}
	}

	private func goForwardWithoutChecking()
	{
		if (step == .networks && isAddingToImported) {
			isAddingToImported = false

			move(to: .importedServers)

			return
		}

		guard let index = steps.firstIndex(of: step), index < (steps.count - 1) else {
			reachedEnd = true

			finish?()

			return
		}

		if (step == .importing) {
			loadPreferences?()
		}

		move(to: steps[index + 1])
	}

	private func move(to newStep: SetupStep)
	{
		if (Self.settingsSteps.contains(newStep) && lookModel == nil) {
			lookModel = SetupLookModel(upgrade: keepsCurrentSettings, window: window)
			choicesModel = SetupChoicesModel(upgrade: keepsCurrentSettings, again: (path == .again), window: window)
		}

		if (Self.settingsSteps.contains(step)) {
			applyLive()
		}

		if (newStep == .notifications || newStep == .interests || newStep == .networks) {
			prepareServers()

			prepareLicense()
		}

		if (newStep == .license) {
			enterLicense()
		}

		if (newStep == .privacy) {
			Self.noteArchiveExplained()
		}

		if (newStep == .interests || newStep == .networks) {
			AtlasFeedStore.shared.refreshIfDue()
		}

		if (newStep == .suggestions) {
			serversModel?.enterSuggestions()
		}

		step = newStep
	}

	/// With the main window open, what was written shows at once
	func applyLive()
	{
		guard path == .again else {
			return
		}

		lookModel?.applyLive()
		choicesModel?.applyLive()
	}

	// MARK: License

	private func prepareLicense()
	{
		guard licenseModel == nil, path == .newInstall || path == .upgrade, let model = TDCSettingsBridge.beginSetupLicense() as? LicenseWindowModel else {
			return
		}

		licenseModel = model

		licenseObserver = model.objectWillChange.sink { [weak self] in
			self?.objectWillChange.send()
		}

		importModel?.licenseImportFinished = { [weak self] (imported) in
			if (imported) {
				self?.checkTextual7License()
			}
		}
	}

	private func enterLicense()
	{
		importModel?.importLicenseIfRemembered()

		checkTextual7License()
	}

	private func checkTextual7License()
	{
		guard checkedTextual7License == false, TDCSettingsBridge.hasTextual7License() else {
			return
		}

		checkedTextual7License = true

		TDCSettingsBridge.checkTextual7UpgradeForSetup()
	}

	// MARK: Choosing where to chat

	func showAllNetworks()
	{
		helpsChoose = false

		serversModel?.isNewcomer = false

		move(to: .networks)
	}

	func showInterests()
	{
		helpsChoose = true

		serversModel?.isNewcomer = true

		move(to: .interests)
	}

	func addToImported()
	{
		isAddingToImported = true

		move(to: .networks)
	}

	func openBouncerSheet()
	{
		guard let window = window, let servers = serversModel else {
			return
		}

		/* Only a rerun has a world to look in. Linking is decided when it's all created, after setup */
		let hasWorld = (path == .again)

		let sheet = AddBouncerSheet(existingClient: { (network, account) in
			(hasWorld ? TDCSettingsBridge.existingServer(for: network, of: account) : nil)
		}, add: { [weak self] (account, networks, _, connect) in
			servers.addBouncer(SetupPendingBouncer(account: account, networks: networks, connect: connect))

			self?.bouncerAdded()
		}, addAsServer: { (address, port, secured) in
			servers.addTyped(SetupServer(host: address, port: port, tls: secured))
		})

		sheet.hostingOfferURL = TDCSettingsBridge.bouncerHostingOfferURL()

		sheet.begin(in: window)
	}

	private func bouncerAdded()
	{
		let hasPicked = (serversModel?.picked.isEmpty == false)

		if (step == .importedServers) {
			return
		}

		if (isAddingToImported) {
			/* Networks picked are still to be checked: that's the button on this step */
			if (hasPicked == false) {
				isAddingToImported = false

				move(to: .importedServers)
			}
		} else if (hasPicked) {
			move(to: .yourName)
		} else if (path == .serversOnly) {
			reachedEnd = true

			finish?()
		} else {
			move(to: licenseSteps.first ?? .done)
		}
	}

	var primaryTitle: String
	{
		switch step {
			case .networks where isAddingToImported:
				return SetupText("sa-b-doneadding")
			case .networks, .suggestions:
				return ((serversModel?.picked.isEmpty == false || serversModel?.typedServer != nil) ? SetupText("sa-b-continue") : SetupText("sa-b-skip"))
			default:
				return SetupText("sa-b-continue")
		}
	}

	var primaryIsEnabled: Bool
	{
		(step != .yourName || serversModel?.nicknameIsValid == true)
	}

	/// Who setup connects to, for Done
	var connectingTo: [String]
	{
		guard let servers = serversModel else {
			return []
		}

		return (servers.picked.map(\.name) + servers.bouncers.map(\.account.serverAddress))
	}

	/// Use Recommended or Keep Everything: past the settings' steps
	func skipSettings()
	{
		lookModel?.applyRecommended()
		choicesModel?.applyRecommended()

		move(to: .notifications)
	}

	var isSettingsStep: Bool
	{
		Self.settingsSteps.contains(step)
	}

	var canGoBack: Bool
	{
		/* An import can't be gone back into, nor can Your servers' list be left that way */
		((path != .upgrade || step != .style) && (step != .networks || isAddingToImported == false) && steps.first != step)
	}

	func goBack()
	{
		guard let index = steps.firstIndex(of: step), index > 0 else {
			return
		}

		move(to: steps[index - 1])
	}
}

// MARK: - Window

@objc(TDCSetupAssistant)
final class SetupAssistant: NSObject, NSWindowDelegate
{
	private static let completedKey = "Setup Assistant -> Completed Version"
	private static let currentVersion = 1

	/* Textual Dev only shows it when asked to, so that a test can start it without servers */
	private static let offerInDebugKey = "Setup Assistant -> Offer in Development Builds"

	private let model: SetupModel
	private let window: NSWindow

	/* Before settings load when Textual 7 is found, so that an import needs no restart */
	@objc(offerAtLaunchLoadingPreferences:then:)
	static func offerAtLaunch(loadingPreferences: @escaping () -> Void, then completion: @escaping () -> Void)
	{
		var preferencesLoaded = false

		let loadPreferencesOnce = {
			if (preferencesLoaded == false) {
				preferencesLoaded = true

				loadingPreferences()
			}
		}

		let importModel = (TPCLegacyImport.shouldOfferAtLaunch ? ImportModel(fromMenu: false) : nil)

		if (importModel == nil) {
			loadPreferencesOnce()

			guard shouldOfferAtLaunch else {
				completion()

				return
			}
		}

		/* Not before the app has finished launching: a modal session started
		 earlier finishes launching early, and the main window ordered in after
		 it never appears on screen. Started from the run loop, not the main
		 queue, which the import needs while the window is open. */
		RunLoop.main.perform(inModes: [.default]) {
			let assistant = SetupAssistant(path: ((importModel != nil) ? .upgrade : .newInstall), importModel: importModel)

			assistant.model.loadPreferences = loadPreferencesOnce

			assistant.runModal()

			loadPreferencesOnce()

			completion()

			assistant.createChosenServers()

			TDCSettingsBridge.endSetupLicense()
		}
	}

	/// No servers yet: the same choosing, from the main window
	@objc static func addServersFromEmptyState()
	{
		openBesideMainWindow(path: .serversOnly)
	}

	/// Help > Setup Assistant…
	@objc static func runAgain()
	{
		openBesideMainWindow(path: .again)
	}

	/* Not modal: IRC carries on behind it, on timers a modal window would hold up */
	private static var openBeside: SetupAssistant?

	private var isModal = false

	private static func openBesideMainWindow(path: SetupPath)
	{
		if let assistant = openBeside {
			assistant.window.makeKeyAndOrderFront(nil)

			return
		}

		let assistant = SetupAssistant(path: path, importModel: nil)

		openBeside = assistant

		assistant.model.begin()

		assistant.window.center()
		assistant.window.makeKeyAndOrderFront(nil)
	}

	private func createChosenServers()
	{
		/* Welcome again is "not now": setup comes back at the next launch */
		if (model.step != .welcome) {
			model.serversModel?.createEverything(onlyChecked: (model.reachedEnd == false))
		}
	}

	/// File > Import Settings from Textual 7…; restarts Textual when done
	@objc static func importFromMenu()
	{
		guard let importModel = ImportModel(fromMenu: true) else {
			TDCAlert.modalAlert(withMessage: ImportText("1nk-dm"), title: ImportText("2e4-mp"), defaultButton: ImportText("oxy-im"), alternateButton: nil)

			return
		}

		let assistant = SetupAssistant(path: .importOnly, importModel: importModel)

		assistant.runModal()
	}

	/// File > Remove Textual 7 Data…
	@objc static func removeEarlierDataFromMenu()
	{
		ImportRemoval.run()
	}

	private static var shouldOfferAtLaunch: Bool
	{
		let defaults = TPCPreferencesUserDefaults.shared()

		if (defaults.integer(forKey: completedKey) >= currentVersion) {
			return false
		}

#if DEBUG
		if (defaults.bool(forKey: offerInDebugKey) == false) {
			return false
		}
#endif

		/* Already in use: it doesn't come back if the servers are removed later */
		if (TPCLegacyImport.hasServers) {
			markCompleted()

			return false
		}

		return true
	}

	private static func markCompleted()
	{
		TPCPreferencesUserDefaults.shared().set(currentVersion, forKey: completedKey)
	}

	private init(path: SetupPath, importModel: ImportModel?)
	{
		model = SetupModel(path: path, importModel: importModel)

		window = NSWindow(contentRect: NSRect(origin: .zero, size: SetupRootView.size),
						  styleMask: [.titled, .closable, .fullSizeContentView],
						  backing: .buffered,
						  defer: false)

		super.init()

		window.title = ((path == .importOnly) ? ImportText("k3w-q8") : SetupText("sa-title"))
		window.titlebarAppearsTransparent = true
		window.titleVisibility = .hidden
		window.isMovableByWindowBackground = true
		window.tabbingMode = .disallowed
		window.isReleasedWhenClosed = false
		window.delegate = self

		window.standardWindowButton(.miniaturizeButton)?.isHidden = true
		window.standardWindowButton(.zoomButton)?.isHidden = true

		window.contentView = NSHostingView(rootView: SetupRootView(model: model))

		importModel?.window = window
		model.window = window

		model.finish = { [weak self] in
			self?.finish()
		}

		model.finishWithoutImport = { [weak self] in
			self?.stop()
		}
	}

	private func runModal()
	{
		isModal = true

		window.center()

		/* Quit stays available: AppKit dims a menu item during a modal window
		 unless its target works while modal, which the application doesn't */
		let quitItem = NSApp.mainMenu?.items
			.compactMap(\.submenu)
			.flatMap(\.items)
			.first { $0.action == #selector(NSApplication.terminate(_:)) }

		let quitItemTarget = quitItem?.target

		quitItem?.target = self

		/* Paste too: its target is the menu controller, which pastes into the chat.
		 Without one it goes to whichever field has the keyboard. */
		let pasteItems = (NSApp.mainMenu?.items ?? [])
			.compactMap(\.submenu)
			.flatMap(\.items)
			.filter { $0.action == #selector(NSText.paste(_:)) }

		let pasteItemTargets = pasteItems.map(\.target)

		pasteItems.forEach { $0.target = nil }

		NSApp.runModal(for: window)

		quitItem?.target = quitItemTarget

		zip(pasteItems, pasteItemTargets).forEach { $0.target = $1 }

		/* Gone before what comes next, which may block on a Keychain prompt: no fading
		 out, which needs this thread to carry on */
		window.animationBehavior = .none

		window.orderOut(nil)

		CATransaction.flush()
	}

	private func stop()
	{
		if (isModal) {
			NSApp.stopModal()

			return
		}

		model.applyLive()

		window.orderOut(nil)

		createChosenServers()

		Self.openBeside = nil
	}

	private func finish()
	{
		/* After an import from the menu, Textual has to restart */
		if (model.path == .importOnly) {
			TPCLegacyImport.restart()

			return
		}

		Self.markCompleted()

		stop()
	}

	private func finishClosedEarly()
	{
		if (model.path == .upgrade && SetupModel.shouldExplainArchive) {
			SetupModel.noteArchiveExplained()

			TDCAlert.modalAlert(withMessage: ImportText("arc-i1"), title: ImportText("arc-i2"), defaultButton: ImportText("oxy-im"), alternateButton: nil)
		}

		finish()
	}

	/* Quit: setup comes back at the next launch */
	@objc func worksWhenModal() -> Bool
	{
		true
	}

	@objc func terminate(_ sender: Any?)
	{
		if (model.importModel?.isCopying == true) {
			return
		}

		NSApp.terminate(sender)
	}

	/* Closing before anything happened is "not now": it comes back at the next
	 launch. After an import, setup ends with what was chosen so far. */
	func windowShouldClose(_ sender: NSWindow) -> Bool
	{
		switch model.step {
			case .welcome:
				stop()
			case .importing:
				guard let importModel = model.importModel, importModel.isCopying == false else {
					return false
				}

				if (importModel.stage == .access || importModel.stage == .nothingToImport) {
					stop()
				} else {
					finishClosedEarly()
				}
			default:
				finishClosedEarly()
		}

		return false
	}
}

// MARK: - Layout

struct SetupRootView: View
{
	static let size = NSSize(width: 720, height: 640)

	@ObservedObject var model: SetupModel

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View
	{
		VStack(spacing: 0) {
			/* A short step sits in the middle of the window; a long one scrolls */
			GeometryReader { geometry in
				ScrollView {
					SetupStepView(model: model)
						.padding(.horizontal, 36)
						.padding(.top, 28)
						.padding(.bottom, 12)
						.frame(maxWidth: .infinity, minHeight: geometry.size.height)
				}
				.scrollBounceBehavior(.basedOnSize)
			}
			.id(model.stepIdentity)
			.transition(.opacity)

			SetupFooter(model: model)
		}
		.frame(width: Self.size.width, height: Self.size.height)
		.sheet(item: $model.connectionCheck) { (check) in
			SetupConnectionCheckSheet(check: check) {
				model.finishCheck(goingOn: false)
			} goOn: {
				model.finishCheck(goingOn: true)
			}
		}
		.animation((reduceMotion ? nil : .easeInOut(duration: 0.18)), value: model.stepIdentity)
	}
}

struct SetupStepView: View
{
	@ObservedObject var model: SetupModel

	var body: some View
	{
		switch model.step {
			case .welcome:
				if let importModel = model.importModel, model.path != .newInstall {
					SetupImportWelcomeStep(model: importModel)
				} else {
					SetupWelcomeStep()
				}
			case .howIRCWorks:
				SetupHowIRCWorksStep()
			case .importing:
				if let importModel = model.importModel {
					SetupImportStep(model: importModel)
				}
			case .style:
				if let lookModel = model.lookModel {
					SetupStyleStep(model: lookModel)
				}
			case .look:
				if let lookModel = model.lookModel {
					SetupLookStep(model: lookModel)
				}
			case .chat:
				if let choicesModel = model.choicesModel {
					SetupChatStep(model: choicesModel)
				}
			case .privacy:
				if let choicesModel = model.choicesModel {
					SetupPrivacyStep(model: choicesModel)
				}
			case .notifications:
				SetupNotificationsStep(permission: model.notifications, upgrade: (model.path == .upgrade))
			case .interests:
				if let servers = model.serversModel {
					SetupInterestsStep(setup: model, model: servers)
				}
			case .suggestions:
				if let servers = model.serversModel {
					SetupSuggestionsStep(setup: model, model: servers)
				}
			case .networks:
				if let servers = model.serversModel {
					SetupNetworksStep(setup: model, model: servers)
				}
			case .yourName:
				if let servers = model.serversModel {
					SetupYourNameStep(model: servers)
				}
			case .importedServers:
				if let servers = model.serversModel {
					SetupImportedServersStep(setup: model, model: servers, imported: model.importedServers)
				}
			case .license:
				if let license = model.licenseModel {
					SetupLicenseStep(license: license, importModel: model.importModel)
				}
			case .done:
				SetupDoneStep(upgrade: model.keepsCurrentSettings, connectingTo: model.connectingTo)
		}
	}
}

/// Where the user is, and the way on
struct SetupFooter: View
{
	@ObservedObject var model: SetupModel

	var body: some View
	{
		HStack(spacing: 10) {
			if (model.isSettingsStep) {
				Button(SetupText(model.keepsCurrentSettings ? "sa-b-keepall" : "sa-b-recommended")) {
					model.skipSettings()
				}
				.buttonStyle(.link)
			} else {
				SetupProgressDots(steps: model.steps, step: model.step)
			}

			Spacer()

			buttons
		}
		.controlSize(.large)
		.padding(.horizontal, 20)
		.padding(.top, 10)
		.padding(.bottom, 16)
	}

	@ViewBuilder
	private var buttons: some View
	{
		switch model.step {
			case .welcome:
				welcomeButtons
			case .importing:
				if let importModel = model.importModel {
					SetupImportButtons(setup: model, model: importModel)
				}
			case .notifications:
				backButton

				SetupNotificationsButtons(setup: model, permission: model.notifications)
			case .license:
				backButton

				if let license = model.licenseModel {
					SetupLicenseButtons(setup: model, license: license)
				}
			case .done:
				backButton

				Button(doneTitle) {
					model.goForward()
				}
				.keyboardShortcut(.defaultAction)
			default:
				if (model.canGoBack) {
					backButton
				}

				Button(model.primaryTitle) {
					model.goForward()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(model.primaryIsEnabled == false)
		}
	}

	private var doneTitle: String
	{
		if (model.connectingTo.isEmpty == false) {
			return SetupText("sa-b-chat")
		}

		switch model.path {
			case .again: return SetupText("sa-b-done")
			case .upgrade: return ImportText("weu-cf")
			default: return SetupText("sa-b-finish")
		}
	}

	@ViewBuilder
	private var welcomeButtons: some View
	{
		switch model.path {
			case .newInstall:
				Button(SetupText("sa-b-know")) {
					model.start(newToIRC: false)
				}

				Button(SetupText("sa-b-new")) {
					model.start(newToIRC: true)
				}
				.keyboardShortcut(.defaultAction)
			case .upgrade:
				Button(ImportText("wpa-sv")) {
					model.startFresh()
				}

				if let importModel = model.importModel {
					SetupImportStartButton(setup: model, model: importModel)
				}
			case .serversOnly, .again:
				EmptyView()
			case .importOnly:
				Button(ImportText("qso-2g")) {
					model.finishWithoutImport?()
				}

				if let importModel = model.importModel {
					SetupImportStartButton(setup: model, model: importModel)
				}
		}
	}

	private var backButton: some View
	{
		Button(SetupText("sa-b-back")) {
			model.goBack()
		}
		.keyboardShortcut("[", modifiers: .command)
	}
}

struct SetupProgressDots: View
{
	let steps: [SetupStep]
	let step: SetupStep

	var body: some View
	{
		let position = (steps.firstIndex(of: step) ?? 0)

		HStack(spacing: 6) {
			ForEach(steps.indices, id: \.self) { index in
				Circle()
					.fill((index == position) ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
					.frame(width: 6, height: 6)
			}
		}
		.accessibilityElement()
		.accessibilityLabel(SetupText("sa-a-step", (position + 1), steps.count))
	}
}

/// The top of a step: the app's icon or a symbol, a title and what it's about
struct SetupHeader<Picture: View>: View
{
	let title: String
	let lead: String
	@ViewBuilder let picture: () -> Picture

	var body: some View
	{
		VStack(spacing: 6) {
			picture()
				.padding(.bottom, 4)

			Text(title)
				.multilineTextAlignment(.center)
				.font(.title.weight(.semibold))
				.accessibilityAddTraits(.isHeader)

			Text(lead)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.frame(maxWidth: 530)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.bottom, 18)
	}
}

/// A symbol on a colored square, as in Settings' sections
struct SetupSymbol: View
{
	let symbol: String
	let color: Color

	var body: some View
	{
		Image(systemName: symbol)
			.font(.system(size: 26, weight: .semibold))
			.foregroundStyle(.white)
			.frame(width: 48, height: 48)
			.background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.gradient))
			.accessibilityHidden(true)
	}
}

struct SetupAppIcon: View
{
	var body: some View
	{
		Image(nsImage: NSApp.applicationIconImage)
			.resizable()
			.frame(width: 72, height: 72)
			.accessibilityHidden(true)
	}
}

/// Rows on a soft background, as in a grouped Form
struct SetupGroup<Content: View>: View
{
	@ViewBuilder let content: () -> Content

	var body: some View
	{
		VStack(alignment: .leading, spacing: 0) {
			content()
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
	}
}

/// A title with an explanation under it; a divider above all but the first
struct SetupTextRow: View
{
	var divider = true
	let title: String
	let text: String

	var body: some View
	{
		VStack(spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(title)

				Text(text)
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 9)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .combine)
	}
}

// MARK: - Steps

struct SetupWelcomeStep: View
{
	var body: some View
	{
		VStack(spacing: 0) {
			SetupHeader(title: SetupText("sa-w-title"), lead: SetupText("sa-w-lead")) {
				SetupAppIcon()
			}

			SetupGroup {
				SetupTextRow(divider: false, title: SetupText("sa-w-new-t"), text: SetupText("sa-w-new-d"))
				SetupTextRow(title: SetupText("sa-w-know-t"), text: SetupText("sa-w-know-d"))
			}
			.frame(maxWidth: 460)
		}
	}
}

struct SetupHowIRCWorksStep: View
{
	var body: some View
	{
		VStack(spacing: 12) {
			SetupHeader(title: SetupText("sa-h-title"), lead: SetupText("sa-h-lead")) {
				SetupSymbol(symbol: "bubble.left.and.bubble.right.fill", color: .blue)
			}

			HStack(alignment: .top, spacing: 10) {
				SetupConceptCard(title: SetupText("sa-h-net-t"), text: SetupText("sa-h-net-d"), example: "Libera.Chat")
				SetupConceptCard(title: SetupText("sa-h-chan-t"), text: SetupText("sa-h-chan-d"), example: "#python · #linux")
				SetupConceptCard(title: SetupText("sa-h-ppl-t"), text: SetupText("sa-h-ppl-d"), example: "alice · bob")
			}
			.fixedSize(horizontal: false, vertical: true)

			SetupGroup {
				SetupTextRow(divider: false, title: SetupText("sa-h-know-t"), text: SetupText("sa-h-know-d"))
			}
		}
	}
}

/// One idea of IRC, with an example of it
struct SetupConceptCard: View
{
	let title: String
	let text: String
	let example: String

	var body: some View
	{
		VStack(alignment: .leading, spacing: 4) {
			Text(title)
				.fontWeight(.semibold)

			Text(text)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			Spacer(minLength: 4)

			Text(example)
				.font(.callout.weight(.medium))
				.modifier(ReadableAccentText())
		}
		.padding(12)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
		.accessibilityElement(children: .combine)
	}
}

struct SetupDoneStep: View
{
	let upgrade: Bool
	let connectingTo: [String]

	var body: some View
	{
		SetupHeader(title: SetupText("sa-d-title"), lead: (connectingTo.isEmpty ? (upgrade ? SetupText("sa-d-lead-u") : SetupText("sa-d-lead")) : SetupText("sa-d-lead-c", ListFormatter.localizedString(byJoining: connectingTo)))) {
			SetupSymbol(symbol: "checkmark", color: .green)
		}
	}
}

// MARK: - Import buttons

struct SetupImportStartButton: View
{
	let setup: SetupModel
	@ObservedObject var model: ImportModel

	var body: some View
	{
		Button(model.replacesServers ? ImportText("6e6-8o") : ImportText("zjw-bd")) {
			setup.startImport()
		}
		.keyboardShortcut(.defaultAction)
		.disabled(model.earlierVersionIsRunning)
	}
}

struct SetupImportButtons: View
{
	@ObservedObject var setup: SetupModel
	@ObservedObject var model: ImportModel

	var body: some View
	{
		switch model.stage {
			case .access:
				Button(ImportText("ivy-ht")) {
					setup.leaveImportAccess()
				}

				Button(ImportText("5je-mb")) {
					model.requestAccess()
				}
				.keyboardShortcut(.defaultAction)
			case .nothingToImport:
				Button(ImportText("ivy-ht")) {
					setup.leaveImportAccess()
				}
				.keyboardShortcut(.defaultAction)
			case .copying:
				EmptyView()
			case .license:
				Button(ImportText("xyt-ns")) {
					model.skipLicense()
				}

				Button(ImportText("5je-mb")) {
					model.requestLicenseAccess()
				}
				.keyboardShortcut(.defaultAction)
			case .summary:
				Button(model.fromMenu ? ImportText("33s-fi") : ImportText("zjw-bd")) {
					setup.goForward()
				}
				.keyboardShortcut(.defaultAction)
		}
	}
}

/// Asks macOS or goes on without asking; once it's asked, only goes on
struct SetupNotificationsButtons: View
{
	let setup: SetupModel

	@ObservedObject var permission: NotificationPermission

	var body: some View
	{
		if (permission.state == .notAsked && permission.asking == false) {
			Button(SetupText("sa-n-b-later")) {
				TDCSettingsBridge.declineNotificationPermissionForNow()

				setup.goForward()
			}

			Button(SetupText("sa-n-b-allow")) {
				permission.ask()
			}
			.keyboardShortcut(.defaultAction)
		} else {
			Button(SetupText("sa-b-continue")) {
				setup.goForward()
			}
			.keyboardShortcut(.defaultAction)
		}
	}
}
