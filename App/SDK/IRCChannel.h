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

#import "IRCChannelConfig.h"
#import "IRCChannelMemberList.h"
#import "IRCTreeItem.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCChannelMode, IRCChannelUser, IRCUser;
@class TVCLogLine;

typedef NS_ENUM(NSUInteger, IRCChannelStatus) {
	IRCChannelStatusParted = 0,
	IRCChannelStatusJoining,
	IRCChannelStatusJoined,
	IRCChannelStatusTerminated,
};

TEXTUAL_EXTERN NSNotificationName const IRCChannelConfigurationWasUpdatedNotification;

@interface IRCChannel : IRCTreeItem <IRCChannelMemberListPrototype>
@property (readonly, copy) IRCChannelConfig *config;
@property (nonatomic, copy) NSString *name; // -setName: will do nothing if type != IRCChannelTypePrivateMessage
@property (nonatomic, copy, nullable) NSString *topic;
@property (nonatomic, assign) BOOL autoJoin;
@property (readonly) IRCChannelType type;
@property (getter=isChannel, readonly) BOOL channel;
@property (getter=isPrivateMessage, readonly) BOOL privateMessage;
@property (getter=isPrivateMessageForZNCUser, readonly) BOOL privateMessageForZNCUser; // For example: *status, *nickserv, etc.
@property (getter=isUtility, readonly) BOOL utility; // See IRCChannelTypeUtility in IRCChannelConfig.h
@property (readonly) IRCChannelStatus status;
@property (readonly) BOOL errorOnLastJoinAttempt;
@property (readonly) NSTimeInterval channelJoinTime;
@property (readonly, copy) NSString *channelTypeString;
@property (readonly, strong, nullable) IRCChannelMode *modeInfo;
@property (readonly, strong, nullable) IRCChannelMemberList *memberInfo;
@property (readonly, copy, nullable) NSString *secretKey;
@property (readonly, copy, nullable) NSURL *logFilePath;
@property (readonly) NSUInteger logFileSessionCount; // Number of lines sent to channel log file for session (from connect to disconnect)
@property (readonly, weak) TVCLogLine *lastLine; // Last line in the channel. There is no guarantee it's visible to the user when accessed.

- (instancetype)init NS_UNAVAILABLE;

- (void)activate;
- (void)deactivate;
@end

NS_ASSUME_NONNULL_END
