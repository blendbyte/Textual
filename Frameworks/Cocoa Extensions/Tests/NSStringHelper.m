/* *********************************************************************
 *
 *           Copyright (c) 2024 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#import <CocoaExtensions/NSFileManagerHelper.h>
#import <CocoaExtensions/NSStringHelper.h>
#import <CocoaExtensions/NSStringTokenizer.h>

@interface CSStringHelperTests : XCTestCase
@end

@implementation CSStringHelperTests

- (BOOL)continueAfterFailure
{
	return NO;
}

- (void)testStandardizedTildePath
{
	[self testStandardizedTildePath:@"" expected:@"~"];
	[self testStandardizedTildePath:@"/" expected:@"~"];
	[self testStandardizedTildePath:@"//////" expected:@"~"];
	[self testStandardizedTildePath:@"/apple.txt" expected:@"~/apple.txt"];
	[self testStandardizedTildePath:@"///apple.txt" expected:@"~/apple.txt"];
	[self testStandardizedTildePath:@"apple.txt" expected:nil];
}

/* nil expected signals there should be no change */
- (void)testStandardizedTildePath:(NSString *)relativePath expected:(nullable NSString *)expectedPath
{
	/* Home directory will not end with a forward slash */
	NSString *homeDirectory = [NSFileManager pathOfHomeDirectoryOutsideSandbox];

	NSString *path = [homeDirectory stringByAppendingString:relativePath];

	NSString *standardizedPath = [path standardizedTildePath];

	if (expectedPath) {
		XCTAssertTrue([standardizedPath isEqualToString:expectedPath]);
	} else {
		XCTAssertTrue([standardizedPath isEqualToString:path]);
	}
}

/* Leading whitespace gave an empty token that deleted nothing, so taking
 tokens until the string was empty never ended */
- (void)testTokensWithLeadingWhitespace
{
	NSMutableString *string = [@"  first   second " mutableCopy];

	XCTAssertEqualObjects(string.getToken, @"first");
	XCTAssertEqualObjects(string.getToken, @"second");
	XCTAssertEqualObjects(string.getToken, @"");
	XCTAssertEqualObjects(string, @"");

	NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:@" one two"];

	XCTAssertEqualObjects(attributed.getToken.string, @"one");
	XCTAssertEqualObjects(attributed.string, @"two");
}

/* A regular expression that matches nothing (zero length) was found at the
 same place for ever */
- (void)testZeroLengthMatchesEnd
{
	__block NSUInteger matches = 0;

	[@"xax" enumerateMatchesOfRegularExpression:@"a*" withBlock:^(NSRange range, BOOL *stop) {
		matches += 1;

		if (matches > 10) {
			*stop = YES;
		}
	}];

	XCTAssertLessThanOrEqual(matches, 4);
}

- (void)testNumberChecks
{
	XCTAssertTrue(@"42".isPositiveWholeNumber);
	XCTAssertTrue(@"4.2".isPositiveDecimalNumber);
	XCTAssertTrue([@"-42" contentsIsOfType:(CSStringTypeWholeNumber | CSStringTypeNegativeNumber)]);
	XCTAssertFalse([@"-" contentsIsOfType:(CSStringTypeWholeNumber | CSStringTypeNegativeNumber)]);
	XCTAssertFalse(@"4.2.1".isPositiveDecimalNumber);
}

@end
