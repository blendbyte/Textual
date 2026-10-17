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
	[self.archive archiveLogLine:logLine
					 highlighted:NO
						 hasLink:NO
						  inView:viewId
						viewName:@"#textual"
						viewType:TLOMessageArchiveViewTypeChannel
						onServer:@"server-1"
					  serverName:@"Libera.Chat"];
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

@end

NS_ASSUME_NONNULL_END
