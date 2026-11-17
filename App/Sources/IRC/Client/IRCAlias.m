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

#import "TPCPreferencesUserDefaults.h"
#import "IRCAliasPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _aliasesDefaultsKey			@"Input -> Aliases"
#define _maximumCommands			10

@implementation IRCAlias

/* Only names and commands that are text, and names that are valid: an
 imported file can hold anything, and Settings › Aliases trapped on a number */
+ (NSDictionary<NSString *, NSString *> *)aliases
{
	NSDictionary *aliases = [RZUserDefaults() dictionaryForKey:_aliasesDefaultsKey];

	if (aliases == nil) {
		return @{};
	}

	NSMutableDictionary<NSString *, NSString *> *validAliases = [NSMutableDictionary dictionaryWithCapacity:aliases.count];

	[aliases enumerateKeysAndObjectsUsingBlock:^(id name, id commands, BOOL *stop) {
		if ([name isKindOfClass:[NSString class]] && [commands isKindOfClass:[NSString class]] && [self isValidAliasName:name]) {
			validAliases[name] = commands;
		}
	}];

	return [validAliases copy];
}

+ (nullable NSString *)commandsForAlias:(NSString *)name
{
	NSParameterAssert(name != nil);

	id commands = [self aliases][name.lowercaseString];

	return (([commands isKindOfClass:[NSString class]]) ? commands : nil);
}

+ (void)setCommands:(nullable NSString *)commands forAlias:(NSString *)name
{
	NSParameterAssert(name != nil);

	NSMutableDictionary *aliases = [[self aliases] mutableCopy];

	aliases[name.lowercaseString] = commands;

	[RZUserDefaults() setObject:[aliases copy] forKey:_aliasesDefaultsKey];
}

+ (BOOL)isValidAliasName:(NSString *)name
{
	NSParameterAssert(name != nil);

	if (name.length == 0 || name.length > 50) {
		return NO;
	}

	NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];

	return ([[name stringByTrimmingCharactersInSet:allowed] length] == 0);
}

+ (nullable NSArray<NSString *> *)linesForCommands:(NSString *)commands
										 arguments:(NSString *)arguments
										  nickname:(nullable NSString *)nickname
										   channel:(nullable NSString *)channel
											server:(nullable NSString *)server
										   network:(nullable NSString *)network
											 error:(IRCAliasError *)error
								 requiredArguments:(NSUInteger *)requiredArguments
{
	NSParameterAssert(commands != nil);
	NSParameterAssert(arguments != nil);
	NSParameterAssert(error != NULL);
	NSParameterAssert(requiredArguments != NULL);

	*error = IRCAliasErrorNone;
	*requiredArguments = 0;

	NSMutableArray<NSString *> *words = [NSMutableArray array];

	for (NSString *word in [arguments componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
		if (word.length > 0) {
			[words addObject:word];
		}
	}

	/* Split at ";" that isn't "\;" */
	NSMutableArray<NSString *> *parts = [NSMutableArray array];

	NSMutableString *part = [NSMutableString string];

	for (NSUInteger index = 0; index < commands.length; index++) {
		unichar character = [commands characterAtIndex:index];

		if (character == '\\' && (index + 1) < commands.length && [commands characterAtIndex:(index + 1)] == ';') {
			[part appendString:@";"];

			index += 1;

			continue;
		}

		if (character == ';') {
			[parts addObject:[part copy]];

			[part setString:@""];

			continue;
		}

		[part appendFormat:@"%C", character];
	}

	[parts addObject:[part copy]];

	NSMutableArray<NSString *> *lines = [NSMutableArray array];

	for (NSString *rawPart in parts) {
		NSString *trimmed = [rawPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		if (trimmed.length == 0) {
			continue;
		}

		NSMutableString *line = [NSMutableString string];

		NSUInteger index = 0;

		while (index < trimmed.length) {
			unichar character = [trimmed characterAtIndex:index];

			if (character != '$' || (index + 1) >= trimmed.length) {
				[line appendFormat:@"%C", character];

				index += 1;

				continue;
			}

			unichar next = [trimmed characterAtIndex:(index + 1)];

			/* $$ */
			if (next == '$') {
				[line appendString:@"$"];

				index += 2;

				continue;
			}

			/* $* (every word, maybe none) */
			if (next == '*') {
				[line appendString:[words componentsJoinedByString:@" "]];

				index += 2;

				continue;
			}

			/* $~ (the last word) */
			if (next == '~') {
				if (words.count == 0) {
					*error = IRCAliasErrorMissingArguments;
					*requiredArguments = MAX(*requiredArguments, 1);
				} else {
					[line appendString:words.lastObject];
				}

				index += 2;

				continue;
			}

			/* $1 – $9, $1- – $9-, $1-2 – $9-9 */
			if (next >= '1' && next <= '9') {
				NSUInteger position = (next - '0');

				BOOL rest = ((index + 2) < trimmed.length && [trimmed characterAtIndex:(index + 2)] == '-');

				NSUInteger last = 0; // with a range: its last word

				if (rest && (index + 3) < trimmed.length) {
					unichar end = [trimmed characterAtIndex:(index + 3)];

					if (end >= '1' && end <= '9') {
						last = (end - '0');
					}
				}

				NSUInteger length = ((last > 0) ? 4 : ((rest) ? 3 : 2));

				if (words.count < position) {
					*error = IRCAliasErrorMissingArguments;
					*requiredArguments = MAX(*requiredArguments, position);

					index += length;

					continue;
				}

				if (last > 0) {
					/* As many as there are; nothing when the range runs backwards */
					NSUInteger upTo = MIN(last, words.count);

					if (upTo >= position) {
						[line appendString:[[words subarrayWithRange:NSMakeRange((position - 1), (upTo - position + 1))] componentsJoinedByString:@" "]];
					}

					index += length;
				} else if (rest) {
					[line appendString:[[words subarrayWithRange:NSMakeRange((position - 1), (words.count - position + 1))] componentsJoinedByString:@" "]];

					index += 3;
				} else {
					[line appendString:words[(position - 1)]];

					index += 2;
				}

				continue;
			}

			NSString *remainder = [trimmed substringFromIndex:(index + 1)];

			NSString *replacement = nil;
			NSUInteger nameLength = 0;

			if ([remainder hasPrefix:@"network"]) {
				replacement = network;
				nameLength = 7;
			} else if ([remainder hasPrefix:@"nick"]) {
				replacement = nickname;
				nameLength = 4;
			} else if ([remainder hasPrefix:@"channel"]) {
				if (channel == nil) {
					*error = IRCAliasErrorNoChannel;

					return nil;
				}

				replacement = channel;
				nameLength = 7;
			} else if ([remainder hasPrefix:@"server"]) {
				replacement = server;
				nameLength = 6;
			}

			if (nameLength == 0) {
				[line appendString:@"$"];

				index += 1;

				continue;
			}

			[line appendString:(replacement ?: @"")];

			index += (1 + nameLength);
		}

		[lines addObject:[line copy]];
	}

	if (*error != IRCAliasErrorNone) {
		return nil;
	}

	if (lines.count > _maximumCommands) {
		*error = IRCAliasErrorTooManyCommands;

		return nil;
	}

	return [lines copy];
}

@end

NS_ASSUME_NONNULL_END
