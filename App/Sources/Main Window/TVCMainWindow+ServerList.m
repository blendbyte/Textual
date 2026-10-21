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
#import "TVCServerListBouncerHeadingPrivate.h"
#import "IRCBouncerAccountPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCTextViewIRCFormattingMenuPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocalPrivate.h"
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
		/* The first server: row 0 may be a bouncer's heading */
		IRCClient *firstClient = worldController().clientList.firstObject;

		NSInteger firstRow = ((firstClient) ? [self.serverList rowForItem:firstClient] : -1);

		[self.serverList selectItemAtIndex:MAX(firstRow, 0)];
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
	self.serverList.action = @selector(outlineViewClicked:);
	self.serverList.doubleAction = @selector(outlineViewDoubleClicked:);

	/* Inform the table we want drag events */
	[self.serverList registerForDraggedTypes:_treeDragItemTypes];

	/* Prepare our first selection */
	[self restoreExpandedClients];

	[self restoreSelectionDuringSetup];

	/* Fake the delegate call */
	[self outlineViewSelectionDidChange:[NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification object:self.serverList]];

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

	/* What is selected isn't hidden in a folded bouncer section */
	[self unfoldBouncerHeadingsHidingItems:selectedItems];

	/* What has a window of its own isn't shown here as well */
	if (self.isPopOut == NO) {
		NSMutableArray<IRCTreeItem *> *itemsShownHere = [NSMutableArray arrayWithCapacity:selectedItems.count];

		for (IRCTreeItem *item in selectedItems) {
			if ([self.class popOutWindowForItem:item] == nil) {
				[itemsShownHere addObject:item];
			}
		}

		selectedItems = [itemsShownHere copy];

		if (selectedItem && [selectedItems containsObject:selectedItem] == NO) {
			selectedItem = selectedItems.lastObject;
		}
	}

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
	/* In a window of its own: that window comes forward */
	TVCMainWindow *popOutWindow = ((item) ? [self.class popOutWindowForItem:item] : nil);

	if (popOutWindow && popOutWindow != self) {
		[popOutWindow makeKeyAndOrderFront:nil];

		return;
	}

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

			/* Not a bouncer's heading: the nearest server or channel beyond it */
			nextSelectionRow = [self serverListSelectableRowFrom:nextSelectionRow around:itemIndexOld forbidden:selectedRowsForbidden];

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
#pragma mark Bouncer Headings

/* Account identifiers of the bouncer sections folded in the server list */
static NSString * const TVCMainWindowFoldedBouncersDefaultsKey = @"Window -> Main Window -> Folded Bouncers";

/* Window → Group Servers by Bouncer (off: a plain list) */
static NSString * const TVCMainWindowGroupsServersByBouncerDefaultsKey = @"Window -> Main Window -> Group Servers by Bouncer";

- (BOOL)serverListGroupsServersByBouncer
{
	return [RZUserDefaults() boolForKey:TVCMainWindowGroupsServersByBouncerDefaultsKey];
}

- (void)setServerListGroupsServersByBouncer:(BOOL)groupsServersByBouncer
{
	if ([self serverListGroupsServersByBouncer] == groupsServersByBouncer) {
		return;
	}

	[RZUserDefaults() setBool:groupsServersByBouncer forKey:TVCMainWindowGroupsServersByBouncerDefaultsKey];

	[self reloadServerListStructure];
}

- (BOOL)serverListShowsBouncerHeadings
{
	if (self.isPopOut || [self serverListGroupsServersByBouncer] == NO) {
		return NO;
	}

	return [self serverListHasServersOfBouncers];
}

- (BOOL)serverListHasServersOfBouncers
{
	for (IRCClient *client in worldController().clientList) {
		NSString *accountIdentifier = client.config.bouncerAccountIdentifier;

		if (accountIdentifier && [worldController() findBouncerAccountWithId:accountIdentifier]) {
			return YES;
		}
	}

	return NO;
}

/* The servers, each bouncer's heading before its servers (kept together
 wherever they are in the list) and none of a folded bouncer's */
- (NSArray *)serverListTopLevelItems
{
	NSArray *cache = self.serverListTopLevelItemsCache;

	if (cache) {
		return cache;
	}

	NSArray<IRCClient *> *clientList = worldController().clientList;

	if ([self serverListShowsBouncerHeadings] == NO) {
		return clientList;
	}

	NSSet *foldedBouncers = [self foldedBouncers];

	NSMutableArray *items = [NSMutableArray arrayWithCapacity:clientList.count];

	NSMutableSet *accountsShown = [NSMutableSet set];

	for (IRCClient *client in clientList) {
		NSString *accountIdentifier = client.config.bouncerAccountIdentifier;

		if (accountIdentifier == nil || [worldController() findBouncerAccountWithId:accountIdentifier] == nil) {
			[items addObject:client];

			continue;
		}

		if ([accountsShown containsObject:accountIdentifier]) {
			continue;
		}

		[accountsShown addObject:accountIdentifier];

		[items addObject:[self bouncerHeadingForAccountIdentifier:accountIdentifier]];

		if ([foldedBouncers containsObject:accountIdentifier]) {
			continue;
		}

		for (IRCClient *member in clientList) {
			if ([member.config.bouncerAccountIdentifier isEqualToString:accountIdentifier]) {
				[items addObject:member];
			}
		}
	}

	/* A gap where a section is followed by a normal server */
	NSMutableArray *itemsWithGaps = [NSMutableArray arrayWithCapacity:(items.count + accountsShown.count)];

	for (NSUInteger index = 0; index < items.count; index++) {
		id item = items[index];

		[itemsWithGaps addObject:item];

		NSString *section = [self bouncerSectionOfTopLevelItem:item];

		if (section == nil || (index + 1) >= items.count) {
			continue;
		}

		id nextItem = items[(index + 1)];

		if ([nextItem isKindOfClass:[IRCClient class]] && [self bouncerSectionOfTopLevelItem:nextItem] == nil) {
			[itemsWithGaps addObject:[self sectionGapForAccountIdentifier:section]];
		}
	}

	self.serverListTopLevelItemsCache = itemsWithGaps;

	return itemsWithGaps;
}

- (TVCServerListSectionGap *)sectionGapForAccountIdentifier:(NSString *)accountIdentifier
{
	NSParameterAssert(accountIdentifier != nil);

	NSMutableDictionary *headings = self.serverListBouncerHeadings;

	if (headings == nil) {
		headings = [NSMutableDictionary dictionary];

		self.serverListBouncerHeadings = headings;
	}

	NSString *key = [@"gap " stringByAppendingString:accountIdentifier];

	TVCServerListSectionGap *gap = headings[key];

	if (gap == nil) {
		gap = [TVCServerListSectionGap new];

		headings[key] = gap;
	}

	return gap;
}

/* The same object for an account across reloads: the outline view knows its rows by object */
- (TVCServerListBouncerHeading *)bouncerHeadingForAccountIdentifier:(NSString *)accountIdentifier
{
	NSParameterAssert(accountIdentifier != nil);

	NSMutableDictionary *headings = self.serverListBouncerHeadings;

	if (headings == nil) {
		headings = [NSMutableDictionary dictionary];

		self.serverListBouncerHeadings = headings;
	}

	TVCServerListBouncerHeading *heading = headings[accountIdentifier];

	if (heading == nil) {
		heading = [[TVCServerListBouncerHeading alloc] initWithAccountIdentifier:accountIdentifier];

		headings[accountIdentifier] = heading;
	}

	return heading;
}

- (void)reloadServerListStructure
{
	NSArray *selectedItems = self.selectedItems;

	IRCTreeItem *selectedItem = self.selectedItem;

	[self reloadServerListRows];

	if (selectedItems.count > 0) {
		[self adjustSelectionWithItems:selectedItems selectedItem:selectedItem];
	}
}

/* Rows again, with the servers that were open opened again; the selection
 isn't touched (the caller puts it back) */
- (void)reloadServerListRows
{
	self.serverListTopLevelItemsCache = nil;

	BOOL ignoredSelectionChanges = self.ignoreOutlineViewSelectionChanges;

	self.ignoreOutlineViewSelectionChanges = YES;

	[self.serverList reloadData];

	for (IRCClient *client in worldController().clientList) {
		if (client.sidebarItemIsExpanded && [self.serverList rowForItem:client] >= 0) {
			[self.serverList expandItem:client];
		}
	}

	self.ignoreOutlineViewSelectionChanges = ignoredSelectionChanges;
}

- (NSSet<NSString *> *)foldedBouncers
{
	NSArray *folded = [RZUserDefaults() arrayForKey:TVCMainWindowFoldedBouncersDefaultsKey];

	return [NSSet setWithArray:(folded ?: @[])];
}

- (void)setFoldedBouncers:(NSSet<NSString *> *)foldedBouncers
{
	NSParameterAssert(foldedBouncers != nil);

	if (foldedBouncers.count == 0) {
		[RZUserDefaults() removeObjectForKey:TVCMainWindowFoldedBouncersDefaultsKey];

		return;
	}

	[RZUserDefaults() setObject:foldedBouncers.allObjects forKey:TVCMainWindowFoldedBouncersDefaultsKey];
}

- (void)toggleFoldingOfBouncerHeading:(TVCServerListBouncerHeading *)heading
{
	NSParameterAssert(heading != nil);

	NSMutableSet *foldedBouncers = [[self foldedBouncers] mutableCopy];

	NSString *accountIdentifier = heading.accountIdentifier;

	if ([foldedBouncers containsObject:accountIdentifier]) {
		[foldedBouncers removeObject:accountIdentifier];
	} else {
		/* The selection moves to a server that stays in view */
		NSArray *clients = heading.clients;

		IRCClient *selectedClient = self.selectedClient;

		if (selectedClient && [clients containsObject:selectedClient]) {
			IRCClient *otherClient = nil;

			for (id item in [self serverListTopLevelItems]) {
				if ([item isKindOfClass:[IRCClient class]] && [clients containsObject:item] == NO) {
					otherClient = item;

					break;
				}
			}

			if (otherClient == nil) {
				NSBeep();

				return;
			}

			[self select:otherClient];
		}

		[foldedBouncers addObject:accountIdentifier];
	}

	[self setFoldedBouncers:foldedBouncers];

	[self reloadServerListStructure];
}

- (void)unfoldBouncerHeadingsHidingItems:(NSArray<IRCTreeItem *> *)items
{
	NSParameterAssert(items != nil);

	NSMutableSet *foldedBouncers = [[self foldedBouncers] mutableCopy];

	if (foldedBouncers.count == 0) {
		return;
	}

	BOOL unfolded = NO;

	for (IRCTreeItem *item in items) {
		NSString *accountIdentifier = item.associatedClient.config.bouncerAccountIdentifier;

		if (accountIdentifier && [foldedBouncers containsObject:accountIdentifier]) {
			[foldedBouncers removeObject:accountIdentifier];

			unfolded = YES;
		}
	}

	if (unfolded == NO) {
		return;
	}

	[self setFoldedBouncers:foldedBouncers];

	[self reloadServerListRows];
}

- (NSView *)viewForBouncerHeading:(TVCServerListBouncerHeading *)heading
{
	NSParameterAssert(heading != nil);

	TVCServerListBouncerHeadingView *view = [self.serverList makeViewWithIdentifier:[TVCServerListBouncerHeadingView viewIdentifier] owner:self];

	if (view == nil) {
		view = [[TVCServerListBouncerHeadingView alloc] initWithFrame:NSZeroRect];
	}

	[view showHeading:heading folded:[[self foldedBouncers] containsObject:heading.accountIdentifier]];

	__weak TVCMainWindow *weakSelf = self;

	view.toggleFolding = ^{
		[weakSelf toggleFoldingOfBouncerHeading:heading];
	};

	return view;
}

/* The row itself, or the nearest one that can be selected (not a bouncer's
 heading, not what is going away), first in the direction it lies from the
 old row; -1 when there is none */
- (NSInteger)serverListSelectableRowFrom:(NSInteger)row around:(NSInteger)oldRow forbidden:(nullable NSIndexSet *)forbidden
{
	if (row < 0) {
		return row;
	}

	TVCServerList *serverList = self.serverList;

	NSInteger numberOfRows = serverList.numberOfRows;

	BOOL (^selectable)(NSInteger) = ^BOOL(NSInteger candidate) {
		if (candidate < 0 || candidate >= numberOfRows || candidate == oldRow) {
			return NO;
		}

		if (forbidden && [forbidden containsIndex:candidate]) {
			return NO;
		}

		return (TVCServerListItemIsDecoration([serverList itemAtRow:candidate]) == NO);
	};

	NSInteger step = ((row > oldRow) ? 1 : -1);

	for (NSInteger candidate = row; candidate >= 0 && candidate < numberOfRows; candidate += step) {
		if (selectable(candidate)) {
			return candidate;
		}
	}

	for (NSInteger candidate = (row - step); candidate >= 0 && candidate < numberOfRows; candidate -= step) {
		if (selectable(candidate)) {
			return candidate;
		}
	}

	return (-1);
}

/* A click on a heading folds or unfolds it */
- (void)outlineViewClicked:(nullable id)sender
{
	NSInteger clickedRow = self.serverList.clickedRow;

	if (clickedRow < 0) {
		return;
	}

	id item = [self.serverList itemAtRow:clickedRow];

	if ([item isKindOfClass:[TVCServerListBouncerHeading class]]) {
		[self toggleFoldingOfBouncerHeading:item];
	}
}

- (NSMenu *)serverListMenuForBouncerHeading:(TVCServerListBouncerHeading *)heading
{
	NSParameterAssert(heading != nil);

	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

	NSMenuItem *editItem = [menu addItemWithTitle:TXTLS(@"BasicLanguage[bnc-m3]") action:@selector(editBouncerOfHeading:) keyEquivalent:@""];

	editItem.target = self;
	editItem.representedObject = heading;

	[menu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *connectItem = [menu addItemWithTitle:TXTLS(@"BasicLanguage[bnc-m1]") action:@selector(connectBouncerHeadingServers:) keyEquivalent:@""];

	connectItem.target = self;
	connectItem.representedObject = heading;

	NSMenuItem *disconnectItem = [menu addItemWithTitle:TXTLS(@"BasicLanguage[bnc-m2]") action:@selector(disconnectBouncerHeadingServers:) keyEquivalent:@""];

	disconnectItem.target = self;
	disconnectItem.representedObject = heading;

	return menu;
}

- (void)editBouncerOfHeading:(NSMenuItem *)sender
{
	IRCBouncerAccount *account = ((TVCServerListBouncerHeading *)sender.representedObject).account;

	if (account) {
		[menuController() editBouncerAccount:account];
	}
}

- (void)connectBouncerHeadingServers:(NSMenuItem *)sender
{
	for (IRCClient *client in ((TVCServerListBouncerHeading *)sender.representedObject).clients) {
		if (client.isConnecting == NO && client.isConnected == NO) {
			[client connect];
		}
	}
}

- (void)disconnectBouncerHeadingServers:(NSMenuItem *)sender
{
	for (IRCClient *client in ((TVCServerListBouncerHeading *)sender.representedObject).clients) {
		if (client.isConnecting || client.isConnected) {
			[client quit];
		}
	}
}

- (nullable id)serverListTopLevelItemForDragToken:(NSString *)token
{
	NSParameterAssert(token != nil);

	if ([token hasPrefix:_bouncerHeadingDragPrefix]) {
		return self.serverListBouncerHeadings[[token substringFromIndex:_bouncerHeadingDragPrefix.length]];
	}

	IRCTreeItem *item = [worldController() findItemWithPasteboardString:token];

	return ((item.isClient) ? item : nil);
}

- (nullable NSString *)bouncerSectionOfTopLevelItem:(nullable id)item
{
	if ([item isKindOfClass:[TVCServerListBouncerHeading class]]) {
		return ((TVCServerListBouncerHeading *)item).accountIdentifier;
	}

	if ([item isKindOfClass:[IRCClient class]]) {
		NSString *accountIdentifier = ((IRCClient *)item).config.bouncerAccountIdentifier;

		if (accountIdentifier && [worldController() findBouncerAccountWithId:accountIdentifier]) {
			return accountIdentifier;
		}
	}

	return nil;
}

/* A bouncer's server moves within its section; a heading takes its section
 along, and it and other servers go between sections, never into one */
- (BOOL)serverListAcceptsDropOf:(id)draggedItem atIndex:(NSInteger)index
{
	NSArray *items = [self serverListTopLevelItems];

	if (index < 0 || index > (NSInteger)items.count) {
		return NO;
	}

	id previousItem = ((index > 0) ? items[(index - 1)] : nil);
	id nextItem = ((index < (NSInteger)items.count) ? items[index] : nil);

	BOOL draggedIsHeading = [draggedItem isKindOfClass:[TVCServerListBouncerHeading class]];

	NSString *draggedSection = ((draggedIsHeading) ? nil : [self bouncerSectionOfTopLevelItem:draggedItem]);

	if (draggedSection) {
		return [[self bouncerSectionOfTopLevelItem:previousItem] isEqualToString:draggedSection];
	}

	/* Not before a section's server: that's inside the section */
	if ([nextItem isKindOfClass:[IRCClient class]] && [self bouncerSectionOfTopLevelItem:nextItem]) {
		return NO;
	}

	return YES;
}

- (void)serverListMoveTopLevelItem:(id)draggedItem toIndex:(NSInteger)index
{
	NSMutableArray *items = [[self serverListTopLevelItems] mutableCopy];

	/* A heading takes the servers shown after it along */
	NSMutableArray *movingItems = [NSMutableArray arrayWithObject:draggedItem];

	if ([draggedItem isKindOfClass:[TVCServerListBouncerHeading class]]) {
		NSString *section = ((TVCServerListBouncerHeading *)draggedItem).accountIdentifier;

		for (id item in items) {
			if ([item isKindOfClass:[IRCClient class]] && [[self bouncerSectionOfTopLevelItem:item] isEqualToString:section]) {
				[movingItems addObject:item];
			}
		}
	}

	NSInteger targetIndex = index;

	for (id item in movingItems) {
		NSUInteger itemIndex = [items indexOfObjectIdenticalTo:item];

		if (itemIndex != NSNotFound && (NSInteger)itemIndex < index) {
			targetIndex -= 1;
		}
	}

	[items removeObjectsInArray:movingItems];

	[items insertObjects:movingItems atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(targetIndex, movingItems.count)]];

	/* Back to the server list's order: a folded section's servers where its heading is */
	NSMutableArray<IRCClient *> *clientList = [NSMutableArray array];

	NSSet *foldedBouncers = [self foldedBouncers];

	for (id item in items) {
		if ([item isKindOfClass:[TVCServerListBouncerHeading class]]) {
			TVCServerListBouncerHeading *heading = item;

			if ([foldedBouncers containsObject:heading.accountIdentifier]) {
				[clientList addObjectsFromArray:heading.clients];
			}

			continue;
		}

		/* (not the space after a section) */
		if ([item isKindOfClass:[IRCClient class]] && [clientList containsObject:item] == NO) {
			[clientList addObject:item];
		}
	}

	for (IRCClient *client in worldController().clientList) {
		if ([clientList containsObject:client] == NO) {
			[clientList addObject:client];
		}
	}

	worldController().clientList = clientList;

	[self reloadServerListStructure];
}

#pragma mark -
#pragma mark Server List Delegate

- (void)outlineViewDoubleClicked:(nullable id)sender
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

	return [self serverListTopLevelItems].count;
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

	return [self serverListTopLevelItems][index];
}

- (nullable id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable id)item
{
	return item;
}

- (nullable NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
	if (TVCServerListItemIsDecoration(item)) {
		return [NSTableRowView new];
	}

	if (item == nil || [item isClient]) {
		return [[TVCServerListGroupRowCell alloc] initWithServerList:(id)outlineView];
	} else {
		return [[TVCServerListChildRowCell alloc] initWithServerList:(id)outlineView];
	}
}

/* Fixed heights, Textual 7's and a point more above and below: server rows
 25 (the 14 pt bold name), channel rows 22 (the 16 pt icon 3 points from the
 top and bottom; the fonts are fixed, TVCServerListAppearance.plist). Automatic heights measured each row
 again while the list drew it (a selected name turns bold), which AppKit
 warns about at launch ("reentrant operation in its NSTableView delegate")
 and will make an assert. */
- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	/* A little space above the section */
	if ([item isKindOfClass:[TVCServerListBouncerHeading class]]) {
		return 28.0;
	}

	/* And after it, before a normal server */
	if ([item isKindOfClass:[TVCServerListSectionGap class]]) {
		return 10.0;
	}

	if (item == nil || [item isClient]) {
		return 25.0;
	}

	return 22.0;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
	if ([item isKindOfClass:[TVCServerListBouncerHeading class]]) {
		return [self viewForBouncerHeading:item];
	}

	if ([item isKindOfClass:[TVCServerListSectionGap class]]) {
		return [[NSView alloc] initWithFrame:NSZeroRect];
	}

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
	/* Through the row view: asking the outline view for the cell while it adds
	 the row is a reentrant call (AppKit warns, and will assert) */
	[[rowView viewAtColumn:0] setNeedsDisplay:YES];
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

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return (TVCServerListItemIsDecoration(item) == NO);
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

	/* A row whose item has a window of its own isn't selected:
	 clicked alone, its window comes forward */
	NSMutableIndexSet *rowsShownHere = [proposedSelectionIndexes mutableCopy];

	/* Nor a bouncer's heading: clicked alone, the selection stays as it is */
	[proposedSelectionIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
		if (TVCServerListItemIsDecoration([outlineView itemAtRow:row])) {
			[rowsShownHere removeIndex:row];
		}
	}];

	if (rowsShownHere.count == 0 && proposedSelectionIndexes.count > 0) {
		return outlineView.selectedRowIndexes;
	}

	proposedSelectionIndexes = [rowsShownHere copy];

	__block TVCMainWindow *popOutWindow = nil;

	[proposedSelectionIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
		IRCTreeItem *item = [outlineView itemAtRow:row];

		TVCMainWindow *window = ((item) ? [self.class popOutWindowForItem:item] : nil);

		if (window) {
			[rowsShownHere removeIndex:row];

			popOutWindow = window;
		}
	}];

	if (popOutWindow && rowsShownHere.count == 0) {
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			[popOutWindow makeKeyAndOrderFront:nil];
		});

		return outlineView.selectedRowIndexes;
	}

	return [outlineView selectionIndexesForProposedSelection:rowsShownHere maximumNumberOfSelections:_maximumSelectedRows];

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
	if (items.count == 1 && [items[0] isKindOfClass:[TVCServerListSectionGap class]]) {
		return NO;
	}

	if (items.count == 1) {
		NSString *itemToken = nil;

		if ([items[0] isKindOfClass:[TVCServerListBouncerHeading class]]) {
			itemToken = [_bouncerHeadingDragPrefix stringByAppendingString:((TVCServerListBouncerHeading *)items[0]).accountIdentifier];
		} else {
			itemToken = [worldController() pasteboardStringForItem:items[0]];
		}

		[pasteboard declareTypes:_treeDragItemTypes owner:self];

		[pasteboard setString:itemToken forType:_treeDragItemType];
	}

	return YES;
}

/* A row let go outside the window: it opens in a window of its own there */
- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
	if (operation != NSDragOperationNone || self.isPopOut) {
		return;
	}

	if (NSPointInRect(screenPoint, self.frame)) {
		return;
	}

	NSString *draggedItemToken = [session.draggingPasteboard stringForType:_treeDragItemType];

	if (draggedItemToken == nil) {
		return;
	}

	IRCTreeItem *draggedItem = [worldController() findItemWithPasteboardString:draggedItemToken];

	if (draggedItem == nil) {
		return;
	}

	[self.class popOutItem:draggedItem atScreenPoint:screenPoint];
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

	/* Servers and headings among bouncer sections */
	id draggedTopLevelItem = [self serverListTopLevelItemForDragToken:draggedItemToken];

	if (draggedTopLevelItem && [self serverListShowsBouncerHeadings]) {
		if (item || [self serverListAcceptsDropOf:draggedTopLevelItem atIndex:index] == NO) {
			return NSDragOperationNone;
		}

		return NSDragOperationGeneric;
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
		/* Manual order and automatic sorting would fight */
		if ([TPCPreferences keepChannelListSorted]) {
			return NSDragOperationNone;
		}

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

	id draggedTopLevelItem = [self serverListTopLevelItemForDragToken:draggedItemToken];

	if (draggedTopLevelItem && [self serverListShowsBouncerHeadings]) {
		if (item || [self serverListAcceptsDropOf:draggedTopLevelItem atIndex:index] == NO) {
			return NO;
		}

		[self serverListMoveTopLevelItem:draggedTopLevelItem toIndex:index];

		[menuController() populateNavigationChannelList];

		return YES;
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
