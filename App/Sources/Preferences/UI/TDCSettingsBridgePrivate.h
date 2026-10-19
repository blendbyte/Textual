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

NS_ASSUME_NONNULL_BEGIN

/* A picture of a style of one's own was taken */
TEXTUAL_EXTERN NSString * const TDCSettingsBridgeStylePreviewsDidChangeNotification;

/* What the Settings window (12.11, SwiftUI) needs from the rest of the app
 beyond plain preference keys, which it reads and writes itself */
@interface TDCSettingsBridge : NSObject
/* Updates (Sparkle builds only): 0 download and install, 1 only tell me, 2 don't check */
@property (class, readonly) BOOL updatesAvailable;
@property (class) NSInteger updateMode;
+ (void)betaUpdatesChanged;

/* A preference changed: what depends on it updates */
+ (void)preferenceChangedForKey:(NSString *)key;

@property (class) BOOL preventSleepWhileConnected;
@property (class) BOOL keepChannelListSorted;
@property (class) NSInteger noticeDestination; // TXNoticeSendLocation
@property (class) NSInteger scrollbackVisibleLimit; // 0 the default

/* Colors stored as archives; nil is the default */
+ (nullable NSColor *)colorForKey:(NSString *)key;
+ (void)setColor:(nullable NSColor *)color forKey:(NSString *)key;
+ (void)resetMemberListColors;

/* The color used while a color is the default (nil): the lists' own */
+ (nullable NSColor *)defaultColorForKey:(NSString *)key;

/* Aliases: [name, commands] pairs, sorted; invalid ones aren't saved */
@property (class, copy) NSArray<NSArray<NSString *> *> *aliases;
+ (BOOL)isValidAliasName:(NSString *)name;

/* Files */
@property (class, readonly, copy, nullable) NSURL *downloadFolderURL;
+ (void)chooseDownloadFolderInWindow:(NSWindow *)window completionHandler:(void (^)(void))completionHandler;
+ (void)clearDownloadFolder;
@property (class, readonly, copy, nullable) NSString *uploadDestinationName;
+ (void)editUploadDestinationInWindow:(NSWindow *)window completionHandler:(void (^)(void))completionHandler;
@property (class) BOOL sendsLongPastesToPasteService;
@property (class) NSInteger fileTransferPortRangeStart;
@property (class) NSInteger fileTransferPortRangeEnd;

/* Advanced */
+ (void)editCustomStyleSheetInWindow:(NSWindow *)window;

/* Extensions */
@property (class, readonly, copy) NSArray<NSString *> *addonCommands;
+ (void)openAddonsFolder;
@property (class, readonly, copy) NSArray<NSString *> *pluginPaneTitles;
+ (nullable NSView *)pluginPaneViewAtIndex:(NSUInteger)index;

/* Sections not rebuilt yet: the old Preferences window at its pane (a tag) */
+ (void)showLegacyPreferencesPaneWithTag:(NSInteger)tag;

/* The window closed */
+ (void)settingsWindowWillClose;
@end

@interface TDCSettingsBridge (Appearance)
/* The main window's light or dark look (nil: the Mac's), which Settings follows */
@property (class, readonly, nullable) NSAppearance *mainWindowAppearance;

/* Appearance (S2): the styles, as dictionaries with "name", "location"
 (TPCThemeStorageLocation), "displayName", "bundled" and "selected" */
@property (class, readonly, copy) NSArray<NSDictionary<NSString *, id> *> *styles;
+ (void)selectStyleNamed:(NSString *)name location:(NSInteger)location;

/* A picture of the style: the bundled ones' from the app, a style of one's own
 from the chat the last time it was used (nil before) */
+ (nullable NSImage *)previewForStyleNamed:(NSString *)name location:(NSInteger)location dark:(BOOL)dark;

/* The active style chose some settings itself: which ("time format, font"), or nil */
@property (class, readonly, copy, nullable) NSString *settingsChosenByStyle;
@property (class, readonly) BOOL styleSupportsChatDisplay;
+ (void)openStyleFilesInWindow:(NSWindow *)window;

/* Pictures of styles of one's own: taken after a style loads (from now on) */
+ (void)startTakingStylePreviews;

/* Chat or Classic; changing it may ask whether to change the formats too */
+ (NSInteger)messageGroupingStyle;
+ (void)setMessageGroupingStyle:(NSInteger)messageGroupingStyle inWindow:(nullable NSWindow *)window;

/* The chat's font */
@property (class, readonly, copy) NSString *fontDescription;
@property (class, readonly) BOOL fontIsSystemFont;
@property (class, readonly) BOOL fontChosenByStyle;
+ (void)chooseFont;
+ (void)useSystemFont;
@end

@interface TDCSettingsBridge (Messages)
/* The time a format gives for 14:02:40 today plus seconds, for the sample */
+ (nullable NSString *)sampleTimeWithFormat:(NSString *)format offset:(NSTimeInterval)offset;

@property (class, readonly) BOOL timestampFormatChosenByStyle;
@property (class, readonly) BOOL nicknameFormatChosenByStyle;
@end

NS_ASSUME_NONNULL_END
