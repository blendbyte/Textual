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

@implementation IRCClient (DCC)

#pragma mark -
#pragma mark File Transfers

- (void)notifyFileTransfer:(TXNotificationType)type nickname:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize requestIdentifier:(NSString *)identifier
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(filename != nil);
	NSParameterAssert(identifier != nil);

	NSString *description = nil;

	switch (type) {
		case TXNotificationTypeFileTransferSendSuccessful:
		{
			description = TXTLS(@"Notifications[fhn-dd]", filename, totalFilesize);

			break;
		}
		case TXNotificationTypeFileTransferReceiveSuccessful:
		{
			description = TXTLS(@"Notifications[oqh-pn]", filename, totalFilesize);

			break;
		}
		case TXNotificationTypeFileTransferSendFailed:
		{
			description = TXTLS(@"Notifications[9r4-cq]", filename);

			break;
		}
		case TXNotificationTypeFileTransferReceiveFailed:
		{
			description = TXTLS(@"Notifications[cqq-ci]", filename);

			break;
		}
		case TXNotificationTypeFileTransferReceiveRequested:
		{
			description = TXTLS(@"Notifications[wik-wq]", filename, totalFilesize);

			break;
		}
		default:
		{
			break;
		}
	}

	NSDictionary *info = @{
	   @"isFileTransferNotification" : @(YES),
	   @"fileTransferUniqueIdentifier" : identifier,
	   @"fileTransferNotificationType" : @(type)
	};

	[self notifyEvent:type lineType:TVCLogLineTypeUndefined target:nil nickname:nickname text:description userInfo:info];
}

- (void)receivedDCCQuery:(IRCMessage *)m text:(NSString *)text ignoreInfo:(nullable IRCAddressBookEntry *)ignoreInfo
{
	NSParameterAssert(m != nil);
	NSParameterAssert(text != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	/* Do not continue if the user has configured an ignore for file transfers */
	if (ignoreInfo.ignoreFileTransferRequests) {
		return;
	}

	/* Do not continue if we are not the target */
	if ([self nicknameIsMyself:[m paramAt:0]] == NO) {
		return;
	}

	/* Record information */
	NSString *sender = m.senderNickname;

	NSMutableString *textMutable = [text mutableCopy];

	NSString *subcommand = textMutable.uppercaseGetToken;

	BOOL isSendRequest = ([subcommand isEqualToString:@"SEND"]);
	BOOL isResumeRequest = ([subcommand isEqualToString:@"RESUME"]);
	BOOL isAcceptRequest = ([subcommand isEqualToString:@"ACCEPT"]);

	if (isSendRequest == NO && isResumeRequest == NO && isAcceptRequest == NO) {
		return;
	}

	NSString *section1 = nil;

	if ([textMutable hasPrefix:@"\""]) {
		section1 = textMutable.tokenInsideQuotes;
	} else {
		section1 = textMutable.token;
	}

	NSString *section2 = textMutable.token;
	NSString *section3 = textMutable.token;
	NSString *section4 = textMutable.token;
	NSString *section5 = textMutable.token;

	/* Trim whitespaces in case someone tries to send blank 
	 spaces in a quoted string for filename. */
	section1 = section1.trim;

	/* Remove T from in front of token if it is there. */
	if (isSendRequest) {
		if ([section5 hasPrefix:@"T"]) {
			section5 = [section5 substringFromIndex:1];
		}
	} else if (isAcceptRequest || isResumeRequest) {
	   if ([section4 hasPrefix:@"T"]) {
			section4 = [section4 substringFromIndex:1];
	   }
	}

	/* Valid values? */
	if ( section1.length == 0 ||
		 section2.length == 0 ||
		(section4.length == 0 && isSendRequest))
	{
		return;
	}

	/* Start data association. */
	NSString *hostAddress = nil;
	NSString *hostPort = nil;
	NSString *filename = nil;
	NSString *filesize = nil;
	NSString *transferToken = nil;

	/* Match data variables. */
	if (isSendRequest)
	{
		/* Get normal information */
		filename = [TDCFileTransferDialogTransferController filenameForOfferedFilename:section1];

		filesize = section4;

		hostPort = section3;

		transferToken = section5;

		/* Translate host address */
		if (section2.numericOnly) {
			long long a = section2.longLongValue;

			NSInteger w = (a & 0xff); a >>= 8;
			NSInteger x = (a & 0xff); a >>= 8;
			NSInteger y = (a & 0xff); a >>= 8;
			NSInteger z = (a & 0xff);

			hostAddress = [NSString stringWithFormat:@"%ld.%ld.%ld.%ld", (long)z, (long)y, (long)x, (long)w];
		} else {
			hostAddress = section2;
		}
	}
	else if (isResumeRequest || isAcceptRequest)
	{
		filename = [TDCFileTransferDialogTransferController filenameForOfferedFilename:section1];

		filesize = section3;

		hostPort = section2;

		transferToken = section4;

		hostAddress = nil;
	}

	if (transferToken && transferToken.length == 0) {
		transferToken = nil;
	}

	/* Important checks */
	if (transferToken.length > 0 && transferToken.numericOnly == NO) {
		LogToConsoleError("Fatal error: Received transfer token that is not a number");

		goto present_error;
	}

	NSInteger hostPortInt = hostPort.integerValue;

	if (hostPortInt == 0 && transferToken == nil) {
		LogToConsoleError("Fatal error: Port cannot be zero without a transfer token");

		goto present_error;
	} else if (hostPortInt < 0 || hostPortInt > TXMaximumTCPPort) {
		LogToConsoleError("Fatal error: Port cannot be less than zero or greater than 65535");

		goto present_error;
	}

	long long filesizeInt = filesize.longLongValue;

	if (filesizeInt <= 0 || filesizeInt > powl(1000, 4)) { // 1 TB
		LogToConsoleError("Fatal error: Filesize is silly");

		goto present_error;
	}

	/* Process individual commands. A reply only ever matches a transfer
	 with the same peer on this connection (by token, otherwise by port),
	 so nobody else can redirect or reposition it. */
	if (isSendRequest) {
		/* DCC SEND <filename> <peer-ip> <port> <filesize> [token] */

		if (transferToken) {
			/* 0 port indicates a new request in reverse DCC */
			if (hostPortInt == 0)
			{
				TDCFileTransferDialogTransferController *e = [[self fileTransferController] fileTransferForClient:self peer:sender isSender:NO token:transferToken port:0];

				/* Clients reuse tokens (HexChat picks from 1-255), so only an unfinished offer counts */
				if (e != nil && e.isStopped == NO) {
					LogToConsoleError("Fatal error: Received reverse DCC request with token '%{public}@' but the token already exists", transferToken);

					goto present_error;
				}

				[self receivedDCCSend:sender
							 filename:filename
							  address:hostAddress
								 port:hostPortInt
							 filesize:filesizeInt
								token:transferToken];

				return;
			}

			/* The reply to our reverse DCC offer */
			TDCFileTransferDialogTransferController *e = [[self fileTransferController] fileTransferForClient:self peer:sender isSender:YES token:transferToken port:0];

			if (e)
			{
				if (e.transferStatus != TDCFileTransferDialogTransferStatusWaitingForReceiverToAccept) {
					LogToConsoleError("Fatal error: Unexpected request to begin transfer");

					goto present_error;
				}

				[e didReceiveSendRequest:hostAddress hostPort:hostPortInt];

				return;
			}
		}
		else // transferToken
		{
			/* Treat as normal DCC request */
			[self receivedDCCSend:sender
						 filename:filename
						  address:hostAddress
							 port:hostPort.integerValue
						 filesize:filesize.longLongValue
							token:nil];

			return;
		}
	}
	else if (isResumeRequest || isAcceptRequest)
	{
		/* RESUME comes from the receiver of our file, ACCEPT from the sender of theirs */
		TDCFileTransferDialogTransferController *e = nil;

		if ((transferToken && hostPortInt == 0) || (transferToken == nil && hostPortInt > 0)) {
			e = [[self fileTransferController] fileTransferForClient:self peer:sender isSender:isResumeRequest token:transferToken port:hostPortInt];
		}

		if (e == nil) {
			LogToConsoleError("Fatal error: Could not locate file transfer that matches resume request");

			goto present_error;
		}

		if ((isResumeRequest && (e.transferStatus != TDCFileTransferDialogTransferStatusWaitingForReceiverToAccept &&
								 e.transferStatus != TDCFileTransferDialogTransferStatusIsListeningAsSender)) ||
			(isAcceptRequest && e.transferStatus != TDCFileTransferDialogTransferStatusWaitingForResumeAccept))
		{
			LogToConsoleError("Fatal error: Bad transfer status");

			goto present_error;
		}

		if (isResumeRequest) {
			[e didReceiveResumeRequest:filesizeInt];
		} else {
			[e didReceiveResumeAccept:filesizeInt];
		}

		return;
	}

	// Report an error
present_error:
	[self print:TXTLS(@"IRC[y3w-la]", sender) by:nil inChannel:nil asType:TVCLogLineTypeDCCFileTransfer command:TVCLogLineDefaultCommandValue];
}

- (void)receivedDCCSend:(NSString *)nickname filename:(NSString *)filename address:(NSString *)address port:(uint16_t)port filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(filename != nil);
	NSParameterAssert(address != nil);

	NSString *message = TXTLS(@"IRC[snf-45]", nickname, filename, totalFilesize);

	[self print:message by:nil inChannel:nil asType:TVCLogLineTypeDCCFileTransfer command:TVCLogLineDefaultCommandValue];

	if ([TPCPreferences fileTransferRequestReplyAction] == TXFileTransferRequestReplyIgnore) {
		return;
	}

	NSString *addedRequest = [[self fileTransferController] addReceiverForClient:self nickname:nickname address:address port:port filename:filename filesize:totalFilesize token:transferToken];

	if (addedRequest == nil) {
		[self print:TXTLS(@"IRC[f7t-lm]", nickname, filename) by:nil inChannel:nil asType:TVCLogLineTypeDCCFileTransfer command:TVCLogLineDefaultCommandValue];

		return;
	}

	[self notifyFileTransfer:TXNotificationTypeFileTransferReceiveRequested nickname:nickname filename:filename filesize:totalFilesize requestIdentifier:addedRequest];
}

- (void)sendFileResume:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	[self _sendFileResumeCommand:@"DCC RESUME" to:nickname port:port filename:filename filesize:totalFilesize token:transferToken];
}

- (void)sendFileResumeAccept:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	[self _sendFileResumeCommand:@"DCC ACCEPT" to:nickname port:port filename:filename filesize:totalFilesize token:transferToken];
}

/* DCC RESUME (asking to continue a transfer) and DCC ACCEPT (agreeing to)
 carry the same arguments */
- (void)_sendFileResumeCommand:(NSString *)command to:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(filename != nil);

	NSString *escapedFilename = [self DCCSendEscapeFilename:filename];

	NSString *stringToSend = nil;

	if (transferToken) {
		stringToSend = [NSString stringWithFormat:@"%@ %hu %lli %@", escapedFilename, port, totalFilesize, transferToken];
	} else {
		stringToSend = [NSString stringWithFormat:@"%@ %hu %lli", escapedFilename, port, totalFilesize];
	}

	[self sendCTCPQuery:nickname command:command text:stringToSend];
}

- (void)sendFile:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(filename != nil);

	NSString *address = [self DCCTransferAddress];

	if (address == nil) {
		return;
	}

	NSString *escapedFilename = [self DCCSendEscapeFilename:filename];

	NSString *stringToSend = nil;

	if (transferToken.length > 0) {
		stringToSend = [NSString stringWithFormat:@"%@ %@ %hu %lli %@", escapedFilename, address, port, totalFilesize, transferToken];
	} else {
		stringToSend = [NSString stringWithFormat:@"%@ %@ %hu %lli", escapedFilename, address, port, totalFilesize];
	}

	[self sendCTCPQuery:nickname command:@"DCC SEND" text:stringToSend];

	NSString *message = TXTLS(@"IRC[ags-s8]", nickname, filename, totalFilesize);

	[self print:message by:nil inChannel:nil asType:TVCLogLineTypeDCCFileTransfer command:TVCLogLineDefaultCommandValue];
}

- (NSString *)DCCSendEscapeFilename:(NSString *)filename
{
	NSParameterAssert(filename != nil);

	NSString *filenameEscaped = filename.safeFilename;

	if ([filenameEscaped contains:@" "] == NO) {
		return filenameEscaped;
	}
	
	/* Escape double quotes because the filename will be wrapped.
	 February 20, 2017: Maybe we should replace the double quote
	 with another character or remove completely? Untested how other
	 clients will handle an escaped double quote. */
	filenameEscaped = [filenameEscaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

	return [NSString stringWithFormat:@"\"%@\"", filenameEscaped];
}

- (nullable NSString *)DCCTransferAddress
{
	NSString *address = [self fileTransferController].IPAddress;

	if (address == nil) {
		return nil;
	}

	if (address.IPv6Address) {
		return address;
	}

	NSArray *addressOctets = [address componentsSeparatedByString:@"."];

	if (addressOctets.count != 4) {
		LogToConsoleError("User configured a silly IP address");

		return nil;
	}

	NSInteger w = [addressOctets[0] integerValue];
	NSInteger x = [addressOctets[1] integerValue];
	NSInteger y = [addressOctets[2] integerValue];
	NSInteger z = [addressOctets[3] integerValue];

	unsigned long long a = 0;

	a |= w; a <<= 8;
	a |= x; a <<= 8;
	a |= y; a <<= 8;
	a |= z;

	return [NSString stringWithFormat:@"%llu", a];
}

@end

NS_ASSUME_NONNULL_END
