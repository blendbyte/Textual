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
#import "IRCChannel.h"
#import "IRCClient.h"
#import "IRCTreeItem.h"
#import "THOUnicodeHelper.h"
#import "TLOLinkParser.h"
#import "TPCPathInfo.h"
#import "IRCChannelConfig.h"
#import "IRCHighlightKeywordPrivate.h"
#import "IRCWorld.h"
#import "TXMasterController.h"
#import "IRCClientConfig.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TVCLogLine.h"
#import "HLSHistoricLogManagerPrivate.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOMessageArchivePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _databaseFilename			@"Message Archive.sqlite"

#define _schemaVersion				1

/* Waiting lines are written two seconds after the first, or at once when
 this many wait (a reconnect replaying history) */
#define _writeDelay					2.0
#define _writeBatchSize				500

/* Old messages go in steps, so writing isn't held up for long */
#define _removeBatchSize			5000

/* Scrollback lines read per step of the import */
#define _importBatchSize			500

/* In the database's meta table once the scrollback was imported */
#define _scrollbackImportedKey		@"scrollback_imported"

@interface TLOMessageArchiveView ()
@property (readwrite, copy) NSString *viewId;
@property (readwrite, copy) NSString *viewName;
@property (readwrite) TLOMessageArchiveViewType viewType;
@property (readwrite, copy) NSString *serverId;
@property (readwrite, copy) NSString *serverName;
@property (readwrite, weak, nullable) IRCTreeItem *item;
@end

@implementation TLOMessageArchiveView

+ (nullable instancetype)viewForItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	IRCClient *client = item.associatedClient;

	IRCChannel *channel = item.associatedChannel;

	NSString *viewName = @"";

	TLOMessageArchiveViewType viewType = TLOMessageArchiveViewTypeConsole;

	if (channel) {
		if (channel.isUtility) {
			return nil;
		}

		viewName = channel.name;

		viewType = ((channel.isPrivateMessage) ? TLOMessageArchiveViewTypeQuery : TLOMessageArchiveViewTypeChannel);
	}

	TLOMessageArchiveView *view =
	[[self alloc] initWithViewId:item.uniqueIdentifier
						viewName:viewName
						viewType:viewType
						serverId:client.uniqueIdentifier
					  serverName:client.networkNameAlt];

	view.item = item;

	return view;
}

- (instancetype)initWithViewId:(NSString *)viewId
					  viewName:(NSString *)viewName
					  viewType:(TLOMessageArchiveViewType)viewType
					  serverId:(NSString *)serverId
					serverName:(NSString *)serverName
{
	NSParameterAssert(viewId != nil);
	NSParameterAssert(viewName != nil);
	NSParameterAssert(serverId != nil);
	NSParameterAssert(serverName != nil);

	if ((self = [super init])) {
		self.viewId = viewId;
		self.viewName = viewName;
		self.viewType = viewType;
		self.serverId = serverId;
		self.serverName = serverName;

		return self;
	}

	return nil;
}

@end

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

@implementation TLOMessageArchiveTextLogTarget

- (instancetype)initWithView:(TLOMessageArchiveView *)view
{
	NSParameterAssert(view != nil);

	if ((self = [super init])) {
		self->_view = view;

		self.highlightKeywords = @[];
		self.excludeKeywords = @[];

		return self;
	}

	return nil;
}

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

/* Read on the queue, set on any thread */
@property (atomic, assign) NSInteger keepDaysValue;

/* Search reads on a connection of its own (WAL: readers don't wait for the
 writer, the writer doesn't wait for them) */
@property (nonatomic, strong) dispatch_queue_t searchQueue;
@property (nonatomic, assign, nullable) sqlite3 *searchDatabase;
@property (nonatomic, assign) BOOL searchClosed;
@end

/* In TLOMessageArchiveSearch.m */
@interface TLOMessageArchiveQuery (Database)
- (TLOMessageArchiveSearchPage *)_pageWithOffset:(NSUInteger)offset limit:(NSUInteger)limit inDatabase:(sqlite3 *)database;
- (NSUInteger)_countInDatabase:(sqlite3 *)database;
+ (NSArray<TLOMessageArchiveResult *> *)_messagesAround:(TLOMessageArchiveResult *)result count:(NSUInteger)count inDatabase:(sqlite3 *)database;
+ (NSArray<NSString *> *)_namesInColumn:(NSString *)column limit:(NSUInteger)limit inDatabase:(sqlite3 *)database;
+ (NSArray<TLOMessageArchiveResult *> *)_messagesInView:(NSString *)viewId rowId:(int64_t)rowId before:(NSUInteger)before after:(NSUInteger)after scrollbackLineId:(nullable NSString *)scrollbackLineId scrollbackTime:(NSTimeInterval)scrollbackTime anchorIndex:(NSUInteger *)anchorIndex inDatabase:(sqlite3 *)database;
@end

NSString * const TLOMessageArchiveDidArchiveHighlightsNotification = @"TLOMessageArchiveDidArchiveHighlightsNotification";

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

		archive.keepDaysValue = [TPCPreferences messageArchiveKeepPeriod];

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

		self.searchQueue = dispatch_queue_create("com.textualapp.message-archive.search", DISPATCH_QUEUE_SERIAL);

		self.pendingRows = [NSMutableArray array];

		self.keepDaysValue = TPCMessageArchiveKeepPeriodOneYear;

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
		"CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);"
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

	long long milliseconds = (long long)(logLine.receivedAt.timeIntervalSince1970 * 1000.0);

	return [NSString stringWithFormat:@"t:%lld:%@:%@", milliseconds, ((logLine.nickname) ?: @""), [self _hashOfBody:body]];
}

/* The first 8 bytes of the text's SHA-256, in hex */
+ (NSString *)_hashOfBody:(NSString *)body
{
	NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];

	unsigned char digest[CC_SHA256_DIGEST_LENGTH];

	CC_SHA256(bodyData.bytes, (CC_LONG)bodyData.length, digest);

	NSMutableString *bodyHash = [NSMutableString stringWithCapacity:16];

	for (NSUInteger i = 0; i < 8; i++) {
		[bodyHash appendFormat:@"%02x", digest[i]];
	}

	return [bodyHash copy];
}

/* The row for a line, or nil when it isn't kept */
+ (nullable TLOMessageArchiveRow *)_rowForLogLine:(TVCLogLine *)logLine highlighted:(BOOL)highlighted hasLink:(BOOL)hasLink inView:(TLOMessageArchiveView *)view
{
	if ([self _archivesLogLine:logLine] == NO) {
		return nil;
	}

	NSString *body = logLine.messageBody.stripIRCEffects;

	if (body.length == 0) {
		return nil;
	}

	TLOMessageArchiveRow *row = [TLOMessageArchiveRow new];

	row.serverId = view.serverId;
	row.serverName = view.serverName;
	row.viewId = view.viewId;
	row.viewName = view.viewName;
	row.viewType = view.viewType;
	row.time = logLine.receivedAt.timeIntervalSince1970;
	row.lineType = logLine.lineType;
	row.nickname = logLine.nickname;
	row.isSelf = (logLine.memberType == TVCLogLineMemberTypeLocalUser);
	row.isHighlight = highlighted;
	row.hasLink = hasLink;
	row.msgid = logLine.msgid;
	row.lineId = logLine.uniqueIdentifier;
	row.dedupeKey = [self _dedupeKeyForLogLine:logLine body:body];
	row.body = body;

	return row;
}

- (void)archiveLogLine:(TVCLogLine *)logLine
		   highlighted:(BOOL)highlighted
			   hasLink:(BOOL)hasLink
				inView:(TLOMessageArchiveView *)view
{
	NSParameterAssert(logLine != nil);
	NSParameterAssert(view != nil);

	if (self.keepDaysValue == TPCMessageArchiveKeepPeriodOff) {
		return;
	}

	TLOMessageArchiveRow *row = [self.class _rowForLogLine:logLine highlighted:highlighted hasLink:hasLink inView:view];

	if (row == nil) {
		return;
	}

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

	[self _insertRows:rows];
}

/* On the queue, in one transaction */
- (void)_insertRows:(NSArray<TLOMessageArchiveRow *> *)rows
{
	if (self.insertStatement == NULL) {
		return;
	}

	if ([self _execute:"BEGIN;"] == NO) {
		return;
	}

	for (TLOMessageArchiveRow *row in rows) {
		(void)[self _insertRow:row];
	}

	(void)[self _execute:"COMMIT;"];

	[self _postHighlightsNotificationForRows:rows];
}

/* On the queue, in a transaction: NO when it was there already (or failed) */
- (BOOL)_insertRow:(TLOMessageArchiveRow *)row
{
	sqlite3_stmt *statement = self.insertStatement;

	if (statement == NULL) {
		return NO;
	}

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

	BOOL inserted = NO;

	if (sqlite3_step(statement) == SQLITE_DONE) {
		inserted = (sqlite3_changes(self.database) > 0);
	} else {
		LogToConsoleError("Failed to archive a message: %{public}s", sqlite3_errmsg(self.database));
	}

	sqlite3_reset(statement);
	sqlite3_clear_bindings(statement);

	return inserted;
}

- (void)_postHighlightsNotificationForRows:(NSArray<TLOMessageArchiveRow *> *)rows
{
	for (TLOMessageArchiveRow *row in rows) {
		if (row.isHighlight == NO) {
			continue;
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			[RZNotificationCenter() postNotificationName:TLOMessageArchiveDidArchiveHighlightsNotification object:self];
		});

		break;
	}
}

#pragma mark -
#pragma mark Importing

- (void)importScrollbackOfViews:(NSArray<TLOMessageArchiveView *> *)views
{
	NSParameterAssert(views != nil);

	/* Read here: the preferences are read on the main thread */
	TXNicknameHighlightMatchType matchType = [TPCPreferences highlightMatchingMethod];

	dispatch_async(self.queue, ^{
		if (self.database == NULL || [[self _metaValueForKey:_scrollbackImportedKey] isEqualToString:@"1"]) {
			return;
		}

		LogToConsoleInfo("Importing the scrollback of %{public}lu views into the message archive", views.count);

		[self _importScrollbackOfViews:views atIndex:0 matchType:matchType importedCount:0];
	});
}

/* One view after the other, a batch at a time: the scrollback's queue and
 this one take other work in between */
- (void)_importScrollbackOfViews:(NSArray<TLOMessageArchiveView *> *)views atIndex:(NSUInteger)index matchType:(TXNicknameHighlightMatchType)matchType importedCount:(NSUInteger)importedCount
{
	if (self.closed) {
		return;
	}

	if (index >= views.count) {
		[self _setMetaValue:@"1" forKey:_scrollbackImportedKey];

		LogToConsoleInfo("Imported %{public}lu scrollback lines into the message archive", importedCount);

		return;
	}

	TLOMessageArchiveView *view = views[index];

	IRCTreeItem *item = view.item;

	if (item == nil) {
		[self _importScrollbackOfViews:views atIndex:(index + 1) matchType:matchType importedCount:importedCount];

		return;
	}

	NSTimeInterval oldestTime = [self _oldestKeptTime];

	__block NSUInteger viewImportedCount = importedCount;

	[sharedHistoricLog() enumerateEntriesForItem:item batchSize:_importBatchSize usingBlock:^(NSArray<TVCLogLine *> *entries, void (^next)(void)) {
		/* Found off the queue: links and keywords take a moment */
		NSMutableArray<TLOMessageArchiveRow *> *rows = [NSMutableArray arrayWithCapacity:entries.count];

		for (TVCLogLine *logLine in entries) {
			if (logLine.receivedAt.timeIntervalSince1970 < oldestTime) {
				continue;
			}

			NSString *body = logLine.messageBody.stripIRCEffects;

			BOOL highlighted = [self.class logLineIsHighlight:logLine body:body matchType:matchType];

			BOOL hasLink = ([TLOLinkParser locateLinksInString:body].count > 0);

			TLOMessageArchiveRow *row = [self.class _rowForLogLine:logLine highlighted:highlighted hasLink:hasLink inView:view];

			if (row) {
				[rows addObject:row];
			}
		}

		dispatch_async(self.queue, ^{
			if (self.closed) {
				return;
			}

			if (rows.count > 0) {
				[self _insertRows:rows];

				viewImportedCount += rows.count;
			}

			if (next) {
				next();

				return;
			}

			[self _importScrollbackOfViews:views atIndex:(index + 1) matchType:matchType importedCount:viewImportedCount];
		});
	}];
}

+ (BOOL)logLineIsHighlight:(TVCLogLine *)logLine body:(NSString *)body matchType:(NSUInteger)matchType
{
	NSParameterAssert(logLine != nil);
	NSParameterAssert(body != nil);

	/* As -[TVCLogRenderer scanForKeywords] */
	TVCLogLineType lineType = logLine.lineType;

	if ((lineType != TVCLogLineTypePrivateMessage && lineType != TVCLogLineTypeAction) || logLine.memberType != TVCLogLineMemberTypeNormal) {
		return NO;
	}

	return [self _body:body matchesKeywords:logLine.highlightKeywords excludeKeywords:logLine.excludeKeywords matchType:matchType];
}

+ (BOOL)_body:(NSString *)body matchesKeywords:(nullable NSArray<NSString *> *)keywords excludeKeywords:(nullable NSArray<NSString *> *)excludeKeywords matchType:(NSUInteger)matchType
{
	if (keywords.count == 0 || body.length == 0) {
		return NO;
	}

	NSMutableArray<NSValue *> *excludedRanges = [NSMutableArray array];

	for (NSString *excludeKeyword in excludeKeywords) {
		[body enumerateMatchesOfString:excludeKeyword withBlock:^(NSRange range, BOOL *stop) {
			[excludedRanges addObject:[NSValue valueWithRange:range]];
		} options:NSCaseInsensitiveSearch];
	}

	BOOL (^excluded)(NSRange) = ^BOOL (NSRange range) {
		for (NSValue *excludedRange in excludedRanges) {
			if (NSIntersectionRange(range, excludedRange.rangeValue).length > 0) {
				return YES;
			}
		}

		return NO;
	};

	if (matchType == TXNicknameHighlightMatchTypeRegularExpression) {
		for (NSString *keyword in keywords) {
			NSRange range = [XRRegularExpression string:body rangeOfRegex:keyword withoutCase:YES];

			if (range.location != NSNotFound && excluded(range) == NO) {
				return YES;
			}
		}

		return NO;
	}

	BOOL exactMatching = (matchType == TXNicknameHighlightMatchTypeExact);

	for (NSString *keyword in keywords) {
		__block BOOL found = NO;

		[body enumerateMatchesOfString:keyword withBlock:^(NSRange range, BOOL *stop) {
			if (excluded(range)) {
				return;
			}

			if (exactMatching && [self _rangeIsWholeWord:range inString:body] == NO) {
				return;
			}

			found = YES;

			*stop = YES;
		} options:NSCaseInsensitiveSearch];

		if (found) {
			return YES;
		}
	}

	return NO;
}

/* As -[TVCLogRenderer sectionOfBodyIsSurroundedByNonAlphabeticals:]: no
 letter or digit right before or after, where the match itself starts or
 ends with one */
+ (BOOL)_rangeIsWholeWord:(NSRange)range inString:(NSString *)string
{
	BOOL (^isWordCharacter)(UniChar) = ^BOOL (UniChar character) {
		return (CS_StringIsBase10Numeric(character) || [THOUnicodeHelper isAlphabeticalCodePoint:character]);
	};

	NSUInteger length = string.length;

	if (isWordCharacter([string characterAtIndex:range.location]) && range.location > 0) {
		if (isWordCharacter([string characterAtIndex:(range.location - 1)])) {
			return NO;
		}
	}

	if (isWordCharacter([string characterAtIndex:(NSMaxRange(range) - 1)]) && NSMaxRange(range) < length) {
		if (isWordCharacter([string characterAtIndex:NSMaxRange(range)])) {
			return NO;
		}
	}

	return YES;
}

#pragma mark -
#pragma mark Meta

/* On the queue */
- (nullable NSString *)_metaValueForKey:(NSString *)key
{
	if (self.database == NULL) {
		return nil;
	}

	sqlite3_stmt *statement = NULL;

	if (sqlite3_prepare_v2(self.database, "SELECT value FROM meta WHERE key = ?", -1, &statement, NULL) != SQLITE_OK) {
		return nil;
	}

	sqlite3_bind_text(statement, 1, key.UTF8String, -1, SQLITE_TRANSIENT);

	NSString *value = nil;

	if (sqlite3_step(statement) == SQLITE_ROW) {
		const unsigned char *text = sqlite3_column_text(statement, 0);

		if (text) {
			value = @((const char *)text);
		}
	}

	sqlite3_finalize(statement);

	return value;
}

- (void)_setMetaValue:(NSString *)value forKey:(NSString *)key
{
	[self _runStatement:"INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)" withStrings:@[key, value]];
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
		[weakSelf _removeExpiredMessages];
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
#pragma mark Keep Period

- (NSInteger)keepDays
{
	return self.keepDaysValue;
}

- (void)setKeepDays:(NSInteger)keepDays
{
	NSInteger oldKeepDays = self.keepDaysValue;

	self.keepDaysValue = keepDays;

	/* Shorter: what is older now goes at once, not at the next daily round */
	if (keepDays > 0 && (oldKeepDays <= 0 || keepDays < oldKeepDays)) {
		dispatch_async(self.queue, ^{
			[self _removeExpiredMessages];
		});
	}
}

/* Messages older than this aren't kept; 0 when everything is */
- (NSTimeInterval)_oldestKeptTime
{
	NSInteger keepDays = self.keepDaysValue;

	if (keepDays <= 0) {
		return 0;
	}

	return ([NSDate date].timeIntervalSince1970 - (keepDays * 24 * 60 * 60));
}

/* On the queue */
- (void)_removeExpiredMessages
{
	NSTimeInterval oldestTime = [self _oldestKeptTime];

	if (oldestTime > 0) {
		[self _removeMessagesOlderThan:oldestTime];
	}
}

+ (BOOL)keepsMessagesOfItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if ([TPCPreferences messageArchiveKeepPeriod] == TPCMessageArchiveKeepPeriodOff) {
		return NO;
	}

	if (item.associatedClient.config.excludedFromArchive) {
		return NO;
	}

	IRCChannel *channel = item.associatedChannel;

	if (channel && channel.config.excludedFromArchive) {
		return NO;
	}

	return YES;
}

#pragma mark -
#pragma mark Deleting

- (void)deleteAllMessagesImportingScrollbackAgain:(BOOL)importScrollbackAgain completionHandler:(nullable void (^)(void))completionHandler
{
	/* The search connection first: a search after this one waits for the
	 writer (-_openSearchDatabase), so it opens the new database */
	dispatch_async(self.searchQueue, ^{
		if (self.searchDatabase) {
			sqlite3_close_v2(self.searchDatabase);

			self.searchDatabase = NULL;
		}

		dispatch_async(self.queue, ^{
			if (self.closed) {
				return;
			}

			[self.pendingRows removeAllObjects];

			[self _closeDatabase];

			[self _deleteDatabaseFiles];

			[self _openDatabase];

			if (importScrollbackAgain == NO) {
				[self _setMetaValue:@"1" forKey:_scrollbackImportedKey];
			}

			LogToConsoleInfo("The message archive was deleted");

			if (completionHandler) {
				dispatch_async(dispatch_get_main_queue(), completionHandler);
			}
		});
	});
}

/* On the queue, closed */
- (void)_deleteDatabaseFiles
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSString *path = self.url.path;

	for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
		NSString *filePath = [path stringByAppendingString:suffix];

		if ([fileManager fileExistsAtPath:filePath] == NO) {
			continue;
		}

		NSError *error = nil;

		if ([fileManager removeItemAtPath:filePath error:&error] == NO) {
			LogToConsoleError("Failed to delete the message archive: %{public}@", error.localizedDescription);
		}
	}
}

- (void)importScrollbackAgain
{
	dispatch_async(self.queue, ^{
		[self _runStatement:"DELETE FROM meta WHERE key = ?" withStrings:@[_scrollbackImportedKey]];
	});
}

- (void)deleteMessagesOfServer:(nullable NSString *)serverId inView:(nullable NSString *)viewId completionHandler:(nullable void (^)(void))completionHandler
{
	NSParameterAssert(serverId != nil || viewId != nil);

	dispatch_async(self.queue, ^{
		/* Some may still be waiting to be written */
		[self _writePendingRows];

		if (viewId) {
			[self _runStatement:"DELETE FROM messages WHERE view_id = ?" withStrings:@[viewId]];
		} else {
			[self _runStatement:"DELETE FROM messages WHERE server_id = ?" withStrings:@[serverId]];
		}

		if (completionHandler) {
			dispatch_async(dispatch_get_main_queue(), completionHandler);
		}
	});
}

#pragma mark -
#pragma mark Size

- (unsigned long long)fileSize
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSString *path = self.url.path;

	unsigned long long fileSize = 0;

	for (NSString *suffix in @[@"", @"-wal"]) {
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:[path stringByAppendingString:suffix] error:NULL];

		fileSize += attributes.fileSize;
	}

	return fileSize;
}

- (void)countMessagesOfServer:(nullable NSString *)serverId inView:(nullable NSString *)viewId completionHandler:(void (^)(NSUInteger count))completionHandler
{
	NSParameterAssert(completionHandler != nil);

	dispatch_async(self.searchQueue, ^{
		NSUInteger count = 0;

		sqlite3 *database = [self _openSearchDatabase];

		sqlite3_stmt *statement = NULL;

		const char *sql = "SELECT count(*) FROM messages";

		if (viewId) {
			sql = "SELECT count(*) FROM messages WHERE view_id = ?";
		} else if (serverId) {
			sql = "SELECT count(*) FROM messages WHERE server_id = ?";
		}

		if (database && sqlite3_prepare_v2(database, sql, -1, &statement, NULL) == SQLITE_OK) {
			NSString *argument = ((viewId) ?: serverId);

			if (argument) {
				sqlite3_bind_text(statement, 1, argument.UTF8String, -1, SQLITE_TRANSIENT);
			}

			if (sqlite3_step(statement) == SQLITE_ROW) {
				count = (NSUInteger)sqlite3_column_int64(statement, 0);
			}

			sqlite3_finalize(statement);
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(count);
		});
	});
}

#pragma mark -
#pragma mark Text Logs

- (void)importTextLogsInFolder:(NSURL *)folderURL
			   progressHandler:(nullable void (^)(NSUInteger filesDone, NSUInteger fileCount))progressHandler
			 completionHandler:(void (^)(NSUInteger importedCount))completionHandler
{
	[self importTextLogsInFolder:folderURL
						resolver:^TLOMessageArchiveTextLogTarget * _Nullable (NSString *serverFolder, TLOMessageArchiveViewType viewType, NSString *viewName) {
							return [TLOMessageArchive _textLogTargetForServerFolder:serverFolder viewType:viewType viewName:viewName];
						}
				 progressHandler:progressHandler
			   completionHandler:completionHandler];
}

- (void)importTextLogsInFolder:(NSURL *)folderURL
					  resolver:(TLOMessageArchiveTextLogResolver)resolver
			   progressHandler:(nullable void (^)(NSUInteger filesDone, NSUInteger fileCount))progressHandler
			 completionHandler:(void (^)(NSUInteger importedCount))completionHandler
{
	NSParameterAssert(folderURL != nil);
	NSParameterAssert(resolver != nil);
	NSParameterAssert(completionHandler != nil);

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		NSUInteger importedCount = 0;

		NSArray<NSURL *> *files = @[];

		if (self.keepDaysValue != TPCMessageArchiveKeepPeriodOff) {
			files = [self.class _textLogFilesInFolder:folderURL];
		}

		LogToConsoleInfo("Importing %{public}lu text logs into the message archive", files.count);

		/* "<server folder>/<view type>/<view name>" → its target, or NSNull */
		NSMutableDictionary<NSString *, id> *targets = [NSMutableDictionary dictionary];

		NSTimeInterval oldestTime = [self _oldestKeptTime];

		NSUInteger fileIndex = 0;

		for (NSURL *file in files) {
			@autoreleasepool {
				importedCount += [self _importTextLogFile:file targets:targets resolver:resolver oldestTime:oldestTime];
			}

			fileIndex += 1;

			if (progressHandler) {
				NSUInteger filesDone = fileIndex;

				dispatch_async(dispatch_get_main_queue(), ^{
					progressHandler(filesDone, files.count);
				});
			}
		}

		LogToConsoleInfo("Imported %{public}lu messages from text logs into the message archive", importedCount);

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(importedCount);
		});
	});
}

/* The text logs under a folder: "<day>.txt" files, in order */
+ (NSArray<NSURL *> *)_textLogFilesInFolder:(NSURL *)folderURL
{
	NSDirectoryEnumerator *enumerator =
	[[NSFileManager defaultManager] enumeratorAtURL:folderURL
						 includingPropertiesForKeys:@[NSURLIsRegularFileKey]
											options:NSDirectoryEnumerationSkipsHiddenFiles
									   errorHandler:nil];

	NSMutableArray<NSURL *> *files = [NSMutableArray array];

	for (NSURL *file in enumerator) {
		if ([self _dayOfTextLogFile:file] == nil) {
			continue;
		}

		[files addObject:file];
	}

	[files sortUsingComparator:^NSComparisonResult(NSURL *file1, NSURL *file2) {
		return [file1.path compare:file2.path];
	}];

	return [files copy];
}

/* Local midnight of the day a text log is named after ("2026-10-17.txt"), or nil */
+ (nullable NSDate *)_dayOfTextLogFile:(NSURL *)file
{
	NSString *name = file.lastPathComponent;

	if (name.length != 14 || [name hasSuffix:@".txt"] == NO) {
		return nil;
	}

	NSInteger year = _numberInString(name, 0, 4);
	NSInteger month = _numberInString(name, 5, 2);
	NSInteger day = _numberInString(name, 8, 2);

	if (year < 0 || month < 0 || day < 0 || [name characterAtIndex:4] != '-' || [name characterAtIndex:7] != '-') {
		return nil;
	}

	NSDateComponents *components = [NSDateComponents new];

	components.year = year;
	components.month = month;
	components.day = day;

	return [[NSCalendar currentCalendar] dateFromComponents:components];
}

/* The digits at a place in a string as a number, or -1 */
static NSInteger _numberInString(NSString *string, NSUInteger location, NSUInteger length)
{
	if ((location + length) > string.length) {
		return -1;
	}

	NSInteger number = 0;

	for (NSUInteger i = location; i < (location + length); i++) {
		unichar character = [string characterAtIndex:i];

		if (character < '0' || character > '9') {
			return -1;
		}

		number = ((number * 10) + (character - '0'));
	}

	return number;
}

/* Off the queue: reads one file and archives its lines; how many were new */
- (NSUInteger)_importTextLogFile:(NSURL *)file
						 targets:(NSMutableDictionary<NSString *, id> *)targets
						resolver:(TLOMessageArchiveTextLogResolver)resolver
					  oldestTime:(NSTimeInterval)oldestTime
{
	NSDate *day = [self.class _dayOfTextLogFile:file];

	if (day == nil) {
		return 0;
	}

	/* Two days of slack for time zones */
	if (oldestTime > 0 && (day.timeIntervalSince1970 + (2 * 24 * 60 * 60)) < oldestTime) {
		return 0;
	}

	/* <server folder>/Console/<day>.txt, <server folder>/Channels/<channel>/<day>.txt,
	 <server folder>/Queries/<nickname>/<day>.txt (TLOFileLogger) */
	NSArray<NSString *> *components = file.pathComponents;

	NSUInteger componentCount = components.count;

	if (componentCount < 3) {
		return 0;
	}

	NSString *parentFolder = components[(componentCount - 2)];

	NSString *serverFolder = nil;

	NSString *viewName = @"";

	TLOMessageArchiveViewType viewType = TLOMessageArchiveViewTypeConsole;

	if ([parentFolder isEqualToString:TLOFileLoggerConsoleDirectoryName]) {
		serverFolder = components[(componentCount - 3)];
	} else if (componentCount >= 4) {
		NSString *typeFolder = components[(componentCount - 3)];

		if ([typeFolder isEqualToString:TLOFileLoggerChannelDirectoryName]) {
			viewType = TLOMessageArchiveViewTypeChannel;
		} else if ([typeFolder isEqualToString:TLOFileLoggerPrivateMessageDirectoryName]) {
			viewType = TLOMessageArchiveViewTypeQuery;
		} else {
			return 0;
		}

		viewName = parentFolder;

		serverFolder = components[(componentCount - 4)];
	} else {
		return 0;
	}

	NSString *targetKey = [NSString stringWithFormat:@"%@/%lu/%@", serverFolder, viewType, viewName];

	id target = targets[targetKey];

	if (target == nil) {
		/* Servers and channels are read on the main queue (the main queue
		 never waits for this one) */
		__block TLOMessageArchiveTextLogTarget *resolvedTarget = nil;

		dispatch_sync(dispatch_get_main_queue(), ^{
			resolvedTarget = resolver(serverFolder, viewType, viewName);
		});

		target = ((resolvedTarget) ?: [NSNull null]);

		targets[targetKey] = target;
	}

	if ([target isKindOfClass:[TLOMessageArchiveTextLogTarget class]] == NO) {
		return 0;
	}

	NSString *contents = [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:NULL];

	if (contents == nil) {
		return 0;
	}

	NSMutableArray<TLOMessageArchiveRow *> *rows = [NSMutableArray array];

	[contents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
		TLOMessageArchiveRow *row = [self.class _rowForTextLogLine:line day:day target:target];

		if (row == nil || row.time < oldestTime) {
			return;
		}

		[rows addObject:row];
	}];

	__block NSUInteger importedCount = 0;

	for (NSUInteger index = 0; index < rows.count; index += _importBatchSize) {
		NSArray *batch = [rows subarrayWithRange:NSMakeRange(index, MIN(_importBatchSize, (rows.count - index)))];

		dispatch_sync(self.queue, ^{
			importedCount += [self _insertTextLogRows:batch];
		});
	}

	return importedCount;
}

/* A line of a text log as TLOFileLogger writes it, or nil for other lines
 (joins, mode changes and the like):

	[2026-10-17T14:03:21+0200] <@alice> a message
	[2026-10-17T14:03:21+0200] • alice: an action
	[2026-10-17T14:03:21+0200] -bob- a notice

 Older logs may have only the time ([14:03:21]): on the file's day. */
+ (nullable TLOMessageArchiveRow *)_rowForTextLogLine:(NSString *)line day:(NSDate *)day target:(TLOMessageArchiveTextLogTarget *)target
{
	if ([line hasPrefix:@"["] == NO) {
		return nil;
	}

	NSRange timeEnd = [line rangeOfString:@"] "];

	if (timeEnd.location == NSNotFound) {
		return nil;
	}

	NSDate *date = [self _dateOfTextLogTimestamp:[line substringWithRange:NSMakeRange(1, (timeEnd.location - 1))] day:day];

	if (date == nil) {
		return nil;
	}

	NSString *rest = [line substringFromIndex:NSMaxRange(timeEnd)];

	TVCLogLineType lineType = TVCLogLineTypePrivateMessage;

	NSRange nicknameRange = NSMakeRange(NSNotFound, 0);

	NSRange end = NSMakeRange(NSNotFound, 0);

	if ([rest hasPrefix:@"<"]) {
		end = [rest rangeOfString:@"> "];

		nicknameRange = NSMakeRange(1, (end.location - 1));
	} else if ([rest hasPrefix:@"• "]) {
		lineType = TVCLogLineTypeAction;

		end = [rest rangeOfString:@": " options:0 range:NSMakeRange(2, (rest.length - 2))];

		nicknameRange = NSMakeRange(2, (end.location - 2));
	} else if ([rest hasPrefix:@"-"]) {
		lineType = TVCLogLineTypeNotice;

		end = [rest rangeOfString:@"- " options:0 range:NSMakeRange(1, (rest.length - 1))];

		nicknameRange = NSMakeRange(1, (end.location - 1));
	}

	if (end.location == NSNotFound) {
		return nil;
	}

	NSString *nickname = [rest substringWithRange:nicknameRange];

	/* A message's sender has their mode symbol before it (<@alice>) */
	if (lineType == TVCLogLineTypePrivateMessage) {
		NSCharacterSet *modeSymbols = [NSCharacterSet characterSetWithCharactersInString:@"~&@%+!"];

		while (nickname.length > 0 && [modeSymbols characterIsMember:[nickname characterAtIndex:0]]) {
			nickname = [nickname substringFromIndex:1];
		}
	}

	NSString *body = [rest substringFromIndex:NSMaxRange(end)];

	if (nickname.length == 0 || [nickname containsString:@" "] || body.length == 0) {
		return nil;
	}

	TLOMessageArchiveView *view = target.view;

	NSString *localNickname = target.localNickname;

	BOOL isSelf = (localNickname && [nickname caseInsensitiveCompare:localNickname] == NSOrderedSame);

	BOOL highlighted = (isSelf == NO && lineType != TVCLogLineTypeNotice &&
						[self _body:body matchesKeywords:target.highlightKeywords excludeKeywords:target.excludeKeywords matchType:target.matchType]);

	TLOMessageArchiveRow *row = [TLOMessageArchiveRow new];

	row.serverId = view.serverId;
	row.serverName = view.serverName;
	row.viewId = view.viewId;
	row.viewName = view.viewName;
	row.viewType = view.viewType;
	row.time = date.timeIntervalSince1970;
	row.lineType = lineType;
	row.nickname = nickname;
	row.isSelf = isSelf;
	row.isHighlight = highlighted;
	row.hasLink = ([TLOLinkParser locateLinksInString:body].count > 0);
	row.lineId = @""; // not in the scrollback
	row.dedupeKey = [NSString stringWithFormat:@"l:%lld:%@:%@", (long long)row.time, nickname, [self _hashOfBody:body]];
	row.body = body;

	return row;
}

/* "2026-10-17T14:03:21+0200" (also +02:00), or "14:03:21" on the day */
+ (nullable NSDate *)_dateOfTextLogTimestamp:(NSString *)timestamp day:(NSDate *)day
{
	NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

	if (timestamp.length == 8) {
		NSInteger hour = _numberInString(timestamp, 0, 2);
		NSInteger minute = _numberInString(timestamp, 3, 2);
		NSInteger second = _numberInString(timestamp, 6, 2);

		if (hour < 0 || minute < 0 || second < 0) {
			return nil;
		}

		calendar.timeZone = [NSTimeZone localTimeZone];

		return [calendar dateBySettingHour:hour minute:minute second:second ofDate:day options:0];
	}

	if (timestamp.length < 24 || [timestamp characterAtIndex:10] != 'T') {
		return nil;
	}

	unichar sign = [timestamp characterAtIndex:19];

	NSUInteger zoneMinutesLocation = (([timestamp characterAtIndex:22] == ':') ? 23 : 22);

	NSInteger zoneHours = _numberInString(timestamp, 20, 2);
	NSInteger zoneMinutes = _numberInString(timestamp, zoneMinutesLocation, 2);

	if ((sign != '+' && sign != '-') || zoneHours < 0 || zoneMinutes < 0) {
		return nil;
	}

	NSInteger zoneSeconds = (((zoneHours * 60) + zoneMinutes) * 60);

	NSDateComponents *components = [NSDateComponents new];

	components.year = _numberInString(timestamp, 0, 4);
	components.month = _numberInString(timestamp, 5, 2);
	components.day = _numberInString(timestamp, 8, 2);
	components.hour = _numberInString(timestamp, 11, 2);
	components.minute = _numberInString(timestamp, 14, 2);
	components.second = _numberInString(timestamp, 17, 2);

	if (components.year < 0 || components.month < 0 || components.day < 0 || components.hour < 0 || components.minute < 0 || components.second < 0) {
		return nil;
	}

	components.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:((sign == '-') ? -zoneSeconds : zoneSeconds)];

	return [calendar dateFromComponents:components];
}

/* On the queue, in one transaction: the lines not archived yet. The same
 message printed live has its time to the millisecond, a text log only to
 the second, so a line is new when the view has no message with its sender
 and text within that second. */
- (NSUInteger)_insertTextLogRows:(NSArray<TLOMessageArchiveRow *> *)rows
{
	if (self.closed || self.database == NULL || self.insertStatement == NULL) {
		return 0;
	}

	sqlite3_stmt *existsStatement = NULL;

	if (sqlite3_prepare_v2(self.database, "SELECT 1 FROM messages WHERE view_id = ? AND time >= ? AND time < ? AND nickname IS ? AND body = ? LIMIT 1", -1, &existsStatement, NULL) != SQLITE_OK) {
		LogToConsoleError("Failed to prepare importing text logs: %{public}s", sqlite3_errmsg(self.database));

		return 0;
	}

	if ([self _execute:"BEGIN;"] == NO) {
		sqlite3_finalize(existsStatement);

		return 0;
	}

	NSMutableArray<TLOMessageArchiveRow *> *insertedRows = [NSMutableArray array];

	for (TLOMessageArchiveRow *row in rows) {
		sqlite3_bind_text(existsStatement, 1, row.viewId.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_double(existsStatement, 2, row.time);
		sqlite3_bind_double(existsStatement, 3, (row.time + 1.0));
		sqlite3_bind_text(existsStatement, 4, row.nickname.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(existsStatement, 5, row.body.UTF8String, -1, SQLITE_TRANSIENT);

		BOOL exists = (sqlite3_step(existsStatement) == SQLITE_ROW);

		sqlite3_reset(existsStatement);
		sqlite3_clear_bindings(existsStatement);

		if (exists) {
			continue;
		}

		if ([self _insertRow:row]) {
			[insertedRows addObject:row];
		}
	}

	(void)[self _execute:"COMMIT;"];

	sqlite3_finalize(existsStatement);

	[self _postHighlightsNotificationForRows:insertedRows];

	return insertedRows.count;
}

/* The server and channel a text log's folders name (Libera (1a2b3)/Channels/#textual):
 by the first five characters of the server's id in the folder name, else by
 its name; channels and queries by name. Those that are gone keep their
 names, with ids of their own. Highlights: the keywords that apply there
 (not those limited to people) and the nickname now. */
+ (nullable TLOMessageArchiveTextLogTarget *)_textLogTargetForServerFolder:(NSString *)serverFolder viewType:(TLOMessageArchiveViewType)viewType viewName:(NSString *)viewName
{
	if ([TPCPreferences messageArchiveKeepPeriod] == TPCMessageArchiveKeepPeriodOff) {
		return nil;
	}

	NSString *serverName = serverFolder;

	NSString *serverIdPrefix = nil;

	NSRange idStart = [serverFolder rangeOfString:@" (" options:NSBackwardsSearch];

	if (idStart.location != NSNotFound && [serverFolder hasSuffix:@")"]) {
		serverName = [serverFolder substringToIndex:idStart.location];

		serverIdPrefix = [serverFolder substringWithRange:NSMakeRange(NSMaxRange(idStart), (serverFolder.length - NSMaxRange(idStart) - 1))];
	}

	IRCClient *client = nil;

	for (IRCClient *u in worldController().clientList) {
		if (serverIdPrefix.length > 0 && [u.uniqueIdentifier.lowercaseString hasPrefix:serverIdPrefix.lowercaseString]) {
			client = u;

			break;
		}
	}

	if (client == nil) {
		for (IRCClient *u in worldController().clientList) {
			if ([u.name.safeFilename isEqualToString:serverName]) {
				client = u;

				break;
			}
		}
	}

	IRCTreeItem *item = nil;

	if (client && viewType == TLOMessageArchiveViewTypeConsole) {
		item = client;
	} else if (client) {
		for (IRCChannel *c in client.channelList) {
			BOOL sameType = ((viewType == TLOMessageArchiveViewTypeChannel) ? c.isChannel : c.isPrivateMessage);

			if (sameType && [c.name.safeFilename caseInsensitiveCompare:viewName] == NSOrderedSame) {
				item = c;

				break;
			}
		}
	}

	if (client.config.excludedFromArchive || (item && [self keepsMessagesOfItem:item] == NO)) {
		return nil;
	}

	TLOMessageArchiveView *view = nil;

	if (item) {
		view = [TLOMessageArchiveView viewForItem:item];
	} else {
		NSString *serverId = ((client) ? client.uniqueIdentifier : [@"textlog:" stringByAppendingString:serverFolder]);

		view = [[TLOMessageArchiveView alloc] initWithViewId:[NSString stringWithFormat:@"textlog:%@/%lu/%@", serverFolder, viewType, viewName]
													viewName:viewName
													viewType:viewType
													serverId:serverId
												  serverName:((client) ? client.networkNameAlt : serverName)];
	}

	if (view == nil) {
		return nil;
	}

	TLOMessageArchiveTextLogTarget *target = [[TLOMessageArchiveTextLogTarget alloc] initWithView:view];

	NSString *localNickname = client.userNickname;

	target.localNickname = localNickname;

	target.matchType = [TPCPreferences highlightMatchingMethod];

	IRCChannel *channel = item.associatedChannel;

	if (channel.config.ignoreHighlights) {
		return target;
	}

	NSArray<NSString *> *(^keywords)(NSArray<IRCHighlightKeyword *> *) = ^NSArray<NSString *> *(NSArray<IRCHighlightKeyword *> *entries) {
		NSMutableArray<NSString *> *keywords = [NSMutableArray array];

		for (IRCHighlightKeyword *e in entries) {
			if (e.nicknames.count > 0 || [e appliesToChannelWithId:view.viewId clientId:view.serverId] == NO) {
				continue;
			}

			[keywords addObjectWithoutDuplication:e.keyword];
		}

		return [keywords copy];
	};

	NSMutableArray<NSString *> *matchKeywords = [keywords([TPCPreferences highlightMatchKeywordEntries]) mutableCopy];

	if (localNickname) {
		[matchKeywords addObjectWithoutDuplication:localNickname];
	}

	target.highlightKeywords = matchKeywords;

	target.excludeKeywords = keywords([TPCPreferences highlightExcludeKeywordEntries]);

	return target;
}

#pragma mark -
#pragma mark Searching

/* On the search queue: opened when first needed */
- (nullable sqlite3 *)_openSearchDatabase
{
	if (self.searchDatabase || self.searchClosed) {
		return self.searchDatabase;
	}

	/* The writer opens (and makes) the database first */
	dispatch_sync(self.queue, ^{});

	sqlite3 *database = NULL;

	int result = sqlite3_open_v2(self.url.fileSystemRepresentation, &database, (SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX), NULL);

	if (result != SQLITE_OK) {
		LogToConsoleError("Failed to open the message archive for search: %{public}s", sqlite3_errstr(result));

		sqlite3_close_v2(database);

		return NULL;
	}

	sqlite3_busy_timeout(database, 2000);

	(void)sqlite3_exec(database, "PRAGMA query_only = 1;", NULL, NULL, NULL);

	self.searchDatabase = database;

	return database;
}

- (void)search:(TLOMessageArchiveQuery *)query
		offset:(NSUInteger)offset
		 limit:(NSUInteger)limit
completionHandler:(void (^)(TLOMessageArchiveSearchPage *page))completionHandler
{
	NSParameterAssert(query != nil);
	NSParameterAssert(completionHandler != nil);

	query = [query copy];

	dispatch_async(self.searchQueue, ^{
		TLOMessageArchiveSearchPage *page = nil;

		sqlite3 *database = ((query.empty) ? NULL : [self _openSearchDatabase]);

		if (database) {
			page = [query _pageWithOffset:offset limit:limit inDatabase:database];
		} else {
			page = [TLOMessageArchiveSearchPage new];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(page);
		});
	});
}

- (void)countResultsOfSearch:(TLOMessageArchiveQuery *)query completionHandler:(void (^)(NSUInteger count))completionHandler
{
	NSParameterAssert(query != nil);
	NSParameterAssert(completionHandler != nil);

	query = [query copy];

	dispatch_async(self.searchQueue, ^{
		NSUInteger count = 0;

		sqlite3 *database = ((query.empty) ? NULL : [self _openSearchDatabase]);

		if (database) {
			count = [query _countInDatabase:database];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(count);
		});
	});
}

- (void)messagesInView:(NSString *)viewId
				 rowId:(int64_t)rowId
				before:(NSUInteger)before
				 after:(NSUInteger)after
	  scrollbackLineId:(nullable NSString *)scrollbackLineId
		scrollbackTime:(NSTimeInterval)scrollbackTime
	 completionHandler:(void (^)(NSArray<TLOMessageArchiveResult *> *messages, NSUInteger anchorIndex))completionHandler
{
	NSParameterAssert(viewId != nil);
	NSParameterAssert(completionHandler != nil);

	dispatch_async(self.searchQueue, ^{
		NSArray *messages = @[];

		NSUInteger anchorIndex = NSNotFound;

		sqlite3 *database = [self _openSearchDatabase];

		if (database) {
			messages = [TLOMessageArchiveQuery _messagesInView:viewId rowId:rowId before:before after:after scrollbackLineId:scrollbackLineId scrollbackTime:scrollbackTime anchorIndex:&anchorIndex inDatabase:database];
		}

		completionHandler(messages, anchorIndex);
	});
}

- (void)namesWithLimit:(NSUInteger)limit completionHandler:(void (^)(NSArray<NSString *> *nicknames, NSArray<NSString *> *viewNames))completionHandler
{
	NSParameterAssert(completionHandler != nil);

	dispatch_async(self.searchQueue, ^{
		NSArray *nicknames = @[];
		NSArray *viewNames = @[];

		sqlite3 *database = [self _openSearchDatabase];

		if (database) {
			nicknames = [TLOMessageArchiveQuery _namesInColumn:@"nickname" limit:limit inDatabase:database];
			viewNames = [TLOMessageArchiveQuery _namesInColumn:@"view_name" limit:limit inDatabase:database];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(nicknames, viewNames);
		});
	});
}

- (void)messagesAround:(TLOMessageArchiveResult *)result count:(NSUInteger)count completionHandler:(void (^)(NSArray<TLOMessageArchiveResult *> *messages))completionHandler
{
	NSParameterAssert(result != nil);
	NSParameterAssert(completionHandler != nil);

	dispatch_async(self.searchQueue, ^{
		NSArray *messages = @[];

		sqlite3 *database = [self _openSearchDatabase];

		if (database) {
			messages = [TLOMessageArchiveQuery _messagesAround:result count:count inDatabase:database];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(messages);
		});
	});
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
	dispatch_sync(self.searchQueue, ^{
		if (self.searchDatabase) {
			sqlite3_close_v2(self.searchDatabase);

			self.searchDatabase = NULL;
		}

		self.searchClosed = YES;
	});

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
