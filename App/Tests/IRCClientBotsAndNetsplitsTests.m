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

#import "IRCClientConfig.h"
#import "IRCClientInternal.h"
#import "IRCISupportInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientBotsAndNetsplitsTests : XCTestCase
@end

@implementation IRCClientBotsAndNetsplitsTests

/* BOT=B names the user mode and WHO flag of bots; a value of more than one character isn't one */
- (void)testBotModeCharacter
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertNil(client.supportInfo.botModeCharacter);

	[client.supportInfo processConfigurationData:@"me BOT=B :are supported by this server"];

	XCTAssertEqualObjects(client.supportInfo.botModeCharacter, @"B");

	[client.supportInfo reset];

	[client.supportInfo processConfigurationData:@"me BOT=Bx :are supported by this server"];

	XCTAssertNil(client.supportInfo.botModeCharacter);
}

/* One line per channel: up to three people by name, more counted; servers that
 hide their links (*.net *.split) aren't named */
- (void)testNetsplitSummary
{
	NSArray *servers = @[@"irc1.test", @"irc2.test"];

	NSArray *two = @[@"alice", @"bob"];

	XCTAssertEqualObjects([IRCClient netsplitSummaryForNicknames:two servers:servers joined:NO],
						  @"Netsplit between irc1.test and irc2.test: alice and bob quit");

	NSArray *many = @[@"a", @"b", @"c", @"d", @"e"];

	XCTAssertEqualObjects([IRCClient netsplitSummaryForNicknames:many servers:servers joined:YES],
						  @"Netsplit between irc1.test and irc2.test is over: 5 people came back");

	NSArray *hidden = @[@"*.net", @"*.split"];

	XCTAssertEqualObjects([IRCClient netsplitSummaryForNicknames:@[@"alice"] servers:hidden joined:NO],
						  @"Netsplit: alice quit");
}

@end

NS_ASSUME_NONNULL_END
