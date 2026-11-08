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

#import "IRCChannelConfig.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientInternal.h"
#import "IRCClientPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientNickServTests : XCTestCase
@end

@implementation IRCClientNickServTests

/* The NickServ password is only sent to this host, so a look-alike domain must never match */
- (void)testKnownNickServHostMatchesOnlyTheNetworkDomain
{
	XCTAssertEqualObjects([IRCClient knownNickServHostForServerAddress:@"irc.libera.chat"], @"services.libera.chat");
	XCTAssertEqualObjects([IRCClient knownNickServHostForServerAddress:@"Libera.Chat"], @"services.libera.chat");
	XCTAssertEqualObjects([IRCClient knownNickServHostForServerAddress:@"irc.eu.oftc.net"], @"services.oftc.net");

	XCTAssertNil([IRCClient knownNickServHostForServerAddress:@"evil-libera.chat"]);
	XCTAssertNil([IRCClient knownNickServHostForServerAddress:@"libera.chat.example.com"]);
	XCTAssertNil([IRCClient knownNickServHostForServerAddress:@"irc.example.net"]);
}

/* A password typed to a service never reaches the screen or the logs; anything else is left alone */
- (void)testPasswordsToServicesAreHidden
{
	NSString *dots = @"••••••••";

	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"IDENTIFY hunter2" toTarget:@"NickServ"], ([NSString stringWithFormat:@"IDENTIFY %@", dots]));
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"identify dan hunter2" toTarget:@"nickserv@services.dal.net"], ([NSString stringWithFormat:@"identify %@", dots]));
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"SET PASSWORD hunter2" toTarget:@"NickServ"], ([NSString stringWithFormat:@"SET PASSWORD %@", dots]));
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"AUTH dan hunter2" toTarget:@"Q@CServe.quakenet.org"], ([NSString stringWithFormat:@"AUTH %@", dots]));

	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"HELP IDENTIFY" toTarget:@"NickServ"], @"HELP IDENTIFY");
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"IDENTIFY" toTarget:@"NickServ"], @"IDENTIFY", @"Nothing to hide");
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"SET email a@b" toTarget:@"NickServ"], @"SET email a@b");
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"identify hunter2" toTarget:@"bob"], @"identify hunter2", @"Not a service");
	XCTAssertEqualObjects([IRCClient textHidingPasswordInServiceCommand:@"auth me" toTarget:@"Q"], @"auth me", @"A person called Q");
}

/* A server decides what we joined, within limits */
- (void)testJoinsAreLimited
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertFalse([client shouldIgnoreJoinOfChannel:@"#textual"]);
	XCTAssertTrue([client shouldIgnoreJoinOfChannel:@"badname"], @"Not a channel name");

	for (NSUInteger i = 0; i < IRCClientMaximumChannelCount; i++) {
		[client addChannel:[[IRCChannel alloc] initWithConfig:[IRCChannelConfig seedWithName:[NSString stringWithFormat:@"#c%lu", i]]]];
	}

	XCTAssertTrue([client shouldIgnoreJoinOfChannel:@"#textual"], @"Past the limit");
	XCTAssertFalse([client shouldIgnoreJoinOfChannel:@"#c5"], @"One it has already");
}

@end


NS_ASSUME_NONNULL_END
