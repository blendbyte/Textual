/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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

#import "TXGlobalModels.h"
#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginItemPrivate.h"
#import "THOPluginProtocol.h"
#import "THOPluginManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN


NSString * const THOPluginManagerFinishedLoadingPluginsNotification = @"THOPluginManagerFinishedLoadingPluginsNotification";

@interface THOPluginManager ()
@property (nonatomic, assign, readwrite) BOOL pluginsLoaded;
@property (nonatomic, copy, readwrite, nullable) NSArray<THOPluginItem *> *loadedPlugins;
@property (nonatomic, copy, nullable) NSArray<NSBundle *> *obsoleteBundles;
@property (nonatomic, copy, nullable) NSArray<NSBundle *> *unsupportedBundles;
@property (nonatomic, assign) THOPluginItemSupportedFeature supportedFeatures;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *cachedScriptCommandsAndPaths;
@property (nonatomic, strong, nullable) XRFileSystemMonitor *scriptsMonitor;
@end

@implementation THOPluginManager

#pragma mark -
#pragma mark Retain & Release

- (void)loadPlugins
{
	static dispatch_once_t onceToken;

	/* Plugins load on the main thread: their init, pluginLoadedIntoMemory and
	 preference pane views are user interface code (a plugin may load a nib), and
	 a new third-party plugin asks for consent. Launch waits for them anyway. */
	dispatch_once(&onceToken, ^{
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			[self _loadPlugins];
		});
	});
}

- (void)unloadPlugins
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		XRPerformBlockSynchronouslyOnMainQueue(^{
			[self _unloadPlugins];
		});
	});
}

- (void)_loadPlugins
{
	NSArray *forbiddenPlugins = self.listOfForbiddenBundles;

	NSMutableArray<THOPluginItem *> *loadedPlugins = [NSMutableArray array];
	NSMutableArray<NSString *> *bundlesToLoad = [NSMutableArray array];
	NSMutableSet<NSString *> *bundledBundlePaths = [NSMutableSet set];
	NSMutableArray<NSString *> *loadedBundles = [NSMutableArray array];
	NSMutableArray<NSBundle *> *obsoleteBundles = [NSMutableArray array];
	NSMutableArray<NSBundle *> *unsupportedBundles = [NSMutableArray array];

	/* Bundled plugins first: the first plugin with an identifier wins, so a
	 bundle in the (writable) Extensions folder can't replace a bundled one */
	NSString *bundledExtensionsPath = [TPCPathInfo bundledExtensions];

	NSArray *pathsToLoad =
	[RZFileManager() buildPathArray:
		bundledExtensionsPath,
		[TPCPathInfo customExtensions],
		nil];

	for (NSString *path in pathsToLoad) {
		NSArray *pathFiles = [RZFileManager() contentsOfDirectoryAtPath:path error:NULL];

		if (pathFiles == nil) {
			continue;
		}

		for (NSString *file in pathFiles) {
			if ([file hasSuffix:TPCResourceManagerBundleDocumentTypeExtension] == NO) {
				continue;
			}

			NSString *filePath = [path stringByAppendingPathComponent:file];

			[bundlesToLoad addObject:filePath];

			/* Remembered by where it was found, not by comparing path strings
			 (the bundled folder's path contains "//", scanned paths don't) */
			if ([path isEqualToString:bundledExtensionsPath]) {
				[bundledBundlePaths addObject:filePath];
			}
		}
	}

	for (NSString *bundlePath in bundlesToLoad) {
		NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];

		if (bundle == nil) {
			continue;
		}

		NSString *bundleIdentifier = bundle.bundleIdentifier;

		if (bundleIdentifier == nil) {
			continue;
		}

		if ([loadedBundles containsObject:bundleIdentifier]) {
			LogToConsoleError("Not loading '%{public}@' at '%{public}@': a plugin with that identifier is already loaded", bundleIdentifier, bundlePath);

			continue;
		}

		/* The list of forbidden bundles logic was added because a plugin previously
		 bundled separately was not bundled with the app. This is a simple check to
		 prevent the old plugin from loading and conflicting with built-in plugin.
		 This is not designed as a security measure. */
		if ([forbiddenPlugins containsObject:bundleIdentifier]) {
			LogToConsoleFault("Forbidden loading of plugin '%{public}@'", bundleIdentifier);

			continue;
		}

		/* Extensions for features Textual no longer has (Blowfish, OTR) */
		if ([self bundleIsUnsupported:bundle]) {
			LogToConsoleError("Not loading unsupported plugin '%{public}@'", bundleIdentifier);

			[unsupportedBundles addObject:bundle];

			continue;
		}

		/* Begin version comparison */
		NSDictionary *infoDictionary = bundle.infoDictionary;

		NSString *comparisonVersion = infoDictionary[@"MinimumTextualVersion"];

		if (comparisonVersion == nil) {
			[obsoleteBundles addObject:bundle];

			NSLog(@" ---------------------------- ERROR ---------------------------- ");
			NSLog(@"                                                                 ");
			NSLog(@"  Textual has failed to load the bundle at the following path    ");
			NSLog(@"  which did not specify a minimum version:                       ");
			NSLog(@"                                                                 ");
			NSLog(@"     Bundle Path: %@", bundle.bundlePath);
			NSLog(@"                                                                 ");
			NSLog(@"  Please add a key-value pair in the bundle's Info.plist file    ");
			NSLog(@"  with the key name as \"MinimumTextualVersion\"                 ");
			NSLog(@"                                                                 ");
			NSLog(@"  For example, to support this version and later:                ");
			NSLog(@"                                                                 ");
			NSLog(@"     <key>MinimumTextualVersion</key>                            ");
			NSLog(@"     <string>%@</string>", THOPluginProtocolCompatibilityMinimumVersion);
			NSLog(@"                                                                 ");
			NSLog(@" --------------------------------------------------------------- ");

			continue;
		}

		NSComparisonResult comparisonResult =
		[comparisonVersion compare:THOPluginProtocolCompatibilityMinimumVersion options:NSNumericSearch];

		if (comparisonResult == NSOrderedAscending) {
			[obsoleteBundles addObject:bundle];

			NSLog(@" ---------------------------- ERROR ---------------------------- ");
			NSLog(@"                                                                 ");
			NSLog(@"  Textual has failed to load the bundle at the following path    ");
			NSLog(@"  because the specified minimum version is out of range:         ");
			NSLog(@"                                                                 ");
			NSLog(@"     Bundle Path: %@", bundle.bundlePath);
			NSLog(@"                                                                 ");
			NSLog(@"     Minimum version specified by bundle: %@", comparisonVersion);
			NSLog(@"     Version used by Textual for comparison: %@", THOPluginProtocolCompatibilityMinimumVersion);
			NSLog(@"                                                                 ");
			NSLog(@" --------------------------------------------------------------- ");

			continue;
		}

		/* Third-party plugins run with Textual's privileges: ask once for
		 each new or changed one */
		if ([bundledBundlePaths containsObject:bundlePath] == NO &&
			[self userAllowsThirdPartyBundle:bundle] == NO)
		{
			continue;
		}

		/* Load bundle as a plugin */
		THOPluginItem *plugin = [THOPluginItem new];

		BOOL pluginLoaded = [plugin loadBundle:bundle];

		if (pluginLoaded == NO) {
			continue;
		}

		[loadedPlugins addObject:plugin];

		[loadedBundles addObject:bundleIdentifier];

		[self updateSupportedFeaturesPropertyWithPlugin:plugin];
	}

	self.loadedPlugins = loadedPlugins;

	self.obsoleteBundles = obsoleteBundles;

	self.unsupportedBundles = unsupportedBundles;

	self.pluginsLoaded = YES;

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self checkForObsoleteBundles];

		[self checkForUnsupportedBundles];

		[RZNotificationCenter() postNotificationName:THOPluginManagerFinishedLoadingPluginsNotification object:self];
	});
}

#pragma mark -
#pragma mark Third-Party Consent

/* What the user decided per plugin path: the plugin's hash and whether it may load */
static NSString * const _thirdPartyPluginDecisionsDefaultsKey = @"THOPluginManager -> Third-Party Plugin Decisions";

/* Changes when any file in the plugin changes (code, nested frameworks,
 nibs, Info.plist): the relative path and contents of every file */
- (nullable NSString *)hashOfBundle:(NSBundle *)bundle
{
	NSString *bundlePath = bundle.bundlePath;

	NSMutableArray<NSString *> *relativePaths = [NSMutableArray array];

	NSDirectoryEnumerator *enumerator = [RZFileManager() enumeratorAtPath:bundlePath];

	for (NSString *relativePath in enumerator) {
		if ([enumerator.fileAttributes.fileType isEqualToString:NSFileTypeRegular]) {
			[relativePaths addObject:relativePath];
		}
	}

	if (relativePaths.count == 0) {
		return nil;
	}

	[relativePaths sortUsingSelector:@selector(compare:)];

	NSMutableData *contents = [NSMutableData data];

	for (NSString *relativePath in relativePaths) {
		NSData *fileContents = [NSData dataWithContentsOfFile:[bundlePath stringByAppendingPathComponent:relativePath]];

		if (fileContents == nil) {
			return nil;
		}

		NSString *fileEntry = [NSString stringWithFormat:@"%@\n%@\n", relativePath, fileContents.sha256];

		[contents appendData:[fileEntry dataUsingEncoding:NSUTF8StringEncoding]];
	}

	return contents.sha256;
}

- (BOOL)userAllowsThirdPartyBundle:(NSBundle *)bundle
{
	NSParameterAssert(bundle != nil);

	NSString *bundlePath = bundle.bundlePath;

#ifdef DEBUG
	/* Textual Dev under automated tests: no consent prompt blocking launch */
	if ([[[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain][@"TextualDevSkipThirdPartyPlugins"] boolValue]) {
		LogToConsole("Skipping third-party plugin at %{public}@ (TextualDevSkipThirdPartyPlugins)", bundlePath);

		return NO;
	}
#endif

	NSString *bundleHash = [self hashOfBundle:bundle];

	if (bundleHash == nil) {
		return NO;
	}

	NSDictionary *decisions = [RZUserDefaults() dictionaryForKey:_thirdPartyPluginDecisionsDefaultsKey];

	NSDictionary *decision = decisions[bundlePath];

	if ([decision isKindOfClass:[NSDictionary class]] &&
		[decision[@"hash"] isEqual:bundleHash] &&
		[decision boolForKey:@"allowed"])
	{
		return YES;
	}

	NSString *bundleName = bundle.infoDictionary[@"CFBundleName"];

	if ([bundleName isKindOfClass:[NSString class]] == NO || bundleName.length == 0) {
		bundleName = bundlePath.lastPathComponent;
	}

	BOOL changed = ([decision isKindOfClass:[NSDictionary class]] && [decision boolForKey:@"allowed"]);

	BOOL allowed = [TDCAlert modalAlertWithMessage:TXTLS(((changed) ? @"Prompts[w8p-a3]" : @"Prompts[w8p-a2]"), bundlePath)
											 title:TXTLS(@"Prompts[w8p-a1]", bundleName)
									 defaultButton:TXTLS(@"Prompts[w8p-a4]")
								   alternateButton:TXTLS(@"Prompts[w8p-a5]")];

	/* Only "Load" is remembered. "Don't Load" holds for this launch: the user
	 is asked again next time, so the choice can't get stuck (to stop being
	 asked, the plugin is removed from the Extensions folder). */
	if (allowed == NO) {
		return NO;
	}

	NSMutableDictionary *decisionsMutable = [decisions mutableCopy];

	if (decisionsMutable == nil) {
		decisionsMutable = [NSMutableDictionary dictionary];
	}

	decisionsMutable[bundlePath] = @{@"hash" : bundleHash, @"allowed" : @YES};

	[RZUserDefaults() setObject:decisionsMutable forKey:_thirdPartyPluginDecisionsDefaultsKey];

	return YES;
}

- (void)_unloadPlugins
{
	for (THOPluginItem *plugin in self.loadedPlugins) {
		[plugin unloadBundle];
	}

	self.loadedPlugins = nil;
}

#pragma mark -
#pragma mark AppleScript Support

- (NSArray<NSString *> *)supportedAppleScriptCommands
{
	return self.supportedAppleScriptCommandsAndPaths.allKeys;
}

/* Every unknown command listed and checked both script folders (and logged
 the same warnings again): the list is kept until the scripts folder changes */
- (NSDictionary<NSString *, NSString *> *)supportedAppleScriptCommandsAndPaths
{
	@synchronized (self) {
		NSDictionary *scripts = self.cachedScriptCommandsAndPaths;

		if (scripts) {
			return scripts;
		}

		scripts = [self supportedAppleScriptCommands:YES];

		self.cachedScriptCommandsAndPaths = scripts;

		[self startMonitoringScripts];

		return scripts;
	}
}

/* The bundled scripts are in the signed app and never change */
- (void)startMonitoringScripts
{
	if (self.scriptsMonitor != nil) {
		return;
	}

	NSString *path = [TPCPathInfo customScripts];

	if (path == nil) {
		return;
	}

	__weak THOPluginManager *weakSelf = self;

	XRFileSystemMonitor *monitor =
	[[XRFileSystemMonitor alloc] initWithFileURL:[NSURL fileURLWithPath:path isDirectory:YES] callbackBlock:^(NSArray<XRFileSystemEvent *> *events) {
		THOPluginManager *strongSelf = weakSelf;

		@synchronized (strongSelf) {
			strongSelf.cachedScriptCommandsAndPaths = nil;
		}
	}];

	[monitor startMonitoringWithLatency:1.0];

	self.scriptsMonitor = monitor;
}

- (id)supportedAppleScriptCommands:(BOOL)returnPathInfo
{
	NSArray *forbiddenCommands = self.listOfForbiddenCommandNames;

	NSArray *scriptPaths =
	[RZFileManager() buildPathArray:
		[TPCPathInfo customScripts],
		[TPCPathInfo bundledScripts],
		nil];

	id returnValue = nil;

	if (returnPathInfo) {
		returnValue = [NSMutableDictionary dictionary];
	} else {
		returnValue = [NSMutableArray array];
	}

	for (NSString *path in scriptPaths) {
		NSArray *pathFiles = [RZFileManager() contentsOfDirectoryAtPath:path error:NULL];

		for (NSString *file in pathFiles) {
			NSString *filePath = [path stringByAppendingPathComponent:file];

			NSString *fileExtension = file.pathExtension;

			NSString *fileWithoutExtension = file.stringByDeletingPathExtension;

			NSString *command = fileWithoutExtension.lowercaseString;

			BOOL executable = [RZFileManager() isExecutableFileAtPath:filePath];

			if (executable == NO && [fileExtension isEqualToString:TPCResourceManagerScriptDocumentTypeExtensionWithoutPeriod] == NO) {
				LogToConsoleInfo("WARNING: File “%{public}@“ found in unsupervised script folder but it isn't AppleScript or an executable. It will be ignored.", file);

				continue;
			} else if ([forbiddenCommands containsObject:command]) {
				LogToConsoleInfo("WARNING: The command “%{public}@“ exists as a script file, but it is being ignored because the command name is forbidden.", fileWithoutExtension);

				continue;
			}

			if (returnPathInfo) {
				[returnValue setObjectWithoutOverride:filePath forKey:command];
			} else {
				[returnValue addObjectWithoutDuplication:command];
			}
		}
	}

	return returnValue;
}

- (NSArray<NSString *> *)listOfForbiddenCommandNames
{
	/* List of commands that cannot be used as the name of a script 
	 because they would conflict with the commands defined by one or
	 more standard (RFC) */
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"THOPluginManager List of Forbidden Commands"];
}

- (NSArray<NSString *> *)listOfForbiddenBundles
{
	/* List of bundle identifiers that are not allowed to load. */
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"THOPluginManager List of Forbidden Extensions"];
}

- (NSArray<NSString *> *)listOfUnsupportedBundles
{
	/* Bundle identifiers of extensions for removed features. Not loaded;
	 the user is told once and offered to move them to the Trash. */
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"THOPluginManager List of Unsupported Extensions"];
}

- (BOOL)bundleIsUnsupported:(NSBundle *)bundle
{
	NSParameterAssert(bundle != nil);

	NSString *bundleIdentifier = bundle.bundleIdentifier;

	return (bundleIdentifier && [self.listOfUnsupportedBundles containsObject:bundleIdentifier]);
}

#pragma mark -
#pragma mark Bundles That Cannot Load

- (void)checkForObsoleteBundles
{
	/* Shown each launch until the plugin is updated or removed */
	NSArray *obsoleteBundles = self.obsoleteBundles;

	if (obsoleteBundles.count == 0) {
		return;
	}

	NSString *bundlesName = [NSBundle formattedDisplayNamesForBundles:obsoleteBundles];

	TVCAlert *alert =
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[45a-df]", THOPluginProtocolCompatibilityMinimumVersion)
						 title:TXTLS(@"Prompts[af6-45]", bundlesName)
				 defaultButton:TXTLS(@"Prompts[324-5d]")
			   alternateButton:nil
				   otherButton:TXTLS(@"Prompts[0ik-o9]")];

	[alert setButtonClickedBlock:^BOOL(TVCAlert *sender, TVCAlertResponseButton buttonClicked) {
		[NSBundle openInstallationLocationsForBundles:obsoleteBundles];

		return NO;
	} forButton:TVCAlertResponseButtonThird];
}

- (void)checkForUnsupportedBundles
{
	/* Told once per extension, whatever the user answers */
	static NSString * const reportedDefaultsKey = @"THOPluginManager -> Reported Unsupported Extensions";

	NSArray<NSString *> *reported = [RZUserDefaults() arrayForKey:reportedDefaultsKey];

	NSMutableArray<NSBundle *> *bundles = [NSMutableArray array];

	for (NSBundle *bundle in self.unsupportedBundles) {
		if ([reported containsObject:bundle.bundleIdentifier] == NO) {
			[bundles addObject:bundle];
		}
	}

	if (bundles.count == 0) {
		return;
	}

	NSMutableArray<NSString *> *reportedMutable = [NSMutableArray arrayWithArray:reported];

	for (NSBundle *bundle in bundles) {
		[reportedMutable addObject:bundle.bundleIdentifier];
	}

	[RZUserDefaults() setObject:[reportedMutable copy] forKey:reportedDefaultsKey];

	NSString *bundlesName = [NSBundle formattedDisplayNamesForBundles:bundles];

	[self _offerToTrashBundles:bundles withTitle:TXTLS(@"Prompts[u5x-b1]", bundlesName) message:TXTLS(@"Prompts[u5x-b2]")];
}

- (void)_offerToTrashBundles:(NSArray<NSBundle *> *)bundles withTitle:(NSString *)title message:(NSString *)message
{
	NSParameterAssert(bundles != nil);
	NSParameterAssert(title != nil);
	NSParameterAssert(message != nil);

	[TDCAlert alertWithMessage:message
						 title:title
				 defaultButton:TXTLS(@"Prompts[u5x-b3]")
			   alternateButton:TXTLS(@"Prompts[u5x-b4]")
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id _Nullable underlyingAlert) {
				   if (buttonClicked != TDCAlertResponseDefault) {
					   return;
				   }

				   for (NSBundle *bundle in bundles) {
					   NSError *trashError = nil;

					   if ([RZFileManager() trashItemAtURL:bundle.bundleURL resultingItemURL:NULL error:&trashError] == NO) {
						   LogToConsoleError("Failed to move '%{public}@' to the Trash: %{public}@",
							   bundle.bundlePath, trashError.localizedDescription);
					   }
				   }
			   }];
}

- (void)findHandlerForOutgoingCommand:(NSString *)command
								 path:(NSString * _Nullable *)path
							 isScript:(BOOL *)isScript
						  isExtension:(BOOL *)isExtension
{
	NSParameterAssert(command != nil);

	/* Reset context pointers */
	if ( path) {
		*path = nil;
	}

	if ( isScript) {
		*isScript = NO;
	}

	if ( isExtension) {
		*isExtension = NO;
	}

	/* Find a script that matches this command */
	NSDictionary *scriptPaths = self.supportedAppleScriptCommandsAndPaths;

	for (NSString *scriptCommand in scriptPaths) {
		if ([scriptCommand isEqualToString:command] == NO) {
			continue;
		}

		if ( path) {
			*path = scriptPaths[scriptCommand];
		}

		if ( isScript) {
			*isScript = YES;
		}

		/* Not return: a plugin with the same command is reported too, so
		 neither runs and the conflict is printed (as documented in
		 THOPluginProtocol); the script used to win silently */
		break;
	}

	/* Find an extension that matches this command */
	/* Not the list cached at launch: a plugin disabled after an exception
	 no longer handles its commands (they reach the server instead of
	 disappearing silently) */
	BOOL pluginFound = NO;

	for (THOPluginItem *plugin in self.loadedPlugins) {
		if ([plugin supportsFeature:THOPluginItemSupportedFeatureSubscribedUserInputCommands] &&
			[plugin.supportedUserInputCommands containsObject:command])
		{
			pluginFound = YES;

			break;
		}
	}

	if (pluginFound) {
		if ( isExtension) {
			*isExtension = YES;
		}

		return;
	}
}

#pragma mark -
#pragma mark Extension Information

- (void)updateSupportedFeaturesPropertyWithPlugin:(THOPluginItem *)plugin
{
	NSParameterAssert(plugin != nil);

#define _ef(_feature)		if ([plugin supportsFeature:(_feature)] && [self supportsFeature:(_feature)] == NO) {		\
								self->_supportedFeatures |= (_feature);														\
							}

	_ef(THOPluginItemSupportedFeatureDidReceiveCommandEvent)
	_ef(THOPluginItemSupportedFeatureDidReceivePlainTextMessageEvent)
//	_ef(THOPluginItemSupportedFeatureInlineMediaManipulation)
	_ef(THOPluginItemSupportedFeatureNewMessagePostedEvent)
	_ef(THOPluginItemSupportedFeatureOutputSuppressionRules)
	_ef(THOPluginItemSupportedFeaturePreferencePane)
	_ef(THOPluginItemSupportedFeatureServerInputDataInterception)
	_ef(THOPluginItemSupportedFeatureSubscribedServerInputCommands)
	_ef(THOPluginItemSupportedFeatureSubscribedUserInputCommands)
	_ef(THOPluginItemSupportedFeatureUserInputDataInterception)
	_ef(THOPluginItemSupportedFeatureWebViewJavaScriptPayloads)
	_ef(THOPluginItemSupportedFeatureWillRenderMessageEvent)

#undef _ef
}

- (BOOL)supportsFeature:(THOPluginItemSupportedFeature)feature
{
	return ((self->_supportedFeatures & feature) == feature);
}

- (NSArray<THOPluginOutputSuppressionRule *> *)pluginOutputSuppressionRules
{
	if (self.pluginsLoaded == NO) {
		return @[];
	}

	static NSArray<THOPluginOutputSuppressionRule *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableArray<THOPluginOutputSuppressionRule *> *allRules = [NSMutableArray array];

		for (THOPluginItem *plugin in self.loadedPlugins) {
			if ([plugin supportsFeature:THOPluginItemSupportedFeatureOutputSuppressionRules] == NO) {
				continue;
			}

			NSArray *rules = plugin.outputSuppressionRules;

			if (rules) {
				[allRules addObjectsFromArray:rules];
			}
		}

		cachedValue = [allRules copy];
	});

	return cachedValue;
}

- (NSArray<NSString *> *)supportedUserInputCommands
{
	if (self.pluginsLoaded == NO) {
		return @[];
	}

	static NSArray<NSString *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableArray<NSString *> *allCommands = [NSMutableArray array];

		for (THOPluginItem *plugin in self.loadedPlugins) {
			if ([plugin supportsFeature:THOPluginItemSupportedFeatureSubscribedUserInputCommands] == NO) {
				continue;
			}

			NSArray *commands = plugin.supportedUserInputCommands;

			for (NSString *command in commands) {
				[allCommands addObjectWithoutDuplication:command];
			}
		}

		[allCommands sortUsingComparator:NSDefaultComparator];

		cachedValue = [allCommands copy];
	});

	return cachedValue;
}

- (NSArray<NSString *> *)supportedServerInputCommands
{
	if (self.pluginsLoaded == NO) {
		return @[];
	}

	static NSArray<NSString *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableArray<NSString *> *allCommands = [NSMutableArray array];

		for (THOPluginItem *plugin in self.loadedPlugins) {
			if ([plugin supportsFeature:THOPluginItemSupportedFeatureSubscribedServerInputCommands] == NO) {
				continue;
			}

			NSArray *commands = plugin.supportedServerInputCommands;

			for (NSString *command in commands) {
				[allCommands addObjectWithoutDuplication:command];
			}
		}

		[allCommands sortUsingComparator:NSDefaultComparator];

		cachedValue = [allCommands copy];
	});

	return cachedValue;
}

- (NSArray<THOPluginItem *> *)pluginsWithPreferencePanes
{
	if (self.pluginsLoaded == NO) {
		return @[];
	}

	static NSArray<THOPluginItem *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableArray<THOPluginItem *> *allExtensions = [NSMutableArray array];

		for (THOPluginItem *plugin in self.loadedPlugins) {
			if ([plugin supportsFeature:THOPluginItemSupportedFeaturePreferencePane] == NO) {
				continue;
			}

			[allExtensions addObject:plugin];
		}

		[allExtensions sortUsingComparator:^NSComparisonResult(THOPluginItem *object1, THOPluginItem *object2) {
			return [object1.pluginPreferencesPaneMenuItemTitle compare:
					object2.pluginPreferencesPaneMenuItemTitle];
		}];

		cachedValue = [allExtensions copy];
	});

	return cachedValue;
}

@end

NS_ASSUME_NONNULL_END
