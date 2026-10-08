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

#import "IRCChannelConfig.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCTreeItemPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientChannelLookupTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@end

@implementation IRCClientChannelLookupTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];
}

- (IRCChannel *)addChannelNamed:(NSString *)name type:(IRCChannelType)type
{
	IRCChannelConfigMutable *config = [IRCChannelConfigMutable new];

	config.channelName = name;

	config.type = type;

	IRCChannel *channel = [[IRCChannel alloc] initWithConfig:config];

	channel.associatedClient = self.client;

	[self.client addChannel:channel];

	return channel;
}

/* Channels are found under the server's CASEMAPPING, also after it changes */
- (void)testLookupFollowsCaseMapping
{
	IRCChannel *channel = [self addChannelNamed:@"#Chan[1]" type:IRCChannelTypeChannel];

	XCTAssertEqual([self.client findChannel:@"#chan{1}"], channel);

	[self.client.supportInfo processConfigurationData:@"me CASEMAPPING=ascii :are supported by this server"];

	XCTAssertNil([self.client findChannel:@"#chan{1}"]);
	XCTAssertEqual([self.client findChannel:@"#CHAN[1]"], channel);
}

/* Adding, removing and replacing channels, and renaming a query, show up in the next lookup */
- (void)testLookupFollowsListChanges
{
	IRCChannel *channel = [self addChannelNamed:@"#textual" type:IRCChannelTypeChannel];
	IRCChannel *query = [self addChannelNamed:@"Bob" type:IRCChannelTypePrivateMessage];

	XCTAssertEqual([self.client findChannel:@"bob"], query);

	query.name = @"Robert";

	XCTAssertNil([self.client findChannel:@"bob"]);
	XCTAssertEqual([self.client findChannel:@"ROBERT"], query);

	[self.client removeChannel:channel];

	XCTAssertNil([self.client findChannel:@"#textual"]);

	IRCChannel *other = [self addChannelNamed:@"#other" type:IRCChannelTypeChannel];

	XCTAssertEqual([self.client findChannel:@"#Other"], other);

	self.client.channelList = @[channel];

	XCTAssertEqual([self.client findChannel:@"#TEXTUAL"], channel);
	XCTAssertNil([self.client findChannel:@"#other"]);
	XCTAssertNil([self.client findChannel:@"robert"]);
}

@end

NS_ASSUME_NONNULL_END
