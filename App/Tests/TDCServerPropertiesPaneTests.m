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
#import "IRCClientConfigPrivate.h"
#import "IRCServerPrivate.h"
#import "TDCServerPropertiesWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerPropertiesPaneTests : XCTestCase
@end

@implementation TDCServerPropertiesPaneTests

/* In Swift: their classes are only known at run time here */
- (TDCServerPropertiesPane *)paneNamed:(NSString *)className
{
	Class paneClass = NSClassFromString(className);

	XCTAssertNotNil(paneClass);

	return [paneClass new];
}

- (TDCServerPropertiesPane *)serverPane
{
	return [self paneNamed:@"TDCServerPropertiesServerPane"];
}

/* The Server page saves what it loaded: nothing is lost or changed by
 opening Server Properties and pressing Save */
- (void)testServerPaneSavesWhatItLoaded
{
	IRCServerMutable *knownServer = [IRCServerMutable new];

	knownServer.serverAddress = @"irc.libera.chat";
	knownServer.serverPort = 6697;
	knownServer.prefersSecuredConnection = YES;

	IRCServerMutable *webSocketServer = [IRCServerMutable new];

	webSocketServer.serverAddress = @"irc.example.net";
	webSocketServer.serverPort = 8443;
	webSocketServer.prefersSecuredConnection = YES;
	webSocketServer.webSocketPath = @"/webirc";

	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	config.connectionName = @"Example";
	config.autoConnect = YES;
	config.autoReconnect = NO;
	config.autoSleepModeDisconnect = YES;
	config.customIcon = [@"icon" dataUsingEncoding:NSUTF8StringEncoding];
	config.serverList = @[[knownServer copy], [webSocketServer copy]];

	TDCServerPropertiesPane *pane = [self serverPane];

	[pane loadFromConfig:config];

	XCTAssertFalse(pane.hasInvalidField);

	IRCClientConfigMutable *saved = [IRCClientConfigMutable new];

	[pane saveToConfig:saved];

	XCTAssertEqualObjects(saved.connectionName, @"Example");
	XCTAssertTrue(saved.autoConnect);
	XCTAssertFalse(saved.autoReconnect);
	XCTAssertTrue(saved.autoSleepModeDisconnect);
	XCTAssertEqualObjects(saved.customIcon, config.customIcon);

	XCTAssertEqual(saved.serverList.count, 2);
	XCTAssertEqualObjects(saved.serverList[0].dictionaryValue, config.serverList[0].dictionaryValue);
	XCTAssertEqualObjects(saved.serverList[1].dictionaryValue, config.serverList[1].dictionaryValue);
}

/* The You and Account pages save what they loaded */
- (void)testYouAndAccountPanesSaveWhatTheyLoaded
{
	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	NSArray *alternateNicknames = @[@"alice_", @"alice__"];

	config.nickname = @"alice";
	config.alternateNicknames = alternateNicknames;
	config.awayNickname = @"alice|away";
	config.realName = @"Alice Example";
	config.username = @"alice";
	config.nicknamePassword = @"secret";
	config.nickServHost = @"services.example.net";
	config.autojoinWaitsForNickServ = YES;
	config.hideAutojoinDelayedWarnings = YES;
	config.saslECDSAKey = @"stored-key";

	TDCServerPropertiesPane *youPane = [self paneNamed:@"TDCServerPropertiesYouPane"];
	TDCServerPropertiesPane *accountPane = [self paneNamed:@"TDCServerPropertiesAccountPane"];

	[youPane loadFromConfig:config];
	[accountPane loadFromConfig:config];

	XCTAssertFalse(youPane.hasInvalidField);
	XCTAssertFalse(accountPane.hasInvalidField);

	IRCClientConfigMutable *saved = [IRCClientConfigMutable new];

	[youPane saveToConfig:saved];
	[accountPane saveToConfig:saved];

	XCTAssertEqualObjects(saved.nickname, @"alice");
	XCTAssertEqualObjects(saved.alternateNicknames, alternateNicknames);
	XCTAssertEqualObjects(saved.awayNickname, @"alice|away");
	XCTAssertEqualObjects(saved.realName, @"Alice Example");
	XCTAssertEqualObjects(saved.username, @"alice");
	XCTAssertEqualObjects(saved.nicknamePassword, @"secret");
	XCTAssertEqualObjects(saved.nickServHost, @"services.example.net");
	XCTAssertTrue(saved.autojoinWaitsForNickServ);
	XCTAssertTrue(saved.hideAutojoinDelayedWarnings);
	XCTAssertEqualObjects(saved.saslECDSAKey, @"stored-key");
	XCTAssertNil(saved.identityClientSideCertificate);
}

/* Channels, People and Messages save what they loaded: queries stay in
 the channel list though only channels are shown */
- (void)testListPanesSaveWhatTheyLoaded
{
	IRCChannelConfigMutable *query = [[IRCChannelConfig seedWithName:@"bob"] mutableCopy];

	query.type = IRCChannelTypePrivateMessage;

	NSArray *channelList = @[[IRCChannelConfig seedWithName:@"#one"], [query copy], [IRCChannelConfig seedWithName:@"#two"]];

	NSArray *ignoreList = @[[IRCAddressBookEntry newIgnoreEntryForHostmask:@"spam!*@*"], [IRCAddressBookEntry newUserTrackingEntry]];

	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	config.channelList = channelList;
	config.ignoreList = ignoreList;
	config.normalLeavingComment = @"Bye";
	config.sleepModeLeavingComment = @"Sleeping";
	config.excludedFromArchive = YES;

	TDCServerPropertiesPane *channelsPane = [self paneNamed:@"TDCServerPropertiesChannelsPane"];
	TDCServerPropertiesPane *peoplePane = [self paneNamed:@"TDCServerPropertiesPeoplePane"];
	TDCServerPropertiesPane *messagesPane = [self paneNamed:@"TDCServerPropertiesMessagesPane"];

	for (TDCServerPropertiesPane *pane in @[channelsPane, peoplePane, messagesPane]) {
		[pane loadFromConfig:config];

		XCTAssertFalse(pane.hasInvalidField);
	}

	IRCClientConfigMutable *saved = [IRCClientConfigMutable new];

	for (TDCServerPropertiesPane *pane in @[channelsPane, peoplePane, messagesPane]) {
		[pane saveToConfig:saved];
	}

	XCTAssertEqualObjects(saved.channelList, channelList);
	XCTAssertEqualObjects(saved.ignoreList, ignoreList);
	XCTAssertEqualObjects(saved.normalLeavingComment, @"Bye");
	XCTAssertEqualObjects(saved.sleepModeLeavingComment, @"Sleeping");
	XCTAssertTrue(saved.excludedFromArchive);
}

/* The Advanced pages save what they loaded */
- (void)testAdvancedPanesSaveWhatTheyLoaded
{
	NSArray *loginCommands = @[@"/mode alice +x", @"/join #help"];

	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	config.loginCommands = loginCommands;
	config.setInvisibleModeOnConnect = YES;
	config.primaryEncoding = NSISOLatin1StringEncoding;
	config.fallbackEncoding = NSUTF8StringEncoding;
	config.performPongTimer = NO;
	config.performDisconnectOnPongTimer = YES;
	config.performDisconnectOnReachabilityChange = YES;
	config.floodControlMaximumMessages = 9;
	config.floodControlDelayTimerInterval = 7;
	config.validateServerCertificateChain = NO;
	config.cipherSuites = RCMCipherSuiteCollectionMozilla2015;
	config.proxyType = IRCConnectionProxyTypeHTTPS;
	config.proxyAddress = @"proxy.example.net";
	config.proxyPort = 3128;
	config.proxyUsername = @"alice";
	config.proxyPassword = @"secret";
	config.uploadDestinationMode = IRCClientUploadDestinationModeOff;
	config.zncIgnoreConfiguredAutojoin = YES;
	config.zncIgnorePlaybackNotifications = YES;
	config.zncOnlyPlaybackLatest = YES;

	NSArray *panes = @[
		[self paneNamed:@"TDCServerPropertiesWhenConnectedPane"],
		[self paneNamed:@"TDCServerPropertiesConnectionPane"],
		[self paneNamed:@"TDCServerPropertiesSecurityPane"],
		[self paneNamed:@"TDCServerPropertiesProxyPane"],
		[self paneNamed:@"TDCServerPropertiesUploadsPane"],
		[self paneNamed:@"TDCServerPropertiesZNCPane"]
	];

	for (TDCServerPropertiesPane *pane in panes) {
		[pane loadFromConfig:config];

		XCTAssertFalse(pane.hasInvalidField);
	}

	IRCClientConfigMutable *saved = [IRCClientConfigMutable new];

	for (TDCServerPropertiesPane *pane in panes) {
		[pane saveToConfig:saved];
	}

	XCTAssertEqualObjects(saved.loginCommands, loginCommands);
	XCTAssertTrue(saved.setInvisibleModeOnConnect);
	XCTAssertEqual(saved.primaryEncoding, NSISOLatin1StringEncoding);
	XCTAssertEqual(saved.fallbackEncoding, NSUTF8StringEncoding);
	XCTAssertFalse(saved.performPongTimer);
	XCTAssertTrue(saved.performDisconnectOnPongTimer);
	XCTAssertTrue(saved.performDisconnectOnReachabilityChange);
	XCTAssertEqual(saved.floodControlMaximumMessages, 9);
	XCTAssertEqual(saved.floodControlDelayTimerInterval, 7);
	XCTAssertFalse(saved.validateServerCertificateChain);
	XCTAssertEqual(saved.cipherSuites, RCMCipherSuiteCollectionMozilla2015);
	XCTAssertEqual(saved.proxyType, IRCConnectionProxyTypeHTTPS);
	XCTAssertEqualObjects(saved.proxyAddress, @"proxy.example.net");
	XCTAssertEqual(saved.proxyPort, 3128);
	XCTAssertEqualObjects(saved.proxyUsername, @"alice");
	XCTAssertEqualObjects(saved.proxyPassword, @"secret");
	XCTAssertEqual(saved.uploadDestinationMode, IRCClientUploadDestinationModeOff);
	XCTAssertTrue(saved.zncIgnoreConfiguredAutojoin);
	XCTAssertTrue(saved.zncIgnorePlaybackNotifications);
	XCTAssertTrue(saved.zncOnlyPlaybackLatest);
}

/* A fallback server whose address isn't one keeps Save from closing the
 sheet, on the Fallback Servers page */
- (void)testFallbackServerNeedsAValidAddress
{
	IRCServerMutable *server = [IRCServerMutable new];

	server.serverAddress = @"irc.example.net";
	server.serverPort = 6697;

	IRCServerMutable *fallbackServer = [IRCServerMutable new];

	fallbackServer.serverAddress = @"irc.example.net!";
	fallbackServer.serverPort = 6697;

	IRCClientConfigMutable *config = [IRCClientConfigMutable new];

	config.serverList = @[[server copy], [fallbackServer copy]];

	TDCServerPropertiesServerPane *serverPane = (TDCServerPropertiesServerPane *)[self serverPane];

	TDCServerPropertiesFallbackServersPane *fallbackServersPane = (TDCServerPropertiesFallbackServersPane *)[self paneNamed:@"TDCServerPropertiesFallbackServersPane"];

	fallbackServersPane.serverPane = serverPane;

	[serverPane loadFromConfig:config];

	XCTAssertFalse(serverPane.hasInvalidField);
	XCTAssertTrue(fallbackServersPane.hasInvalidField);
}

/* A new server can't be saved without an address */
- (void)testNewServerNeedsAnAddress
{
	TDCServerPropertiesPane *pane = [self serverPane];

	[pane loadFromConfig:[IRCClientConfigMutable new]];

	XCTAssertTrue(pane.hasInvalidField);
}

@end

NS_ASSUME_NONNULL_END
