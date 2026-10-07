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
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TDCChannelSpotlightSearchResultPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelSpotlightSearchResult ()
@property (nonatomic, weak, readwrite) IRCChannel *channel;
@property (nonatomic, copy, readwrite) NSNumber *distance;
@end

@implementation TDCChannelSpotlightSearchResult

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super init])) {
		self.channel = channel;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.distance = @(0.0);
}

- (NSComparisonResult)compare:(TDCChannelSpotlightSearchResult *)other
{
	double localDistance = self.distance.doubleValue;

	double remoteDistance = other.distance.doubleValue;

	if (localDistance > remoteDistance) {
		return NSOrderedAscending;
	} else if (localDistance < remoteDistance) {
		return NSOrderedDescending;
	}

	return NSOrderedSame;
}

- (void)recalculateDistanceWith:(NSString *)searchString
{
	NSParameterAssert(searchString != nil);

	if (searchString.length == 0) {
		self.distance = @(0.0);

		return;
	}

	NSString *searchableString = self.channel.name;

	double distance = [searchableString compareWithWord:searchString lengthPenaltyWeight:1.0];

	self.distance = @(distance);
}

- (NSString *)clientId
{
	return self.channel.associatedClient.uniqueIdentifier;
}

@end

NS_ASSUME_NONNULL_END
