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
#import "TPCResourceManager.h"
#import "IRCNetworkList.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCNetworkList ()
@property (nonatomic, copy, readwrite) NSArray<IRCNetwork *> *listOfNetworks;
@end

@interface IRCNetwork ()
@property (nonatomic, copy, readwrite) NSString *networkName;
@property (nonatomic, copy, readwrite) NSString *serverAddress;
@property (nonatomic, assign, readwrite) uint16_t serverPort;
@property (nonatomic, assign, readwrite) BOOL prefersSecuredConnection;

- (instancetype)initWithNetworkNamed:(NSString *)networkName networkConfiguration:(NSDictionary<NSString *, id> *)networkConfiguration;
@end

@implementation IRCNetworkList

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	NSMutableArray<IRCNetwork *> *listOfNetworks = [NSMutableArray array];

	NSDictionary *networkList = [TPCResourceManager dictionaryFromResources:@"IRCNetworks" cacheValue:NO];

	NSArray *networkNamesUnsorted = networkList.allKeys;

	NSArray *networkNamesSorted = [networkNamesUnsorted sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

	for (NSString *networkName in networkNamesSorted) {
		NSDictionary<NSString *, id> *networkConfiguration = networkList[networkName];

		  IRCNetwork *networkObject =
		[[IRCNetwork alloc] initWithNetworkNamed:networkName networkConfiguration:networkConfiguration];

		[listOfNetworks addObject:networkObject];
	}

	self.listOfNetworks = listOfNetworks;
}

- (nullable IRCNetwork *)networkNamed:(NSString *)networkName
{
	NSParameterAssert(networkName != nil);

	IRCNetwork *network =
	[self.listOfNetworks objectPassingTest:^BOOL(IRCNetwork *network, NSUInteger index, BOOL *stop) {
		return [network.networkName isEqualToStringIgnoringCase:networkName];
	}];

	return network;
}

- (nullable IRCNetwork *)networkWithServerAddress:(NSString *)serverAddress
{
	NSParameterAssert(serverAddress != nil);

	IRCNetwork *network =
	[self.listOfNetworks objectPassingTest:^BOOL(IRCNetwork *network, NSUInteger index, BOOL *stop) {
		return [network.serverAddress isEqualToStringIgnoringCase:serverAddress];
	}];

	return network;
}

@end

#pragma mark -

@implementation IRCNetwork

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithNetworkNamed:(NSString *)networkName networkConfiguration:(NSDictionary<NSString *, id> *)networkConfiguration
{
	NSParameterAssert(networkName != nil);
	NSParameterAssert(networkConfiguration != nil);

	if ((self = [super init])) {
		self.networkName = networkName;

		[self populateNetworkConfiguration:networkConfiguration];

		return self;
	}

	return nil;
}

- (void)populateNetworkConfiguration:(NSDictionary<NSString *, id> *)networkConfiguration
{
	NSParameterAssert(networkConfiguration != nil);

	self.serverAddress = networkConfiguration[@"serverAddress"];

	self.serverPort = [networkConfiguration unsignedShortForKey:@"serverPort"];

	self.prefersSecuredConnection = [networkConfiguration boolForKey:@"prefersSecuredConnection"];
}

@end

NS_ASSUME_NONNULL_END
