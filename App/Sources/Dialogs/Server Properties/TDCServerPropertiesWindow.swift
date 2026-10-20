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

/* The Server Properties sheet's window, in the look of Settings: a sidebar
 of pages in two groups, the page, and Cancel and Save under them. The
 sheet (TDCServerPropertiesSheet) keeps its panes: they load, check and
 save the configuration. */

/// A string of the Server Properties sheet (TDCServerPropertiesSheet.strings)
func ServerPropertiesText(_ key: String, _ arguments: CVarArg...) -> String
{
	let format = LocalizedKey("TDCServerPropertiesSheet[\(key)]")

	if (arguments.isEmpty) {
		return format
	}

	return String(format: format, arguments: arguments)
}

// MARK: - Pages

/* Raw values are the sheet's selections (TDCServerPropertiesSheetSelection) */
enum ServerPropertiesPage: UInt, CaseIterable, Identifiable
{
	case server = 5
	case you = 6
	case account = 12
	case channels = 2
	case people = 1
	case messages = 8
	case whenConnected = 3
	case connection = 14
	case security = 18
	case proxy = 15
	case fallbackServers = 16
	case uploads = 17
	case znc = 10

	var id: UInt
	{
		rawValue
	}

	static let basics: [ServerPropertiesPage] = [.server, .you, .account, .channels, .people, .messages]

	static let advanced: [ServerPropertiesPage] = [.whenConnected, .connection, .security, .proxy, .fallbackServers, .uploads, .znc]

	private var key: String
	{
		switch self {
			case .server: return "server"
			case .you: return "you"
			case .account: return "account"
			case .channels: return "channels"
			case .people: return "people"
			case .messages: return "messages"
			case .whenConnected: return "commands"
			case .connection: return "connection"
			case .security: return "security"
			case .proxy: return "proxy"
			case .fallbackServers: return "fallback"
			case .uploads: return "uploads"
			case .znc: return "znc"
		}
	}

	var title: String
	{
		ServerPropertiesText("spp-t-\(key)")
	}

	var lead: String
	{
		ServerPropertiesText("spp-l-\(key)")
	}

	var symbol: String
	{
		switch self {
			case .server: return "server.rack"
			case .you: return "person.fill"
			case .account: return "key.fill"
			case .channels: return "number"
			case .people: return "person.2.fill"
			case .messages: return "text.bubble.fill"
			case .whenConnected: return "play.fill"
			case .connection: return "network"
			case .security: return "lock.fill"
			case .proxy: return "arrow.triangle.branch"
			case .fallbackServers: return "list.number"
			case .uploads: return "arrow.up.doc.fill"
			case .znc: return "tray.full.fill"
		}
	}

	var color: Color
	{
		switch self {
			case .server: return Color(nsColor: .systemBlue)
			case .you: return Color(nsColor: .systemPurple)
			case .account: return Color(nsColor: .systemYellow)
			case .channels: return Color(nsColor: .systemGreen)
			case .people: return Color(nsColor: .systemOrange)
			case .messages: return Color(nsColor: .systemTeal)
			default: return Color(nsColor: .systemGray)
		}
	}
}

// MARK: - Window

final class ServerPropertiesWindowModel: ObservableObject
{
	@Published var selection: ServerPropertiesPage = .server

	let panes: [UInt: TDCServerPropertiesPane]

	let serverPane: ServerPropertiesServerPane

	let save: () -> Void
	let cancel: () -> Void

	weak var window: NSWindow?

	init(panes: [TDCServerPropertiesPane], serverPane: ServerPropertiesServerPane, save: @escaping () -> Void, cancel: @escaping () -> Void)
	{
		var panesBySelection: [UInt: TDCServerPropertiesPane] = [:]

		for pane in panes {
			panesBySelection[pane.selection.rawValue] = pane
		}

		self.panes = panesBySelection
		self.serverPane = serverPane
		self.save = save
		self.cancel = cancel
	}
}

@objc(TDCServerPropertiesWindow)
final class ServerPropertiesWindow: NSObject
{
	@objc let window: NSWindow

	private let model: ServerPropertiesWindowModel

	@objc(initWithPanes:serverPane:save:cancel:)
	init(panes: [TDCServerPropertiesPane], serverPane: ServerPropertiesServerPane, save: @escaping () -> Void, cancel: @escaping () -> Void)
	{
		model = ServerPropertiesWindowModel(panes: panes, serverPane: serverPane, save: save, cancel: cancel)

		window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: ServerPropertiesRootView.width, height: ServerPropertiesRootView.height),
						  styleMask: [.titled],
						  backing: .buffered,
						  defer: true)

		window.isReleasedWhenClosed = false

		window.title = ServerPropertiesText("spp-title")

		window.contentViewController = NSHostingController(rootView: ServerPropertiesRootView().environmentObject(model))

		model.window = window

		super.init()
	}

	@objc var selection: TDCServerPropertiesSheetSelection
	{
		get {
			TDCServerPropertiesSheetSelection(rawValue: model.selection.rawValue) ?? .general
		}
		set {
			model.selection = (ServerPropertiesPage(rawValue: newValue.rawValue) ?? .server)
		}
	}
}

struct ServerPropertiesRootView: View
{
	static let width: CGFloat = 780
	static let height: CGFloat = 580

	@EnvironmentObject private var model: ServerPropertiesWindowModel

	private var selection: Binding<ServerPropertiesPage?>
	{
		Binding {
			model.selection
		} set: { (page) in
			if let page = page {
				model.selection = page
			}
		}
	}

	var body: some View
	{
		VStack(spacing: 0) {
			HStack(spacing: 0) {
				List(selection: selection) {
					Section(ServerPropertiesText("spp-g-basics")) {
						ForEach(ServerPropertiesPage.basics) { (page) in
							ServerPropertiesPageLabel(page: page)
								.tag(page)
						}
					}

					Section(ServerPropertiesText("spp-g-advanced")) {
						ForEach(ServerPropertiesPage.advanced) { (page) in
							ServerPropertiesPageLabel(page: page)
								.tag(page)
						}
					}
				}
				.listStyle(.sidebar)
				.frame(width: 200)

				Divider()

				ServerPropertiesPageView(page: model.selection)
					.id(model.selection)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}

			Divider()

			HStack {
				Spacer()

				Button(ServerPropertiesText("spp-b-cancel")) {
					model.cancel()
				}
				.keyboardShortcut(.cancelAction)

				Button(ServerPropertiesText("spp-b-save")) {
					model.save()
				}
				.keyboardShortcut(.defaultAction)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 14)
		}
		.frame(width: Self.width, height: Self.height)
	}
}

struct ServerPropertiesPageIcon: View
{
	let page: ServerPropertiesPage
	var size: CGFloat = 20

	var body: some View
	{
		Image(systemName: page.symbol)
			.font(.system(size: (size * 0.55), weight: .semibold))
			.foregroundStyle(.white)
			.frame(width: size, height: size)
			.background(RoundedRectangle(cornerRadius: (size * 0.25), style: .continuous).fill(page.color.gradient))
	}
}

struct ServerPropertiesPageLabel: View
{
	let page: ServerPropertiesPage

	var body: some View
	{
		Label {
			Text(page.title)
		} icon: {
			ServerPropertiesPageIcon(page: page)
		}
	}
}

/// The top of a page: its icon, title and what it covers, centered
struct ServerPropertiesPageHeader: View
{
	let page: ServerPropertiesPage

	var body: some View
	{
		VStack(spacing: 6) {
			ServerPropertiesPageIcon(page: page, size: 48)
				.padding(.bottom, 4)

			Text(page.title)
				.font(.title.weight(.semibold))

			Text(page.lead)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 10)
	}
}

struct ServerPropertiesPageView: View
{
	let page: ServerPropertiesPage

	@EnvironmentObject private var model: ServerPropertiesWindowModel

	var body: some View
	{
		switch page {
			case .server:
				ServerPage(pane: model.serverPane)
			case .fallbackServers:
				FallbackServersPage(pane: model.serverPane)
			case .security:
				if let pane = model.panes[page.rawValue] as? ServerPropertiesSecurityPane {
					SecurityPage(pane: pane, serverPane: model.serverPane)
				}
			default:
				if let pane = model.panes[page.rawValue] as? ServerPropertiesYouPane {
					YouPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesAccountPane {
					AccountPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesChannelsPane {
					ChannelsPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesPeoplePane {
					PeoplePage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesMessagesPane {
					MessagesPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesWhenConnectedPane {
					WhenConnectedPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesConnectionPane {
					ConnectionPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesProxyPane {
					ProxyPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesUploadsPane {
					UploadsPage(pane: pane)
				} else if let pane = model.panes[page.rawValue] as? ServerPropertiesZNCPane {
					ZNCPage(pane: pane)
				}
		}
	}
}
