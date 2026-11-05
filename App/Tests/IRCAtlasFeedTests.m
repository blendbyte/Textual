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

#import <XCTest/XCTest.h>

#import "IRCAtlasFeedStorePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCAtlasFeedTests : XCTestCase
@end

@implementation IRCAtlasFeedTests

- (NSDictionary *)networkWithIdentifier:(NSString *)identifier
							  languages:(NSArray *)languages
							certificate:(id)certificate
							   channels:(NSArray *)channels
{
	return @{
		@"id" : identifier,
		@"name" : identifier,
		@"description" : @"A network.",
		@"tags" : @[@"gaming"],
		@"languages" : languages,
		@"activity" : @{@"users" : @100, @"channels" : [NSNull null]},
		@"connection" : @{
			@"host" : [identifier stringByAppendingString:@".example.org"],
			@"port" : @6697,
			@"tls" : @(certificate != [NSNull null]),
			@"certificate_valid" : certificate,
			@"url" : @"ircs://example.org:6697"
		},
		@"sasl" : @YES,
		@"website_url" : [NSNull null],
		@"registration_url" : [NSNull null],
		@"featured_channels" : channels
	};
}

- (NSData *)feedWithNetworks:(NSArray *)networks tagged:(NSArray *)tagged
{
	NSDictionary *feed = @{
		@"schema_version" : @1,
		@"generated_at" : @"2026-11-04T08:37:07Z",
		@"license" : @"CC-BY-4.0",
		@"attribution" : @"IRC Atlas",
		@"tags" : @[@{@"tag" : @"gaming", @"name" : @"Gaming", @"networks" : tagged}],
		@"networks" : networks
	};

	return [NSJSONSerialization dataWithJSONObject:feed options:0 error:NULL];
}

/* A feed comes from the internet: nothing in it is used unchecked */
- (void)testBadFeedsAndEntriesAreRefused
{
	NSDictionary *good = [self networkWithIdentifier:@"good" languages:@[@"en"] certificate:@YES channels:@[]];

	NSMutableDictionary *badHost = [[self networkWithIdentifier:@"badhost" languages:@[@"en"] certificate:@YES channels:@[]] mutableCopy];
	badHost[@"connection"] = @{@"host" : @"evil.example.org -oProxy", @"port" : @6697, @"tls" : @YES};

	NSMutableDictionary *badPort = [[self networkWithIdentifier:@"badport" languages:@[@"en"] certificate:@YES channels:@[]] mutableCopy];
	badPort[@"connection"] = @{@"host" : @"example.org", @"port" : @70000, @"tls" : @YES};

	NSArray *identifiers = [IRCAtlasFeedStore networkIdentifiersWithFeedData:[self feedWithNetworks:@[badHost, good, badPort] tagged:@[]]];

	XCTAssertEqualObjects(identifiers, @[@"good"]);

	XCTAssertNil([IRCAtlasFeedStore networkIdentifiersWithFeedData:[self feedWithNetworks:@[] tagged:@[]]]);

	XCTAssertNil([IRCAtlasFeedStore networkIdentifiersWithFeedData:[self feedWithNetworks:@[badHost] tagged:@[]]]);

	XCTAssertNil([IRCAtlasFeedStore networkIdentifiersWithFeedData:[@"not json" dataUsingEncoding:NSUTF8StringEncoding]]);

	NSMutableDictionary *newerSchema =
	[NSJSONSerialization JSONObjectWithData:[self feedWithNetworks:@[good] tagged:@[]] options:NSJSONReadingMutableContainers error:NULL];

	newerSchema[@"schema_version"] = @2;

	XCTAssertNil([IRCAtlasFeedStore networkIdentifiersWithFeedData:[NSJSONSerialization dataWithJSONObject:newerSchema options:0 error:NULL]]);
}

/* Secure networks only, the chosen language's own first, and saying so when there are none */
- (void)testSuggestions
{
	NSArray *networks = @[
		[self networkWithIdentifier:@"biggest" languages:@[@"en", @"de"] certificate:@YES channels:@[]],
		[self networkWithIdentifier:@"badcert" languages:@[@"de"] certificate:@NO channels:@[]],
		[self networkWithIdentifier:@"plain" languages:@[@"de"] certificate:[NSNull null] channels:@[]],
		[self networkWithIdentifier:@"german" languages:@[@"de"] certificate:@YES channels:@[]]
	];

	NSArray *tagged = @[@"biggest", @"badcert", @"plain", @"german"];

	NSData *feed = [self feedWithNetworks:networks tagged:tagged];

	XCTAssertEqualObjects(([IRCAtlasFeedStore suggestionsWithFeedData:feed tag:@"gaming" language:@"de-DE"]),
						  (@[@"german", @"biggest", @"language"]));

	XCTAssertEqualObjects(([IRCAtlasFeedStore suggestionsWithFeedData:feed tag:@"gaming" language:nil]),
						  (@[@"biggest", @"german", @"language"]));

	XCTAssertEqualObjects(([IRCAtlasFeedStore suggestionsWithFeedData:feed tag:@"gaming" language:@"fi"]),
						  (@[@"biggest", @"german", @"any language"]));
}

/* A network with no channels stays listed, behind those someone could start in */
- (void)testSuggestionsWithoutChannels
{
	NSArray *channels = @[@{@"name" : @"#chat", @"reason" : @"Why.", @"users" : @5, @"tags" : @[], @"language" : [NSNull null]}];

	NSArray *networks = @[
		[self networkWithIdentifier:@"empty" languages:@[@"fr"] certificate:@YES channels:@[]],
		[self networkWithIdentifier:@"first" languages:@[@"fr"] certificate:@YES channels:channels],
		[self networkWithIdentifier:@"also" languages:@[@"en", @"fr"] certificate:@YES channels:channels]
	];

	NSData *feed = [self feedWithNetworks:networks tagged:@[@"empty", @"first", @"also"]];

	XCTAssertEqualObjects(([IRCAtlasFeedStore suggestionsWithFeedData:feed tag:@"gaming" language:@"fr"]),
						  (@[@"first", @"also", @"empty", @"language"]));

	XCTAssertEqualObjects(([IRCAtlasFeedStore suggestionsWithFeedData:feed tag:@"gaming" language:nil]),
						  (@[@"first", @"also", @"empty", @"language"]));

	XCTAssertEqualObjects(([IRCAtlasFeedStore suggestionsWithFeedData:feed tag:@"gaming" language:@"fi"]),
						  (@[@"first", @"also", @"empty", @"any language"]));

	XCTAssertEqualObjects(([IRCAtlasFeedStore starterChannelsWithFeedData:feed network:@"empty" tag:@"gaming" language:nil]),
						  (@[]));
}

/* The tag's channels first with the top one ticked; other tags and languages not at all */
- (void)testStarterChannels
{
	NSDictionary *(^channel)(NSString *, NSArray *, id) = ^NSDictionary *(NSString *name, NSArray *tags, id language) {
		return @{@"name" : name, @"reason" : @"Why.", @"users" : @5, @"tags" : tags, @"language" : language};
	};

	NSArray *channels = @[
		channel(@"#unsorted", @[], [NSNull null]),
		channel(@"#music", @[@"art-music"], @"de"),
		channel(@"#spiele", @[@"gaming"], @"de"),
		channel(@"#games", @[@"gaming"], @"en"),
		channel(@"#zocken", @[@"gaming"], [NSNull null]),
		channel(@"bad name", @[@"gaming"], @"de")
	];

	NSData *feed = [self feedWithNetworks:@[[self networkWithIdentifier:@"net" languages:@[@"de"] certificate:@YES channels:channels]]
								   tagged:@[@"net"]];

	XCTAssertEqualObjects(([IRCAtlasFeedStore starterChannelsWithFeedData:feed network:@"net" tag:@"gaming" language:@"de"]),
						  (@[@"*#spiele", @"#zocken", @"#unsorted"]));

	XCTAssertEqualObjects(([IRCAtlasFeedStore starterChannelsWithFeedData:feed network:@"net" tag:@"science" language:@"en"]),
						  (@[@"#unsorted"]));
}

@end

NS_ASSUME_NONNULL_END
