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

#import "TPCPreferencesLocal.h"
#import "TPCResourceManager.h"
#import "IRCCommandIndexPrivate.h"
#import "IRCSendingMessage.h"

NS_ASSUME_NONNULL_BEGIN

/* Implemented in IRCSendingMessage.m */
@interface IRCSendingMessage (IRCCommandIndex)
+ (NSDictionary<NSString *, NSNumber *> *)textParameterPositions;
@end

#define _reservedSlotDictionaryKey			@"Reserved Information"

@implementation IRCCommandIndex

static NSArray * _Nullable _cachedLocalCommandList = nil;

static NSDictionary *IRCCommandIndexLocalData = nil;
static NSDictionary *IRCCommandIndexRemoteData = nil;

+ (void)populateCommandIndex
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		[self _populateCommandIndex];
	});
}

/* Commands are looked up by their uppercase name, the form the line parser produces */
+ (NSDictionary *)dictionaryWithUppercaseKeys:(NSDictionary<NSString *, id> *)dictionary
{
	NSMutableDictionary *uppercased = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

	[dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object, BOOL *stop) {
		uppercased[key.uppercaseString] = object;
	}];

	return [uppercased copy];
}

+ (void)_populateCommandIndex
{
	/* Populate public data */
	NSDictionary *publicValues = [TPCResourceManager dictionaryFromResources:@"IRCCommandIndexLocalData" cacheValue:NO];

	if (publicValues) {
		NSMutableDictionary *publicValuesMutable = [publicValues mutableCopy];

		[publicValuesMutable removeObjectForKey:_reservedSlotDictionaryKey];

		IRCCommandIndexLocalData = [self dictionaryWithUppercaseKeys:publicValuesMutable];
	}

	/* Populate private data */
	NSDictionary *privateValues = [TPCResourceManager dictionaryFromResources:@"IRCCommandIndexRemoteData" cacheValue:NO];

	if (privateValues) {
		NSMutableDictionary *privateValuesMutable = [privateValues mutableCopy];

		[privateValuesMutable removeObjectForKey:_reservedSlotDictionaryKey];

		IRCCommandIndexRemoteData = [self dictionaryWithUppercaseKeys:privateValuesMutable];
	}

	/* Only error checking we need. It either fails or succeeds. */
	NSParameterAssert(IRCCommandIndexRemoteData != nil);
	NSParameterAssert(IRCCommandIndexLocalData != nil);
}

+ (void)invalidateCaches
{
	_cachedLocalCommandList = nil;
}

+ (void)rebuildLocalCommandList
{
	NSMutableArray<NSString *> *commandList = [NSMutableArray array];
	
	BOOL developerModeEnabled = [TPCPreferences developerModeEnabled];
	
	[IRCCommandIndexLocalData enumerateKeysAndObjectsUsingBlock:^(NSString *indexKey, NSDictionary *indexValue, BOOL *stop) {
		BOOL developerOnly = [indexValue boolForKey:@"developerModeOnly"];
		
		if (developerModeEnabled == NO && developerOnly) {
			return;
		}
		
		[commandList addObject:indexKey.uppercaseString];
	}];
	
	_cachedLocalCommandList = [commandList copy];
}

+ (NSArray<NSString *> *)localCommandList
{
	if (_cachedLocalCommandList == nil) {
		[self rebuildLocalCommandList];
	}

	return _cachedLocalCommandList;
}

+ (NSUInteger)indexOfLocalCommand:(NSString *)command
{
	return [self indexOfCommand:command isLocal:YES];
}

+ (NSUInteger)indexOfRemoteCommand:(NSString *)command
{
	return [self indexOfCommand:command isLocal:NO];
}

+ (NSUInteger)indexOfCommand:(NSString *)command isLocal:(BOOL)isLocalCommand
{
	NSDictionary *index = nil;
	
	if (isLocalCommand) {
		index = IRCCommandIndexLocalData[command.uppercaseString];
	} else {
		index = IRCCommandIndexRemoteData[command.uppercaseString];
	}
	
	if (index == nil) {
		return NSNotFound;
	}
	
	if (isLocalCommand) {
		if ([index boolForKey:@"developerModeOnly"] && [TPCPreferences developerModeEnabled] == NO) {
			return NSNotFound;
		}
	}
	
	return [index unsignedIntegerForKey:@"indexValue"];
}

+ (NSUInteger)colonPositionForRemoteCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	NSNumber *position = [IRCSendingMessage textParameterPositions][command.uppercaseString];

	if (position == nil) {
		return NSNotFound;
	}

	return position.unsignedIntegerValue;
}

+ (nullable NSString *)syntaxForLocalCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	NSDictionary *index = IRCCommandIndexLocalData[command.uppercaseString];

	if (index == nil) {
		return nil;
	}

	NSString *commandFormatted = command.uppercaseString;

	NSString *argumentFormat = index[@"arguments"];
	
	if (argumentFormat) {
		return [NSString stringWithFormat:@"%@ %@", commandFormatted, argumentFormat];
	}
	
	return commandFormatted;
}

@end

NS_ASSUME_NONNULL_END
