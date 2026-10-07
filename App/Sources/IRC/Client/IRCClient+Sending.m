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

@implementation IRCClient (Sending)

#pragma mark -
#pragma mark Send Raw Data

- (void)sendLine:(NSString *)string
{
	NSParameterAssert(string != nil);

	if (self.isConnected == NO) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[6rj-2r]")];

		return;
	}

	[self.socket sendLine:string];

	worldController().bandwidthOut += string.length;

	worldController().messagesSent += 1;
}

- (void)send:(NSString *)string arguments:(NSArray<NSString *> *)arguments
{
	NSParameterAssert(string != nil);
	NSParameterAssert(arguments != nil);

	NSString *stringToSend = [IRCSendingMessage stringWithCommand:string arguments:arguments];

	[self sendLine:stringToSend];
}

- (void)send:(NSString *)string, ...
{
	NSParameterAssert(string != nil);

	NSMutableArray<NSString *> *argumentsOut = [NSMutableArray array];

	va_list argumentsIn;
	va_start(argumentsIn, string);

	NSString *argumentInString = nil;

	while ((argumentInString = va_arg(argumentsIn, NSString *))) {
		[argumentsOut addObject:argumentInString];
	}

	va_end(argumentsIn);

	[self send:string arguments:argumentsOut];
}

#pragma mark -
#pragma mark Sending Text

- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command
{
	IRCTreeItem *destination = mainWindow().selectedItem;

	[self inputText:string asCommand:command destination:destination];
}

- (void)inputText:(id)string destination:(IRCTreeItem *)destination
{
	[self inputText:string asCommand:IRCRemoteCommandPrivmsg destination:destination];
}

- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command destination:(IRCTreeItem *)destination
{
	NSParameterAssert(string != nil);
	NSParameterAssert(destination != nil);

	if (self.isTerminating) {
		return;
	}

	BOOL inputIsNSString = [string isKindOfClass:[NSString class]];

	if (inputIsNSString == NO && [string isKindOfClass:[NSAttributedString class]] == NO) {
		NSAssert(NO, @"'string' must be NSString or NSAttributedString");
	}

	if (command != IRCRemoteCommandPrivmsg &&
		command != IRCRemoteCommandPrivmsgAction &&
		command != IRCRemoteCommandNotice)
	{
		NSAssert(NO, @"Bad 'command' value");
	}

	if ([string length] == 0) {
		return;
	}

	NSAttributedString *stringIn = nil;

	if (inputIsNSString) {
		stringIn = [NSAttributedString attributedStringWithString:string];
	} else {
		stringIn = string;
	}

	NSArray *lines = ((NSAttributedString *)stringIn).splitIntoLines;

	/* Warn if the split value is above 4 lines or if the total string 
	 length exceeds TXMaximumIRCBodyLength times 4. */
	if (lines.count > 4 || (stringIn.length > (TXMaximumIRCBodyLength * 4))) {
		BOOL continueInput = [TDCAlert modalAlertWithMessage:TXTLS(@"IRC[lql-8i]")
													   title:TXTLS(@"IRC[u4c-7i]")
											   defaultButton:TXTLS(@"Prompts[mvh-ms]")
											 alternateButton:TXTLS(@"Prompts[99q-gg]")
											  suppressionKey:@"input_text_possible_flood_warning"
											 suppressionText:nil];

		if (continueInput == NO) {
			return;
		}
	}

	for (__strong NSAttributedString *line in lines) {
		NSString *lineString = line.string;

		BOOL isPrefixed = [lineString hasPrefix:@"/"];

		if (destination.isClient) {
			if (isPrefixed) {
				line = [line attributedSubstringFromIndex:1];
			}

			[self sendCommand:line];

			continue;
		}

		NSUInteger lineLength = line.length;

		IRCChannel *channel = (IRCChannel *)destination;

		if (isPrefixed && [lineString hasPrefix:@"//"] == NO && lineLength > 1) {
			line = [line attributedSubstringFromIndex:1];

			[self sendCommand:line];
		} else {
			if (isPrefixed && lineLength > 1) {
				line = [line attributedSubstringFromIndex:1];
			}

			[self sendText:line asCommand:command toChannel:channel];
		}
	}
}

- (void)sendText:(NSAttributedString *)string asCommand:(IRCRemoteCommand)command toChannel:(IRCChannel *)channel withEncryption:(BOOL)encryptText
{
	[self sendText:string asCommand:command toChannel:channel];
}

- (void)sendText:(NSAttributedString *)string asCommand:(IRCRemoteCommand)command toChannel:(IRCChannel *)channel
{
	NSParameterAssert(string != nil);
	NSParameterAssert(channel != nil);

	if (string.length == 0) {
		return;
	}

	if (channel.isUtility) {
		[self printDebugInformation:TXTLS(@"IRC[z2r-sd]") inChannel:channel];

		return;
	}

	NSString *commandToSend = nil;

	TVCLogLineType lineType = TVCLogLineTypeUndefined;

	if (command == IRCRemoteCommandPrivmsg) {
		commandToSend = @"PRIVMSG";

		lineType = TVCLogLineTypePrivateMessage;
	} else if (command == IRCRemoteCommandPrivmsgAction) {
		commandToSend = @"PRIVMSG";

		lineType = TVCLogLineTypeAction;
	} else if (command == IRCRemoteCommandNotice) {
		commandToSend = @"NOTICE";

		lineType = TVCLogLineTypeNotice;
	}

	NSParameterAssert(lineType != TVCLogLineTypeUndefined);

	NSArray *lines = string.splitIntoLines;

	for (NSAttributedString *line in lines) {
		NSMutableAttributedString *lineMutable = [line mutableCopy];

		while (lineMutable.length > 0)
		{
			NSString *message = [lineMutable stringFormattedForChannel:channel.name onClient:self withLineType:lineType];

			if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] == NO) {
				[self print:message
						 by:self.userNickname
				  inChannel:channel
					 asType:lineType
					command:commandToSend
				 receivedAt:[NSDate date]];
			}

			if (lineType == TVCLogLineTypeAction) {
				message = [NSString stringWithFormat:@"%cACTION %@%c", 0x01, message, 0x01];
			}

			[self send:commandToSend, channel.name, message, nil];
		}
	}

	[self processBundlesUserMessage:string.string command:commandToSend];
}

- (void)sendPrivmsg:(NSString *)message toChannel:(IRCChannel *)channel
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self sendText:[NSAttributedString attributedStringWithString:message]
			 asCommand:IRCRemoteCommandPrivmsg
			 toChannel:channel];
	});
}

- (void)sendAction:(NSString *)message toChannel:(IRCChannel *)channel
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self sendText:[NSAttributedString attributedStringWithString:message]
			 asCommand:IRCRemoteCommandPrivmsgAction
			 toChannel:channel];
	});
}

- (void)sendNotice:(NSString *)message toChannel:(IRCChannel *)channel
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self sendText:[NSAttributedString attributedStringWithString:message]
			 asCommand:IRCRemoteCommandNotice
			 toChannel:channel];
	});
}

- (void)sendPrivmsgToSelectedChannel:(NSString *)message
{
	IRCChannel *channel = [mainWindow() selectedChannelOn:self];

	if (channel == nil) {
		return;
	}

	[self sendPrivmsg:message toChannel:channel];
}

- (void)sendCTCPQuery:(NSString *)nickname command:(NSString *)command text:(nullable NSString *)text
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(command != nil);

	NSString *stringToSend = nil;

	if (text == nil) {
		stringToSend = command;
	} else {
		stringToSend = [NSString stringWithFormat:@"%@ %@", command, text];
	}

	NSString *message = [NSString stringWithFormat:@"%c%@%c", 0x01, stringToSend, 0x01];

	[self send:@"PRIVMSG", nickname, message, nil];
}

- (void)sendCTCPReply:(NSString *)nickname command:(NSString *)command text:(nullable NSString *)text
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(command != nil);

	NSString *stringToSend = nil;

	if (text == nil) {
		stringToSend = command;
	} else {
		stringToSend = [NSString stringWithFormat:@"%@ %@", command, text];
	}

	NSString *message = [NSString stringWithFormat:@"%c%@%c", 0x01, stringToSend, 0x01];

	[self send:@"NOTICE", nickname, message, nil];
}

- (void)sendCTCPPing:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);
	
	NSString *text = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSince1970]];

	[self sendCTCPQuery:nickname
				command:@"PING"
				   text:text];
}

@end

NS_ASSUME_NONNULL_END
