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

NS_ASSUME_NONNULL_BEGIN

/* TLOLinkParser is written in Swift; its generated header is not installed. */
@interface TLOLinkParser : NSObject
+ (NSArray<AHHyperlinkScannerResult *> *)locateLinksInString:(NSString *)string;
@end

@interface TLOLinkParserTests : XCTestCase
@end

@implementation TLOLinkParserTests

- (void)testFindsWebLinkWithoutTrailingPunctuation
{
	NSString *text = @"Read https://www.textualapp.com/docs.";

	NSArray *links = [TLOLinkParser locateLinksInString:text];

	XCTAssertEqual(links.count, 1);

	AHHyperlinkScannerResult *link = links.firstObject;

	XCTAssertEqualObjects([text substringWithRange:link.range], @"https://www.textualapp.com/docs");
	XCTAssertTrue(link.strictMatch);
}

- (void)testFindsIRCLink
{
	NSArray *links = [TLOLinkParser locateLinksInString:@"Join us at irc://irc.libera.chat/#textual today"];

	XCTAssertEqual(links.count, 1);
	XCTAssertEqualObjects([links.firstObject stringValue], @"irc://irc.libera.chat/#textual");
}

- (void)testFindsSchemelessDomain
{
	NSArray *links = [TLOLinkParser locateLinksInString:@"see example.com for details"];

	XCTAssertEqual(links.count, 1);
	XCTAssertFalse([links.firstObject strictMatch]);
}

- (void)testPlainTextHasNoLinks
{
	XCTAssertEqual([TLOLinkParser locateLinksInString:@"just a normal sentence, nothing to see"].count, 0);
}

@end

NS_ASSUME_NONNULL_END
