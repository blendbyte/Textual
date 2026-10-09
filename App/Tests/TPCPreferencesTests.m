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

#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReloadPrivate.h"
#import "TPCPreferencesUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPCPreferencesTests : XCTestCase
@end

@implementation TPCPreferencesTests

/* Changing a setting reloads what depends on it, and only that: the two scrollback
 limits are separate (the visible one never applied, R7.9) */
- (void)testReloadActionForKeys
{
	TPCPreferencesReloadAction visible = [TPCPreferences reloadActionForKeys:@[@"ScrollbackMaximumVisibleLineCount"]];

	XCTAssertTrue((visible & TPCPreferencesReloadActionScrollbackVisibleLimit) == TPCPreferencesReloadActionScrollbackVisibleLimit);
	XCTAssertFalse((visible & TPCPreferencesReloadActionScrollbackSaveLimit) == TPCPreferencesReloadActionScrollbackSaveLimit);

	TPCPreferencesReloadAction saved = [TPCPreferences reloadActionForKeys:@[@"ScrollbackMaximumSavedLineCount"]];

	XCTAssertTrue((saved & TPCPreferencesReloadActionScrollbackSaveLimit) == TPCPreferencesReloadActionScrollbackSaveLimit);
	XCTAssertFalse((saved & TPCPreferencesReloadActionScrollbackVisibleLimit) == TPCPreferencesReloadActionScrollbackVisibleLimit);

	TPCPreferencesReloadAction style = [TPCPreferences reloadActionForKeys:@[@"Theme -> Timestamp Format"]];

	XCTAssertTrue((style & TPCPreferencesReloadActionStyle) == TPCPreferencesReloadActionStyle);

	/* Every change ends in the general "preferences changed" pass */
	XCTAssertEqual([TPCPreferences reloadActionForKeys:@[]], TPCPreferencesReloadActionPreferencesChanged);
}

/* Textual 7's Caffeine extension setting carries over once, then its key is gone */
- (void)testCaffeineMigration
{
	NSString *extensionKey = @"Private Extension Store -> Caffeine Extension -> Prevent Sleep";
	NSString *preferenceKey = @"PreventSleepWhileConnected";

	id savedPreference = [RZUserDefaults() objectForKey:preferenceKey];

	[RZUserDefaults() setBool:NO forKey:preferenceKey];
	[RZUserDefaults() setBool:YES forKey:extensionKey];

	[TPCPreferences migrateCaffeinePreference];

	XCTAssertTrue([RZUserDefaults() boolForKey:preferenceKey]);
	XCTAssertNil([RZUserDefaults() objectForKey:extensionKey]);

	/* Without the extension's key nothing changes */
	[RZUserDefaults() setBool:NO forKey:preferenceKey];

	[TPCPreferences migrateCaffeinePreference];

	XCTAssertFalse([RZUserDefaults() boolForKey:preferenceKey]);

	if (savedPreference) {
		[RZUserDefaults() setObject:savedPreference forKey:preferenceKey];
	} else {
		[RZUserDefaults() removeObjectForKey:preferenceKey];
	}
}

@end

NS_ASSUME_NONNULL_END
