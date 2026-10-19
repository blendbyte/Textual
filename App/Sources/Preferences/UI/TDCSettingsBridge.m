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
#import "TDCAlert.h"
#import "TPCTheme.h"
#import "TPCThemeControllerPrivate.h"
#import "TXGlobalModels.h"
#import "TPCThemePrivate.h"
#import "TVCLogController.h"
#import "TVCLogView.h"
#import "NSStringHelper.h"
#import <WebKit/WebKit.h>

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

NSString * const TDCSettingsBridgeStylePreviewsDidChangeNotification = @"TDCSettingsBridgeStylePreviewsDidChangeNotification";

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
	NSInteger value = MAX(_fileTransferPortRangeMin, MIN(TXMaximumTCPPort, fileTransferPortRangeStart));

	[TPCPreferences setFileTransferPortRangeStart:(uint16_t)value];

	/* A start past the end moves the end along, so a new range can be typed from either side */
	if ([TPCPreferences fileTransferPortRangeEnd] < value) {
		[TPCPreferences setFileTransferPortRangeEnd:(uint16_t)value];
	}
}

+ (NSInteger)fileTransferPortRangeEnd
{
	return [TPCPreferences fileTransferPortRangeEnd];
}

+ (void)setFileTransferPortRangeEnd:(NSInteger)fileTransferPortRangeEnd
{
	NSInteger value = MAX(_fileTransferPortRangeMin, MIN(TXMaximumTCPPort, fileTransferPortRangeEnd));

	[TPCPreferences setFileTransferPortRangeEnd:(uint16_t)value];

	if ([TPCPreferences fileTransferPortRangeStart] > value) {
		[TPCPreferences setFileTransferPortRangeStart:(uint16_t)value];
	}
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

#pragma mark -
#pragma mark Appearance

/* The font panel's target while it changes the chat's font */
@interface TDCSettingsFontTarget : NSObject
@end

@implementation TDCSettingsFontTarget

- (void)changeChatFont:(NSFontManager *)sender
{
	NSFont *newFont = [sender convertFont:[TPCPreferences themeChannelViewFont]];

	[TPCPreferences setThemeChannelViewFontName:newFont.fontName];
	[TPCPreferences setThemeChannelViewFontSize:newFont.pointSize];

	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

@end

@implementation TDCSettingsBridge (Appearance)

+ (nullable NSAppearance *)mainWindowAppearance
{
	return mainWindow().appearance;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)styles
{
	NSMutableArray *styles = [NSMutableArray array];

	NSString *currentName = themeController().name;

	TPCThemeStorageLocation currentLocation = themeController().storageLocation;

	[themeController() enumerateAvailableThemesWithBlock:^(NSString *name, TPCThemeStorageLocation location, BOOL multipleVariants, BOOL *stop) {
		NSString *displayName = name;

		if (multipleVariants) {
			displayName = [NSString stringWithFormat:@"%@ (%@)", name, [TPCThemeController descriptionForStorageLocation:location]];
		}

		[styles addObject:@{
			@"name" : name,
			@"location" : @(location),
			@"displayName" : displayName,
			@"bundled" : @(location == TPCThemeStorageLocationBundle),
			@"selected" : @([name isEqualToString:currentName] && location == currentLocation)
		}];
	}];

	return [styles copy];
}

+ (void)selectStyleNamed:(NSString *)name location:(NSInteger)location
{
	NSParameterAssert(name != nil);

	NSString *newTheme = [TPCThemeController buildFilename:name forStorageLocation:location];

	if (newTheme == nil || [[TPCPreferences themeName] isEqualToString:newTheme]) {
		return;
	}

	[TPCPreferences setThemeName:newTheme];

	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

/* Application Support/Textual/Style Previews: pictures of styles of one's own */
+ (nullable NSURL *)_snapshotURLForStyleNamed:(NSString *)name location:(NSInteger)location dark:(BOOL)dark
{
	NSString *filename = [TPCThemeController buildFilename:name forStorageLocation:location];

	NSString *folder = [TPCPathInfo applicationSupport];

	if (filename == nil || folder == nil) {
		return nil;
	}

	NSString *file = [NSString stringWithFormat:@"%@ %@.png", filename.safeFilename, ((dark) ? @"dark" : @"light")];

	return [NSURL fileURLWithPath:[[folder stringByAppendingPathComponent:@"Style Previews"] stringByAppendingPathComponent:file]];
}

+ (nullable NSImage *)previewForStyleNamed:(NSString *)name location:(NSInteger)location dark:(BOOL)dark
{
	NSParameterAssert(name != nil);

	/* Styles with only one look have only the dark picture */
	if (location == TPCThemeStorageLocationBundle) {
		for (NSString *look in ((dark) ? @[@"dark"] : @[@"light", @"dark"])) {
			NSString *file = [NSString stringWithFormat:@"Style Previews/%@ %@.jpg", name, look];

			NSImage *image = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle].resourceURL URLByAppendingPathComponent:file]];

			if (image) {
				return image;
			}
		}
	}

	NSURL *snapshotURL = [self _snapshotURLForStyleNamed:name location:location dark:dark];

	if (snapshotURL == nil) {
		return nil;
	}

	return [[NSImage alloc] initWithContentsOfURL:snapshotURL];
}

/* After a style of one's own loaded: a picture of the chat, for its preview */
+ (void)snapshotActiveStyle
{
	if (themeController().bundledTheme) {
		return;
	}

	TVCMainWindow *window = mainWindow();

	NSView *webView = window.selectedViewController.backingView.webView;

	if ([webView isKindOfClass:[WKWebView class]] == NO || webView.window == nil) {
		return;
	}

	NSURL *snapshotURL = [self _snapshotURLForStyleNamed:themeController().name location:themeController().storageLocation dark:window.usingDarkAppearance];

	if (snapshotURL == nil) {
		return;
	}

	WKSnapshotConfiguration *configuration = [WKSnapshotConfiguration new];

	/* The newest lines, at the bottom; about as much as the bundled pictures show */
	CGFloat height = MIN(380, NSHeight(webView.bounds));

	configuration.rect = NSMakeRect(0, (NSHeight(webView.bounds) - height), MIN(460, NSWidth(webView.bounds)), height);

	configuration.snapshotWidth = @(460);

	[(WKWebView *)webView takeSnapshotWithConfiguration:configuration completionHandler:^(NSImage * _Nullable image, NSError * _Nullable error) {
		if (image == nil) {
			return;
		}

		CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];

		if (cgImage == NULL) {
			return;
		}

		NSData *data = [[[NSBitmapImageRep alloc] initWithCGImage:cgImage] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];

		[RZFileManager() createDirectoryAtURL:snapshotURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];

		[data writeToURL:snapshotURL atomically:YES];

		[RZNotificationCenter() postNotificationName:TDCSettingsBridgeStylePreviewsDidChangeNotification object:nil];
	}];
}

+ (void)_themeDidReload:(NSNotification *)notification
{
	/* The chat redraws in the new style first */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self snapshotActiveStyle];
	});
}

+ (void)startTakingStylePreviews
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		[RZNotificationCenter() addObserver:self selector:@selector(_themeDidReload:) name:TVCMainWindowDidReloadThemeNotification object:nil];
	});

	/* A style of one's own in use without a picture yet */
	NSURL *snapshotURL = [self _snapshotURLForStyleNamed:themeController().name location:themeController().storageLocation dark:mainWindow().usingDarkAppearance];

	if (snapshotURL && [RZFileManager() fileExistsAtPath:snapshotURL.path] == NO) {
		[self snapshotActiveStyle];
	}
}

+ (nullable NSString *)settingsChosenByStyle
{
	NSMutableArray<NSString *> *chosen = [NSMutableArray array];

	if ([TPCPreferences themeTimestampFormatPreferenceUserConfigurable] == NO) {
		[chosen addObject:TXTLS(@"TDCPreferencesController[set-app-ct]")];
	}

	if ([TPCPreferences themeNicknameFormatPreferenceUserConfigurable] == NO) {
		[chosen addObject:TXTLS(@"TDCPreferencesController[set-app-cn]")];
	}

	if ([TPCPreferences themeChannelViewFontPreferenceUserConfigurable] == NO) {
		[chosen addObject:TXTLS(@"TDCPreferencesController[set-app-cf]")];
	}

	if (chosen.count == 0) {
		return nil;
	}

	return [chosen componentsJoinedByString:@", "];
}

+ (BOOL)styleSupportsChatDisplay
{
	return theme().supportsGroupedDisplay;
}

+ (void)openStyleFilesInWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	if (themeController().bundledTheme == NO) {
		[RZWorkspace() openURL:themeController().originalURL];

		return;
	}

	/* A bundled style is replaced by updates: offer a copy, or custom CSS */
	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCPreferencesController[ojj-ap]")
							 title:TXTLS(@"TDCPreferencesController[5jv-aw]")
					 defaultButton:TXTLS(@"TDCPreferencesController[6ws-av]")
				   alternateButton:TXTLS(@"TDCPreferencesController[aib-iy]")
					   otherButton:TXTLS(@"TDCPreferencesController[dj8-1t]")
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseDefault) {
			[RZWorkspace() openURL:themeController().originalURL];
		} else if (buttonClicked == TDCAlertResponseAlternate) {
			[[underlyingAlert window] orderOut:nil];

			[self editCustomStyleSheetInWindow:window];
		} else if (buttonClicked == TDCAlertResponseOther) {
			[[underlyingAlert window] orderOut:nil];

			[themeController() copyActiveThemeToDestinationLocation:TPCThemeStorageLocationCustom reloadOnCopy:YES openOnCopy:YES];
		}
	}];
}

/* The time and nickname formats each display is made for */
+ (NSString *)_nicknameFormatForGroupingStyle:(TVCLogLineGroupingStyle)groupingStyle
{
	return ((groupingStyle == TVCLogLineGroupingStyleGrouped) ? @"%@%n" : [TPCPreferences themeNicknameFormatDefault]);
}

+ (NSString *)_timestampFormatForGroupingStyle:(TVCLogLineGroupingStyle)groupingStyle
{
	return ((groupingStyle == TVCLogLineGroupingStyleGrouped) ? @"%H:%M" : [TPCPreferences themeTimestampFormatDefault]);
}

+ (NSInteger)messageGroupingStyle
{
	return [TPCPreferences messageGroupingStyle];
}

/* Formats still at the previous display's change with it; formats someone
 chose themselves only after asking (as the old Style section did) */
+ (void)setMessageGroupingStyle:(NSInteger)messageGroupingStyle inWindow:(nullable NSWindow *)window
{
	TVCLogLineGroupingStyle previousStyle = [TPCPreferences messageGroupingStyle];

	if (previousStyle == (TVCLogLineGroupingStyle)messageGroupingStyle) {
		return;
	}

	[TPCPreferences setMessageGroupingStyle:messageGroupingStyle];

	NSString *nicknameFormat = [self _nicknameFormatForGroupingStyle:messageGroupingStyle];
	NSString *timestampFormat = [self _timestampFormatForGroupingStyle:messageGroupingStyle];

	BOOL formatsAreDefaults =
	([[TPCPreferences themeNicknameFormat] isEqualToString:[self _nicknameFormatForGroupingStyle:previousStyle]] &&
	 [[TPCPreferences themeTimestampFormat] isEqualToString:[self _timestampFormatForGroupingStyle:previousStyle]]);

	BOOL formatsAlreadyMatch =
	([[TPCPreferences themeNicknameFormat] isEqualToString:nicknameFormat] &&
	 [[TPCPreferences themeTimestampFormat] isEqualToString:timestampFormat]);

	void (^reload)(void) = ^{
		[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
	};

	void (^changeFormats)(void) = ^{
		[TPCPreferences setThemeNicknameFormat:nicknameFormat];
		[TPCPreferences setThemeTimestampFormat:timestampFormat];
	};

	if (formatsAlreadyMatch || window == nil) {
		reload();

		return;
	}

	if (formatsAreDefaults) {
		changeFormats();

		reload();

		return;
	}

	NSString *timestampExample = (TXFormattedTimestamp([NSDate date], timestampFormat) ?: timestampFormat);

	NSString *nicknameExample = [nicknameFormat stringByReplacingOccurrencesOfString:@"%@" withString:@"@"];
	nicknameExample = [nicknameExample stringByReplacingOccurrencesOfString:@"%n" withString:@"alice"];

	NSString *displayName = ((messageGroupingStyle == TVCLogLineGroupingStyleGrouped) ? TXTLS(@"TDCPreferencesController[g7d-n1]") : TXTLS(@"TDCPreferencesController[g7d-n2]"));

	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCPreferencesController[g7d-b1]", displayName, timestampExample, nicknameExample)
							 title:TXTLS(@"TDCPreferencesController[g7d-t1]")
					 defaultButton:TXTLS(@"TDCPreferencesController[g7d-y1]")
				   alternateButton:TXTLS(@"TDCPreferencesController[g7d-k1]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseDefault) {
			changeFormats();
		}

		reload();
	}];
}

+ (NSString *)fontDescription
{
	NSString *name = (([TPCPreferences themeChannelViewFontIsSystemFont]) ? TXTLS(@"TDCPreferencesController[s7f-n1]") : ([TPCPreferences themeChannelViewFont].displayName ?: [TPCPreferences themeChannelViewFontName]));

	return [NSString stringWithFormat:@"%@ %@", name, [NSNumberFormatter localizedStringFromNumber:@([TPCPreferences themeChannelViewFontSize]) numberStyle:NSNumberFormatterDecimalStyle]];
}

+ (BOOL)fontIsSystemFont
{
	return [TPCPreferences themeChannelViewFontIsSystemFont];
}

+ (BOOL)fontChosenByStyle
{
	return ([TPCPreferences themeChannelViewFontPreferenceUserConfigurable] == NO);
}

+ (TDCSettingsFontTarget *)_fontTarget
{
	static TDCSettingsFontTarget *target = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		target = [TDCSettingsFontTarget new];
	});

	return target;
}

+ (void)chooseFont
{
	[RZFontManager() setSelectedFont:[TPCPreferences themeChannelViewFont] isMultiple:NO];

	RZFontManager().target = [self _fontTarget];
	RZFontManager().action = @selector(changeChatFont:);

	[RZFontManager() orderFrontFontPanel:nil];
}

+ (void)useSystemFont
{
	[TPCPreferences setThemeChannelViewFontName:TPCPreferencesThemeFontNameSystemFont];

	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

@end


#pragma mark -

@implementation TDCSettingsBridge (Messages)

+ (nullable NSString *)sampleTimeWithFormat:(NSString *)format offset:(NSTimeInterval)offset
{
	NSParameterAssert(format != nil);

	NSDate *date = [[NSCalendar currentCalendar] dateBySettingHour:14 minute:2 second:40 ofDate:[NSDate date] options:0];

	return TXFormattedTimestamp([date dateByAddingTimeInterval:offset], format);
}

+ (BOOL)timestampFormatChosenByStyle
{
	return ([TPCPreferences themeTimestampFormatPreferenceUserConfigurable] == NO);
}

+ (BOOL)nicknameFormatChosenByStyle
{
	return ([TPCPreferences themeNicknameFormatPreferenceUserConfigurable] == NO);
}

@end

NS_ASSUME_NONNULL_END
