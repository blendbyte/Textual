/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *   Copyright (c) 2024 Codeux Software, LLC & respective contributors.
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

#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "TPCSandboxMigrationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/*
 Standalone Classic - This refers to an installation of Textual 7
 downloaded from codeux.com before the transition to sandbox.

 Mac App Store - This refers to an installation of Textual 7
 downloaded from the Mac App Store.

 Migration steps:
	1. 	Check the age of the current group container.
		If it wasn't recently created. Like within the
		span of a few seconds ago, then stop.
	2. 	Locate Standalone Classic preferences
	3. 	If located, is the value of TXRunCount >= 1
		If yes, perform migration on that installation.
	4. 	If migration is not performed, then locate
		Mac App Store preferences if this is the first
		time this installation of Textual has launched.
	5. 	If located, is the value of TXRunCount >= 1
		If yes, have the preferences been modified with
		the last 30 days (see MaximumAgeOfStalePreferences)
		If yes, perform migration on that installation.

 Data and files are migrated by creating copies.
 After migration is completed, the user will be asked if
 they want to remove (delete / erase) the old contents.
*/

/* Textual will import preferences from a Mac App Store purchase
 if this is the first launch. This macro defines the maximum amount
 of time that was allowed to elapse since the preferences for that
 installation was last modified. We don't want to import an installation
 that the user setup a year ago on a whim and only used it a day. */
#define MaximumAgeOfStalePreferences 		(60 * 60 * 24 * 30)  // 30 days

/* Defaults key set after migration is performed. */
/* YES if migration was completed */
#define MigrationCompleteDefaultsKey					@"Sandbox Migration -> Migrated Resources"

/* Integer for the installation that was migrated */
/* nil value or zero result is possible even after migration
 is complete because nothing might have been migrated. */
/* Migration is designed to be one shot. */
#define MigrationInstallationMigratedDefaultsKey		@"Sandbox Migration -> Installation Migrated"

/* Whether the user has dismissed the notification alert */
#define MigrationUserAcknowledgedDefaultsKey			@"Sandbox Migration -> User Acknowledged"

/* Whether the user wants to delete old files */
#define MigrationUserPrefersPruningDefaultsKey			@"Sandbox Migration -> User Prefers Pruning Files"

/* YES if there are no more extensions to prune
 which means we can bypass all the directory scans. */
#define MigrationAllExtensionsPrunedDefaultsKey			@"Sandbox Migration -> All Extensions Pruned"

/* An array of preference keys migrated */
#define MigrationKeysImportedDefaultsKey				@"Sandbox Migration -> Imported Keys"

/* Result returned when performing migration of a specific installation. */
typedef NS_ENUM(NSUInteger, TPCMigrateSandboxResult)
{
	/* Migration was performed successfully */
	TPCMigrateSandboxResultSuccess,

	/* Candidate for migration is not suitable.
	 For example, a Mac App Store installation was located
	 but the age of its preference file is out of range. */
	TPCMigrateSandboxResultNotSuitable,

	/* An error occurred during migration. */
	/* Errors are logged to console. */
	TPCMigrateSandboxResultError
};

/* The installation attempting migration / migrated */
typedef NS_ENUM(NSUInteger, TPCMigrateSandboxInstallation)
{
	/* Standalone Classic */
	TPCMigrateSandboxInstallationStandaloneClassic 	= 100,

	/* Mac App Store */
	TPCMigrateSandboxInstallationMacAppStore		= 200
};

@interface TPCPathInfo (TPCSandboxMigration)
+ (nullable NSURL *)_groupContainerURLForInstallation:(TPCMigrateSandboxInstallation)installation;
+ (nullable NSURL *)_groupContainerPreferencesURLForInstallation:(TPCMigrateSandboxInstallation)installation;
+ (nullable NSURL *)_groupContainerExtensionsURLForInstallation:(TPCMigrateSandboxInstallation)installation;
@end

@interface TPCResourceManager (TPCSandoxMigration)
+ (nullable NSArray<NSURL *> *)_listOfExtensionsForInstallation:(TPCMigrateSandboxInstallation)installation;
+ (BOOL)_ageOfCurrentContainerIsRecent;
+ (NSTimeInterval)_modificationDateForMacAppStorePreferencesIsRecent;
+ (NSTimeInterval)_intervalSinceCreatedForURL:(NSURL *)url;
+ (NSTimeInterval)_intervalSinceLastModificationForURL:(NSURL *)url;
+ (BOOL)_URLIsSymbolicLink:(NSURL *)url;
@end

@interface TPCPreferencesUserDefaults ()
- (void)_migrateObject:(nullable id)value forKey:(NSString *)defaultName;
@end

@implementation TPCSandboxMigration

+ (void)migrateResources
{
	LogToConsole("Preparing to migrate group containers");

	/* Do not migrate if we have done so in the past. */
	if ([RZUserDefaults() boolForKey:MigrationCompleteDefaultsKey]) {
		[self _notifyGroupContainerMigratedFromDefaults];
		[self _pruneExtensionSymbolicLinksFromDefaults];

		LogToConsole("Group containers have already been migrated");

		return;
	}

	/* Do not migrate if the age of the current group container is not recent.
	 The age is only going to be recent the launch it was created. */
	if ([TPCResourceManager _ageOfCurrentContainerIsRecent] == NO) {
		[self _setMigrationCompleteAndAcknowledged];

		LogToConsole("Current group container was not created recently");

		return;
	}

	/* The order of this array is the order of preference for migration.
	 If one migrates, then it stops there. */
	/* I acknowledge creating a list of numbers just to enumerate them
	 is not efficient. This will be ran once. It's okay. :) */
	NSArray *installations = @[@(TPCMigrateSandboxInstallationStandaloneClassic),
							   @(TPCMigrateSandboxInstallationMacAppStore)];

	for (NSNumber *installationRef in installations) {
		if ([self _migrateInstallationEntry:installationRef]) {
			return; // Success
		}
	}

	/* No other migration path */
	[self _setMigrationCompleteAndAcknowledged];
}

#pragma mark -
#pragma mark Standalone Classic Migration

+ (BOOL)_migrateInstallationEntry:(NSNumber *)installationRef
{
	NSParameterAssert(installationRef != nil);

	TPCMigrateSandboxInstallation installation = installationRef.unsignedIntegerValue;

	NSString *description = [self _descriptionOfInstallation:installation];

	LogToConsole("Start: Migrating [%{public}@] installation", description);

	TPCMigrateSandboxResult result = [self _migrateInstallation:installation];

	switch (result) {
		case TPCMigrateSandboxResultSuccess:
			[self _setMigrationCompleteForInstallation:installation];

			LogToConsole("End: Migrating [%{public}@] successful", description);

			return YES; // Stop further migration
		case TPCMigrateSandboxResultError:
			LogToConsole("End: Migrating [%{public}@] failed. Stopping all migration", description);

			return YES; // Stop further migration
		case TPCMigrateSandboxResultNotSuitable:
			LogToConsole("End: Migrating [%{public}@] failed. Installation is not suitable", description);

			return NO; // Allow further migration
	}
}

+ (TPCMigrateSandboxResult)_migrateInstallation:(TPCMigrateSandboxInstallation)installation
{
	/* Preflight checks */
	BOOL isMacAppStore = (installation == TPCMigrateSandboxInstallationMacAppStore);

	if (isMacAppStore && [TPCResourceManager _modificationDateForMacAppStorePreferencesIsRecent] == NO) {
		LogToConsoleDebug("Migration of Mac App Store has stale preferences file");

		return TPCMigrateSandboxResultNotSuitable;
	}

	NSString *suiteName = [self _defaultsSuiteNameForInstallation:installation];

	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];

	if (defaults == nil) {
		LogToConsole("NSUserDefaults object could not be created for [%{public}@] domain: '%{public}@'",
			[self _descriptionOfInstallation:installation], ((suiteName) ?: @"<no suite name>"));

		return TPCMigrateSandboxResultNotSuitable;
	}

	/* Import preference keys */
	/* Import preferences before migrating group container that way if a
	 hard failure is encountered there, it wont undo the progress we made.
	 The user will want something rather than nothing. Especially when it
	 comes to their configuration. Custom content can be copied manually. */
	NSDictionary *preferences = defaults.dictionaryRepresentation;

	NSUInteger runCount = [preferences unsignedIntegerForKey:@"TXRunCount"];

	if (runCount == 0) {
		LogToConsoleError("Migration of [%{public}@] has zero run count",
			[self _descriptionOfInstallation:installation]);

		return TPCMigrateSandboxResultNotSuitable;
	}

	/* Import preferences */
	NSArray *importedKeys = [self _importPreferences:preferences];

	/* Migrate group container */
	BOOL migrateContainer = [self _migrateGroupContainerContentsForInstallation:installation];

	if (migrateContainer == NO) {
		return TPCMigrateSandboxResultError;
	}

	/* Finish */
	[self _setListOfImportedKeys:importedKeys];

	[self _notifyGroupContainerMigratedForInstallation:installation];

	return TPCMigrateSandboxResultSuccess;
}

+ (NSArray<NSString *> *)_importPreferences:(NSDictionary<NSString *, id> *)dict
{
	NSParameterAssert(dict != nil);

	LogToConsole("Start: Migrating preferences");

	NSMutableArray *importedKeys = [NSMutableArray arrayWithCapacity:dict.count];

	[dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object, BOOL *stop) {
		if ([TPCPreferencesUserDefaults keyIsExcludedFromMigration:key]) {
#ifdef DEBUG
			LogToConsoleDebug("Key is excluded from migration: '%{public}@'", key);
#endif

			return;
		}

		[importedKeys addObject:key];

		[RZUserDefaults() _migrateObject:object forKey:key];
	}];

	LogToConsole("End: Migrating preferences");

	return [importedKeys copy];
}

+ (void)_removeImportedKeysForInstallation:(TPCMigrateSandboxInstallation)installation
{
	LogToConsole("Start: Remove old preferences");

	NSArray *listOfKeys = [RZUserDefaults() arrayForKey:MigrationKeysImportedDefaultsKey];

	if (listOfKeys == nil) {
		LogToConsole("No preferences to remove");

		return;
	}

	NSUserDefaults *defaults = 
	[[NSUserDefaults alloc] initWithSuiteName:[self _defaultsSuiteNameForInstallation:installation]];

	if (defaults == nil) {
		LogToConsole("NSUserDefaults object could not be created for [%{public}@] installation",
			[self _descriptionOfInstallation:installation]);

		return;
	}

	for (id key in listOfKeys) {
		/* This data could have been manipulated from the outside. */
		if ([key isKindOfClass:[NSString class]] == NO) {
			LogToConsoleFault("Corrupted data found inside list of keys");

			continue;
		}

#ifdef DEBUG
		LogToConsoleDebug("Removing key: '%{public}@'", key);
#endif

		[defaults removeObjectForKey:key];
	}

	[self _unsetListOfImportedKeys];

	LogToConsole("End: Remove old preferences - Removed: %{public}lu", listOfKeys.count);
}

+ (void)_setListOfImportedKeys:(nullable NSArray<NSString *> *)list
{
	[RZUserDefaults() _migrateObject:list forKey:MigrationKeysImportedDefaultsKey];
}

+ (void)_unsetListOfImportedKeys
{
	[self _setListOfImportedKeys:nil];
}

+ (void)_setMigrationComplete
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationCompleteDefaultsKey];
}

+ (void)_setMigrationCompleteAndAcknowledged
{
	/* This method is called when there was nothing to migrate
	 so we set complete and pretend user acknowledged it. */
	[self _setMigrationComplete];

	[self _setUserAcknowledgedMigration];
}

+ (void)_setMigrationCompleteForInstallation:(TPCMigrateSandboxInstallation)installation
{
	[RZUserDefaults() _migrateObject:@(installation) forKey:MigrationInstallationMigratedDefaultsKey];

	[self _setMigrationComplete];
}

#pragma mark -
#pragma mark Group Container Migration

+ (BOOL)_migrateGroupContainerContentsForInstallation:(TPCMigrateSandboxInstallation)installation
{
	LogToConsole("Start: Migrate group container for '%{public}@'",
		[self _descriptionOfInstallation:installation]);

	NSURL *oldLocation = [TPCPathInfo _groupContainerURLForInstallation:installation];

	if (oldLocation == nil) {
		LogToConsoleError("Cannot migrate group container contents because of nil source location");

		return NO;
	}

	NSURL *newLocation = [TPCPathInfo groupContainerURL];

	if (newLocation == nil) {
		LogToConsoleError("Cannot migrate group container contents because of nil destination location");

		return NO;
	}

	/* Migration is performed by recursively copying contents effectively merging the contents. */
	/* If a file already exists, it will not be overwrote under any condition. */
	/* This should only be performed with no real resources in the group container
	 destination group container anyways so this wont matter much. */
	BOOL result =
	[RZFileManager() mergeDirectoryAtURL:oldLocation
					  withDirectoryAtURL:newLocation
								 options:(CSFileManagerOptionsEnumerateDirectories |
										  CSFileManagerOptionContinueOnError |
										  CSFileManagerOptionsCreateDirectory |
										  CSFileManagerCreateSymbolicLinkForPackages)];

	LogToConsole("End: Migrate group container - Result: %{BOOL}d", result);

	return result;
}

+ (void)_notifyGroupContainerMigratedForInstallation:(TPCMigrateSandboxInstallation)installation
{
	LogToConsole("Notifying user that installation of type [%{public}@] migration performed",
		[self _descriptionOfInstallation:installation]);

	TVCAlert *alert =
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[qy4-5o]")
						 title:TXTLS(@"Prompts[ios-na]")
				 defaultButton:TXTLS(@"Prompts[zjw-bd]")
			   alternateButton:nil
				   otherButton:TXTLS(@"Prompts[d90-au]")
				suppressionKey:nil
			   suppressionText:TXTLS(@"Prompts[q3t-45]")
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id  _Nullable underlyingAlert) 
	 {
		[self _setUserAcknowledgedMigration];

		if (suppressed) {
			[self _setUserPrefersPruningFiles];

			[self _removeImportedKeysForInstallation:installation];
			[self _removeGroupContainerContentsForInstallation:installation];
		} else {
			[self _unsetListOfImportedKeys];
		}
	}];

	[alert setButtonClickedBlock:^BOOL(TVCAlert *sender, TVCAlertResponseButton buttonClicked) {
		[TLOpenLink openWithString:@"https://help.codeux.com/textual/miscellaneous/Why-Did-Textual-Copy-Files-to-a-New-Location.kb" inBackground:NO];

		return NO;
	} forButton:TVCAlertResponseButtonThird];
}

+ (void)_notifyGroupContainerMigratedFromDefaults
{
	/* This method is only invoked internally if the defaults key
	 MigrationCompleteDefaultsKey is set which means we are just
	 asking the user what they want to do with their files until
	 they acknowledge the alert. */
	BOOL userAcknowledged = [RZUserDefaults() boolForKey:MigrationUserAcknowledgedDefaultsKey];

	if (userAcknowledged) {
		return; // Stop migration
	}

	TPCMigrateSandboxInstallation installation = [RZUserDefaults() unsignedIntegerForKey:MigrationInstallationMigratedDefaultsKey];

	if ([self _isInstallationSupported:installation] == NO) {
		[self _setUserAcknowledgedMigration];

		return; // Stop migration
	}

	[self _notifyGroupContainerMigratedForInstallation:installation];
}

+ (void)_setUserAcknowledgedMigration
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationUserAcknowledgedDefaultsKey];
}

+ (void)_setUserPrefersPruningFiles
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationUserPrefersPruningDefaultsKey];
}

#pragma mark -
#pragma mark Group Container Removal

+ (BOOL)_removeGroupContainerContentsForInstallation:(TPCMigrateSandboxInstallation)installation
{
	LogToConsole("Start: Remove group container for '%{public}@'",
		[self _descriptionOfInstallation:installation]);

	NSURL *gcLocation = [TPCPathInfo _groupContainerURLForInstallation:installation];

	if (gcLocation == nil) {
		LogToConsoleError("Cannot remove group container contents because of nil location");

		return NO;
	}

	/* -_listOfExtensionsForInstallation: should only return nil on fatal errors.
	 It will not return nil for an extension folder that does not exist, or is empty. */
	NSArray *oldExtensions = [TPCResourceManager _listOfExtensionsForInstallation:installation];

	if (gcLocation == nil) {
		LogToConsoleError("Cannot remove group container contents because of nil extension list");

		return NO;
	}

	LogToConsole("Removing group container contents at URL: %{public}@", gcLocation.standardizedTildePath);

	BOOL result = [RZFileManager() removeContentsOfDirectoryAtURL:gcLocation
													excludingURLs:oldExtensions
														  options:(CSFileManagerOptionContinueOnError)];

	LogToConsole("End: Remove group container - Result: %{BOOL}d", result);

	return result;
}

#pragma mark -
#pragma mark Extension Pruning

+ (void)_pruneExtensionSymbolicLinksForInstallation:(TPCMigrateSandboxInstallation)installation
{
	/* When you create a copy of a bundle programmatically, macOS will move it to
	 quarantine. The user is then notified macOS can't verify that it isn't malware.
	 That is less than ideal when performing migration. */
	/* When migration is performed, we create a symbolic link to the original
	 extension instead of copying it to the new location. If the symbolic link
	 at the new location is replaced, then that extension is now just dangling
	 never to be used again. */
	/* TPCResourceManager will handle garbage collection. It will compare the
	 contents of the old location and new location each launch. If a symbolic
	 link is not present for an extension in the old location, that extension
	 is deleted. Once all extensions are deleted, a flag is set to stop pruning
	 so we don't keep scanning the old location forever. */
	LogToConsole("Start: Pruning extensions for '%{public}@'",
		[self _descriptionOfInstallation:installation]);

	NSArray *oldExtensions = [TPCResourceManager _listOfExtensionsForInstallation:installation];

	if (oldExtensions == nil) {
		/* Helper method will describe error. */

		return;
	}

	if (oldExtensions.count == 0) {
		LogToConsole("Source location for extensions to prune is empty");

		[self _setAllExtensionSymbolicLinksPruned];

		return;
	}

	NSURL *newLocation = [TPCPathInfo customExtensionsURL];

	if (newLocation == nil) {
		LogToConsoleError("Cannot prune extensions because of nil destination location");

		return;
	}

	NSUInteger numberPruned = 0;
	NSUInteger numberRemaining = 0;

	for (NSURL *oldExtension in oldExtensions) {
		NSString *name = [oldExtension resourceValueForKey:NSURLNameKey];
		
		NSNumber *isPackage = [oldExtension resourceValueForKey:NSURLIsPackageKey];

		if ([name hasSuffix:@".bundle"] == NO ||
			(isPackage == nil || isPackage.boolValue == NO))
		{
#ifdef DEBUG
			LogToConsoleDebug("Ignoring non-bundle: '%{public}@' - isPackage: %{BOOL}d", name, isPackage.boolValue);
#endif

			continue;
		}

		NSURL *newExtension = [newLocation URLByAppendingPathComponent:name];

		/* Should we check if the symbolic link points to this extension
		 and not some other random file on the operating system?
		 The likelihood of the user having a symbolic link they
		 created is near zero if not zero. This is already over engineered. */
		BOOL pruned = NO;

		if ([TPCResourceManager _URLIsSymbolicLink:newExtension] == NO) {
#ifdef DEBUG
			LogToConsoleDebug("Pruning URL: '%{public}@'", oldExtension.standardizedTildePath);
#endif

			NSError *deleteError = nil;

			pruned = [RZFileManager() removeItemAtURL:oldExtension error:&deleteError];

			if (deleteError) {
				LogToConsoleError("Failed to prune extension at URL ['%{public}@']: %{public}@",
					oldExtension.standardizedTildePath, deleteError.localizedDescription);
			}
		}

		if (pruned) {
			numberPruned += 1;
		} else {
			numberRemaining += 1;
		}
	} // Directory list for loop

	if (numberRemaining == 0) {
		[self _setAllExtensionSymbolicLinksPruned];
	}

	LogToConsole("End: Pruning extensions completed. "
				 "Number remaining: %{public}lu, Number pruned: %{public}lu",
		numberRemaining, numberPruned);
}

+ (void)_pruneExtensionSymbolicLinksFromDefaults
{
	BOOL doPrune = [RZUserDefaults() boolForKey:MigrationUserPrefersPruningDefaultsKey];

	if (doPrune == NO) {
		return; // Stop pruning
	}

	BOOL pruningExhausted = [RZUserDefaults() boolForKey:MigrationAllExtensionsPrunedDefaultsKey];

	if (pruningExhausted) {
		return; // Stop pruning
	}

	TPCMigrateSandboxInstallation installation = [RZUserDefaults() unsignedIntegerForKey:MigrationInstallationMigratedDefaultsKey];

	if ([self _isInstallationSupported:installation] == NO) {
		[self _setAllExtensionSymbolicLinksPruned];

		return; // Stop pruning
	}

	[self _pruneExtensionSymbolicLinksForInstallation:installation];
}

+ (void)_setAllExtensionSymbolicLinksPruned
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationAllExtensionsPrunedDefaultsKey];
}

#pragma mark -
#pragma mark Utilities

+ (NSString *)_descriptionOfInstallation:(TPCMigrateSandboxInstallation)installation
{
	/* This is used for logging so is not localized.
	 Localize is use changes. */
	switch (installation) {
		case TPCMigrateSandboxInstallationStandaloneClassic:
			return @"Standalone Classic";
		case TPCMigrateSandboxInstallationMacAppStore:
			return @"Mac App Store";
		default:
			return @"<Unknown Installation>";
	}
}

+ (nullable NSString *)_groupContainerIdentifierForInstallation:(TPCMigrateSandboxInstallation)installation
{
	switch (installation) {
		case TPCMigrateSandboxInstallationStandaloneClassic:
			return @"com.codeux.apps.textual";
		case TPCMigrateSandboxInstallationMacAppStore:
			return @"8482Q6EPL6.com.codeux.irc.textual";
		default:
			break;
	}

	return nil;
}

+ (nullable NSString *)_defaultsSuiteNameForInstallation:(TPCMigrateSandboxInstallation)installation
{
	switch (installation) {
		case TPCMigrateSandboxInstallationMacAppStore:
			return @"8482Q6EPL6.com.codeux.irc.textual";
		default:
			break;
	}

	return nil;
}

+ (BOOL)_isInstallationSupported:(TPCMigrateSandboxInstallation)installation
{
	return (installation == TPCMigrateSandboxInstallationStandaloneClassic ||
			installation == TPCMigrateSandboxInstallationMacAppStore);
}

@end

#pragma mark -
#pragma mark Resource Management

@implementation TPCResourceManager (TPCSandoxMigration)

+ (nullable NSArray<NSURL *> *)_listOfExtensionsForInstallation:(TPCMigrateSandboxInstallation)installation
{
	NSURL *oldLocation = [TPCPathInfo _groupContainerExtensionsURLForInstallation:installation];

	if (oldLocation == nil) {
		LogToConsoleError("Cannot list extensions because of nil source location");

		return nil;
	}

	if ([RZFileManager() fileExistsAtURL:oldLocation] == NO) {
		return @[];
	}

	NSError *listExtensionsError = nil;

	NSArray *oldExtensions = [RZFileManager() contentsOfDirectoryAtURL:oldLocation
											includingPropertiesForKeys:@[NSURLNameKey, NSURLIsPackageKey]
															   options:0
																 error:&listExtensionsError];

	if (listExtensionsError) {
		LogToConsoleError("Unable to list contents of extensions at URL ['%{public}@']: %{public}@",
			oldLocation.standardizedTildePath, listExtensionsError.localizedDescription);

		return nil;
	}

	return oldExtensions;
}

+ (BOOL)_ageOfCurrentContainerIsRecent
{
	NSURL *newLocation = [TPCPathInfo groupContainerURL];

	if (newLocation == NO) {
		return NO;
	}

	NSTimeInterval age = [self _intervalSinceCreatedForURL:newLocation];

	/* macOS will create the group container the first time
	 we ask for its path. If the group container wasn't created
	 recently, then we have no reason to perform migration to it.
	 In theory, this could probably be narrowed down further as
	 the interval should be sub-second. */
	return (age < 5.0);
}

+ (NSTimeInterval)_modificationDateForMacAppStorePreferencesIsRecent
{
	NSURL *location = [TPCPathInfo _groupContainerPreferencesURLForInstallation:TPCMigrateSandboxInstallationMacAppStore];

	if (location == nil) {
		return NO;
	}

	NSTimeInterval age = [self _intervalSinceLastModificationForURL:location];

	return (age >= 0 && age <= MaximumAgeOfStalePreferences);
}

+ (NSTimeInterval)_intervalSinceCreatedForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSError *error = nil;

	NSTimeInterval age = [url intervalSinceCreatedWithError:&error];

	if (error) {
		/* This is purposely considered debug information as the user knowing
		 a file not existing is not an error when that is probable outcome. */
		LogToConsoleDebug("Error caught when calculating age of file: %{public}@",
			error.localizedDescription);
	}

	return age;
}

+ (NSTimeInterval)_intervalSinceLastModificationForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSError *error = nil;

	NSTimeInterval age = [url intervalSinceLastModificationWithError:&error];

	if (error) {
		/* This is purposely considered debug information as the user knowing
		 a file not existing is not an error when that is probable outcome. */
		LogToConsoleDebug("Error caught when calculating age of file: %{public}@",
			error.localizedDescription);
	}

	return age;
}

+ (BOOL)_URLIsSymbolicLink:(NSURL *)url
{
	NSParameterAssert(url != nil);

	/* Skip check if file exists because no resource value
	 will be returned if that is the case. */
	NSNumber *isSymblink = [url resourceValueForKey:NSURLIsSymbolicLinkKey];

	return (isSymblink != nil && isSymblink.boolValue);
}

@end

#pragma mark -
#pragma mark Path Information

@implementation TPCPathInfo (TPCSandboxMigration)

+ (nullable NSURL *)_groupContainerURLForInstallation:(TPCMigrateSandboxInstallation)installation
{
	NSString *identifier = [TPCSandboxMigration _groupContainerIdentifierForInstallation:installation];

	if (identifier == nil) {
		return nil;
	}

	/* The reason we are not using -containerURLForSecurityApplicationGroupIdentifier: in this context is because
	 during testing, that method was returning ~/Library/Containers/com.codeux.apps.textual instead of the group
	 container location. I assume it's related to the fact the group identifier is same as the app's identifier.
	 This is not a make-or-break location in which hard coding will hurt it. */
	identifier = [NSString localizedStringWithFormat:@"/Library/Group Containers/%@/", identifier];

	NSURL *baseURL = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:identifier];

	return baseURL;
}

+ (nullable NSURL *)_groupContainerPreferencesURLForInstallation:(TPCMigrateSandboxInstallation)installation
{
	NSString *identifier = [TPCSandboxMigration _groupContainerIdentifierForInstallation:installation];

	if (identifier == nil) {
		return nil;
	}

	identifier = [NSString localizedStringWithFormat:@"/Library/Group Containers/%1$@/Library/Preferences/%1$@.plist", identifier];

	NSURL *baseURL = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:identifier];

	return baseURL;
}

+ (nullable NSURL *)_groupContainerExtensionsURLForInstallation:(TPCMigrateSandboxInstallation)installation
{
	NSURL *sourceURL = [self _groupContainerURLForInstallation:installation];

	if (sourceURL == nil) {
		return nil;
	}

	return [sourceURL URLByAppendingPathComponent:@"/Library/Application Support/Textual/Extensions/"];
}

@end

NS_ASSUME_NONNULL_END
