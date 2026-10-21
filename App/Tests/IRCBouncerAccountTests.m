/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
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

#import "IRCBouncerAccountPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCBouncerAccountTests : XCTestCase
@end

@implementation IRCBouncerAccountTests

- (IRCBouncerAccount *)accountOfKind:(IRCBouncerKind)kind password:(nullable NSString *)password
{
	IRCBouncerAccountMutable *account = [IRCBouncerAccountMutable new];

	account.kind = kind;
	account.name = @"My bouncer";
	account.serverAddress = @"bnc.example.com";
	account.serverPort = 6697;
	account.prefersSecuredConnection = YES;
	account.username = @"dan";
	account.password = password; // in memory: tests don't touch the Keychain
	account.ignoredNetworks = @[@"2"];

	return [account copy];
}

- (IRCClientConfig *)configLinkedTo:(IRCBouncerAccount *)account network:(NSString *)network
{
	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	config.connectionName = network;
	config.bouncerAccountIdentifier = account.uniqueIdentifier;
	config.bouncerNetwork = network;

	return [config copy];
}

/* Saved and read back: everything but the password, which is in the Keychain */
- (void)testAccountKeepsItsValues
{
	IRCBouncerAccount *account = [self accountOfKind:IRCBouncerKindSoju password:@"secret"];

	NSDictionary *saved = account.dictionaryValue;

	XCTAssertNil(saved[@"password"]);

	IRCBouncerAccount *loaded = [[IRCBouncerAccount alloc] initWithDictionary:saved];

	XCTAssertEqualObjects(loaded.uniqueIdentifier, account.uniqueIdentifier);
	XCTAssertEqual(loaded.kind, IRCBouncerKindSoju);
	XCTAssertEqualObjects(loaded.name, @"My bouncer");
	XCTAssertEqualObjects(loaded.displayName, @"My bouncer");
	XCTAssertEqualObjects(loaded.serverAddress, @"bnc.example.com");
	XCTAssertEqual(loaded.serverPort, 6697);
	XCTAssertTrue(loaded.prefersSecuredConnection);
	XCTAssertEqualObjects(loaded.username, @"dan");
	XCTAssertTrue(loaded.checksForNetworkChanges);
	XCTAssertEqualObjects(loaded.ignoredNetworks, @[@"2"]);

	/* No name: the address is shown */
	IRCBouncerAccountMutable *unnamed = [loaded mutableCopy];

	unnamed.name = nil;

	XCTAssertEqualObjects(unnamed.displayName, @"bnc.example.com");

	/* A damaged entry keeps the account */
	NSMutableDictionary *damaged = [saved mutableCopy];

	damaged[@"kind"] = @(99);
	damaged[@"ignoredNetworks"] = @[@"2", @(3)];

	IRCBouncerAccount *repaired = [[IRCBouncerAccount alloc] initWithDictionary:damaged];

	XCTAssertEqual(repaired.kind, IRCBouncerKindUnknown);
	XCTAssertEqualObjects(repaired.ignoredNetworks, @[@"2"]);
}

/* ZNC: the network's login as the server password; soju logs in with SASL */
- (void)testLinkedServerConnectsWithTheAccountsLogin
{
	IRCBouncerAccount *znc = [self accountOfKind:IRCBouncerKindZNC password:@"secret"];

	IRCServer *server = [znc serverForNetwork:@"libera"];

	XCTAssertEqualObjects(server.serverAddress, @"bnc.example.com");
	XCTAssertEqual(server.serverPort, 6697);
	XCTAssertTrue(server.prefersSecuredConnection);
	XCTAssertEqualObjects(server.serverPassword, @"dan/libera:secret");

	XCTAssertNil([[self accountOfKind:IRCBouncerKindSoju password:@"secret"] serverForNetwork:@"1"].serverPassword);
	XCTAssertNil([[self accountOfKind:IRCBouncerKindZNC password:nil] serverForNetwork:@"libera"].serverPassword);
}

/* One change to the account reaches every network linked to it */
- (void)testPasswordChangeReachesEveryNetwork
{
	IRCBouncerAccount *account = [self accountOfKind:IRCBouncerKindZNC password:@"old"];

	NSArray *configs = @[[self configLinkedTo:account network:@"libera"], [self configLinkedTo:account network:@"oftc"]];

	IRCBouncerAccountMutable *changed = [account mutableCopy];

	changed.password = @"new";

	for (IRCClientConfig *config in configs) {
		NSString *expected = [NSString stringWithFormat:@"dan/%@:new", config.bouncerNetwork];

		XCTAssertEqualObjects([changed serverForNetwork:config.bouncerNetwork].serverPassword, expected);
	}
}

/* The link survives saving, copying and Duplicate; unlinking leaves a normal server */
- (void)testLinkIsKeptAndUnlinkingKeepsTheLogin
{
	IRCBouncerAccount *account = [self accountOfKind:IRCBouncerKindZNC password:@"secret"];

	IRCClientConfig *config = [self configLinkedTo:account network:@"libera"];

	IRCClientConfig *loaded = [[IRCClientConfig alloc] initWithDictionary:config.dictionaryValue];

	XCTAssertEqualObjects(loaded.bouncerAccountIdentifier, account.uniqueIdentifier);
	XCTAssertEqualObjects(loaded.bouncerNetwork, @"libera");

	IRCClientConfig *duplicate = [config uniqueCopy];

	XCTAssertNotEqualObjects(duplicate.uniqueIdentifier, config.uniqueIdentifier);
	XCTAssertEqualObjects(duplicate.bouncerAccountIdentifier, account.uniqueIdentifier);
	XCTAssertEqualObjects(duplicate.bouncerNetwork, @"libera");

	IRCClientConfigMutable *unlinked = [config mutableCopy];

	[unlinked unlinkFromBouncerAccount:account];

	XCTAssertNil(unlinked.bouncerAccountIdentifier);
	XCTAssertNil(unlinked.bouncerNetwork);
	XCTAssertEqual(unlinked.serverList.count, 1);

	IRCServer *server = unlinked.serverList.firstObject;

	XCTAssertEqualObjects(server.serverAddress, @"bnc.example.com");
	XCTAssertEqual(server.serverPort, 6697);
	XCTAssertTrue(server.prefersSecuredConnection);
	XCTAssertEqualObjects(server.serverPassword, @"dan/libera:secret");
}

@end

NS_ASSUME_NONNULL_END
