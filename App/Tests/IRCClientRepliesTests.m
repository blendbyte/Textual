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
#import "IRCClientPrivate.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientRepliesTests : XCTestCase
@end

@implementation IRCClientRepliesTests

/* +reply names the message answered; an ID with a space can't go back to the server */
- (void)testReplyTag
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	IRCMessage *reply = [[IRCMessage alloc] initWithLine:@"@msgid=m2;+reply=m1 :alice!a@a.test PRIVMSG #c :yes" onClient:client];

	XCTAssertEqualObjects(reply.msgid, @"m2");
	XCTAssertEqualObjects(reply.replyToMsgid, @"m1");

	IRCMessage *broken = [[IRCMessage alloc] initWithLine:@"@+reply=a\\sb :alice!a@a.test PRIVMSG #c :yes" onClient:client];

	XCTAssertNil(broken.replyToMsgid);
}

/* Replies need message-tags and a server that doesn't deny +reply */
- (void)testCanSendReplies
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertFalse(client.canSendReplies);

	[client enableCapability:ClientIRCv3SupportedCapabilityMessageTags];

	XCTAssertTrue(client.canSendReplies);

	client.outgoingReplyMsgid = @"m1";

	XCTAssertEqualObjects(client.outgoingReplyMsgid, @"m1");

	[client.supportInfo processConfigurationData:@"me CLIENTTAGDENY=* :are supported by this server"];

	XCTAssertFalse(client.canSendReplies);

	client.outgoingReplyMsgid = @"m1";

	XCTAssertNil(client.outgoingReplyMsgid);
}

@end

NS_ASSUME_NONNULL_END
