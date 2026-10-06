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

#import "TPCPreferencesImportExportPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPCPreferencesImportTests : XCTestCase
@end

@implementation TPCPreferencesImportTests

/* A settings file can come from anyone: only what export writes, with the
 type each preference has, may be imported */
- (void)testImportOnlyWhatExportWrites
{
	NSDictionary *file = @{
		@"AutojoinChannelOnInvite" : @YES,
		@"Theme -> Name" : @"resource:Simplified",
		@"World Controller Client Configurations" : @[],

		@"ReplyUnignoredExternalCTCPRequests" : @"YES", // wrong type
		@"Theme -> Name -> Did Not Exist During Last Sync" : @YES, // not exported
		@"TXRunCount" : @1000, // excluded from export
		@"SUFeedURL" : @"https://example.com/feed.xml", // excluded from export
		@"Some Key Textual Never Wrote" : @"value"
	};

	NSDictionary *importable = [TPCPreferencesImportExport importableContentsOfDictionary:file];

	XCTAssertEqualObjects([NSSet setWithArray:importable.allKeys],
						  ([NSSet setWithArray:@[@"AutojoinChannelOnInvite", @"Theme -> Name", @"World Controller Client Configurations"]]));
}

@end

NS_ASSUME_NONNULL_END
