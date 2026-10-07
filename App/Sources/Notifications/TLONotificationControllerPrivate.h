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

#import "TLONotificationController.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCClient;

TEXTUAL_EXTERN NSString * const TXNotificationUserInfoClientIdentifierKey;
TEXTUAL_EXTERN NSString * const TXNotificationUserInfoChannelIdentifierKey;

TEXTUAL_EXTERN NSString * const TXNotificationDialogStandardNicknameFormat;
TEXTUAL_EXTERN NSString * const TXNotificationDialogActionNicknameFormat;

TEXTUAL_EXTERN NSString * const TXNotificationHighlightLogStandardActionFormat;
TEXTUAL_EXTERN NSString * const TXNotificationHighlightLogStandardMessageFormat;

@interface TLONotificationController ()
/* All methods in this controller do not honor any user preference for
 silencing notifications. By the time a notification reaches this point,
 it is assumed that those related conditions have been checked. */

/* This method will automatically configure the notification based on the
 event type such as setting a title or description. It will also perform
 formatter stripping if need be. In addition to properly separating
 notifications by threads. */
- (void)notify:(TXNotificationType)eventType
		 title:(nullable NSString *)eventTitle
   description:(nullable NSString *)eventDescription
	  userInfo:(nullable NSDictionary<NSString *, id> *)eventContext;

- (void)dismissNotificationsForChannel:(nullable IRCChannel *)channel onClient:(IRCClient *)client;

/* These methods schedule notifications with the UserNotification.framework.
 Nothing more. -notify:title:description:userInfo: is the proper entry point
 for sending notifications related to IRC. These entry points are conveniences
 for sending unrelated notifications such as from the license manager or addons. */
- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 onClient:(IRCClient *)client;

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
						   forChannel:(IRCChannel *)channel;

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
						   forChannel:(nullable IRCChannel *)channel
							 onClient:(IRCClient *)client;

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;

- (void)scheduleNotificationWithTitle:(NSString *)title
							  message:(NSString *)message
							 userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
					 threadIdentifier:(NSString *)threadIdentifier;
@end

NS_ASSUME_NONNULL_END
