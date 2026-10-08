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
#import "IRCClientInternal.h"
#import "IRCMessage.h"
#import "IRCUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientAccountTrackingTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@end

@implementation IRCClientAccountTrackingTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	[self.client addUser:[[IRCUser alloc] initWithNickname:@"bob" onClient:self.client]];
}

- (IRCMessage *)parse:(NSString *)line
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:line onClient:self.client];

	XCTAssertNotNil(message, @"Failed to parse: %@", line);

	return message;
}

- (nullable NSString *)accountOfBob
{
	return [self.client findUser:@"bob"].account;
}

/* account-notify: ACCOUNT names the account a user logged in to, "*" means logged out */
- (void)testAccountNotifyFollowsLoginAndLogout
{
	[self.client receiveAccount:[self parse:@":bob!b@host.test ACCOUNT bobsaccount"]];

	XCTAssertEqualObjects([self accountOfBob], @"bobsaccount");

	[self.client receiveAccount:[self parse:@":bob!b@host.test ACCOUNT *"]];

	XCTAssertNil([self accountOfBob]);
}

/* account-tag: the account tag on a user's message updates their account, only with the capability */
- (void)testAccountTagUpdatesTheSender
{
	IRCMessage *message = [self parse:@"@account=bobsaccount :bob!b@host.test PRIVMSG #textual :hello"];

	[self.client processAccountTagInMessage:message];

	XCTAssertNil([self accountOfBob], @"account-tag isn't enabled");

	[self.client enableCapability:ClientIRCv3SupportedCapabilityAccountTag];

	[self.client processAccountTagInMessage:message];

	XCTAssertEqualObjects([self accountOfBob], @"bobsaccount");

	[self.client processAccountTagInMessage:[self parse:@":bob!b@host.test PRIVMSG #textual :no tag"]];

	XCTAssertEqualObjects([self accountOfBob], @"bobsaccount", @"A line without the tag says nothing about the account");
}

/* extended-join: JOIN #channel account :real name, "*" when not logged in */
- (void)testExtendedJoinSetsAccountAndRealName
{
	[self.client enableCapability:ClientIRCv3SupportedCapabilityExtendedJoin];

	IRCUserMutable *carol = [[IRCUserMutable alloc] initWithNickname:@"carol" onClient:self.client];

	[self.client updateUser:carol fromExtendedJoin:[self parse:@":carol!c@host.test JOIN #textual carolsaccount :Carol Example"]];

	XCTAssertEqualObjects(carol.account, @"carolsaccount");
	XCTAssertEqualObjects(carol.realName, @"Carol Example");

	[self.client updateUser:carol fromExtendedJoin:[self parse:@":carol!c@host.test JOIN #textual * :Carol Example"]];

	XCTAssertNil(carol.account);
}

/* setname: a user's real name changes while connected */
- (void)testSetNameChangesTheRealName
{
	[self.client receiveSetName:[self parse:@":bob!b@host.test SETNAME :Bob the Builder"]];

	XCTAssertEqualObjects([self.client findUser:@"bob"].realName, @"Bob the Builder");
}

@end

NS_ASSUME_NONNULL_END
