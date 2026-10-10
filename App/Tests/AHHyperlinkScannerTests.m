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

#import <AutoHyperlinks/AutoHyperlinks.h>

NS_ASSUME_NONNULL_BEGIN

@interface AHHyperlinkScannerTests : XCTestCase
@end

@implementation AHHyperlinkScannerTests

- (NSArray<NSString *> *)linksInString:(NSString *)string
{
	NSMutableArray<NSString *> *links = [NSMutableArray array];

	for (AHHyperlinkScannerResult *result in [AHHyperlinkScanner matchesInString:string]) {
		[links addObject:[string substringWithRange:result.range]];
	}

	return links;
}

/* The scan position moved by the UTF-8 length: after a link with non-ASCII
 characters the next one was cut ("ww.textualapp.com") */
- (void)testLinkAfterNonASCIILink
{
	XCTAssertEqualObjects([self linksInString:@"https://example.com/grüße www.textualapp.com"],
						  (@[@"https://example.com/grüße", @"www.textualapp.com"]));
}

/* Trailing punctuation after a link with brackets stayed when the link was
 not at the start of the message */
- (void)testTrailingPunctuationAfterBracketedLink
{
	XCTAssertEqualObjects([self linksInString:@"Look: https://en.wikipedia.org/wiki/Foo_(bar)."],
						  (@[@"https://en.wikipedia.org/wiki/Foo_(bar)"]));
}

/* An unrelated "(" earlier in the message took the link's own ")" off */
- (void)testBracketsAroundAndInsideLinks
{
	XCTAssertEqualObjects([self linksInString:@"(note https://en.wikipedia.org/wiki/Foo_(bar)"],
						  (@[@"https://en.wikipedia.org/wiki/Foo_(bar)"]));

	XCTAssertEqualObjects([self linksInString:@"(see https://example.com)"],
						  (@[@"https://example.com"]));
}

- (void)testSchemesIgnoreCase
{
	XCTAssertEqualObjects([self linksInString:@"HTTPS://EXAMPLE.COM/Page"], (@[@"HTTPS://EXAMPLE.COM/Page"]));
}

/* Top-level domains come from IANA's list; file names are not links */
- (void)testTopLevelDomains
{
	XCTAssertEqualObjects([self linksInString:@"try www.textual.dev or textualapp.app"], (@[@"www.textual.dev", @"textualapp.app"]));

	XCTAssertEqualObjects([self linksInString:@"see main.rs, readme.md and photo.notatld"], (@[]));

	XCTAssertEqualObjects([self linksInString:@"news at www.b92.rs"], (@[@"www.b92.rs"]));

	XCTAssertEqualObjects([AHHyperlinkScanner matchesInString:@"example.com"].firstObject.stringValue, @"https://example.com");
}

@end

NS_ASSUME_NONNULL_END
