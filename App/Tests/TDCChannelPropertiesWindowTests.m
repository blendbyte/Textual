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
#import "TDCChannelPropertiesWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelPropertiesWindowTests : XCTestCase
@end

@implementation TDCChannelPropertiesWindowTests

/* In Swift: its class is only known at run time here */
- (TDCChannelPropertiesWindow *)windowForConfig:(IRCChannelConfigMutable *)config
{
	Class windowClass = NSClassFromString(@"TDCChannelPropertiesWindow");

	XCTAssertNotNil(windowClass);

	return [[windowClass alloc] initWithConfig:config client:nil save:^{} cancel:^{}];
}

/* Opening Channel Properties and pressing Save changes nothing: every
 setting comes back as it was, the two that make "Never" included */
- (void)testChannelPropertiesSaveWhatTheyLoaded
{
	IRCChannelConfigMutable *config = [[IRCChannelConfig seedWithName:@"#textual"] mutableCopy];

	config.label = @"Textual";
	config.secretKey = @"secret";
	config.autoJoin = NO;
	config.muted = YES;
	config.pushNotifications = NO;
	config.showTreeBadgeCount = NO;
	config.inlineMediaDisabled = YES;
	config.formatting = IRCChannelFormattingRemove;
	config.ignoreHighlights = YES;
	config.ignoreGeneralEventMessages = YES;
	config.excludedFromArchive = YES;
	config.defaultTopic = @"Welcome";
	config.defaultModes = @"+nt";

	IRCChannelConfig *original = [config copy];

	TDCChannelPropertiesWindow *window = [self windowForConfig:config];

	XCTAssertTrue([window applyChanges]);

	XCTAssertEqualObjects(config.channelName, original.channelName);
	XCTAssertEqualObjects(config.label, original.label);
	XCTAssertEqualObjects(config.secretKey, original.secretKey);
	XCTAssertFalse(config.autoJoin);
	XCTAssertTrue(config.muted);
	XCTAssertFalse(config.pushNotifications);
	XCTAssertFalse(config.showTreeBadgeCount);
	XCTAssertTrue(config.inlineMediaDisabled);
	XCTAssertFalse(config.inlineMediaEnabled);
	XCTAssertEqual(config.formatting, IRCChannelFormattingRemove);
	XCTAssertTrue(config.ignoreHighlights);
	XCTAssertTrue(config.ignoreGeneralEventMessages);
	XCTAssertTrue(config.excludedFromArchive);
	XCTAssertEqualObjects(config.defaultTopic, original.defaultTopic);
	XCTAssertEqualObjects(config.defaultModes, original.defaultModes);
}

/* A new channel can't be saved without a name */
- (void)testNewChannelNeedsAName
{
	IRCChannelConfigMutable *config = [IRCChannelConfigMutable new];

	TDCChannelPropertiesWindow *window = [self windowForConfig:config];

	XCTAssertFalse([window applyChanges]);
}

@end

NS_ASSUME_NONNULL_END
