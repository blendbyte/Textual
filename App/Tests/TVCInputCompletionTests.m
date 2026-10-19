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

#import "IRCCommandIndex.h"
#import "TVCInputCompletionPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCInputCompletionTests : XCTestCase
@end

@implementation TVCInputCompletionTests

- (nullable TVCInputCompletionQuery *)queryIn:(NSString *)string
{
	return [TVCInputCompletion queryInString:string selectedRange:NSMakeRange(string.length, 0)];
}

/* When the list opens, and for which kind */
- (void)testQueries
{
	TVCInputCompletionQuery *query = [self queryIn:@"hi @al"];

	XCTAssertEqual(query.kind, TVCInputCompletionKindNickname);
	XCTAssertEqualObjects(query.text, @"al");
	XCTAssertEqual(query.range.location, (NSUInteger)3);

	XCTAssertEqual([self queryIn:@"@"].kind, TVCInputCompletionKindNickname);
	XCTAssertEqual([self queryIn:@"join #tex"].kind, TVCInputCompletionKindChannel);
	XCTAssertEqual([self queryIn:@"/wh"].kind, TVCInputCompletionKindCommand);
	XCTAssertEqual([self queryIn:@"great :thu"].kind, TVCInputCompletionKindEmoji);

	/* A command only at the start; "//" sends a slash */
	XCTAssertNil([self queryIn:@"see /wh"]);
	XCTAssertNil([self queryIn:@"//wh"]);

	/* Smileys and addressing never open emoji */
	XCTAssertNil([self queryIn:@"nice :)"]);
	XCTAssertNil([self queryIn:@":D"]);
	XCTAssertNil([self queryIn:@"alice:"]);
	XCTAssertNil([self queryIn:@"see https://x"]);

	/* Not in the middle of a word, an address, or with a selection */
	XCTAssertNil([self queryIn:@"mail me@host"]);
	XCTAssertNil([self queryIn:@"hi @@al"]);
	XCTAssertNil([TVCInputCompletion queryInString:@"hi @alice" selectedRange:NSMakeRange(6, 0)]);
	XCTAssertNil([TVCInputCompletion queryInString:@"hi @al" selectedRange:NSMakeRange(3, 3)]);
	XCTAssertNil([self queryIn:@"hi "]);
}

/* The @ goes; the suffix only at the start; no double space */
- (void)testReplacements
{
	TVCInputCompletionItem *alice = [TVCInputCompletionItem itemWithKind:TVCInputCompletionKindNickname value:@"alice" title:@"alice" detail:nil];

	NSString *string = @"@al";

	XCTAssertEqualObjects([TVCInputCompletion replacementForItem:alice query:[self queryIn:string] inString:string nicknameSuffix:@": "], @"alice: ");

	string = @"thanks @al";

	XCTAssertEqualObjects([TVCInputCompletion replacementForItem:alice query:[self queryIn:string] inString:string nicknameSuffix:@": "], @"alice ");

	string = @"@al tomorrow";

	TVCInputCompletionQuery *query = [TVCInputCompletion queryInString:string selectedRange:NSMakeRange(3, 0)];

	XCTAssertEqualObjects([TVCInputCompletion replacementForItem:alice query:query inString:string nicknameSuffix:@","], @"alice,");

	string = @"/wh";

	TVCInputCompletionItem *command = [TVCInputCompletionItem itemWithKind:TVCInputCompletionKindCommand value:@"whois" title:@"/whois" detail:nil];

	XCTAssertEqualObjects([TVCInputCompletion replacementForItem:command query:[self queryIn:string] inString:string nicknameSuffix:@": "], @"/whois ");

	string = @"so :tada";

	TVCInputCompletionItem *emoji = [TVCInputCompletionItem itemWithKind:TVCInputCompletionKindEmoji value:@"🎉" title:@"🎉" detail:nil];

	XCTAssertEqualObjects([TVCInputCompletion replacementForItem:emoji query:[self queryIn:string] inString:string nicknameSuffix:@": "], @"🎉 ");
}

- (void)testMatching
{
	NSArray *names = @[@"bob", @"Alice", @"malice", @"al"];

	NSArray *matches = [TVCInputCompletion names:names matching:@"al" limit:10];

	NSArray *expected = @[@"Alice", @"al", @"malice"];

	XCTAssertEqualObjects(matches, expected);

	XCTAssertEqual([TVCInputCompletion names:names matching:@"" limit:2].count, (NSUInteger)2);

	NSArray<TVCInputCompletionItem *> *emoji = [TVCInputCompletion emojiMatching:@"thumbsup" limit:5];

	XCTAssertEqualObjects(emoji.firstObject.value, @"👍");

	emoji = [TVCInputCompletion emojiMatching:@"tada" limit:5];

	XCTAssertEqualObjects(emoji.firstObject.value, @"🎉");
}

/* The list shows what a command does */
- (void)testEveryCommandHasADescription
{
	for (NSString *command in [IRCCommandIndex localCommandList]) {
		XCTAssertNotNil([TVCInputCompletion descriptionForCommand:command], @"%@", command);
	}
}

@end

NS_ASSUME_NONNULL_END
