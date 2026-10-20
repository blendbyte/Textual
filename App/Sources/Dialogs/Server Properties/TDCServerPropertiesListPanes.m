/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "IRCClientConfigPrivate.h"
#import "IRCChannelConfig.h"
#import "TLOLocalization.h"
#import "TVCBasicTableView.h"
#import "TDCAddressBookSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TDCServerPropertiesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark Autojoin

@interface TDCServerPropertiesChannelsPane () <TDCChannelPropertiesSheetDelegate>
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, NSString *> *channelSecretKeys; // channel ID → key, read once
@end

@implementation TDCServerPropertiesChannelsPane

- (void)loadFromConfig:(IRCClientConfig *)config
{
	[self.arrayController addObjects:config.channelList];

	self.arrayController.filterPredicate = [NSPredicate predicateWithFormat:@"type == 0"]; // Is channel type

	[super loadFromConfig:config];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.channelList = self.allChannelConfigs;
}

/* The table shows the channels of a list that also holds queries (the
 "type == 0" filter). Rows are mapped to their objects and changes are made
 to the whole list: row numbers of the shown channels were applied to the
 whole list, so deleting a channel could delete a query and editing one
 could replace another. */
- (NSArray<IRCChannelConfig *> *)allChannelConfigs
{
	NSArray *content = self.arrayController.content;

	return ((content) ? [content copy] : @[]);
}

- (void)setAllChannelConfigs:(NSArray<IRCChannelConfig *> *)channelConfigs
{
	NSParameterAssert(channelConfigs != nil);

	self.arrayController.content = [channelConfigs mutableCopy];
}

- (void)showSheetForItem:(nullable IRCChannelConfig *)item
{
	TDCChannelPropertiesSheet *sheet = nil;

	if (item) {
		sheet = [[TDCChannelPropertiesSheet alloc] initWithConfig:item];

		sheet.window = self.propertiesSheet.sheet;
	} else {
		sheet = [[TDCChannelPropertiesSheet alloc] initWithWindow:self.propertiesSheet.sheet];
	}

	sheet.delegate = self;

	[sheet start];

	self.childSheet = sheet;
}

- (void)channelPropertiesSheet:(TDCChannelPropertiesSheet *)sender onOk:(IRCChannelConfig *)config
{
	[self addOrReplaceItem:config];
}

- (void)channelPropertiesSheetWillClose:(TDCChannelPropertiesSheet *)sender
{
	self.childSheet = nil;
}

- (void)addOrReplaceItem:(IRCChannelConfig *)config
{
	NSParameterAssert(config != nil);

	NSMutableArray *channelConfigs = [self.allChannelConfigs mutableCopy];

	NSUInteger entryIndex =
	[channelConfigs indexOfObjectPassingTest:^BOOL(IRCChannelConfig *object, NSUInteger index, BOOL *stop) {
		return [object.uniqueIdentifier isEqualToString:config.uniqueIdentifier];
	}];

	/* A new channel with the name of one in the list made two entries for it */
	if (entryIndex == NSNotFound) {
		NSUInteger duplicateIndex =
		[channelConfigs indexOfObjectPassingTest:^BOOL(IRCChannelConfig *object, NSUInteger index, BOOL *stop) {
			return ([object.channelName caseInsensitiveCompare:config.channelName] == NSOrderedSame);
		}];

		if (duplicateIndex != NSNotFound) {
			NSBeep();

			return;
		}
	}

	/* Its key may have changed */
	[self.channelSecretKeys removeObjectForKey:config.uniqueIdentifier];

	if (entryIndex == NSNotFound) {
		[channelConfigs addObject:config];
	} else {
		channelConfigs[entryIndex] = config;
	}

	self.allChannelConfigs = channelConfigs;
}

- (void)removeItem:(IRCChannelConfig *)config
{
	NSMutableArray *channelConfigs = [self.allChannelConfigs mutableCopy];

	[channelConfigs removeObjectIdenticalTo:config];

	self.allChannelConfigs = channelConfigs;
}

- (BOOL)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
	NSArray *channelList = self.items;

	IRCChannelConfig *movedConfig = channelList[fromIndex];

	IRCChannelConfig *configAfter = ((toIndex < channelList.count) ? channelList[toIndex] : nil);

	if (configAfter == movedConfig) {
		return NO;
	}

	NSMutableArray *channelConfigs = [self.allChannelConfigs mutableCopy];

	[channelConfigs removeObjectIdenticalTo:movedConfig];

	NSUInteger insertionIndex = ((configAfter) ? [channelConfigs indexOfObjectIdenticalTo:configAfter] : channelConfigs.count);

	[channelConfigs insertObject:movedConfig atIndex:insertionIndex];

	self.allChannelConfigs = channelConfigs;

	return YES;
}

- (nullable id)valueForColumn:(NSString *)columnId ofItem:(IRCChannelConfig *)config
{
	if ([columnId isEqualToString:@"name"]) {
		return config.channelName;
	} else if ([columnId isEqualToString:@"pass"]) {
		/* Dots of one length, like Channel Properties: the key is a secret */
		return (([self secretKeyForChannelConfig:config].length > 0) ? @"••••••••" : @"");
	} else if ([columnId isEqualToString:@"join"]) {
		return @(config.autoJoin);
	}

	return nil;
}

- (void)setValue:(nullable id)value forColumn:(NSString *)columnId ofItem:(IRCChannelConfig *)oldConfig
{
	IRCChannelConfigMutable *config = [oldConfig mutableCopy];

	if ([columnId isEqualToString:@"join"]) {
		config.autoJoin = [value boolValue];
	}

	NSMutableArray *channelConfigs = [self.allChannelConfigs mutableCopy];

	NSUInteger configIndex = [channelConfigs indexOfObjectIdenticalTo:oldConfig];

	if (configIndex != NSNotFound) {
		channelConfigs[configIndex] = [config copy];

		self.allChannelConfigs = channelConfigs;
	}
}

/* The key is read from the Keychain once per channel: it was read for every
 row each time the table drew */
- (NSString *)secretKeyForChannelConfig:(IRCChannelConfig *)config
{
	NSParameterAssert(config != nil);

	if (self.channelSecretKeys == nil) {
		self.channelSecretKeys = [NSMutableDictionary dictionary];
	}

	NSString *channelId = config.uniqueIdentifier;

	NSString *secretKey = self.channelSecretKeys[channelId];

	if (secretKey == nil) {
		secretKey = (config.secretKey ?: @"");

		self.channelSecretKeys[channelId] = secretKey;
	}

	return secretKey;
}

@end

#pragma mark -
#pragma mark Address Book

@interface TDCServerPropertiesAddressBookPane () <TDCAddressBookSheetDelegate>
- (IBAction)addAddressBookEntry:(nullable id)sender;
@end

@implementation TDCServerPropertiesAddressBookPane

- (void)loadFromConfig:(IRCClientConfig *)config
{
	[self.arrayController addObjects:config.ignoreList];

	[super loadFromConfig:config];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.ignoreList = self.items;
}

/* Add offers an ignore or a tracked user */
- (void)addItem:(nullable id)sender
{
	[self.addMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, 0) inView:sender];
}

- (void)addAddressBookEntry:(nullable id)sender
{
	if ([sender tag] == 3) {
		[self addIgnoreEntryWithHostmask:nil];
	} else if ([sender tag] == 4) {
		[self showSheet:[TDCAddressBookSheet sheetForNewEntryOfType:IRCAddressBookEntryTypeUserTracking]];
	}
}

- (void)addIgnoreEntryWithHostmask:(nullable NSString *)hostmask
{
	if (hostmask) {
		[self showSheet:[TDCAddressBookSheet sheetWithConfig:[IRCAddressBookEntry newIgnoreEntryForHostmask:hostmask]]];
	} else {
		[self showSheet:[TDCAddressBookSheet sheetForNewEntryOfType:IRCAddressBookEntryTypeIgnore]];
	}
}

- (void)editEntry:(IRCAddressBookEntry *)entry
{
	NSParameterAssert(entry != nil);

	NSInteger tableIndex = [self.items indexOfObject:entry];

	if (tableIndex == NSNotFound) {
		return;
	}

	[self.table selectItemAtIndex:tableIndex];

	[self editItem:nil];
}

- (void)showSheetForItem:(nullable IRCAddressBookEntry *)item
{
	if (item == nil) {
		[self addIgnoreEntryWithHostmask:nil];

		return;
	}

	[self showSheet:[TDCAddressBookSheet sheetWithConfig:item]];
}

- (void)showSheet:(TDCAddressBookSheet *)sheet
{
	NSParameterAssert(sheet != nil);

	sheet.delegate = self;

	sheet.window = self.propertiesSheet.sheet;

	[sheet start];

	self.childSheet = sheet;
}

- (void)addressBookSheet:(TDCAddressBookSheet *)sender onOk:(IRCAddressBookEntry *)config
{
	[self addOrReplaceItem:config];
}

- (void)addressBookSheetWillClose:(TDCAddressBookSheet *)sender
{
	self.childSheet = nil;
}

- (nullable id)valueForColumn:(NSString *)columnId ofItem:(IRCAddressBookEntry *)config
{
	if ([columnId isEqualToString:@"hostmask"]) {
		return config.hostmask;
	} else if ([columnId isEqualToString:@"type"]) {
		if (config.entryType == IRCAddressBookEntryTypeIgnore) {
			return TXTLS(@"TDCServerPropertiesSheet[f7o-x4]");
		} else {
			return TXTLS(@"TDCServerPropertiesSheet[b0g-0x]");
		}
	}

	return nil;
}

@end

NS_ASSUME_NONNULL_END
