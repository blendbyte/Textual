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
#import "IRCClientInternal.h"
#import "IRCMessage.h"
#import "IRCTreeItemPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientFailedSendsTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@property (nonatomic, strong) IRCChannel *channel;
@end

@implementation IRCClientFailedSendsTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	self.client.userNickname = @"me";

	self.channel = [[IRCChannel alloc] initWithConfig:[IRCChannelConfig seedWithName:@"#textual"]];

	self.channel.associatedClient = self.client;

	[self.client addChannel:self.channel];
}

/* A message to #textual, shown at once (its line named after its text) */
- (IRCClientOutgoingMessage *)send:(NSString *)text
{
	IRCClientOutgoingMessage *outgoing = [self.client outgoingMessageWithText:text target:@"#textual" command:@"PRIVMSG" lineType:TVCLogLineTypePrivateMessage channel:self.channel];

	outgoing.printedLocally = YES;
	outgoing.lineNumber = text;

	[self.client sendOutgoingMessage:outgoing usingBlock:^{
		(void)[self.client lineByLabelingLine:[@"PRIVMSG #textual :" stringByAppendingString:text]];
	}];

	return outgoing;
}

- (BOOL)refuses:(NSString *)line
{
	IRCMessage *m = [[IRCMessage alloc] initWithLine:line onClient:self.client];

	self.client.labeledReplyRequest = [self.client labeledRequestForMessage:m];

	BOOL refused = [self.client outgoingMessageFailedWithReply:m];

	self.client.labeledReplyRequest = nil;

	return refused;
}

/* With labels the refusal names its message, and an error to another command isn't one */
- (void)testLabeledRefusalIsExact
{
	[self.client enableCapability:ClientIRCv3SupportedCapabilityBatch];
	[self.client enableCapability:ClientIRCv3SupportedCapabilityLabeledResponse];

	IRCClientOutgoingMessage *first = [self send:@"first"];
	IRCClientOutgoingMessage *second = [self send:@"second"];

	XCTAssertEqualObjects(first.label, @"t1");
	XCTAssertEqualObjects(second.label, @"t2");

	XCTAssertTrue([self refuses:@"@label=t2 :irc.test 404 me #textual :Cannot send to channel"]);

	XCTAssertEqualObjects(second.failedReason, @"Cannot send to channel");
	XCTAssertNil(first.failedReason);

	XCTAssertFalse([self refuses:@"@label=t9 :irc.test 404 me #textual :Cannot send to channel"]);

	/* Echoed or ACKed: taken, nothing left to refuse */
	[self.client labeledMessageProcessed:[[IRCMessage alloc] initWithLine:@"@label=t1 :irc.test ACK" onClient:self.client]];

	XCTAssertEqual(self.client.outgoingMessages.count, (NSUInteger)0);
}

/* Without labels: with echo-message the oldest not echoed; without it only a single message */
- (void)testUnlabeledRefusalOnlyWhenUnambiguous
{
	(void)[self send:@"hello"];
	(void)[self send:@"refused"];

	XCTAssertFalse([self refuses:@":irc.test 404 me #textual :Cannot send to channel"]);

	[self.client removeOutgoingMessages];

	IRCClientOutgoingMessage *single = [self send:@"single"];

	XCTAssertFalse([self refuses:@":irc.test 404 me #elsewhere :Cannot send to channel"]);
	XCTAssertTrue([self refuses:@":irc.test 404 me #textual :Cannot send to channel"]);
	XCTAssertNotNil(single.failedReason);

	[self.client enableCapability:ClientIRCv3SupportedCapabilityEchoMessage];

	(void)[self send:@"hello"];

	IRCClientOutgoingMessage *refused = [self send:@"refused"];

	[self.client outgoingMessageEchoed:[[IRCMessage alloc] initWithLine:@":me!u@client.test PRIVMSG #textual :hello" onClient:self.client]];

	XCTAssertTrue([self refuses:@":irc.test 404 me #textual :Cannot send to channel"]);
	XCTAssertNotNil(refused.failedReason);
}

/* The echo of a line Textual sent itself (the NickServ password) shows nowhere, taken once */
- (void)testEchoOfOwnAutomaticLineIsTaken
{
	BOOL (^takes)(NSString *) = ^BOOL(NSString *line) {
		return [self.client takeSilentEcho:[[IRCMessage alloc] initWithLine:line onClient:self.client]];
	};

	[self.client noteSilentPrivmsg:@"IDENTIFY secret" to:@"NickServ"];

	XCTAssertFalse(takes(@":me!u@client.test PRIVMSG NickServ :IDENTIFY secret"), @"No echo without echo-message");

	[self.client enableCapability:ClientIRCv3SupportedCapabilityEchoMessage];

	[self.client noteSilentPrivmsg:@"IDENTIFY secret" to:@"NickServ"];

	XCTAssertFalse(takes(@":NickServ!s@services.test PRIVMSG me :IDENTIFY secret"));
	XCTAssertFalse(takes(@":me!u@client.test PRIVMSG NickServ :IDENTIFY other"));
	XCTAssertTrue(takes(@":me!u@client.test PRIVMSG nickserv :IDENTIFY secret"));
	XCTAssertFalse(takes(@":me!u@client.test PRIVMSG NickServ :IDENTIFY secret"), @"A second one is the user's");
}

@end

NS_ASSUME_NONNULL_END
