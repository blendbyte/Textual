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
#import "IRCISupportInfoPrivate.h"
#import "IRCMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientChatHistoryTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@property (nonatomic, strong) IRCChannel *channel;
@end

@implementation IRCClientChatHistoryTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	self.client.userNickname = @"me";

	[self.client enableCapability:ClientIRCv3SupportedCapabilityServerTime];

	self.channel = [[IRCChannel alloc] initWithConfig:[IRCChannelConfig seedWithName:@"#textual"]];
}

/* A channel message with an ID, sent seconds after the given time */
- (IRCMessage *)message:(NSString *)msgid from:(NSString *)nickname at:(NSTimeInterval)seconds
{
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(1700000000 + seconds)];

	NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];

	formatter.formatOptions = (NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds);

	NSString *line = [NSString stringWithFormat:@"@msgid=%@;time=%@ :%@!u@host.test PRIVMSG #textual :hello",
					  msgid, [formatter stringFromDate:date], nickname];

	IRCMessage *message = [[IRCMessage alloc] initWithLine:line onClient:self.client];

	XCTAssertNotNil(message, @"Failed to parse: %@", line);

	return message;
}

/* The request asks for the messages after the newest one seen, at most 100 or the server's limit */
- (void)testRequestIsAnchoredOnTheNewestMessage
{
	XCTAssertNil([self.client chatHistoryRequestForChannel:self.channel], @"Nothing seen, nothing to ask for");

	[self.client chatHistoryShouldSkipMessage:[self message:@"new" from:@"bob" at:20] inChannel:self.channel fromHistory:NO];
	[self.client chatHistoryShouldSkipMessage:[self message:@"old" from:@"bob" at:10] inChannel:self.channel fromHistory:YES];

	XCTAssertEqualObjects([self.client chatHistoryRequestForChannel:self.channel], @"CHATHISTORY LATEST #textual msgid=new 100",
						  @"A batch processed after a newer line doesn't move the anchor back");

	[self.client.supportInfo processConfigurationData:@"me CHATHISTORY=50 :are supported by this server"];

	XCTAssertEqualObjects([self.client chatHistoryRequestForChannel:self.channel], @"CHATHISTORY LATEST #textual msgid=new 50");
}

/* Backfilled lines already shown, and our own lines from before the connection ended, are skipped */
- (void)testBackfillSkipsWhatIsOnScreen
{
	XCTAssertFalse([self.client chatHistoryShouldSkipMessage:[self message:@"a" from:@"bob" at:10] inChannel:self.channel fromHistory:NO]);
	XCTAssertTrue([self.client chatHistoryShouldSkipMessage:[self message:@"a" from:@"bob" at:10] inChannel:self.channel fromHistory:YES]);
	XCTAssertFalse([self.client chatHistoryShouldSkipMessage:[self message:@"b" from:@"bob" at:30] inChannel:self.channel fromHistory:YES]);

	self.client.chatHistoryDisconnectTime = [NSDate dateWithTimeIntervalSince1970:(1700000000 + 40)];

	XCTAssertTrue([self.client chatHistoryShouldSkipMessage:[self message:@"c" from:@"me" at:35] inChannel:self.channel fromHistory:YES],
				  @"Sent before the connection ended: already shown");
	XCTAssertFalse([self.client chatHistoryShouldSkipMessage:[self message:@"d" from:@"me" at:50] inChannel:self.channel fromHistory:YES],
				   @"Sent from another client while we were away");
}

@end

NS_ASSUME_NONNULL_END
