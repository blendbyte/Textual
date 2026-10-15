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
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "IRCChannelConfig.h"
#import "IRCChannelPrivate.h"
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

/* A long line in alternating colours: the split must not repeat or lose text
 (wrapping used to reach back into the previous colour and miscount its codes) */
- (void)testLongColouredLinesSplitWithoutRepeating
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	NSMutableAttributedString *line = [NSMutableAttributedString new];

	/* Two words per colour, so that a message fills up inside a colour */
	for (NSUInteger i = 0; i < 150; i++) {
		NSDictionary *attributes = @{IRCTextFormatterForegroundColorAttributeName : @((i % 2 == 0) ? 4 : 12)};

		NSString *words = [NSString stringWithFormat:@"w%03lu w%03lu ", (unsigned long)(i * 2), (unsigned long)(i * 2 + 1)];

		[line appendAttributedString:[[NSAttributedString alloc] initWithString:words attributes:attributes]];
	}

	/* A copy: -string is the live backing store, which the split empties */
	NSString *expected = [line.string copy];

	NSMutableString *joined = [NSMutableString string];

	NSUInteger messageCount = 0;

	while (line.length > 0 && messageCount < 50) {
		[joined appendString:[line stringFormattedForChannel:@"#channel" onClient:client withLineType:TVCLogLineTypePrivateMessage].stripIRCEffects];

		messageCount += 1;
	}

	XCTAssertGreaterThan(messageCount, 1);

	XCTAssertEqualObjects(joined, expected);
}

/* A channel's own colors and formatting choice wins over the global one, both
 ways, and is kept when the configuration is saved (10.10) */
- (void)testChannelFormattingChoiceOverridesGlobal
{
	BOOL savedRemove = [TPCPreferences removeAllFormatting];

	IRCChannelConfigMutable *config = [IRCChannelConfigMutable new];

	config.channelName = @"#textual";

	for (NSNumber *globalRemove in @[@NO, @YES]) {
		[RZUserDefaults() setBool:globalRemove.boolValue forKey:@"RemoveIRCTextFormatting"];

		config.formatting = IRCChannelFormattingGlobal;

		XCTAssertEqual([[IRCChannel alloc] initWithConfig:config].removesFormatting, globalRemove.boolValue);

		config.formatting = IRCChannelFormattingRemove;

		XCTAssertTrue([[IRCChannel alloc] initWithConfig:config].removesFormatting);

		config.formatting = IRCChannelFormattingShow;

		XCTAssertFalse([[IRCChannel alloc] initWithConfig:config].removesFormatting);
	}

	[RZUserDefaults() setBool:savedRemove forKey:@"RemoveIRCTextFormatting"];

	IRCChannelConfig *saved = [[IRCChannelConfig alloc] initWithDictionary:config.dictionaryValue];

	XCTAssertEqual(saved.formatting, IRCChannelFormattingShow);
}

@end

NS_ASSUME_NONNULL_END
