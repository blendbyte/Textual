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

@implementation IRCClient (Notifications)

#pragma mark -
#pragma mark Notifications

- (nullable NSString *)formatNotificationToSpeak:(TLOSpokenNotification *)notification
{
	NSParameterAssert(notification != nil);

	if (self.isTerminating) {
		return nil;
	}

	NSString *formattedMessage = nil;

	TXNotificationType eventType = notification.notificationType;

	IRCChannel *channel = notification.channel;

	NSString *nickname = notification.nickname;

	NSString *text = notification.text;

	if (text) {
		text = text.trim;

		if ([TPCPreferences removeAllFormatting] == NO) {
			text = text.stripIRCEffects;
		}
	}

	switch (eventType) {
		case TXNotificationTypeHighlight:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (text.length == 0) {
				break;
			}

			/* Highlights are spoken regardless of whether the user has configured
			 Channel Messages to be only spoken for selection. When the user has 
			 configured that preference, then we exclude the channel name at least
			 because that information is uninteresting. */
			/* For private messages, we speak everything, regardless of any preference. */
			BOOL isChannel = channel.isChannel;

			BOOL onlySpeakEventsForSelection = [TPCPreferences onlySpeakEventsForSelection];

			BOOL speakChannelName =
			/* 1 */	(isChannel == NO ||
			/* 2 */ (onlySpeakEventsForSelection == NO &&
					 [TPCPreferences channelMessageSpeakChannelName]) ||
			/* 2 */	(onlySpeakEventsForSelection &&
					 [mainWindow() isItemSelected:channel] == NO));

			BOOL speakNickname = (isChannel == NO ||
					[TPCPreferences channelMessageSpeakNickname]);

			NSMutableString *mutableMessage = [NSMutableString string];

			[mutableMessage appendString:TXTLS(@"Notifications[qld-sa]")];

			if (speakChannelName || speakNickname) {
				if (speakChannelName) {
					if (isChannel) {
						[mutableMessage appendString:TXTLS(@"Notifications[ke8-17]", channel.name.channelNameWithoutBang)]; // Channel
					} else {
						[mutableMessage appendString:TXTLS(@"Notifications[6nw-ec]")]; // Private Message
					}
				}

				if (speakNickname) {
					if (isChannel) {
						[mutableMessage appendString:TXTLS(@"Notifications[qy9-86]", nickname)]; // by <nickname>
					} else {
						[mutableMessage appendString:TXTLS(@"Notifications[a7i-pu]", nickname)]; // from <nickname>
					}
				}

				[mutableMessage appendString:TXTLS(@"Notifications[g9t-bt]")];
			}

			[mutableMessage appendString:text];

			formattedMessage = [mutableMessage copy];

			break;
		}
		case TXNotificationTypeChannelMessage:
		case TXNotificationTypeChannelNotice:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (text.length == 0) {
				break;
			}

			BOOL onlySpeakEventsForSelection = [TPCPreferences onlySpeakEventsForSelection];

			BOOL channelIsSelected = [mainWindow() isItemSelected:channel];

			if (onlySpeakEventsForSelection && channelIsSelected == NO) {
				break;
			}

			BOOL speakChannelName = (onlySpeakEventsForSelection == NO &&
									 [TPCPreferences channelMessageSpeakChannelName]);

			BOOL speakNickname = [TPCPreferences channelMessageSpeakNickname];

			NSMutableString *mutableMessage = [NSMutableString string];

			if (speakChannelName || speakNickname) {
				if (eventType == TXNotificationTypeChannelMessage) {
					[mutableMessage appendString:TXTLS(@"Notifications[tao-i2]")];
				} else if (eventType == TXNotificationTypeChannelNotice) {
					[mutableMessage appendString:TXTLS(@"Notifications[kk4-68]")];
				}

				if (speakChannelName) {
					[mutableMessage appendString:TXTLS(@"Notifications[ke8-17]", channel.name.channelNameWithoutBang)];
				}

				if (speakNickname) {
					[mutableMessage appendString:TXTLS(@"Notifications[qy9-86]", nickname)];
				}

				[mutableMessage appendString:TXTLS(@"Notifications[g9t-bt]")];
			}

			[mutableMessage appendString:text];

			formattedMessage = [mutableMessage copy];

			break;
		}
		case TXNotificationTypeNewPrivateMessage:
		case TXNotificationTypePrivateMessage:
		case TXNotificationTypePrivateNotice:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (text.length == 0) {
				break;
			}

			NSString *formatter = nil;

			if (eventType == TXNotificationTypeNewPrivateMessage) {
				formatter = @"Notifications[rvb-9l]";
			} else if (eventType == TXNotificationTypePrivateMessage) {
				formatter = @"Notifications[2bu-ep]";
			} else if (eventType == TXNotificationTypePrivateNotice) {
				formatter = @"Notifications[6jl-vh]";
			}

			formattedMessage = TXTLS(formatter, nickname, text);

			break;
		}
		case TXNotificationTypeKick:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);

			NSString *formatter = @"Notifications[5yu-bf]";

			formattedMessage = TXTLS(formatter, channel.name.channelNameWithoutBang, nickname);

			break;
		}
		case TXNotificationTypeInvite:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			NSString *formatter = @"Notifications[l5i-at]";

			formattedMessage = TXTLS(formatter, text.channelNameWithoutBang, nickname);

			break;
		}
		case TXNotificationTypeConnect:
		case TXNotificationTypeDisconnect:
		{
			NSString *formatter = nil;

			if (eventType == TXNotificationTypeConnect) {
				formatter = @"Notifications[z4p-yr]";
			} else if (eventType == TXNotificationTypeDisconnect) {
				formatter = @"Notifications[fd0-f8]";
			}

			formattedMessage = TXTLS(formatter, self.networkNameAlt);

			break;
		}
		case TXNotificationTypeAddressBookMatch:
		{
			NSParameterAssert(text != nil);

			formattedMessage = text;

			break;
		}
		case TXNotificationTypeFileTransferSendSuccessful:
		case TXNotificationTypeFileTransferReceiveSuccessful:
		case TXNotificationTypeFileTransferSendFailed:
		case TXNotificationTypeFileTransferReceiveFailed:
		case TXNotificationTypeFileTransferReceiveRequested:
		{
			NSParameterAssert(nickname != nil);

			NSString *formatter = nil;

			if (eventType == TXNotificationTypeFileTransferSendSuccessful) {
				formatter = @"Notifications[5e4-vg]";
			} else if (eventType == TXNotificationTypeFileTransferReceiveSuccessful) {
				formatter = @"Notifications[4cd-p3]";
			} else if (eventType == TXNotificationTypeFileTransferSendFailed) {
				formatter = @"Notifications[f0u-32]";
			} else if (eventType == TXNotificationTypeFileTransferReceiveFailed) {
				formatter = @"Notifications[mak-bj]";
			} else if (eventType == TXNotificationTypeFileTransferReceiveRequested) {
				formatter = @"Notifications[at0-vi]";
			}

			formattedMessage = TXTLS(formatter, nickname);

			break;
		}
		case TXNotificationTypeUserJoined:
		case TXNotificationTypeUserParted:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);

			NSString *formatter = nil;

			if (eventType == TXNotificationTypeUserJoined) {
				formatter = @"Notifications[bwu-ps]";
			} else if (eventType == TXNotificationTypeUserParted) {
				formatter = @"Notifications[4aq-hz]";
			}

			formattedMessage = TXTLS(formatter, nickname, channel.name.channelNameWithoutBang);

			break;
		}
		case TXNotificationTypeUserDisconnected:
		{
			NSParameterAssert(nickname != nil);

			NSString *formatter = @"Notifications[sqf-4y]";

			formattedMessage = TXTLS(formatter, nickname);

			break;
		}
	}

	return formattedMessage;
}

- (void)clearEventsToSpeak
{
	[[TXSharedApplication sharedSpeechSynthesizer] clearQueueForClient:self];
}

- (void)speakEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCTreeItem *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text
{
	if ([sharedNotificationController() speakEvent:eventType inChannel:(IRCChannel *)target] == NO) {
		return;
	}

	if (target == nil) {
		target = self;
	}

	TLOSpokenNotification *notification =
	[[TLOSpokenNotification alloc] initWithNotification:eventType
											   lineType:lineType
												 target:target
											   nickname:nickname
												   text:text];

	[[TXSharedApplication sharedSpeechSynthesizer] speak:notification];
}

- (BOOL)notifyText:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(IRCChannel *)target nickname:(NSString *)nickname text:(NSString *)text
{
	return [self notifyEvent:eventType lineType:lineType target:target nickname:nickname text:text userInfo:nil];
}

- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType
{
	return [self notifyEvent:eventType lineType:lineType target:nil nickname:nil text:nil userInfo:nil];
}

- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCChannel *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text
{
	return [self notifyEvent:eventType lineType:lineType target:target nickname:nickname text:text userInfo:nil];
}

- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCChannel *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
{
	if (self.isTerminating) {
		return NO;
	}

	BOOL isTextEvent =
	(eventType == TXNotificationTypeHighlight			||
	 eventType == TXNotificationTypeNewPrivateMessage	||
	 eventType == TXNotificationTypeChannelMessage		||
	 eventType == TXNotificationTypeChannelNotice		||
	 eventType == TXNotificationTypePrivateMessage		||
	 eventType == TXNotificationTypePrivateNotice);

	if (isTextEvent) {
		if ([self nicknameIsMyself:nickname]) {
			return NO;
		}
	}

	if (target && text != nil) {
		if ([self outputRuleMatchedInMessage:text inChannel:target]) {
			return NO;
		}
	}

	IRCChannelConfig *targetConfig = nil;

	if (target) {
		targetConfig = target.config;

		if (eventType == TXNotificationTypeHighlight) {
			if (targetConfig.ignoreHighlights) {
				return YES;
			}
		} else {
			if (targetConfig.pushNotifications == NO) {
				return YES;
			}
		}
	}

	if ([sharedNotificationController() bounceDockIconForEvent:eventType inChannel:target]) {
		if ([sharedNotificationController() bounceDockIconRepeatedlyForEvent:eventType inChannel:target]) {
			[NSApp requestUserAttention:NSCriticalRequest];
		} else {
			[NSApp requestUserAttention:NSInformationalRequest];
		}
	}

	if (sharedNotificationController().areNotificationsDisabled) {
		return YES;
	}

	BOOL mainWindowIsFocused = (mainWindow().inactive == NO);

	BOOL postNotificationsWhileFocused = [TPCPreferences postNotificationsWhileInFocus];

	BOOL targetIsSelected = [mainWindow() isItemSelected:target];

	BOOL onlySpeakEvent = (postNotificationsWhileFocused && mainWindowIsFocused && targetIsSelected);

	if ([TPCPreferences soundIsMuted] == NO) {
		if (onlySpeakEvent == NO) {
			NSString *soundName = [sharedNotificationController() soundForEvent:eventType inChannel:target];

			if (soundName) {
				[TLOSoundPlayer playAlertSound:soundName];
			}
		}

		[self speakEvent:eventType lineType:lineType target:target nickname:nickname text:text];
	}

	if (onlySpeakEvent) {
		return YES;
	}

	if ([sharedNotificationController() notificationEnabledForEvent:eventType inChannel:target] == NO) {
		return YES;
	}

	if (postNotificationsWhileFocused == NO && mainWindowIsFocused) {
		if (eventType != TXNotificationTypeAddressBookMatch) {
			return YES;
		}
	}

	if ([sharedNotificationController() disabledWhileAwayForEvent:eventType inChannel:target]) {
		if (self.userIsAway) {
			return YES;
		}
	}

	NSString *eventTitle = nil;

	NSString *eventDescription = nil;

	if (userInfo == nil) {
		if (target) {
			userInfo = @{TXNotificationUserInfoClientIdentifierKey : self.uniqueIdentifier,
						 TXNotificationUserInfoChannelIdentifierKey: target.uniqueIdentifier};
		} else {
			userInfo = @{TXNotificationUserInfoClientIdentifierKey : self.uniqueIdentifier};
		}
	}

	switch (eventType) {
		case TXNotificationTypeHighlight:
		case TXNotificationTypeNewPrivateMessage:
		case TXNotificationTypeChannelMessage:
		case TXNotificationTypeChannelNotice:
		case TXNotificationTypePrivateMessage:
		case TXNotificationTypePrivateNotice:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (eventType == TXNotificationTypeHighlight ||
				eventType == TXNotificationTypeChannelMessage ||
				eventType == TXNotificationTypeChannelNotice)
			{
				NSParameterAssert(target != nil);

				eventTitle = target.name;
			}

			if (lineType == TVCLogLineTypeAction || lineType == TVCLogLineTypeActionNoHighlight) {
				eventDescription = [NSString stringWithFormat:TXNotificationDialogActionNicknameFormat, nickname, text];
			} else {
				nickname = [self formatNickname:nickname inChannel:target];

				eventDescription = [NSString stringWithFormat:TXNotificationDialogStandardNicknameFormat, nickname, text];
			}

			break;
		}
		case TXNotificationTypeFileTransferSendSuccessful:
		case TXNotificationTypeFileTransferReceiveSuccessful:
		case TXNotificationTypeFileTransferSendFailed:
		case TXNotificationTypeFileTransferReceiveFailed:
		case TXNotificationTypeFileTransferReceiveRequested:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = nickname;

			eventDescription = text;

			break;
		}
		case TXNotificationTypeConnect:
		{
			eventTitle = self.networkNameAlt;

			break;
		}
		case TXNotificationTypeDisconnect:
		{
			eventTitle = self.networkNameAlt;

			break;
		}
		case TXNotificationTypeAddressBookMatch:
		{
			NSParameterAssert(text != nil);

			eventDescription = text;

			break;
		}
		case TXNotificationTypeKick:
		{
			NSParameterAssert(target != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			eventDescription = TXTLS(@"Notifications[fkt-p3]", nickname, target.name, text);

			break;
		}
		case TXNotificationTypeInvite:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			eventDescription = TXTLS(@"Notifications[xl5-dn]", nickname, text);

			break;
		}
		case TXNotificationTypeUserJoined:
		{
			NSParameterAssert(target != nil);
			NSParameterAssert(nickname != nil);

			eventTitle = self.networkNameAlt;

			eventDescription = TXTLS(@"Notifications[yas-us]", nickname, target.name);

			break;
		}
		case TXNotificationTypeUserParted:
		{
			NSParameterAssert(target != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			if (text == nil || text.length == 0) {
				eventDescription = TXTLS(@"Notifications[bu2-9m]", nickname, target.name);
			} else {
				eventDescription = TXTLS(@"Notifications[3ur-i8]", nickname, target.name, text);
			}

			break;
		}
		case TXNotificationTypeUserDisconnected:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			if (text == nil || text.length == 0) {
				eventDescription = TXTLS(@"Notifications[7ao-n8]", nickname);
			} else {
				eventDescription = TXTLS(@"Notifications[ssw-m6]", nickname, text);
			}

			break;
		}
		default:
		{
			return YES;
		}
	}

	[sharedNotificationController() notify:eventType title:eventTitle description:eventDescription userInfo:userInfo];

	return YES;
}

#pragma mark -
#pragma mark Post Events

- (void)postEventToViewController:(NSString *)eventToken
{
	if (themeSettings().js_postHandleEventNotifications == NO) {
		return; // Cancel operation...
	}

	[self postEventToViewController:eventToken forItem:self];

	for (IRCChannel *channel in self.channelList) {
		[self postEventToViewController:eventToken forItem:channel];
	}
}

- (void)postEventToViewController:(NSString *)eventToken forChannel:(IRCChannel *)channel
{
	if (themeSettings().js_postHandleEventNotifications == NO) {
		return; // Cancel operation...
	}

	[self postEventToViewController:eventToken forItem:channel];
}

- (void)postEventToViewController:(NSString *)eventToken forItem:(IRCTreeItem *)item
{
	NSParameterAssert(eventToken != nil);
	NSParameterAssert(item != nil);

	if (self.isTerminating) {
		return;
	}

	[item.viewController evaluateFunction:@"Textual.handleEvent" withArguments:@[eventToken] onQueue:NO];
}

@end

NS_ASSUME_NONNULL_END
