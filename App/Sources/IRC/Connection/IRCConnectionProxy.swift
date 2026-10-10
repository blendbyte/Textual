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

import Network
import WebKit

/// The proxy a server's settings ask for. The IRC connection, inline media
/// requests and the chat view's own loads all go through it, so a server
/// set to use a proxy (Tor included) does not reveal the user's address
/// through link previews either.
struct ProxySettings
{
	static let torAddress = "127.0.0.1"
	static let torPort: UInt16 = 9150

	let configuration: ProxyConfiguration
	let address: String
	let port: UInt16

	/// Nil for none and "Automatic" (system settings). SOCKS4 is no longer
	/// supported and is tried as SOCKS5.
	init?(type: IRCConnectionProxyType, address proxyAddress: String?, port proxyPort: UInt16, username: String?, password: String?)
	{
		switch type {
			case .tor:
				address = ProxySettings.torAddress
				port = ProxySettings.torPort
			case .socks4, .socks5, .HTTP, .HTTPS:
				guard let proxyAddress = proxyAddress, proxyAddress.isEmpty == false, proxyPort > 0 else {
					return nil
				}

				address = proxyAddress
				port = proxyPort
			default:
				return nil
		}

		let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(address), port: NWEndpoint.Port(integerLiteral: port))

		var proxy: ProxyConfiguration

		switch type {
			case .HTTP:
				proxy = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
			case .HTTPS:
				proxy = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: NWProtocolTLS.Options())
			default:
				proxy = ProxyConfiguration(socksv5Proxy: endpoint)
		}

		/* Never fall back to a direct connection when the proxy fails */
		proxy.allowFailover = false

		if (type != .tor), let username = username, username.isEmpty == false, let password = password {
			proxy.applyCredential(username: username, password: password)
		}

		configuration = proxy
	}

	/// The same server settings as the IRC connection gets them
	/// (IRCClient+Commands builds its connection configuration this way)
	init?(clientConfig config: IRCClientConfig)
	{
		let type = config.proxyType

		if (type == .socks5 || type == .HTTP || type == .HTTPS) {
			self.init(type: type, address: config.proxyAddress, port: config.proxyPort, username: config.proxyUsername, password: config.proxyPassword)
		} else {
			self.init(type: type, address: nil, port: 0, username: nil, password: nil)
		}
	}
}

@objc(IRCConnectionProxy)
final class ConnectionProxy: NSObject
{
	/// Equal for servers that use the same proxy, nil for those without one.
	/// Holds the proxy password: only for use as a key in memory.
	@objc(identifierForClientConfig:)
	static func identifier(for config: IRCClientConfig) -> String?
	{
		guard ProxySettings(clientConfig: config) != nil else {
			return nil
		}

		let address = ((config.proxyType == .tor) ? ProxySettings.torAddress : (config.proxyAddress ?? ""))

		return [String(config.proxyType.rawValue), address, String(config.proxyPort), (config.proxyUsername ?? ""), (config.proxyPassword ?? "")].joined(separator: "\u{1F}")
	}

	/// Routes the session's requests through the server's proxy, if it has one
	@objc(applyClientConfig:toSessionConfiguration:)
	static func apply(_ config: IRCClientConfig, to sessionConfiguration: URLSessionConfiguration)
	{
		sessionConfiguration.proxyConfigurations = proxyConfigurations(for: config)
	}

	/// Routes the web views' loads through the server's proxy, or back to
	/// the system settings when it has none. Takes effect for new loads.
	@objc(applyClientConfig:toWebsiteDataStore:)
	static func apply(_ config: IRCClientConfig, to dataStore: WKWebsiteDataStore)
	{
		dataStore.proxyConfigurations = proxyConfigurations(for: config)
	}

	fileprivate static func proxyConfigurations(for config: IRCClientConfig) -> [ProxyConfiguration]
	{
		if let settings = ProxySettings(clientConfig: config) {
			return [settings.configuration]
		}

		return []
	}
}
