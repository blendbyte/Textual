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

#import <XCTest/XCTest.h>

#import "IRCHighlightMatchCondition.h"
#import "IRCHighlightKeywordPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCHighlightKeywordTests : XCTestCase
@end

@implementation IRCHighlightKeywordTests

- (IRCHighlightMatchCondition *)condition:(NSString *)keyword channel:(nullable NSString *)channelId excluded:(BOOL)excluded
{
	IRCHighlightMatchConditionMutable *condition = [IRCHighlightMatchConditionMutable new];

	condition.matchKeyword = keyword;
	condition.matchChannelId = channelId;
	condition.matchIsExcluded = excluded;

	return [condition copy];
}

/* A server's own keywords move into the global lists without losing where
 they applied: no channel = that whole server */
- (void)testServerKeywordsMove
{
	NSArray *entries = @[
		@{@"string" : @"deploy"},
		@{@"string" : @"release", @"limitedTo" : @[@"channel-a"]},
		@{@"string" : @"alert", @"nicknames" : @[@"bot"]}
	];

	NSArray *conditions = @[
		[self condition:@"Deploy" channel:nil excluded:NO], // already everywhere
		[self condition:@"release" channel:@"channel-b" excluded:NO], // joins the limits
		[self condition:@"build" channel:nil excluded:NO], // new, this server
		[self condition:@"alert" channel:@"channel-c" excluded:NO], // the existing one is for one person
		[self condition:@"spam" channel:@"channel-c" excluded:YES] // the other list
	];

	NSArray *merged = [IRCHighlightKeyword entries:entries mergingServerConditions:conditions excluded:NO clientId:@"server-1"];

	NSArray *expected = @[
		@{@"string" : @"deploy"},
		@{@"string" : @"release", @"limitedTo" : @[@"channel-a", @"channel-b"]},
		@{@"string" : @"alert", @"nicknames" : @[@"bot"]},
		@{@"string" : @"build", @"limitedTo" : @[@"server-1"]},
		@{@"string" : @"alert", @"limitedTo" : @[@"channel-c"]}
	];

	XCTAssertEqualObjects(merged, expected);

	NSArray *mergedExcluded = [IRCHighlightKeyword entries:nil mergingServerConditions:conditions excluded:YES clientId:@"server-1"];

	NSArray *expectedExcluded = @[@{@"string" : @"spam", @"limitedTo" : @[@"channel-c"]}];

	XCTAssertEqualObjects(mergedExcluded, expectedExcluded);
}

/* A keyword limited to a channel or a network applies there only */
- (void)testChannelLimits
{
	NSArray *dictionaries = @[
		@{@"string" : @"everywhere"},
		@{@"string" : @"one", @"limitedTo" : @[@"channel-a"], @"sound" : @"Glass"},
		@{@"string" : @"network", @"limitedTo" : @[@"server-1"]},
		@{@"string" : @""}
	];

	NSArray<IRCHighlightKeyword *> *keywords = [IRCHighlightKeyword keywordsWithDictionaries:dictionaries];

	XCTAssertEqual(keywords.count, (NSUInteger)3);

	XCTAssertTrue([keywords[0] appliesToChannelWithId:@"channel-z" clientId:@"server-2"]);

	XCTAssertTrue([keywords[1] appliesToChannelWithId:@"channel-a" clientId:@"server-1"]);
	XCTAssertFalse([keywords[1] appliesToChannelWithId:@"channel-b" clientId:@"server-1"]);
	XCTAssertEqualObjects(keywords[1].sound, @"Glass");

	XCTAssertTrue([keywords[2] appliesToChannelWithId:@"channel-b" clientId:@"server-1"]);
	XCTAssertFalse([keywords[2] appliesToChannelWithId:@"channel-a" clientId:@"server-2"]);
}

@end

NS_ASSUME_NONNULL_END
