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

	NSString *modeSymbol = @"";

	if (channel.isChannel) {
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

- (void)printAndLog:(TVCLogLine *)logLine completionBlock:(TVCLogControllerPrintOperationCompletionBlock)completionBlock
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

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted escapeMessage:(BOOL)escapeMessage referenceMessage:(nullable IRCMessage *)referenceMessage completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
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

	NSMutableArray<NSString *> *excludeKeywords = nil;
	NSMutableArray<NSString *> *matchKeywords = nil;
	
	if (matchHighlights) {
		/* Global highlight keywords */
		excludeKeywords = [[TPCPreferences highlightExcludeKeywords] mutableCopy];
		matchKeywords = [[TPCPreferences highlightMatchKeywords] mutableCopy];

		/* Self nickname keyword */
		if ([TPCPreferences highlightMatchingMethod] != TXNicknameHighlightMatchTypeRegularExpression &&
			[TPCPreferences highlightCurrentNickname])
		{
			[matchKeywords addObjectWithoutDuplication:localNickname];
		}

		/* Client/channel specific keywords */
		NSArray *clientHighlightList = self.config.highlightList;

		NSString *channelId = channel.uniqueIdentifier;

		for (IRCHighlightMatchCondition *e in clientHighlightList) {
			NSString *matchChannelId = e.matchChannelId;
			
			if (matchChannelId.length > 0) {
				if ([matchChannelId isEqualToString:channelId] == NO) {
					continue;
				}
			}
			
			if (e.matchIsExcluded) {
				[excludeKeywords addObjectWithoutDuplication:e.matchKeyword];
			} else {
				[matchKeywords addObjectWithoutDuplication:e.matchKeyword];
			}
		}
	} // matchKeywords

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
		if ([mainWindow() isItemVisible:channel] == NO || mainWindow().mainWindow == NO) {
			if (channel.isUnread == NO &&
				(lineType == TVCLogLineTypePrivateMessage ||
				 lineType == TVCLogLineTypeAction ||
				 lineType == TVCLogLineTypeNotice))
			{
				[channel.viewController mark];
			}
		}
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

- (void)printReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel withSequence:(NSUInteger)sequence
{
	NSParameterAssert(message != nil);

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

	NSString *errorMessage = TXTLS(@"IRC[3yo-gw]", message.commandNumeric, sequenceMessage);

	[self printDebugInformation:errorMessage inChannel:channel asCommand:message.command escapeMessage:YES];
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
	IRCChannel *channel = [mainWindow() selectedChannelOn:self];

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

- (void)printDebugInformationInAllViews:(NSString *)message
{
	[self printDebugInformationInAllViews:message asCommand:TVCLogLineDefaultCommandValue escapeMessage:YES];
}

- (void)printDebugInformationInAllViews:(NSString *)message asCommand:(NSString *)command
{
	[self printDebugInformationInAllViews:message asCommand:command escapeMessage:YES];
}

- (void)printDebugInformationInAllViews:(NSString *)message escapeMessage:(BOOL)escapeMessage
{
	[self printDebugInformationInAllViews:message asCommand:TVCLogLineDefaultCommandValue escapeMessage:escapeMessage];
}

- (void)printDebugInformationInAllViews:(NSString *)message asCommand:(NSString *)command escapeMessage:(BOOL)escapeMessage
{
	for (IRCChannel *channel in self.channelList) {
		[self printDebugInformation:message inChannel:channel asCommand:command escapeMessage:escapeMessage];
	}

	[self printDebugInformationToConsole:message asCommand:command escapeMessage:escapeMessage];
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
