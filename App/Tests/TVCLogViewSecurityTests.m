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
#import <JavaScriptCore/JavaScriptCore.h>

#import "TVCLogRenderer.h"
#import "TVCLogScriptEventSinkPrivate.h"
#import "TVCLogViewPrivate.h"

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

/* Links the scanner finds stay clickable, but never ones that run script or
 reach local content, even if the user permits any scheme */
- (void)testScriptAndLocalSchemesNeverBecomeLinks
{
	for (NSString *link in @[@"https://example.com", @"HTTP://example.com", @"ircs://irc.libera.chat/#textual", @"mailto:a@example.com", @"ssh://host.example.com", @"webcal://example.com/cal.ics"]) {
		XCTAssertTrue([TVCLogRenderer isClickableLinkLocation:link], @"%@", link);
	}

	for (NSString *link in @[@"javascript:alert(1)", @"JavaScript:alert(1)", @" javascript:alert(1)", @"data:text/html,x", @"file:///etc/passwd", @"example.com"]) {
		XCTAssertFalse([TVCLogRenderer isClickableLinkLocation:link], @"%@", link);
	}
}

/* Message text becomes part of a script: whatever it contains, the function
 receives it unchanged and nothing else runs */
- (void)testFunctionCallArgumentsCannotEscape
{
	NSString *hostile = @"a\"b\\c'd\ne\rf\u2028g\u2029h</script><script>injected = true;</script>\");injected = true;//";

	NSArray *arguments = @[hostile, @42, @YES, [NSNull null], @[@"x", @{@"key" : @"va\"lue"}], [NSURL URLWithString:@"https://example.com/?a=1&b=2"]];

	NSString *script = [TVCLogView compiledFunctionCall:@"capture" withArguments:arguments];

	JSContext *context = [JSContext new];

	[context evaluateScript:@"var captured = null; var injected = false; function capture() { captured = Array.prototype.slice.call(arguments); }"];

	[context evaluateScript:script];

	XCTAssertNil(context.exception);
	XCTAssertFalse([context[@"injected"] toBool]);

	NSArray *captured = [context[@"captured"] toArray];

	XCTAssertEqual(captured.count, (NSUInteger)6);
	XCTAssertEqualObjects(captured[0], hostile);
	XCTAssertEqualObjects(captured[1], @42);
	XCTAssertEqualObjects(captured[2], @YES);
	XCTAssertEqualObjects(captured[3], [NSNull null]);
	XCTAssertEqualObjects(captured[4], (@[@"x", @{@"key" : @"va\"lue"}]));
	XCTAssertEqualObjects(captured[5], @"https://example.com/?a=1&b=2");
}

@end

NS_ASSUME_NONNULL_END
