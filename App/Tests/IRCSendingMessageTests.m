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

#import "IRCSendingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCSendingMessageTests : XCTestCase
@end

@implementation IRCSendingMessageTests

- (NSString *)line:(NSString *)command, ... NS_REQUIRES_NIL_TERMINATION
{
	NSMutableArray *arguments = [NSMutableArray array];

	va_list list;
	va_start(list, command);

	NSString *argument = nil;

	while ((argument = va_arg(list, NSString *))) {
		[arguments addObject:argument];
	}

	va_end(list);

	return [IRCSendingMessage stringWithCommand:command arguments:arguments];
}

/* Free text is always the trailing parameter, also when it is empty */
- (void)testFreeTextIsTheTrailingParameter
{
	XCTAssertEqualObjects(([self line:@"PRIVMSG", @"#c", @"hi", nil]), @"PRIVMSG #c :hi");
	XCTAssertEqualObjects(([self line:@"TOPIC", @"#c", @"", nil]), @"TOPIC #c :");
	XCTAssertEqualObjects(([self line:@"TOPIC", @"#c", nil]), @"TOPIC #c");
	XCTAssertEqualObjects(([self line:@"PART", @"#c", nil]), @"PART #c");
	XCTAssertEqualObjects(([self line:@"CAP", @"REQ", @"batch sasl", nil]), @"CAP REQ :batch sasl");
}

/* Parameter lists go out as given (plugins pass "+o nick" as one argument);
 other commands get a trailing parameter when the last argument has spaces */
- (void)testOtherCommandsKeepTheirArguments
{
	XCTAssertEqualObjects(([self line:@"MODE", @"#c", @"+o nick", nil]), @"MODE #c +o nick");
	XCTAssertEqualObjects(([self line:@"SETNAME", @"New Name", nil]), @"SETNAME :New Name");
	XCTAssertEqualObjects(([self line:@"PONG", @":token", nil]), @"PONG ::token");
}

/* An empty argument is left out instead of cutting off the rest */
- (void)testEmptyArgumentIsLeftOut
{
	XCTAssertEqualObjects(([self line:@"JOIN", @"#c", @"", nil]), @"JOIN #c");
	XCTAssertEqualObjects(([self line:@"WHOIS", @"", @"nick", nil]), @"WHOIS nick");
}

@end

NS_ASSUME_NONNULL_END
