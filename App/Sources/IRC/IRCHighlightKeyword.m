/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "IRCHighlightKeywordPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCHighlightKeywordStringKey = @"string";
NSString * const IRCHighlightKeywordLimitedToKey = @"limitedTo";
NSString * const IRCHighlightKeywordNicknamesKey = @"nicknames";
NSString * const IRCHighlightKeywordSoundKey = @"sound";
NSString * const IRCHighlightKeywordMatchTypeKey = @"matchType";

@interface IRCHighlightKeyword ()
@property (readwrite, copy) NSString *keyword;
@property (readwrite, copy) NSArray<NSString *> *limitedTo;
@property (readwrite, copy) NSArray<NSString *> *nicknames;
@property (readwrite, copy, nullable) NSString *sound;
@property (readwrite) TXNicknameHighlightMatchType matchType;
@end

@implementation IRCHighlightKeyword

+ (NSArray<NSString *> *)_stringsInArray:(nullable id)array
{
	if ([array isKindOfClass:[NSArray class]] == NO) {
		return @[];
	}

	NSMutableArray<NSString *> *strings = [NSMutableArray array];

	for (id object in array) {
		if ([object isKindOfClass:[NSString class]] && [object length] > 0) {
			[strings addObject:object];
		}
	}

	return [strings copy];
}

+ (IRCHighlightKeyword *)keywordWithString:(NSString *)string matchType:(TXNicknameHighlightMatchType)matchType
{
	NSParameterAssert(string != nil);

	IRCHighlightKeyword *keyword = [IRCHighlightKeyword new];

	keyword.keyword = string;
	keyword.limitedTo = @[];
	keyword.nicknames = @[];
	keyword.matchType = matchType;

	return keyword;
}

+ (NSArray<IRCHighlightKeyword *> *)keywordsWithDictionaries:(nullable NSArray *)dictionaries defaultMatchType:(TXNicknameHighlightMatchType)defaultMatchType
{
	NSMutableArray<IRCHighlightKeyword *> *keywords = [NSMutableArray array];

	for (NSDictionary *dic in dictionaries) {
		if ([dic isKindOfClass:[NSDictionary class]] == NO) {
			continue;
		}

		NSString *string = dic[IRCHighlightKeywordStringKey];

		if ([string isKindOfClass:[NSString class]] == NO) {
			continue;
		}

		NSArray *nicknames = [self _stringsInArray:dic[IRCHighlightKeywordNicknamesKey]];

		if (string.length == 0 && nicknames.count == 0) {
			continue;
		}

		IRCHighlightKeyword *keyword = [IRCHighlightKeyword new];

		keyword.keyword = string;
		keyword.limitedTo = [self _stringsInArray:dic[IRCHighlightKeywordLimitedToKey]];
		keyword.nicknames = nicknames;

		id matchType = dic[IRCHighlightKeywordMatchTypeKey];

		if ([matchType isKindOfClass:[NSNumber class]] && [matchType unsignedIntegerValue] <= TXNicknameHighlightMatchTypeRegularExpression) {
			keyword.matchType = [matchType unsignedIntegerValue];
		} else {
			keyword.matchType = defaultMatchType;
		}

		NSString *sound = dic[IRCHighlightKeywordSoundKey];

		if ([sound isKindOfClass:[NSString class]] && sound.length > 0) {
			keyword.sound = sound;
		}

		[keywords addObject:keyword];
	}

	return [keywords copy];
}

- (NSUInteger)lineMatchType
{
	if (self.keyword.length == 0) {
		return IRCHighlightKeywordMatchTypeEveryMessage;
	}

	return self.matchType;
}

- (BOOL)appliesToChannelWithId:(NSString *)channelId clientId:(NSString *)clientId
{
	NSParameterAssert(channelId != nil);
	NSParameterAssert(clientId != nil);

	NSArray *limitedTo = self.limitedTo;

	if (limitedTo.count == 0) {
		return YES;
	}

	return ([limitedTo containsObject:channelId] || [limitedTo containsObject:clientId]);
}

- (BOOL)appliesToNickname:(NSString *)nickname supportInfo:(IRCISupportInfo *)supportInfo
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(supportInfo != nil);

	NSArray *nicknames = self.nicknames;

	if (nicknames.count == 0) {
		return YES;
	}

	NSString *foldedNickname = [supportInfo foldedString:nickname];

	for (NSString *e in nicknames) {
		if ([[supportInfo foldedString:e] isEqualToString:foldedNickname]) {
			return YES;
		}
	}

	return NO;
}

+ (NSArray<NSDictionary *> *)entries:(nullable NSArray<NSDictionary *> *)entries
		  mergingServerConditions:(NSArray<IRCHighlightMatchCondition *> *)conditions
						 excluded:(BOOL)excluded
						 clientId:(NSString *)clientId
{
	NSParameterAssert(conditions != nil);
	NSParameterAssert(clientId != nil);

	NSMutableArray<NSDictionary *> *entriesOut = [NSMutableArray array];

	for (NSDictionary *entry in entries) {
		if ([entry isKindOfClass:[NSDictionary class]]) {
			[entriesOut addObject:entry];
		}
	}

	for (IRCHighlightMatchCondition *condition in conditions) {
		if (condition.matchIsExcluded != excluded) {
			continue;
		}

		NSString *string = condition.matchKeyword;

		if (string.length == 0) {
			continue;
		}

		NSString *place = condition.matchChannelId;

		if (place.length == 0) {
			place = clientId;
		}

		BOOL merged = NO;

		for (NSUInteger i = 0; i < entriesOut.count; i++) {
			NSDictionary *entry = entriesOut[i];

			NSString *entryString = entry[IRCHighlightKeywordStringKey];

			if ([entryString isKindOfClass:[NSString class]] == NO ||
				[entryString compare:string options:NSCaseInsensitiveSearch] != NSOrderedSame)
			{
				continue;
			}

			/* Limited to people: a different rule, kept apart */
			if ([self _stringsInArray:entry[IRCHighlightKeywordNicknamesKey]].count > 0) {
				continue;
			}

			NSArray *limitedTo = [self _stringsInArray:entry[IRCHighlightKeywordLimitedToKey]];

			if (limitedTo.count > 0 && [limitedTo containsObject:place] == NO) {
				NSMutableDictionary *entryMutable = [entry mutableCopy];

				entryMutable[IRCHighlightKeywordLimitedToKey] = [limitedTo arrayByAddingObject:place];

				entriesOut[i] = [entryMutable copy];
			}

			merged = YES;

			break;
		}

		if (merged) {
			continue;
		}

		[entriesOut addObject:@{
			IRCHighlightKeywordStringKey : string,
			IRCHighlightKeywordLimitedToKey : @[place]
		}];
	}

	return [entriesOut copy];
}

@end

NS_ASSUME_NONNULL_END
