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
#import "IRCTimerCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (ZNC)

#pragma mark -
#pragma mark Playback

- (void)playbackClearChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback] == NO) {
		return;
	}

	if (channel.isPrivateMessage == NO || channel.isPrivateMessageForZNCUser) {
		return;
	}

	NSString *command = [NSString stringWithFormat:@"clear %@", channel.name];

	if (self.isConnectedToZNC) {
		[self sendCommand:command toZNCModuleNamed:@"playback"];

		return;
	}

	[self send:@"PRIVMSG", @"*playback", command, nil];
}

- (void)requestPlayback
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback] == NO) {
		return;
	}

	/* For our first connect, only playback using timestamp if logging was enabled. */
	/* For all other connects, then playback timestamp regardless of logging. */
	NSString *command = nil;

	if ((self.successfulConnects > 1 || (self.successfulConnects == 1 && self.config.zncOnlyPlaybackLatest)) && self.lastMessageServerTime > 0) {
		command = [NSString stringWithFormat:@"play * %.0f", self.lastMessageServerTime];
	} else {
		command = @"play * 0";
	}

	if (self.isConnectedToZNC) {
		[self sendCommand:command toZNCModuleNamed:@"playback"];

		return;
	}

	[self send:@"PRIVMSG", @"*playback", command, nil];
}

#pragma mark -
#pragma mark ZNC Bouncer Accessories

- (void)zncPlaybackClearChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (self.isConnectedToZNC == NO) {
		return;
	}

	[self playbackClearChannel:channel];
}

- (BOOL)nicknameIsZNCUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self.isConnectedToZNC == NO) {
		return NO;
	}

	return [nickname hasPrefix:@"*"];
}

- (BOOL)nickname:(NSString *)nickname isZNCUser:(NSString *)zncNickname
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(zncNickname != nil);
	
	return [nickname isEqualToString:[self nicknameAsZNCUser:zncNickname]];
}

- (nullable NSString *)nicknameAsZNCUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self.isConnectedToZNC == NO) {
		return nil;
	}

	return [@"*" stringByAppendingString:nickname];
}

- (BOOL)isSafeToPostNotificationForMessage:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(message != nil);

	if (self.isConnectedToZNC == NO) {
		return YES;
	}

	if (self.config.zncIgnoreUserNotifications) {
		if (channel && [self nicknameIsZNCUser:channel.name]) {
			return NO;
		}
	}

	if (self.config.zncIgnorePlaybackNotifications == NO) {
		return YES;
	}

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBatch]) {
		NSString *batchType = message.parentBatchMessage.batchType;

		return ([batchType isEqualToString:@"znc.in/playback"] == NO);
	}

	return (message.isHistoric == NO);
}

- (void)updateConnectedToZNCPropertyWithMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	if (self.isConnectedToZNC) {
		return;
	}

	if (message.senderIsServer == NO) {
		return;
	}

	if ([message.senderNickname isEqualToString:@"irc.znc.in"]) {
		self.isConnectedToZNC = YES;

		LogToConsole("ZNC detected...");
	}
}

- (void)sendCommand:(NSString *)command toZNCModuleNamed:(NSString *)module
{
	NSParameterAssert(command != nil);
	NSParameterAssert(module != nil);

	NSString *destination = [self nicknameAsZNCUser:module];

	if (destination == nil) {
		return;
	}

	NSString *stringToSend = [NSString stringWithFormat:@"ZNC %@ %@", destination, command];

	[self sendLine:stringToSend];
}

@end

NS_ASSUME_NONNULL_END
