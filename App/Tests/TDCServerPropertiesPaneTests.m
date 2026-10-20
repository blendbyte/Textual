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
#import "IRCServerPrivate.h"
#import "TDCServerPropertiesWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerPropertiesPaneTests : XCTestCase
@end

@implementation TDCServerPropertiesPaneTests

- (TDCServerPropertiesPane *)serverPane
{
	/* In Swift: its class is only known at run time here */
	Class paneClass = NSClassFromString(@"TDCServerPropertiesServerPane");

	XCTAssertNotNil(paneClass);

	return [paneClass new];
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

/* A new server can't be saved without an address */
- (void)testNewServerNeedsAnAddress
{
	TDCServerPropertiesPane *pane = [self serverPane];

	[pane loadFromConfig:[IRCClientConfigMutable new]];

	XCTAssertTrue(pane.hasInvalidField);
}

@end

NS_ASSUME_NONNULL_END
