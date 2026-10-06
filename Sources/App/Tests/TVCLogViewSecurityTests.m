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

#import "TVCLogRenderer.h"
#import "TVCLogScriptEventSinkPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogRenderer (Testing)
+ (BOOL)isClickableLinkLocation:(NSString *)linkLocation;
@end

@interface TVCLogViewSecurityTests : XCTestCase
@end

@implementation TVCLogViewSecurityTests

/* A style reads only listed preferences; this used to call any class method */
- (void)testStylesReadOnlyListedPreferences
{
	XCTAssertNotNil([TVCLogScriptEventSink valueOfPreferenceReadableByStyles:@"themeName"]);
	XCTAssertTrue([[TVCLogScriptEventSink valueOfPreferenceReadableByStyles:@"showInlineMedia"] isKindOfClass:[NSNumber class]]);

	XCTAssertNil([TVCLogScriptEventSink valueOfPreferenceReadableByStyles:@"defaultNickname"]);
	XCTAssertNil([TVCLogScriptEventSink valueOfPreferenceReadableByStyles:@"exportedPreferencesDictionary"]);
	XCTAssertNil([TVCLogScriptEventSink valueOfPreferenceReadableByStyles:@"alloc"]);
}

/* Only these schemes become clickable; javascript: and the like stay text */
- (void)testOnlySafeSchemesBecomeLinks
{
	for (NSString *link in @[@"https://example.com", @"HTTP://example.com", @"ircs://irc.libera.chat/#textual", @"mailto:a@example.com"]) {
		XCTAssertTrue([TVCLogRenderer isClickableLinkLocation:link], @"%@", link);
	}

	for (NSString *link in @[@"javascript:alert(1)", @"JavaScript:alert(1)", @"data:text/html,x", @"file:///etc/passwd", @"example.com"]) {
		XCTAssertFalse([TVCLogRenderer isClickableLinkLocation:link], @"%@", link);
	}
}

@end

NS_ASSUME_NONNULL_END
