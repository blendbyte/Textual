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

#include "BuildConfig.h"

#import "TLOLocalization.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "IRCWorldPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCChannelConfigPrivate.h"
#import "IRCServerPrivate.h"
#import "TXMasterController.h"
#import "HLSHistoricLogManagerPrivate.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOKeychainPrivate.h"
#import "TPCLegacyImportPrivate.h"
#import "TLOMessageArchivePrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* YES once the user imported, or chose to start fresh: the launch offer
 then stays away (the menu item always works) */
#define _offeredDefaultsKey				@"Legacy Settings Import -> Offered"

/* Security-scoped bookmarks of granted folders, by path, so a later import
 from the same place needs no new grant */
#define _bookmarksDefaultsKey			@"Legacy Settings Import -> Bookmarks"

/* Development builds offer the import at launch only when asked to */
#define _importedCompletelyDefaultsKey	@"Legacy Settings Import -> Imported Completely"
#define _offerInDebugDefaultsKey		@"Legacy Settings Import -> Offer in Development Builds"

#define _historicLogFilenameKey			@"TVCLogControllerHistoricLogFileSavePath_v3"

#define _transcriptFolderBookmarkKey	@"LogTranscriptDestinationSecurityBookmark_5"
#define _downloadFolderBookmarkKey		@"File Transfers -> File Transfer Download Folder Bookmark"

#define _licenseFilename				@"Textual_User_License_v2.plist"

#pragma mark -
#pragma mark Source

@interface TPCLegacyImportSource ()
@property (readwrite, copy) NSString *groupIdentifier;
@property (readwrite, copy) NSString *displayName;
@property (readwrite, copy, nullable) NSURL *outsidePreferencesURL;
@property (nonatomic, copy, nullable) NSString *licenseContainerIdentifier;
@property (nonatomic, assign) BOOL offeredFirst;
@end

@implementation TPCLegacyImportSource

+ (instancetype)sourceWithGroup:(NSString *)groupIdentifier name:(NSString *)displayName
{
	TPCLegacyImportSource *source = [self new];

	source.groupIdentifier = groupIdentifier;
	source.displayName = displayName;

	return source;
}

- (NSURL *)groupURL
{
	NSString *path = [NSString stringWithFormat:@"Library/Group Containers/%@", self.groupIdentifier];

	return [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:path isDirectory:YES];
}

- (NSURL *)preferencesURL
{
	if (self.outsidePreferencesURL) {
		return self.outsidePreferencesURL;
	}

	NSString *path = [NSString stringWithFormat:@"Library/Preferences/%@.plist", self.groupIdentifier];

	return [self.groupURL URLByAppendingPathComponent:path];
}

- (BOOL)groupExists
{
	return [RZFileManager() fileExistsAtURL:self.groupURL];
}

/* The sandbox lets Textual see that another app's files exist, and when
 they changed, but not read them */
- (BOOL)preferencesExist
{
	return [RZFileManager() fileExistsAtURL:self.preferencesURL];
}

- (nullable NSDate *)lastUsedDate
{
	return [RZFileManager() attributesOfItemAtPath:self.preferencesURL.path error:NULL].fileModificationDate;
}

- (nullable NSURL *)licenseFolderURL
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	/* Textual 7's licence file only proves the upgrade: not needed once this
	 copy is activated or already has one */
	if (self.licenseContainerIdentifier == nil || TLOLicenseManagerTextualIsRegistered() || TLOLicenseManagerTextual7LicenseFileExists()) {
		return nil;
	}

	NSString *path = [NSString stringWithFormat:@"Library/Containers/%@/Data/Library/Application Support/Textual", self.licenseContainerIdentifier];

	NSURL *folderURL = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:path isDirectory:YES];

	if ([RZFileManager() fileExistsAtURL:[folderURL URLByAppendingPathComponent:_licenseFilename]] == NO) {
		return nil;
	}

	return folderURL;
#else
	return nil;
#endif
}

@end

#pragma mark -
#pragma mark Result

@interface TPCLegacyImportResult ()
@property (readwrite) NSUInteger serverCount;
@property (readwrite) BOOL foundSavedPasswords;
@property (readwrite, copy) NSArray<NSString *> *styles;
@property (readwrite, copy) NSArray<NSString *> *extensions;
@property (readwrite, copy) NSArray<NSString *> *inlineMediaModules;
@property (readwrite) NSUInteger failureCount;
@property (readwrite, copy) NSArray<NSString *> *keptItems;
@property (readwrite) BOOL importedScrollback;
@property (readwrite) BOOL triedLicense;
@property (readwrite) BOOL importedLicense;
@property (readwrite) BOOL hadTranscriptFolder;
@property (readwrite) BOOL hadDownloadFolder;
@property (readwrite, copy, nullable) NSURL *encryptionComponentsURL;
@property (readwrite, copy, nullable) NSURL *scriptsURL;
@end

@implementation TPCLegacyImportResult

- (instancetype)init
{
	if ((self = [super init])) {
		self.styles = @[];
		self.extensions = @[];
		self.inlineMediaModules = @[];
		self.keptItems = @[];
	}

	return self;
}

@end

#pragma mark -
#pragma mark Import

@interface TPCPreferencesUserDefaults ()
- (void)_migrateObject:(nullable id)value forKey:(NSString *)defaultName;
@end

@interface TPCLegacyImport ()
@property (readwrite, strong) TPCLegacyImportSource *source;
@property (readwrite, strong) TPCLegacyImportResult *result;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *preferences;
@property (nonatomic, copy) NSArray *servers;
@end

@implementation TPCLegacyImport

+ (NSArray<TPCLegacyImportSource *> *)_sources
{
	TPCLegacyImportSource *direct = [TPCLegacyImportSource sourceWithGroup:@"8482Q6EPL6.com.codeux.apps.textual" name:TXTLS(@"Prompts[v6v-zm]")];

	direct.licenseContainerIdentifier = @"com.codeux.apps.textual";

	/* What most people come from, however recently something older was opened */
	direct.offeredFirst = YES;

	/* One group container for every App Store version (Textual 1 to 7) */
	TPCLegacyImportSource *appStore = [TPCLegacyImportSource sourceWithGroup:@"8482Q6EPL6.com.codeux.irc.textual" name:TXTLS(@"Prompts[hbs-te]")];

	/* The 2025 betas only */
	TPCLegacyImportSource *beta = [TPCLegacyImportSource sourceWithGroup:@"com.codeux.apps.textual.group" name:TXTLS(@"Prompts[ufu-b0]")];

	/* Before the sandbox: files in this group container, but preferences in
	 the regular preferences folder */
	TPCLegacyImportSource *preSandbox = [TPCLegacyImportSource sourceWithGroup:@"com.codeux.apps.textual" name:TXTLS(@"Prompts[9j6-4w]")];

	preSandbox.outsidePreferencesURL = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:@"Library/Preferences/com.codeux.apps.textual.plist"];

	return @[direct, appStore, beta, preSandbox];
}

/* macOS creates every group container an app declares, so most of them
 exist without any settings: only sources whose preferences file exists
 count, the most recently used first */
+ (NSArray<TPCLegacyImportSource *> *)availableSources
{
	NSMutableArray<TPCLegacyImportSource *> *sources = [NSMutableArray array];

	for (TPCLegacyImportSource *source in [self _sources]) {
		BOOL preferencesExist = source.preferencesExist;

		LogToConsole("Legacy import: %{public}@ - group: %{BOOL}d, preferences: %{BOOL}d",
			source.groupIdentifier, source.groupExists, preferencesExist);

		if (preferencesExist) {
			[sources addObject:source];
		}
	}

	[sources sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(TPCLegacyImportSource *source1, TPCLegacyImportSource *source2) {
		if (source1.offeredFirst != source2.offeredFirst) {
			return (source1.offeredFirst ? NSOrderedAscending : NSOrderedDescending);
		}

		NSDate *date1 = source1.lastUsedDate ?: [NSDate distantPast];
		NSDate *date2 = source2.lastUsedDate ?: [NSDate distantPast];

		return [date2 compare:date1];
	}];

	return [sources copy];
}

+ (BOOL)earlierVersionIsRunning
{
	NSArray *identifiers = @[@"com.codeux.apps.textual", @"com.codeux.apps.textual-mas", @"com.codeux.irc.textual5", @"com.codeux.irc.textual"];

	for (NSRunningApplication *application in RZWorkspace().runningApplications) {
		if ([identifiers containsObject:application.bundleIdentifier]) {
			return YES;
		}
	}

	return NO;
}

+ (BOOL)hasServers
{
	return ([RZUserDefaults() arrayForKey:IRCWorldClientListDefaultsKey].count > 0);
}

+ (BOOL)shouldOfferAtLaunch
{
	if ([RZUserDefaults() boolForKey:_offeredDefaultsKey]) {
		return NO;
	}

#ifdef DEBUG
	/* Textual Dev never looks at another installation's data unless asked */
	if ([RZUserDefaults() boolForKey:_offerInDebugDefaultsKey] == NO) {
		return NO;
	}
#endif

	if ([self hasServers]) {
		return NO;
	}

	return (self.availableSources.count > 0);
}

+ (nullable TPCLegacyImportSource *)sourceImportedCompletely
{
	NSString *groupIdentifier = [RZUserDefaults() stringForKey:_importedCompletelyDefaultsKey];

	if (groupIdentifier == nil) {
		return nil;
	}

	for (TPCLegacyImportSource *source in self.availableSources) {
		if ([source.groupIdentifier isEqualToString:groupIdentifier]) {
			return source;
		}
	}

	return nil;
}

+ (void)noteImportedCompletelyFromSource:(TPCLegacyImportSource *)source
{
	NSParameterAssert(source != nil);

	[RZUserDefaults() _migrateObject:source.groupIdentifier forKey:_importedCompletelyDefaultsKey];
}

+ (void)clearCompleteImportNote
{
	[RZUserDefaults() _migrateObject:nil forKey:_importedCompletelyDefaultsKey];
}

+ (void)markOffered
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:_offeredDefaultsKey];
}

#pragma mark -
#pragma mark Access

+ (nullable NSURL *)rememberedURLForFolder:(NSURL *)folderURL
{
	NSData *bookmark = [RZUserDefaults() dictionaryForKey:_bookmarksDefaultsKey][folderURL.path];

	if ([bookmark isKindOfClass:[NSData class]] == NO) {
		return nil;
	}

	BOOL isStale = NO;

	NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
										   options:NSURLBookmarkResolutionWithSecurityScope
									 relativeToURL:nil
							   bookmarkDataIsStale:&isStale
											 error:NULL];

	if (isStale || [url.path isEqualToString:folderURL.path] == NO) {
		return nil;
	}

	return url;
}

+ (void)rememberGrantedURL:(NSURL *)url
{
	NSError *bookmarkError = nil;

	NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
					 includingResourceValuesForKeys:nil
									  relativeToURL:nil
											  error:&bookmarkError];

	if (bookmark == nil) {
		LogToConsoleError("Legacy import: cannot keep access to %{public}@: %{public}@", url.path, bookmarkError.localizedDescription);

		return;
	}

	NSMutableDictionary *bookmarks = [[RZUserDefaults() dictionaryForKey:_bookmarksDefaultsKey] mutableCopy] ?: [NSMutableDictionary dictionary];

	bookmarks[url.path] = bookmark;

	[RZUserDefaults() _migrateObject:[bookmarks copy] forKey:_bookmarksDefaultsKey];
}

#pragma mark -
#pragma mark Steps

- (instancetype)initWithSource:(TPCLegacyImportSource *)source
{
	NSParameterAssert(source != nil);

	if ((self = [super init])) {
		self.source = source;
		self.result = [TPCLegacyImportResult new];
		self.servers = @[];
	}

	return self;
}

- (NSURL *)preferencesURLInGroupURL:(NSURL *)groupURL
{
	NSString *path = [NSString stringWithFormat:@"Library/Preferences/%@.plist", self.source.groupIdentifier];

	return [groupURL URLByAppendingPathComponent:path];
}

- (TPCLegacyImportReadError)readPreferencesAtURL:(NSURL *)preferencesURL
{
	NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfURL:preferencesURL];

	if (preferences == nil) {
		LogToConsoleError("Legacy import: cannot read preferences at %{public}@", preferencesURL.path);

		return TPCLegacyImportReadErrorUnreadable;
	}

	NSArray *servers = [preferences arrayForKey:IRCWorldClientListDefaultsKey];

	if (servers.count == 0) {
		/* Before Textual 6 */
		servers = [[preferences dictionaryForKey:@"World Controller"] arrayForKey:@"clients"] ?: @[];
	}

	if ([preferences unsignedIntegerForKey:@"TXRunCount"] == 0 && servers.count == 0) {
		return TPCLegacyImportReadErrorEmpty;
	}

	self.preferences = preferences;
	self.servers = servers;

	LogToConsole("Legacy import: start, from %{public}@", self.source.groupIdentifier);

	return TPCLegacyImportReadErrorNone;
}

- (NSUInteger)serverCount
{
	return self.servers.count;
}

- (NSURL *)_textualFolderInGroupURL:(NSURL *)groupURL
{
	return [groupURL URLByAppendingPathComponent:@"Library/Application Support/Textual" isDirectory:YES];
}

- (void)importStylesFromGroupURL:(NSURL *)groupURL
{
	self.result.styles = [self _copyContentsOfFolder:[[self _textualFolderInGroupURL:groupURL] URLByAppendingPathComponent:@"Styles"]
											toFolder:[TPCPathInfo customThemesURL]];
}

- (void)importExtensionsFromGroupURL:(NSURL *)groupURL
{
	self.result.extensions = [self _copyContentsOfFolder:[[self _textualFolderInGroupURL:groupURL] URLByAppendingPathComponent:@"Extensions"]
												toFolder:[TPCPathInfo customExtensionsURL]];
}

/* The store can't be replaced while it is open: it is put next to it and
 takes its place the next time it opens (HLSHistoricLogManager) */
- (void)importScrollbackFromGroupURL:(NSURL *)groupURL
{
	NSString *filename = [self.preferences stringForKey:_historicLogFilenameKey];

	if (filename.length == 0 || [filename containsString:@"/"]) {
		return;
	}

	NSURL *sourceURL = [[groupURL URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES] URLByAppendingPathComponent:filename];

	NSURL *stagedURL = [HLSHistoricLogManager importedStoreURL];

	if (stagedURL == nil || [RZFileManager() fileExistsAtURL:sourceURL] == NO) {
		return;
	}

	for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
		NSString *source = [sourceURL.path stringByAppendingString:suffix];
		NSString *destination = [stagedURL.path stringByAppendingString:suffix];

		[RZFileManager() removeItemAtPath:destination error:NULL];

		if ([RZFileManager() fileExistsAtPath:source] == NO) {
			continue;
		}

		NSError *copyError = nil;

		if ([RZFileManager() copyItemAtPath:source toPath:destination error:&copyError] == NO) {
			LogToConsoleError("Legacy import: failed to copy %{public}@: %{public}@", source, copyError.localizedDescription);

			self.result.failureCount += 1;

			/* The next launch adopts whatever is staged: a database without
			 its WAL file has lost the newest history, and replaced the current one */
			for (NSString *suffixCopied in @[@"", @"-wal", @"-shm"]) {
				[RZFileManager() removeItemAtPath:[stagedURL.path stringByAppendingString:suffixCopied] error:NULL];
			}

			return;
		}
	}

	self.result.importedScrollback = YES;

	/* Into the message archive at the next launch, though this copy's was before */
	[sharedMessageArchive() importScrollbackAgain];
}

- (void)noteOtherContentOfGroupURL:(NSURL *)groupURL
{
	NSURL *textualURL = [self _textualFolderInGroupURL:groupURL];

	/* Textual 7's inline media modules: listed, never copied */
	NSMutableArray *modules = [NSMutableArray array];

	for (NSURL *file in [self _contentsOfFolder:[textualURL URLByAppendingPathComponent:@"Inline Media Modules"]]) {
		if ([file.pathExtension isEqualToString:@"mediaPlugin"]) {
			[modules addObject:file.lastPathComponent.stringByDeletingPathExtension];
		}
	}

	self.result.inlineMediaModules = modules;

	/* OTR keys: Textual 8 has no OTR; the summary offers to save a copy */
	NSURL *encryptionComponentsURL = [textualURL URLByAppendingPathComponent:@"Encryption Components" isDirectory:YES];

	if ([self _contentsOfFolder:encryptionComponentsURL].count > 0) {
		self.result.encryptionComponentsURL = encryptionComponentsURL;
	}

	/* The scripts folder is outside the grant; the link to it is not */
	NSString *scriptsPath = [RZFileManager() destinationOfSymbolicLinkAtPath:[textualURL URLByAppendingPathComponent:@"Custom Scripts"].path error:NULL];

	if (scriptsPath) {
		self.result.scriptsURL = [NSURL fileURLWithPath:scriptsPath isDirectory:YES];
	}

	/* Bookmarks belong to the earlier version's identity; the folders
	 have to be chosen again */
	self.result.hadTranscriptFolder = (self.preferences[_transcriptFolderBookmarkKey] != nil);
	self.result.hadDownloadFolder = (self.preferences[_downloadFolderBookmarkKey] != nil);
}

/* The servers this copy had and the import doesn't bring back: their
 passwords, login keys and channel keys stayed in the Keychain */
- (void)destroyKeychainItemsOfReplacedServers
{
	NSMutableSet<NSString *> *importedIdentifiers = [NSMutableSet set];

	for (NSDictionary *server in self.servers) {
		NSString *identifier = server[@"uniqueIdentifier"];

		if ([identifier isKindOfClass:[NSString class]]) {
			[importedIdentifiers addObject:identifier];
		}
	}

	for (id server in [RZUserDefaults() arrayForKey:IRCWorldClientListDefaultsKey]) {
		if ([server isKindOfClass:[NSDictionary class]] == NO) {
			continue;
		}

		IRCClientConfig *config = [[IRCClientConfig alloc] initWithDictionary:server];

		if ([importedIdentifiers containsObject:config.uniqueIdentifier]) {
			continue;
		}

		[config destroyNicknamePasswordKeychainItem];
		[config destroyProxyPasswordKeychainItem];
		[config destroySASLECDSAKeyKeychainItem];

		for (IRCServer *endpoint in config.serverList) {
			[endpoint destroyServerPasswordKeychainItem];
		}

		for (IRCChannelConfig *channel in config.channelList) {
			[channel destroySecretKeyKeychainItem];
		}
	}
}

/* Replace: first remove this copy's own settings, keeping what is never
 imported (KeysExcludedFromMigrate.plist and keys outside the master list,
 such as the import's own bookkeeping and the licence) */
- (void)importPreferences
{
	NSDictionary *preferences = self.preferences;

	if (preferences == nil) {
		return;
	}

	[self destroyKeychainItemsOfReplacedServers];

	NSDictionary *current = [RZUserDefaults() persistentDomainForName:[TPCApplicationInfo applicationBundleIdentifier]];

	for (NSString *key in current) {
		if ([TPCPreferencesUserDefaults keyIsExcludedFromMigration:key] == NO) {
			[RZUserDefaults() _migrateObject:nil forKey:key];
		}
	}

	[preferences enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object, BOOL *stop) {
		if ([TPCPreferencesUserDefaults keyIsExcludedFromMigration:key]) {
			return;
		}

		[RZUserDefaults() _migrateObject:object forKey:key];
	}];

	/* Textual 7's default style (Simplified) and font (Lucida Grande 12) were
	 never stored: without these, the import would quietly switch to Textual 8's
	 (Lumen, the system font at 13). The new look is offered on purpose instead. */
	if (preferences[TPCPreferencesThemeNameDefaultsKey] == nil) {
		[RZUserDefaults() _migrateObject:@"resource:Simplified" forKey:TPCPreferencesThemeNameDefaultsKey];
	}

	if (preferences[TPCPreferencesThemeFontNameDefaultsKey] == nil) {
		[RZUserDefaults() _migrateObject:@"Lucida Grande" forKey:TPCPreferencesThemeFontNameDefaultsKey];
	}

	if (preferences[TPCPreferencesThemeFontSizeDefaultsKey] == nil) {
		[RZUserDefaults() _migrateObject:@(12.0) forKey:TPCPreferencesThemeFontSizeDefaultsKey];
	}

	/* Suggestions while typing are new: off for Textual 7 users (decided
	 2026-10-13), offered on purpose */
	for (NSString *key in TPCPreferencesInputCompletionDefaultsKeys()) {
		[RZUserDefaults() _migrateObject:@(NO) forKey:key];
	}

	/* Markdown when sending is new too: off for Textual 7 users (decided 2026-10-13) */
	[RZUserDefaults() _migrateObject:@(NO) forKey:TPCPreferencesInputMarkdownDefaultsKey];

	/* Sorting by name is new: off for Textual 7 users, whose list may be in an
	 order they arranged (decided 2026-11-08), offered on purpose. On, the list
	 is sorted as it loads, and that order can't be brought back. */
	[RZUserDefaults() _migrateObject:@(NO) forKey:@"Server List -> Keep Channels Sorted"];

	/* Textual 7 showed no previews unless turned on; Textual 8 does,
	 which is offered on purpose too */
	if (preferences[TPCPreferencesShowInlineMediaDefaultsKey] == nil) {
		[RZUserDefaults() _migrateObject:@(NO) forKey:TPCPreferencesShowInlineMediaDefaultsKey];
	}

	/* Textual 7's "Join, Part, Quit" checkbox (on unless turned off) is Show or Hide:
	 collapsing them is offered on purpose too */
	TXGeneralEventDisplay generalEventDisplay =
	[TPCPreferences generalEventDisplayForCheckboxValue:preferences[TPCPreferencesGeneralEventCheckboxDefaultsKey]];

	[RZUserDefaults() _migrateObject:@(generalEventDisplay) forKey:TPCPreferencesGeneralEventDisplayDefaultsKey];

	/* Textual 7's member list width, if never resized (120), becomes 190 at the
	 restart: the one-time step runs again for the imported layout */
	[RZUserDefaults() _migrateObject:nil forKey:@"TPCPreferences -> Migration -> Member List Width (800)"];

	[RZUserDefaults() _migrateObject:self.servers forKey:IRCWorldClientListDefaultsKey];

	/* From the menu, the running app keeps going until the restart: its
	 periodic and on-join saves wrote the old servers over these */
	worldController().savingSuspended = YES;

	self.result.serverCount = self.servers.count;

	self.result.foundSavedPasswords = [self _importedServersHaveSavedPasswords];

	[self.class markOffered];

	LogToConsole("Legacy import: done, %{public}lu servers, %{public}lu files failed",
		self.result.serverCount, self.result.failureCount);
}

/* From the dictionaries, not an IRCClientConfig: making one moves older entries
 into the Keychain, which can prompt before the summary has warned about it */
- (BOOL)_importedServersHaveSavedPasswords
{
	for (NSDictionary *client in self.servers) {
		if ([client isKindOfClass:[NSDictionary class]] == NO) {
			continue;
		}

		/* Older entries kept the server password under the client's identifier */
		if ([self _hasPasswordOfKinds:@[@(TLOKeychainItemKindNicknamePassword), @(TLOKeychainItemKindProxyPassword), @(TLOKeychainItemKindSASLECDSAKey), @(TLOKeychainItemKindServerPassword)] inDictionary:client]) {
			return YES;
		}

		for (NSDictionary *server in [client arrayForKey:@"serverList"]) {
			if ([self _hasPasswordOfKinds:@[@(TLOKeychainItemKindServerPassword)] inDictionary:server]) {
				return YES;
			}
		}

		for (NSDictionary *channel in [client arrayForKey:@"channelList"]) {
			if ([self _hasPasswordOfKinds:@[@(TLOKeychainItemKindChannelKey)] inDictionary:channel]) {
				return YES;
			}
		}
	}

	return NO;
}

- (BOOL)_hasPasswordOfKinds:(NSArray<NSNumber *> *)kinds inDictionary:(NSDictionary *)dictionary
{
	if ([dictionary isKindOfClass:[NSDictionary class]] == NO) {
		return NO;
	}

	NSString *identifier = dictionary[@"uniqueIdentifier"];

	if ([identifier isKindOfClass:[NSString class]] == NO) {
		return NO;
	}

	for (NSNumber *kind in kinds) {
		if ([TLOKeychain hasPasswordOfKind:kind.unsignedIntegerValue forIdentifier:identifier]) {
			return YES;
		}
	}

	return NO;
}

- (void)importLicenseFromFolderURL:(NSURL *)folderURL
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	NSData *licenseContents = [NSData dataWithContentsOfURL:[folderURL URLByAppendingPathComponent:_licenseFilename]];

	if (licenseContents == nil) {
		return;
	}

	self.result.triedLicense = YES;

	/* The licensing server checks it when the upgrade is asked for */
	self.result.importedLicense = TLOLicenseManagerImportTextual7LicenseFile(licenseContents);
#endif
}

#pragma mark -
#pragma mark Files

- (NSArray<NSURL *> *)_contentsOfFolder:(NSURL *)folderURL
{
	return [RZFileManager() contentsOfDirectoryAtURL:folderURL
						  includingPropertiesForKeys:nil
											 options:NSDirectoryEnumerationSkipsHiddenFiles
											   error:NULL] ?: @[];
}

/* Copies (never moves) each item; one of the same name already in Textual 8
 is kept and the earlier version's is listed in keptItems. Links are followed,
 so the copy has the files and not a link back into the earlier version's folder. */
- (NSArray<NSString *> *)_copyContentsOfFolder:(NSURL *)sourceURL toFolder:(nullable NSURL *)destinationURL
{
	if (destinationURL == nil) {
		return @[];
	}

	NSMutableArray<NSString *> *copied = [NSMutableArray array];

	for (NSURL *item in [self _contentsOfFolder:sourceURL]) {
		NSURL *destinationItem = [destinationURL URLByAppendingPathComponent:item.lastPathComponent];

		/* Added to the user's, as the import says: a Textual 8 style or
		 extension of the same name was deleted (not even to the Trash) */
		if ([destinationItem checkResourceIsReachableAndReturnError:NULL]) {
			LogToConsoleInfo("Legacy import: kept the existing %{public}@", destinationItem.path);

			/* Shown in the summary, and the earlier version's data isn't offered for deletion */
			self.result.keptItems = [self.result.keptItems arrayByAddingObject:item.lastPathComponent.stringByDeletingPathExtension];

			continue;
		}

		NSError *copyError = nil;

		if ([RZFileManager() copyItemAtURL:item.URLByResolvingSymlinksInPath toURL:destinationItem error:&copyError] == NO) {
			LogToConsoleError("Legacy import: failed to copy %{public}@: %{public}@", item.path, copyError.localizedDescription);

			self.result.failureCount += 1;

			continue;
		}

		[copied addObject:item.lastPathComponent.stringByDeletingPathExtension];
	}

	return [copied copy];
}

- (BOOL)saveEncryptionComponentsToFolderURL:(NSURL *)folderURL groupURL:(NSURL *)groupURL
{
	NSURL *sourceURL = self.result.encryptionComponentsURL;

	if (sourceURL == nil) {
		return NO;
	}

	NSURL *destinationURL = [folderURL URLByAppendingPathComponent:sourceURL.lastPathComponent isDirectory:YES];

	[groupURL startAccessingSecurityScopedResource];
	[folderURL startAccessingSecurityScopedResource];

	NSError *copyError = nil;

	BOOL copied = [RZFileManager() copyItemAtURL:sourceURL toURL:destinationURL error:&copyError];

	if (copied == NO) {
		LogToConsoleError("Legacy import: failed to save the OTR keys: %{public}@", copyError.localizedDescription);
	}

	[folderURL stopAccessingSecurityScopedResource];
	[groupURL stopAccessingSecurityScopedResource];

	return copied;
}

/* Only after the copy and only when asked: never the folder itself, only
 what Textual put in it */
- (BOOL)deleteEarlierDataInGroupURL:(NSURL *)groupURL
{
	[groupURL startAccessingSecurityScopedResource];

	NSMutableArray<NSURL *> *items = [NSMutableArray array];

	[items addObject:[self _textualFolderInGroupURL:groupURL]];

	if (self.source.outsidePreferencesURL == nil) {
		[items addObject:[self preferencesURLInGroupURL:groupURL]];
	}

	for (NSURL *file in [self _contentsOfFolder:[groupURL URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES]]) {
		if ([file.lastPathComponent hasPrefix:@"logControllerHistoricLog_"]) {
			[items addObject:file];
		}
	}

	BOOL deletedEverything = YES;

	for (NSURL *item in items) {
		NSError *deleteError = nil;

		if ([RZFileManager() removeItemAtURL:item error:&deleteError] == NO && [RZFileManager() fileExistsAtURL:item]) {
			LogToConsoleError("Legacy import: failed to delete %{public}@: %{public}@", item.path, deleteError.localizedDescription);

			deletedEverything = NO;
		}
	}

	[groupURL stopAccessingSecurityScopedResource];

	return deletedEverything;
}

#pragma mark -
#pragma mark Restart

/* Quits without saving (that would write the old server list over the
 imported one) and starts a new copy, which waits until this one is gone
 (main.m; the process identifier goes through the preferences because a
 sandboxed app can't pass launch arguments) */
+ (void)restart
{
	[RZUserDefaults() _migrateObject:@{@"processIdentifier" : @([NSProcessInfo processInfo].processIdentifier), @"date" : [NSDate date]}
							  forKey:@"TextualRestartAfterProcess"];

	[RZUserDefaults() synchronize];

	NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];

	configuration.createsNewApplicationInstance = YES;

	/* A launch refused at once (the copy moved or deleted) keeps this one
	 open rather than leaving nothing running */
	__block BOOL launchFailed = NO;

	[RZWorkspace() openApplicationAtURL:RZMainBundle().bundleURL
						  configuration:configuration
					  completionHandler:^(NSRunningApplication *application, NSError *error) {
		if (error == nil) {
			return;
		}

		LogToConsoleError("Legacy import: failed to restart: %{public}@", error.localizedDescription);

		dispatch_async(dispatch_get_main_queue(), ^{
			launchFailed = YES;

			[RZUserDefaults() removeObjectForKey:@"TextualRestartAfterProcess"];
		});
	}];

	/* Not in the completion handler: that only runs once the new copy has
	 launched, and the new copy waits for this one to quit first */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (launchFailed) {
			return;
		}

		exit(0);
	});
}

@end

NS_ASSUME_NONNULL_END
