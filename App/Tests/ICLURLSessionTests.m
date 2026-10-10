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

#import "ICLURLSessionPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICLURLSessionTests : XCTestCase
@end

@implementation ICLURLSessionTests

/* Inline media must never request an address on the user's network (R1.7),
 whichever way the address is written */
- (void)testLocalAddressesAreRefused
{
	for (NSString *address in @[
		 @"https://127.0.0.1/a.png",
		 @"https://127.1/a.png",
		 @"https://2130706433/a.png",
		 @"https://0x7f.1/a.png",
		 @"https://0.0.0.0/a.png",
		 @"https://10.1.2.3/a.png",
		 @"https://100.64.0.1/a.png",
		 @"https://169.254.169.254/latest/meta-data",
		 @"https://172.16.0.1/a.png",
		 @"https://172.31.255.255/a.png",
		 @"https://192.168.1.1/a.png",
		 @"https://224.0.0.1/a.png",
		 @"https://255.255.255.255/a.png",
		 @"https://[::1]/a.png",
		 @"https://[::]/a.png",
		 @"https://[fe80::1]/a.png",
		 @"https://[fd00::1]/a.png",
		 @"https://[::ffff:192.168.1.1]/a.png",
		 @"https://[64:ff9b::a00:1]/a.png",
		 @"https://localhost/a.png",
		 @"https://LOCALHOST./a.png",
		 @"https://router/a.png",
		 @"https://printer.local/a.png",
		 @"https://app.localhost/a.png",
		 @"https://nas.home.arpa/a.png",
		 @"file:///etc/passwd",
		 @"ftp://example.com/a.png",
		 @"https:///a.png",
		 @"http:///a.png"])
	{
		NSURL *url = [NSURL URLWithString:address];

		XCTAssertNotNil(url, @"%@", address);

		XCTAssertFalse([ICLURLSession URLIsAllowed:url], @"%@", address);
	}
}

/* App Transport Security: inline media is only requested over HTTPS */
- (void)testPlainHTTPIsRefused
{
	XCTAssertFalse([ICLURLSession URLIsAllowed:[NSURL URLWithString:@"http://example.com/a.png"]]);
	XCTAssertFalse([ICLURLSession URLIsAllowed:[NSURL URLWithString:@"http://8.8.8.8/a.png"]]);
}

- (void)testPublicAddressesAreAllowed
{
	for (NSString *address in @[
		 @"https://example.com/a.png",
		 @"HTTPS://EXAMPLE.COM/A.PNG",
		 @"https://8.8.8.8/a.png",
		 @"https://172.32.0.1/a.png",
		 @"https://100.128.0.1/a.png",
		 @"https://[2606:4700:4700::1111]/a.png",
		 @"https://[64:ff9b::808:808]/a.png"])
	{
		XCTAssertTrue([ICLURLSession URLIsAllowed:[NSURL URLWithString:address]], @"%@", address);
	}
}

@end

NS_ASSUME_NONNULL_END
