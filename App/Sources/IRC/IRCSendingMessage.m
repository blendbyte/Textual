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

#import "IRCCommandIndex.h"
#import "IRCSendingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCSendingMessage

/* How the last argument of a command is sent:
 - Free text at a known position (PRIVMSG, TOPIC…): always as the trailing
   parameter (":text"), also when empty (TOPIC #c : clears the topic).
 - Parameter lists (MODE, WHO…): as given, so a plugin passing several
   parameters in one string ("+o nick") keeps working.
 - Any other command: as the trailing parameter when it contains a space. */
+ (NSDictionary<NSString *, NSNumber *> *)textParameterPositions
{
	static NSDictionary<NSString *, NSNumber *> *positions = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		positions = @{
			@"ADCHAT" : @(0),
			@"AWAY" : @(0),
			@"CAP" : @(1),
			@"CHATOPS" : @(0),
			@"ERROR" : @(0),
			@"GLINE" : @(2),
			@"GLOBOPS" : @(0),
			@"GZLINE" : @(2),
			@"KICK" : @(2),
			@"KILL" : @(1),
			@"LOCOPS" : @(0),
			@"NACHAT" : @(0),
			@"NOTICE" : @(1),
			@"PART" : @(1),
			@"PASS" : @(0),
			@"PRIVMSG" : @(1),
			@"QUIT" : @(0),
			@"SHUN" : @(2),
			@"TEMPSHUN" : @(1),
			@"TOPIC" : @(1),
			@"USER" : @(3),
			@"WALLOPS" : @(0),
			@"ZLINE" : @(2)
		};
	});

	return positions;
}

+ (NSSet<NSString *> *)parameterListCommands
{
	static NSSet<NSString *> *commands = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		commands = [NSSet setWithArray:@[
			@"AUTHENTICATE", @"BATCH", @"CERTINFO", @"CHGHOST", @"INVITE", @"ISON", @"JOIN", @"LIST",
			@"MODE", @"MONITOR", @"NAMES", @"NICK", @"PING", @"PONG", @"WATCH", @"WHO", @"WHOIS", @"WHOWAS"
		]];
	});

	return commands;
}

+ (NSString *)stringWithCommand:(NSString *)command arguments:(nullable NSArray<NSString *> *)arguments
{
	NSParameterAssert(command != nil);

	NSString *commandUppercase = command.uppercaseString;

	NSNumber *textPosition = [self textParameterPositions][commandUppercase];

	BOOL isParameterList = [[self parameterListCommands] containsObject:commandUppercase];

	NSMutableString *builtString = [NSMutableString stringWithString:commandUppercase];

	NSUInteger argumentCount = arguments.count;

	NSUInteger position = 0;

	for (NSUInteger index = 0; index < argumentCount; index++) {
		NSString *argument = arguments[index];

		BOOL isLastArgument = (index == (argumentCount - 1));

		BOOL isText = (textPosition && position == textPosition.unsignedIntegerValue);

		/* An empty argument can't be sent except as free text: it is left
		 out (it used to cut off every argument after it, R3.20) */
		if (argument.length == 0 && (isText == NO || isLastArgument == NO)) {
			continue;
		}

		[builtString appendString:@" "];

		if (isLastArgument) {
			BOOL trailing = NO;

			if (isText || [argument hasPrefix:@":"]) {
				trailing = YES;
			} else if (textPosition == nil && isParameterList == NO) {
				trailing = [argument contains:@" "];
			}

			if (trailing) {
				[builtString appendString:@":"];
			}
		}

		[builtString appendString:argument];

		position += 1;
	}

	return [builtString copy];
}

@end

NS_ASSUME_NONNULL_END
