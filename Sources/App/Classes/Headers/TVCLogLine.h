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

NS_ASSUME_NONNULL_BEGIN

@class IRCChannel;

TEXTUAL_EXTERN NSString * const TVCLogLineUndefinedNicknameFormat;
TEXTUAL_EXTERN NSString * const TVCLogLineActionNicknameFormat;
TEXTUAL_EXTERN NSString * const TVCLogLineNoticeNicknameFormat;

TEXTUAL_EXTERN NSString * const TVCLogLineSpecialNoticeMessageFormat;

TEXTUAL_EXTERN NSString * const TVCLogLineDefaultCommandValue;

typedef NS_ENUM(NSUInteger, TVCLogLineType) {
	TVCLogLineTypeUndefined					= 0,
	TVCLogLineTypeAction,
	TVCLogLineTypeActionNoHighlight,
	TVCLogLineTypeCTCP,
	TVCLogLineTypeCTCPQuery,
	TVCLogLineTypeCTCPReply,
	TVCLogLineTypeDCCFileTransfer,
	TVCLogLineTypeDebug,
	TVCLogLineTypeInvite,
	TVCLogLineTypeJoin,
	TVCLogLineTypeKick,
	TVCLogLineTypeKill,
	TVCLogLineTypeMode,
	TVCLogLineTypeNick,
	TVCLogLineTypeNotice,
	TVCLogLineTypeOffTheRecordEncryptionStatus, // Unused (Off-the-Record Messaging was removed); kept so that later values do not change
	TVCLogLineTypePart,
	TVCLogLineTypePrivateMessage,
	TVCLogLineTypePrivateMessageNoHighlight,
	TVCLogLineTypeQuit,
	TVCLogLineTypeTopic,
	TVCLogLineTypeWebsite,
};

typedef NS_ENUM(NSUInteger, TVCLogLineMemberType) {
	TVCLogLineMemberTypeNormal = 0,
	TVCLogLineMemberTypeLocalUser,
};

#define IRCCommandFromLineType(t)		[TVCLogLine stringForLineType:t]

#pragma mark -
#pragma mark Immutable Object

@interface TVCLogLine : XRPortablePropertyObject
@property (readonly) BOOL isEncrypted;
@property (readonly) BOOL isFirstForDay; // // YES if is first line for the day defined by receivedAt
@property (readonly, copy) NSDate *receivedAt;
@property (readonly, copy) NSString *nicknameColorStyle;
@property (readonly) BOOL nicknameColorStyleOverride; // YES if the nicknameColorStyle was set by the user
@property (readonly, copy, nullable) NSString *nickname;
@property (readonly, copy) NSString *messageBody;
@property (readonly, copy) NSString *command; // Can be the actual command (PRIVMSG, NOTICE, etc.) or the raw numeric (001, 002, etc.)
@property (readonly, copy) NSString *uniqueIdentifier;
@property (readonly) TVCLogLineType lineType;
@property (readonly) TVCLogLineMemberType memberType;
@property (readonly, copy, nullable) NSArray<NSString *> *highlightKeywords;
@property (readonly, copy, nullable) NSArray<NSString *> *excludeKeywords;
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *rendererAttributes;
@property (readonly) NSUInteger sessionIdentifier;

- (nullable instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;

@property (readonly, copy) NSString *formattedTimestamp;

@property (readonly, copy) NSString *formattedNickname;
- (nullable NSString *)formattedNicknameInChannel:(nullable IRCChannel *)channel;

@property (readonly, copy, nullable) NSString *lineTypeString;
@property (readonly, copy) NSString *memberTypeString;

+ (nullable NSString *)stringForLineType:(TVCLogLineType)type;
+ (NSString *)stringForMemberType:(TVCLogLineMemberType)type;
@end

#pragma mark -
#pragma mark Mutable Object

@interface TVCLogLineMutable : TVCLogLine
@property (nonatomic, assign, readwrite) BOOL isEncrypted;
@property (nonatomic, assign, readwrite) BOOL isFirstForDay;
@property (nonatomic, copy, readwrite) NSDate *receivedAt;
@property (nonatomic, copy, readwrite, nullable) NSString *nickname;
@property (nonatomic, copy, readwrite) NSString *messageBody;
@property (nonatomic, copy, readwrite) NSString *command;
@property (nonatomic, assign, readwrite) TVCLogLineType lineType;
@property (nonatomic, assign, readwrite) TVCLogLineMemberType memberType;
@property (nonatomic, copy, readwrite, nullable) NSArray<NSString *> *highlightKeywords;
@property (nonatomic, copy, readwrite, nullable) NSArray<NSString *> *excludeKeywords;
@property (nonatomic, copy, readwrite, nullable) NSDictionary<NSString *, id> *rendererAttributes;
@end

NS_ASSUME_NONNULL_END
