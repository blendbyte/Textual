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

#import <netdb.h>

#import "NSObjectHelperPrivate.h"
#import "TPCPreferences.h"
#import "ICLMediaAssessment.h"
#import "ICLMediaAssessor.h"

NS_ASSUME_NONNULL_BEGIN

/* Hardcoded maximum width for images (and maybe other media) */
#define _assessorMaximumImageWidth				7200

/* Redirects followed for one assessment */
#define _assessorMaximumRedirects				5

NSString * const ICLMediaAssessorErrorDomain = @"ICLMediaAssessorErrorDomain";

@interface ICLMediaAssessorConfiguration : NSObject
@property (nonatomic, copy) ICLMediaAssessorCompletionBlock completionBlock;
@property (nonatomic, assign) ICLMediaType expectedType;
@property (nonatomic, copy) NSURL *url;
@end

@interface ICLMediaAssessorLimits : NSObject
@property (nonatomic, assign) NSUInteger imageMaximumWidth;
@property (nonatomic, assign) NSUInteger imageMaximumHeight;
@property (nonatomic, assign) unsigned long long imageMaximumFilesize;
@end

@interface ICLMediaAssessorRequest : NSObject
@property (nonatomic, strong, nullable) NSURLSession *session;
@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, copy, nullable) NSError *alternateError;
@property (nonatomic, assign) BOOL doNotFinalize;
@property (nonatomic, assign) NSUInteger redirectCount;
@end

@interface ICLMediaAssessorState : NSObject
@property (nonatomic, copy, nullable) ICLMediaAssessment *assessment;
@property (nonatomic, assign) BOOL performExtendedValidation;
@end

@interface ICLMediaAssessor ()
@property (nonatomic, strong, nullable) ICLMediaAssessorConfiguration *config;
@property (nonatomic, strong, nullable) ICLMediaAssessorLimits *limits;
@property (nonatomic, strong, nullable) ICLMediaAssessorRequest *request;
@property (nonatomic, strong, nullable) ICLMediaAssessorState *state;
@end

#pragma mark -
#pragma mark Local Addresses

/* Previews never reach the local network: loopback, private, link-local,
 unique local, multicast, .local and single-label names, and names that
 resolve to them, also after redirects. Clicking such a link still opens it. */

/* address is in host byte order */
static BOOL ICLIPv4AddressIsLocal(uint32_t address)
{
	uint8_t a = (address >> 24);
	uint8_t b = ((address >> 16) & 0xff);
	uint8_t c = ((address >> 8) & 0xff);

	return (a == 0 ||								// "this network"
			a == 10 ||								// private
			a == 127 ||								// loopback
			(a == 100 && (b & 0xc0) == 64) ||		// shared address space (CGNAT)
			(a == 169 && b == 254) ||				// link-local
			(a == 172 && (b & 0xf0) == 16) ||		// private
			(a == 192 && b == 0 && c == 0) ||		// IETF protocol assignments
			(a == 192 && b == 168) ||				// private
			(a == 198 && (b & 0xfe) == 18) ||		// benchmarking
			a >= 224);								// multicast, reserved, broadcast
}

static BOOL ICLSocketAddressIsLocal(const struct sockaddr *address)
{
	if (address->sa_family == AF_INET) {
		return ICLIPv4AddressIsLocal(ntohl(((const struct sockaddr_in *)address)->sin_addr.s_addr));
	}

	if (address->sa_family != AF_INET6) {
		return YES;
	}

	const struct in6_addr *address6 = &((const struct sockaddr_in6 *)address)->sin6_addr;

	const uint8_t *bytes = address6->s6_addr;

	/* IPv4-mapped (::ffff:0:0/96) and NAT64 (64:ff9b::/96) addresses carry an IPv4 address */
	static const uint8_t nat64Prefix[12] = {0x00, 0x64, 0xff, 0x9b, 0, 0, 0, 0, 0, 0, 0, 0};

	if (IN6_IS_ADDR_V4MAPPED(address6) || memcmp(bytes, nat64Prefix, sizeof(nat64Prefix)) == 0) {
		uint32_t address4 = (((uint32_t)bytes[12] << 24) | ((uint32_t)bytes[13] << 16) | ((uint32_t)bytes[14] << 8) | bytes[15]);

		return ICLIPv4AddressIsLocal(address4);
	}

	return (IN6_IS_ADDR_UNSPECIFIED(address6) ||
			IN6_IS_ADDR_LOOPBACK(address6) ||
			IN6_IS_ADDR_V4COMPAT(address6) ||		// deprecated ::a.b.c.d
			IN6_IS_ADDR_LINKLOCAL(address6) ||		// fe80::/10
			IN6_IS_ADDR_SITELOCAL(address6) ||		// fec0::/10
			IN6_IS_ADDR_MULTICAST(address6) ||		// ff00::/8
			(bytes[0] & 0xfe) == 0xfc);				// unique local, fc00::/7
}

/* Returns NO if any address of the host is local or none is found.
 found is set to YES when the lookup returns addresses. */
static BOOL ICLAddressesOfHostAreAllowed(NSString *host, int flags, BOOL *found)
{
	struct addrinfo hints;

	memset(&hints, 0, sizeof(hints));

	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = flags;

	struct addrinfo *result = NULL;

	if (getaddrinfo(host.UTF8String, NULL, &hints, &result) != 0 || result == NULL) {
		return NO;
	}

	*found = YES;

	BOOL allowed = YES;

	for (struct addrinfo *entry = result; entry != NULL; entry = entry->ai_next) {
		if (entry->ai_addr == NULL || ICLSocketAddressIsLocal(entry->ai_addr)) {
			allowed = NO;

			break;
		}
	}

	freeaddrinfo(result);

	return allowed;
}

/* Lowercased host without brackets or trailing dots,
 or nil if the URL is not HTTP(S) or has no host. */
static NSString * _Nullable ICLHostForURL(NSURL *url)
{
	NSString *scheme = url.scheme.lowercaseString;

	if ([scheme isEqualToString:@"http"] == NO && [scheme isEqualToString:@"https"] == NO) {
		return nil;
	}

	NSString *host = url.host.lowercaseString;

	if ([host hasPrefix:@"["] && [host hasSuffix:@"]"] && host.length > 2) {
		host = [host substringWithRange:NSMakeRange(1, (host.length - 2))];
	}

	while ([host hasSuffix:@"."]) {
		host = [host substringToIndex:(host.length - 1)];
	}

	if (host.length == 0) {
		return nil;
	}

	return host;
}

static BOOL ICLHostNameIsLocal(NSString *host)
{
	/* Single-label names ("router", "localhost") resolve through the
	 search domains of the local network. */
	return ([host containsString:@"."] == NO ||
			[host hasSuffix:@".localhost"] ||
			[host hasSuffix:@".local"] ||
			[host hasSuffix:@".home.arpa"] ||
			[host hasSuffix:@".internal"]);
}

/* Calls completionBlock on a background queue. A public name can point at a
 local address: the request makes its own lookup, so this narrows the
 window rather than closing it. */
static void ICLCheckURLIsAllowed(NSURL *url, void (^completionBlock)(BOOL allowed))
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		NSString *host = ICLHostForURL(url);

		if (host == nil) {
			completionBlock(NO);

			return;
		}

		BOOL numeric = NO;

		BOOL allowed = ICLAddressesOfHostAreAllowed(host, AI_NUMERICHOST, &numeric);

		if (numeric) {
			completionBlock(allowed);

			return;
		}

		if (ICLHostNameIsLocal(host)) {
			completionBlock(NO);

			return;
		}

		BOOL found = NO;

		allowed = ICLAddressesOfHostAreAllowed(host, 0, &found);

		completionBlock(found && allowed);
	});
}

@implementation ICLMediaAssessor

#pragma mark -
#pragma mark Construction

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

+ (instancetype)assessorForAddress:(NSString *)address completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	return [self assessorForAddress:address withType:ICLMediaTypeUnknown completionBlock:completionBlock];
}

+ (instancetype)assessorForURL:(NSURL *)url completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	return [self assessorForURL:url withType:ICLMediaTypeUnknown completionBlock:completionBlock];
}

+ (instancetype)assessorForAddress:(NSString *)address withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	ICLMediaAssessor *object = [[self alloc] initWithAddress:address withType:type completionBlock:completionBlock];

	return object;
}

+ (instancetype)assessorForURL:(NSURL *)url withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	ICLMediaAssessor *object = [[self alloc] initWithURL:url withType:type completionBlock:completionBlock];

	return object;
}

- (instancetype)initWithAddress:(NSString *)address withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	NSParameterAssert(address != nil);
	NSParameterAssert(completionBlock != nil);

	NSURL *url = [NSURL URLWithString:address];

	return [self initWithURL:url withType:type completionBlock:completionBlock];
}

- (instancetype)initWithURL:(NSURL *)url withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(url.isFileURL == NO);
	NSParameterAssert(completionBlock != nil);

	if ((self = [super init])) {
		[self prepareToAssessURL:url withType:type completionBlock:completionBlock];

		return self;
	}

	return nil;
}

- (void)prepareToAssessURL:(NSURL *)url withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	/* Prepare configuration */
	ICLMediaAssessorConfiguration *config = [ICLMediaAssessorConfiguration new];

	config.completionBlock = completionBlock;

	config.expectedType = type;

	config.url = url;

	self.config = config;
}

#pragma mark -
#pragma mark Actions (Public)

- (void)resume
{
	[self _assess];
}

- (void)suspend
{
	[self _cancel];
}

#pragma mark -
#pragma mark Actions (Private)

- (void)_assess
{
	NSAssert((self.request == nil), @"An assessment is already in progress");

	ICLMediaAssessorConfiguration *config = self.config;

	NSAssert((config != nil), @"-assess called after an assessment finalized");

	/* The request exists while the address is checked, so that
	 -suspend can stop the assessment before it starts */
	ICLMediaAssessorRequest *request = [ICLMediaAssessorRequest new];

	self.request = request;

	/* Prepare limits */
	ICLMediaType expectedType = self.config.expectedType;

	if (expectedType == ICLMediaTypeUnknown ||
		expectedType == ICLMediaTypeImage)
	{
		ICLMediaAssessorLimits *limits = [ICLMediaAssessorLimits new];

		limits.imageMaximumWidth = _assessorMaximumImageWidth;
		limits.imageMaximumHeight = [TPCPreferences inlineMediaMaxHeight];
		limits.imageMaximumFilesize = [TPCPreferences inlineImagesMaxFilesize];

		self.limits = limits;
	}

	/* Perform request, unless the address is on the local network */
	ICLCheckURLIsAllowed(config.url, ^(BOOL allowed) {
		if (request.doNotFinalize) {
			[self _flushRequestState]; // Suspended while checking

			return;
		}

		if (allowed == NO) {
			[self _finalizeAssessmentWithError:[self _errorWithDescription:@"Address is on the local network, unresolvable or not HTTP(S)" code:ICLMediaAssessorErrorCodeAddressNotAllowed]];

			return;
		}

		NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[self.class _sharedSessionConfiguration] delegate:(id)self delegateQueue:nil];

		request.session = urlSession;

		/* We use a data task which is always GET.
		 Many services block HEAD requests, so we use GET.
		 When we are only interested in the headers, we close the
		 connection after receiving them, so we don't waste resources. */
		NSURLSessionDataTask *urlSessionTask = [urlSession dataTaskWithURL:config.url];

		request.task = urlSessionTask;

		[urlSessionTask resume];
	});
}

- (void)_cancel
{
	[self _cancelRequest];
}

#pragma mark -
#pragma mark Utilities

- (void)_cancelRequest
{
	ICLMediaAssessorRequest *request = self.request;

	if (request == nil) {
		return;
	}

	request.doNotFinalize = YES;

	NSURLSession *session = request.session;

	[session invalidateAndCancel];
}

- (void)_flushRequestState
{
	self.limits = nil;
	self.state = nil;
	self.request = nil;
}

- (void)_finalizeAssessmentWithError:(nullable NSError *)error
{
	if (error.isURLSessionCancelError) {
		error = self.request.alternateError;
	}

	[self _performCompletionBlockWithError:error];

	[self _flushRequestState];

	self.config = nil;
}

- (void)_performCompletionBlockWithError:(nullable NSError *)error
{
	ICLMediaAssessorConfiguration *config = self.config;

	ICLMediaAssessment *assessment = self.state.assessment;

	/* This condition is typically true when we refuse an authentication challenge. */
	if (error == nil && assessment == nil) {
		error = [self _errorWithDescription:@"Assessment failed" code:ICLMediaAssessorErrorCodeAssessmentFailed];
	}

	config.completionBlock(assessment, error);
}

- (NSError *)_errorWithDescription:(NSString *)errorDescription code:(ICLMediaAssessorErrorCode)errorCode
{
	NSParameterAssert(errorDescription != nil);

	return
	[NSError errorWithDomain:ICLMediaAssessorErrorDomain
						code:errorCode
					userInfo:@{
		NSLocalizedDescriptionKey : errorDescription
	}];
}

#pragma mark -
#pragma mark URL Session Delegate

+ (NSURLSessionConfiguration *)_sharedSessionConfiguration
{
	static NSURLSessionConfiguration *config = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		config = [NSURLSessionConfiguration ephemeralSessionConfiguration];

		/* Ignore local caches */
		config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

		/* Do not send cookies from local store */
		config.HTTPShouldSetCookies = NO;

		/* Do not allow cookies to be set */
		config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
	});

	return config;
}

- (nullable ICLMediaAssessorState *)_readHeadersInWithError:(NSError **)error
{
	NSParameterAssert(error != NULL);

	NSHTTPURLResponse *response = (id)self.request.task.response;

	/* Read in status code */
	if (response.statusCode != 200) {
		*error = [self _errorWithDescription:@"Endpoint did not respond with OK (200)" code:ICLMediaAssessorErrorCodeUnexpectedStatusCode];

		return nil;
	}

	/* Read in content type */
	NSString *contentType = response.MIMEType;

	if (contentType.length > 128) {
		*error = [self _errorWithDescription:@"Content-Type header is improperly formatted" code:ICLMediaAssessorErrorCodeMalformedContentType];

		return nil;
	}

	/* Read in content length */
	long long contentLength = response.expectedContentLength;

	if (contentLength <= 0) {
		*error = [self _errorWithDescription:@"Content-Length header is improperly formatted" code:ICLMediaAssessorErrorCodeMalformedContentLength];

		return nil;
	}

	/* Figure out what type of media this is */
	ICLMediaType mediaType = ICLMediaTypeOther;

	BOOL performExtendedValidation = NO;

	/* Content is an image */
	if ([[self.class validImageContentTypes] containsObject:contentType])
	{
		mediaType = ICLMediaTypeImage;
	}

	/* Content is a video */
	else if ([[self.class validVideoContentTypes] containsObject:contentType])
	{
		mediaType = ICLMediaTypeVideo;
	}

	/* Is this a type we are interested in? */
	ICLMediaType expectedType = self.config.expectedType;

	if (expectedType != ICLMediaTypeUnknown &&
		expectedType != mediaType)
	{
		*error = [self _errorWithDescription:@"Unexpected media type" code:ICLMediaAssessorErrorCodeUnexpectedType];

		return nil;
	}

	/* Perform basic validation */
	switch (mediaType) {
		case ICLMediaTypeImage:
		{
			ICLMediaAssessorLimits *limits = self.limits;

			/* Limit maximum filesize */
			if (contentLength > limits.imageMaximumFilesize) {
				*error = [self _errorWithDescription:@"Content-Length exceeds maximum allowed" code:ICLMediaAssessorErrorCodeContentLengthExceeded];

				return nil;
			}

			/* Limiting the height of an image requires us to download
			 the contents of the image first, which we do by setting
			 the performExtendedValidation flag on the state. */
			if (limits.imageMaximumHeight > 0) {
				performExtendedValidation = YES;
			}

			break;
		}
		default:
		{
			break;
		}
	}

	/* Complete read in */
	ICLMediaAssessmentMutable *assessment =
	[[ICLMediaAssessmentMutable alloc] initWithURL:response.URL asType:mediaType];

	assessment.contentType = contentType;
	assessment.contentLength = contentLength;

	ICLMediaAssessorState *state = [ICLMediaAssessorState new];

	state.assessment = assessment;

	state.performExtendedValidation = performExtendedValidation;

	return state;
}

#pragma mark
#pragma mark URL Session Delegate Cont.

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
	/* Response might not be an HTTP response if we
	 end up receiving a redirect to a data URL. */
	if ([response isKindOfClass:[NSHTTPURLResponse class]] == NO) {
		self.request.alternateError =
		[self _errorWithDescription:@"Invalid response type (not HTTP)" code:ICLMediaAssessorErrorCodeUnexpectedResponse];

		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	/* Perform basic assessment of request.
	 -readHeadersIn returning a nil value indicates that
	 something was erroneous and we should not continue. */
	NSError *readHeadersInError;

	ICLMediaAssessorState *state = [self _readHeadersInWithError:&readHeadersInError];

	if (state == nil) {
		/* A refused redirect arrives here as the redirect response:
		 keep the reason it was refused */
		if (self.request.alternateError.code != ICLMediaAssessorErrorCodeAddressNotAllowed) {
			self.request.alternateError = readHeadersInError;
		}

		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	self.state = state;

	/* Some requests may require us to download the data
	 of the media to perform extended validation, such
	 as when the user limits the height of images. */
	/* When we don't have to perform extended validation,
	 we can just cancel any further actions because we
	 already have enough from the headers. */
	if (state.performExtendedValidation == NO) {
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	/* Change to download task */
	completionHandler(NSURLSessionResponseBecomeDownload);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler
{
	/* Do not perform caching */

	completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
	/* Follow redirects, but not to the local network and not too many.
	 Refusing one completes the task with the redirect response, which
	 fails the assessment (not 200); the error says why. */
	ICLMediaAssessorRequest *assessorRequest = self.request;

	assessorRequest.redirectCount += 1;

	NSURL *url = request.URL;

	if (assessorRequest.redirectCount > _assessorMaximumRedirects || url == nil) {
		assessorRequest.alternateError = [self _errorWithDescription:@"Too many redirects" code:ICLMediaAssessorErrorCodeAddressNotAllowed];

		completionHandler(nil);

		return;
	}

	ICLCheckURLIsAllowed(url, ^(BOOL allowed) {
		if (allowed == NO) {
			assessorRequest.alternateError = [self _errorWithDescription:@"Redirect to an address on the local network, unresolvable or not HTTP(S)" code:ICLMediaAssessorErrorCodeAddressNotAllowed];
		}

		completionHandler((allowed) ? request : nil);
	});
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
	/* Refuse challenge requests */

	NSString *authenticationMethod = challenge.protectionSpace.authenticationMethod;

	if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic] ||
		[authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest])
	{
		completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);

		return;
	}

	completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
	self.request.task = downloadTask;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
	/* According to the documentation for NSURLSession,
	 the file at the URL will be deleted once this delegate
	 call completes which means we do not have to do much:
	 Just perform our extended validation, then return. */

	NSError *extendedValidationError;

	if ([self _performExtendedValidationAtURL:location withError:&extendedValidationError]) {
		return; /* Success */
	}

	self.request.alternateError = extendedValidationError;

	[session invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
	/* Don't allow our Content-Length to lie to us/ */

	if ([self _downloadProgressExceededMaximumFilesize:totalBytesWritten] == NO) {
		return; /* Success */
	}

	self.request.alternateError =
	[self _errorWithDescription:@"Maximum response size exceeded" code:ICLMediaAssessorErrorCodeContentLengthExceeded];

	[session invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	/* If -suspend was called on this object,
	 cleanup the request but do not finalize. */
	if (self.request.doNotFinalize) {
		[self _flushRequestState];

		return;
	}

	[self _finalizeAssessmentWithError:error];
}

#pragma mark -
#pragma mark Basic Validation

+ (NSArray<NSString *> *)validImageContentTypes
{
	static NSArray<NSString *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cachedValue =
		@[@"image/gif",
		  @"image/jpeg",
		  @"image/png",
		  @"image/svg+xml",
		  @"image/tiff",
		  @"image/x-ms-bmp"];
	});

	return cachedValue;
}

+ (NSArray<NSString *> *)validVideoContentTypes
{
	static NSArray<NSString *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cachedValue =
		@[@"video/3gpp",
		  @"video/3gpp2",
		  @"video/mp4",
		  @"video/quicktime",
		  @"video/x-m4v"];
	});

	return cachedValue;
}

#pragma mark -
#pragma mark Extended Validation

- (BOOL)_downloadProgressExceededMaximumFilesize:(unsigned long long)downloadProgress
{
	unsigned long long maximumFilesize = 0;

	switch (self.state.assessment.type) {
		case ICLMediaTypeImage:
		{
			maximumFilesize = self.limits.imageMaximumFilesize;

			break;
		}
		default:
		{
			break;
		}
	}

	if (maximumFilesize == 0) {
		return NO; /* Success */
	}

	return (downloadProgress > maximumFilesize);
}

- (BOOL)_performExtendedValidationAtURL:(NSURL *)url withError:(NSError **)error
{
	NSParameterAssert(url != nil);
	NSParameterAssert(error != NULL);

	switch (self.state.assessment.type) {
		case ICLMediaTypeImage:
		{
			return [self _performExtendedValidationForImageAtURL:url withError:error];

			break;
		}
		default:
		{
			break;
		}
	}

	return YES; /* Success */
}

- (BOOL)_performExtendedValidationForImageAtURL:(NSURL *)url withError:(NSError **)error
{
	NSParameterAssert(url != nil);
	NSParameterAssert(error != NULL);

	CGImageSourceRef image = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);

	if (image == NULL) {
		*error =
		[self _errorWithDescription:@"Image validation: CGImageSourceCreateWithURL() returned NULL" code:ICLMediaAssessorErrorCodeAssessmentFailed];

		return NO;
	}

	CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(image, 0, NULL);

	if (imageProperties == NULL) {
		CFRelease(image);

		*error =
		[self _errorWithDescription:@"Image validation: CGImageSourceCopyPropertiesAtIndex() returned NULL" code:ICLMediaAssessorErrorCodeAssessmentFailed];

		return NO;
	}

	NSNumber *imageWidth = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
	NSNumber *imageHeight = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);

	CFRelease(image);
	CFRelease(imageProperties);

	ICLMediaAssessorLimits *limits = self.limits;

	if (imageWidth.integerValue > limits.imageMaximumWidth)
	{
		*error = [self _errorWithDescription:@"Image validation: Maximum width exceeded" code:ICLMediaAssessorErrorCodeMaximumWidthExceeded];

		return NO;
	}
	else if (imageHeight.integerValue > limits.imageMaximumHeight)
	{
		*error = [self _errorWithDescription:@"Image validation: Maximum height exceeded" code:ICLMediaAssessorErrorCodeMaximumHeightExceeded];

		return NO;
	}

	return YES; /* Success */
}

#pragma mark -
#pragma mark Logging

+ (void)logError:(NSError *)error
{
	NSParameterAssert(error != nil);

	if ([error.domain isEqualToString:ICLMediaAssessorErrorDomain] == NO) {
		return;
	}

	ICLMediaAssessorErrorCode errorCode = error.code;

	switch (errorCode) {
		case ICLMediaAssessorErrorCodeAssessmentFailed:
		case ICLMediaAssessorErrorCodeUnexpectedStatusCode:
		case ICLMediaAssessorErrorCodeMalformedContentType:
		case ICLMediaAssessorErrorCodeMalformedContentLength:
		case ICLMediaAssessorErrorCodeUnexpectedResponse:
		{
			LogToConsoleDebug("Assessor fatal error: %{public}@",
				error.localizedDescription);
		}
		case ICLMediaAssessorErrorCodeAddressNotAllowed:
		case ICLMediaAssessorErrorCodeUnexpectedType:
		case ICLMediaAssessorErrorCodeContentLengthExceeded:
		case ICLMediaAssessorErrorCodeMaximumWidthExceeded:
		case ICLMediaAssessorErrorCodeMaximumHeightExceeded:
		{
			LogToConsoleDebug("Assessor validation error: %{public}@",
				error.localizedDescription);
		}
	} // switch()
}

@end

#pragma mark -

@implementation ICLMediaAssessorConfiguration
@end

@implementation ICLMediaAssessorLimits
@end

@implementation ICLMediaAssessorRequest
@end

@implementation ICLMediaAssessorState
@end

NS_ASSUME_NONNULL_END
