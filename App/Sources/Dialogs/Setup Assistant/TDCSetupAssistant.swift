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
	case done
}

enum SetupPath
{
	case newInstall
	case upgrade // Textual 7 or an earlier version was found
	case importOnly // File > Import Settings from Textual 7…
}

final class SetupModel: ObservableObject
{
	@Published private(set) var path: SetupPath
	@Published private(set) var step = SetupStep.welcome

	/* From Welcome: new to IRC gets the introduction */
	private var newToIRC = true

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

	private static let settingsSteps: [SetupStep] = [.style, .look, .chat, .privacy]

	var steps: [SetupStep]
	{
		switch path {
			case .newInstall:
				return ((newToIRC ? [.welcome, .howIRCWorks] : [.welcome]) + Self.settingsSteps + [.done])
			case .upgrade:
				return ([.welcome, .importing] + Self.settingsSteps + [.done])
			case .importOnly:
				return [.welcome, .importing]
		}
	}

	func start(newToIRC: Bool)
	{
		self.newToIRC = newToIRC

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
		guard let index = steps.firstIndex(of: step), index < (steps.count - 1) else {
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
			lookModel = SetupLookModel(upgrade: (path == .upgrade), window: window)
			choicesModel = SetupChoicesModel(upgrade: (path == .upgrade))
		}

		step = newStep
	}

	/// Use Recommended or Keep Everything: past the settings' steps
	func skipSettings()
	{
		lookModel?.applyRecommended()
		choicesModel?.applyRecommended()

		guard let next = steps.first(where: { $0 == .done }) else {
			return
		}

		move(to: next)
	}

	var isSettingsStep: Bool
	{
		Self.settingsSteps.contains(step)
	}

	var canGoBack: Bool
	{
		/* An import can't be gone back into */
		(path != .upgrade || step != .style)
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
		window.center()

		/* Quit stays available: AppKit dims a menu item during a modal window
		 unless its target works while modal, which the application doesn't */
		let quitItem = NSApp.mainMenu?.items
			.compactMap(\.submenu)
			.flatMap(\.items)
			.first { $0.action == #selector(NSApplication.terminate(_:)) }

		let quitItemTarget = quitItem?.target

		quitItem?.target = self

		NSApp.runModal(for: window)

		quitItem?.target = quitItemTarget

		window.orderOut(nil)
	}

	private func stop()
	{
		NSApp.stopModal()
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
					finish()
				}
			default:
				finish()
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
			case .done:
				SetupDoneStep(upgrade: (model.path == .upgrade))
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
				Button(SetupText((model.path == .upgrade) ? "sa-b-keepall" : "sa-b-recommended")) {
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
			case .done:
				backButton

				Button((model.path == .upgrade) ? ImportText("weu-cf") : SetupText("sa-b-finish")) {
					model.goForward()
				}
				.keyboardShortcut(.defaultAction)
			default:
				if (model.canGoBack) {
					backButton
				}

				Button(SetupText("sa-b-continue")) {
					model.goForward()
				}
				.keyboardShortcut(.defaultAction)
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
				.foregroundStyle(Color.accentColor)
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

	var body: some View
	{
		SetupHeader(title: SetupText("sa-d-title"), lead: (upgrade ? SetupText("sa-d-lead-u") : SetupText("sa-d-lead"))) {
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
