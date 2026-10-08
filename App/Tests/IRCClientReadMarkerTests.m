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
#import "IRCClientInternal.h"
#import "IRCMessage.h"
#import "IRCTreeItemPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientReadMarkerTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@property (nonatomic, strong) IRCChannel *channel;
@end

@implementation IRCClientReadMarkerTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	self.channel = [[IRCChannel alloc] initWithConfig:[IRCChannelConfig seedWithName:@"#textual"]];

	self.channel.associatedClient = self.client;

	[self.client addChannel:self.channel];
}

- (NSDate *)dateAt:(NSTimeInterval)seconds
{
	return [NSDate dateWithTimeIntervalSince1970:(1700000000 + seconds)];
}

- (BOOL)apply:(NSString *)timestamp
{
	NSString *line = [NSString stringWithFormat:@":irc.test MARKREAD #textual timestamp=%@", timestamp];

	return [self.client applyReadMarker:[[IRCMessage alloc] initWithLine:line onClient:self.client]];
}

/* The marker names the newest message's time, and is only sent when it moves forward */
- (void)testRequestNamesTheNewestMessage
{
	XCTAssertNil([self.client readMarkerRequestForChannel:self.channel]);

	[self.client readMarkerNoteMessageAt:[self dateAt:20] inChannel:self.channel];
	[self.client readMarkerNoteMessageAt:[self dateAt:10] inChannel:self.channel];

	XCTAssertEqualObjects([self.client readMarkerRequestForChannel:self.channel], @"MARKREAD #textual timestamp=2023-11-14T22:13:40.000Z");

	self.channel.readMarkerTime = [self dateAt:20];

	XCTAssertNil([self.client readMarkerRequestForChannel:self.channel]);
}

/* Another client's marker clears the badges only when it covers everything shown */
- (void)testMarkerFromElsewhereClearsCoveredUnread
{
	[self.client readMarkerNoteMessageAt:[self dateAt:20] inChannel:self.channel];

	self.channel.treeUnreadCount = 3;
	self.channel.nicknameHighlightCount = 1;

	XCTAssertFalse([self apply:@"2023-11-14T22:13:30.000Z"], @"Older than the newest message");
	XCTAssertEqual(self.channel.treeUnreadCount, 3);

	XCTAssertFalse([self apply:@"*"]);

	XCTAssertTrue([self apply:@"2023-11-14T22:13:40.000Z"]);
	XCTAssertEqual(self.channel.treeUnreadCount, 0);
	XCTAssertEqual(self.channel.nicknameHighlightCount, 0);
}

@end

NS_ASSUME_NONNULL_END
