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

#import <CocoaExtensions/CocoaExtensions.h>

NS_ASSUME_NONNULL_BEGIN

@interface CSHelperTests : XCTestCase
@end

@implementation CSHelperTests

/* A number stored as a string (an imported or hand-edited configuration)
 crashed the accessors NSString has no method for */
- (void)testNumbersStoredAsStrings
{
	NSDictionary *dictionary = @{@"port" : @"6697", @"count" : @(3)};

	XCTAssertEqual([dictionary unsignedShortForKey:@"port"], 6697);
	XCTAssertEqual([dictionary unsignedIntegerForKey:@"port"], 6697);
	XCTAssertEqual([dictionary longForKey:@"count"], 3);

	NSArray *array = @[@"21", @(5)];

	XCTAssertEqual([array unsignedShortAtIndex:0], 21);
	XCTAssertEqual([array shortAtIndex:1], 5);
}

/* A channel of 01 was full intensity: #010101 rendered white */
- (void)testHexadecimalColors
{
	NSColor *color = [NSColor colorWithHexadecimalValue:@"#010101"];

	XCTAssertEqualWithAccuracy(color.redComponent, (1.0 / 255.0), 0.0001);
	XCTAssertEqualWithAccuracy(color.alphaComponent, 1.0, 0.0001);

	XCTAssertEqualWithAccuracy([NSColor colorWithHexadecimalValue:@"ff000080"].alphaComponent, (128.0 / 255.0), 0.0001);

	XCTAssertNil([NSColor colorWithHexadecimalValue:@"#zz0000"]);
	XCTAssertNil([NSColor colorWithHexadecimalValue:@"#fff"]);
}

/* The destination was removed before copying: a copy that failed lost it */
- (void)testFailedReplaceKeepsDestination
{
	NSURL *folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	[[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:NULL];

	NSURL *destination = [folder URLByAppendingPathComponent:@"destination.txt"];
	NSURL *source = [folder URLByAppendingPathComponent:@"source.txt"];

	[@"keep me" writeToURL:destination atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	XCTAssertFalse([[NSFileManager defaultManager] replaceItemAtURL:destination withItemAtURL:source options:CSFileManagerOptionsRemoveIfExists]);

	XCTAssertEqualObjects([NSString stringWithContentsOfURL:destination encoding:NSUTF8StringEncoding error:NULL], @"keep me");

	[@"new" writeToURL:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	XCTAssertTrue([[NSFileManager defaultManager] replaceItemAtURL:destination withItemAtURL:source options:CSFileManagerOptionsRemoveIfExists]);

	XCTAssertEqualObjects([NSString stringWithContentsOfURL:destination encoding:NSUTF8StringEncoding error:NULL], @"new");

	XCTAssertEqual([[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder.path error:NULL].count, 2);

	[[NSFileManager defaultManager] removeItemAtURL:folder error:NULL];
}

@end

NS_ASSUME_NONNULL_END
