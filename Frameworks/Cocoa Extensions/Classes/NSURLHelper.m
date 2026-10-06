/* *********************************************************************
 *
 *         Copyright (c) 2016 - 2020 Codeux Software, LLC
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

@implementation NSURL (CSURLHelper)

- (nullable id)resourceValueForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	return [self resourceValueForKey:key error:nil];
}

- (nullable id)resourceValueForKeyWithLoggedError:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSError *error = nil;

	id resourceValue = [self resourceValueForKey:key error:&error];

	if (error) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Resource value [%{public}@] could not be accessed for URL [%{public}@]: %{public}@",
				 key, self.standardizedTildePath, error.localizedDescription);
	}

	return resourceValue;
}

- (nullable NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeyWithLoggedError:(NSArray<NSURLResourceKey> *)keys
{
	NSParameterAssert(keys != nil);

	NSError *error = nil;

	id resourceValues = [self resourceValuesForKeys:keys error:&error];

	if (error) {
		LogToConsoleErrorWithSubsystem(_CSFrameworkInternalLogSubsystem(),
			"Resource values [%{public}@] could not be accessed for URL [%{public}@]: %{public}@",
				[keys componentsJoinedByString:@", "], self.standardizedTildePath, error.localizedDescription);
	}

	return resourceValues;
}

- (nullable id)resourceValueForKey:(NSString *)key error:(NSError * _Nullable * _Nullable)error
{
	NSParameterAssert(key != nil);

	id resourceValue = nil;

	if ([self getResourceValue:&resourceValue forKey:key error:error] == NO) {
		return nil;
	}

	return resourceValue;
}

- (nullable NSString *)filesystemRepresentationString
{
	if (self.isFileURL == NO) {
		return nil;
	}

	const char *cstring = self.fileSystemRepresentation;

	return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:cstring length:strlen(cstring)];
}

- (BOOL)isEqualByFileRepresentation:(NSURL *)url
{
	NSParameterAssert(url != nil);
	NSParameterAssert(url.isFileURL);

	const char *left = self.fileSystemRepresentation;
	const char *right = url.fileSystemRepresentation;

	return (strcmp(left, right) == 0);
}

- (BOOL)isEqualByResourceIdentifier:(NSURL *)url
{
	NSParameterAssert(url != nil);
	NSParameterAssert(url.isFileURL);

	id left = [self resourceValueForKey:NSURLFileResourceIdentifierKey];
	id right = [self resourceValueForKey:NSURLFileResourceIdentifierKey];

	return NSObjectsAreEqual(left, right);
}

- (NSTimeInterval)intervalSinceCreated
{
	return [self intervalSinceCreatedWithError:nil];
}

- (NSTimeInterval)intervalSinceCreatedWithError:(NSError * _Nullable * _Nullable)error
{
	NSDate *modificationDate = [self resourceValueForKey:NSURLCreationDateKey error:error];

	if (modificationDate == nil) {
		modificationDate = [NSDate distantFuture];
	}

	return -([modificationDate timeIntervalSinceNow]);
}

- (NSTimeInterval)intervalSinceLastModification
{
	return [self intervalSinceLastModificationWithError:nil];
}

- (NSTimeInterval)intervalSinceLastModificationWithError:(NSError * _Nullable * _Nullable)error
{
	NSDate *modificationDate = [self resourceValueForKey:NSURLContentModificationDateKey error:error];

	if (modificationDate == nil) {
		modificationDate = [NSDate distantFuture];
	}

	return -([modificationDate timeIntervalSinceNow]);
}

- (nullable NSString *)standardizedTildePath
{
	if (self.fileURL == NO) {
		return nil;
	}

	return self.path.standardizedTildePath;
}

@end

#pragma mark -

@implementation NSArray (CSURLHelper)

+ (NSArray<NSString *> *)pathsArrayForFileURLs:(NSArray<NSURL *> *)fileURLs
{
	return [self pathsArrayForFileURLs:fileURLs standardizingPaths:YES];
}

+ (NSArray<NSString *> *)pathsArrayForFileURLs:(NSArray<NSURL *> *)fileURLs standardizingPaths:(BOOL)standardizingPaths
{
	NSParameterAssert(fileURLs != nil);

	return [fileURLs arrayByApplyingBlock:^NSString *(NSURL *urlIn, NSUInteger index, BOOL *stop) {
		NSAssert(urlIn.isFileURL, @"URL '%@' is not a file", urlIn.standardizedTildePath);

		NSURL *urlOut = urlIn;

		if (standardizingPaths) {
			urlOut = urlOut.URLByStandardizingPath;
		}

		return urlOut.path;
	}];
}

@end

NS_ASSUME_NONNULL_END
