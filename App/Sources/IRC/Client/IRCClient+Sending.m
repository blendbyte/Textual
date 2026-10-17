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

	string = [self lineByLabelingLine:string];

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
	IRCTreeItem *destination = TVCMainWindow.currentWindow.selectedItem;

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

	/* Several lines, or one too long for a line, as one message where the
	 server takes them (draft/multiline) */
	if ([self sendMultilineText:lines asCommand:command destination:destination]) {
		return;
	}

	/* Warn if the split value is above 4 lines or if the total string 
	 length exceeds TXMaximumIRCBodyLength times 4. */
	if (lines.count > 4 || (stringIn.length > (TXMaximumIRCBodyLength * 4))) {
		if ([self confirmSendingLongText:stringIn asCommand:command destination:destination] == NO) {
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

/* Text that becomes many messages: send it (YES), not (NO), or, where text can
 go up (9.18 D), as a link instead (NO here; the link is sent once it's up) */
- (BOOL)confirmSendingLongText:(NSAttributedString *)text asCommand:(IRCRemoteCommand)command destination:(IRCTreeItem *)destination
{
	NSParameterAssert(text != nil);
	NSParameterAssert(destination != nil);

	NSString *linkDestination = ((destination.isClient) ? nil : self.textUploadDestinationDescription);

	if (linkDestination == nil) {
		return [TDCAlert modalAlertWithMessage:TXTLS(@"IRC[lql-8i]")
										 title:TXTLS(@"IRC[u4c-7i]")
								 defaultButton:TXTLS(@"Prompts[mvh-ms]")
							   alternateButton:TXTLS(@"Prompts[99q-gg]")
								suppressionKey:@"input_text_possible_flood_warning"
							   suppressionText:nil];
	}

	NSString *body = [NSString stringWithFormat:@"%@\n\n%@", TXTLS(@"IRC[lql-8i]"), TXTLS(@"IRC[pst-n1]", linkDestination)];

	TDCAlertResponse response = [TDCAlert modalAlertWithMessage:body
														   title:TXTLS(@"IRC[u4c-7i]")
												   defaultButton:TXTLS(@"Prompts[mvh-ms]")
												 alternateButton:TXTLS(@"Prompts[99q-gg]")
													 otherButton:TXTLS(@"IRC[pst-b1]")
												  suppressionKey:@"input_text_possible_flood_warning"
												 suppressionText:nil
												   accessoryView:nil
											 suppressionResponse:NULL];

	if (response == TDCAlertResponseOther) {
		[TVCMainWindow.currentWindow sendText:text.string asLinkOnClient:self toItem:destination asCommand:command];

		return NO;
	}

	return (response == TDCAlertResponseDefault);
}

/* NO when the lines can't go as a multi-line message: no draft/multiline, an
 action, the console, a command among them, or one line that fits */
- (BOOL)sendMultilineText:(NSArray<NSAttributedString *> *)lines asCommand:(IRCRemoteCommand)command destination:(IRCTreeItem *)destination
{
	NSParameterAssert(lines != nil);
	NSParameterAssert(destination != nil);

	if (self.multilineUsable == NO || destination.isClient || command == IRCRemoteCommandPrivmsgAction) {
		return NO;
	}

	IRCChannel *channel = (IRCChannel *)destination;

	if (channel.isUtility) {
		return NO;
	}

	/* "//text" sends "/text" */
	NSMutableArray<NSAttributedString *> *textLines = [NSMutableArray arrayWithCapacity:lines.count];

	for (NSAttributedString *line in lines) {
		NSString *lineString = line.string;

		if ([lineString hasPrefix:@"//"]) {
			[textLines addObject:[line attributedSubstringFromIndex:1]];
		} else if ([lineString hasPrefix:@"/"] && lineString.length > 1) {
			return NO;
		} else {
			[textLines addObject:line];
		}
	}

	BOOL isNotice = (command == IRCRemoteCommandNotice);

	NSString *commandToSend = ((isNotice) ? @"NOTICE" : @"PRIVMSG");

	TVCLogLineType lineType = ((isNotice) ? TVCLogLineTypeNotice : TVCLogLineTypePrivateMessage);

	NSArray *batches = [self multilineBatchesForLines:textLines target:channel.name lineType:lineType];

	if (batches == nil) {
		return NO;
	}

	/* More than the server takes in one message: several, after the usual warning */
	if (batches.count > 1) {
		NSAttributedString *text = [[NSAttributedString alloc] initWithString:[[lines valueForKey:@"string"] componentsJoinedByString:@"\n"]];

		if ([self confirmSendingLongText:text asCommand:command destination:destination] == NO) {
			return YES;
		}
	}

	BOOL printLocally = ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] == NO);

	for (NSArray<IRCClientMultilinePart *> *batch in batches) {
		/* A reply: the first message answers it */
		NSString *replyMsgid = self.outgoingReplyMsgid;

		/* Remembered until the server takes or refuses it */
		NSString *text = [self.class multilineTextOfParts:batch];

		IRCClientOutgoingMessage *outgoing = [self outgoingMessageWithText:text target:channel.name command:commandToSend lineType:lineType channel:channel];

		if (printLocally) {
			outgoing.printedLocally = YES;

			[self printOutgoingMessage:outgoing usingBlock:^{
				[self print:text
						 by:self.userNickname
				  inChannel:channel
					 asType:lineType
					command:commandToSend
				 receivedAt:[NSDate date]];
			}];
		}

		[self sendOutgoingMessage:outgoing usingBlock:^{
			[self sendMultilineBatch:batch command:commandToSend target:channel.name replyTo:replyMsgid];
		}];

		self.outgoingReplyMsgid = nil;
	}

	NSMutableArray *lineStrings = [NSMutableArray arrayWithCapacity:textLines.count];

	for (NSAttributedString *line in textLines) {
		[lineStrings addObject:line.string];
	}

	[self processBundlesUserMessage:[lineStrings componentsJoinedByString:@"\n"] command:commandToSend inChannel:channel];

	return YES;
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
		[self sendTextLine:line
			 asCommand:commandToSend
			  lineType:lineType
		 toDestination:channel.name
			   printIn:channel
		printAsCommand:commandToSend];
	}

	[self processBundlesUserMessage:string.string command:commandToSend inChannel:channel];
}

/* Sends one line of text to a channel or user, split into as many messages
 as the server allows, and shows each in the channel (if there is one)
 unless the server echoes it back */
- (void)sendTextLine:(NSAttributedString *)line asCommand:(NSString *)command lineType:(TVCLogLineType)lineType toDestination:(NSString *)destinationName printIn:(nullable IRCChannel *)channel printAsCommand:(NSString *)printCommand
{
	NSParameterAssert(line != nil);
	NSParameterAssert(command != nil);
	NSParameterAssert(destinationName != nil);
	NSParameterAssert(printCommand != nil);

	NSMutableAttributedString *lineMutable = [line mutableCopy];

	while (lineMutable.length > 0)
	{
		NSString *message = [lineMutable stringFormattedForChannel:destinationName onClient:self withLineType:lineType];

		/* Remembered until the server takes or refuses it (failed sends) */
		IRCClientOutgoingMessage *outgoing = nil;

		if (channel) {
			outgoing = [self outgoingMessageWithText:message target:destinationName command:printCommand lineType:lineType channel:channel];
		}

		if (channel && [self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] == NO) {
			outgoing.printedLocally = YES;

			[self printOutgoingMessage:outgoing usingBlock:^{
				[self print:message
						 by:self.userNickname
				  inChannel:channel
					 asType:lineType
					command:printCommand
				 receivedAt:[NSDate date]];
			}];
		}

		if (lineType == TVCLogLineTypeAction) {
			message = [NSString stringWithFormat:@"%cACTION %@%c", 0x01, message, 0x01];
		}

		/* A reply: the first message (of a line split in several) answers it */
		NSString *replyMsgid = self.outgoingReplyMsgid;

		self.outgoingReplyMsgid = nil;

		void (^sendMessage)(void) = ^{
			if (replyMsgid) {
				NSString *lineToSend = [IRCSendingMessage stringWithCommand:command arguments:@[destinationName, message]];

				[self sendLine:[NSString stringWithFormat:@"@+reply=%@ %@", replyMsgid.encodedMessageTagString, lineToSend]];
			} else {
				[self send:command, destinationName, message, nil];
			}
		};

		if (outgoing) {
			[self sendOutgoingMessage:outgoing usingBlock:sendMessage];
		} else {
			sendMessage();
		}
	}
}

#pragma mark -
#pragma mark Replies

- (nullable NSString *)outgoingReplyMsgid
{
	return self.outgoingReplyMsgidValue;
}

- (void)setOutgoingReplyMsgid:(nullable NSString *)outgoingReplyMsgid
{
	self.outgoingReplyMsgidValue = ((self.canSendReplies) ? [IRCMessage validatedMessageIdentifier:outgoingReplyMsgid] : nil);
}

- (void)updateMessageActionsInViews
{
	for (IRCChannel *channel in self.channelList) {
		[channel.viewController updateMessageActions];
	}
}

- (BOOL)canSendReplies
{
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMessageTags] &&
			[self.supportInfo isClientTagAllowed:@"reply"]);
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
	IRCChannel *channel = [TVCMainWindow.currentWindow selectedChannelOn:self];

	if (channel == nil) {
		return;
	}

	[self sendPrivmsg:message toChannel:channel];
}

- (void)sendCTCPQuery:(NSString *)nickname command:(NSString *)command text:(nullable NSString *)text
{
	[self _sendCTCP:command text:text to:nickname as:@"PRIVMSG"];
}

- (void)sendCTCPReply:(NSString *)nickname command:(NSString *)command text:(nullable NSString *)text
{
	[self _sendCTCP:command text:text to:nickname as:@"NOTICE"];
}

/* A query goes out as PRIVMSG, a reply as NOTICE */
- (void)_sendCTCP:(NSString *)command text:(nullable NSString *)text to:(NSString *)nickname as:(NSString *)messageCommand
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

	[self send:messageCommand, nickname, message, nil];
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
