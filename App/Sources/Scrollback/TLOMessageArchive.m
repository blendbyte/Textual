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

#import <CommonCrypto/CommonDigest.h>
#import <sqlite3.h>

#import "NSStringHelper.h"
#import "TPCPathInfo.h"
#import "TVCLogLine.h"
#import "TLOMessageArchivePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _databaseFilename			@"Message Archive.sqlite"

#define _schemaVersion				1

/* Waiting lines are written two seconds after the first, or at once when
 this many wait (a reconnect replaying history) */
#define _writeDelay					2.0
#define _writeBatchSize				500

/* The keep period until it is a setting (10.9 step F): a year */
#define _keepPeriod					(365 * 24 * 60 * 60)

/* Old messages go in steps, so writing isn't held up for long */
#define _removeBatchSize			5000

@interface TLOMessageArchiveRow : NSObject
@property (nonatomic, copy) NSString *serverId;
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, copy) NSString *viewId;
@property (nonatomic, copy) NSString *viewName;
@property (nonatomic, assign) TLOMessageArchiveViewType viewType;
@property (nonatomic, assign) NSTimeInterval time;
@property (nonatomic, assign) TVCLogLineType lineType;
@property (nonatomic, copy, nullable) NSString *nickname;
@property (nonatomic, assign) BOOL isSelf;
@property (nonatomic, assign) BOOL isHighlight;
@property (nonatomic, assign) BOOL hasLink;
@property (nonatomic, copy, nullable) NSString *msgid;
@property (nonatomic, copy) NSString *lineId;
@property (nonatomic, copy) NSString *dedupeKey;
@property (nonatomic, copy) NSString *body;
@end

@implementation TLOMessageArchiveRow
@end

@interface TLOMessageArchive ()
@property (readwrite, copy) NSURL *url;
@property (nonatomic, strong) dispatch_queue_t queue;
/* The properties below are only used on -queue */
@property (nonatomic, assign, nullable) sqlite3 *database; // NULL if it failed to open
@property (nonatomic, assign, nullable) sqlite3_stmt *insertStatement;
@property (nonatomic, strong) NSMutableArray<TLOMessageArchiveRow *> *pendingRows;
@property (nonatomic, assign) BOOL writeScheduled;
@property (nonatomic, strong, nullable) dispatch_source_t removeTimer;
@property (nonatomic, assign) BOOL closed;
@end

@implementation TLOMessageArchive

+ (TLOMessageArchive *)sharedArchive
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSString *directory = [TPCPathInfo applicationSupport];

		if (directory == nil) {
			directory = NSTemporaryDirectory();
		}

		NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:_databaseFilename]];

		TLOMessageArchive *archive = [[self alloc] initWithURL:url];

		[archive _startRemovingOldMessages];

		sharedSelf = archive;
	});

	return sharedSelf;
}

- (instancetype)initWithURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	if ((self = [super init])) {
		self.url = url;

		self.queue = dispatch_queue_create("com.textualapp.message-archive", DISPATCH_QUEUE_SERIAL);

		self.pendingRows = [NSMutableArray array];

		/* First on the queue: everything else waits for the database */
		dispatch_async(self.queue, ^{
			[self _openDatabase];
		});

		return self;
	}

	return nil;
}

#pragma mark -
#pragma mark Database

- (void)_openDatabase
{
	if ([self _openDatabaseAtURL:self.url]) {
		return;
	}

	/* Damaged: put aside (not deleted, it may be rescued) and start again */
	if (self.database == NULL && [self _moveDamagedDatabaseAside]) {
		(void)[self _openDatabaseAtURL:self.url];
	}
}

- (BOOL)_openDatabaseAtURL:(NSURL *)url
{
	sqlite3 *database = NULL;

	int result = sqlite3_open_v2(url.fileSystemRepresentation, &database, (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX), NULL);

	if (result != SQLITE_OK) {
		LogToConsoleError("Failed to open the message archive: %{public}s", sqlite3_errstr(result));

		sqlite3_close_v2(database);

		return NO;
	}

	self.database = database;

	if ([self _prepareSchema] == NO) {
		[self _closeDatabase];

		return NO;
	}

	sqlite3_stmt *insertStatement = NULL;

	result = sqlite3_prepare_v2(database,
		"INSERT OR IGNORE INTO messages "
		"(server_id, server_name, view_id, view_name, view_type, time, line_type, nickname, is_self, is_highlight, has_link, msgid, line_id, dedupe_key, body) "
		"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, &insertStatement, NULL);

	if (result != SQLITE_OK) {
		LogToConsoleError("Failed to prepare the message archive: %{public}s", sqlite3_errmsg(database));

		[self _closeDatabase];

		return NO;
	}

	self.insertStatement = insertStatement;

	return YES;
}

/* The text index has its own table, filled and emptied by triggers. Trigram
 tokens find any part of a word in any script, three characters or more. */
- (BOOL)_prepareSchema
{
	return [self _execute:
		"PRAGMA journal_mode = WAL;"
		"PRAGMA synchronous = NORMAL;"
		"CREATE TABLE IF NOT EXISTS messages ("
			"id INTEGER PRIMARY KEY, "
			"server_id TEXT NOT NULL, "
			"server_name TEXT NOT NULL, "
			"view_id TEXT NOT NULL, "
			"view_name TEXT NOT NULL, "
			"view_type INTEGER NOT NULL, "
			"time REAL NOT NULL, "
			"line_type INTEGER NOT NULL, "
			"nickname TEXT, "
			"is_self INTEGER NOT NULL DEFAULT 0, "
			"is_highlight INTEGER NOT NULL DEFAULT 0, "
			"has_link INTEGER NOT NULL DEFAULT 0, "
			"msgid TEXT, "
			"line_id TEXT NOT NULL, "
			"dedupe_key TEXT NOT NULL, "
			"body TEXT NOT NULL);"
		"CREATE UNIQUE INDEX IF NOT EXISTS messages_dedupe ON messages (view_id, dedupe_key);"
		"CREATE INDEX IF NOT EXISTS messages_view_time ON messages (view_id, time);"
		"CREATE INDEX IF NOT EXISTS messages_time ON messages (time);"
		"CREATE INDEX IF NOT EXISTS messages_highlights ON messages (time) WHERE is_highlight = 1;"
		"CREATE INDEX IF NOT EXISTS messages_msgid ON messages (msgid) WHERE msgid IS NOT NULL;"
		"CREATE VIRTUAL TABLE IF NOT EXISTS messages_text USING fts5 (body, content = 'messages', content_rowid = 'id', tokenize = 'trigram');"
		"CREATE TRIGGER IF NOT EXISTS messages_inserted AFTER INSERT ON messages BEGIN "
			"INSERT INTO messages_text (rowid, body) VALUES (new.id, new.body); "
		"END;"
		"CREATE TRIGGER IF NOT EXISTS messages_deleted AFTER DELETE ON messages BEGIN "
			"INSERT INTO messages_text (messages_text, rowid, body) VALUES ('delete', old.id, old.body); "
		"END;"
		"PRAGMA user_version = 1;"];
}

- (BOOL)_execute:(const char *)sql
{
	char *errorMessage = NULL;

	int result = sqlite3_exec(self.database, sql, NULL, NULL, &errorMessage);

	if (result != SQLITE_OK) {
		LogToConsoleError("Message archive: %{public}s", ((errorMessage) ? errorMessage : sqlite3_errstr(result)));

		sqlite3_free(errorMessage);

		return NO;
	}

	return YES;
}

- (BOOL)_moveDamagedDatabaseAside
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSString *path = self.url.path;

	if ([fileManager fileExistsAtPath:path] == NO) {
		return NO;
	}

	NSString *damagedPath = [path.stringByDeletingPathExtension stringByAppendingFormat:@" (Damaged %.0f).sqlite", [NSDate timeIntervalSinceReferenceDate]];

	for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
		NSString *source = [path stringByAppendingString:suffix];

		if ([fileManager fileExistsAtPath:source] == NO) {
			continue;
		}

		NSError *error = nil;

		if ([fileManager moveItemAtPath:source toPath:[damagedPath stringByAppendingString:suffix] error:&error] == NO) {
			LogToConsoleError("Failed to move the damaged message archive aside: %{public}@", error.localizedDescription);

			return NO;
		}
	}

	LogToConsoleError("The message archive was damaged and was moved aside");

	return YES;
}

- (void)_closeDatabase
{
	if (self.insertStatement) {
		sqlite3_finalize(self.insertStatement);

		self.insertStatement = NULL;
	}

	if (self.database) {
		sqlite3_close_v2(self.database);

		self.database = NULL;
	}
}

#pragma mark -
#pragma mark Writing

+ (BOOL)archivesLineType:(NSUInteger)lineType
{
	switch (lineType) {
		case TVCLogLineTypePrivateMessage:
		case TVCLogLineTypePrivateMessageNoHighlight:
		case TVCLogLineTypeAction:
		case TVCLogLineTypeActionNoHighlight:
		case TVCLogLineTypeNotice:
		case TVCLogLineTypeTopic:
		{
			return YES;
		}
		default:
		{
			return NO;
		}
	}
}

+ (BOOL)_archivesLogLine:(TVCLogLine *)logLine
{
	if ([self archivesLineType:logLine.lineType] == NO || logLine.isRedacted) {
		return NO;
	}

	/* Topic changes, not the topic shown on joining (numerics 332 and 333) */
	if (logLine.lineType == TVCLogLineTypeTopic) {
		return [logLine.command isEqualToString:@"TOPIC"];
	}

	return YES;
}

/* The same message replayed (history after a reconnect, a bouncer's
 playback) has the same key: its msgid, else its time, sender and text */
+ (NSString *)_dedupeKeyForLogLine:(TVCLogLine *)logLine body:(NSString *)body
{
	NSString *msgid = logLine.msgid;

	if (msgid.length > 0) {
		return [@"m:" stringByAppendingString:msgid];
	}

	NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];

	unsigned char digest[CC_SHA256_DIGEST_LENGTH];

	CC_SHA256(bodyData.bytes, (CC_LONG)bodyData.length, digest);

	NSMutableString *bodyHash = [NSMutableString stringWithCapacity:16];

	for (NSUInteger i = 0; i < 8; i++) {
		[bodyHash appendFormat:@"%02x", digest[i]];
	}

	long long milliseconds = (long long)(logLine.receivedAt.timeIntervalSince1970 * 1000.0);

	return [NSString stringWithFormat:@"t:%lld:%@:%@", milliseconds, ((logLine.nickname) ?: @""), bodyHash];
}

- (void)archiveLogLine:(TVCLogLine *)logLine
		   highlighted:(BOOL)highlighted
			   hasLink:(BOOL)hasLink
				inView:(NSString *)viewId
			  viewName:(NSString *)viewName
			  viewType:(TLOMessageArchiveViewType)viewType
			  onServer:(NSString *)serverId
			serverName:(NSString *)serverName
{
	NSParameterAssert(logLine != nil);
	NSParameterAssert(viewId != nil);
	NSParameterAssert(viewName != nil);
	NSParameterAssert(serverId != nil);
	NSParameterAssert(serverName != nil);

	if ([self.class _archivesLogLine:logLine] == NO) {
		return;
	}

	NSString *body = logLine.messageBody.stripIRCEffects;

	if (body.length == 0) {
		return;
	}

	TLOMessageArchiveRow *row = [TLOMessageArchiveRow new];

	row.serverId = serverId;
	row.serverName = serverName;
	row.viewId = viewId;
	row.viewName = viewName;
	row.viewType = viewType;
	row.time = logLine.receivedAt.timeIntervalSince1970;
	row.lineType = logLine.lineType;
	row.nickname = logLine.nickname;
	row.isSelf = (logLine.memberType == TVCLogLineMemberTypeLocalUser);
	row.isHighlight = highlighted;
	row.hasLink = hasLink;
	row.msgid = logLine.msgid;
	row.lineId = logLine.uniqueIdentifier;
	row.dedupeKey = [self.class _dedupeKeyForLogLine:logLine body:body];
	row.body = body;

	dispatch_async(self.queue, ^{
		if (self.closed) {
			return;
		}

		[self.pendingRows addObject:row];

		if (self.pendingRows.count >= _writeBatchSize) {
			[self _writePendingRows];

			return;
		}

		if (self.writeScheduled) {
			return;
		}

		self.writeScheduled = YES;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_writeDelay * NSEC_PER_SEC)), self.queue, ^{
			[self _writePendingRows];
		});
	});
}

/* On the queue */
- (void)_writePendingRows
{
	self.writeScheduled = NO;

	if (self.pendingRows.count == 0) {
		return;
	}

	NSArray *rows = [self.pendingRows copy];

	[self.pendingRows removeAllObjects];

	sqlite3_stmt *statement = self.insertStatement;

	if (statement == NULL) {
		return;
	}

	if ([self _execute:"BEGIN;"] == NO) {
		return;
	}

	for (TLOMessageArchiveRow *row in rows) {
		sqlite3_bind_text(statement, 1, row.serverId.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(statement, 2, row.serverName.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(statement, 3, row.viewId.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(statement, 4, row.viewName.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_int(statement, 5, (int)row.viewType);
		sqlite3_bind_double(statement, 6, row.time);
		sqlite3_bind_int(statement, 7, (int)row.lineType);

		if (row.nickname) {
			sqlite3_bind_text(statement, 8, row.nickname.UTF8String, -1, SQLITE_TRANSIENT);
		} else {
			sqlite3_bind_null(statement, 8);
		}

		sqlite3_bind_int(statement, 9, row.isSelf);
		sqlite3_bind_int(statement, 10, row.isHighlight);
		sqlite3_bind_int(statement, 11, row.hasLink);

		if (row.msgid) {
			sqlite3_bind_text(statement, 12, row.msgid.UTF8String, -1, SQLITE_TRANSIENT);
		} else {
			sqlite3_bind_null(statement, 12);
		}

		sqlite3_bind_text(statement, 13, row.lineId.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(statement, 14, row.dedupeKey.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(statement, 15, row.body.UTF8String, -1, SQLITE_TRANSIENT);

		if (sqlite3_step(statement) != SQLITE_DONE) {
			LogToConsoleError("Failed to archive a message: %{public}s", sqlite3_errmsg(self.database));
		}

		sqlite3_reset(statement);
		sqlite3_clear_bindings(statement);
	}

	(void)[self _execute:"COMMIT;"];
}

#pragma mark -
#pragma mark Removing

- (void)removeMessageWithMsgid:(NSString *)msgid inView:(NSString *)viewId
{
	NSParameterAssert(msgid != nil);
	NSParameterAssert(viewId != nil);

	dispatch_async(self.queue, ^{
		/* It may still be waiting to be written */
		[self _writePendingRows];

		[self _runStatement:"DELETE FROM messages WHERE view_id = ? AND msgid = ?" withStrings:@[viewId, msgid]];
	});
}

- (void)removeMessagesOlderThan:(NSDate *)date
{
	NSParameterAssert(date != nil);

	NSTimeInterval time = date.timeIntervalSince1970;

	dispatch_async(self.queue, ^{
		[self _removeMessagesOlderThan:time];
	});
}

/* On the queue, in steps: each step is its own transaction */
- (void)_removeMessagesOlderThan:(NSTimeInterval)time
{
	if (self.database == NULL) {
		return;
	}

	sqlite3_stmt *statement = NULL;

	if (sqlite3_prepare_v2(self.database, "DELETE FROM messages WHERE id IN (SELECT id FROM messages WHERE time < ? LIMIT ?)", -1, &statement, NULL) != SQLITE_OK) {
		LogToConsoleError("Failed to prepare removing old messages: %{public}s", sqlite3_errmsg(self.database));

		return;
	}

	while (YES) {
		sqlite3_bind_double(statement, 1, time);
		sqlite3_bind_int(statement, 2, _removeBatchSize);

		int result = sqlite3_step(statement);

		sqlite3_reset(statement);

		if (result != SQLITE_DONE) {
			LogToConsoleError("Failed to remove old messages: %{public}s", sqlite3_errmsg(self.database));

			break;
		}

		if (sqlite3_changes(self.database) < _removeBatchSize) {
			break;
		}
	}

	sqlite3_finalize(statement);
}

/* At launch (a minute in, not to slow it down) and once a day */
- (void)_startRemovingOldMessages
{
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);

	dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), (uint64_t)(24 * 60 * 60) * NSEC_PER_SEC, (uint64_t)(60 * NSEC_PER_SEC));

	__weak typeof(self) weakSelf = self;

	dispatch_source_set_event_handler(timer, ^{
		[weakSelf _removeMessagesOlderThan:([NSDate date].timeIntervalSince1970 - _keepPeriod)];
	});

	dispatch_resume(timer);

	self.removeTimer = timer;
}

- (void)_runStatement:(const char *)sql withStrings:(NSArray<NSString *> *)strings
{
	if (self.database == NULL) {
		return;
	}

	sqlite3_stmt *statement = NULL;

	if (sqlite3_prepare_v2(self.database, sql, -1, &statement, NULL) != SQLITE_OK) {
		LogToConsoleError("Message archive: %{public}s", sqlite3_errmsg(self.database));

		return;
	}

	[strings enumerateObjectsUsingBlock:^(NSString *string, NSUInteger index, BOOL *stop) {
		sqlite3_bind_text(statement, (int)(index + 1), string.UTF8String, -1, SQLITE_TRANSIENT);
	}];

	if (sqlite3_step(statement) != SQLITE_DONE) {
		LogToConsoleError("Message archive: %{public}s", sqlite3_errmsg(self.database));
	}

	sqlite3_finalize(statement);
}

#pragma mark -
#pragma mark Finishing

- (void)flush
{
	dispatch_sync(self.queue, ^{
		[self _writePendingRows];
	});
}

- (void)prepareForApplicationTermination
{
	dispatch_sync(self.queue, ^{
		[self _writePendingRows];

		if (self.removeTimer) {
			dispatch_source_cancel(self.removeTimer);

			self.removeTimer = nil;
		}

		[self _closeDatabase];

		self.closed = YES;
	});
}

@end

NS_ASSUME_NONNULL_END
