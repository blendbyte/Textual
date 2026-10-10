/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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
#import "TPCPreferencesLocal.h"
#import "TLOInternetAddressLookup.h"

NS_ASSUME_NONNULL_BEGIN

#define _requestTimeoutInterval			30.0

/* A plain-text address is a few dozen bytes */
#define _maximumResponseLength			1024

@interface TLOInternetAddressLookup () <NSURLSessionDataDelegate>
@property (nonatomic, weak) id requestDelegate;
@property (nonatomic, strong, nullable) NSURLSession *session;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *task;
@property (nonatomic, strong, nullable) NSMutableData *responseData;
@property (nonatomic, copy) NSArray<NSURL *> *remainingSources;
@end

@implementation TLOInternetAddressLookup

#pragma mark -
#pragma mark Public API

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithDelegate:(id <TLOInternetAddressLookupDelegate>)delegate
{
	NSParameterAssert(delegate != nil);

	if ((self = [super init])) {
		self.IPv4AddressIsValid = YES;
		self.IPv6AddressIsValid = YES;

		self.requestDelegate = delegate;

		self.remainingSources = @[];

		return self;
	}

	return nil;
}

- (void)performLookup
{
	NSAssert((self.session == nil),
		@"A lookup is already in progress");

	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];

	configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	configuration.URLCache = nil;
	configuration.HTTPShouldSetCookies = NO;
	configuration.timeoutIntervalForRequest = _requestTimeoutInterval;

	/* The session keeps its delegate until it is invalidated (-_finish) */
	self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];

	self.remainingSources = [self.class addressSources];

	[self requestNextSource];
}

- (void)cancelLookup
{
	[self _finish];
}

/* Textual's own service first, then public ones: a failed lookup leaves file
 transfers behind NAT unable to work. With "Router and third party" chosen,
 only the public ones, in random order. All HTTPS (App Transport Security). */
+ (NSArray<NSURL *> *)addressSources
{
	NSArray *thirdParty = @[
		@"https://api.ipify.org/",
		@"https://icanhazip.com/",
		@"https://ifconfig.me/ip",
		@"https://wtfismyip.com/text"
	];

	NSMutableArray<NSString *> *addresses = [NSMutableArray array];

	if ([TPCPreferences fileTransferIPAddressDetectionMethod] == TXFileTransferIPAddressMethodRouterAndThirdParty) {
		NSMutableArray *shuffled = [thirdParty mutableCopy];

		for (NSUInteger i = shuffled.count; i > 1; i--) {
			[shuffled exchangeObjectAtIndex:(i - 1) withObjectAtIndex:arc4random_uniform((uint32_t)i)];
		}

		[addresses addObjectsFromArray:shuffled];
	} else {
		[addresses addObject:@"https://myip.textualapp.com/"];

		[addresses addObjectsFromArray:thirdParty];
	}

	NSMutableArray<NSURL *> *sources = [NSMutableArray arrayWithCapacity:addresses.count];

	for (NSString *address in addresses) {
		[sources addObject:[NSURL URLWithString:address]];
	}

	return [sources copy];
}

- (void)requestNextSource
{
	NSURL *source = self.remainingSources.firstObject;

	if (source == nil) {
		[self _finish];

		[self informDelegateLookupFailed];

		return;
	}

	self.remainingSources = [self.remainingSources subarrayWithRange:NSMakeRange(1, (self.remainingSources.count - 1))];

	self.responseData = [NSMutableData data];

	NSURLSessionDataTask *task = [self.session dataTaskWithURL:source];

	self.task = task;

	[task resume];
}

- (void)_finish
{
	[self.task cancel];

	self.task = nil;

	self.responseData = nil;

	[self.session invalidateAndCancel];

	self.session = nil;
}

#pragma mark -
#pragma mark Delegate

- (void)informDelegateLookupReturnedAddress:(NSString *)address
{
	if ([self.requestDelegate respondsToSelector:@selector(internetAddressLookupReturnedAddress:)]) {
		[self.requestDelegate internetAddressLookupReturnedAddress:address];
	}
}

- (void)informDelegateLookupFailed
{
	if ([self.requestDelegate respondsToSelector:@selector(internetAddressLookupFailed)]) {
		[self.requestDelegate internetAddressLookupFailed];
	}
}

#pragma mark -
#pragma mark Session Delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
	BOOL acceptable = ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode == 200);

	completionHandler((acceptable) ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	if (dataTask != self.task) {
		return;
	}

	[self.responseData appendData:data];

	if (self.responseData.length > _maximumResponseLength) {
		LogToConsoleError("Too much data has been received for this to be a valid request");

		[dataTask cancel];
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler
{
	completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	/* Cancelled by -cancelLookup, or an earlier source */
	if (task != self.task) {
		return;
	}

	self.task = nil;

	NSString *address = nil;

	if (error == nil && self.responseData.length <= _maximumResponseLength) {
		address = [NSString stringWithData:self.responseData encoding:NSUTF8StringEncoding];

		address = [address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if ((address.isIPv4Address && self.IPv4AddressIsValid) == NO &&
			(address.isIPv6Address && self.IPv6AddressIsValid) == NO)
		{
			address = nil;
		}
	} else if (error) {
		LogToConsole("Lookup with %{public}@ failed: %{public}@", task.originalRequest.URL.host, error.localizedDescription);
	}

	if (address == nil) {
		[self requestNextSource];

		return;
	}

	[self _finish];

	[self informDelegateLookupReturnedAddress:address];
}

@end

NS_ASSUME_NONNULL_END
