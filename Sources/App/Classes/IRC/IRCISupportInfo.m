/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual and/or Codeux Software, nor the names of
 *    its contributors may be used to endorse or promote products derived
 * 	  from this software without specific prior written permission.
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
#import "NSStringHelper.h"
#import "TLOLocalization.h"
#import "IRC.h"
#import "IRCClientPrivate.h"
#import "IRCModeInfo.h"
#import "IRCISupportInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _channelUserModeValue		100

@interface IRCISupportInfo ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, copy) NSArray<NSDictionary *> *cachedConfiguration;
@property (nonatomic, assign, readwrite) NSUInteger maximumAwayLength;
@property (nonatomic, assign, readwrite) NSUInteger maximumChannelNameLength;
@property (nonatomic, assign, readwrite) NSUInteger maximumKeyLength;
@property (nonatomic, assign, readwrite) NSUInteger maximumKickLength;
@property (nonatomic, assign, readwrite) NSUInteger maximumNicknameLength;
@property (nonatomic, assign, readwrite) NSUInteger maximumTopicLength;
@property (nonatomic, assign, readwrite) NSUInteger maximumModeCount;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *channelNamePrefixes;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *statusMessageModeSymbols;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSNumber *> *channelModes;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSArray *> *userModeSymbols;
@property (nonatomic, copy, readwrite, nullable) NSString *banExceptionModeSymbol;
@property (nonatomic, copy, readwrite, nullable) NSString *inviteExceptionModeSymbol;
@property (nonatomic, copy, readwrite, nullable) NSString *networkName;
@property (nonatomic, copy, readwrite, nullable) NSString *networkNameFormatted;
@end

@implementation IRCISupportInfo

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[self reset];
}

- (void)reset
{
	self.cachedConfiguration = @[];

	self.serverAddress = nil;

	self.networkName = nil;
	self.networkNameFormatted = nil;

	self.channelNamePrefixes = @[@"#"];

	self.maximumModeCount = TXMaximumNodesPerModeCommand;
	self.maximumNicknameLength = IRCProtocolDefaultNicknameMaximumLength;

	self.userModeSymbols = @{
		@"modeSymbols" : @[@"o", @"v"],
		@"characters" : @[@"@", @"+"]
	};

	self.channelModes = @{
		@"o" : @(_channelUserModeValue),
		@"v" : @(_channelUserModeValue)
	};

	self.statusMessageModeSymbols = @[];
}

- (void)processConfigurationData:(NSString *)configurationData
{
	NSParameterAssert(configurationData != nil);

	configurationData = configurationData.trim;

	if (configurationData.length == 0) {
		return;
	}

	IRCClient *client = self.client;

	NSMutableDictionary *configuration = [NSMutableDictionary dictionary];

	NSArray *segments = [configurationData componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	for (NSString *segment in segments) {
		if (segment.length == 0) { // Blank
			continue;
		}

		NSString *segmentKey = segment;
		NSString *segmentValue = nil;

		NSInteger equalSignPosition = [segment stringPosition:@"="];

		if (equalSignPosition > 0) {
			segmentKey = [segment substringToIndex:equalSignPosition];
			segmentValue = [segment substringAfterIndex:equalSignPosition];

			if (segmentValue.length == 0) {
				segmentValue = nil;
			}
		}

		if (segmentValue) {
			configuration[segmentKey] = segmentValue;
		} else {
			configuration[segmentKey] = @(YES);
		}

		if (segmentValue) {
			if ([segmentKey isEqualToStringIgnoringCase:@"AWAYLEN"]) {
				NSInteger awayLength = segmentValue.integerValue;

				if (awayLength > 0) {
					self.maximumAwayLength = awayLength;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"CHANMODES"]) {
				[self parseChannelModes:segmentValue];
			} else if ([segmentKey isEqualToStringIgnoringCase:@"CHANNELLEN"]) {
				NSInteger channelNameLength = segmentValue.integerValue;

				if (channelNameLength > 0) {
					self.maximumChannelNameLength = channelNameLength;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"CHANTYPES"]) {
				NSArray *channelNamePrefixes = segmentValue.characterStringBuffer;

				if (channelNamePrefixes.count > 0) {
					self.channelNamePrefixes = channelNamePrefixes;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"KEYLEN"]) {
				NSInteger maximumKeyLength = segmentValue.integerValue;

				if (maximumKeyLength > 0) {
					self.maximumKeyLength = maximumKeyLength;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"KICKLEN"]) {
				NSInteger maximumKickLength = segmentValue.integerValue;

				if (maximumKickLength > 0) {
					self.maximumKickLength = maximumKickLength;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"MODES"]) {
				NSInteger maximumModesCount = segmentValue.integerValue;

				if (maximumModesCount > 0) {
					self.maximumModeCount = maximumModesCount;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"NETWORK"]) {
				self.networkName = segmentValue;
				self.networkNameFormatted = TXTLS(@"IRC[8hg-7k]", segmentValue);
			} else if ([segmentKey isEqualToStringIgnoringCase:@"NICKLEN"]) {
				NSInteger maximumNicknameLength = segmentValue.integerValue;

				if (maximumNicknameLength > 0) {
					self.maximumNicknameLength = maximumNicknameLength;
				}
			} else if ([segmentKey isEqualToStringIgnoringCase:@"PREFIX"]) {
				[self parseUserModeSymbols:segmentValue];
			} else if ([segmentKey isEqualToStringIgnoringCase:@"STATUSMSG"]) {
				self.statusMessageModeSymbols = segmentValue.characterStringBuffer;
			} else if ([segmentKey isEqualToStringIgnoringCase:@"TOPICLEN"]) {
				NSInteger maximumTopicLength = segmentValue.integerValue;

				if (maximumTopicLength > 0) {
					self.maximumTopicLength = maximumTopicLength;
				}
			}
		}

		if ([segmentKey isEqualToStringIgnoringCase:@"EXCEPTS"]) {
			if (segmentValue.isModeSymbol) {
				self.banExceptionModeSymbol = segmentValue;
			} else {
				self.banExceptionModeSymbol = @"e";
			}
		} else if ([segmentKey isEqualToStringIgnoringCase:@"INVEX"]) {
			if (segmentValue.isModeSymbol) {
				self.inviteExceptionModeSymbol = segmentValue;
			} else {
				self.inviteExceptionModeSymbol = @"I";
			}
		} else if ([segmentKey isEqualToStringIgnoringCase:@"MONITOR"]) {
			// freenode advertises support for MONITOR but does not respond to command
			/*
			 Update as of May 30, 2018:

			 [17:25:55]  <milky>	Back in 2016 I hard coded MONITOR support disabled on freenode in
			 						my client because back then the network advertised it but didn't
			 						actually respond to it. Has that since changed?
			 [17:26:53]  <@Unit193>	milky: Depends on the server unfortunately.
			 [17:27:24]  <milky>	Unit193 so just keep it disabled, you think?
			 [17:27:39]  <@Unit193>	milky: Yeah, the server I'm on claims support.
			 */
			if ([self.serverAddress hasSuffix:@".freenode.net"]) {
				continue;
			}

			[client enableCapability:ClientIRCv3SupportedCapabilityMonitorCommand];
		} else if ([segmentKey isEqualToStringIgnoringCase:@"NAMESX"]) {
			if ([client isCapabilityEnabled:ClientIRCv3SupportedCapabilityMultiPrefix] == NO) {
				[client sendLine:@"PROTOCTL NAMESX"];

				[client enableCapability:ClientIRCv3SupportedCapabilityMultiPrefix];
			}
		} else if ([segmentKey isEqualToStringIgnoringCase:@"UHNAMES"]) {
			if ([client isCapabilityEnabled:ClientIRCv3SupportedCapabilityUserhostInNames] == NO) {
				[client sendLine:@"PROTOCTL UHNAMES"];

				[client enableCapability:ClientIRCv3SupportedCapabilityUserhostInNames];
			}
		} else if ([segmentKey isEqualToStringIgnoringCase:@"WATCH"]) {
			[client enableCapability:ClientIRCv3SupportedCapabilityWatchCommand];
		}
	} // while()

	self.cachedConfiguration = [self.cachedConfiguration arrayByAddingObject:configuration];
}

- (nullable NSString *)stringValueForConfiguration:(NSDictionary<NSString *, id> *)configuration
{
	NSParameterAssert(configuration != nil);

	/* This takes our cached configuration data and builds it into what it would look like if we
	 were to receive an actual 005. The only difference is this method formats each token that
	 is in our configuration cache to make them easier to see. We use bold for the tokens. 
	 This is pretty much only used in developer mode, but it could have other uses? */

	if (configuration.count == 0) {
		return nil;
	}

	NSMutableString *stringValue = [NSMutableString string];

	NSArray *sortedKeys = configuration.sortedDictionaryKeys;

	for (NSString *key in sortedKeys) {
		id value = configuration[key];

		if ([value isKindOfClass:[NSString class]]) {
			[stringValue appendFormat:@"\002%@\002=%@ ", key, value];
		} else {
			[stringValue appendFormat:@"\002%@ \002", key];
		}
	}

	return [stringValue copy];
}

- (nullable NSString *)stringValueForLastUpdate
{
	NSDictionary *configuration = self.cachedConfiguration.lastObject;

	if (configuration == nil) {
		return nil;
	}

	return [self stringValueForConfiguration:configuration];
}

- (NSArray<IRCModeInfo *> *)parseModes:(NSString *)modeString
{
	NSParameterAssert(modeString != nil);

	NSMutableArray<IRCModeInfo *> *modes = [NSMutableArray array];

	NSMutableString *modeStringMutable = [modeString mutableCopy];

	BOOL modeIsSet = NO;

	do {
		NSString *nextToken = modeStringMutable.token;

		if (nextToken.length == 0) {
			break;
		}

		UniChar nextCharacter = [nextToken characterAtIndex:0];

		if (nextCharacter != '+' && nextCharacter != '-') {
			continue;
		}

		modeIsSet = (nextCharacter == '+');

		nextToken = [nextToken substringFromIndex:1];

		for (NSUInteger i = 0; i < nextToken.length; i++) {
			nextCharacter = [nextToken characterAtIndex:i];

			if (nextCharacter == '-') {
				modeIsSet = NO;
			} else if (nextCharacter == '+') {
				modeIsSet = YES;
			} else {
				NSString *modeSymbol = [NSString stringWithUniChar:nextCharacter];

				IRCModeInfoMutable *mode =
				[[IRCModeInfoMutable alloc] initWithModeSymbol:modeSymbol modeIsSet:modeIsSet];

				if ([self modeHasParameter:modeSymbol whenModeIsSet:modeIsSet]) {
					mode.modeParameter = modeStringMutable.token;
				}

				[modes addObject:[mode copy]];
			}
		}
	} while (modeStringMutable.length > 0);

	return [modes copy];
}

- (void)parseUserModeSymbols:(NSString *)modeString
{
	NSParameterAssert(modeString != nil);

	// Format: (qaohv)~&@%+

	/* Perform validation on placement of parentheses */
	NSInteger openingParenthesesPosition = [modeString stringPosition:@"("];
	NSInteger closingParenthesesPosition = [modeString stringPosition:@")"];

	if (openingParenthesesPosition != 0 ||
		closingParenthesesPosition <= openingParenthesesPosition)
	{
		return;
	}

	/* Extract relevant information and ensure that they are equal length */
	NSString *modeSymbols = [modeString substringWithRange:NSMakeRange(1, (closingParenthesesPosition - 1))];

	NSString *characters = [modeString substringAfterIndex:closingParenthesesPosition];

	if (modeSymbols.length != characters.length) {
		return;
	}

	/* Begin processing modes */
	/* The mode symbols and characters are stored in separate arrays because
	 NSDictionary has no sense of order and the order of the user mode
	 symbols is very important to establish rank. */
	NSArray *modeSymbolsArray = modeSymbols.characterStringBuffer;
	NSArray *charactersArray = characters.characterStringBuffer;

	self.userModeSymbols = @{
		 @"modeSymbols" : modeSymbolsArray,
		 @"characters" : charactersArray
	};

	/* Update channel modes array so that we know these mode symbols are for user */
	NSMutableDictionary *channelModes = [self.channelModes mutableCopy];

	for (NSString *modeSymbol in modeSymbolsArray) {
		channelModes[modeSymbol] = @(_channelUserModeValue);
	}

	self.channelModes = channelModes;
}

- (BOOL)modeHasParameter:(NSString *)modeSymbol whenModeIsSet:(BOOL)whenModeIsSet
{
	NSParameterAssert(modeSymbol != nil);

	// Input: CHANMODES=A,B,C,D
	//
	// A = Always has a parameter.			Index: 1
	// B = Always has a parameter.			Index: 2
	// C = Only has a parameter when set.	Index: 3
	// D = Never has a parameter.			Index: 4

	NSUInteger modeIndex = [self.channelModes unsignedIntegerForKey:modeSymbol];

	if (modeIndex == 1 || modeIndex == 2 || modeIndex == _channelUserModeValue) {
		return YES;
	} else if (modeIndex == 3) {
		return whenModeIsSet;
	}

	return NO;
}

- (void)parseChannelModes:(NSString *)modeString
{
	NSParameterAssert(modeString != nil);

	// Input: CHANMODES=A,B,C,D
	//
	// A = Always has a parameter.			Index: 1
	// B = Always has a parameter.			Index: 2
	// C = Only has a parameter when set.	Index: 3
	// D = Never has a parameter.			Index: 4

	NSMutableDictionary *channelModes = [self.channelModes mutableCopy];

	NSArray *modes = [modeString split:@","];

	for (NSUInteger i = 0; i < modes.count; i++) {
		NSString *modeSet = modes[i];

		for (NSUInteger j = 0; j < modeSet.length; j++) {
			NSString *modeSymbol = [modeSet stringCharacterAtIndex:j];

			channelModes[modeSymbol] = @(i + 1);
		}
	}

	self.channelModes = channelModes;
}

- (nullable NSString *)userPrefixForModeSymbol:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	NSArray *modeSymbols = self.userModeSymbols[@"modeSymbols"];

	NSUInteger modeSymbolIndex = [modeSymbols indexOfObject:modeSymbol];

	if (modeSymbolIndex == NSNotFound) {
		return 0;
	}

	NSArray *characters = self.userModeSymbols[@"characters"];

	return characters[modeSymbolIndex];
}

- (BOOL)modeSymbolIsUserPrefix:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	return ([self userPrefixForModeSymbol:modeSymbol] != nil);
}

- (nullable NSString *)modeSymbolForUserPrefix:(NSString *)character
{
	NSParameterAssert(character != nil);

	NSArray *characters = self.userModeSymbols[@"characters"];

	NSUInteger characterIndex = [characters indexOfObject:character];

	if (characterIndex == NSNotFound) {
		return nil;
	}

	NSArray *modeSymbols = self.userModeSymbols[@"modeSymbols"];

	return modeSymbols[characterIndex];
}

- (BOOL)characterIsUserPrefix:(NSString *)character
{
	NSParameterAssert(character != nil);

	return ([self modeSymbolForUserPrefix:character] != nil);
}

- (NSUInteger)rankForUserPrefixWithMode:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	NSArray *modeSymbols = self.userModeSymbols[@"modeSymbols"];

	NSUInteger modeSymbolIndex = [modeSymbols indexOfObject:modeSymbol];

	if (modeSymbolIndex == NSNotFound) {
		return 0;
	}

	return (IRCISupportInfoHighestUserPrefixRank - modeSymbolIndex);
}

- (NSString *)extractStatusMessagePrefixFromChannelNamed:(NSString *)channel
{
	NSArray *characters = self.statusMessageModeSymbols;

	return [self _extractCharacters:characters fromChannelNamed:channel];
}

- (NSString *)_extractCharacters:(NSArray<NSString *> *)characters fromChannelNamed:(NSString *)channel
{
	NSParameterAssert(characters != nil);
	NSParameterAssert(channel != nil);

	if (channel.length < 2) {
		return @"";
	}

	NSArray *channelNamePrefixes = self.channelNamePrefixes;

	for (NSString *character in characters) {
		if ([channel hasPrefix:character] == NO) {
			continue;
		}

		NSString *nextCharacter = [channel stringCharacterAtIndex:1];

		if ([channelNamePrefixes containsObject:nextCharacter]) {
			return character;
		}
	}

	return @"";
}

- (IRCModeInfo *)createModeWithSymbol:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	return [[IRCModeInfo alloc] initWithModeSymbol:modeSymbol];
}

- (IRCModeInfo *)createModeWithSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet modeParameter:(nullable NSString *)modeParameter
{
	NSParameterAssert(modeSymbol != nil);

	return [[IRCModeInfo alloc] initWithModeSymbol:modeSymbol modeIsSet:modeIsSet modeParameter:modeParameter];
}

- (BOOL)configurationReceived
{
	return (self.cachedConfiguration.count > 0);
}

- (BOOL)isListSupported:(IRCISupportInfoListType)listType
{
	return ([self modeSymbolForList:listType] != nil);
}

- (nullable NSString *)modeSymbolForList:(IRCISupportInfoListType)listType
{
	switch (listType) {
		case IRCISupportInfoListTypeBan:
		{
			return @"b";
		}
		case IRCISupportInfoListTypeBanException:
		{
			return self.banExceptionModeSymbol;
		}
		case IRCISupportInfoListTypeInviteException:
		{
			return self.inviteExceptionModeSymbol;
		}
		case IRCISupportInfoListTypeQuiet:
		{
			/* +q is used by some servers as the user mode for channel owner.
			 If this mode is a user mode, then hide the menu item. */
			if ([self modeSymbolIsUserPrefix:@"q"]) {
				return nil;
			}

			return @"q";
		}
		default:
		{
			return nil;
		}
	} // switch
}

- (nullable NSString *)statusMessagePrefixForModeSymbol:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	NSString *character = [self userPrefixForModeSymbol:modeSymbol];

	if (character == nil) {
		return nil;
	}

	if ([self.statusMessageModeSymbols containsObject:character] == NO) {
		return nil;
	}

	return character;
}

@end

NS_ASSUME_NONNULL_END
