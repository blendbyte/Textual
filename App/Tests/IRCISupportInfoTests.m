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
#import "IRCClientPrivate.h"
#import "IRCISupportInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCISupportInfoTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@end

@implementation IRCISupportInfoTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];
}

- (void)testTypicalConfiguration
{
	IRCISupportInfo *info = self.client.supportInfo;

	[info processConfigurationData:@"me CHANTYPES=#& PREFIX=(qaohv)~&@%+ NICKLEN=30 TOPICLEN=390 MODES=4 NETWORK=Libera.Chat :are supported by this server"];

	XCTAssertEqualObjects(info.channelNamePrefixes, (@[@"#", @"&"]));
	XCTAssertEqualObjects(info.userModeSymbols[@"modeSymbols"], (@[@"q", @"a", @"o", @"h", @"v"]));
	XCTAssertEqualObjects(info.userModeSymbols[@"characters"], (@[@"~", @"&", @"@", @"%", @"+"]));
	XCTAssertEqual(info.maximumNicknameLength, 30);
	XCTAssertEqual(info.maximumTopicLength, 390);
	XCTAssertEqual(info.maximumModeCount, 4);
	XCTAssertEqualObjects(info.networkName, @"Libera.Chat");
}

/* Nicknames and channel names compare under the server's CASEMAPPING:
 under rfc1459 (also the default) [ ] \\ ~ are the upper case of { } | ^ */
- (void)testCaseMappingFoldsNamesLikeTheServer
{
	IRCISupportInfo *info = self.client.supportInfo;

	XCTAssertEqual(info.caseMapping, IRCISupportInfoCaseMappingRFC1459);
	XCTAssertEqualObjects([info foldedString:@"Nick[A]\\~"], @"nick{a}|^");

	[info processConfigurationData:@"me CASEMAPPING=strict-rfc1459 :are supported by this server"];

	XCTAssertEqualObjects([info foldedString:@"Nick[A]\\~"], @"nick{a}|~");

	[info processConfigurationData:@"me CASEMAPPING=ascii :are supported by this server"];

	XCTAssertEqualObjects([info foldedString:@"Nick[A]\\~"], @"nick[a]\\~");
	XCTAssertEqualObjects([info foldedString:@"ÄBC"], @"Äbc");

	[info processConfigurationData:@"me CASEMAPPING=rfc8265 :are supported by this server"];

	XCTAssertEqualObjects([info foldedString:@"ÄBC"], @"äbc");
}

/* UTF8ONLY can be withdrawn later with "-UTF8ONLY", like other tokens; values unescape \\xHH */
- (void)testTokenWithdrawalAndEscapedValues
{
	IRCISupportInfo *info = self.client.supportInfo;

	[info processConfigurationData:@"me UTF8ONLY CHATHISTORY=100 NETWORK=Example\\x20Net :are supported by this server"];

	XCTAssertTrue(info.utf8Only);
	XCTAssertEqual(info.chatHistoryLimit, 100);
	XCTAssertEqualObjects(info.networkName, @"Example Net");

	[info processConfigurationData:@"me -UTF8ONLY -CHATHISTORY :are supported by this server"];

	XCTAssertFalse(info.utf8Only);
	XCTAssertEqual(info.chatHistoryLimit, 0);
}

/* With UTF8ONLY nothing is guessed: bytes that aren't UTF-8 become U+FFFD and the rest of the line stays */
- (void)testUTF8OnlyDecoding
{
	const char bytes[] = { 'c', 'a', 'f', (char)0xE9, ' ', 'x' };

	NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];

	XCTAssertEqualObjects([self.client convertFromCommonEncoding:data], @"caf\u00E9 x", @"Without UTF8ONLY: the fallback encoding (Latin-1)");

	[self.client.supportInfo processConfigurationData:@"me UTF8ONLY :are supported by this server"];

	XCTAssertEqualObjects([self.client convertFromCommonEncoding:data], @"caf\uFFFD x");
}

/* A malformed PREFIX from any server or bouncer used to crash the app */
- (void)testMalformedPrefixIsIgnored
{
	IRCISupportInfo *info = self.client.supportInfo;

	[info processConfigurationData:@"me PREFIX=(qaohv)~&@%+ :are supported by this server"];

	for (NSString *malformed in @[@"(ov", @"ov)@+", @")(ov@+", @"(ov)@"]) {
		[info processConfigurationData:[NSString stringWithFormat:@"me PREFIX=%@ :are supported by this server", malformed]];

		XCTAssertEqualObjects(info.userModeSymbols[@"modeSymbols"], (@[@"q", @"a", @"o", @"h", @"v"]), @"PREFIX=%@ was not ignored", malformed);
	}
}

@end

NS_ASSUME_NONNULL_END
