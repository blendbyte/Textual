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
#import "IRCISupportInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientBotsAndNetsplitsTests : XCTestCase
@end

@implementation IRCClientBotsAndNetsplitsTests

/* BOT=B names the user mode and WHO flag of bots; a value of more than one character isn't one */
- (void)testBotModeCharacter
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertNil(client.supportInfo.botModeCharacter);

	[client.supportInfo processConfigurationData:@"me BOT=B :are supported by this server"];

	XCTAssertEqualObjects(client.supportInfo.botModeCharacter, @"B");

	[client.supportInfo reset];

	[client.supportInfo processConfigurationData:@"me BOT=Bx :are supported by this server"];

	XCTAssertNil(client.supportInfo.botModeCharacter);
}

/* One line per channel: up to three people by name, more counted; servers that
 hide their links (*.net *.split) aren't named */
- (void)testNetsplitSummary
{
	NSArray *servers = @[@"irc1.test", @"irc2.test"];

	NSArray *two = @[@"alice", @"bob"];

	XCTAssertEqualObjects([IRCClient netsplitSummaryForNicknames:two servers:servers joined:NO],
						  @"Netsplit between irc1.test and irc2.test: alice and bob quit");

	NSArray *many = @[@"a", @"b", @"c", @"d", @"e"];

	XCTAssertEqualObjects([IRCClient netsplitSummaryForNicknames:many servers:servers joined:YES],
						  @"Netsplit between irc1.test and irc2.test is over: 5 people came back");

	NSArray *hidden = @[@"*.net", @"*.split"];

	XCTAssertEqualObjects([IRCClient netsplitSummaryForNicknames:@[@"alice"] servers:hidden joined:NO],
						  @"Netsplit: alice quit");
}

/* ACCOUNTEXTBAN with EXTBAN's prefix: "$R:bob", "~account:bob"; none without them */
- (void)testAccountBanMask
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertNil([client.supportInfo accountBanMaskForAccount:@"bob"]);

	[client.supportInfo processConfigurationData:@"me EXTBAN=$,ARar ACCOUNTEXTBAN=R :are supported by this server"];

	XCTAssertEqualObjects([client.supportInfo accountBanMaskForAccount:@"bob"], @"$R:bob");

	[client.supportInfo reset];

	[client.supportInfo processConfigurationData:@"me EXTBAN=~,a ACCOUNTEXTBAN=account,a :are supported by this server"];

	XCTAssertEqualObjects([client.supportInfo accountBanMaskForAccount:@"bob"], @"~account:bob");
}

/* draft/ICON names the network's icon; {size} becomes the pixel size, and only HTTPS is fetched */
- (void)testNetworkIconAddress
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	XCTAssertNil(client.supportInfo.networkIconAddress);

	[client.supportInfo processConfigurationData:@"me NETWORK=Example draft/ICON=https://example.net/icon.png?size={size} :are supported by this server"];

	NSString *address = client.supportInfo.networkIconAddress;

	XCTAssertEqualObjects(address, @"https://example.net/icon.png?size={size}");

	NSURL *url = [IRCClient networkIconURLForAddress:address pixelSize:32];

	XCTAssertEqualObjects(url.absoluteString, @"https://example.net/icon.png?size=32");

	XCTAssertNil([IRCClient networkIconURLForAddress:@"http://example.net/icon.png" pixelSize:32]);

	[client.supportInfo reset];

	XCTAssertNil(client.supportInfo.networkIconAddress);
}

/* A chosen picture becomes a 64 px PNG square; see-through parts go on white; data that isn't a picture is refused */
- (void)testCustomIconData
{
	NSBitmapImageRep *picture =
	[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:10 pixelsHigh:10 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];

	NSData *pictureData = [picture representationUsingType:NSBitmapImageFileTypePNG properties:@{}]; // all see-through

	NSData *iconData = [IRCClient customIconDataFromImageData:pictureData];

	NSBitmapImageRep *icon = [NSBitmapImageRep imageRepWithData:iconData];

	XCTAssertEqual(icon.pixelsWide, 64);
	XCTAssertEqual(icon.pixelsHigh, 64);

	NSColor *corner = [[icon colorAtX:0 y:0] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];

	XCTAssertEqualWithAccuracy(corner.alphaComponent, 1.0, 0.01);
	XCTAssertEqualWithAccuracy(corner.redComponent, 1.0, 0.01);

	NSData *text = [@"not a picture" dataUsingEncoding:NSUTF8StringEncoding];

	XCTAssertNil([IRCClient customIconDataFromImageData:text]);
}

@end

NS_ASSUME_NONNULL_END
