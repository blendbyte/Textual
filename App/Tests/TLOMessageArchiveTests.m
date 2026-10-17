/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
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
#import <sqlite3.h>

#import "TPCPreferencesLocal.h"
#import "TVCLogLine.h"
#import "TLOMessageArchivePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLOMessageArchiveTests : XCTestCase
@property (nonatomic, strong) NSURL *databaseURL;
@property (nonatomic, strong) TLOMessageArchive *archive;
@end

@implementation TLOMessageArchiveTests

- (void)setUp
{
	self.databaseURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	self.archive = [[TLOMessageArchive alloc] initWithURL:self.databaseURL];
}

- (void)tearDown
{
	[self.archive prepareForApplicationTermination];

	for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
		[[NSFileManager defaultManager] removeItemAtPath:[self.databaseURL.path stringByAppendingString:suffix] error:NULL];
	}
}

- (TVCLogLine *)lineOfType:(TVCLogLineType)lineType body:(NSString *)body nickname:(nullable NSString *)nickname msgid:(nullable NSString *)msgid command:(NSString *)command time:(NSDate *)time
{
	TVCLogLineMutable *logLine = [TVCLogLineMutable new];

	logLine.lineType = lineType;
	logLine.messageBody = body;
	logLine.nickname = nickname;
	logLine.msgid = msgid;
	logLine.command = command;
	logLine.receivedAt = time;

	return [logLine copy];
}

- (void)archive:(TVCLogLine *)logLine
{
	[self archive:logLine inView:@"view-1"];
}

- (void)archive:(TVCLogLine *)logLine inView:(NSString *)viewId
{
	TLOMessageArchiveView *view =
	[[TLOMessageArchiveView alloc] initWithViewId:viewId
										 viewName:@"#textual"
										 viewType:TLOMessageArchiveViewTypeChannel
										 serverId:@"server-1"
									   serverName:@"Libera.Chat"];

	[self.archive archiveLogLine:logLine highlighted:NO hasLink:NO inView:view];
}

/* What the database holds, read with SQLite directly after the queue is done */
- (NSArray<NSString *> *)bodiesForQuery:(NSString *)query
{
	[self.archive flush];

	sqlite3 *database = NULL;

	XCTAssertEqual(sqlite3_open_v2(self.databaseURL.fileSystemRepresentation, &database, SQLITE_OPEN_READONLY, NULL), SQLITE_OK);

	sqlite3_stmt *statement = NULL;

	XCTAssertEqual(sqlite3_prepare_v2(database, query.UTF8String, -1, &statement, NULL), SQLITE_OK, @"%s", sqlite3_errmsg(database));

	NSMutableArray *bodies = [NSMutableArray array];

	while (sqlite3_step(statement) == SQLITE_ROW) {
		[bodies addObject:@((const char *)sqlite3_column_text(statement, 0))];
	}

	sqlite3_finalize(statement);

	sqlite3_close_v2(database);

	return [bodies copy];
}

- (NSArray<NSString *> *)allBodies
{
	return [self bodiesForQuery:@"SELECT body FROM messages ORDER BY time, id"];
}

/* The conversation only: no joins, and the topic only when it changes */
- (void)testKeepsConversationOnly
{
	NSDate *now = [NSDate date];

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"hello" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypeAction body:@"waves" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypeNotice body:@"a notice" nickname:@"carol" msgid:nil command:@"NOTICE" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypeJoin body:@"dave joined" nickname:nil msgid:nil command:@"JOIN" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypeTopic body:@"Topic is old" nickname:nil msgid:nil command:@"332" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypeTopic body:@"alice changed the topic to new" nickname:nil msgid:nil command:@"TOPIC" time:now]];

	TVCLogLineMutable *redacted = [[self lineOfType:TVCLogLineTypePrivateMessage body:@"Message deleted" nickname:@"erin" msgid:@"x1" command:@"PRIVMSG" time:now] mutableCopy];

	redacted.isRedacted = YES;

	[self archive:[redacted copy]];

	NSArray *expected = @[@"hello", @"waves", @"a notice", @"alice changed the topic to new"];

	XCTAssertEqualObjects(self.allBodies, expected);
}

/* History replayed after a reconnect is kept once: by msgid, else by
 time, sender and text */
- (void)testKeepsTheSameMessageOnce
{
	NSDate *time = [NSDate dateWithTimeIntervalSince1970:1700000000];

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"with id" nickname:@"alice" msgid:@"abc" command:@"PRIVMSG" time:time]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"with id" nickname:@"alice" msgid:@"abc" command:@"PRIVMSG" time:[time dateByAddingTimeInterval:5]]];

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"no id" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:time]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"no id" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:time]];

	/* Not the same: another text, another time, another channel */
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"no id, again" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:time]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"no id" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:1]]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"with id" nickname:@"alice" msgid:@"abc" command:@"PRIVMSG" time:time] inView:@"view-2"];

	XCTAssertEqual(self.allBodies.count, 5);
}

/* The text index finds any part of a word, three characters or more,
 without IRC formatting */
- (void)testIndexFindsPartsOfWords
{
	NSDate *now = [NSDate date];

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"what a \x02wonderful\x02 day" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"nothing here" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"Grüße aus München" nickname:@"carol" msgid:nil command:@"PRIVMSG" time:now]];

	NSArray *found = [self bodiesForQuery:@"SELECT m.body FROM messages_text JOIN messages m ON m.id = messages_text.rowid WHERE messages_text MATCH 'NDERF'"];

	XCTAssertEqualObjects(found, @[@"what a wonderful day"]);

	found = [self bodiesForQuery:@"SELECT m.body FROM messages_text JOIN messages m ON m.id = messages_text.rowid WHERE messages_text MATCH 'ünch'"];

	XCTAssertEqualObjects(found, @[@"Grüße aus München"]);
}

/* A deleted message goes, also before it was written, and out of the index */
- (void)testRemovesDeletedMessages
{
	NSDate *now = [NSDate date];

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"keep me" nickname:@"alice" msgid:@"m1" command:@"PRIVMSG" time:now]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"delete me" nickname:@"alice" msgid:@"m2" command:@"PRIVMSG" time:now]];

	[self.archive removeMessageWithMsgid:@"m2" inView:@"view-1"];

	XCTAssertEqualObjects(self.allBodies, @[@"keep me"]);

	NSArray *found = [self bodiesForQuery:@"SELECT m.body FROM messages_text JOIN messages m ON m.id = messages_text.rowid WHERE messages_text MATCH 'delete'"];

	XCTAssertEqual(found.count, 0);
}

/* The keep period: older messages go, newer ones stay */
- (void)testRemovesMessagesOlderThanTheKeepPeriod
{
	NSDate *now = [NSDate date];

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"old" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:[now dateByAddingTimeInterval:(-400 * 24 * 60 * 60)]]];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"new" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:now]];

	[self.archive flush];

	[self.archive removeMessagesOlderThan:[now dateByAddingTimeInterval:(-365 * 24 * 60 * 60)]];

	XCTAssertEqualObjects(self.allBodies, @[@"new"]);
}

/* Highlights of imported scrollback, found as the renderer finds them */
- (void)testFindsHighlightsOfImportedLines
{
	TVCLogLineMutable *logLine = [TVCLogLineMutable new];

	logLine.lineType = TVCLogLineTypePrivateMessage;
	logLine.memberType = TVCLogLineMemberTypeNormal;
	logLine.highlightKeywords = @[@"Guest66", @"release"];
	logLine.excludeKeywords = @[@"prerelease"];

	/* Exact: a whole word only, any case */
	XCTAssertTrue([TLOMessageArchive logLineIsHighlight:logLine body:@"hi guest66, welcome" matchType:TXNicknameHighlightMatchTypeExact]);
	XCTAssertFalse([TLOMessageArchive logLineIsHighlight:logLine body:@"hi Guest667" matchType:TXNicknameHighlightMatchTypeExact]);

	/* Partial: inside a word too, but not in an excluded word */
	XCTAssertTrue([TLOMessageArchive logLineIsHighlight:logLine body:@"hi Guest667" matchType:TXNicknameHighlightMatchTypePartial]);
	XCTAssertFalse([TLOMessageArchive logLineIsHighlight:logLine body:@"the prerelease is out" matchType:TXNicknameHighlightMatchTypePartial]);
	XCTAssertTrue([TLOMessageArchive logLineIsHighlight:logLine body:@"the prerelease and the release" matchType:TXNicknameHighlightMatchTypePartial]);

	/* Regular expressions */
	logLine.highlightKeywords = @[@"gu[e]st\\d+"];

	XCTAssertTrue([TLOMessageArchive logLineIsHighlight:logLine body:@"ping Guest66" matchType:TXNicknameHighlightMatchTypeRegularExpression]);

	/* Never one's own lines, notices or lines without keywords */
	logLine.highlightKeywords = @[@"Guest66"];
	logLine.memberType = TVCLogLineMemberTypeLocalUser;

	XCTAssertFalse([TLOMessageArchive logLineIsHighlight:logLine body:@"I am Guest66" matchType:TXNicknameHighlightMatchTypeExact]);

	logLine.memberType = TVCLogLineMemberTypeNormal;
	logLine.lineType = TVCLogLineTypeNotice;

	XCTAssertFalse([TLOMessageArchive logLineIsHighlight:logLine body:@"Guest66: notice" matchType:TXNicknameHighlightMatchTypeExact]);
}

#pragma mark -
#pragma mark Search

- (void)archive:(TVCLogLine *)logLine inView:(NSString *)viewId named:(NSString *)viewName type:(TLOMessageArchiveViewType)viewType server:(NSString *)serverId highlighted:(BOOL)highlighted hasLink:(BOOL)hasLink
{
	TLOMessageArchiveView *view =
	[[TLOMessageArchiveView alloc] initWithViewId:viewId
										 viewName:viewName
										 viewType:viewType
										 serverId:serverId
									   serverName:serverId];

	[self.archive archiveLogLine:logLine highlighted:highlighted hasLink:hasLink inView:view];
}

- (TLOMessageArchiveSearchPage *)search:(TLOMessageArchiveQuery *)query offset:(NSUInteger)offset limit:(NSUInteger)limit
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"search"];

	__block TLOMessageArchiveSearchPage *page = nil;

	[self.archive search:query offset:offset limit:limit completionHandler:^(TLOMessageArchiveSearchPage *result) {
		page = result;

		[expectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:10 handler:nil];

	return page;
}

- (NSArray<NSString *> *)bodiesFound:(NSString *)string inView:(nullable NSString *)viewId
{
	TLOMessageArchiveQuery *query = [TLOMessageArchiveQuery queryWithString:string];

	query.viewId = viewId;

	return [[self search:query offset:0 limit:50].results valueForKey:@"body"];
}

- (NSArray<NSString *> *)bodiesFound:(NSString *)string
{
	return [self bodiesFound:string inView:nil];
}

/* Words, phrases and filters, read from what was typed */
- (void)testParsesQueries
{
	NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

	calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

	NSDate *now = [NSDate dateWithTimeIntervalSince1970:1791979200]; // 2026-10-14 12:00 UTC

	NSDate * (^day)(NSInteger, NSInteger, NSInteger) = ^NSDate *(NSInteger year, NSInteger month, NSInteger dayOfMonth) {
		NSDateComponents *components = [NSDateComponents new];

		components.year = year;
		components.month = month;
		components.day = dayOfMonth;

		return [calendar dateFromComponents:components];
	};

	TLOMessageArchiveQuery *query =
	[TLOMessageArchiveQuery queryWithString:@"from:@alice FROM:bob in:textual \"hello world\" deploy* has:link mentions:me http://example.org from: before:2026-10-05 after:2026-09 during:2026"
								   calendar:calendar
										now:now];

	NSArray *terms = @[@"hello world", @"deploy", @"http://example.org"];
	NSArray *nicknames = @[@"alice", @"bob"];
	NSArray *viewNames = @[@"textual"];

	XCTAssertEqualObjects(query.terms, terms);
	XCTAssertEqualObjects(query.nicknames, nicknames);
	XCTAssertEqualObjects(query.viewNames, viewNames);
	XCTAssertTrue(query.hasLink);
	XCTAssertTrue(query.mentionsMe);

	/* after: the day after September; before: the start of the day; during: narrowed by both */
	XCTAssertEqualObjects(query.earliestDate, day(2026, 10, 1));
	XCTAssertEqualObjects(query.latestDate, day(2026, 10, 5));

	/* Unknown or malformed filters and quoted ones are text; typographic quotes are quotes */
	query = [TLOMessageArchiveQuery queryWithString:@"has:files before:2026-02-30 \"from:alice\" “smart quotes” during:yesterday" calendar:calendar now:now];

	terms = @[@"has:files", @"before:2026-02-30", @"from:alice", @"smart quotes"];

	XCTAssertEqualObjects(query.terms, terms);
	XCTAssertEqual(query.nicknames.count, 0);
	XCTAssertEqualObjects(query.earliestDate, day(2026, 10, 13));
	XCTAssertEqualObjects(query.latestDate, day(2026, 10, 14));

	/* Filters still being typed: nothing to search for */
	XCTAssertTrue([TLOMessageArchiveQuery queryWithString:@" from: in: " calendar:calendar now:now].empty);
}

/* Words anywhere in a message, any case; filters; where; newest first; pages */
- (void)testSearchFindsAndFilters
{
	NSDate *time = [NSDate dateWithTimeIntervalSince1970:1791633600]; // 2026-10-10 12:00 UTC

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"the deploy went fine" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:1]]
		   inView:@"view-1" named:@"#textual" type:TLOMessageArchiveViewTypeChannel server:@"server-1" highlighted:NO hasLink:NO];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"deploying again, see https://example.org" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:2]]
		   inView:@"view-1" named:@"#textual" type:TLOMessageArchiveViewTypeChannel server:@"server-1" highlighted:NO hasLink:YES];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"Deploy notes" nickname:@"bob" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:3]]
		   inView:@"view-2" named:@"#other" type:TLOMessageArchiveViewTypeChannel server:@"server-1" highlighted:YES hasLink:NO];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"nothing to see" nickname:@"carol" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:4]]
		   inView:@"view-3" named:@"carol" type:TLOMessageArchiveViewTypeQuery server:@"server-2" highlighted:NO hasLink:NO];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"ok" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:5]]
		   inView:@"view-1" named:@"#textual" type:TLOMessageArchiveViewTypeChannel server:@"server-1" highlighted:NO hasLink:NO];
	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:@"deploy of last year" nickname:@"alice" msgid:nil command:@"PRIVMSG" time:[NSDate dateWithTimeIntervalSince1970:1748779200]] // 2025-06-01
		   inView:@"view-1" named:@"#textual" type:TLOMessageArchiveViewTypeChannel server:@"server-1" highlighted:NO hasLink:NO];

	[self.archive flush];

	NSArray *expected = @[@"Deploy notes", @"deploying again, see https://example.org", @"the deploy went fine", @"deploy of last year"];

	XCTAssertEqualObjects([self bodiesFound:@"DEPLOY"], expected);

	expected = @[@"deploying again, see https://example.org", @"the deploy went fine", @"deploy of last year"];

	XCTAssertEqualObjects([self bodiesFound:@"deploy" inView:@"view-1"], expected);

	expected = @[@"the deploy went fine", @"deploy of last year"];

	XCTAssertEqualObjects([self bodiesFound:@"deploy from:ALICE"], expected);
	XCTAssertEqualObjects([self bodiesFound:@"deploy in:other"], @[@"Deploy notes"]);
	XCTAssertEqualObjects([self bodiesFound:@"in:carol"], @[@"nothing to see"]);
	XCTAssertEqualObjects([self bodiesFound:@"has:link"], @[@"deploying again, see https://example.org"]);
	XCTAssertEqualObjects([self bodiesFound:@"mentions:me"], @[@"Deploy notes"]);
	XCTAssertEqualObjects([self bodiesFound:@"\"deploy went\""], @[@"the deploy went fine"]);
	XCTAssertEqualObjects([self bodiesFound:@"deploy before:2026-01-01"], @[@"deploy of last year"]);

	/* Shorter than the index's three characters: found in the text */
	XCTAssertEqualObjects([self bodiesFound:@"ok"], @[@"ok"]);

	/* Nothing to search for, nothing found */
	XCTAssertEqual([self bodiesFound:@"  "].count, 0);

	/* Pages */
	TLOMessageArchiveQuery *query = [TLOMessageArchiveQuery queryWithString:@"deploy"];

	TLOMessageArchiveSearchPage *page = [self search:query offset:0 limit:2];

	XCTAssertEqual(page.results.count, 2);
	XCTAssertTrue(page.hasMore);

	page = [self search:query offset:2 limit:2];

	XCTAssertEqual(page.results.count, 2);
	XCTAssertFalse(page.hasMore);

	/* Best match finds the same */
	query.order = TLOMessageArchiveSearchOrderBestMatch;

	XCTAssertEqual([self search:query offset:0 limit:10].results.count, 4);

	/* What was found where, and how many */
	TLOMessageArchiveResult *result = [self search:[TLOMessageArchiveQuery queryWithString:@"in:other notes deploy"] offset:0 limit:1].results.firstObject;

	XCTAssertEqualObjects(result.viewName, @"#other");
	XCTAssertEqualObjects(result.nickname, @"bob");
	XCTAssertTrue(result.isHighlight);

	NSArray *ranges = @[[NSValue valueWithRange:NSMakeRange(0, 6)], [NSValue valueWithRange:NSMakeRange(7, 5)]];

	XCTAssertEqualObjects(result.matchRanges, ranges);

	XCTestExpectation *expectation = [self expectationWithDescription:@"count"];

	[self.archive countResultsOfSearch:query completionHandler:^(NSUInteger count) {
		XCTAssertEqual(count, 4);

		[expectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:10 handler:nil];
}

/* A long message cut around what was found */
- (void)testSnippets
{
	NSMutableString *body = [NSMutableString string];

	for (NSUInteger i = 0; i < 30; i++) {
		[body appendString:@"lorem "];
	}

	[body appendString:@"the Needle is here"];

	for (NSUInteger i = 0; i < 30; i++) {
		[body appendString:@" ipsum"];
	}

	[self archive:[self lineOfType:TVCLogLineTypePrivateMessage body:body nickname:@"alice" msgid:nil command:@"PRIVMSG" time:[NSDate date]]];

	[self.archive flush];

	TLOMessageArchiveResult *result = [self search:[TLOMessageArchiveQuery queryWithString:@"needle"] offset:0 limit:1].results.firstObject;

	NSArray<NSValue *> *ranges = nil;

	NSString *snippet = [result snippetWithMaximumLength:40 matchRanges:&ranges];

	XCTAssertTrue([snippet hasPrefix:@"…"]);
	XCTAssertTrue([snippet hasSuffix:@"…"]);
	XCTAssertLessThanOrEqual(snippet.length, 42);
	XCTAssertEqual(ranges.count, 1);
	XCTAssertEqualObjects([snippet substringWithRange:ranges.firstObject.rangeValue], @"Needle");

	/* Short enough: all of it */
	XCTAssertEqualObjects([result snippetWithMaximumLength:1000 matchRanges:NULL], body);
}

/* The chat's history past the scrollback: the archive's messages before
 the scrollback's first line, also those of the same time (a burst) */
- (void)testMessagesBeforeTheScrollback
{
	NSDate *time = [NSDate dateWithTimeIntervalSince1970:1791633600];

	NSArray *bodies = @[@"a", @"b", @"c", @"d", @"e"];
	NSArray *offsets = @[@0, @60, @60, @60, @120];

	NSMutableArray<TVCLogLine *> *logLines = [NSMutableArray array];

	for (NSUInteger i = 0; i < bodies.count; i++) {
		TVCLogLine *logLine = [self lineOfType:TVCLogLineTypePrivateMessage body:bodies[i] nickname:@"alice" msgid:nil command:@"PRIVMSG" time:[time dateByAddingTimeInterval:[offsets[i] doubleValue]]];

		[logLines addObject:logLine];

		[self archive:logLine];
	}

	[self.archive flush];

	/* The scrollback starts at "c", which has the time of "b" and "d" */
	NSString *scrollbackLineId = logLines[2].uniqueIdentifier;
	NSTimeInterval scrollbackTime = logLines[2].receivedAt.timeIntervalSince1970;

	NSArray * (^messages)(int64_t, NSUInteger, NSUInteger, NSString *, NSUInteger *) = ^NSArray *(int64_t rowId, NSUInteger before, NSUInteger after, NSString *lineId, NSUInteger *anchorIndex) {
		XCTestExpectation *expectation = [self expectationWithDescription:@"messages"];

		__block NSArray *result = nil;

		[self.archive messagesInView:@"view-1" rowId:rowId before:before after:after scrollbackLineId:lineId scrollbackTime:scrollbackTime completionHandler:^(NSArray<TLOMessageArchiveResult *> *found, NSUInteger index) {
			result = found;

			*anchorIndex = index;

			[expectation fulfill];
		}];

		[self waitForExpectationsWithTimeout:10 handler:nil];

		return result;
	};

	NSUInteger anchorIndex = 0;

	NSArray *expected = @[@"a", @"b"];

	XCTAssertEqualObjects([messages(0, 10, 0, scrollbackLineId, &anchorIndex) valueForKey:@"body"], expected);
	XCTAssertEqual(anchorIndex, NSNotFound);

	/* Without its line in the archive: by time, so the burst isn't split */
	expected = @[@"a"];

	XCTAssertEqualObjects([messages(0, 10, 0, @"unknown", &anchorIndex) valueForKey:@"body"], expected);

	/* Around a message: up to the scrollback */
	NSArray<TLOMessageArchiveResult *> *older = messages(0, 10, 0, scrollbackLineId, &anchorIndex);

	expected = @[@"a", @"b"];

	XCTAssertEqualObjects([messages(older.firstObject.rowId, 5, 5, scrollbackLineId, &anchorIndex) valueForKey:@"body"], expected);
	XCTAssertEqual(anchorIndex, 0);

	/* One the scrollback has: none */
	TLOMessageArchiveResult *first = older.firstObject;

	NSArray *found = messages((first.rowId + 3), 5, 5, scrollbackLineId, &anchorIndex);

	XCTAssertEqual(found.count, 0);
	XCTAssertEqual(anchorIndex, NSNotFound);
}

@end


NS_ASSUME_NONNULL_END
