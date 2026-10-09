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

#import "IRCChannelConfig.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCISupportInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientTypingTests : XCTestCase
@end

@implementation IRCClientTypingTests

/* Someone stays typing until their signal expires or is cleared */
- (void)testTypingStateExpires
{
	IRCChannel *channel = [[IRCChannel alloc] initWithConfig:[IRCChannelConfig seedWithName:@"#textual"]];

	NSDate *now = [NSDate dateWithTimeIntervalSince1970:1700000000];

	XCTAssertTrue([channel markNicknameAsTyping:@"carl" until:[now dateByAddingTimeInterval:6]]);
	XCTAssertFalse([channel markNicknameAsTyping:@"carl" until:[now dateByAddingTimeInterval:9]], @"A refresh changes nothing shown");
	XCTAssertTrue([channel markNicknameAsTyping:@"bob" until:[now dateByAddingTimeInterval:3]]);

	XCTAssertEqualObjects([channel typingNicknamesAtDate:now], (@[@"bob", @"carl"]));
	XCTAssertEqualObjects([channel typingNicknamesAtDate:[now dateByAddingTimeInterval:4]], (@[@"carl"]), @"bob's signal expired");

	XCTAssertTrue([channel clearTypingForNickname:@"carl"]);
	XCTAssertEqualObjects([channel typingNicknamesAtDate:now], (@[]));
}

/* CLIENTTAGDENY: "*" denies all client tags, "-name" makes an exception */
- (void)testClientTagDenyList
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	IRCISupportInfo *info = client.supportInfo;

	XCTAssertTrue([info isClientTagAllowed:@"typing"]);

	[info processConfigurationData:@"me CLIENTTAGDENY=*,-typing :are supported by this server"];

	XCTAssertTrue([info isClientTagAllowed:@"typing"]);
	XCTAssertFalse([info isClientTagAllowed:@"draft/react"]);

	[info processConfigurationData:@"me CLIENTTAGDENY=typing :are supported by this server"];

	XCTAssertFalse([info isClientTagAllowed:@"typing"]);
}

/* One name, two names, then a count */
- (void)testIndicatorText
{
	XCTAssertNil([IRCClient typingIndicatorTextForNicknames:@[]]);
	XCTAssertTrue([[IRCClient typingIndicatorTextForNicknames:@[@"bob"]] containsString:@"bob"]);

	NSString *two = [IRCClient typingIndicatorTextForNicknames:@[@"bob", @"carl"]];

	XCTAssertTrue([two containsString:@"bob"] && [two containsString:@"carl"]);
	XCTAssertTrue(([[IRCClient typingIndicatorTextForNicknames:@[@"a", @"b", @"c"]] containsString:@"3"]));
}

@end

NS_ASSUME_NONNULL_END
