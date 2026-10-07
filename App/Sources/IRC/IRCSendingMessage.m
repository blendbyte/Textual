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

+ (NSString *)stringWithCommand:(NSString *)command arguments:(nullable NSArray<NSString *> *)arguments
{
	NSParameterAssert(command != nil);

	NSString *commandUppercase = command.uppercaseString;

	if (arguments.count == 0) {
		return commandUppercase;
	}

	NSMutableString *builtString = [NSMutableString stringWithString:commandUppercase];

	NSInteger colonIndexBase = [IRCCommandIndex colonPositionForRemoteCommand:command];

	NSInteger colonIndexCount = 0;

	for (NSString *argument in arguments) {
		if (argument.length == 0) {
			break;
		}

		[builtString appendString:@" "];

		if (colonIndexBase == NSNotFound) {
			// Guess where the colon (:) should go.
			//
			// A colon is supposed to represent a section of an outgoing command
			// that has a parameter which contains spaces. For example, PRIVMSG
			// is in the format "PRIVMSG #channel :long message" — The message
			// will have spaces part of it, so we inform the server.

			if (colonIndexCount == (arguments.count - 1) && ([argument hasPrefix:@":"] || [argument contains:@" "])) {
				[builtString appendString:@":"];
			}
		} else {
			// We know where it goes thanks to the command index

			if (colonIndexCount == colonIndexBase) {
				[builtString appendString:@":"];
			}
		}

		[builtString appendString:argument];

		colonIndexCount += 1;
	}

	return [builtString copy];
}

@end

NS_ASSUME_NONNULL_END
