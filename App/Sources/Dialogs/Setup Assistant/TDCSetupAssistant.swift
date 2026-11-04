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
	case done
}

final class SetupModel: ObservableObject
{
	@Published private(set) var step = SetupStep.welcome

	/* From Welcome: new to IRC gets the introduction */
	private var newToIRC = true

	var finish: (() -> Void)?

	var steps: [SetupStep]
	{
		var steps = [SetupStep.welcome]

		if (newToIRC) {
			steps.append(.howIRCWorks)
		}

		steps.append(.done)

		return steps
	}

	func start(newToIRC: Bool)
	{
		self.newToIRC = newToIRC

		goForward()
	}

	func goForward()
	{
		guard let index = steps.firstIndex(of: step), index < (steps.count - 1) else {
			finish?()

			return
		}

		step = steps[index + 1]
	}

	func goBack()
	{
		guard let index = steps.firstIndex(of: step), index > 0 else {
			return
		}

		step = steps[index - 1]
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

	private let model = SetupModel()
	private let window: NSWindow

	@objc(offerAtLaunchThen:)
	static func offerAtLaunch(then completion: @escaping () -> Void)
	{
		guard shouldOfferAtLaunch else {
			completion()

			return
		}

		/* Not before the app has finished launching, for the reason in
		 +[TDCLegacyImportAssistant offerImportAtLaunchThen:] */
		RunLoop.main.perform(inModes: [.default]) {
			let assistant = SetupAssistant()

			assistant.runModal()

			completion()
		}
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

		/* Already in use, or imported: it doesn't come back if the servers are removed later */
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

	private override init()
	{
		window = NSWindow(contentRect: NSRect(origin: .zero, size: SetupRootView.size),
						  styleMask: [.titled, .closable, .fullSizeContentView],
						  backing: .buffered,
						  defer: false)

		super.init()

		window.title = SetupText("sa-title")
		window.titlebarAppearsTransparent = true
		window.titleVisibility = .hidden
		window.isMovableByWindowBackground = true
		window.tabbingMode = .disallowed
		window.isReleasedWhenClosed = false
		window.delegate = self

		window.standardWindowButton(.miniaturizeButton)?.isHidden = true
		window.standardWindowButton(.zoomButton)?.isHidden = true

		window.contentView = NSHostingView(rootView: SetupRootView(model: model))

		model.finish = { [weak self] in
			Self.markCompleted()

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

	/* Quit: setup comes back at the next launch */
	@objc func worksWhenModal() -> Bool
	{
		true
	}

	@objc func terminate(_ sender: Any?)
	{
		NSApp.terminate(sender)
	}

	/* Closing on Welcome is "not now": it comes back at the next launch.
	 Later on, setup ends with what was chosen so far. */
	func windowShouldClose(_ sender: NSWindow) -> Bool
	{
		if (model.step != .welcome) {
			Self.markCompleted()
		}

		stop()

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
					SetupStepView(step: model.step)
						.padding(.horizontal, 36)
						.padding(.top, 28)
						.padding(.bottom, 12)
						.frame(maxWidth: .infinity, minHeight: geometry.size.height)
				}
				.scrollBounceBehavior(.basedOnSize)
			}
			.id(model.step)
			.transition(.opacity)

			SetupFooter(model: model)
		}
		.frame(width: Self.size.width, height: Self.size.height)
		.animation((reduceMotion ? nil : .easeInOut(duration: 0.18)), value: model.step)
	}
}

struct SetupStepView: View
{
	let step: SetupStep

	var body: some View
	{
		switch step {
			case .welcome: SetupWelcomeStep()
			case .howIRCWorks: SetupHowIRCWorksStep()
			case .done: SetupDoneStep()
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
			SetupProgressDots(steps: model.steps, step: model.step)

			Spacer()

			switch model.step {
				case .welcome:
					Button(SetupText("sa-b-know")) {
						model.start(newToIRC: false)
					}

					Button(SetupText("sa-b-new")) {
						model.start(newToIRC: true)
					}
					.keyboardShortcut(.defaultAction)
				case .done:
					backButton

					Button(SetupText("sa-b-finish")) {
						model.goForward()
					}
					.keyboardShortcut(.defaultAction)
				default:
					backButton

					Button(SetupText("sa-b-continue")) {
						model.goForward()
					}
					.keyboardShortcut(.defaultAction)
			}
		}
		.controlSize(.large)
		.padding(.horizontal, 20)
		.padding(.top, 10)
		.padding(.bottom, 16)
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
	var body: some View
	{
		SetupHeader(title: SetupText("sa-d-title"), lead: SetupText("sa-d-lead")) {
			SetupSymbol(symbol: "checkmark", color: .green)
		}
	}
}
