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

#import <CocoaExtensions/NSUserDefaultsHelper.h>

NS_ASSUME_NONNULL_BEGIN

@interface CSUserDefaultsHelperTests : XCTestCase
@end

@implementation CSUserDefaultsHelperTests

/* Saving a colour raised in Debug builds (an inverted assertion), which
 crashed Textual when a colour was picked in Preferences */
- (void)testColorIsSavedAndReadBack
{
	NSString *suiteName = [NSString stringWithFormat:@"textual.test.%@", [NSUUID UUID].UUIDString];

	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];

	NSColor *color = [NSColor colorWithSRGBRed:0.2 green:0.4 blue:0.6 alpha:0.8];

	XCTAssertNoThrow([defaults setColor:color forKey:@"Color"]);

	XCTAssertEqualObjects([defaults colorForKey:@"Color"], color);

	[defaults setColor:nil forKey:@"Color"];

	XCTAssertNil([defaults colorForKey:@"Color"]);

	[defaults removePersistentDomainForName:suiteName];
}

@end

NS_ASSUME_NONNULL_END
