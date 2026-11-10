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

#import "IRCClient.h"
#import "TPCPreferencesLocalPrivate.h"
#import "ICLInlineContentLoaderPrivate.h"
#import "IRCClientConfig.h"
#import "IRCConnectionProxyPrivate.h"
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
@property (nonatomic, assign) BOOL readsPrefix; // the body is cut at maximumLength instead of refused
@property (nonatomic, copy, nullable) NSArray<NSData *> *endMarkers;
@property (nonatomic, copy, nullable) BOOL (^responseBlock)(NSHTTPURLResponse *response);
@property (nonatomic, strong, nullable) NSHTTPURLResponse *response;
@property (nonatomic, strong, nullable) NSMutableData *data;
@property (nonatomic, assign) BOOL dataComplete; // stopped early with all that was wanted
@property (nonatomic, copy, nullable) void (^completionBlock)(NSHTTPURLResponse * _Nullable response, NSData * _Nullable data);
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

/* Fake-IP tools (Clash, Surge) answer every name with a made-up address from
 the benchmarking range and route the connection by that name */
static BOOL ICLSocketAddressIsFakeIP(const struct sockaddr *address)
{
	if (address->sa_family != AF_INET) {
		return NO;
	}

	uint32_t address4 = ntohl(((const struct sockaddr_in *)address)->sin_addr.s_addr);

	return ((address4 >> 24) == 198 && ((address4 >> 16) & 0xfe) == 18);
}

/* Returns NO if any address of the host is local or none is found.
 A name may point at a fake-IP address, a typed address may not.
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
		if (entry->ai_addr == NULL) {
			allowed = NO;

			break;
		}

		if (ICLSocketAddressIsLocal(entry->ai_addr) &&
			((flags & AI_NUMERICHOST) != 0 || ICLSocketAddressIsFakeIP(entry->ai_addr) == NO))
		{
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

static BOOL ICLHostNameIsOnion(NSString *host)
{
	return [host hasSuffix:@".onion"];
}

/* Whether a request for the URL goes through a proxy set in System Settings */
static BOOL ICLSystemProxyAppliesToURL(NSURL *url)
{
	CFDictionaryRef settings = CFNetworkCopySystemProxySettings();

	if (settings == NULL) {
		return NO;
	}

	NSArray<NSDictionary *> *proxies = CFBridgingRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)url, settings));

	CFRelease(settings);

	NSString *proxyType = proxies.firstObject[(__bridge NSString *)kCFProxyTypeKey];

	return (proxyType != nil && [proxyType isEqualToString:(__bridge NSString *)kCFProxyTypeNone] == NO);
}

#pragma mark -

@implementation ICLURLSession

/* Proxy identifier → session */
static NSMutableDictionary<NSString *, NSURLSession *> *_proxySessions = nil;

/* Session → how its host names are checked (ICLURLSessionResolution); absent: local */
static NSMapTable<NSURLSession *, NSNumber *> *_sessionResolutions = nil;

/* Session → its media session */
static NSMapTable<NSURLSession *, NSURLSession *> *_mediaSessions = nil;

/* Seconds a streamed media download may take in all */
#define _mediaResourceTimeout			(6 * 60 * 60)

+ (NSURLSessionConfiguration *)_sessionConfiguration
{
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];

	config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	config.URLCache = nil;

	config.HTTPShouldSetCookies = NO;
	config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
	config.HTTPCookieStorage = nil;

	config.URLCredentialStorage = nil;

	config.timeoutIntervalForRequest = _requestTimeout;
	config.timeoutIntervalForResource = _requestTimeout;

	return config;
}

+ (NSURLSession *)_sessionWithConfiguration:(NSURLSessionConfiguration *)config
{
	return [NSURLSession sessionWithConfiguration:config
										 delegate:[ICLURLSessionDelegate new]
									delegateQueue:[NSOperationQueue mainQueue]];
}

+ (NSURLSession *)sharedSession
{
	static NSURLSession *session = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		session = [self _sessionWithConfiguration:[self _sessionConfiguration]];

		_proxySessions = [NSMutableDictionary dictionary];

		_sessionResolutions = [NSMapTable weakToStrongObjectsMapTable];

		_mediaSessions = [NSMapTable weakToStrongObjectsMapTable];
	});

	return session;
}

/* The identifier holds the proxy password, read from the Keychain: worked out
 once per configuration (a changed server gets a new one), not for every link */
+ (nullable NSString *)_proxyIdentifierForConfig:(IRCClientConfig *)config
{
	NSParameterAssert(config != nil);

	static NSMapTable<IRCClientConfig *, id> *identifiers = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		/* By object, not by equal contents: the password isn't in them */
		identifiers = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality)
											valueOptions:NSPointerFunctionsStrongMemory];
	});

	@synchronized (identifiers) {
		id identifier = [identifiers objectForKey:config];

		if (identifier == nil) {
			identifier = ([IRCConnectionProxy identifierForClientConfig:config] ?: [NSNull null]);

			[identifiers setObject:identifier forKey:config];
		}

		return ((identifier == [NSNull null]) ? nil : identifier);
	}
}

+ (NSURLSession *)sessionForClient:(nullable IRCClient *)client
{
	NSURLSession *sharedSession = self.sharedSession;

	IRCClientConfig *config = client.config;

	NSString *proxyIdentifier = ((config) ? [self _proxyIdentifierForConfig:config] : nil);

	if (proxyIdentifier == nil) {
		return sharedSession;
	}

	@synchronized (_proxySessions) {
		NSURLSession *session = _proxySessions[proxyIdentifier];

		if (session == nil) {
			NSURLSessionConfiguration *sessionConfig = [self _sessionConfiguration];

			[IRCConnectionProxy applyClientConfig:config toSessionConfiguration:sessionConfig];

			session = [self _sessionWithConfiguration:sessionConfig];

			_proxySessions[proxyIdentifier] = session;

			ICLURLSessionResolution resolution =
			((config.proxyType == IRCConnectionProxyTypeTor) ? ICLURLSessionResolutionTor : ICLURLSessionResolutionProxy);

			[_sessionResolutions setObject:@(resolution) forKey:session];
		}

		return session;
	}
}

+ (NSURLSession *)mediaSessionForSession:(NSURLSession *)session
{
	NSParameterAssert(session != nil);

	(void)self.sharedSession;

	@synchronized (_proxySessions) {
		NSURLSession *mediaSession = [_mediaSessions objectForKey:session];

		if (mediaSession == nil) {
			NSURLSessionConfiguration *mediaConfig = [session.configuration copy];

			mediaConfig.timeoutIntervalForResource = _mediaResourceTimeout;

			mediaSession = [self _sessionWithConfiguration:mediaConfig];

			[_mediaSessions setObject:mediaSession forKey:session];

			NSNumber *resolution = [_sessionResolutions objectForKey:session];

			if (resolution) {
				[_sessionResolutions setObject:resolution forKey:mediaSession];
			}
		}

		return mediaSession;
	}
}

+ (ICLURLSessionResolution)resolutionForSession:(NSURLSession *)session
{
	NSParameterAssert(session != nil);

	(void)self.sharedSession;

	@synchronized (_proxySessions) {
		return (ICLURLSessionResolution)[_sessionResolutions objectForKey:session].unsignedIntegerValue;
	}
}

+ (NSArray<NSURLSession *> *)allSessions
{
	NSURLSession *sharedSession = self.sharedSession;

	@synchronized (_proxySessions) {
		NSMutableArray<NSURLSession *> *sessions = [NSMutableArray arrayWithObject:sharedSession];

		[sessions addObjectsFromArray:_proxySessions.allValues];

		for (NSURLSession *mediaSession in _mediaSessions.objectEnumerator) {
			[sessions addObject:mediaSession];
		}

		return [sessions copy];
	}
}

+ (BOOL)URLIsAllowed:(NSURL *)url withResolution:(ICLURLSessionResolution)resolution
{
	NSParameterAssert(url != nil);

	if ([self URLIsAllowed:url] == NO) {
		return NO;
	}

	NSString *host = ICLHostForURL(url);

	if (ICLHostNameIsOnion(host)) {
		return (resolution == ICLURLSessionResolutionTor);
	}

	return YES;
}

+ (void)checkURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(BOOL allowed))completionBlock
{
	NSParameterAssert(url != nil);
	NSParameterAssert(session != nil);
	NSParameterAssert(completionBlock != nil);

	ICLURLSessionResolution resolution = [self resolutionForSession:session];

	if (resolution == ICLURLSessionResolutionLocal) {
		[self checkURL:url completionBlock:completionBlock];

		return;
	}

	/* Through a proxy: no local lookup, the proxy resolves the name */
	BOOL allowed = [self URLIsAllowed:url withResolution:resolution];

	dispatch_async(dispatch_get_main_queue(), ^{
		completionBlock(allowed);
	});
}

+ (BOOL)URLIsAllowed:(NSURL *)url
{
	NSParameterAssert(url != nil);

	if ([url.scheme.lowercaseString isEqualToString:@"https"] == NO) {
		return NO;
	}

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

	/* App Transport Security refuses plain HTTP */
	if ([url.scheme.lowercaseString isEqualToString:@"https"] == NO) {
		host = nil;
	}

	BOOL numeric = NO;

	BOOL allowed = (host != nil && ICLAddressesOfHostAreAllowed(host, AI_NUMERICHOST, &numeric));

	/* An onion name is for Tor alone (RFC 7686): asking the resolver about
	 it would tell it which hidden service was linked */
	if (host && ICLHostNameIsOnion(host)) {
		host = nil;
	}

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

		/* Behind a system proxy, the proxy resolves the name. It not resolving
		 here says nothing. An onion name stays with Tor. */
		if (found == NO) {
			result = (ICLHostNameIsOnion(host) == NO && ICLSystemProxyAppliesToURL(url));
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(result);
		});
	});
}

+ (void)requestDataFromURL:(NSURL *)url session:(NSURLSession *)session maximumLength:(NSUInteger)maximumLength completionBlock:(void (^)(NSData * _Nullable data))completionBlock
{
	NSParameterAssert(completionBlock != nil);

	ICLURLSessionDataRequest *request = [ICLURLSessionDataRequest new];

	request.maximumLength = maximumLength;

	request.completionBlock = ^(NSHTTPURLResponse * _Nullable response, NSData * _Nullable data) {
		completionBlock(data);
	};

	[self _performRequest:request withURL:url session:session];
}

+ (void)requestPrefixFromURL:(NSURL *)url session:(NSURLSession *)session maximumLength:(NSUInteger)maximumLength endMarkers:(nullable NSArray<NSData *> *)endMarkers responseBlock:(nullable BOOL (^)(NSHTTPURLResponse *response))responseBlock completionBlock:(void (^)(NSHTTPURLResponse * _Nullable response, NSData * _Nullable data))completionBlock
{
	NSParameterAssert(completionBlock != nil);

	ICLURLSessionDataRequest *request = [ICLURLSessionDataRequest new];

	request.maximumLength = maximumLength;

	request.readsPrefix = YES;

	request.endMarkers = endMarkers;

	request.responseBlock = responseBlock;

	request.completionBlock = completionBlock;

	[self _performRequest:request withURL:url session:session];
}

+ (void)_performRequest:(ICLURLSessionDataRequest *)request withURL:(NSURL *)url session:(NSURLSession *)session
{
	NSParameterAssert(request != nil);
	NSParameterAssert(url != nil);
	NSParameterAssert(session != nil);
	NSParameterAssert(request.maximumLength > 0);

	[self checkURL:url session:session completionBlock:^(BOOL allowed) {
		if (allowed == NO) {
			LogToConsoleDebug("Refused request to a local, unresolvable or plain HTTP address");

			request.completionBlock(nil, nil);

			return;
		}

		NSURLSessionDataTask *task = [session dataTaskWithURL:url];

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

	/* Settings › Previews › Sites: a link to a site they allow can't lead to
	 one they don't. A service's own address outside them (its API, its
	 picture host) isn't held to them, nor where it leads. */
	NSArray<NSString *> *domains = [TPCPreferences inlineMediaDomains];

	TXInlineMediaDomainRuleMode mode = [TPCPreferences inlineMediaDomainRuleMode];

	NSString *originalHost = task.originalRequest.URL.host;

	if (originalHost && url.host &&
		[ICLInlineContentLoader host:originalHost isPreviewedWithDomains:domains mode:mode] &&
		[ICLInlineContentLoader host:url.host isPreviewedWithDomains:domains mode:mode] == NO)
	{
		LogToConsoleDebug("Refused redirect to a site that isn't previewed");

		completionHandler(nil);

		return;
	}

	[ICLURLSession checkURL:url session:session completionBlock:^(BOOL allowed) {
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
		((NSHTTPURLResponse *)response).statusCode != 200)
	{
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

	self.response = httpResponse;

	/* The caller has seen all it wants (no data) */
	BOOL (^responseBlock)(NSHTTPURLResponse *) = self.responseBlock;

	if (responseBlock && responseBlock(httpResponse) == NO) {
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	if (self.readsPrefix == NO && response.expectedContentLength > (long long)self.maximumLength) {
		self.response = nil;

		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	self.data = [NSMutableData data];

	completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	NSMutableData *dataIn = self.data;

	if (dataIn == nil || self.dataComplete) {
		return;
	}

	/* The Content-Length header is optional and can lie */
	NSUInteger room = (self.maximumLength - dataIn.length);

	if (data.length > room) {
		if (self.readsPrefix == NO) {
			self.data = nil;
		} else {
			[dataIn appendData:[data subdataWithRange:NSMakeRange(0, room)]];

			self.dataComplete = YES;
		}

		[dataTask cancel];

		return;
	}

	/* A marker can span two pieces */
	NSUInteger searchFrom = dataIn.length;

	[dataIn appendData:data];

	for (NSData *endMarker in self.endMarkers) {
		NSUInteger markerSearchFrom = ((searchFrom > endMarker.length) ? (searchFrom - endMarker.length) : 0);

		if ([dataIn rangeOfData:endMarker options:0 range:NSMakeRange(markerSearchFrom, (dataIn.length - markerSearchFrom))].location != NSNotFound) {
			self.dataComplete = YES;

			[dataTask cancel];

			return;
		}
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	void (^completionBlock)(NSHTTPURLResponse * _Nullable, NSData * _Nullable) = self.completionBlock;

	self.completionBlock = nil;

	if (error && (self.dataComplete && error.isURLSessionCancelError) == NO) {
		if (error.isURLSessionCancelError == NO) {
			LogToConsoleDebug("Request failed: %{public}@", error.localizedDescription);
		}

		self.data = nil;
	}

	if (completionBlock) {
		completionBlock(self.response, [self.data copy]);
	}

	self.response = nil;

	self.data = nil;
}

@end

NS_ASSUME_NONNULL_END
