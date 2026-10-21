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

/* The Channel List window: the public channels the server lists, searched
 by name and topic, with the ones you're in marked; the selected channel's
 full topic under the list, and Join. The dialog (TDCServerChannelListDialog)
 feeds it what the server sends, in batches, and does what it asks. */

/// A string of the Channel List window (TDCServerChannelListDialog.strings)
func ChannelListText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCServerChannelListDialog[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Channels

struct ChannelListEntry: Identifiable
{
	let id: Int
	let name: String
	let people: Int
	let topic: String // With IRC formatting
	let plainTopic: String
	let lowercasedName: String
	let searchText: String // Name and topic, lowercased

	init(id: Int, entry: TDCServerChannelListDialogEntry)
	{
		self.id = id

		name = entry.channelName
		people = Int(entry.channelMemberCount)
		topic = entry.channelTopic
		plainTopic = (entry.channelTopic as NSString).stripIRCEffects

		lowercasedName = name.lowercased()
		searchText = "\(lowercasedName) \(plainTopic.lowercased())"
	}
}

/// Topics with their IRC formatting, as SwiftUI text
enum ChannelListTopic
{
	static func text(_ topic: String, plain: String, links: Bool = false) -> AttributedString
	{
		var result = AttributedString(plain)

		/* Formatting codes only when there are some: most topics have none */
		if (topic != plain),
		   let formatted = (topic as NSString).attributedString(withIRCFormatting: NSFont.systemFont(ofSize: NSFont.systemFontSize),
																 preferredFontColor: nil,
																 honorFormattingPreference: true)
		{
			result = convert(formatted)
		}

		if links {
			addLinks(to: &result)
		}

		return result
	}

	private static func convert(_ string: NSAttributedString) -> AttributedString
	{
		var result = AttributedString()

		string.enumerateAttributes(in: NSRange(location: 0, length: string.length)) { (attributes, range, _) in
			var part = AttributedString(string.attributedSubstring(from: range).string)

			if let color = attributes[.foregroundColor] as? NSColor {
				part.foregroundColor = Color(nsColor: color)
			}

			if let color = attributes[.backgroundColor] as? NSColor {
				part.backgroundColor = Color(nsColor: color)
			}

			if let font = attributes[.font] as? NSFont {
				let traits = font.fontDescriptor.symbolicTraits

				var intent = InlinePresentationIntent()

				if traits.contains(.bold) {
					intent.insert(.stronglyEmphasized)
				}

				if traits.contains(.italic) {
					intent.insert(.emphasized)
				}

				if (intent.isEmpty == false) {
					part.inlinePresentationIntent = intent
				}
			}

			if let underline = attributes[.underlineStyle] as? Int, (underline != 0) {
				part.underlineStyle = .single
			}

			if let strikethrough = attributes[.strikethroughStyle] as? Int, (strikethrough != 0) {
				part.strikethroughStyle = .single
			}

			result += part
		}

		return result
	}

	private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

	private static func addLinks(to text: inout AttributedString)
	{
		guard let detector = linkDetector else {
			return
		}

		let string = String(text.characters)

		for match in detector.matches(in: string, range: NSRange(string.startIndex..., in: string)) {
			if let url = match.url, let range = Range(match.range, in: text) {
				text[range].link = url
			}
		}
	}
}

// MARK: - Window

final class ChannelListModel: ObservableObject
{
	/* As many as joining at once sends in one JOIN */
	static let joinLimit = 8

	@Published private(set) var entries: [ChannelListEntry] = []
	@Published private(set) var shown: [ChannelListEntry] = []

	@Published var search = ""
	{
		didSet {
			if (search != oldValue) {
				update()
			}
		}
	}

	@Published var sortOrder = [KeyPathComparator(\ChannelListEntry.people, order: .reverse)]
	{
		didSet {
			update()
		}
	}

	@Published var selection = Set<Int>()

	@Published private(set) var isLoading = true
	@Published private(set) var updatedAt: Date?
	@Published private(set) var joined = Set<String>()

	weak var window: NSWindow?

	private let joinBlock: ([String]) -> Void
	private let refreshBlock: () -> Void
	private let joinedChannelsBlock: () -> Set<String>

	private var nextIdentifier = 0
	private var topics: [Int: AttributedString] = [:]

	init(join: @escaping ([String]) -> Void, refresh: @escaping () -> Void, joinedChannels: @escaping () -> Set<String>)
	{
		joinBlock = join
		refreshBlock = refresh
		joinedChannelsBlock = joinedChannels

		refreshJoined()
	}

	// MARK: List

	func clear()
	{
		entries = []
		shown = []
		selection = []
		topics = [:]

		isLoading = true
		updatedAt = nil

		refreshJoined()
	}

	func add(_ newEntries: [TDCServerChannelListDialogEntry])
	{
		var entries = self.entries

		entries.reserveCapacity(entries.count + newEntries.count)

		for entry in newEntries {
			entries.append(ChannelListEntry(id: nextIdentifier, entry: entry))

			nextIdentifier += 1
		}

		self.entries = entries

		update()
	}

	func finishLoading()
	{
		isLoading = false
		updatedAt = Date()

		refreshJoined()
	}

	func refreshJoined()
	{
		let joined = joinedChannelsBlock()

		if (joined != self.joined) {
			self.joined = joined
		}
	}

	private func update()
	{
		let query = search.trimmingCharacters(in: .whitespaces).lowercased()

		var shown = (query.isEmpty ? entries : entries.filter { $0.searchText.contains(query) })

		shown.sort(using: sortOrder)

		self.shown = shown
	}

	func isJoined(_ entry: ChannelListEntry) -> Bool
	{
		joined.contains(entry.lowercasedName)
	}

	/* Formatted when shown, then kept */
	func topic(of entry: ChannelListEntry) -> AttributedString
	{
		if let topic = topics[entry.id] {
			return topic
		}

		let topic = ChannelListTopic.text(entry.topic, plain: entry.plainTopic)

		topics[entry.id] = topic

		return topic
	}

	/* In the order shown */
	func entries(_ identifiers: Set<Int>) -> [ChannelListEntry]
	{
		if identifiers.isEmpty {
			return []
		}

		return shown.filter { identifiers.contains($0.id) }
	}

	var selectedEntries: [ChannelListEntry]
	{
		entries(selection)
	}

	// MARK: Status

	private static let timeFormatter: DateFormatter =
	{
		let formatter = DateFormatter()

		formatter.dateStyle = .none
		formatter.timeStyle = .short

		return formatter
	}()

	private static func number(_ value: Int) -> String
	{
		NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
	}

	/// "Loading… 1,234 channels so far", "2 of 5 channels · updated 09:31"
	var status: String
	{
		let total = Self.number(entries.count)

		if isLoading {
			return (entries.isEmpty ? ChannelListText("cl-loading-0") : ChannelListText("cl-loading", total))
		}

		var count = ChannelListText("cl-count", total)

		if (search.trimmingCharacters(in: .whitespaces).isEmpty == false) {
			count = ChannelListText("cl-count-of", Self.number(shown.count), total)
		}

		if let updatedAt = updatedAt {
			return ChannelListText("cl-updated", count, Self.timeFormatter.string(from: updatedAt))
		}

		return count
	}

	static func peopleText(_ count: Int) -> String
	{
		(count == 1 ? ChannelListText("cl-people1") : ChannelListText("cl-peoplen", number(count)))
	}

	// MARK: Actions

	func joinTitle(for entries: [ChannelListEntry]) -> String
	{
		if (entries.count == 1), let entry = entries.first {
			return (isJoined(entry) ? ChannelListText("cl-show", entry.name) : ChannelListText("cl-join1", entry.name))
		}

		if (entries.count > 1) {
			return ChannelListText("cl-joinn", entries.count)
		}

		return ChannelListText("cl-join")
	}

	func canJoin(_ entries: [ChannelListEntry]) -> Bool
	{
		(entries.isEmpty == false && entries.count <= Self.joinLimit)
	}

	/* Already joined: Textual shows the channel */
	func join(_ entries: [ChannelListEntry])
	{
		guard canJoin(entries) else {
			return
		}

		joinBlock(entries.map(\.name))

		/* The server's answer marks them joined */
		DispatchQueue.main.asyncAfter(deadline: (.now() + 1.5)) { [weak self] in
			self?.refreshJoined()
		}
	}

	func refresh()
	{
		refreshBlock()
	}
}

@objc(TDCServerChannelListWindow)
final class ChannelListWindow: NSObject
{
	@objc let window: NSWindow

	private let model: ChannelListModel

	private var keyObserver: NSObjectProtocol?

	@objc(initWithNetworkName:join:refresh:joinedChannels:)
	init(networkName: String, join: @escaping ([String]) -> Void, refresh: @escaping () -> Void, joinedChannels: @escaping () -> Set<String>)
	{
		model = ChannelListModel(join: join, refresh: refresh, joinedChannels: joinedChannels)

		window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
						  styleMask: [.titled, .closable, .miniaturizable, .resizable],
						  backing: .buffered,
						  defer: true)

		window.isReleasedWhenClosed = false

		window.tabbingMode = .disallowed

		window.title = ChannelListText("cl-title", networkName)

		window.minSize = NSSize(width: 600, height: 440)

		let hostingController = NSHostingController(rootView: ChannelListView().environmentObject(model))

		/* The window keeps the size it's given or the user chooses */
		hostingController.sizingOptions = []

		window.contentViewController = hostingController

		window.setContentSize(NSSize(width: 720, height: 500))

		/* Until it has been closed once and its frame is saved */
		window.center()

		model.window = window

		super.init()

		/* Joined or left in the main window meanwhile */
		keyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] (_) in
			self?.model.refreshJoined()
		}
	}

	deinit
	{
		if let keyObserver = keyObserver {
			NotificationCenter.default.removeObserver(keyObserver)
		}
	}

	@objc func clear()
	{
		model.clear()
	}

	@objc(addEntries:)
	func add(_ entries: [TDCServerChannelListDialogEntry])
	{
		model.add(entries)
	}

	@objc func finishLoading()
	{
		model.finishLoading()
	}
}

struct ChannelListView: View
{
	@EnvironmentObject private var model: ChannelListModel

	var body: some View
	{
		let selected = model.selectedEntries

		VStack(spacing: 0) {
			HStack(spacing: 10) {
				ChannelListSearchField(text: $model.search)
					.frame(maxWidth: 260)

				Spacer(minLength: 8)

				if model.isLoading {
					ProgressView()
						.controlSize(.small)
				}

				Text(model.status)
					.foregroundStyle(.secondary)
					.monospacedDigit()
					.lineLimit(1)

				Button {
					model.refresh()
				} label: {
					Label(ChannelListText("cl-refresh"), systemImage: "arrow.clockwise")
						.labelStyle(.iconOnly)
				}
				.help(ChannelListText("cl-refresh"))
				.disabled(model.isLoading)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 10)

			Divider()

			ChannelListTable()
				.overlay {
					ChannelListEmptyView()
				}

			Divider()

			ChannelListDetailView(entries: selected)

			Divider()

			HStack {
				if (selected.count > ChannelListModel.joinLimit) {
					Text(ChannelListText("cl-limit"))
						.foregroundStyle(.secondary)
				}

				Spacer()

				Button(model.joinTitle(for: selected)) {
					model.join(selected)
				}
				.keyboardShortcut(.defaultAction)
				.disabled(model.canJoin(selected) == false)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 10)
		}
		.frame(minWidth: 600, minHeight: 400)
		.onExitCommand {
			model.window?.close()
		}
	}
}

struct ChannelListSearchField: View
{
	@Binding var text: String

	var body: some View
	{
		HStack(spacing: 4) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)

			TextField(ChannelListText("cl-search"), text: $text)
				.textFieldStyle(.plain)

			if (text.isEmpty == false) {
				Button {
					text = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.borderless)
			}
		}
		.padding(.horizontal, 7)
		.padding(.vertical, 4)
		.background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(nsColor: .textBackgroundColor)))
		.overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
	}
}

struct ChannelListTable: View
{
	@EnvironmentObject private var model: ChannelListModel

	/* Clicking a row selects it without giving the table the keyboard
	 (arrows, Return), so the table takes it */
	@FocusState private var tableFocused: Bool

	var body: some View
	{
		Table(model.shown, selection: $model.selection, sortOrder: $model.sortOrder) {
			TableColumn(ChannelListText("cl-col-channel"), value: \.name) { (entry) in
				HStack(spacing: 6) {
					Text(entry.name)
						.lineLimit(1)
						.truncationMode(.middle)

					/* The name gives way, not the mark */
					if model.isJoined(entry) {
						Text(ChannelListText("cl-joined"))
							.font(.caption)
							.foregroundStyle(.secondary)
							.padding(.horizontal, 5)
							.padding(.vertical, 1)
							.background(Capsule().fill(.quaternary))
							.fixedSize()
							.layoutPriority(1)
					}
				}
			}
			.width(min: 120, ideal: 180)

			TableColumn(ChannelListText("cl-col-people"), value: \.people) { (entry) in
				Text(entry.people, format: .number)
					.monospacedDigit()
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
			.width(min: 56, ideal: 64, max: 90)

			TableColumn(ChannelListText("cl-col-topic"), value: \.plainTopic) { (entry) in
				Text(model.topic(of: entry))
					.lineLimit(1)
					.help(entry.plainTopic)
			}
		}
		.contextMenu(forSelectionType: Int.self) { (identifiers) in
			let entries = model.entries(identifiers)

			if (entries.isEmpty == false) {
				Button(model.joinTitle(for: entries)) {
					model.join(entries)
				}
				.disabled(model.canJoin(entries) == false)
			}
		} primaryAction: { (identifiers) in
			model.join(model.entries(identifiers))
		}
		.focused($tableFocused)
		.onChange(of: model.selection) { (_, selection) in
			if (selection.isEmpty == false) {
				tableFocused = true
			}
		}
	}
}

struct ChannelListEmptyView: View
{
	@EnvironmentObject private var model: ChannelListModel

	var body: some View
	{
		if model.shown.isEmpty {
			Group {
				if model.entries.isEmpty {
					if model.isLoading {
						Text(ChannelListText("cl-loading-0"))
					} else {
						Text(ChannelListText("cl-empty-none"))
					}
				} else {
					Text(ChannelListText("cl-empty-search", model.search.trimmingCharacters(in: .whitespaces)))
				}
			}
			.foregroundStyle(.secondary)
			.padding()
		}
	}
}

/// The selected channel's full topic, with links
struct ChannelListDetailView: View
{
	let entries: [ChannelListEntry]

	var body: some View
	{
		VStack(alignment: .leading, spacing: 4) {
			if (entries.count == 1), let entry = entries.first {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Text(entry.name)
						.fontWeight(.semibold)

					Text(ChannelListModel.peopleText(entry.people))
						.foregroundStyle(.secondary)
				}

				if entry.plainTopic.isEmpty {
					Text(ChannelListText("cl-no-topic"))
						.foregroundStyle(.secondary)
				} else {
					Text(ChannelListTopic.text(entry.topic, plain: entry.plainTopic, links: true))
						.textSelection(.enabled)
						.lineLimit(4)
						.fixedSize(horizontal: false, vertical: true)
				}
			} else if (entries.count > 1) {
				Text(ChannelListText("cl-n-selected", entries.count))
					.foregroundStyle(.secondary)
			} else {
				Text(ChannelListText("cl-select"))
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
}
