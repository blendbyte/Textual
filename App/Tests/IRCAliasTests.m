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

#import <XCTest/XCTest.h>

#import "IRCAliasPrivate.h"
#import "TPCPreferencesUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCAliasTests : XCTestCase
@end

@implementation IRCAliasTests

- (nullable NSArray<NSString *> *)lines:(NSString *)commands arguments:(NSString *)arguments channel:(nullable NSString *)channel error:(IRCAliasError *)error required:(NSUInteger *)required
{
	return [IRCAlias linesForCommands:commands arguments:arguments nickname:@"me" channel:channel server:@"irc.libera.chat" network:@"Libera.Chat" error:error requiredArguments:required];
}

/* What an alias runs: words, the rest, names, several commands */
- (void)testExpansion
{
	IRCAliasError error;
	NSUInteger required;

	NSArray *lines = [self lines:@"/mode $channel +o $1" arguments:@"alice" channel:@"#here" error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/mode #here +o alice"]);

	lines = [self lines:@"/msg $1 $2-" arguments:@"bob  hello there" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/msg bob hello there"]);

	lines = [self lines:@"/me waves at $1; /notice $1 hi" arguments:@"carol" channel:@"#x" error:&error required:&required];

	NSArray *expected = @[@"/me waves at carol", @"/notice carol hi"];

	XCTAssertEqualObjects(lines, expected);

	lines = [self lines:@"/echo a\\;b costs $$5, $nick on $server, $other" arguments:@"" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/echo a;b costs $5, me on irc.libera.chat, $other"]);
}

/* $network (behind a bouncer $server is the bouncer), $*, $~ and ranges */
- (void)testMorePlaceholders
{
	IRCAliasError error;
	NSUInteger required;

	NSArray *lines = [self lines:@"/echo $network via $server" arguments:@"" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/echo Libera.Chat via irc.libera.chat"]);

	/* $* may be empty, unlike $1- */
	lines = [self lines:@"/away $*" arguments:@"" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/away "]);

	lines = [self lines:@"/msg alice $*" arguments:@" one  two three " channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/msg alice one two three"]);

	lines = [self lines:@"/kick $channel $~" arguments:@"a b carol" channel:@"#x" error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/kick #x carol"]);

	XCTAssertNil([self lines:@"/whois $~" arguments:@"" channel:nil error:&error required:&required]);
	XCTAssertEqual(error, IRCAliasErrorMissingArguments);
	XCTAssertEqual(required, (NSUInteger)1);

	/* A range: as many words as there are */
	lines = [self lines:@"/say $2-3 | $1" arguments:@"a b c d" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/say b c | a"]);

	lines = [self lines:@"/say $2-4" arguments:@"a b" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/say b"]);

	XCTAssertNil([self lines:@"/say $3-4" arguments:@"a" channel:nil error:&error required:&required]);
	XCTAssertEqual(required, (NSUInteger)3);

	/* $2- is still the rest */
	lines = [self lines:@"/say $2-" arguments:@"a b c" channel:nil error:&error required:&required];

	XCTAssertEqualObjects(lines, @[@"/say b c"]);
}

/* Missing words or channel, and too many commands, run nothing */
- (void)testErrors
{
	IRCAliasError error;
	NSUInteger required;

	XCTAssertNil([self lines:@"/mode $channel +o $1 $3" arguments:@"alice" channel:@"#here" error:&error required:&required]);
	XCTAssertEqual(error, IRCAliasErrorMissingArguments);
	XCTAssertEqual(required, (NSUInteger)3);

	XCTAssertNil([self lines:@"/topic $channel" arguments:@"" channel:nil error:&error required:&required]);
	XCTAssertEqual(error, IRCAliasErrorNoChannel);

	XCTAssertNil([self lines:@"a;b;c;d;e;f;g;h;i;j;k" arguments:@"" channel:nil error:&error required:&required]);
	XCTAssertEqual(error, IRCAliasErrorTooManyCommands);

	XCTAssertTrue([IRCAlias isValidAliasName:@"op-2_x"]);
	XCTAssertFalse([IRCAlias isValidAliasName:@"op me"]);
	XCTAssertFalse([IRCAlias isValidAliasName:@""]);
}

/* An imported file can hold anything: only text names and commands with a valid name are aliases */
- (void)testOnlyValidAliasesAreRead
{
	id saved = [RZUserDefaults() objectForKey:@"Input -> Aliases"];

	NSDictionary *stored = @{@"ok" : @"/me waves", @"num" : @5, @"bad name" : @"/x", @"list" : @[@"/y"]};

	[RZUserDefaults() setObject:stored forKey:@"Input -> Aliases"];

	NSDictionary *expected = @{@"ok" : @"/me waves"};

	XCTAssertEqualObjects(IRCAlias.aliases, expected);

	if (saved) {
		[RZUserDefaults() setObject:saved forKey:@"Input -> Aliases"];
	} else {
		[RZUserDefaults() removeObjectForKey:@"Input -> Aliases"];
	}
}

@end

NS_ASSUME_NONNULL_END
