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
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCChannelUser.h"
#import "IRCExtrasPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "IRCWorldPrivate.h"
#import "TVCBasicTableView.h"
#import "TVCLogController.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMemberList.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextView.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TDCAboutDialogPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelInviteSheetPrivate.h"
#import "TDCChannelModifyModesSheetPrivate.h"
#import "TDCChannelModifyTopicSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TDCChannelSpotlightControllerPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCInputPrompt.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TDCNicknameColorSheetPrivate.h"
#import "TDCPreferencesControllerPrivate.h"
#import "TDCServerChangeNicknameSheetPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TDCWelcomeSheetPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesImportExport.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TXMasterControllerPrivate.h"
#import "TXWindowControllerPrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif
#import "TXMenuControllerInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TXMenuController (Window)

#pragma mark -
#pragma mark Window

- (void)closeWindow:(id)sender
{
	TXCommandWKeyAction keyAction = [TPCPreferences commandWKeyAction];

	if (keyAction == TXCommandWKeyActionCloseWindow || mainWindow().keyWindow == NO) {
		NSWindow *windowToClose = [NSApp keyWindow];

		if (windowToClose == nil) {
			windowToClose = [NSApp mainWindow];
		}

		if (windowToClose) {
			[windowToClose performClose:sender];
		}

		return;
	}

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil) {
		return;
	}

	switch (keyAction) {
		case TXCommandWKeyActionPartChannel:
		{
			if (c == nil) {
				return;
			}

			if (c.isChannel) {
				if (c.isActive == NO) {
					return;
				}

				[u partChannel:c];
			} else {
				[worldController() destroyChannel:c];
			}

			break;
		}
		case TXCommandWKeyActionDisconnect:
		{
			if (u.isConnecting == NO && u.isConnected == NO) {
				return;
			}

			[u quit];

			break;
		}
		case TXCommandWKeyActionTerminate:
		{
			[NSApp terminate:sender];

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)showMainWindow:(id)sender
{
	[mainWindow() makeKeyAndOrderFront:sender];
}

- (void)centerMainWindow:(id)sender
{
	[mainWindow() exactlyCenterWindow];
}

- (void)toggleFullscreen:(id)sender
{
	[[NSApp keyWindow] toggleFullScreen:sender];
}

- (void)resetMainWindowFrame:(id)sender
{
	if (mainWindow().inFullscreenMode) {
		[mainWindow() toggleFullScreen:sender];
	}

	[mainWindow() setFrame:[mainWindow() defaultWindowFrame] display:YES animate:YES];

	[mainWindow() exactlyCenterWindow];
}

- (void)sortChannelListNames:(id)sender
{
	for (IRCClient *u in worldController().clientList) {
		NSMutableArray *channelList = [u.channelList mutableCopy];

		[channelList sortUsingComparator:^NSComparisonResult(IRCChannel *channel1, IRCChannel *channel2) {
			if (channel1.isChannel && channel2.isChannel == NO) {
				return NSOrderedAscending;
			}

			NSString *name1 = channel1.name.lowercaseString;
			NSString *name2 = channel2.name.lowercaseString;

			return [name1 compare:name2];
		}];

		if ([channelList isEqualToArray:u.channelList]) {
			continue;
		}

		u.channelList = channelList;

		[u reloadServerListItems];
	}

	[worldController() save];
}

- (void)markAllAsRead:(id)sender
{
	[mainWindow() markAllAsRead];
}

#pragma mark -
#pragma mark Navigation

- (void)navigateToTreeItemAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *path = url.path;
	
	if (path == nil) {
		return;
	}
	
	NSCharacterSet *slashCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	
	NSString *identifier = [path stringByTrimmingCharactersInSet:slashCharacterSet];
	
	if (identifier.length == 0) {
		return;
	}
	
	[self navigateToTreeItemWithIdentifier:identifier];
}

- (void)navigateToTreeItemWithIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);
	
	/* Do not use assert for this condition so we
	 don't crash user when we open a malformed URL. */
	if (identifier.length != 36) {
		return;
	}
	
	IRCTreeItem *item = [worldController() findItemWithId:identifier];
	
	if (item == nil) {
		return;
	}
	
	[self navigateToTreeItem:item];
}

- (void)navigateToTreeItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);
	
	[mainWindow() select:item];
}

- (void)populateNavigationChannelList
{
	[self.mainMenuNavigationChannelListMenu removeAllItems];

	NSUInteger channelCount = 0;

	for (IRCClient *u in worldController().clientList) {
		NSMenu *channelSubmenu = [NSMenu new];

		NSMenuItem *clientMenuItem = [NSMenuItem new];

		clientMenuItem.title = u.name;

		clientMenuItem.submenu = channelSubmenu;

		for (IRCChannel *c in u.channelList) {
			NSMenuItem *channelMenuItem = nil;

			if (channelCount >= 10) {
				channelMenuItem = [NSMenuItem menuItemWithTitle:c.name
														 target:self
														 action:@selector(_navigateToChannelInNavigationList:)];
			} else {
				NSUInteger keyboardIndex = (channelCount + 1);

				if (keyboardIndex == 10) {
					keyboardIndex = 0; // Have 0 as the last item.
				}

				channelMenuItem = [NSMenuItem menuItemWithTitle:c.name
														 target:self
														 action:@selector(_navigateToChannelInNavigationList:)
												  keyEquivalent:[NSString stringWithUniChar:('0' + keyboardIndex)]
											  keyEquivalentMask:NSEventModifierFlagCommand];
			}

			channelMenuItem.userInfo = [worldController() pasteboardStringForItem:c];

			[channelSubmenu addItem:channelMenuItem];

			channelCount += 1;
		}

		[self.mainMenuNavigationChannelListMenu addItem:clientMenuItem];
	}
}

- (void)_navigateToChannelInNavigationList:(NSMenuItem *)sender
{
	IRCTreeItem *treeItem = [worldController() findItemWithPasteboardString:sender.userInfo];

	if (treeItem == nil) {
		return;
	}

	[mainWindow() select:treeItem];
}

- (void)performNavigationAction:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	switch ([sender tag]) {
		case MTMMNavigationServersMenuNextServer:
		{
			[mainWindow() selectNextServer:sender];

			break;
		}
		case MTMMNavigationServersMenuPreviousServer:
		{
			[mainWindow() selectPreviousServer:sender];

			break;
		}
		case MTMMNavigationServersMenuNextActiveServer:
		{
			[mainWindow() selectNextActiveServer:sender];

			break;
		}
		case MTMMNavigationServersMenuPreviousActiveServer:
		{
			[mainWindow() selectPreviousActiveServer:sender];

			break;
		}
		case MTMMNavigationChannelsMenuNextChannel:
		{
			[mainWindow() selectNextChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuPreviousChannel:
		{
			[mainWindow() selectPreviousChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuNextActiveChannel:
		{
			[mainWindow() selectNextActiveChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuPreviousActiveChannel:
		{
			[mainWindow() selectPreviousActiveChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuNextUnreadChannel:
		{
			[mainWindow() selectNextUnreadChannel:sender];

			break;
		}
		case MTMMNavigationChannelsMenuPreviousUnreadChannel:
		{
			[mainWindow() selectPreviousUnreadChannel:sender];

			break;
		}
		case MTMMNavigationMoveBackward:
		{
			[mainWindow() selectPreviousWindow:sender];

			break;
		}
		case MTMMNavigationMoveForward:
		{
			[mainWindow() selectNextWindow:sender];

			break;
		}
		case MTMMNavigationPreviousSelection:
		{
			[mainWindow() selectPreviousSelection:sender];

			break;
		}
	} // switch()
}

- (void)onNextHighlight:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController nextHighlight];
}

- (void)onPreviousHighlight:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController previousHighlight];
}

- (void)jumpToCurrentSession:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController jumpToCurrentSession];
}

- (void)jumpToPresent:(id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController jumpToPresent];
}

@end

NS_ASSUME_NONNULL_END
