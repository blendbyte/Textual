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
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCModeInfo.h"
#import "IRCChannelModePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCChannelMode ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, weak) IRCChannel *channel;
@property (nonatomic, copy, readwrite) IRCChannelModeContainer *modes;
@end

@interface IRCChannelModeContainer ()
@property (nonatomic, weak) IRCISupportInfo *supportInfo;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IRCModeInfo *> *modeObjects;
@property (readonly, copy) NSArray<NSString *> *unwantedModes;

- (instancetype)initWithSupportInfo:(IRCISupportInfo *)supportInfo;
@end

@implementation IRCChannelMode

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super init])) {
		self.client = channel.associatedClient;
		self.channel = channel;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self->_modes = [[IRCChannelModeContainer alloc] initWithSupportInfo:self.client.supportInfo];
}

- (NSArray<IRCModeInfo *> *)updateModes:(NSString *)modeString
{
	NSParameterAssert(modeString != nil);

	IRCISupportInfo *supportInfo = self.client.supportInfo;

	NSArray *modes = [supportInfo parseModes:modeString];

	[self.modes applyModes:modes];

	return modes;
}

- (NSString *)getChangeCommand:(IRCChannelModeContainer *)modes
{
	NSParameterAssert(modes != nil);

	NSDictionary *modesSetOld = self.modes.modes;

	NSDictionary *modesSetNew = modes.modes;

	NSMutableString *modeAddString = [NSMutableString string];
	NSMutableString *modeRemoveString = [NSMutableString string];
	NSMutableString *modeParamString = [NSMutableString string];

	/* Look over the set of modes that are currently set. If a mode is present
	 in that set, but not in the new set, then mark that mode for removal. */
	[modesSetOld enumerateKeysAndObjectsUsingBlock:^(NSString *modeSymbol, IRCModeInfo *mode, BOOL *stop) {
		if (modesSetNew[modeSymbol] != nil) {
			return;
		}

		if (modeRemoveString.length == 0) {
			[modeRemoveString appendFormat:@"-%@", modeSymbol];
		} else {
			[modeRemoveString appendString:modeSymbol];
		}
	}];

	/* Look over the new set of modes and compare them to the old set.
	 If a mode has changed (check for equality), then perform action. */
	[modesSetNew enumerateKeysAndObjectsUsingBlock:^(NSString *modeSymbol, IRCModeInfo *mode, BOOL *stop) {
		IRCModeInfo *modeOld = modesSetOld[modeSymbol];

		if ([mode isEqual:modeOld]) {
			return;
		}

		if (mode.modeIsSet) {
			if (modeAddString.length == 0) {
				[modeAddString appendFormat:@"+%@", modeSymbol];
			} else {
				[modeAddString appendString:modeSymbol];
			}
		} else {
			if (modeRemoveString.length == 0) {
				[modeRemoveString appendFormat:@"-%@", modeSymbol];
			} else {
				[modeRemoveString appendString:modeSymbol];
			}
		}

		NSString *modeParameter = mode.modeParameter;

		if (modeParameter.length == 0) {
			return;
		}

		[modeParamString appendFormat:@" %@", modeParameter];
	}];

	return [NSString stringWithFormat:@"%@%@%@", modeRemoveString, modeAddString, modeParamString];
}

- (void)clear
{
	[self.modes clear];
}

- (BOOL)modeIsDefined:(NSString *)modeSymbol
{
	return [self.modes modeIsDefined:modeSymbol];
}

- (nullable IRCModeInfo *)modeInfoFor:(NSString *)modeSymbol
{
	return [self.modes modeInfoFor:modeSymbol];
}

- (NSString *)stringWithMaskedPassword:(BOOL)maskPassword
{
	NSMutableString *modeSetString = [NSMutableString string];
	NSMutableString *modeParamString = [NSMutableString string];

	NSDictionary *modes = self.modes.modes;

	NSArray *modesSorted = modes.sortedDictionaryKeys;

	for (NSString *modeSymbol in modesSorted) {
		IRCModeInfo *mode = modes[modeSymbol];

		if (mode.modeIsSet == NO) {
			continue;
		}

		if (modeSetString.length == 0) {
			[modeSetString appendFormat:@"+%@", modeSymbol];
		} else {
			[modeSetString appendString:modeSymbol];
		}

		NSString *modeParameter = mode.modeParameter;

		if (modeParameter.length == 0) {
			continue;
		}

		if ([modeSymbol isEqualToString:@"k"] && maskPassword) {
			[modeParamString appendFormat:@" ******"];
		} else {
			[modeParamString appendFormat:@" %@", modeParameter];
		}
	}

	return [modeSetString stringByAppendingString:modeParamString];
}

- (NSString *)string
{
	return [self stringWithMaskedPassword:NO];
}

- (NSString *)stringWithMaskedPassword
{
	return [self stringWithMaskedPassword:YES];
}

@end

#pragma mark -

@implementation IRCChannelModeContainer

- (instancetype)initWithSupportInfo:(IRCISupportInfo *)supportInfo
{
	NSParameterAssert(supportInfo != nil);

	if ((self = [super init])) {
		self.supportInfo = supportInfo;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.modeObjects = [NSMutableDictionary dictionary];
}

- (void)clear
{
	@synchronized(self.modeObjects) {
		[self.modeObjects removeAllObjects];
	}
}

- (NSDictionary<NSString *, IRCModeInfo *> *)modes
{
	@synchronized(self.modeObjects) {
		return [self.modeObjects copy];
	}
}

- (NSArray<NSString *> *)unwantedModes
{
	IRCISupportInfo *supportInfo = self.supportInfo;

	/* Using some random value in place of mode if there is none
	 is easier than creating a mutable array with four if statements. */
	return @[
		 /* ban */			 	(([supportInfo modeSymbolForList:IRCISupportInfoListTypeBan]) ?: @"not supported: b"),
		 /* ban exception */	(([supportInfo modeSymbolForList:IRCISupportInfoListTypeBanException]) ?: @"not supported: e"),
		 /* invite exception */	(([supportInfo modeSymbolForList:IRCISupportInfoListTypeInviteException]) ?: @"not supported: I"),
		 /* quiet */			(([supportInfo modeSymbolForList:IRCISupportInfoListTypeQuiet]) ?: @"not supported: q")
	];
}

- (BOOL)modeIsPermitted:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	if ([self.unwantedModes containsObject:modeSymbol]) {
		return NO;
	}

	if ([self.supportInfo modeSymbolIsUserPrefix:modeSymbol]) {
		return NO;
	}

	return YES;
}

- (BOOL)modeIsDefined:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	return (self.modes[modeSymbol] != nil);
}

- (nullable IRCModeInfo *)modeInfoFor:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol != nil);

	@synchronized (self.modeObjects) {
		IRCModeInfo *mode = self.modeObjects[modeSymbol];

		if (mode) {
			return mode;
		}

		if ([self modeIsPermitted:modeSymbol] == NO) {
			return nil;
		}

		mode = [[IRCModeInfo alloc] initWithModeSymbol:modeSymbol];

		self.modeObjects[modeSymbol] = mode;

		return mode;
	}
}

- (void)applyModes:(NSArray<IRCModeInfo *> *)modes
{
	NSParameterAssert(modes != nil);

	for (IRCModeInfo *mode in modes) {
		[self changeMode:mode.modeSymbol
			   modeIsSet:mode.modeIsSet
		   modeParameter:mode.modeParameter];
	}
}

- (void)changeMode:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet
{
	[self changeMode:modeSymbol modeIsSet:modeIsSet modeParameter:nil];
}

- (void)changeMode:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet modeParameter:(nullable NSString *)modeParameter
{
	NSParameterAssert(modeSymbol != nil);

	IRCModeInfo *mode = [self modeInfoFor:modeSymbol];

	if (mode == nil) {
		return;
	}

	IRCModeInfoMutable *modeMutable = [mode mutableCopy];

	modeMutable.modeSymbol = modeSymbol;
	modeMutable.modeIsSet = modeIsSet;
	modeMutable.modeParameter = modeParameter;

	@synchronized (self.modeObjects) {
		self.modeObjects[modeSymbol] = [modeMutable copy];
	}
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	IRCChannelModeContainer *object =
	[[IRCChannelModeContainer alloc] initWithSupportInfo:self.supportInfo];

	/* modeObjects contain immutable objects which means
	 we don't have to copy the objects themselves. */
	/* If we ever modify IRCModeInfo internal logic to ever
	 modify the contents of the object after initialization,
	 then we should perform a deep copy here. */
	object.modeObjects = [self.modeObjects mutableCopy];

	return object;
}

@end

NS_ASSUME_NONNULL_END
