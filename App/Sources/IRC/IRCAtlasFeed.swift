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

/* IRC Atlas's onboarding feed (ircatlas.org, CC BY 4.0): the networks Textual
 suggests and lists. This file only reads it and answers questions about it;
 IRCAtlasFeedStore.swift decides which copy to use. Nothing in the feed is
 trusted: an entry with a bad value is dropped, and a feed left without
 networks is no feed. */

struct AtlasChannel
{
	let name: String
	let reason: String
	let users: Int?
	let tags: [String]
	let language: String?
}

struct AtlasNetwork
{
	let id: String
	let name: String
	let description: String
	let tags: [String]
	let languages: [String] // most used first
	let users: Int?
	let channelCount: Int?
	let host: String
	let port: UInt16
	let tls: Bool
	let certificateValid: Bool? // nil without TLS
	let sasl: Bool
	let websiteURL: URL?
	let registrationURL: URL?
	let channels: [AtlasChannel]

	/* What Textual suggests by itself. Anything else is in the whole list only,
	 with a warning before connecting. */
	var connectsSecurely: Bool
	{
		(tls && certificateValid == true)
	}
}

struct AtlasTag
{
	let tag: String
	let name: String
	let networks: [String] // ids, largest first
}

/// A channel offered to start in, and whether it starts ticked
struct AtlasStarterChannel
{
	let channel: AtlasChannel
	let ticked: Bool
}

struct AtlasSuggestions
{
	let networks: [AtlasNetwork]

	/* NO: nothing in the chosen language, so these are the tag's networks in any language */
	let matchesLanguage: Bool
}

struct AtlasFeed
{
	static let schemaVersion = 1

	private static let largestFeed = (16 * 1024 * 1024)

	static let suggestionLimit = 5
	static let starterChannelLimit = 3

	let generatedAt: Date
	let license: String
	let attribution: String
	let tags: [AtlasTag]
	let networks: [AtlasNetwork]

	private let networksByID: [String: AtlasNetwork]

	// MARK: - Reading

	init?(data: Data)
	{
		guard data.count <= Self.largestFeed,
			  let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
			  (root["schema_version"] as? Int) == Self.schemaVersion,
			  let generatedText = root["generated_at"] as? String,
			  let generatedAt = ISO8601DateFormatter().date(from: generatedText),
			  let license = Self.text(root["license"]),
			  let attribution = Self.text(root["attribution"]),
			  let networkEntries = root["networks"] as? [[String: Any]] else {
			return nil
		}

		var networks: [AtlasNetwork] = []
		var networksByID: [String: AtlasNetwork] = [:]

		for entry in networkEntries {
			guard let network = Self.network(entry), networksByID[network.id] == nil else {
				continue
			}

			networks.append(network)
			networksByID[network.id] = network
		}

		guard networks.isEmpty == false else {
			return nil
		}

		self.generatedAt = generatedAt
		self.license = license
		self.attribution = attribution
		self.networks = networks
		self.networksByID = networksByID

		/* Ids of dropped networks go too, so that a tag's size is what it can show */
		self.tags = ((root["tags"] as? [[String: Any]]) ?? []).compactMap { (entry) in
			guard let tag = Self.text(entry["tag"]), let name = Self.text(entry["name"]) else {
				return nil
			}

			let ids = Self.strings(entry["networks"]).filter { networksByID[$0] != nil }

			return AtlasTag(tag: tag, name: name, networks: ids)
		}
	}

	private static func network(_ entry: [String: Any]) -> AtlasNetwork?
	{
		guard let id = text(entry["id"]),
			  let name = text(entry["name"]),
			  let connection = entry["connection"] as? [String: Any],
			  let host = connection["host"] as? String, isHost(host),
			  let portNumber = connection["port"] as? Int, (1...65535).contains(portNumber),
			  let tls = connection["tls"] as? Bool else {
			return nil
		}

		let activity = (entry["activity"] as? [String: Any])

		let channels = ((entry["featured_channels"] as? [[String: Any]]) ?? []).compactMap(channel)

		return AtlasNetwork(id: id,
							name: name,
							description: (text(entry["description"]) ?? ""),
							tags: strings(entry["tags"]),
							languages: strings(entry["languages"]),
							users: count(activity?["users"]),
							channelCount: count(activity?["channels"]),
							host: host,
							port: UInt16(portNumber),
							tls: tls,
							certificateValid: (tls ? (connection["certificate_valid"] as? Bool) : nil),
							sasl: ((entry["sasl"] as? Bool) ?? false),
							websiteURL: webLink(entry["website_url"]),
							registrationURL: webLink(entry["registration_url"]),
							channels: channels)
	}

	private static func channel(_ entry: [String: Any]) -> AtlasChannel?
	{
		guard let name = entry["name"] as? String, isChannelName(name) else {
			return nil
		}

		return AtlasChannel(name: name,
							reason: (text(entry["reason"]) ?? ""),
							users: count(entry["users"]),
							tags: strings(entry["tags"]),
							language: text(entry["language"]))
	}

	// MARK: - Checking values

	/* Text is shown as it is, so it needn't be clean; only present and on one line */
	private static func text(_ value: Any?) -> String?
	{
		guard let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
			  string.isEmpty == false,
			  string.rangeOfCharacter(from: .controlCharacters) == nil else {
			return nil
		}

		return string
	}

	private static func strings(_ value: Any?) -> [String]
	{
		((value as? [Any]) ?? []).compactMap(text)
	}

	private static func count(_ value: Any?) -> Int?
	{
		guard let number = value as? Int, number >= 0 else {
			return nil
		}

		return number
	}

	private static func isHost(_ host: String) -> Bool
	{
		let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")

		guard (1...253).contains(host.utf8.count), host.rangeOfCharacter(from: allowed.inverted) == nil else {
			return false
		}

		return host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { (label) in
			(label.isEmpty == false && label.hasPrefix("-") == false && label.hasSuffix("-") == false)
		}
	}

	private static func isChannelName(_ name: String) -> Bool
	{
		guard let prefix = name.first, "#&+!".contains(prefix), (2...200).contains(name.utf8.count) else {
			return false
		}

		let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters).union(CharacterSet(charactersIn: ",:"))

		return (name.rangeOfCharacter(from: forbidden) == nil)
	}

	private static func webLink(_ value: Any?) -> URL?
	{
		guard let string = value as? String,
			  let url = URL(string: string),
			  let scheme = url.scheme?.lowercased(), (scheme == "https" || scheme == "http"),
			  url.host?.isEmpty == false else {
			return nil
		}

		return url
	}

	// MARK: - Languages

	/* pt-BR and pt are the same language here: the choice is about being understood */
	private static func primaryLanguage(_ language: String) -> String
	{
		String(language.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "").lowercased()
	}

	private static func sameLanguage(_ first: String, _ second: String) -> Bool
	{
		(primaryLanguage(first) == primaryLanguage(second))
	}

	/// The first of the languages the Mac prefers that any network speaks; nil for none of them
	func language(preferred: [String]) -> String?
	{
		preferred.first { (language) in
			networks.contains { $0.languages.contains { Self.sameLanguage($0, language) } }
		}
		.map(Self.primaryLanguage)
	}

	// MARK: - Newcomers

	/// Tags to pick from: those with the most networks first, none without networks
	var tagChoices: [AtlasTag]
	{
		tags.filter { $0.networks.isEmpty == false }
			.enumerated()
			.sorted { ($0.element.networks.count, $1.offset) > ($1.element.networks.count, $0.offset) }
			.map(\.element)
	}

	/// Where someone new could go for a tag: secure connections only, the networks
	/// whose first language is theirs ahead, otherwise in the tag's own order
	/// (largest first). Without a language, the tag's networks as they are. Networks
	/// with no channels to offer at all come last, so nobody starts on one by default.
	func suggestions(tag: String, language: String?, limit: Int = AtlasFeed.suggestionLimit) -> AtlasSuggestions
	{
		let inTag = (tags.first { $0.tag == tag }?.networks ?? [])
			.compactMap { networksByID[$0] }
			.filter(\.connectsSecurely)

		guard let language = language else {
			return AtlasSuggestions(networks: Array(Self.withChannelsFirst(inTag).prefix(limit)), matchesLanguage: true)
		}

		let first = inTag.filter { (network) in
			network.languages.first.map { Self.sameLanguage($0, language) } ?? false
		}

		let also = inTag.filter { (network) in
			(network.languages.dropFirst().contains { Self.sameLanguage($0, language) }
				&& first.contains { $0.id == network.id } == false)
		}

		let matching = (first + also)

		guard matching.isEmpty == false else {
			return AtlasSuggestions(networks: Array(Self.withChannelsFirst(inTag).prefix(limit)), matchesLanguage: false)
		}

		return AtlasSuggestions(networks: Array(Self.withChannelsFirst(matching).prefix(limit)), matchesLanguage: true)
	}

	private static func withChannelsFirst(_ networks: [AtlasNetwork]) -> [AtlasNetwork]
	{
		(networks.filter { $0.channels.isEmpty == false } + networks.filter { $0.channels.isEmpty })
	}

	/// Channels to start in: those with the tag first and the top one ticked, then
	/// those nobody classified, unticked. Other tags, or another known language,
	/// aren't shown; no known language might fit.
	func starterChannels(network: AtlasNetwork,
						 tag: String,
						 language: String?,
						 limit: Int = AtlasFeed.starterChannelLimit) -> [AtlasStarterChannel]
	{
		let fitting = network.channels.filter { (channel) in
			guard let language = language, let channelLanguage = channel.language else {
				return true
			}

			return Self.sameLanguage(channelLanguage, language)
		}

		let matching = fitting.filter { $0.tags.contains(tag) }
		let unclassified = fitting.filter { $0.tags.isEmpty }

		return (matching + unclassified).prefix(limit).enumerated().map { (offset, channel) in
			AtlasStarterChannel(channel: channel, ticked: (offset == 0 && matching.isEmpty == false))
		}
	}
}
