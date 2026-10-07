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
#import "IRCHighlightMatchConditionInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCHighlightMatchCondition

- (instancetype)init
{
	return [super initWithDictionary:@{}];
}

- (void)initializedClassHealthCheck
{
	if (self.mutable || self.initializedAsCopy) {
		return;
	}

	NSParameterAssert(self->_matchKeyword.length > 0);
}

- (void)populateDictionaryValues:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	[dic assignBoolTo:&self->_matchIsExcluded forKey:@"matchIsExcluded"];

	[dic assignStringTo:&self->_matchChannelId forKey:@"matchChannelID"];
	[dic assignStringTo:&self->_matchKeyword forKey:@"matchKeyword"];
	[dic assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];
}

- (void)populateDefaultsPostflight
{
	SetVariableIfNil(self->_matchKeyword, @"")

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	[dic maybeSetObject:self.matchChannelId forKey:@"matchChannelID"];
	[dic maybeSetObject:self.matchKeyword forKey:@"matchKeyword"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	[dic setBool:self.matchIsExcluded forKey:@"matchIsExcluded"];

	return [dic copy];
}

- (id)uniqueCopyAsMutable:(BOOL)mutableCopy
{
	IRCHighlightMatchCondition *object = [super uniqueCopyAsMutable:mutableCopy];

	object->_uniqueIdentifier = [NSString stringWithUUID];

	return object;
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [IRCHighlightMatchConditionMutable self];
}

@end

#pragma mark -

@implementation IRCHighlightMatchConditionMutable

@dynamic matchChannelId;
@dynamic matchIsExcluded;
@dynamic matchKeyword;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [IRCHighlightMatchCondition self];
}

- (void)setMatchIsExcluded:(BOOL)matchIsExcluded
{
	if (self->_matchIsExcluded != matchIsExcluded) {
		self->_matchIsExcluded = matchIsExcluded;
	}
}

- (void)setMatchChannelId:(nullable NSString *)matchChannelId
{
	if (self->_matchChannelId != matchChannelId) {
		self->_matchChannelId = [matchChannelId copy];
	}
}

- (void)setMatchKeyword:(NSString *)matchKeyword
{
	NSParameterAssert(matchKeyword != nil);

	if (self->_matchKeyword != matchKeyword) {
		self->_matchKeyword = [matchKeyword copy];
	}
}

@end

NS_ASSUME_NONNULL_END
