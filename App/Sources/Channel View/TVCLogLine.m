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
#import "NSStringHelper.h"
#import "TXGlobalModels.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCUserNicknameColorStyleGeneratorPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "TLOFileLoggerPrivate.h"
#import "TVCLogLineInternal.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TVCLogLineUndefinedNicknameFormat = @"<%@%n>";
NSString * const TVCLogLineActionNicknameFormat	= @"%@ ";
NSString * const TVCLogLineNoticeNicknameFormat	= @"-%@-";

NSString * const TVCLogLineSpecialNoticeMessageFormat = @"[%@]: %@";

NSString * const TVCLogLineDefaultCommandValue = @"-100";

@interface TVCLogLine ()
@property (readonly, copy) NSDictionary<NSString *, id> *dictionaryValue;
@end

@implementation TVCLogLine

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)init
{
	if ((self = [super init])) {
		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (nullable instancetype)initWithData:(NSData *)data
{
	NSParameterAssert(data != nil);

	/* The decoded line takes the place of self. Secure decoding: every
	 field names its classes (-populateWithDecoder:), older archives too */
	NSError *decodeError = nil;

	TVCLogLine *logLine = [NSKeyedUnarchiver unarchivedObjectOfClass:[TVCLogLine class] fromData:data error:&decodeError];

	if (logLine == nil) {
		LogToConsoleError("Failed to unarchive a log line: %{public}@", decodeError.localizedDescription);
	}

	return logLine;
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

+ (nullable TVCLogLine *)logLineWithData:(NSData *)data uniqueIdentifier:(nullable NSString *)uniqueIdentifier
{
	NSParameterAssert(data != nil);

	/* Lines from early versions of the historic log don't carry their unique
	 identifier in the archive; the database row has it */
	TVCLogLine *object = nil;

	/* Unarchiving damaged data raises */
	@try {
		object = [[TVCLogLine alloc] initWithData:data];
	} @catch (NSException *exception) {
		LogToConsoleError("Failed to unarchive a log line: %{public}@", exception.reason);

		return nil;
	}

	if (object == nil || [object isKindOfClass:[TVCLogLine class]] == NO) {
		return nil;
	}

	if (object->_uniqueIdentifier == nil) {
		object->_uniqueIdentifier = [uniqueIdentifier copy];
	}

	return [object copy];
}

- (BOOL)populateWithDecoder:(NSCoder *)aDecoder
{
	self->_receivedAt = [aDecoder decodeObjectOfClass:[NSDate class] forKey:@"receivedAt"];

	self->_excludeKeywords = [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
												   forKey:@"excludeKeywords"];

	self->_highlightKeywords = [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
													 forKey:@"highlightKeywords"];

	id rendererAttributes = [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], nil]
													 forKey:@"rendererAttributes"];

	self->_rendererAttributes = ([rendererAttributes isKindOfClass:[NSDictionary class]] ? rendererAttributes : nil);

	self->_isEncrypted = [aDecoder decodeBoolForKey:@"isEncrypted"];
	self->_isFirstForDay = [aDecoder decodeBoolForKey:@"isFirstForDay"];

	self->_command = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"command"];
	self->_messageBody = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"messageBody"];
	self->_nickname = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"nickname"];

	self->_lineType = [aDecoder decodeIntegerForKey:@"lineType"];
	self->_memberType = [aDecoder decodeIntegerForKey:@"memberType"];

	self->_uniqueIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"uniqueIdentifier"];

	self->_sessionIdentifier = [aDecoder decodeIntegerForKey:@"sessionIdentifier"];

	[self computeNicknameColorStyle];

	return YES;
}

- (void)populateDefaultsPostflight
{
	[self populateDefaultUniqueIdentifier];
	[self populateDefaultSessionIdentifier];

	SetVariableIfNil(self->_command, TVCLogLineDefaultCommandValue)
	SetVariableIfNil(self->_messageBody, @"")
	SetVariableIfNil(self->_receivedAt, [NSDate date])

	if (self->_lineType == TVCLogLineTypeActionNoHighlight) {
		self->_lineType = TVCLogLineTypeAction;

		self->_highlightKeywords = nil;
	} else if (self->_lineType == TVCLogLineTypePrivateMessageNoHighlight) {
		self->_lineType = TVCLogLineTypePrivateMessage;

		self->_highlightKeywords = nil;
	}
}

- (void)populateDefaultUniqueIdentifier
{
	if (self->_uniqueIdentifier != nil) {
		return;
	}

	self->_uniqueIdentifier = [self.class newUniqueIdentifier];
}

- (void)populateDefaultSessionIdentifier
{
	if (self->_sessionIdentifier != 0) {
		return;
	}

	self->_sessionIdentifier = [self.class currentSessionIdentifier];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:self.command forKey:@"command"];
	[aCoder encodeObject:self.messageBody forKey:@"messageBody"];

	[aCoder maybeEncodeObject:self.excludeKeywords forKey:@"excludeKeywords"];
	[aCoder maybeEncodeObject:self.highlightKeywords forKey:@"highlightKeywords"];
	[aCoder maybeEncodeObject:self.rendererAttributes forKey:@"rendererAttributes"];
	[aCoder maybeEncodeObject:self.nickname forKey:@"nickname"];

	[aCoder encodeBool:self.isEncrypted forKey:@"isEncrypted"];
	[aCoder encodeBool:self.isFirstForDay forKey:@"isFirstForDay"];

	[aCoder encodeObject:self.receivedAt forKey:@"receivedAt"];

	[aCoder encodeInteger:self.lineType forKey:@"lineType"];
	[aCoder encodeInteger:self.memberType forKey:@"memberType"];

	[aCoder encodeObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	[aCoder encodeInteger:self.sessionIdentifier forKey:@"sessionIdentifier"];
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (nullable NSData *)archivedData
{
	NSError *encodeError = nil;

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:&encodeError];

	if (data == nil) {
		LogToConsoleError("Failed to archive a log line: %{public}@", encodeError.localizedDescription);
	}

	return data;
}

+ (NSString *)newUniqueIdentifier
{
	NSString *printIdentifier = [NSString stringWithUUID]; // Example: 68753A44-4D6F-1226-9C60-0050E4C00067

	return [printIdentifier substringFromIndex:19]; // Example: 9C60-0050E4C00067
}

+ (NSUInteger)currentSessionIdentifier
{
	static NSUInteger sessionIdentifier = 0;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sessionIdentifier = TXRandomNumber(999999);
	});

	return sessionIdentifier;
}

- (BOOL)fromCurrentSession
{
	return (self.sessionIdentifier == [self.class currentSessionIdentifier]);
}

+ (nullable NSString *)stringForLineType:(TVCLogLineType)type
{
#define _dv(lineType, returnValue)			case (lineType): { return (returnValue); break; }

	switch (type) {
		_dv(TVCLogLineTypeAction, @"action")
		_dv(TVCLogLineTypeActionNoHighlight, @"action")
		_dv(TVCLogLineTypeCTCP, @"ctcp")
		_dv(TVCLogLineTypeCTCPQuery, @"ctcp")
		_dv(TVCLogLineTypeCTCPReply, @"ctcp")
		_dv(TVCLogLineTypeDCCFileTransfer, @"dcc-file-transfer")
		_dv(TVCLogLineTypeDebug, @"debug")
		_dv(TVCLogLineTypeInvite, @"invite")
		_dv(TVCLogLineTypeJoin, @"join")
		_dv(TVCLogLineTypeKick, @"kick")
		_dv(TVCLogLineTypeKill, @"kill")
		_dv(TVCLogLineTypeMode, @"mode")
		_dv(TVCLogLineTypeNick, @"nick")
		_dv(TVCLogLineTypeNotice, @"notice")
		_dv(TVCLogLineTypeOffTheRecordEncryptionStatus, @"off-the-record-encryption-status")
		_dv(TVCLogLineTypePart, @"part")
		_dv(TVCLogLineTypePrivateMessage, @"privmsg")
		_dv(TVCLogLineTypePrivateMessageNoHighlight, @"privmsg")
		_dv(TVCLogLineTypeQuit, @"quit")
		_dv(TVCLogLineTypeTopic, @"topic")
		_dv(TVCLogLineTypeWebsite, @"website")

		default:
		{
			return nil;
		}
	}

#undef _dv
}

+ (NSString *)stringForMemberType:(TVCLogLineMemberType)type
{
	if (type == TVCLogLineMemberTypeLocalUser) {
		return @"myself";
	} else {
		return @"normal";
	}
}

- (nullable NSString *)lineTypeString
{
	return [self.class stringForLineType:self.lineType];
}

- (NSString *)memberTypeString
{
	return [self.class stringForMemberType:self.memberType];
}

- (NSString *)formattedTimestamp
{
	return [self formattedTimestampWithFormat:nil];
}

- (NSString *)formattedTimestampWithFormat:(nullable NSString *)format
{
	if (format.length == 0) {
		format = themeSettings().themeTimestampFormat;
	}

	if (format.length == 0) {
		format = [TPCPreferences themeTimestampFormat];
	}

	if (format.length == 0) {
		format = [TPCPreferences themeTimestampFormatDefault];
	}

	NSString *time = TXFormattedTimestamp(self.receivedAt, format);

	return time;
}

- (nullable NSString *)formattedNicknameInChannel:(nullable IRCChannel *)channel
{
	return [self formattedNicknameInChannel:channel withFormat:nil];
}

- (nullable NSString *)formattedNicknameInChannel:(nullable IRCChannel *)channel withFormat:(nullable NSString *)format
{
	if (self.nickname == nil) {
		return nil;
	}

	if (format == nil) {
		if (self.lineType == TVCLogLineTypeAction) {
			return [NSString stringWithFormat:TVCLogLineActionNicknameFormat, self.nickname];
		} else if (self.lineType == TVCLogLineTypeNotice) {
			return [NSString stringWithFormat:TVCLogLineNoticeNicknameFormat, self.nickname];
		}
	}

	return [channel.associatedClient formatNickname:self.nickname inChannel:channel withFormat:format];
}

- (NSString *)renderedBodyForTranscriptLog
{
	return [self renderedBodyForTranscriptLogInChannel:nil];
}

- (NSString *)renderedBodyForTranscriptLogInChannel:(nullable IRCChannel *)channel
{
	NSMutableString *s = [NSMutableString string];

	NSString *timeFormatted = [self formattedTimestampWithFormat:TLOFileLoggerISOStandardClockFormat];

	if (timeFormatted) {
		[s appendString:timeFormatted];
		[s appendString:@" "];
	}

	NSString *nicknameFormatted = nil;

	if (self.lineType == TVCLogLineTypeAction) {
		nicknameFormatted = [self formattedNicknameInChannel:channel withFormat:TLOFileLoggerActionNicknameFormat];
	} else if (self.lineType == TVCLogLineTypeNotice) {
		nicknameFormatted = [self formattedNicknameInChannel:channel withFormat:TLOFileLoggerNoticeNicknameFormat];
	} else {
		nicknameFormatted = [self formattedNicknameInChannel:channel withFormat:TLOFileLoggerUndefinedNicknameFormat];
	}

	if (nicknameFormatted) {
		[s appendString:nicknameFormatted];
		[s appendString:@" "];
	}

	[s appendString:self.messageBody];

	return s.stripIRCEffects;
}

- (void)computeNicknameColorStyle
{
	if (self.nickname != nil &&
		(self.lineType == TVCLogLineTypePrivateMessage ||
		 self.lineType == TVCLogLineTypePrivateMessageNoHighlight ||
		 self.lineType == TVCLogLineTypeAction ||
		 self.lineType == TVCLogLineTypeActionNoHighlight))
	{
		BOOL isOverride = NO;

		self->_nicknameColorStyle =
		[IRCUserNicknameColorStyleGenerator nicknameColorStyleForString:self.nickname isOverride:&isOverride];

		self->_nicknameColorStyleOverride = isOverride;
	} else {
		self->_nicknameColorStyle = nil;
	}
}

- (void)populateDuringCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy
{
	TVCLogLine *object = (TVCLogLine *)newObject;

	object->_uniqueIdentifier = self->_uniqueIdentifier;

	object->_isEncrypted = self->_isEncrypted;
	object->_isFirstForDay = self->_isFirstForDay;

	object->_excludeKeywords = self->_excludeKeywords;
	object->_highlightKeywords = self->_highlightKeywords;

	object->_rendererAttributes = self->_rendererAttributes;

	object->_receivedAt = self->_receivedAt;

	object->_command = self->_command;
	object->_messageBody = self->_messageBody;
	object->_nickname = self->_nickname;
	object->_nicknameColorStyle = self->_nicknameColorStyle;

	object->_nicknameColorStyleOverride = self->_nicknameColorStyleOverride;

	object->_lineType = self->_lineType;
	object->_memberType = self->_memberType;

	object->_sessionIdentifier = self->_sessionIdentifier;
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [TVCLogLineMutable self];
}

@end

#pragma mark -

@implementation TVCLogLineMutable

@dynamic command;
@dynamic excludeKeywords;
@dynamic highlightKeywords;
@dynamic rendererAttributes;
@dynamic isEncrypted;
@dynamic isFirstForDay;
@dynamic lineType;
@dynamic memberType;
@dynamic messageBody;
@dynamic nickname;
@dynamic receivedAt;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [TVCLogLine self];
}

- (void)setIsEncrypted:(BOOL)isEncrypted
{
	if (self->_isEncrypted != isEncrypted) {
		self->_isEncrypted = isEncrypted;
	}
}

- (void)setIsFirstForDay:(BOOL)isFirstForDay
{
	if (self->_isFirstForDay != isFirstForDay) {
		self->_isFirstForDay = isFirstForDay;
	}
}

- (void)setExcludeKeywords:(nullable NSArray<NSString *> *)excludeKeywords
{
	if (self->_excludeKeywords != excludeKeywords) {
		self->_excludeKeywords = [excludeKeywords copy];
	}
}

- (void)setHighlightKeywords:(nullable NSArray<NSString *> *)highlightKeywords
{
	if (self->_highlightKeywords != highlightKeywords) {
		self->_highlightKeywords = [highlightKeywords copy];
	}
}

- (void)setRendererAttributes:(nullable NSDictionary<NSString *, id> *)rendererAttributes
{
	if (self->_rendererAttributes != rendererAttributes) {
		self->_rendererAttributes = [rendererAttributes copy];
	}
}

- (void)setReceivedAt:(NSDate *)receivedAt
{
	NSParameterAssert(receivedAt != nil);

	if (self->_receivedAt != receivedAt) {
		self->_receivedAt = [receivedAt copy];
	}
}

- (void)setCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	if (self->_command != command) {
		self->_command = [command copy];
	}
}

- (void)setMessageBody:(NSString *)messageBody
{
	NSParameterAssert(messageBody != nil);

	if (self->_messageBody != messageBody) {
		self->_messageBody = [messageBody copy];
	}
}

- (void)setNickname:(nullable NSString *)nickname
{
	if (self->_nickname != nickname) {
		self->_nickname = [nickname copy];

		[self computeNicknameColorStyle];
	}
}

- (void)setMemberType:(TVCLogLineMemberType)memberType
{
	if (self->_memberType != memberType) {
		self->_memberType = memberType;
	}
}

- (void)setLineType:(TVCLogLineType)lineType
{
	if (self->_lineType != lineType) {
		self->_lineType = lineType;
	}
}

@end

NS_ASSUME_NONNULL_END
