/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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

#import "GTMEncodeHTML.h"
#import "TVCLogRendererPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogRendererTests : XCTestCase
@end

@implementation TVCLogRendererTests

- (NSArray<NSString *> *)channelNamesInString:(NSString *)string prefixes:(NSArray<NSString *> *)prefixes
{
	NSMutableArray *names = [NSMutableArray array];

	for (NSValue *range in [TVCLogRenderer channelNameRangesInString:string withPrefixes:prefixes]) {
		[names addObject:[string substringWithRange:range.rangeValue]];
	}

	return names;
}

/* Channel names are linked whole (underscores, dots inside, non-ASCII), without the
 punctuation after them, and with the server's own prefixes (CHANTYPES) */
- (void)testChannelNames
{
	NSArray *hash = @[@"#"];

	XCTAssertEqualObjects([self channelNamesInString:@"see #foo_bar and #c++" prefixes:hash], (@[@"#foo_bar", @"#c++"]));
	XCTAssertEqualObjects([self channelNamesInString:@"join #textual." prefixes:hash], (@[@"#textual"]));
	XCTAssertEqualObjects([self channelNamesInString:@"(#a.b) #chän!" prefixes:hash], (@[@"#a.b", @"#chän"]));
	XCTAssertEqualObjects([self channelNamesInString:@"#one,#two" prefixes:hash], (@[@"#one", @"#two"]));
	XCTAssertEqualObjects([self channelNamesInString:@"a lone # sign" prefixes:hash], (@[]));

	XCTAssertEqualObjects([self channelNamesInString:@"&local #global" prefixes:hash], (@[@"#global"]));
	XCTAssertEqualObjects([self channelNamesInString:@"&local #global" prefixes:(@[@"#", @"&"])], (@[@"&local", @"#global"]));
}

/* Nicknames are found without searching for every member: the candidates must
 include every nickname the old search found, and never part of a word */
- (void)testNicknameCandidates
{
	NSString *message = @"hey [bob], ab-cd and bobby: x_y";

	NSMutableSet *candidates = [NSMutableSet set];

	for (NSValue *range in [TVCLogRenderer nicknameCandidateRangesInString:message]) {
		[candidates addObject:[message substringWithRange:range.rangeValue]];
	}

	for (NSString *expected in @[@"hey", @"bob", @"[bob]", @"ab", @"cd", @"ab-cd", @"bobby", @"x_y", @"x", @"y"]) {
		XCTAssertTrue([candidates containsObject:expected], @"%@", expected);
	}

	for (NSString *unexpected in @[@"bo", @"ob", @"bobb", @"by", @"b-c", @"bob]," ]) {
		XCTAssertFalse([candidates containsObject:unexpected], @"%@", unexpected);
	}
}

/* A long run of special characters made a candidate for every pair of them:
 one message of dashes took seconds to render */
- (void)testNicknameCandidatesOfLongSpecialRun
{
	NSString *message = [@"" stringByPaddingToLength:20000 withString:@"-" startingAtIndex:0];

	NSDate *start = [NSDate date];

	NSArray *candidates = [TVCLogRenderer nicknameCandidateRangesInString:message];

	XCTAssertLessThanOrEqual(candidates.count, 4096);
	XCTAssertLessThan(-start.timeIntervalSinceNow, 1.0);
}

/* Message text is escaped before it goes into the chat view's HTML; the
 escaping skips text that needs none */
- (void)testHTMLEscaping
{
	XCTAssertEqualObjects(@"plain text, nothing to do".gtm_stringByEscapingForHTML, @"plain text, nothing to do");

	XCTAssertEqualObjects(@"<b>\"Tom\" & 'Jerry'</b>".gtm_stringByEscapingForHTML,
						  @"&lt;b&gt;&quot;Tom&quot; &amp; &apos;Jerry&apos;&lt;/b&gt;");

	/* Other characters of the table are named; the rest stays as it is */
	XCTAssertEqualObjects(@"5 \u20AC – Ü".gtm_stringByEscapingForHTML, @"5 &euro; &ndash; Ü");
}

/* Every color span a message opens is closed once, never before it is opened.
 A span left open swallows what follows the message (its time, its inline
 media); one closed too often ends the message early. */
- (void)testColorSpansAreBalanced
{
	NSString *fg = TVCLogRendererFormattingForegroundColorAttribute;
	NSString *bg = TVCLogRendererFormattingBackgroundColorAttribute;

	NSArray<NSArray<NSDictionary *> *> *messages = @[
		@[@{fg : @4}],							// "\x034all red"
		@[@{}, @{fg : @4}, @{}, @{fg : @15}],	// "x \x034red\x03 \x0315last\x03"
		@[@{fg : @4}, @{}],						// "\x034red\x03 plain"
		@[@{fg : @4}, @{fg : @4}],				// one color over two fragments (a link)
		@[@{fg : @4}, @{fg : @5}],				// "\x034red\x035maroon"
		@[@{fg : @8, bg : @1}, @{fg : @8}],		// "\x038,1on black\x03\x038yellow"
		@[@{}, @{}],
	];

	for (NSArray<NSDictionary *> *fragments in messages) {
		TVCLogRenderer *renderer = [TVCLogRenderer new];

		NSInteger open = 0;

		for (NSUInteger i = 0; i < fragments.count; i++) {
			NSMutableDictionary *tokens = [NSMutableDictionary dictionary];

			[renderer addColorTokens:tokens forAttributes:fragments[i] isFirstFragment:(i == 0) isLastFragment:(i == (fragments.count - 1))];

			/* The template closes the previous span, opens one, then closes at the end */
			open -= [tokens boolForKey:@"fragmentTextColorClosedAtStart"];

			XCTAssertGreaterThanOrEqual(open, 0, @"%@", fragments);

			open += [tokens boolForKey:@"fragmentTextColorOpened"];
			open -= [tokens boolForKey:@"fragmentTextColorClosedAtEnd"];

			XCTAssertGreaterThanOrEqual(open, 0, @"%@", fragments);
		}

		XCTAssertEqual(open, 0, @"%@", fragments);
	}
}

@end

NS_ASSUME_NONNULL_END
