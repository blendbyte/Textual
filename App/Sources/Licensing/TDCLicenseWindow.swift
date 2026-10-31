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

/* The license window: the trial or the license at the top, and below it
 what can be done, in the look of Settings. Everything happens inside the
 window: errors under the key field, the Mac to move a key from, upgrade
 offers. TDCLicenseManagerDialog does the work and fills in the model. */

/// A string of the license window (TLOLicenseManager.strings)
func LicenseText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TLOLicenseManager[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Model

/// What the window is waiting for, shown as a spinner in its button
@objc(TDCLicenseWindowBusy)
enum LicenseWindowBusy: Int
{
	case none = 0
	case activating
	case deactivating
	case checkingUpgrade
	case upgrading
}

/// One of the two Macs a key is in use on
@objc(TDCLicenseWindowSeat)
final class LicenseWindowSeat: NSObject, Identifiable
{
	@objc let activationID: String
	@objc let title: String
	@objc let detail: String

	var id: String { activationID }

	@objc(initWithActivationID:title:detail:)
	init(activationID: String, title: String, detail: String)
	{
		self.activationID = activationID
		self.title = title
		self.detail = detail
	}
}

@objc(TDCLicenseWindowModel)
final class LicenseWindowModel: NSObject, ObservableObject
{
	/* The top */
	@objc var registered = false { willSet { objectWillChange.send() } }
	@objc var statusText = "" { willSet { objectWillChange.send() } }
	@objc var trialFraction: Double = -1 { willSet { objectWillChange.send() } } // Below 0: no bar

	/* Licensed */
	@objc var licenseKey = "" { willSet { objectWillChange.send() } }
	@objc var licenseDate = "" { willSet { objectWillChange.send() } }
	@objc var macModel = "" { willSet { objectWillChange.send() } }
	@objc var deactivateError: String? { willSet { objectWillChange.send() } }

	/* Activating */
	@objc var keyText = "" { willSet { objectWillChange.send() } }
	@objc var keyError: String? { willSet { objectWillChange.send() } }
	@objc var keyErrorOffersSupport = false { willSet { objectWillChange.send() } }
	@objc var busy = LicenseWindowBusy.none { willSet { objectWillChange.send() } }

	/* Both seats taken */
	@objc var seats: [LicenseWindowSeat] = [] { willSet { objectWillChange.send() } }
	@objc var selectedSeatID: String? { willSet { objectWillChange.send() } }
	@objc var seatsNote = "" { willSet { objectWillChange.send() } }

	/* Textual 7 */
	@objc var textual7LicenseKey: String? { willSet { objectWillChange.send() } }
	@objc var upgradeError: String? { willSet { objectWillChange.send() } }

	/* An upgrade offer, or anything else to decide on */
	@objc var offerTitle: String? { willSet { objectWillChange.send() } }
	@objc var offerMessage: String? { willSet { objectWillChange.send() } }
	@objc var offerLicenseKey: String? { willSet { objectWillChange.send() } }
	@objc var offerPrimaryTitle: String? { willSet { objectWillChange.send() } }
	@objc var offerSecondaryTitle: String? { willSet { objectWillChange.send() } }

	/* What the buttons do, set by the dialog */
	@objc var cleanKey: ((String) -> String)?
	@objc var isValidKey: ((String) -> Bool)?
	@objc var activate: ((String) -> Void)?
	@objc var lostKey: (() -> Void)?
	@objc var buy: (() -> Void)?
	@objc var upgrade: (() -> Void)?
	@objc var moveSeat: ((String) -> Void)?
	@objc var cancelSeats: (() -> Void)?
	@objc var offerPrimary: (() -> Void)?
	@objc var offerSecondary: (() -> Void)?
	@objc var deactivate: (() -> Void)?
	@objc var contactSupport: (() -> Void)?

	var keyIsValid: Bool
	{
		isValidKey?(keyText) ?? false
	}

	func activateKey()
	{
		guard keyIsValid, busy == .none else {
			return
		}

		activate?(keyText)
	}
}

// MARK: - Window

@objc(TDCLicenseWindow)
final class LicenseWindow: NSObject
{
	@objc let window: NSWindow

	@objc(initWithModel:)
	init(model: LicenseWindowModel)
	{
		let hostingController = NSHostingController(rootView: LicenseRootView(model: model))

		/* The window follows the content's height as the sections come and go */
		hostingController.sizingOptions = [.preferredContentSize]

		window = NSWindow(contentViewController: hostingController)

		window.styleMask = [.titled, .closable, .miniaturizable]
		window.title = LicenseText("lw-title")
		window.tabbingMode = .disallowed
		window.isReleasedWhenClosed = false

		super.init()
	}
}

// MARK: - Views

struct LicenseRootView: View
{
	/* Wide enough for a whole license key in the field, with Copy beside it */
	static let width: CGFloat = 600

	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		VStack(alignment: .leading, spacing: 0) {
			LicenseHeader(model: model)

			/* An offer first; the Mac to move a key from right under the key */
			if (model.offerTitle != nil) {
				LicenseOfferSection(model: model)
			}

			if (model.registered) {
				LicenseLicensedSections(model: model)

				if (model.seats.isEmpty == false) {
					LicenseSeatsSection(model: model)
				}
			} else {
				LicenseActivateSection(model: model)

				if (model.seats.isEmpty == false) {
					LicenseSeatsSection(model: model)
				} else {
					LicenseGetKeySection(model: model)
				}
			}
		}
		.padding(.horizontal, 20)
		.padding(.top, 8)
		.padding(.bottom, 20)
		.frame(width: Self.width)
		.fixedSize(horizontal: false, vertical: true)
		.animation(.default, value: model.registered)
	}
}

/// The trial or the license, as a Settings page's header
struct LicenseHeader: View
{
	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		VStack(spacing: 6) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 64, height: 64)

			Text(LicenseText("lw-h0"))
				.font(.title.weight(.semibold))

			if (model.registered) {
				Label(model.statusText, systemImage: "checkmark.seal.fill")
					.font(.headline)
					.foregroundStyle(.green)

				Text(LicenseText("lw-h1"))
					.foregroundStyle(.secondary)
			} else {
				Text(model.statusText)
					.foregroundStyle(.secondary)

				if (model.trialFraction >= 0) {
					ProgressView(value: model.trialFraction)
						.frame(width: 240)
						.padding(.top, 2)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 16)
		.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
	}
}

/// A titled group of rows, as in a grouped Form
struct LicenseGroup<Content: View>: View
{
	let title: String
	@ViewBuilder let content: () -> Content

	var body: some View
	{
		VStack(alignment: .leading, spacing: 6) {
			Text(title)
				.font(.headline)
				.padding(.leading, 2)

			VStack(alignment: .leading, spacing: 0) {
				content()
			}
			.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quinary))
		}
		.padding(.top, 18)
	}
}

/// One row of a group; a divider above all but the first
struct LicenseRow<Content: View>: View
{
	var divider = true
	@ViewBuilder let content: () -> Content

	var body: some View
	{
		VStack(spacing: 0) {
			if (divider) {
				Divider()
					.padding(.horizontal, 10)
			}

			HStack(spacing: 10) {
				content()
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 9)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

/// A button's title with a spinner while it waits
struct LicenseBusyLabel: View
{
	let title: String
	let busy: Bool

	var body: some View
	{
		HStack(spacing: 6) {
			if (busy) {
				ProgressView()
					.controlSize(.small)
			}

			Text(title)
		}
	}
}

/// What went wrong, in red, with Contact Support when it may help
struct LicenseErrorText: View
{
	let text: String
	var offersSupport = false
	let contactSupport: (() -> Void)?

	var body: some View
	{
		VStack(alignment: .leading, spacing: 4) {
			Text(text)
				.foregroundStyle(.red)
				.fixedSize(horizontal: false, vertical: true)

			if (offersSupport) {
				Button(LicenseText("vgp-j6")) {
					contactSupport?()
				}
				.buttonStyle(.link)
			}
		}
		.font(.callout)
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

/// A license key, whole, to read or select
struct LicenseKeyText: View
{
	let key: String

	var body: some View
	{
		Text(key)
			.font(.system(.body, design: .monospaced))
			.textSelection(.enabled)
			.lineLimit(1)
			.fixedSize()
	}
}

struct LicenseCopyButton: View
{
	let key: String

	var body: some View
	{
		Button(LicenseText("lw-copy")) {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(key, forType: .string)
		}
	}
}

struct LicenseActivateSection: View
{
	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		LicenseGroup(title: LicenseText("lw-a0")) {
			LicenseRow(divider: false) {
				Text(LicenseText("lw-a1"))

				LicenseKeyField(model: model)
			}

			if let keyError = model.keyError {
				LicenseRow(divider: false) {
					LicenseErrorText(text: keyError, offersSupport: model.keyErrorOffersSupport, contactSupport: model.contactSupport)
				}
				.padding(.top, -6)
			}

			LicenseRow {
				Button(LicenseText("lw-a2")) {
					model.lostKey?()
				}
				.buttonStyle(.link)

				Spacer()

				Button {
					model.activateKey()
				} label: {
					LicenseBusyLabel(title: LicenseText("lw-a3"), busy: ((model.busy == .activating) && model.seats.isEmpty))
				}
				/* The window's one default button: an offer's or the seats' when they're shown */
				.keyboardShortcut((model.seats.isEmpty && model.offerTitle == nil) ? .defaultAction : nil)
				.disabled(model.keyIsValid == false || model.busy != .none || model.seats.isEmpty == false)
			}
		}
	}
}

/// The key field: as it's typed or pasted, only what a key can have stays
/// (spaces, line breaks and quotes go), the insertion point where it was;
/// Return activates
struct LicenseKeyField: NSViewRepresentable
{
	@ObservedObject var model: LicenseWindowModel

	func makeNSView(context: Context) -> NSTextField
	{
		let field = NSTextField()

		field.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		field.usesSingleLineMode = true
		field.lineBreakMode = .byClipping
		field.cell?.isScrollable = true
		field.bezelStyle = .roundedBezel
		field.delegate = context.coordinator
		field.placeholderString = LicenseText("lw-a4")
		field.setContentHuggingPriority(.defaultLow, for: .horizontal)

		return field
	}

	func updateNSView(_ field: NSTextField, context: Context)
	{
		context.coordinator.model = model

		if (field.stringValue != model.keyText) {
			field.stringValue = model.keyText
		}
	}

	func makeCoordinator() -> Coordinator
	{
		Coordinator(model: model)
	}

	final class Coordinator: NSObject, NSTextFieldDelegate
	{
		var model: LicenseWindowModel

		init(model: LicenseWindowModel)
		{
			self.model = model
		}

		func controlTextDidChange(_ notification: Notification)
		{
			guard let field = notification.object as? NSTextField else {
				return
			}

			let typed = field.stringValue

			let cleaned = (model.cleanKey?(typed) ?? typed)

			if (cleaned != typed) {
				let editor = field.currentEditor()

				let insertionPoint = min(NSMaxRange(editor?.selectedRange ?? NSRange(location: typed.utf16.count, length: 0)), typed.utf16.count)

				let typedBefore = String((typed as NSString).substring(to: insertionPoint))

				let cleanedInsertionPoint = (model.cleanKey?(typedBefore) ?? typedBefore).utf16.count

				field.stringValue = cleaned

				editor?.selectedRange = NSRange(location: cleanedInsertionPoint, length: 0)
			}

			model.keyText = cleaned

			/* A new key: the last one's error is about something else */
			model.keyError = nil
		}

		func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool
		{
			if (commandSelector == #selector(NSResponder.insertNewline(_:))) {
				model.activateKey()

				return true
			}

			return false
		}
	}
}

struct LicenseGetKeySection: View
{
	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		LicenseGroup(title: LicenseText("lw-b0")) {
			/* Not while its offer is shown above */
			if let textual7LicenseKey = model.textual7LicenseKey, model.offerTitle == nil {
				LicenseRow(divider: false) {
					VStack(alignment: .leading, spacing: 2) {
						Text(LicenseText("lw-b1"))

						Text(LicenseText("lw-b2", textual7LicenseKey))
							.font(.callout)
							.foregroundStyle(.secondary)
					}

					Spacer()

					Button {
						model.upgrade?()
					} label: {
						LicenseBusyLabel(title: LicenseText("lw-b3"), busy: (model.busy == .checkingUpgrade))
					}
					.disabled(model.busy != .none)
				}

				if let upgradeError = model.upgradeError {
					LicenseRow(divider: false) {
						LicenseErrorText(text: upgradeError, offersSupport: true, contactSupport: model.contactSupport)
					}
					.padding(.top, -6)
				}
			}

			LicenseRow(divider: (model.textual7LicenseKey != nil && model.offerTitle == nil)) {
				VStack(alignment: .leading, spacing: 2) {
					Text(LicenseText("lw-b4"))

					Text(LicenseText("lw-b5"))
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				Spacer()

				Button(LicenseText("lw-b6")) {
					model.buy?()
				}
			}
		}
	}
}

/// Both seats taken: the Mac to move the key from
struct LicenseSeatsSection: View
{
	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		LicenseGroup(title: LicenseText("lw-s0")) {
			ForEach(Array(model.seats.enumerated()), id: \.element.id) { (index, seat) in
				LicenseRow(divider: (index > 0)) {
					Image(systemName: ((model.selectedSeatID == seat.activationID) ? "largecircle.fill.circle" : "circle"))
						.foregroundStyle((model.selectedSeatID == seat.activationID) ? Color.accentColor : Color.secondary)
						.font(.title3)

					VStack(alignment: .leading, spacing: 2) {
						Text(seat.title)

						Text(seat.detail)
							.font(.callout)
							.foregroundStyle(.secondary)
					}

					Spacer()
				}
				.contentShape(Rectangle())
				.onTapGesture {
					model.selectedSeatID = seat.activationID
				}
			}
		}

		VStack(alignment: .leading, spacing: 10) {
			Text(model.seatsNote)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			HStack {
				Spacer()

				Button(LicenseText("lw-s1")) {
					model.cancelSeats?()
				}
				.keyboardShortcut(.cancelAction)

				Button {
					if let activationID = model.selectedSeatID {
						model.moveSeat?(activationID)
					}
				} label: {
					LicenseBusyLabel(title: LicenseText("lw-s2"), busy: (model.busy == .activating))
				}
				.keyboardShortcut(.defaultAction)
				.disabled(model.selectedSeatID == nil || model.busy != .none)
			}
		}
		.padding(.top, 8)
		.padding(.horizontal, 2)
	}
}

/// An upgrade offer from the licensing server, or its answer
struct LicenseOfferSection: View
{
	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		LicenseGroup(title: LicenseText("lw-u0")) {
			LicenseRow(divider: false) {
				VStack(alignment: .leading, spacing: 4) {
					Text(model.offerTitle ?? "")
						.font(.headline)

					if let message = model.offerMessage {
						Text(message)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}

			if let offerLicenseKey = model.offerLicenseKey {
				LicenseRow {
					LicenseKeyText(key: offerLicenseKey)

					Spacer()

					LicenseCopyButton(key: offerLicenseKey)
				}
			}

			if let upgradeError = model.upgradeError {
				LicenseRow {
					LicenseErrorText(text: upgradeError, offersSupport: true, contactSupport: model.contactSupport)
				}
			}

			LicenseRow {
				if let secondaryTitle = model.offerSecondaryTitle {
					Button(secondaryTitle) {
						model.offerSecondary?()
					}
					.disabled(model.busy != .none)
				}

				Spacer()

				if let primaryTitle = model.offerPrimaryTitle {
					Button {
						model.offerPrimary?()
					} label: {
						LicenseBusyLabel(title: primaryTitle, busy: (model.busy == .upgrading))
					}
					.keyboardShortcut(.defaultAction)
					.disabled(model.busy != .none)
				}
			}
		}
	}
}

struct LicenseLicensedSections: View
{
	@ObservedObject var model: LicenseWindowModel

	var body: some View
	{
		LicenseGroup(title: LicenseText("lw-l0")) {
			LicenseRow(divider: false) {
				Text(LicenseText("lw-a1"))

				Spacer()

				LicenseKeyText(key: model.licenseKey)

				LicenseCopyButton(key: model.licenseKey)
			}

			if (model.licenseDate.isEmpty == false) {
				LicenseRow {
					Text(LicenseText("lw-l1"))

					Spacer()

					Text(model.licenseDate)
						.foregroundStyle(.secondary)
				}
			}

			if let keyError = model.keyError {
				LicenseRow {
					LicenseErrorText(text: keyError, offersSupport: model.keyErrorOffersSupport, contactSupport: model.contactSupport)
				}
			}
		}

		LicenseGroup(title: LicenseText("lw-m0")) {
			LicenseRow(divider: false) {
				VStack(alignment: .leading, spacing: 2) {
					Text(LicenseText("lw-m1", model.macModel))

					Text(LicenseText("lw-m2"))
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			if let deactivateError = model.deactivateError {
				LicenseRow {
					LicenseErrorText(text: deactivateError, contactSupport: model.contactSupport)
				}
			}

			LicenseRow {
				Spacer()

				Button(role: .destructive) {
					model.deactivate?()
				} label: {
					LicenseBusyLabel(title: LicenseText("lw-m3"), busy: (model.busy == .deactivating))
				}
				.disabled(model.busy != .none)
			}
		}
	}
}

// MARK: - Trial Ended

/// What the main window shows instead of the chat once the trial has ended
@objc(TDCLicenseTrialEndedView)
final class LicenseTrialEndedViewFactory: NSObject
{
	@objc(viewWithTextual7License:activate:buy:upgrade:)
	static func view(textual7License: Bool, activate: @escaping () -> Void, buy: @escaping () -> Void, upgrade: @escaping () -> Void) -> NSView
	{
		let view = NSHostingView(rootView: LicenseTrialEndedView(textual7License: textual7License, activate: activate, buy: buy, upgrade: upgrade))

		view.translatesAutoresizingMaskIntoConstraints = false

		return view
	}
}

struct LicenseTrialEndedView: View
{
	let textual7License: Bool
	let activate: () -> Void
	let buy: () -> Void
	let upgrade: () -> Void

	var body: some View
	{
		VStack(spacing: 16) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 96, height: 96)

			VStack(spacing: 6) {
				Text(LicenseText("lw-x0"))
					.font(.title.weight(.semibold))

				Text(LicenseText(textual7License ? "lw-x5" : "lw-x1"))
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}

			if (textual7License) {
				/* Three in a row, or the upgrade above the other two when they don't fit */
				ViewThatFits(in: .horizontal) {
					HStack(spacing: 10) {
						buyButton

						activateButton

						upgradeButton
					}

					VStack(spacing: 10) {
						upgradeButton

						HStack(spacing: 10) {
							buyButton

							activateButton
						}
					}
				}
				.controlSize(.large)
				.padding(.top, 4)
			} else {
				HStack(spacing: 10) {
					buyButton

					activateButton
						.keyboardShortcut(.defaultAction)
				}
				.controlSize(.large)
				.padding(.top, 4)
			}
		}
		.padding(.horizontal, 32)
		.padding(.vertical, 28)
		.frame(width: 480)
		.background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quinary))
	}

	private var buyButton: some View
	{
		Button(LicenseText("lw-x3"), action: buy)
	}

	private var activateButton: some View
	{
		Button(LicenseText("lw-x2"), action: activate)
	}

	private var upgradeButton: some View
	{
		Button(LicenseText("lw-x4"), action: upgrade)
			.keyboardShortcut(.defaultAction)
	}
}
