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

@end
