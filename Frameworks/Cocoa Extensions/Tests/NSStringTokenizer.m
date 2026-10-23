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

#import <CocoaExtensions/NSStringTokenizer.h>

@interface CSStringTokenizerTests : XCTestCase
@end

@implementation CSStringTokenizerTests

- (BOOL)continueAfterFailure
{
	return NO;
}

- (void)testGoodQuoteGroups
{
	/* Testing default configuration:
	 Collapse quotes, terminate in whitespace, double quote only */
	/* In Xcode two slashes = one because Xcode does similar
	 collapse logic so keep that in mind. */
	NSDictionary *goodGroups = @{
		@"\"\"" 						: @"",					// ""
		@"\"test\"" 					: @"test",				// "test"
		@"\"test\" Test" 				: @"test",				// "test" Test
		@"\"test\" \"Test\"" 			: @"test",				// "test" "Test"
		@"\"test\\\"    \"" 			: @"test\"    ",		// "test\"   "
		@"\"test\\\\ \\\" \"" 			: @"test\\ \" ",		// "test\\ \" "
		@"\"test \\\\\\\\\\\\  \""		: @"test \\\\\\  ",		// "test \\\\\\  "
		@"\"test \\\\\\\\\\\\\""		: @"test \\\\\\",		// "test \\\\\\"
		@"\"\\\\\\\\\\\\\""				: @"\\\\\\",			// "\\\\\\"
		@"\"\\\\\\\\\\\\test\""			: @"\\\\\\test",		// "\\\\\\test"
		@"\"\\\\\\\\\\\\\\\"test\""		: @"\\\\\\\"test",		// "\\\\\\\"test"
		@"\"\\\"\\\"\\\"\\\"\""			: @"\"\"\"\"",			// "\"\"\"\""
	};

	[self testGoodQuoteGroups:goodGroups options:CSStringQuoteGroupOptionsDefault];
}

- (void)testBadQuoteGroups
{
	NSArray *badGroups = @[
		@"\"\\\"",						// "\"
		@"\"test'",						// "test'
		@"'test\"",						// 'test"
		@"'\"test\"",					// '"test"
		@"\"test\"Test",				// "test"Test
		@"\"test\"\"Test\"",			// "test""Test"
		@"\"test\\\\\"\""				// "test\\""
	];

	[self testBadQuoteGroups:badGroups options:CSStringQuoteGroupOptionsDefault];
}

- (void)testGoodQuoteGroups:(NSDictionary<NSString *, NSString *> *)quoteGroups options:(CSStringQuoteGroupOptions)options
{
	[quoteGroups enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
		[key getTokenFromQuoteGroupWithBlock:^(NSString *token, NSRange tokenRange, NSRange deletionRange) {
			NSLog(@"Testing good group:\n\tInput: %@\n\tExpected output: %@\n\tAtctual output: %@", key, obj, token);

			XCTAssertTrue([token isEqualToString:obj]);
		} options:options];
	}];
}

- (void)testBadQuoteGroups:(NSArray<NSString *> *)quoteGroups options:(CSStringQuoteGroupOptions)options
{
	[quoteGroups enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
		[obj getTokenFromQuoteGroupWithBlock:^(NSString *token, NSRange tokenRange, NSRange deletionRange) {
			NSLog(@"Testing bad group:\n\tInput: %@\n\tOutput: %@", obj, token);

			XCTAssertTrue(token == nil);
		} options:options];
	}];
}

@end
