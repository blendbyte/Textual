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

/* The File Transfers window: one row per transfer with what it is doing in
 plain words and the buttons that fit; the same actions in its right-click
 menu. The dialog (TDCFileTransferDialog) keeps the transfers and does what
 the buttons ask. */

/// A string of the File Transfers window (TDCFileTransferDialog.strings)
func FileTransfersText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCFileTransferDialog[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Rows

enum FileTransferState: Equatable
{
	case offer			// Someone offers a file, not answered yet
	case preparing		// Finding the address or a port
	case waiting		// For the other side to accept or connect
	case moving
	case stopped		// By you
	case failed			// Can be tried again
	case failedForGood
	case done

	var canStop: Bool
	{
		[.preparing, .waiting, .moving].contains(self)
	}

	var canRetry: Bool
	{
		[.stopped, .failed].contains(self)
	}

	var isFinished: Bool
	{
		[.done, .failed, .failedForGood].contains(self)
	}

	var isFailure: Bool
	{
		[.failed, .failedForGood].contains(self)
	}
}

struct FileTransferRow: Identifiable, Equatable
{
	let id: String
	let transfer: TDCFileTransferDialogTransferController
	let filename: String
	let size: String
	let isSender: Bool
	let state: FileTransferState
	let status: String
	let progress: Double? // While data moves
	let isConnecting: Bool

	static func == (lhs: FileTransferRow, rhs: FileTransferRow) -> Bool
	{
		(lhs.id == rhs.id &&
		 lhs.filename == rhs.filename &&
		 lhs.size == rhs.size &&
		 lhs.state == rhs.state &&
		 lhs.status == rhs.status &&
		 lhs.progress == rhs.progress &&
		 lhs.isConnecting == rhs.isConnecting)
	}

	var canOpen: Bool
	{
		(state == .done && isSender == false)
	}

	var canReveal: Bool
	{
		(state == .done || isSender)
	}

	init(transfer: TDCFileTransferDialogTransferController, showsServerName: Bool)
	{
		id = transfer.uniqueIdentifier
		self.transfer = transfer
		filename = transfer.filename
		size = Self.bytes(transfer.totalFilesize)
		isSender = transfer.isSender

		var peer = transfer.peerNickname

		if showsServerName, let client = transfer.client {
			peer = FileTransfersText("ftw-on", peer, client.networkNameAlt)
		}

		var progress: Double? = nil
		var isConnecting = false

		switch transfer.transferStatus {
			case .stopped:
				/* An offer has no folder until it's accepted */
				if (transfer.isSender == false && transfer.path == nil) {
					state = .offer
					status = FileTransfersText("ftw-offer", peer)
				} else {
					state = .stopped
					status = FileTransfersText((transfer.isSender ? "ftw-stopped-to" : "ftw-stopped-from"), peer)
				}
			case .initializing, .mappingListeningPort, .waitingForLocalIPAddress:
				state = .preparing
				status = FileTransfersText("ftw-preparing")
			case .isListeningAsSender, .waitingForReceiverToAccept:
				state = .waiting
				status = FileTransfersText("ftw-wait-accept", peer)
			case .isListeningAsReceiver:
				state = .waiting
				status = FileTransfersText("ftw-wait-connect", peer)
			case .waitingForResumeAccept:
				state = .waiting
				status = FileTransfersText("ftw-resume", peer)
			case .connecting:
				state = .waiting
				status = FileTransfersText("ftw-connecting", peer)
				isConnecting = true
			case .sending, .receiving:
				state = .moving
				status = Self.progressText(of: transfer)

				if (transfer.totalFilesize > 0) {
					progress = min(1, (Double(transfer.processedFilesize) / Double(transfer.totalFilesize)))
				} else {
					progress = 0
				}
			case .complete:
				state = .done

				if transfer.isSender {
					status = FileTransfersText("ftw-sent", peer)
				} else {
					let folder = transfer.path.map { FileManager.default.displayName(atPath: $0) } ?? ""

					status = FileTransfersText("ftw-received", peer, folder)
				}
			case .recoverableError, .fatalError:
				state = ((transfer.transferStatus == .fatalError) ? .failedForGood : .failed)
				status = FileTransfersText("ftw-failed", (transfer.errorMessageDescription ?? ""))
			@unknown default:
				state = .stopped
				status = ""
		}

		self.progress = progress
		self.isConnecting = isConnecting
	}

	static func bytes(_ count: UInt64) -> String
	{
		ByteCountFormatter.string(fromByteCount: Int64(clamping: count), countStyle: .file)
	}

	/// "12 MB of 100 MB · 1.2 MB/s · 2 minutes left"
	private static func progressText(of transfer: TDCFileTransferDialogTransferController) -> String
	{
		let records = transfer.speedRecords

		/* Bytes a second, over the last few seconds */
		let speed: UInt64 = (records.isEmpty ? 0 : (records.reduce(0) { $0 + $1.uint64Value } / UInt64(records.count)))

		let processed = transfer.processedFilesize
		let total = transfer.totalFilesize

		if (speed > 0 && total > processed),
		   let left = timeLeftFormatter.string(from: TimeInterval((total - processed) / speed))
		{
			return FileTransfersText("ftw-progress-left", bytes(processed), bytes(total), bytes(speed), left)
		}

		return FileTransfersText("ftw-progress", bytes(processed), bytes(total), bytes(speed))
	}

	private static let timeLeftFormatter: DateComponentsFormatter =
	{
		let formatter = DateComponentsFormatter()

		formatter.allowedUnits = [.day, .hour, .minute, .second]
		formatter.unitsStyle = .full
		formatter.maximumUnitCount = 2

		return formatter
	}()
}

// MARK: - Window

final class FileTransfersModel: ObservableObject
{
	@Published private(set) var rows: [FileTransferRow] = []

	@Published var selection = Set<String>()

	/* Asked about before they go: they are still running */
	@Published var pendingRemoval: [TDCFileTransferDialogTransferController] = []

	private weak var dialog: TDCFileTransferDialog?

	weak var window: NSWindow?

	private var icons: [String: NSImage] = [:]

	init(dialog: TDCFileTransferDialog)
	{
		self.dialog = dialog
	}

	func reload()
	{
		guard let dialog = dialog else {
			return
		}

		let showsServerNames = dialog.showsServerNames

		let rows = dialog.fileTransfers.map { FileTransferRow(transfer: $0, showsServerName: showsServerNames) }

		if (rows != self.rows) {
			self.rows = rows
		}

		let identifiers = Set(rows.map(\.id))

		if (selection.isSubset(of: identifiers) == false) {
			selection.formIntersection(identifiers)
		}
	}

	func rows(_ identifiers: Set<String>) -> [FileTransferRow]
	{
		rows.filter { identifiers.contains($0.id) }
	}

	var hasFinished: Bool
	{
		rows.contains { $0.state.isFinished }
	}

	func icon(for filename: String) -> NSImage
	{
		let pathExtension = (filename as NSString).pathExtension.lowercased()

		if let icon = icons[pathExtension] {
			return icon
		}

		let icon = NSWorkspace.shared.icon(for: (UTType(filenameExtension: pathExtension) ?? .data))

		icons[pathExtension] = icon

		return icon
	}

	// MARK: Actions

	func start(_ rows: [FileTransferRow])
	{
		dialog?.startFileTransfers(rows.map(\.transfer))
	}

	func stop(_ rows: [FileTransferRow])
	{
		dialog?.stopFileTransfers(rows.map(\.transfer))
	}

	func open(_ rows: [FileTransferRow])
	{
		dialog?.openFileTransfers(rows.map(\.transfer))
	}

	func reveal(_ rows: [FileTransferRow])
	{
		dialog?.revealFileTransfers(rows.map(\.transfer))
	}

	func remove(_ rows: [FileTransferRow])
	{
		if rows.contains(where: { $0.state.canStop }) {
			pendingRemoval = rows.map(\.transfer)
		} else {
			dialog?.removeFileTransfers(rows.map(\.transfer))
		}
	}

	func confirmRemoval()
	{
		dialog?.removeFileTransfers(pendingRemoval)

		pendingRemoval = []
	}

	func clearFinished()
	{
		dialog?.clearFinishedFileTransfers()
	}

	/* Double-click or Return: accept an offer, open what arrived, show what was sent */
	func primaryAction(_ rows: [FileTransferRow])
	{
		start(rows.filter { $0.state == .offer })

		open(rows.filter(\.canOpen))

		reveal(rows.filter { $0.state == .done && $0.isSender })
	}
}

@objc(TDCFileTransfersWindow)
final class FileTransfersWindow: NSObject
{
	@objc let window: NSWindow

	private let model: FileTransfersModel

	@objc(initWithDialog:)
	init(dialog: TDCFileTransferDialog)
	{
		model = FileTransfersModel(dialog: dialog)

		window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 380),
						  styleMask: [.titled, .closable, .miniaturizable, .resizable],
						  backing: .buffered,
						  defer: true)

		window.isReleasedWhenClosed = false

		window.tabbingMode = .disallowed

		window.title = FileTransfersText("ftw-title")

		window.minSize = NSSize(width: 420, height: 260)

		let hostingController = NSHostingController(rootView: FileTransfersView().environmentObject(model))

		/* The window keeps the size it's given or the user chooses */
		hostingController.sizingOptions = []

		window.contentViewController = hostingController

		window.setContentSize(NSSize(width: 540, height: 380))

		/* Until it has been closed once and its frame is saved */
		window.center()

		model.window = window

		super.init()

		model.reload()
	}

	@objc func reload()
	{
		model.reload()
	}
}

struct FileTransfersView: View
{
	@EnvironmentObject private var model: FileTransfersModel

	/* Clicking a row selects it without giving the list the keyboard
	 (Delete, arrows, Return), so the list takes it */
	@FocusState private var listFocused: Bool

	private var confirmsRemoval: Binding<Bool>
	{
		Binding {
			model.pendingRemoval.isEmpty == false
		} set: { (presented) in
			if (presented == false) {
				model.pendingRemoval = []
			}
		}
	}

	private var removalQuestion: String
	{
		let pending = model.pendingRemoval

		if (pending.count == 1), let transfer = pending.first {
			return FileTransfersText("ftw-remove-q1", transfer.filename)
		}

		return FileTransfersText("ftw-remove-qn", pending.count)
	}

	var body: some View
	{
		VStack(spacing: 0) {
			if model.rows.isEmpty {
				FileTransfersEmptyView()
			} else {
				List(selection: $model.selection) {
					ForEach(model.rows) { (row) in
						FileTransferRowView(row: row)
							.tag(row.id)
					}
				}
				.listStyle(.inset)
				.contextMenu(forSelectionType: String.self) { (identifiers) in
					FileTransfersMenu(rows: model.rows(identifiers))
				} primaryAction: { (identifiers) in
					model.primaryAction(model.rows(identifiers))
				}
				.onDeleteCommand {
					model.remove(model.rows(model.selection))
				}
				.focused($listFocused)
				.onAppear {
					listFocused = true
				}
				.onChange(of: model.selection) { (_, _) in
					listFocused = true
				}
			}

			Divider()

			HStack {
				Button(FileTransfersText("ftw-clear")) {
					model.clearFinished()
				}
				.disabled(model.hasFinished == false)

				Spacer()

				Button(FileTransfersText("ftw-settings")) {
					SettingsWindowController.show(section: "files")
				}
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 10)
		}
		.frame(minWidth: 420, minHeight: 260)
		.onExitCommand {
			model.window?.close()
		}
		.alert(removalQuestion, isPresented: confirmsRemoval) {
			Button(FileTransfersText("ftw-remove-b"), role: .destructive) {
				model.confirmRemoval()
			}

			Button(FileTransfersText("ftw-cancel"), role: .cancel) {
				model.pendingRemoval = []
			}
		} message: {
			Text(FileTransfersText("ftw-remove-h"))
		}
	}
}

struct FileTransfersEmptyView: View
{
	var body: some View
	{
		VStack(spacing: 8) {
			Image(systemName: "arrow.up.arrow.down.circle")
				.font(.system(size: 40, weight: .light))
				.foregroundStyle(.tertiary)
				.accessibilityHidden(true)

			Text(FileTransfersText("ftw-empty"))
				.font(.title3.weight(.semibold))

			Text(FileTransfersText("ftw-empty-h"))
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: 320)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

struct FileTransferRowView: View
{
	let row: FileTransferRow

	@EnvironmentObject private var model: FileTransfersModel

	var body: some View
	{
		HStack(spacing: 10) {
			ZStack(alignment: .bottomTrailing) {
				Image(nsImage: model.icon(for: row.filename))
					.resizable()
					.frame(width: 32, height: 32)

				/* Which way the file goes */
				Image(systemName: (row.isSender ? "arrow.up.circle.fill" : "arrow.down.circle.fill"))
					.font(.system(size: 13, weight: .semibold))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.white, (row.isSender ? Color(nsColor: .systemBlue) : Color(nsColor: .systemGreen)))
					.background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-1))
					.offset(x: 3, y: 3)
			}
			.accessibilityHidden(true)

			VStack(alignment: .leading, spacing: 3) {
				HStack(alignment: .firstTextBaseline) {
					Text(row.filename)
						.lineLimit(1)
						.truncationMode(.middle)

					Spacer(minLength: 6)

					Text(row.size)
						.foregroundStyle(.secondary)
						.monospacedDigit()
				}

				if let progress = row.progress {
					ProgressView(value: progress)
						.controlSize(.small)
				} else if row.isConnecting {
					ProgressView()
						.progressViewStyle(.linear)
						.controlSize(.small)
				}

				Text(row.status)
					.font(.callout)
					.foregroundStyle(row.state.isFailure ? Color(nsColor: .systemRed) : Color.secondary)
					.monospacedDigit()
					.lineLimit(2)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel(Text("\(FileTransfersText(row.isSender ? "ftw-sending" : "ftw-receiving")), \(row.filename), \(row.size), \(row.status)"))

			FileTransferRowButtons(row: row)
		}
		.padding(.vertical, 4)
	}
}

/// The buttons that fit what the transfer is doing
struct FileTransferRowButtons: View
{
	let row: FileTransferRow

	@EnvironmentObject private var model: FileTransfersModel

	var body: some View
	{
		HStack(spacing: 6) {
			switch row.state {
				case .offer:
					Button(FileTransfersText("ftw-accept")) {
						model.start([row])
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)

					iconButton("ftw-decline", "xmark.circle.fill") {
						model.remove([row])
					}
				case .preparing, .waiting, .moving:
					iconButton("ftw-stop", "xmark.circle.fill") {
						model.stop([row])
					}
				case .stopped, .failed:
					iconButton("ftw-retry", "arrow.clockwise.circle.fill") {
						model.start([row])
					}
				case .failedForGood:
					iconButton("ftw-remove", "xmark.circle.fill") {
						model.remove([row])
					}
				case .done:
					iconButton("ftw-reveal", "magnifyingglass.circle.fill") {
						model.reveal([row])
					}
			}
		}
	}

	private func iconButton(_ key: String, _ symbol: String, action: @escaping () -> Void) -> some View
	{
		Button(action: action) {
			Label(FileTransfersText(key), systemImage: symbol)
				.labelStyle(.iconOnly)
				.font(.title2)
				.foregroundStyle(.secondary)
		}
		.buttonStyle(.borderless)
		.help(FileTransfersText(key))
	}
}

/// The right-click menu, for one transfer or all selected
struct FileTransfersMenu: View
{
	let rows: [FileTransferRow]

	@EnvironmentObject private var model: FileTransfersModel

	var body: some View
	{
		if rows.isEmpty == false {
			let offers = rows.filter { $0.state == .offer }
			let retries = rows.filter(\.state.canRetry)
			let running = rows.filter(\.state.canStop)
			let openable = rows.filter(\.canOpen)
			let revealable = rows.filter(\.canReveal)

			if offers.isEmpty == false {
				Button(FileTransfersText("ftw-accept")) {
					model.start(offers)
				}
			}

			if retries.isEmpty == false {
				Button(FileTransfersText("ftw-retry")) {
					model.start(retries)
				}
			}

			if running.isEmpty == false {
				Button(FileTransfersText("ftw-stop")) {
					model.stop(running)
				}
			}

			if (openable.isEmpty == false || revealable.isEmpty == false) {
				Divider()
			}

			if openable.isEmpty == false {
				Button(FileTransfersText("ftw-open")) {
					model.open(openable)
				}
			}

			if revealable.isEmpty == false {
				Button(FileTransfersText("ftw-reveal")) {
					model.reveal(revealable)
				}
			}

			Divider()

			Button(FileTransfersText("ftw-remove")) {
				model.remove(rows)
			}
		}
	}
}
