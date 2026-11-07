/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "ICLMediaAssessor.h"
#import "ICLURLSessionPrivate.h"
#import "ICLMediaSchemeHandlerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const ICLMediaSchemeHandlerScheme = @"textual-media";

NSErrorDomain const ICLMediaFetchErrorDomain = @"ICLMediaFetchErrorDomain";

/* Addresses handed out: the oldest are forgotten first */
#define _maximumEntries			4000

@implementation ICLMediaSchemeEntry
@end

#pragma mark -

@interface ICLMediaFetch ()
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) ICLMediaType type;
@property (nonatomic, assign) unsigned long long maximumLength;
@property (nonatomic, copy, nullable) NSString *rangeHeader;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *task;
@property (nonatomic, assign) unsigned long long receivedLength;
@property (nonatomic, assign) BOOL receivedResponse;
@property (nonatomic, assign) BOOL finished; // completed or cancelled: no more blocks
@end

@implementation ICLMediaFetch

- (instancetype)initWithURL:(NSURL *)url session:(NSURLSession *)session type:(ICLMediaType)type maximumLength:(unsigned long long)maximumLength rangeHeader:(nullable NSString *)rangeHeader
{
	NSParameterAssert(url != nil);
	NSParameterAssert(session != nil);

	if ((self = [super init])) {
		self.url = url;
		self.session = session;
		self.type = type;
		self.maximumLength = maximumLength;
		self.rangeHeader = rangeHeader;

		return self;
	}

	return nil;
}

+ (NSArray<NSString *> *)contentTypesForMediaType:(ICLMediaType)type
{
	switch (type) {
		case ICLMediaTypeImage:
		{
			return ICLMediaAssessor.validImageContentTypes;
		}
		case ICLMediaTypeVideo:
		case ICLMediaTypeVideoGif:
		{
			return ICLMediaAssessor.validVideoContentTypes;
		}
		case ICLMediaTypeAudio:
		{
			return ICLMediaAssessor.validAudioContentTypes;
		}
		default:
		{
			return [ICLMediaAssessor.validImageContentTypes arrayByAddingObjectsFromArray:ICLMediaAssessor.validVideoContentTypes];
		}
	}
}

- (void)start
{
	[ICLURLSession checkURL:self.url session:self.session completionBlock:^(BOOL allowed) {
		if (self.finished) {
			return;
		}

		if (allowed == NO) {
			[self _finishWithErrorCode:ICLMediaFetchErrorCodeNotAllowed description:@"Address is on the local network, unresolvable or not HTTPS"];

			return;
		}

		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];

		NSString *rangeHeader = self.rangeHeader;

		if (rangeHeader.length > 0) {
			[request setValue:rangeHeader forHTTPHeaderField:@"Range"];
		}

		/* Redirects are checked by the session's delegate (ICLURLSession) */
		NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];

		task.delegate = self;

		self.task = task;

		[task resume];
	}];
}

- (void)cancel
{
	self.finished = YES;

	[self _forgetBlocks];

	[self.task cancel];

	self.task = nil;
}

- (void)_forgetBlocks
{
	self.responseBlock = nil;
	self.dataBlock = nil;
	self.completionBlock = nil;
}

- (void)_finishWithErrorCode:(ICLMediaFetchErrorCode)code description:(NSString *)description
{
	NSError *error = [NSError errorWithDomain:ICLMediaFetchErrorDomain code:code userInfo:@{
		NSLocalizedDescriptionKey : description
	}];

	[self _finishWithError:error];
}

- (void)_finishWithError:(nullable NSError *)error
{
	if (self.finished) {
		return;
	}

	self.finished = YES;

	void (^completionBlock)(NSError * _Nullable) = self.completionBlock;

	[self _forgetBlocks];

	if (error) {
		[self.task cancel];
	}

	self.task = nil;

	if (completionBlock) {
		completionBlock(error);
	}
}

/* "bytes 0-1023/52428800": the full length, or -1 when the server doesn't say */
+ (long long)_totalLengthInContentRange:(nullable NSString *)contentRange
{
	NSRange slash = [contentRange rangeOfString:@"/" options:NSBackwardsSearch];

	if (slash.location == NSNotFound) {
		return -1;
	}

	NSString *total = [contentRange substringFromIndex:(slash.location + 1)];

	if (total.length == 0 || total.isNumericOnly == NO) {
		return -1;
	}

	return total.longLongValue;
}

#pragma mark -
#pragma mark URL Session Delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
	if (self.finished) {
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	if ([response isKindOfClass:[NSHTTPURLResponse class]] == NO) {
		completionHandler(NSURLSessionResponseCancel);

		[self _finishWithErrorCode:ICLMediaFetchErrorCodeUnexpectedResponse description:@"Not an HTTP response"];

		return;
	}

	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

	NSInteger statusCode = httpResponse.statusCode;

	BOOL rangeRequested = (self.rangeHeader.length > 0);

	if (statusCode != 200 && (statusCode != 206 || rangeRequested == NO)) {
		completionHandler(NSURLSessionResponseCancel);

		[self _finishWithErrorCode:ICLMediaFetchErrorCodeUnexpectedResponse description:@"Unexpected status code"];

		return;
	}

	NSString *contentType = httpResponse.MIMEType.lowercaseString;

	if (contentType == nil || [[self.class contentTypesForMediaType:self.type] containsObject:contentType] == NO) {
		completionHandler(NSURLSessionResponseCancel);

		[self _finishWithErrorCode:ICLMediaFetchErrorCodeUnexpectedType description:@"Unexpected content type"];

		return;
	}

	NSString *contentLength = [httpResponse valueForHTTPHeaderField:@"Content-Length"];
	NSString *contentRange = [httpResponse valueForHTTPHeaderField:@"Content-Range"];
	NSString *acceptRanges = [httpResponse valueForHTTPHeaderField:@"Accept-Ranges"];
	NSString *contentEncoding = [httpResponse valueForHTTPHeaderField:@"Content-Encoding"];

	/* A compressed body arrives decompressed: its length is not the header's */
	if (contentEncoding.length > 0 && [contentEncoding isEqualToStringIgnoringCase:@"identity"] == NO) {
		contentLength = nil;
	}

	/* The headers are checked here, the body as it arrives (headers can lie) */
	unsigned long long maximumLength = self.maximumLength;

	if (maximumLength > 0) {
		long long totalLength = ((statusCode == 206) ? [self.class _totalLengthInContentRange:contentRange] : httpResponse.expectedContentLength);

		if (totalLength > 0 && (unsigned long long)totalLength > maximumLength) {
			completionHandler(NSURLSessionResponseCancel);

			[self _finishWithErrorCode:ICLMediaFetchErrorCodeTooLarge description:@"Larger than the size limit"];

			return;
		}
	}

	NSMutableDictionary<NSString *, NSString *> *headerFields = [NSMutableDictionary dictionary];

	headerFields[@"Content-Type"] = contentType;

	if (contentLength.isNumericOnly) {
		headerFields[@"Content-Length"] = contentLength;
	}

	if (statusCode == 206 && contentRange.length > 0) {
		headerFields[@"Content-Range"] = contentRange;
	}

	if ([acceptRanges isEqualToString:@"bytes"]) {
		headerFields[@"Accept-Ranges"] = acceptRanges;
	}

	self.receivedResponse = YES;

	if (self.responseBlock) {
		self.responseBlock(statusCode, [headerFields copy]);
	}

	completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	if (self.finished) {
		return;
	}

	self.receivedLength += data.length;

	unsigned long long maximumLength = self.maximumLength;

	if (maximumLength > 0 && self.receivedLength > maximumLength) {
		[self _finishWithErrorCode:ICLMediaFetchErrorCodeTooLarge description:@"Larger than the size limit"];

		return;
	}

	if (self.dataBlock) {
		self.dataBlock(data);
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	if (self.finished) {
		return;
	}

	if (error) {
		[self _finishWithErrorCode:ICLMediaFetchErrorCodeFailed description:error.localizedDescription];

		return;
	}

	/* Ended without a response, e.g. a refused redirect */
	if (self.receivedResponse == NO) {
		[self _finishWithErrorCode:ICLMediaFetchErrorCodeUnexpectedResponse description:@"No response"];

		return;
	}

	[self _finishWithError:nil];
}

@end

#pragma mark -

@interface ICLMediaSchemeHandler ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, ICLMediaSchemeEntry *> *entries;
@property (nonatomic, strong) NSMutableArray<NSString *> *entryTokens; // least recently used first
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *entryTokensByMedia; // the same media gets the same address
@property (nonatomic, strong) NSMapTable<id <WKURLSchemeTask>, ICLMediaFetch *> *fetches;
@end

@implementation ICLMediaSchemeHandler

+ (ICLMediaSchemeHandler *)sharedHandler
{
	static ICLMediaSchemeHandler *sharedHandler = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedHandler = [ICLMediaSchemeHandler new];
	});

	return sharedHandler;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self.entries = [NSMutableDictionary dictionary];

		self.entryTokens = [NSMutableArray array];
		self.entryTokensByMedia = [NSMutableDictionary dictionary];

		self.fetches = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality)
											 valueOptions:NSPointerFunctionsStrongMemory];

		return self;
	}

	return nil;
}

- (NSURL *)URLForMediaAtURL:(NSURL *)url session:(NSURLSession *)session type:(ICLMediaType)type maximumLength:(unsigned long long)maximumLength
{
	NSParameterAssert(url != nil);
	NSParameterAssert(session != nil);

	/* A line rendered again (a style reload, scrolling back) asks for the
	 same media: it keeps its address, so lines on screen don't lose theirs */
	NSString *mediaKey = [NSString stringWithFormat:@"%p %lu %llu %@", (__bridge void *)session, (unsigned long)type, maximumLength, url.absoluteString];

	NSString *existingToken = self.entryTokensByMedia[mediaKey];

	if (existingToken && self.entries[existingToken]) {
		[self _noteTokenUsed:existingToken];

		return [NSURL URLWithString:[NSString stringWithFormat:@"%@://media/%@", ICLMediaSchemeHandlerScheme, existingToken]];
	}

	ICLMediaSchemeEntry *entry = [ICLMediaSchemeEntry new];

	entry.url = url;
	entry.session = session;
	entry.type = type;
	entry.maximumLength = maximumLength;

	NSString *token = [NSUUID UUID].UUIDString;

	self.entries[token] = entry;

	self.entryTokensByMedia[mediaKey] = token;

	entry.mediaKey = mediaKey;

	[self.entryTokens addObject:token];

	/* The ones used least recently go first */
	while (self.entryTokens.count > _maximumEntries) {
		NSString *oldestToken = self.entryTokens.firstObject;

		[self.entryTokensByMedia removeObjectForKey:self.entries[oldestToken].mediaKey];

		[self.entries removeObjectForKey:oldestToken];

		[self.entryTokens removeObjectAtIndex:0];
	}

	return [NSURL URLWithString:[NSString stringWithFormat:@"%@://media/%@", ICLMediaSchemeHandlerScheme, token]];
}

- (nullable ICLMediaSchemeEntry *)entryForMediaURL:(NSURL *)mediaURL
{
	NSParameterAssert(mediaURL != nil);

	if ([mediaURL.scheme isEqualToString:ICLMediaSchemeHandlerScheme] == NO ||
		[mediaURL.host isEqualToString:@"media"] == NO)
	{
		return nil;
	}

	NSString *token = mediaURL.lastPathComponent;

	ICLMediaSchemeEntry *entry = self.entries[token];

	if (entry) {
		[self _noteTokenUsed:token];
	}

	return entry;
}

- (void)_noteTokenUsed:(NSString *)token
{
	NSParameterAssert(token != nil);

	NSUInteger index = [self.entryTokens indexOfObject:token];

	if (index == NSNotFound || index == (self.entryTokens.count - 1)) {
		return;
	}

	[self.entryTokens removeObjectAtIndex:index];

	[self.entryTokens addObject:token];
}

#pragma mark -
#pragma mark URL Scheme Handler

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
	NSURL *requestURL = urlSchemeTask.request.URL;

	ICLMediaSchemeEntry *entry = ((requestURL) ? [self entryForMediaURL:requestURL] : nil);

	if (entry == nil) {
		[urlSchemeTask didFailWithError:[NSError errorWithDomain:ICLMediaFetchErrorDomain code:ICLMediaFetchErrorCodeNotAllowed userInfo:nil]];

		return;
	}

	/* The media session: a large image or a video may take longer than 20 seconds */
	NSURLSession *session = [ICLURLSession mediaSessionForSession:entry.session];

	NSString *rangeHeader = [urlSchemeTask.request valueForHTTPHeaderField:@"Range"];

	ICLMediaFetch *fetch = [[ICLMediaFetch alloc] initWithURL:entry.url session:session type:entry.type maximumLength:entry.maximumLength rangeHeader:rangeHeader];

	fetch.responseBlock = ^(NSInteger statusCode, NSDictionary<NSString *, NSString *> *headerFields) {
		NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:requestURL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:headerFields];

		[urlSchemeTask didReceiveResponse:response];
	};

	fetch.dataBlock = ^(NSData *data) {
		[urlSchemeTask didReceiveData:data];
	};

	fetch.completionBlock = ^(NSError * _Nullable error) {
		[self.fetches removeObjectForKey:urlSchemeTask];

		if (error) {
			LogToConsoleDebug("Media request refused or failed: %{public}@", error.localizedDescription);

			[urlSchemeTask didFailWithError:error];
		} else {
			[urlSchemeTask didFinish];
		}
	};

	[self.fetches setObject:fetch forKey:urlSchemeTask];

	[fetch start];
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
	/* WebKit no longer wants it: no more calls to the task */
	ICLMediaFetch *fetch = [self.fetches objectForKey:urlSchemeTask];

	[fetch cancel];

	[self.fetches removeObjectForKey:urlSchemeTask];
}

@end

NS_ASSUME_NONNULL_END
