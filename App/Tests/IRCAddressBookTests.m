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

#import "IRCAddressBook.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCAddressBookTests : XCTestCase
@end

@implementation IRCAddressBookTests

/* An ignore mask matches whole hostmasks; * and ? are the only wildcards */
- (void)testIgnoreMaskMatchesWholeHostmasksOnly
{
	IRCAddressBookEntry *bob = [IRCAddressBookEntry newIgnoreEntryForHostmask:@"bob!*@*"];

	XCTAssertTrue([bob checkMatch:@"bob!user@host.example"]);
	XCTAssertTrue([bob checkMatch:@"BOB!user@host.example"]);
	XCTAssertFalse([bob checkMatch:@"jimbob!user@host.example"]);
	XCTAssertFalse([bob checkMatch:@"bobby!user@host.example"]);

	IRCAddressBookEntry *oneCharacter = [IRCAddressBookEntry newIgnoreEntryForHostmask:@"b?b!*@*"];

	XCTAssertTrue([oneCharacter checkMatch:@"bab!user@host"]);
	XCTAssertFalse([oneCharacter checkMatch:@"bb!user@host"]);

	IRCAddressBookEntry *host = [IRCAddressBookEntry newIgnoreEntryForHostmask:@"*!*@host.example"];

	XCTAssertTrue([host checkMatch:@"anyone!user@host.example"]);
	XCTAssertFalse([host checkMatch:@"anyone!user@hostXexample"]);
}

/* A tracked nickname is literal, even with regular expression characters */
- (void)testTrackedNicknameIsMatchedLiterally
{
	IRCAddressBookEntryMutable *entry = [[IRCAddressBookEntry newUserTrackingEntry] mutableCopy];

	entry.hostmask = @"[x]";

	XCTAssertTrue([entry checkMatch:@"[x]!user@host"]);
	XCTAssertFalse([entry checkMatch:@"x!user@host"]);
}

@end

NS_ASSUME_NONNULL_END
