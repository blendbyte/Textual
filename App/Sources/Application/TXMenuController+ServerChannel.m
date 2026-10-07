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

@implementation TXMenuController (ServerChannel)

#pragma mark -
#pragma mark Server

- (void)connect:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected || u.isQuitting) {
		return;
	}

	[u connect];

	[mainWindow() expandClient:u];
}

- (void)connectBypassingProxy:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected || u.isQuitting) {
		return;
	}

	[u connect:IRCClientConnectModeNormal bypassProxy:YES];

	[mainWindow() expandClient:u];
}

- (void)disconnect:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || (u.isConnecting == NO && u.isConnected == NO) || u.isQuitting) {
		return;
	}

	[u quit];
}

- (void)cancelReconnection:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	[u cancelReconnect];
}

- (void)showServerChannelList:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	[u createChannelListDialog];

	[u requestChannelList];
}

- (void)addServer:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	TDCServerPropertiesSheet *sheet =
	[[TDCServerPropertiesSheet alloc] initWithClient:nil];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet startWithSelection:TDCServerPropertiesSheetSelectionDefault context:nil];

	[windowController() addWindowToWindowList:sheet];
}

- (void)duplicateServer:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	IRCClientConfigMutable *config = [u.config uniqueCopyMutable];

	config.connectionName = [config.connectionName stringByAppendingString:@"_"];

	IRCClient *newClient = [worldController() createClientWithConfig:config reload:YES];

	if (newClient.config.sidebarItemExpanded) { // Only expand new client if old was expanded already.
		[mainWindow() expandClient:newClient];
	}

	[worldController() save];
}

- (void)deleteServer:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil || u.isConnecting || u.isConnected) {
		return;
	}

	BOOL result = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[etl-ss]")
											title:TXTLS(@"Prompts[0kz-wd]")
									defaultButton:TXTLS(@"Prompts[mvh-ms]")
								  alternateButton:TXTLS(@"Prompts[99q-gg]")];

	if (result == NO) {
		return;
	}

	[worldController() destroyClient:u];

	[worldController() save];
}

#pragma mark -
#pragma mark Channel

- (void)joinChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO || c.isActive) {
		return;
	}

	[u joinChannel:c];

	[mainWindow() select:c];
}

- (void)leaveChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	/* Second boxed in condition is because this is used for queries too */
	if (u == nil || c == nil || (c.isChannel && (u.isLoggedIn == NO || c.isActive == NO))) {
		return;
	}

	if (c.isChannel) {
		[u partChannel:c];

		return;
	}

	[worldController() destroyChannel:c];
}

- (void)addChannel:(id)sender
{
	[windowController() popMainWindowSheetIfExists];

	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	TDCChannelPropertiesSheet *sheet =
	[[TDCChannelPropertiesSheet alloc] initWithClient:u];

	sheet.delegate = self;

	sheet.window = mainWindow();

	[sheet start];

	[windowController() addWindowToWindowList:sheet];
}

- (void)deleteChannel:(id)sender
{
	IRCChannel *c = self.selectedChannel;

	if (c == nil) {
		return;
	}

	if (c.isChannel) {
		BOOL result = [TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[516-ms]")
												title:TXTLS(@"Prompts[i8o-7z]")
										defaultButton:TXTLS(@"Prompts[mvh-ms]")
									  alternateButton:TXTLS(@"Prompts[99q-gg]")
									   suppressionKey:@"delete_channel"
									  suppressionText:nil];

		if (result == NO) {
			return;
		}
	}

	[worldController() destroyChannel:c];

	[worldController() save];
}

- (void)copyUniqueIdentifier:(id)sender
{
	IRCChannel *c = self.selectedChannel;

	if (c == nil) {
		return;
	}

	[RZPasteboard() setStringContent:c.uniqueIdentifier];
}

#pragma mark -
#pragma mark Other Actions

- (void)copyUrl:(id)sender
{
	NSString *pointedUrl = ((NSMenuItem *)sender).userInfo;

	if (pointedUrl.length == 0) {
		return;
	}

	RZPasteboard().stringContent = pointedUrl;
}

- (void)joinChannelClicked:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	NSString *pointedChannelName = nil;

	if ([sender isKindOfClass:[NSMenuItem class]]) {
		pointedChannelName = ((NSMenuItem *)sender).userInfo;
	} else if ([sender isKindOfClass:[NSString class]]) {
		pointedChannelName = sender;
	} else {
		return;
	}

	if ([u stringIsChannelName:pointedChannelName] == NO) {
		return;
	}

	IRCChannel *c = [u findChannelOrCreate:pointedChannelName];

	[u joinChannel:c];

	[mainWindow() select:c];
}

#pragma mark -
#pragma mark Logging

- (void)openLogLocation:(id)sender
{	
	NSURL *path = [TPCPathInfo transcriptFolderURL];

	if (path == nil) {
		return;
	}

	if ([RZFileManager() fileExistsAtURL:path]) {
		[RZWorkspace() openURL:path];

		return;
	}

	[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[f05-hu]")
							  title:TXTLS(@"Prompts[k55-19]")
					  defaultButton:TXTLS(@"Prompts[c7s-dq]")
					alternateButton:nil];
}

- (void)openChannelLogs:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSURL *path = c.logFilePath;

	if (path == nil) {
		return;
	}

	if ([RZFileManager() fileExistsAtURL:path]) {
		[RZWorkspace() openURL:path];

		return;
	}

	[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[f05-hu]")
							  title:TXTLS(@"Prompts[k55-19]")
					  defaultButton:TXTLS(@"Prompts[c7s-dq]")
					alternateButton:nil];
}

#pragma mark -
#pragma mark IRC

- (void)showChannelBanList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelBanListSheet];

	[u sendModes:@"+b" withParameters:nil inChannel:c];
}

- (void)showChannelBanExceptionList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelBanExceptionListSheet];

	[u sendModes:@"+e" withParameters:nil inChannel:c];
}

- (void)showChannelInviteExceptionList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelInviteExceptionListSheet];

	[u sendModes:@"+I" withParameters:nil inChannel:c];
}

- (void)showChannelQuietList:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	[u createChannelQuietListSheet];

	[u sendModes:@"+q" withParameters:nil inChannel:c];
}

- (void)toggleChannelModerationMode:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSString *modeSymbol = nil;

	if ([sender tag] == MTMMChannelModesMenuRemoveModerated) {
		modeSymbol = @"-m";
	} else {
		modeSymbol = @"+m";
	}

	[u sendModes:modeSymbol withParameters:nil inChannel:c];
}

- (void)toggleChannelInviteMode:(id)sender
{
	NSParameterAssert(sender != nil);

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSString *modeSymbol = nil;

	if ([sender tag] == MTMMChannelModesMenuRemoveInviteOnly) {
		modeSymbol = @"-i";
	} else {
		modeSymbol = @"+i";
	}

	[u sendModes:modeSymbol withParameters:nil inChannel:c];
}

@end

NS_ASSUME_NONNULL_END
