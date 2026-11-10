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

#import "IRCColorFormat.h"
#import "TVCInputMarkdownPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCInputMarkdownTests : XCTestCase
@end

@implementation TVCInputMarkdownTests

/* The text with each formatted run marked: <B>bold</B>, <I>, <M>onospace, <S>poiler */
- (NSString *)marked:(NSString *)string
{
	NSAttributedString *result = [TVCInputMarkdown attributedStringByApplyingMarkdown:[[NSAttributedString alloc] initWithString:string]];

	NSMutableString *marked = [NSMutableString string];

	[result enumerateAttributesInRange:NSMakeRange(0, result.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
		NSMutableString *kinds = [NSMutableString string];

		if (attributes[IRCTextFormatterBoldAttributeName]) [kinds appendString:@"B"];
		if (attributes[IRCTextFormatterItalicAttributeName]) [kinds appendString:@"I"];
		if (attributes[IRCTextFormatterMonospaceAttributeName]) [kinds appendString:@"M"];
		if (attributes[IRCTextFormatterSpoilerAttributeName]) [kinds appendString:@"S"];

		NSString *text = [result.string substringWithRange:range];

		if (kinds.length > 0) {
			[marked appendFormat:@"<%@>%@</%@>", kinds, text, kinds];
		} else {
			[marked appendString:text];
		}
	}];

	return marked;
}

- (void)testFormatting
{
	XCTAssertEqualObjects([self marked:@"this is **bold** text"], @"this is <B>bold</B> text");
	XCTAssertEqualObjects([self marked:@"_italic_, `code` and ||secret||"], @"<I>italic</I>, <M>code</M> and <S>secret</S>");
	XCTAssertEqualObjects([self marked:@"**_both_**"], @"<BI>both</BI>");
	XCTAssertEqualObjects([self marked:@"(**bracketed**)."], @"(<B>bracketed</B>).");
	XCTAssertEqualObjects([self marked:@"`**as is**`"], @"<M>**as is**</M>");
	XCTAssertEqualObjects([self marked:@"/me waves **hard**"], @"/me waves <B>hard</B>");
	XCTAssertEqualObjects([self marked:@"one **a**\nline _two_"], @"one <B>a</B>\nline <I>two</I>");
}

/* Strict: never in the middle of words, paths, links or commands */
- (void)testLeftAlone
{
	NSArray<NSString *> *unchanged = @[@"snake_case_name",
									   @"see /usr/_lib_/x",
									   @"a**b**c",
									   @"2*3*4",
									   @"**not closed",
									   @"** spaced **",
									   @"__init__",
									   @"***triple***",
									   @"https://example.com/_a_/**b**",
									   @"/mode #c +o _x_"];

	for (NSString *string in unchanged) {
		XCTAssertEqualObjects([self marked:string], string);
	}
}

/* ||spoiler|| is the classic IRC spoiler: black on black */
/* Someone called _bob_ is addressed as _bob_; a message escaped with // gets Markdown */
- (void)testNicknamesAndSlashMessages
{
	NSAttributedString *result = [TVCInputMarkdown attributedStringByApplyingMarkdown:[[NSAttributedString alloc] initWithString:@"_bob_: see _this_"] protectingNicknames:@[@"_Bob_", @"alice"]];

	XCTAssertEqualObjects(result.string, @"_bob_: see this");

	XCTAssertEqualObjects([self marked:@"//etc is **important**"], @"//etc is <B>important</B>");
}

- (void)testSpoilerColours
{
	NSAttributedString *result = [TVCInputMarkdown attributedStringByApplyingMarkdown:[[NSAttributedString alloc] initWithString:@"||x||"]];

	XCTAssertEqualObjects(result.string, @"x");
	XCTAssertEqualObjects([result attribute:IRCTextFormatterForegroundColorAttributeName atIndex:0 effectiveRange:NULL], @(1));
	XCTAssertEqualObjects([result attribute:IRCTextFormatterBackgroundColorAttributeName atIndex:0 effectiveRange:NULL], @(1));
}

@end

NS_ASSUME_NONNULL_END
