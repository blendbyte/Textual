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

@objc(TLOpenLink)
public class OpenLink: NSObject
{
	@objc(open:inBackground:)
	public static func open(url: URL, inBackground: Bool = TPCPreferences.openBrowserInBackground())
	{
		if inBackground {
			/* User should not be clicking links frequently enough that
			 we need to worry about making the configuration static. */
			let configuration = NSWorkspace.OpenConfiguration();
			configuration.activates = false

			NSWorkspace.shared.open(url, configuration: configuration)

			return
		}

		NSWorkspace.shared.open(url)
	}

	@objc(openWithString:inBackground:)
	public static func open(string: String, inBackground: Bool = TPCPreferences.openBrowserInBackground())
	{
		guard let urlToOpen = URL(string: string) else {
			return
		}

		open(url: urlToOpen, inBackground: inBackground)
	}
}

extension OpenLink {
	/// Schemes opened without asking. Everything else asks first.
	private static let schemesOpenedDirectly: Set<String> = ["http", "https", "irc", "ircs"]

	/// Schemes for which "Don't ask again" is never offered: file: links open
	/// local files and textual: links make Textual act (e.g. activate a licence).
	private static let schemesAlwaysConfirmed: Set<String> = ["file", "textual"]

	/// Decides whether a link from content Textual doesn't control (a message,
	/// a topic) may be opened, asking the user unless its scheme is safe.
	/// "Don't ask again" is remembered per scheme.
	@objc(confirmOpeningUntrustedURL:)
	public static func confirmOpeningUntrusted(url: URL) -> Bool
	{
		let scheme = url.scheme?.lowercased() ?? ""

		if schemesOpenedDirectly.contains(scheme) {
			return true
		}

		var applicationName = "Textual"

		if scheme != "textual" {
			guard let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
				return false // Nothing can open it
			}

			applicationName = FileManager.default.displayName(atPath: applicationURL.path)
		}

		var suppressionKey: String? = nil

		if scheme.isEmpty == false && schemesAlwaysConfirmed.contains(scheme) == false {
			suppressionKey = "open_link_with_scheme_\(scheme)"
		}

		return TDCAlert.modalAlert(withMessage: localizedString("Prompts[5oq-vv]", url.absoluteString),
								   title: localizedString("Prompts[2ul-cl]", applicationName),
								   defaultButton: localizedString("Prompts[mvh-ms]"),
								   alternateButton: localizedString("Prompts[99q-gg]"),
								   suppressionKey: suppressionKey,
								   suppressionText: nil)
	}

	private static func localizedString(_ key: String, _ arguments: CVarArg...) -> String
	{
		return withVaList(arguments) { TXLocalizedString(Bundle.main, key, $0) }
	}

	@objc(open:)
	public static func openBridged(url: URL)
	{
		open(url: url)
	}

	@objc(openWithString:)
	public static func openBridged(string: String)
	{
		open(string: string)
	}
}
