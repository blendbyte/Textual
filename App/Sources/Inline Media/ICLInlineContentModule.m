/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

#import "ICLPayloadPrivate.h"
#import "ICLInlineContentLoaderPrivate.h"
#import "ICLInlineContentModulePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICLInlineContentModule ()
{
@private
	ICLPayloadMutable *_payload;
	BOOL _moduleFinalized;
}

@end

@implementation ICLInlineContentModule

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithPayload:(ICLPayloadMutable *)payload
{
	NSParameterAssert(payload != nil);

	if ((self = [super init])) {
		self->_payload = payload;

		[self mergePropertiesIntoPayload];

		return self;
	}

	return nil;
}

/* Goes through -initWithPayload: so subclasses set up their state
 (deferred videos lost their controls, autoplay and loop before) */
- (instancetype)initWithDeferredModule:(ICLInlineContentModule *)module
{
	NSParameterAssert(module != nil);

	ICLPayloadMutable *payload = [[ICLPayloadMutable alloc] initWithDeferredPayload:module.payload];

	return [self initWithPayload:payload];
}

- (void)mergePropertiesIntoPayload
{
	NSArray *scriptResources = self.scriptResources;

	if (scriptResources) {
		self.payload.scriptResources = scriptResources;
	}

	NSArray *styleResources = self.styleResources;

	if (styleResources) {
		self.payload.styleResources = styleResources;
	}

	NSString *entrypoint = self.entrypoint;

	if (entrypoint) {
		self.payload.entrypoint = entrypoint;
	}
}

- (nullable NSURL *)templateURL
{
	return nil;
}

- (nullable GRMustacheTemplate *)template
{
	NSURL *templateURL = self.templateURL;

	if (templateURL == nil || templateURL.isFileURL == NO) {
		return nil;
	}

	NSError *templateLoadError;

	GRMustacheTemplate *template = [GRMustacheTemplate templateFromContentsOfURL:templateURL error:&templateLoadError];

	if (template == nil) {
		LogToConsoleError("Failed to load template '%{public}@': %{public}@",
			templateURL.standardizedTildePath, templateLoadError.localizedDescription);
	}

	return template;
}

+ (nullable NSArray<NSString *> *)domains
{
	return nil;
}

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	return nil;
}

+ (nullable SEL)actionForURL:(NSURL *)url
{
	return NULL;
}

- (nullable NSArray<NSURL *> *)styleResources
{
	return nil;
}

- (nullable NSArray<NSURL *> *)scriptResources
{
	return nil;
}

- (nullable NSString *)entrypoint
{
	return nil;
}

+ (BOOL)contentImageOrVideo
{
	return NO;
}

+ (BOOL)contentUntrusted
{
	return NO;
}

+ (BOOL)contentNotSafeForWork
{
	return NO;
}

+ (BOOL)contentIsFile
{
	return NO;
}

@end

#pragma mark -
#pragma mark Completion

@implementation ICLInlineContentModule (Completion)

- (void)_finalizeAll
{
	self->_moduleFinalized = YES;
}

/* A module finishes once. Modules run in Textual's process, so a
 second call is logged and ignored instead of asserting. */
- (BOOL)_moduleCanFinish
{
	if (self->_moduleFinalized) {
		LogToConsoleError("Module '%{public}@' already finished", NSStringFromClass(self.class));

		return NO;
	}

	return YES;
}

- (void)finalize
{
	[self finalizeWithError:nil];
}

- (void)finalizeWithError:(nullable NSError *)error
{
	if ([self _moduleCanFinish] == NO) {
		return;
	}

	[self finalizePreflight];

	/* Marked first because the loader may release the module */
	[self _finalizeAll];

	[[ICLInlineContentLoader sharedLoader] _finalizeModule:self withError:error];
}

- (void)cancel
{
	if ([self _moduleCanFinish] == NO) {
		return;
	}

	[self finalizePreflight];

	/* Marked first because the loader may release the module */
	[self _finalizeAll];

	[[ICLInlineContentLoader sharedLoader] _cancelModule:self];
}

+ (BOOL)isTypeDeferrable:(ICLMediaType)type
{
	return (type == ICLMediaTypeImage ||
			type == ICLMediaTypeVideo ||
			type == ICLMediaTypeVideoGif);
}

- (void)deferAsType:(ICLMediaType)type
{
	[self deferAsType:type performCheck:YES];
}

- (void)deferAsType:(ICLMediaType)type performCheck:(BOOL)performCheck
{
	if ([self _moduleCanFinish] == NO) {
		return;
	}

	[self finalizePreflight];

	/* Marked first because the loader may release the module */
	[self _finalizeAll];

	[[ICLInlineContentLoader sharedLoader] _deferModule:self asType:type performCheck:performCheck];
}

@end

#pragma mark -
#pragma mark Completion (Private)

@implementation ICLInlineContentModule (CompletionPrivate)

- (void)finalizePreflight
{

}

@end

NS_ASSUME_NONNULL_END
