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

#import "IRCClientConfig.h"
#import "IRCClientInternal.h"
#import "IRCMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientStandardReplyTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@end

@implementation IRCClientStandardReplyTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];
}

- (NSString *)textFor:(NSString *)line
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:line onClient:self.client];

	XCTAssertNotNil(message, @"Failed to parse: %@", line);

	return [self.client standardReplyText:message];
}

/* FAIL <command> <code> [<context>...] <description>: the description is the
 last parameter however many context parameters come before it */
- (void)testReplyNamesCommandCodeAndDescription
{
	NSString *text = [self textFor:@":irc.test FAIL CHATHISTORY INVALID_TARGET LATEST #nowhere :Messages could not be retrieved"];

	XCTAssertTrue([text containsString:@"FAIL"], @"%@", text);
	XCTAssertTrue([text containsString:@"CHATHISTORY"], @"%@", text);
	XCTAssertTrue([text containsString:@"INVALID_TARGET"], @"%@", text);
	XCTAssertTrue([text containsString:@"Messages could not be retrieved"], @"%@", text);
	XCTAssertFalse([text containsString:@"#nowhere"], @"%@", text);
}

/* "*" stands for no particular command and isn't shown */
- (void)testReplyWithoutCommand
{
	NSString *text = [self textFor:@":irc.test NOTE * SERVER_RESTARTING :The server restarts in five minutes"];

	XCTAssertTrue([text containsString:@"NOTE"], @"%@", text);
	XCTAssertTrue([text containsString:@"SERVER_RESTARTING"], @"%@", text);
	XCTAssertFalse([text containsString:@"*"], @"%@", text);
}

@end

NS_ASSUME_NONNULL_END
