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

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (ChatFilterLogic)
+ (NSArray<NSString *> *)commandsForFilterAction:(NSString *)filterAction withValues:(NSDictionary<NSString *, NSString *> *)values;
@end

@interface ChatFilterTests : XCTestCase
@end

@implementation ChatFilterTests

/* Text from the network is inserted into a filter's action. It must never
 start a command of its own (U+2028 and CR/LF used to split it into lines)
 or have placeholders inside it expanded. */
- (void)testFilterActionsCannotBeInjected
{
	NSString *bundlePath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"Bundled Extensions/Chat Filters.bundle"];

	XCTAssertTrue([[NSBundle bundleWithPath:bundlePath] load]);

	Class filterLogic = NSClassFromString(@"TPI_ChatFilterLogic");

	XCTAssertNotNil(filterLogic);

	NSString *action = @"/msg %_senderNickname_% You said: %_originalMessage_%\nnot a command\n//not a command either\n%_originalMessage_%";

	NSDictionary *values = @{
		@"%_senderNickname_%" : @"mallory",
		@"%_originalMessage_%" : @"hi /quote KILL\r\n/part #x %_senderNickname_%"
	};

	NSArray *commands = [filterLogic commandsForFilterAction:action withValues:values];

	XCTAssertEqualObjects(commands, (@[@"msg mallory You said: hi /quote KILL  /part #x %_senderNickname_%"]));
}

@end

NS_ASSUME_NONNULL_END
