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
#import "IRCMessage.h"
#import "IRCMessageBatchPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientMultilineTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@end

@implementation IRCClientMultilineTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	self.client.userNickname = @"me";

	[self.client enableCapability:ClientIRCv3SupportedCapabilityBatch];
	[self.client enableCapability:ClientIRCv3SupportedCapabilityMultiline];
}

- (NSArray<NSString *> *)textsOf:(NSArray<IRCClientMultilinePart *> *)batch
{
	NSMutableArray *texts = [NSMutableArray array];

	for (IRCClientMultilinePart *part in batch) {
		[texts addObject:((part.concat) ? [@"+" stringByAppendingString:part.text] : part.text)];
	}

	return texts;
}

/* max-bytes is required (no multi-line messages without it); max-lines and
 unknown tokens are optional */
- (void)testCapabilityValue
{
	XCTAssertTrue([self.client processMultilineCapabilityValue:@"max-bytes=4096,max-lines=24,future=1"]);
	XCTAssertEqual(self.client.multilineMaxBytes, (NSUInteger)4096);
	XCTAssertEqual(self.client.multilineMaxLines, (NSUInteger)24);
	XCTAssertTrue(self.client.multilineUsable);

	XCTAssertFalse([self.client processMultilineCapabilityValue:@"max-lines=24"]);
	XCTAssertFalse(self.client.multilineUsable);
}

/* Batches keep to max-bytes (line breaks count, joined pieces don't add one)
 and max-lines; a batch never starts with a joined piece or a blank line */
- (void)testBatchesKeepToTheLimits
{
	NSArray *parts = @[
		[IRCClientMultilinePart partWithText:@"aaaaa" concat:NO],
		[IRCClientMultilinePart partWithText:@"bbbbb" concat:NO],
		[IRCClientMultilinePart partWithText:@"ccccc" concat:YES],
		[IRCClientMultilinePart partWithText:@"" concat:NO],
		[IRCClientMultilinePart partWithText:@"ddddd" concat:NO]
	];

	NSArray *batches = [IRCClient multilineBatchesOfParts:parts maxBytes:16 maxLines:0];

	XCTAssertEqual(batches.count, (NSUInteger)2);

	NSArray *expected = @[@"aaaaa", @"bbbbb", @"+ccccc"];

	XCTAssertEqualObjects([self textsOf:batches[0]], expected); // 5 + 1 + 5 + 5 = 16

	expected = @[@"ddddd"];

	XCTAssertEqualObjects([self textsOf:batches[1]], expected); // the blank line between doesn't start a batch

	batches = [IRCClient multilineBatchesOfParts:parts maxBytes:100 maxLines:2];

	expected = @[@"ccccc"];

	XCTAssertEqualObjects([self textsOf:batches[1]], expected); // blank at its end dropped
	XCTAssertEqual(batches.count, (NSUInteger)3);

	XCTAssertEqualObjects([IRCClient multilineTextOfParts:parts], @"aaaaa\nbbbbbccccc\n\nddddd");
}

/* Typed lines become parts; a line too long for one message goes in pieces
 that join back to exactly what was typed */
- (void)testTypedLinesBecomeParts
{
	[self.client processMultilineCapabilityValue:@"max-bytes=4096"];

	NSArray *lines = @[
		[[NSAttributedString alloc] initWithString:@""],
		[[NSAttributedString alloc] initWithString:@"first"],
		[[NSAttributedString alloc] initWithString:@""],
		[[NSAttributedString alloc] initWithString:@"second"],
		[[NSAttributedString alloc] initWithString:@""]
	];

	NSArray *batches = [self.client multilineBatchesForLines:lines target:@"#textual" lineType:TVCLogLineTypePrivateMessage];

	NSArray *expected = @[@"first", @"", @"second"];

	XCTAssertEqualObjects([self textsOf:batches.firstObject], expected);

	NSMutableArray *words = [NSMutableArray array];

	for (NSUInteger i = 0; i < 120; i++) {
		[words addObject:[NSString stringWithFormat:@"word%lu", i]];
	}

	NSString *longLine = [words componentsJoinedByString:@" "];

	batches = [self.client multilineBatchesForLines:@[[[NSAttributedString alloc] initWithString:longLine]] target:@"#textual" lineType:TVCLogLineTypePrivateMessage];

	XCTAssertEqual(batches.count, (NSUInteger)1);
	XCTAssertGreaterThan([batches.firstObject count], (NSUInteger)1);
	IRCClientMultilinePart *secondPiece = batches.firstObject[1];

	XCTAssertTrue(secondPiece.concat);
	XCTAssertEqualObjects([IRCClient multilineTextOfParts:batches.firstObject], longLine);

	/* One short line: an ordinary message; an action: never multi-line */
	XCTAssertNil([self.client multilineBatchesForLines:@[[[NSAttributedString alloc] initWithString:@"hi"]] target:@"#textual" lineType:TVCLogLineTypePrivateMessage]);
	XCTAssertNil([self.client multilineBatchesForLines:lines target:@"#textual" lineType:TVCLogLineTypeAction]);
}

/* A received batch is one message: lines joined (with or without a break),
 the batch's msgid and time */
- (void)testReceivedBatchIsOneMessage
{
	IRCMessageBatchMessage *batch = [IRCMessageBatchMessage new];

	batch.batchToken = @"m1";
	batch.batchType = @"draft/multiline";
	batch.openingMessage = [[IRCMessage alloc] initWithLine:@"@msgid=abc;time=2026-10-15T10:00:00.000Z :alice!a@alice.test BATCH +m1 draft/multiline #textual" onClient:self.client];

	for (NSString *line in @[@"@batch=m1 :alice!a@alice.test PRIVMSG #textual :hello",
							 @"@batch=m1;draft/multiline-concat :alice!a@alice.test PRIVMSG #textual : world",
							 @"@batch=m1 :alice!a@alice.test PRIVMSG #textual :second line"])
	{
		[batch queueEntry:[[IRCMessage alloc] initWithLine:line onClient:self.client]];
	}

	IRCMessage *message = [self.client messageCombiningMultilineBatch:batch];

	XCTAssertEqualObjects(message.command, @"PRIVMSG");
	XCTAssertEqualObjects([message paramAt:0], @"#textual");
	XCTAssertEqualObjects(message.params.lastObject, @"hello world\nsecond line");
	XCTAssertEqualObjects(message.msgid, @"abc");
	XCTAssertEqualObjects(message.receivedAt, batch.openingMessage.receivedAt);
	XCTAssertEqualObjects(message.senderNickname, @"alice");
}

@end

NS_ASSUME_NONNULL_END
