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

#import <netdb.h>

#import "ICLURLSessionPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Redirects followed for one request */
#define _maximumRedirects				5

/* Seconds a request may take, redirects included */
#define _requestTimeout					20

@interface ICLURLSessionDelegate : NSObject <NSURLSessionTaskDelegate>
@property (readonly) NSMapTable<NSURLSessionTask *, NSNumber *> *redirectCounts;
@end

@interface ICLURLSessionDataRequest : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, assign) NSUInteger maximumLength;
@property (nonatomic, strong, nullable) NSMutableData *data;
@property (nonatomic, copy, nullable) void (^completionBlock)(NSData * _Nullable data);
@end

#pragma mark -
#pragma mark Local Addresses

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

#pragma mark -

@implementation ICLURLSession

+ (NSURLSession *)sharedSession
{
	static NSURLSession *session = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];

		config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
		config.URLCache = nil;

		config.HTTPShouldSetCookies = NO;
		config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
		config.HTTPCookieStorage = nil;

		config.URLCredentialStorage = nil;

		config.timeoutIntervalForRequest = _requestTimeout;
		config.timeoutIntervalForResource = _requestTimeout;

		session = [NSURLSession sessionWithConfiguration:config
												delegate:[ICLURLSessionDelegate new]
										   delegateQueue:[NSOperationQueue mainQueue]];
	});

	return session;
}

+ (BOOL)URLIsAllowed:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *host = ICLHostForURL(url);

	if (host == nil) {
		return NO;
	}

	BOOL numeric = NO;

	BOOL allowed = ICLAddressesOfHostAreAllowed(host, AI_NUMERICHOST, &numeric);

	if (numeric) {
		return allowed;
	}

	return (ICLHostNameIsLocal(host) == NO);
}

+ (void)checkURL:(NSURL *)url completionBlock:(void (^)(BOOL allowed))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(completionBlock != nil);

	NSString *host = ICLHostForURL(url);

	BOOL numeric = NO;

	BOOL allowed = (host != nil && ICLAddressesOfHostAreAllowed(host, AI_NUMERICHOST, &numeric));

	if (host == nil || numeric || ICLHostNameIsLocal(host)) {
		BOOL result = (numeric && allowed);

		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(result);
		});

		return;
	}

	/* A public name can point at a local address. The request makes its
	 own lookup, so this narrows the window rather than closing it. */
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		BOOL found = NO;

		BOOL result = ICLAddressesOfHostAreAllowed(host, 0, &found);

		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(found && result);
		});
	});
}

+ (void)requestDataFromURL:(NSURL *)url maximumLength:(NSUInteger)maximumLength completionBlock:(void (^)(NSData * _Nullable data))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(maximumLength > 0);
	NSParameterAssert(completionBlock != nil);

	[self checkURL:url completionBlock:^(BOOL allowed) {
		if (allowed == NO) {
			LogToConsoleDebug("Refused request to a local or unresolvable address");

			completionBlock(nil);

			return;
		}

		ICLURLSessionDataRequest *request = [ICLURLSessionDataRequest new];

		request.maximumLength = maximumLength;

		request.completionBlock = completionBlock;

		NSURLSessionDataTask *task = [self.sharedSession dataTaskWithURL:url];

		task.delegate = request;

		[task resume];
	}];
}

@end

#pragma mark -

@implementation ICLURLSessionDelegate

- (instancetype)init
{
	if ((self = [super init])) {
		self->_redirectCounts = [NSMapTable weakToStrongObjectsMapTable];

		return self;
	}

	return nil;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
	/* Refusing a redirect completes the task with the redirect
	 response, which every caller treats as a failure (not 200). */
	NSUInteger redirectCount = ([self.redirectCounts objectForKey:task].unsignedIntegerValue + 1);

	[self.redirectCounts setObject:@(redirectCount) forKey:task];

	NSURL *url = request.URL;

	if (redirectCount > _maximumRedirects || url == nil) {
		LogToConsoleDebug("Refused redirect: too many redirects");

		completionHandler(nil);

		return;
	}

	[ICLURLSession checkURL:url completionBlock:^(BOOL allowed) {
		if (allowed == NO) {
			LogToConsoleDebug("Refused redirect to a local or unresolvable address");
		}

		completionHandler((allowed) ? request : nil);
	}];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
	/* Server trust is evaluated as usual. Requests for credentials
	 (passwords, client certificates) are refused. */
	if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
		completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);

		return;
	}

	completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

@end

#pragma mark -

@implementation ICLURLSessionDataRequest

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
	if ([response isKindOfClass:[NSHTTPURLResponse class]] == NO ||
		((NSHTTPURLResponse *)response).statusCode != 200 ||
		response.expectedContentLength > (long long)self.maximumLength)
	{
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	self.data = [NSMutableData data];

	completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	NSMutableData *dataIn = self.data;

	if (dataIn == nil) {
		return;
	}

	/* The Content-Length header is optional and can lie */
	if ((dataIn.length + data.length) > self.maximumLength) {
		self.data = nil;

		[dataTask cancel];

		return;
	}

	[dataIn appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	void (^completionBlock)(NSData * _Nullable) = self.completionBlock;

	self.completionBlock = nil;

	if (error) {
		if (error.isURLSessionCancelError == NO) {
			LogToConsoleDebug("Request failed: %{public}@", error.localizedDescription);
		}

		self.data = nil;
	}

	if (completionBlock) {
		completionBlock([self.data copy]);
	}

	self.data = nil;
}

@end

NS_ASSUME_NONNULL_END
