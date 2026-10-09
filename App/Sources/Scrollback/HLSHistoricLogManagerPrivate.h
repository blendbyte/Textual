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

@class IRCTreeItem, TVCLogLine, NSFetchRequest;

#define sharedHistoricLog()			[HLSHistoricLogManager sharedInstance]

/* The scrollback history ("historic log"): every printed line, kept per
 view in a Core Data store so views can be reloaded (theme changes, crash
 recovery, launch). All work runs on one private queue, in the order it
 was asked for, after the store has opened. Completion blocks are called
 on a background queue. */
@interface HLSHistoricLogManager : NSObject
+ (HLSHistoricLogManager *)sharedInstance;

/* Where an imported store (Textual 7's scrollback) is put, with its -wal and
 -shm files. It replaces the store the next time the store is opened. */
@property (class, readonly, nullable) NSURL *importedStoreURL;

- (void)writeNewEntryWithLogLine:(TVCLogLine *)logLine forItem:(IRCTreeItem *)item;

- (void)saveData; // asynchronous operation

- (void)resetMaximumLineCount;

@property (readonly) BOOL isSaving;

- (void)prepareForApplicationTermination;

- (void)forgetItem:(IRCTreeItem *)item;
- (void)resetDataForItem:(IRCTreeItem *)item;

- (void)fetchEntriesForItem:(IRCTreeItem *)item
				  ascending:(BOOL)ascending
				 fetchLimit:(NSUInteger)fetchLimit // 0 == up to the internal cap
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock;

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	   withUniqueIdentifier:(NSString *)uniqueId
		   beforeFetchLimit:(NSUInteger)fetchLimitBefore // 0 == only uniqueId
			afterFetchLimit:(NSUInteger)fetchLimitAfter // 0 == only uniqueId
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock;

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	 beforeUniqueIdentifier:(NSString *)uniqueId
				 fetchLimit:(NSUInteger)fetchLimit // required (> 0)
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock;

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	  afterUniqueIdentifier:(NSString *)uniqueId
				 fetchLimit:(NSUInteger)fetchLimit // required (> 0)
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock;

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	  afterUniqueIdentifier:(NSString *)uniqueIdAfter
	 beforeUniqueIdentifier:(NSString *)uniqueIdBefore
				 fetchLimit:(NSUInteger)fetchLimit // 0 == up to the internal cap
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock;

/* The view's lines with entry identifiers in the range, oldest or newest first */
+ (NSFetchRequest *)fetchRequestForView:(NSString *)viewId
							  ascending:(BOOL)ascending
							 fetchLimit:(NSUInteger)fetchLimit // 0 == up to the internal cap
				  lowestEntryIdentifier:(NSInteger)lowestEntryIdentifier
				 highestEntryIdentifier:(NSInteger)highestEntryIdentifier
							limitToDate:(nullable NSDate *)limitToDate;
@end

NS_ASSUME_NONNULL_END
