/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *      Please see Acknowledgements.pdf for additional information.
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

#import <objc/message.h>
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocol.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOpenLink.h"
#import "TLOSoundPlayer.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TLOSpokenNotificationPrivate.h"
#import "TLOTimer.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelBanListSheetPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "IRC.h"
#import "IRCAddressBook.h"
#import "IRCAddressBookMatchCachePrivate.h"
#import "IRCAddressBookUserTrackingPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannelModePrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientRequestedCommandsPrivate.h"
#import "IRCColorFormatPrivate.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCExtrasPrivate.h"
#import "IRCHighlightLogEntryPrivate.h"
#import "IRCHighlightMatchCondition.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCModeInfo.h"
#import "IRCPrefix.h"
#import "IRCNumerics.h"
#import "IRCSendingMessage.h"
#import "IRCServerPrivate.h"
#import "IRCTimedCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Dialogs)

#pragma mark -
#pragma mark Channel Ban List Dialog

- (void)createChannelInviteExceptionListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeInviteException];
}

- (void)createChannelBanExceptionListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeBanException];
}

- (void)createChannelBanListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeBan];
}

- (void)createChannelQuietListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeQuiet];
}

- (void)createChannelBanListSheet:(TDCChannelBanListSheetEntryType)entryType
{
	[windowController() popMainWindowSheetIfExists];

	IRCChannel *c = mainWindow().selectedChannel;

	if (c == nil) {
		return;
	}

	TDCChannelBanListSheet *listSheet = [[TDCChannelBanListSheet alloc] initWithEntryType:entryType inChannel:c];

	if (listSheet == nil) {
		return;
	}

	listSheet.delegate = (id)self;

	listSheet.window = mainWindow();

	[listSheet start];

	[windowController() addWindowToWindowList:listSheet];
}

- (void)channelBanListSheetOnUpdate:(TDCChannelBanListSheet *)sender
{
	IRCChannel *channel = sender.channel;

	if (channel == nil) {
		return;
	}

	NSString *modeSend = [NSString stringWithFormat:@"+%@", sender.modeSymbol];

	[self sendModes:modeSend withParametersString:nil inChannel:channel];
}

- (void)channelBanListSheetWillClose:(TDCChannelBanListSheet *)sender
{
	IRCChannel *channel = sender.channel;

	if (channel == nil) {
		return;
	}

	NSArray *listOfChanges = sender.listOfChanges;

	for (NSString *change in listOfChanges) {
		[self sendModes:change withParametersString:nil inChannel:channel];
	}

	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Network Channel List Dialog

- (NSString *)channelListDialogWindowKey
{
	return [NSString stringWithFormat:@"TDCServerChannelListDialog -> %@", self.uniqueIdentifier];
}

- (nullable TDCServerChannelListDialog *)channelListDialog
{
	return [windowController() windowFromWindowList:[self channelListDialogWindowKey]];
}

- (void)createChannelListDialog
{
	if ([windowController() maybeBringWindowForward:[self channelListDialogWindowKey]]) {
		return; // The window was brought forward already.
	}

	TDCServerChannelListDialog *channelListDialog = [[TDCServerChannelListDialog alloc] initWithClient:self];

	channelListDialog.delegate = (id)self;

	[channelListDialog show];

	[windowController() addWindowToWindowList:channelListDialog withDescription:[self channelListDialogWindowKey]];
}

- (void)serverChannelListDialogOnUpdate:(TDCServerChannelListDialog *)sender
{
	[self requestChannelList];
}

- (void)serverChannelListDialog:(TDCServerChannelListDialog *)sender joinChannels:(NSArray<NSString *> *)channels
{
	[self joinUnlistedChannelsAndSelectBestMatch:channels];
}

- (void)serverChannelDialogWillClose:(TDCServerChannelListDialog *)sender
{
	[windowController() removeWindowFromWindowList:[self channelListDialogWindowKey]];
}

@end

NS_ASSUME_NONNULL_END
