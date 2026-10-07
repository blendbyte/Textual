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

@interface TLOInternetAddressLookup ()
@property (nonatomic, weak) id requestDelegate;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *connectionResponse;
@property (nonatomic, strong) NSMutableData *connectionResponseData;
@property (nonatomic, copy, nullable) NSString *address;
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

		return self;
	}

	return nil;
}

- (void)performLookup
{
	[self setupConnectionRequest];
}

- (void)cancelLookup
{
	[self _teardownConnectionRequest];
}

- (void)setupConnectionRequest
{
	NSAssert((self.connection == nil),
		@"A lookup is already in progress");

	self.connectionResponseData = [NSMutableData data];

	NSURL *requestURL = [NSURL URLWithString:[self addressSourceURL]];

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL
														   cachePolicy:NSURLRequestReloadIgnoringCacheData
													   timeoutInterval:_requestTimeoutInterval];

	request.HTTPMethod = @"GET";

	self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)_teardownConnectionRequest
{
	if (self.connection) {
		[self.connection cancel];
	}

	self.connection = nil;
	self.connectionResponse = nil;
	self.connectionResponseData = nil;
}

- (void)teardownConnectionRequest
{
	[self _teardownConnectionRequest];

	[self informDelegate];

	self.address = nil;
}

- (NSString *)addressSourceURL
{
	if ([TPCPreferences fileTransferIPAddressDetectionMethod] == TXFileTransferIPAddressMethodRouterAndThirdParty) {
		return [self thirdPartySourceURL];
	}
	
	return @"https://myip.codeux.com/";
}

- (NSString *)thirdPartySourceURL
{
	NSArray *services = @[
	  @"https://wtfismyip.com/text",
	  @"https://canhazip.com/",
	  @"http://ifconfig.me/ip",
	  @"http://v4.ipv6-test.com/api/myip.php",
	];

	NSUInteger randomIndex = (arc4random() % services.count);

	return services[randomIndex];
}

#pragma mark -
#pragma mark Connection Delegate

- (void)informDelegate
{
	NSString *address = self.address;

	if (address) {
		[self informDelegateLookupReturnedAddress:address];
	} else {
		[self informDelegateLookupFailed];
	}
}

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

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	id connectionResponse = self.connectionResponse;

	// connectionResponse may not be NSHTTPURLResponse if the website
	// requested performs a location redirect to a data resource.
	if ([connectionResponse isKindOfClass:[NSHTTPURLResponse class]]) {
		BOOL isValidResponse = ([connectionResponse statusCode] == 200);

		if (isValidResponse) {
			NSData *addressData = self.connectionResponseData;

			NSString *address = [NSString stringWithData:addressData encoding:NSUTF8StringEncoding];

			address = [address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

			if ((address.isIPv4Address && self.IPv4AddressIsValid) ||
				(address.isIPv6Address && self.IPv6AddressIsValid))
			{
				self.address = address;
			}
		}
	}

	[self teardownConnectionRequest];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	LogToConsole("Lookup failed with error: %{public}@", error.localizedDescription);

	[self teardownConnectionRequest];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.connectionResponseData appendData:data];

	// There is no reasonable explanation for the content of a request,
	// without headers, to exceed this length when it's sent in plain text.
	if (self.connectionResponseData.length > 1024) {
		LogToConsoleError("Too much data has been received for this to be a valid request");

		[self teardownConnectionRequest];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.connectionResponse = response;
}

- (nullable NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	return nil;
}

@end

NS_ASSUME_NONNULL_END
