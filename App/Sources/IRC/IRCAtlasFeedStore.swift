/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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

import Foundation

/* Which copy of IRC Atlas's feed to use: the one in the app, the one saved from
 an earlier fetch, or a fresh one; the newest valid one wins. A fetch happens only
 when someone is about to choose a network and at most once a day, and a failed
 one changes nothing and tells nobody. */
@objc(IRCAtlasFeedStore)
final class AtlasFeedStore: NSObject, ObservableObject
{
	static let shared = AtlasFeedStore()

	@Published private(set) var feed: AtlasFeed?

	private static let bundledName = "IRCAtlasOnboarding"
	private static let cacheName = "IRCAtlasOnboarding.json"
	private static let lastCheckedKey = "IRC Atlas -> Last Checked"
	private static let entityTagKey = "IRC Atlas -> Entity Tag"
	private static let checkInterval: TimeInterval = 86400

	private var isFetching = false

	private override init()
	{
		super.init()

		feed = Self.newest(Self.bundledFeed(), Self.cachedFeed())
	}

	// MARK: - The copies

	private static func newest(_ first: AtlasFeed?, _ second: AtlasFeed?) -> AtlasFeed?
	{
		guard let first = first, let second = second else {
			return (first ?? second)
		}

		return ((second.generatedAt > first.generatedAt) ? second : first)
	}

	private static func bundledFeed() -> AtlasFeed?
	{
		guard let url = Bundle.main.url(forResource: bundledName, withExtension: "json"),
			  let data = try? Data(contentsOf: url) else {
			return nil
		}

		return AtlasFeed(data: data)
	}

	private static var cacheURL: URL?
	{
		TPCPathInfo.applicationCachesURL?.appendingPathComponent(cacheName)
	}

	private static func cachedFeed() -> AtlasFeed?
	{
		guard let url = cacheURL, let data = try? Data(contentsOf: url) else {
			return nil
		}

		return AtlasFeed(data: data)
	}

	// MARK: - Fetching

	/* Debug builds fetch only from where they are told to, so tests never reach the real feed:
	 defaults write com.textualapp.app.dev "IRC Atlas -> Feed URL" http://127.0.0.1:8089/onboarding.json */
	private static var feedURL: URL?
	{
#if DEBUG
		return TPCPreferencesUserDefaults.shared().string(forKey: "IRC Atlas -> Feed URL").flatMap(URL.init(string:))
#else
		return URL(string: "https://www.ircatlas.org/v1/onboarding.json")
#endif
	}

	/// For when someone is about to choose a network. The list shows at once;
	/// a newer feed replaces it in place.
	func refreshIfDue()
	{
		let defaults = TPCPreferencesUserDefaults.shared()

		if let lastChecked = defaults.object(forKey: Self.lastCheckedKey) as? Date,
		   Date().timeIntervalSince(lastChecked) < Self.checkInterval,
		   lastChecked <= Date() {
			return
		}

		guard isFetching == false, let url = Self.feedURL else {
			return
		}

		isFetching = true

		var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)

		/* Only with a saved copy to fall back on: "not modified" would otherwise leave nothing newer */
		if Self.cachedFeed() != nil, let entityTag = defaults.string(forKey: Self.entityTagKey) {
			request.setValue(entityTag, forHTTPHeaderField: "If-None-Match")
		}

		let session = URLSession(configuration: .ephemeral)

		session.dataTask(with: request) { [weak self] (data, response, error) in
			session.finishTasksAndInvalidate()

			let answered = (response as? HTTPURLResponse)

			let fresh = ((answered?.statusCode == 200) ? data.flatMap(AtlasFeed.init(data:)) : nil)

			DispatchQueue.main.async {
				self?.finishFetching(answered: answered, fresh: fresh, data: data)
			}
		}.resume()
	}

	private func finishFetching(answered: HTTPURLResponse?, fresh: AtlasFeed?, data: Data?)
	{
		isFetching = false

		/* No answer at all doesn't count as the day's request */
		guard let answered = answered else {
			return
		}

		let defaults = TPCPreferencesUserDefaults.shared()

		defaults.set(Date(), forKey: Self.lastCheckedKey)

		/* Not modified, refused, or older than what's here: what's here stays, saved copy included */
		guard let fresh = fresh, (feed.map { $0.generatedAt < fresh.generatedAt } ?? true) else {
			return
		}

		feed = fresh

		defaults.set(answered.value(forHTTPHeaderField: "ETag"), forKey: Self.entityTagKey)

		if let data = data, let url = Self.cacheURL {
			try? data.write(to: url, options: .atomic)
		}
	}

	// MARK: - For IRCNetworkList

	/* name -> the configuration IRCNetworkList reads */
	@objc static func networkConfigurations() -> [String: [String: Any]]
	{
		var configurations: [String: [String: Any]] = [:]

		for network in (shared.feed?.networks ?? []) {
			configurations[network.name] = [
				"serverAddress": network.host,
				"serverPort": Int(network.port),
				"prefersSecuredConnection": network.tls
			]
		}

		return configurations
	}

	// MARK: - For network icons

	/* The logo of the network at this address; nil without one. The server
	 list shows it until the network names an icon of its own (draft/ICON). */
	@objc static func logoAddress(serverAddress: String) -> String?
	{
		shared.feed?.networks
			.first { $0.host.caseInsensitiveCompare(serverAddress) == .orderedSame }?
			.logoURL?.absoluteString
	}

	// MARK: - For tests

#if DEBUG
	/* Network ids; nil when the feed is rejected */
	@objc static func networkIdentifiers(feedData: Data) -> [String]?
	{
		AtlasFeed(data: feedData)?.networks.map(\.id)
	}

	/* Network id -> logo address, for the networks that have one */
	@objc static func logoAddresses(feedData: Data) -> [String: String]?
	{
		AtlasFeed(data: feedData).map { (feed) in
			Dictionary(uniqueKeysWithValues: feed.networks.compactMap { (network) in
				network.logoURL.map { (network.id, $0.absoluteString) }
			})
		}
	}

	/* Network ids; the last entry is "language" or "any language" */
	@objc static func suggestions(feedData: Data, tag: String, language: String?) -> [String]?
	{
		guard let suggestions = AtlasFeed(data: feedData)?.suggestions(tag: tag, language: language) else {
			return nil
		}

		return (suggestions.networks.map(\.id) + [suggestions.matchesLanguage ? "language" : "any language"])
	}

	/* Channel names; a ticked one starts with "*" */
	@objc static func starterChannels(feedData: Data, network identifier: String, tag: String, language: String?) -> [String]?
	{
		guard let feed = AtlasFeed(data: feedData), let network = feed.networks.first(where: { $0.id == identifier }) else {
			return nil
		}

		return feed.starterChannels(network: network, tag: tag, language: language).map { (starter) in
			(starter.ticked ? "*" : "") + starter.channel.name
		}
	}
#endif
}
