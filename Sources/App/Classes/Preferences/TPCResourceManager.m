/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TLOLocalization.h"
#import "TPCResourceManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TPCResourceManagerBundleDocumentTypeExtension					= @".bundle";
NSString * const TPCResourceManagerBundleDocumentTypeExtensionWithoutPeriod		= @"bundle";

NSString * const TPCResourceManagerScriptDocumentTypeExtension					= @".scpt";
NSString * const TPCResourceManagerScriptDocumentTypeExtensionWithoutPeriod		= @"scpt";

@implementation TPCResourceManager

+ (void)copyResourcesToApplicationSupportFolder
{
	/* Add a system link for the unsupervised scripts folder if it exists. */
	NSString *sourcePath = [TPCPathInfo customScripts];

	NSString *destinationPath = [[TPCPathInfo groupContainerApplicationSupport] stringByAppendingPathComponent:@"/Custom Scripts/"];

	if ([RZFileManager() fileExistsAtPath:sourcePath] &&
		[RZFileManager() fileExistsAtPath:destinationPath] == NO)
	{
		[RZFileManager() createSymbolicLinkAtPath:destinationPath withDestinationPath:sourcePath error:NULL];
	}
}

+ (NSCache *)sharedResourcesCache
{
	static NSCache *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cachedValue = [NSCache new];
	});

	return cachedValue;
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name
{
	return [self dictionaryFromResources:name inDirectory:nil key:nil cacheValue:YES];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath
{
	return [self dictionaryFromResources:name inDirectory:subpath key:nil cacheValue:YES];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath cacheValue:(BOOL)cacheValue
{
	return [self dictionaryFromResources:name inDirectory:subpath key:nil cacheValue:cacheValue];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name cacheValue:(BOOL)cacheValue
{
	return [self dictionaryFromResources:name inDirectory:nil key:nil cacheValue:cacheValue];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name key:(nullable NSString *)key
{
	return [self dictionaryFromResources:name inDirectory:nil key:key cacheValue:YES];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name key:(nullable NSString *)key cacheValue:(BOOL)cacheValue
{
	return [self dictionaryFromResources:name inDirectory:nil key:key cacheValue:cacheValue];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key
{
	return [self dictionaryFromResources:name inDirectory:subpath key:key cacheValue:YES];
}

+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key cacheValue:(BOOL)cacheValue
{
	return [self objectFromResources:name inDirectory:subpath key:key kindOf:[NSDictionary class] cacheValue:cacheValue];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name
{
	return [self arrayFromResources:name inDirectory:nil key:nil cacheValue:YES];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath
{
	return [self arrayFromResources:name inDirectory:subpath key:nil cacheValue:YES];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath cacheValue:(BOOL)cacheValue
{
	return [self arrayFromResources:name inDirectory:subpath key:nil cacheValue:cacheValue];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name cacheValue:(BOOL)cacheValue
{
	return [self arrayFromResources:name inDirectory:nil key:nil cacheValue:cacheValue];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name key:(nullable NSString *)key
{
	return [self arrayFromResources:name inDirectory:nil key:key cacheValue:YES];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name key:(nullable NSString *)key cacheValue:(BOOL)cacheValue
{
	return [self arrayFromResources:name inDirectory:nil key:key cacheValue:cacheValue];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key
{
	return [self arrayFromResources:name inDirectory:subpath key:key cacheValue:YES];
}

+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key cacheValue:(BOOL)cacheValue
{
	return [self objectFromResources:name inDirectory:subpath key:key kindOf:[NSArray class] cacheValue:cacheValue];
}

+ (nullable id)objectFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key kindOf:(Class)class cacheValue:(BOOL)cacheValue
{
	NSParameterAssert(name != nil);

	/* Bypass cache? */
	if (cacheValue == NO) {
		return [self _objectFromResources:name inDirectory:subpath key:key kindOf:class];
	}

	/* Cache hit? */
	NSString *cacheKey = [NSString stringWithFormat:@"%@.plist / %@ / %@",
		name, ((subpath) ?: @"Root Folder"), ((key) ?: @"Root Object")];

	NSCache *cache = self.sharedResourcesCache;

	id cachedValue = [cache objectForKey:cacheKey];

	if (cachedValue) {
		return cachedValue;
	}

	/* No cache hit, generate */
	cachedValue = [self _objectFromResources:name inDirectory:subpath key:key kindOf:class];

	if (cachedValue) {
		[cache setObject:cachedValue forKey:cacheKey];
	}

	return cachedValue;
}

+ (nullable id)_objectFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key kindOf:(Class)class
{
	/* Locate resource */
	NSURL *resourceURL = [RZMainBundle() URLForResource:name withExtension:@"plist" subdirectory:subpath];

	if (resourceURL == nil) {
		LogToConsoleError("Resource '%{public}@' in subpath '%{public}@' was not found.",
			name, ((subpath) ?: @"<No subpath>"));

		return nil;
	}

	/* Read resource */
	NSError *readError = nil;

	NSData *fileContents = [NSData dataWithContentsOfURL:resourceURL options:0 error:&readError];

	if (readError) {
		LogToConsoleError("Resource '%{public}@' could not be read with error: %{public}@",
			resourceURL.standardizedTildePath, readError.localizedDescription);

		return nil;
	}

	/* Process as a property list */
	NSError *parseError = nil;

	id propertyList =
	[NSPropertyListSerialization propertyListWithData:fileContents
											  options:NSPropertyListImmutable
											   format:NULL
												error:&parseError];

	if (parseError) {
		LogToConsoleFault("Resource '%{public}@' could not be parsed as a property list with error: %{public}@",
			resourceURL.standardizedTildePath, parseError.localizedDescription);

		return nil;
	}

	/* Locate object */
	/* Until we know otherwise, the value is the root object. */
	id objectValue = nil;

	if (key == nil) {
		objectValue = propertyList;
	} else {
		/* Property list can be an array. */
		if ([propertyList isKindOfClass:[NSDictionary class]] == NO) {
			LogToConsoleError("Contents of resource '%{public}@' is not a dictionary. "
							  "Cannot locate value of 'key' in other formats.",
							  resourceURL.standardizedTildePath);

			return nil;
		}

		objectValue = [propertyList objectForKey:key];
	}

	if ([objectValue isKindOfClass:class] == NO) {
		LogToConsoleError("Contents of key '%{public}@' in resource '%{public}@' is not kind of class: %{public}@",
			((key) ?: @"<Root Object>"), resourceURL.standardizedTildePath, NSStringFromClass(class));

		return nil;
	}

	return objectValue;
}

@end

#pragma mark -

@implementation TPCResourceManagerDocumentTypeImporter

+ (BOOL)autosavesInPlace
{
	/* We are read-only. This suppresses a warning in console. */
	return YES;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	NSString *filePath = url.filePathURL.absoluteString;

	if ([filePath hasSuffix:TPCResourceManagerScriptDocumentTypeExtension]) {
		[self performImportOfScriptFile:url];

		return YES;
	}

	NSString *pluginSuffix = [TPCResourceManagerBundleDocumentTypeExtension stringByAppendingString:@"/"];

	if ([filePath hasSuffix:pluginSuffix]) {
		[self performImportOfPluginFile:url];

		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Custom Plugin Files

- (void)performImportOfPluginFile:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *filename = url.lastPathComponent;

	BOOL performInstall = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[6tj-yp]")
													title:TXTLS(@"Prompts[xfl-8e]", filename)
											defaultButton:TXTLS(@"Prompts[mvh-ms]")
										  alternateButton:TXTLS(@"Prompts[99q-gg]")];

	if (performInstall == NO) {
		return;
	}

	NSURL *newPath = [[TPCPathInfo customExtensionsURL] URLByAppendingPathComponent:filename];

	BOOL didImport = [self import:url into:newPath];

	if (didImport) {
		NSString *filenameWithoutExtension = filename.stringByDeletingPathExtension;

		[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[k69-q0]")
								  title:TXTLS(@"Prompts[xek-0t]", filenameWithoutExtension)
						  defaultButton:TXTLS(@"Prompts[c7s-dq]")
						alternateButton:nil];
	}
}

#pragma mark -
#pragma mark Custom Script Files

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
	NSString *scriptsPath = [TPCPathInfo customScripts];

	if ([url.path hasPrefix:scriptsPath] == NO) {
		if (outError) {
			NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];

			userInfo[NSURLErrorKey] = url;

			userInfo[NSLocalizedDescriptionKey] = TXTLS(@"Prompts[m2r-gv]");
			userInfo[NSLocalizedRecoverySuggestionErrorKey] = TXTLS(@"Prompts[ztu-nv]");

			*outError = [NSError errorWithDomain:TXErrorDomain code:27984 userInfo:userInfo];
		}

		return NO;
	}

	return YES;
}

- (void)performImportOfScriptFile:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *filename = url.lastPathComponent;

	/* Ask user before installing. */
	BOOL performInstall = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[6tj-yp]")
													title:TXTLS(@"Prompts[xfl-8e]", filename)
											defaultButton:TXTLS(@"Prompts[mvh-ms]")
										  alternateButton:TXTLS(@"Prompts[99q-gg]")];

	if (performInstall == NO) {
		return; // Do not install.
	}

	NSURL *folderRep = [TPCPathInfo customScriptsURL];

	if ([RZFileManager() fileExistsAtURL:folderRep] == NO) {
		folderRep = [TPCPathInfo userApplicationScriptsURL];
	}

	NSString *bundleID = [TPCApplicationInfo applicationBundleIdentifier];

	NSSavePanel *d = [NSSavePanel savePanel];

	d.delegate = (id)self;

	d.canCreateDirectories = YES;

	d.directoryURL = folderRep;

	d.title = TXTLS(@"Prompts[6hx-ni]");

	d.message = TXTLS(@"Prompts[0bj-ic]", bundleID);

	d.nameFieldStringValue = url.lastPathComponent;

	d.showsTagField = NO;

	[d beginWithCompletionHandler:^(NSInteger returnCode) {
		if (returnCode == NSModalResponseOK) {
			if ([self import:url into:d.URL] == NO) {
				return;
			}

			NSString *filename = d.URL.lastPathComponent;

			XRPerformBlockAsynchronouslyOnMainQueue(^{
				[self performImportOfScriptFilePostflight:filename];
			});
		}
	}];
}

- (void)performImportOfScriptFilePostflight:(NSString *)filename
{
	NSParameterAssert(filename != nil);

	NSString *filenameWithoutExtension = filename.stringByDeletingPathExtension;

	[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[3ze-xh]", filenameWithoutExtension)
							  title:TXTLS(@"Prompts[4ua-v5]", filenameWithoutExtension)
					  defaultButton:TXTLS(@"Prompts[c7s-dq]")
					alternateButton:nil];
}

#pragma mark -
#pragma mark General Import Controller

- (BOOL)import:(NSURL *)url into:(NSURL *)destination
{
	return [RZFileManager() replaceItemAtURL:destination
							   withItemAtURL:url
									 options:(CSFileManagerOptionsMoveToTrash |
											  CSFileManagerOptionsRemoveIfExists)];
}

@end

NS_ASSUME_NONNULL_END
