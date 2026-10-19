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

NS_ASSUME_NONNULL_BEGIN

/* Simple aliases: your own commands, one list for every
 server. "/alias o /mode $channel +o $1" makes "/o alice" run
 "/mode #here +o alice". Textual's own commands always come first. */

typedef NS_ENUM(NSUInteger, IRCAliasError) {
	IRCAliasErrorNone = 0,
	IRCAliasErrorMissingArguments, // $N used, fewer words given
	IRCAliasErrorNoChannel, // $channel used outside a channel or private message
	IRCAliasErrorTooManyCommands // more than 10
};

@interface IRCAlias : NSObject
/* Name (lowercase) → commands, as stored */
@property (readonly, class, copy) NSDictionary<NSString *, NSString *> *aliases;

+ (nullable NSString *)commandsForAlias:(NSString *)name;
+ (void)setCommands:(nullable NSString *)commands forAlias:(NSString *)name;

/* Letters, digits, - and _ */
+ (BOOL)isValidAliasName:(NSString *)name;

/* The lines an alias runs: commands split at ";" ("\;" is a semicolon),
 then $1–$9 (words), $1- to $9- (from that word on), $nick, $channel, $server
 and $$ (a dollar sign). nil and an error when a word or the channel is
 missing or there are more than 10. requiredArguments is set for
 IRCAliasErrorMissingArguments. */
+ (nullable NSArray<NSString *> *)linesForCommands:(NSString *)commands
										 arguments:(NSString *)arguments
										  nickname:(nullable NSString *)nickname
										   channel:(nullable NSString *)channel
											server:(nullable NSString *)server
											 error:(IRCAliasError *)error
								 requiredArguments:(NSUInteger *)requiredArguments;
@end

NS_ASSUME_NONNULL_END
