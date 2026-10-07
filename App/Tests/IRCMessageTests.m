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
#import "IRCMessage.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCMessagePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCMessageTests : XCTestCase
@end

@implementation IRCMessageTests

- (IRCMessage *)parse:(NSString *)line
{
	return [self parse:line onClient:nil];
}

- (IRCMessage *)parse:(NSString *)line onClient:(nullable IRCClient *)client
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:line onClient:client];

	XCTAssertNotNil(message, @"Failed to parse: %@", line);

	return message;
}

- (IRCClient *)clientConnectedTo:(NSString *)serverAddress
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	client.supportInfo.serverAddress = serverAddress;

	return client;
}

- (void)testPrivmsgWithHostmask
{
	IRCMessage *message = [self parse:@":nick!user@host.example PRIVMSG #channel :hello: world :-)"];

	XCTAssertEqualObjects(message.command, @"PRIVMSG");
	XCTAssertEqualObjects(message.senderNickname, @"nick");
	XCTAssertEqualObjects(message.senderUsername, @"user");
	XCTAssertEqualObjects(message.senderAddress, @"host.example");
	XCTAssertFalse(message.senderIsServer);
	XCTAssertEqualObjects(message.params, (@[@"#channel", @"hello: world :-)"]));
}

- (void)testNumericFromServer
{
	IRCMessage *message = [self parse:@":irc.example.net 001 me :Welcome to the network"];

	XCTAssertEqual(message.commandNumeric, 1);
	XCTAssertTrue(message.senderIsServer);
	XCTAssertEqualObjects(message.params, (@[@"me", @"Welcome to the network"]));
}

/* Lines without a prefix come from the server. Without a client (the public
 -initWithLine: plugins use) there is no address, which used to crash. */
- (void)testLineWithoutPrefixComesFromTheServer
{
	IRCMessage *withClient = [self parse:@"PING :token" onClient:[self clientConnectedTo:@"irc.example.net"]];

	XCTAssertEqualObjects(withClient.command, @"PING");
	XCTAssertEqualObjects(withClient.params, (@[@"token"]));
	XCTAssertTrue(withClient.senderIsServer);
	XCTAssertEqualObjects(withClient.senderNickname, @"irc.example.net");

	IRCMessage *withoutClient = [self parse:@"PING :token"];

	XCTAssertTrue(withoutClient.senderIsServer);
	XCTAssertEqualObjects(withoutClient.senderNickname, @"");
}

/* A no-break space or a tab is part of a token. Splitting on it let
 "JOIN #a<NBSP>b" pass for a JOIN of "#a". */
- (void)testParametersAreSplitOnSpacesOnly
{
	IRCMessage *join = [self parse:@":nick!user@host JOIN #a b"];

	XCTAssertEqualObjects(join.params, (@[@"#a b"]));

	IRCMessage *privmsg = [self parse:@":nick!user@host PRIVMSG #a\tb :hello"];

	XCTAssertEqualObjects(privmsg.params, (@[@"#a\tb", @"hello"]));
}

/* An empty trailing parameter is a value (TOPIC #channel : clears the topic) */
- (void)testEmptyTrailingParameter
{
	IRCMessage *message = [self parse:@":nick!user@host TOPIC #channel :"];

	XCTAssertEqualObjects(message.params, (@[@"#channel", @""]));
}

- (void)testMalformedLinesAreRejected
{
	XCTAssertNil([[IRCMessage alloc] initWithLine:@""]);
	XCTAssertNil([[IRCMessage alloc] initWithLine:@"@msgid=abc"]);
	XCTAssertNil([[IRCMessage alloc] initWithLine:@":nick!user@host"]);
}

- (void)testMessageTags
{
	IRCMessage *message = [self parse:@"@msgid=abc123;example.com/flag :nick!user@host PRIVMSG #channel :tagged"];

	XCTAssertEqualObjects(message.messageTags[@"msgid"], @"abc123");
	XCTAssertEqualObjects(message.messageTags[@"example.com/flag"], @"");
	XCTAssertEqualObjects([message paramAt:1], @"tagged");
}

/* https://ircv3.net/specs/extensions/message-tags: decoded in one pass, so "\\s"
 is an escaped backslash followed by "s"; unknown escapes drop the backslash. */
- (void)testTagValueEscapes
{
	IRCMessage *message = [self parse:@"@a=semi\\:colon\\sspace\\\\backslash;b=x\\\\sy;c=\\q :nick!user@host PRIVMSG #channel :x"];

	XCTAssertEqualObjects(message.messageTags[@"a"], @"semi;colon space\\backslash");
	XCTAssertEqualObjects(message.messageTags[@"b"], @"x\\sy");
	XCTAssertEqualObjects(message.messageTags[@"c"], @"q");
}

/* time= is honoured only when server-time was negotiated */
- (void)testServerTime
{
	NSString *line = @"@time=2026-01-02T03:04:05.000Z :nick!user@host PRIVMSG #channel :old";

	IRCClient *client = [self clientConnectedTo:@"irc.example.net"];

	XCTAssertFalse([self parse:line onClient:client].isHistoric);

	[client enableCapability:ClientIRCv3SupportedCapabilityServerTime];

	IRCMessage *message = [self parse:line onClient:client];

	XCTAssertTrue(message.isHistoric);
	XCTAssertEqualWithAccuracy(message.receivedAt.timeIntervalSince1970, 1767323045.0, 0.001);
}

/* Messages from a playback batch must keep it when copied, or they are
 treated as live and trigger notifications. */
- (void)testCopiesKeepTheirBatch
{
	IRCClient *client = [self clientConnectedTo:@"irc.example.net"];

	[client enableCapability:ClientIRCv3SupportedCapabilityBatch];

	IRCMessageBatchMessage *batch = [IRCMessageBatchMessage new];

	batch.batchToken = @"abc";
	batch.batchIsOpen = YES;

	[(IRCMessageBatchMessageContainer *)[client valueForKey:@"batchMessages"] queueEntry:batch];

	IRCMessage *message = [self parse:@"@batch=abc :nick!user@host PRIVMSG #channel :from playback" onClient:client];

	IRCMessage *copy = [message copy];
	IRCMessage *mutableCopy = [message mutableCopy];

	XCTAssertEqual(message.parentBatchMessage, batch);
	XCTAssertEqual(copy.parentBatchMessage, batch);
	XCTAssertEqual(mutableCopy.parentBatchMessage, batch);
}

@end

NS_ASSUME_NONNULL_END
