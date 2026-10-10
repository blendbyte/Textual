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
#import "IRCChannelMemberListPrivate.h"
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
#import "IRCWhoReplyPrivate.h"
#import "TVCMemberListPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Numerics)

#pragma mark -
#pragma mark Protocol Handlers

- (void)receivePing:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	NSString *token = [m sequence:0];

	[self sendPong:token];

	[self postReceivedMessage:m];
}

- (void)receiveAwayNotifyCapability:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityAwayNotify] == NO) {
		return;
	}

	BOOL away = (m.sequence.length > 0);

	NSString *nickname = m.senderNickname;

	[self modifyUserWithNickname:nickname asAway:away];
}

- (void)receiveInit:(IRCMessage *)m // Raw numeric = 001
{
	NSParameterAssert(m != nil);

	/* Manage timers */
	[self startPongTimer];

	[self stopRetryTimer];

	/* Manage properties */
	self.isLoggedIn = YES;

	/* Registration is complete: capability negotiation no longer ends it */
	[self.capabilityNegotiator registrationCompleted];

	self.supportInfo.serverAddress = m.senderHostmask;

	self.invokingISONCommandForFirstTime = YES;

	self.reconnectEnabledBecauseOfSleepMode = NO;

	self.tryingNicknameSentNickname = nil;

	self.userNickname = [m paramAt:0];

	self.successfulConnects += 1;

	/* Begin enforcing flood control */
	[self.socket enforceFloodControl];

	/* Post event */
	[self postEventToViewController:@"serverConnected"];

	[self notifyEvent:TXNotificationTypeConnect lineType:TVCLogLineTypeDebug];

	/* Perform login commands */
	for (__strong NSString *command in self.config.loginCommands) {
		if ([command hasPrefix:@"/"]) {
			command = [command substringFromIndex:1];
		}

		[self sendCommand:command completeTarget:NO target:nil];
	}

	/* Request certificate information */
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityZNCCertInfoModule]) {
		[self sendCommand:@"send-data" toZNCModuleNamed:@"tlsinfo"];
	}

	/* Request playback since the last seen message when previously connected */
	[self requestPlayback];

	/* draft/chathistory: missed private messages (channels ask once joined) */
	[self requestChatHistoryForQueries];

	/* Activate existing queries */
	for (IRCChannel *c in self.channelList) {
		if (c.privateMessage) {
			[c activate];

			[mainWindow() reloadTreeItem:c];
		}
	}

	[mainWindow() reloadTreeItem:self];

	[mainWindow() updateTitleFor:self];

	[mainWindowTextField() updateSegmentedController];

	/* Everything else */
	if (self.config.autojoinWaitsForNickServ == NO || [self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL]) {
		[self performAutoJoin];
	} else {
		/* If we wait for NickServ we set a timer of 3.0 seconds before performing auto join.
		 When this timer is executed, if we do not have any knowledge of NickServ existing
		 on the current server, then we perform the autojoin. This is primarily a fix for the
		 ZNC SASL module which will complete identification before connecting and once connected
		 Textual will have no knowledge of whether the local user is identified or not. */
		/* NickServ will send a notice asking for identification as soon as connection occurs so
		 this is the best patch. At least for right now. */

		if (self.isConnectedToZNC) {
			[self cs_reschedulePerformSelectorInCommonModes:@selector(performAutoJoin) withObject:nil afterDelay:3.0];
		} else {
			[self startAutojoinDelayedWarningTimer];
		}
	}

	/* We need time for the server to send its configuration */
	[self cs_reschedulePerformSelectorInCommonModes:@selector(populateISONTrackedUsersList) withObject:nil afterDelay:10.0];
}

- (void)receiveNumericReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSInteger numeric = m.commandNumeric;

	if (numeric > 400 && numeric < 597 && numeric != ERR_NOMOTD) {
		[self receiveErrorNumericReply:m];

		return;
	}

	BOOL printMessage = YES;

	/* These numerics are treated differently below which is why the exception exists.
	 For example, for channel topic, only the contents of the topic are sent to the filter. */
	if (numeric != RPL_UMODEIS &&
		numeric != RPL_CHANNELMODEIS &&
		numeric != RPL_TOPIC &&
		numeric != RPL_TOPICWHOTIME)
	{
		printMessage = [self postReceivedMessage:m];
	}

	if ([self _receiveRegistrationNumericReply:m print:printMessage] ||
		[self _receiveWhoisNumericReply:m print:printMessage] ||
		[self _receiveChannelNumericReply:m print:printMessage] ||
		[self _receiveListNumericReply:m print:printMessage] ||
		[self _receiveTrackingNumericReply:m print:printMessage] ||
		[self _receiveSASLNumericReply:m print:printMessage])
	{
		return;
	}

	/* Not handled above */
	[self _receiveUnhandledNumericReply:m print:printMessage];
}

/* Registration and the connection: welcome, server information, MOTD,
 own modes and away state. Returns NO for other numerics. */
- (BOOL)_receiveRegistrationNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	switch (numeric) {
		case RPL_WELCOME:
		{
			[self receiveInit:m];

			if (printMessage) {
				[self printReply:m];
			}

			break;
		}
		case RPL_YOURHOST:
		case RPL_CREATED:
		case RPL_MYINFO:
		{
			if (printMessage) {
				[self printReply:m];
			}

			break;
		}
		case RPL_ISUPPORT:
		{
			NSAssertReturnR([m paramsCount] >= 3, YES);

			NSMutableArray *params = [m.params mutableCopy];

			[params removeObjectAtIndex:0]; // Remove nickname

			NSString *message = params.lastObject;

			[params removeLastObject]; // Remove "are supported by this server"

			NSString *configuration = [params componentsJoinedByString:@" "];

			[self.supportInfo processConfigurationData:configuration];

			if (printMessage) {
				NSString *configurationFormatted = self.supportInfo.stringValueForLastUpdate;

				[self printDebugInformationToConsole:TXTLS(@"IRC[u51-nn]", configurationFormatted, message)
										   asCommand:m.command];
			}

			break;
		}
		case RPL_REDIR:
		{
			NSAssertReturnR([m paramsCount] == 4, YES);

			NSString *serverAddress = [m paramAt:1];
			NSString *serverPort = [m paramAt:2];

			self.disconnectType = IRCClientDisconnectModeServerRedirect;

			/* If the address is thought to be invalid, then we still
			 perform the disconnect suggested by the redirect, but
			 we do not go any further than that. */
			if (serverAddress.validInternetAddress == NO ||
				serverPort.validInternetPort == NO)
			{
				[self disconnect];

				return YES;
			}

			/* A redirect never drops TLS: a server (or anyone tampering with the
			 redirect) could otherwise move the session, and SASL or NickServ
			 passwords, to plaintext. Read the state before -disconnect
			 destroys the socket. */
			BOOL connectionIsSecured = (self.socket.isSecured || self.socket.config.connectionPrefersSecuredConnection);

			if (connectionIsSecured) {
				[self printDebugInformationToConsole:TXTLS(@"IRC[r3d-t1]", serverAddress, serverPort)];
			}

			/* Perform reconnect to specified locations */
			[self disconnectThen:^(IRCClient *client) {
				[client connect];
			}];

			/* -disconnect would destroy this so we set them after... */
			self.temporaryServerAddressOverride = serverAddress;
			self.temporaryServerPortOverride = serverPort.integerValue;
			self.temporaryServerPrefersSecuredConnection = connectionIsSecured;

			break;
		}
		case RPL_STATSCONN:
		case RPL_LUSERCLIENT:
		case RPL_LUSERHOP:
		case RPL_LUSERUNKNOWN:
		case RPL_LUSERCHANNELS:
		case RPL_LUSERME:
		{
			if (printMessage) {
				[self printReply:m];
			}

			break;
		}
		case RPL_LOCALUSERS:
		case RPL_GLOBALUSERS:
		{
			NSAssertReturnR(printMessage, YES);

			NSString *message = nil;

			if (m.paramsCount == 4) {
				/* Removes user count from in front of messages on IRCds that send them.
				 Example: ">> :irc.example.com 265 Guest 2 3 :Current local users 2, max 3" */

				message = [m sequence:3];
			} else {
				message = m.sequence;
			}

			[self print:message
					 by:nil
			  inChannel:nil
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_MOTD:
		case RPL_MOTDSTART:
		case RPL_ENDOFMOTD:
		case ERR_NOMOTD:
		{
			NSAssertReturnR(printMessage, YES);

			if ([TPCPreferences displayServerMOTD] == NO) {
				break;
			}

			if (numeric == ERR_NOMOTD) {
				[self printErrorReply:m];
			} else {
				[self printReply:m];
			}

			break;
		}
		case RPL_UMODEIS:
		{
			NSAssertReturnR([m paramsCount] > 1, YES);

			NSString *nickname = [m paramAt:0];

			NSString *modeString = [m paramAt:1];

			if ([modeString isEqualToString:@"+"]) {
				break;
			}

			printMessage = [self postReceivedMessage:m withText:modeString destinedFor:nil];

			if (printMessage) {
				[self print:TXTLS(@"IRC[ipj-34]", nickname, modeString)
						 by:nil
				  inChannel:nil
					 asType:TVCLogLineTypeDebug
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_UNAWAY:
		case RPL_NOWAWAY:
		{
			BOOL away = (numeric == RPL_NOWAWAY);

			self.userIsAway = away;
			
			[mainWindow() updateTitle];

			if (printMessage) {
				[self printReply:m];
			}

			/* Update our own status. This has to only be done with away-notify CAP enabled.
			 Old, WHO based information requests will still show our own status. */
			IRCUser *myself = self.myself;

			if (myself == nil) {
				break;
			}

			[self modifyUser:myself asAway:away];

			break;
		}
		case RPL_YOUREOPER:
		{
			if (self.userIsIRCop == NO) {
				self.userIsIRCop = YES;
			} else {
				break;
			}

			if (printMessage) {
				[self print:TXTLS(@"IRC[6bh-br]", m.senderNickname)
						 by:nil
				  inChannel:nil
					 asType:TVCLogLineTypeDebug
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		default:
		{
			return NO;
		}
	} // switch()

	return YES;
}

/* WHOIS and WHOWAS. Returns NO for other numerics. */
- (BOOL)_receiveWhoisNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	switch (numeric) {
		case RPL_AWAY:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			NSString *awayNickname = [m paramAt:1];
			NSString *awayComment = [m paramAt:2];

			IRCChannel *channel = [self findChannel:awayNickname];

			NSString *message = TXTLS(@"IRC[c1h-fq]", awayNickname, awayComment);

			if (channel == nil) {
				channel = [mainWindow() selectedChannelOn:self];
			}

			IRCUser *user = [self findUser:awayNickname];

			if ( user) {
				if (self.monitorAwayStatus) {
					[user markAsAway];
				}

				if (user.presentAwayMessageFor301 == NO) {
					break;
				}
			}

			if (printMessage) {
				[self print:message
						 by:nil
				  inChannel:channel
					 asType:TVCLogLineTypeDebug
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_CHANNELSMSG:
		case RPL_WHOISBOT:
		case RPL_WHOISHELPOP:
		case RPL_WHOISHOST:
		case RPL_WHOISMODES:
		case RPL_WHOISOPERATOR:
		case RPL_WHOISREALIP:
		case RPL_WHOISREGNICK:
		case RPL_WHOISSECURE:
		case RPL_WHOISSPECIAL:
		{
			NSAssertReturnR([m paramsCount] > 2, YES);

			if (printMessage) {
				[self printReply:m inChannel:[mainWindow() selectedChannelOn:self]];
			}

			break;
		}
		case RPL_WHOISACTUALLY:
		{
			NSAssertReturnR([m paramsCount] == 5, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];
			NSString *hostmask = [m paramAt:2];
			NSString *ipAddress = [m paramAt:3];

			NSString *message = nil;

			if (self.inWhowasResponse) { // bahamut sends RPL_WHOISACTUALLY in WHOWAS
				message = TXTLS(@"IRC[x69-rz]", nickname, hostmask, ipAddress);
			} else {
				message = TXTLS(@"IRC[3oa-mv]", nickname, hostmask, ipAddress);
			}

			[self print:message
					 by:nil
			  inChannel:[mainWindow() selectedChannelOn:self]
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_WHOISUSER:
		case RPL_WHOWASUSER:
		{
			NSAssertReturnR([m paramsCount] >= 6, YES);

			NSString *nickname = [m paramAt:1];
			NSString *username = [m paramAt:2];
			NSString *address = [m paramAt:3];
			NSString *realName = [m paramAt:5];

			if ([realName hasPrefix:@":"]) {
				realName = [realName substringFromIndex:1];
			}

			self.inWhoisResponse = (numeric == RPL_WHOISUSER);
			self.inWhowasResponse = (numeric == RPL_WHOWASUSER);

			NSString *message = nil;

			if (self.inWhowasResponse) {
				if (printMessage) {
					message = TXTLS(@"IRC[32c-87]", nickname, username, address, realName);
				}
			} else {
				if (printMessage) {
					message = TXTLS(@"IRC[plg-lr]", nickname, username, address, realName);
				}

				/* Update local cache of our hostmask */
				if ([self nicknameIsMyself:nickname]) {
					NSString *hostmask = [NSString stringWithFormat:@"%@!%@@%@", nickname, username, address];

					self.userHostmask = hostmask;
				}
			}

			if (message) {
				[self print:message
						 by:nil
				  inChannel:[mainWindow() selectedChannelOn:self]
					 asType:TVCLogLineTypeDebug
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_WHOISSERVER:
		{
			NSAssertReturnR([m paramsCount] == 4, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];
			NSString *serverAddress = [m paramAt:2];
			NSString *serverInfo = [m paramAt:3];

			NSString *message = nil;

			if (self.inWhowasResponse) { // bahamut sends RPL_WHOISSERVER in WHOWAS
				NSString *timeInfo = TXFormatDateLongStyle(serverInfo, YES);

				if (timeInfo == nil) {
					timeInfo = serverInfo;
				}

				message = TXTLS(@"IRC[cdu-ed]", nickname, serverAddress, timeInfo);
			} else {
				message = TXTLS(@"IRC[h19-n2]", nickname, serverAddress, serverInfo);
			}

			[self print:message
					 by:nil
			  inChannel:[mainWindow() selectedChannelOn:self]
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_WHOISIDLE:
		{
			NSAssertReturnR([m paramsCount] == 5, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];
			NSString *idleTime = [m paramAt:2];
			NSString *connectTime = [m paramAt:3];

			idleTime = TXHumanReadableTimeInterval(idleTime.doubleValue, NO, 0);

			NSDate *connTimeDate = [NSDate dateWithTimeIntervalSince1970:connectTime.doubleValue];

			connectTime = TXFormatDateLongStyle(connTimeDate, YES);

			NSString *message = TXTLS(@"IRC[6hn-o6]", nickname, connectTime, idleTime);

			[self print:message
					 by:nil
			  inChannel:[mainWindow() selectedChannelOn:self]
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_WHOISCHANNELS:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];
			NSString *channels = [m paramAt:2];

			NSString *message = TXTLS(@"IRC[onk-l5]", nickname, channels);

			[self print:message
					 by:nil
			  inChannel:[mainWindow() selectedChannelOn:self]
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_WHOISACCOUNT:
		{
			NSAssertReturnR([m paramsCount] == 4, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *message = [NSString stringWithFormat:@"%@ %@ %@", [m paramAt:1], [m sequence:3], [m paramAt:2]];

			[self print:message
					 by:nil
			  inChannel:[mainWindow() selectedChannelOn:self]
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_ENDOFWHOIS:
		{
			self.inWhoisResponse = NO;

/*			if (printMessage) {
				[self printReply:m inChannel:[mainWindow() selectedChannelOn:self]];
			} */

			break;
		}
		case RPL_ENDOFWHOWAS:
		{
			self.inWhowasResponse = NO;

/*			if (printMessage) {
				[self printReply:m inChannel:[mainWindow() selectedChannelOn:self]];
			} */

			break;
		}
		default:
		{
			return NO;
		}
	} // switch()

	return YES;
}

/* Channel state: modes, topic, invites, WHO and NAMES. Returns NO for
 other numerics. */
- (BOOL)_receiveChannelNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	switch (numeric) {
		case RPL_CHANNELMODEIS:
		{
			NSAssertReturnR([m paramsCount] > 2, YES);

			NSString *channelName = [m paramAt:1];

			NSString *modeString = [m sequence:2];

			if ([modeString isEqualToString:@"+"]) {
				return YES;
			}

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				break;
			}

			if (channel.isActive) {
				[channel.modeInfo clear];

				[channel.modeInfo updateModes:modeString];
			}

			printMessage = [self postReceivedMessage:m withText:modeString destinedFor:channel];

			/* We perform this check after printMessage is defined so that
			 filters have a chance to act on the input. */
			/* IRCClient perform mode requests for channels without the user
			 asking for it so we must check that here. */
			if (channel.channelModesReceived == NO) {
				channel.channelModesReceived = YES;
			}

			if (printMessage) {
				NSString *message = channel.modeInfo.stringWithMaskedPassword;

				[self print:TXTLS(@"IRC[obp-ww]", message)
						 by:nil
				  inChannel:channel
					 asType:TVCLogLineTypeMode
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_TOPIC:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			NSString *channelName = [m paramAt:1];
			NSString *topic = [m paramAt:2];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				break;
			}

			printMessage = [self postReceivedMessage:m withText:topic destinedFor:channel];

			channel.topic = topic;

			if (printMessage) {
				[self print:TXTLS(@"IRC[7nm-7v]", topic)
						 by:nil
				  inChannel:channel
					 asType:TVCLogLineTypeTopic
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_TOPICWHOTIME:
		{
			NSAssertReturnR([m paramsCount] == 4, YES);

			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				break;
			}

			printMessage = [self postReceivedMessage:m withText:nil destinedFor:channel];

			if (printMessage == NO) {
				return YES;
			}

			NSString *topicSetter = [m paramAt:2];
			NSString *setTime = [m paramAt:3];

			topicSetter = topicSetter.nicknameFromHostmask;

			NSDate *setTimeDate = [NSDate dateWithTimeIntervalSince1970:setTime.doubleValue];

			setTime = TXFormatDateLongStyle(setTimeDate, YES);

			NSString *message = TXTLS(@"IRC[y7s-3e]", topicSetter, setTime);

			[self print:message
					 by:nil
			  inChannel:channel
				 asType:TVCLogLineTypeTopic
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_CREATIONTIME:
		{
			break; // Ignore
		}
		case RPL_INVITING:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];
			NSString *channelName = [m paramAt:2];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				break;
			}

			[self print:TXTLS(@"IRC[wk4-rv]", nickname, channelName)
					 by:nil
			  inChannel:channel
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_WHOREPLY:
		case RPL_WHOSPCRPL:
		{
			/* Present reply to the user if we have destination */
			if (self.requestedCommands.visibleWhoRequest) {
				if (printMessage) {
					[self printReplyToHiddenCommandResponsesQuery:m];
				}

				/* We could remove this and be fine, but it's a lot
				 over overhead to process WHO responses so let's just
				 wait until the next automated one. */
				break;
			}

			/* 354 that isn't an answer to our WHOX request: left to plugins */
			IRCWhoReply *reply = nil;

			if (numeric == RPL_WHOREPLY) {
				reply = [IRCWhoReply replyFromWhoReply:m];
			} else {
				reply = [IRCWhoReply replyFromWhoxReply:m];
			}

			if (reply == nil) {
				break;
			}

			[self processWhoReply:reply];

			break;
		}
		case RPL_ENDOFWHO:
		{
			BOOL visibleWhoRequest = self.requestedCommands.visibleWhoRequest;

			[self.requestedCommands recordWhoRequestClosed];

			/* The first WHOX answer for a channel makes its accounts known: redraw its members */
			if ([m paramsCount] > 1) {
				IRCChannel *channel = [self findChannel:[m paramAt:1]];

				if (channel.whoxRefreshPending) {
					channel.whoxRefreshPending = NO;

					if (mainWindow().selectedChannel == channel) {
						[mainWindow().memberList refreshAllDrawings];
					}
				}
			}

			if (visibleWhoRequest && printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case RPL_NAMEREPLY:
		{
			NSAssertReturnR([m paramsCount] > 3, YES);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			/* Process reply */
			NSString *channelName = [m paramAt:2];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil || channel.channelNamesReceived) {
				break;
			}

			/* Collected until RPL_ENDOFNAMES, then sorted and shown once */
			[channel.memberInfo beginNamesBatch];

			NSString *nicknamesString = [m paramAt:3];

			NSArray *nicknames = [nicknamesString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *nickname in nicknames) {
				if (nickname.length == 0) {
					continue;
				}

				/* Find first character that is not a user mode */
				NSMutableString *memberModes = [NSMutableString string];

				NSUInteger characterIndex = 0;

				for (characterIndex = 0; characterIndex < nickname.length; characterIndex++) {
					NSString *prefix = [nickname stringCharacterAtIndex:characterIndex];

					NSString *modeSymbol = [self.supportInfo modeSymbolForUserPrefix:prefix];

					if (modeSymbol == nil) {
						break;
					}

					[memberModes appendString:modeSymbol];
				} // for

				/* Split away hostmask if available */
				NSString *newNickname = [nickname substringFromIndex:characterIndex];

				NSString *nicknameInt = nil;
				NSString *usernameInt = nil;
				NSString *addressInt = nil;

				if ([newNickname hostmaskComponents:&nicknameInt username:&usernameInt address:&addressInt onClient:self] == NO) {
					/* When NAMES reply is not a host, then set the nicknameInt
					 to the value of nickname and leave the rest as nil. */

					nicknameInt = newNickname;
				}

				/* Find global user */
				/* An instance of IRCUser may already exist from a NAMES
				 reply for another channel. If one already exist, then
				 we don't make an effort to change it's credentials. */
				IRCUser *userAdded = nil;

				IRCUser *user = [self findUser:nicknameInt];

				if (user == nil) {
					IRCUserMutable *userMutable = [[IRCUserMutable alloc] initWithNickname:nicknameInt onClient:self];

					userMutable.nickname = nicknameInt;
					userMutable.username = usernameInt;
					userMutable.address = addressInt;

					userAdded = [self addUserAndReturn:userMutable];
				} else {
					userAdded = user;
				}

				/* Find channel user */
				IRCChannelUser *member = [userAdded userAssociatedWithChannel:channel];

				IRCChannelUserMutable *memberMutable = nil;

				if (member == nil) {
					memberMutable = [[IRCChannelUserMutable alloc] initWithUser:userAdded];
				} else if ([self nicknameIsMyself:nicknameInt]) {
					memberMutable = [member mutableCopy];
				} else {
					/* A user with this name is already in the channel: skip
					 them, unless it's us. We are added to the channel when the
					 JOIN is received, but we still need modes. */

					continue;
				}

				/* Create channel user */
				memberMutable.modes = memberModes;

				/* Add user to channel */
				[channel addMember:memberMutable checkForDuplicates:YES];
			} // for

			break;
		}
		case RPL_ENDOFNAMES:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			/* Process reply */
			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil || channel.channelNamesReceived) {
				break;
			}

			channel.channelNamesReceived = YES;

			[channel.memberInfo endNamesBatch];

			/* We have to wait until names are processed before populating
			 defaults for a channel so that we are certain there is actually
			 only one user, which is us. */
			if (channel.numberOfMembers == 1 && self.isBrokenIRCd_aka_Twitch == NO) {
				NSString *defaultModes = channel.config.defaultModes;

				if (defaultModes.length > 0) {
					[self sendModes:defaultModes withParametersString:nil inChannel:channel];
				}

				NSString *defaultTopic = channel.config.defaultTopic;

				if (defaultTopic.length > 0) {
					[self sendTopicTo:defaultTopic inChannel:channel];
				}
			}

			/* Update user count in title */
			[mainWindow() updateTitleFor:channel];

			break;
		}
		case RPL_CHANNEL_URL:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *channelName = [m paramAt:1];
			NSString *website = [m paramAt:2];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				return YES;
			}

			[self print:TXTLS(@"IRC[8tq-g6]", website)
					 by:nil
			  inChannel:channel
				 asType:TVCLogLineTypeWebsite
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		default:
		{
			return NO;
		}
	} // switch()

	return YES;
}

/* The channel list and ban, invite, exception and quiet lists. Returns NO
 for other numerics. */
- (BOOL)_receiveListNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	switch (numeric) {
		case RPL_LISTSTART:
		{
			TDCServerChannelListDialog *channelListDialog = [self channelListDialog];

			if (channelListDialog) {
				channelListDialog.contentAlreadyReceived = NO;

				[channelListDialog clear];
			}

			break;
		}
		case RPL_LIST:
		{
			NSAssertReturnR([m paramsCount] > 2, YES);

			NSString *channel = [m paramAt:1];
			NSString *userCount = [m paramAt:2];
			NSString *topic = [m sequence:3];

			if ([channel isEqualToString:@"*"]) {
				break;
			}

			TDCServerChannelListDialog *channelListDialog = [self channelListDialog];

			if (channelListDialog) {
				[channelListDialog addChannel:channel count:userCount.integerValue topic:topic];
			}

			break;
		}
		case RPL_LISTEND:
		{
			TDCServerChannelListDialog *channelListDialog = [self channelListDialog];

			if (channelListDialog) {
				channelListDialog.contentAlreadyReceived = YES;
			}

			break;
		}
		case RPL_BANLIST:
		case RPL_INVITELIST:
		case RPL_EXCEPTLIST:
		case RPL_QUIETLIST:
		{
			NSAssertReturnR([m paramsCount] > 2, YES);

			NSUInteger paramsOffset = 0;

			/* Quiet list has an extra argument which is the string "q" */
			if (numeric == RPL_QUIETLIST && m.paramsCount == 6)	{
				paramsOffset = 1;
			}

			NSString *channelName = [m paramAt:1];

			NSString *entryMask = [m paramAt:(2 + paramsOffset)];

			NSString *entryAuthor = nil;

			NSDate *entryCreationDate = nil;

			BOOL extendedLine = (m.paramsCount > (4 + paramsOffset));

			if (extendedLine) {
				entryAuthor = [m paramAt:(3 + paramsOffset)].nicknameFromHostmask;

				entryCreationDate = [NSDate dateWithTimeIntervalSince1970:[m paramAt:(4 + paramsOffset)].doubleValue];
			}

			TDCChannelBanListSheetEntryType entryType = TDCChannelBanListSheetEntryTypeBan;

			if (numeric == RPL_INVITELIST) {
				entryType = TDCChannelBanListSheetEntryTypeInviteException;
			} else if (numeric == RPL_EXCEPTLIST) {
				entryType = TDCChannelBanListSheetEntryTypeBanException;
			} else if (numeric == RPL_QUIETLIST) {
				entryType = TDCChannelBanListSheetEntryTypeQuiet;
			}

			TDCChannelBanListSheet *listSheet = [self banListSheetForChannelNamed:channelName entryType:entryType];

			if (listSheet) {
				if (listSheet.contentAlreadyReceived) {
					listSheet.contentAlreadyReceived = NO;

					[listSheet clear];
				}

				[listSheet addEntry:entryMask setBy:entryAuthor creationDate:entryCreationDate];

				return YES;
			}

			if (printMessage == NO) {
				return YES;
			}

			NSString *localization = nil;

			if (numeric == RPL_BANLIST) {
				localization = @"c04-d0";
			} else if (numeric == RPL_INVITELIST) {
				localization = @"py2-qh";
			} else if (numeric == RPL_EXCEPTLIST) {
				localization = @"ov2-ci";
			} else if (numeric == RPL_QUIETLIST) {
				localization = @"u5z-az";
			}

			if (extendedLine) {
				localization = [NSString stringWithFormat:@"IRC[%@-1]", localization];
			} else {
				localization = [NSString stringWithFormat:@"IRC[%@-2]", localization];
			}

			NSString *message = nil;

			if (extendedLine) {
				message = TXTLS(localization, channelName, entryMask, entryAuthor, entryCreationDate);
			} else {
				message = TXTLS(localization, channelName, entryMask);
			}

			[self print:message
					 by:nil
			  inChannel:nil
				 asType:TVCLogLineTypeDebug
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_ENDOFBANLIST:
		case RPL_ENDOFINVITELIST:
		case RPL_ENDOFEXCEPTLIST:
		case RPL_ENDOFQUIETLIST:
		{
			TDCChannelBanListSheetEntryType entryType = TDCChannelBanListSheetEntryTypeBan;

			if (numeric == RPL_ENDOFINVITELIST) {
				entryType = TDCChannelBanListSheetEntryTypeInviteException;
			} else if (numeric == RPL_ENDOFEXCEPTLIST) {
				entryType = TDCChannelBanListSheetEntryTypeBanException;
			} else if (numeric == RPL_ENDOFQUIETLIST) {
				entryType = TDCChannelBanListSheetEntryTypeQuiet;
			}

			TDCChannelBanListSheet *listSheet = [self banListSheetForChannelNamed:[m paramAt:1] entryType:entryType];

			if (listSheet) {
				listSheet.contentAlreadyReceived = YES;

				break;
			}

			if (printMessage) {
				[self printReply:m];
			}

			break;
		}
		default:
		{
			return NO;
		}
	} // switch()

	return YES;
}

/* The open ban list sheet for this server, channel and list, if there is one:
 replies for any channel or list went into whatever ban list sheet was open */
- (nullable TDCChannelBanListSheet *)banListSheetForChannelNamed:(NSString *)channelName entryType:(TDCChannelBanListSheetEntryType)entryType
{
	NSParameterAssert(channelName != nil);

	TDCChannelBanListSheet *listSheet = [windowController() windowFromWindowList:@"TDCChannelBanListSheet"];

	if (listSheet == nil || listSheet.client != self || listSheet.entryType != entryType) {
		return nil;
	}

	IRCChannel *channel = [self findChannel:channelName];

	if (channel == nil || listSheet.channel != channel) {
		return nil;
	}

	return listSheet;
}

/* User tracking: ISON, WATCH, MONITOR and caller ID (+g). Returns NO for
 other numerics. */
- (BOOL)_receiveTrackingNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	switch (numeric) {
		case RPL_ISON:
		{
			/* Present reply to the user if we have destination */
			BOOL visibleIsonRequest = self.requestedCommands.visibleIsonRequest;

			if (visibleIsonRequest) {
				[self.requestedCommands recordIsonRequestClosed];

				if (printMessage) {
					[self printReplyToHiddenCommandResponsesQuery:m];
				}

				/* It is important that we don't process logic for visible
				 requests because if user does ISON for people that aren't
				 on the tracked list and the logic below sees the response
				 missing those, then it will think everyone tracked went offline. */
				break;
			}

			/* If the ISON records were not requested by the user, then
			 treat the results as user tracking information. A long request
			 is sent as several lines: collect the replies until the last. */
			for (NSString *nickname in [m.sequence componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
				if (nickname.length > 0) {
					[self.isonReplyNicknames addObject:nickname];
				}
			}

			if ([self.requestedCommands recordIsonReplyReceived] == NO) {
				break;
			}

			NSArray *onlineNicknames = [self.isonReplyNicknames copy];

			[self.isonReplyNicknames removeAllObjects];

			/* Start going over the list of tracked nicknames */
			NSDictionary *trackedUsers = self.trackedUsers.trackedUsers;

			[trackedUsers enumerateKeysAndObjectsUsingBlock:^(NSString *trackedUser, NSNumber *trackingStatusInt, BOOL *stop) {
				IRCAddressBookUserTrackingStatus trackingStatus =
				IRCAddressBookUserTrackingStatusUnknown;

				/* Was the user on during the last check? */
				BOOL ison = trackingStatusInt.boolValue;

				if (ison) {
					/* If the user was on before, but is not in the list of ISON
					 users in this reply, then they are considered gone. Log that. */
					if ([onlineNicknames containsObjectIgnoringCase:trackedUser] == NO) {
						if (self.invokingISONCommandForFirstTime == NO) {
							trackingStatus = IRCAddressBookUserTrackingStatusSignedOff;
						}
					}
				} else {
					/* If they were not on but now are, then log that too. */
					if ([onlineNicknames containsObjectIgnoringCase:trackedUser]) {
						if (self.invokingISONCommandForFirstTime) {
							trackingStatus = IRCAddressBookUserTrackingStatusAvailable;
						} else {
							trackingStatus = IRCAddressBookUserTrackingStatusSignedOn;
						}
					}
				}

				/* If something changed (non-nil localization string), then scan 
				 the list of address book entries to report the result. */
				if (trackingStatus != IRCAddressBookUserTrackingStatusUnknown) {
					[self statusOfTrackedNickname:trackedUser changedTo:trackingStatus notify:YES];
				}
			}]; // for

			if (self.invokingISONCommandForFirstTime) { // Reset internal property
				self.invokingISONCommandForFirstTime = NO;
			}

			/* Update private messages */
			for (IRCChannel *channel in self.channelList) {
				if (channel.privateMessage == NO) {
					continue;
				}

				if (channel.isActive) {
					/* If the user is no longer on, deactivate the private message */
					if ([onlineNicknames containsObjectIgnoringCase:channel.name] == NO) {
						[channel deactivate];

						[mainWindow() reloadTreeItem:channel];
					}
				} else {
					/* Activate the private message if the user is back online */
					if ([onlineNicknames containsObjectIgnoringCase:channel.name]) {
						[channel activate];

						[mainWindow() reloadTreeItem:channel];
					}
				}
			}

			break;
		}
		case RPL_WATCHSTAT:
		case RPL_WATCHLIST:
		case RPL_WATCHOFF:
//		case RPL_CLEARWATCH: /* Not implemented by any IRCd */
		case RPL_ENDOFWATCHLIST:
		case RPL_MONLIST:
		case RPL_ENDOFMONLIST:
		{
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case RPL_REAWAY:
		case RPL_GONEAWAY:
		case RPL_NOTAWAY:
		case RPL_LOGON:
		case RPL_LOGOFF:
		case RPL_NOWON:
		case RPL_NOWOFF:
		{
			NSAssertReturnR([m paramsCount] > 4, YES);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			/* Process reply */
			[self _trackedNickname:[m paramAt:1] changedWithNumeric:numeric];

			break;
		}
		case ERR_TOOMANYWATCH:
		case ERR_MONLISTFULL:
		{
			/* This message is always printed because Textual does not
			 make an effort to check the maximum allowance for this
			 command. We therefore want a user to know why tracking
			 breaks in Textual instead of blaming it on a bug. */
			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		case RPL_MONONLINE:
		case RPL_MONOFFLINE:
		{
			NSAssertReturnR([m paramsCount] == 2, YES);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			/* Process reply */
			NSString *changedUsersString = [m paramAt:1];

			NSArray *changedUsers = [changedUsersString componentsSeparatedByString:@","];

			for (NSString *changedUser in changedUsers) {
				NSString *nickname = nil;

				if ([changedUser hostmaskComponents:&nickname username:NULL address:NULL onClient:self] == NO) {
					nickname = changedUser;
				}

				[self _trackedNickname:nickname changedWithNumeric:numeric];
			}

			break;
		}
		case RPL_TARGUMODEG:
		{
			// Ignore. 717 will take care of notification.

			break;
		}
		case RPL_TARGNOTIFY:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];

			[self printDebugInformation:TXTLS(@"IRC[11i-ev]", nickname)];

			break;
		}
		case RPL_UMODEGMSG:
		{
			NSAssertReturnR([m paramsCount] == 4, YES);

			NSAssertReturnR(printMessage, YES);

			NSString *nickname = [m paramAt:1];
			NSString *hostmask = [m paramAt:2];

			NSString *message = TXTLS(@"IRC[3yj-in]", nickname, hostmask);

			IRCChannel *channel = nil;

			if ([TPCPreferences locationToSendNotices] == TXNoticeSendLocationSelectedChannel) {
				channel = [mainWindow() selectedChannelOn:self];
			}

			if (channel) {
				[self printDebugInformation:message inChannel:channel];
			} else {
				[self printDebugInformationToConsole:message];
			}

			break;
		}
		default:
		{
			return NO;
		}
	} // switch()

	return YES;
}

/* A WATCH or MONITOR reply about one user: update the user if they are
 on the tracked list (the address book) */
- (void)_trackedNickname:(NSString *)nickname changedWithNumeric:(NSInteger)numeric
{
	IRCAddressBookEntry *addressBookEntry =	[self findUserTrackingAddressBookEntryForNickname:nickname];

	if (addressBookEntry == nil) {
		return;
	}

	switch (numeric) {
		case RPL_REAWAY:
		case RPL_GONEAWAY: // is away
		{
			[self modifyUserWithNickname:nickname asAway:YES];

			break;
		}
		case RPL_NOTAWAY: // is no longer away
		{
			[self modifyUserWithNickname:nickname asAway:NO];

			break;
		}
		case RPL_LOGON: // logged online
		case RPL_MONONLINE:
		{
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];

			break;
		}
		case RPL_LOGOFF: // logged offline
		case RPL_MONOFFLINE:
		{
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];

			break;
		}
		case RPL_NOWON: // is online
		{
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusAvailable notify:NO];

			break;
		}
		case RPL_NOWOFF: // is offline
		{
			[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusNotAvailable notify:NO];

			break;
		}
		default:
		{
			break;
		}
	} // switch()
}

/* A WHO or WHOX line: update the user (and their account, when WHOX reported it) and their membership */
- (void)processWhoReply:(IRCWhoReply *)reply
{
	NSParameterAssert(reply != nil);

	IRCChannel *channel = [self findChannel:reply.channelName];

	if (channel == nil) {
		return;
	}

	NSString *nickname = reply.nickname;

	/* Flags: <H|G>[*][member prefixes] */
	NSString *flags = reply.flags;

	BOOL isAway = NO;
	BOOL isIRCop = NO;

	NSMutableString *userModes = [NSMutableString string];

	for (NSUInteger i = 0; i < flags.length; i++) {
		NSString *character = [flags stringCharacterAtIndex:i];

		if ([character isEqualToString:@"G"]) {
			isAway = self.monitorAwayStatus;

			continue;
		} else if ([character isEqualToString:@"*"]) {
			isIRCop = YES;

			continue;
		}

		NSString *modeSymbol = [self.supportInfo modeSymbolForUserPrefix:character];

		if (modeSymbol == nil) {
			continue;
		}

		[userModes appendString:modeSymbol];
	}

	/* Find global user and create mutable copy */
	IRCUser *user = [self findUser:nickname];

	IRCUserMutable *userMutable = nil;

	if (user == nil) {
		userMutable = [[IRCUserMutable alloc] initWithNickname:nickname onClient:self];
	} else {
		userMutable = [user mutableCopy];
	}

	userMutable.nickname = nickname;
	userMutable.username = reply.username;
	userMutable.address = reply.address;

	userMutable.isAway = isAway;
	userMutable.isIRCop = isIRCop;

	if (reply.realName) {
		userMutable.realName = reply.realName;
	}

	if (reply.accountKnown) {
		userMutable.account = reply.account;

		if (channel.receivedWhoxAccountData == NO) {
			channel.receivedWhoxAccountData = YES;

			channel.whoxRefreshPending = YES;
		}
	}

	/* Insert the user into the client and return the final copy that was */
	BOOL userChanged = (user != nil && [user isEqual:userMutable] == NO);

	IRCUser *userAdded = nil;

	if (user == nil || userChanged) {
		userAdded = [self addUserAndReturn:userMutable];
	} else {
		userAdded = user;
	}

	/* The membership of the user as it is now */
	IRCChannelUser *member = [userAdded userAssociatedWithChannel:channel];

	if (member == nil)
	{
		IRCChannelUserMutable *memberMutable = [[IRCChannelUserMutable alloc] initWithUser:userAdded];

		memberMutable.modes = userModes;

		[channel addMember:memberMutable];
	}
	else if (userChanged)
	{
		/* Determine whether the users were modified in such a way that
		 they require their cell in the user list be resorted. */
		/* We do not want to resort unless absolutely necessary because
		 sorting a channel with a few hundred users has overhead. */
		BOOL IRCopStatusChanged = (user.isIRCop != userAdded.isIRCop);

		BOOL replaceInAllChannels = (IRCopStatusChanged && [TPCPreferences memberListSortFavorsServerStaff]);

		if (IRCopStatusChanged) {
			[channel replaceMember:member
						withMember:member
							resort:YES
			  replaceInAllChannels:replaceInAllChannels];
		}
		else if (user.isAway != userAdded.isAway || NSObjectsAreEqual(user.account, userAdded.account) == NO)
		{
			[mainWindow() updateDrawingForUserInUserList:userAdded];
		}
	}

	/* Update local cache of our hostmask */
	if ([self nicknameIsMyself:nickname]) {
		self.userHostmask = [NSString stringWithFormat:@"%@!%@@%@", nickname, reply.username, reply.address];
	}
}

/* SASL authentication. Returns NO for other numerics. */
- (BOOL)_receiveSASLNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	switch (numeric) {
		case RPL_LOGGEDIN:
		{
			NSAssertReturnR([m paramsCount] == 4, YES);

			[self enableCapability:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL];

			if (printMessage) {
				[self print:[m sequence:3]
						 by:nil
				  inChannel:nil
					 asType:TVCLogLineTypeDebug
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_LOGGEDOUT:
		{
			NSAssertReturnR([m paramsCount] == 3, YES);

			[self resetSASLNegotiation];

			/* NickServ may ask to identify again */
			self.isAuthenticatedWithSASL = NO;

			if (printMessage) {
				[self print:[m sequence:2]
						 by:nil
				  inChannel:nil
					 asType:TVCLogLineTypeDebug
					command:m.command
				 receivedAt:m.receivedAt];
			}

			break;
		}
		case RPL_SASLMECHS:
		{
			/* Followed by ERR_SASLFAIL; narrows what is tried next */
			if ([m paramsCount] >= 2) {
				[self receiveSASLMechanismList:[m paramAt:1]];
			}

			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		case ERR_SASLFAIL:
		{
			if (printMessage) {
				[self printErrorReply:m];
			}

			/* The next mechanism (a server may lack SCRAM credentials for an account) */
			if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation] && [self sendNextSASLMechanism]) {
				break;
			}

			if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation]) {
				[self disablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

				[self resumeCapabilityNegotiation];
			}

			break;
		}
		case RPL_SASLSUCCESS:
		case ERR_NICKLOCKED:
		case ERR_SASLTOOLONG:
		case ERR_SASLABORTED:
		case ERR_SASLALREADY:
		{
			if (numeric == RPL_SASLSUCCESS) {
				self.isAuthenticatedWithSASL = YES;
			}

			if (printMessage) {
				if (numeric == RPL_SASLSUCCESS) { // success
					[self printReply:m];
				} else {
					[self printErrorReply:m];
				}
			}

			if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation]) {
				[self disablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

				[self resumeCapabilityNegotiation];
			}

			break;
		}
		default:
		{
			return NO;
		}
	} // switch()

	return YES;
}

/* We will handle custom WHOIS responses here because there are so many
 that it is impossible to cover them all in -_receiveWhoisNumericReply:. */
- (void)_receiveUnhandledNumericReply:(IRCMessage *)m print:(BOOL)printMessage
{
	NSInteger numeric = m.commandNumeric;

	/* For those that we don't handle, give a plugin a chance first. */
	NSString *numericString = [NSString stringWithUnsignedInteger:numeric];

	if ([sharedPluginManager().supportedServerInputCommands containsObject:numericString]) {
		return;
	}

	if (printMessage) {
		/* Output custom WHOIS response to proper target */
		if (self.inWhoisResponse && m.paramsCount > 2) {
			[self printUnknownReply:m inChannel:[mainWindow() selectedChannelOn:self]];

			return;
		}

		/* Output unknown result */
		[self printUnknownReply:m];
	}
}

- (void)receiveErrorNumericReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSUInteger numeric = m.commandNumeric;

	BOOL printMessage = [self postReceivedMessage:m];

	switch (numeric) {
		case ERR_NOSUCHNICK:
		{
			NSAssertReturn(printMessage);

			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel) {
				[self printErrorReply:m inChannel:channel withSequence:2];
			} else {
				[self printErrorReply:m];
			}

			break;
		}
		case ERR_NOSUCHSERVER:
		case ERR_NOSUCHCHANNEL:
		{
			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		case ERR_NICKNAMEINUSE:
		case ERR_ERRONEUSNICKNAME:
		{
			if (self.isLoggedIn) {
				if (printMessage) {
					[self printErrorReply:m];
				}

				break;
			}

			[self receiveNicknameCollisionError:m];

			break;
		}
		case ERR_UNAVAILRESOURCE:
		{
			NSString *target = [m paramAt:1];

			if (self.isLoggedIn || [self stringIsNickname:target] == NO) {
				if (printMessage) {
					[self printErrorReply:m];
				}

				break;
			}

			[self receiveNicknameCollisionError:m];

			break;
		}
		case ERR_CANNOTSENDTOCHAN:
		{
			NSAssertReturn(printMessage);

			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel) {
				[self printErrorReply:m inChannel:channel withSequence:2];
			} else {
				[self printErrorReply:m];
			}

			break;
		}
		case ERR_ADMONLY:
		case ERR_BADCHANMASK:
		case ERR_BADCHANNAME:
		case ERR_BADCHANNEL:
		case ERR_BADCHANNELKEY:
		case ERR_BANNEDFROMCHAN:
		case ERR_CHANNELISFULL:
		case ERR_DELAYREJOIN:
		case ERR_FORBIDDENCHANNEL:
		case ERR_INVITEONLYCHAN:
		case ERR_LINKCHANNEL:
		case ERR_NEEDREGGEDNICK:
		case ERR_NOHIDING:
		case ERR_OPERONLY:
		case ERR_OPERSPVERIFY:
		case ERR_SECUREONLYCHAN:
		case ERR_THROTTLE:
		case ERR_TOOMANYCHANNELS:
		case ERR_TOOMANYJOINS:
		{
			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel) {
				channel.errorOnLastJoinAttempt = YES;

				/* In addition to the console, print join errors in
				 the channel itself because user might check there. */
				if (printMessage) {
					[self printErrorReply:m inChannel:channel withSequence:2];
				}
			}

			/* Print to console */
			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		case ERR_WHOSYNTAX:
		case ERR_WHOLIMEXCEED:
		{
			[self.requestedCommands recordWhoRequestClosed];

			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		case ERR_DISABLED:
		case ERR_UNKNOWNCOMMAND:
		case ERR_NEEDMOREPARAMS:
		{
			NSString *command = [m paramAt:1];

			if ([command isEqualToString:@"ISON"]) {
				[self.requestedCommands recordIsonRequestClosed];
			} else if ([command isEqualToString:@"WHO"]) {
				[self.requestedCommands recordWhoRequestClosed];
			}

			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		default:
		{
			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
	} // switch()
}

- (void)receiveNicknameCollisionError:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (self.isConnected == NO || self.isLoggedIn) {
		return;
	}

	NSArray *alternateNicknames = self.config.alternateNicknames;

	NSString *tryingNickname = self.tryingNicknameSentNickname;

	[self printDebugInformationToConsole:TXTLS(@"IRC[js3-9v]", tryingNickname)];

	NSUInteger tryingNicknameNumber = self.tryingNicknameNumber;

	if (alternateNicknames.count > tryingNicknameNumber) {
		NSString *nickname = alternateNicknames[tryingNicknameNumber];

		[self changeNickname:nickname];
	} else {
		[self tryAnotherNickname];
	}

	self.tryingNicknameNumber += 1;
}

- (void)tryAnotherNickname
{
	if (self.isConnected == NO || self.isLoggedIn) {
		return;
	}

	/* IRCISupportInfo would not be populated by now which means we cannot use a
	 server-specific maximum nickname length value at this point. */
	const NSUInteger maximumLength = IRCProtocolDefaultNicknameMaximumLength;

	NSString *tryingNickname = [self.tryingNicknameSentNickname padNicknameWithCharacter:'_' maximumLength:maximumLength];

	if (tryingNickname) {
		self.tryingNicknameSentNickname = tryingNickname;
	} else {
		self.tryingNicknameSentNickname = @"0";
	}

	[self changeNickname:self.tryingNicknameSentNickname];
}

@end

NS_ASSUME_NONNULL_END
