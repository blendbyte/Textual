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

#import "NSObjectHelperPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMemberListPrivate.h"
#import "IRCChannelMemberListControllerPrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCWorld.h"
#import "TPCPreferencesLocal.h"
#import "TVCMemberList.h"
#import "TVCMainWindow.h"
#import "TXMasterController.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCChannelMemberList ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, weak) IRCChannel *channel;
@property (nonatomic, strong, nullable) IRCChannelMemberListController *controller;
@property (nonatomic, strong) NSMutableArray<IRCChannelUser *> *memberContainer;
@end

@implementation IRCChannelMemberList

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
	self.memberContainer = [NSMutableArray array];
}

- (void)dealloc
{
	/* Send a last message before death. */
	[self unassignController];
}

- (void)assignController:(nullable IRCChannelMemberListController *)controller
{
	/* All modifications to the controller occur on the main thread.
	 The controller is a UI object which requires updates on the
	 main thread in addition to the safety it provides us again
	 race conditions. */
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[controller replaceContents:self.memberList];

		self.controller = controller;
	});
}

- (void)unassignController
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCChannelMemberListController *controller = self.controller;

		if ( controller) {
			[controller assignToChannel:nil];
		}
	});
}

#pragma mark -
#pragma mark Grand Central Dispatch

/* All modifications to the member list occur on this serial queue
 to guarantee that there is only ever one person accessing the mutable
 store at any given time. */
+ (dispatch_queue_t)modifyMemberListSerialQueue
{
	static dispatch_queue_t workerQueue = NULL;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		workerQueue =
		XRCreateDispatchQueueWithPriority("IRCChannel.modifyMemberListSerialQueue", DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT);
	});

	return workerQueue;
}

+ (void)resumeMemberListSerialQueues
{
	dispatch_resume([self modifyMemberListSerialQueue]);
}

+ (void)suspendMemberListSerialQueues
{
	dispatch_suspend([self modifyMemberListSerialQueue]);
}

+ (void)accessMemberListUsingBlock:(dispatch_block_t)block
{
	NSCParameterAssert(block != NULL);

	dispatch_queue_t workerQueue = [self modifyMemberListSerialQueue];

	static void *IsOnWorkerQueueKey = NULL;

	if (IsOnWorkerQueueKey == NULL) {
		IsOnWorkerQueueKey = &IsOnWorkerQueueKey;

		dispatch_queue_set_specific(workerQueue, IsOnWorkerQueueKey, (void *)1, NULL);
	}

	if (dispatch_get_specific(IsOnWorkerQueueKey)) {
		block();

		return;
	}

	dispatch_sync(workerQueue, ^{
		@autoreleasepool {
			block();
		}
	});
}

#pragma mark -
#pragma mark Backend Operations

- (NSUInteger)nonatomic_sortedIndexForMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	NSMutableArray *container = self.memberContainer;

	NSUInteger index = [container
							indexOfObject:member
							inSortedRange:container.range
								  options:NSBinarySearchingInsertionIndex
						  usingComparator:[IRCChannelUser channelRankComparator]];

	return index;
}

- (NSInteger)nonatomic_sortedInsert:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	NSInteger insertedIndex = [self nonatomic_sortedIndexForMember:member];

	[self.memberContainer insertObject:member atIndex:insertedIndex];

	return insertedIndex;
}

- (NSInteger)nonatomic_replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2
{
	NSParameterAssert(member1 != nil);
	NSParameterAssert(member2 != nil);

	NSMutableArray *container = self.memberContainer;

	NSUInteger index = [container indexOfObjectIdenticalTo:member1];

	if (index == NSNotFound) {
		return (-1);
	}

	container[index] = member2;

	return index;
}

- (NSInteger)nonatomic_removeMember:(IRCChannelUser *)member
{
	NSParameterAssert(member != nil);

	NSMutableArray *container = self.memberContainer;

	NSUInteger index = [container indexOfObjectIdenticalTo:member];

	if (index == NSNotFound) {
		return (-1);
	}

	[container removeObjectAtIndex:index];

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

	__block NSInteger sortedIndex = (-1);

	[self.class accessMemberListUsingBlock:^{
		sortedIndex = [self nonatomic_sortedInsert:member];
	}];

	[self didChangeValueForKey:@"numberOfMembers"];
	[self didChangeValueForKey:@"memberList"];

	if (channel.isChannel == NO) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCChannelMemberListController *controller = self.controller;

		if ( controller != nil) {
			[controller insertObject:member atArrangedObjectIndex:sortedIndex];
		}

		[self.client postEventToViewController:@"channelMemberAdded" forChannel:channel];
	});
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

	__block NSInteger sortedIndex = (-1);

	[self.class accessMemberListUsingBlock:^{
		sortedIndex = [self nonatomic_removeMember:member];
	}];

	if (sortedIndex < 0 || channel.isChannel == NO) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCChannelMemberListController *controller = self.controller;

		if ( controller != nil) {
			[controller removeObjectAtArrangedObjectIndex:sortedIndex];
		}

		[self.client postEventToViewController:@"channelMemberRemoved" forChannel:channel];
	});
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

	[self.class accessMemberListUsingBlock:^{
		if (resort) {
			oldIndex = [self nonatomic_removeMember:member1];

			newIndex = [self nonatomic_sortedInsert:member2];
		} else {
			newIndex = [self nonatomic_replaceMember:member1 withMember:member2];
		}
	}];

	if (newIndex < 0 || channel.isChannel == NO) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCChannelMemberListController *controller = self.controller;

		if (controller == nil) {
			return;
		}

		[mainWindowMemberList() beginUpdates];

		if (resort) {
			if (oldIndex >= 0) {
				[controller removeObjectAtArrangedObjectIndex:oldIndex];
			}

			[controller insertObject:member2 atArrangedObjectIndex:newIndex];
		} else {
			[mainWindowMemberList() refreshDrawingForRow:newIndex];
		}

		[mainWindowMemberList() endUpdates];
	});
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

- (void)sortMembers
{
	[self.class accessMemberListUsingBlock:^{
		[self.memberContainer sortUsingComparator:[IRCChannelUser channelRankComparator]];
	}];

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCChannelMemberListController *controller = self.controller;

		if (controller == nil) {
			return;
		}

		[controller replaceContents:self.memberList];
	});
}

- (void)clearMembers
{
	IRCChannel *channel = self.channel;

	[self.class accessMemberListUsingBlock:^{
		[self willChangeValueForKey:@"numberOfMembers"];
		[self willChangeValueForKey:@"memberList"];

		[self.memberContainer makeObjectsPerformSelector:@selector(disassociateWithChannel:) withObject:channel];

		[self.memberContainer removeAllObjects];

		[self didChangeValueForKey:@"numberOfMembers"];
		[self didChangeValueForKey:@"memberList"];
	}];

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCChannelMemberListController *controller = self.controller;

		if (controller == nil) {
			return;
		}

		[controller replaceContents:@[]];
	});
}

- (NSUInteger)numberOfMembers
{
	__block NSUInteger memberCount = 0;

	[self.class accessMemberListUsingBlock:^{
		memberCount = self.memberContainer.count;
	}];

	return memberCount;
}

- (nullable NSArray<IRCChannelUser *> *)memberList
{
	__block NSArray<IRCChannelUser *> *memberList = nil;

	[self.class accessMemberListUsingBlock:^{
		memberList = [self.memberContainer copy];
	}];

	return memberList;
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
