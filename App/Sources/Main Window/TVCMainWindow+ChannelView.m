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
#import "TVCTextViewIRCFormattingMenuPrivate.h"
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

@implementation TVCMainWindow (ChannelView)

#pragma mark -
#pragma mark Channel View Box

- (void)channelViewSelectionChangeTo:(IRCTreeItem *)selectedItem
{
	[self selectItemInSelectedItems:selectedItem refreshChannelView:NO];
}

- (void)updateChannelViewArrangement
{
	[self.channelView updateArrangement];
}

- (void)updateChannelViewBoxContentViewSelection
{
	[self.channelView populateSubviews];
}

- (BOOL)isItemVisible:(IRCTreeItem *)item
{
	if (item == nil) {
		return NO;
	}

	return ([self isItemSelected:item] || [self isItemInSelectedGroup:item]);
}

- (BOOL)isItemSelected:(IRCTreeItem *)item
{
	if (item == nil) {
		return NO;
	}

	return (self.selectedItem == item);
}

- (BOOL)isItemInSelectedGroup:(IRCTreeItem *)item
{
	if (item == nil) {
		return NO;
	}

	return ([self.selectedItems containsObject:item]);
}

- (void)selectionDidChangeToRows:(NSIndexSet *)selectedRows
{
	[self selectionDidChangeToRows:selectedRows selectedItem:nil];
}

- (void)selectionDidChangeToRows:(NSIndexSet *)selectedRows selectedItem:(nullable IRCTreeItem *)selectedItem
{
	NSParameterAssert(selectedRows != nil);

	/* Create list of selected items and notify those newly selected items
	 that they are now visible + part of a stacked view */
	NSArray *selectedItems = self.serverList.selectedObjects;

	/* Update selected item even if group hasn't changed */
	if ([selectedItems isEqualToArray:self.selectedItems]) { /* Update selected item even if group hasn't changed */
		if (selectedItem) {
			[self selectItemInSelectedItems:selectedItem];
		}

		return;
	}

	NSUInteger selectedItemsCount = selectedItems.count;

	/* Store previous selection */
	[self storePreviousSelection];

	/* Update properties */
	NSArray *selectedItemsPrevious = nil;

	if (self.selectedItems) {
		selectedItemsPrevious = [self.selectedItems copy];
	}

	if (selectedItemsCount > 0) {
		self.selectedItems = selectedItems;

		if (selectedItem == nil) {
			selectedItem = self.selectedItem;
		}

		if (selectedItem && [self isItemInSelectedGroup:selectedItem]) {
			self.selectedItem = selectedItem;
		} else {
			self.selectedItem = selectedItems[(selectedItemsCount - 1)];
		}
	} else {
		self.selectedItem = nil;
		self.selectedItems = @[];
	}

	/* Update split view */
	[self updateChannelViewBoxContentViewSelection];

	/* Inform views that are currently selected that no longer will be that they
	 are now hidden. We wait until after -updateChannelViewBoxContentViewSelection
	 is called to do this so that the views that are hidden are actually hidden
	 before informing the views of this fact. */
	for (IRCTreeItem *item in selectedItemsPrevious) {
		if (selectedItems == nil || [selectedItems containsObject:item] == NO) {
			[item.viewController notifyDidBecomeHidden];
		}
	}

	/* Inform new views that they are visible now that they are visible. */
	for (IRCTreeItem *item in selectedItems) {
		if (selectedItemsPrevious == nil || [selectedItemsPrevious containsObject:item] == NO) {
			[item.viewController notifyDidBecomeVisible];

			if (item != self.selectedItem) {
				[item.viewController notifySelectionChanged];
			}
		}
	}

	selectedItems = nil;
	selectedItemsPrevious = nil;

	/* Perform postflight routines */
	[self selectionDidChangePostflight];
}

- (void)selectionDidChangePostflight
{
	/* If the selection hasn't changed, then do nothing. */
	IRCTreeItem *itemChangedTo = self.selectedItem;

	IRCTreeItem *itemChangedFrom = self.previouslySelectedItem;

	if (itemChangedTo == itemChangedFrom) {
		return;
	}

	/* Reset state of selections */
	if (itemChangedFrom) {
		[itemChangedFrom resetState];
	}

	if (itemChangedTo) {
		if (self.multipleItemsSelected) {
			[self.serverList refreshMessageCountForItem:itemChangedTo];
		}

		[itemChangedTo resetState];

		if (itemChangedTo.isClient == NO) {
			[itemChangedTo.associatedClient markChannelAsRead:(IRCChannel *)itemChangedTo];
		}
	}

	/* Notify WebKit its selection status has changed */
	if (itemChangedFrom) {
		[itemChangedFrom.viewController notifySelectionChanged];
	}

	/* Typing: leaving a conversation ends ours there; the next one shows its own */
	if (itemChangedFrom && itemChangedFrom.isClient == NO) {
		IRCChannel *previousChannel = (IRCChannel *)itemChangedFrom;

		[previousChannel.associatedClient sendTypingDoneToChannel:previousChannel];

		[previousChannel.viewController removeTypingIndicator];
	}

	[self refreshTypingIndicator];

	/* Destroy member list if we have no selection */
	if (itemChangedTo == nil) {
		[self.memberList assignToChannel:nil];

		self.serverList.menu = nil;

		[self updateTitle];

		return; // Nothing more to do for empty selections
	}

	/* Prepare the member list for the selection */
	BOOL isClient = itemChangedTo.isClient;

	BOOL isChannel = itemChangedTo.isChannel;

	/* The right click menu follows selection so let's update
	 the menu we will show depending on the selection. */
	if (isClient) {
		self.serverList.menu = menuController().mainMenuServerMenuItem.submenu;
	} else if (isChannel) {
		self.serverList.menu = menuController().mainMenuChannelMenu;
	} else {
		self.serverList.menu = menuController().mainMenuQueryMenu;
	}

	/* Update table view data sources */
	if (isChannel) {
		[self.memberList assignToChannel:(id)itemChangedTo];
	} else {
		[self.memberList assignToChannel:nil];
	}

	/* Begin work on text field */
	BOOL autoFocusInputTextField = [TPCPreferences focusMainTextViewOnSelectionChange];

	if (autoFocusInputTextField && [XRAccessibility isVoiceOverEnabled] == NO) {
		[self.inputTextField focus];
	}

	[self.inputTextField updateSegmentedController];

	/* Setup text field value with history item when we have
	 history setup to be channel specific. */
	[self.inputHistoryManager moveFocusTo:itemChangedTo];

	/* Reset spelling for text field */
	[self.inputTextField resetSpellingIgnores];

	/* Update splitter view depending on selection */
	if (isChannel) {
		if (self.memberList.isHiddenByUser == NO) {
			[self.contentSplitView expandMemberList];
		}
	} else {
		[self.contentSplitView collapseMemberList];
	}

	/* Notify WebKit its selection status has changed */
	[itemChangedTo.viewController notifySelectionChanged];

	/* Finish up */
	[self storeLastSelectedChannel];

	[RZNotificationCenter() postNotificationName:TVCMainWindowSelectionChangedNotification object:self];

	[TVCDockIcon updateDockIcon];

	[self updateTitle];
}

#pragma mark -
#pragma mark Split View

- (void)saveContentSplitViewState
{
	[RZUserDefaults() setBool:self.serverListVisible
					   forKey:@"Window -> Main Window -> Server List is Visible"];

	[RZUserDefaults() setBool:(self.memberList.isHiddenByUser == NO)
					   forKey:@"Window -> Main Window -> Member List is Visible"];
}

- (void)restoreSavedContentSplitViewState
{
	/* Make server list and member list visible + restore saved position. */
	[self.contentSplitView restorePositions];

	/* Collapse one or more items if they were collapsed when closing Textual. */
	id makeMemberListVisible = [RZUserDefaults() objectForKey:@"Window -> Main Window -> Member List is Visible"];

	if (makeMemberListVisible && [makeMemberListVisible boolValue] == NO) {
		self.memberList.isHiddenByUser = YES;

		[self.contentSplitView collapseMemberList];
	}

	id makeServerListVisible = [RZUserDefaults() objectForKey:@"Window -> Main Window -> Server List is Visible"];

	if (makeServerListVisible && [makeServerListVisible boolValue] == NO) {
		[self.contentSplitView collapseServerList];
	}
}

#pragma mark -
#pragma mark User List

#pragma mark -
#pragma mark Typing Notifications

/* Only the selected channel shows who is typing, as the last line of its view */
- (void)updateTypingIndicatorForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (channel != self.selectedChannel) {
		return;
	}

	[self refreshTypingIndicator];
}

- (void)refreshTypingIndicator
{
	IRCChannel *channel = self.selectedChannel;

	/* The console (no channel) has nobody typing */
	NSArray *nicknames = @[];

	if (channel) {
		nicknames = [channel typingNicknamesAtDate:[NSDate date]];
	}

	NSString *text = [IRCClient typingIndicatorTextForNicknames:nicknames];

	if (text == nil) {
		[channel.viewController removeTypingIndicator];

		[self.typingIndicatorSweepTimer invalidate];

		self.typingIndicatorSweepTimer = nil;

		return;
	}

	[channel.viewController setTypingIndicatorText:text];

	/* Nothing has to arrive for typing to expire: look again every few seconds */
	if (self.typingIndicatorSweepTimer == nil) {
		__weak TVCMainWindow *weakSelf = self;

		self.typingIndicatorSweepTimer =
		[NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
			[weakSelf refreshTypingIndicator];
		}];
	}
}

- (void)inputTextDidChange
{
	IRCTreeItem *selectedItem = self.selectedItem;

	if (selectedItem == nil || selectedItem.isClient) {
		return;
	}

	[selectedItem.associatedClient typingInputChanged:self.inputTextField.string inChannel:(IRCChannel *)selectedItem];
}

- (void)updateDrawingForUserInUserList:(IRCUser *)user
{
	IRCChannel *selectedChannel = self.selectedChannel;

	if (selectedChannel == nil) {
		return;
	}

	IRCChannelUser *channelUser = [user userAssociatedWithChannel:selectedChannel];

	if (channelUser == nil) {
		return;
	}

	[self.memberList refreshDrawingForMember:channelUser];
}

@end

NS_ASSUME_NONNULL_END
