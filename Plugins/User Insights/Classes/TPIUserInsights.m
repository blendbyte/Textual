/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2013 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TPIUserInsights.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TPIUserInsights

#pragma mark -
#pragma mark User Input

/* The channel the command was entered in (the selection may have moved on) */
- (void)userInputCommandInvokedOnClient:(IRCClient *)client
							  inChannel:(nullable IRCChannel *)channel
						  commandString:(NSString *)commandString
						  messageString:(NSString *)messageString
{
	/* Every command needs a channel or query; there is none in a server console */
	if (channel == nil) {
		return;
	}

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self _userInputCommandInvokedOnClient:client
									 inChannel:channel
								 commandString:commandString
								 messageString:messageString];
	});
}

- (void)_userInputCommandInvokedOnClient:(IRCClient *)client
							   inChannel:(IRCChannel *)channel
						   commandString:(NSString *)commandString
						   messageString:(NSString *)messageString
{
	/* We can brag in private messages so add above if statement */
	if ([commandString isEqualToString:@"BRAG"]) {
		[self bragInChannel:channel onClient:client];

		return;
	}

	if (channel.isChannel == NO) {
		return;
	}

	messageString = messageString.trim;

	if ([commandString isEqualToString:@"CLONES"]) {
		[self findAllClonesInChannel:channel onClient:client];
	} else if ([commandString isEqualToString:@"NAMEL"]) {
		[self buildListOfUsersInChannel:channel onClient:client parameters:messageString];
	} else if ([commandString isEqualToString:@"FINDUSER"]) {
		[self findAllUsersMatchingString:messageString inChannel:channel onClient:client];
	}
}

- (NSArray *)subscribedUserInputCommands
{
	return @[@"clones", @"namel", @"finduser", @"brag"];
}

- (void)buildListOfUsersInChannel:(IRCChannel *)channel onClient:(IRCClient *)client parameters:(NSString *)parameters
{
	NSParameterAssert(channel != nil);
	NSParameterAssert(client != nil);
	NSParameterAssert(parameters != nil);

	NSArray *memberList = channel.memberList;

	if (memberList.count == 0) {
		[client printDebugInformation:TPILocalizedString(@"BasicLanguage[5dx-rs]", channel.name) inChannel:channel];

		return;
	}

	/* Process parameters */
	BOOL displayRank = NO;
	BOOL sortByRank = NO;

	if ([parameters hasPrefix:@"-"]) {
		NSString *flagsString = [parameters substringFromIndex:1];

		NSArray *flags = flagsString.characterStringBuffer;

		displayRank = [flags containsObject:@"d"];
		sortByRank = [flags containsObject:@"r"];
	}

	/* -memberList returns a list sorted by rank by default.
	 If we are not sorting by rank, then we have to first get
	 the member list then sort it another way. */
	if (sortByRank == NO) {
		/* Sort user objects alphabetically by comparing nicknames */

		memberList =
		[memberList sortedArrayUsingComparator:^NSComparisonResult(IRCChannelUser *member1, IRCChannelUser *member2) {
			NSString *nickname1 = member1.user.nickname;
			NSString *nickname2 = member2.user.nickname;

			return [nickname1 caseInsensitiveCompare:nickname2];
		}];
	}

	/* Join user objects into string */
	NSMutableString *resultString = [NSMutableString string];

	for (IRCChannelUser *member in memberList) {
		if (displayRank) {
			[resultString appendString:member.mark];
		}

		[resultString appendString:member.user.nickname];

		[resultString appendString:@" "];
	}

	[client printDebugInformation:[resultString copy] inChannel:channel];
}

- (void)findAllUsersMatchingString:(NSString *)matchString inChannel:(IRCChannel *)channel onClient:(IRCClient *)client
{
	NSParameterAssert(matchString != nil);
	NSParameterAssert(channel != nil);
	NSParameterAssert(client != nil);

	BOOL hasSearchCondition = (matchString.length > 0);

	NSArray *memberList = channel.memberList;

	if (memberList.count == 0) {
		if (hasSearchCondition) {
			[client printDebugInformation:TPILocalizedString(@"BasicLanguage[n1j-tp]", channel.name, matchString) inChannel:channel];
		} else {
			[client printDebugInformation:TPILocalizedString(@"BasicLanguage[1ab-27]", channel.name) inChannel:channel];
		}

		return;
	}

	NSMutableArray<IRCChannelUser *> *membersMatched = [NSMutableArray array];

	for (IRCChannelUser *member in memberList) {
		NSString *hostmask = member.user.hostmask;

		if (hostmask == nil) {
			continue;
		}

		if (hasSearchCondition) {
			if ([hostmask containsIgnoringCase:matchString] == NO) {
				continue;
			}
		}

		[membersMatched addObject:member];
	}

	if (membersMatched.count <= 0) {
		if (hasSearchCondition) {
			[client printDebugInformation:TPILocalizedString(@"BasicLanguage[n1j-tp]", channel.name, matchString) inChannel:channel];
		} else {
			[client printDebugInformation:TPILocalizedString(@"BasicLanguage[1ab-27]", channel.name) inChannel:channel];
		}

		return;
	}

	if (hasSearchCondition) {
		[client printDebugInformation:TPILocalizedString(@"BasicLanguage[oq7-mg]", membersMatched.count, channel.name, matchString) inChannel:channel];
	} else {
		[client printDebugInformation:TPILocalizedString(@"BasicLanguage[nn7-6s]", membersMatched.count, channel.name) inChannel:channel];
	}

	[membersMatched sortUsingComparator:^NSComparisonResult(IRCChannelUser *member1, IRCChannelUser *member2) {
		NSString *nickname1 = member1.user.nickname;
		NSString *nickname2 = member2.user.nickname;

		return [nickname1 caseInsensitiveCompare:nickname2];
	}];

	for (IRCChannelUser *member in membersMatched) {
		NSString *resultString = [NSString stringWithFormat:@"%@ -> %@", member.user.nickname, member.user.hostmask];

		[client printDebugInformation:resultString inChannel:channel];
	}
}

- (void)findAllClonesInChannel:(IRCChannel *)channel onClient:(IRCClient *)client
{
	NSParameterAssert(channel != nil);
	NSParameterAssert(client != nil);

	/* Grown in place: a new array per clone made big channels quadratic */
	NSMutableDictionary<NSString *, NSMutableArray *> *members = [NSMutableDictionary dictionary];

	/* Populate our list by matching an array of users to that of the address. */
	for (IRCChannelUser *member in channel.memberList) {
		NSString *address = member.user.address;

		if (address == nil) {
			continue;
		}

		NSString *nickname = member.user.nickname;

		NSMutableArray *clones = members[address];

		if (clones) {
			[clones addObject:nickname];
		} else {
			members[address] = [NSMutableArray arrayWithObject:nickname];
		}
	}

	/* Filter the new list by removing users with less than two matches. */
	NSArray *memberHosts = members.allKeys;

	for (NSString *memberHost in memberHosts) {
		NSArray *clones = [members arrayForKey:memberHost];

		if (clones.count < 2) {
			[members removeObjectForKey:memberHost];
		}
	}

	/* No clones found */
	if (members.count == 0) {
		[client printDebugInformation:TPILocalizedString(@"BasicLanguage[gxq-47]") inChannel:channel];

		return;
	}

	/* Build result string */
	[client printDebugInformation:TPILocalizedString(@"BasicLanguage[iaa-5v]", members.count, channel.name) inChannel:channel];

	for (NSString *memberHost in members) {
		NSArray *clones = [members arrayForKey:memberHost];

		NSString *clonesString = [clones componentsJoinedByString:@", "];

		NSString *resultString = [NSString stringWithFormat:@"*!*@%@ -> %@", memberHost, clonesString];

		[client printDebugInformation:resultString inChannel:channel];
	}
}

- (void)appendPluralOrSingular:(NSMutableString *)resultString valueToken:(NSString *)valueToken value:(NSInteger)value
{
	NSParameterAssert(resultString != nil);
	NSParameterAssert(valueToken != nil);

	NSString *valueKey = nil;

	if (value == 1) {
		valueKey = [NSString stringWithFormat:@"BasicLanguage[%@-1]", valueToken];
	} else {
		valueKey = [NSString stringWithFormat:@"BasicLanguage[%@-2]", valueToken];
	}

	[resultString appendString:TPILocalizedString(valueKey, value)];
}

- (void)bragInChannel:(IRCChannel *)channel onClient:(IRCClient *)client
{
	NSParameterAssert(channel != nil);
	NSParameterAssert(client != nil);

	NSUInteger operCount = 0;
	NSUInteger channelOpCount = 0;
	NSUInteger channelHalfopCount = 0;
	NSUInteger channelVoiceCount = 0;
	NSUInteger channelCount = 0;
	NSUInteger networkCount = 0;
	NSUInteger powerOverCount = 0;

	for (IRCClient *cl in worldController().clientList) {
		if (cl.isConnected == NO) {
			continue;
		}

		networkCount++;

		IRCUser *localUser = cl.myself;

		if (cl.userIsIRCop || localUser.isIRCop) {
			operCount++;
		}

		/* A set: an array was searched for every member of every channel */
		NSMutableSet<NSString *> *trackedUsers = [NSMutableSet new];

		for (IRCChannel *ch in cl.channelList) {
			if (ch.isActive == NO || ch.isChannel == NO) {
				continue;
			}

			channelCount += 1;

			IRCChannelUser *myself = [ch findMember:cl.userNickname];

			IRCUserRank myRanks = myself.ranks;

			BOOL IHaveModeQ = ((myRanks & IRCUserRankChannelOwner) == IRCUserRankChannelOwner);
			BOOL IHaveModeA = ((myRanks & IRCUserRankSuperOperator) == IRCUserRankSuperOperator);
			BOOL IHaveModeO = ((myRanks & IRCUserRankNormalOperator) == IRCUserRankNormalOperator);
			BOOL IHaveModeH = ((myRanks & IRCUserRankHalfOperator) == IRCUserRankHalfOperator);
			BOOL IHaveModeV = ((myRanks & IRCUserRankVoiced) == IRCUserRankVoiced);

			if (IHaveModeQ || IHaveModeA || IHaveModeO) {
				channelOpCount++;
			} else if (IHaveModeH) {
				channelHalfopCount++;
			} else if (IHaveModeV) {
				channelVoiceCount++;
			}

			for (IRCChannelUser *member in ch.memberList) {
				if ([member isEqual:myself]) {
					continue;
				}

				BOOL addUser = NO;

				IRCUserRank userRanks = member.ranks;

				BOOL UserHasModeQ = ((userRanks & IRCUserRankChannelOwner) == IRCUserRankChannelOwner);
				BOOL UserHasModeA = ((userRanks & IRCUserRankSuperOperator) == IRCUserRankSuperOperator);
				BOOL UserHasModeO = ((userRanks & IRCUserRankNormalOperator) == IRCUserRankNormalOperator);
				BOOL UserHasModeH = ((userRanks & IRCUserRankHalfOperator) == IRCUserRankHalfOperator);

				if (cl.userIsIRCop && member.user.isIRCop == NO) {
					addUser = YES;
				} else if (IHaveModeQ && UserHasModeQ == NO) {
					addUser = YES;
				} else if (IHaveModeA && UserHasModeQ == NO && UserHasModeA == NO) {
					addUser = YES;
				} else if (IHaveModeO && UserHasModeQ == NO && UserHasModeA == NO && UserHasModeO == NO) {
					addUser = YES;
				} else if (IHaveModeH && UserHasModeQ == NO && UserHasModeA == NO && UserHasModeO == NO && UserHasModeH == NO) {
					addUser = YES;
				}

				if (addUser) {
					NSString *nickname = member.user.nickname;

					if ([trackedUsers containsObject:nickname] == NO) {
						[trackedUsers addObject:nickname];

						powerOverCount++;
					}
				}
			}
		}
	}

	NSMutableString *resultString = [NSMutableString string];

	[self appendPluralOrSingular:resultString valueToken:@"30l-sx" value:channelCount];
	[self appendPluralOrSingular:resultString valueToken:@"rks-0t" value:networkCount];

	if (powerOverCount == 0) {
		[resultString appendString:TPILocalizedString(@"BasicLanguage[jpi-po]")];
	} else {
		[self appendPluralOrSingular:resultString valueToken:@"614-ac" value:operCount];
		[self appendPluralOrSingular:resultString valueToken:@"qne-b5" value:channelOpCount];
		[self appendPluralOrSingular:resultString valueToken:@"431-yv" value:channelHalfopCount];
		[self appendPluralOrSingular:resultString valueToken:@"x1m-jp" value:channelVoiceCount];
		[self appendPluralOrSingular:resultString valueToken:@"ny4-wd" value:powerOverCount];
	}

	[client sendPrivmsg:[resultString copy] toChannel:channel];
}

@end

NS_ASSUME_NONNULL_END
