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

#import "NSStringHelper.h"
#import "IRCClientPrivate.h"
#import "IRCClientConfig.h"
#import "IRCColorFormatPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCColorFormatTests : XCTestCase
@end

@implementation IRCColorFormatTests

/* \x02 bold, \x1d italic, \x1f underline, \x0f reset, \x03 colour (foreground[,background]) */
- (void)testStripsFormattingCodes
{
	NSString *formatted = @"\x02" @"bold" @"\x02 \x1d" @"italic" @"\x1d \x03" @"04red\x03 \x03" @"12,01blue on black\x0f plain";

	XCTAssertEqualObjects(formatted.stripIRCEffects, @"bold italic red blue on black plain");
}

/* What the sender does with a typed line: one message per pass until nothing is left */
- (nullable NSArray<NSString *> *)messagesForLine:(NSString *)line
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	NSMutableAttributedString *remainder = [[NSMutableAttributedString alloc] initWithString:line];

	NSMutableArray<NSString *> *messages = [NSMutableArray array];

	while (remainder.length > 0) {
		if (messages.count == 50) {
			return nil; // never ends
		}

		[messages addObject:[remainder stringFormattedForChannel:@"#channel" onClient:client withLineType:TVCLogLineTypePrivateMessage]];
	}

	return [messages copy];
}

/* Long lines are split into messages that lose nothing, also when a single
 character is longer than a message may be or the only space comes first (R2.21) */
- (void)testLongLinesSplitWithoutLoss
{
	NSMutableString *words = [NSMutableString string];

	for (NSUInteger i = 0; i < 120; i++) {
		[words appendString:@"word "];
	}

	NSMutableString *oversizedCharacter = [NSMutableString stringWithString:@"a"];

	for (NSUInteger i = 0; i < 300; i++) {
		[oversizedCharacter appendString:@"\u0301"]; // combining acute accent: one character of 601 bytes
	}

	NSString *leadingSpace = [@" " stringByPaddingToLength:700 withString:@"x" startingAtIndex:0];

	for (NSString *line in @[words, oversizedCharacter, leadingSpace]) {
		NSArray<NSString *> *messages = [self messagesForLine:line];

		XCTAssertNotNil(messages);

		XCTAssertEqualObjects([messages componentsJoinedByString:@""], line);
	}

	XCTAssertEqual([self messagesForLine:oversizedCharacter].count, 1);
}

@end

NS_ASSUME_NONNULL_END
