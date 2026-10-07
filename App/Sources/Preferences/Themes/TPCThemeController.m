/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import "TXAppearance.h"
#import "TXGlobalModels.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TDCAlert.h"
#import "TDCProgressIndicatorSheetPrivate.h"
#import "TLOLocalization.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCResourceManager.h"
#import "TPCThemePrivate.h"
#import "TPCThemeControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TPCThemeControllerCustomThemeNameBasicPrefix			= @"user";
NSString * const TPCThemeControllerCustomThemeNameCompletePrefix		= @"user:";

NSString * const TPCThemeControllerBundledThemeNameBasicPrefix			= @"resource";
NSString * const TPCThemeControllerBundledThemeNameCompletePrefix		= @"resource:";

NSString * const TPCThemeControllerThemeListDidChangeNotification		= @"TPCThemeControllerThemeListDidChangeNotification";

typedef NSDictionary		<NSString *, TPCTheme *> 	*TPCThemeControllerThemeList;
typedef NSMutableDictionary	<NSString *, TPCTheme *> 	*TPCThemeControllerThemeListMutable;

/* Copy operation class is responsible for copying the active theme to a 
 different location when a user requests a local copy of the theme. */
@interface TPCThemeControllerCopyOperation : NSObject
@property (nonatomic, weak) TPCThemeController *themeController;
@property (nonatomic, copy) NSString *themeName; // Name without source prefix
@property (nonatomic, copy) NSString *pathBeingCopiedTo;
@property (nonatomic, copy) NSString *pathBeingCopiedFrom;
@property (nonatomic, assign) TPCThemeStorageLocation destinationLocation;
@property (nonatomic, assign) BOOL reloadThemeWhenCopied; // If YES, setThemeName: is called when copy completes. Otherwise, files are copied and nothing happens.
@property (nonatomic, assign) BOOL openThemeWhenCopied;
@property (nonatomic, strong) TDCProgressIndicatorSheet *progressIndicator;

- (void)beginOperation;
@end

@interface TPCThemeController ()
@property (nonatomic, copy) NSString *cachedThemeName;
@property (nonatomic, copy, readwrite) NSString *cacheToken;
@property (nonatomic, strong, readwrite) TPCTheme *theme;
@property (nonatomic, strong, nullable) TPCThemeControllerCopyOperation *currentCopyOperation;
@property (nonatomic, strong) TPCThemeControllerThemeListMutable bundledThemes;
@property (nonatomic, strong) TPCThemeControllerThemeListMutable customThemes;
@property (nonatomic, strong) XRFileSystemMonitor *themeMonitor;
@end

#pragma mark -
#pragma mark Theme Controller

@implementation TPCThemeController

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.bundledThemes = [NSMutableDictionary dictionary];
	self.customThemes = [NSMutableDictionary dictionary];

	[self populateThemes];

	[self startMonitoringThemes];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(applicationAppearanceChanged:)
								   name:TXApplicationAppearanceChangedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeIntegrityCompromised:)
								   name:TPCThemeIntegrityCompromisedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeWasDeleted:)
								   name:TPCThemeWasDeletedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeWasModified:)
								   name:TPCThemeWasModifiedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeVarietyChanged:)
								   name:TPCThemeAppearanceChangedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeVarietyChanged:)
								   name:TPCThemeVarietyChangedNotification
								 object:nil];
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Preparing theme controller");

	LogToConsoleTerminationProgress("Removing theme controller observers");

	[RZNotificationCenter() removeObserver:self];

	LogToConsoleTerminationProgress("Removing theme change observers");

	[self stopMonitoringThemes];

	LogToConsoleTerminationProgress("Empty theme cache");

	[self removeTemporaryCopyOfTheme];
}

- (NSURL *)originalURL
{
	return self.theme.originalURL;
}

- (NSString *)originalPath
{
	return self.originalURL.path;
}

- (NSURL *)temporaryURL
{
	return self.theme.temporaryURL;
}

- (NSString *)temporaryPath
{
	return self.temporaryURL.path;
}

- (TPCThemeSettings *)settings
{
	return self.theme.settings;
}

- (TPCThemeStorageLocation)storageLocation
{
	return self.theme.storageLocation;
}

- (NSString *)name
{
	return self.theme.name;
}

- (void)metadata:(void (^ NS_NOESCAPE)(NSString *fileName, TPCThemeStorageLocation storageLocation))metadataBlock ofThemeNamed:(NSString *)themeName
{
	NSParameterAssert(metadataBlock != nil);
	NSParameterAssert(themeName != nil);

	NSString *fileName = [self.class extractThemeName:themeName];

	if (fileName == nil) {
		return;
	}

	TPCThemeStorageLocation storageLocation = [self.class storageLocationOfThemeWithName:themeName];

	if (storageLocation == TPCThemeStorageLocationUnknown) {
		return;
	}

	metadataBlock(fileName, storageLocation);
}

- (BOOL)themeExists:(NSString *)themeName
{
	TPCTheme *theme = [self themeNamed:themeName createIfNecessary:YES];

	return theme.usable;
}

- (nullable TPCTheme *)themeNamed:(NSString *)themeName
{
	return [self themeNamed:themeName createIfNecessary:NO];
}

- (nullable TPCTheme *)themeNamed:(NSString *)themeName createIfNecessary:(BOOL)createIfNecessary
{
	NSParameterAssert(themeName != nil);

	__block TPCTheme *theme = nil;

	[self metadata:^(NSString *fileName, TPCThemeStorageLocation storageLocation) {
		TPCThemeControllerThemeListMutable list = [self mutableListForStorageLocation:storageLocation];

		if (list == nil) {
			return;
		}

		NSString *filePath = [self.class pathOfThemeWithFilename:fileName storageLocation:storageLocation];

		if (filePath == nil) {
			return;
		}

		NSURL *fileURL = [NSURL fileURLWithPath:filePath isDirectory:YES];

		theme =
		[self themeAtURL:fileURL
			withFilename:fileName
		 storageLocation:storageLocation
				  inList:list
	   createIfNecessary:createIfNecessary
		  skipFileExists:NO];
	} ofThemeNamed:themeName];

	return theme;
}

- (nullable TPCTheme *)themeAtURL:(NSURL *)url withFilename:(NSString *)name storageLocation:(TPCThemeStorageLocation)storageLocation inList:(TPCThemeControllerThemeListMutable)list createIfNecessary:(BOOL)createIfNecessary skipFileExists:(BOOL)skipFileExists
{
	return [self themeAtURL:url
			   withFilename:name
			storageLocation:storageLocation
					 inList:list
		  createIfNecessary:createIfNecessary
				 wasCreated:NULL
			 skipFileExists:skipFileExists];
}

- (nullable TPCTheme *)themeAtURL:(NSURL *)url withFilename:(NSString *)name storageLocation:(TPCThemeStorageLocation)storageLocation inList:(TPCThemeControllerThemeListMutable)list createIfNecessary:(BOOL)createIfNecessary wasCreated:(nullable BOOL *)wasCreated skipFileExists:(BOOL)skipFileExists
{
	NSParameterAssert(url != nil);
	NSParameterAssert(url.isFileURL);
	NSParameterAssert(name != nil);
	NSParameterAssert(name.length > 0);
	NSParameterAssert(list != nil);

	TPCTheme *theme = nil;

	@synchronized (list) {
		theme = list[name];
	}

	if (theme || (theme == nil && createIfNecessary == NO)) {
		return theme;
	}

	if (skipFileExists == NO && [RZFileManager() directoryExistsAtURL:url] == NO) {
		return nil;
	}

	theme = [[TPCTheme alloc] initWithURL:url inStorageLocation:storageLocation];

	[self addTheme:theme withFilename:name storageLocation:storageLocation];

	if ( wasCreated) {
		*wasCreated = YES;
	}

	return theme;
}

- (void)addTheme:(nullable TPCTheme *)theme withFilename:(NSString *)name storageLocation:(TPCThemeStorageLocation)storageLocation
{
	[self add:YES theme:theme withFilename:name storageLocation:storageLocation];
}

- (void)removeThemeWithFilename:(NSString *)name storageLocation:(TPCThemeStorageLocation)storageLocation
{
	[self add:NO theme:nil withFilename:name storageLocation:storageLocation];
}

- (void)add:(BOOL)addOrRemove theme:(nullable TPCTheme *)theme withFilename:(NSString *)name storageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert((addOrRemove && theme != nil) ||
					   addOrRemove == NO);
	NSParameterAssert(name != nil);
	NSParameterAssert(name.length > 0);
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	TPCThemeControllerThemeListMutable list = [self mutableListForStorageLocation:storageLocation];

	if (list == nil) {
		return;
	}

	@synchronized (list) {
		if (addOrRemove) {
			list[name] = theme;
		} else {
			[list removeObjectForKey:name];
		}
	}
}

+ (nullable NSString *)pathOfThemeWithName:(NSString *)themeName
{
	return [self pathOfThemeWithName:themeName storageLocation:NULL];
}

+ (nullable NSString *)pathOfThemeWithName:(NSString *)themeName storageLocation:(nullable TPCThemeStorageLocation *)storageLocationIn
{
	NSParameterAssert(themeName != nil);

	TPCThemeStorageLocation storageLocation = [self.class storageLocationOfThemeWithName:themeName];

	if ( storageLocationIn) {
		*storageLocationIn = storageLocation;
	}

	if (storageLocation == TPCThemeStorageLocationUnknown) {
		return nil;
	}

	NSString *fileName = [self extractThemeName:themeName];

	if (fileName == nil) {
		return nil;
	}

	return [self pathOfThemeWithFilename:fileName storageLocation:storageLocation];
}

+ (nullable NSString *)pathOfThemeWithFilename:(NSString *)name storageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(name != nil);
	NSParameterAssert(name.length > 0);
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	NSString *basePath = [self pathOfStorageLocation:storageLocation];

	if (basePath == nil) {
		return nil;
	}

	NSString *filePath = [basePath stringByAppendingPathComponent:name];

	return filePath.stringByStandardizingPath;
}

+ (nullable NSString *)pathOfStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	switch (storageLocation) {
		case TPCThemeStorageLocationBundle:
		{
			return [TPCPathInfo bundledThemes];
		}
		case TPCThemeStorageLocationCustom:
		{
			return [TPCPathInfo customThemes];
		}
		default:
		{
			break;
		}
	}

	return nil;
}

- (nullable TPCThemeControllerThemeListMutable)mutableListForStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	switch (storageLocation) {
		case TPCThemeStorageLocationBundle:
		{
			return self.bundledThemes;
		}
		case TPCThemeStorageLocationCustom:
		{
			return self.customThemes;
		}
		default:
		{
			break;
		}
	}

	return nil;
}

- (void)startMonitoringThemes
{
	NSMutableArray<NSURL *> *urls = [NSMutableArray arrayWithCapacity:2];

	NSMutableDictionary<NSURL *, NSNumber *> *context = [NSMutableDictionary dictionaryWithCapacity:2];

	void (^_addStorageLocation)(TPCThemeStorageLocation) = ^(TPCThemeStorageLocation storageLocation)
	{
		NSString *path = [self.class pathOfStorageLocation:storageLocation];

		if (path == nil) {
			return;
		}

		NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];

		[urls addObject:url];

		[context setObject:@(storageLocation) forKey:url];
	};

	_addStorageLocation(TPCThemeStorageLocationCustom);

	__weak TPCThemeController *weakSelf = self;

	  XRFileSystemMonitor *monitor =
	[[XRFileSystemMonitor alloc] initWithFileURLs:urls context:context callbackBlock:^(NSArray<XRFileSystemEvent *> *events) {
		[weakSelf reactToMonitoringEvents:events];
	}];

	[monitor startMonitoringWithLatency:1.0];

	self.themeMonitor = monitor;
}

- (void)stopMonitoringThemes
{
	XRFileSystemMonitor *monitor = self.themeMonitor;

	if (monitor == nil) {
		return;
	}

	[monitor stopMonitoring];

	self.themeMonitor = nil;
}

- (void)reactToMonitoringEvents:(NSArray<XRFileSystemEvent *> *)events
{
	NSParameterAssert(events != nil);

	for (XRFileSystemEvent *event in events) {
		[self reactToMonitoringEvent:event];
	}
}

- (void)reactToMonitoringEvent:(XRFileSystemEvent *)event
{
	NSParameterAssert(event != nil);

	/* The purpose of the theme monitor is to recognize when
	 new themes have appeared so that we can make them an
	 option for the user immediately. To accomplish this we
	 monitor the directory of each storage location. */
	/* Monitor is recursive which means we have to use flags
	 and context information to narrow scope of events. */
	FSEventStreamEventFlags flags = event.flags;

	if ((flags & kFSEventStreamEventFlagItemIsDir) != kFSEventStreamEventFlagItemIsDir) {
//		LogToConsoleDebug("Ignoring monitoring event for non-directory");

		return;
	}

	/* Each URL that is monitored is assigned the storage location
	 enum value as its context object. We can use this to understand
	 with certainty which storage location an event is related to. */
	NSURL *url = event.url;

	NSURL *parentURL = url.URLByDeletingLastPathComponent;

	/* If the parent URL of this event does not contain an object,
	 then the event is not related to a subfolder of the storage location. */
	NSNumber *parentContext = [self.themeMonitor contextObjectForURL:parentURL];

	if (parentContext == nil) {
//		LogToConsoleDebug("Ignoring monitoring event for unrelated directory");

		return;
	}

	TPCThemeStorageLocation storageLocation = parentContext.unsignedIntegerValue;

	[self reactToMonitoringEventAtURL:url storageLocation:storageLocation flags:flags];
}

- (void)reactToMonitoringEventAtURL:(NSURL *)url storageLocation:(TPCThemeStorageLocation)storageLocation flags:(FSEventStreamEventFlags)flags
{
	NSParameterAssert(url != nil);
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	/* TPCTheme objects will announce when they are deleted.
	 We are not interested in events related to those. */
	if ([RZFileManager() fileExistsAtURL:url] == NO) {
		return;
	}

	/* Create theme */
	NSString *themeName = [url resourceValueForKey:NSURLNameKey];

	TPCThemeControllerThemeListMutable themeList = [self mutableListForStorageLocation:storageLocation];

	BOOL themeCreated = NO;

	TPCTheme *theme =
	[self themeAtURL:url
		withFilename:themeName
	 storageLocation:storageLocation
			  inList:themeList
   createIfNecessary:YES
		  wasCreated:&themeCreated
	  skipFileExists:YES];

	/* Only post notification if the theme was created. */
	if (themeCreated == NO) {
		return;
	}

	LogToConsoleDebug("Theme '%{public}@' named '%{public}@' at '%{public}@' created", theme, themeName, url.standardizedTildePath);

	[RZNotificationCenter() postNotificationName:TPCThemeControllerThemeListDidChangeNotification object:self];
}

- (void)populateThemes
{
	[self populateThemesFromStorageLocation:TPCThemeStorageLocationBundle];
	[self populateThemesFromStorageLocation:TPCThemeStorageLocationCustom];
}

- (void)populateThemesFromStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	NSString *path = [self.class pathOfStorageLocation:storageLocation];

	if (path == nil) {
		return;
	}

	TPCThemeControllerThemeListMutable list = [self mutableListForStorageLocation:storageLocation];

	if (list == nil) {
		return;
	}

	NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];

	NSError *preFileListError;

	NSArray *preFileList =
	[RZFileManager() contentsOfDirectoryAtURL:url
				   includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
									  options:(NSDirectoryEnumerationSkipsHiddenFiles |
											   NSDirectoryEnumerationSkipsPackageDescendants)
										error:&preFileListError];

	if (preFileListError) {
		LogToConsoleError("Failed to list contents of theme folder: %{public}@",
			preFileListError.localizedDescription);
	}

	for (NSURL *fileURL in preFileList) {
		NSNumber *isDirectory = [fileURL resourceValueForKey:NSURLIsDirectoryKey];

		if ([isDirectory boolValue] == NO) {
			continue;
		}

		NSString *name = [fileURL resourceValueForKey:NSURLNameKey];

		(void)[self themeAtURL:fileURL
				  withFilename:name
			   storageLocation:storageLocation
						inList:list
			 createIfNecessary:YES
				skipFileExists:YES];
	}
}

- (TPCThemeControllerThemeList)themesInStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	TPCThemeControllerThemeListMutable list = [self mutableListForStorageLocation:storageLocation];

	if (list == nil) {
		return @{};
	}

	return [list copy];
}

- (void)enumerateAvailableThemesWithBlock:(void(NS_NOESCAPE ^)(NSString *fileName, TPCThemeStorageLocation storageLocation, BOOL multipleVariants, BOOL *stop))enumerationBlock
{
	NSParameterAssert(enumerationBlock != nil);

	/* Create a dictionary of the theme name (file name) as the key,
	 and an array of storage locations it appears within as the value. */
	NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *themesMappedByName = [NSMutableDictionary dictionary];

	void (^_mapByName)(TPCThemeStorageLocation) = ^(TPCThemeStorageLocation storageLocation)
	{
		TPCThemeControllerThemeList themes = [self themesInStorageLocation:storageLocation];

		[themes enumerateKeysAndObjectsUsingBlock:^(NSString *name, TPCTheme *theme, BOOL *stop) {
			if (theme.usable == NO) {
				return;
			}

			NSMutableArray<NSNumber *> *mappedLocations = themesMappedByName[name];

			if (mappedLocations == nil) {
				mappedLocations = [NSMutableArray array];

				themesMappedByName[name] = mappedLocations;
			}

			[mappedLocations addObject:@(storageLocation)];
		}];
	};

	_mapByName(TPCThemeStorageLocationBundle);
	_mapByName(TPCThemeStorageLocationCustom);

	/* Create sorted list of themes */
	NSArray *themeNamesSorted = themesMappedByName.sortedDictionaryKeys;

	/* Perform enumeration */
	BOOL stopEnumeration = NO;

	for (NSString *themeName in themeNamesSorted) {
		NSArray *themeLocations = themesMappedByName[themeName];

		BOOL multipleVariants = (themeLocations.count > 1);

		for (NSNumber *themeLocation in themeLocations) {
			enumerationBlock(themeName, themeLocation.unsignedIntegerValue, multipleVariants, &stopEnumeration);

			if (stopEnumeration) {
				break;
			}
		} // for themeLocation
	} // for themeName
}

- (void)applicationAppearanceChanged:(NSNotification *)notification
{
	[self.theme updateAppearance];
}

- (void)themeVarietyChanged:(NSNotification *)notification
{
	[self updatePreferences];
}

- (void)themeIntegrityCompromised:(NSNotification *)notification
{
	TPCTheme *theme = notification.object;

	if (self.theme != theme) {
		return;
	}

	if ([self resetPreferencesForActiveTheme] == NO) { // Validate theme
		return;
	}

	LogToConsoleInfo("Reloading theme because it failed validation");

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionStyle];

	[RZNotificationCenter() postNotificationName:TPCThemeControllerThemeListDidChangeNotification object:self];

	[self presentIntegrityCompromisedAlert];
}

- (void)themeWasDeleted:(NSNotification *)notification
{
	TPCTheme *theme = notification.object;

	[self removeThemeWithFilename:theme.name storageLocation:theme.storageLocation];

	if (self.theme != theme) {
		[RZNotificationCenter() postNotificationName:TPCThemeControllerThemeListDidChangeNotification object:self];

		return;
	}

	if ([self resetPreferencesForActiveTheme] == NO) { // Validate theme
		LogToConsoleFault("This should be an impossible condition");
		LogStackTrace();

		return;
	}

	LogToConsoleInfo("Reloading theme because it was deleted");

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionStyle];

	[RZNotificationCenter() postNotificationName:TPCThemeControllerThemeListDidChangeNotification object:self];
}

- (void)themeWasModified:(NSNotification *)notification
{
	TPCTheme *theme = notification.object;

	if (self.theme != theme) {
		return;
	}

	if ([TPCPreferences automaticallyReloadCustomThemesWhenTheyChange] == NO) {
		return;
	}

	LogToConsoleInfo("Reloading theme because it was modified");

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionStyle];
}

- (void)load
{
	/* resetPreferencesForPreferredTheme is called for the configured
	 theme before the first ever -reload is called to recover from a
	 style being deleted while the app was closed. */
	[self resetPreferencesForPreferredTheme];

	[self reload];
}

- (void)reload
{
	NSString *themeName = [TPCPreferences themeName];

	TPCTheme *theme = [self themeNamed:themeName createIfNecessary:YES];

	NSAssert1((theme != nil), @"Missing style resource files: %@", themeName);

	if (self.theme != theme) {
		self.theme = theme;
	} else {
		return;
	}

	self.cachedThemeName = themeName;

	self.cacheToken = [NSString stringWithUnsignedInteger:TXRandomNumber(1000000)];

	[self updatePreferences];

	[self createTemporaryCopyOfTheme];

	[self presentCompatibilityAlert];

	[self presentInvertSidebarColorsAlert];
}

- (void)updatePreferences
{
	/* Inform our defaults controller about a few overrides. */
	/* These setValue calls basically tell the NSUserDefaultsController for the "Preferences"
	 window that the active theme has overrode a few user configurable options. The window then
	 blanks out the options specified to prevent the user from modifying. */
	TPCThemeSettings *settings = self.settings;

	[TPCPreferences setThemeChannelViewFontPreferenceUserConfigurable:(settings.themeChannelViewFont == nil)];

	[TPCPreferences setThemeNicknameFormatPreferenceUserConfigurable:(settings.themeNicknameFormat.length == 0)];

	[TPCPreferences setThemeTimestampFormatPreferenceUserConfigurable:(settings.themeTimestampFormat.length == 0)];
}

- (void)recreateTemporaryCopyOfThemeIfNecessary
{
	NSURL *temporaryURL = self.temporaryURL;

	if ([RZFileManager() fileExistsAtURL:temporaryURL]) {
		return;
	}

	[self createTemporaryCopyOfTheme];
}

- (void)removeTemporaryCopyOfTheme
{
	NSURL *temporaryURL = self.temporaryURL;

	if ([RZFileManager() fileExistsAtURL:temporaryURL] == NO) {
		return;
	}

	NSError *removeItemError = nil;

	if ([RZFileManager() removeItemAtURL:temporaryURL error:&removeItemError] == NO) {
		LogToConsoleError("Failed to remove temporary directory: %{public}@",
				removeItemError.localizedDescription);
	}
}

- (void)createTemporaryCopyOfTheme
{
	NSURL *originalURL = self.originalURL;

	NSURL *temporaryURL = self.temporaryURL;

	[RZFileManager() replaceItemAtURL:temporaryURL
						withItemAtURL:originalURL
							  options:CSFileManagerOptionsRemoveIfExists];
}

- (void)presentCompatibilityAlert
{
	if (self.settings.usesIncompatibleTemplateEngineVersion == NO) {
		return;
	}

	NSUInteger themeNameHash = self.cachedThemeName.hash;

	NSString *suppressionKey = [NSString stringWithFormat:
					@"incompatible_theme_dialog_%lu", themeNameHash];

	[TDCAlert alertWithMessage:TXTLS(@"Prompts[76t-pn]")
						 title:TXTLS(@"Prompts[py0-cr]", self.name)
				 defaultButton:TXTLS(@"Prompts[2a3-5s]")
			   alternateButton:TXTLS(@"Prompts[c7s-dq]")
				suppressionKey:suppressionKey
			   suppressionText:nil
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
				   if (buttonClicked != TDCAlertResponseDefault) {
					   return;
				   }

				   [menuController() showStylePreferences:nil];
			   }];
}

- (void)presentInvertSidebarColorsAlert
{
	if (self.settings.invertSidebarColors == NO) {
		return;
	}

	if ([TXSharedApplication sharedAppearance].properties.isDarkAppearance) {
		return;
	}

	NSUInteger themeNameHash = self.cachedThemeName.hash;

	NSString *suppressionKey = [NSString stringWithFormat:
								@"theme_appearance_dialog_%lu", themeNameHash];

	[TDCAlert alertWithMessage:TXTLS(@"Prompts[193-6o]")
						 title:TXTLS(@"Prompts[ezn-rm]", self.name)
				 defaultButton:TXTLS(@"Prompts[hf0-w3]")
			   alternateButton:TXTLS(@"Prompts[hv0-79]")
				suppressionKey:suppressionKey
			   suppressionText:nil
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
				   if (buttonClicked == TDCAlertResponseDefault) {
					   return;
				   }

				   [TPCPreferences setAppearance:TXPreferredAppearanceDark];

				   [TPCPreferences performReloadAction:TPCPreferencesReloadActionAppearance];
			   }];
}

- (void)presentIntegrityCompromisedAlert
{
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[3wd-gj]")
						 title:TXTLS(@"Prompts[fjw-hj]", self.name)
				 defaultButton:TXTLS(@"Prompts[c4z-2b]")
			   alternateButton:TXTLS(@"Prompts[c7s-dq]")
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
				   if (buttonClicked != TDCAlertResponseDefault) {
					   return;
				   }

				   [menuController() showStylePreferences:nil];
			   }];
}

- (void)resetPreferencesForPreferredTheme
{
	NSString *themeName = [TPCPreferences themeName];

	[self resetPreferencesForThemeNamed:themeName];
}

- (BOOL)resetPreferencesForActiveTheme
{
	NSString *themeName = self.cachedThemeName;

	return [self resetPreferencesForThemeNamed:themeName];
}

- (BOOL)resetPreferencesForThemeNamed:(NSString *)themeName
{
	NSParameterAssert(themeName != nil);

	NSString *suggestedFontName = nil;
	NSString *suggestedThemeName = nil;

	BOOL validationResult = [self performValidationForTheme:themeName
											  suggestedFont:&suggestedFontName
											 suggestedTheme:&suggestedThemeName];

	if (validationResult) {
		return NO;
	}

	if (suggestedFontName) {
		[TPCPreferences setThemeChannelViewFontName:suggestedFontName];
	}

	if (suggestedThemeName) {
		[TPCPreferences setThemeName:suggestedThemeName];
	}

	return YES;
}

- (BOOL)performValidationForTheme:(NSString *)validatedTheme suggestedFont:(NSString **)suggestedFontName suggestedTheme:(NSString **)suggestedThemeName
{
	NSParameterAssert(validatedTheme != nil);
	NSParameterAssert(suggestedFontName != NULL);
	NSParameterAssert(suggestedThemeName != NULL);

	/* Validate font */
	BOOL keyChanged = NO;

	NSString *fontName = [TPCPreferences themeChannelViewFontName];

	if ([NSFont fontIsAvailable:fontName] == NO) {
		if ( suggestedFontName) {
			*suggestedFontName = [TPCPreferences themeChannelViewFontNameDefault];
		}

		keyChanged = YES;
	}

	/* Validate theme */
	NSString *themeName = [self.class extractThemeName:validatedTheme];

	NSString *themeSource = [self.class extractThemeSource:validatedTheme];

	LogToConsoleInfo("Performing validation on theme named '%{public}@' with source type of '%{public}@'", themeName, themeSource);

	/* Note from October 2020 during refactoring:
	 I know this is ugly as hell. Please don't shame me for it.
	 I just don't have the time to improve it.
	 If it works, it works. */

	if (themeSource == nil || [themeSource isEqualToString:TPCThemeControllerBundledThemeNameBasicPrefix])
	{
		/* Remap name of bundled themes. */
		NSString *bundledTheme = [self remappedThemeName:validatedTheme];

		if (bundledTheme) {
			if ( suggestedThemeName) {
				*suggestedThemeName = bundledTheme;

				keyChanged = YES;
			}
		}

		/* If the theme is faulted and is a bundled theme, then we can do
		 nothing except try to recover by using the default one. */
		if (bundledTheme == nil) {
			bundledTheme = validatedTheme;
		}

		if ([self themeExists:bundledTheme] == NO) {
			if ( suggestedThemeName) {
				*suggestedThemeName = [TPCPreferences themeNameDefault];

				keyChanged = YES;
			}
		} // preferred theme exists
	} // theme source bundled

	else if ([themeSource isEqualToString:TPCThemeControllerCustomThemeNameBasicPrefix])
	{
		if ([self themeExists:validatedTheme] == NO) {
			NSString *bundledTheme = [self.class buildFilename:themeName forStorageLocation:TPCThemeStorageLocationBundle];

			if ([self themeExists:bundledTheme]) {
				/* Use a bundled theme with the same name if available. */
				if ( suggestedThemeName) {
					*suggestedThemeName = bundledTheme;

					keyChanged = YES;
				}
			} else {
				/* Revert back to the default theme if no recovery is possible. */
				if ( suggestedThemeName) {
					*suggestedThemeName = [TPCPreferences themeNameDefault];

					keyChanged = YES;
				}
			} // bundled theme exists
		} // preferred theme exists
	} // theme source custom

	return (keyChanged == NO);
}

- (nullable NSString *)remappedThemeName:(NSString *)themeName
{
	NSParameterAssert(themeName != nil);

	NSDictionary *cachedValues =
	[TPCResourceManager dictionaryFromResources:@"StaticStore" key:@"TPCThemeController Remapped Themes"];

	return cachedValues[themeName];
}

- (BOOL)isBundledTheme
{
	return (self.storageLocation == TPCThemeStorageLocationBundle);
}

+ (nullable NSString *)buildFilename:(NSString *)name forStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(name != nil);
	NSParameterAssert(name.length > 0);
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	switch (storageLocation) {
		case TPCThemeStorageLocationBundle:
		{
			return [TPCThemeControllerBundledThemeNameCompletePrefix stringByAppendingString:name];
		}
		case TPCThemeStorageLocationCustom:
		{
			return [TPCThemeControllerCustomThemeNameCompletePrefix stringByAppendingString:name];
		}
		default:
		{
			break;
		}
	}

	return nil;
}

+ (nullable NSString *)descriptionForStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	switch (storageLocation) {
		case TPCThemeStorageLocationBundle:
		{
			return TXTLS(@"BasicLanguage[7lm-bq]");
		}
		case TPCThemeStorageLocationCustom:
		{
			return TXTLS(@"BasicLanguage[bm2-4p]");
		}
		default:
		{
			break;
		}
	}

	return nil;
}

+ (nullable NSString *)extractThemeSource:(NSString *)source
{
	NSParameterAssert(source != nil);

	if ([source hasPrefix:TPCThemeControllerCustomThemeNameCompletePrefix] == NO &&
		[source hasPrefix:TPCThemeControllerBundledThemeNameCompletePrefix] == NO)
	{
		return nil;
	}

	NSInteger colonIndex = [source stringPosition:@":"];

	return [source substringToIndex:colonIndex];
}

+ (nullable NSString *)extractThemeName:(NSString *)source
{
	NSParameterAssert(source != nil);

	if ([source hasPrefix:TPCThemeControllerCustomThemeNameCompletePrefix] == NO &&
		[source hasPrefix:TPCThemeControllerBundledThemeNameCompletePrefix] == NO)
	{
		return nil;
	}

	NSInteger colonIndex = [source stringPosition:@":"];

	NSString *name = [source substringAfterIndex:colonIndex];

	if (name.length == 0) {
		return nil;
	}

	return name;
}

+ (TPCThemeStorageLocation)storageLocationOfThemeWithName:(NSString *)themeName
{
	NSParameterAssert(themeName != nil);

	if ([themeName hasPrefix:TPCThemeControllerCustomThemeNameCompletePrefix]) {
		return TPCThemeStorageLocationCustom;
	} else if ([themeName hasPrefix:TPCThemeControllerBundledThemeNameCompletePrefix]) {
		return TPCThemeStorageLocationBundle;
	}

	return TPCThemeStorageLocationUnknown;
}

- (void)copyActiveThemeToDestinationLocation:(TPCThemeStorageLocation)destinationLocation reloadOnCopy:(BOOL)reloadOnCopy openOnCopy:(BOOL)openOnCopy
{
	NSAssert((self.currentCopyOperation == nil),
		@"Tried to create a new copy operation with operation already in progress");

	if (self.storageLocation == destinationLocation) {
		LogToConsoleError("Tried to copy active theme to same storage location that it already exists within");

		return;
	}

	if (TPCThemeStorageLocationBundle == destinationLocation) {
		LogToConsoleError("Tried to copy active theme to the application itself");

		return;
	}

	TPCThemeControllerCopyOperation *copyOperation = [TPCThemeControllerCopyOperation new];

	copyOperation.themeController = self;

	copyOperation.themeName = self.name;

	copyOperation.pathBeingCopiedFrom = self.originalPath;

	copyOperation.destinationLocation = destinationLocation;

	copyOperation.openThemeWhenCopied = openOnCopy;
	copyOperation.reloadThemeWhenCopied = reloadOnCopy;

	[copyOperation beginOperation];

	self.currentCopyOperation = copyOperation;
}

- (void)copyActiveThemeOperationCompleted
{
	self.currentCopyOperation = nil;
}

@end

#pragma mark -
#pragma mark Theme Controller Copy Operation

@implementation TPCThemeControllerCopyOperation

- (void)beginOperation
{
	/* Setup progress indicator. */
	  TDCProgressIndicatorSheet *progressIndicator =
	[[TDCProgressIndicatorSheet alloc] initWithWindow:[NSApp keyWindow]];

	self.progressIndicator = progressIndicator;

	[self.progressIndicator start];

	/* All work is done in a background thread. */
	/* Once started, the operation cannot be cancelled. It will occur
	 then it will either call -cancelOperation itself on failure or wait
	 for the theme controller itself to call -completeOperation which 
	 signals to the copier that the theme controller sees the files. */
	XRPerformBlockAsynchronouslyOnGlobalQueue(^{
		[self _beginOperation];
	});
}

- (void)_beginOperation
{
	[self _defineDestinationPath];

	NSURL *sourceURL = [NSURL fileURLWithPath:self.pathBeingCopiedFrom isDirectory:YES];

	NSURL *destinationURL = [NSURL fileURLWithPath:self.pathBeingCopiedTo isDirectory:YES];

	if ([RZFileManager() replaceItemAtURL:destinationURL
							withItemAtURL:sourceURL
								  options:(CSFileManagerOptionsMoveToTrash |
										   CSFileManagerOptionsRemoveIfExists)] == NO)
	{
		[self cancelOperation];

		return;
	}

	[self completeOperation];
}

- (void)_defineDestinationPath
{
	NSString *destinationPath = nil;

	destinationPath = [TPCPathInfo customThemes];
	destinationPath = [destinationPath stringByAppendingPathComponent:self.themeName];

	/* Cast as nonnull to make static analyzer happy */
	self.pathBeingCopiedTo = (NSString * _Nonnull)destinationPath;
}

- (void)cancelOperation
{
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self _cancelOperation];
	});
}

- (void)completeOperation
{
	/* The copy process is usually instantaneous so add a slight 
	 delay because I like to mess with people */
	[NSThread sleepForTimeInterval:3.0];

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self _completeOperation];
	});
}

- (void)_cancelOperation
{
	[self invalidateOperation];
}

- (void)_completeOperation
{
	/* Maybe open new path of theme */
	if (self.openThemeWhenCopied) {
		NSURL *fileURL = [NSURL fileURLWithPath:self.pathBeingCopiedTo];

		[RZWorkspace() openURL:fileURL];
	}

	/* Maybe reload new theme */
	if (self.reloadThemeWhenCopied) {
		NSString *newThemeName = [TPCThemeController buildFilename:self.themeName forStorageLocation:self.destinationLocation];

		[TPCPreferences setThemeName:newThemeName];

		[TPCPreferences performReloadAction:TPCPreferencesReloadActionStyle];
	}

	/* Close progress indicator */
	[self invalidateOperation];
}

- (void)invalidateOperation
{
	[self.progressIndicator stop];
	 self.progressIndicator = nil;

	[self.themeController copyActiveThemeOperationCompleted];
}

@end

NS_ASSUME_NONNULL_END
