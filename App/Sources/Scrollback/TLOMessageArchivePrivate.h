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

@class TVCLogLine;

#define sharedMessageArchive()			[TLOMessageArchive sharedArchive]

/* Where a line was said, taken when it is printed (on any thread, the
 tree item is read once on the thread that prints) */
typedef NS_ENUM(NSUInteger, TLOMessageArchiveViewType)
{
	TLOMessageArchiveViewTypeConsole = 0,
	TLOMessageArchiveViewTypeChannel = 1,
	TLOMessageArchiveViewTypeQuery = 2
};

/* The message archive (10.9): every message, action, notice and topic
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

/* Lines of other types are ignored. Redacted lines are never kept. */
- (void)archiveLogLine:(TVCLogLine *)logLine
		   highlighted:(BOOL)highlighted
			   hasLink:(BOOL)hasLink
				inView:(NSString *)viewId
			  viewName:(NSString *)viewName
			  viewType:(TLOMessageArchiveViewType)viewType
			  onServer:(NSString *)serverId
			serverName:(NSString *)serverName;

/* A deleted message (REDACT): out of the archive too */
- (void)removeMessageWithMsgid:(NSString *)msgid inView:(NSString *)viewId;

/* The keep period: everything older goes (in steps, on the queue) */
- (void)removeMessagesOlderThan:(NSDate *)date;

/* Writes what is waiting and waits for the queue to be done */
- (void)flush;

- (void)prepareForApplicationTermination;
@end

NS_ASSUME_NONNULL_END
