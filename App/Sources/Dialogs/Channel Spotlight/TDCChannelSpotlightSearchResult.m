/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "NSObjectHelperPrivate.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TLOLocalization.h"
#import "TDCChannelSpotlightSearchResultPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelSpotlightSearchResult ()
@property (nonatomic, weak, readwrite, nullable) IRCChannel *channel;
@property (nonatomic, weak, readwrite, nullable) NSMenuItem *menuItem;
@property (nonatomic, copy, readwrite, nullable) NSString *menuPath;
@property (nonatomic, assign, readwrite) BOOL isMenuAction;
@property (nonatomic, copy, readwrite) NSNumber *distance;
@end

@implementation TDCChannelSpotlightSearchResult

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super init])) {
		self.channel = channel;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (instancetype)initWithMenuItem:(NSMenuItem *)menuItem path:(NSString *)menuPath
{
	NSParameterAssert(menuItem != nil);
	NSParameterAssert(menuPath != nil);

	if ((self = [super init])) {
		self.menuItem = menuItem;
		self.menuPath = menuPath;
		self.isMenuAction = YES;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.distance = @(0.0);
}

- (NSComparisonResult)compare:(TDCChannelSpotlightSearchResult *)other
{
	double localDistance = self.distance.doubleValue;

	double remoteDistance = other.distance.doubleValue;

	if (localDistance > remoteDistance) {
		return NSOrderedAscending;
	} else if (localDistance < remoteDistance) {
		return NSOrderedDescending;
	}

	return NSOrderedSame;
}

- (void)recalculateDistanceWith:(NSString *)searchString
{
	NSParameterAssert(searchString != nil);

	if (searchString.length == 0) {
		self.distance = @(0.0);

		return;
	}

	NSString *searchableString = ((self.isMenuAction) ? self.menuItem.title : self.channel.name);

	if (searchableString == nil) {
		self.distance = @(0.0);

		return;
	}

	double distance = [searchableString compareWithWord:searchString lengthPenaltyWeight:1.0];

	self.distance = @(distance);
}

- (nullable NSString *)clientId
{
	return self.channel.associatedClient.uniqueIdentifier;
}

#pragma mark -
#pragma mark Menu Commands

+ (NSArray<TDCChannelSpotlightSearchResult *> *)searchResultsForActionsInMenu:(NSMenu *)menu
{
	NSParameterAssert(menu != nil);

	NSMutableArray<TDCChannelSpotlightSearchResult *> *searchResults = [NSMutableArray array];

	[self _addSearchResultsForActionsInMenu:menu path:nil to:searchResults];

	return [searchResults copy];
}

+ (void)_addSearchResultsForActionsInMenu:(NSMenu *)menu path:(nullable NSString *)menuPath to:(NSMutableArray<TDCChannelSpotlightSearchResult *> *)searchResults
{
	NSParameterAssert(menu != nil);
	NSParameterAssert(searchResults != nil);

	if (menu == NSApp.servicesMenu) {
		return;
	}

	/* Enables the items as the menu would when it opens */
	[menu update];

	/* Listed elsewhere (channels) or of no use here (this box, the window list) */
	static NSSet<NSString *> *excludedActions = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		excludedActions = [NSSet setWithArray:@[
			@"showChannelSpotlightWindow:",
			@"emptyAction:",
			@"_navigateToChannelInNavigationList:",
			@"makeKeyAndOrderFront:"
		]];
	});

	for (NSMenuItem *item in menu.itemArray) {
		if (item.separatorItem || item.hidden || item.alternate || item.view != nil) {
			continue;
		}

		NSString *title = item.title;

		if (item.submenu) {
			/* Top-level menus give their name; an item without a title uses its menu's */
			NSString *submenuTitle = ((title.length > 0) ? title : item.submenu.title);

			NSString *submenuPath = ((menuPath) ? [NSString stringWithFormat:TXLocalizationNotNeeded(@"%@ \u203A %@"), menuPath, submenuTitle] : submenuTitle);

			[self _addSearchResultsForActionsInMenu:item.submenu path:submenuPath to:searchResults];

			continue;
		}

		if (title.length == 0) {
			continue;
		}

		if (menuPath == nil || item.action == NULL || item.enabled == NO) {
			continue;
		}

		if ([excludedActions containsObject:NSStringFromSelector(item.action)]) {
			continue;
		}

		[searchResults addObject:[[self alloc] initWithMenuItem:item path:menuPath]];
	}
}

- (nullable NSString *)keyEquivalentDescription
{
	NSMenuItem *item = self.menuItem;

	NSString *key = item.keyEquivalent;

	if (key.length == 0) {
		return nil;
	}

	static NSDictionary<NSString *, NSString *> *specialKeys = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		specialKeys = @{
			@"\r" : TXLocalizationNotNeeded(@"\u21A9"),					// return
			@"\b" : TXLocalizationNotNeeded(@"\u232B"),					// delete
			@"\x7f" : TXLocalizationNotNeeded(@"\u232B"),
			@"\x1b" : TXLocalizationNotNeeded(@"\u238B"),				// escape
			@"\t" : TXLocalizationNotNeeded(@"\u21E5"),					// tab
			@" " : TXLocalizationNotNeeded(@"\u2423"),
			[NSString stringWithFormat:@"%C", (unichar)NSUpArrowFunctionKey] : TXLocalizationNotNeeded(@"\u2191"),
			[NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey] : TXLocalizationNotNeeded(@"\u2193"),
			[NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey] : TXLocalizationNotNeeded(@"\u2190"),
			[NSString stringWithFormat:@"%C", (unichar)NSRightArrowFunctionKey] : TXLocalizationNotNeeded(@"\u2192"),
			[NSString stringWithFormat:@"%C", (unichar)NSDeleteFunctionKey] : TXLocalizationNotNeeded(@"\u2326"),
			[NSString stringWithFormat:@"%C", (unichar)NSPageUpFunctionKey] : TXLocalizationNotNeeded(@"\u21DE"),
			[NSString stringWithFormat:@"%C", (unichar)NSPageDownFunctionKey] : TXLocalizationNotNeeded(@"\u21DF")
		};
	});

	NSEventModifierFlags modifiers = item.keyEquivalentModifierMask;

	/* An uppercase key means Shift */
	if ([key isEqualToString:key.lowercaseString] == NO) {
		modifiers |= NSEventModifierFlagShift;
	}

	NSMutableString *description = [NSMutableString string];

	if (modifiers & NSEventModifierFlagControl) {
		[description appendString:TXLocalizationNotNeeded(@"\u2303")];
	}

	if (modifiers & NSEventModifierFlagOption) {
		[description appendString:TXLocalizationNotNeeded(@"\u2325")];
	}

	if (modifiers & NSEventModifierFlagShift) {
		[description appendString:TXLocalizationNotNeeded(@"\u21E7")];
	}

	if (modifiers & NSEventModifierFlagCommand) {
		[description appendString:TXLocalizationNotNeeded(@"\u2318")];
	}

	[description appendString:(specialKeys[key] ?: key.uppercaseString)];

	return [description copy];
}

@end

NS_ASSUME_NONNULL_END
