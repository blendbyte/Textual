/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "NSObjectHelperPrivate.h"
#import "TXAppearance.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeInternal.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TPCThemeIntegrityCompromisedNotification	= @"TPCThemeIntegrityCompromisedNotification";
NSString * const TPCThemeIntegrityRestoredNotification		= @"TPCThemeIntegrityRestoredNotification";
NSString * const TPCThemeAppearanceChangedNotification		= @"TPCThemeAppearanceChangedNotification";
NSString * const TPCThemeVarietyChangedNotification			= @"TPCThemeVarietyChangedNotification";
NSString * const TPCThemeWasModifiedNotification			= @"TPCThemeWasModifiedNotification";
NSString * const TPCThemeWasDeletedNotification				= @"TPCThemeWasDeletedNotification";

typedef NS_ENUM(NSUInteger, _TPCThemeChooseVarietyResult) {
	_TPCThemeChooseVarietyResultNoChange,
	_TPCThemeChooseVarietyResultNoBestChoice,
	_TPCThemeChooseVarietyResultChanged
};

typedef NS_OPTIONS(NSUInteger, _TPCThemeMonitoringResult) {
	_TPCThemeMonitoringResultNoChange					= 0, // Default
	_TPCThemeMonitoringResultReloadableFileModified		= 1 << 0, // Any CSS or JavaScript file was changed in the current variety
	_TPCThemeMonitoringResultCriticalFileDeleted		= 1 << 1, // The design.css or scripts.js file of any variety was deleted
	_TPCThemeMonitoringResultVarietyCreated				= 1 << 2, // A variety was created
	_TPCThemeMonitoringResultVarietyDeleted				= 1 << 3, // A variety was deleted
	_TPCThemeMonitoringResultThemeDeleted				= 1 << 4  // The theme was deleted
};

@class TPCThemeVariety;

@implementation TPCTheme

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithURL:(NSURL *)url inStorageLocation:(TPCThemeStorageLocation)storageLocation
{
	NSParameterAssert(url != nil);
	NSParameterAssert(url.isFileURL);
	NSParameterAssert(storageLocation != TPCThemeStorageLocationUnknown);

	if ((self = [super init])) {
		NSURL *originalURL = url.URLByStandardizingPath;

		self.name = originalURL.lastPathComponent;

		self.originalURL = originalURL;

		self.storageLocation = storageLocation;

		[self _loadTheme];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self _stopMonitoring];
}

- (void)_loadTheme
{
	[self _assignTemporaryURL];

	[self _loadGlobalVariety];

	[self _loadVarieties];

	if (self.varieties == nil) {
		self.varieties = @[];
	}

	/* During init there should be not variety already set. */
	self.usable =
	([self _chooseBestVariety] == _TPCThemeChooseVarietyResultChanged);

	[self _startMonitoring];
}

- (void)_loadGlobalVariety
{
	NSURL *url = self.originalURL;

	TPCThemeVariety *variety = [[TPCThemeVariety alloc] initWithURL:url];

	variety.isGlobalVariety = YES;

	self.globalVariety = variety;
}

- (void)_loadVarieties
{
	NSURL *varietiesURL = [self _varietiesURL];

	if ([RZFileManager() fileExistsAtURL:varietiesURL] == NO) {
		return;
	}

	NSError *preFileListError;

	NSArray *preFileList =
	[RZFileManager() contentsOfDirectoryAtURL:varietiesURL
				   includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
									  options:NSDirectoryEnumerationSkipsHiddenFiles
										error:&preFileListError];

	if (preFileListError) {
		LogToConsoleError("Failed to list contents of Varieties folder: %{public}@",
			preFileListError.localizedDescription);
	}

	NSMutableArray<TPCThemeVariety *> *varieties = [NSMutableArray array];

	for (NSURL *fileURL in preFileList) {
		NSNumber *isDirectory = [fileURL resourceValueForKey:NSURLIsDirectoryKey];

		if ([isDirectory boolValue] == NO) {
			continue;
		}

		TPCThemeVariety *variety = [[TPCThemeVariety alloc] initWithURL:fileURL];

		[varieties addObject:variety];
	}

	self.varieties = varieties;
}

- (NSURL *)_varietiesURL
{
	NSURL *url = self.originalURL;

	return [url URLByAppendingPathComponent:@"Varieties/"];
}

- (void)_populateSettings
{
	self.settings = [[TPCThemeSettings alloc] initWithTheme:self];
}

- (void)_assignDefaultTemplateRepository
{
	NSURL *repositoryURL = [self _applicationTemplateRepositoryURL];

	GRMustacheTemplateRepository *repository = [GRMustacheTemplateRepository templateRepositoryWithBaseURL:repositoryURL];

	NSAssert((repository != nil),
		@"Default template repository not found");

	self.defaultTemplateRepository = repository;
}

- (void)_assignTemporaryURL
{
//	NSURL *sourceURL = [TPCPathInfo applicationTemporaryProcessSpecificURL];
	NSURL *sourceURL = [TPCPathInfo applicationCachesURL];

	NSURL *baseURL = [sourceURL URLByAppendingPathComponent:@"/Cached-Style-Resources/"];

	self.temporaryURL = baseURL.URLByStandardizingPath;
}

#pragma mark -
#pragma mark Monitoring

- (BOOL)_isDirectoryURLSelf:(NSURL *)url
{
	NSURL *selfURL = self.originalURL;

	return [self _isDirectoryURL:url equalTo:selfURL];
}

- (BOOL)_isDirectoryURL:(NSURL *)url1 equalTo:(NSURL *)url2
{
	NSParameterAssert(url1 != nil);
	NSParameterAssert(url2 != nil);

	/* The file representation is compared instead of the
	 resource identifier because the resource identifier
	 returns nil when the URL no longer exists. */
	return [url1 isEqualByFileRepresentation:url2];
}

- (nullable TPCThemeVariety *)_varietyAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	TPCThemeVariety *globalVariety = self.globalVariety;

	NSURL *globalVarietyURL = globalVariety.url;

	if ([self _isDirectoryURL:url equalTo:globalVarietyURL]) {
		return globalVariety;
	}

	NSArray *varieties = self.varieties;

	TPCThemeVariety *variety =
	[varieties objectPassingTest:^BOOL(TPCThemeVariety *variety, NSUInteger index, BOOL *stop) {
		NSURL *varietyURL = variety.url;

		return [self _isDirectoryURL:url equalTo:varietyURL];
	}];

	return variety;
}

- (void)_stopMonitoring
{
	XRFileSystemMonitor *monitor = self.fileSystemMonitor;

	if (monitor == nil) {
		return;
	}

	[monitor stopMonitoring];

	self.fileSystemMonitor = nil;
}

- (void)_startMonitoring
{
	NSURL *url = self.originalURL;

	__weak TPCTheme *weakSelf = self;

	  XRFileSystemMonitor *monitor =
	[[XRFileSystemMonitor alloc] initWithFileURL:url callbackBlock:^(NSArray<XRFileSystemEvent *> *events) {
		[weakSelf _reactToMonitoringEvents:events];
	}];

	[monitor startMonitoringWithLatency:5.0];

	self.fileSystemMonitor = monitor;
}

- (void)_concludeMonitoringEventWithResult:(_TPCThemeMonitoringResult)result
{
	/* Theme was deleted */
	if ((result & _TPCThemeMonitoringResultThemeDeleted) == _TPCThemeMonitoringResultThemeDeleted) {
		[self _reactToDeletion];

		return;
	}

	/* Theme was modified in such a way that it must be validated
	 and possibly a new best choice is chosen. */
	if ((result & _TPCThemeMonitoringResultCriticalFileDeleted) == _TPCThemeMonitoringResultCriticalFileDeleted ||
		(result & _TPCThemeMonitoringResultVarietyCreated) == _TPCThemeMonitoringResultVarietyCreated ||
		(result & _TPCThemeMonitoringResultVarietyDeleted) == _TPCThemeMonitoringResultVarietyDeleted)
	{
		[self _verifyIntegrity];
	}

	/* CSS or JavaScript file in the current variety was modified. */
	else if ((result & _TPCThemeMonitoringResultReloadableFileModified) == _TPCThemeMonitoringResultReloadableFileModified)
	{
		[self _notifyRecentlyModified];
	}
}

- (void)_reactToMonitoringEvents:(NSArray<XRFileSystemEvent *> *)events
{
	NSParameterAssert(events != nil);

	_TPCThemeMonitoringResult result = _TPCThemeMonitoringResultNoChange;

	for (XRFileSystemEvent *event in events) {
		result |= [self _reactToMonitoringEventAtURL:event.url withFlags:event.flags];
	}

	[self _concludeMonitoringEventWithResult:result];
}

- (_TPCThemeMonitoringResult)_reactToMonitoringEventAtURL:(NSURL *)url withFlags:(FSEventStreamEventFlags)flags
{
	NSParameterAssert(url != nil);

	/* Returns YES if something changed that requires an integrity check. NO otherwise. */
	if (flags & kFSEventStreamEventFlagItemIsFile) {
		return [self _reactToMonitoringEventForFileAtURL:url withFlags:flags];
	} else if (flags & kFSEventStreamEventFlagItemIsDir) {
		return [self _reactToMonitoringEventForDirectoryAtURL:url withFlags:flags];
	}

	return _TPCThemeMonitoringResultNoChange; // No change
}

- (_TPCThemeMonitoringResult)_reactToMonitoringEventForFileAtURL:(NSURL *)url withFlags:(FSEventStreamEventFlags)flags
{
	NSParameterAssert(url != nil);

	NSURL *directoryURL = url.URLByDeletingLastPathComponent;

	TPCThemeVariety *variety = [self _varietyAtURL:directoryURL];

	/* The monitor is used for two parts:
	 1. To continuously verify the integrity of the theme
	  and varieties so that the next time that it's reloaded,
	  it will be in a usable state.
	 2. To automatically reload the theme when CSS and JavaScript
	  files changed if that's what the user has configured.
	  If #1 is triggered, then we do not do #2. */
	if (variety == nil) {
		return _TPCThemeMonitoringResultNoChange;
	}

	_TPCThemeMonitoringResult result = _TPCThemeMonitoringResultNoChange;

	BOOL varietyChanged = [self _verifyIntegrityOfFileAtURL:url duringMonitoringOfVariety:variety];

	if (varietyChanged) {
		result |= _TPCThemeMonitoringResultCriticalFileDeleted;
	}

	/* Limit #2 to scope of active variety. */
	if (variety != self.variety &&
		variety != self.globalVariety)
	{
		return result;
	}

	/* Do #2 */
	NSString *fileExtension = url.pathExtension;

	if ([fileExtension isEqual:@"css"] ||
		[fileExtension isEqual:@"js"])
	{
		result |= _TPCThemeMonitoringResultReloadableFileModified;
	}

	return result; // No change
}

- (_TPCThemeMonitoringResult)_reactToMonitoringEventForDirectoryAtURL:(NSURL *)url withFlags:(FSEventStreamEventFlags)flags
{
	NSParameterAssert(url != nil);

	/* React to changes to the theme itself. */
	if ([self _isDirectoryURLSelf:url]) {
		if ([RZFileManager() directoryExistsAtURL:url] == NO) {
			return _TPCThemeMonitoringResultThemeDeleted;
		}

		return _TPCThemeMonitoringResultNoChange;
	}

	/* React to changes to a specific variety folder.
	 We determine which URLs to target by comparing the
	 parent of this URL to the Varieties directory URL. */
	NSURL *parentURL = url.URLByDeletingLastPathComponent;

	NSURL *varietiesURL = [self _varietiesURL];

	if ([self _isDirectoryURL:parentURL equalTo:varietiesURL]) {
		return [self _reactToMonitoringVarietyDirectoryEventAtURL:url withFlags:flags];
	}

	return _TPCThemeMonitoringResultNoChange;
}

- (_TPCThemeMonitoringResult)_reactToMonitoringVarietyDirectoryEventAtURL:(NSURL *)url withFlags:(FSEventStreamEventFlags)flags
{
	NSParameterAssert(url != nil);

	BOOL varietyDeleted = ([RZFileManager() directoryExistsAtURL:url] == NO);

	TPCThemeVariety *variety = [self _varietyAtURL:url];

	NSMutableArray *varieties = self.varieties.mutableCopy;

	if (variety) {
		[varieties removeObject:variety];
	} else {
		if (varietyDeleted) {
			return _TPCThemeMonitoringResultNoChange; // No change
		}
	}

	if (varietyDeleted == NO) {
		TPCThemeVariety *newVariety = [[TPCThemeVariety alloc] initWithURL:url];

		[varieties addObject:newVariety];
	}

	self.varieties = varieties;

	return ((varietyDeleted) ?
			_TPCThemeMonitoringResultVarietyDeleted :
			_TPCThemeMonitoringResultVarietyCreated);
}

- (void)_reactToDeletion
{
	[self _stopMonitoring];

	[self _changeVariety:nil];

	self.usable = NO;

	[self _notifyDeleted];
}

- (void)_notifyRecentlyModified
{
	[RZNotificationCenter() postNotificationName:TPCThemeWasModifiedNotification object:self];
}

- (void)_notifyDeleted
{
	[RZNotificationCenter() postNotificationName:TPCThemeWasDeletedNotification object:self];
}

#pragma mark -
#pragma mark Integrity

- (BOOL)_verifyIntegrityOfFileAtURL:(NSURL *)url duringMonitoringOfVariety:(TPCThemeVariety *)variety
{
	NSParameterAssert(url != nil);
	NSParameterAssert(variety != nil);

	/* Returns YES if a change is made to property. NO otherwise. */

	/* The variety will first determine which type of file was
	 changed. CSS or JavaScript.
	 • If the property for this file is set and the file no longer
	   exists, then the property is set to nil.
	 • If the property for this file is nil and the file exists,
	   then the property is set to the URL of the file.
	 After action is performed by the variety, we can decide
	 wether to do anything depending on whether a change
	 actually took place. */
	BOOL fileChanged =
	[variety _reevaluateFileDuringMonitoringAtURL:url];

	if (fileChanged == NO) {
		return NO; // No change
	}

	return YES; // Change made
}

- (BOOL)_verifyIntegrity
{
	/* The variety changed in some way as described above.
	 The theme will now try to choose the best variety again.
	 If there is not a suitable variety to change to, then at
	 this point integrity of the theme is considered compromised.
	 It is possible to recover from the compromised state by
	 changing this variety or the global variety in such a way
	 that either can be used. */
	_TPCThemeChooseVarietyResult varietyChanged = [self _chooseBestVariety];

	if (self.usable) {
		if (varietyChanged == _TPCThemeChooseVarietyResultNoChange) {
			return NO; // No change
		}

		if (varietyChanged == _TPCThemeChooseVarietyResultNoBestChoice) {
			self.usable = NO;

			[self _chooseNoVariety]; // Reset selection

			[RZNotificationCenter() postNotificationName:TPCThemeIntegrityCompromisedNotification object:self];
		}
	}
	else // usable
	{
		if (varietyChanged == _TPCThemeChooseVarietyResultNoBestChoice) {
			return NO; // No change
		}

		self.usable = YES;

		[RZNotificationCenter() postNotificationName:TPCThemeIntegrityRestoredNotification object:self];
	} // usable

	return YES; // Change made
}

#pragma mark -
#pragma mark Changing Variety

- (void)_combineFiles
{
	TPCThemeVariety *variety = self.variety;

	if (variety == nil) {
		self.cssFiles = @[];
		self.jsFiles = @[];

		self.temporaryCSSFiles = @[];
		self.temporaryJSFiles = @[];

		self.templateRepositories = @[];

		return;
	}

	TPCThemeVariety *globalVariety = self.globalVariety;

	NSMutableArray<NSURL *> *cssFiles = [NSMutableArray array];
	NSMutableArray<NSURL *> *jsFiles = [NSMutableArray array];
	NSMutableArray<NSURL *> *temporaryCSSFiles = [NSMutableArray array];
	NSMutableArray<NSURL *> *temporaryJSFiles = [NSMutableArray array];

	NSMutableArray<GRMustacheTemplateRepository *> *templates = [NSMutableArray array];

	NSString *originalRemapPath = self.originalURL.path;

	if ([originalRemapPath hasSuffix:@"/"]) {
		 originalRemapPath = [originalRemapPath substringAtIndex:0 toLength:(-1)];
	}

	NSString *temporaryRemapPath = self.temporaryURL.path;

	if ([temporaryRemapPath hasSuffix:@"/"]) {
		 temporaryRemapPath = [temporaryRemapPath substringAtIndex:0 toLength:(-1)];
	}

	NSURL *(^_remapTemporaryFile)(NSURL *) = ^NSURL *(NSURL *url)
	{
		NSString *path = url.path;

		if ([path hasPrefix:originalRemapPath] == NO) {
			return url;
		}

		path = [path substringFromIndex:originalRemapPath.length];

		path = [temporaryRemapPath stringByAppendingString:path];

		return [NSURL fileURLWithPath:path].URLByStandardizingPath;
	};

	void (^_addCSSFile)(TPCThemeVariety *) = ^(TPCThemeVariety *variety) {
		NSURL *cssFile = variety.cssFile;

		if (cssFile == nil) {
			return;
		}

		[cssFiles addObject:cssFile];

		[temporaryCSSFiles addObject:_remapTemporaryFile(cssFile)];
	};

	void (^_addJSFile)(TPCThemeVariety *) = ^(TPCThemeVariety *variety) {
		NSURL *jsFile = variety.jsFile;

		if (jsFile == nil) {
			return;
		}

		[jsFiles addObject:jsFile];

		[temporaryJSFiles addObject:_remapTemporaryFile(jsFile)];
	};

	void (^_addTemplates)(TPCThemeVariety *) = ^(TPCThemeVariety *variety) {
		GRMustacheTemplateRepository *repository = variety.templateRepository;

		if (repository == nil) {
			return;
		}

		[templates addObject:repository];
	};

	_addCSSFile(globalVariety);
	_addJSFile(globalVariety);

	if (variety.isGlobalVariety == NO) {
		_addCSSFile(variety);
		_addJSFile(variety);

		_addTemplates(variety);
	}

	_addTemplates(globalVariety);

	self.cssFiles = cssFiles;
	self.jsFiles = jsFiles;

	self.temporaryCSSFiles = temporaryCSSFiles;
	self.temporaryJSFiles = temporaryJSFiles;

	self.templateRepositories = templates;
}

- (_TPCThemeChooseVarietyResult)_chooseBestVariety
{
	TPCThemeVariety *bestVariety = [self _bestVariety];

	if (bestVariety == nil) {
		return _TPCThemeChooseVarietyResultNoBestChoice;
	}

	TPCThemeVariety *currentVariety = self.variety;

	if (currentVariety == bestVariety) {
		return _TPCThemeChooseVarietyResultNoChange;
	}

	[self _changeVariety:bestVariety];

	return _TPCThemeChooseVarietyResultChanged;
}

- (void)_changeVariety:(nullable TPCThemeVariety *)variety
{
	TPCThemeVariety *previousVariety = self.variety;

	self.templateCache = nil;

	self.variety = variety;

	[self _combineFiles];

	[self _populateSettings];

	/* Assign the default repository after populating settings
	 as we need the template engine version for construction. */
	[self _assignDefaultTemplateRepository];

	/* Do not fire notification if there is not a previous
	 variety (during init) or we are in a compromised state. */
	if (previousVariety != nil && variety != nil && self.usable) {
		if (previousVariety.appearance == variety.appearance) {
			[RZNotificationCenter() postNotificationName:TPCThemeVarietyChangedNotification object:self];
		} else {
			[RZNotificationCenter() postNotificationName:TPCThemeAppearanceChangedNotification object:self];
		}
	}
}

- (void)_chooseNoVariety
{
	[self _changeVariety:nil];
}

- (nullable TPCThemeVariety *)_bestVariety
{
	TXAppearance *appAppearance = [TXSharedApplication sharedAppearance];

	BOOL isDarkAppearance = appAppearance.properties.isDarkAppearance;

	TPCThemeVariety *globalVariety = self.globalVariety;

	BOOL globalHasCSS = (globalVariety.cssFile != nil);
	BOOL globalHasJS = (globalVariety.jsFile != nil);

	TPCThemeVariety *bestVariety = nil;

	NSArray *varieties = self.varieties;

	/* A variety does not need to contain a CSS or JavaScript file
	 to be the best. As long those exist within the global variety,
	 then any variety that meets the appearance criteria can be
	 the best. This allows for flexibility such as specific variety
	 containing different templates and/or settings while using a
	 unified CSS and/or JavaScript file. */
	for (TPCThemeVariety *variety in varieties) {
		BOOL isBestVariety = NO;

		/* Perform first pass based on appearance criteria. */
		if ((variety.appearance == TPCThemeAppearanceTypeLight && isDarkAppearance == NO) ||
			(variety.appearance == TPCThemeAppearanceTypeDark && isDarkAppearance))
		{
			isBestVariety = YES;
		}

		/* We always set a best appearance even when appearance doesn't match
		 so that we can at least have one to work off of. Of course if we find
		 a better variety while enumerating, such as one that does match the
		 appearance, then the default is discarded. */
		else if (bestVariety == nil)
		{
			isBestVariety = YES;
		}

		if (isBestVariety) {
			/* Ensure someone has a CSS and JavaScript file. */
			if ((globalHasCSS == NO && variety.cssFile == nil) ||
				(globalHasJS == NO && variety.jsFile == nil))
			{
				isBestVariety = NO;
			}
		}

		/* Set as best variety if all conditions are met. */
		if (isBestVariety) {
			bestVariety = variety;
		}
	}

	/* If we do not have a best variety, then use the global
	 variety assuming it can be used. */
	if (bestVariety == nil && globalHasCSS && globalHasCSS) {
		bestVariety = globalVariety;
	}

	return bestVariety;
}

- (void)updateAppearance
{
	[self _chooseBestVariety];
}

#pragma mark -
#pragma mark Getters

- (TPCThemeAppearanceType)appearance
{
	return self.variety.appearance;
}

- (NSArray<NSString *> *)cssFilePaths
{
	return [self _pathsArrayForURLs:self.cssFiles];
}

- (NSArray<NSString *> *)jsFilePaths
{
	return [self _pathsArrayForURLs:self.jsFiles];
}

- (NSArray<NSString *> *)temporaryCSSFilePaths
{
	return [self _pathsArrayForURLs:self.temporaryCSSFiles];
}

- (NSArray<NSString *> *)temporaryJSFilePaths
{
	return [self _pathsArrayForURLs:self.temporaryJSFiles];
}

- (NSArray<NSString *> *)_pathsArrayForURLs:(NSArray<NSURL *> *)urls
{
	NSParameterAssert(urls != nil);

	return [NSArray pathsArrayForFileURLs:urls];
}

#pragma mark -
#pragma mark Templates

+ (NSDictionary<NSString *, NSString *> *)_templateLineTypes
{	
	return [TPCResourceManager dictionaryFromResources:@"TemplateLineTypes"];
}

- (NSURL *)_applicationTemplateRepositoryURL
{
	TPCThemeSettings *settings = self.settings;

	NSString *filename = [NSString stringWithFormat:@"/Style Default Templates/Version %lu/", settings.templateEngineVersion];

	NSURL *templatesPath = [[TPCPathInfo applicationResourcesURL] URLByAppendingPathComponent:filename];

	return templatesPath;
}

- (NSString *)applicationTemplateRepositoryPath
{
	NSURL *repositoryURL = [self _applicationTemplateRepositoryURL];

	return repositoryURL.path;
}

- (nullable GRMustacheTemplate *)templateWithLineType:(TVCLogLineType)type
{
	NSString *typeString = [TVCLogLine stringForLineType:type];

	NSString *templateName = [@"Line Types/" stringByAppendingString:typeString];

	GRMustacheTemplate *template = [self _templateWithName:templateName logErrors:NO];

	if (template == nil) {
		templateName = [self.class _templateLineTypes][typeString];

		if (templateName == nil) {
			return nil;
		}

		template = [self _templateWithName:templateName logErrors:YES];
	}

	return template;
}

- (nullable GRMustacheTemplate *)templateWithName:(NSString *)templateName
{
	return [self _templateWithName:templateName logErrors:YES];
}

- (nullable GRMustacheTemplate *)_templateWithName:(NSString *)templateName logErrors:(BOOL)logErrors
{
	NSParameterAssert(templateName != nil);

	NSCache *cache = self.templateCache;

	if (cache == nil) {
		cache = [NSCache new];

		self.templateCache = cache;
	} else {
		GRMustacheTemplate *template = [cache objectForKey:templateName];

		if (template) {
			return template;
		}
	}

	 GRMustacheTemplate * _Nullable (^_loadTemplate)(GRMustacheTemplateRepository *) =
	^GRMustacheTemplate * _Nullable (GRMustacheTemplateRepository *repository)
	{
		NSError *loadError = nil;

		GRMustacheTemplate *template = [repository templateNamed:templateName error:&loadError];

		if (loadError && (loadError.code == GRMustacheErrorCodeTemplateNotFound || loadError.code == 260)) {
			return nil;
		}

		if (loadError && logErrors) {
			LogToConsoleError("Failed to load template '%{public}@' with error: '%{public}@'",
				templateName, loadError.localizedDescription);
			LogStackTrace();
		}

		return template;
	};

	GRMustacheTemplate *template = nil;

	NSArray *repositories = self.templateRepositories;

	for (GRMustacheTemplateRepository *repository in repositories) {
		template = _loadTemplate(repository);

		if (template != nil) {
			break;
		}
	}

	if (template == nil) {
		GRMustacheTemplateRepository *repository = self.defaultTemplateRepository;

		template = _loadTemplate(repository);
	}

	if (template != nil) {
		[cache setObject:template forKey:templateName];
	}

	return template;
}

@end

NS_ASSUME_NONNULL_END
