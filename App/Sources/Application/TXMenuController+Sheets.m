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

@implementation TXMenuController (Sheets)

#pragma mark -
#pragma mark Channel Properties Sheet

- (void)showChannelPropertiesSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	TDCChannelPropertiesSheet *sheet =
	[[TDCChannelPropertiesSheet alloc] initWithChannel:c];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelPropertiesSheet:(TDCChannelPropertiesSheet *)sender onOk:(IRCChannelConfig *)config
{
	IRCClient *u = sender.client;

	if (u == nil) {
		return;
	}

	IRCChannel *c = sender.channel;

	if (c == nil) {
		[worldController() createChannelWithConfig:config onClient:u];

		[mainWindow() expandClient:u];

		return;
	}

	[c updateConfig:config];

	[worldController() save];
}

- (void)channelPropertiesSheetWillClose:(TDCChannelPropertiesSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Invite Sheet

- (void)memberSendInvite:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO || c.isActive == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSMutableArray<NSString *> *channels = [NSMutableArray array];

	for (IRCChannel *e in u.channelList) {
		if (c != e && e.isChannel) {
			[channels addObject:e.name];
		}
	}

	if (channels.count == 0) {
		return;
	}

	TDCChannelInviteSheet *sheet =
	[[TDCChannelInviteSheet alloc] initWithNicknames:nicknames onClient:u];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet startWithChannels:channels];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelInviteSheet:(TDCChannelInviteSheet *)sender onSelectChannel:(NSString *)channelName
{
	IRCClient *u = sender.client;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in sender.nicknames) {
		[u sendInviteTo:nickname toJoinChannelNamed:channelName];
	}
}

- (void)channelInviteSheetWillClose:(TDCChannelInviteSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Address Book Sheet

- (void)showAddressBook:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[self showServerPropertiesSheetForClient:u
							   withSelection:TDCServerPropertiesSheetSelectionAddressBook
									 context:nil];
}

- (void)showIgnoreList:(id)sender
{
	[self showAddressBook:sender];
}

#pragma mark -
#pragma mark Welcome Sheet

- (void)showWelcomeSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	TDCWelcomeSheet *sheet =
	[[TDCWelcomeSheet alloc] initWithWindow:mainWindow()];

	sheet.delegate = (id)self;

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)welcomeSheet:(TDCWelcomeSheet *)sender onOk:(IRCClientConfig *)config
{
	IRCClient *u = [worldController() createClientWithConfig:config reload:YES];

	[mainWindow() expandClient:u];

	[worldController() save];

	[u connect];

	[u selectFirstChannelInChannelList];
}

- (void)welcomeSheetWillClose:(TDCWelcomeSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark About Window

- (void)showAboutWindow:(id)sender
{
	_popWindowViewIfExists(@"TDCAboutDialog");

	TDCAboutDialog *dialog = [TDCAboutDialog new];

	dialog.delegate = (id)self;

	[dialog show];

	[windowController() addWindowToWindowList:dialog];
}

- (void)aboutDialogWillClose:(TDCAboutDialog *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Server Properties Sheet

- (void)showServerPropertiesSheetForClient:(IRCClient *)client withSelection:(TDCServerPropertiesSheetSelection)selection context:(nullable id)context
{
	NSParameterAssert(client != nil);

	[windowController() popMainWindowSheetIfExists];

	TDCServerPropertiesSheet *sheet = [[TDCServerPropertiesSheet alloc] initWithClient:client];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet startWithSelection:selection context:context];

	[windowController() addWindowToWindowList:sheet];
}

- (void)showServerPropertiesSheet:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[self showServerPropertiesSheetForClient:u
							   withSelection:TDCServerPropertiesSheetSelectionDefault
									 context:nil];
}

- (void)serverPropertiesSheet:(TDCServerPropertiesSheet *)sender onOk:(IRCClientConfig *)config
{
	IRCClient *u = sender.client;

	if (u == nil) {
		u = [worldController() createClientWithConfig:config reload:YES];

		[mainWindow() expandClient:u];

		[worldController() save];

		return;
	}

	BOOL sameEncoding = (config.primaryEncoding == u.config.primaryEncoding);

	[u updateConfig:config];

	if (sameEncoding == NO) {
		[mainWindow() reloadTheme];
	}

	[mainWindow() reloadTreeGroup:u];

	[worldController() save];
}

- (void)serverPropertiesSheetWillClose:(TDCServerPropertiesSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Highlight List Sheet

- (void)showServerHighlightList:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	TDCServerHighlightListSheet *sheet =
	[[TDCServerHighlightListSheet alloc] initWithClient:u];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)serverHighlightListSheetWillClose:(TDCServerHighlightListSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Nickname Color Sheet

- (void)memberChangeColor:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	TDCNicknameColorSheet *sheet =
	[[TDCNicknameColorSheet alloc] initWithNickname:nickname];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)nicknameColorSheetOnOk:(TDCNicknameColorSheet *)sender
{
	[mainWindow() reloadTheme];
}

- (void)nicknameColorSheetWillClose:(TDCNicknameColorSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Topic Sheet

- (void)showChannelModifyTopicSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	TDCChannelModifyTopicSheet *sheet =
	[[TDCChannelModifyTopicSheet alloc] initWithChannel:c];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelModifyTopicSheet:(TDCChannelModifyTopicSheet *)sender onOk:(NSString *)topic
{
	IRCClient *u = sender.client;
	IRCChannel *c = sender.channel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u sendTopicTo:topic inChannel:c];
}

- (void)channelModifyTopicSheetWillClose:(TDCChannelModifyTopicSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Mode Sheet

- (void)showChannelModifyModesSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || c.isChannel == NO) {
		return;
	}

	TDCChannelModifyModesSheet *sheet =
	[[TDCChannelModifyModesSheet alloc] initWithChannel:c];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)channelModifyModesSheet:(TDCChannelModifyModesSheet *)sender onOk:(IRCChannelModeContainer *)modes
{
	IRCClient *u = sender.client;
	IRCChannel *c = sender.channel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSString *changeString = [c.modeInfo getChangeCommand:modes];

	if (changeString.length == 0) {
		return;
	}

	[u sendModes:changeString withParameters:nil inChannel:c];
}

- (void)channelModifyModesSheetWillClose:(TDCChannelModifyModesSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Channel Spotlight Window

- (void)showChannelSpotlightWindow:(id)sender
{
	_popWindowViewIfExists(@"TDCChannelSpotlightController");

	TDCChannelSpotlightController *dialog = [TDCChannelSpotlightController new];

	dialog.delegate = (id)self;

	[dialog show];

	[windowController() addWindowToWindowList:dialog];
}

- (void)channelSpotlightController:(TDCChannelSpotlightController *)sender selectChannel:(IRCChannel *)channel
{
	[mainWindow() select:channel];
}

- (void)channelSpotlightControllerWillClose:(TDCChannelSpotlightController *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Change Nickname Sheet

- (void)showServerChangeNicknameSheet:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	TDCServerChangeNicknameSheet *sheet =
	[[TDCServerChangeNicknameSheet alloc] initWithClient:u];

	sheet.delegate = (id)self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)serverChangeNicknameSheet:(TDCServerChangeNicknameSheet *)sender didInputNickname:(NSString *)nickname
{
	IRCClient *u = sender.client;

	if (u == nil || u.isConnected == NO) {
		return;
	}

	[u changeNickname:nickname];
}

- (void)serverChangeNicknameSheetWillClose:(TDCServerChangeNicknameSheet *)sender
{
	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Preferences Dialog

- (void)showPreferencesWindow:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionDefault];
}

- (void)showNotificationPreferences:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionNotifications];
}

- (void)showStylePreferences:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionStyle];
}

- (void)showHiddenPreferences:(id)sender
{
	[self showPreferencesWindowWithSelection:TDCPreferencesControllerSelectionHiddenPreferences];
}

- (void)showPreferencesWindowWithSelection:(TDCPreferencesControllerSelection)selection
{
	TDCPreferencesController *openWindow = [windowController() windowFromWindowList:@"TDCPreferencesController"];

	if (openWindow) {
		[openWindow show:selection];

		return;
	}

	TDCPreferencesController *controller =
	[TDCPreferencesController new];

	controller.delegate = (id)self;

	[controller show:selection];

	[windowController() addWindowToWindowList:controller];
}

- (void)preferencesDialogWillClose:(TDCPreferencesController *)sender
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionHighlightKeywords |
										 TPCPreferencesReloadActionPreferencesChanged)];

	[windowController() removeWindowFromWindowList:sender];
}

@end

NS_ASSUME_NONNULL_END
