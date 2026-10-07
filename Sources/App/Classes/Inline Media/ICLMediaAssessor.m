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
#import "ICLMediaAssessment.h"
#import "ICLURLSessionPrivate.h"
#import "ICLMediaAssessor.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const ICLMediaAssessorErrorDomain = @"ICLMediaAssessorErrorDomain";

@interface ICLMediaAssessor () <NSURLSessionDataDelegate>
@property (nonatomic, copy, nullable) ICLMediaAssessorCompletionBlock completionBlock;
@property (nonatomic, assign) ICLMediaType expectedType;
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *task;
@property (nonatomic, copy, nullable) ICLMediaAssessment *assessment;
@property (nonatomic, copy, nullable) NSError *assessmentError;
@property (nonatomic, assign) BOOL started;
@end

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
	NSParameterAssert(address != nil);

	/* An address that isn't a URL fails when the assessment is resumed */
	NSURL *url = [NSURL URLWithString:address];

	if (url == nil) {
		url = [NSURL URLWithString:@"invalid:"];
	}

	return [self assessorForURL:url withType:type completionBlock:completionBlock];
}

+ (instancetype)assessorForURL:(NSURL *)url withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	return [[self alloc] initWithURL:url withType:type completionBlock:completionBlock];
}

- (instancetype)initWithURL:(NSURL *)url withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	if ((self = [super init])) {
		self.url = url;

		self.expectedType = type;

		self.completionBlock = completionBlock;

		return self;
	}

	return nil;
}

#pragma mark -
#pragma mark Actions

- (void)resume
{
	NSAssert((self.started == NO), @"An assessment was already started");

	self.started = YES;

	[ICLURLSession checkURL:self.url completionBlock:^(BOOL allowed) {
		/* -suspend was called */
		if (self.completionBlock == nil) {
			return;
		}

		if (allowed == NO) {
			[self _finishWithError:[self _errorWithDescription:@"Address is on the local network, unresolvable or not HTTP(S)" code:ICLMediaAssessorErrorCodeAddressNotAllowed]];

			return;
		}

		/* A GET request because many services refuse HEAD.
		 It is cancelled as soon as the headers arrive. */
		NSURLSessionDataTask *task = [[ICLURLSession sharedSession] dataTaskWithURL:self.url];

		task.delegate = self;

		self.task = task;

		[task resume];
	}];
}

- (void)suspend
{
	self.completionBlock = nil;

	[self.task cancel];

	self.task = nil;
}

#pragma mark -
#pragma mark Utilities

- (void)_finishWithError:(nullable NSError *)error
{
	ICLMediaAssessorCompletionBlock completionBlock = self.completionBlock;

	self.completionBlock = nil;

	self.task = nil;

	if (completionBlock == nil) {
		return;
	}

	ICLMediaAssessment *assessment = self.assessment;

	if (assessment && error == nil) {
		completionBlock(assessment, nil);

		return;
	}

	if (error == nil || error.isURLSessionCancelError) {
		error = [self _errorWithDescription:@"Assessment failed" code:ICLMediaAssessorErrorCodeAssessmentFailed];
	}

	completionBlock(nil, error);
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
#pragma mark Assessment

- (nullable ICLMediaAssessment *)_assessResponse:(NSHTTPURLResponse *)response withError:(NSError **)error
{
	NSParameterAssert(response != nil);
	NSParameterAssert(error != NULL);

	/* Read in status code */
	if (response.statusCode != 200) {
		*error = [self _errorWithDescription:@"Endpoint did not respond with OK (200)" code:ICLMediaAssessorErrorCodeUnexpectedStatusCode];

		return nil;
	}

	/* Read in content type */
	NSString *contentType = response.MIMEType.lowercaseString;

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

	if (contentType && [[self.class validImageContentTypes] containsObject:contentType]) {
		mediaType = ICLMediaTypeImage;
	} else if (contentType && [[self.class validVideoContentTypes] containsObject:contentType]) {
		mediaType = ICLMediaTypeVideo;
	}

	/* Is this a type we are interested in? */
	ICLMediaType expectedType = self.expectedType;

	if (expectedType != ICLMediaTypeUnknown &&
		expectedType != mediaType)
	{
		*error = [self _errorWithDescription:@"Unexpected media type" code:ICLMediaAssessorErrorCodeUnexpectedType];

		return nil;
	}

	/* Limit the size of images. Their dimensions are
	 checked by the chat view once WebKit loads them. */
	if (mediaType == ICLMediaTypeImage &&
		(unsigned long long)contentLength > [TPCPreferences inlineImagesMaxFilesize])
	{
		*error = [self _errorWithDescription:@"Content-Length exceeds maximum allowed" code:ICLMediaAssessorErrorCodeContentLengthExceeded];

		return nil;
	}

	NSURL *url = response.URL;

	if (url == nil) {
		*error = [self _errorWithDescription:@"Response has no URL" code:ICLMediaAssessorErrorCodeUnexpectedResponse];

		return nil;
	}

	ICLMediaAssessmentMutable *assessment = [[ICLMediaAssessmentMutable alloc] initWithURL:url asType:mediaType];

	if (contentType) {
		assessment.contentType = contentType;
	}

	assessment.contentLength = contentLength;

	return [assessment copy];
}

#pragma mark -
#pragma mark URL Session Delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
	/* Response might not be an HTTP response if we
	 end up receiving a redirect to a data URL. */
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSError *assessmentError = nil;

		self.assessment = [self _assessResponse:(NSHTTPURLResponse *)response withError:&assessmentError];

		self.assessmentError = assessmentError;
	} else {
		self.assessmentError = [self _errorWithDescription:@"Invalid response type (not HTTP)" code:ICLMediaAssessorErrorCodeUnexpectedResponse];
	}

	/* The headers are all that is needed. The body is never downloaded. */
	completionHandler(NSURLSessionResponseCancel);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	/* The task is always cancelled after the headers arrive,
	 so an error only matters if no assessment was made. */
	NSError *assessmentError = self.assessmentError;

	if (assessmentError) {
		error = assessmentError;
	} else if (self.assessment) {
		error = nil;
	}

	[self _finishWithError:error];
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
#pragma mark Logging

+ (void)logError:(NSError *)error
{
	NSParameterAssert(error != nil);

	if ([error.domain isEqualToString:ICLMediaAssessorErrorDomain] == NO) {
		return;
	}

	LogToConsoleDebug("Assessment failed: %{public}@", error.localizedDescription);
}

@end

NS_ASSUME_NONNULL_END
