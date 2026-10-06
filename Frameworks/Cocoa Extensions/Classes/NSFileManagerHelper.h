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

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, CSFileManagerOptions) {
	/* If file or directory exists at destination, remove it. */
	/* For a directory, the entire directly is removed. */
	CSFileManagerOptionsRemoveIfExists		= 1 << 1,

	/* During a merge, if an item is a directory, enumerate its contents
	 and merge those individually. Instead of the directory as a whole. */
	/* At all times, even with this flag enabled, applications and packages
	 will be merged in whole as they are considered self contained. */
	CSFileManagerOptionsEnumerateDirectories		= 1 << 2,

	/* When enumerating directories, create the directory at the destination
	 if it does not already exist. */
	CSFileManagerOptionsCreateDirectory				= 1 << 3,

	/* When migrating the contents of a directory, the migration does not
	 stop if an error occurs on an individual file. */
	CSFileManagerOptionContinueOnError				= 1 << 4,

	/* When removing a file or directory, move it to Trash?
	 If not, just outright delete. */
	CSFileManagerOptionsMoveToTrash			= 1 << 5,

	/* When merging, move source to destination.
	 If not specified, copy is perform instead. */
	CSFileManagerOptionsMoveToDestination	= 1 << 6,

	/* Dot files (e.g. .DS_Store) are ignored by default
	 when migrating. Set flag to include. */
	CSFileManagerOptionsIncludeDotFiles 	= 1 << 7,

	/* Copying or moving an application, bundle, or other
	 packaged executable while inside a sandbox will add
	 the destination to quarantine. Create symbolic link
	 to the source instead of creating copy. */
	CSFileManagerCreateSymbolicLinkForPackages	= 1 << 8,
};

@interface NSFileManager (CSFileManagerHelper)
@property (class, nonatomic, copy, readonly) NSString *pathOfHomeDirectoryOutsideSandbox;
@property (class, nonatomic, copy, readonly) NSURL *URLOfHomeDirectoryOutsideSandbox;

- (BOOL)fileExistsAtURL:(NSURL *)url;

- (BOOL)directoryExistsAtURL:(NSURL *)url;
- (BOOL)directoryExistsAtPath:(NSString *)path;

- (BOOL)lockItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)unlockItemAtPath:(NSString *)path error:(NSError **)error;

- (NSArray<NSString *> *)buildPathArray:(NSString *)path, ...;

/* Trash the individual items inside a directory instead of the directory itself. */
/* Only options supported: CSFileManagerOptionContinueOnError, CSFileManagerOptionsMoveToTrash */
- (BOOL)removeContentsOfDirectoryAtURL:(NSURL *)url options:(CSFileManagerOptions)options;
- (BOOL)removeContentsOfDirectoryAtURL:(NSURL *)url excludingURLs:(nullable NSArray<NSURL *> *)excludedURLs options:(CSFileManagerOptions)options;

/* Recursively merge two directories using options. */
- (BOOL)mergeDirectoryAtURL:(NSURL *)sourceURL withDirectoryAtURL:(NSURL *)destinationURL options:(CSFileManagerOptions)options;

// The following methods default to moving destination to trash + copying source
- (BOOL)replaceItemAtPath:(NSString *)destinationPath
		   withItemAtPath:(NSString *)sourcePath;

- (BOOL)replaceItemAtURL:(NSURL *)destinationURL
		   withItemAtURL:(NSURL *)sourceURL;

- (BOOL)replaceItemAtPath:(NSString *)destinationPath
		   withItemAtPath:(NSString *)sourcePath
				  options:(CSFileManagerOptions)options;

- (BOOL)replaceItemAtURL:(NSURL *)destinationURL
		   withItemAtURL:(NSURL *)sourceURL
				 options:(CSFileManagerOptions)options;
@end

NS_ASSUME_NONNULL_END
