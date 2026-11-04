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

/* Bringing over Textual 7 or an earlier version, in the setup window: asking
 macOS for access to its folders, copying (TPCLegacyImport does the work) and
 what came over. File > Import Settings from Textual 7… shows the same steps. */

/// A string of the import (Prompts.strings)
func ImportText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("Prompts[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Model

enum ImportStage
{
	case access
	case nothingToImport
	case copying
	case license
	case summary
}

struct ImportProgressRow: Identifiable
{
	let id: String
	let title: String
	var finished = false
	var done = false
	var detail = ""
}

/// Something that didn't simply come over, with a button where Textual can help
struct ImportNote: Identifiable
{
	enum Action
	{
		case saveKeys
		case showScripts
	}

	let id = UUID()
	let symbol: String
	let color: Color
	let text: String
	var action: Action?
}

final class ImportModel: NSObject, ObservableObject, NSOpenSavePanelDelegate
{
	let fromMenu: Bool

	@Published private(set) var sources: [TPCLegacyImportSource]
	@Published var source: TPCLegacyImportSource
	@Published private(set) var earlierVersionIsRunning = TPCLegacyImport.earlierVersionIsRunning

	@Published private(set) var stage = ImportStage.access
	@Published private(set) var grantingPreferencesFile = false
	@Published private(set) var accessProblem: String?
	@Published private(set) var progressRows: [ImportProgressRow] = []
	@Published private(set) var imported: [String] = []
	@Published private(set) var notes: [ImportNote] = []
	@Published private(set) var savedKeys = false

	/* The window for the panels, and what to do once access was refused or it's all done */
	weak var window: NSWindow?
	var showStage: (() -> Void)?
	var finished: (() -> Void)?

	private var importer: TPCLegacyImport?
	private var groupURL: URL?
	private var preferencesURL: URL?
	private var panelItemURL: URL?

	/* Copying can't be stopped halfway */
	var isCopying: Bool
	{
		(stage == .copying)
	}

	var replacesServers: Bool
	{
		TPCLegacyImport.hasServers
	}

	init?(fromMenu: Bool)
	{
		let sources = TPCLegacyImport.availableSources

		guard let source = sources.first else {
			return nil
		}

		self.fromMenu = fromMenu
		self.sources = sources
		self.source = source

		super.init()
	}

	func checkEarlierVersion()
	{
		let running = TPCLegacyImport.earlierVersionIsRunning

		if (running != earlierVersionIsRunning) {
			earlierVersionIsRunning = running
		}
	}

	func description(of source: TPCLegacyImportSource, capitalized: Bool) -> String
	{
		var name = source.displayName

		if (capitalized) {
			name = (name.prefix(1).uppercased() + name.dropFirst())
		}

		guard let lastUsed = source.lastUsedDate else {
			return name
		}

		let formatter = RelativeDateTimeFormatter()

		formatter.unitsStyle = .full

		return ImportText("orc-1q", name, formatter.localizedString(for: lastUsed, relativeTo: Date()))
	}

	// MARK: Access

	/// Import: a folder granted before needs no panel
	func begin()
	{
		importer = TPCLegacyImport(source: source)
		accessProblem = nil
		grantingPreferencesFile = false

		if let rememberedURL = TPCLegacyImport.rememberedURL(forFolder: source.groupURL) {
			use(groupURL: rememberedURL)

			return
		}

		stage = .access
	}

	func requestAccess()
	{
		if (grantingPreferencesFile) {
			guard let fileURL = source.outsidePreferencesURL else {
				return
			}

			openPanel(selecting: fileURL, isFolder: false, message: ImportText("fh6-zg", source.displayName)) { [weak self] url in
				self?.preferencesURL = url

				self?.readPreferences()
			}

			return
		}

		openPanel(selecting: source.groupURL, isFolder: true, message: ImportText("qsc-uk", source.displayName)) { [weak self] url in
			TPCLegacyImport.rememberGrantedURL(url)

			self?.use(groupURL: url)
		}
	}

	/// Leaving the access step: nothing was imported
	func stopUsingGroupFolder()
	{
		groupURL?.stopAccessingSecurityScopedResource()

		groupURL = nil

		accessProblem = nil
		grantingPreferencesFile = false
	}

	/* macOS only lets Textual read another app's files once the user picked
	 them in an open panel, so the panel opens with the item selected: one click
	 on Grant Access. Everything else is greyed out, and choosing anything else
	 explains itself and keeps the panel open. (The panel runs outside the app,
	 so it can't be moved back to the item once it is open.) */
	private func openPanel(selecting itemURL: URL, isFolder: Bool, message: String, completion: @escaping (URL) -> Void)
	{
		guard let window = window else {
			return
		}

		let panel = NSOpenPanel()

		panel.canChooseDirectories = isFolder
		panel.canChooseFiles = (isFolder == false)
		panel.allowsMultipleSelection = false
		panel.canCreateDirectories = false
		panel.directoryURL = itemURL
		panel.message = message
		panel.prompt = ImportText("5wl-b5")
		panel.delegate = self

		panelItemURL = itemURL

		panel.beginSheetModal(for: window) { response in
			if response == .OK, let url = panel.url {
				completion(url)
			}
		}
	}

	func panel(_ sender: Any, shouldEnable url: URL) -> Bool
	{
		guard let itemPath = panelItemURL?.standardizedFileURL.path else {
			return true
		}

		let path = url.standardizedFileURL.path

		/* The item and the folders leading to it */
		return (path == itemPath || itemPath.hasPrefix(path + "/"))
	}

	func panel(_ sender: Any, validate url: URL) throws
	{
		guard let itemURL = panelItemURL, url.standardizedFileURL.path != itemURL.standardizedFileURL.path else {
			return
		}

		/* Not NSUserCancelledError: the panel doesn't show those */
		throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [
			NSLocalizedDescriptionKey: ImportText("mzr-ak", itemURL.lastPathComponent),
			NSLocalizedRecoverySuggestionErrorKey: ImportText("wux-a5")
		])
	}

	private func use(groupURL url: URL)
	{
		groupURL = url

		_ = url.startAccessingSecurityScopedResource()

		/* Before the sandbox, the preferences were outside the folder */
		if (source.outsidePreferencesURL != nil) {
			grantingPreferencesFile = true
			accessProblem = nil
			stage = .access

			return
		}

		preferencesURL = importer?.preferencesURL(inGroupURL: url)

		readPreferences()
	}

	private func readPreferences()
	{
		guard let importer = importer, let preferencesURL = preferencesURL else {
			return
		}

		let outside = (source.outsidePreferencesURL != nil)

		if (outside) {
			_ = preferencesURL.startAccessingSecurityScopedResource()
		}

		let error = importer.readPreferences(at: preferencesURL)

		if (outside) {
			preferencesURL.stopAccessingSecurityScopedResource()
		}

		switch error {
			case .unreadable:
				accessProblem = ImportText("ndc-ll")
				stage = .access
			case .empty:
				stage = .nothingToImport
			default:
				startCopying()
		}
	}

	// MARK: Copying

	private func startCopying()
	{
		guard let importer = importer, let groupURL = groupURL else {
			return
		}

		progressRows = [
			ImportProgressRow(id: "servers", title: ImportText("26f-4z")),
			ImportProgressRow(id: "styles", title: ImportText("x3o-dm")),
			ImportProgressRow(id: "extensions", title: ImportText("d2h-gn")),
			ImportProgressRow(id: "scrollback", title: ImportText("abx-17")),
			ImportProgressRow(id: "preferences", title: ImportText("f6m-6o"))
		]

		stage = .copying

		let none = ImportText("ass-fu")

		func countDetail(_ count: Int) -> String
		{
			(count == 0) ? none : ImportText("zos-f9", UInt(count))
		}

		/* The copies run in the background; each row ticks off as its part
		 finishes, with a short pause so the steps can be followed */
		func step(_ work: () -> Void, _ done: () -> Void)
		{
			work()

			Thread.sleep(forTimeInterval: 0.35)

			DispatchQueue.main.sync(execute: done)
		}

		DispatchQueue.global(qos: .userInitiated).async {
			step({}, {
				self.finishRow("servers", detail: ImportText("u7y-7m", UInt(importer.serverCount)), done: true)
			})

			step({
				importer.importStyles(fromGroupURL: groupURL)
			}, {
				let count = importer.result.styles.count

				self.finishRow("styles", detail: countDetail(count), done: (count > 0))
			})

			step({
				importer.importExtensions(fromGroupURL: groupURL)
			}, {
				let count = importer.result.extensions.count

				self.finishRow("extensions", detail: countDetail(count), done: (count > 0))
			})

			step({
				importer.importScrollback(fromGroupURL: groupURL)
				importer.noteOtherContent(ofGroupURL: groupURL)
			}, {
				let done = importer.result.importedScrollback

				self.finishRow("scrollback", detail: (done ? "" : none), done: done)
			})

			/* Preferences last and on the main thread: they replace this copy's
			 settings, and the user interface may observe them */
			step({}, {
				importer.importPreferences()

				self.finishRow("preferences", detail: "", done: true)
			})

			Thread.sleep(forTimeInterval: 0.4)

			DispatchQueue.main.async {
				groupURL.stopAccessingSecurityScopedResource()

				if (self.source.licenseFolderURL != nil) {
					self.stage = .license
				} else {
					self.showSummary()
				}
			}
		}
	}

	private func finishRow(_ id: String, detail: String, done: Bool)
	{
		guard let index = progressRows.firstIndex(where: { $0.id == id }) else {
			return
		}

		progressRows[index].finished = true
		progressRows[index].done = done
		progressRows[index].detail = detail
	}

	// MARK: License

	func requestLicenseAccess()
	{
		guard let folderURL = source.licenseFolderURL else {
			showSummary()

			return
		}

		if let rememberedURL = TPCLegacyImport.rememberedURL(forFolder: folderURL) {
			importLicense(from: rememberedURL)

			return
		}

		openPanel(selecting: folderURL, isFolder: true, message: ImportText("4l1-08")) { [weak self] url in
			TPCLegacyImport.rememberGrantedURL(url)

			self?.importLicense(from: url)
		}
	}

	private func importLicense(from folderURL: URL)
	{
		_ = folderURL.startAccessingSecurityScopedResource()

		importer?.importLicense(fromFolderURL: folderURL)

		folderURL.stopAccessingSecurityScopedResource()

		showSummary()
	}

	func skipLicense()
	{
		showSummary()
	}

	// MARK: Summary

	private func showSummary()
	{
		guard let result = importer?.result else {
			return
		}

		let name = source.displayName

		var imported = [ImportText("r0h-rs", UInt(result.serverCount))]

		if (result.styles.isEmpty == false) {
			imported.append(ImportText("k7h-z8", result.styles.joined(separator: ", ")))
		}

		if (result.extensions.isEmpty == false) {
			imported.append(ImportText("iy3-3h", result.extensions.joined(separator: ", ")))
		}

		if (result.importedScrollback) {
			imported.append(ImportText("r6r-r0"))
		}

		if (result.importedLicense) {
			imported.append(ImportText("pxp-p6"))
		}

		var notes: [ImportNote] = []

		if (result.triedLicense && result.importedLicense == false) {
			notes.append(ImportNote(symbol: "key", color: .orange, text: ImportText("3jr-s5")))
		}

		/* The message archive: on for them too, so they hear of it once */
		if (TPCPreferences.messageArchiveKeepPeriod != .off) {
			notes.append(ImportNote(symbol: "magnifyingglass", color: .secondary, text: ImportText("arc-i1")))
		}

		if (result.encryptionComponentsURL != nil) {
			notes.append(ImportNote(symbol: "lock.doc", color: .orange, text: ImportText("3po-7m"), action: .saveKeys))
		}

		if (result.scriptsURL != nil) {
			notes.append(ImportNote(symbol: "applescript", color: .orange, text: ImportText("fk1-ci", name), action: .showScripts))
		}

		if (result.hadTranscriptFolder) {
			notes.append(ImportNote(symbol: "folder", color: .secondary, text: ImportText("2zf-mn")))
		}

		if (result.hadDownloadFolder) {
			notes.append(ImportNote(symbol: "arrow.down.to.line", color: .secondary, text: ImportText("voq-wj")))
		}

		if (result.inlineMediaModules.isEmpty == false) {
			notes.append(ImportNote(symbol: "photo", color: .secondary, text: ImportText("pjp-bp", result.inlineMediaModules.joined(separator: ", "))))
		}

		if (result.keptItems.isEmpty == false) {
			notes.append(ImportNote(symbol: "square.on.square", color: .orange, text: ImportText("k7t-r3", name, result.keptItems.joined(separator: ", "))))
		}

		if (result.failureCount > 0) {
			notes.append(ImportNote(symbol: "exclamationmark.triangle", color: .orange, text: ImportText("to7-nt", UInt(result.failureCount))))
		}

		self.imported = imported
		self.notes = notes

		/* File > Remove Textual 7 Data… is only offered once everything is safely here */
		if (result.failureCount == 0 && result.keptItems.isEmpty) {
			TPCLegacyImport.noteImportedCompletely(from: source)
		} else {
			TPCLegacyImport.clearCompleteNote()
		}

		stage = .summary
	}

	func perform(_ action: ImportNote.Action)
	{
		switch action {
			case .saveKeys: saveKeys()
			case .showScripts: showScripts()
		}
	}

	private func saveKeys()
	{
		guard let window = window, let importer = importer, let groupURL = groupURL else {
			return
		}

		let panel = NSOpenPanel()

		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.message = ImportText("mqc-bj")
		panel.prompt = ImportText("iud-uj")

		panel.beginSheetModal(for: window) { [weak self] response in
			guard response == .OK, let url = panel.url else {
				return
			}

			if (importer.saveEncryptionComponents(toFolderURL: url, groupURL: groupURL)) {
				self?.savedKeys = true
			}
		}
	}

	/* Finder only opens another app's folder for Textual once the user granted
	 access to it */
	private func showScripts()
	{
		guard let scriptsURL = importer?.result.scriptsURL else {
			return
		}

		func show(_ grantedURL: URL)
		{
			_ = grantedURL.startAccessingSecurityScopedResource()

			NSWorkspace.shared.open(grantedURL)

			grantedURL.stopAccessingSecurityScopedResource()

			if let newScriptsURL = try? FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
				NSWorkspace.shared.open(newScriptsURL)
			}
		}

		if let rememberedURL = TPCLegacyImport.rememberedURL(forFolder: scriptsURL) {
			show(rememberedURL)

			return
		}

		openPanel(selecting: scriptsURL, isFolder: true, message: ImportText("q3o-j2")) { url in
			TPCLegacyImport.rememberGrantedURL(url)

			show(url)
		}
	}
}

// MARK: - Views

/// A symbol and a line of text
struct SetupSymbolRow: View
{
	let symbol: String
	let color: Color
	let text: String

	var body: some View
	{
		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Image(systemName: symbol)
				.foregroundStyle(color)
				.frame(width: 20)
				.accessibilityHidden(true)

			Text(text)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

struct SetupImportWelcomeStep: View
{
	@ObservedObject var model: ImportModel

	var body: some View
	{
		VStack(spacing: 14) {
			SetupHeader(title: (model.fromMenu ? ImportText("r7d-m2") : ImportText("nzb-35")),
						lead: (model.fromMenu ? ImportText("x5p-v9", model.source.displayName) : ImportText("3y5-mz", model.source.displayName))) {
				SetupAppIcon()
			}

			SetupGroup {
				VStack(alignment: .leading, spacing: 7) {
					SetupSymbolRow(symbol: "checkmark.circle.fill", color: .green, text: ImportText("f5o-br"))
					SetupSymbolRow(symbol: "checkmark.circle.fill", color: .green, text: ImportText("704-yh"))
					SetupSymbolRow(symbol: "checkmark.circle.fill", color: .green, text: ImportText("qge-yy"))
					SetupSymbolRow(symbol: "checkmark.circle.fill", color: .green, text: ImportText("gdv-pf"))

					if (model.source.licenseFolderURL != nil) {
						SetupSymbolRow(symbol: "checkmark.circle.fill", color: .green, text: ImportText("57n-je"))
					}
				}
				.padding(12)
			}
			.frame(maxWidth: 460)

			VStack(alignment: .leading, spacing: 8) {
				if (model.sources.count > 1) {
					Text(ImportText("8c5-mj"))
						.foregroundStyle(.secondary)

					Picker("", selection: $model.source) {
						ForEach(model.sources, id: \.self) { source in
							Text(model.description(of: source, capitalized: true))
								.tag(source)
						}
					}
					.pickerStyle(.radioGroup)
					.labelsHidden()
				} else {
					SetupSymbolRow(symbol: "magnifyingglass", color: .secondary, text: ImportText("32s-9w", model.description(of: model.source, capitalized: false)))
				}

				if (model.replacesServers) {
					SetupSymbolRow(symbol: "exclamationmark.triangle.fill", color: .orange, text: ImportText("1ik-g8"))
				} else {
					SetupSymbolRow(symbol: "lock.fill", color: .secondary, text: ImportText("uw5-6m", model.source.displayName))
				}

				if (model.earlierVersionIsRunning) {
					SetupSymbolRow(symbol: "xmark.octagon.fill", color: .red, text: ImportText("tjw-7s"))
				}
			}
			.frame(maxWidth: 460)
		}
		.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
			model.checkEarlierVersion()
		}
	}
}

struct SetupImportStep: View
{
	@ObservedObject var model: ImportModel

	var body: some View
	{
		switch model.stage {
			case .access: access
			case .nothingToImport: nothingToImport
			case .copying: copying
			case .license: license
			case .summary: summary
		}
	}

	private var access: some View
	{
		VStack(spacing: 14) {
			if (model.grantingPreferencesFile) {
				SetupHeader(title: ImportText("yt0-lz"), lead: ImportText("hkb-mk", model.source.displayName)) {
					SetupSymbol(symbol: "doc.badge.gearshape.fill", color: .blue)
				}
			} else {
				SetupHeader(title: ImportText("tha-yv"), lead: ImportText("k1o-i0", model.source.displayName)) {
					SetupSymbol(symbol: "lock.shield.fill", color: .blue)
				}
			}

			accessSteps

			if let problem = model.accessProblem {
				SetupSymbolRow(symbol: "exclamationmark.triangle.fill", color: .orange, text: problem)
					.frame(maxWidth: 460)
			}
		}
	}

	private var accessSteps: some View
	{
		SetupGroup {
			VStack(alignment: .leading, spacing: 7) {
				SetupSymbolRow(symbol: "1.circle.fill", color: .accentColor, text: ImportText("200-fe"))
				SetupSymbolRow(symbol: "2.circle.fill", color: .accentColor, text: ImportText("sgc-fg"))
				SetupSymbolRow(symbol: "eye.fill", color: .secondary, text: ImportText("77x-j6"))
			}
			.padding(12)
		}
		.frame(maxWidth: 460)
	}

	private var nothingToImport: some View
	{
		SetupHeader(title: ImportText("q8n-t4"), lead: ImportText("v12-hf", model.source.displayName)) {
			SetupSymbol(symbol: "tray.fill", color: .gray)
		}
	}

	private var copying: some View
	{
		VStack(spacing: 14) {
			SetupHeader(title: ImportText("mo5-4j"), lead: ImportText("yhg-2i", model.source.displayName)) {
				SetupSymbol(symbol: "arrow.down", color: .blue)
			}

			SetupGroup {
				VStack(alignment: .leading, spacing: 10) {
					ForEach(model.progressRows) { row in
						HStack(spacing: 8) {
							Group {
								if (row.finished == false) {
									ProgressView()
										.controlSize(.small)
								} else if (row.done) {
									Image(systemName: "checkmark.circle.fill")
										.foregroundStyle(.green)
								} else {
									Image(systemName: "minus.circle")
										.foregroundStyle(.tertiary)
								}
							}
							.frame(width: 20)

							Text(row.title)

							Spacer()

							Text(row.detail)
								.foregroundStyle(.secondary)
						}
						.accessibilityElement(children: .combine)
					}
				}
				.padding(12)
			}
			.frame(maxWidth: 460)
		}
	}

	private var license: some View
	{
		VStack(spacing: 14) {
			SetupHeader(title: ImportText("0xu-7t"), lead: ImportText("wsg-m5", model.source.displayName)) {
				SetupSymbol(symbol: "key.fill", color: .yellow)
			}

			SetupGroup {
				VStack(alignment: .leading, spacing: 7) {
					SetupSymbolRow(symbol: "1.circle.fill", color: .accentColor, text: ImportText("200-fe"))
					SetupSymbolRow(symbol: "2.circle.fill", color: .accentColor, text: ImportText("sgc-fg"))
				}
				.padding(12)
			}
			.frame(maxWidth: 460)
		}
	}

	private var summary: some View
	{
		VStack(spacing: 12) {
			SetupHeader(title: ImportText("zy7-wx"),
						lead: (model.fromMenu ? ImportText("1m5-76", model.source.displayName) : ImportText("frk-e5", model.source.displayName))) {
				SetupSymbol(symbol: "checkmark", color: .green)
			}

			SetupGroup {
				VStack(alignment: .leading, spacing: 7) {
					ForEach(model.imported, id: \.self) { line in
						SetupSymbolRow(symbol: "checkmark.circle.fill", color: .green, text: line)
					}
				}
				.padding(12)
			}

			if (model.notes.isEmpty == false) {
				SetupGroup {
					VStack(alignment: .leading, spacing: 8) {
						Text(ImportText("bmq-fg"))
							.fontWeight(.semibold)

						ForEach(model.notes) { note in
							HStack(alignment: .firstTextBaseline, spacing: 8) {
								SetupSymbolRow(symbol: note.symbol, color: note.color, text: note.text)

								if let action = note.action {
									noteButton(action)
								}
							}
						}
					}
					.padding(12)
				}
			}
		}
	}

	@ViewBuilder
	private func noteButton(_ action: ImportNote.Action) -> some View
	{
		switch action {
			case .saveKeys:
				Button(model.savedKeys ? ImportText("uos-wu") : ImportText("x5g-hy")) {
					model.perform(.saveKeys)
				}
				.disabled(model.savedKeys)
				.controlSize(.small)
			case .showScripts:
				Button(ImportText("gt5-wm")) {
					model.perform(.showScripts)
				}
				.controlSize(.small)
		}
	}
}

// MARK: - Removing the earlier version's data

/// File > Remove Textual 7 Data…: after a complete import, once the user chooses to
enum ImportRemoval
{
	static func run()
	{
		guard let source = TPCLegacyImport.sourceImportedCompletely else {
			return
		}

		if (TPCLegacyImport.earlierVersionIsRunning) {
			TDCAlert.modalAlert(withMessage: ImportText("tjw-7s"), title: ImportText("e7h-w1", source.displayName), defaultButton: ImportText("oxy-im"), alternateButton: nil)

			return
		}

		guard let groupURL = (TPCLegacyImport.rememberedURL(forFolder: source.groupURL) ?? askForFolder(of: source)) else {
			return
		}

		let importer = TPCLegacyImport(source: source)

		_ = groupURL.startAccessingSecurityScopedResource()

		defer {
			groupURL.stopAccessingSecurityScopedResource()
		}

		importer.noteOtherContent(ofGroupURL: groupURL)

		let hasKeys = (importer.result.encryptionComponentsURL != nil)

		let alert = NSAlert()

		alert.alertStyle = .warning
		alert.messageText = ImportText("e7h-w1", source.displayName)
		alert.informativeText = ImportText("19s-28", source.displayName)

		/* The OTR keys are in the folder that is deleted */
		if (hasKeys) {
			alert.informativeText += ("\n\n" + ImportText("k7t-r2"))
		}

		alert.addButton(withTitle: ImportText("fbm-cu"))
		alert.addButton(withTitle: ImportText("hqr-xy")).hasDestructiveAction = true

		if (hasKeys) {
			alert.addButton(withTitle: ImportText("x5g-hy"))
		}

		var response = alert.runModal()

		if (response == .alertThirdButtonReturn) {
			saveKeys(of: importer, groupURL: groupURL)

			alert.buttons.last?.isHidden = true

			response = alert.runModal()
		}

		guard response == .alertSecondButtonReturn else {
			return
		}

		importer.deleteEarlierData(inGroupURL: groupURL)

		TPCLegacyImport.clearCompleteNote()
	}

	private static func askForFolder(of source: TPCLegacyImportSource) -> URL?
	{
		let delegate = ImportPanelDelegate(itemURL: source.groupURL)

		let panel = NSOpenPanel()

		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.canCreateDirectories = false
		panel.directoryURL = source.groupURL
		panel.message = ImportText("qsc-uk", source.displayName)
		panel.prompt = ImportText("5wl-b5")
		panel.delegate = delegate

		guard panel.runModal() == .OK, let url = panel.url else {
			return nil
		}

		TPCLegacyImport.rememberGrantedURL(url)

		return url
	}

	private static func saveKeys(of importer: TPCLegacyImport, groupURL: URL)
	{
		let panel = NSOpenPanel()

		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.message = ImportText("mqc-bj")
		panel.prompt = ImportText("iud-uj")

		if panel.runModal() == .OK, let url = panel.url {
			_ = importer.saveEncryptionComponents(toFolderURL: url, groupURL: groupURL)
		}
	}
}

/// Only the folder Textual needs can be chosen
private final class ImportPanelDelegate: NSObject, NSOpenSavePanelDelegate
{
	private let itemPath: String

	init(itemURL: URL)
	{
		itemPath = itemURL.standardizedFileURL.path
	}

	func panel(_ sender: Any, shouldEnable url: URL) -> Bool
	{
		let path = url.standardizedFileURL.path

		return (path == itemPath || itemPath.hasPrefix(path + "/"))
	}
}
