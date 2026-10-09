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

@implementation TXMenuController (Members)

#pragma mark -
#pragma mark Selected User(s)

- (BOOL)checkSelectedMembers:(id)sender
{
	return ([self selectedMembers:sender].count > 0);
}

- (NSArray<IRCChannelUser *> *)selectedMembers:(id)sender
{
	return [self selectedMembers:sender returnStrings:NO];
}

- (NSArray<NSString *> *)selectedMembersNicknames:(id)sender
{
	return [self selectedMembers:sender returnStrings:YES];
}

- (NSArray *)selectedMembers:(id)sender returnStrings:(BOOL)returnStrings
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isActive == NO) {
		return @[];
	}

	/* Return a specific nickname for WebView events */
	NSString *pointedNickname = nil;

	if ([sender isKindOfClass:[NSMenuItem class]]) {
		pointedNickname = ((NSMenuItem *)sender).userInfo;
	} else {
		pointedNickname = self.pointedNickname;
	}

	if (pointedNickname) {
		if (returnStrings) {
			return @[pointedNickname];
		}

		IRCChannelUser *user = [c findMember:pointedNickname];

		if (user) {
			return @[user];
		}

		return @[];
	}

	/* If we did not have a specific nickname, then query
	 the user list for selected rows. */
	NSMutableArray *userArray = [NSMutableArray array];

	NSIndexSet *selectedRows = mainWindowMemberList().selectedRowIndexes;

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		IRCChannelUser *user = [mainWindowMemberList() itemAtRow:index];

		if (returnStrings) {
			[userArray addObject:user.user.nickname];
		} else {
			[userArray addObject:user];
		}
	}];

	return [userArray copy];
}

- (void)deselectMembers:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		if (((NSMenuItem *)sender).userInfo.length > 0) {
			return; // Nothing to deselect when our sender used userInfo
		}
	}

	if (self.pointedNickname) {
		self.pointedNickname = nil;

		return;
	}

	[mainWindowMemberList() deselectAll:sender];
}

#pragma mark -
#pragma mark Ignores

- (void)memberAddIgnore:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSString *command = [NSString stringWithFormat:@"ignore %@", nicknames[0]];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberRemoveIgnore:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSString *command = [NSString stringWithFormat:@"unignore %@", nicknames[0]];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberModifyIgnore:(id)sender
{
	IRCClient *u = self.selectedClient;

	if (u == nil) {
		return;
	}

	NSArray<IRCChannelUser *> *nicknames = [self selectedMembers:sender];

	[self deselectMembers:sender];

	/* User's hostmask and other information can change between the point
	 the menu item is opened and the point the action is performed.
	 We therefore perform a new query for ignores when performing action. */
	NSString *hostmask = nicknames.firstObject.user.hostmask;

	if (nicknames.count != 1 || hostmask == nil) {
		return;
	}

	NSArray *userIgnores = [u findIgnoresForHostmask:hostmask];

	/* If we have more than one user ignore, then open
	 the address book instead of a specific ignore. */
	if (userIgnores.count == 1) {
		[self showServerPropertiesSheetForClient:u
								   withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry
										 context:userIgnores[0]];
	} else {
		[self showServerPropertiesSheetForClient:u
								   withSelection:TDCServerPropertiesSheetSelectionAddressBook
										 context:nil];
	}
}

#pragma mark -
#pragma mark Members

- (void)memberInMemberListDoubleClicked:(id)sender
{
	/* The member list's selection, never a nickname left from the chat view */
	self.pointedNickname = nil;

	NSInteger rowBeneathMouse = mainWindowMemberList().rowBeneathMouse;

	if (rowBeneathMouse < 0) {
		return;
	}

	TXUserDoubleClickAction action = [TPCPreferences userDoubleClickOption];

	if (action == TXUserDoubleClickActionWhois) {
		[self whoisSelectedMembers:sender];
	} else if (action == TXUserDoubleClickActionPrivateMessage) {
		[self memberStartPrivateMessage:sender];
	} else if (action == TXUserDoubleClickActionInsertTextField) {
		[self memberInsertNameIntoTextField:sender];
	}
}

- (void)memberInChannelViewDoubleClicked:(id)sender
{
	TXUserDoubleClickAction action = [TPCPreferences userDoubleClickOption];

	if (action == TXUserDoubleClickActionWhois) {
		[self whoisSelectedMembers:sender];
	} else if (action == TXUserDoubleClickActionPrivateMessage) {
		[self memberStartPrivateMessage:sender];
	} else if (action == TXUserDoubleClickActionInsertTextField) {
		[self memberInsertNameIntoTextField:sender];
	}

	/* For this double-click only: an action that returned early left it set */
	self.pointedNickname = nil;
}

- (void)memberInsertNameIntoTextField:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	TVCMainWindowTextView *textView = mainWindowTextField();

	NSRange selectedRange = textView.selectedRange;

	NSMutableString *stringToInsert = [NSMutableString string];

	if (selectedRange.location > 0) {
		UniChar previousCharacter = [textView.stringValue characterAtIndex:(selectedRange.location - 1)];

		if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:previousCharacter] == NO) {
			[stringToInsert appendString:@" "];
		}
	}

	NSString *nicknamesString = [nicknames componentsJoinedByString:@", "];

	[stringToInsert appendString:nicknamesString];

	NSString *completionSuffix = [TPCPreferences tabCompletionSuffix];

	if (completionSuffix != nil) {
		[stringToInsert appendString:completionSuffix];
	}

	[textView replaceCharactersInRange:selectedRange withString:stringToInsert];

	[textView resetFontColorInRange:selectedRange];

	[textView focus];
}

- (void)memberSendWhois:(id)sender
{
	[self whoisSelectedMembers:sender];
}

- (void)whoisSelectedMembers:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendWhois:nickname];
	}

	[self deselectMembers:sender];
}

- (void)memberStartPrivateMessage:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		IRCChannel *query = [u findChannelOrCreate:nickname isPrivateMessage:YES];

		[mainWindow() select:query];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPPing:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPPing:nickname];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPFinger:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"FINGER" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPTime:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"TIME" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPVersion:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"VERSION" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPUserinfo:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"USERINFO" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)memberSendCTCPClientInfo:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u sendCTCPQuery:nickname command:@"CLIENTINFO" text:nil];
	}

	[self deselectMembers:sender];
}

- (void)_processModeChange:(id)sender usingCommand:(NSString *)modeCommand
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	[self deselectMembers:sender];

	NSString *nicknamesString = [nicknames componentsJoinedByString:@" "];

	NSString *command = [NSString stringWithFormat:@"%@ %@", modeCommand, nicknamesString];

	[u sendCommand:command completeTarget:YES target:c.name];
}

- (void)memberModeGiveOp:(id)sender
{
	[self _processModeChange:sender usingCommand:@"OP"];
}

- (void)memberModeTakeOp:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEOP"];
}

- (void)memberModeGiveOwner:(id)sender
{
	[self _processModeChange:sender usingCommand:@"OWNER"];
}

- (void)memberModeTakeOwner:(id)sender
{
	[self _processModeChange:sender usingCommand:@"DEOWNER"];
}

- (void)memberModeGiveHalfop:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"HALFOP"];
}

- (void)memberModeTakeHalfop:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEHALFOP"];
}

- (void)memberModeGiveVoice:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"VOICE"];
}

- (void)memberModeTakeVoice:(id)sender
{ 
	[self _processModeChange:sender usingCommand:@"DEVOICE"];
}

- (void)memberKickFromChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		[u kick:nickname inChannel:c];
	}

	[self deselectMembers:sender];
}

- (void)memberBanFromChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"BAN %@", nickname];

		[u sendCommand:command completeTarget:YES target:c.name];
	}

	[self deselectMembers:sender];
}

- (void)memberKickbanFromChannel:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isChannel == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"KICKBAN %@ %@", nickname, [TPCPreferences defaultKickMessage]];

		[u sendCommand:command completeTarget:YES target:c.name];
	}

	[self deselectMembers:sender];
}

- (void)memberKillFromServer:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"KILL %@ %@", nickname, [TPCPreferences IRCopDefaultKillMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)memberBanFromServer:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		if ([u nicknameIsMyself:nickname]) {
			[u printDebugInformation:TXTLS(@"IRC[0r1-5l]", u.serverAddress) inChannel:c];

			continue;
		}

		NSString *command = [NSString stringWithFormat:@"GLINE %@ %@", nickname, [TPCPreferences IRCopDefaultGlineMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)memberShunOnServer:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	for (NSString *nickname in [self selectedMembersNicknames:sender]) {
		NSString *command = [NSString stringWithFormat:@"SHUN %@ %@", nickname, [TPCPreferences IRCopDefaultShunMessage]];

		[u sendCommand:command];
	}

	[self deselectMembers:sender];
}

- (void)_showSetVhostPromptOpenDialog:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	void (^promptCompletionBlock)(NSString *) = ^(NSString *resultString)
	{
		NSString *vhost = resultString.trimAndGetFirstToken;

		if (vhost.length == 0) {
			return;
		}

		for (NSString *nickname in nicknames) {
			NSString *command = [NSString stringWithFormat:@"hs setall %@ %@", nickname, vhost];

			[u sendCommand:command completeTarget:NO target:nil];
		}
	};

	NSString *vhost = nil;

	TVCAlertResponseButton response =
	[TDCInputPrompt promptWithMessage:TXTLS(@"Prompts[2mx-jf]")
								title:TXTLS(@"Prompts[7gr-e4]")
						defaultButton:TXTLS(@"Prompts[c7s-dq]")
					  alternateButton:TXTLS(@"Prompts[qso-2g]")
						prefillString:nil
						 resultString:&vhost];

	if (response == TVCAlertResponseButtonFirst) {
		promptCompletionBlock(vhost);
	}
}

- (void)showSetVhostPrompt:(id)sender
{
	[self _showSetVhostPromptOpenDialog:sender];
}

#pragma mark -
#pragma mark File Transfers

- (void)showFileTransfersWindow:(id)sender
{
	[self.fileTransferController show:YES restorePosition:YES];
}

- (void)memberSendFileRequest:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO) {
		return;
	}

	NSArray *nicknames = [self selectedMembersNicknames:sender];

	if (nicknames.count == 0) {
		return;
	}

	[self deselectMembers:sender];

	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.allowsMultipleSelection = YES;
	openPanel.canChooseDirectories = NO;
	openPanel.canChooseFiles = YES;
	openPanel.canCreateDirectories = NO;
	openPanel.resolvesAliases = YES;

	[openPanel beginSheetModalForWindow:mainWindow() completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSModalResponseOK) {
			return;
		}

		[self.fileTransferController.fileTransferTable beginUpdates];

		for (NSString *nickname in nicknames) {
			for (NSURL *path in openPanel.URLs) {
				[self.fileTransferController addSenderForClient:u nickname:nickname path:path.path autoOpen:YES];
			}
		}

		[self.fileTransferController.fileTransferTable endUpdates];
	}];
}

- (void)memberSendDroppedFilesToSelectedChannel:(NSArray<NSString *> *)files
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	[self memberSendDroppedFiles:files to:c.name];
}

- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files row:(NSUInteger)row
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil || c == nil || u.isLoggedIn == NO || c.isPrivateMessage == NO) {
		return;
	}

	IRCChannelUser *member = [mainWindowMemberList() itemAtRow:row];

	[self memberSendDroppedFiles:files to:member.user.nickname];
}

- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files to:(NSString *)nickname
{
	NSParameterAssert(files != nil);
	NSParameterAssert(nickname != nil);

	IRCClient *u = self.selectedClient;

	if (u == nil || u.isLoggedIn == NO) {
		return;
	}

	[self.fileTransferController.fileTransferTable beginUpdates];

	for (NSString *file in files) {
		BOOL isDirectory = NO;

		if ([RZFileManager() fileExistsAtPath:file isDirectory:&isDirectory] == NO) {
			continue;
		} else if (isDirectory) {
			continue;
		}

		[self.fileTransferController addSenderForClient:u nickname:nickname path:file autoOpen:YES];
	}

	[self.fileTransferController.fileTransferTable endUpdates];
}

@end

NS_ASSUME_NONNULL_END
