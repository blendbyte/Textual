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

/* A portion of this source file contains copyrighted work derived from one or more
 3rd-party, open source projects. The use of this work is hereby acknowledged. */

/* This source file contains work that originated from the Chat Core 
 framework of the Colloquy project. The source in question is in relation
 to the handling of SASL authentication requests. The license of the 
 Chat Core project is as follows: 

 This document can be found mirrored at the author's website:
 <http://colloquy.info/project/browser/trunk/Resources/BSD%20License.txt>

 No actual copyright is presented in the license file or the actual 
 source file in which this work was obtained so the work is assumed to
 be Copyright © 2000 - 2012 the Colloquy IRC Client

 ------- License -------

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:

 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote
 products derived from this software without specific prior written
 permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
 NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
#import "IRCTextDecodingPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCClientConfigurationWasUpdatedNotification = @"IRCClientConfigurationWasUpdatedNotification";

NSString * const IRCClientChannelListWasModifiedNotification = @"IRCClientChannelListWasModifiedNotification";

NSString * const IRCClientWillConnectNotification = @"IRCClientWillConnectNotification";
NSString * const IRCClientDidConnectNotification = @"IRCClientDidConnectNotification";

NSString * const IRCClientWillSendQuitNotification = @"IRCClientWillSendQuitNotification";
NSString * const IRCClientWillDisconnectNotification = @"IRCClientWillDisconnectNotification";
NSString * const IRCClientDidDisconnectNotification = @"IRCClientDidDisconnectNotification";

NSString * const IRCClientUserNicknameChangedNotification = @"IRCClientUserNicknameChangedNotification";

@implementation IRCClient

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithConfigDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	IRCClientConfig *config = [[IRCClientConfig alloc] initWithDictionary:dic];

	return [self initWithConfig:config];
}

- (instancetype)initWithConfig:(IRCClientConfig *)config
{
	NSParameterAssert(config != nil);

	if ((self = [super init])) {
		self.config = config;

		[self writePasswordsToKeychain];

		/* Server passwords of a new configuration (e.g. Duplicate Server) */
		[self writeServerPasswordsToKeychain];

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.batchMessages = [IRCMessageBatchMessageContainer new];

	self.supportInfo = [[IRCISupportInfo alloc] initWithClient:self];

	self.connectType = IRCClientConnectModeNormal;
	self.disconnectType = IRCClientDisconnectModeNormal;

	self.cachedHighlights = @[];

	self.isonReplyNicknames = [NSMutableArray array];

	self.capabilityNegotiator = [IRCCapabilityNegotiator new];

	self.capabilityNegotiator.delegate = self;

	self.channelListPrivate = [NSMutableArray array];

	self.chatHistoryPendingTargets = [NSMutableSet set];

	self.timedCommands = [NSMutableDictionary dictionary];

	self.knownUsers = [[IRCUserList alloc] initWithClient:self];

	self.addressBookMatchCache = [[IRCAddressBookMatchCache alloc] initWithClient:self];
	
	self.trackedUsers = [[IRCAddressBookUserTrackingContainer alloc] initWithClient:self];

	self.requestedCommands = [IRCClientRequestedCommands new];

	self.lastMessageServerTime = self.config.lastMessageServerTime;

	self.lastServerSelected = NSNotFound;

/* Weak: the timers are owned by the client, so a strong reference kept
	 a deleted client alive */
	__weak IRCClient *weakSelf = self;

	self.autojoinTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onAutojoinTimer];
	}];

	self.autojoinNextJoinTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onAutojoinNextJoinTimer];
	}];

	self.autojoinDelayedWarningTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onAutojoinDelayedWarningTimer];
	}];

	self.isonTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onISONTimer];
	}];

	self.reconnectTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onReconnectTimer];
	}];

	self.retryTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onRetryTimer];
	}];

	self.pongTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onPongTimer];
	}];

	self.whoTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[weakSelf onWhoTimer];
	}];

	[RZNotificationCenter() addObserver:self selector:@selector(willDestroyChannel:) name:IRCWorldWillDestroyChannelNotification object:nil];
}

- (void)dealloc
{
	[RZNotificationCenter() removeObserver:self];

	[self.autojoinTimer stop];
	[self.autojoinNextJoinTimer stop];
	[self.autojoinDelayedWarningTimer stop];
	[self.isonTimer	stop];
	[self.pongTimer	stop];
	[self.reconnectTimer stop];
	[self.retryTimer stop];
	[self.whoTimer stop];

	self.channelsToAutojoin = nil;
	self.logFile = nil;
	self.socket = nil;
	[self.knownUsers stopExpiryTimer];

	self.knownUsers = nil;

	[self cancelPerformRequests];
}

- (void)updateConfig:(IRCClientConfig *)config
{
	[self updateConfig:config updateSelection:YES];
}

- (void)updateConfig:(IRCClientConfig *)config updateSelection:(BOOL)updateSelection
{
	NSParameterAssert(config != nil);

	if (self.isTerminating) {
		return;
	}

	IRCClientConfig *currentConfig = self.config;

	if ([currentConfig isEqual:config]) {
		return;
	}

	if ([currentConfig.uniqueIdentifier isEqualToString:config.uniqueIdentifier] == NO) {
		LogToConsoleError("Tried to load configuration for incorrect client");

		return;
	}

	self.config = config;

	/* Update channel list */
	{
		NSMutableArray<IRCChannel *> *channelListOld = [self.channelList mutableCopy];

		NSMutableArray<IRCChannel *> *channelListNew = [NSMutableArray array];

		NSMutableArray<NSString *> *channelListNewNames = [NSMutableArray array];

		NSArray *channelConfigurations = self.config.channelList;

		for (IRCChannelConfig *channelConfig in channelConfigurations) {
			/* Block duplicate channel names by maintaining array of names */
			NSString *channelName = channelConfig.channelName;

			if ([channelListNewNames containsObject:channelName] == NO) {
				[channelListNewNames addObject:channelName];
			} else {
				continue;
			}

			/* Check whether the channel exists in the current list of channels */
			/* If it does not exist, then create it. Otherwise, update it. */
			IRCChannel *channel = [self findChannel:channelConfig.channelName inList:channelListOld];

			if (channel == nil) {
				channel = [worldController() createChannelWithConfig:channelConfig onClient:self add:NO adjust:NO reload:NO];
			} else {
				[channel updateConfig:channelConfig fireChangedNotification:NO updateStoredChannelList:NO];

				[channelListOld removeObjectIdenticalTo:channel];
			}

			[channelListNew addObject:channel];
		}

		/* Any channels left in the old array can be destroyed 
		 or if they are not a channel, then they can be reinserted
		 because we do not care about private messages being updated
		 above so they must be reinserted here. */
		for (IRCChannel *channel in channelListOld) {
			if (channel.isChannel == NO) {
				[channelListNew addObject:channel];
			} else {
				[worldController() destroyChannel:channel reload:NO];
			}
		}

		/* Save updated channel list then safe its contents */
		self.channelList = channelListNew;
	}

	/* Update server list */
	{
		/* To update the server list, we first make a map of all existing
		 servers in a dictionary with the key as the identifier and the
		 object is the server itself. */
		NSArray *serverListOld = currentConfig.serverList;

		NSMutableDictionary<NSString *, IRCServer *> *serverListOldMap =
		[[NSMutableDictionary alloc] initWithCapacity:serverListOld.count];

		for (IRCServer *server in serverListOld) {
			serverListOldMap[server.uniqueIdentifier] = server;
		}

		/* We then make a map of the new server list */
		NSArray *serverListNew = self.config.serverList;

		NSMutableDictionary<NSString *, IRCServer *> *serverListNewMap =
		[[NSMutableDictionary alloc] initWithCapacity:serverListNew.count];

		for (IRCServer *server in serverListNew) {
			serverListNewMap[server.uniqueIdentifier] = server;
		}

		/* Record information about the current server (if any). */
		IRCServer *serverInUse = self.server;

		NSString *uniqueIdentifierInUse = serverInUse.uniqueIdentifier;

		/* Enumerate old server list */
		/* If an old server no longer appears in the new list of identifiers,
		 then we destroy its keychain items. If the server is the active server,
		 then we mark the keychain items to be destroyed later, incase they
		 need to be reused by IRCClient. */
		[serverListOldMap enumerateKeysAndObjectsUsingBlock:^(NSString *uniqueIdentifier, IRCServer *server, BOOL *stop) {
			if ([serverListNewMap containsKey:uniqueIdentifier]) {
				return;
			}

			if ([uniqueIdentifier isEqualToString:uniqueIdentifierInUse]) {
				serverInUse.destroyKeychainItemsDuringDealloc = YES;
			} else {
				[server destroyServerPasswordKeychainItem];
			}
		}];

		/* Enumerate new server list */
		/* All servers in the new server list have their keychain item written. */
		if (serverListNew.count == 0) {
			self.lastServerSelected = NSNotFound;
		} else {
			[serverListNewMap enumerateKeysAndObjectsUsingBlock:^(NSString *uniqueIdentifier, IRCServer *server, BOOL *stop) {
				[server writeServerPasswordToKeychain];
			}];
		}
	}

	/* -reloadItem will drop the views and reload them. */
	/* We need to remember the selection because of this. */
	if (updateSelection) {
		[self reloadServerListItems];
	}

	/* Update navigation list */
	[menuController() populateNavigationChannelList];

	/* Write passwords to keychain */
	[self writePasswordsToKeychain];

	[self destroyServerPasswordKeychainItemAfterMigration];

	/* Update main window title */
	[mainWindow() updateTitleFor:self];

	/* Rebuild list of users that are ignored and/or tracked */
	[self clearAddressBookCache];

	[self populateISONTrackedUsersList];

	/* Post notification */
	[RZNotificationCenter() postNotificationName:IRCClientConfigurationWasUpdatedNotification object:self];
}

- (void)reloadServerListItems
{
	mainWindow().ignoreOutlineViewSelectionChanges = YES;

	[mainWindowServerList() beginUpdates];

	[mainWindowServerList() reloadItem:self reloadChildren:YES];

	[mainWindowServerList() endUpdates];

	[mainWindow() adjustSelection];

	mainWindow().ignoreOutlineViewSelectionChanges = NO;
}

- (void)writePasswordsToKeychain
{
	[self.config writeNicknamePasswordToKeychain];
	[self.config writeProxyPasswordToKeychain];
	[self.config writeSASLECDSAKeyToKeychain];
}

- (void)destroyServerPasswordKeychainItemAfterMigration
{
	[self.config destroyServerPasswordKeychainItemAfterMigration];
}

- (void)updateStoredConfiguration
{
	if (self.configurationIsStale == NO) {
		return;
	}

	IRCClientConfigMutable *configMutable = [self.config mutableCopy];

	configMutable.lastMessageServerTime = self.lastMessageServerTime;

	configMutable.sidebarItemExpanded = self.sidebarItemIsExpanded;

	self.config = configMutable;

	/* Until one of them changes again (R3.12: every save copied the configuration) */
	self.configurationIsStale = NO;
}

- (void)updateStoredChannelList
{
	/* Rebuild list of channel configurations */
	NSMutableArray<IRCChannelConfig *> *channelList = [NSMutableArray array];

	for (IRCChannel *channel in self.channelList) {
		if (channel.isUtility) {
			continue;
		}

		if (channel.isChannel == NO && [TPCPreferences rememberServerListQueryStates] == NO) {
			continue;
		}

		[channelList addObject:channel.config];
	}

	/* Save list */
	IRCClientConfigMutable *mutableConfig = [self.config mutableCopy];

	mutableConfig.channelList = channelList;

	self.config = mutableConfig;

	/* Post notification */
	[RZNotificationCenter() postNotificationName:IRCClientChannelListWasModifiedNotification object:self];
}

- (NSDictionary<NSString *, id> *)configurationDictionary
{
	[self updateStoredConfiguration];

	return [self.config dictionaryValue];
}

- (void)prepareForApplicationTermination
{
	self.isTerminating = YES;

	LogToConsoleTerminationProgress("Preparing client: <%{public}@>", self.uniqueIdentifier);

	LogToConsoleTerminationProgress("[%{public}@] Closing dialogs", self.uniqueIdentifier);

	[self closeDialogs];

	if (self.isConnecting || self.isConnected) {
		LogToConsoleTerminationProgress("[%{public}@] Performing disconnect", self.uniqueIdentifier);

		__weak IRCClient *weakSelf = self;

		self.terminationCallback = ^{
			[weakSelf prepareForApplicationTerminationPostflight];
		};

		[self quit];

		return;
	}

	[self prepareForApplicationTerminationPostflight];
}

- (void)prepareForApplicationTerminationPostflight
{
	LogToConsoleTerminationProgress("[%{public}@] Closing log file", self.uniqueIdentifier);

	[self closeLogFile];

	LogToConsoleTerminationProgress("[%{public}@] Removing unspoken messages from speech synthesizer", self.uniqueIdentifier);

	[self clearEventsToSpeak];

	LogToConsoleTerminationProgress("[%{public}@] Emptying Address Book cache", self.uniqueIdentifier);

	[self clearAddressBookCache];

	LogToConsoleTerminationProgress("[%{public}@] Removing all tracked users", self.uniqueIdentifier);

	[self clearTrackedUsers];

	LogToConsoleTerminationProgress("[%{public}@] Preparing channels: %{public}ld", self.uniqueIdentifier, self.channelCount);

	for (IRCChannel *c in self.channelList) {
		[c prepareForApplicationTermination];
	}

	LogToConsoleTerminationProgress("[%{public}@] Preparing view controller: <%{public}@>",
					self.uniqueIdentifier, self.viewController.uniqueIdentifier);

	[self.viewController prepareForApplicationTermination];

	LogToConsoleTerminationProgress("[%{public}@] Decrementing client count", self.uniqueIdentifier);

	masterController().terminatingClientCount -= 1;
}

- (void)prepareForPermanentDestruction
{
	self.isTerminating = YES;

//	[self disconnect];	// Disconnect is called by IRCWorld for us

	[self closeDialogs];

	[self closeLogFile];

	[self clearEventsToSpeak];
	
	[self clearAddressBookCache];

	[self clearTrackedUsers];

	[self.config destroyNicknamePasswordKeychainItem];
	[self.config destroyProxyPasswordKeychainItem];
	[self.config destroySASLECDSAKeyKeychainItem];

	[self destroyServerPasswordsKeychainItems];

	for (IRCChannel *c in self.channelList) {
		[c prepareForPermanentDestruction];
	}

	[[mainWindow() inputHistoryManager] destroy:self];

	[self.viewController prepareForPermanentDestruction];
}

- (void)closeDialogs
{
	TDCServerChannelListDialog *channelListDialog = [self channelListDialog];

	if (channelListDialog) {
		[channelListDialog close];
	}

	NSArray *openWindows =
	[windowController() windowsFromWindowList:@[@"TDCChannelInviteSheet",
												@"TDCServerChangeNicknameSheet",
												@"TDCServerHighlightListSheet",
												@"TDCServerPropertiesSheet"]];

	for (TDCSheetBase <TDCClientPrototype> *windowObject in openWindows) {
		if ([windowObject.clientId isEqualToString:self.uniqueIdentifier]) {
			[windowObject close];
		}
	}
}

- (void)preferencesChanged
{
	for (IRCChannel *c in self.channelList) {
		[c preferencesChanged];
	}

	if (self.monitorAwayStatus == NO) {
		[self resetAwayStatusForUsers];
	}
}

- (void)willDestroyChannel:(NSNotification *)notification
{
	IRCChannel *channel = notification.object;

	if (channel.associatedClient != self) {
		return;
	}

	[self zncPlaybackClearChannel:channel];

	if (self.hiddenCommandResponsesQuery == channel) {
		self.hiddenCommandResponsesQuery = nil;
	}

	if (self.rawDataLogQuery == channel) {
		self.rawDataLogQuery = nil;
	}
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	/* Implement this method to allow client to be
	 used as a dictionary key. */

	return self;
}

#pragma mark -
#pragma mark Servers

- (void)enumerateServers:(void (NS_NOESCAPE ^)(IRCServer *server, NSUInteger index, BOOL *stop))block
{
	[self.config.serverList enumerateObjectsUsingBlock:block];
}

- (void)writeServerPasswordsToKeychain
{
	[self enumerateServers:^(IRCServer *server, NSUInteger index, BOOL *stop) {
		[server writeServerPasswordToKeychain];
	}];
}

- (void)destroyServerPasswordsKeychainItems
{
	[self enumerateServers:^(IRCServer *server, NSUInteger index, BOOL *stop) {
		[server destroyServerPasswordKeychainItem];
	}];
}

#pragma mark -
#pragma mark Properties

- (NSString *)description
{
	return [NSString stringWithFormat:@"<IRCClient [%@]: %@>", self.networkNameAlt, self.serverAddress];
}

- (NSString *)uniqueIdentifier
{
	return self.config.uniqueIdentifier;
}

- (NSString *)name
{
	return self.config.connectionName;
}

- (nullable NSString *)networkName
{
	return self.supportInfo.networkNameFormatted;
}

- (NSString *)networkNameAlt
{
	NSString *networkName = self.networkName;

	if (networkName) {
		return networkName;
	}

	return self.config.connectionName;
}

- (nullable NSString *)serverAddress
{
	NSString *serverAddress = self.supportInfo.serverAddress;

	if (serverAddress) {
		return serverAddress;
	}

	NSString *serverAddressOnSocket = self.socket.config.serverAddress;

	if (serverAddressOnSocket) {
		return serverAddressOnSocket;
	}

	return self.server.serverAddress;
}

- (NSString *)userNickname
{
	NSString *userNickname = self->_userNickname;

	if (userNickname) {
		return userNickname;
	}

	return self.config.nickname;
}

- (TDCFileTransferDialog *)fileTransferController
{
	return [TXSharedApplication sharedFileTransferDialog];
}

- (BOOL)isReconnecting
{
	return self.reconnectTimer.timerIsActive;
}

- (void)setSidebarItemIsExpanded:(BOOL)sidebarItemIsExpanded
{
	/* This is a non-critical property that can be saved periodically */
	if (self->_sidebarItemIsExpanded != sidebarItemIsExpanded) {
		self->_sidebarItemIsExpanded = sidebarItemIsExpanded;

		self.configurationIsStale = YES;

		[worldController() savePeriodically];
	}
}

- (void)setLastMessageServerTime:(NSTimeInterval)lastMessageServerTime
{
	/* This is a non-critical property that can be saved periodically */
	if (self->_lastMessageServerTime != lastMessageServerTime) {
		self->_lastMessageServerTime = lastMessageServerTime;

		self.configurationIsStale = YES;

		[worldController() savePeriodically];
	}
}

- (BOOL)isSecured
{
	if (self.socket) {
		return self.socket.isSecured;
	}

	return NO;
}

- (nullable NSData *)zncBouncerCertificateChainData
{
	/* If the data is still being processed, then return
	 nil so that partial data is not returned. */
	if (self.isConnectedToZNC == NO ||
		self.zncBouncerIsSendingCertificateInfo ||
		self.zncBouncerCertificateChainDataMutable == nil)
	{
		return nil;
	}

	return [self.zncBouncerCertificateChainDataMutable dataUsingEncoding:NSASCIIStringEncoding];
}

- (BOOL)isBrokenIRCd_aka_Twitch
{
	return [self.serverAddress hasSuffix:@".twitch.tv"];
}

- (BOOL)supportsAdvancedTracking
{
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityMonitorCommand] ||
			[self isCapabilityEnabled:ClientIRCv3SupportedCapabilityWatchCommand]);
}

- (BOOL)monitorAwayStatus
{
	return ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityAwayNotify] ||
			[TPCPreferences trackUserAwayStatusMaximumChannelSize] > 0);
}

- (nullable TVCLogLine *)lastLine
{
	return self.viewController.lastLine;
}

#pragma mark -
#pragma mark Standalone Utilities

- (BOOL)messageIsFromMyself:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	return [self nicknameIsMyself:message.senderNickname];
}

- (BOOL)nicknameIsMyself:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	NSString *userNickname = self.userNickname;

	if (userNickname == nil) {
		return NO;
	}

	IRCISupportInfo *supportInfo = self.supportInfo;

	return [[supportInfo foldedString:userNickname] isEqualToString:[supportInfo foldedString:nickname]];
}

- (BOOL)stringIsNickname:(NSString *)string
{
	NSParameterAssert(string != nil);

	return ([string isHostmaskNicknameOn:self] && [string isChannelNameOn:self] == NO);
}

- (BOOL)stringIsChannelName:(NSString *)string
{
	NSParameterAssert(string != nil);

	return [string isChannelNameOn:self];
}

- (BOOL)stringIsChannelNameOrZero:(NSString *)string
{
	NSParameterAssert(string != nil);

	return ([self stringIsChannelName:string] || [string isEqualToString:@"0"]);
}

- (NSArray<NSString *> *)compileListOfModeChangesForModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet parameterString:(NSString *)parameterString
{
	return [self compileListOfModeChangesForModeSymbol:modeSymbol modeIsSet:modeIsSet parameterString:parameterString characterSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSArray<NSString *> *)compileListOfModeChangesForModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet parameterString:(NSString *)parameterString characterSet:(NSCharacterSet *)characterList
{
	NSParameterAssert(parameterString != nil);
	NSParameterAssert(characterList != nil);

	NSArray *modeParameters = [parameterString componentsSeparatedByCharactersInSet:characterList];

	return [self compileListOfModeChangesForModeSymbol:modeSymbol modeIsSet:modeIsSet modeParameters:modeParameters];
}

- (NSArray<NSString *> *)compileListOfModeChangesForModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet modeParameters:(NSArray<NSString *> *)modeParameters
{
	NSParameterAssert(modeSymbol.length == 1);
	NSParameterAssert(modeParameters != nil);

	if (modeParameters.count == 0) {
		return @[];
	}

	NSMutableArray<NSString *> *listOfChanges = [NSMutableArray array];

	NSMutableString *modeSetString = [NSMutableString string];
	NSMutableString *modeParamString = [NSMutableString string];

	NSUInteger numberOfEntries = 0;

	for (NSString *modeParameter in modeParameters) {
		if (modeParameter.length == 0) {
			continue;
		}

		if (modeSetString.length == 0) {
			if (modeIsSet) {
				[modeSetString appendFormat:@"+%@", modeSymbol];
			} else {
				[modeSetString appendFormat:@"-%@", modeSymbol];
			}
		} else {
			[modeSetString appendString:modeSymbol];
		}

		[modeParamString appendFormat:@" %@", modeParameter];

		numberOfEntries += 1;

		if (numberOfEntries == self.supportInfo.maximumModeCount) {
			numberOfEntries = 0;

			NSString *modeSetCombined = [modeSetString stringByAppendingString:modeParamString];

			[listOfChanges addObject:modeSetCombined];

			[modeSetString setString:@""];
			[modeParamString setString:@""];
		}
	}

	if (modeSetString.length > 0 && modeParamString.length > 0) {
		NSString *modeSetCombined = [modeSetString stringByAppendingString:modeParamString];

		[listOfChanges addObject:modeSetCombined];
	}

	return [listOfChanges copy];
}

- (void)separateTargetsInString:(NSString *)targetString withCompletionBlock:(void (NS_NOESCAPE ^)(NSArray<NSString *> *targets))completionBlock
{
	NSParameterAssert(targetString != nil);
	NSParameterAssert(completionBlock != nil);

	NSArray *targets = [targetString componentsSeparatedByString:@","];

	completionBlock(targets);
}

- (void)enumerateTargetsInString:(NSString *)targetString withBlock:(void (^)(NSString *target, NSUInteger atIndex, NSUInteger ofTotal, BOOL *stop))block
{
	NSParameterAssert(targetString != nil);
	NSParameterAssert(block != nil);

	NSArray *targets = [targetString componentsSeparatedByString:@","];

	NSUInteger targetsCount = targets.count;

	[targets enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
		block(object, index, targetsCount, stop);
	}];
}

#pragma mark -
#pragma mark Highlights

- (void)clearCachedHighlights
{
	self.cachedHighlights = @[];
}

- (void)cacheHighlightInChannel:(IRCChannel *)channel withLogLine:(TVCLogLine *)logLine
{
	NSParameterAssert(channel != nil);
	NSParameterAssert(logLine != nil);

	if ([TPCPreferences logHighlights] == NO) {
		return;
	}

	/* Create entry */
	IRCHighlightLogEntryMutable *newEntry = [IRCHighlightLogEntryMutable new];

	newEntry.clientId = self.uniqueIdentifier;
	newEntry.channelId = channel.uniqueIdentifier;

	newEntry.lineLogged = logLine;

	/* We insert at head so that latest is always on top. */
	NSMutableArray *cachedHighlights = [self.cachedHighlights mutableCopy];

	[cachedHighlights insertObject:[newEntry copy] atIndex:0];

	self.cachedHighlights = cachedHighlights;

	/* Reload table if the window is open. */
	TDCServerHighlightListSheet *highlightListSheet = [windowController() windowFromWindowList:@"TDCServerHighlightListSheet"];

	if ([highlightListSheet.clientId isEqualToString:self.uniqueIdentifier] == NO) {
		return;
	}

	[highlightListSheet addEntry:self.cachedHighlights.firstObject];
}

#pragma mark -
#pragma mark Reachability

- (void)noteReachabilityChanged:(BOOL)reachable
{
	if (reachable) {
		return;
	}

	[self disconnectOnReachabilityChange];
}

- (void)disconnectOnReachabilityChange
{
	if (self.isLoggedIn == NO) {
		return;
	}

	if (self.config.performDisconnectOnReachabilityChange == NO) {
		return;
	}

	self.disconnectType = IRCClientDisconnectModeReachabilityChange;

	self.reconnectEnabled = YES;

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self disconnect];
	});
}

#pragma mark -
#pragma mark Channel Storage

- (void)selectFirstChannelInChannelList
{
	NSArray *channelList = self.channelList;

	if (channelList.count == 0) {
		return;
	}

	[mainWindow() select:channelList[0]];
}

- (void)addChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	@synchronized(self.channelListPrivate) {
		if ([self.channelListPrivate containsObject:channel]) {
			return;
		}

		/* Add channels atop of the first non-channel (private message).
		 Private messages can be add to the bottom of the array. */
		if (channel.isChannel == NO)
		{
			[self.channelListPrivate addObject:channel];
		}
		else
		{
			NSUInteger privateMessageIndex =
			[self.channelListPrivate indexOfObjectPassingTest:^BOOL(IRCChannel *object, NSUInteger index, BOOL *stop) {
				return (object.isChannel == NO);
			}];

			if (privateMessageIndex == NSNotFound) {
				[self.channelListPrivate addObject:channel];
			} else {
				[self.channelListPrivate insertObject:channel atIndex:privateMessageIndex];
			}
		}

		self.channelMap = nil;

		[self updateStoredChannelList];
	}
}

- (void)addChannel:(IRCChannel *)channel atPosition:(NSUInteger)position
{
	NSParameterAssert(channel != nil);

	@synchronized(self.channelListPrivate) {
		if ([self.channelListPrivate containsObject:channel]) {
			return;
		}

		[self.channelListPrivate insertObject:channel atIndex:position];

		self.channelMap = nil;

		[self updateStoredChannelList];
	}
}

- (void)removeChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	@synchronized(self.channelListPrivate) {
		[self.channelListPrivate removeObjectIdenticalTo:channel];

		self.channelMap = nil;

		[self updateStoredChannelList];
	}
}

- (NSUInteger)indexOfChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	@synchronized (self.channelListPrivate) {
		return [self.channelListPrivate indexOfObject:channel];
	}
}

- (NSUInteger)channelCount
{
	@synchronized (self.channelListPrivate) {
		return self.channelListPrivate.count;
	}
}

- (NSArray<IRCChannel *> *)channelList
{
	@synchronized (self.channelListPrivate) {
		return [self.channelListPrivate copy];
	}
}

- (void)setChannelList:(NSArray<IRCChannel *> *)channelList
{
	NSParameterAssert(channelList != nil);

	@synchronized (self.channelListPrivate) {
		[self.channelListPrivate removeAllObjects];

		[self.channelListPrivate addObjectsFromArray:channelList];

		self.channelMap = nil;

		[self updateStoredChannelList];
	}
}

#pragma mark -
#pragma mark IRCTreeItem

- (BOOL)isClient
{
	return YES;
}

- (BOOL)isActive
{
	return self.isLoggedIn;
}

- (nullable IRCClient *)associatedClient
{
	return self;
}

- (nullable IRCChannel *)associatedChannel
{
	return nil;
}

- (NSUInteger)numberOfChildren
{
	return self.channelCount;
}

- (nullable id)childAtIndex:(NSUInteger)index
{
	return self.channelList[index];
}

- (NSString *)label
{
	return self.config.connectionName;
}

#pragma mark -
#pragma mark Encoding

- (nullable NSData *)convertToCommonEncoding:(NSString *)string
{
	NSParameterAssert(string != nil);

	/* UTF8ONLY: the server takes nothing else */
	if (self.supportInfo.utf8Only) {
		return [string dataUsingEncoding:NSUTF8StringEncoding];
	}

	NSData *data = [string dataUsingEncoding:self.config.primaryEncoding allowLossyConversion:NO];

	if (data == nil) {
		data = [string dataUsingEncoding:self.config.fallbackEncoding allowLossyConversion:NO];

		if (data == nil) {
			data = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		}
	}

	if (data == nil) {
		LogToConsoleError("NSData encode failure");
		LogStackTrace();
	}

	return data;
}

- (nullable NSString *)convertFromCommonEncoding:(NSData *)data
{
	NSParameterAssert(data != nil);

	/* UTF8ONLY: no guessing; bytes that aren't UTF-8 become replacement characters */
	if (self.supportInfo.utf8Only) {
		return [IRCTextDecoding stringByDecodingUTF8Replacing:data];
	}

	NSString *string = [NSString stringWithBytes:data.bytes length:data.length encoding:self.config.primaryEncoding];

	if (string == nil) {
		string = [NSString stringWithBytes:data.bytes length:data.length encoding:self.config.fallbackEncoding];

		if (string == nil) {
			string = [NSString stringWithBytes:data.bytes length:data.length encoding:NSASCIIStringEncoding];
		}
	}

	if (string == nil) {
		LogToConsoleError("NSData decode failure");
		LogStackTrace();
	}

	return string;
}

#pragma mark -
#pragma mark Output Rules

- (BOOL)outputRuleMatchedInMessage:(NSString *)message inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(message != nil);

	NSArray *rules = sharedPluginManager().pluginOutputSuppressionRules;

	if (rules.count == 0) {
		return NO;
	}

	if ([TPCPreferences removeAllFormatting] == NO) {
		message = message.stripIRCEffects;
	}

	for (THOPluginOutputSuppressionRule *rule in rules) {
		if ([XRRegularExpression string:message isMatchedByRegex:rule.match] == NO) {
			continue;
		}

		if (channel) {
			if ((channel.isChannel && rule.restrictChannel) ||
				(channel.isPrivateMessage && rule.restrictPrivateMessage))
			{
				return YES;
			}
		} else {
			if (rule.restrictConsole) {
				return YES;
			}
		}
	}

	return NO;
}

#pragma mark -
#pragma mark Channel States

- (void)setHighlightStateForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (mainWindow().keyWindow && [mainWindow() isItemSelected:channel]) {
		return;
	}

	channel.nicknameHighlightCount += 1;

	[TVCDockIcon updateDockIcon];

	[mainWindow() reloadTreeItem:channel];
}

- (void)setUnreadStateForChannel:(IRCChannel *)channel
{
	[self setUnreadStateForChannel:channel isHighlight:NO];
}

- (void)setUnreadStateForChannel:(IRCChannel *)channel isHighlight:(BOOL)isHighlight
{
	NSParameterAssert(channel != nil);

	if (mainWindow().keyWindow && [mainWindow() isItemSelected:channel]) {
		return;
	}

	if (channel.isChannel == NO || [TPCPreferences displayPublicMessageCountOnDockBadge]) {
		channel.dockUnreadCount += 1;

		[TVCDockIcon updateDockIcon];
	}

	channel.treeUnreadCount += 1;

	// The isHighlight flag is not sent for the purpose of incrementing
	// a count. It's passed so that we can know whether the option to
	// show badge count should be ignored when performing update.
	if (isHighlight || channel.config.showTreeBadgeCount) {
		[mainWindowServerList() refreshMessageCountForItem:channel];
	}
}

#pragma mark -
#pragma mark Find Channel

- (nullable IRCChannel *)findChannel:(NSString *)withName inList:(NSArray<IRCChannel *> *)channelList
{
	NSParameterAssert(withName != nil);
	NSParameterAssert(channelList != nil);

	/* Compared under the server's CASEMAPPING (R3.15) */
	IRCISupportInfo *supportInfo = self.supportInfo;

	NSString *foldedName = [supportInfo foldedString:withName];

	for (IRCChannel *channel in channelList) {
		if ([foldedName isEqualToString:[supportInfo foldedString:channel.name]]) {
			return channel;
		}
	}

	return nil;
}

- (nullable IRCChannel *)findChannel:(NSString *)name
{
	NSParameterAssert(name != nil);

	IRCISupportInfo *supportInfo = self.supportInfo;

	@synchronized (self.channelListPrivate) {
		/* Built on first use after the list, a query name or CASEMAPPING changed */
		IRCISupportInfoCaseMapping caseMapping = supportInfo.caseMapping;

		if (self.channelMap == nil || self.channelMapCaseMapping != caseMapping) {
			NSMutableDictionary *channelMap = [NSMutableDictionary dictionaryWithCapacity:self.channelListPrivate.count];

			for (IRCChannel *channel in self.channelListPrivate) {
				NSString *foldedName = [supportInfo foldedString:channel.name];

				/* The first of two names that fold the same wins, as in a linear search */
				if (channelMap[foldedName] == nil) {
					channelMap[foldedName] = channel;
				}
			}

			self.channelMap = channelMap;

			self.channelMapCaseMapping = caseMapping;
		}

		return self.channelMap[[supportInfo foldedString:name]];
	}
}

- (void)channelNameChanged
{
	@synchronized (self.channelListPrivate) {
		self.channelMap = nil;
	}
}

- (nullable IRCChannel *)findChannelOrCreate:(NSString *)name
{
	return [self findChannelOrCreate:name isPrivateMessage:NO];
}

- (nullable IRCChannel *)findChannelOrCreate:(NSString *)withName isPrivateMessage:(BOOL)isPrivateMessage
{
	NSParameterAssert(withName != nil);

	if (isPrivateMessage == NO) {
		return [self findChannelOrCreate:withName asType:IRCChannelTypeChannel];
	} else {
		return [self findChannelOrCreate:withName asType:IRCChannelTypePrivateMessage];
	}
}

- (nullable IRCChannel *)findChannelOrCreate:(NSString *)withName isUtility:(BOOL)isUtility
{
	NSParameterAssert(withName != nil);

	if (isUtility == NO) {
		return [self findChannelOrCreate:withName asType:IRCChannelTypeChannel];
	} else {
		return [self findChannelOrCreate:withName asType:IRCChannelTypeUtility];
	}
}

- (nullable IRCChannel *)findChannelOrCreate:(NSString *)withName asType:(IRCChannelType)type
{
	NSParameterAssert(withName != nil);

	IRCChannel *channel = [self findChannel:withName];

	if (channel) {
		return channel;
	}

	if (type == IRCChannelTypeChannel) {
		IRCChannelConfig *config = [IRCChannelConfig seedWithName:withName];

		channel = [worldController() createChannelWithConfig:config onClient:self add:YES adjust:YES reload:YES];

		[worldController() savePeriodically];
	} else {
		channel = [worldController() createPrivateMessage:withName onClient:self asType:type];
	}

	return channel;
}

#pragma mark -
#pragma mark User List 

- (nullable IRCUser *)myself
{
	return [self findUser:self.userNickname];
}

- (NSUInteger)numberOfUsers
{
	return self.knownUsers.count;
}

- (NSArray<IRCUser *> *)userList
{
	NSArray *users = self.knownUsers.users;

	return (users ?: @[]);
}

#pragma mark -
#pragma mark NickServ Information

- (NSArray<NSString *> *)nickServSupportedNeedIdentificationTokens
{
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"IRCClient List of NickServ Needs Identification Tokens"];
}

- (NSArray<NSString *> *)nickServSupportedSuccessfulIdentificationTokens
{
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"IRCClient List of NickServ Successfully Identified Tokens"];
}

#pragma mark -
#pragma mark Requested Commands

- (void)removeRequestedCommands
{
	[self.requestedCommands removeCommands];

	[self.isonReplyNicknames removeAllObjects];
}

- (void)createHiddenCommandResponses
{
	if (self.isTerminating) {
		return;
	}

	if (self.hiddenCommandResponsesQuery != nil) {
		return;
	}

	IRCChannel *query = [self findChannelOrCreate:@"Hidden Responses" isUtility:YES];

	self.hiddenCommandResponsesQuery = query;

	[mainWindow() select:query];

	[self printDebugInformation:TXTLS(@"IRC[yem-td]") inChannel:query];
}

- (void)printReplyToHiddenCommandResponsesQuery:(IRCMessage *)message
{
	IRCChannel *query = self.hiddenCommandResponsesQuery;

	if (query == nil) {
		return;
	}

	[self printReply:message inChannel:query];
}

@end

NS_ASSUME_NONNULL_END
