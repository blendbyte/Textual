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
#import "TPCPreferencesUserDefaults.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "IRCWorld.h"
#import "HLSHistoricLogManagerPrivate.h"
#import "TLOLicenseManagerPrivate.h"
#import "TPCLegacyImportPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* YES once the user imported, or chose to start fresh: the launch offer
 then stays away (the menu item always works) */
#define _offeredDefaultsKey				@"Legacy Settings Import -> Offered"

/* Security-scoped bookmarks of granted folders, by path, so a later import
 from the same place needs no new grant */
#define _bookmarksDefaultsKey			@"Legacy Settings Import -> Bookmarks"

/* Development builds offer the import at launch only when asked to */
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
	/* Never over a licence this copy already has */
	if (self.licenseContainerIdentifier == nil || TLOLicenseManagerTextualIsRegistered()) {
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
@property (readwrite, copy) NSArray<NSString *> *styles;
@property (readwrite, copy) NSArray<NSString *> *extensions;
@property (readwrite, copy) NSArray<NSString *> *inlineMediaModules;
@property (readwrite) NSUInteger failureCount;
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

			return;
		}
	}

	self.result.importedScrollback = YES;
}

- (void)noteOtherContentOfGroupURL:(NSURL *)groupURL
{
	NSURL *textualURL = [self _textualFolderInGroupURL:groupURL];

	/* Textual 7's inline media modules: listed, never copied (3.5) */
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

/* Replace: first remove this copy's own settings, keeping what is never
 imported (KeysExcludedFromMigrate.plist and keys outside the master list,
 such as the import's own bookkeeping and the licence) */
- (void)importPreferences
{
	NSDictionary *preferences = self.preferences;

	if (preferences == nil) {
		return;
	}

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

	[RZUserDefaults() _migrateObject:self.servers forKey:IRCWorldClientListDefaultsKey];

	self.result.serverCount = self.servers.count;

	[self.class markOffered];

	LogToConsole("Legacy import: done, %{public}lu servers, %{public}lu files failed",
		self.result.serverCount, self.result.failureCount);
}

- (void)importLicenseFromFolderURL:(NSURL *)folderURL
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	NSData *licenseContents = [NSData dataWithContentsOfURL:[folderURL URLByAppendingPathComponent:_licenseFilename]];

	if (licenseContents == nil) {
		return;
	}

	self.result.triedLicense = YES;

	/* Verified before it is written, with the public key that setting up the
	 licence manager loads (at launch, the import runs before that) */
	TLOLicenseManagerSetup();

	self.result.importedLicense = (TLOLicenseManagerWriteLicenseFileContents(licenseContents) == TLOLicenseManagerActionResultSuccess);
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

/* Copies (never moves) each item, replacing an item of the same name. Links
 are followed, so the copy has the files and not a link back into the
 earlier version's folder. */
- (NSArray<NSString *> *)_copyContentsOfFolder:(NSURL *)sourceURL toFolder:(nullable NSURL *)destinationURL
{
	if (destinationURL == nil) {
		return @[];
	}

	NSMutableArray<NSString *> *copied = [NSMutableArray array];

	for (NSURL *item in [self _contentsOfFolder:sourceURL]) {
		NSURL *destinationItem = [destinationURL URLByAppendingPathComponent:item.lastPathComponent];

		[RZFileManager() removeItemAtURL:destinationItem error:NULL];

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
- (void)deleteEarlierDataInGroupURL:(NSURL *)groupURL
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

	for (NSURL *item in items) {
		NSError *deleteError = nil;

		if ([RZFileManager() removeItemAtURL:item error:&deleteError] == NO && [RZFileManager() fileExistsAtURL:item]) {
			LogToConsoleError("Legacy import: failed to delete %{public}@: %{public}@", item.path, deleteError.localizedDescription);
		}
	}

	[groupURL stopAccessingSecurityScopedResource];
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

	[RZWorkspace() openApplicationAtURL:RZMainBundle().bundleURL
						  configuration:configuration
					  completionHandler:^(NSRunningApplication *application, NSError *error) {
		if (error) {
			LogToConsoleError("Legacy import: failed to restart: %{public}@", error.localizedDescription);
		}
	}];

	/* Not in the completion handler: that only runs once the new copy has
	 launched, and the new copy waits for this one to quit first */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		exit(0);
	});
}

@end

NS_ASSUME_NONNULL_END
