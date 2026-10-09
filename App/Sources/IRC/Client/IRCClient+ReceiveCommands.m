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

@implementation IRCClient (ReceiveCommands)

#pragma mark -
#pragma mark Protocol Handlers

- (void)receiveWallops:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	/* WALLOPS are rewritten so that they can be parsed as regular notices */
	NSMutableArray *paramsMutable = [m.params mutableCopy];

	[paramsMutable insertObject:self.userNickname atIndex:0];

	NSString *text = [NSString stringWithFormat:TVCLogLineSpecialNoticeMessageFormat, m.command, paramsMutable[1]];

	paramsMutable[1] = text;

	/* ======================================== */

	IRCMessageMutable *messageMutable = [m mutableCopy];

	messageMutable.command = @"NOTICE";

	messageMutable.params = paramsMutable;

	/* ======================================== */

	[self receivePrivmsgAndNotice:[messageMutable copy]];
}

- (void)receivePrivmsgAndNotice:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 1);

	NSString *text = [m paramAt:1];

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIdentifyCTCP] && ([text hasPrefix:@"+\x01"] || [text hasPrefix:@"-\x01"])) {
		text = [text substringFromIndex:1];
	} else if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIdentifyMsg] && ([text hasPrefix:@"+"] || [text hasPrefix:@"-"])) {
		text = [text substringFromIndex:1];
	}

	TVCLogLineType lineType = TVCLogLineTypePrivateMessage;

	BOOL isPlainText = [m.command isEqualToString:@"PRIVMSG"];

	if ([text hasPrefix:@"\x01"]) {
		text = [text substringFromIndex:1];

		NSInteger closingIndex = [text stringPosition:@"\x01"];

		if (closingIndex >= 0) {
			text = [text substringToIndex:closingIndex];
		}

		if (isPlainText) {
			if ([text hasPrefixIgnoringCase:@"ACTION "]) {
				text = [text substringFromIndex:7];

				lineType = TVCLogLineTypeAction;
			} else {
				lineType = TVCLogLineTypeCTCPQuery;
			}
		} else {
			lineType = TVCLogLineTypeCTCPReply; // notice -> query
		}
	} else if (isPlainText == NO) {
		lineType = TVCLogLineTypeNotice;
	}

	if (lineType == TVCLogLineTypeAction ||
		lineType == TVCLogLineTypePrivateMessage ||
		lineType == TVCLogLineTypeNotice)
	{
		[self receiveText:m lineType:lineType text:text];
	} else if (lineType == TVCLogLineTypeCTCPQuery) {
		[self receiveCTCPQuery:m text:text];
	} else if (lineType == TVCLogLineTypeCTCPReply) {
		[self receiveCTCPReply:m text:text];
	}
}

- (void)receiveText:(IRCMessage *)m lineType:(TVCLogLineType)lineType text:(NSString *)text
{
	NSParameterAssert(m != nil);

	NSParameterAssert(lineType == TVCLogLineTypeAction ||
					  lineType == TVCLogLineTypeActionNoHighlight ||
					  lineType == TVCLogLineTypePrivateMessage ||
					  lineType == TVCLogLineTypePrivateMessageNoHighlight ||
					  lineType == TVCLogLineTypeNotice);

	NSParameterAssert(text != nil);

	NSAssertReturn([m paramsCount] > 1);

	/* Allow empty actions but no other type */
	if (text.length == 0) {
		if (lineType == TVCLogLineTypeAction ||
			lineType == TVCLogLineTypeActionNoHighlight)
		{
			text = @" ";
		} else {
			return;
		}
	}

	/* Process target */
	NSString *target = [m paramAt:0];

	if (target.length == 0) {
		return;
	}

	/* It is possible for a channel to have a user mode character in front
	 of it when the message is being addressed to a specific group of users.
	 For example, "+#channel" as the channel name means that the message is
	 addressed to only the voiced users of #channel. We don't care about this
	 mode but we still have to remove it while also taking into account
	 channels who use a character other than the pound symbol as their prefix. */
	NSString *targetPrefix = [self.supportInfo extractStatusMessagePrefixFromChannelNamed:target];

	if (targetPrefix.length == 1) {
		target = [target substringFromIndex:1];
	}

	/* Perform ignore check */
	IRCAddressBookEntry *ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

	if (ignoreInfo.ignorePublicMessageHighlights) {
		if (lineType == TVCLogLineTypeAction) {
			lineType = TVCLogLineTypeActionNoHighlight;
		} else if (lineType == TVCLogLineTypePrivateMessage) {
			lineType = TVCLogLineTypePrivateMessageNoHighlight;
		}
	}

	if (lineType == TVCLogLineTypeNotice) {
		if (ignoreInfo.ignoreNoticeMessages) {
			return;
		}
	}

	/* Public message (directed at channel) */
	if ([self stringIsChannelName:target]) {
		if (ignoreInfo.ignorePublicMessages) {
			return;
		}

		[self _receiveText_Public:m lineType:lineType target:target text:text];
	}

	/* Private message (from user) */
	else if (m.senderIsServer == NO) {
		if (ignoreInfo.ignorePrivateMessages) {
			return;
		}

		[self _receiveText_Private:m lineType:lineType target:target text:text];
	}

	/* Private message (from server) */
	else {
		[self _receiveText_PrivateServer:m lineType:lineType target:target text:text];
	}
}

- (void)_receiveText_Public:(IRCMessage *)m lineType:(TVCLogLineType)lineType target:(NSString *)target text:(NSString *)text
{
	NSParameterAssert(m != nil);
	NSParameterAssert(target != nil);
	NSParameterAssert(text != nil);

	IRCChannel *channel = [self findChannel:target];

	if (channel == nil) {
		return;
	}

	if ([self chatHistoryShouldSkipMessage:m inChannel:channel]) {
		return;
	}

	NSString *sender = m.senderNickname;

	[self typingEndedByMessageFrom:sender inChannel:channel];

	BOOL isSelfMessage = NO;

	/* Backfilled history includes our own lines */
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] || [self isChatHistoryMessage:m]) {
		isSelfMessage = [self nicknameIsMyself:sender];
	}

	TVCLogControllerPrintOperationCompletionBlock printCompletionBlock = nil;

	BOOL isPlainText = (lineType != TVCLogLineTypeNotice);

	if (isPlainText == NO) {
		/* Completion block for notices */

		printCompletionBlock =
		^(TVCLogControllerPrintOperationContext *context)
		{
			if ([self isSafeToPostNotificationForMessage:m inChannel:channel]) {
				[self notifyPrintedText:TXNotificationTypeChannelNotice lineType:lineType target:channel nickname:sender text:text];
			}
		};
	} else {
		/* Completion block for regular messages */

		printCompletionBlock =
		^(TVCLogControllerPrintOperationContext *context)
		{
			if (isSelfMessage) {
				return;
			}

			BOOL isHighlight = context.highlight;

			BOOL postEvent = YES;

			if ([self isSafeToPostNotificationForMessage:m inChannel:channel]) {
				if (isHighlight) {
					postEvent = [self notifyPrintedText:TXNotificationTypeHighlight lineType:lineType target:channel nickname:sender text:text];
				} else {
					postEvent = [self notifyPrintedText:TXNotificationTypeChannelMessage lineType:lineType target:channel nickname:sender text:text];
				}
			}

			if (postEvent == NO) {
				return;
			}

			if (isHighlight) {
				[self setHighlightStateForChannel:channel];
			}

			[self setUnreadStateForChannel:channel isHighlight:isHighlight];
		};
	}

	/* Ask for permission to print message */
	BOOL printMessage = YES;

	if ([sharedPluginManager() supportsFeature:THOPluginItemSupportedFeatureDidReceivePlainTextMessageEvent]) {
		printMessage = [THOPluginDispatcher receivedText:text
											  authoredBy:m.sender
											 destinedFor:channel
											  asLineType:lineType
												onClient:self
											  receivedAt:m.receivedAt
											wasEncrypted:NO];
	}

	/* Print message */
	if (printMessage) {
		[self print:text
				 by:sender
		  inChannel:channel
			 asType:lineType
			command:m.command
		 receivedAt:m.receivedAt
		isEncrypted:NO
   referenceMessage:m
	completionBlock:printCompletionBlock];
	}

	/* The remaining logic does not apply to notices */
	if (isPlainText == NO) {
		return;
	}

	/* Update weights of user we're talking with */
	IRCChannelUser *senderMember = [channel findMember:sender];

	if (senderMember == nil) {
		return;
	}

	NSString *localNickname = [self.userNickname trimCharacters:@"_"]; // Remove any underscores from around nickname (Guest___ becomes Guest)

	/* If we are mentioned in this piece of text, then update our weight for the user */
	if ([text contains:localNickname]) {
		[senderMember outgoingConversation];
	} else {
		[senderMember conversation];
	}
}

- (void)_receiveText_Private:(IRCMessage *)m lineType:(TVCLogLineType)lineType target:(NSString *)target text:(NSString *)text
{
	NSParameterAssert(m != nil);
	NSParameterAssert(target != nil);
	NSParameterAssert(text != nil);

	NSString *sender = m.senderNickname;

	TVCLogControllerPrintOperationCompletionBlock printCompletionBlock = nil;

	BOOL isPlainText = (lineType != TVCLogLineTypeNotice);

	/* If the self-message CAP is not enabled, we still check if we are on a ZNC
	 based connections because older versions of ZNC combined with the privmsg
	 module need the correct behavior which the self-message CAP evolved into. */
	BOOL isSelfMessage = NO;

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] ||
		[self isCapabilityEnabled:ClientIRCv3SupportedCapabilityZNCSelfMessage] ||
		self.isConnectedToZNC ||
		[self isChatHistoryMessage:m]) // backfilled history includes our own lines
	{
		isSelfMessage = [self nicknameIsMyself:sender];
	}

	/* Does the query for the sender already exist?... */
	IRCChannel *query = nil;

	if (isSelfMessage) {
		query = [self findChannel:target]; // Look for a query related to target, rather than sender
	} else {
		query = [self findChannel:sender];
	}

	BOOL newPrivateMessage = NO;

	if (isPlainText == NO) {
		/* Logic for notices */

		/* Process services */
		if ([sender isEqualToStringIgnoringCase:@"ChanServ"]) {
			[self _receiveText_PrivateNoticeFromChanServ:&query text:&text];
		} else if ([sender isEqualToStringIgnoringCase:@"NickServ"]) {
			[self _receiveText_PrivateNoticeFromNickServ:&query text:&text sender:m.sender];
		}

		/* Determine where to send notice messages */
		if ([TPCPreferences locationToSendNotices] == TXNoticeSendLocationSelectedChannel) {
			query = [mainWindow() selectedChannelOn:self];
		}

		/* Do not create query until after ChanServ notices have been processed
		 so that entry messages do not create a new window. */
		if (query == nil) {
			if ([TPCPreferences locationToSendNotices] == TXNoticeSendLocationQuery) {
//				newPrivateMessage = YES;

				if (isSelfMessage) {
					query = [worldController() createPrivateMessage:target onClient:self];
				} else {
					query = [worldController() createPrivateMessage:sender onClient:self];
				}
			}
		}

		printCompletionBlock =
		^(TVCLogControllerPrintOperationContext *context)
		{
			if (isSelfMessage) {
				return;
			}

			BOOL postEvent = YES;

			if ([self isSafeToPostNotificationForMessage:m inChannel:query]) {
				postEvent = [self notifyPrintedText:TXNotificationTypePrivateNotice lineType:lineType target:query nickname:sender text:text];
			}

			if (postEvent && query != nil) {
				[self setUnreadStateForChannel:query];
			}
		};
	}
	else // NOTICE message
	{
		/* Logic for regular messages */

		if (query == nil) {
			newPrivateMessage = YES;

			if (isSelfMessage) {
				query = [worldController() createPrivateMessage:target onClient:self];
			} else {
				query = [worldController() createPrivateMessage:sender onClient:self];
			}
		}

		printCompletionBlock =
		^(TVCLogControllerPrintOperationContext *context)
		{
			if (isSelfMessage) {
				return;
			}

			BOOL isHighlight = context.highlight;

			BOOL postEvent = YES;

			if ([self isSafeToPostNotificationForMessage:m inChannel:query]) {
				if (isHighlight) {
					postEvent = [self notifyPrintedText:TXNotificationTypeHighlight lineType:lineType target:query nickname:sender text:text];
				} else {
					if (newPrivateMessage) {
						postEvent = [self notifyPrintedText:TXNotificationTypeNewPrivateMessage lineType:lineType target:query nickname:sender text:text];
					} else {
						postEvent = [self notifyPrintedText:TXNotificationTypePrivateMessage lineType:lineType target:query nickname:sender text:text];
					}
				}
			}

			if (postEvent == NO) {
				return;
			}

			if (isHighlight) {
				[self setHighlightStateForChannel:query];
			}

			[self setUnreadStateForChannel:query isHighlight:isHighlight];
		};
	}

	if (query && [self chatHistoryShouldSkipMessage:m inChannel:query]) {
		return;
	}

	if (query) {
		[self typingEndedByMessageFrom:sender inChannel:query];
	}

	/* Ask for permission to print message */
	BOOL printMessage = YES;

	if ([sharedPluginManager() supportsFeature:THOPluginItemSupportedFeatureDidReceivePlainTextMessageEvent]) {
		printMessage = [THOPluginDispatcher receivedText:text
											  authoredBy:m.sender
											 destinedFor:query
											  asLineType:lineType
												onClient:self
											  receivedAt:m.receivedAt
											wasEncrypted:NO];
	}

	/* Print message */
	if (printMessage) {
		[self print:text
				 by:sender
		  inChannel:query
			 asType:lineType
			command:m.command
		 receivedAt:m.receivedAt
		isEncrypted:NO
   referenceMessage:m
	completionBlock:printCompletionBlock];
	}

	/* The remaining logic does not apply to notices */
	if (isPlainText == NO) {
		return;
	}

	/* Update query status (a message, unlike a notice, always has a query) */
	if (query != nil && query.isActive == NO) {
		[query activate];

		[mainWindow() reloadTreeItem:query];
	}
}

- (void)_receiveText_PrivateNoticeFromChanServ:(IRCChannel **)target text:(NSString **)text
{
	NSParameterAssert(target != NULL);
	NSParameterAssert(text != NULL);

	NSString *textIn = (*text);

	/* Forward entry messages to the channel they are associated with. */
	/* Format we are going for: -ChanServ- [#channelname] blah blah... */
	NSInteger spacePosition = [textIn stringPosition:@" "];

	if ([textIn hasPrefix:@"["] == NO || spacePosition < 4) {
		return;
	}

	NSString *textHead = [textIn substringToIndex:spacePosition];

	if ([textHead hasSuffix:@"]"] == NO) {
		return;
	}

	textHead = [textHead substringToIndex:(textHead.length - 1)]; // Remove the ]
	textHead = [textHead substringFromIndex:1]; // Remove the [

	if ([self stringIsChannelName:textHead] == NO) {
		return;
	}

	IRCChannel *channel = [self findChannel:textHead];

	if (channel == nil) {
		return;
	}

	*text = [textIn substringFromIndex:(textHead.length + 2)]; // Remove the [#channelname] from the text

	*target = channel;
}

/* Anyone can use the nickname "NickServ" (during a services outage, for example),
 so the password is only sent when the notice comes from the network's services
 host. The host is the server's "NickServ Host" setting, or the built-in host for
 known networks (StaticStore.plist). Logging in with SASL avoids NickServ entirely. */
+ (nullable NSString *)knownNickServHostForServerAddress:(nullable NSString *)serverAddress
{
	if (serverAddress.length == 0) {
		return nil;
	}

	NSDictionary<NSString *, NSString *> *knownHosts = [TPCResourceManager dictionaryFromResources:@"StaticStore" key:@"IRCClient NickServ Hosts by Network"];

	NSString *address = serverAddress.lowercaseString;

	for (NSString *networkDomain in knownHosts) {
		if ([address isEqualToString:networkDomain] ||
			[address hasSuffix:[@"." stringByAppendingString:networkDomain]])
		{
			return knownHosts[networkDomain];
		}
	}

	return nil;
}

- (nullable NSString *)nickServHostForVerification
{
	NSString *configuredHost = self.config.nickServHost.trim;

	if (configuredHost.length > 0) {
		return configuredHost;
	}

	NSString *knownHost = [IRCClient knownNickServHostForServerAddress:self.server.serverAddress];

	if (knownHost == nil) {
		knownHost = [IRCClient knownNickServHostForServerAddress:self.serverAddress];
	}

	return knownHost;
}

- (BOOL)nickServSenderIsVerified:(IRCPrefix *)sender
{
	NSString *expectedHost = self.nickServHostForVerification;

	/* Trust on first use: with no host configured or built in, the first
	 NickServ that asks to identify is trusted, and its host is saved as the
	 server's NickServ Host (visible in Server Properties), so a NickServ
	 from any other host later is refused. */
	if (expectedHost == nil) {
		NSString *senderHost = sender.address;

		if (senderHost.length == 0) {
			return NO;
		}

		IRCClientConfigMutable *config = [self.config mutableCopy];

		config.nickServHost = senderHost;

		[self updateConfig:config];

		[worldController() save];

		[self printDebugInformationToConsole:TXTLS(@"IRC[n5v-h3]", sender.hostmask, senderHost)];

		return YES;
	}

	if ([sender.address isEqualToStringIgnoringCase:expectedHost]) {
		return YES;
	}

	/* Say why the password was not sent, once per connection */
	if (self.nickServVerificationWarningShown == NO) {
		self.nickServVerificationWarningShown = YES;

		[self printDebugInformationToConsole:TXTLS(@"IRC[n5v-h2]", sender.hostmask, expectedHost)];
	}

	return NO;
}

- (void)_receiveText_PrivateNoticeFromNickServ:(IRCChannel **)target text:(NSString **)text sender:(IRCPrefix *)sender
{
	NSParameterAssert(target != NULL);
	NSParameterAssert(text != NULL);
	NSParameterAssert(sender != nil);

	self.serverHasNickServ = YES;

	NSString *textIn = nil;

	if ([TPCPreferences removeAllFormatting] == NO) {
		textIn = (*text).stripIRCEffects;
	} else {
		textIn = (*text);
	}

	/* If we are not waiting for a response from NickServ, 
	 then try sending our password if that's what it requested. */
	if (self.isWaitingForNickServ == NO) {
		NSString *nicknamePassword = self.config.nicknamePassword;

		if (nicknamePassword.length == 0) {
			return;
		}

		for (NSString *token in self.nickServSupportedNeedIdentificationTokens) {
			if ([textIn containsIgnoringCase:token] == NO) {
				continue;
			}

			/* Already logged in with SASL: never send the password to NickServ */
			if (self.isAuthenticatedWithSASL) {
				break;
			}

			/* A notice from the wrong host may be a spoof ahead of the real
			 NickServ: autojoin keeps waiting for identification then, so
			 channels aren't joined before it (e.g. before a cloak) */
			if ([self nickServSenderIsVerified:sender] == NO) {
				break;
			}

			// Send password
			if ([self.serverAddress hasSuffix:@".dal.net"])
			{
				NSString *message = [NSString stringWithFormat:@"IDENTIFY %@", nicknamePassword];

				[self send:@"PRIVMSG", @"NickServ@services.dal.net", message, nil];
			}
			else if (self.config.sendAuthenticationRequestsToUserServ)
			{
				NSString *message = [NSString stringWithFormat:@"login %@ %@", self.config.nickname, nicknamePassword];

				[self send:@"PRIVMSG", @"userserv", message, nil];
			}
			else
			{
				NSString *message = [NSString stringWithFormat:@"IDENTIFY %@", nicknamePassword];

				[self send:@"PRIVMSG", @"NickServ", message, nil];
			}

			// Reset properties
			self.isWaitingForNickServ = YES;

			self.userIsIdentifiedWithNickServ = NO;

			break;
		}

		return;
	}

	/* Scan for messages telling us that we are now identified */
	for (NSString *token in self.nickServSupportedSuccessfulIdentificationTokens) {
		if ([textIn containsIgnoringCase:token] == NO) {
			continue;
		}

		self.isWaitingForNickServ = NO;

		self.userIsIdentifiedWithNickServ = YES;

		if (self.config.autojoinWaitsForNickServ) {
			[self performAutoJoin];
		}

		break;
	}
}

- (void)_receiveText_PrivateServer:(IRCMessage *)m lineType:(TVCLogLineType)lineType target:(NSString *)target text:(NSString *)text
{
	NSParameterAssert(m != nil);
	NSParameterAssert(target != nil);
	NSParameterAssert(text != nil);

	NSString *sender = m.senderNickname;

	BOOL isPlainText = (lineType != TVCLogLineTypeNotice);

	IRCChannel *query = nil;

	/* For notices, send to a query if a query for the server already exists.
	 Otherwise, it is always sent to the console. Plain text messages always
	 create a new query but does not post a notification. */
	if (isPlainText == NO) {
		query = [self findChannel:sender];
	} else { // NOTICE message
		query = [self findChannelOrCreate:sender isPrivateMessage:YES];
	}

	/* Print message */
	BOOL printMessage = YES;

	if ([sharedPluginManager() supportsFeature:THOPluginItemSupportedFeatureDidReceivePlainTextMessageEvent]) {
		printMessage = [THOPluginDispatcher receivedText:text
											  authoredBy:m.sender
											 destinedFor:query
											  asLineType:lineType
												onClient:self
											  receivedAt:m.receivedAt
											wasEncrypted:NO];
	}

	if (printMessage) {
		[self print:text
				 by:sender
		  inChannel:query
			 asType:lineType
			command:m.command
		 receivedAt:m.receivedAt
		isEncrypted:NO];
	}

	/* Disconnect and reconnect if message is believed to be from an irssi proxy */
	/* If we do not do this, the internal state of the client becomes fucked all around */
	if ([sender hasSuffix:@".proxy"] && [text isEqualToString:@"Connected to server"]) {
		[self disconnectThen:^(IRCClient *client) {
			[client printDebugInformationToConsole:TXTLS(@"IRC[5i4-qq]")];

			[client connect:IRCClientConnectModeReconnect];
		}];
	}
}

- (void)receiveCTCPQuery:(IRCMessage *)m text:(NSString *)text
{
	NSParameterAssert(m != nil);
	NSParameterAssert(text != nil);

	NSString *sender = m.senderNickname;

	BOOL myself = [self nicknameIsMyself:sender];

	/* Context */
	NSMutableString *textMutable = [text mutableCopy];

	NSString *command = textMutable.uppercaseGetToken;

	if (command.length == 0) {
		return;
	}

	IRCAddressBookEntry *ignoreInfo = nil;

	if (myself) {
		/* Ignore messages echoed back to ourselves, except the lag check,
		 which is sent to ourselves on purpose (R3.11) */
		if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] &&
			[command isEqualToString:@"LAGCHECK"] == NO)
		{
			return;
		}
	} else {
		/* Find ignore for sender and possibly exit method */
		ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

		if (ignoreInfo.ignoreClientToClientProtocol) {
			return;
		}
	}

	/* Lag check responses should only ever come from ourselves so we
	 let it through. The method we call into already has a built-in
	 check for myself so no need to wrap an if statement here. */
	if ([command isEqualToString:@"LAGCHECK"]) {
		[self receiveCTCPLagCheckQuery:m text:textMutable];

		return;
	}

	/* Only queries sent to us are answered. One sent to a channel (also as
	 @#channel or +#channel, or to a server mask) would make everyone in it
	 reply at once. ACTION never reaches this method. */
	if ([self nicknameIsMyself:[m paramAt:0]] == NO) {
		return;
	}

	/* Ignore query if the user has configured Textual to do so */
	if ([TPCPreferences replyToCTCPRequests] == NO) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[bg3-h2]", command, sender)];

		return;
	}

	/* Process DCC requests elsewhere */
	if ([command isEqualToString:@"DCC"]) {
		[self receivedDCCQuery:m text:textMutable ignoreInfo:ignoreInfo];

		return;
	}

	/* Queries beyond the limit are dropped silently so that a flood
	 neither fills the console nor delays our own messages. */
	if ([self CTCPReplyIsWithinLimitForSender:m.senderAddress] == NO) {
		return;
	}

	/* Print message */
	IRCChannel *printTarget = nil;

	if ([TPCPreferences locationToSendNotices] == TXNoticeSendLocationSelectedChannel) {
		printTarget = [mainWindow() selectedChannelOn:self];
	}

	NSString *messageToPrint = TXTLS(@"IRC[6o8-eu]", command, sender);

	[self print:messageToPrint
			 by:nil
	  inChannel:printTarget
		 asType:TVCLogLineTypeCTCPQuery
		command:m.command
	 receivedAt:m.receivedAt];

	/* CLIENTINFO command */
	if ([command isEqualToString:@"CLIENTINFO"])
	{
		[self sendCTCPReply:sender command:command text:TXTLS(@"IRC[jer-ju]")];
	}

	/* FINGER command */
	else if ([command isEqualToString:@"FINGER"])
	{
		[self sendCTCPReply:sender command:command text:TXTLS(@"IRC[en6-mw]")];
	}

	/* PING command */
	else if ([command isEqualToString:@"PING"])
	{
		if (textMutable.length > 50) {
			LogToConsoleFault("Ignoring PING query that exceeds 50 bytes");

			return;
		}

		[self sendCTCPReply:sender command:command text:textMutable];
	}

	/* TIME command */
	else if ([command isEqualToString:@"TIME"])
	{
		NSDateFormatter *dateFormatter = TXSharedISOStandardDateFormatter();

		NSString *text = [dateFormatter stringFromDate:[NSDate date]];

		[self sendCTCPReply:sender command:command text:text];
	}

	/* USERINFO command */
	else if ([command isEqualToString:@"USERINFO"])
	{
		[self sendCTCPReply:sender command:command text:self.config.realName];
	}

	/* VERSION command */
	else if ([command isEqualToString:@"VERSION"])
	{
		NSString *fakeVersion = [TPCPreferences masqueradeCTCPVersion];

		if (fakeVersion.length > 0) {
			[self sendCTCPReply:sender command:command text:fakeVersion];

			return;
		}

		NSString *applicationName = [TPCApplicationInfo applicationNameWithoutVersion];
		NSString *versionShort = [TPCApplicationInfo applicationVersionShort];

		NSString *text = TXTLS(@"IRC[vzu-u7]", applicationName, versionShort);

		[self sendCTCPReply:sender command:command text:text];
	}
}

/* At most _CTCPReplyLimit replies per interval on this connection, and at
 most _CTCPReplyLimitPerSender to any one host, so that one sender can't use
 up the replies for everyone else */
- (BOOL)CTCPReplyIsWithinLimitForSender:(nullable NSString *)senderAddress
{
	NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;

	if ((now - self.CTCPReplyCountStarted) >= _CTCPReplyLimitInterval || self.CTCPReplyCountBySender == nil) {
		self.CTCPReplyCountStarted = now;

		self.CTCPReplyCount = 0;

		self.CTCPReplyCountBySender = [NSMutableDictionary dictionary];
	}

	if (self.CTCPReplyCount >= _CTCPReplyLimit) {
		return NO;
	}

	NSString *senderKey = ((senderAddress) ? senderAddress.lowercaseString : @"");

	NSUInteger senderCount = self.CTCPReplyCountBySender[senderKey].unsignedIntegerValue;

	if (senderCount >= _CTCPReplyLimitPerSender) {
		return NO;
	}

	self.CTCPReplyCountBySender[senderKey] = @(senderCount + 1);

	self.CTCPReplyCount += 1;

	return YES;
}

- (void)receiveCTCPLagCheckQuery:(IRCMessage *)m text:(NSString *)text
{
	NSParameterAssert(m != nil);

	if ([self messageIsFromMyself:m] == NO) {
		return;
	}
	
	NSDictionary *lagCheckContext = [text formDataUsingSeparator:@"&"];
	
	if (lagCheckContext.count == 0) {
		return;
	}

	NSString *connectionIdentifier = lagCheckContext[@"connection"];
	
	if ([connectionIdentifier isEqualToString:self.socket.uniqueIdentifier] == NO) {
		/* We check which connection this event is linked to so that
		 we ignore events after reconnects (such as from a bouncer). */

		return;
	}
	
	NSTimeInterval firstTime = [lagCheckContext doubleForKey:@"time"];

	/* With echo-message a query to ourselves arrives twice (delivered and echoed): answer it once */
	if (firstTime == self.lastAnsweredLagCheckTime) {
		return;
	}

	self.lastAnsweredLagCheckTime = firstTime;

	double delta = (([NSDate timeIntervalSince1970] - firstTime) * 1000);
	
	NSString *ratingString = nil;
	
	if (delta < 10) { // Yeah, okay…
		ratingString = TXTLS(@"IRC[58g-m9]");
	} else if (delta > 10 && delta <= 25) { // Are you plugged into the server?
		ratingString = TXTLS(@"IRC[0jp-93]");
	} else if (delta > 25 && delta <= 100) { // Pretty good
		ratingString = TXTLS(@"IRC[yym-8y]");
	} else if (delta > 100 && delta <= 125) { // Not bad
		ratingString = TXTLS(@"IRC[mic-qe]");
	} else if (delta > 125 && delta <= 200) { // Okay
		ratingString = TXTLS(@"IRC[mqg-wi]");
	} else if (delta > 200 && delta <= 225) { // Needs work
		ratingString = TXTLS(@"IRC[ut8-7s]");
	} else if (delta > 225 && delta <= 300) { // Slow
		ratingString = TXTLS(@"IRC[8fo-ss]");
	} else if (delta > 300) { // Very Slow
		ratingString = TXTLS(@"IRC[4oc-p2]");
	}
	
	NSString *message = TXTLS(@"IRC[5bf-jp]", self.serverAddress, delta, ratingString);
	
	NSString *channelName = lagCheckContext[@"channel"];
	
	IRCChannel *channel = nil;
	
	if (channelName) {
		channel = [self findChannel:channelName];
	}

	if (channel) {
		[self sendPrivmsg:message toChannel:channel];
	} else {
		[self printDebugInformation:message];
	}
}

- (void)receiveCTCPReply:(IRCMessage *)m text:(NSString *)text
{
	NSParameterAssert(m != nil);
	NSParameterAssert(text != nil);

	/* Find ignore for sender and possibly exit method */
	IRCAddressBookEntry *ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

	if (ignoreInfo.ignoreClientToClientProtocol) {
		return;
	}

	/* Context */
	NSMutableString *textMutable = [text mutableCopy];

	NSString *sender = m.senderNickname;

	/* Our own replies, echoed back (echo-message) */
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] && [self nicknameIsMyself:sender]) {
		return;
	}

	NSString *command = textMutable.uppercaseGetToken;

	if (command.length == 0) {
		return;
	}

	/* Print message */
	IRCChannel *printTarget = nil;

	if ([TPCPreferences locationToSendNotices] == TXNoticeSendLocationSelectedChannel) {
		printTarget = [mainWindow() selectedChannelOn:self];
	}

	NSString *messageToPrint = nil;

	if ([command isEqualToString:@"PING"]) {
		double delta = ([NSDate timeIntervalSince1970] - textMutable.doubleValue);

		messageToPrint = TXTLS(@"IRC[vy7-pk]", sender, command, delta);
	} else {
		messageToPrint = TXTLS(@"IRC[dri-l7]", sender, command, textMutable);
	}

	[self print:messageToPrint
			 by:nil
	  inChannel:printTarget
		 asType:TVCLogLineTypeCTCPReply
		command:m.command
	 receivedAt:m.receivedAt];
}

/* Whether a join, part, kick, quit, nickname change or mode change by
 someone else is printed: the "show join and leave" preference, then the
 channel's setting, then the user's address book entry, if there is one */
- (BOOL)shouldPrintGeneralEventInChannel:(IRCChannel *)channel addressBookEntry:(nullable IRCAddressBookEntry *)addressBookEntry
{
	NSParameterAssert(channel != nil);

	if ([TPCPreferences showJoinLeave] == NO) {
		return NO;
	}

	if (channel.config.ignoreGeneralEventMessages) {
		return NO;
	}

	if (addressBookEntry) {
		return (addressBookEntry.ignoreGeneralEventMessages == NO);
	}

	return YES;
}

- (void)receiveJoin:(IRCMessage *)m
{
	NSAssertReturn([m paramsCount] > 0);

	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSString *sender = m.senderNickname;

	BOOL myself = [self nicknameIsMyself:sender];

	NSString *channelName = [m paramAt:0];

	IRCChannel *channel = nil;

	if (isPrintOnlyMessage == NO && myself)
	{
		channel = [self findChannelOrCreate:channelName];

		if (channel.isActive == NO && channel.isChannel) {
			[channel activate];

			[self requestChatHistoryForChannel:channel];

			/* Members' accounts and away state soon, not at the next WHO interval */
			[self scheduleWhoRequestPass];
		} else {
			return;
		}

		self.userHostmask = m.senderHostmask;

		[mainWindow() reloadTreeItem:channel];
	}
	else // myself
	{
		channel = [self findChannel:channelName];

		if (channel == nil || channel.isChannel == NO) {
			return;
		}
	}

	if (isPrintOnlyMessage == NO) {
		/* A user might already exist by having a private message open */
		IRCUserMutable *userMutable = [self mutableCopyOfUserWithNickname:sender];

		userMutable.nickname = m.senderNickname;
		userMutable.username = m.senderUsername;
		userMutable.address = m.senderAddress;

		[self updateUser:userMutable fromExtendedJoin:m];

		IRCUser *userAdded = [self addUserAndReturn:userMutable];

		IRCChannelUser *member = [[IRCChannelUser alloc] initWithUser:userAdded];

		[channel addMember:member checkForDuplicates:YES];
	}

	if (isPrintOnlyMessage == NO && myself == NO) {
		IRCChannel *senderQuery = [self findChannel:sender];

		if (senderQuery && senderQuery.isActive == NO) {
			[senderQuery activate];

			[self print:TXTLS(@"IRC[q0q-ch]", sender)
					 by:nil
			  inChannel:senderQuery
				 asType:TVCLogLineTypeJoin
				command:m.command
			 receivedAt:m.receivedAt];

			[mainWindow() reloadTreeItem:senderQuery];
		}
	}

	IRCAddressBookEntry *ignoreInfo = nil;

	if (myself == NO) {
		ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

		if (ignoreInfo && isPrintOnlyMessage == NO) {
			[self updateUserTrackingStatusForEntry:ignoreInfo withMessage:m];
		}
	}

	BOOL printMessage = [self postReceivedMessage:m withText:nil destinedFor:channel];

	if (printMessage && myself == NO) {
		printMessage = [self shouldPrintGeneralEventInChannel:channel addressBookEntry:ignoreInfo];
	}

	if (printMessage) {
		NSString *message = TXTLS(@"IRC[ziu-p9]", sender, m.senderUsername, m.senderAddress.stringByAppendingIRCFormattingStop);

		[self print:message
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypeJoin
			command:m.command
		 receivedAt:m.receivedAt];
	}

	if (isPrintOnlyMessage) {
		return;
	}

	[mainWindow() updateTitleFor:channel];

	if (myself) {
		if (self.config.sendWhoCommandRequestsToChannels && self.isBrokenIRCd_aka_Twitch == NO) {
			[self requestModesForChannel:channel];
		}
	} else {
		[self notifyEvent:TXNotificationTypeUserJoined lineType:TVCLogLineTypeJoin target:channel nickname:sender text:nil];
	}
}

- (void)receivePart:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	/* ZNC sends PART messages for every channel when the client disconnects to force
	 it to update its local status. This is incredibly misleading to the user, as they
	 see the message that they left the channel and believe they did. This condition
	 filters out these messages. Because Textual is intelligent enough to clear status
	 related to channels when the connection is quit, this is safe. */
	if (self.isQuitting && self.isConnectedToZNC) {
		return;
	}

	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSString *channelName = [m paramAt:0];

	IRCChannel *channel = [self findChannel:channelName];

	if (channel == nil || channel.isChannel == NO) {
		return;
	}

	NSString *sender = m.senderNickname;

	NSString *comment = [m paramAt:1];

	BOOL myself = [self nicknameIsMyself:sender];

	if (isPrintOnlyMessage == NO) {
		if (myself) {
			[channel deactivate];

			[mainWindow() reloadTreeItem:channel];
		} else {
			[channel removeMemberWithNickname:sender];

			/* Notify user */
			[self notifyEvent:TXNotificationTypeUserParted lineType:TVCLogLineTypePart target:channel nickname:sender text:comment];
		}
	}

	BOOL printMessage = [self postReceivedMessage:m withText:comment destinedFor:channel];

	if (printMessage && myself == NO) {
		IRCAddressBookEntry *ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

		printMessage = [self shouldPrintGeneralEventInChannel:channel addressBookEntry:ignoreInfo];
	}

	if (printMessage) {
		NSString *message = TXTLS(@"IRC[nkr-kf]", sender, m.senderUsername, m.senderAddress.stringByAppendingIRCFormattingStop);

		if (comment.length > 0) {
			message = TXTLS(@"IRC[ozy-6i]", message, comment.stringByAppendingIRCFormattingStop);
		}

		[self print:message
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypePart
			command:m.command
		 receivedAt:m.receivedAt];
	}

	if (isPrintOnlyMessage == NO) {
		[mainWindow() updateTitleFor:channel];
	}
}

- (void)receiveKick:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 1);

	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSString *channelName = [m paramAt:0];

	IRCChannel *channel = [self findChannel:channelName];

	if (channel == nil || channel.isChannel == NO) {
		return;
	}

	NSString *sender = m.senderNickname;

	NSString *target = [m paramAt:1];
	NSString *comment = [m paramAt:2];

	BOOL myself = [self nicknameIsMyself:target];

	if (isPrintOnlyMessage == NO) {
		if (myself)
		{
			[channel deactivate];

			[mainWindow() reloadTreeItem:channel];

			/* Notify user */
			[self notifyEvent:TXNotificationTypeKick lineType:TVCLogLineTypeKick target:channel nickname:sender text:comment];

			/* Rejoin channel */
			if ([TPCPreferences rejoinOnKick] && channel.errorOnLastJoinAttempt == NO) {
				[self printDebugInformation:TXTLS(@"IRC[zzj-2h]") inChannel:channel];

				[self cs_reschedulePerformSelectorInCommonModes:@selector(joinKickedChannel:) withObject:channel afterDelay:3.0];
			}
		}
		else // myself
		{
			[channel removeMemberWithNickname:target];
		}
	}

	BOOL printMessage = [self postReceivedMessage:m withText:comment destinedFor:channel];

	if (printMessage && myself == NO) {
		IRCAddressBookEntry *ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

		printMessage = [self shouldPrintGeneralEventInChannel:channel addressBookEntry:ignoreInfo];
	}

	if (printMessage) {
		NSString *message = TXTLS(@"IRC[9aj-bd]", sender, target, comment.stringByAppendingIRCFormattingStop);

		[self print:message
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypeKick
			command:m.command
		 receivedAt:m.receivedAt];
	}

	if (isPrintOnlyMessage == NO) {
		[mainWindow() updateTitleFor:channel];
	}
}

- (void)receiveQuit:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSString *channelName = nil;

	NSString *comment = nil;

	if (isPrintOnlyMessage) {
		channelName = [m paramAt:0];

		comment = [m paramAt:1];
	} else {
		comment = [m paramAt:0];
	}

	NSString *sender = m.senderNickname;

	BOOL myself = [self nicknameIsMyself:sender];

	IRCUser *user = nil;

	if (isPrintOnlyMessage == NO) {
		user = [self findUser:sender];

		if (user == nil) {
			return;
		}
	}

	IRCAddressBookEntry *ignoreInfo = nil;

	if (myself == NO) {
		ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

		if (ignoreInfo && isPrintOnlyMessage == NO) {
			[self updateUserTrackingStatusForEntry:ignoreInfo withMessage:m];
		}
	}

	NSString *messageToPrint = TXTLS(@"IRC[53b-dm]", sender, m.senderUsername, m.senderAddress.stringByAppendingIRCFormattingStop);

	if (comment.length > 0) {
		messageToPrint = TXTLS(@"IRC[tok-st]", messageToPrint, comment.stringByAppendingIRCFormattingStop);
	}

	void (^printingBlock)(IRCChannel *) = ^(IRCChannel *channel)
	{
		if (myself == NO && isPrintOnlyMessage == NO) {
			switch (channel.type) {
				case IRCChannelTypeChannel:
				{
					IRCChannelUser *member = [user userAssociatedWithChannel:channel];

					if (member == nil) {
						return;
					}

					[channel removeMember:member];

					break;
				}
				case IRCChannelTypePrivateMessage:
				{
					if ([sender isEqualToStringIgnoringCase:channel.name] == NO) {
						return;
					}

					if (channel.isActive) {
						[channel deactivate];

						[mainWindow() reloadTreeItem:channel];
					}

					break;
				}
				default:
				{
					return;
				}
			}
		}

		NSString *message = messageToPrint;

		if (channel.isChannel)
		{
			BOOL printMessage = [self postReceivedMessage:m withText:comment destinedFor:channel];

			if (printMessage && myself == NO) {
				printMessage = [self shouldPrintGeneralEventInChannel:channel addressBookEntry:ignoreInfo];
			}

			[mainWindow() updateTitleFor:channel];

			if (printMessage == NO) {
				return;
			}
		}
		else // -isChannel
		{
			message = TXTLS(@"IRC[8bk-mx]", sender);
		}

		[self print:message
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypeQuit
			command:m.command
		 receivedAt:m.receivedAt];
	};

	if (isPrintOnlyMessage) {
		IRCChannel *channel = [self findChannel:channelName];

		if (channel == nil) {
			return;
		}

		printingBlock(channel);

		return;
	}

	for (IRCChannel *c in self.channelList) {
		printingBlock(c);
	}

	if (myself == NO) {
		[mainWindow() updateTitleFor:self];

		[self notifyEvent:TXNotificationTypeUserDisconnected lineType:TVCLogLineTypeQuit target:nil nickname:sender text:comment];
	}
}

- (void)receiveKill:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	NSString *nickname = [m paramAt:0];

	for (IRCChannel *c in self.channelList) {
		[c removeMemberWithNickname:nickname];
	}
}

- (void)receiveNick:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	/* Print only messages target specific channels which means
	 the index of incoming data will be different: [channel, nickname] */
	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSAssertReturn([m paramsCount] == (isPrintOnlyMessage ? 2 : 1));

	NSString *channelName = nil;

	NSString *newNickname = nil;

	if (isPrintOnlyMessage) {
		channelName = [m paramAt:0];

		newNickname = [m paramAt:1];
	} else {
		newNickname = [m paramAt:0];
	}

	/* There's no reason to perform an update if nothing changed */
	NSString *oldNickname = m.senderNickname;

	if ([oldNickname isEqualToString:newNickname]) {
		return;
	}

	BOOL myself = [self nicknameIsMyself:oldNickname];

	/* Find address book entry for old nickname and update tracking
	 status. This entry will also be used later on,	 when printing, 
	 to decide whether to print the message. */
	IRCAddressBookEntry *oldNicknameIgnoreInfo = nil;

	if (myself == NO) {
		oldNicknameIgnoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];
	}

	/* Perform restricted actions */
	if (isPrintOnlyMessage == NO) {
		if (myself)
		{
			self.userNickname = newNickname;

			if (self.tryingNicknameSentNickname != nil) {
				self.tryingNicknameSentNickname = newNickname;
			}

			/* Reload window title (our nickname is shown there) */
			[mainWindow() updateTitleFor:self];
		}
		else
		{
			/* Update user tracking status for old nickname */
			if (oldNicknameIgnoreInfo) {
				[self updateUserTrackingStatusForEntry:oldNicknameIgnoreInfo nickname:oldNickname withMessage:m];
			}

			/* Update user tracking status for new nickname */
			IRCAddressBookEntry *newNicknameIgnoreInfo = [self findUserTrackingAddressBookEntryForNickname:newNickname];

			if (newNicknameIgnoreInfo) {
				[self updateUserTrackingStatusForEntry:newNicknameIgnoreInfo nickname:newNickname withMessage:m];
			}
		}

		/* Inform style of change */
		[self postEventToViewController:@"nicknameChanged"];
	}

	/* Inform observers (not for print-only messages: playback, not a change) */
	if (isPrintOnlyMessage == NO) {
		[RZNotificationCenter() postNotificationName:IRCClientUserNicknameChangedNotification
											  object:self
											userInfo:@{
												@"oldNickname" : oldNickname,
												@"newNickname" : newNickname
											}];
	}

	/* Look for user */
	IRCUser *user = nil;

	if (isPrintOnlyMessage == NO) {
		user = [self findUser:oldNickname];

		if (user == nil) {
			return;
		}
	}

	/* Setup block that is used by printing operations */
	NSString *messageToPrint = nil;

	if (myself) {
		messageToPrint = TXTLS(@"IRC[rr6-yo]", newNickname);
	} else {
		messageToPrint = TXTLS(@"IRC[fxw-5s]", oldNickname, newNickname);
	}

	void (^printingBlock)(IRCChannel *) = ^(IRCChannel *channel)
	{
		if (isPrintOnlyMessage == NO) {
			switch (channel.type) {
				case IRCChannelTypeChannel:
				{
					/* Rename the user in the channel */
					IRCChannelUser *member = [user userAssociatedWithChannel:channel];

					if (member == nil) {
						return;
					}

					[channel resortMember:member];

					break;
				}
				case IRCChannelTypePrivateMessage:
				{
					/* Rename private message if one with old name is found */
					if ([oldNickname isEqualToStringIgnoringCase:channel.name] == NO) {
						return;
					}

					IRCChannel *newNicknameQuery = [self findChannel:newNickname];

					if (newNicknameQuery) {
						break;
					}

					channel.name = newNickname;

					[mainWindow() reloadTreeItem:channel];

					[mainWindow() updateTitleFor:channel]; // Refresh hostmask

					break;
				}
				default:
				{
					return;
				}
			}
		} // isPrintOnlyMessage == NO

		/* Determine whether the message should be printed */
		if (channel.isChannel) {
			BOOL printMessage = [self postReceivedMessage:m withText:newNickname destinedFor:channel];

			if (printMessage && myself == NO) {
				printMessage = [self shouldPrintGeneralEventInChannel:channel addressBookEntry:oldNicknameIgnoreInfo];
			}

			if (printMessage == NO) {
				return;
			}
		}

		/* Print message */
		[self print:messageToPrint
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypeNick
			command:m.command
		 receivedAt:m.receivedAt];
	};

	/* Target print */
	if (isPrintOnlyMessage) {
		IRCChannel *channel = [self findChannel:channelName];

		if (channel == nil) {
			return;
		}

		printingBlock(channel);

		return;
	}

	/* Continue with normal operations */
	[self renameUser:user to:newNickname];

	for (IRCChannel *c in self.channelList) {
		printingBlock(c);
	}
}

- (void)receiveMode:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 1);

	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSString *sender = m.senderNickname;

	NSString *channelName = [m paramAt:0];
	NSString *modeString = [m sequence:1];

	/* Present user modes */
	if ([self stringIsChannelName:channelName] == NO) {
		/* Losing operator status (-o) on ourselves (R3.14: it was never cleared) */
		if (isPrintOnlyMessage == NO && self.userIsIRCop && [self nicknameIsMyself:channelName]) {
			BOOL modeIsSet = YES;

			for (NSUInteger i = 0; i < modeString.length; i++) {
				unichar modeCharacter = [modeString characterAtIndex:i];

				if (modeCharacter == '+') {
					modeIsSet = YES;
				} else if (modeCharacter == '-') {
					modeIsSet = NO;
				} else if (modeCharacter == ' ') {
					break;
				} else if (modeCharacter == 'o' && modeIsSet == NO) {
					self.userIsIRCop = NO;
				}
			}
		}

		BOOL printMessage = [self postReceivedCommand:@"UMODE" withText:modeString destinedFor:nil referenceMessage:m];

		if (printMessage) {
			[self print:TXTLS(@"IRC[v5d-ix]", sender, modeString)
					 by:nil
			  inChannel:nil
				 asType:TVCLogLineTypeMode
				command:m.command
			 receivedAt:m.receivedAt];
		}

		return;
	}

	/* Present channel modes */
	IRCChannel *channel = [self findChannel:channelName];

	if (channel == nil || channel.isChannel == NO) {
		return;
	}

	if (isPrintOnlyMessage == NO) {
		NSArray *modes = [channel.modeInfo updateModes:modeString];

		for (IRCModeInfo *mode in modes) {
			if ([mode isModeForChangingMemberModeOn:self] == NO) {
				continue;
			}

			[channel changeMember:mode.modeParameter mode:mode.modeSymbol value:mode.modeIsSet];
		}
	}

	BOOL printMessage = [self postReceivedMessage:m withText:modeString destinedFor:channel];

	if (printMessage) {
		printMessage = [self shouldPrintGeneralEventInChannel:channel addressBookEntry:nil];
	}

	if (printMessage) {
		[self print:TXTLS(@"IRC[v5d-ix]", sender, modeString)
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypeMode
			command:m.command
		 receivedAt:m.receivedAt];
	}

	if (isPrintOnlyMessage == NO) {
		[mainWindow() updateTitleFor:channel];
	}
}

- (void)receiveTopic:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] == 2);

	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

	NSString *sender = m.senderNickname;

	NSString *channelName = [m paramAt:0];
	NSString *topic = [m paramAt:1];

	IRCChannel *channel = [self findChannel:channelName];

	if (channel == nil || channel.isChannel == NO) {
		return;
	}

	if (isPrintOnlyMessage == NO) {
		channel.topic = topic;
	}

	BOOL printMessage = [self postReceivedMessage:m withText:topic destinedFor:channel];

	if (printMessage) {
		[self print:TXTLS(@"IRC[qq2-66]", sender, topic)
				 by:nil
		  inChannel:channel
			 asType:TVCLogLineTypeTopic
			command:m.command
		 receivedAt:m.receivedAt];
	}
}

- (void)receiveInvite:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] == 2);

	NSString *sender = m.senderNickname;

	NSString *invitedNickname = [m paramAt:0];

	NSString *channelName = [m paramAt:1];

	/* invite-notify also tells channel members about invites for others:
	 a quiet line in that channel, without notification or auto-join */
	if ([self nicknameIsMyself:invitedNickname] == NO) {
		IRCChannel *channel = [self findChannel:channelName];

		if (channel == nil) {
			return;
		}

		if ([self postReceivedMessage:m withText:channelName destinedFor:channel]) {
			[self print:TXTLS(@"IRC[t8m-3k]", sender, invitedNickname)
					 by:nil
			  inChannel:channel
				 asType:TVCLogLineTypeInvite
				command:m.command
			 receivedAt:m.receivedAt];
		}

		return;
	}

	NSString *message = TXTLS(@"IRC[qw4-t3]", sender, m.senderUsername, m.senderAddress, channelName);

	/* Invite notifications are sent to frontmost channel on server of if it is
	 not on server, then it will be redirected to console. */
	BOOL printMessage = [self postReceivedMessage:m withText:channelName destinedFor:nil];

	if (printMessage) {
		[self print:message
				 by:nil
		  inChannel:[mainWindow() selectedChannelOn:self]
			 asType:TVCLogLineTypeInvite
			command:m.command
		 receivedAt:m.receivedAt];
	}

	[self notifyEvent:TXNotificationTypeInvite lineType:TVCLogLineTypeInvite target:nil nickname:sender text:channelName];

	if ([TPCPreferences autoJoinOnInvite]) {
		[self joinUnlistedChannel:channelName];
	}
}

- (void)receiveError:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSString *message = m.sequence;

	if (([message hasPrefix:@"Closing Link:"] && [message hasSuffix:@"(Excess Flood)"]) ||
		([message hasPrefix:@"Closing Link:"] && [message hasSuffix:@"(Max SendQ exceeded)"]))
	{
		[self afterDisconnectPerform:^(IRCClient *client) {
			[client cancelReconnect];
		}];
	}

	[self printError:message asCommand:m.command];
}

- (void)receiveCertInfo:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] == 2);

	/* CERTINFO is not a standard command for Textual to
	 receive which means we should be strict about what
	 conditions we will accept it under. */
	if (self.zncBouncerIsSendingCertificateInfo == NO ||
		m.senderIsServer == NO ||
		[m.senderNickname isEqualToString:@"znc.in"] == NO)
	{
		return;
	}

	/* The data we expect to receive should be chunk split 
	 which means it is safe to assume a maximum length. */
	NSString *data = m.sequence;

	if (data.length < 2 || data.length > 65) {
		return;
	}

	/* Write line to the mutable buffer */
	if ( self.zncBouncerCertificateChainDataMutable) {
		[self.zncBouncerCertificateChainDataMutable appendFormat:@"%@\n", data];
	}
}

- (void)receiveBatch:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] >= 1);

	NSString *batchToken = [m paramAt:0];

	if (batchToken.length <= 1) {
		LogToConsoleError("Cannot process BATCH command because [batchToken length] <= 1");

		return;
	}

	NSString *batchType = [m paramAt:1];

	BOOL isBatchOpening = NO;

	if ([batchToken hasPrefix:@"+"]) {
		 batchToken = [batchToken substringFromIndex:1];

		isBatchOpening = YES;
	} else if ([batchToken hasPrefix:@"-"]) {
		batchToken = [batchToken substringFromIndex:1];

		isBatchOpening = NO;
	} else {
		LogToConsoleError("Cannot process BATCH command because there was no open or close modifier");

		return;
	}

	if ([batchToken onlyContainsCharactersFromCharacterSet:[NSCharacterSet Ato9UnderscoreDash]] == NO) {
		LogToConsoleError("Cannot process BATCH command because the batch token contains illegal characters");

		return;
	}

	if (isBatchOpening == NO)
	{
		/* Find batch message matching known token */
		IRCMessageBatchMessage *thisBatchMessage = [self.batchMessages queuedEntryWithBatchToken:batchToken];

		if (thisBatchMessage == nil) {
			LogToConsoleError("Cannot process BATCH command because -queuedEntryWithBatchToken: returned nil");

			return;
		}

		thisBatchMessage.batchIsOpen = NO;

		/* If this batch message has a parent batch, then we 
		 do not remove this batch or process it until the close
		 statement for the parent is received. */
		if (thisBatchMessage.parentBatchMessage) {
			return; // Nothing left to do...
		}

		[self cancelPerformRequestsWithSelector:@selector(flushUnclosedBatchWithToken:) object:batchToken];

		[self finishBatchMessage:thisBatchMessage];
	}
	else // isBatchOpening == NO
	{
		/* Check batch= value to look for possible parent batch.*/
		IRCMessageBatchMessage *parentBatchMessage = nil;

		NSString *parentBatchMessageToken = m.batchToken;

		if (parentBatchMessageToken) {
			parentBatchMessage = [self.batchMessages queuedEntryWithBatchToken:parentBatchMessageToken];
		}

		/* Create new batch message and queue it. */
		IRCMessageBatchMessage *newBatchMessage = [IRCMessageBatchMessage new];

		newBatchMessage.batchIsOpen = YES;

		newBatchMessage.batchToken = batchToken;
		newBatchMessage.batchType = batchType;

		newBatchMessage.parentBatchMessage = parentBatchMessage;

		[self.batchMessages queueEntry:newBatchMessage];

		/* A nested batch is processed in its place in the parent, when
		 the parent closes; a batch that never closes would hold its
		 messages forever, so after a while it is processed anyway */
		if (parentBatchMessage) {
			[parentBatchMessage queueEntry:newBatchMessage];
		} else {
			[self performSelectorInCommonModes:@selector(flushUnclosedBatchWithToken:) withObject:batchToken afterDelay:_batchFlushTimeout];
		}

		/* An answer to a CHATHISTORY request: BATCH +token chathistory target */
		if ([batchType isEqualToString:@"chathistory"] || [batchType isEqualToString:@"draft/chathistory"]) {
			[self chatHistoryBatchOpenedForTarget:[m paramAt:2]];
		}

		/* Set vendor specific flags based on BATCH command values */
		if ([batchType isEqualToString:@"znc.in/playback"]) {
			self.zncBouncerIsPlayingBackHistory = self.isConnectedToZNC;
		} else if ([batchType isEqualToString:@"znc.in/tlsinfo"]) {
			self.zncBouncerIsSendingCertificateInfo = self.isConnectedToZNC;

			/* If this is parent batch (there is no @batch=), then we
			 reset the mutable object to read new data. */
			if (parentBatchMessageToken == nil) {
				self.zncBouncerCertificateChainDataMutable = [NSMutableString string];
			}
		}
	}
}

- (void)receiveChangeHost:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] == 2);

	NSString *username = [m paramAt:0];

	if ([username isHostmaskUsernameOn:self] == NO) {
		LogToConsoleError("Username ('%{private}@') received from CHGHOST command is improperly formatted", username);

		return;
	}

	NSString *address = [m paramAt:1];

	if ([address isHostmaskAddressOn:self] == NO) {
		LogToConsoleError("Address ('%{private}@') received from CHGHOST command is improperly formatted", address);

		return;
	}

	NSString *nickname = m.senderNickname;

	[self modifyUserUserWithNickname:nickname withBlock:^(IRCUserMutable *userMutable) {
		userMutable.username = username;
		userMutable.address = address;
	}];
}

#pragma mark -
#pragma mark Standard Replies

/* FAIL, WARN and NOTE: <command> <code> [<context>...] <description>.
 Shown whether or not standard-replies was negotiated, unknown codes included. */
- (void)receiveStandardReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] >= 3);

	if ([self chatHistoryHidesStandardReply:m]) {
		return;
	}

	/* In a channel the context names, otherwise in the console */
	IRCChannel *channel = nil;

	for (NSUInteger i = 2; i < (m.paramsCount - 1); i++) {
		IRCChannel *contextChannel = [self findChannel:[m paramAt:i]];

		if (contextChannel.isChannel) {
			channel = contextChannel;

			break;
		}
	}

	[self printDebugInformation:[self standardReplyText:m] inChannel:channel asCommand:m.command];
}

- (NSString *)standardReplyText:(IRCMessage *)m
{
	NSParameterAssert(m != nil);
	NSParameterAssert([m paramsCount] >= 3);

	NSString *replyType = m.command.uppercaseString;

	NSString *command = [m paramAt:0];

	NSString *code = [m paramAt:1];

	NSString *description = [m paramAt:(m.paramsCount - 1)];

	/* "*" means the reply isn't about one command */
	if ([command isEqualToString:@"*"]) {
		return TXTLS(@"IRC[s4r-2q]", replyType, code, description);
	}

	return TXTLS(@"IRC[s4r-1p]", replyType, command, code, description);
}

#pragma mark -
#pragma mark Account Tracking

/* The account name in ACCOUNT, extended-join and account-tag; "*" means logged out */
- (nullable NSString *)accountNameFromValue:(NSString *)value
{
	NSParameterAssert(value != nil);

	if (value.length == 0 || [value isEqualToString:@"*"]) {
		return nil;
	}

	return value;
}

/* extended-join: JOIN #channel account :real name */
- (void)updateUser:(IRCUserMutable *)userMutable fromExtendedJoin:(IRCMessage *)m
{
	NSParameterAssert(userMutable != nil);
	NSParameterAssert(m != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityExtendedJoin] == NO || [m paramsCount] < 3) {
		return;
	}

	userMutable.account = [self accountNameFromValue:[m paramAt:1]];

	userMutable.realName = [m sequence:2];
}

- (void)receiveAccount:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	/* Replayed lines describe the past, not the user's current account */
	if (m.isPrintOnlyMessage) {
		return;
	}

	NSString *account = [self accountNameFromValue:[m paramAt:0]];

	[self modifyUserUserWithNickname:m.senderNickname withBlock:^(IRCUserMutable *userMutable) {
		userMutable.account = account;
	}];
}

- (void)receiveSetName:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	if (m.isPrintOnlyMessage) {
		return;
	}

	NSString *realName = [m sequence:0];

	[self modifyUserUserWithNickname:m.senderNickname withBlock:^(IRCUserMutable *userMutable) {
		userMutable.realName = realName;
	}];
}

- (void)processAccountTagInMessage:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityAccountTag] == NO) {
		return;
	}

	/* Replayed lines carry the account the user had then. Live lines with
	 server-time are seconds old; a bouncer's backlog is older. */
	if (m.isPrintOnlyMessage || (m.isHistoric && m.receivedAt.timeIntervalSinceNow < (-60.0))) {
		return;
	}

	NSString *accountTag = m.messageTags[@"account"];

	if (accountTag == nil) {
		return;
	}

	NSString *nickname = m.senderNickname;

	if (nickname.length == 0) {
		return;
	}

	NSString *account = [self accountNameFromValue:accountTag];

	[self modifyUserUserWithNickname:nickname withBlock:^(IRCUserMutable *userMutable) {
		userMutable.account = account;
	}];
}

#pragma mark -
#pragma mark BATCH Command

- (id)queuedBatchMessageWithToken:(NSString *)batchToken
{
	return [self.batchMessages queuedEntryWithBatchToken:batchToken];
}

- (BOOL)filterBatchCommandIncomingData:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	/* BATCH lines open and close batches, also nested ones (which carry the
	 parent's batch tag), so they are never held back in a batch */
	if ([m.command isEqualToStringIgnoringCase:@"BATCH"]) {
		return NO;
	}

	NSString *batchToken = m.batchToken;

	if (batchToken) {
		IRCMessageBatchMessage *thisBatchMessage = [self.batchMessages queuedEntryWithBatchToken:batchToken];

		if (thisBatchMessage.batchIsOpen) {
			[thisBatchMessage queueEntry:m];

			return YES;
		}
	}

	return NO;
}

- (void)recursivelyProcessBatchMessage:(IRCMessageBatchMessage *)batchMessage
{
	[self recursivelyProcessBatchMessage:batchMessage depth:0];
}

- (void)recursivelyProcessBatchMessage:(IRCMessageBatchMessage *)batchMessage depth:(NSInteger)recursionDepth
{
	NSParameterAssert(batchMessage != nil);

	/* A nested batch still open when its parent is processed never closed
	 properly: its messages are processed rather than lost */
	if (recursionDepth == 0 && batchMessage.batchIsOpen) {
		return;
	}

	batchMessage.batchIsOpen = NO;

	NSArray *queuedEntries = batchMessage.queuedEntries;

	for (id queuedEntry in queuedEntries) {
		if ([queuedEntry isKindOfClass:[IRCMessage class]]) {
			[self processIncomingMessage:queuedEntry];
		} else if ([queuedEntry isKindOfClass:[IRCMessageBatchMessage class]]) {
			[self recursivelyProcessBatchMessage:queuedEntry depth:(recursionDepth + 1)];
		}
	}

	/* Nested batches are registered by token too, so each one goes */
	[self.batchMessages dequeueEntry:batchMessage];
}

/* Processes a closed top-level batch and resets the vendor states it set */
- (void)finishBatchMessage:(IRCMessageBatchMessage *)batchMessage
{
	NSParameterAssert(batchMessage != nil);

	NSString *batchType = batchMessage.batchType;

	/* Process queued entries for this batch message. */
	/* The method used for processing queued entries will
	 also remove it from queue once completed. */
	[self recursivelyProcessBatchMessage:batchMessage];

	/* Set vendor specific flags based on BATCH command values */
	if ([batchType isEqualToString:@"znc.in/playback"]) {
		self.zncBouncerIsPlayingBackHistory = NO;
	} else if ([batchType isEqualToString:@"znc.in/tlsinfo"]) {
		self.zncBouncerIsSendingCertificateInfo = NO;
	}
}

- (void)flushUnclosedBatchWithToken:(NSString *)batchToken
{
	NSParameterAssert(batchToken != nil);

	IRCMessageBatchMessage *batchMessage = [self.batchMessages queuedEntryWithBatchToken:batchToken];

	if (batchMessage == nil || batchMessage.batchIsOpen == NO) {
		return;
	}

	LogToConsoleError("BATCH '%{public}@' was not closed within %d seconds; processing its %lu messages",
		batchToken, _batchFlushTimeout, (unsigned long)batchMessage.queuedEntries.count);

	batchMessage.batchIsOpen = NO;

	[self finishBatchMessage:batchMessage];
}

@end

NS_ASSUME_NONNULL_END
