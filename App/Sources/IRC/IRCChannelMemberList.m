/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual and/or Codeux Software, nor the names of
 *    its contributors may be used to endorse or promote products derived
 * 	  from this software without specific prior written permission.
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

#import <os/lock.h>

#import "NSObjectHelperPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMemberListPrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCWorld.h"
#import "TPCPreferencesLocal.h"
#import "TVCMemberListPrivate.h"
#import "TVCMainWindow.h"
#import "TXMasterController.h"

NS_ASSUME_NONNULL_BEGIN

/* Members are changed on the main thread, where messages are processed, and
 the member list's table is told about each change, so its selection stays
 with the same people. Other threads (rendering, plugins) may read: a lock
 guards the array. */
@interface IRCChannelMemberList ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, weak) IRCChannel *channel;
@property (nonatomic, weak, nullable) TVCMemberList *tableView;
@property (nonatomic, strong) NSMutableArray<IRCChannelUser *> *memberContainer;
@property (nonatomic, assign) BOOL batchingNames; // from the first NAMES reply to its end: unsorted, no table updates
@end

@implementation IRCChannelMemberList
{
	os_unfair_lock _memberContainerLock;
}

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super init])) {
		self.client = channel.associatedClient;
		self.channel = channel;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self->_memberContainerLock = OS_UNFAIR_LOCK_INIT;

	self.memberContainer = [NSMutableArray array];
}

- (void)dealloc
{
	/* Send a last message before death. */
	TVCMemberList *tableView = self.tableView;

	if (tableView == nil) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[tableView memberListWasDestroyed];
	});
}

- (void)assignToTableView:(nullable TVCMemberList *)tableView
{
	self.tableView = tableView;
}

- (void)withContainer:(void (NS_NOESCAPE ^)(NSMutableArray<IRCChannelUser *> *container))block
{
	NSParameterAssert(block != nil);

	os_unfair_lock_lock(&self->_memberContainerLock);

	block(self.memberContainer);

	os_unfair_lock_unlock(&self->_memberContainerLock);
}

/* The table is told on the main thread, in the order of the changes */
- (void)updateTableView:(void (^)(TVCMemberList *tableView))block
{
	NSParameterAssert(block != nil);

	XRPerformBlockSynchronouslyOnMainQueue(^{
		TVCMemberList *tableView = self.tableView;

		if (tableView) {
			block(tableView);
		}
	});
}

#pragma mark -
#pragma mark Backend Operations

/* Call with the lock held */

- (NSUInteger)nonatomic_sortedIndexForMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	NSMutableArray *container = self.memberContainer;

	return [container indexOfObject:member
					  inSortedRange:container.range
							options:NSBinarySearchingInsertionIndex
					usingComparator:[IRCChannelUser channelRankComparator]];
}

/* Members are sorted: a binary search finds one, unless the list is unsorted
 (during NAMES) or the order is stale (a preference changed before resorting) */
- (NSUInteger)nonatomic_indexOfMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	NSMutableArray *container = self.memberContainer;

	if (self.batchingNames == NO) {
		NSUInteger index = [container indexOfObject:member
									  inSortedRange:container.range
											options:NSBinarySearchingFirstEqual
									usingComparator:[IRCChannelUser channelRankComparator]];

		if (index != NSNotFound && container[index] == member) {
			return index;
		}
	}

	return [container indexOfObjectIdenticalTo:member];
}

- (NSInteger)nonatomic_insertMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	if (self.batchingNames) {
		[self.memberContainer addObject:member];

		return (-1);
	}

	NSUInteger index = [self nonatomic_sortedIndexForMember:member];

	[self.memberContainer insertObject:member atIndex:index];

	return index;
}

- (NSInteger)nonatomic_removeMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	NSUInteger index = [self nonatomic_indexOfMember:member];

	if (index == NSNotFound) {
		return (-1);
	}

	[self.memberContainer removeObjectAtIndex:index];

	return index;
}

#pragma mark -
#pragma mark Frontend Operations

- (void)addUser:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	IRCChannelUser *member = [[IRCChannelUser alloc] initWithUser:user];

	[self addMember:member];
}

- (void)addMember:(IRCChannelUser *)member
{
	[self addMember:member checkForDuplicates:NO];
}

- (void)addMember:(IRCChannelUser *)member checkForDuplicates:(BOOL)checkForDuplicates
{
	NSParameterAssert(member != nil);

	IRCChannel *channel = self.channel;

	if (checkForDuplicates) {
		IRCChannelUser *oldMember = [member.user userAssociatedWithChannel:channel];

		if (oldMember != nil) {
			[self replaceMember:oldMember withMember:member];

			return;
		}
	}

	if ([member isKindOfClass:[IRCChannelUserMutable class]]) {
		 member = [member copy];
	}

	[member associateWithChannel:channel];

	[self willChangeValueForKey:@"numberOfMembers"];
	[self willChangeValueForKey:@"memberList"];

	__block NSInteger insertedIndex = (-1);

	[self withContainer:^(NSMutableArray *container) {
		insertedIndex = [self nonatomic_insertMember:member];
	}];

	[self didChangeValueForKey:@"numberOfMembers"];
	[self didChangeValueForKey:@"memberList"];

	if (insertedIndex < 0) {
		return; // NAMES: the table is reloaded at its end
	}

	[self updateTableView:^(TVCMemberList *tableView) {
		[tableView memberListInsertedRowAtIndex:insertedIndex];
	}];

	if (channel.isChannel) {
		[self.client postEventToViewController:@"channelMemberAdded" forChannel:channel];
	}
}

- (void)removeMemberWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCChannelUser *member = [self findMember:nickname];

	if (member) {
		[self removeMember:member];
	}
}

- (void)removeMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	IRCChannel *channel = self.channel;

	[member disassociateWithChannel:channel];

	[self willChangeValueForKey:@"numberOfMembers"];
	[self willChangeValueForKey:@"memberList"];

	__block NSInteger removedIndex = (-1);
	__block BOOL batching = NO;

	[self withContainer:^(NSMutableArray *container) {
		removedIndex = [self nonatomic_removeMember:member];

		batching = self.batchingNames;
	}];

	[self didChangeValueForKey:@"numberOfMembers"];
	[self didChangeValueForKey:@"memberList"];

	if (removedIndex < 0 || batching) {
		return;
	}

	[self updateTableView:^(TVCMemberList *tableView) {
		[tableView memberListRemovedRowAtIndex:removedIndex];
	}];

	if (channel.isChannel) {
		[self.client postEventToViewController:@"channelMemberRemoved" forChannel:channel];
	}
}

- (void)resortMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	if ([member isKindOfClass:[IRCChannelUserMutable class]]) {
		 member = [member copy];
	}

	[self replaceMember:member withMember:member resort:YES];
}

- (void)_replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2 resort:(BOOL)resort
{
	NSParameterAssert(member1 != nil);
	NSParameterAssert(member2 != nil);

	IRCChannel *channel = self.channel;

	if (member1 != member2) {
		[member1 disassociateWithChannel:channel];

		[member2 associateWithChannel:channel];
	}

	__block NSInteger oldIndex = (-1);
	__block NSInteger newIndex = (-1);
	__block BOOL batching = NO;

	[self withContainer:^(NSMutableArray *container) {
		batching = self.batchingNames;

		/* During NAMES the list is sorted at the end */
		if (resort && batching == NO) {
			oldIndex = [self nonatomic_removeMember:member1];

			newIndex = [self nonatomic_insertMember:member2];
		} else {
			NSUInteger index = [self nonatomic_indexOfMember:member1];

			if (index != NSNotFound) {
				container[index] = member2;

				oldIndex = index;
				newIndex = index;
			}
		}
	}];

	if (newIndex < 0 || batching) {
		return;
	}

	[self updateTableView:^(TVCMemberList *tableView) {
		if (oldIndex < 0) {
			[tableView memberListInsertedRowAtIndex:newIndex];
		} else {
			[tableView memberListMovedRowAtIndex:oldIndex toIndex:newIndex];
		}
	}];
}

- (void)replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2
{
	[self replaceMember:member1 withMember:member2 resort:YES replaceInAllChannels:NO];
}

- (void)replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2 resort:(BOOL)resort
{
	[self replaceMember:member1 withMember:member2 resort:YES replaceInAllChannels:NO];
}

- (void)replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2 resort:(BOOL)resort replaceInAllChannels:(BOOL)replaceInAllChannels
{
	NSParameterAssert(member1 != nil);
	NSParameterAssert(member2 != nil);

	if ([member2 isKindOfClass:[IRCChannelUserMutable class]]) {
		 member2 = [member2 copy];
	}

	[self _replaceMember:member1 withMember:member2 resort:resort];

	if (replaceInAllChannels) {
		IRCChannel *thisChannel = self.channel;

		NSDictionary *relations = member2.user.relations;

		[relations enumerateKeysAndObjectsUsingBlock:^(IRCChannel *targetChannel, IRCChannelUser *member, BOOL *stop) {
			if (thisChannel == targetChannel) {
				return;
			}

			IRCChannelMemberList *memberList = targetChannel.memberInfo;

			[memberList _replaceMember:member withMember:member resort:resort];
		}];
	}
}

- (void)changeMember:(NSString *)nickname mode:(NSString *)mode value:(BOOL)value
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(mode.length == 1);

	IRCClient *client = self.client;
	IRCChannel *channel = self.channel;

	// Find member and create mutable copy for editing
	IRCChannelUser *member = [channel findMember:nickname];

	if (member == nil) {
		return;
	}

	IRCChannelUserMutable *memberMutable = [member mutableCopy];

	NSString *oldMemberModes = memberMutable.modes;

	// If the member has no modes already and we are setting a mode, then
	// all we have to do is set the value of -modes to new mode
	BOOL processModes = YES;

	if (oldMemberModes.length == 0) {
		if (value) {
			processModes = NO;

			memberMutable.modes = mode;
		} else {
			return; // Can't remove mode from empty string
		}
	} else {
		if (value && [oldMemberModes contains:mode]) {
			return; // Mode is already in string
		}
	}

	// Split up the current user modes into an array of characters.
	// Enumerate over the array of characters to find which mode in the
	// current set has a rank lower than the mode being inserted.
	// Insert before the lower ranked mode or insert at end.
	if (processModes) {
		IRCISupportInfo *clientSupportInfo = client.supportInfo;

		NSArray *oldModeSymbols = oldMemberModes.characterStringBuffer;

		NSMutableArray *newModeSymbols = [oldModeSymbols mutableCopy];

		if (value == NO) {
			[newModeSymbols removeObject:mode];
		} else {
			NSUInteger rankOfNewMode = [clientSupportInfo rankForUserPrefixWithMode:mode];

			NSUInteger lowerRankedMode =
			[oldModeSymbols indexOfObjectPassingTest:^BOOL(NSString *oldModeSymbol, NSUInteger index, BOOL *stop) {
				NSInteger rankOfOldMode = [clientSupportInfo rankForUserPrefixWithMode:oldModeSymbol];

				return (rankOfOldMode < rankOfNewMode);
			}];

			if (lowerRankedMode != NSNotFound) {
				[newModeSymbols insertObject:mode atIndex:lowerRankedMode];
			} else {
				[newModeSymbols addObject:mode];
			}
		}

		NSString *newMemberModes = [newModeSymbols componentsJoinedByString:@""];

		memberMutable.modes = newMemberModes;
	}

	BOOL replaceInAllChannels = NO;

	if (value && [mode isEqualToString:@"Y"] && member.user.isIRCop == NO) {
		/* InspIRCd treats +Y as an IRCop. */
		/* If the user wasn't already marked as an IRCop, then we
		 mark them at this point. */

		[client modifyUser:member.user withBlock:^(IRCUserMutable *userMutable) {
			userMutable.isIRCop = YES;
		}];

		if ([TPCPreferences memberListSortFavorsServerStaff]) {
			replaceInAllChannels = YES;
		}
	}

	// Remove the user from the member list and insert sorted
	[self replaceMember:member
			 withMember:memberMutable
				 resort:YES
   replaceInAllChannels:replaceInAllChannels];
}

#pragma mark -
#pragma mark Utilities

- (void)reloadTableView
{
	[self updateTableView:^(TVCMemberList *tableView) {
		[tableView memberListReloaded];
	}];
}

- (void)sortMembers
{
	NSComparator comparator = [IRCChannelUser channelRankComparator];

	[self withContainer:^(NSMutableArray *container) {
		if (self.batchingNames) {
			return; // sorted when NAMES ends
		}

		[container sortUsingComparator:comparator];
	}];

	[self reloadTableView];
}

- (void)clearMembers
{
	IRCChannel *channel = self.channel;

	[self willChangeValueForKey:@"numberOfMembers"];
	[self willChangeValueForKey:@"memberList"];

	[self withContainer:^(NSMutableArray *container) {
		[container makeObjectsPerformSelector:@selector(disassociateWithChannel:) withObject:channel];

		[container removeAllObjects];

		self.batchingNames = NO;
	}];

	[self didChangeValueForKey:@"numberOfMembers"];
	[self didChangeValueForKey:@"memberList"];

	[self reloadTableView];
}

/* A big channel's NAMES (thousands of members) was one table insert and one
 view event per member: they are collected, sorted once and shown at once */
- (void)beginNamesBatch
{
	[self withContainer:^(NSMutableArray *container) {
		self.batchingNames = YES;
	}];

	/* A server that never ends the list would hide the members for good */
	[self cs_reschedulePerformSelectorInCommonModes:@selector(endNamesBatch) withObject:nil afterDelay:10.0];
}

- (void)endNamesBatch
{
	[self cancelPerformRequestsWithSelector:@selector(endNamesBatch)];

	__block BOOL wasBatching = NO;

	NSComparator comparator = [IRCChannelUser channelRankComparator];

	[self withContainer:^(NSMutableArray *container) {
		wasBatching = self.batchingNames;

		if (wasBatching == NO) {
			return;
		}

		self.batchingNames = NO;

		[container sortUsingComparator:comparator];
	}];

	if (wasBatching == NO) {
		return;
	}

	[self reloadTableView];

	IRCChannel *channel = self.channel;

	if (channel.isChannel) {
		[self.client postEventToViewController:@"channelMemberAdded" forChannel:channel];
	}
}

- (NSUInteger)numberOfMembers
{
	__block NSUInteger memberCount = 0;

	[self withContainer:^(NSMutableArray *container) {
		memberCount = container.count;
	}];

	return memberCount;
}

- (nullable NSArray<IRCChannelUser *> *)memberList
{
	__block NSArray<IRCChannelUser *> *memberList = nil;

	[self withContainer:^(NSMutableArray *container) {
		memberList = [container copy];
	}];

	return memberList;
}

- (nullable IRCChannelUser *)memberAtIndex:(NSUInteger)index
{
	__block IRCChannelUser *member = nil;

	[self withContainer:^(NSMutableArray *container) {
		if (index < container.count) {
			member = container[index];
		}
	}];

	return member;
}

- (NSInteger)indexOfMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	__block NSUInteger index = NSNotFound;

	[self withContainer:^(NSMutableArray *container) {
		index = [self nonatomic_indexOfMember:member];
	}];

	return ((index == NSNotFound) ? (-1) : (NSInteger)index);
}

#pragma mark -
#pragma mark Clipboard

- (NSData *)pasteboardDataForMembers:(NSArray<IRCChannelUser *> *)members
{
	NSParameterAssert(members != nil);

	NSString *channelId = self.channel.uniqueIdentifier;

	NSMutableArray<NSString *> *nicknames = [NSMutableArray arrayWithCapacity:members.count];

	for (IRCChannelUser *member in members) {
		[nicknames addObject:member.user.nickname];
	}

	NSDictionary *pasteboardDictionary = @{
	   @"channelId" : channelId,
	   @"nicknames" : nicknames
	};

	NSData *pasteboardData = [NSKeyedArchiver archivedDataWithRootObject:pasteboardDictionary];

	return pasteboardData;
}

+ (BOOL)readNicknamesFromPasteboardData:(NSData *)pasteboardData withBlock:(void (NS_NOESCAPE ^)(IRCChannel *channel, NSArray<NSString *> *nicknames))callbackBlock
{
	NSParameterAssert(pasteboardData != nil);
	NSParameterAssert(callbackBlock != nil);

	/* This is a private method which means that we are very lazy about
	 validating the input, but this is a TODO to myself: add strict type
	 checks if you end up making this method public. */
	NSDictionary *pasteboardDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:pasteboardData];

	if ([pasteboardDictionary isKindOfClass:[NSDictionary class]] == NO) {
		return NO;
	}

	NSString *channelId = pasteboardDictionary[@"channelId"];

	IRCChannel *channel = (IRCChannel *)[worldController() findItemWithId:channelId];

	if (channel == nil) {
		return NO;
	}

	NSArray *nicknames = pasteboardDictionary[@"nicknames"];

	callbackBlock(channel, nicknames);

	return YES;
}

+ (BOOL)readMembersFromPasteboardData:(NSData *)pasteboardData withBlock:(void (NS_NOESCAPE ^)(IRCChannel *channel, NSArray<IRCChannelUser *> *members))callbackBlock
{
	NSParameterAssert(pasteboardData != nil);
	NSParameterAssert(callbackBlock != nil);

	return
	[self readNicknamesFromPasteboardData:pasteboardData withBlock:^(IRCChannel *channel, NSArray<NSString *> *nicknames) {
		NSMutableArray *members = [NSMutableArray arrayWithCapacity:nicknames.count];

		for (NSString *nickname in nicknames) {
			IRCChannelUser *member = [channel findMember:nickname];

			if (member == nil) {
				continue;
			}

			[members addObject:member];
		}

		callbackBlock(channel, [members copy]);
	}];
}

#pragma mark -
#pragma mark Search

- (BOOL)memberExists:(NSString *)nickname
{
	return ([self findMember:nickname] != nil);
}

- (nullable IRCChannelUser *)findMember:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCUser *user = [self.client findUser:nickname];

	if (user == nil) {
		return nil;
	}

	IRCChannelUser *member = [user userAssociatedWithChannel:self.channel];

	if (member == nil) {
		return nil;
	}

	return member;
}

@end

NS_ASSUME_NONNULL_END
