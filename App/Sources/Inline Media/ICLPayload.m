/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2020 Codeux Software, LLC & respective contributors.
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
#import "TPCPathInfoPrivate.h"
#import "TPCThemeController.h"
#import "ICLPayloadPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICLPayload ()
{
@protected
	NSURL *_urlToInline;
	unsigned long long _contentLength;
	NSSize _contentSize;
	NSArray<NSURL *> *_styleResources;
	NSArray<NSURL *> *_scriptResources;
	NSString *_html;
	NSString *_entrypoint;
	NSDictionary<NSString *, id <NSCopying>> *_entrypointPayload;
	NSString *_classAttribute;

@private
	NSURL *_url;
	NSString *_lineNumber;
	NSString *_uniqueIdentifier;
	NSString *_viewIdentifier;
	NSUInteger _index;
	NSURLSession *_session;
}

@end

@implementation ICLPayload

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initOnMutate
{
	if ((self = [super initOnMutate])) {
		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}

- (instancetype)initWithURL:(NSURL *)url
	   withUniqueIdentifier:(NSString *)uniqueIdentifier
			   atLineNumber:(NSString *)lineNumber
					  index:(NSUInteger)index
					 inView:(NSString *)viewIdentifier
					session:(NSURLSession *)session
{
	NSParameterAssert(url != nil);
	NSParameterAssert(session != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(viewIdentifier != nil);

	if ((self = [super init])) {
		self->_url = [url copy];
		self->_lineNumber = [lineNumber copy];
		self->_index = index;
		self->_uniqueIdentifier = [uniqueIdentifier copy];
		self->_viewIdentifier = [viewIdentifier copy];
		self->_session = session;

		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}

- (instancetype)initWithDeferredPayload:(ICLPayload *)payload
{
	NSParameterAssert(payload != nil);

	if ((self = [super init])) {
		/* All values are immutable which means we
		 don't need to copy their contents. */
		self->_url = payload.url;
		self->_urlToInline = payload.urlToInline;
		self->_lineNumber = payload.lineNumber;
		self->_index = payload.index;
		self->_uniqueIdentifier = payload.uniqueIdentifier;
		self->_viewIdentifier = payload.viewIdentifier;
		self->_session = payload.session;
		self->_classAttribute = payload.classAttribute;

		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy == NO) {
		self->_contentSize = NSZeroSize;
	}

	SetVariableIfNil(self->_urlToInline, self->_url);
	SetVariableIfNil(self->_styleResources, @[]);
	SetVariableIfNil(self->_scriptResources, @[]);
	SetVariableIfNil(self->_html, @"");
	SetVariableIfNil(self->_classAttribute, @"");
}

- (void)initializedClassHealthCheck
{
	NSParameterAssert(self->_html != nil);
	NSParameterAssert(self->_url != nil);
	NSParameterAssert(self->_urlToInline != nil);
	NSParameterAssert(self->_lineNumber != nil);
	NSParameterAssert(self->_uniqueIdentifier != nil);
	NSParameterAssert(self->_viewIdentifier != nil);
	NSParameterAssert(self->_classAttribute != nil);
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	ICLPayload *object = [self allocForCopyAsMutable:mutableCopy];

	object->_contentLength = self->_contentLength;
	object->_contentSize = self->_contentSize;

	object->_styleResources = self->_styleResources;
	object->_scriptResources = self->_scriptResources;

	object->_html = self->_html;

	object->_entrypoint = self->_entrypoint;
	object->_entrypointPayload = self->_entrypointPayload;

	object->_url = self->_url;
	object->_urlToInline = self->_urlToInline;

	object->_lineNumber = self->_lineNumber;

	object->_uniqueIdentifier = self->_uniqueIdentifier;
	object->_viewIdentifier = self->_viewIdentifier;
	object->_session = self->_session;

	object->_index = self->_index;

	object->_classAttribute = self->_classAttribute;

	return [object initOnCopy];
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [ICLPayloadMutable self];
}

- (NSDictionary<NSString *, id<NSCopying>> *)entrypointPayload
{
	NSDictionary *payload = self->_entrypointPayload;

	if (payload == nil) {
		return [self entrypointPayloadDefaultContext];
	}

	return payload;
}

- (NSDictionary<NSString *, id<NSCopying>> *)entrypointPayloadDefaultContext
{
	return @{
		@"class" : self->_classAttribute,
		@"html" : self->_html,
		@"url" : self->_url,
		@"urlToInline" : self->_urlToInline,
		@"lineNumber" : self->_lineNumber,
		@"uniqueIdentifier" : self->_uniqueIdentifier
	};
}

- (void)entrypointPayloadSetContext
{
	/* Set context to payload that module sets. */
	/* The values set in the context don't change so we
	 are safe setting and forgetting. */
	NSDictionary *payload = self->_entrypointPayload;

	if (payload == nil) {
		return;
	}

	NSDictionary *payloadToSet = [self entrypointPayloadDefaultContext];

	self->_entrypointPayload = [payload dictionaryByAddingEntries:payloadToSet];
}

- (NSString *)address
{
	return self->_url.absoluteString;
}

- (NSString *)addressToInline
{
	return self->_urlToInline.absoluteString;
}

#pragma mark -
#pragma mark JavaScript

- (NSString *)_resourcesTemporaryLocation
{
//	NSString *sourcePath = [TPCPathInfo applicationTemporaryProcessSpecific];
	NSString *sourcePath = themeController().temporaryPath;

	NSString *basePath = [sourcePath stringByAppendingPathComponent:@"/ICLPayload-Resources/"];

	[TPCPathInfo _createDirectoryAtPath:basePath];

	return basePath;
}

/* WebKit2 uses sandboxed processes. We copy the resources files to
 the application's temporary folder so that it can access them. */
- (nullable NSArray<NSString *> *)_copyResourcesToTemporaryLocation:(nullable NSArray<NSURL *> *)resources
{
	if (resources == nil) {
		return nil;
	}

	NSString *basePath = [self _resourcesTemporaryLocation];

	NSString *(^copyOperation)(NSURL *) = ^NSString *(NSURL *resourceURL)
	{
		if (resourceURL.isFileURL == NO) {
			return resourceURL.absoluteString;
		}

		NSString *resourcePath = resourceURL.relativePath;

		NSString *filename =
		[NSString stringWithFormat:@"%@.%@",
		 resourcePath.md5,
		 resourcePath.pathExtension];

		NSString *destinationPath = [basePath stringByAppendingPathComponent:filename];

		if ([RZFileManager() fileExistsAtPath:destinationPath]) {
			return destinationPath;
		}

		NSError *copyError;

		BOOL copyResult =
		[RZFileManager() copyItemAtPath:resourcePath
								 toPath:destinationPath
								  error:&copyError];

		if (copyResult == NO) {
			LogToConsoleError("Copy operation for '%{public}@' failed with error: %{public}@",
				resourcePath.standardizedTildePath, copyError.localizedDescription);
		}

		return destinationPath;
	};

	NSMutableArray<NSString *> *temporaryResources = [NSMutableArray arrayWithCapacity:resources.count];

	for (NSURL *resourceURL in resources) {
		@autoreleasepool {
			[temporaryResources addObject:copyOperation(resourceURL)];
		}
	}

	return [temporaryResources copy];
}

- (NSDictionary<NSString *, id> *)javaScriptObject
{
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];

	[dic setUnsignedInteger:self->_contentLength forKey:@"contentLength"];

	[dic setObject:@{
		@"width" : @(self->_contentSize.width),
		@"height" : @(self->_contentSize.height)
	} forKey:@"contentSize"];

	[dic maybeSetObject:[self _copyResourcesToTemporaryLocation:self->_styleResources]
				 forKey:@"styleResources"];

	[dic maybeSetObject:[self _copyResourcesToTemporaryLocation:self->_scriptResources]
				 forKey:@"scriptResources"];

	[dic setObject:self->_html forKey:@"html"];

	NSString *entrypoint = self->_entrypoint;

	if (entrypoint) {
		[dic setObject:entrypoint forKey:@"entrypoint"];

		/* call self. instead of self->_ for entrypointPayload to allow
		 the default values to be assigned to the exported object. */
		[dic setObject:self.entrypointPayload forKey:@"entrypointPayload"];
	}

	[dic setObject:self->_url forKey:@"url"];
	[dic setObject:self->_urlToInline forKey:@"urlToInline"];

	[dic setObject:self->_lineNumber forKey:@"lineNumber"];

	[dic setObject:self->_uniqueIdentifier forKey:@"uniqueIdentifier"];
//	[dic setObject:self->_viewIdentifier forKey:@"viewIdentifier"];

	[dic setUnsignedInteger:self->_index forKey:@"index"];

	return [dic copy];
}

@end

#pragma mark -

@implementation ICLPayloadMutable

@dynamic urlToInline;
@dynamic contentLength;
@dynamic contentSize;
@dynamic styleResources;
@dynamic scriptResources;
@dynamic html;
@dynamic entrypoint;
@dynamic entrypointPayload;
@dynamic classAttribute;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [ICLPayload self];
}

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)init
{
	return [self initOnMutate];
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

- (void)setUrlToInline:(NSURL *)urlToInline
{
	NSParameterAssert(urlToInline != nil);
	NSParameterAssert(urlToInline.isFileURL == NO);

	if (self->_urlToInline != urlToInline) {
		self->_urlToInline = [urlToInline copy];
	}
}

- (void)setContentLength:(unsigned long long)contentLength
{
	if (self->_contentLength != contentLength) {
		self->_contentLength = contentLength;
	}
}

- (void)setContentSize:(NSSize)contentSize
{
	self->_contentSize = contentSize;
}

- (void)setStyleResources:(NSArray<NSURL *> *)styleResources
{
	NSParameterAssert(styleResources != nil);

	if (self->_styleResources != styleResources) {
		self->_styleResources = [styleResources copy];
	}
}

- (void)setScriptResources:(NSArray<NSURL *> *)scriptResources
{
	NSParameterAssert(scriptResources != nil);

	if (self->_scriptResources != scriptResources) {
		self->_scriptResources = [scriptResources copy];
	}
}

- (void)setHtml:(NSString *)html
{
	NSParameterAssert(html != nil);

	if (self->_html != html) {
		self->_html = [html copy];
	}
}

- (void)setEntrypoint:(nullable NSString *)entrypoint
{
	if (self->_entrypoint != entrypoint) {
		self->_entrypoint = [entrypoint copy];
	}
}

- (void)setEntrypointPayload:(nullable NSDictionary<NSString *, id<NSCopying>> *)entrypointPayload
{
	if (self->_entrypointPayload != entrypointPayload) {
		self->_entrypointPayload = [entrypointPayload copy];

		[self entrypointPayloadSetContext];
	}
}

- (void)setClassAttribute:(NSString *)classAttribute
{
	NSParameterAssert(classAttribute != nil);

	if (self->_classAttribute != classAttribute) {
		self->_classAttribute = [classAttribute copy];
	}
}

@end

NS_ASSUME_NONNULL_END
