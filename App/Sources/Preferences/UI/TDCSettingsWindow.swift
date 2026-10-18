/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
* Copyright (c) 2018 - 2020 Codeux Software, LLC & respective contributors.
*       Please see Acknowledgements.pdf for additional information.
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

/* The Settings window (12.11): a sidebar of sections with a search field, and
 each section one page of grouped rows (a grouped Form, like System Settings).
 Settings are read from and written to Textual's preferences directly; what
 depends on a key is updated through TDCSettingsBridge. Sections not rebuilt
 yet open their pane of the old Preferences window. */

/// A string of the Settings window (TDCPreferencesController.strings)
func SettingsText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCPreferencesController[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Sections

enum SettingsSection: String, CaseIterable, Identifiable
{
	case general, appearance, messages, typing, notifications, highlights, previews, history
	case lists, files, servers, commands, extensions, advanced

	var id: String { rawValue }

	var title: String { SettingsText("set-s-\(rawValue)") }

	/// One line under the title of the page
	var lead: String { SettingsText("set-l-\(rawValue)") }

	/// Words the search field finds the section by, besides its title
	var keywords: String { SettingsText("set-k-\(rawValue)") }

	var symbol: String
	{
		switch self {
			case .general: return "gearshape.fill"
			case .appearance: return "paintbrush.fill"
			case .messages: return "text.bubble.fill"
			case .typing: return "keyboard.fill"
			case .notifications: return "bell.badge.fill"
			case .highlights: return "at"
			case .previews: return "photo.on.rectangle.angled"
			case .history: return "clock.fill"
			case .lists: return "sidebar.left"
			case .files: return "folder.fill"
			case .servers: return "network"
			case .commands: return "command"
			case .extensions: return "puzzlepiece.extension.fill"
			case .advanced: return "wrench.and.screwdriver.fill"
		}
	}

	var color: Color
	{
		switch self {
			case .general, .typing: return Color(nsColor: .systemGray)
			case .appearance: return Color(nsColor: .systemIndigo)
			case .messages: return Color(nsColor: .systemTeal)
			case .notifications: return Color(nsColor: .systemRed)
			case .highlights: return Color(nsColor: .systemOrange)
			case .previews: return Color(nsColor: .systemGreen)
			case .history, .servers: return Color(nsColor: .systemBlue)
			case .lists: return Color(nsColor: .systemPurple)
			case .files: return Color(nsColor: .systemCyan)
			case .commands, .advanced: return Color(nsColor: .darkGray)
			case .extensions: return Color(nsColor: .systemPink)
		}
	}

	/// Sections are shown in groups, with room between them, as System Settings does
	static let groups: [[SettingsSection]] = [
		[.general],
		[.appearance, .messages, .lists], // how Textual looks
		[.typing, .notifications, .highlights], // talking, and what gets your attention
		[.previews, .files, .history], // what comes in, and what is kept
		[.servers, .commands], // IRC itself
		[.extensions, .advanced]
	]

	func matches(_ query: String) -> Bool
	{
		let query = query.trimmingCharacters(in: .whitespaces).lowercased()

		if (query.isEmpty) {
			return true
		}

		return (title.lowercased().contains(query) || keywords.lowercased().contains(query))
	}
}

// MARK: - Window

final class SettingsModel: ObservableObject
{
	@Published var selection: SettingsSection? = .general
	@Published var query = ""

	weak var window: NSWindow?
}

@objc(TDCSettingsWindowController)
final class SettingsWindowController: NSWindowController, NSWindowDelegate
{
	private static var shared: SettingsWindowController?

	let model = SettingsModel()

	@objc(showSection:)
	static func show(section: String?)
	{
		let controller = (shared ?? SettingsWindowController())

		shared = controller

		if let section = section, let found = SettingsSection(rawValue: section) {
			controller.model.query = ""
			controller.model.selection = found
		}

		controller.showWindow(nil)

		controller.window?.makeKeyAndOrderFront(nil)

		/* The sections have the focus, not the search field (the window's first
		 control), so the selected one shows in the accent color */
		DispatchQueue.main.asyncAfter(deadline: (.now() + 0.15)) {
			guard let window = controller.window, let list = Self.sectionList(in: window.contentView) else {
				return
			}

			window.makeFirstResponder(list)
		}
	}

	private static func sectionList(in view: NSView?) -> NSTableView?
	{
		guard let view = view else {
			return nil
		}

		if let table = view as? NSTableView {
			return table
		}

		for subview in view.subviews {
			if let table = sectionList(in: subview) {
				return table
			}
		}

		return nil
	}

	init()
	{
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
							  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
							  backing: .buffered,
							  defer: true)

		window.title = SettingsText("set-title")
		window.titleVisibility = .hidden
		window.toolbarStyle = .unified
		window.tabbingMode = .disallowed
		window.isReleasedWhenClosed = false
		window.contentMinSize = NSSize(width: 700, height: 460)

		super.init(window: window)

		let hostingController = NSHostingController(rootView: SettingsRootView(model: model))

		hostingController.sceneBridgingOptions = [.toolbars, .title]

		window.contentViewController = hostingController
		window.toolbar = NSToolbar(identifier: "Settings")

		window.setContentSize(NSSize(width: 860, height: 680))

		if (window.setFrameUsingName("Settings") == false) {
			window.center()
		}

		window.setFrameAutosaveName("Settings")

		window.delegate = self

		model.window = window
	}

	required init?(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}

	func windowWillClose(_ notification: Notification)
	{
		TDCSettingsBridge.settingsWindowWillClose()
	}
}

// MARK: - Root

struct SettingsRootView: View
{
	@ObservedObject var model: SettingsModel

	private var visibleSections: [SettingsSection]
	{
		SettingsSection.groups.joined().filter { $0.matches(model.query) }
	}

	var body: some View
	{
		NavigationSplitView {
			VStack(spacing: 0) {
				SettingsSearchField(text: $model.query, prompt: SettingsText("set-search"))
					.padding(.horizontal, 10)
					.padding(.top, 2)
					.padding(.bottom, 16)

				List(selection: $model.selection) {
					ForEach(Array(SettingsSection.groups.enumerated()), id: \.offset) { (_, group) in
						let sections = group.filter { $0.matches(model.query) }

						if (sections.isEmpty == false) {
							Section {
								ForEach(sections) { section in
									SettingsSectionLabel(section: section)
										.tag(section)
								}
							}
						}
					}
				}
				.listStyle(.sidebar)
			}
			.frame(minWidth: 230)
			.navigationSplitViewColumnWidth(min: 230, ideal: 230, max: 320)
			.toolbar(removing: .sidebarToggle)
		} detail: {
			NavigationStack {
				if let section = model.selection {
					SettingsPage(section: section)
						.id(section)
				}
			}
		}
		.environmentObject(model)
		.onChange(of: model.query) { _, _ in
			/* The first section that matches, as System Settings does */
			let sections = visibleSections

			if let selection = model.selection, sections.contains(selection) {
				return
			}

			model.selection = sections.first
		}
	}
}

/// The search field above the sections: the system's, so it looks like one
struct SettingsSearchField: NSViewRepresentable
{
	@Binding var text: String
	let prompt: String

	func makeNSView(context: Context) -> NSSearchField
	{
		let field = NSSearchField()

		field.placeholderString = prompt
		field.delegate = context.coordinator
		field.sendsSearchStringImmediately = true

		return field
	}

	func updateNSView(_ field: NSSearchField, context: Context)
	{
		if (field.stringValue != text) {
			field.stringValue = text
		}
	}

	func makeCoordinator() -> Coordinator
	{
		Coordinator(text: $text)
	}

	final class Coordinator: NSObject, NSSearchFieldDelegate
	{
		var text: Binding<String>

		init(text: Binding<String>)
		{
			self.text = text
		}

		func controlTextDidChange(_ notification: Notification)
		{
			guard let field = notification.object as? NSSearchField else {
				return
			}

			text.wrappedValue = field.stringValue
		}
	}
}

struct SettingsSectionIcon: View
{
	let section: SettingsSection
	var size: CGFloat = 20

	var body: some View
	{
		Image(systemName: section.symbol)
			.font(.system(size: (size * 0.55), weight: .semibold))
			.foregroundStyle(.white)
			.frame(width: size, height: size)
			.background(RoundedRectangle(cornerRadius: (size * 0.25), style: .continuous).fill(section.color.gradient))
	}
}

struct SettingsSectionLabel: View
{
	let section: SettingsSection

	var body: some View
	{
		Label {
			Text(section.title)
		} icon: {
			SettingsSectionIcon(section: section)
		}
	}
}

// MARK: - Pages

struct SettingsPage: View
{
	let section: SettingsSection

	var body: some View
	{
		Group {
			switch section {
				case .general: GeneralSettings()
				case .lists: ListsSettings()
				case .servers: ServersSettings()
				case .commands: CommandsSettings()
				case .files: FilesSettings()
				case .extensions: ExtensionsSettings()
				case .advanced: AdvancedSettings()
				default: LegacySettings(section: section)
			}
		}
		.formStyle(.grouped)
		.navigationTitle(section.title)
	}
}

/// The top of a page: its icon, title and what it covers, centered
struct SettingsPageHeader: View
{
	let section: SettingsSection

	var body: some View
	{
		VStack(spacing: 6) {
			SettingsSectionIcon(section: section, size: 48)
				.padding(.bottom, 4)

			Text(section.title)
				.font(.title.weight(.semibold))

			Text(section.lead)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 10)
	}
}

// MARK: - Rows

/// A setting's name with an explanation under it
struct SettingLabel: View
{
	let title: String
	var help: String? = nil

	var body: some View
	{
		VStack(alignment: .leading, spacing: 2) {
			Text(title)

			if let help = help {
				Text(help)
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
}

struct SettingToggle: View
{
	let title: String
	var help: String? = nil
	let isOn: Binding<Bool>

	var body: some View
	{
		Toggle(isOn: isOn) {
			SettingLabel(title: title, help: help)
		}
	}
}

// MARK: - Preferences

/// Textual's preferences as bindings. A change updates what depends on the key
/// (TPCPreferences' reload actions); changes made elsewhere redraw the page.
final class SettingsStore: ObservableObject
{
	static let shared = SettingsStore()

	private let defaults = TPCPreferencesUserDefaults.shared()

	private var observer: NSObjectProtocol?

	private init()
	{
		observer = NotificationCenter.default.addObserver(forName: .TPCPreferencesUserDefaultsDidChange, object: nil, queue: .main) { [weak self] _ in
			self?.objectWillChange.send()
		}
	}

	private func store(_ value: Any?, forKey key: String)
	{
		objectWillChange.send()

		defaults.set(value, forKey: key)

		TDCSettingsBridge.preferenceChanged(forKey: key)
	}

	func bool(_ key: String, then action: (() -> Void)? = nil) -> Binding<Bool>
	{
		Binding(get: { self.defaults.bool(forKey: key) },
				set: { self.store($0, forKey: key); action?() })
	}

	func integer(_ key: String) -> Binding<Int>
	{
		Binding(get: { self.defaults.integer(forKey: key) },
				set: { self.store($0, forKey: key) })
	}

	func double(_ key: String) -> Binding<Double>
	{
		Binding(get: { self.defaults.double(forKey: key) },
				set: { self.store($0, forKey: key) })
	}

	func string(_ key: String) -> Binding<String>
	{
		Binding(get: { (self.defaults.string(forKey: key) ?? "") },
				set: { self.store($0, forKey: key) })
	}

	/// A setting kept somewhere else than one preference key
	func value<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value>
	{
		Binding(get: get,
				set: { self.objectWillChange.send(); set($0) })
	}

	/// A color: while it is the default (nil), the color the lists use
	func color(_ key: String) -> Binding<Color>
	{
		Binding(get: { Color(nsColor: (TDCSettingsBridge.color(forKey: key) ?? TDCSettingsBridge.defaultColor(forKey: key) ?? .gray)) },
				set: { self.objectWillChange.send(); TDCSettingsBridge.setColor(NSColor($0), forKey: key) })
	}
}
