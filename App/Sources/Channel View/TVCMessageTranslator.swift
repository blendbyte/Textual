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
import Translation

/* Translate in a message's menu: Apple's on-device Translation (macOS 15),
 the language found by itself, into the Mac's language. A session only comes
 from SwiftUI's translationTask, so an invisible view in the chat's window
 holds it; macOS asks there to download a language first when it needs to. */
@objc(TVCMessageTranslator)
final class TVCMessageTranslator: NSObject
{
	@objc static var isAvailable: Bool
	{
		if #available(macOS 15.0, *) {
			return true
		}

		return false
	}

	/// The translation of the text on the main queue, or nil when it couldn't be made
	@objc(translateText:inView:completionHandler:)
	static func translate(_ text: String, in view: NSView, completionHandler: @escaping (String?) -> Void)
	{
		guard #available(macOS 15.0, *) else {
			completionHandler(nil)

			return
		}

		TVCMessageTranslationHost.shared.translate(text, in: view, completionHandler: completionHandler)
	}
}

@available(macOS 15.0, *)
private final class TVCMessageTranslationHost
{
	static let shared = TVCMessageTranslationHost()

	private let model = TVCMessageTranslationModel()

	private var hostingView: NSHostingView<TVCMessageTranslationTaskView>?

	func translate(_ text: String, in view: NSView, completionHandler: @escaping (String?) -> Void)
	{
		/* In the window of the chat asked from (a language download is asked there) */
		if (hostingView?.superview !== view) {
			hostingView?.removeFromSuperview()

			let hostingView = NSHostingView(rootView: TVCMessageTranslationTaskView(model: model))

			hostingView.frame = NSRect(x: 0, y: 0, width: 1, height: 1)

			view.addSubview(hostingView)

			self.hostingView = hostingView
		}

		model.translate(text, completionHandler: completionHandler)
	}
}

@available(macOS 15.0, *)
private final class TVCMessageTranslationModel: ObservableObject
{
	@Published var configuration: TranslationSession.Configuration?

	private var pending: [(text: String, completionHandler: (String?) -> Void)] = []

	func translate(_ text: String, completionHandler: @escaping (String?) -> Void)
	{
		pending.append((text, completionHandler))

		/* A new or invalidated configuration runs the task again */
		if (configuration == nil) {
			configuration = TranslationSession.Configuration(source: nil, target: nil)
		} else {
			configuration?.invalidate()
		}
	}

	func takePending() -> [(text: String, completionHandler: (String?) -> Void)]
	{
		let requests = pending

		pending = []

		return requests
	}
}

@available(macOS 15.0, *)
private struct TVCMessageTranslationTaskView: View
{
	@ObservedObject var model: TVCMessageTranslationModel

	var body: some View
	{
		Color.clear
			.frame(width: 1, height: 1)
			.translationTask(model.configuration) { (session) in
				for request in await MainActor.run(body: { model.takePending() }) {
					var translation: String? = nil

					do {
						translation = try await session.translate(request.text).targetText
					} catch {
						translation = nil
					}

					await MainActor.run {
						request.completionHandler(translation)
					}
				}
			}
	}
}
