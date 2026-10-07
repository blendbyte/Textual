/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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
#import "NSStringHelper.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowAppearancePrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListCellPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCTextFormatterMenuPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCTheme.h"
#import "TXGlobalModels.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "THOPluginDispatcherPrivate.h"
#import "TLOKeyEventHandler.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindow (ServerList)

#pragma mark -
#pragma mark Server List

- (void)saveSelection
{
	NSMutableArray<NSString *> *selectedIdentifiers = [NSMutableArray array];

	for (IRCTreeItem *item in self.selectedItems) {
		[selectedIdentifiers addObject:item.uniqueIdentifier];
	}

	[RZUserDefaults() setObject:[selectedIdentifiers copy]
						 forKey:@"Window -> Main Window -> Server List Selection"];
}

- (void)restoreExpandedClients
{
	for (IRCClient *e in worldController().clientList) {
		if (e.config.sidebarItemExpanded) {
			[self expandClient:e];
		}
	}
}

- (void)restoreSelectionDuringSetup
{
	NSArray *selectedIdentifiers = [RZUserDefaults() objectForKey:@"Window -> Main Window -> Server List Selection"];

	if (selectedIdentifiers == nil || selectedIdentifiers.count == 0) {
		[self selectBestChoiceDuringSetup];

		return;
	}

	NSArray *selection = [worldController() findItemsWithIds:selectedIdentifiers];

	if (selection.count == 0) {
		[self selectBestChoiceDuringSetup];

		return;
	}

	[self adjustSelectionWithItems:selection selectedItem:nil];
}

- (void)selectBestChoiceDuringSetup
{
	IRCClient *firstSelection = nil;

	for (IRCClient *e in worldController().clientList) {
		if (e.config.autoConnect && e.config.sidebarItemExpanded) {
			if (firstSelection == nil) {
				firstSelection = e;
			}
		}
	}

	if (firstSelection) {
		NSInteger n = [self.serverList rowForItem:firstSelection];

		if (firstSelection.channelCount > 0) {
			n++;
		}

		[self.serverList selectItemAtIndex:n];
	} else {
		[self.serverList selectItemAtIndex:0];
	}
}

- (void)setupTrees
{
	self.memberList.keyDelegate = self;

	self.memberList.target = menuController();
	self.memberList.doubleAction = @selector(memberInMemberListDoubleClicked:);

	self.serverList.keyDelegate = self;

	self.serverList.delegate = (id)self;
	self.serverList.dataSource = (id)self;

	self.serverList.target = self;
	self.serverList.doubleAction = @selector(outlineViewDoubleClicked:);

	/* Inform the table we want drag events */
	[self.serverList registerForDraggedTypes:_treeDragItemTypes];

	/* Prepare our first selection */
	[self restoreExpandedClients];

	[self restoreSelectionDuringSetup];

	/* Fake the delegate call */
	[self outlineViewSelectionDidChange:nil];

	/* Populate navigation list */
	[menuController() populateNavigationChannelList];
}

- (nullable IRCChannel *)selectedChannelOn:(IRCClient *)c
{
	if (self.selectedClient == c) {
		return self.selectedChannel;
	} else {
		return nil;
	}
}

- (void)reloadTreeItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	[self.serverList refreshDrawingForItem:item];
}

- (void)reloadTreeGroup:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if (item.isClient == NO) {
		return;
	}

	[self reloadTreeItem:item];

	for (IRCChannel *channel in ((IRCClient *)item).channelList) {
		[self reloadTreeItem:channel];
	}
}

- (void)reloadTree
{
	[self.serverList refreshAllDrawings];
}

- (void)expandClient:(IRCClient *)client
{
	[[self.serverList animator] expandItem:client];
}

- (void)adjustSelection
{
	[self adjustSelectionWithItems:self.selectedItems selectedItem:self.selectedItem];
}

- (void)adjustSelectionWithItems:(NSArray<IRCTreeItem *> *)selectedItems selectedItem:(nullable IRCTreeItem *)selectedItem
{
	NSParameterAssert(selectedItems != nil);

	NSMutableIndexSet *itemRows = [NSMutableIndexSet indexSet];

	for (IRCTreeItem *item in selectedItems) {
		/* Expand the parent of the item if its not already expanded. */
		if (item.isClient == NO) {
			IRCClient *itemClient = item.associatedClient;

			[self.serverList expandItem:itemClient];
		}

		/* Find the row of the item */
		NSInteger itemRow = [self.serverList rowForItem:item];

		if ( itemRow >= 0) {
			[itemRows addIndex:itemRow];
		}
	}

	/* If the selected rows have not changed, then only select the one item */
	NSIndexSet *selectedRows = self.serverList.selectedRowIndexes;

	if ([selectedRows isEqualToIndexSet:itemRows] == NO) {
		/* Selection updates are disabled and selection changes are faked so that
		 the correct next item is selected when moving to previous group. */
		self.ignoreNextOutlineViewSelectionChange = YES;

		[self.serverList selectRowIndexes:itemRows
					 byExtendingSelection:NO
						scrollToSelection:YES];
	}

	/* Perform selection logic */
	[self selectionDidChangeToRows:itemRows selectedItem:selectedItem];
}

- (void)storePreviousSelection
{
	self.previousSelectedItemId = self.selectedItem.uniqueIdentifier;

	[self storePreviousSelections];
}

- (void)storePreviousSelections
{
	NSMutableArray<NSString *> *previousSelectedItems = [NSMutableArray array];

	for (IRCTreeItem *item in self.selectedItems) {
		[previousSelectedItems addObject:item.uniqueIdentifier];
	}

	self.previousSelectedItemsId = previousSelectedItems;
}

- (void)storeLastSelectedChannel
{
	if (self.selectedClient) {
		self.selectedClient.lastSelectedChannel = self.selectedChannel;
	}
}

- (void)selectPreviousItem
{
	/* Do not try to browse backwards without these items */
	if (self.previousSelectedItemId == nil ||
		self.previousSelectedItemsId == nil)
	{
		return;
	}

	/* Get previously selected item and cancel if its missing */
	IRCTreeItem *itemPrevious = self.previouslySelectedItem;

	if (itemPrevious == nil) {
		return;
	}

	/* Build list of rows in the table view that contain previous group */
	NSMutableArray<IRCTreeItem *> *itemsPrevious = [NSMutableArray array];

	for (NSString *itemIdentifier in self.previousSelectedItemsId) {
		IRCTreeItem *item = [worldController() findItemWithId:itemIdentifier];

		if ( item) {
			[itemsPrevious addObject:item];
		}
	}

	[self adjustSelectionWithItems:itemsPrevious selectedItem:itemPrevious];
}

- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem
{
	[self selectItemInSelectedItems:selectedItem refreshChannelView:YES];
}

- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem refreshChannelView:(BOOL)refreshChannelView
{
	NSParameterAssert(selectedItem != nil);

	/* Do nothing if items are the same */
	if ([self isItemSelected:selectedItem]) {
		return;
	}

	/* Select item if its in the current group */
	if ([self isItemInSelectedGroup:selectedItem] == NO) {
		return;
	}

	[self storePreviousSelection];

	self.selectedItem = selectedItem;

	if (refreshChannelView) {
		[self updateChannelViewBoxContentViewSelection];
	}

	[self selectionDidChangePostflight];
}

- (void)select:(nullable IRCTreeItem *)item
{
	[self shiftSelection:self.selectedItem
				  toItem:item
				 options:(TVCMainWindowShiftSelectionFlagMaintainGrouping |
						  TVCMainWindowShiftSelectionFlagPerformDeselect)];
}

- (void)deselect:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	[self shiftSelection:item
				  toItem:nil
				 options:TVCMainWindowShiftSelectionFlagPerformDeselect];
}

- (void)deselectGroup:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if (item.isClient == NO) {
		return;
	}

	[self shiftSelection:item
				  toItem:nil
				 options:(TVCMainWindowShiftSelectionFlagPerformDeselect |
						  TVCMainWindowShiftSelectionFlagPerformDeselectChildren)];
}

- (void)shiftSelection:(nullable IRCTreeItem *)oldItem toItem:(nullable IRCTreeItem *)newItem options:(TVCMainWindowShiftSelectionFlags)selectionOptions
{
	if (oldItem == newItem) {
		return;
	}

	/* If the next item is a channel, then make sure the client
	 it is associated with is expanded, or we can't switch to it. */
	if (newItem && newItem.isClient == NO) {
		IRCClient *itemClient = newItem.associatedClient;

		[self expandClient:itemClient];
	}

	/* Context */
	BOOL optionMaintainGrouping = ((selectionOptions & TVCMainWindowShiftSelectionFlagMaintainGrouping) == TVCMainWindowShiftSelectionFlagMaintainGrouping);

	BOOL optionPerformDeselectAll = NO;
	BOOL optionPerformDeselectOld = ((selectionOptions & TVCMainWindowShiftSelectionFlagPerformDeselect) == TVCMainWindowShiftSelectionFlagPerformDeselect);
	BOOL optionPerformDeselectChildren = ((selectionOptions & TVCMainWindowShiftSelectionFlagPerformDeselectChildren) == TVCMainWindowShiftSelectionFlagPerformDeselectChildren);

	BOOL optionPerformDeselect = (optionPerformDeselectChildren || optionPerformDeselectOld);

	/* Do nothing if item is not group */
	NSInteger itemIndexOld = [self.serverList rowForItem:oldItem];
	NSInteger itemIndexNew = [self.serverList rowForItem:newItem];

	NSIndexSet *selectedRows = self.serverList.selectedRowIndexes;

	NSIndexSet *selectedRowsForbidden = nil;

	/* Maybe do nothing at all */
	if (optionPerformDeselect && itemIndexOld >= 0 && [selectedRows containsIndex:itemIndexOld] == NO) {
		return;
	}

	/* If we are not performing a deselect for the old item and both items
	 are selected, then simply update selection inside grouping. */
	if (optionMaintainGrouping &&
		(itemIndexOld >= 0 && [selectedRows containsIndex:itemIndexOld]) &&
		(itemIndexNew >= 0 && [selectedRows containsIndex:itemIndexNew]) &&
		newItem != nil) // This condition is impossible but static analyzer doesn't know that.
						// Condition is impossible because itemIndexNew will never return
						// greater to or equal zero unless item is non-nil.
	{
		[self selectItemInSelectedItems:newItem];

		return;
	} else {
		if (optionPerformDeselectOld) {
			optionPerformDeselectAll = YES;
		}
	}

	/* Create a mutable copy of the current selection */
	NSMutableIndexSet *selectedRowsNew = [selectedRows mutableCopy];

	if (optionPerformDeselectAll) {
		[selectedRowsNew removeAllIndexes];
	} else if (optionPerformDeselectOld) {
		[selectedRowsNew removeIndex:itemIndexOld];
	}

	/* optionPerformDeselectChildren is still performed even if optionPerformDeselectAll
	 is set so that the list of forbidden rows can be defined by it. */
	if (optionPerformDeselectChildren) {
		NSIndexSet *childrenRowRange = [self.serverList indexesOfItemsInGroup:oldItem];

		if (childrenRowRange) {
			[selectedRowsNew removeIndexes:childrenRowRange];

			selectedRowsForbidden = childrenRowRange;
		}
	}

	/* If the next item is not nil and is a row, then select that */
	if (newItem) {
		if (itemIndexNew >= 0) {
			[selectedRowsNew addIndex:itemIndexNew];
		} else {
			LogToConsoleDebug("Tried to shift selection to an item not in the server list");

			return;
		}
	}

	/* If no item to switch to is specified, then the current action is 
	 treated as a deselect for the old item. In that case, we pick the 
	 next best item to remain selected. */
	if (newItem == nil) {
		/* If there is an item in the current selection that is before 
		 or after the row removed, then we can use that. */
		BOOL selectedRowsComplete =
		([selectedRowsNew indexLessThanIndex:itemIndexOld] != NSNotFound ||
		 [selectedRowsNew indexGreaterThanIndex:itemIndexOld] != NSNotFound);

		/* If there is not an item in the current selection that can take over,
		 then the first step is to try to find an item newer than the current. */
		if (selectedRowsComplete == NO) {
			NSInteger numberOfRows = self.serverList.numberOfRows;

			NSInteger nextSelectionRow = (itemIndexOld + 1);

			/* Next row is in forbidden range */
			if (selectedRowsForbidden && [selectedRowsForbidden containsIndex:nextSelectionRow]) {
				nextSelectionRow = (selectedRowsForbidden.lastIndex + 1);
			}

			/* Next row is above number of rows. Try to go one below instead. */
			if (nextSelectionRow >= numberOfRows) {
				nextSelectionRow = (itemIndexOld - 1);
			}

			/* Previous row is in forbidden range */
			if (selectedRowsForbidden && [selectedRowsForbidden containsIndex:nextSelectionRow]) {
				nextSelectionRow = (selectedRowsForbidden.firstIndex - 1);
			}

			/* Previous row is less than zero. There is no where else to go. */
			if (nextSelectionRow < 0) {
				nextSelectionRow = (-1);
			}

			/* Add new selection index if there is one. */
			if (nextSelectionRow >= 0) {
				[selectedRowsNew addIndex:nextSelectionRow];
			}
		}
	}

	/* Save selection */
	if (selectedRowsNew.count == 0) {
		[self storePreviousSelection];

		self.selectedItem = nil;
		self.selectedItems = @[];

		[self selectionDidChangePostflight];

		return;
	}

	[self.serverList selectRowIndexes:selectedRowsNew
				 byExtendingSelection:NO
					scrollToSelection:YES];
}

#pragma mark -
#pragma mark Server List Delegate

- (void)outlineViewDoubleClicked:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil && c == nil) {
		return;
	}

	if (u && c == nil)
	{
		if (u.isConnecting || u.isConnected)
		{
			if ([TPCPreferences disconnectOnDoubleclick]) {
				[u quit];
			}
		}
		else if (u.isQuitting)
		{
			LogToConsole("Double click event ignored because client is quitting");
		}
		else
		{
			if ([TPCPreferences connectOnDoubleclick]) {
				[u connect];
			}
		}

		[self expandClient:u];
	}
	else
	{
		if (u.isLoggedIn == NO) {
			return;
		}

		if (c.isActive)
		{
			if ([TPCPreferences leaveOnDoubleclick]) {
				[u partChannel:c];
			}
		}
		else
		{
			if ([TPCPreferences joinOnDoubleclick]) {
				[u joinChannel:c];
			}
		}
	}
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item
{
	if (item) {
		return [item numberOfChildren];
	}

	return worldController().clientCount;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return ([item numberOfChildren] > 0);
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	if (item) {
		return [item childAtIndex:index];
	}

	return worldController().clientList[index];
}

- (nullable id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable id)item
{
	return item;
}

- (nullable NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
	if (item == nil || [item isClient]) {
		return [[TVCServerListGroupRowCell alloc] initWithServerList:(id)outlineView];
	} else {
		return [[TVCServerListChildRowCell alloc] initWithServerList:(id)outlineView];
	}
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
	NSString *viewIdentifier = nil;

	if (item == nil || [item isClient]) {
		viewIdentifier = @"GroupView";
	} else {
		viewIdentifier = @"ChildView";
	}

	NSView *newView = [outlineView makeViewWithIdentifier:viewIdentifier owner:self];

	return newView;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	[self.serverList refreshDrawingForRow:row];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	id itemBeingCollapsed = notification.userInfo[@"NSObject"];

	IRCClient *u = [itemBeingCollapsed associatedClient];

	u.sidebarItemIsExpanded = NO;
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	id itemBeingCollapsed = notification.userInfo[@"NSObject"];

	IRCClient *u = [itemBeingCollapsed associatedClient];

	u.sidebarItemIsExpanded = YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	return YES;
}

- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{

}

- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView
{
	TVCServerList *serverList = (id)outlineView;

	/* Allow rows to be deselected during redrawing */
	/* See logic in -updateAppearance in TVCServerList */
	if (serverList.invalidatingBackgroundForSelection) {
		return YES;
	}

	/* If the window is not focused, don't allow change. */
	if (self.keyWindow == NO) {
		return NO;
	}

	/* If the server list does not have a mouse down event, allow change. */
	if (serverList.leftMouseIsDownInView == NO) {
		return YES;
	}

	/* If command or shift are held down, allow change. */
	NSUInteger keyboardKeys = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);

	if ((keyboardKeys & NSEventModifierFlagCommand) == NSEventModifierFlagCommand ||
		(keyboardKeys & NSEventModifierFlagShift) == NSEventModifierFlagShift)
	{
		return YES;
	}

	/* Find which row is beneath the mouse */
	NSInteger rowBeneathMouse = outlineView.rowBeneathMouse;

	/* If a row is not beneath the mouse or the row that is, is not
	 selected, then the selection is allowed to be changed. */
	if (rowBeneathMouse < 0) {
		return YES;
	}

	if ([outlineView isRowSelected:rowBeneathMouse] == NO) {
		return YES;
	}

	/* If the item beneath the mouse is already selected and we did not 
	 try to unselect it by holding command or shift, then tell the table
	 view not to change the selection. That will be handled by us. */
	IRCTreeItem *itemUnderMouse = [outlineView itemAtRow:rowBeneathMouse];

	[self selectItemInSelectedItems:itemUnderMouse];

	return NO;
}

- (NSIndexSet *)outlineView:(NSOutlineView *)outlineView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
#define _maximumSelectedRows	6

	return [outlineView selectionIndexesForProposedSelection:proposedSelectionIndexes maximumNumberOfSelections:_maximumSelectedRows];

#undef _maximumSelectedRows
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	TVCServerList *serverList = (id)((notification.object) ?: self.serverList);

	if (serverList.invalidatingBackgroundForSelection) {
		return;
	}

	if (self.ignoreNextOutlineViewSelectionChange) {
		self.ignoreNextOutlineViewSelectionChange = NO;

		return;
	}

	if (self.ignoreOutlineViewSelectionChanges) {
		return;
	}

	NSIndexSet *selectedRows = serverList.selectedRowIndexes;

	IRCTreeItem *selectedItem = nil;

	NSUInteger keyboardKeys = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);

	if (keyboardKeys == NSEventModifierFlagCommand) {
		NSInteger rowBeneathMouse = serverList.rowBeneathMouse;

		if (rowBeneathMouse >= 0 && [selectedRows containsIndex:rowBeneathMouse]) {
			selectedItem = [serverList itemAtRow:rowBeneathMouse];
		}
	}

	if (selectedItem) {
		[self selectionDidChangeToRows:selectedRows selectedItem:selectedItem];
	} else {
		[self selectionDidChangeToRows:selectedRows];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard
{
	/* TODO (March 27, 2016): Support dragging multiple items */
	if (items.count == 1) {
		NSString *itemToken = [worldController() pasteboardStringForItem:items[0]];

		[pasteboard declareTypes:_treeDragItemTypes owner:self];

		[pasteboard setString:itemToken forType:_treeDragItemType];
	}

	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(nullable id)item proposedChildIndex:(NSInteger)index
{
	if (index < 0) {
		return NSDragOperationNone;
	}

	NSPasteboard *pasteboard = [info draggingPasteboard];

	if ([pasteboard availableTypeFromArray:_treeDragItemTypes] == nil) {
		return NSDragOperationNone;
	}

	NSString *draggedItemToken = [pasteboard stringForType:_treeDragItemType];

	if (draggedItemToken == nil) {
		return NSDragOperationNone;
	}

	IRCTreeItem *draggedItem = [worldController() findItemWithPasteboardString:draggedItemToken];

	if (draggedItem == nil) {
		return NSDragOperationNone;
	}

	if (draggedItem.isClient)
	{
		if (item) {
			return NSDragOperationNone;
		}
	}
	else
	{
		IRCChannel *channel = (IRCChannel *)draggedItem;

		if (channel.associatedClient != item) {
			return NSDragOperationNone;
		}

		IRCClient *client = (IRCClient *)item;

		NSArray *channelList = client.channelList;

		IRCChannel *previousItem = nil;

		if ((index - 1) >= 0) {
			previousItem = channelList[(index - 1)];
		}

		IRCChannel *nextItem = nil;

		if (index < channelList.count) {
			nextItem = channelList[index];
		}

		if (channel.isChannel) {
			if (previousItem && previousItem.isChannel == NO) {
				return NSDragOperationNone;
			}
		} else {
			if (nextItem.isChannel) {
				return NSDragOperationNone;
			}
		}
	}

	return NSDragOperationGeneric;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(nullable id)item childIndex:(NSInteger)index
{
	if (index < 0) {
		return NSDragOperationNone;
	}

	NSPasteboard *pasteboard = [info draggingPasteboard];

	if ([pasteboard availableTypeFromArray:_treeDragItemTypes] == nil) {
		return NSDragOperationNone;
	}

	NSString *draggedItemToken = [pasteboard stringForType:_treeDragItemType];

	if (draggedItemToken == nil) {
		return NSDragOperationNone;
	}

	IRCTreeItem *draggedItem = [worldController() findItemWithPasteboardString:draggedItemToken];

	if (draggedItem == nil) {
		return NSDragOperationNone;
	}

	TVCServerList *serverList = (id)outlineView;

	if (draggedItem.isClient)
	{
		NSArray *clientList = worldController().clientList;

		NSMutableArray *clientListMutable = [clientList mutableCopy];

		NSUInteger originalIndex = [clientList indexOfObjectIdenticalTo:draggedItem];

		[clientListMutable moveObjectAtIndex:originalIndex toIndex:index];

		worldController().clientList = clientListMutable;

		[serverList moveItemAtIndex:originalIndex inParent:nil toIndex:index inParent:nil];
	}
	else
	{
		if (item == nil || item != draggedItem.associatedClient) {
			return NO;
		}

		IRCClient *client = (IRCClient *)item;

		NSArray *channelList = client.channelList;

		NSMutableArray *channelListMutable = [channelList mutableCopy];

		NSUInteger originalIndex = [channelList indexOfObjectIdenticalTo:draggedItem];

		[channelListMutable moveObjectAtIndex:originalIndex toIndex:index];

		client.channelList = channelListMutable;

		[serverList moveItemAtIndex:originalIndex inParent:client toIndex:index inParent:client];
	}

	[menuController() populateNavigationChannelList];

	return YES;
}

@end

NS_ASSUME_NONNULL_END
