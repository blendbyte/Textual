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

#import "TPCPreferences.h"
#import "ICLPayloadPrivate.h"
#import "ICLURLSessionPrivate.h"
#import "ICLInlineContentModulePrivate.h"
#import "ICMInlineImage.h"
#import "ICMInlineVideo.h"
#import "ICPCoreMediaPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "ICLInlineContentLoaderPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const ICLInlineContentErrorDomain = @"ICLInlineContentErrorDomain";

@interface ICLInlineContentLoader ()
@property (readonly, copy) NSDictionary<NSString *, NSArray<Class> *> *modules;

/* Modules that have started and not yet finished. NSCache evicted
 them in the middle of a request in Textual 7. */
@property (readonly) NSMutableSet<ICLInlineContentModule *> *activeModules;

@property (nonatomic, assign) BOOL terminating;
@end

@implementation ICLInlineContentLoader

+ (ICLInlineContentLoader *)sharedLoader
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedSelf = [[self alloc] init];
	});

	return sharedSelf;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self->_modules = [self.class _mapModulesToDomains:[ICPCoreMedia modules]];

		self->_activeModules = [NSMutableSet set];

		return self;
	}

	return nil;
}

/* Returns a dictionary with the key equal to the domain a module
 maps to and the value a list of modules that map to that domain. */
/* If a module does not map to a specific domain, then those can be
 accessed by the wildcard key "*" */
+ (NSDictionary<NSString *, NSArray<Class> *> *)_mapModulesToDomains:(NSArray<Class> *)moduleClasses
{
	NSParameterAssert(moduleClasses != nil);

	NSMutableDictionary<NSString *, NSMutableArray<Class> *> *modulesOut = [NSMutableDictionary dictionary];

	void (^mapModuleDomain)(Class, NSString *) = ^(Class moduleClass, NSString *moduleDomain) {
		NSMutableArray *mappedDomains = modulesOut[moduleDomain];

		if (mappedDomains == nil) {
			mappedDomains = [NSMutableArray array];

			modulesOut[moduleDomain] = mappedDomains;
		}

		[mappedDomains addObject:moduleClass];
	};

	for (Class moduleClass in moduleClasses) {
		NSArray<NSString *> *moduleDomains = [moduleClass domains];

		/* If the module does not map to a specific domain,
		 then map it to a wildcard for all other classes. */
		if (moduleDomains.count == 0) {
			mapModuleDomain(moduleClass, @"*");

			continue;
		}

		for (NSString *moduleDomain in moduleDomains) {
			mapModuleDomain(moduleClass, moduleDomain.lowercaseString);
		}
	}

	/* Replace mutable arrays with immutable copies */
	[modulesOut performSelectorOnObjectValueAndReplace:@selector(copy)];

	return [modulesOut copy];
}

#pragma mark -
#pragma mark Processing

- (void)processURL:(NSURL *)url withUniqueIdentifier:(NSString *)uniqueIdentifier atLineNumber:(NSString *)lineNumber index:(NSUInteger)index inView:(NSString *)viewIdentifier session:(NSURLSession *)session
{
	NSParameterAssert(url != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(lineNumber != nil);
	NSParameterAssert(viewIdentifier != nil);

	if (self.terminating) {
		return;
	}

	/* Only HTTP(S) URLs with a host, which is lowercased
	 so that modules match their domains in any case. */
	NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

	NSString *urlScheme = urlComponents.scheme.lowercaseString;

	if ([urlScheme isEqualToString:@"http"] == NO &&
		[urlScheme isEqualToString:@"https"] == NO)
	{
		return;
	}

	NSString *urlHost = urlComponents.host.lowercaseString;

	if (urlHost.length == 0) {
		return;
	}

	urlComponents.scheme = urlScheme;
	urlComponents.host = urlHost;

	NSURL *urlOut = urlComponents.URL;

	if (urlOut == nil) {
		return;
	}

	  ICLPayloadMutable *payload =
	[[ICLPayloadMutable alloc] initWithURL:urlOut
					  withUniqueIdentifier:uniqueIdentifier
							  atLineNumber:lineNumber
									 index:index
									inView:viewIdentifier
								   session:session];

	if ([self _processPayload:payload withModulesForDomain:urlHost]) {
		return;
	}

	/* If no module accepted responsibility for the urlHost,
	 then we try modules that do not map to a specific domain. */
	(void)[self _processPayload:payload withModulesForDomain:@"*"];
}

- (BOOL)_processPayload:(ICLPayloadMutable *)payload withModulesForDomain:(NSString *)domain
{
	NSParameterAssert(payload != nil);
	NSParameterAssert(domain != nil);

	for (Class module in self.modules[domain]) {
		if ([self _processPayload:payload usingModule:module]) {
			return YES;
		}
	}

	return NO;
}

- (BOOL)_processPayload:(ICLPayloadMutable *)payloadIn usingModule:(Class)moduleClass
{
	NSParameterAssert(payloadIn != nil);
	NSParameterAssert(moduleClass != NULL);

	/* Do not allow unsafe content */
	if ([moduleClass contentImageOrVideo] == NO && [TPCPreferences inlineMediaLimitToBasics]) {
		return NO;
	} else if ([moduleClass contentIsFile] == NO && [TPCPreferences inlineMediaLimitToBasics] && [TPCPreferences inlineMediaLimitBasicsToFiles]) {
		return NO;
	} else if ([moduleClass contentNotSafeForWork] && [TPCPreferences inlineMediaLimitNaughtyContent]) {
		return NO;
	} else if ([moduleClass contentUntrusted] && [TPCPreferences inlineMediaLimitUnsafeContent]) {
		return NO;
	}

	/* Determine whether this module has an action for this URL. */
	NSURL *url = payloadIn.url;

	ICLInlineContentModuleActionBlock actionBlock = [moduleClass actionBlockForURL:url];

	SEL action = NULL;

	if (actionBlock == nil) {
		action = [moduleClass actionForURL:url];
	}

	if (actionBlock == nil && action == NULL) {
		return NO;
	}

	/* Create module and call it */
	ICLInlineContentModule *module = [[moduleClass alloc] initWithPayload:payloadIn];

	[self _addReferenceForModule:module];

	if (actionBlock) {
		actionBlock(module);
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[module performSelector:action];
#pragma clang diagnostic pop
	}

	return YES;
}

#pragma mark -
#pragma mark State

- (void)_finalizeModule:(ICLInlineContentModule *)module withError:(nullable NSError *)error
{
	NSParameterAssert(module != nil);

	ICLPayload *payload = [module.payload copy];

	/* Remove reference to module */
	[self _removeReferenceForModule:module];

	if (error) {
		/* Report as is */
	}
	else if (payload.html.length == 0 &&
			 payload.scriptResources.count == 0)
	{
		error =
		[NSError errorWithDomain:ICLInlineContentErrorDomain
							code:1001
						userInfo:@{
			NSLocalizedDescriptionKey : @"-[ICLPayload scriptResources] must contain at least one path if -[ICLPayload html] is empty"
		}];
	}
	else if (payload.html.length == 0 &&
			 payload.entrypoint.length == 0)
	{
		error =
		[NSError errorWithDomain:ICLInlineContentErrorDomain
							code:1002
						userInfo:@{
			NSLocalizedDescriptionKey : @"-[ICLPayload html] and -[ICLPayload entrypoint] cannot both be empty"
		}];
	}
	else if ([ICLURLSession URLIsAllowed:payload.urlToInline] == NO)
	{
		/* Images and videos are checked before this point. This
		 keeps any other route from inlining a local address. */
		error =
		[NSError errorWithDomain:ICLInlineContentErrorDomain
							code:1004
						userInfo:@{
			NSLocalizedDescriptionKey : @"-[ICLPayload urlToInline] is a local address or not HTTPS"
		}];
	}

	if (self.terminating) {
		return;
	}

	if (error) {
		[TVCLogControllerInlineMediaSharedInstance() processingPayload:payload failedWithError:error];
	} else {
		[TVCLogControllerInlineMediaSharedInstance() processingPayloadSucceeded:payload];
	}
}

- (void)_cancelModule:(ICLInlineContentModule *)module
{
	NSParameterAssert(module != nil);

	[self _removeReferenceForModule:module];
}

- (void)_deferModule:(ICLInlineContentModule *)module asType:(ICLMediaType)type performCheck:(BOOL)performCheck
{
	NSParameterAssert(module != nil);

	switch (type) {
		case ICLMediaTypeImage:
		{
			ICMInlineImage *imageModule = [[ICMInlineImage alloc] initWithDeferredModule:module];

			[self _addReferenceForModule:imageModule];

			[imageModule performActionWithImageCheck:performCheck];

			break;
		}
		case ICLMediaTypeVideo:
		{
			ICMInlineVideo *videoModule = [[ICMInlineVideo alloc] initWithDeferredModule:module];

			[self _addReferenceForModule:videoModule];

			[videoModule performActionWithVideoCheck:performCheck];

			break;
		}
		case ICLMediaTypeVideoGif:
		{
			ICMInlineGifVideo *videoModule = [[ICMInlineGifVideo alloc] initWithDeferredModule:module];

			[self _addReferenceForModule:videoModule];

			[videoModule performActionWithVideoCheck:performCheck];

			break;
		}
		default:
		{
			LogToConsoleError("Unexpected media type: %{public}lu", type);

			break;
		} // case
	} // switch

	/* Last, because this may release the module */
	[self _removeReferenceForModule:module];
}

#pragma mark -
#pragma mark Memory

- (void)_addReferenceForModule:(ICLInlineContentModule *)module
{
	NSParameterAssert(module != nil);

	@synchronized (self.activeModules) {
		[self.activeModules addObject:module];
	}
}

- (void)_removeReferenceForModule:(ICLInlineContentModule *)module
{
	NSParameterAssert(module != nil);

	@synchronized (self.activeModules) {
		[self.activeModules removeObject:module];
	}
}

#pragma mark -
#pragma mark Termination

- (void)prepareForApplicationTermination
{
	self.terminating = YES;

	for (NSURLSession *session in [ICLURLSession allSessions]) {
		[session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> *tasks) {
			for (NSURLSessionTask *task in tasks) {
				[task cancel];
			}
		}];
	}
}

@end

NS_ASSUME_NONNULL_END
