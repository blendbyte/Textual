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
#import "IRCUserListPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Connection)

#pragma mark -
#pragma mark IRCConnection Delegate

- (void)resetAllPropertyValues
{
	// Some properties are purposely excluded from this method
	// because their state must be kept or they are reset elsewhere

	[self.batchMessages dequeueEntries];

	self.connectDelay = 0;

	self.invokingISONCommandForFirstTime = NO;

	self.isAutojoining = NO;
	self.isAutojoined = NO;

	self.autojoinDelayedWarningCount = 0;

	self.isConnected = NO;
	self.isConnecting = NO;
	self.isLoggedIn = NO;
	self.isQuitting = NO;
	self.isDisconnecting = NO;

	self.inWhoisResponse = NO;
	self.inWhowasResponse = NO;

	self.isWaitingForNickServ = NO;
	self.serverHasNickServ = NO;
	self.userIsIdentifiedWithNickServ = NO;
	self.isAuthenticatedWithSASL = NO;
	self.nickServVerificationWarningShown = NO;

	self.CTCPReplyCount = 0;
	self.CTCPReplyCountStarted = 0;
	self.CTCPReplyCountBySender = nil;

	self.userIsAway = NO;
	self.userIsIRCop = NO;

	self.isConnectedToZNC = NO;
	self.zncBouncerIsSendingCertificateInfo = NO;
	self.zncBouncerCertificateChainDataMutable = nil;
	self.zncBouncerIsPlayingBackHistory = NO;

	self.reconnectEnabled = NO;

	self.timeoutWarningShownToUser = NO;

	self.lastWhoRequestChannelListIndex = 0;

	self.server = nil;

	self.userHostmask = nil;
	self.userNickname = nil;

	self.tryingNicknameNumber = 0;
	self.tryingNicknameSentNickname = nil;

	self.preAwayUserNickname = nil;

	self.lastMessageReceived = 0;

	[self resetCapabilities];

	[self.knownUsers removeAllUsers];
}

- (void)changeStateOff
{
	[self changeStateOffWithError:nil];
}

- (void)changeStateOffWithError:(nullable NSError *)disconnectError
{
	if (self.isConnecting == NO && self.isConnected == NO) {
		return;
	}

	BOOL isTerminating = self.isTerminating;

	self.socket = nil;

	[self removeTimedCommands];

	[self removeRequestedCommands];

	[self stopAutojoinTimer];
	[self stopAutojoinNextJoinTimer];
	[self stopAutojoinDelayedWarningTimer];
	[self stopISONTimer];
	[self stopPongTimer];
	[self stopRetryTimer];

	[self cancelPerformRequests];

	if (isTerminating == NO && self.reconnectEnabled) {
		[self startReconnectTimer];
	}

	[self.supportInfo reset];

	[self clearAddressBookCache];

	[self clearTrackedUsers];

	if (isTerminating == NO) {
		/* -prepareForApplicationTermination in TVCLogController will cancel
		 all operations for this client for us during termination. */
		[[TXSharedApplication sharedPrintingQueue] cancelOperationsForClient:self];

		IRCClientDisconnectMode disconnectType = self.disconnectType;

		if (disconnectError) {
			// TODO: Don't hardcode the error domain and code
			if ( disconnectError.code == IRCConnectionErrorCodeBadCertificate &&
				[disconnectError.domain isEqualToString:IRCConnectionErrorDomain])
			{
				disconnectType = IRCClientDisconnectModeBadCertificate;
			}

			[self printError:disconnectError.localizedDescription asCommand:TVCLogLineDefaultCommandValue];
		}

		NSString *disconnectMessage = nil;

		switch (disconnectType) {
			case IRCClientDisconnectModeNormal:
			{
				disconnectMessage = TXTLS(@"IRC[9b4-10]");

				break;
			}
			case IRCClientDisconnectModeComputerSleep:
			{
				disconnectMessage = TXTLS(@"IRC[drg-b7]");

				break;
			}
			case IRCClientDisconnectModeBadCertificate:
			{
				disconnectMessage = TXTLS(@"IRC[zro-bg]");

				break;
			}
			case IRCClientDisconnectModeServerRedirect:
			{
				disconnectMessage = TXTLS(@"IRC[wcl-po]");

				break;
			}
			case IRCClientDisconnectModeReachabilityChange:
			{
				disconnectMessage = TXTLS(@"IRC[isx-fi]");

				break;
			}
		} // switch()

		for (IRCChannel *channel in self.channelList) {
			if (channel.isActive == NO) {
				channel.errorOnLastJoinAttempt = NO;
			} else {
				[channel deactivate];

				if (channel.isUtility) {
					continue;
				}

				[self printDebugInformation:disconnectMessage inChannel:channel];
			}
		}

		[self printDebugInformationToConsole:disconnectMessage];

		[self.viewController mark];

		if (self.isConnected) {
			[self notifyEvent:TXNotificationTypeDisconnect lineType:TVCLogLineTypeDebug];
		}

		[self postEventToViewController:@"serverDisconnected"];
	}

	[self endLoggingSessions];

	[self resetAllPropertyValues];

	if (isTerminating == NO) {
		[mainWindow() reloadTreeGroup:self];

		[mainWindow() updateTitleFor:self];
	}
}

- (void)ircConnection:(IRCConnection *)sender willConnectToProxy:(NSString *)proxyHost port:(uint16_t)proxyPort
{
	NSParameterAssert(sender == self.socket);

	IRCConnectionProxyType proxyType = self.socket.config.proxyType;

	if (proxyType == IRCConnectionProxyTypeHTTP || proxyType == IRCConnectionProxyTypeHTTPS) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[oby-av]", proxyHost, proxyPort)];
	} else {
		[self printDebugInformationToConsole:TXTLS(@"IRC[ni5-cy]", proxyHost, proxyPort)];
	}
}

- (void)ircConnectionDidSecureConnection:(IRCConnection *)sender withProtocolType:(tls_protocol_version_t)protocolType cipherSuite:(tls_ciphersuite_t)cipherSuite
{
	NSParameterAssert(sender == self.socket);

	NSString *protocolDescription = [RCMSecureTransport descriptionForProtocolType:protocolType];

	NSString *cipherDescription = [RCMSecureTransport descriptionForCipherSuite:cipherSuite];

	if (protocolDescription == nil || cipherDescription == nil) {
		return;
	}

	NSString *description = nil;

	if ([RCMSecureTransport isCipherSuiteDeprecated:cipherSuite] == NO) {
		description = TXTLS(@"IRC[uyz-4r]", protocolDescription, cipherDescription);
	} else {
		description = TXTLS(@"IRC[xwj-xy]", protocolDescription, cipherDescription);
	}

	[self printDebugInformationToConsole:TXTLS(@"IRC[ex4-f8]", description)];
}

- (void)ircConnectionDidConnect:(IRCConnection *)sender
{
	NSParameterAssert(sender == self.socket);

	if (self.isTerminating) {
		return;
	}

	[self startRetryTimer];

	/* If the address we are connecting to is not an IP address,
	 then we report back the actual IP address it was resolved to. */
	NSString *connectedAddress = self.socket.connectedAddress;

	if (connectedAddress == nil || self.socket.config.serverAddress.IPAddress) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[4vt-ow]")];
	} else {
		[self printDebugInformationToConsole:TXTLS(@"IRC[l21-p7]", connectedAddress)];
	}

	self.isConnecting = NO;
	self.isConnected = YES;

	self.userNickname = self.config.nickname;

	self.tryingNicknameSentNickname = self.config.nickname;

	[mainWindow() updateTitleFor:self];

	[RZNotificationCenter() postNotificationName:IRCClientDidConnectNotification object:self];

	NSString *username = self.config.username;
	NSString *realName = self.config.realName;

	NSString *modeSymbols = @"0";

	NSString *serverPassword = self.server.serverPassword;

	if (self.config.setInvisibleModeOnConnect) {
		modeSymbols = @"8";
	}

	if (username.length == 0) {
		username = self.config.nickname;
	}

	if (realName.length == 0) {
		realName = self.config.nickname;
	}

	[self sendCapability:@"LS" data:@"302"];

	if (serverPassword) {
		[self sendPassword:serverPassword];
	}

	[self changeNickname:self.tryingNicknameSentNickname];

	[self send:@"USER", username, modeSymbols, @"*", realName, nil];
}

- (void)ircConnection:(IRCConnection *)sender didDisconnectWithError:(nullable NSError *)disconnectError
{
	NSParameterAssert(sender == self.socket);

//	if (self.isTerminating) {
//		return;
//	}

	[self changeStateOffWithError:disconnectError];

	/* Termination has its own slot: reconnect paths (retry, /CONN,
	 redirects, flood errors, irssi proxy) set disconnectCallback and must
	 not replace what quitting the app waits for */
	dispatch_block_t callback = (self.terminationCallback ?: self.disconnectCallback);

	self.terminationCallback = nil;
	self.disconnectCallback = nil;

	if (callback) {
		callback();
	}

	[RZNotificationCenter() postNotificationName:IRCClientDidDisconnectNotification object:self];
}

- (void)ircConnectionDidCloseReadStream:(IRCConnection *)sender
{
	NSParameterAssert(sender == self.socket);

	if (self.isTerminating) {
		return;
	}

	if (self.isDisconnecting) {
		return;
	}

	if (self.isQuitting) {
		[self disconnect];

		return;
	}

	[self printDebugInformationToConsole:TXTLS(@"IRC[5h5-sl]")];
}

/* Called on the main queue, one line at a time, in order: parsing depends
 on state the previous lines changed (capabilities, batches, ISUPPORT) */
- (void)ircConnection:(IRCConnection *)sender didReceiveData:(NSString *)data
{
	NSParameterAssert(sender == self.socket);

	if (self.isConnected == NO || self.isTerminating) {
		return;
	}

	if (data.length == 0) {
		return;
	}

	self.lastMessageReceived = [NSDate timeIntervalSince1970];

	worldController().bandwidthIn += data.length;

	worldController().messagesReceived += 1;

	[self rawDataLogIncomingTraffic:data];

	if ([TPCPreferences removeAllFormatting]) {
		data = data.stripIRCEffects;
	}

	IRCMessage *message = [[IRCMessage alloc] initWithLine:data onClient:self];

	if (message == nil) {
		return;
	}

	message = [THOPluginDispatcher interceptServerInput:message for:self];

	if (message == nil) {
		return;
	}

	if ([self filterBatchCommandIncomingData:message]) {
		return;
	}

	[self processIncomingMessage:message];
}

- (void)processIncomingMessageAttributes:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (message.isHistoric == NO) {
		return;
	}

	NSTimeInterval receivedTime = message.receivedAt.timeIntervalSince1970;

	if (receivedTime <= self.lastMessageServerTime) {
		return;
	}

	self.lastMessageServerTime = receivedTime;

	/* If the playback module is in use, then all messages are
	 set as historic, so we set any lines above our current 
	 reference date as not historic to avoid collisions. */
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback]) {
		[message markAsNotHistoric];
	}
}

- (void)processIncomingMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self _processIncomingMessage:message];
	});
}

- (void)_processIncomingMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	[self processIncomingMessageAttributes:message];

	if (message.commandNumeric > 0) {
		[self receiveNumericReply:message];
	} else {
		NSUInteger commandNumeric = [IRCCommandIndex indexOfRemoteCommand:message.command];

		switch (commandNumeric) {
			case IRCRemoteCommandNotice: // Command: NOTICE
			case IRCRemoteCommandPrivmsg: // Command: PRIVMSG
			{
				[self receivePrivmsgAndNotice:message];

				break;
			}
			case IRCRemoteCommandError: // Command: ERROR
			{
				[self receiveError:message];

				break;
			}
			case IRCRemoteCommandInvite: // Command: INVITE
			{
				[self receiveInvite:message];

				break;
			}
			case IRCRemoteCommandJoin: // Command: JOIN
			{
				[self receiveJoin:message];

				break;
			}
			case IRCRemoteCommandKick: // Command: KICK
			{
				[self receiveKick:message];

				break;
			}
			case IRCRemoteCommandKill: // Command: KILL
			{
				[self receiveKill:message];

				break;
			}
			case IRCRemoteCommandMode: // Command: MODE
			{
				[self receiveMode:message];

				break;
			}
			case IRCRemoteCommandNick: // Command: NICK
			{
				[self receiveNick:message];

				break;
			}
			case IRCRemoteCommandPart: // Command: PART
			{
				[self receivePart:message];

				break;
			}
			case IRCRemoteCommandPing: // Command: PING
			{
				[self receivePing:message];

				break;
			}
			case IRCRemoteCommandQuit: // Command: QUIT
			{
				[self receiveQuit:message];

				break;
			}
			case IRCRemoteCommandTopic: // Command: TOPIC
			{
				[self receiveTopic:message];

				break;
			}
			case IRCRemoteCommandWallops: // Command: WALLOPS
			{
				[self receiveWallops:message];

				break;
			}
			case IRCRemoteCommandAuthenticate: // Command: AUTHENTICATE
			case IRCRemoteCommandCap: // Command: CAP
			{
				[self updateConnectedToZNCPropertyWithMessage:message];

				[self receiveCapabilityOrAuthenticationRequest:message];

				break;
			}
			case IRCRemoteCommandAway: // Command: AWAY (away-notify CAP)
			{
				[self receiveAwayNotifyCapability:message];

				break;
			}
			case IRCRemoteCommandBatch: // BATCH
			{
				[self receiveBatch:message];

				break;
			}
			case IRCRemoteCommandCertinfo: // CERTINFO
			{
				[self receiveCertInfo:message];

				break;
			}
			case IRCRemoteCommandChghost:
			{
				[self receiveChangeHost:message];

				break;
			}
		} // switch
	}

	[self processBundlesServerMessage:message];
}

- (void)ircConnection:(IRCConnection *)sender willSendData:(NSString *)data
{
	NSParameterAssert(sender == self.socket);

	if (self.isTerminating) {
		return;
	}

	[self rawDataLogOutgoingTraffic:data];
}

@end

NS_ASSUME_NONNULL_END
