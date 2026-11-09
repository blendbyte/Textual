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

#import "IRCProtocolLinkPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCProtocolLinkTests : XCTestCase
@end

@implementation IRCProtocolLinkTests

/* Links come from web pages, other apps and messages: they are read the same
 way every time, and what can't be read is refused */
- (void)testServerPortAndTLS
{
	IRCProtocolLink *link = [IRCProtocolLink linkWithString:@"irc://irc.libera.chat"];

	XCTAssertEqualObjects(link.serverInfo, @"irc.libera.chat:6667");
	XCTAssertEqualObjects(link.channelList, @"");

	link = [IRCProtocolLink linkWithString:@"ircs://irc.libera.chat/#textual"];

	XCTAssertEqualObjects(link.serverInfo, @"-SSL irc.libera.chat:6697");
	XCTAssertEqualObjects(link.channelList, @"#textual");

	link = [IRCProtocolLink linkWithString:@" irc://irc.example.com:7000/ "];

	XCTAssertEqualObjects(link.serverInfo, @"irc.example.com:7000");

	/* "needssl" as the last section asks for TLS, and so the TLS port */
	link = [IRCProtocolLink linkWithString:@"irc://irc.example.com/chat,needssl"];

	XCTAssertEqualObjects(link.serverInfo, @"-SSL irc.example.com:6697");
	XCTAssertEqualObjects(link.channelList, @"#chat");

	/* An IPv6 address keeps its brackets, or it can't be told from the port */
	link = [IRCProtocolLink linkWithString:@"ircs://[2001:db8::1]:6697/#textual"];

	XCTAssertEqualObjects(link.serverInfo, @"-SSL [2001:db8::1]:6697");
}

- (void)testChannels
{
	IRCProtocolLink *link = [IRCProtocolLink linkWithString:@"irc://irc.example.com/textual,#chat,,%23encoded"];

	XCTAssertEqualObjects(link.channels, (@[@"#textual", @"#chat", @"#encoded"]));

	/* At most five sections after the slash */
	link = [IRCProtocolLink linkWithString:@"irc://irc.example.com/a,b,c,d,e,f"];

	XCTAssertEqualObjects(link.channelList, @"#a,#b,#c,#d,#e");

	/* Split first, then decoded: an encoded slash belongs to the name */
	link = [IRCProtocolLink linkWithString:@"irc://irc.example.com/%23a%2Fb"];

	XCTAssertEqualObjects(link.channels, (@[@"#a/b"]));

	/* Schemes are compared in any case: this one is still TLS */
	link = [IRCProtocolLink linkWithString:@"IRCS://irc.example.com/#textual"];

	XCTAssertEqualObjects(link.serverInfo, @"-SSL irc.example.com:6697");
}

/* A channel name never has spaces or control characters: decoded line
 breaks in one would send the rest as a command of its own when joining */
- (void)testChannelsWithLineBreaksAreDropped
{
	IRCProtocolLink *link = [IRCProtocolLink linkWithString:@"irc://irc.example.com/%23x%0D%0APRIVMSG%20NickServ%20:SET%20EMAIL%20evil,%23ok"];

	XCTAssertEqualObjects(link.channels, (@[@"#ok"]));

	link = [IRCProtocolLink linkWithString:@"irc://irc.example.com/%23a%07b,%23c%20d"];

	XCTAssertEqualObjects(link.channels, (@[]));
}

- (void)testUnreadableLinksAreRefused
{
	for (NSString *location in @[@"irc:irc.example.com", @"irc://", @"irc://irc.example.com/a/b", @"irc.example.com/#chat", @""]) {
		XCTAssertNil([IRCProtocolLink linkWithString:location], @"%@", location);
	}
}

/* textual:// links name an app action in the host */
- (void)testTextualScheme
{
	IRCProtocolLink *link = [IRCProtocolLink linkWithString:@"textual://acknowledgements"];

	XCTAssertEqualObjects(link.scheme, @"textual");
	XCTAssertEqualObjects(link.host, @"acknowledgements");
}

@end

NS_ASSUME_NONNULL_END
