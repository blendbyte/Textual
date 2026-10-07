/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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
#import "IRCClient.h"
#import "IRCISupportInfo.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCChannelUserInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCChannelUser ()
@property (atomic, strong, readwrite) IRCUser *user;
@property (readonly) IRCClient *client;
@property (readonly) NSString *highestRankedUserMode;
@end

@implementation IRCChannelUser

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithUser:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	if ((self = [super init])) {
		self.user = user;

		[self prepareInitialState];

		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self->_lastWeightFade = CFAbsoluteTimeGetCurrent();

	self->_creationTime = [[NSDate date] timeIntervalSince1970];
}

- (void)populateDefaultsPostflight
{
	SetVariableIfNil(self->_modes, @"")
}

- (void)changeUserToUser:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	self.user = user;
}

- (IRCClient *)client
{
	return self.user.client;
}

- (BOOL)userModesContainsMode:(NSString *)mode
{
	return [self.modes contains:mode];
}

- (NSString *)highestRankedUserMode
{
	NSString *modes = self.modes;

	if (modes.length == 0) {
		return modes;
	}

	return [modes stringCharacterAtIndex:0];
}

- (NSString *)mark
{
	IRCISupportInfo *supportInfo = self.client.supportInfo;

	NSString *mode = self.highestRankedUserMode;

	NSString *mark = [supportInfo userPrefixForModeSymbol:mode];

	if (mark) {
		return mark;
	}

	return @"";
}

- (NSUInteger)channelRank
{
	IRCISupportInfo *supportInfo = self.client.supportInfo;

	NSString *mode = self.highestRankedUserMode;

	return [supportInfo rankForUserPrefixWithMode:mode];
}

- (BOOL)isOp
{
	return [self.modes containsCharacters:@"qOao"];
}

- (BOOL)isHalfOp 
{
	return [self.modes containsCharacters:@"qOaoh"];
}

- (IRCUserRank)rank
{
	NSString *mode = self.highestRankedUserMode;

	return [self rankForModeSymbol:mode];
}

- (IRCUserRank)ranks
{
	IRCUserRank ranks = 0;

	NSString *modes = self.modes;

	for (NSUInteger i = 0; i < modes.length; i++) {
		NSString *mode = [modes stringCharacterAtIndex:i];

		IRCUserRank rank = [self rankForModeSymbol:mode];

		if (rank != IRCUserRankNone) {
			ranks |= rank;
		}
	}

	if (ranks == 0) {
		ranks |= IRCUserRankNone;
	}

	return ranks;
}

- (IRCUserRank)rankForModeSymbol:(nullable NSString *)modeSymbol
{
	if (modeSymbol == nil) {
		return IRCUserRankNone;
	}

	if ([modeSymbol isEqualToString:@"y"] ||
		[modeSymbol isEqualToString:@"Y"])
	{
		return IRCUserRankIRCopByMode;
	}
	else if ([modeSymbol isEqualToString:@"q"] ||
			 [modeSymbol isEqualToString:@"O"])
	{
		return IRCUserRankChannelOwner;
	} else if ([modeSymbol isEqualToString:@"a"]) {
		return IRCUserRankSuperOperator;
	} else if ([modeSymbol isEqualToString:@"o"]) {
		return IRCUserRankNormalOperator;
	} else if ([modeSymbol isEqualToString:@"h"]) {
		return IRCUserRankHalfOperator;
	} else if ([modeSymbol isEqualToString:@"v"]) {
		return IRCUserRankVoiced;
	}

	return IRCUserRankNone;
}

- (double)totalWeight
{
	[self decayConversation];

	return (self->_incomingWeight + self->_outgoingWeight);
}

- (void)outgoingConversation
{
	double change = ((lrint(self->_outgoingWeight) == 0) ? 20 : 5);

	self->_outgoingWeight += change;
}

- (void)incomingConversation
{
	double change = ((lrint(self->_incomingWeight) == 0) ? 100 : 20);

	self->_incomingWeight += change;
}

- (void)conversation
{
	double change = ((lrint(self->_incomingWeight) == 0) ? 4 : 1);

	self->_incomingWeight += change;
}

- (void)decayConversation
{
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

	double minutes = ((now - self->_lastWeightFade) / 60);

	if (minutes > 1) {
		self->_lastWeightFade = now;

		if (self->_incomingWeight > 0) {
			self->_incomingWeight /= pow(2, minutes);
		}

		if (self->_outgoingWeight > 0) {
			self->_outgoingWeight /= pow(2, minutes);
		}
	}
}

- (NSComparisonResult)compareUsingWeights:(IRCChannelUser *)other
{
	NSParameterAssert(other != nil);

	double localWeight = self.totalWeight;

	double remoteWeight = other.totalWeight;

	if (localWeight > remoteWeight) {
		return NSOrderedAscending;
	} else if (localWeight < remoteWeight) {
		return NSOrderedDescending;
	}

	return [self compareUsingRank:other];
}

- (NSComparisonResult)compareUsingRank:(IRCChannelUser *)other
{
	NSParameterAssert(other != nil);

	BOOL favorIRCop = [TPCPreferences memberListSortFavorsServerStaff];

	if (favorIRCop && self.user.isIRCop && other.user.isIRCop == NO) {
		return NSOrderedAscending;
	} else if (favorIRCop && self.user.isIRCop == NO && other.user.isIRCop) {
		return NSOrderedDescending;
	}

	NSNumber *localRank = @([self channelRank]);

	NSNumber *remoteRank = @([other channelRank]);

	NSComparisonResult normalRank = [localRank compare:remoteRank];

	NSComparisonResult invertedRank = NSInvertedComparisonResult(normalRank);

	if (invertedRank == NSOrderedSame) {
		return [self.user.nickname caseInsensitiveCompare:other.user.nickname];
	}

	return invertedRank;
}

+ (NSComparator)channelRankComparator
{
	return [^(IRCChannelUser *object1, IRCChannelUser *object2) {
		return [object1 compareUsingRank:object2];
	} copy];
}

+ (NSComparator)nicknameLengthComparator
{
	return [^(IRCChannelUser *object1, IRCChannelUser *object2) {
		return (object1.user.nickname.length <=
				object2.user.nickname.length);
	} copy];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<IRCChannelUser %@%@>", self.mark, self.user.nickname];
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[IRCChannelUser class]] == NO) {
		return NO;
	}

	IRCChannelUser *objectCast = (IRCChannelUser *)object;

	return (self.user == objectCast.user &&

			((self.modes == nil && objectCast.modes == nil) ||
			 [self.modes isEqualToString:objectCast.modes]));
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCChannelUser *object = [self allocForCopyAsMutable:mutableCopy];

	object->_user = self->_user;

	object->_modes = self->_modes;

	object->_creationTime = self->_creationTime;

	object->_incomingWeight = self->_incomingWeight;
	object->_outgoingWeight = self->_outgoingWeight;
	object->_lastWeightFade = self->_lastWeightFade;

	return [object initOnCopy];
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [IRCChannelUserMutable self];
}

@end

#pragma mark -

@implementation IRCChannelUser (IRCUserRelationsPrivate)

- (void)disassociateWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	[self.user disassociateUserWithChannel:channel];
}

- (void)associateWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	[self.user associateUser:self withChannel:channel];
}

@end

#pragma mark -

@implementation IRCChannelUserMutable

@dynamic modes;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [IRCChannelUser self];
}

- (void)setModes:(NSString *)modes
{
	NSParameterAssert(modes != nil);

	if (self->_modes != modes) {
		self->_modes = [modes copy];
	}
}

@end

NS_ASSUME_NONNULL_END
