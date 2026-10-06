/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2020 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CSFileManagerRemoveItemResult) {
	CSFileManagerRemoveItemResultSuccess = 0,
	CSFileManagerRemoveItemResultError,
	CSFileManagerRemoveItemResultExcluded
};

@implementation NSFileManager (CSFileManagerHelper)

+ (NSString *)pathOfHomeDirectoryOutsideSandbox
{
	uid_t userId = getuid();

	struct passwd *pw = getpwuid(userId);

	return @(pw->pw_dir);
}

+ (NSURL *)URLOfHomeDirectoryOutsideSandbox
{
	return [NSURL fileURLWithPath:self.pathOfHomeDirectoryOutsideSandbox isDirectory:YES];
}

- (BOOL)fileExistsAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	return [self fileExistsAtPath:url.path];
}

- (BOOL)directoryExistsAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	return [self directoryExistsAtPath:url.path];
}

- (BOOL)directoryExistsAtPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	BOOL isDirectory = NO;

	BOOL existsResult = [self fileExistsAtPath:path isDirectory:&isDirectory];

	return (existsResult && isDirectory);
}

- (BOOL)lockItemAtPath:(NSString *)path error:(NSError **)error
{
	NSParameterAssert(path != nil);

	NSDictionary *newattrs = @{NSFileImmutable : @(YES)};

	return [self setAttributes:newattrs	ofItemAtPath:path error:error];
}

- (BOOL)unlockItemAtPath:(NSString *)path error:(NSError **)error
{
	NSParameterAssert(path != nil);

	NSDictionary *newattrs = @{NSFileImmutable : @(NO)};

	return [self setAttributes:newattrs	ofItemAtPath:path error:error];
}

- (NSArray<NSString *> *)buildPathArrayWithPaths:(NSArray<NSString *> *)paths
{
	NSParameterAssert(paths != nil);

	NSMutableArray<NSString *> *pathData = [NSMutableArray array];

	for (id pathObject in paths) {
		if ([pathObject isKindOfClass:[NSString class]] == NO) {
			continue;
		}

		if ([pathObject length] == 0) {
			continue;
		}

		BOOL isDirectory = NO;

		BOOL pathExists = [self fileExistsAtPath:pathObject isDirectory:&isDirectory];

		if (pathExists && isDirectory) {
			[pathData addObject:pathObject];
		}
	}

	return [pathData copy];
}

- (NSArray<NSString *> *)buildPathArray:(NSString *)path, ...
{
	NSParameterAssert(path != nil);

	NSMutableArray<NSString *> *pathObjects = [NSMutableArray array];

	if ( path) {
		[pathObjects addObject:path];
	}

	id pathObj = nil;

	va_list args;
	va_start(args, path);

	while ((pathObj = va_arg(args, id))) {
		[pathObjects addObject:pathObj];
	}

	va_end(args);

	return [self buildPathArrayWithPaths:pathObjects];
}

- (BOOL)replaceItemAtPath:(NSString *)destinationPath withItemAtPath:(NSString *)sourcePath
{
	return [self replaceItemAtPath:destinationPath
					withItemAtPath:sourcePath
						   options:(CSFileManagerOptionsMoveToTrash |
									CSFileManagerOptionsRemoveIfExists)];
}

- (BOOL)replaceItemAtPath:(NSString *)destinationPath
		   withItemAtPath:(NSString *)sourcePath
				  options:(CSFileManagerOptions)options
{
	if (sourcePath == nil || destinationPath == nil) {
		return NO;
	}

	return [self replaceItemAtURL:[NSURL fileURLWithPath:destinationPath]
					withItemAtURL:[NSURL fileURLWithPath:sourcePath]
						  options:options];
}

- (BOOL)replaceItemAtURL:(NSURL *)destinationURL withItemAtURL:(NSURL *)sourceURL
{
	return [self replaceItemAtURL:destinationURL
					withItemAtURL:sourceURL
						  options:(CSFileManagerOptionsMoveToTrash |
								   CSFileManagerOptionsRemoveIfExists)];
}

- (BOOL)replaceItemAtURL:(NSURL *)destinationURL
		   withItemAtURL:(NSURL *)sourceURL
				 options:(CSFileManagerOptions)options
{
	/* Check URLs */
	if (sourceURL == nil || sourceURL.fileURL == NO ||
		destinationURL == nil || destinationURL.fileURL == NO)
	{
		return NO;
	}

	BOOL moveToDestination = ((options & CSFileManagerOptionsMoveToDestination) == CSFileManagerOptionsMoveToDestination);
	BOOL moveDestinationToTrash = ((options & CSFileManagerOptionsMoveToTrash) == CSFileManagerOptionsMoveToTrash);
	BOOL removeIfExists = ((options & CSFileManagerOptionsRemoveIfExists) == CSFileManagerOptionsRemoveIfExists);

	/* Remove destination if it exists */
	if ([self fileExistsAtURL:destinationURL]) {
		if (removeIfExists == NO) {
			/* The method was purposely configured with the thought we wont
			 override files so it shouldn't be a failure if we follow that rule. */
			return YES;
		}

		NSError *removeFileError = nil;

		BOOL removeResult = NO;

		if (moveDestinationToTrash) {
			removeResult = [self trashItemAtURL:destinationURL resultingItemURL:NULL error:&removeFileError];
		} else {
			removeResult = [self removeItemAtURL:destinationURL error:&removeFileError];
		}

		if (removeResult == NO) {
			LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
				"Failed to remove file at destination: '%{public}@': %{public}@",
				[destinationURL standardizedTildePath], removeFileError.localizedDescription);
			LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

			return NO;
		}
	}

	/* Are we working with a symbolic link? */
	NSNumber *isSymlinkRef = [sourceURL resourceValueForKeyWithLoggedError:NSURLIsSymbolicLinkKey];

	if (isSymlinkRef == nil) {
		return NO;
	}

	BOOL createSymbolicLink = isSymlinkRef.boolValue;

	/* Do we want to create symbolic link for a package? */
	if (createSymbolicLink == NO) {
		if ((options & CSFileManagerCreateSymbolicLinkForPackages) == CSFileManagerCreateSymbolicLinkForPackages) {
			NSDictionary *resourceValues = [sourceURL resourceValuesForKeyWithLoggedError:@[NSURLIsApplicationKey, NSURLIsPackageKey]];

			createSymbolicLink = ([resourceValues boolForKey:NSURLIsApplicationKey] ||
								  [resourceValues boolForKey:NSURLIsPackageKey]);
		}
	}

	/* Perform replace operation */
	BOOL copyResult = NO;

	NSError *copyFileError = nil;

	if (createSymbolicLink) {
		NSURL *symlinkDestination = [sourceURL URLByResolvingSymlinksInPath];

		if (symlinkDestination == nil) {
			return NO;
		}

		copyResult = [self createSymbolicLinkAtURL:destinationURL withDestinationURL:symlinkDestination error:&copyFileError];
	} else if (moveToDestination) {
		copyResult = [self moveItemAtURL:sourceURL toURL:destinationURL error:&copyFileError];
	} else {
		copyResult = [self copyItemAtURL:sourceURL toURL:destinationURL error:&copyFileError];
	}

	if (copyResult == NO) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Failed to copy file to destination: '%{public}@' -> '%{public}@': %{public}@",
			sourceURL.standardizedTildePath, destinationURL.standardizedTildePath, copyFileError.localizedDescription);
		LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

		return NO;
	}

	/* Success */
	return YES;
}

- (BOOL)mergeDirectoryAtURL:(NSURL *)sourceURL withDirectoryAtURL:(NSURL *)destinationURL options:(CSFileManagerOptions)options
{
	return [self _mergeDirectoryAtURL:sourceURL withDirectoryAtURL:destinationURL options:options recursionDepth:0];
}

- (BOOL)_mergeDirectoryAtURL:(NSURL *)sourceURL withDirectoryAtURL:(NSURL *)destinationURL options:(CSFileManagerOptions)options recursionDepth:(NSUInteger)recursionDepth
{
	NSParameterAssert(sourceURL != nil);
	NSParameterAssert(destinationURL != nil);

	/* Check URLs */
	if (sourceURL.fileURL == NO || destinationURL.fileURL == NO) {
		return NO;
	}

	/* Determine the type of the current source URL.
	 Regardless of our depth, we must know if the source
	 is a file or directory. */
	NSDictionary *sourceURLResources = [sourceURL resourceValuesForKeyWithLoggedError:@[NSURLIsDirectoryKey,
																						NSURLIsRegularFileKey,
																						NSURLIsSymbolicLinkKey,
																						NSURLIsApplicationKey,
																						NSURLIsPackageKey]];

	if (sourceURLResources == nil) {
		return NO;
	}

	BOOL sourceIsDirectory = [sourceURLResources boolForKey:NSURLIsDirectoryKey];

	if (recursionDepth == 0 && sourceIsDirectory == NO) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Source URL is not directory when expected: '%{public}@'",
			sourceURL.standardizedTildePath);
		LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

		return NO;
	}

	BOOL sourceIsFile = [sourceURLResources boolForKey:NSURLIsRegularFileKey];
	BOOL sourceIsSymbolicLink = [sourceURLResources boolForKey:NSURLIsSymbolicLinkKey];
	BOOL sourceIsApplication = [sourceURLResources boolForKey:NSURLIsApplicationKey];
	BOOL sourceIsPackage = [sourceURLResources boolForKey:NSURLIsPackageKey];

	if (sourceIsDirectory == NO &&
		sourceIsFile == NO &&
		sourceIsSymbolicLink == NO &&
		sourceIsApplication == NO &&
		sourceIsPackage == NO)
	{
		LogToConsoleFaultWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Source URL is of type not supported by this library and will be ignored: %{public}@",
			sourceURL.standardizedTildePath);

		return NO;
	}

#ifdef DEBUG
	LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
		"'%{public}@': dir=%{BOOL}d, file=%{BOOL}d, symblink=%{BOOL}d, app=%{BOOL}d, pkg=%{BOOL}d",
		sourceURL.standardizedTildePath, sourceIsDirectory, sourceIsFile,
		sourceIsSymbolicLink, sourceIsApplication, sourceIsPackage);
#endif

	/* Destination URL must be a directory for top level depth. */
	if (recursionDepth == 0) {
		/* We are not concerned at this point if the destination exists,
		 if there are any errors returned retrieving its resources
		 (such as when it doesn't exist), or any other conditions.
		 Just fail if there is probability it's not a directory. */
		NSNumber *destinationIsDirectoryRef = [destinationURL resourceValueForKey:NSURLIsDirectoryKey];

		if ((destinationIsDirectoryRef != nil &&
			 destinationIsDirectoryRef.boolValue == NO) ||
			destinationURL.hasDirectoryPath == NO)
		{
			LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
				"Destination URL is not directory when expected: '%{public}@'",
				destinationURL.standardizedTildePath);
			LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

			return NO;
		}
	}

	/* Perform merge */
	BOOL enumerateDirectories = ((options & CSFileManagerOptionsEnumerateDirectories) == CSFileManagerOptionsEnumerateDirectories);

	/* If the recursion depth is above zero (the root directory) and
	 we are not interested in merging individual files, then simply
	 call out to replace the item. We do not care about the depth
	 beyond this scope. */
	if (recursionDepth > 0 && enumerateDirectories == NO) {
		return [self replaceItemAtURL:destinationURL withItemAtURL:sourceURL options:options];
	}

	/* If this is not a directory, then perform merge. */
	/* Applications and packages are not considered directories despite the
	 fact they are because they are usually considered self contained entities. */
	if (sourceIsFile || sourceIsSymbolicLink || sourceIsApplication || sourceIsPackage) {
		return [self replaceItemAtURL:destinationURL withItemAtURL:sourceURL options:options];
	}

	/* Create parent directory? */
	BOOL createDirectory = ((options & CSFileManagerOptionsCreateDirectory) == CSFileManagerOptionsCreateDirectory);

	if (createDirectory) {
		NSError *createError = nil;

		if ([self createDirectoryAtURL:destinationURL withIntermediateDirectories:YES attributes:nil error:&createError] == NO) {
			LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
				"Failed to create destination: '%{public}@': %{public}@",
				destinationURL.standardizedTildePath, createError.localizedDescription);
			LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

			return NO;
		}
	}

	/* List directory contents and begin recursion. */
	NSError *directoryContentsError = nil;

	NSArray *directoryContents = [self contentsOfDirectoryAtURL:sourceURL
									 includingPropertiesForKeys:@[NSURLNameKey,
																  NSURLIsDirectoryKey,
																  NSURLIsRegularFileKey,
																  NSURLIsSymbolicLinkKey,
																  NSURLIsApplicationKey,
																  NSURLIsPackageKey]
														options:0
														  error:&directoryContentsError];

	if (directoryContents == nil) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"directoryContents returned nil: '%{public}@': %{public}@",
			sourceURL.standardizedTildePath, directoryContentsError.localizedDescription);
		LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

		return NO;
	}

	/* Merge directory contents */
	BOOL continueOnError = ((options & CSFileManagerOptionContinueOnError) == CSFileManagerOptionContinueOnError);
	BOOL allowDotFiles = ((options & CSFileManagerOptionsIncludeDotFiles) == CSFileManagerOptionsIncludeDotFiles);

	for (NSURL *sourceItem in directoryContents) {
		NSString *filename = sourceItem.lastPathComponent;

		if (allowDotFiles == NO && [filename hasPrefix:@"."]) {
			continue;
		}

		NSURL *destinationItem = [destinationURL URLByAppendingPathComponent:filename];

		if ([self _mergeDirectoryAtURL:sourceItem
					withDirectoryAtURL:destinationItem
							   options:options
						recursionDepth:(recursionDepth + 1)] == NO) {
			if (continueOnError) {
				continue;
			}

			return NO;
		}
	}

	/* Success */
	return YES;
}

- (BOOL)removeContentsOfDirectoryAtURL:(NSURL *)url options:(CSFileManagerOptions)options
{
	return [self removeContentsOfDirectoryAtURL:url excludingURLs:nil options:options];
}

- (BOOL)removeContentsOfDirectoryAtURL:(NSURL *)url excludingURLs:(nullable NSArray<NSURL *> *)excludedURLs options:(CSFileManagerOptions)options
{
	CSFileManagerRemoveItemResult result =
	[self _removeContentsOfDirectoryAtURL:url 
							excludingURLs:excludedURLs
								  options:options
						   recursionDepth:0];

	return (result == CSFileManagerRemoveItemResultSuccess ||
			result == CSFileManagerRemoveItemResultExcluded);
}

- (CSFileManagerRemoveItemResult)_removeContentsOfDirectoryAtURL:(NSURL *)url excludingURLs:(nullable NSArray<NSURL *> *)excludedURLs options:(CSFileManagerOptions)options recursionDepth:(NSUInteger)recursionDepth
{
	NSParameterAssert(url != nil);

	/* Check URLs */
	if (url.fileURL == NO) {
		return CSFileManagerRemoveItemResultError;
	}
	
	/* Check for exclusion. Depth doesn't matter here.
	 If user wants to exclude the source URL who are we
	 to really care? */
	if (excludedURLs && [excludedURLs containsObject:url]) {
#ifdef DEBUG
		LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"URL is excluded: %{public}@", url.standardizedTildePath);
#endif

		return CSFileManagerRemoveItemResultExcluded;
	}

	/* Determine the type of the current source URL.
	 Regardless of our depth, we must know if the source
	 is a file or directory. */
	NSDictionary *resourceKeys = [url resourceValuesForKeyWithLoggedError:@[NSURLIsDirectoryKey,
																				  NSURLIsRegularFileKey,
																				  NSURLIsSymbolicLinkKey,
																				  NSURLIsApplicationKey,
																				  NSURLIsPackageKey]];

	if (resourceKeys == nil) {
		return CSFileManagerRemoveItemResultError;
	}

	BOOL sourceIsDirectory = [resourceKeys boolForKey:NSURLIsDirectoryKey];

	if (recursionDepth == 0 && sourceIsDirectory == NO) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Source URL is not directory when expected: '%{public}@'",
			url.standardizedTildePath);
		LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

		return CSFileManagerRemoveItemResultError;
	}

	BOOL sourceIsApplication = [resourceKeys boolForKey:NSURLIsApplicationKey];
	BOOL sourceIsPackage = [resourceKeys boolForKey:NSURLIsPackageKey];

#ifdef DEBUG
	BOOL sourceIsFile = [resourceKeys boolForKey:NSURLIsRegularFileKey];
	BOOL sourceIsSymbolicLink = [resourceKeys boolForKey:NSURLIsSymbolicLinkKey];

	LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
		"'%{public}@': dir=%{BOOL}d, file=%{BOOL}d, symblink=%{BOOL}d, app=%{BOOL}d, pkg=%{BOOL}d",
		url.standardizedTildePath, sourceIsDirectory, sourceIsFile,
		sourceIsSymbolicLink, sourceIsApplication, sourceIsPackage);
#endif

	/* For regular directories, list its contents.
	 Perform remove on individual files using recursion.
	 If a child is flagged as excluded, or for some reason it could not
	 be removed, then we set performRemoved to NO to exclude attempting
	 to delete the parent directory. */
	BOOL performRemove = (recursionDepth > 0); // Don't delete root

	if (sourceIsDirectory && sourceIsApplication == NO && sourceIsPackage == NO) {
		NSError *directoryContentsError = nil;

		NSArray *directoryContents = [self contentsOfDirectoryAtURL:url
										 includingPropertiesForKeys:@[NSURLNameKey,
																	  NSURLIsDirectoryKey,
																	  NSURLIsRegularFileKey,
																	  NSURLIsSymbolicLinkKey,
																	  NSURLIsApplicationKey,
																	  NSURLIsPackageKey]
															options:0
															  error:&directoryContentsError];

		if (directoryContents == nil) {
			LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
				"directoryContents returned nil: '%{public}@': %{public}@",
				url.standardizedTildePath, directoryContentsError.localizedDescription);
			LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

			return CSFileManagerRemoveItemResultError;
		}

		/* Trash directory contents */
		BOOL continueOnError = ((options & CSFileManagerOptionContinueOnError) == CSFileManagerOptionContinueOnError);

		for (NSURL *item in directoryContents) {
			CSFileManagerRemoveItemResult result =
			[self _removeContentsOfDirectoryAtURL:item
									excludingURLs:excludedURLs
										  options:options
								   recursionDepth:(recursionDepth + 1)];

			if (result == CSFileManagerRemoveItemResultError) {
				if (continueOnError == NO) {
					return CSFileManagerRemoveItemResultError;
				}

				performRemove = NO;
			} else if (result == CSFileManagerRemoveItemResultExcluded) {
				performRemove = NO;
			}
		}
	} // sourceIsDirectory

	/* Perform remove */
	if (performRemove == NO) {
#ifdef DEBUG
		LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Skipping remove for URL: %{public}@", url.standardizedTildePath);
#endif

		return CSFileManagerRemoveItemResultExcluded;
	}

#ifdef DEBUG
	LogToConsoleDebugWithSubsystem(_CSFrameworkInternalLogSubsystem(),
		"Removing URL: %{public}@", url.standardizedTildePath);
#endif

	NSError *removeError = nil;

	BOOL removeResult = NO;

	BOOL moveToTrash = ((options & CSFileManagerOptionsMoveToTrash) == CSFileManagerOptionsMoveToTrash);

	if (moveToTrash) {
		removeResult = [self trashItemAtURL:url resultingItemURL:nil error:&removeError];
	} else {
		removeResult = [self removeItemAtURL:url error:&removeError];
	}

	if (removeError) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Failed to remove item to trash: '%{public}@': %{public}@",
			url.standardizedTildePath, removeError.localizedDescription);
		LogStackTraceWithSubsystem(_CSFrameworkInternalLogSubsystem());

		return CSFileManagerRemoveItemResultError;
	}

	/* Success */
	return CSFileManagerRemoveItemResultSuccess;
}

@end

NS_ASSUME_NONNULL_END
