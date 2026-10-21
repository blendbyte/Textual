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

/* Servers added by hand before (dan/libera logins) are recognised, to be
 linked: the network from the username or the server password, only with
 the account's address, port and user, and not when already linked */
- (void)testServerAddedByHandIsRecognised
{
	IRCBouncerAccount *account = [self accountOfKind:IRCBouncerKindZNC password:@"secret"];

	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	/* The objects themselves: a copy reads its password from the Keychain */
	config.serverList = @[[self serverAt:@"BNC.example.com" port:6697 password:@"dan/libera:secret"]];

	XCTAssertEqualObjects([account networkOfServerAddedByHand:config], @"libera");

	config.serverList = @[[self serverAt:@"bnc.example.com" port:6697 password:nil]];
	config.username = @"dan/oftc@laptop";

	XCTAssertEqualObjects([account networkOfServerAddedByHand:config], @"oftc");

	config.username = @"bob/oftc";

	XCTAssertNil([account networkOfServerAddedByHand:config]);

	config.username = @"dan/oftc";
	config.serverList = @[[self serverAt:@"bnc.example.com" port:6667 password:nil]];

	XCTAssertNil([account networkOfServerAddedByHand:config]);

	XCTAssertNil([account networkOfServerAddedByHand:[self configLinkedTo:account network:@"oftc"]]);
}

- (IRCServer *)serverAt:(NSString *)address port:(uint16_t)port password:(nullable NSString *)password
{
	IRCServerMutable *server = [IRCServerMutable new];

	server.serverAddress = address;
	server.serverPort = port;
	server.serverPassword = password;

	return server;
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

	/* soju: the network (by the server's name) in the username, the password as PASS */
	IRCBouncerAccount *soju = [self accountOfKind:IRCBouncerKindSoju password:@"secret"];

	IRCClientConfigMutable *sojuConfig = [[self configLinkedTo:soju network:@"2"] mutableCopy];

	sojuConfig.connectionName = @"OFTC";

	[sojuConfig unlinkFromBouncerAccount:soju];

	XCTAssertNil(sojuConfig.bouncerAccountIdentifier);
	XCTAssertEqualObjects(sojuConfig.username, @"dan/OFTC");
	XCTAssertEqualObjects(sojuConfig.serverList.firstObject.serverAddress, @"bnc.example.com");
	XCTAssertEqualObjects(sojuConfig.serverList.firstObject.serverPassword, @"secret");
}

/* soju's list as captured from soju (3dec1ed44), then changes as its
 notifications send them: only what changed, an empty value removes an
 attribute, "*" removes the network */
- (void)testSojuNetworkListFollowsItsReplies
{
	IRCBouncerNetworkList *list = [IRCBouncerNetworkList new];

	XCTAssertEqual([list updateNetwork:@"1" attributes:@"realname=sojudan;tls=0;host=127.0.0.1;port=6667;name=Ergo;state=connected;nickname=sojudan"], IRCBouncerNetworkChangeAdded);
	XCTAssertEqual([list updateNetwork:@"2" attributes:@"nickname=sojudan2;realname=sojudan2;tls=0;host=127.0.0.1;port=6667;name=Ergo\\sTwo;state=connected"], IRCBouncerNetworkChangeAdded);

	NSArray *names = [list.networks valueForKey:@"name"];
	NSArray *expectedNames = @[@"Ergo", @"Ergo Two"];

	XCTAssertEqualObjects(names, expectedNames);

	XCTAssertEqual([list updateNetwork:@"2" attributes:@"state=disconnected;error=Connection\\srefused"], IRCBouncerNetworkChangeChanged);

	IRCBouncerNetwork *network = [list networkWithIdentifier:@"2"];

	XCTAssertEqualObjects(network.name, @"Ergo Two");
	XCTAssertEqualObjects(network.state, @"disconnected");
	XCTAssertEqualObjects(network.attributes[@"error"], @"Connection refused");
	XCTAssertEqualObjects(network.attributes[@"nickname"], @"sojudan2");

	XCTAssertEqual([list updateNetwork:@"2" attributes:@"error="], IRCBouncerNetworkChangeChanged);
	XCTAssertNil([list networkWithIdentifier:@"2"].attributes[@"error"]);

	XCTAssertEqual([list updateNetwork:@"1" attributes:@"*"], IRCBouncerNetworkChangeRemoved);
	XCTAssertEqual([list updateNetwork:@"1" attributes:@"*"], IRCBouncerNetworkChangeNone);
	XCTAssertEqual(list.networks.count, 1);
	XCTAssertNil([list networkWithIdentifier:@"1"]);
}

/* ZNC's ListNetworks answer as captured from ZNC 1.10.3 (1.7 draws the same
 table), a network without a server included */
- (void)testZNCNetworkListReadFromItsTable
{
	NSArray<NSString *> *lines = @[
		@"+---------+--------+------------------+------------------------------+----------+",
		@"| Network | On IRC | IRC Server       | IRC User                     | Channels |",
		@"+---------+--------+------------------+------------------------------+----------+",
		@"| ergo    | Yes    | irc.textual.test | zncdan!~u@skgexaezgkdqy.irc  | 0        |",
		@"| ergotwo | Yes    | irc.textual.test | zncdan2!~u@skgexaezgkdqy.irc | 0        |",
		@"| offline | No     |                  |                              |          |",
		@"+---------+--------+------------------+------------------------------+----------+"
	];

	IRCZNCNetworkListReader *reader = [IRCZNCNetworkListReader new];

	for (NSString *line in lines) {
		XCTAssertTrue([reader readLine:line], @"%@", line);
	}

	XCTAssertTrue(reader.finished);
	XCTAssertFalse([reader readLine:@"Network deleted"]);

	NSArray *names = [reader.networkList.networks valueForKey:@"name"];
	NSArray *expectedNames = @[@"ergo", @"ergotwo", @"offline"];

	XCTAssertEqualObjects(names, expectedNames);

	IRCBouncerNetwork *ergotwo = [reader.networkList networkWithIdentifier:@"ergotwo"];

	XCTAssertEqualObjects(ergotwo.state, @"connected");
	XCTAssertEqualObjects(ergotwo.attributes[@"host"], @"irc.textual.test");
	XCTAssertEqualObjects(ergotwo.attributes[@"nickname"], @"zncdan2");

	XCTAssertEqualObjects([reader.networkList networkWithIdentifier:@"offline"].state, @"disconnected");
}

/* In German (ZNC's de_DE translation) the words differ and ZNC pads by bytes,
 so "Kanäle" is a character short; a nickname may have a "|". Without
 networks, ZNC sends one line instead of the table. */
- (void)testZNCNetworkListReadInAnotherLanguage
{
	NSArray<NSString *> *lines = @[
		@"+----------+--------+-----------------+------------------+---------+",
		@"| Netzwerk | Im IRC | IRC-Server      | IRC-Benutzer     | Kanäle |",
		@"+----------+--------+-----------------+------------------+---------+",
		@"| libera   | Ja     | irc.libera.chat | dan|away!~d@host | 3       |",
		@"| oftc     | Nein   |                 |                  |         |",
		@"+----------+--------+-----------------+------------------+---------+"
	];

	IRCZNCNetworkListReader *reader = [IRCZNCNetworkListReader new];

	for (NSString *line in lines) {
		XCTAssertTrue([reader readLine:line], @"%@", line);
	}

	XCTAssertTrue(reader.finished);

	IRCBouncerNetwork *libera = [reader.networkList networkWithIdentifier:@"libera"];

	XCTAssertEqualObjects(libera.state, @"connected");
	XCTAssertEqualObjects(libera.attributes[@"nickname"], @"dan|away");
	XCTAssertEqualObjects([reader.networkList networkWithIdentifier:@"oftc"].state, @"disconnected");

	IRCZNCNetworkListReader *emptyReader = [IRCZNCNetworkListReader new];

	XCTAssertTrue([emptyReader readLine:@"Keine Netzwerke"]);
	XCTAssertTrue(emptyReader.finished);
	XCTAssertEqual(emptyReader.networkList.networks.count, 0);
}

@end

NS_ASSUME_NONNULL_END
