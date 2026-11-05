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

#import "IRCClientConfig.h"
#import "IRCClientConfigPrivate.h"
#import "TLOKeychainPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLOKeychainTests : XCTestCase
@end

@implementation TLOKeychainTests

- (void)tearDown
{
	TLOKeychain.simulatedWriteStatus = nil;
	TLOKeychain.simulatedReadStatus = nil;
	TLOKeychain.reportsFailures = YES;
}

/* Declining the prompt is an answer: one saved password asks once, not at every read */
- (void)testDeclinedAccessAsksOnce
{
	for (NSNumber *declined in @[@(errSecUserCanceled), @(errSecAuthFailed)]) {
		NSString *identifier = [NSUUID UUID].UUIDString;

		TLOKeychain.simulatedReadStatus = declined;

		XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);
		XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

		XCTAssertEqual(TLOKeychain.simulatedReadCount, 1);

		/* Its own answer: another item still asks */
		XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindNicknamePassword forIdentifier:identifier]);

		XCTAssertEqual(TLOKeychain.simulatedReadCount, 2);
	}
}

/* A password typed in afterwards is the user's new answer */
- (void)testReplacedPasswordIsReadAgain
{
	NSString *identifier = [NSUUID UUID].UUIDString;

	TLOKeychain.simulatedReadStatus = @(errSecUserCanceled);

	XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	TLOKeychain.simulatedWriteStatus = @(errSecSuccess);

	XCTAssertTrue([TLOKeychain setPassword:@"secret" ofKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	XCTAssertEqual(TLOKeychain.simulatedReadCount, 2);
}

/* Declined, a field shows empty. Saving it mustn't replace the password nobody could read. */
- (void)testEmptyPasswordAfterDecliningIsNotWritten
{
	NSString *identifier = [NSUUID UUID].UUIDString;

	TLOKeychain.simulatedReadStatus = @(errSecUserCanceled);

	XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	/* A write that got through would fail with this */
	TLOKeychain.simulatedWriteStatus = @(errSecAuthFailed);
	TLOKeychain.reportsFailures = NO;

	XCTAssertTrue([TLOKeychain setPassword:@"" ofKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	/* Without declining, an empty password does reach the Keychain: to delete it */
	XCTAssertFalse([TLOKeychain setPassword:@"" ofKind:TLOKeychainItemKindNicknamePassword forIdentifier:identifier]);

	XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	XCTAssertEqual(TLOKeychain.simulatedReadCount, 1);
}

/* Locked, a field shows empty too: that's no reason to delete what's saved. Once
 it can be read again, an empty field means cleared. */
- (void)testEmptyPasswordAfterFailedReadIsNotDeleted
{
	NSString *identifier = [NSUUID UUID].UUIDString;

	TLOKeychain.simulatedReadStatus = @(errSecInteractionNotAllowed);

	XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	/* A deletion that got through would fail with this */
	TLOKeychain.simulatedWriteStatus = @(errSecAuthFailed);
	TLOKeychain.reportsFailures = NO;

	XCTAssertTrue([TLOKeychain setPassword:@"" ofKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	TLOKeychain.simulatedReadStatus = @(errSecItemNotFound);

	XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

	XCTAssertFalse([TLOKeychain setPassword:@"" ofKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);
}

/* A locked Keychain or a missing item isn't anyone's answer: ask again next time */
- (void)testOtherFailuresAreNotRemembered
{
	for (NSNumber *status in @[@(errSecInteractionNotAllowed), @(errSecItemNotFound)]) {
		NSString *identifier = [NSUUID UUID].UUIDString;

		TLOKeychain.simulatedReadStatus = status;

		XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);
		XCTAssertNil([TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:identifier]);

		XCTAssertEqual(TLOKeychain.simulatedReadCount, 2);
	}
}

/* When the Keychain refuses a password (e.g. a denied access prompt), it must
 not be thrown away: it stays in memory and the user is told */
- (void)testRefusedPasswordIsKept
{
	TLOKeychain.simulatedWriteStatus = @(errSecAuthFailed);
	TLOKeychain.reportsFailures = NO;

	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	config.nicknamePassword = @"secret";

	[config writeNicknamePasswordToKeychain];

	XCTAssertEqualObjects(config.nicknamePassword, @"secret");
}

@end

NS_ASSUME_NONNULL_END
