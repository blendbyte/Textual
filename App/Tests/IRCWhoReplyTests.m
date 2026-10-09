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

#import "IRCMessage.h"
#import "IRCWhoReplyPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCWhoReplyTests : XCTestCase
@end

@implementation IRCWhoReplyTests

- (IRCMessage *)parse:(NSString *)line
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:line onClient:nil];

	XCTAssertNotNil(message, @"Failed to parse: %@", line);

	return message;
}

/* 352: the real name follows the hop count; no account */
- (void)testWhoReply
{
	IRCWhoReply *reply = [IRCWhoReply replyFromWhoReply:[self parse:@":irc.test 352 me #textual ~bob host.test irc.test bob G*@ :0 Bob Example"]];

	XCTAssertEqualObjects(reply.channelName, @"#textual");
	XCTAssertEqualObjects(reply.nickname, @"bob");
	XCTAssertEqualObjects(reply.username, @"~bob");
	XCTAssertEqualObjects(reply.address, @"host.test");
	XCTAssertEqualObjects(reply.flags, @"G*@");
	XCTAssertEqualObjects(reply.realName, @"Bob Example");
	XCTAssertFalse(reply.accountKnown);
}

/* 354 for "%tcuhnfar,152": fixed fields, "0" means no account; other tokens are not ours */
- (void)testWhoxReply
{
	IRCWhoReply *reply = [IRCWhoReply replyFromWhoxReply:[self parse:@":irc.test 354 me 152 #textual ~bob host.test bob H@ bobsaccount :Bob Example"]];

	XCTAssertEqualObjects(reply.nickname, @"bob");
	XCTAssertEqualObjects(reply.flags, @"H@");
	XCTAssertEqualObjects(reply.realName, @"Bob Example");
	XCTAssertTrue(reply.accountKnown);
	XCTAssertEqualObjects(reply.account, @"bobsaccount");

	IRCWhoReply *loggedOut = [IRCWhoReply replyFromWhoxReply:[self parse:@":irc.test 354 me 152 #textual ~carl host.test carl H 0 :Carl"]];

	XCTAssertTrue(loggedOut.accountKnown);
	XCTAssertNil(loggedOut.account);

	XCTAssertNil([IRCWhoReply replyFromWhoxReply:[self parse:@":irc.test 354 me 999 #textual ~bob host.test bob H bobsaccount :Bob"]]);
	XCTAssertNil([IRCWhoReply replyFromWhoxReply:[self parse:@":irc.test 354 me 152 #textual bob"]]);
}

@end

NS_ASSUME_NONNULL_END
