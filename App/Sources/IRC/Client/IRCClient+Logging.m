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
#import "IRCHighlightKeywordPrivate.h"
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

/* The highlight keywords of a channel and what they were built from,
 so they are only rebuilt when one of those changes (R4.5) */
@interface IRCChannelHighlightKeywords : NSObject
@property (nonatomic, copy) NSArray<NSString *> *matchKeywords;
@property (nonatomic, copy) NSArray<NSString *> *excludeKeywords;
@property (nonatomic, copy) NSArray<IRCHighlightKeyword *> *matchKeywordsForPeople; // limited to people: added per sender
@property (nonatomic, copy) NSArray<IRCHighlightKeyword *> *excludeKeywordsForPeople;
@property (nonatomic, strong, nullable) NSArray<IRCHighlightKeyword *> *globalMatchKeywords;
@property (nonatomic, strong, nullable) NSArray<IRCHighlightKeyword *> *globalExcludeKeywords;
@property (nonatomic, copy, nullable) NSString *nickname; // nil when the nickname isn't a keyword
@end

@implementation IRCChannelHighlightKeywords
@end

@implementation IRCClient (Logging)

#pragma mark -
#pragma mark Log File

- (void)reopenLogFileIfNeeded
{
	if ([TPCPreferences logToDiskIsEnabled]) {
		if ( self.logFile) {
			[self.logFile reopenIfNeeded];
		}
	} else {
		[self closeLogFile];
	}
}

- (void)closeLogFile
{
	if (self.logFile == nil) {
		return;
	}

	[self.logFile close];
}

- (void)writeToLogLineToLogFile:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	if ([TPCPreferences logToDiskIsEnabled] == NO) {
		return;
	}

	// Perform addition before if statement to avoid infinite loop
	self.logFileSessionCount += 1;

	if (self.logFileSessionCount == 1) {
		[self logFileWriteSessionBegin];
	}

	if (self.logFile == nil) {
		self.logFile = [[TLOFileLogger alloc] initWithClient:self];
	}

	[self.logFile writeLogLine:logLine];
}

- (void)logFileRecordSessionChanged:(BOOL)toNewSession inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(channel.isUtility == NO);

	NSString *localization = nil;

	if (toNewSession) {
		localization = @"IRC[qrg-ua]";
	} else {
		localization = @"IRC[d5d-uy]";
	}

	TVCLogLineMutable *logLine = [TVCLogLineMutable new];

	/* ============================ */

	logLine.messageBody = @" ";

	if (channel) {
		[channel writeToLogLineToLogFile:logLine];
	} else {
		[self writeToLogLineToLogFile:logLine];
	}

	/* ============================ */

	logLine.messageBody = TXTLS(localization);

	if (channel) {
		[channel writeToLogLineToLogFile:logLine];
	} else {
		[self writeToLogLineToLogFile:logLine];
	}

	/* ============================ */

	logLine.messageBody = @" ";

	if (channel) {
		[channel writeToLogLineToLogFile:logLine];
	} else {
		[self writeToLogLineToLogFile:logLine];
	}
}

- (void)endLoggingSessions
{
	for (IRCChannel *channel in self.channelList) {
		if (channel.isUtility) {
			continue;
		}

		[channel logFileWriteSessionEnd];
	}

	[self logFileWriteSessionEnd];
}

- (void)logFileWriteSessionBegin
{
	[self logFileRecordSessionChanged:YES inChannel:nil];
}

- (void)logFileWriteSessionEnd
{
	[self logFileRecordSessionChanged:NO inChannel:nil];

	self.logFileSessionCount = 0;
}

#pragma mark -
#pragma mark Print

- (NSString *)formatNickname:(NSString *)nickname inChannel:(nullable IRCChannel *)channel
{
	return [self formatNickname:nickname inChannel:channel withFormat:nil];
}

- (NSString *)formatNickname:(NSString *)nickname inChannel:(nullable IRCChannel *)channel withFormat:(nullable NSString *)format
{
	return [self formatNickname:nickname inChannel:channel withFormat:format modeSymbol:nil];
}

- (NSString *)formatNickname:(NSString *)nickname inChannel:(nullable IRCChannel *)channel withFormat:(nullable NSString *)format modeSymbol:(nullable NSString *)modeSymbolIn
{
	NSParameterAssert(nickname != nil);

	if (format.length == 0) {
		format = themeSettings().themeNicknameFormat;
	}

	if (format.length == 0) {
		format = [TPCPreferences themeNicknameFormat];
	}

	if (format.length == 0) {
		format = [TPCPreferences themeNicknameFormatDefault];
	}

	NSString *modeSymbol = (modeSymbolIn ?: @"");

	if (modeSymbolIn == nil && channel.isChannel) {
		IRCChannelUser *member = [channel findMember:nickname];

		if (member) {
			modeSymbol = member.mark;
		}
	}

	NSString *formatMarker = @"%";

	NSString *chunk = nil;

	NSScanner *scanner = [NSScanner scannerWithString:format];

	scanner.charactersToBeSkipped = nil;

	NSMutableString *buffer = [NSMutableString new];

	while (scanner.atEnd == NO) {
		if ([scanner scanUpToString:formatMarker intoString:&chunk]) {
			[buffer appendString:chunk];
		}

		if ([scanner scanString:formatMarker intoString:nil] == NO) {
			break;
		}

		NSInteger paddingWidth = 0;

		[scanner scanInteger:&paddingWidth];

		/* Read the output type marker */
		NSString *outputValue = nil;

		if ([scanner scanString:@"@" intoString:nil]) {
			outputValue = modeSymbol;
		} else if ([scanner scanString:@"n" intoString:nil]) {
			outputValue = nickname;
		} else if ([scanner scanString:formatMarker intoString:nil]) {
			outputValue = formatMarker;
		}

		if (outputValue) {
			if (paddingWidth < 0 && ABS(paddingWidth) > outputValue.length) {
				NSString *paddedString = [@"" stringByPaddingToLength:(ABS(paddingWidth) - outputValue.length) withString:@" " startingAtIndex:0];

				[buffer appendString:paddedString];
			}

			[buffer appendString:outputValue];

			if (paddingWidth > 0 && paddingWidth > outputValue.length) {
				NSString *paddedString = [@"" stringByPaddingToLength:(paddingWidth - outputValue.length) withString:@" " startingAtIndex:0];

				[buffer appendString:paddedString];
			}
		}
	}

	return [buffer copy];
}

- (void)printAndLog:(TVCLogLine *)logLine completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	NSParameterAssert(logLine != nil);

	[self.viewController print:logLine completionBlock:completionBlock];

	[self writeToLogLineToLogFile:logLine];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:[NSDate date] isEncrypted:NO escapeMessage:YES referenceMessage:nil completionBlock:nil];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command escapeMessage:(BOOL)escapeMessage
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:[NSDate date] isEncrypted:NO escapeMessage:escapeMessage referenceMessage:nil completionBlock:nil];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command receivedAt:(NSDate *)receivedAt
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:receivedAt isEncrypted:NO escapeMessage:YES referenceMessage:nil completionBlock:nil];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:receivedAt isEncrypted:isEncrypted escapeMessage:YES referenceMessage:nil completionBlock:nil];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted referenceMessage:(nullable IRCMessage *)referenceMessage
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:receivedAt isEncrypted:isEncrypted escapeMessage:YES referenceMessage:referenceMessage completionBlock:nil];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted referenceMessage:(nullable IRCMessage *)referenceMessage completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:receivedAt isEncrypted:isEncrypted escapeMessage:YES referenceMessage:referenceMessage completionBlock:completionBlock];
}

- (IRCChannelHighlightKeywords *)highlightKeywordsForChannel:(IRCChannel *)channel nickname:(NSString *)localNickname
{
	NSParameterAssert(channel != nil);
	NSParameterAssert(localNickname != nil);

	/* Highlight keywords (TPCPreferences replaces these arrays when they change) */
	NSArray *globalExcludeKeywords = [TPCPreferences highlightExcludeKeywordEntries];
	NSArray *globalMatchKeywords = [TPCPreferences highlightMatchKeywordEntries];

	/* Self nickname keyword */
	NSString *nickname = nil;

	if ([TPCPreferences highlightMatchingMethod] != TXNicknameHighlightMatchTypeRegularExpression &&
		[TPCPreferences highlightCurrentNickname])
	{
		nickname = localNickname;
	}

	IRCChannelHighlightKeywords *keywords = channel.highlightKeywords;

	if (keywords &&
		keywords.globalExcludeKeywords == globalExcludeKeywords &&
		keywords.globalMatchKeywords == globalMatchKeywords &&
		NSObjectsAreEqual(keywords.nickname, nickname))
	{
		return keywords;
	}

	NSString *channelId = channel.uniqueIdentifier;
	NSString *clientId = self.uniqueIdentifier;

	/* Keywords limited to other channels or networks are left out here;
	 those limited to people are checked against each sender */
	NSMutableArray<NSString *> *excludeKeywords = [NSMutableArray array];
	NSMutableArray<IRCHighlightKeyword *> *excludeKeywordsForPeople = [NSMutableArray array];

	for (IRCHighlightKeyword *e in globalExcludeKeywords) {
		if ([e appliesToChannelWithId:channelId clientId:clientId] == NO) {
			continue;
		}

		if (e.nicknames.count > 0) {
			[excludeKeywordsForPeople addObject:e];
		} else {
			[excludeKeywords addObjectWithoutDuplication:e.keyword];
		}
	}

	NSMutableArray<NSString *> *matchKeywords = [NSMutableArray array];
	NSMutableArray<IRCHighlightKeyword *> *matchKeywordsForPeople = [NSMutableArray array];

	for (IRCHighlightKeyword *e in globalMatchKeywords) {
		if ([e appliesToChannelWithId:channelId clientId:clientId] == NO) {
			continue;
		}

		if (e.nicknames.count > 0) {
			[matchKeywordsForPeople addObject:e];
		} else {
			[matchKeywords addObjectWithoutDuplication:e.keyword];
		}
	}

	if (nickname) {
		[matchKeywords addObjectWithoutDuplication:nickname];
	}

	keywords = [IRCChannelHighlightKeywords new];

	keywords.excludeKeywords = excludeKeywords;
	keywords.matchKeywords = matchKeywords;

	keywords.excludeKeywordsForPeople = excludeKeywordsForPeople;
	keywords.matchKeywordsForPeople = matchKeywordsForPeople;

	keywords.globalExcludeKeywords = globalExcludeKeywords;
	keywords.globalMatchKeywords = globalMatchKeywords;
	keywords.nickname = nickname;

	channel.highlightKeywords = keywords;

	return keywords;
}

/* The channel's keywords plus those limited to the sender */
- (NSArray<NSString *> *)highlightKeywords:(NSArray<NSString *> *)keywords addingKeywordsForPeople:(NSArray<IRCHighlightKeyword *> *)keywordsForPeople sender:(nullable NSString *)sender
{
	NSParameterAssert(keywords != nil);
	NSParameterAssert(keywordsForPeople != nil);

	if (keywordsForPeople.count == 0 || sender == nil) {
		return keywords;
	}

	IRCISupportInfo *supportInfo = self.supportInfo;

	NSMutableArray<NSString *> *keywordsOut = nil;

	for (IRCHighlightKeyword *e in keywordsForPeople) {
		if ([e appliesToNickname:sender supportInfo:supportInfo] == NO) {
			continue;
		}

		if (keywordsOut == nil) {
			keywordsOut = [keywords mutableCopy];
		}

		[keywordsOut addObjectWithoutDuplication:e.keyword];
	}

	if (keywordsOut == nil) {
		return keywords;
	}

	return [keywordsOut copy];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted escapeMessage:(BOOL)escapeMessage referenceMessage:(nullable IRCMessage *)referenceMessage completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	[self print:messageBody by:nickname inChannel:channel asType:lineType command:command receivedAt:receivedAt isEncrypted:isEncrypted escapeMessage:escapeMessage referenceMessage:referenceMessage eventNicknames:nil completionBlock:completionBlock];
}

/* A join, part, quit or nickname change: printed without a sender, and with the
 nicknames it is about, which a collapsed run of them names */
- (void)printGeneralEvent:(NSString *)messageBody aboutNicknames:(NSArray<NSString *> *)nicknames inChannel:(IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command receivedAt:(NSDate *)receivedAt
{
	NSParameterAssert(nicknames != nil);

	[self print:messageBody by:nil inChannel:channel asType:lineType command:command receivedAt:receivedAt isEncrypted:NO escapeMessage:YES referenceMessage:nil eventNicknames:nicknames completionBlock:nil];
}

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted escapeMessage:(BOOL)escapeMessage referenceMessage:(nullable IRCMessage *)referenceMessage eventNicknames:(nullable NSArray<NSString *> *)eventNicknames completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	NSParameterAssert(messageBody != nil);
	NSParameterAssert(command != nil || referenceMessage != nil);

	if (self.isTerminating) {
		return;
	}

	/* If an operation does not specify a command value, 
	 then try to obtain it from the reference message. */
	if (command == nil) {
		command = referenceMessage.command;
	}

	/* Prevent stupid plugin authors */
	if ([channel isKindOfClass:[IRCChannel class]] == NO) {
		channel = nil;
	}

	/* Do not print this message? */
	if (channel) {
		if ([self outputRuleMatchedInMessage:messageBody inChannel:channel]) {
			return;
		}
	}

	/* Define where the message originated */
	NSString *localNickname = self.userNickname;

	TVCLogLineMemberType memberType = TVCLogLineMemberTypeNormal;

	if ([nickname isEqualToString:localNickname]) {
		memberType = TVCLogLineMemberTypeLocalUser;
	}

	/* Define list of highlight keywords */
	BOOL matchHighlights =
		(channel &&
		 channel.config.ignoreHighlights == NO &&
		 (lineType == TVCLogLineTypePrivateMessage || lineType == TVCLogLineTypeAction) &&
		 memberType == TVCLogLineMemberTypeNormal);

	NSArray<NSString *> *excludeKeywords = nil;
	NSArray<NSString *> *matchKeywords = nil;
	
	if (matchHighlights) {
		IRCChannelHighlightKeywords *keywords = [self highlightKeywordsForChannel:channel nickname:localNickname];

		excludeKeywords = [self highlightKeywords:keywords.excludeKeywords addingKeywordsForPeople:keywords.excludeKeywordsForPeople sender:nickname];
		matchKeywords = [self highlightKeywords:keywords.matchKeywords addingKeywordsForPeople:keywords.matchKeywordsForPeople sender:nickname];
	}

	if (lineType == TVCLogLineTypeActionNoHighlight) {
		lineType = TVCLogLineTypeAction;
	} else if (lineType == TVCLogLineTypePrivateMessageNoHighlight) {
		lineType = TVCLogLineTypePrivateMessage;
	}

	/* Renderer attributes */
	NSDictionary<NSString *, id> *rendererAttributes = nil;

	if (escapeMessage == NO) {
		rendererAttributes = @{
			TVCLogRendererConfigurationDoNotEscapeBodyAttribute : @(YES)
		};
	}

	/* Create new log entry */
	TVCLogLineMutable *logLine = [TVCLogLineMutable new];

	logLine.command	= command.lowercaseString;

	logLine.lineType = lineType;
	logLine.memberType = memberType;

	logLine.isEncrypted = isEncrypted;

	logLine.excludeKeywords = excludeKeywords;
	logLine.highlightKeywords = matchKeywords;

	logLine.rendererAttributes = rendererAttributes;

	logLine.nickname = nickname;

	/* The sender's rank now, kept with the line (shown with it later) */
	if (nickname && channel.isChannel) {
		logLine.nicknameModeSymbol = ([channel findMember:nickname].mark ?: @"");
	}

	logLine.eventNicknames = eventNicknames;

	/* Bot mode: the server's bot tag on the message */
	logLine.senderIsBot = (referenceMessage.messageTags[@"bot"] != nil);

	/* Sent to us, shown in a channel (+channel-context) */
	logLine.isPrivateInChannel = (channel.isChannel && referenceMessage != nil &&
								  [self stringIsChannelName:[referenceMessage paramAt:0]] == NO);

	/* Replies, reactions and deleting refer to the server's message ID.
	 Our own line printed without echo-message has none, but shows its reply. */
	logLine.msgid = referenceMessage.msgid;

	/* A message of ours being sent, or refused (failed sends) */
	IRCClientOutgoingMessage *outgoing = self.printingOutgoingMessage;

	if (referenceMessage) {
		logLine.replyToMsgid = referenceMessage.replyToMsgid;
	} else if (outgoing) {
		logLine.replyToMsgid = outgoing.replyToMsgid;

		logLine.sendFailedReason = outgoing.failedReason;

		outgoing.lineNumber = logLine.uniqueIdentifier;
	} else if (memberType == TVCLogLineMemberTypeLocalUser) {
		logLine.replyToMsgid = self.outgoingReplyMsgid;
	}

	logLine.messageBody = messageBody;

	/* Has the date changed */
	TVCLogLine *lastLine = ((channel) ? channel.lastLine : self.lastLine);

	if (lastLine == nil) {
		logLine.isFirstForDay = YES;
	} else {
		logLine.isFirstForDay = ([receivedAt isInSameDayAsDate:lastLine.receivedAt] == NO);
	}

	logLine.receivedAt = receivedAt;

	/* Print to server console if there is no channel */
	if (channel == nil) {
		[self printAndLog:logLine completionBlock:completionBlock];

		return;
	}

	/* Add scrollback marker to channel if conditions are met */
	if ([TPCPreferences autoAddScrollbackMark]) {
		BOOL channelInFront = NO;

		for (TVCMainWindow *window in [TVCMainWindow windowsShowingItem:channel]) {
			if (window.mainWindow) {
				channelInFront = YES;
			}
		}

		if (channelInFront == NO) {
			if (channel.isUnread == NO &&
				(lineType == TVCLogLineTypePrivateMessage ||
				 lineType == TVCLogLineTypeAction ||
				 lineType == TVCLogLineTypeNotice))
			{
				[channel.viewController mark];
			}
		}
	}

	/* draft/read-marker: the newest message someone viewing the channel has seen */
	if (lineType == TVCLogLineTypePrivateMessage ||
		lineType == TVCLogLineTypeAction ||
		lineType == TVCLogLineTypeNotice)
	{
		[self readMarkerNoteMessageAt:receivedAt inChannel:channel];
	}

	/* Print to channel */
	[channel print:logLine completionBlock:completionBlock];
}

- (void)printReply:(IRCMessage *)message
{
	[self printReply:message inChannel:nil];
}

- (void)printReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel
{
	[self printReply:message inChannel:channel withSequence:1];
}

/* Without a channel: the console, or the window a labeled command came from */
- (void)printReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel withSequence:(NSUInteger)sequence
{
	NSParameterAssert(message != nil);

	if (channel == nil) {
		channel = [self channelForReplyWithFallback:nil];
	}

	[self print:[message sequence:sequence] by:nil inChannel:channel asType:TVCLogLineTypeDebug command:message.command receivedAt:message.receivedAt];
}

- (void)printUnknownReply:(IRCMessage *)message
{
	[self printUnknownReply:message inChannel:nil];
}

- (void)printUnknownReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel
{
	[self printUnknownReply:message inChannel:channel withSequence:1];
}

- (void)printUnknownReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel withSequence:(NSUInteger)sequence
{
	[self printReply:message inChannel:channel withSequence:sequence];
}

- (void)printErrorReply:(IRCMessage *)message
{
	[self printErrorReply:message inChannel:nil];
}

- (void)printErrorReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel
{
	[self printErrorReply:message inChannel:channel withSequence:NSNotFound];
}

- (void)printErrorReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel withSequence:(NSUInteger)sequence
{
	NSParameterAssert(message != nil);

	NSString *sequenceMessage = nil;

	if (sequence == NSNotFound) {
		sequenceMessage = message.sequence;
	} else {
		sequenceMessage = [message sequence:sequence];
	}

	if (channel == nil) {
		channel = [self channelForReplyWithFallback:nil];
	}

	/* The server's text alone ("Message(482): …" before): the line carries
	 the number as its command, and styles show error replies in red */
	[self printDebugInformation:sequenceMessage inChannel:channel asCommand:message.command escapeMessage:YES];
}

- (void)printError:(NSString *)errorMessage asCommand:(NSString *)command
{
	[self printDebugInformation:errorMessage inChannel:nil asCommand:command escapeMessage:YES];
}

- (void)printDebugInformationToConsole:(NSString *)message
{
	[self printDebugInformationToConsole:message asCommand:TVCLogLineDefaultCommandValue escapeMessage:YES];
}

- (void)printDebugInformationToConsole:(NSString *)message asCommand:(NSString *)command
{
	[self printDebugInformationToConsole:message asCommand:command escapeMessage:YES];
}

- (void)printDebugInformationToConsole:(NSString *)message escapeMessage:(BOOL)escapeMessage
{
	[self printDebugInformationToConsole:message asCommand:TVCLogLineDefaultCommandValue escapeMessage:escapeMessage];
}

- (void)printDebugInformationToConsole:(NSString *)message asCommand:(NSString *)command escapeMessage:(BOOL)escapeMessage
{
	[self printDebugInformation:message inChannel:nil asCommand:command escapeMessage:escapeMessage];
}

- (void)printDebugInformation:(NSString *)message
{
	[self printDebugInformation:message asCommand:TVCLogLineDefaultCommandValue escapeMessage:YES];
}

- (void)printDebugInformationMultiline:(NSString *)message
{
	[message enumerateSplitOnNewLinesWithBlock:^(NSString *sequence, BOOL *stop) {
		[self printDebugInformation:sequence];
	}];
}

- (void)printDebugInformation:(NSString *)message asCommand:(NSString *)command
{
	[self printDebugInformation:message asCommand:command escapeMessage:YES];
}

- (void)printDebugInformation:(NSString *)message escapeMessage:(BOOL)escapeMessage
{
	[self printDebugInformation:message asCommand:TVCLogLineDefaultCommandValue escapeMessage:escapeMessage];
}

- (void)printDebugInformation:(NSString *)message asCommand:(NSString *)command escapeMessage:(BOOL)escapeMessage
{
	IRCChannel *channel = self.selectedChannelForReplies;

	[self printDebugInformation:message inChannel:channel asCommand:command escapeMessage:escapeMessage];
}

- (void)printDebugInformation:(NSString *)message inChannel:(nullable IRCChannel *)channel
{
	[self printDebugInformation:message inChannel:channel asCommand:TVCLogLineDefaultCommandValue escapeMessage:YES];
}

- (void)printDebugInformation:(NSString *)message inChannel:(nullable IRCChannel *)channel asCommand:(NSString *)command
{
	[self printDebugInformation:message inChannel:channel asCommand:command escapeMessage:YES];
}

- (void)printDebugInformation:(NSString *)message inChannel:(nullable IRCChannel *)channel escapeMessage:(BOOL)escapeMessage
{
	[self printDebugInformation:message inChannel:channel asCommand:TVCLogLineDefaultCommandValue escapeMessage:escapeMessage];
}

/* Every debug message (console, selected channel, a channel, all views,
 errors) ends here */
- (void)printDebugInformation:(NSString *)message inChannel:(nullable IRCChannel *)channel asCommand:(NSString *)command escapeMessage:(BOOL)escapeMessage
{
	[self print:message by:nil inChannel:channel asType:TVCLogLineTypeDebug command:command escapeMessage:escapeMessage];
}

#pragma mark -
#pragma mark Raw Data Logging

- (void)createRawDataLogQuery
{
	if (self.isTerminating) {
		return;
	}

	if (self.rawDataLogQuery != nil) {
		return;
	}

	IRCChannel *query = [self findChannelOrCreate:@"Server Traffic" isUtility:YES];

	self.rawDataLogQuery = query;

	[mainWindow() select:query];

	[self rawDataLog:TXTLS(@"IRC[ik6-dl]")];
}

- (void)destroyRawDataLogQuery
{
	if (self.isTerminating) {
		return;
	}

	if (self.rawDataLogQuery == nil) {
		return;
	}

	[worldController() destroyChannel:self.rawDataLogQuery];
}

- (void)rawDataLog:(NSString *)data
{
	NSParameterAssert(data != nil);

	if (self.isTerminating) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self printDebugInformation:data inChannel:self.rawDataLogQuery];
	});
}

- (void)rawDataLogOutgoingTraffic:(NSString *)data
{
	NSParameterAssert(data != nil);

	if (self.rawDataLogQuery == nil) {
		return;
	}

	NSString *dataToLog = [NSString stringWithFormat:@"<< %@", data];

	[self rawDataLog:dataToLog];
}

- (void)rawDataLogIncomingTraffic:(NSString *)data
{
	NSParameterAssert(data != nil);

	if (self.rawDataLogQuery == nil) {
		return;
	}

	NSString *dataToLog = [NSString stringWithFormat:@">> %@", data];

	[self rawDataLog:dataToLog];
}

@end

NS_ASSUME_NONNULL_END
