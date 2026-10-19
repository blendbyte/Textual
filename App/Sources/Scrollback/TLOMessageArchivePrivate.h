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

NS_ASSUME_NONNULL_BEGIN

@class IRCTreeItem, TVCLogLine;

#define sharedMessageArchive()			[TLOMessageArchive sharedArchive]

/* Highlights were written (Mentions): posted on the main queue */
TEXTUAL_EXTERN NSString * const TLOMessageArchiveDidArchiveHighlightsNotification;

typedef NS_ENUM(NSUInteger, TLOMessageArchiveViewType)
{
	TLOMessageArchiveViewTypeConsole = 0,
	TLOMessageArchiveViewTypeChannel = 1,
	TLOMessageArchiveViewTypeQuery = 2
};

/* Where a line was said: read from the tree item once, on the thread that
 has it, so the archive's queue doesn't touch the item */
@interface TLOMessageArchiveView : NSObject
/* nil for a utility channel: its lines aren't kept */
+ (nullable instancetype)viewForItem:(IRCTreeItem *)item;

- (instancetype)initWithViewId:(NSString *)viewId
					  viewName:(NSString *)viewName
					  viewType:(TLOMessageArchiveViewType)viewType
					  serverId:(NSString *)serverId
					serverName:(NSString *)serverName NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, copy) NSString *viewId;
@property (readonly, copy) NSString *viewName; // empty for the console
@property (readonly) TLOMessageArchiveViewType viewType;
@property (readonly, copy) NSString *serverId;
@property (readonly, copy) NSString *serverName;
@property (readonly, weak, nullable) IRCTreeItem *item;
@end

/* Where a text log's lines go, and what's needed to read them */
@interface TLOMessageArchiveTextLogTarget : NSObject
- (instancetype)initWithView:(TLOMessageArchiveView *)view NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly) TLOMessageArchiveView *view;
@property (copy, nullable) NSString *localNickname; // own lines, and a highlight word
@property (copy) NSArray<NSString *> *highlightKeywords;
@property (copy) NSArray<NSString *> *excludeKeywords;
@property (assign) NSUInteger matchType; // TXNicknameHighlightMatchType
@end

/* The folders a text log is in: the server's ("Libera (1a2b3)"), the kind of
 view and its name (empty for the console) → where its lines go, or nil to
 leave it out. Called on the main queue. */
typedef TLOMessageArchiveTextLogTarget * _Nullable (^TLOMessageArchiveTextLogResolver)(NSString *serverFolder, TLOMessageArchiveViewType viewType, NSString *viewName);

typedef NS_ENUM(NSUInteger, TLOMessageArchiveSearchOrder)
{
	TLOMessageArchiveSearchOrderNewest = 0,
	TLOMessageArchiveSearchOrderBestMatch = 1 // newest without words to search for
};

/* What to search for, read from what the user typed:

	words and "a phrase"	found anywhere in a message, any case
							(word* is the same as word)
	from:nick				said by; several are any of them
	in:#channel				in this channel or query (in:textual is
							#textual too); several are any of them
	before:2026-10-01		before that day (also a month, a year, today
	after:2026-10			or yesterday); after: after the day or month
	during:2026				on that day, in that month or year
	has:link				with a link
	mentions:me				highlights

 A filter without a value (still being typed) is left out; an unknown or
 malformed one is searched as text. */
@interface TLOMessageArchiveQuery : NSObject <NSCopying>
+ (instancetype)queryWithString:(NSString *)string;

/* Dates in this calendar (and its time zone), today and yesterday from now */
+ (instancetype)queryWithString:(NSString *)string calendar:(NSCalendar *)calendar now:(NSDate *)now;

@property (readonly, copy) NSString *string;

@property (readonly, copy) NSArray<NSString *> *terms; // words and phrases, without quotes
@property (readonly, copy) NSArray<NSString *> *nicknames; // from:
@property (readonly, copy) NSArray<NSString *> *viewNames; // in:
@property (readonly, copy, nullable) NSDate *earliestDate; // included
@property (readonly, copy, nullable) NSDate *latestDate; // not included
@property (readonly) BOOL hasLink;
@property (readonly) BOOL mentionsMe;

/* Nothing to search for: no words and no filters */
@property (readonly, getter=isEmpty) BOOL empty;

/* Where to search, set by the caller: one view, one server, or everywhere */
@property (copy, nullable) NSString *serverId;
@property (copy, nullable) NSString *viewId;

@property (assign) TLOMessageArchiveSearchOrder order;
@end

@interface TLOMessageArchiveResult : NSObject
@property (readonly) int64_t rowId;
@property (readonly, copy) NSString *serverId;
@property (readonly, copy) NSString *serverName;
@property (readonly, copy) NSString *viewId;
@property (readonly, copy) NSString *viewName;
@property (readonly) TLOMessageArchiveViewType viewType;
@property (readonly, copy) NSDate *date;
@property (readonly) NSUInteger lineType; // TVCLogLineType
@property (readonly, copy, nullable) NSString *nickname;
@property (readonly) BOOL isSelf;
@property (readonly) BOOL isHighlight;
@property (readonly) BOOL hasLink;
@property (readonly, copy, nullable) NSString *msgid;
@property (readonly, copy) NSString *lineId; // the scrollback line (TVCLogLine uniqueIdentifier)
@property (readonly, copy) NSString *body; // without formatting

/* Where the words searched for are in the body, in order, not overlapping */
@property (readonly, copy) NSArray<NSValue *> *matchRanges;

/* The body cut to about this many characters around the first match, with
 "…" where it was cut; the ranges of the matches in it */
- (NSString *)snippetWithMaximumLength:(NSUInteger)maximumLength matchRanges:(NSArray<NSValue *> * _Nullable * _Nullable)matchRanges;
@end

@interface TLOMessageArchiveSearchPage : NSObject
@property (readonly, copy) NSArray<TLOMessageArchiveResult *> *results;
@property (readonly) BOOL hasMore; // a next page has results
@end

/* The message archive: every message, action, notice and topic
 change, kept as searchable text in its own SQLite database with a full
 text index (FTS5, trigram tokenizer: substrings in any language), for
 search over all past messages. Separate from the scrollback store (the
 historic log), which keeps whole lines for redrawing views and only the
 newest ones. Kept when a channel or query is closed or a server deleted,
 until the keep period ends.

 Lines are written in batches on a private queue. The same message is
 kept once: by its msgid, else by its time, sender and text (history
 replayed by the server after a reconnect). */
@interface TLOMessageArchive : NSObject
+ (TLOMessageArchive *)sharedArchive; // Application Support/Message Archive.sqlite

/* A separate database (tests) */
- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, copy) NSURL *url;

/* Only these are kept: the conversation, not joins, parts or mode changes */
+ (BOOL)archivesLineType:(NSUInteger)lineType; // TVCLogLineType

/* NO when the archive is off, or the server or channel is left out
 (Server and Channel Properties); read on the main thread */
+ (BOOL)keepsMessagesOfItem:(IRCTreeItem *)item;

/* The keep period in days (TPCMessageArchiveKeepPeriod: 0 forever, -1 off,
 when nothing new is kept); a year by default. Shortened, older messages go
 at once. */
@property (assign) NSInteger keepDays;

/* Lines of other types are ignored. Redacted lines are never kept. */
- (void)archiveLogLine:(TVCLogLine *)logLine
		   highlighted:(BOOL)highlighted
			   hasLink:(BOOL)hasLink
				inView:(TLOMessageArchiveView *)view;

/* Once: the lines already in the scrollback store of these views,
 kept as if they had been printed, so search reaches back before the archive
 began. Highlights are found from the keywords saved with each line. Marked
 done in the database (a new database imports again); stopped by quitting,
 it starts over next time, which keeps nothing twice. */
- (void)importScrollbackOfViews:(NSArray<TLOMessageArchiveView *> *)views;

/* Whether the line highlighted, as the renderer decides it, for lines
 rendered before the archive (the renderer also skips keywords inside links) */
+ (BOOL)logLineIsHighlight:(TVCLogLine *)logLine body:(NSString *)body matchType:(NSUInteger)matchType; // TXNicknameHighlightMatchType

/* A deleted message (REDACT): out of the archive too */
- (void)removeMessageWithMsgid:(NSString *)msgid inView:(NSString *)viewId;

/* The keep period: everything older goes (in steps, on the queue) */
- (void)removeMessagesOlderThan:(NSDate *)date;

/* Search, on a connection of its own, so writing doesn't wait for
 it; lines written in the last two seconds may not be found yet. An empty
 query finds nothing. The completion handlers are called on the main queue. */
- (void)search:(TLOMessageArchiveQuery *)query
		offset:(NSUInteger)offset
		 limit:(NSUInteger)limit
completionHandler:(void (^)(TLOMessageArchiveSearchPage *page))completionHandler;

- (void)countResultsOfSearch:(TLOMessageArchiveQuery *)query completionHandler:(void (^)(NSUInteger count))completionHandler;

/* The chat's history past the scrollback: a view's messages older
 than where its scrollback starts (the line with scrollbackLineId, found in
 the archive by its line id, else by scrollbackTime; nil and DBL_MAX for an
 empty scrollback), oldest first. Around a message (rowId): up to before
 messages earlier than it, it (anchorIndex), and up to after later ones; or,
 with rowId 0, up to before messages before the scrollback. A message the
 scrollback has, or that is gone, gives none (anchorIndex NSNotFound). The
 completion handler is called on a background queue. */
- (void)messagesInView:(NSString *)viewId
				 rowId:(int64_t)rowId
				before:(NSUInteger)before
				 after:(NSUInteger)after
	  scrollbackLineId:(nullable NSString *)scrollbackLineId
		scrollbackTime:(NSTimeInterval)scrollbackTime
	 completionHandler:(void (^)(NSArray<TLOMessageArchiveResult *> *messages, NSUInteger anchorIndex))completionHandler;

/* For suggestions while typing from: and in:: who wrote and the
 channels and queries written in, most recent first, up to limit each */
- (void)namesWithLimit:(NSUInteger)limit completionHandler:(void (^)(NSArray<NSString *> *nicknames, NSArray<NSString *> *viewNames))completionHandler;

/* A result in its conversation (for results older than the
 scrollback): up to count messages before it and after it, oldest first */
- (void)messagesAround:(TLOMessageArchiveResult *)result count:(NSUInteger)count completionHandler:(void (^)(NSArray<TLOMessageArchiveResult *> *messages))completionHandler;

/* Delete Archive: the database is deleted and made again, which
 gives the space back at once. The scrollback is imported into the new one at
 the next launch only when asked (the archive turned off, so that turning it
 on again starts with the scrollback), not after deleting on purpose. */
- (void)deleteAllMessagesImportingScrollbackAgain:(BOOL)importScrollbackAgain completionHandler:(nullable void (^)(void))completionHandler;

/* The scrollback is imported again at the next launch (Textual 7's was
 imported into it); what is in the archive already isn't kept twice */
- (void)importScrollbackAgain;

/* A server's or a view's messages (one of them) */
- (void)deleteMessagesOfServer:(nullable NSString *)serverId inView:(nullable NSString *)viewId completionHandler:(nullable void (^)(void))completionHandler;

/* The database's size on disk */
@property (readonly) unsigned long long fileSize;

/* All messages, a server's, or a view's; on the main queue */
- (void)countMessagesOfServer:(nullable NSString *)serverId inView:(nullable NSString *)viewId completionHandler:(void (^)(NSUInteger count))completionHandler;

/* Import Text Logs…: the text logs under a folder as Textual writes
 them (TLOFileLogger: <server> (<id>)/Channels/<channel>/<day>.txt, Queries,
 Console), matched to servers and channels by the id in the folder name, else
 by name (those that are gone keep their names); messages, actions and
 notices (not joins and the like) within the keep period, each kept once, also
 when it is in the archive already from the scrollback. Handlers on the main
 queue. */
- (void)importTextLogsInFolder:(NSURL *)folderURL
			   progressHandler:(nullable void (^)(NSUInteger filesDone, NSUInteger fileCount))progressHandler
			 completionHandler:(void (^)(NSUInteger importedCount))completionHandler;

/* With another way of finding where lines go (tests) */
- (void)importTextLogsInFolder:(NSURL *)folderURL
					  resolver:(TLOMessageArchiveTextLogResolver)resolver
			   progressHandler:(nullable void (^)(NSUInteger filesDone, NSUInteger fileCount))progressHandler
			 completionHandler:(void (^)(NSUInteger importedCount))completionHandler;

/* Writes what is waiting and waits for the queue to be done */
- (void)flush;

- (void)prepareForApplicationTermination;
@end

NS_ASSUME_NONNULL_END
