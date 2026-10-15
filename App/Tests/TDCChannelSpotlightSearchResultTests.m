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

#import "TDCChannelSpotlightSearchResultPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelSpotlightSearchResultTests : XCTestCase
@end

@implementation TDCChannelSpotlightSearchResultTests

- (NSMenuItem *)itemWithTitle:(NSString *)title action:(nullable SEL)action inMenu:(NSMenu *)menu
{
	NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:@""];

	item.target = self;

	return item;
}

/* Channel Spotlight lists the commands that can be chosen now, with their menu,
 and not what can't be chosen or is listed elsewhere (10.17 idea 3) */
- (void)testFindsOnlyCommandsThatCanBeChosen
{
	NSMenu *mainMenu = [NSMenu new];

	NSMenu *serverMenu = [[NSMenu alloc] initWithTitle:@"Server"];

	serverMenu.autoenablesItems = NO;

	NSMenuItem *connect = [self itemWithTitle:@"Connect" action:@selector(connect:) inMenu:serverMenu];

	connect.keyEquivalent = @"K";
	connect.keyEquivalentModifierMask = NSEventModifierFlagCommand;

	[self itemWithTitle:@"Disconnect" action:@selector(connect:) inMenu:serverMenu].enabled = NO;
	[self itemWithTitle:@"Hidden" action:@selector(connect:) inMenu:serverMenu].hidden = YES;
	[self itemWithTitle:@"Alternate" action:@selector(connect:) inMenu:serverMenu].alternate = YES;
	[self itemWithTitle:@"No Action" action:NULL inMenu:serverMenu];
	[self itemWithTitle:@"Search Channels and Actions" action:NSSelectorFromString(@"showChannelSpotlightWindow:") inMenu:serverMenu];

	[serverMenu addItem:[NSMenuItem separatorItem]];

	NSMenu *modesMenu = [[NSMenu alloc] initWithTitle:@"Modes"];

	modesMenu.autoenablesItems = NO;

	[self itemWithTitle:@"Moderated" action:@selector(connect:) inMenu:modesMenu];

	[serverMenu addItemWithTitle:@"Modes" action:NULL keyEquivalent:@""].submenu = modesMenu;

	[mainMenu addItemWithTitle:@"Server" action:NULL keyEquivalent:@""].submenu = serverMenu;

	NSArray<TDCChannelSpotlightSearchResult *> *results = [TDCChannelSpotlightSearchResult searchResultsForActionsInMenu:mainMenu];

	NSArray *titles = [results valueForKeyPath:@"menuItem.title"];
	NSArray *paths = [results valueForKey:@"menuPath"];

	NSArray *expectedTitles = @[@"Connect", @"Moderated"];
	NSArray *expectedPaths = @[@"Server", @"Server › Modes"];

	XCTAssertEqualObjects(titles, expectedTitles);
	XCTAssertEqualObjects(paths, expectedPaths);

	TDCChannelSpotlightSearchResult *connectResult = results.firstObject;

	XCTAssertEqualObjects(connectResult.keyEquivalentDescription, @"⇧⌘K");
	XCTAssertNil(connectResult.clientId);

	[connectResult recalculateDistanceWith:@"conn"];

	XCTAssertGreaterThan(connectResult.distance.doubleValue, 0.5);
}

- (void)connect:(nullable id)sender
{
}

@end

NS_ASSUME_NONNULL_END
