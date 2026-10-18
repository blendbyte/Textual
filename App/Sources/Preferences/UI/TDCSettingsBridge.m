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

#import "TLOLocalization.h"

#import "NSObjectHelperPrivate.h"
#import "IRC.h"
#import "TXMasterController.h"
#import "TXMenuControllerPrivate.h"
#import "TXSharedApplicationPrivate.h"
#import "TPCPathInfo.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCMemberListAppearance.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListAppearance.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCSecurityScopedFolderPrivate.h"
#import "IRCAliasPrivate.h"
#import "IRCCommandIndex.h"
#import "THOPluginItemPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "TLOUploadDestinationPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCUploadDestinationSheetPrivate.h"
#import "TDCPreferencesUserStyleSheetPrivate.h"
#import "TDCSettingsBridgePrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#define _fileTransferPortRangeMin		1024
#define _scrollbackVisibleLinesMin		100
#define _scrollbackVisibleLinesMax		15000

/* Keeps the custom CSS sheet while it is open */
@interface TDCSettingsUserStyleSheetDelegate : NSObject <TDCPreferencesUserStyleSheetDelegate>
@property (nonatomic, strong, nullable) TDCPreferencesUserStyleSheet *sheet;
@end

@implementation TDCSettingsUserStyleSheetDelegate

- (void)userStyleSheetRulesChanged:(TDCPreferencesUserStyleSheet *)sender
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

- (void)userStyleSheetWillClose:(TDCPreferencesUserStyleSheet *)sender
{
	self.sheet = nil;
}

@end

@implementation TDCSettingsBridge

#pragma mark -
#pragma mark Updates

+ (BOOL)updatesAvailable
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	return YES;
#else
	return NO;
#endif
}

+ (NSInteger)updateMode
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUUpdater *updater = masterController().updateController.updater;

	if (updater.automaticallyChecksForUpdates == NO) {
		return 2;
	}

	return ((updater.automaticallyDownloadsUpdates) ? 0 : 1);
#else
	return 2;
#endif
}

+ (void)setUpdateMode:(NSInteger)updateMode
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUUpdater *updater = masterController().updateController.updater;

	updater.automaticallyChecksForUpdates = (updateMode != 2);
	updater.automaticallyDownloadsUpdates = (updateMode == 0);
#endif
}

+ (void)betaUpdatesChanged
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionSparkleFrameworkFeedURL];

	if ([TPCPreferences receiveBetaUpdates]) {
		[menuController() checkForUpdates:nil];
	}
#endif
}

#pragma mark -
#pragma mark Preferences

+ (void)preferenceChangedForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[TPCPreferences performReloadActionForKeys:@[key]];
}

+ (BOOL)preventSleepWhileConnected
{
	return [TPCPreferences preventSleepWhileConnected];
}

+ (void)setPreventSleepWhileConnected:(BOOL)preventSleepWhileConnected
{
	[TPCPreferences setPreventSleepWhileConnected:preventSleepWhileConnected];
}

+ (BOOL)keepChannelListSorted
{
	return [TPCPreferences keepChannelListSorted];
}

+ (void)setKeepChannelListSorted:(BOOL)keepChannelListSorted
{
	[TPCPreferences setKeepChannelListSorted:keepChannelListSorted];

	/* Sorted at once, not only from the next change */
	if (keepChannelListSorted) {
		[menuController() sortChannelListNames:nil];
	}
}

+ (NSInteger)noticeDestination
{
	return [TPCPreferences locationToSendNotices];
}

+ (void)setNoticeDestination:(NSInteger)noticeDestination
{
	[TPCPreferences setLocationToSendNotices:noticeDestination];
}

+ (NSInteger)scrollbackVisibleLimit
{
	return [TPCPreferences scrollbackVisibleLimit];
}

+ (void)setScrollbackVisibleLimit:(NSInteger)scrollbackVisibleLimit
{
	if (scrollbackVisibleLimit != 0) {
		scrollbackVisibleLimit = MAX(_scrollbackVisibleLinesMin, MIN(_scrollbackVisibleLinesMax, scrollbackVisibleLimit));
	}

	[TPCPreferences setScrollbackVisibleLimit:scrollbackVisibleLimit];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionScrollbackVisibleLimit];
}

#pragma mark -
#pragma mark Colors

+ (nullable NSColor *)colorForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	return [RZUserDefaults() colorForKey:key];
}

+ (void)setColor:(nullable NSColor *)color forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[RZUserDefaults() setColor:color forKey:key];

	[TPCPreferences performReloadActionForKeys:@[key]];
}

+ (void)resetMemberListColors
{
	NSArray *keys = @[@"User List Mode Badge Colors -> +y",
					  @"User List Mode Badge Colors -> +q",
					  @"User List Mode Badge Colors -> +a",
					  @"User List Mode Badge Colors -> +o",
					  @"User List Mode Badge Colors -> +h",
					  @"User List Mode Badge Colors -> +v",
					  @"User List Mode Badge Colors -> no mode"];

	for (NSString *key in keys) {
		[RZUserDefaults() setObject:nil forKey:key];
	}

	[TPCPreferences performReloadActionForKeys:keys];
}

+ (nullable NSColor *)defaultColorForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	TVCMainWindow *window = mainWindow();

	if ([key isEqualToString:@"Server List Unread Message Count Badge Colors -> Highlight"]) {
		return window.serverList.userInterfaceObjects.unreadBadgeHighlightBackgroundColorActiveWindow;
	} else if ([key isEqualToString:@"User List Mode Badge Colors -> no mode"]) {
		return window.memberList.userInterfaceObjects.markBadgeBackgroundColorActiveWindow;
	}

	return nil;
}

#pragma mark -
#pragma mark Aliases

+ (NSArray<NSArray<NSString *> *> *)aliases
{
	NSDictionary<NSString *, NSString *> *aliases = IRCAlias.aliases;

	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:aliases.count];

	for (NSString *name in [aliases.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
		[rows addObject:@[name, aliases[name]]];
	}

	return [rows copy];
}

+ (void)setAliases:(NSArray<NSArray<NSString *> *> *)rows
{
	NSParameterAssert(rows != nil);

	NSMutableDictionary<NSString *, NSString *> *aliases = [NSMutableDictionary dictionary];

	for (NSArray<NSString *> *row in rows) {
		if (row.count != 2) {
			continue;
		}

		NSString *name = row[0].lowercaseString;

		if ([name hasPrefix:@"/"]) {
			name = [name substringFromIndex:1];
		}

		NSString *commands = [row[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		if ([self isValidAliasName:name] == NO || commands.length == 0) {
			continue;
		}

		aliases[name] = commands;
	}

	[RZUserDefaults() setObject:[aliases copy] forKey:@"Input -> Aliases"];
}

+ (BOOL)isValidAliasName:(NSString *)name
{
	NSParameterAssert(name != nil);

	if ([name hasPrefix:@"/"]) {
		name = [name substringFromIndex:1];
	}

	return ([IRCAlias isValidAliasName:name.lowercaseString] && [IRCCommandIndex indexOfLocalCommand:name.lowercaseString] == NSNotFound);
}

#pragma mark -
#pragma mark Files

+ (nullable NSURL *)downloadFolderURL
{
	return [TXSharedApplication sharedFileTransferDialog].downloadDestinationURL;
}

+ (void)chooseDownloadFolderInWindow:(NSWindow *)window completionHandler:(void (^)(void))completionHandler
{
	NSParameterAssert(window != nil);
	NSParameterAssert(completionHandler != nil);

	NSOpenPanel *panel = [NSOpenPanel openPanel];

	panel.allowsMultipleSelection = NO;
	panel.canChooseDirectories = YES;
	panel.canChooseFiles = NO;
	panel.canCreateDirectories = YES;
	panel.resolvesAliases = YES;

	[panel beginSheetModalForWindow:window completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		NSData *bookmark = [TPCSecurityScopedFolder bookmarkForURL:panel.URLs[0]];

		if (bookmark) {
			[[TXSharedApplication sharedFileTransferDialog] setDownloadDestinationBookmark:bookmark];
		}

		completionHandler();
	}];
}

+ (void)clearDownloadFolder
{
	[[TXSharedApplication sharedFileTransferDialog] setDownloadDestinationBookmark:nil];
}

+ (nullable NSString *)uploadDestinationName
{
	return [TLOUploadDestination globalDestination].name;
}

+ (void)editUploadDestinationInWindow:(NSWindow *)window completionHandler:(void (^)(void))completionHandler
{
	NSParameterAssert(window != nil);
	NSParameterAssert(completionHandler != nil);

	[TDCUploadDestinationSheet editGlobalDestinationInWindow:window completionBlock:completionHandler];
}

+ (BOOL)sendsLongPastesToPasteService
{
	return [TLOUploadDestination sendsLongPastesToPasteService];
}

+ (void)setSendsLongPastesToPasteService:(BOOL)sendsLongPastesToPasteService
{
	[TLOUploadDestination setSendsLongPastesToPasteService:sendsLongPastesToPasteService];
}

/* The start of the range stays at or below its end */
+ (NSInteger)fileTransferPortRangeStart
{
	return [TPCPreferences fileTransferPortRangeStart];
}

+ (void)setFileTransferPortRangeStart:(NSInteger)fileTransferPortRangeStart
{
	NSInteger value = MAX(_fileTransferPortRangeMin, MIN([TPCPreferences fileTransferPortRangeEnd], fileTransferPortRangeStart));

	[TPCPreferences setFileTransferPortRangeStart:(uint16_t)value];
}

+ (NSInteger)fileTransferPortRangeEnd
{
	return [TPCPreferences fileTransferPortRangeEnd];
}

+ (void)setFileTransferPortRangeEnd:(NSInteger)fileTransferPortRangeEnd
{
	NSInteger value = MAX([TPCPreferences fileTransferPortRangeStart], MIN(TXMaximumTCPPort, fileTransferPortRangeEnd));

	[TPCPreferences setFileTransferPortRangeEnd:(uint16_t)value];
}

#pragma mark -
#pragma mark Advanced

+ (TDCSettingsUserStyleSheetDelegate *)userStyleSheetDelegate
{
	static TDCSettingsUserStyleSheetDelegate *delegate = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		delegate = [TDCSettingsUserStyleSheetDelegate new];
	});

	return delegate;
}

+ (void)editCustomStyleSheetInWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	TDCSettingsUserStyleSheetDelegate *delegate = [self userStyleSheetDelegate];

	if (delegate.sheet) {
		return;
	}

	TDCPreferencesUserStyleSheet *sheet = [[TDCPreferencesUserStyleSheet alloc] initWithWindow:window];

	sheet.delegate = delegate;

	[sheet start];

	delegate.sheet = sheet;
}

#pragma mark -
#pragma mark Extensions

+ (NSArray<NSString *> *)addonCommands
{
	NSMutableArray<NSString *> *commands = [NSMutableArray array];

	[commands addObjectsFromArray:sharedPluginManager().supportedAppleScriptCommands];
	[commands addObjectsFromArray:sharedPluginManager().supportedUserInputCommands];

	return [commands sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

+ (void)openAddonsFolder
{
	[RZWorkspace() openURL:[TPCPathInfo applicationSupportURL]];
}

+ (NSArray<NSString *> *)pluginPaneTitles
{
	NSMutableArray<NSString *> *titles = [NSMutableArray array];

	for (THOPluginItem *plugin in sharedPluginManager().pluginsWithPreferencePanes) {
		[titles addObject:(plugin.pluginPreferencesPaneMenuItemTitle ?: @"")];
	}

	return [titles copy];
}

+ (nullable NSView *)pluginPaneViewAtIndex:(NSUInteger)index
{
	NSArray *plugins = sharedPluginManager().pluginsWithPreferencePanes;

	if (index >= plugins.count) {
		return nil;
	}

	THOPluginItem *plugin = plugins[index];

	return plugin.pluginPreferencesPaneView;
}

#pragma mark -
#pragma mark Old Preferences

+ (void)showLegacyPreferencesPaneWithTag:(NSInteger)tag
{
	[menuController() showLegacyPreferencesPaneWithTag:tag];
}

+ (void)settingsWindowWillClose
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionHighlightKeywords |
										 TPCPreferencesReloadActionPreferencesChanged)];
}

@end

NS_ASSUME_NONNULL_END
