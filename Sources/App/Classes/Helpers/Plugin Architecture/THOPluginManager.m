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

#define _extrasInstallerExtensionUpdateCheckInterval			345600

NSString * const THOPluginManagerFinishedLoadingPluginsNotification = @"THOPluginManagerFinishedLoadingPluginsNotification";

@interface THOPluginManager ()
@property (nonatomic, assign, readwrite) BOOL pluginsLoaded;
@property (nonatomic, copy, readwrite, nullable) NSArray<THOPluginItem *> *loadedPlugins;
@property (nonatomic, copy, nullable) NSArray<NSBundle *> *obsoleteBundles;
@property (nonatomic, assign) THOPluginItemSupportedFeature supportedFeatures;
@end

@implementation THOPluginManager

#pragma mark -
#pragma mark Retain & Release

- (void)loadPlugins
{
	static dispatch_once_t onceToken;

	/* Plugins load on the main thread: their init, pluginLoadedIntoMemory and
	 preference pane views are user interface code (Caffeine loads a nib), and
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

	self.pluginsLoaded = YES;

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self checkForObsoleteBundlesOrUpdatesAvailable];

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
	return [self supportedAppleScriptCommands:NO];
}

- (NSDictionary<NSString *, NSString *> *)supportedAppleScriptCommandsAndPaths
{
	return [self supportedAppleScriptCommands:YES];
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

#pragma mark -
#pragma mark Extras Installer

- (void)checkForObsoleteBundlesOrUpdatesAvailable
{
	/* This method will perform three actions:
	 1. It will notify user if they have any 3rd-party obsolete addons.
		This will prompt them to contact the developer.
	 2. It will notify user if they have any obsolete extras installer
		addons that cannot be loaded. This will prompt to open installer.
	 3. It will notify the user if they have any extras installer addons
		that have an update available.

	 #3 allows the user to suppress the prompt until a later time.
	 #2 and #1 are aggressive. The prompt will show each launch until the
	 addon is updated or deleted.

	 It is possible that multiple prompts will appear on the screen at
	 once. This will be considered an acceptable behavior for now.
	 Just make sure non-blocking alerts are used for this purpose. */

	[self checkForObsoleteBundles];

	[self extrasInstallerCheckForUpdates];
}

- (void)checkForObsoleteBundles
{
	NSArray *obsoleteBundles = self.obsoleteBundles;

	if (obsoleteBundles.count == 0) {
		return;
	}

	NSMutableArray<NSBundle *> *obsoleteExtras = [NSMutableArray array];
	NSMutableArray<NSBundle *> *obsoleteThirdParty = [NSMutableArray array];

	NSArray *extrasBundleIdentifiers = self.extrasInstallerBundleIdentifiers;

	for (NSBundle *bundle in self.obsoleteBundles) {
		NSString *bundleIdentifier = bundle.bundleIdentifier;

		if ([extrasBundleIdentifiers containsObject:bundleIdentifier]) {
			[obsoleteExtras addObject:bundle];
		} else {
			[obsoleteThirdParty addObject:bundle];
		}
	}

	if (obsoleteExtras.count > 0) {
		[self _extrasInstallerInformUserAboutUpdateForBundles:[obsoleteExtras copy] updateOptional:NO];
	}

	if (obsoleteThirdParty.count == 0) {
		return;
	}

	NSArray *thirdPartyBundles = [obsoleteThirdParty copy];

	NSString *bundlesName = [NSBundle formattedDisplayNamesForBundles:thirdPartyBundles];

	TVCAlert *alert =
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[45a-df]", THOPluginProtocolCompatibilityMinimumVersion)
						 title:TXTLS(@"Prompts[af6-45]", bundlesName)
				 defaultButton:TXTLS(@"Prompts[324-5d]")
			   alternateButton:nil
				   otherButton:TXTLS(@"Prompts[0ik-o9]")];

	[alert setButtonClickedBlock:^BOOL(TVCAlert *sender, TVCAlertResponseButton buttonClicked) {
		[NSBundle openInstallationLocationsForBundles:thirdPartyBundles];

		return NO;
	} forButton:TVCAlertResponseButtonThird];
}

- (void)extrasInstallerCheckForUpdates
{
	/* Do not check for updates too often */
#define _defaultsKey 	@"THOPluginManager -> Extras Installer Last Check for Update Payload"

	NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

	NSString *applicationVersion = [TPCApplicationInfo applicationVersion];

	NSDictionary<NSString *, id> *lastUpdatePayload = [RZUserDefaults() dictionaryForKey:_defaultsKey];

	if (lastUpdatePayload) {
		NSTimeInterval lastCheckTime = [lastUpdatePayload doubleForKey:@"lastCheck"];

		NSString *lastVersion = [lastUpdatePayload stringForKey:@"lastVersion"];

		if ((currentTime - lastCheckTime) < _extrasInstallerExtensionUpdateCheckInterval &&
			[lastVersion isEqualToString:applicationVersion])
		{
			return;
		}
	}

	/* Record the last time updates were checked for */
	[RZUserDefaults() setObject:@{
		@"lastCheck" : @(currentTime),
		@"lastVersion" : applicationVersion
	} forKey:_defaultsKey];

	/* Check for updates */
	[self _extrasInstallerCheckForUpdates];

#undef _defaultsKey
}

- (void)_extrasInstallerCheckForUpdates
{
	/* Perform update check */
	NSDictionary *latestVersions = self.extrasInstallerLatestBundleVersions;

	NSMutableArray<NSBundle *> *outdatedBundles = [NSMutableArray array];

	for (THOPluginItem *plugin in self.loadedPlugins) {
		NSBundle *bundle = plugin.bundle;

		NSString *bundleIdentifier = bundle.bundleIdentifier;

		NSString *latestVersion = latestVersions[bundleIdentifier];

		if (latestVersion == nil) {
			continue;
		}

		NSDictionary *infoDictionary = bundle.infoDictionary;

		NSString *currentVersion = infoDictionary[@"CFBundleVersion"];

		NSComparisonResult comparisonResult = [currentVersion compare:latestVersion options:NSNumericSearch];

		if (comparisonResult == NSOrderedAscending) {
			[outdatedBundles addObject:bundle];
		}
	}

	if (outdatedBundles.count == 0) {
		return;
	}

	[self _extrasInstallerInformUserAboutUpdateForBundles:[outdatedBundles copy] updateOptional:YES];
}

- (void)_extrasInstallerInformUserAboutUpdateForBundles:(NSArray<NSBundle *> *)bundles updateOptional:(BOOL)updateOptional
{
	NSParameterAssert(bundles != nil);

	/* Append the current version to the suppression key so that updates 
	 aren't refused forever. Only until the next version of Textual is out. */
	NSString *suppressionKey = nil;

	if (updateOptional) {
		suppressionKey =
		[@"plugin_manager_extension_update_dialog_"
	  stringByAppendingString:[TPCApplicationInfo applicationVersionShort]];
	}

	NSString *bundlesName = [NSBundle formattedDisplayNamesForBundles:bundles];

	NSString *promptTitle = ((updateOptional) ? @"Prompts[9mb-o5]" : @"Prompts[ins-op]");
	NSString *promptMessage = ((updateOptional) ? @"Prompts[x4w-is]" : @"Prompts[34o-pk]");
	NSString *promptDefaultButton = ((updateOptional) ? @"Prompts[ece-dd]" : @"Prompts[hd0-bf]");
	NSString *promptAlternateButton = ((updateOptional) ? @"Prompts[ioq-nf]" : @"Prompts[467-5l]");
	NSString *promptOtherButton = ((updateOptional) ? nil : TXTLS(@"Prompts[h78-9e]"));

	TVCAlert *alert =
	[TDCAlert alertWithMessage:TXTLS(promptMessage)
						 title:TXTLS(promptTitle, bundlesName)
				 defaultButton:TXTLS(promptDefaultButton)
			   alternateButton:TXTLS(promptAlternateButton)
				   otherButton:promptOtherButton
				suppressionKey:suppressionKey
			   suppressionText:nil
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id  _Nullable underlyingAlert) {
				   if (buttonClicked == TDCAlertResponseAlternate) {
					   [self extrasInstallerLaunchInstaller];
				   }
			   }];

	[alert setButtonClickedBlock:^BOOL(TVCAlert *sender, TVCAlertResponseButton buttonClicked) {
		[NSBundle openInstallationLocationsForBundles:bundles];

		return NO;
	} forButton:TVCAlertResponseButtonThird];
}

- (NSArray<NSString *> *)extrasInstallerBundleIdentifiers
{
	return self.extrasInstallerLatestBundleVersions.allKeys;
}

- (NSDictionary<NSString *, NSString *> *)extrasInstallerLatestBundleVersions
{
	/* List of extra bundles and their latest version number. */
	return [TPCResourceManager dictionaryFromResources:@"StaticStore" key:@"THOPluginManager Extras Installer Latest Extension Versions"];
}

- (NSArray<NSString *> *)extrasInstallerReservedCommands
{
	/* List of scripts that are available as downloadable
	 content from the www.codeux.com website. */
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"THOPluginManager List of Reserved Commands"];
}

- (void)findHandlerForOutgoingCommand:(NSString *)command
								 path:(NSString * _Nullable *)path
						   isReserved:(BOOL *)isReserved
							 isScript:(BOOL *)isScript
						  isExtension:(BOOL *)isExtension
{
	NSParameterAssert(command != nil);

	/* Reset context pointers */
	if ( path) {
		*path = nil;
	}

	if ( isReserved) {
		*isReserved = NO;
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

		return;
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

	/* Find a reserved command */
	NSArray *reservedCommands = self.extrasInstallerReservedCommands;

	if ( isReserved) {
		*isReserved = [reservedCommands containsObject:command];
	}
}

- (void)extrasInstallerAskUserIfTheyWantToInstallCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	BOOL download = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[bpb-vv]")
											  title:TXTLS(@"Prompts[o9p-4n]", command)
									  defaultButton:TXTLS(@"Prompts[6lr-02]")
									alternateButton:TXTLS(@"Prompts[qso-2g]")
									 suppressionKey:@"plugin_manager_reserved_command_dialog"
									suppressionText:nil];

	if (download) {
		[self extrasInstallerLaunchInstaller];
	}
}

- (void)extrasInstallerLaunchInstaller
{
	NSURL *extrasURL = [RZMainBundle() URLForResource:@"Textual-Extras" withExtension:@"pkg"];

	NSURL *installerURL =
	[RZWorkspace() URLForApplicationWithBundleIdentifier:@"com.apple.installer"];

	[RZWorkspace() openURLs:@[extrasURL]
	   withApplicationAtURL:installerURL
			  configuration:[NSWorkspaceOpenConfiguration new]
		  completionHandler:nil];;
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
