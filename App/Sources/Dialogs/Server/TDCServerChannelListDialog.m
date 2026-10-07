/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "NSColorHelper.h"
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "TXGlobalModels.h"
#import "NSTableViewHelperPrivate.h"
#import "TLOLocalization.h"
#import "IRCClient.h"
#import "TVCBasicTableView.h"
#import "TDCServerChannelListDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerChannelListDialogEntry : NSObject
@property (nonatomic, copy) NSString *channelName;
@property (nonatomic, copy) NSNumber *channelMemberCount;
@property (nonatomic, copy) NSString *channelTopicUnformatted;
@property (nonatomic, copy) NSAttributedString *channelTopicFormatted;
@end

@interface TDCServerChannelListDialog () <NSControlTextEditingDelegate>
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, assign) BOOL isWaitingForWrites;
@property (nonatomic, strong) NSMutableArray<TDCServerChannelListDialogEntry *> *queuedWrites;
@property (nonatomic, weak) IBOutlet NSButton *updateButton;
@property (nonatomic, weak) IBOutlet NSSearchField *searchTextField;
@property (nonatomic, weak) IBOutlet NSTextField *networkNameTextField;
@property (nonatomic, weak) IBOutlet TVCBasicTableView *channelListTable;
@property (nonatomic, strong) IBOutlet NSArrayController *channelListController;

- (IBAction)onClose:(id)sender;

- (IBAction)onUpdate:(id)sender;
- (IBAction)onJoinChannels:(id)sender;
@end

@implementation TDCServerChannelListDialog

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCServerChannelListDialog" owner:self topLevelObjects:nil];

	self.queuedWrites = [NSMutableArray array];

	self.channelListTable.doubleAction = @selector(onJoin:);

	self.channelListTable.sortDescriptors = @[
		[NSSortDescriptor sortDescriptorWithKey:@"channelMemberCount" ascending:NO selector:@selector(compare:)]
	];

	self.networkNameTextField.stringValue = TXTLS(@"TDCServerChannelListDialog[7qf-r0]", self.client.networkNameAlt);
}

- (void)show
{
	[self.window restoreWindowStateForClass:self.class];

	[super show];
}

- (void)clear
{
	self.channelListController.content = nil;

	[self updateDialogTitle];
}

- (void)addChannel:(NSString *)channel count:(NSUInteger)count topic:(nullable NSString *)topic
{
	NSParameterAssert(channel != nil);

	TDCServerChannelListDialogEntry *newEntry = [TDCServerChannelListDialogEntry new];

	newEntry.channelName = channel;
	newEntry.channelMemberCount = @(count);

	if (topic == nil) {
		newEntry.channelTopicUnformatted = @"";

		newEntry.channelTopicFormatted = [NSAttributedString attributedString];
	} else {
		newEntry.channelTopicUnformatted = topic;

		NSAttributedString *topicFormatted =
		[topic attributedStringWithIRCFormatting:[NSTableView preferredGlobalTableViewFont]
							  preferredFontColor:[NSColor controlTextColor]];

		newEntry.channelTopicFormatted = topicFormatted;
	}

	@synchronized(self.queuedWrites) {
		[self.queuedWrites addObject:newEntry];
	}

	if (self.isWaitingForWrites == NO) {
		self.isWaitingForWrites = YES;

		[self performSelectorInCommonModes:@selector(queuedWritesTimer) withObject:nil afterDelay:1.0];
	}
}

- (void)queuedWritesTimer
{
	self.isWaitingForWrites = NO;

	[self writeQueuedWrites];
}

- (void)writeQueuedWrites
{
	@synchronized(self.queuedWrites) {
		if (self.queuedWrites.count == 0) {
			return;
		}

		NSPredicate *filterPredicate = self.channelListController.filterPredicate;

		if (filterPredicate) {
			NSMutableArray<TDCServerChannelListDialogEntry *> *queuedWrites = [NSMutableArray array];

			for (TDCServerChannelListDialogEntry *queuedWrite in self.queuedWrites) {
				if ([filterPredicate evaluateWithObject:queuedWrite]) {
					[queuedWrites addObject:queuedWrite];
				}
			}

			[self.channelListController addObjects:queuedWrites];

			[self.queuedWrites removeObjectsInArray:queuedWrites];
		} else {
			[self.channelListController addObjects:self.queuedWrites];

			[self.queuedWrites removeAllObjects];
		}
	}

	[self updateDialogTitle];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
	if (obj.object == self.searchTextField) {
		NSString *currentSearchValue = self.searchTextField.stringValue;

		if (currentSearchValue.length == 0) {
			[self writeQueuedWrites];
		}
	}
}

- (void)updateDialogTitle
{
	id arrangedObjects = self.channelListController.arrangedObjects;

	NSString *arrangedObjectsCount = TXFormattedNumber([arrangedObjects count]);

	self.window.title = TXTLS(@"TDCServerChannelListDialog[ct4-wh]", arrangedObjectsCount);
}

#pragma mark -
#pragma mark Actions

- (void)onClose:(id)sender
{
	[self close];
}

- (void)onUpdate:(id)sender
{
	[self clear];

	if ([self.delegate respondsToSelector:@selector(serverChannelListDialogOnUpdate:)]) {
		[self.delegate serverChannelListDialogOnUpdate:self];
	}
}

/* onJoinChannels: handles join for selected items. */
- (void)onJoinChannels:(id)sender
{
	[self onJoin:sender];
}

/* onJoin: is a legacy method. It handles join on double click. */
- (void)onJoin:(id)sender
{
	NSIndexSet *selectedRows = self.channelListTable.selectedRowIndexes;

	NSMutableArray<NSString *> *channelNames = [NSMutableArray arrayWithCapacity:selectedRows.count];

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		TDCServerChannelListDialogEntry *channelEntry = self.channelListController.arrangedObjects[index];

		[channelNames addObject:channelEntry.channelName];
	}];

	if ([self.delegate respondsToSelector:@selector(serverChannelListDialog:joinChannels:)]) {
		[self.delegate serverChannelListDialog:self joinChannels:[channelNames copy]];
	}

	[self.channelListTable deselectAll:nil];
}

#pragma mark -
#pragma mark NSTableViewDelegate

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
#define _maximumSelectedRows	8

	return [tableView selectionIndexesForProposedSelection:proposedSelectionIndexes maximumNumberOfSelections:_maximumSelectedRows];

#undef _maximumSelectedRows
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self cancelPerformRequests];

	self.channelListTable.dataSource = nil;
	self.channelListTable.delegate = nil;

	[self.window saveWindowStateForClass:self.class];

	if ([self.delegate respondsToSelector:@selector(serverChannelDialogWillClose:)]) {
		[self.delegate serverChannelDialogWillClose:self];
	}
}

@end

#pragma mark -

@implementation TDCServerChannelListDialogEntry
@end

NS_ASSUME_NONNULL_END
