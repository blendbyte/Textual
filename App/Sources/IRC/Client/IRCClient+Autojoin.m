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

@implementation IRCClient (Autojoin)

#pragma mark -
#pragma mark Autojoin

- (void)startAutojoinTimer
{
	if (self.autojoinTimer.timerIsActive) {
		return;
	}

	NSTimeInterval interval = [TPCPreferences autojoinDelayAfterIdentification];

	if (CGFloatAreEqual(interval, 0.0)) {
		[self onAutojoinTimer];

		return;
	}

	[self.autojoinTimer start:interval onRepeat:NO];
}

- (void)stopAutojoinTimer
{
	if (self.autojoinTimer.timerIsActive == NO) {
		return;
	}

	[self.autojoinTimer stop];
}

- (void)onAutojoinTimer
{
	[self startAutojoinNextJoinTimer];
}

- (void)startAutojoinDelayedWarningTimer
{
	if (self.autojoinDelayedWarningTimer.timerIsActive) {
		return;
	}

	[self.autojoinDelayedWarningTimer start:_autojoinDelayedWarningInterval onRepeat:YES];
}

- (void)stopAutojoinDelayedWarningTimer
{
	if (self.autojoinDelayedWarningTimer.timerIsActive == NO) {
		return;
	}

	[self.autojoinDelayedWarningTimer stop];
}

- (void)onAutojoinDelayedWarningTimer
{
	if (self.isLoggedIn == NO ||
		self.config.hideAutojoinDelayedWarnings ||
		self.autojoinDelayedWarningCount >= _autojoinDelayedWarningMaxCount)
	{
		[self stopAutojoinDelayedWarningTimer];

		return;
	}

	self.autojoinDelayedWarningCount += 1;

	/* This message is posted to the server console and the 
	 front most channel if it is on this server. */
	NSString *text = TXTLS(@"IRC[r5h-fj]");

	[self printDebugInformationToConsole:text];

	IRCChannel *c = [mainWindow() selectedChannelOn:self];

	if (c != nil) {
		[self printDebugInformation:text inChannel:c];
	}
}

- (void)startAutojoinNextJoinTimer
{
	if (self.autojoinNextJoinTimer.timerIsActive) {
		return;
	}

	NSTimeInterval interval = [TPCPreferences autojoinDelayBetweenChannelJoins];

	[self.autojoinNextJoinTimer start:interval onRepeat:YES];

	/* Fake first event */
	[self onAutojoinNextJoinTimer];
}

- (void)stopAutojoinNextJoinTimer
{
	if (self.autojoinNextJoinTimer.timerIsActive == NO) {
		return;
	}

	[self.autojoinNextJoinTimer stop];

	self.channelsToAutojoin = nil;
}

- (void)onAutojoinNextJoinTimer
{
	[self autojoinNextChannel];
}

- (void)autojoinNextChannel
{
	if (self.isAutojoining == NO) {
		return;
	}

	@synchronized (self.channelsToAutojoin) {
		NSUInteger numberOfChannelsRemaining = self.channelsToAutojoin.count;

		NSUInteger maximumNumberOfJoins = [TPCPreferences autojoinMaximumChannelJoins];

		NSRange arrayRange;

		BOOL endOfArray = (numberOfChannelsRemaining <= maximumNumberOfJoins);

		if (endOfArray == NO) {
			arrayRange = NSMakeRange(0, maximumNumberOfJoins);
		} else {
			arrayRange = NSMakeRange(0, numberOfChannelsRemaining);
		}

		NSArray *channelsToJoin = [self.channelsToAutojoin subarrayWithRange:arrayRange];

		[self autojoinChannels:channelsToJoin];

		if (endOfArray == NO) {
			[self.channelsToAutojoin removeObjectsInRange:arrayRange];
		} else {
			self.isAutojoining = NO;

			self.isAutojoined = YES;

			[self stopAutojoinNextJoinTimer];
		}
	}
}

- (void)autojoinChannels:(NSArray<IRCChannel *> *)channels
{
	NSParameterAssert(channels != nil);

	[self joinChannels:channels];
}

- (void)performAutoJoin
{
	[self performAutoJoinInitiatedByUser:NO];
}

- (void)performAutoJoinInitiatedByUser:(BOOL)initiatedByUser
{
	if (self.isAutojoining) {
		return;
	}

	[self stopAutojoinDelayedWarningTimer];

	if (initiatedByUser == NO) {
		/* Ignore previous invocations of this method */
		if (self.isAutojoined) {
			return;
		}

		/* Ignore autojoin based on ZNC preferences */
		if (self.isConnectedToZNC && self.config.zncIgnoreConfiguredAutojoin) {
			self.isAutojoined = YES;

			return;
		}

		/* Do nothing unless certain conditions are met */
		if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL] == NO) {
			if (self.config.autojoinWaitsForNickServ) {
				if (self.serverHasNickServ && self.userIsIdentifiedWithNickServ == NO) {
					return;
				}
			}
		}
	}

	NSMutableArray<IRCChannel *> *channelsToAutojoin = [NSMutableArray array];

	for (IRCChannel *c in self.channelList) {
		if (c.isChannel && c.isActive == NO) {
			if (c.config.autoJoin) {
				[channelsToAutojoin addObject:c];
			}
		}
	}

	if (channelsToAutojoin.count == 0) {
		self.isAutojoining = YES;

		return;
	}

	self.isAutojoining = YES;

	@synchronized (self.channelsToAutojoin) {
		[channelsToAutojoin shuffle];

		self.channelsToAutojoin = channelsToAutojoin;
	}

	[self startAutojoinTimer];
}

#pragma mark -
#pragma mark Timers

- (void)startPongTimer
{
	if (self.pongTimer.timerIsActive) {
		return;
	}

	[self.pongTimer start:_pongCheckInterval onRepeat:YES];
}

- (void)stopPongTimer
{
	if (self.pongTimer.timerIsActive == NO) {
		return;
	}

	[self.pongTimer stop];
}

- (void)onPongTimer
{
	if (self.isLoggedIn == NO) {
		[self stopPongTimer];

		return;
	}

	/* Instead of stopping and starting the timer every time this changes, it
	 it is easier to check if we should do it every timer iteration.
	 The ability to disable this is important on PSYBNC connection because
	 PSYBNC doesn't respond to PING commands. There are other irc daemons that
	 don't reply to PING either and they should all be shot. */
	NSTimeInterval timeSpent = [NSDate timeIntervalSinceNow:self.lastMessageReceived];

	if (timeSpent >= _timeoutInterval)
	{
		/* If EOF Received when we were not expecting it, then timeout regardless
		 of user preference once our timeout interval is reached. */
		if (self.socket.EOFReceived || self.config.performDisconnectOnPongTimer) {
			[self printDebugInformation:TXTLS(@"IRC[bps-la]", (timeSpent / 60.0)) inChannel:nil];

			XRPerformBlockSynchronouslyOnMainQueue(^{
				[self disconnect];
			});

			return;
		}

		if (self.timeoutWarningShownToUser == NO) {
			self.timeoutWarningShownToUser = YES;

			[self printDebugInformation:TXTLS(@"IRC[gzo-54]", (timeSpent / 60.0)) inChannel:nil];
		}
	}
	else if (timeSpent >= _pingInterval)
	{
		if (self.config.performPongTimer == NO) {
			return;
		}

		[self sendPing:self.serverAddress];
	}
}

- (void)startReconnectTimer
{
	if ((self.reconnectEnabledBecauseOfSleepMode		&& self.config.autoSleepModeDisconnect == NO) ||
		(self.reconnectEnabledBecauseOfSleepMode == NO  && self.config.autoReconnect == NO))
	{
		return;
	}

	if (self.reconnectTimer.timerIsActive) {
		return;
	}

	[self.reconnectTimer start:_reconnectInterval onRepeat:YES];
}

- (void)stopReconnectTimer
{
	if (self.reconnectTimer.timerIsActive == NO) {
		return;
	}

	[self.reconnectTimer stop];
}

- (void)onReconnectTimer
{
	if (self.isConnecting || self.isConnected) {
		return;
	}

	[self connect:IRCClientConnectModeReconnect];
}

- (void)startRetryTimer
{
	if (self.retryTimer.timerIsActive) {
		return;
	}

	[self.retryTimer start:_retryInterval];
}

- (void)stopRetryTimer
{
	if (self.retryTimer.timerIsActive == NO) {
		return;
	}

	[self.retryTimer stop];
}

- (void)onRetryTimer
{
	if (self.isConnected == NO) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCClient *weakSelf = self;

		self.disconnectCallback = ^{
			[weakSelf connect:IRCClientConnectModeRetry];
		};

		[self disconnect];
	});
}

@end

NS_ASSUME_NONNULL_END
