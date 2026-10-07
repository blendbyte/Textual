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

#import "NSObjectHelperPrivate.h"
#import "TXMasterController.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCWorld.h"
#import "TVCChannelSelectionOutlineViewCellPrivate.h"
#import "TVCChannelSelectionViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCChannelSelectionViewController ()
@property (nonatomic, strong) IBOutlet NSScrollView *outlineViewScrollView;
@property (nonatomic, weak) IBOutlet NSOutlineView *outlineView;
@property (nonatomic, weak) NSView *attachedView;
@property (nonatomic, strong) NSMutableArray<NSString *> *cachedSelectedClientIds;
@property (nonatomic, strong) NSMutableArray<NSString *> *cachedSelectedChannelIds;
@property (nonatomic, copy) NSDictionary<IRCClient *, NSArray<IRCChannel *> *> *cachedChannelList;
@property (nonatomic, strong) dispatch_source_t expandOutlineViewTimer;
@end

@implementation TVCChannelSelectionViewController

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TVCChannelSelectionView" owner:self topLevelObjects:nil];

	[self addObserverForChannelListUpdates];

	[self rebuildCachedChannelList];
}

- (void)dealloc
{
	[self removeObserverForChannelListUpdates];
}

- (void)attachToView:(NSView *)view
{
	NSParameterAssert(view != nil);

	if (self.attachedView == nil) {
		self.attachedView = view;
	} else {
		NSAssert(NO, @"Table view is already attached to a view");
	}

	NSScrollView *outlineViewScroller = self.outlineViewScrollView;

	[view addSubview:outlineViewScroller];

	[view addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[outlineViewScroller]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(outlineViewScroller)]];

	[view addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[outlineViewScroller]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(outlineViewScroller)]];
}

- (nullable IRCTreeItem *)itemFromCellView:(TVCChannelSelectionOutlineCellView *)cellView
{
	NSParameterAssert(cellView != nil);

	NSOutlineView *outlineView = self.outlineView;

	NSInteger cellRow = [outlineView rowForView:cellView];

	if (cellRow < 0) {
		return nil;
	}

	return [outlineView itemAtRow:cellRow];
}

- (void)selectionCheckboxClickedInCell:(TVCChannelSelectionOutlineCellView *)clickedCell
{
	NSParameterAssert(clickedCell != nil);

	IRCTreeItem *item = [self itemFromCellView:clickedCell];

	NSOutlineView *outlineView = self.outlineView;

	BOOL isGroupItem = [outlineView isGroupItem:item];

	BOOL isEnablingItem = (clickedCell.selectedCheckbox.state == NSControlStateValueOn ||
						   clickedCell.selectedCheckbox.state == NSControlStateValueMixed);

	/* Add or remove item from appropriate filter */
	if (isGroupItem) {
		if (isEnablingItem) {
			[self.cachedSelectedClientIds addObject:item.uniqueIdentifier];
		} else {
			[self.cachedSelectedClientIds removeObject:item.uniqueIdentifier];
		}
	} else {
		if (isEnablingItem) {
			[self.cachedSelectedChannelIds addObject:item.uniqueIdentifier];
		} else {
			[self.cachedSelectedChannelIds removeObject:item.uniqueIdentifier];
		}
	}

	/* Further process filters depending on state of other items */
	if (isGroupItem && isEnablingItem) {
		NSArray *childrenItems = [outlineView itemsFromParentGroup:item];

		for (IRCTreeItem *childItem in childrenItems) {
			[self.cachedSelectedChannelIds removeObject:childItem.uniqueIdentifier];
		}
	}

	/* Reload checkbox state for all */
	[self updateSelectedStateForItem:item];

	/* Call out to delegate */
	if ([self.delegate respondsToSelector:@selector(channelSelectionControllerSelectionChanged:)]) {
		[self.delegate channelSelectionControllerSelectionChanged:self];
	}
}

- (void)updateSelectedStateForItem:(IRCTreeItem *)item
{
	NSOutlineView *outlineView = self.outlineView;

	IRCTreeItem *parentItem = ((item.isClient) ? item : item.associatedClient);

	NSInteger parentItemRow = [outlineView rowForItem:parentItem];

	TVCChannelSelectionOutlineCellView *parentItemView = [outlineView viewAtColumn:0 row:parentItemRow makeIfNecessary:NO];

	BOOL parentItemInFilter = [self.cachedSelectedClientIds containsObject:parentItem.uniqueIdentifier];

	BOOL atleastOneChildChecked = NO;

	NSArray *childrenItems = [outlineView itemsInGroup:parentItem];

	for (IRCTreeItem *childItem in childrenItems) {
		NSInteger childItemRow = [outlineView rowForItem:childItem];

		TVCChannelSelectionOutlineCellView *childItemView = [outlineView viewAtColumn:0 row:childItemRow makeIfNecessary:NO];

		BOOL childItemInFilter = [self.cachedSelectedChannelIds containsObject:childItem.uniqueIdentifier];

		if (parentItemInFilter) {
			childItemView.selectedCheckbox.state = NSControlStateValueOn;
		} else if (childItemInFilter) {
			if (atleastOneChildChecked == NO) {
				atleastOneChildChecked = YES;
			}

			childItemView.selectedCheckbox.state = NSControlStateValueOn;
		} else {
			childItemView.selectedCheckbox.state = NSControlStateValueOff;
		}

		childItemView.selectedCheckbox.enabled = (parentItemInFilter == NO);
	}

	/* Process parent item */
	if (parentItemInFilter) {
		parentItemView.selectedCheckbox.state = NSControlStateValueOn;
	} else if (atleastOneChildChecked) {
		parentItemView.selectedCheckbox.state = NSControlStateValueMixed;
	} else {
		parentItemView.selectedCheckbox.state = NSControlStateValueOff;
	}
}

#pragma mark -
#pragma mark Properties

- (NSArray<NSString *> *)selectedClientIds
{
	@synchronized (self.cachedSelectedClientIds) {
		return [self.cachedSelectedClientIds copy];
	}
}

- (NSArray<NSString *> *)selectedChannelIds
{
	@synchronized (self.cachedSelectedChannelIds) {
		return [self.cachedSelectedChannelIds copy];
	}
}

- (void)setSelectedClientIds:(NSArray<NSString *> *)selectedClientIds
{
	@synchronized (self.cachedSelectedClientIds) {
		if (self->_cachedSelectedClientIds != selectedClientIds) {
			self->_cachedSelectedClientIds = [selectedClientIds mutableCopy];

			[self reloadOutlineView];
		}
	}
}

- (void)setSelectedChannelIds:(NSArray<NSString *> *)selectedChannelIds
{
	@synchronized (self.cachedSelectedChannelIds) {
		if (self->_cachedSelectedChannelIds != selectedChannelIds) {
			self->_cachedSelectedChannelIds = [selectedChannelIds mutableCopy];

			[self reloadOutlineView];
		}
	}
}

#pragma mark -
#pragma mark Cache Management

- (void)addObserverForChannelListUpdates
{
	[RZNotificationCenter() addObserver:self selector:@selector(channelListChanged:) name:IRCWorldClientListWasModifiedNotification object:nil];

	[RZNotificationCenter() addObserver:self selector:@selector(channelListChanged:) name:IRCClientChannelListWasModifiedNotification object:nil];
}

- (void)removeObserverForChannelListUpdates
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)reloadOutlineView
{
	[self.outlineView reloadData];
}

- (void)expandOutlineViewItemsCancelTimer
{
	if (self.expandOutlineViewTimer != nil) {
		XRCancelScheduledBlock(self.expandOutlineViewTimer);
	}
}

- (void)expandOutlineViewItemsCreateTimer
{
	if (self.expandOutlineViewTimer != nil) {
		return;
	}

	__weak TVCChannelSelectionViewController *weakSelf = self;

	dispatch_source_t expandOutlineViewTimer =
	XRScheduleBlockOnMainQueue(^{
		if (weakSelf == nil) {
			return;
		}

		[weakSelf.outlineView expandItem:nil expandChildren:YES];

		weakSelf.expandOutlineViewTimer = nil;
	}, 0.5);

	XRResumeScheduledBlock(expandOutlineViewTimer);

	self.expandOutlineViewTimer = expandOutlineViewTimer;
}

- (void)channelListChanged:(id)sender
{
	[self rebuildCachedChannelList];

	[self reloadOutlineView];

	[self expandOutlineViewItemsCancelTimer];
}

- (void)rebuildCachedChannelList
{
	NSArray *clientList = worldController().clientList;

	NSMutableDictionary<IRCClient *, NSArray<IRCChannel *> *> *cachedChannelList = [NSMutableDictionary dictionary];

	for (IRCClient *u in clientList) {
		NSMutableArray<IRCChannel *> *uChannelList = [NSMutableArray array];

		for (IRCChannel *c in u.channelList) {
			if (c.isChannel == NO) {
				continue;
			}

			[uChannelList addObject:c];
		}

		cachedChannelList[(id)u] = [uChannelList copy];
	}

	self.cachedChannelList = cachedChannelList;
}

#pragma mark -
#pragma mark Table View Delegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item
{
	if (item) {
		return self.cachedChannelList[item].count;
	}

	return self.cachedChannelList.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	if (item) {
		return self.cachedChannelList[item][index];
	}

	return self.cachedChannelList.allKeys[index];
}

- (nullable id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable id)item
{
	return item;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
	TVCChannelSelectionOutlineCellView *newView = nil;
	
	if ([item isClient]) {
		newView = (id)[outlineView makeViewWithIdentifier:@"serverEntry" owner:self];
	} else {
		newView = (id)[outlineView makeViewWithIdentifier:@"channelEntry" owner:self];
	}

	newView.parentController = self;

	return newView;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	/* Perform work on next pass of the main thread to avoid exception:
	 "insertRowsAtIndexes:withRowAnimation: can not happen while updating visible rows!" */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		NSView *cellView = [rowView viewAtColumn:0];

		[cellView prepareInitialState];

		id item = [outlineView itemAtRow:row];

		[self updateSelectedStateForItem:item];
	});

	[self expandOutlineViewItemsCreateTimer];
}

- (BOOL)outlineView:(NSOutlineView *)sender isItemExpandable:(id)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
	return NO;
}

@end

NS_ASSUME_NONNULL_END
