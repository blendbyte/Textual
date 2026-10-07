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

#import "IRCClient.h"
#import "IRCClientConfig.h"
#import "IRCAddressBook.h"
#import "IRCAddressBookMatchCachePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCAddressBookMatchCache ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, strong) NSCache<NSString *, id> *cachedMatchesInt;
@end

@implementation IRCAddressBookMatchCache

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	NSCache *cachedMatches = [NSCache new];
	
	cachedMatches.countLimit = 100;

	self.cachedMatchesInt = cachedMatches;
}

- (void)clearCachedMatches
{
	[self.cachedMatchesInt removeAllObjects];
}

- (void)clearCachedMatchesForHostmask:(NSString *)hostmask
{
	NSParameterAssert(hostmask != nil);
	
	[self.cachedMatchesInt removeObjectForKey:hostmask];
}

- (NSArray<IRCAddressBookEntry *> *)findIgnoresForHostmask:(NSString *)hostmask
{
	IRCAddressBookEntry *match = [self findAddressBookEntryForHostmask:hostmask];
	
	if (match && match.entryType == IRCAddressBookEntryTypeIgnore) {
		return @[match];
	}

	if (match && match.entryType == IRCAddressBookEntryTypeMixed) {
		NSArray *parentEntries = match.parentEntries;
		
		return
		[parentEntries filteredArrayUsingPredicate:
		 [NSPredicate predicateWithFormat:@"entryType == %d", IRCAddressBookEntryTypeIgnore]];
	}
	
	return @[];
}

- (nullable IRCAddressBookEntry *)findAddressBookEntryForHostmask:(NSString *)hostmask
{
	NSParameterAssert(hostmask != nil);

	IRCAddressBookEntry *cachedEntry = [self.cachedMatchesInt objectForKey:hostmask];
	
	if (cachedEntry) {
		/* We reset the cache when new items are added to the client
		 which means we are perfectly fine keeping a cache of when
		 there isn't result for a hostmask. Whatever is needed to
		 gain a little bit more speed. */
		if ([cachedEntry isKindOfClass:[NSNull class]]) {
			return nil;
		}

		return cachedEntry;
	}
	
	/* A separate variable is used to store a single entry
	 and multiple so that we don’t allocate an array when
	 it is very infrequent for there to be multiple. */
	IRCAddressBookEntry *matchedEntry = nil;

	NSMutableArray <IRCAddressBookEntry *> *matchedEntries = nil;

	for (IRCAddressBookEntry *entry in self.client.config.ignoreList) {
		if ([entry checkMatch:hostmask] == NO) {
			continue;
		}
		
		if (matchedEntries) {
			[matchedEntries addObject:entry];
		} else if (matchedEntry) {
			matchedEntries = [NSMutableArray array];

			[matchedEntries addObject:matchedEntry];
			
			[matchedEntries addObject:entry];
			
			matchedEntry = nil;
		} else {
			matchedEntry = entry;
		}
	}

	/* Combine multiple entries */
	if (matchedEntries) {
		IRCAddressBookEntryMutable *mixedEntry = [IRCAddressBookEntryMutable new];
		
		mixedEntry.entryType = IRCAddressBookEntryTypeMixed;
		
		mixedEntry.parentEntries = matchedEntries;

		for (IRCAddressBookEntry *entry in matchedEntries) {
			mixedEntry.ignoreClientToClientProtocol = ((entry.ignoreClientToClientProtocol) ? YES : mixedEntry.ignoreClientToClientProtocol);
			mixedEntry.ignoreGeneralEventMessages = ((entry.ignoreGeneralEventMessages) ? YES : mixedEntry.ignoreGeneralEventMessages);
			mixedEntry.ignoreNoticeMessages = ((entry.ignoreNoticeMessages) ? YES : mixedEntry.ignoreNoticeMessages);
			mixedEntry.ignorePrivateMessageHighlights = ((entry.ignorePrivateMessageHighlights) ? YES : mixedEntry.ignorePrivateMessageHighlights);
			mixedEntry.ignorePrivateMessages = ((entry.ignorePrivateMessages) ? YES : mixedEntry.ignorePrivateMessages);
			mixedEntry.ignorePublicMessageHighlights = ((entry.ignorePublicMessageHighlights) ? YES : mixedEntry.ignorePublicMessageHighlights);
			mixedEntry.ignorePublicMessages = ((entry.ignorePublicMessages) ? YES : mixedEntry.ignorePublicMessages);
			mixedEntry.ignoreFileTransferRequests = ((entry.ignoreFileTransferRequests) ? YES : mixedEntry.ignoreFileTransferRequests);
			mixedEntry.ignoreInlineMedia = ((entry.ignoreInlineMedia) ? YES : mixedEntry.ignoreInlineMedia);
			mixedEntry.trackUserActivity = ((entry.trackUserActivity) ? YES : mixedEntry.trackUserActivity);
		}
		
		matchedEntry = [mixedEntry copy];
	}

	/* Cache entry */
	if (matchedEntry) {
		[self.cachedMatchesInt setObject:matchedEntry forKey:hostmask];
	} else {
		[self.cachedMatchesInt setObject:[NSNull null] forKey:hostmask];
	}
	
	return matchedEntry;
}

@end

NS_ASSUME_NONNULL_END
