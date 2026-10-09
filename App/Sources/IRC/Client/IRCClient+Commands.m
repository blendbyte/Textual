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
#import "IRCStrictTransportSecurityPrivate.h"
#import "IRCWhoReplyPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Commands)

#pragma mark -
#pragma mark Commands

- (void)connect
{
	[self connect:IRCClientConnectModeNormal];
}

- (void)connect:(IRCClientConnectMode)connectMode
{
	[self connect:connectMode bypassProxy:NO];
}

- (void)connect:(IRCClientConnectMode)connectMode bypassProxy:(BOOL)bypassProxy
{
	/* Do not allow a connect to occur until the current 
	 socket has completed disconnecting */
	if (self.isConnecting || self.isConnected || self.isQuitting || self.isDisconnecting) {
		return;
	}

	/* Check if system is sleeping. */
	if ([XRSystemInformation systemIsSleeping]) {
		LogToConsoleInfo("Refusing to connect because system is sleeping");

		return;
	}

	/* Do we have somewhere to connect to? */
	NSArray *servers = self.config.serverList;

	if (servers.count == 0) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[iaa-0u]")];

		return;
	}

	/* Begin populating configuration */
	/* Temporary values take priority. When a temporary server
	 address is specified, then the temporary port and TLS setting
	 are used too (6697 with TLS, 6667 without, if none was given). Nothing else from
	 the current server configuration is read if there is a
	 temporary server. */
	NSString *serverAddress = nil;

	uint16_t serverPort = IRCConnectionDefaultServerPort;

	BOOL connectionPrefersSecuredConnection = NO;

	if (self.temporaryServerAddressOverride) {
		serverAddress = self.temporaryServerAddressOverride;

		connectionPrefersSecuredConnection = self.temporaryServerPrefersSecuredConnection;

		if (self.temporaryServerPortOverride > 0 &&
			self.temporaryServerPortOverride <= TXMaximumTCPPort)
		{
			serverPort = self.temporaryServerPortOverride;
		} else if (connectionPrefersSecuredConnection) {
			serverPort = IRCConnectionDefaultSecureServerPort;
		}
	}

	if (serverAddress.isValidInternetAddress == NO) {
		NSUInteger serverIndex = self.lastServerSelected;

		if (serverIndex == NSNotFound) {
			serverIndex = 0;
		} else {
			serverIndex += 1;

			if (serverIndex >= servers.count) {
				serverIndex = 0;
			}
		}

		self.lastServerSelected = serverIndex;

		IRCServer *server = servers[serverIndex];

		serverAddress = server.serverAddress;
		serverPort = server.serverPort;

		connectionPrefersSecuredConnection = server.prefersSecuredConnection;

		self.server = server;
	}

	/* strict-transport-security: a host with a policy is only reached over TLS */
	if (connectionPrefersSecuredConnection == NO) {
		uint16_t policyPort = [[IRCStrictTransportSecurity sharedPolicies] portForHost:serverAddress];

		if (policyPort > 0) {
			[self printDebugInformationToConsole:TXTLS(@"IRC[st5-u2]", serverAddress, policyPort)];

			serverPort = policyPort;

			connectionPrefersSecuredConnection = YES;
		}
	}

	/* Do not wait for an actual connect before destroying the temporary
	 store. Once its defined, its to be nil'd out no matter what. */
	self.temporaryServerAddressOverride = nil;
	self.temporaryServerPortOverride = 0;
	self.temporaryServerPrefersSecuredConnection = NO;

	/* Reset status */
	self.connectType = connectMode;

	self.disconnectType = IRCClientDisconnectModeNormal;

	self.isConnecting = YES;

	/* Disable reconnect attempt but permit more */
	[self stopReconnectTimer];

	self.reconnectEnabled = YES;

	/* Present status to user */
	[mainWindow() updateTitleFor:self];

	if (connectMode == IRCClientConnectModeReconnect) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[xxb-y2]")];
	} else if (connectMode == IRCClientConnectModeRetry) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[ky3-36]")];
	}

	/* To provide user with similar behavior, when migrating -connectionPrefersIPv4
	 in IRCClientConfig, we set the address type to IRCConnectionAddressTypeIPv4.
	 We check if both values are set to offer the user a warning that the preference
	 they had has changed in a way they may not want. When user changes the address
	 type in Server Properties, we unset -connectionPrefersIPv4 so that the warning
	 does not appear again, ever. */
	IRCConnectionAddressType addressType = self.config.addressType;

	if (self.config.showConnectionPrefersIPv4Warning) {
		[self printDebugInformation:TXTLS(@"IRC[w05-ph]")];
	}

	[self printDebugInformationToConsole:TXTLS(@"IRC[o77-ls]", serverAddress, serverPort)];

	[RZNotificationCenter() postNotificationName:IRCClientWillConnectNotification object:self];

	/* Create socket */
	IRCConnectionConfigMutable *socketConfig = [IRCConnectionConfigMutable new];

	socketConfig.addressType = addressType;

	socketConfig.serverAddress = serverAddress;
	socketConfig.serverPort = serverPort;

	IRCConnectionProxyType proxyType = self.config.proxyType;

	socketConfig.cipherSuites = self.config.cipherSuites;

	socketConfig.connectionPrefersSecuredConnection = connectionPrefersSecuredConnection;
	socketConfig.connectionShouldValidateCertificateChain = self.config.validateServerCertificateChain;

	socketConfig.identityClientSideCertificate = self.config.identityClientSideCertificate;

	if (bypassProxy == NO) {
		socketConfig.proxyType = proxyType;

		if (socketConfig.proxyType == IRCConnectionProxyTypeSocks5 ||
			socketConfig.proxyType == IRCConnectionProxyTypeHTTP ||
			socketConfig.proxyType == IRCConnectionProxyTypeHTTPS)
		{
			socketConfig.proxyPort = self.config.proxyPort;
			socketConfig.proxyAddress = self.config.proxyAddress;
			socketConfig.proxyPassword = self.config.proxyPassword;
			socketConfig.proxyUsername = self.config.proxyUsername;
		}
	}

	socketConfig.floodControlDelayInterval = self.config.floodControlDelayTimerInterval;
	socketConfig.floodControlMaximumMessages = self.config.floodControlMaximumMessages;

	socketConfig.connectionPrefersModernCiphersOnly = [TPCPreferences preferModernCiphers];

	self.socket = [[IRCConnection alloc] initWithConfig:socketConfig onClient:self];

	[self.socket open];

	/* Pass status to view controller */
	[self postEventToViewController:@"serverConnecting"];
}

- (void)autoConnectWithDelay:(NSUInteger)delay afterWakeUp:(BOOL)afterWakeUp
{
	self.connectDelay = delay;

	/* After waking up, the connection counts as a reconnect */
	if (delay == 0) {
		if (afterWakeUp) {
			[self autoConnectAfterWakeUpPerformConnect];
		} else {
			[self autoConnectPerformConnect];
		}

		return;
	}

	if (afterWakeUp) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[3s6-e6]", delay)];
	}

	SEL performConnect = (afterWakeUp ? @selector(autoConnectAfterWakeUpPerformConnect) : @selector(autoConnectPerformConnect));

	[self cs_reschedulePerformSelectorInCommonModes:performConnect withObject:nil afterDelay:delay];
}

- (void)autoConnectPerformConnect
{
	if (self.isConnecting || self.isConnected) {
		return;
	}

	[self connect];
}

- (void)autoConnectAfterWakeUpPerformConnect
{
	if (self.isConnecting || self.isConnected) {
		return;
	}

	self.reconnectEnabledBecauseOfSleepMode = YES;

	[self connect:IRCClientConnectModeReconnect];
}

- (void)afterDisconnectPerform:(void (^)(IRCClient *client))block
{
	NSParameterAssert(block != nil);

	__weak IRCClient *weakSelf = self;

	self.disconnectCallback = ^{
		IRCClient *client = weakSelf;

		if (client) {
			block(client);
		}
	};
}

- (void)disconnectThen:(void (^)(IRCClient *client))block
{
	[self afterDisconnectPerform:block];

	[self disconnect];
}

- (void)quitThen:(void (^)(IRCClient *client))block
{
	[self afterDisconnectPerform:block];

	[self quit];
}

- (void)disconnect
{
	[self cancelPerformRequestsWithSelector:@selector(disconnect) object:nil];

	if (self.isConnecting == NO && self.isConnected == NO) {
		return;
	}

	if (self.socket == nil) {
		return;
	}

	self.isDisconnecting = YES;

	[RZNotificationCenter() postNotificationName:IRCClientWillDisconnectNotification object:self];

	[self.socket close];
}

- (void)quit
{
	NSString *comment = nil;

	if (self.disconnectType == IRCClientDisconnectModeComputerSleep) {
		comment = self.config.sleepModeLeavingComment;
	} else {
		comment = self.config.normalLeavingComment;
	}

	[self quitWithComment:comment];
}

- (void)quitWithComment:(NSString *)comment
{
	NSParameterAssert(comment != nil);

	if ((self.isConnecting == NO && self.isConnected == NO) || self.isQuitting || self.isDisconnecting) {
		return;
	}

	self.isQuitting	= YES;

	[self cancelReconnect];

	if (self.isTerminating == NO) {
		[self postEventToViewController:@"serverDisconnecting"];
	}

	[RZNotificationCenter() postNotificationName:IRCClientWillSendQuitNotification object:self];

	[self.socket clearSendQueue];

	/* If -isLoggedIn is NO, then the connection does not need 
	 to be closed gracefully because the user hasn't even joined
	 a channel yet, so who are we doing it for? */
	if (self.isLoggedIn == NO) {
		[self disconnect];

		return;
	}

	[self send:@"QUIT", comment, nil];

	/* We give it two seconds before forcefully breaking so that the graceful
	 quit with the quit message above can be performed. */
	[self cs_reschedulePerformSelectorInCommonModes:@selector(disconnect) withObject:nil afterDelay:2.0];
}

- (void)cancelReconnect
{
	self.reconnectEnabled = NO;
	self.reconnectEnabledBecauseOfSleepMode = NO;

	[self stopReconnectTimer];

	[mainWindow() updateTitleFor:self];
}

- (void)changeNickname:(NSString *)newNickname
{
	NSParameterAssert(newNickname != nil);

	if (self.isConnected == NO) {
		return;
	}

	if (newNickname.length == 0) {
		return;
	}

	[self send:@"NICK", newNickname, nil];
}

- (void)joinKickedChannel:(IRCChannel *)channel
{
	[self joinChannel:channel];
}

- (void)joinChannel:(IRCChannel *)channel
{
	[self joinChannel:channel password:nil];
}

- (void)joinUnlistedChannel:(NSString *)channel
{
	[self joinUnlistedChannel:channel password:nil];
}

- (void)joinChannel:(IRCChannel *)channel password:(nullable NSString *)password
{
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO || channel.isActive) {
		return;
	}

	channel.status = IRCChannelStatusJoining;

	if (password == nil) {
		password = channel.secretKey;
	}

	[self forceJoinChannel:channel.name password:password];
}

- (void)joinUnlistedChannel:(NSString *)channel password:(nullable NSString *)password
{
	NSParameterAssert(channel != nil);

	if ([self stringIsChannelName:channel] == NO) {
		// Many IRCd (I don't know of any that don't) use "JOIN 0" as a
		// secret way to have the user part all channels they are in.
		if ([channel isEqualToString:@"0"]) {
			[self forceJoinChannel:channel password:password];
		}

		return;
	}

	IRCChannel *channelPointer = [self findChannel:channel];

	if (channelPointer) {
		[self joinChannel:channelPointer password:password];

		return;
	}

	[self forceJoinChannel:channel password:password];
}

- (void)forceJoinChannel:(NSString *)channel password:(nullable NSString *)password
{
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channel.length == 0) {
		return;
	}

	[self send:@"JOIN", channel, password, nil];
}

- (void)joinUnlistedChannelsWithStringAndSelectBestMatch:(NSString *)channels
{
	[self joinUnlistedChannelsWithStringAndSelectBestMatch:channels passwords:nil];
}

- (void)joinUnlistedChannelsWithStringAndSelectBestMatch:(NSString *)channels passwords:(nullable NSString *)passwords
{
	NSParameterAssert(channels != nil);

	if (channels.length == 0) {
		return;
	}

	NSArray *targets = [channels componentsSeparatedByString:@","];

	[self joinUnlistedChannelsAndSelectBestMatch:targets passwords:passwords];
}

- (void)joinUnlistedChannelsAndSelectBestMatch:(NSArray<NSString *> *)channels
{
	[self joinUnlistedChannelsAndSelectBestMatch:channels passwords:nil];
}

- (void)joinUnlistedChannelsAndSelectBestMatch:(NSArray<NSString *> *)channels passwords:(nullable NSString *)passwords
{
	NSParameterAssert(channels != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channels.count == 0) {
		return;
	}

	__block BOOL performJoin = YES;

	__block IRCChannel *channelToSelect = nil;

	for (NSString *channel in channels) {
		if (channelToSelect == nil && [self stringIsChannelName:channel]) {
			channelToSelect = [self findChannelOrCreate:channel];

			performJoin = (channelToSelect.isActive == NO || channels.count > 1);

			break;
		}
	}

	if (performJoin) {
		[self send:@"JOIN", [channels componentsJoinedByString:@","], passwords, nil];
	}

	if (channelToSelect) {
		[mainWindow() select:channelToSelect];
	}
}

- (void)joinChannels:(NSArray<IRCChannel *> *)channels
{
	NSParameterAssert(channels != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channels.count == 0) {
		return;
	}

	NSMutableString *joinStringWithoutKey = nil;
	NSMutableString *joinStringWithKey = nil;

	NSMutableString *keyString = nil;

	for (IRCChannel *channel in channels) {
		if (channel.isChannel == NO || channel.isActive) {
			continue;
		}

		channel.status = IRCChannelStatusJoining;

		NSString *password = nil;

		if (password == nil) {
			password = channel.secretKey;
		}

		if (password.length == 0) {
			if (joinStringWithoutKey == nil) {
				joinStringWithoutKey = [NSMutableString stringWithString:channel.name];
			} else {
				[joinStringWithoutKey appendFormat:@",%@", channel.name];
			}
		} else {
			if (joinStringWithKey == nil) {
				joinStringWithKey = [NSMutableString stringWithString:channel.name];
			} else {
				[joinStringWithKey appendFormat:@",%@", channel.name];
			}

			if (keyString == nil) {
				keyString = [NSMutableString stringWithString:password];
			} else {
				[keyString appendFormat:@",%@", password];
			}
		}
	}

	if (joinStringWithoutKey) {
		[self send:@"JOIN", joinStringWithoutKey, nil];
	}

	if (joinStringWithKey && keyString) {
		[self send:@"JOIN", joinStringWithKey, keyString, nil];
	}
}

- (void)partUnlistedChannel:(NSString *)channel
{
	[self partUnlistedChannel:channel withComment:nil];
}

- (void)partChannel:(IRCChannel *)channel
{
	[self partChannel:channel withComment:nil];
}

- (void)partUnlistedChannel:(NSString *)channel withComment:(nullable NSString *)comment
{
	NSParameterAssert(channel != nil);

	if ([self stringIsChannelName:channel] == NO) {
		return;
	}

	IRCChannel *channelPointer = [self findChannel:channel];

	if (channelPointer == nil) {
		return;
	}

	[self partChannel:channelPointer withComment:comment];
}

- (void)partChannel:(IRCChannel *)channel withComment:(nullable NSString *)comment
{
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channel.isChannel == NO || channel.isActive == NO) {
		return;
	}

	if (comment == nil) {
		comment = self.config.normalLeavingComment;
	}

	[self send:@"PART", channel.name, comment, nil];
}

- (void)sendWhoToChannel:(IRCChannel *)channel
{
	[self sendWhoToChannel:channel hideResponse:NO];
}

- (void)sendWhoToChannel:(IRCChannel *)channel hideResponse:(BOOL)hideResponse
{
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO) {
		return;
	}

	[self sendWhoToChannelNamed:channel.name hideResponse:hideResponse];
}

- (void)sendWhoToChannelNamed:(NSString *)channel
{
	[self sendWhoToChannelNamed:channel hideResponse:NO];
}

- (void)sendWhoToChannelNamed:(NSString *)channel hideResponse:(BOOL)hideResponse
{
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channel.length == 0) {
		return;
	}

	if (hideResponse == NO) {
		[self.requestedCommands recordWhoRequestOpenedAsVisible];
	} else {
		[self.requestedCommands recordWhoRequestOpened];
	}

	/* Textual's own requests ask WHOX for accounts too; a /WHO typed by the user stays plain */
	if (hideResponse && self.supportInfo.whoxSupported) {
		[self send:@"WHO", channel, IRCWhoReplyWhoxRequest, nil];

		return;
	}

	[self send:@"WHO", channel, nil];
}

- (void)sendWhois:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (nickname.length == 0) {
		return;
	}

	[self send:@"WHOIS", nickname, nickname, nil];
}

- (void)kick:(NSString *)nickname inChannel:(IRCChannel *)channel
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channel.isChannel == NO || channel.isActive == NO) {
		return;
	}

	if (nickname.length == 0) {
		return;
	}

	NSString *reason = [TPCPreferences defaultKickMessage];

	[self send:@"KICK", channel.name, nickname, reason, nil];
}

- (void)toggleAwayStatusWithComment:(nullable NSString *)comment
{
	if (self.userIsAway) {
		[self toggleAwayStatus:NO withComment:nil];
	} else {
		if (comment.length == 0) {
			comment = TXTLS(@"IRC[xog-in]");
		}

		[self toggleAwayStatus:YES withComment:comment];
	}
}

- (void)toggleAwayStatus:(BOOL)setAway
{
	NSString *comment = TXTLS(@"IRC[xog-in]");

	[self toggleAwayStatus:setAway withComment:comment];
}

- (void)toggleAwayStatus:(BOOL)setAway withComment:(nullable NSString *)comment
{
	NSParameterAssert(setAway == NO || comment != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (setAway) {
		[self send:@"AWAY", comment, nil];
	} else {
		[self send:@"AWAY", nil];
	}

	NSString *newNickname = nil;

	if (setAway) {
		newNickname = self.config.awayNickname;

		self.preAwayUserNickname = self.userNickname;
	} else {
		newNickname = self.preAwayUserNickname;

		self.preAwayUserNickname = nil;

		/* If we have an away nickname configured but no preAwayNickname set,
		 then use the configured nickname instead. User probably was on bouncer
		 and relaunched Textual, losing preAwayNickname.*/
		if (newNickname == nil && self.config.awayNickname.length > 0) {
			newNickname = self.config.nickname;
		}
	}

	if (newNickname) {
		[self changeNickname:newNickname];
	}
}

- (void)presentCertificateTrustInformation
{
	if (self.isSecured == NO) {
		return;
	}

	[self.socket openSecuredConnectionCertificateModal];
}

- (void)requestModesForChannel:(IRCChannel *)channel
{
	[self sendModes:nil withParameters:nil inChannel:channel];
}

- (void)requestModesForChannelNamed:(NSString *)channel
{
	[self sendModes:nil withParameters:nil inChannelNamed:channel];
}

- (void)sendModes:(nullable NSString *)modeSymbols withParameters:(nullable NSArray<NSString *> *)parameters inChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	[self sendModes:modeSymbols withParameters:parameters inChannelNamed:channel.name];
}

- (void)sendModes:(nullable NSString *)modeSymbols withParametersString:(nullable NSString *)parametersString inChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	[self sendModes:modeSymbols withParametersString:parametersString inChannelNamed:channel.name];
}

- (void)sendModes:(nullable NSString *)modeSymbols withParameters:(nullable NSArray<NSString *> *)parameters inChannelNamed:(NSString *)channel
{
	NSString *parametersString = [parameters componentsJoinedByString:@" "];

	[self sendModes:modeSymbols withParametersString:parametersString inChannelNamed:channel];
}

- (void)sendModes:(nullable NSString *)modeSymbols withParametersString:(nullable NSString *)parametersString inChannelNamed:(NSString *)channel
{
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channel.length == 0) {
		return;
	}

	[self send:@"MODE", channel, modeSymbols, parametersString, nil];
}

- (void)sendPing:(NSString *)tokenString
{
	NSParameterAssert(tokenString != nil);

	if (self.isConnected == NO) {
		return;
	}

	[self send:@"PING", tokenString, nil];
}

- (void)sendPong:(NSString *)tokenString
{
	NSParameterAssert(tokenString != nil);

	if (self.isConnected == NO) {
		return;
	}

	[self send:@"PONG", tokenString, nil];
}

- (void)sendInviteTo:(NSString *)nickname toJoinChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO) {
		return;
	}

	[self sendInviteTo:nickname toJoinChannelNamed:channel.name];
}

- (void)sendInviteTo:(NSString *)nickname toJoinChannelNamed:(NSString *)channel
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(channel != nil);

	if (nickname.length == 0 || channel.length == 0) {
		return;
	}

	[self send:@"INVITE", nickname, channel, nil];
}

- (void)requestTopicForChannel:(IRCChannel *)channel
{
	[self sendTopicTo:nil inChannel:channel];
}

- (void)requestTopicForChannelNamed:(NSString *)channel
{
	[self sendTopicTo:nil inChannelNamed:channel];
}

- (void)sendTopicTo:(nullable NSString *)topic inChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO || channel.isActive == NO) {
		return;
	}

	[self sendTopicTo:topic inChannelNamed:channel.name];
}

- (void)sendTopicTo:(nullable NSString *)topic inChannelNamed:(NSString *)channel
{
	NSParameterAssert(channel != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (channel.length == 0) {
		return;
	}

	[self send:@"TOPIC", channel, topic, nil];
}

- (void)sendCapability:(NSString *)subcommand data:(nullable NSString *)data
{
	NSParameterAssert(subcommand != nil);

	if (self.isConnected == NO) {
		return;
	}

	[self send:@"CAP", subcommand, data, nil];
}

- (void)sendCapabilityAuthenticate:(NSString *)data
{
	NSParameterAssert(data != nil);

	if (self.isConnected == NO) {
		return;
	}

	if (data.length == 0) {
		return;
	}

	[self send:@"AUTHENTICATE", data, nil];
}

- (void)sendIsonForNicknames:(NSArray<NSString *> *)nicknames
{
	[self sendIsonForNicknames:nicknames hideResponse:NO];
}

- (void)sendIsonForNicknames:(NSArray<NSString *> *)nicknames hideResponse:(BOOL)hideResponse
{
	NSParameterAssert(nicknames != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	/* A long list is split into lines that stay under the server's line
	 limit (R3.14). The tracking logic needs every nickname in one reply,
	 so the replies to a hidden request are collected and evaluated
	 together once the last one arrives (see RPL_ISON). */
	NSMutableArray<NSString *> *lines = [NSMutableArray array];

	NSMutableString *line = [NSMutableString string];

	for (NSString *nickname in nicknames) {
		NSUInteger nicknameLength = [nickname lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

		if (line.length > 0 && ([line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1 + nicknameLength) > _isonLineMaximumLength) {
			[lines addObject:[line copy]];

			[line setString:@""];
		}

		if (line.length > 0) {
			[line appendString:@" "];
		}

		[line appendString:nickname];
	}

	if (line.length > 0) {
		[lines addObject:[line copy]];
	}

	if (lines.count == 0) {
		return;
	}

	if (hideResponse) {
		[self.isonReplyNicknames removeAllObjects];

		[self.requestedCommands recordIsonRequestOpenedWithCount:lines.count];
	}

	for (NSString *nicknamesString in lines) {
		if (hideResponse == NO) {
			[self.requestedCommands recordIsonRequestOpenedAsVisible];
		}

		[self send:@"ISON", nicknamesString, nil];
	}
}

- (void)requestChannelList
{
	if (self.isLoggedIn == NO) {
		return;
	}

	[self send:@"LIST", nil];
}

- (void)sendPassword:(NSString *)password
{
	NSParameterAssert(password != nil);

	if (self.isConnected == NO) {
		return;
	}

	if (password.length == 0) {
		return;
	}

	[self send:@"PASS", password, nil];
}

- (void)modifyWatchListBy:(BOOL)adding nicknames:(NSArray<NSString *> *)nicknames
{
	NSParameterAssert(nicknames != nil);

	/* Split nicknames into fixed number per-command in case there are a lot or are long. */
	[nicknames enumerateSubarraysOfSize:8 usingBlock:^(NSArray *objects, BOOL *stop) {
		[self _modifyWatchListBy:adding nicknames:objects];
	}];
}

- (void)_modifyWatchListBy:(BOOL)adding nicknames:(NSArray<NSString *> *)nicknames
{
	NSParameterAssert(nicknames != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (nicknames.count == 0) {
		return;
	}

	NSString *modifier = nil;

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMonitorCommand])
	{
		if (adding) {
			modifier = @"+";
		} else {
			modifier = @"-";
		}

		NSString *nicknamesString = [nicknames componentsJoinedByString:@","];

		[self send:@"MONITOR", modifier, nicknamesString, nil];
	}
	else if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityWatchCommand])
	{
		if (adding) {
			modifier = @" +";
		} else {
			modifier = @" -";
		}

		NSString *nicknamesString = [nicknames componentsJoinedByString:modifier];

		[self send:@"WATCH", [modifier stringByAppendingString:nicknamesString], nil];
	}
}

@end

NS_ASSUME_NONNULL_END
