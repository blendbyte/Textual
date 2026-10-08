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

@implementation IRCClient (UserTracking)

#pragma mark -
#pragma mark User Tracking

- (void)clearTrackedUsers
{
	[self.trackedUsers clearTrackedUsers];
}

- (void)statusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus
{
	[self statusOfTrackedNickname:nickname changedTo:newStatus notify:NO];
}

- (void)statusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus notify:(BOOL)notify
{
	NSParameterAssert(nickname != nil);

	[self.trackedUsers statusOfTrackedNickname:nickname changedTo:newStatus];

	if (notify) {
		[self notifyStatusOfTrackedNickname:nickname changedTo:newStatus];
	}
}

- (void)notifyStatusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus
{
	NSParameterAssert(nickname != nil);

	NSString *message = nil;

	if (newStatus == IRCAddressBookUserTrackingStatusSignedOn) {
		message = TXTLS(@"Notifications[xk2-1l]", nickname);
	} else if (newStatus == IRCAddressBookUserTrackingStatusSignedOff) {
		message = TXTLS(@"Notifications[rif-9r]", nickname);
	} else if (newStatus == IRCAddressBookUserTrackingStatusAvailable) {
		message = TXTLS(@"Notifications[97r-0l]", nickname);
	}

	if (message == nil) {
		return;
	}

	[self notifyEvent:TXNotificationTypeAddressBookMatch lineType:TVCLogLineTypeNotice target:nil nickname:nickname text:message];
}

- (void)populateISONTrackedUsersList
{
	if (self.isLoggedIn == NO) {
		return;
	}

	/* Additions & Removals for WATCH command. ISON does not access these. */
	NSMutableArray<NSString *> *watchAdditions = [NSMutableArray array];
	NSMutableArray<NSString *> *watchRemovals = [NSMutableArray array];

	/* Compare configuration to the list of tracked nicknames.
	 * Nicknames that are new are added to watchAdditions */
	NSDictionary *trackedUsersOld = self.trackedUsers.trackedUsers;

	NSMutableArray<NSString *> *trackedUsersNew = [NSMutableArray array];

	for (IRCAddressBookEntry *g in self.config.ignoreList) {
		if (g.trackUserActivity == NO) {
			continue;
		}

		NSString *trackingNickname = g.trackingNickname;

		IRCAddressBookUserTrackingStatus trackingStatus = [self.trackedUsers statusOfUser:trackingNickname];

		if (trackingStatus != IRCAddressBookUserTrackingStatusUnknown) {
			[trackedUsersNew addObject:trackingNickname];

			continue;
		}

		[watchAdditions addObject:trackingNickname];

		[self.trackedUsers _addTrackedUser:trackingNickname];
	}

	/* Compare old list of tracked nicknames to new list to find
	 those that no longer appear. Mark those for removal. */
	for (NSString *trackedUser in trackedUsersOld) {
		if ([trackedUsersNew containsObjectIgnoringCase:trackedUser]) {
			continue;
		}

		[watchRemovals addObject:trackedUser];

		[self.trackedUsers _removeTrackedUser:trackedUser];
	}

	/* Set new entries */
	[self modifyWatchListBy:YES nicknames:watchAdditions];

	[self modifyWatchListBy:NO nicknames:watchRemovals];

	[self startISONTimer];
}

- (void)startISONTimer
{
	if (self.isonTimer.timerIsActive) {
		return;
	}

	[self.isonTimer start:_isonCheckInterval onRepeat:YES];

	[self startWhoTimer];
}

- (void)stopISONTimer
{
	if (self.isonTimer.timerIsActive == NO) {
		return;
	}

	[self.isonTimer stop];

	[self stopWhoTimer];
}

- (void)onISONTimer
{
	if (self.isLoggedIn == NO || self.isBrokenIRCd_aka_Twitch) {
		return;
	}

	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];

	// Request ISON status for tracked users
	if (self.supportsAdvancedTracking == NO) {
		for (NSString *trackedUser in self.trackedUsers.trackedUsers) {
			[nicknames addObject:trackedUser];
		}
	}

	// Request ISON status for private messages
	for (IRCChannel *channel in self.channelList) {
		if (channel.privateMessage) {
			[nicknames addObject:channel.name];
		}
	}

	[self sendIsonForNicknames:nicknames hideResponse:YES];
}

- (void)startWhoTimer
{
	if (self.whoTimer.timerIsActive) {
		return;
	}

	[self.whoTimer start:_whoCheckInterval onRepeat:YES];
}

- (void)stopWhoTimer
{
	if (self.whoTimer.timerIsActive == NO) {
		return;
	}

	[self.whoTimer stop];
}

- (void)onWhoTimer
{
	if (self.isLoggedIn == NO || self.isBrokenIRCd_aka_Twitch) {
		return;
	}

	NSArray *channelList = self.channelList;

	[self sendTimedWhoRequestsToChannels:channelList];
}

- (void)sendTimedWhoRequestsToChannels:(NSArray<IRCChannel *> *)channelList
{
	NSParameterAssert(channelList != nil);

	if (self.isLoggedIn == NO || self.isBrokenIRCd_aka_Twitch) {
		return;
	}

#define _maximumChannelCountPerWhoBatchRequest			4
#define _maximumSingleChannelSizePerWhoBatchRequest		5000
#define _maximumTotalChannelSizePerWhoBatchRequest		2000

	NSUInteger channelCount = channelList.count;

	if (channelCount == 0) {
		return;
	}

	/* Wrap around before working out the end of the batch: computed from
	 a position past the end, the batch covered every channel (R3.14) */
	NSUInteger startingPosition = self.lastWhoRequestChannelListIndex;

	if (startingPosition >= channelCount) {
		startingPosition = 0;
	}

	NSUInteger endingPosition = (startingPosition + _maximumChannelCountPerWhoBatchRequest - 1);

	if (endingPosition >= channelCount) {
		endingPosition = (channelCount - 1);
	}

	NSUInteger totalMemberCount = 0;

	NSMutableArray<IRCChannel *> *channelsToQuery = nil;

	for (NSUInteger channelIndex = startingPosition; channelIndex <= endingPosition; channelIndex++) {
		IRCChannel *channel = channelList[channelIndex];

		if (channel.isActive == NO || channel.isChannel == NO) {
			continue;
		}

		/* Update internal state of flag */
		BOOL sentInitialWhoRequest = channel.sentInitialWhoRequest;

		if (sentInitialWhoRequest == NO) {
			channel.sentInitialWhoRequest = YES;
		}

		/* continue to next channel and do not break so that the
		 -sentInitialWhoRequest flag of all channels can be updated. */
		if (self.config.sendWhoCommandRequestsToChannels == NO) {
			continue;
		}

		/* Perform comparisons to know whether channel is acceptable */
		NSUInteger numberOfMembers = channel.numberOfMembers;

		if (sentInitialWhoRequest == NO) {
			if (numberOfMembers > _maximumSingleChannelSizePerWhoBatchRequest) {
				continue;
			}
		} else {
			if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityAwayNotify]) {
				continue;
			}

			if (numberOfMembers > [TPCPreferences trackUserAwayStatusMaximumChannelSize]) {
				continue;
			}
		}

		/* Add channel to list */
		if (channelsToQuery == nil) {
			channelsToQuery = [NSMutableArray new];
		}

		[channelsToQuery addObject:channel];

		/* Update total number of members and maybe break loop */
		totalMemberCount += numberOfMembers;

		if (totalMemberCount > _maximumTotalChannelSizePerWhoBatchRequest) {
			endingPosition = channelIndex;

			break;
		}
	}

	self.lastWhoRequestChannelListIndex = (endingPosition + 1);

	/* Send WHO requests */
	if (channelsToQuery == nil) {
		return;
	}

	for (IRCChannel *channel in channelsToQuery) {
		[self sendWhoToChannel:channel hideResponse:YES];
	}

#undef _maximumChannelCountPerWhoBatchRequest
#undef _maximumSingleChannelSizePerWhoBatchRequest
#undef _maximumTotalChannelSizePerWhoBatchRequest
}

- (void)updateUserTrackingStatusForEntry:(IRCAddressBookEntry *)addressBookEntry withMessage:(IRCMessage *)message
{
	[self updateUserTrackingStatusForEntry:addressBookEntry nickname:message.senderNickname withMessage:message];
}

/* nickname is the user the entry matched: the sender, or for NICK the old
 or the new nickname */
- (void)updateUserTrackingStatusForEntry:(IRCAddressBookEntry *)addressBookEntry nickname:(NSString *)nickname withMessage:(IRCMessage *)message
{
	NSParameterAssert(addressBookEntry != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(message != nil);

	if (self.supportsAdvancedTracking) {
		return;
	}

	IRCAddressBookUserTrackingStatus trackingStatus = [self.trackedUsers statusOfEntry:addressBookEntry];

	if (trackingStatus == IRCAddressBookUserTrackingStatusUnknown) {
		return;
	}

	BOOL ison = (trackingStatus == IRCAddressBookUserTrackingStatusAvailable);

	/* Notification Type: JOIN Command */
	if ([message.command isEqualToStringIgnoringCase:@"JOIN"]) {
		if (ison == NO) {
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];
		}

		return;
	}

	/* Notification Type: QUIT Command */
	if ([message.command isEqualToStringIgnoringCase:@"QUIT"]) {
		if (ison) {
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];
		}

		return;
	}

	/* Notification Type: NICK Command: the old nickname is gone,
	 the new one has arrived (R3.3: the new one was reported as the old) */
	if ([message.command isEqualToStringIgnoringCase:@"NICK"]) {
		BOOL isOldNickname = [nickname isEqualToStringIgnoringCase:message.senderNickname];

		if (isOldNickname && ison) {
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];
		} else if (isOldNickname == NO && ison == NO) {
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];
		}

		return;
	}
}

@end

NS_ASSUME_NONNULL_END
