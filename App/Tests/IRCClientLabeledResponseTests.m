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
#import "IRCMessageBatchPrivate.h"
#import "IRCTreeItemPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientLabeledResponseTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@property (nonatomic, strong) IRCChannel *channel;
@end

@implementation IRCClientLabeledResponseTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	self.client.userNickname = @"me";

	[self.client enableCapability:ClientIRCv3SupportedCapabilityBatch];
	[self.client enableCapability:ClientIRCv3SupportedCapabilityLabeledResponse];

	self.channel = [[IRCChannel alloc] initWithConfig:[IRCChannelConfig seedWithName:@"#textual"]];

	self.channel.associatedClient = self.client;

	[self.client addChannel:self.channel];
}

- (IRCMessage *)message:(NSString *)line
{
	return [[IRCMessage alloc] initWithLine:line onClient:self.client];
}

/* A command typed in a window: the line it sends, labeled */
- (NSString *)typedIn:(nullable IRCChannel *)channel sends:(NSString *)line
{
	__block NSString *sent = nil;

	[self.client performLabeledCommandFromChannel:channel block:^{
		sent = [self.client lineByLabelingLine:line];
	}];

	return sent;
}

/* Lines a typed command sends get a label, merged with tags already there;
 Textual's own lines, the connection's and a /raw line's own label don't */
- (void)testTypedCommandsAreLabeled
{
	XCTAssertEqualObjects([self typedIn:self.channel sends:@"WHOIS bob"], @"@label=t1 WHOIS bob");
	XCTAssertEqualObjects([self typedIn:self.channel sends:@"@+draft/reply=abc PRIVMSG #textual :hi"], @"@label=t2;+draft/reply=abc PRIVMSG #textual :hi");

	XCTAssertEqualObjects([self typedIn:self.channel sends:@"PONG :irc.test"], @"PONG :irc.test");
	XCTAssertEqualObjects([self typedIn:self.channel sends:@"@label=mine WHO #textual"], @"@label=mine WHO #textual");

	XCTAssertEqualObjects([self.client lineByLabelingLine:@"WHO #textual %tna,10"], @"WHO #textual %tna,10"); // our own polling

	XCTAssertEqualObjects(self.client.labeledRequests[@"t1"].command, @"WHOIS");
	XCTAssertEqual(self.client.labeledRequests[@"t1"].channel, self.channel);
	XCTAssertEqual(self.client.labeledRequests.count, (NSUInteger)2);

	/* Without batch, a labeled answer of several lines couldn't be told apart */
	[self.client disableCapability:ClientIRCv3SupportedCapabilityBatch];

	XCTAssertEqualObjects([self typedIn:self.channel sends:@"WHOIS bob"], @"WHOIS bob");
}

/* A reply with the label, or inside the labeled batch, goes to the window the
 command was typed in; once answered (or ACKed) the label is forgotten */
- (void)testRepliesGoToTheWindowOfTheirCommand
{
	(void)[self typedIn:self.channel sends:@"WHOIS bob"];
	(void)[self typedIn:nil sends:@"MOTD"];

	IRCMessage *reply = [self message:@"@label=t1 :irc.test 311 me bob b bob.test * :Bob"];

	self.client.labeledReplyRequest = [self.client labeledRequestForMessage:reply];

	XCTAssertEqual([self.client channelForReplyWithFallback:nil], self.channel);
	XCTAssertTrue([self.client processingLabeledReplyToCommand:@"WHOIS"]);
	XCTAssertFalse(self.client.processingLabeledReplyToListCommand);

	[self.client labeledMessageProcessed:reply];

	XCTAssertNil(self.client.labeledRequests[@"t1"]);

	/* Typed in the console: there, whatever is selected */
	IRCMessageBatchMessage *batch = [IRCMessageBatchMessage new];

	batch.batchToken = @"b1";
	batch.batchType = @"labeled-response";
	batch.batchIsOpen = YES;
	batch.label = @"t2";

	[(IRCMessageBatchMessageContainer *)[self.client valueForKey:@"batchMessages"] queueEntry:batch];

	IRCMessage *motdLine = [self message:@"@batch=b1 :irc.test 372 me :- Welcome"];

	self.client.labeledReplyRequest = [self.client labeledRequestForMessage:motdLine];

	XCTAssertNotNil(self.client.labeledReplyRequest);
	XCTAssertNil([self.client channelForReplyWithFallback:self.channel]);

	[self.client labeledMessageProcessed:motdLine];

	XCTAssertNotNil(self.client.labeledRequests[@"t2"]); // the batch is still open

	[self.client labeledBatchFinished:batch];

	XCTAssertNil(self.client.labeledRequests[@"t2"]);

	/* An unlabeled reply: as before */
	self.client.labeledReplyRequest = [self.client labeledRequestForMessage:[self message:@":irc.test 372 me :- Welcome"]];

	XCTAssertEqual([self.client channelForReplyWithFallback:self.channel], self.channel);
}

@end

NS_ASSUME_NONNULL_END
