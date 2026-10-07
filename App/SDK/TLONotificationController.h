/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@class IRCChannel;

typedef NS_ENUM(NSUInteger, TXNotificationType) {
	TXNotificationTypeHighlight							= 1000,
	TXNotificationTypeNewPrivateMessage					= 1001,
	TXNotificationTypeChannelMessage					= 1002,
	TXNotificationTypeChannelNotice						= 1003,
	TXNotificationTypePrivateMessage					= 1004,
	TXNotificationTypePrivateNotice						= 1005,
	TXNotificationTypeKick								= 1006,
	TXNotificationTypeInvite							= 1007,
	TXNotificationTypeConnect							= 1008,
	TXNotificationTypeDisconnect						= 1009,
	TXNotificationTypeAddressBookMatch					= 1010,
	TXNotificationTypeFileTransferSendSuccessful		= 1011,
	TXNotificationTypeFileTransferReceiveSuccessful		= 1012,
	TXNotificationTypeFileTransferSendFailed			= 1013,
	TXNotificationTypeFileTransferReceiveFailed			= 1014,
	TXNotificationTypeFileTransferReceiveRequested		= 1015,
	TXNotificationTypeUserJoined						= 1016,
	TXNotificationTypeUserParted						= 1017,
	TXNotificationTypeUserDisconnected					= 1018
};

@interface TLONotificationController : NSObject
@property (nonatomic, assign) BOOL areNotificationsDisabled;

- (NSString *)titleForEvent:(TXNotificationType)event;
@end

@interface TLONotificationController (Preferences)
- (nullable NSString *)soundForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel;
- (BOOL)speakEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel;
- (BOOL)notificationEnabledForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel;
- (BOOL)disabledWhileAwayForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel;
- (BOOL)bounceDockIconForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel;
- (BOOL)bounceDockIconRepeatedlyForEvent:(TXNotificationType)event inChannel:(nullable IRCChannel *)channel;
@end

NS_ASSUME_NONNULL_END
