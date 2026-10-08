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
#import "IRCChannelConfig.h"
#import "IRCClientConfig.h"
#import "IRCServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientConfigTests : XCTestCase
@end

@implementation IRCClientConfigTests

/* Duplicate Server: the copy and everything in it get new identifiers, or
 deleting the copy deletes the original's Keychain items (R2.2) */
- (void)testUniqueCopyHasNewIdentifiersThroughout
{
	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	IRCServerMutable *server = [IRCServerMutable new];

	server.serverAddress = @"irc.example.net";

	config.serverList = @[[server copy]];
	config.channelList = @[[IRCChannelConfig seedWithName:@"#example"]];
	config.ignoreList = @[[IRCAddressBookEntry newIgnoreEntryForHostmask:@"bob!*@*"]];

	IRCClientConfig *original = [config copy];

	IRCClientConfig *duplicate = [original uniqueCopy];

	XCTAssertNotEqualObjects(duplicate.uniqueIdentifier, original.uniqueIdentifier);
	XCTAssertNotEqualObjects(duplicate.serverList.firstObject.uniqueIdentifier, original.serverList.firstObject.uniqueIdentifier);
	XCTAssertNotEqualObjects(duplicate.channelList.firstObject.uniqueIdentifier, original.channelList.firstObject.uniqueIdentifier);
	XCTAssertNotEqualObjects(duplicate.ignoreList.firstObject.uniqueIdentifier, original.ignoreList.firstObject.uniqueIdentifier);

	/* Everything else is the same */
	XCTAssertEqualObjects(duplicate.serverList.firstObject.serverAddress, @"irc.example.net");
	XCTAssertEqualObjects(duplicate.channelList.firstObject.channelName, @"#example");

	/* A plain copy keeps the identifiers */
	IRCClientConfig *plainCopy = [original copy];

	XCTAssertEqualObjects(plainCopy.uniqueIdentifier, original.uniqueIdentifier);
}

@end

NS_ASSUME_NONNULL_END
