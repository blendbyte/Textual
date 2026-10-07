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
#import "GCDAsyncSocketExtensions.h"
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
#import "IRCClientPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _autojoinDelayedWarningInterval		90 // max delay after identification is 10 so keep this above that
#define _autojoinDelayedWarningMaxCount		3

#define _isonCheckInterval			30
#define _pingInterval				270
#define _pongCheckInterval			30
#define _reconnectInterval			20
#define _retryInterval				240
#define _timeoutInterval			360
#define _whoCheckInterval			120

#define _CTCPReplyLimit				5 // replies per _CTCPReplyLimitInterval
#define _CTCPReplyLimitPerSender	2 // replies to one host per _CTCPReplyLimitInterval
#define _CTCPReplyLimitInterval		10

NSString * const IRCClientConfigurationWasUpdatedNotification = @"IRCClientConfigurationWasUpdatedNotification";

NSString * const IRCClientChannelListWasModifiedNotification = @"IRCClientChannelListWasModifiedNotification";

NSString * const IRCClientWillConnectNotification = @"IRCClientWillConnectNotification";
NSString * const IRCClientDidConnectNotification = @"IRCClientDidConnectNotification";

NSString * const IRCClientWillSendQuitNotification = @"IRCClientWillSendQuitNotification";
NSString * const IRCClientWillDisconnectNotification = @"IRCClientWillDisconnectNotification";
NSString * const IRCClientDidDisconnectNotification = @"IRCClientDidDisconnectNotification";

NSString * const IRCClientUserNicknameChangedNotification = @"IRCClientUserNicknameChangedNotification";

@interface IRCClient ()
// Properties that are public in IRCClient.h
@property (nonatomic, copy, readwrite) IRCClientConfig *config;
@property (nonatomic, copy, readwrite, nullable) IRCServer *server;
@property (nonatomic, strong, readwrite) IRCISupportInfo *supportInfo;
@property (nonatomic, assign, readwrite) BOOL isAutojoined;
@property (nonatomic, assign, readwrite) BOOL isAutojoining;
@property (nonatomic, assign, readwrite) BOOL isConnecting;
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, assign, readwrite) BOOL isConnectedToZNC;
@property (nonatomic, assign, readwrite) BOOL isLoggedIn;
@property (nonatomic, assign, readwrite) BOOL isQuitting;
@property (nonatomic, assign, readwrite) BOOL isDisconnecting;
@property (nonatomic, assign, readwrite) BOOL isReconnecting;
@property (nonatomic, assign, readwrite) BOOL isSecured;
@property (nonatomic, assign, readwrite) BOOL userIsAway;
@property (nonatomic, assign, readwrite) BOOL userIsIRCop;
@property (nonatomic, assign, readwrite) BOOL userIsIdentifiedWithNickServ;
@property (nonatomic, assign, readwrite) BOOL isWaitingForNickServ;
@property (nonatomic, assign) BOOL isAuthenticatedWithSASL;
@property (nonatomic, assign) BOOL nickServVerificationWarningShown;
@property (nonatomic, assign) NSUInteger CTCPReplyCount;
@property (nonatomic, assign) NSTimeInterval CTCPReplyCountStarted;
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, NSNumber *> *CTCPReplyCountBySender;
@property (nonatomic, assign, readwrite) BOOL serverHasNickServ;
@property (nonatomic, assign, readwrite) NSTimeInterval lastMessageReceived;
@property (nonatomic, assign, readwrite) NSTimeInterval lastMessageServerTime;
@property (nonatomic, assign, readwrite) ClientIRCv3SupportedCapability capabilities;
@property (nonatomic, copy, readwrite) NSArray<IRCHighlightLogEntry *> *cachedHighlights;
@property (nonatomic, copy, readwrite, nullable) NSString *userHostmask;
@property (nonatomic, copy, readwrite) NSString *userNickname;
@property (nonatomic, copy, readwrite) NSString *serverAddress;
@property (nonatomic, copy, readwrite, nullable) NSString *preAwayUserNickname;
@property (nonatomic, assign, readwrite) NSUInteger logFileSessionCount;

// Properties private
@property (nonatomic, assign) BOOL configurationIsStale;
@property (nonatomic, strong, nullable) IRCConnection *socket;
@property (nonatomic, strong) IRCMessageBatchMessageContainer *batchMessages;
@property (nonatomic, strong, nullable) TLOFileLogger *logFile;
@property (nonatomic, strong) TLOTimer *autojoinTimer;
@property (nonatomic, strong) TLOTimer *autojoinNextJoinTimer;
@property (nonatomic, strong) TLOTimer *autojoinDelayedWarningTimer;
@property (nonatomic, strong) TLOTimer *isonTimer;
@property (nonatomic, strong) TLOTimer *pongTimer;
@property (nonatomic, strong) TLOTimer *reconnectTimer;
@property (nonatomic, strong) TLOTimer *retryTimer;
@property (nonatomic, strong) TLOTimer *whoTimer;
@property (nonatomic, assign) BOOL capabilityNegotiationIsPaused;
@property (nonatomic, assign) BOOL invokingISONCommandForFirstTime;
@property (nonatomic, assign) BOOL isTerminating; // Is being destroyed
@property (nonatomic, assign) BOOL inWhoisResponse;
@property (nonatomic, assign) BOOL inWhowasResponse;
@property (nonatomic, assign) BOOL reconnectEnabled;
@property (nonatomic, assign) BOOL reconnectEnabledBecauseOfSleepMode;
@property (nonatomic, assign) BOOL timeoutWarningShownToUser;
@property (nonatomic, assign) BOOL zncBouncerIsSendingCertificateInfo;
@property (nonatomic, assign) BOOL zncBouncerIsPlayingBackHistory;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *capabilitiesPending;
@property (nonatomic, assign) NSUInteger connectDelay;
@property (nonatomic, assign) NSUInteger lastServerSelected;
@property (nonatomic, assign) NSUInteger lastWhoRequestChannelListIndex;
@property (nonatomic, assign) NSUInteger successfulConnects;
@property (nonatomic, assign) NSUInteger tryingNicknameNumber;
@property (nonatomic, assign) NSUInteger autojoinDelayedWarningCount;
@property (nonatomic, copy, nullable) NSString *tryingNicknameSentNickname;
@property (nonatomic, strong) NSMutableArray<IRCChannel *> *channelListPrivate;
@property (nonatomic, strong, nullable) NSMutableArray<IRCChannel *> *channelsToAutojoin;
@property (nonatomic, strong) IRCAddressBookMatchCache *addressBookMatchCache;
@property (nonatomic, strong) IRCAddressBookUserTrackingContainer *trackedUsers;
@property (nonatomic, strong) IRCClientRequestedCommands *requestedCommands;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IRCTimedCommand *> *timedCommands;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IRCUser *> *userListPrivate;
@property (nonatomic, strong, nullable) NSMutableString *zncBouncerCertificateChainDataMutable;
@property (nonatomic, copy, nullable) NSString *temporaryServerAddressOverride;
@property (nonatomic, assign) uint16_t temporaryServerPortOverride;
@property (nonatomic, assign) BOOL temporaryServerPrefersSecuredConnection;
@property (readonly) BOOL isBrokenIRCd_aka_Twitch;
@property (readonly) BOOL monitorAwayStatus;
@property (readonly) BOOL supportsAdvancedTracking;
@property (readonly, copy) NSArray<NSString *> *nickServSupportedNeedIdentificationTokens;
@property (readonly, copy) NSArray<NSString *> *nickServSupportedSuccessfulIdentificationTokens;
@property (nonatomic, strong, nullable) IRCChannel *rawDataLogQuery;
@property (nonatomic, strong, nullable) IRCChannel *hiddenCommandResponsesQuery;
@end

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

	self.capabilitiesPending = [NSMutableArray array];

	self.channelListPrivate = [NSMutableArray array];

	self.timedCommands = [NSMutableDictionary dictionary];

	self.userListPrivate = [NSMutableDictionary dictionary];

	self.addressBookMatchCache = [[IRCAddressBookMatchCache alloc] initWithClient:self];
	
	self.trackedUsers = [[IRCAddressBookUserTrackingContainer alloc] initWithClient:self];

	self.requestedCommands = [IRCClientRequestedCommands new];

	self.lastMessageServerTime = self.config.lastMessageServerTime;

	self.lastServerSelected = NSNotFound;

	self.autojoinTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onAutojoinTimer];
	}];

	self.autojoinNextJoinTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onAutojoinNextJoinTimer];
	}];

	self.autojoinDelayedWarningTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onAutojoinDelayedWarningTimer];
	}];

	self.isonTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onISONTimer];
	}];

	self.reconnectTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onReconnectTimer];
	}];

	self.retryTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onRetryTimer];
	}];

	self.pongTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onPongTimer];
	}];

	self.whoTimer =
	[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onWhoTimer];
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

	self.autojoinTimer = nil;
	self.autojoinNextJoinTimer = nil;
	self.autojoinDelayedWarningTimer = nil;
	self.isonTimer = nil;
	self.pongTimer = nil;
	self.reconnectTimer = nil;
	self.retryTimer = nil;
	self.whoTimer = nil;

	self.addressBookMatchCache = nil;
	self.batchMessages = nil;
	self.cachedHighlights = nil;
	self.channelListPrivate = nil;
	self.channelsToAutojoin = nil;
	self.logFile = nil;
	self.socket = nil;
	self.supportInfo = nil;
	self.timedCommands = nil;
	self.trackedUsers = nil;
	self.requestedCommands = nil;
	self.userListPrivate = nil;

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

		self.disconnectCallback = ^{
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
		self.hiddenCommandResponsesQuery = channel;
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

	return [self.userNickname isEqualToStringIgnoringCase:nickname];
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

		[self updateStoredChannelList];
	}
}

- (void)removeChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	@synchronized(self.channelListPrivate) {
		[self.channelListPrivate removeObjectIdenticalTo:channel];

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
#pragma mark Address Book

- (NSArray<IRCAddressBookEntry *> *)findIgnoresForHostmask:(NSString *)hostmask
{
	return [self.addressBookMatchCache findIgnoresForHostmask:hostmask];
}

- (nullable IRCAddressBookEntry *)findUserTrackingAddressBookEntryForHostmask:(NSString *)hostmask
{
	/* We chop off the nickname from the host and only use that in the
	 matching to keep everything a little more consistent internally. */
	NSString *nickname = hostmask.nicknameFromHostmask;
	
	if (nickname == nil) {
		return nil;
	}
	
	return [self findUserTrackingAddressBookEntryForNickname:nickname];
}

- (nullable IRCAddressBookEntry *)findUserTrackingAddressBookEntryForNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	NSString *hostmask = [NSString stringWithFormat:@"%@!*@*", nickname];
	
	return [self findAddressBookEntryForHostmask:hostmask];
}

- (nullable IRCAddressBookEntry *)findAddressBookEntryForHostmask:(NSString *)hostmask
{
	return [self.addressBookMatchCache findAddressBookEntryForHostmask:hostmask];
}

- (void)clearAddressBookCache
{
	[self.addressBookMatchCache clearCachedMatches];
}

- (void)clearAddressBookCacheForHostmask:(NSString *)hostmask
{
	/* Clear host */
	[self.addressBookMatchCache clearCachedMatchesForHostmask:hostmask];

	/* Clear nickname */
	NSString *nickname = hostmask.nicknameFromHostmask;

	NSString *nicknameHostmask = [NSString stringWithFormat:@"%@!*@*", nickname];
	
	[self.addressBookMatchCache clearCachedMatchesForHostmask:nicknameHostmask];
}

#pragma mark -
#pragma mark Output Rules

- (BOOL)outputRuleMatchedInMessage:(NSString *)message inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(message != nil);

	if ([TPCPreferences removeAllFormatting] == NO) {
		message = message.stripIRCEffects;
	}

	NSArray *rules = sharedPluginManager().pluginOutputSuppressionRules;

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
#pragma mark Notifications

- (nullable NSString *)formatNotificationToSpeak:(TLOSpokenNotification *)notification
{
	NSParameterAssert(notification != nil);

	if (self.isTerminating) {
		return nil;
	}

	NSString *formattedMessage = nil;

	TXNotificationType eventType = notification.notificationType;

	IRCChannel *channel = notification.channel;

	NSString *nickname = notification.nickname;

	NSString *text = notification.text;

	if (text) {
		text = text.trim;

		if ([TPCPreferences removeAllFormatting] == NO) {
			text = text.stripIRCEffects;
		}
	}

	switch (eventType) {
		case TXNotificationTypeHighlight:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (text.length == 0) {
				break;
			}

			/* Highlights are spoken regardless of whether the user has configured
			 Channel Messages to be only spoken for selection. When the user has 
			 configured that preference, then we exclude the channel name at least
			 because that information is uninteresting. */
			/* For private messages, we speak everything, regardless of any preference. */
			BOOL isChannel = channel.isChannel;

			BOOL onlySpeakEventsForSelection = [TPCPreferences onlySpeakEventsForSelection];

			BOOL speakChannelName =
			/* 1 */	(isChannel == NO ||
			/* 2 */ (onlySpeakEventsForSelection == NO &&
					 [TPCPreferences channelMessageSpeakChannelName]) ||
			/* 2 */	(onlySpeakEventsForSelection &&
					 [mainWindow() isItemSelected:channel] == NO));

			BOOL speakNickname = (isChannel == NO ||
					[TPCPreferences channelMessageSpeakNickname]);

			NSMutableString *mutableMessage = [NSMutableString string];

			[mutableMessage appendString:TXTLS(@"Notifications[qld-sa]")];

			if (speakChannelName || speakNickname) {
				if (speakChannelName) {
					if (isChannel) {
						[mutableMessage appendString:TXTLS(@"Notifications[ke8-17]", channel.name.channelNameWithoutBang)]; // Channel
					} else {
						[mutableMessage appendString:TXTLS(@"Notifications[6nw-ec]")]; // Private Message
					}
				}

				if (speakNickname) {
					if (isChannel) {
						[mutableMessage appendString:TXTLS(@"Notifications[qy9-86]", nickname)]; // by <nickname>
					} else {
						[mutableMessage appendString:TXTLS(@"Notifications[a7i-pu]", nickname)]; // from <nickname>
					}
				}

				[mutableMessage appendString:TXTLS(@"Notifications[g9t-bt]")];
			}

			[mutableMessage appendString:text];

			formattedMessage = [mutableMessage copy];

			break;
		}
		case TXNotificationTypeChannelMessage:
		case TXNotificationTypeChannelNotice:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (text.length == 0) {
				break;
			}

			BOOL onlySpeakEventsForSelection = [TPCPreferences onlySpeakEventsForSelection];

			BOOL channelIsSelected = [mainWindow() isItemSelected:channel];

			if (onlySpeakEventsForSelection && channelIsSelected == NO) {
				break;
			}

			BOOL speakChannelName = (onlySpeakEventsForSelection == NO &&
									 [TPCPreferences channelMessageSpeakChannelName]);

			BOOL speakNickname = [TPCPreferences channelMessageSpeakNickname];

			NSMutableString *mutableMessage = [NSMutableString string];

			if (speakChannelName || speakNickname) {
				if (eventType == TXNotificationTypeChannelMessage) {
					[mutableMessage appendString:TXTLS(@"Notifications[tao-i2]")];
				} else if (eventType == TXNotificationTypeChannelNotice) {
					[mutableMessage appendString:TXTLS(@"Notifications[kk4-68]")];
				}

				if (speakChannelName) {
					[mutableMessage appendString:TXTLS(@"Notifications[ke8-17]", channel.name.channelNameWithoutBang)];
				}

				if (speakNickname) {
					[mutableMessage appendString:TXTLS(@"Notifications[qy9-86]", nickname)];
				}

				[mutableMessage appendString:TXTLS(@"Notifications[g9t-bt]")];
			}

			[mutableMessage appendString:text];

			formattedMessage = [mutableMessage copy];

			break;
		}
		case TXNotificationTypeNewPrivateMessage:
		case TXNotificationTypePrivateMessage:
		case TXNotificationTypePrivateNotice:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (text.length == 0) {
				break;
			}

			NSString *formatter = nil;

			if (eventType == TXNotificationTypeNewPrivateMessage) {
				formatter = @"Notifications[rvb-9l]";
			} else if (eventType == TXNotificationTypePrivateMessage) {
				formatter = @"Notifications[2bu-ep]";
			} else if (eventType == TXNotificationTypePrivateNotice) {
				formatter = @"Notifications[6jl-vh]";
			}

			formattedMessage = TXTLS(formatter, nickname, text);

			break;
		}
		case TXNotificationTypeKick:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);

			NSString *formatter = @"Notifications[5yu-bf]";

			formattedMessage = TXTLS(formatter, channel.name.channelNameWithoutBang, nickname);

			break;
		}
		case TXNotificationTypeInvite:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			NSString *formatter = @"Notifications[l5i-at]";

			formattedMessage = TXTLS(formatter, text.channelNameWithoutBang, nickname);

			break;
		}
		case TXNotificationTypeConnect:
		case TXNotificationTypeDisconnect:
		{
			NSString *formatter = nil;

			if (eventType == TXNotificationTypeConnect) {
				formatter = @"Notifications[z4p-yr]";
			} else if (eventType == TXNotificationTypeDisconnect) {
				formatter = @"Notifications[fd0-f8]";
			}

			formattedMessage = TXTLS(formatter, self.networkNameAlt);

			break;
		}
		case TXNotificationTypeAddressBookMatch:
		{
			NSParameterAssert(text != nil);

			formattedMessage = text;

			break;
		}
		case TXNotificationTypeFileTransferSendSuccessful:
		case TXNotificationTypeFileTransferReceiveSuccessful:
		case TXNotificationTypeFileTransferSendFailed:
		case TXNotificationTypeFileTransferReceiveFailed:
		case TXNotificationTypeFileTransferReceiveRequested:
		{
			NSParameterAssert(nickname != nil);

			NSString *formatter = nil;

			if (eventType == TXNotificationTypeFileTransferSendSuccessful) {
				formatter = @"Notifications[5e4-vg]";
			} else if (eventType == TXNotificationTypeFileTransferReceiveSuccessful) {
				formatter = @"Notifications[4cd-p3]";
			} else if (eventType == TXNotificationTypeFileTransferSendFailed) {
				formatter = @"Notifications[f0u-32]";
			} else if (eventType == TXNotificationTypeFileTransferReceiveFailed) {
				formatter = @"Notifications[mak-bj]";
			} else if (eventType == TXNotificationTypeFileTransferReceiveRequested) {
				formatter = @"Notifications[at0-vi]";
			}

			formattedMessage = TXTLS(formatter, nickname);

			break;
		}
		case TXNotificationTypeUserJoined:
		case TXNotificationTypeUserParted:
		{
			NSParameterAssert(channel != nil);
			NSParameterAssert(nickname != nil);

			NSString *formatter = nil;

			if (eventType == TXNotificationTypeUserJoined) {
				formatter = @"Notifications[bwu-ps]";
			} else if (eventType == TXNotificationTypeUserParted) {
				formatter = @"Notifications[4aq-hz]";
			}

			formattedMessage = TXTLS(formatter, nickname, channel.name.channelNameWithoutBang);

			break;
		}
		case TXNotificationTypeUserDisconnected:
		{
			NSParameterAssert(nickname != nil);

			NSString *formatter = @"Notifications[sqf-4y]";

			formattedMessage = TXTLS(formatter, nickname);

			break;
		}
	}

	return formattedMessage;
}

- (void)clearEventsToSpeak
{
	[[TXSharedApplication sharedSpeechSynthesizer] clearQueueForClient:self];
}

- (void)speakEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCTreeItem *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text
{
	if ([sharedNotificationController() speakEvent:eventType inChannel:(IRCChannel *)target] == NO) {
		return;
	}

	if (target == nil) {
		target = self;
	}

	TLOSpokenNotification *notification =
	[[TLOSpokenNotification alloc] initWithNotification:eventType
											   lineType:lineType
												 target:target
											   nickname:nickname
												   text:text];

	[[TXSharedApplication sharedSpeechSynthesizer] speak:notification];
}

- (BOOL)notifyText:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(IRCChannel *)target nickname:(NSString *)nickname text:(NSString *)text
{
	return [self notifyEvent:eventType lineType:lineType target:target nickname:nickname text:text userInfo:nil];
}

- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType
{
	return [self notifyEvent:eventType lineType:lineType target:nil nickname:nil text:nil userInfo:nil];
}

- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCChannel *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text
{
	return [self notifyEvent:eventType lineType:lineType target:target nickname:nickname text:text userInfo:nil];
}

- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCChannel *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
{
	if (self.isTerminating) {
		return NO;
	}

	BOOL isTextEvent =
	(eventType == TXNotificationTypeHighlight			||
	 eventType == TXNotificationTypeNewPrivateMessage	||
	 eventType == TXNotificationTypeChannelMessage		||
	 eventType == TXNotificationTypeChannelNotice		||
	 eventType == TXNotificationTypePrivateMessage		||
	 eventType == TXNotificationTypePrivateNotice);

	if (isTextEvent) {
		if ([self nicknameIsMyself:nickname]) {
			return NO;
		}
	}

	if (target && text != nil) {
		if ([self outputRuleMatchedInMessage:text inChannel:target]) {
			return NO;
		}
	}

	IRCChannelConfig *targetConfig = nil;

	if (target) {
		targetConfig = target.config;

		if (eventType == TXNotificationTypeHighlight) {
			if (targetConfig.ignoreHighlights) {
				return YES;
			}
		} else {
			if (targetConfig.pushNotifications == NO) {
				return YES;
			}
		}
	}

	if ([sharedNotificationController() bounceDockIconForEvent:eventType inChannel:target]) {
		if ([sharedNotificationController() bounceDockIconRepeatedlyForEvent:eventType inChannel:target]) {
			[NSApp requestUserAttention:NSCriticalRequest];
		} else {
			[NSApp requestUserAttention:NSInformationalRequest];
		}
	}

	if (sharedNotificationController().areNotificationsDisabled) {
		return YES;
	}

	BOOL mainWindowIsFocused = (mainWindow().inactive == NO);

	BOOL postNotificationsWhileFocused = [TPCPreferences postNotificationsWhileInFocus];

	BOOL targetIsSelected = [mainWindow() isItemSelected:target];

	BOOL onlySpeakEvent = (postNotificationsWhileFocused && mainWindowIsFocused && targetIsSelected);

	if ([TPCPreferences soundIsMuted] == NO) {
		if (onlySpeakEvent == NO) {
			NSString *soundName = [sharedNotificationController() soundForEvent:eventType inChannel:target];

			if (soundName) {
				[TLOSoundPlayer playAlertSound:soundName];
			}
		}

		[self speakEvent:eventType lineType:lineType target:target nickname:nickname text:text];
	}

	if (onlySpeakEvent) {
		return YES;
	}

	if ([sharedNotificationController() notificationEnabledForEvent:eventType inChannel:target] == NO) {
		return YES;
	}

	if (postNotificationsWhileFocused == NO && mainWindowIsFocused) {
		if (eventType != TXNotificationTypeAddressBookMatch) {
			return YES;
		}
	}

	if ([sharedNotificationController() disabledWhileAwayForEvent:eventType inChannel:target]) {
		if (self.userIsAway) {
			return YES;
		}
	}

	NSString *eventTitle = nil;

	NSString *eventDescription = nil;

	if (userInfo == nil) {
		if (target) {
			userInfo = @{TXNotificationUserInfoClientIdentifierKey : self.uniqueIdentifier,
						 TXNotificationUserInfoChannelIdentifierKey: target.uniqueIdentifier};
		} else {
			userInfo = @{TXNotificationUserInfoClientIdentifierKey : self.uniqueIdentifier};
		}
	}

	switch (eventType) {
		case TXNotificationTypeHighlight:
		case TXNotificationTypeNewPrivateMessage:
		case TXNotificationTypeChannelMessage:
		case TXNotificationTypeChannelNotice:
		case TXNotificationTypePrivateMessage:
		case TXNotificationTypePrivateNotice:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			if (eventType == TXNotificationTypeHighlight ||
				eventType == TXNotificationTypeChannelMessage ||
				eventType == TXNotificationTypeChannelNotice)
			{
				NSParameterAssert(target != nil);

				eventTitle = target.name;
			}

			if (lineType == TVCLogLineTypeAction || lineType == TVCLogLineTypeActionNoHighlight) {
				eventDescription = [NSString stringWithFormat:TXNotificationDialogActionNicknameFormat, nickname, text];
			} else {
				nickname = [self formatNickname:nickname inChannel:target];

				eventDescription = [NSString stringWithFormat:TXNotificationDialogStandardNicknameFormat, nickname, text];
			}

			break;
		}
		case TXNotificationTypeFileTransferSendSuccessful:
		case TXNotificationTypeFileTransferReceiveSuccessful:
		case TXNotificationTypeFileTransferSendFailed:
		case TXNotificationTypeFileTransferReceiveFailed:
		case TXNotificationTypeFileTransferReceiveRequested:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = nickname;

			eventDescription = text;

			break;
		}
		case TXNotificationTypeConnect:
		{
			eventTitle = self.networkNameAlt;

			break;
		}
		case TXNotificationTypeDisconnect:
		{
			eventTitle = self.networkNameAlt;

			break;
		}
		case TXNotificationTypeAddressBookMatch:
		{
			NSParameterAssert(text != nil);

			eventDescription = text;

			break;
		}
		case TXNotificationTypeKick:
		{
			NSParameterAssert(target != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			eventDescription = TXTLS(@"Notifications[fkt-p3]", nickname, target.name, text);

			break;
		}
		case TXNotificationTypeInvite:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			eventDescription = TXTLS(@"Notifications[xl5-dn]", nickname, text);

			break;
		}
		case TXNotificationTypeUserJoined:
		{
			NSParameterAssert(target != nil);
			NSParameterAssert(nickname != nil);

			eventTitle = self.networkNameAlt;

			eventDescription = TXTLS(@"Notifications[yas-us]", nickname, target.name);

			break;
		}
		case TXNotificationTypeUserParted:
		{
			NSParameterAssert(target != nil);
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			if (text == nil || text.length == 0) {
				eventDescription = TXTLS(@"Notifications[bu2-9m]", nickname, target.name);
			} else {
				eventDescription = TXTLS(@"Notifications[3ur-i8]", nickname, target.name, text);
			}

			break;
		}
		case TXNotificationTypeUserDisconnected:
		{
			NSParameterAssert(nickname != nil);
			NSParameterAssert(text != nil);

			eventTitle = self.networkNameAlt;

			if (text == nil || text.length == 0) {
				eventDescription = TXTLS(@"Notifications[7ao-n8]", nickname);
			} else {
				eventDescription = TXTLS(@"Notifications[ssw-m6]", nickname, text);
			}

			break;
		}
		default:
		{
			return YES;
		}
	}

	[sharedNotificationController() notify:eventType title:eventTitle description:eventDescription userInfo:userInfo];

	return YES;
}

#pragma mark -
#pragma mark Playback

- (void)playbackClearChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback] == NO) {
		return;
	}

	if (channel.isPrivateMessage == NO || channel.isPrivateMessageForZNCUser) {
		return;
	}

	NSString *command = [NSString stringWithFormat:@"clear %@", channel.name];

	if (self.isConnectedToZNC) {
		[self sendCommand:command toZNCModuleNamed:@"playback"];

		return;
	}

	[self send:@"PRIVMSG", @"*playback", command, nil];
}

- (void)requestPlayback
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityPlayback] == NO) {
		return;
	}

	/* For our first connect, only playback using timestamp if logging was enabled. */
	/* For all other connects, then playback timestamp regardless of logging. */
	NSString *command = nil;

	if ((self.successfulConnects > 1 || (self.successfulConnects == 1 && self.config.zncOnlyPlaybackLatest)) && self.lastMessageServerTime > 0) {
		command = [NSString stringWithFormat:@"play * %.0f", self.lastMessageServerTime];
	} else {
		command = @"play * 0";
	}

	if (self.isConnectedToZNC) {
		[self sendCommand:command toZNCModuleNamed:@"playback"];

		return;
	}

	[self send:@"PRIVMSG", @"*playback", command, nil];
}

#pragma mark -
#pragma mark ZNC Bouncer Accessories

- (void)zncPlaybackClearChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (self.isConnectedToZNC == NO) {
		return;
	}

	[self playbackClearChannel:channel];
}

- (BOOL)nicknameIsZNCUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self.isConnectedToZNC == NO) {
		return NO;
	}

	return [nickname hasPrefix:@"*"];
}

- (BOOL)nickname:(NSString *)nickname isZNCUser:(NSString *)zncNickname
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(zncNickname != nil);
	
	return [nickname isEqualToString:[self nicknameAsZNCUser:zncNickname]];
}

- (nullable NSString *)nicknameAsZNCUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self.isConnectedToZNC == NO) {
		return nil;
	}

	return [@"*" stringByAppendingString:nickname];
}

- (BOOL)isSafeToPostNotificationForMessage:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(message != nil);

	if (self.isConnectedToZNC == NO) {
		return YES;
	}

	if (self.config.zncIgnoreUserNotifications) {
		if (channel && [self nicknameIsZNCUser:channel.name]) {
			return NO;
		}
	}

	if (self.config.zncIgnorePlaybackNotifications == NO) {
		return YES;
	}

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBatch]) {
		NSString *batchType = message.parentBatchMessage.batchType;

		return ([batchType isEqualToString:@"znc.in/playback"] == NO);
	}

	return (message.isHistoric == NO);
}

- (void)updateConnectedToZNCPropertyWithMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	if (self.isConnectedToZNC) {
		return;
	}

	if (message.senderIsServer == NO) {
		return;
	}

	if ([message.senderNickname isEqualToString:@"irc.znc.in"]) {
		self.isConnectedToZNC = YES;

		LogToConsole("ZNC detected...");
	}
}

- (void)sendCommand:(NSString *)command toZNCModuleNamed:(NSString *)module
{
	NSParameterAssert(command != nil);
	NSParameterAssert(module != nil);

	NSString *destination = [self nicknameAsZNCUser:module];

	if (destination == nil) {
		return;
	}

	NSString *stringToSend = [NSString stringWithFormat:@"ZNC %@ %@", destination, command];

	[self sendLine:stringToSend];
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

	NSUInteger channelIndex =
	[channelList indexOfObjectWithOptions:NSEnumerationConcurrent
							  passingTest:^BOOL(IRCChannel *channel, NSUInteger index, BOOL *stop) {
								  NSString *channelName = channel.name;

								  return [withName isEqualToStringIgnoringCase:channelName];
							  }];

	if (channelIndex != NSNotFound) {
		return channelList[channelIndex];
	}

	return nil;
}

- (nullable IRCChannel *)findChannel:(NSString *)name
{
	return [self findChannel:name inList:self.channelList];
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

- (BOOL)userExists:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	return ([self findUser:nickname] != nil);
}

- (nullable IRCUser *)findUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	nickname = nickname.lowercaseString;

	@synchronized (self.userListPrivate) {
		return self.userListPrivate[nickname];
	}
}

- (IRCUserMutable *)mutableCopyOfUserWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCUser *user = [self findUser:nickname];

	if (user == nil) {
		return [[IRCUserMutable alloc] initWithNickname:nickname onClient:self];
	} else {
		return [user mutableCopy];
	}
}

- (NSUInteger)numberOfUsers
{
	@synchronized (self.userListPrivate) {
		return self.userListPrivate.count;
	}
}

- (NSArray<IRCUser *> *)userList
{
	@synchronized (self.userListPrivate) {
		return self.userListPrivate.allValues;
	}
}

- (void)addUser:(IRCUser *)user
{
	[self addUserAndReturn:user];
}

- (IRCUser *)addUserAndReturn:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	if ([user isKindOfClass:[IRCUserMutable class]]) {
		user = [user copy];
	}

	NSString *nickname = user.lowercaseNickname;

	@synchronized (self.userListPrivate) {
		self.userListPrivate[nickname] = user;
	}

	[user becamePrimaryUser];

	return user;
}

- (IRCUser *)findUserOrCreate:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCUser *user = [self findUser:nickname];

	if (user == nil) {
		user = [[IRCUser alloc] initWithNickname:nickname onClient:self];

		[self addUser:user];
	}

	return user;
}

- (void)removeUser:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	[user cancelRemoveUserTimer];
	
	NSString *hostmask = user.hostmask;

	if (hostmask) {
		[self clearAddressBookCacheForHostmask:hostmask];
	}

	[self removeUserWithNickname:user.nickname];
}

- (void)removeUserWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	nickname = nickname.lowercaseString;

	@synchronized (self.userListPrivate) {
		[self.userListPrivate removeObjectForKey:nickname];
	}
}

- (void)renameUser:(IRCUser *)user to:(NSString *)toNickname
{
	NSParameterAssert(user != nil);
	NSParameterAssert(toNickname != nil);

	[self modifyUser:user withBlock:^(IRCUserMutable *userMutable) {
		userMutable.nickname = toNickname;
	}];
}

- (void)renameUserWithNickname:(NSString *)fromNickname to:(NSString *)toNickname
{
	NSParameterAssert(fromNickname != nil);
	NSParameterAssert(toNickname != nil);

	IRCUser *user = [self findUser:fromNickname];

	if (user == nil) {
		return;
	}

	[self renameUser:user to:toNickname];
}

- (void)modifyUser:(IRCUser *)user withBlock:(void(NS_NOESCAPE ^)(IRCUserMutable *userMutable))block
{
	NSParameterAssert(user != nil);
	NSParameterAssert(block != nil);

	IRCUserMutable *userMutable = [user mutableCopy];

	block(userMutable);

	if ([user.nickname isEqualToString:userMutable.nickname] == NO) {
		[self removeUser:user];
	}

	[self addUser:userMutable];
}

- (void)modifyUserUserWithNickname:(NSString *)nickname withBlock:(void(NS_NOESCAPE ^)(IRCUserMutable *userMutable))block
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(block != nil);

	IRCUser *user = [self findUser:nickname];

	if (user == nil) {
		return;
	}

	[self modifyUser:user withBlock:block];
}

- (void)modifyUserWithNickname:(NSString *)nickname asAway:(BOOL)away
{
	NSParameterAssert(nickname != nil);
	
	IRCUser *user = [self findUser:nickname];
	
	if (user == nil) {
		return;
	}

	[self modifyUser:user asAway:away];
}

- (void)modifyUser:(IRCUser *)user asAway:(BOOL)away
{
	NSParameterAssert(user != nil);
	
	if (self.monitorAwayStatus == NO) {
		return;
	}

	if (away) {
		[user markAsAway];
	} else {
		[user markAsReturned];
	}
	
	[mainWindow() updateDrawingForUserInUserList:user];
}

- (void)resetAwayStatusForUsers
{
	[self.userList makeObjectsPerformSelector:@selector(markAsReturned)];
}

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

#pragma mark -
#pragma mark Send Command

- (void)sendCommand:(id)string
{
	[self sendCommand:string completeTarget:YES target:nil];
}

- (void)sendCommand:(id)string completeTarget:(BOOL)completeTarget target:(nullable NSString *)targetChannelName
{
	NSParameterAssert(string != nil);

	BOOL inputIsNSString = [string isKindOfClass:[NSString class]];

	if (inputIsNSString == NO && [string isKindOfClass:[NSAttributedString class]] == NO) {
		NSAssert(NO, @"'string' must be NSString or NSAttributedString");
	}

	if ([string length] == 0) {
		return;
	}

	NSMutableAttributedString *stringIn = nil;

	if (inputIsNSString) {
		stringIn = [[NSMutableAttributedString alloc] initWithString:string];
	} else {
		stringIn = [string mutableCopy];
	}

	if ([stringIn.string hasPrefix:@"/"]) {
		[stringIn deleteCharactersInRange:NSMakeRange(0, 1)];
	}

	NSString *command = stringIn.tokenAsString;

	NSString *lowercaseCommand = command.lowercaseString;
	NSString *uppercaseCommand = command.uppercaseString;

	IRCClient *selectedClient = mainWindow().selectedClient;
	IRCChannel *selectedChannel = mainWindow().selectedChannel;

	IRCChannel *targetChannel = nil;

	NSInteger commandNumeric = [IRCCommandIndex indexOfLocalCommand:command];

	if (completeTarget && targetChannelName != nil) {
		targetChannel = [self findChannel:targetChannelName];
	} else if (completeTarget && selectedClient == self && selectedChannel) {
		targetChannel = selectedChannel;
	}

	switch (commandNumeric) {
		case IRCLocalCommandAme: // Command: AME
		case IRCLocalCommandAmsg: // Command: AMSG
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			IRCRemoteCommand sendAsCommand = 0;

			if (commandNumeric == IRCLocalCommandAmsg) {
				sendAsCommand = IRCRemoteCommandPrivmsg;
			} else {
				sendAsCommand = IRCRemoteCommandPrivmsgAction;
			}

			for (IRCClient *client in worldController().clientList) {
				if (client != self && [TPCPreferences amsgAllConnections] == NO) {
					continue;
				}

				for (IRCChannel *channel in client.channelList) {
					if (channel.isActive == NO || channel.isChannel == NO) {
						continue;
					}

					[client sendText:stringIn asCommand:sendAsCommand toChannel:channel];
				}
			}

			break;
		}
		case IRCLocalCommandAquote: // Command: AQUOTE
		case IRCLocalCommandAraw: // Command: ARAW
		{
			NSAssertReturnLoopBreak(self.isConnected);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			for (IRCClient *client in worldController().clientList) {
				[client sendLine:stringIn.string];
			}

			break;
		}
		case IRCLocalCommandAutojoin: // Command: AUTOJOIN
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			[self performAutoJoinInitiatedByUser:YES];

			break;
		}
		case IRCLocalCommandAway: // Command: AWAY
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			for (IRCClient *client in worldController().clientList) {
				if (client != self && [TPCPreferences awayAllConnections] == NO) {
					continue;
				}

				NSString *comment = stringIn.string;

				/* We enforce the maximum away length here instead of
				 -toggleAwayStatusWithComment: so that we have an easier
				 way to know when it is truncated so the user can be informed. */
				NSUInteger commentMaximumLength = client.supportInfo.maximumAwayLength;

				if (commentMaximumLength > 0 && comment.length > commentMaximumLength) {
					[client printDebugInformation:TXTLS(@"IRC[41y-p2]", self.networkNameAlt, commentMaximumLength)];
				}

				[client toggleAwayStatusWithComment:comment];
			}

			break;
		}
		case IRCLocalCommandBack: // Command: BACK
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			for (IRCClient *client in worldController().clientList) {
				if (client != self && [TPCPreferences awayAllConnections] == NO) {
					continue;
				}

				[client toggleAwayStatus:NO withComment:nil];
			}

			break;
		}
		case IRCLocalCommandCap: // Command: CAP
		case IRCLocalCommandCaps: // Command: CAPS
		{
			NSString *capabilities = self.enabledCapabilitiesStringValue;

			if (capabilities.length == 0) {
				[self printDebugInformation:TXTLS(@"IRC[5wa-lb]")];
			} else {
				[self printDebugInformation:TXTLS(@"IRC[7p9-rs]", capabilities)];
			}

			break;
		}
		case IRCLocalCommandClear: // Command: CLEAR
		{
			if (targetChannel) {
				[mainWindow() clearContentsOfChannel:targetChannel];
			} else {
				[mainWindow() clearContentsOfClient:self];
			}

			break;
		}
		case IRCLocalCommandClearall: // Command: CLEARALL
		{
			for (IRCClient *client in worldController().clientList) {
				if (client != self && [TPCPreferences clearAllConnections] == NO) {
					continue;
				}

				[mainWindow() clearContentsOfClient:client];

				for (IRCChannel *channel in client.channelList) {
					[mainWindow() clearContentsOfChannel:channel];
				}
			}

			break;
		}
		case IRCLocalCommandClose: // Command: CLOSE
		case IRCLocalCommandRemove: // Command: REMOVE
		{
			NSString *channelName = stringIn.tokenAsString;
			
			if (channelName.length == 0) {
				if (targetChannel) {
					[worldController() destroyChannel:targetChannel];
				}

				break;
			}

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				[self printDebugInformation:TXTLS(@"IRC[pxa-ox]", channelName)];
				
				break;
			}
			
			[worldController() destroyChannel:channel];

			break;
		}
		case IRCLocalCommandConn: // Command: CONN
		{
			NSString *serverAddress = stringIn.lowercaseGetToken;

			if (serverAddress.length > 0) {
				if (serverAddress.isValidInternetAddress == NO) {
					[self printDebugInformation:TXTLS(@"IRC[zef-q9]")];
					
					break;
				}

				/* Another host on the same port and with the same TLS setting as the
				 configured server; never plaintext if the current connection is secured. */
				IRCServer *currentServer = self.server;

				if (currentServer == nil) {
					currentServer = self.config.serverList.firstObject;
				}

				self.temporaryServerAddressOverride = serverAddress;
				self.temporaryServerPortOverride = currentServer.serverPort;
				self.temporaryServerPrefersSecuredConnection = (currentServer.prefersSecuredConnection || self.socket.isSecured);
			}

			if (self.isConnecting || self.isConnected) {
				__weak IRCClient *weakSelf = self;

				self.disconnectCallback = ^{
					[weakSelf connect];
				};

				[self quit];

				break;
			}

			[self connect];

			break;
		}
		case IRCLocalCommandCtcp: // Command: CTCP
		case IRCLocalCommandCtcpreply: // Command: CTCPREPLY
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (targetChannel && targetChannel != selectedChannel) {
				if (targetChannel.isUtility) {
					[self printDebugInformation:TXTLS(@"sxf-qx")];

					break;
				}

				targetChannelName = targetChannel.name;
			} else {
				targetChannelName = stringIn.tokenAsString;
			}

			NSString *subCommand = stringIn.uppercaseGetToken;

			if (subCommand.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			if (commandNumeric == IRCLocalCommandCtcp) {
				if ([subCommand isEqualToString:@"PING"]) {
					[self sendCTCPPing:targetChannelName];
				} else {
					[self sendCTCPQuery:targetChannelName command:subCommand text:stringIn.string];
				}
			} else {
				[self sendCTCPReply:targetChannelName command:subCommand text:stringIn.string];
			}

			break;
		}
		case IRCLocalCommandCycle: // Command: CYCLE
		case IRCLocalCommandHop: // Command: HOP
		case IRCLocalCommandRejoin: // Command: REJOIN
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (targetChannel == nil || targetChannel.isChannel == NO) {
				[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
				
				break;
			}

			[self partChannel:targetChannel];

			[self forceJoinChannel:targetChannel.name password:targetChannel.secretKey];

			break;
		}
		case IRCLocalCommandDehalfop: // Command: DEHALFOP
		case IRCLocalCommandDeop: // Command: DEOP
		case IRCLocalCommandDevoice: // Command: DEVOICE
		case IRCLocalCommandHalfop: // Command: HALFOP
		case IRCLocalCommandOp: // Command: OP
		case IRCLocalCommandVoice: // Command: VOICE
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);
			
			BOOL modeIsSet = (commandNumeric == IRCLocalCommandOp ||
							  commandNumeric == IRCLocalCommandHalfop ||
							  commandNumeric == IRCLocalCommandVoice);

			NSString *modeSymbol = nil;

			if (commandNumeric == IRCLocalCommandOp || commandNumeric == IRCLocalCommandDeop) {
				modeSymbol = @"o";
			} else if (commandNumeric == IRCLocalCommandHalfop || commandNumeric == IRCLocalCommandDehalfop) {
				modeSymbol = @"h";
			} else if (commandNumeric == IRCLocalCommandVoice || commandNumeric == IRCLocalCommandDevoice) {
				modeSymbol = @"v";
			}

			if ([self.supportInfo modeSymbolIsUserPrefix:modeSymbol] == NO) {
				[self printDebugInformation:TXTLS(@"IRC[dwi-d1]", modeSymbol)];

				break;
			}

			if ([self stringIsChannelName:stringIn.string] == NO) {
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else {
					[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
					
					break;
				}
			} else {
				targetChannelName = stringIn.tokenAsString;
			}
			
			NSString *nicknamesString = stringIn.string;

			if (nicknamesString.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			NSArray *modeChanges =
			[self compileListOfModeChangesForModeSymbol:modeSymbol
											  modeIsSet:modeIsSet
										parameterString:nicknamesString];

			for (NSString *modeChange in modeChanges) {
				[self send:@"MODE", targetChannelName, modeChange, nil];
			}

			break;
		}
		case IRCLocalCommandDebug: // Command: DEBUG
		case IRCLocalCommandEcho: // Command: ECHO
		{
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}
			
			NSString *stringInString = stringIn.string;

			if ([stringInString isEqualToStringIgnoringCase:@"raw on"])
			{
				[self createRawDataLogQuery];
			}
			else if ([stringInString isEqualToStringIgnoringCase:@"raw off"])
			{
				[self destroyRawDataLogQuery];
			}
			else
			{
				[self printDebugInformation:stringInString];
			}

			break;
		}
		case IRCLocalCommandDefaults: // Command: DEFAULTS
		{
			if (stringIn.length == 0) {
				[self printDebugInformation:TXTLS(@"IRC[1dz-jb]")];

				break;
			}

			NSString *action = stringIn.tokenAsString;

			/* Present help */
			if ([action isEqualToString:@"help"])
			{
				NSString *help = TXTLS(@"IRC[bkk-lo]");

				[self printDebugInformationMultiline:help];

				break;
			}

			/* Present list of features */
			else if ([action isEqualToString:@"features"])
			{
				[TLOpenLink openWithString:@"https://help.codeux.com/textual/Command-Reference.kb#cr=defaults" inBackground:NO];

				break;
			}

			/* Prepare to toggle feature */
			NSString *feature = stringIn.tokenInsideQuotes.string;

			BOOL applyToAll = [feature isEqualToString:@"-a"];

			if (applyToAll) {
				feature = stringIn.tokenInsideQuotes.string;
			}

			NSDictionary *features = @{
				@"Ignore Notifications by Private ZNC Users"		: @"setZncIgnoreUserNotifications:",
				@"Send Authentication Requests to UserServ"			: @"setSendAuthenticationRequestsToUserServ:",
				@"Disable Automatic SASL EXTERNAL Response"			: @"setSaslAuthenticationDisableExternalMechanism:",
				@"Send WHO Command Requests to Channels"			: @"setSendWhoCommandRequestsToChannels:",
			};

			BOOL enableFeature = [action isEqualToString:@"enable"];

			/* Cannot toggle feature if the user doesn't tell us which */
			if (feature.length == 0) {
				[self printDebugInformation:TXTLS(@"IRC[1dz-jb]")];

				break;
			}

			/* Make sure the feature exists */
			if ([features containsKey:feature] == NO) {
				if (enableFeature) {
					[self printDebugInformation:TXTLS(@"IRC[pc4-67]", feature)];
				} else {
					[self printDebugInformation:TXTLS(@"IRC[d7y-pv]", feature)];
				}

				break;
			}

			/* Toggle the feature by mutating the client's configuration,
			 invoking the appropriate method, then saving it. */
			void (^toggleFeature)(IRCClient *, NSString *, BOOL) = ^(IRCClient *client, NSString *featureKey, BOOL featureValue) {
				NSString *selectorString = features[featureKey];

				SEL selector = NSSelectorFromString(selectorString);

				IRCClientConfigMutable *mutableClientConfig = [client.config mutableCopy];

				NSMethodSignature *signature = [mutableClientConfig methodSignatureForSelector:selector];

				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

				[invocation setTarget:mutableClientConfig];
				[invocation setSelector:selector];

				[invocation setArgument:&featureValue atIndex:2];

				[invocation invoke];

				client.config = mutableClientConfig;
			};

			/* Toggle feature */
			for (IRCClient *client in worldController().clientList) {
				if (client != self && applyToAll == NO) {
					continue;
				}

				toggleFeature(client, feature, enableFeature);

				if (enableFeature) {
					[client printDebugInformation:TXTLS(@"IRC[5ke-18]", feature)];
				} else {
					[client printDebugInformation:TXTLS(@"IRC[0gn-cb]", feature)];
				}
			}

			/* Save modified client */
			[worldController() save];

			break;
		}
		case IRCLocalCommandGline: // Command: GLINE
		case IRCLocalCommandGzline: // Command: GZLINE
		case IRCLocalCommandShun:  // Command: SHUN
		case IRCLocalCommandTempshun: // Command: TEMPSHUN
		case IRCLocalCommandZline: // Command: ZLINE
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			NSString *segment1 = stringIn.getTokenAsString;
			NSString *segment2 = stringIn.getTokenAsString;

			[self send:uppercaseCommand, segment1, segment2, stringIn.string, nil];

			break;
		}
		case IRCLocalCommandGoto: // Command: GOTO
		{
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			NSString *needle = stringIn.tokenAsString;

			IRCTreeItem *bestMatch = mainWindow().selectedItem;

			CGFloat bestScore = 0.0;

			for (IRCClient *client in worldController().clientList) {
				for (IRCChannel *channel in client.channelList) {
					CGFloat currentScore = [channel.name compareWithWord:needle lengthPenaltyWeight:0.1];

					if (currentScore > bestScore) {
						bestMatch = channel;

						bestScore = currentScore;
					}
				}
			}

			[mainWindow() select:bestMatch];

			break;
		}
		case IRCLocalCommandIgnore: // Command: IGNORE
		case IRCLocalCommandUnignore: // Command: UNIGNORE
		{
			BOOL isIgnoreCommand = (commandNumeric == IRCLocalCommandIgnore);

			if (stringIn.length == 0 || targetChannel == nil) {
				if (isIgnoreCommand) {
					[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry context:@""];
				} else {
					[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionAddressBook context:nil];
				}

				break;
			}

			NSString *nickname = stringIn.tokenAsString;

			IRCUser *member = [self findUser:nickname];

			if (member == nil) {
				if (isIgnoreCommand) {
					[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionNewIgnoreEntry context:nickname];
				} else {
					[menuController() showServerPropertiesSheetForClient:self withSelection:TDCServerPropertiesSheetSelectionAddressBook context:nil];
				}

				break;
			}

			/* Build list of ignores that already match the user's host */
			NSString *hostmask = member.hostmask;

			if (hostmask == nil) {
				hostmask = [NSString stringWithFormat:@"%@!*@*", nickname];
			}

			NSMutableArray *matchedIgnores = [NSMutableArray array];

			for (IRCAddressBookEntry *ignore in self.config.ignoreList) {
				if (ignore.entryType != IRCAddressBookEntryTypeIgnore) {
					continue;
				}

				if ([ignore checkMatch:hostmask]) {
					[matchedIgnores addObject:ignore];
				}
			}

			/* Cancel if there is nothing to change */
			if (isIgnoreCommand) {
				if (matchedIgnores.count > 0) {
					[self printDebugInformation:TXTLS(@"IRC[5ix-zn]", member.nickname)];

					break;
				}
			} else {
				if (matchedIgnores.count == 0) {
					[self printDebugInformation:TXTLS(@"IRC[wu0-jp]", member.nickname)];

					break;
				} else if (matchedIgnores.count > 1) {
					[self printDebugInformation:TXTLS(@"IRC[vrx-1f]", member.nickname)];
					
					break;
				}
			}

			/* Modify ignore list and inform user of change */
			NSMutableArray *mutableIgnoreList = [self.config.ignoreList mutableCopy];

			if (isIgnoreCommand) {
				IRCAddressBookEntry *ignore =
				[IRCAddressBookEntry newIgnoreEntryForHostmask:member.banMask];

				[self printDebugInformation:TXTLS(@"IRC[ret-20]", member.nickname, ignore.hostmask)];

				[mutableIgnoreList addObject:ignore];
			} else{
				IRCAddressBookEntry *ignore = matchedIgnores[0];
				
				[self printDebugInformation:TXTLS(@"IRC[jzg-g8]", member.nickname, ignore.hostmask)];

				[mutableIgnoreList removeObjectIdenticalTo:ignore];
			}

			/* Save modified ignore list */
			IRCClientConfigMutable *mutableClientConfig = [self.config mutableCopy];

			mutableClientConfig.ignoreList = mutableIgnoreList;

			self.config = mutableClientConfig;
			
			/* Clear cache */
			/* If we have a host, then it's easy to clear only that.
			 If we don't have a host, then we have to clear everything. */
			if (hostmask) {
				[self clearAddressBookCacheForHostmask:hostmask];
			} else {
				[self clearAddressBookCache];
			}

			break;
		}
		case IRCLocalCommandInvite: // Command: INVITE
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			NSArray *nicknames = [stringIn.string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			if ([self stringIsChannelName:nicknames.lastObject] == NO) {
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else {
					[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
					
					break;
				}
			} else {
				targetChannelName = nicknames.lastObject;
				
				nicknames = [nicknames subarrayWithRange:NSMakeRange(0, (nicknames.count - 1))];
			}

			for (NSString *nickname in nicknames) {
				if ([self stringIsNickname:nickname] == NO) {
					continue;
				}

				[self send:@"INVITE", nickname, targetChannelName, nil];
			}

			break;
		}
		case IRCLocalCommandIson: // Command: ISON
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			[self createHiddenCommandResponses];

			[self.requestedCommands recordIsonRequestOpenedAsVisible];

			[self send:@"ISON", stringIn.string, nil];

			break;
		}
		case IRCLocalCommandJ: // Command: J
		case IRCLocalCommandJoin:  // Command: JOIN
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else {
					[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
					
					break;
				}
			} else {
				targetChannelName = stringIn.tokenAsString;

				if (targetChannelName.length == 0) {
					[self printInvalidSyntaxMessageForCommand:command];

					break;
				}

				if ([self stringIsChannelNameOrZero:targetChannelName] == NO) {
					targetChannelName = [@"#" stringByAppendingString:targetChannelName];
				}
			}

			[self joinUnlistedChannelsWithStringAndSelectBestMatch:targetChannelName passwords:stringIn.string];

			break;
		}
		case IRCLocalCommandJoinRandom: // Command: JOIN_RANDOM
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			NSInteger numberOfChannelsToJoin = 0;

			NSString *numberOfChannelsToken = stringIn.tokenAsString;

			if (numberOfChannelsToken.isNumericOnly) {
				numberOfChannelsToJoin = numberOfChannelsToken.integerValue;
			}

			if (numberOfChannelsToJoin <= 0) {
				numberOfChannelsToJoin = 1;
			}

			for (NSUInteger i = 0; i < numberOfChannelsToJoin; i++) {
				NSString *channelName = [NSString stringWithFormat:@"#debug-channel-%lu", TXRandomNumber(9999999)];

				[self send:@"JOIN", channelName, nil];
			}

			break;
		}
		case IRCLocalCommandBan: // Command: BAN
		case IRCLocalCommandKb: // Command: KB
		case IRCLocalCommandKick: // Command: KICK
		case IRCLocalCommandKickban: // Command: KICKBAN
		case IRCLocalCommandUnban: // Command: UNBAN
		case IRCLocalCommandUnquiet: // Command: UNQUIET
		case IRCLocalCommandQuiet: // Command: QUIET
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			NSString *nickname = stringIn.tokenAsString;

			if ([self stringIsChannelName:nickname] == NO) {
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else {
					[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];
					
					break;
				}
			} else {
				targetChannelName = nickname;

				targetChannel = [self findChannel:targetChannelName];
				
				nickname = stringIn.tokenAsString;
			}

			if (nickname.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
					
				break;
			}

			if (commandNumeric == IRCLocalCommandKickban ||
				commandNumeric == IRCLocalCommandKb ||
				commandNumeric == IRCLocalCommandBan ||
				commandNumeric == IRCLocalCommandUnban ||
				commandNumeric == IRCLocalCommandQuiet ||
				commandNumeric == IRCLocalCommandUnquiet)
			{
				IRCChannelUser *member = [targetChannel findMember:nickname];

				NSString *banMask = member.user.banMask;

				if (banMask == nil) {
					banMask = nickname;
				}

				NSString *modeSymbol = nil;

				if (commandNumeric == IRCLocalCommandQuiet ||
					commandNumeric == IRCLocalCommandUnquiet)
				{
					modeSymbol = @"q";
				} else {
					modeSymbol = @"b";
				}

				if ([self.supportInfo modeSymbolIsUserPrefix:modeSymbol]) {
					[self printDebugInformation:TXTLS(@"IRC[dwi-d1]", modeSymbol)];

					break;
				}

				if (commandNumeric == IRCLocalCommandUnban ||
					commandNumeric == IRCLocalCommandUnquiet)
				{
					[self send:@"MODE", targetChannelName, [@"-" stringByAppendingString:modeSymbol], banMask, nil];
				} else {
					[self send:@"MODE", targetChannelName, [@"+" stringByAppendingString:modeSymbol], banMask, nil];
				}
			}

			if (commandNumeric == IRCLocalCommandKb ||
				commandNumeric == IRCLocalCommandKick ||
				commandNumeric == IRCLocalCommandKickban)
			{
				NSString *reason = stringIn.string;

				if (reason.length == 0) {
					reason = [TPCPreferences defaultKickMessage];
				}

				NSUInteger reasonMaximumLength = self.supportInfo.maximumKickLength;

				if (reasonMaximumLength > 0 && reason.length > reasonMaximumLength) {
					[self printDebugInformation:TXTLS(@"IRC[59a-ir]", self.networkNameAlt, reasonMaximumLength)];
				}

				[self send:@"KICK", targetChannelName, nickname, reason, nil];
			}

			break;
		}
		case IRCLocalCommandKill: // Command: KILL
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			NSString *nickname = stringIn.getTokenAsString;

			if (nickname.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			NSString *reason = stringIn.string;

			if (reason.length == 0) {
				reason = [TPCPreferences IRCopDefaultKillMessage];
			}

			[self send:@"KILL", nickname, reason, nil];

			break;
		}
		case IRCLocalCommandLagcheck: // Command: LAGCHECK
		case IRCLocalCommandMylag: // Command: MYLAG
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			/* We only accept LAGCHECK CTCP responses from ourselves which
			 means it is relatively safe to pack some data on the end of
			 the CTCP so that we can provide ourselves some context. */
			NSMutableDictionary *lagCheckContext = [NSMutableDictionary dictionaryWithCapacity:3];

			lagCheckContext[@"connection"] = self.socket.uniqueIdentifier;
			
			lagCheckContext[@"time"] = @([NSDate timeIntervalSince1970]);

			if (commandNumeric == IRCLocalCommandMylag) {
				IRCChannel *selectedChannel = [mainWindow() selectedChannelOn:self];
				
				if (selectedChannel) {
					lagCheckContext[@"channel"] = selectedChannel.name;
				}
			}
			
			NSString *ctcpContext = [lagCheckContext formDataUsingSeparator:@"&"];

			[self sendCTCPQuery:self.userNickname
						command:@"LAGCHECK"
						   text:ctcpContext];

			[self printDebugInformation:TXTLS(@"IRC[qoh-kt]")];

			break;
		}
		case IRCLocalCommandLeave: // Command: LEAVE
		case IRCLocalCommandPart: // Command: PART
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if ([self stringIsChannelName:stringIn.string] == NO) {
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else if (targetChannel) {
					[worldController() destroyChannel:targetChannel];

					break;
				} else {
					break;
				}
			} else {
				targetChannelName = stringIn.tokenAsString;
			}
			
			NSString *reason = stringIn.string;

			if (reason.length == 0) {
				reason = self.config.normalLeavingComment;
			}

			[self send:@"PART", targetChannelName, reason, nil];

			break;
		}
		case IRCLocalCommandList: // Command: LIST
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			TDCServerChannelListDialog *channelListDialog = [self channelListDialog];

			if (channelListDialog == nil) {
				[self createChannelListDialog];
			}

			[self requestChannelList];

			break;
		}
		case IRCLocalCommandM: // Command: M
		case IRCLocalCommandMode: // Command: MODE
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			NSString *modeString = stringIn.string;

			if (  modeString.length == 0 ||
				([modeString hasPrefix:@"+"] ||
				 [modeString hasPrefix:@"-"]))
			{
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else {
					[self printInvalidSyntaxMessageForCommand:command];
					
					break;
				}
			} else {
				targetChannelName = stringIn.tokenAsString;
			}

			if (modeString.length == 0) {
				[self send:@"MODE", targetChannelName, nil];
			} else {
				[self send:@"MODE", targetChannelName, modeString, nil];
			}

			break;
		}
		case IRCLocalCommandMute: // Command: MUTE
		{
			if ([TPCPreferences soundIsMuted]) {
				[self printDebugInformation:TXTLS(@"IRC[sdn-yr]")];
			} else {
				[self printDebugInformation:TXTLS(@"IRC[u48-aa]")];

				[menuController() toggleMuteOnNotificationSoundsShortcutOn:YES];
			}

			break;
		}
		case IRCLocalCommandMyversion: // Command: MYVERSION
		{
			NSString *applicationName = [TPCApplicationInfo applicationNameWithoutVersion];
			NSString *versionLong = [TPCApplicationInfo applicationVersion];
			NSString *versionShort = [TPCApplicationInfo applicationVersionShort];
//			NSString *buildScheme = [TPCApplicationInfo applicationBuildScheme];

			NSString *downloadSource = @""; // Assume standalone by default
			NSString *buildType = @""; // Assume universal binary by default

#if TEXTUAL_BUILT_AS_UNIVERSAL_BINARY == 0
			NSString *hostType = nil;

#if TARGET_CPU_ARM64
			hostType = TXTLS(@"IRC[g1u-os]");
#elif TARGET_CPU_X86_64
			hostType = TXTLS(@"IRC[swz-uj]");
#endif

			buildType = TXTLS(@"IRC[b8p-44]", hostType);
#endif // Universal

			NSString *message = TXTLS(@"IRC[ccb-ur]", applicationName, versionShort, versionLong, downloadSource, buildType);

			if (targetChannel) {
				message = TXTLS(@"IRC[pqj-1y]", message);

				[self sendPrivmsg:message toChannel:targetChannel];
			} else {
				[self printDebugInformationToConsole:message];
			}

			break;
		}
		case IRCLocalCommandNick: // Command: NICK
		{
			/* Use -isConnected instead of -isLoggedIn so that
			 user can change their nickname during registration
			 phase before the 001 numeric is received. */
			NSAssertReturnLoopBreak(self.isConnected);
			
			NSString *newNickname = stringIn.tokenAsString;
			
			if (newNickname.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			for (IRCClient *client in worldController().clientList) {
				if (client != self && [TPCPreferences nickAllConnections] == NO) {
					continue;
				}

				[client changeNickname:newNickname];
			}

			break;
		}
		case IRCLocalCommandNotifybubble: // Command: NOTIFYBUBBLE
		{
			if ([self stringIsChannelName:stringIn.string]) {
				targetChannel = [self findChannel:stringIn.tokenAsString];
			} else {
				targetChannel = nil;
			}
			
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			NSString *title = [TPCApplicationInfo applicationNameWithoutVersion];

			NSString *message = stringIn.string;

			[sharedNotificationController() scheduleNotificationWithTitle:title
																  message:message
															   forChannel:targetChannel
																 onClient:self];

			break;
		}
		case IRCLocalCommandNotifysound: // Command: NOTIFYSOUND
		{
			NSString *soundName = stringIn.tokenAsString;
			
			if (soundName.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			[TLOSoundPlayer playAlertSound:soundName];

			break;
		}
		case IRCLocalCommandNotifyspeak: // Command: NOTIFYSPEAK
		{
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}
			
			[[TXSharedApplication sharedSpeechSynthesizer] speak:stringIn.string];

			break;
		}
		case IRCLocalCommandQuery: // Command: QUERY
		{
			NSString *nickname = stringIn.tokenAsString;
			
			if (nickname.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			if ([self stringIsNickname:nickname] == NO) {
				[self printDebugInformation:TXTLS(@"IRC[zef-q9]")];
				
				break;
			}

			IRCChannel *query = [self findChannelOrCreate:nickname isPrivateMessage:YES];

			[mainWindow() select:query];

			if (stringIn.length > 0) {
				[self sendText:stringIn asCommand:IRCRemoteCommandPrivmsg toChannel:query];
			}

			break;
		}
		case IRCLocalCommandQuote: // Command: QUOTE
		case IRCLocalCommandRaw: // Command: RAW
		{
			NSAssertReturnLoopBreak(self.isConnected);
			
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}
			
			[self sendLine:stringIn.string];

			break;
		}
		case IRCLocalCommandQuit: // Command: QUIT
		{
			NSAssertReturnLoopBreak(self.isConnected);

			if (stringIn.length == 0) {
				[self quit];
			} else {
				[self quitWithComment:stringIn.string];
			}

			break;
		}
		case IRCLocalCommandNames: // Command: NAMES
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			[self createHiddenCommandResponses];

			[self send:@"NAMES", stringIn.string, nil];

			break;
		}
		case IRCLocalCommandRecv: // Command: RECV
		{
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];

				break;
			}

			[self ircConnection:self.socket didReceiveData:stringIn.string];

			break;
		}
		case IRCLocalCommandSetcolor: // Command: SETCOLOR
		{
			if ([TPCPreferences disableNicknameColorHashing]) {
				[self printDebugInformation:TXTLS(@"IRC[026-qv]")];

				break;
			}

			NSString *nickname = stringIn.lowercaseGetToken;

			if (nickname.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			if ([self stringIsNickname:nickname] == NO) {
				[self printDebugInformation:TXTLS(@"IRC[8dy-6f]", nickname)];

				break;
			}

			[menuController() memberChangeColor:nickname];

			break;
		}
		case IRCLocalCommandSetqueryname: // Command: SETQUERYNAME
		{
			if (targetChannel == nil || targetChannel.isPrivateMessage == NO) {
				[self printDebugInformation:TXTLS(@"IRC[m6o-z1]")];

				break;
			}

			NSString *nickname = stringIn.getTokenAsString;

			if (nickname.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];

				break;
			}

			if ([self stringIsNickname:nickname] == NO) {
				[self printDebugInformation:TXTLS(@"IRC[zef-q9]")];

				break;
			}

			IRCChannel *oldQuery = [self findChannel:nickname];

			if (oldQuery) {
				BOOL deleteOldQuery =
				[TDCAlert modalAlertWithMessage:TXTLS(@"Prompts[61s-jc]")
										  title:TXTLS(@"Prompts[d22-76]", oldQuery.name)
								  defaultButton:TXTLS(@"Prompts[mvh-ms]")
								alternateButton:TXTLS(@"Prompts[99q-gg]")];

				if (deleteOldQuery) {
					[worldController() destroyChannel:oldQuery];
				} else {
					break;
				}
			}

			targetChannel.name = nickname;

			[mainWindow() reloadTreeItem:targetChannel];

			[mainWindow() updateTitleFor:targetChannel];

			break;
		}
		case IRCLocalCommandServer: // Command: SERVER
		{
			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			[IRCExtras createConnectionToServer:stringIn.string channelList:nil connectWhenCreated:YES];

			break;
		}
		case IRCLocalCommandSslcontext: // Command: SSLCONTEXT
		{
			[self presentCertificateTrustInformation];

			break;
		}
		case IRCLocalCommandTage: // Command: TAGE
		{
			NSTimeInterval timePassed = [NSDate timeIntervalSinceNow:[TPCApplicationInfo applicationBirthday]];

			NSString *message = TXTLS(@"IRC[v9x-18]", TXHumanReadableTimeInterval(timePassed, NO, 0));

			if (targetChannel) {
				[self sendPrivmsg:message toChannel:targetChannel];
			} else {
				[self printDebugInformationToConsole:message];
			}

			break;
		}
		case IRCLocalCommandTimer: // Command: TIMER
		{
			if (stringIn.length == 0) {
				[self printDebugInformation:TXTLS(@"IRC[jj9-94]")];

				break;
			}

			NSString *action = stringIn.tokenAsString;

			/* Present help */
			if ([action isEqualToString:@"help"])
			{
				NSString *topic = stringIn.tokenAsString;

				[self printDebugInformation:TXTLS(@"IRC[aox-zz]")]; // divider

				if ([topic isEqualToStringIgnoringCase:@"add"])
				{
					[self printDebugInformationMultiline:TXTLS(@"IRC[6r0-il]")];
				}
				else if ([topic isEqualToStringIgnoringCase:@"remove"])
				{
					[self printDebugInformationMultiline:TXTLS(@"IRC[i2d-x5]")];
				}
				else if ([topic isEqualToStringIgnoringCase:@"list"])
				{
					[self printDebugInformationMultiline:TXTLS(@"IRC[x1n-ve]")];
				}
				else if ([topic isEqualToStringIgnoringCase:@"stop"])
				{
					[self printDebugInformationMultiline:TXTLS(@"IRC[bx2-n1]")];
				}
				else if ([topic isEqualToStringIgnoringCase:@"restart"])
				{
					[self printDebugInformationMultiline:TXTLS(@"IRC[r27-tv]")];
				}
				else
				{
					[self printDebugInformationMultiline:TXTLS(@"IRC[xkq-rt]")];
				}

				break;
			}

			/* Stop timer */
			if ([action isEqualToString:@"stop"])
			{
				NSString *identifier = stringIn.tokenAsString;

				if (identifier.length == 0) {
					[self printDebugInformation:TXTLS(@"IRC[p6l-o4]")];

					break;
				}

				IRCTimedCommand *timedCommand = [self timedCommandWithIdentifier:identifier];

				if (timedCommand == nil) {
					[self printDebugInformation:TXTLS(@"IRC[vzu-xh]", identifier)];

					break;
				}

				if (timedCommand.timerIsActive == NO) {
					[self printDebugInformation:TXTLS(@"IRC[ax6-n9]", identifier)];

					break;
				}

				[self stopTimedCommand:timedCommand];

				[self printDebugInformation:TXTLS(@"IRC[hs0-up]", identifier)];

				break;
			}

			/* Restart timer */
			if ([action isEqualToString:@"restart"])
			{
				NSString *identifier = stringIn.tokenAsString;

				if (identifier.length == 0) {
					[self printDebugInformation:TXTLS(@"IRC[p6l-o4]")];

					break;
				}

				IRCTimedCommand *timedCommand = [self timedCommandWithIdentifier:identifier];

				if (timedCommand == nil) {
					[self printDebugInformation:TXTLS(@"IRC[vzu-xh]", identifier)];

					break;
				}

				if ([self restartTimedCommand:timedCommand]) {
					[self printDebugInformation:TXTLS(@"IRC[qb7-mi]", identifier)];
				} else {
					[self printDebugInformation:TXTLS(@"IRC[dgp-d4]", identifier)];
				}

				break;
			}

			/* Remove timer */
			if ([action isEqualToString:@"remove"])
			{
				NSString *identifier = stringIn.tokenAsString;

				if (identifier.length == 0) {
					[self printDebugInformation:TXTLS(@"IRC[p6l-o4]")];

					break;
				}

				if ([identifier isEqualToStringIgnoringCase:@"all"]) {
					[self removeTimedCommands];

					[self printDebugInformation:TXTLS(@"IRC[808-bs]")];

					break;
				}

				IRCTimedCommand *timedCommand = [self timedCommandWithIdentifier:identifier];

				if (timedCommand == nil) {
					[self printDebugInformation:TXTLS(@"IRC[vzu-xh]", identifier)];

					break;
				}

				[self removeTimedCommand:timedCommand];

				[self printDebugInformation:TXTLS(@"IRC[p7s-is]", identifier)];

				break;
			}

			/* List timers */
			if ([action isEqualToString:@"list"])
			{
				NSArray *timedCommands = [self listOfTimedCommands];

				NSUInteger numberOfTimers = timedCommands.count;

				if (numberOfTimers == 0) {
					[self printDebugInformation:TXTLS(@"IRC[pqk-5k]")];

					break;
				} else if (numberOfTimers == 1) {
					[self printDebugInformation:TXTLS(@"IRC[6ts-oi]", numberOfTimers)];
				} else {
					[self printDebugInformation:TXTLS(@"IRC[q1m-1e]", numberOfTimers)];
				}

				for (IRCTimedCommand *timedCommand in timedCommands) {
					NSString *description = [self descriptionForTimedCommand:timedCommand];

					[self printDebugInformation:description];
				}

				break;
			}

			/* Add timer */
			/*
			 This command is designed to be backwards compatible.

			 Old syntax:
			 "/timer <seconds> <command>"

			 New syntax:
			 "/timer <seconds> <repeat> <command>"

			 We check the value of the second argument. If it's a number,
			 then we treat it as the new syntax which means that number
			 is the repeat count for the timer.
			 */

			/* Parse interval */
			NSString *intervalString = action;

			if (intervalString.length == 0) {
				[self printDebugInformation:TXTLS(@"IRC[jj9-94]")];

				break;
			}

			NSInteger interval = intervalString.integerValue;

			if (interval <= 0) {
				[self printDebugInformation:TXTLS(@"IRC[327-pv]")];

				break;
			}

			/* Parse repeat count and/or command */
			/*
			 Repeat argument is treated as such:
			   == 0 — repeat and never stop
			   == 1 - perform timer once, do not repeat
			   > 1 — repeat number of times
			 */
			NSString *repeatString = stringIn.tokenAsString;

			NSInteger repeat = NSNotFound;

			NSString *command = stringIn.trimmedString;

			if ([repeatString contentsIsOfType:CSStringTypeAnyNumber])
			{
				/* Contents of second argument is a number,
				 which means we want to treat it as the repeat count. */
				repeat = repeatString.integerValue;
			}
			else
			{
				/* Contents of second argument is NOT a number,
				 which means we need to merge that back with the
				 remainder of the command value. */
				if (command.length == 0) {
					command = repeatString;
				} else {
					command = [repeatString stringByAppendingFormat:@" %@", command];
				}
			}

			/* Perform additional validation */
			if (repeat < 0) {
				[self printDebugInformation:TXTLS(@"IRC[eud-kc]")];

				break;
			}

			if (command.length == 0) {
				[self printDebugInformation:TXTLS(@"IRC[jj9-94]")];

				break;
			}

			/* If we have no repeat value, then treat is one pass. */
			if (repeat == NSNotFound) {
				repeat = 1;
			}

			/* Add timer */
			IRCTimedCommand *timedCommand = nil;

			if (targetChannel == nil) {
				timedCommand = [[IRCTimedCommand alloc] initWithCommand:command onClient:self];
			} else {
				timedCommand = [[IRCTimedCommand alloc] initWithCommand:command onClient:self inChannel:targetChannel];
			}

			[self addTimedCommand:timedCommand];

			[self startTimedCommand:timedCommand interval:interval onRepeat:(repeat != 1) iterations:repeat];

			break;
		}
		case IRCLocalCommandT: // Command: T
		case IRCLocalCommandTopic: // Command: TOPIC
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if ([self stringIsChannelName:stringIn.string] == NO) {
				if (targetChannel && targetChannel.isChannel) {
					targetChannelName = targetChannel.name;
				} else {
					break;
				}
			} else {
				targetChannelName = stringIn.tokenAsString;
			}

			NSString *topic = stringIn.stringFormattedForIRC;

			NSUInteger topicLength = topic.length;

			if (topicLength == 0) {
				[self send:@"TOPIC", targetChannelName, nil];

				return;
			}

			NSUInteger topicLengthMaximum = self.supportInfo.maximumTopicLength;

			if (topicLengthMaximum > 0 && topicLength > topicLengthMaximum) {
				[self printDebugInformation:TXTLS(@"IRC[1oo-3b]", self.networkNameAlt, topicLengthMaximum)];
			}

			[self send:@"TOPIC", targetChannelName, topic, nil];

			break;
		}
		case IRCLocalCommandUmode: // Command: UMODE
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self send:@"MODE", self.userNickname, nil];
			} else {
				[self send:@"MODE", self.userNickname, stringIn.string, nil];
			}

			break;
		}
		case IRCLocalCommandUnmute: // Command: UNMUTE
		{
			if ([TPCPreferences soundIsMuted] == NO) {
				[self printDebugInformation:TXTLS(@"IRC[5rf-mj]")];
			} else {
				[self printDebugInformation:TXTLS(@"IRC[190-f2]")];

				[menuController() toggleMuteOnNotificationSoundsShortcutOn:NO];
			}

			break;
		}
		case IRCLocalCommandWallops: // Command: WALLOPS
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			[self send:@"WALLOPS", stringIn.string, nil];

			break;
		}
		case IRCLocalCommandMonitor: // Command: MONITOR
		case IRCLocalCommandWatch: // Command: WATCH
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			BOOL isClearCommand = NO;
			BOOL isModifierCommand = NO;

			/* UnrealIRCd splits arguments using space and loops through all of them
			 which means a modifier or clear command can appear at the same time. */
			NSArray *arguments = [stringIn.string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *argument in arguments) {
				if ([argument hasPrefix:@"-"] || [stringIn.string hasPrefix:@"+"] ) {
					isModifierCommand = YES;

					break;
				} else if ([argument isEqualIgnoringCase:@"c"]) {
					isClearCommand = YES;
				}
			}

			if (isModifierCommand) {
				[self printDebugInformation:TXTLS(@"IRC[khw-4y]")];

				break;
			}

			/* The clear command doesn't produce a result */
			if (isClearCommand == NO) {
				[self createHiddenCommandResponses];
			}

			[self sendCommand:uppercaseCommand withData:stringIn.string];

			break;
		}
		case IRCLocalCommandWho: // Command: WHO
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			if (stringIn.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];
				
				break;
			}

			[self createHiddenCommandResponses];

			[self.requestedCommands recordWhoRequestOpenedAsVisible];

			[self send:@"WHO", stringIn.string, nil];

			break;
		}
		case IRCLocalCommandWeights: // Command: WEIGHTS
		{
			if (targetChannel == nil || targetChannel.isChannel == NO) {
				[self printDebugInformation:TXTLS(@"IRC[g01-qn]")];

				break;
			}

			[self printDebugInformation:TXTLS(@"IRC[zud-u3]", targetChannel.name)];

			BOOL haveWeights = NO;

			for (IRCChannelUser *member in targetChannel.memberList) {
				double incomingWeight = member.incomingWeight;
				double outgoingWeight = member.outgoingWeight;

				CGFloat weight = (incomingWeight + outgoingWeight);

				if (weight > 0) {
					haveWeights = YES;

					[self printDebugInformation:TXTLS(@"IRC[24r-8c]",
							member.user.nickname, outgoingWeight, incomingWeight, weight)];
				}
			}

			if (haveWeights == NO) {
				[self printDebugInformation:TXTLS(@"IRC[dje-41]")];
			}

			break;
		}
		case IRCLocalCommandWhois: // Command: WHOIS
		{
			NSAssertReturnLoopBreak(self.isLoggedIn);

			NSString *nickname1 = stringIn.tokenAsString;

			if (nickname1.length == 0) {
				if (targetChannel && targetChannel.isPrivateMessage) {
					nickname1 = targetChannel.name;
				} else {
					[self printInvalidSyntaxMessageForCommand:command];
					
					break;
				}
			}

			NSString *nickname2 = stringIn.tokenAsString;
	
			if (nickname2.length == 0) {
				[self send:@"WHOIS", nickname1, nickname1, nil];
			} else {
				[self send:@"WHOIS", nickname1, nickname2, nil];
			}

			break;
		}
		case IRCLocalCommandMe: // Command: ME
		case IRCLocalCommandMsg: // Command: MSG
		case IRCLocalCommandNotice: // Command: NOTICE
		case IRCLocalCommandOmsg: // Command: OMSG
		case IRCLocalCommandOnotice: // Command: ONOTICE
		case IRCLocalCommandSme: // Command: SME
		case IRCLocalCommandSmsg: // Command: SMSG
		{
			/* Where would se send data to? */
			if (self.isLoggedIn == NO) {
				[self printDebugInformationToConsole:TXTLS(@"IRC[6rj-2r]")];

				break;
			}

			/* Establish context for comand */
			NSString *channelNamePrefix = nil;

			BOOL isOperatorMessage = NO;
			BOOL isSecretMessage = NO;

			NSString *commandToSend = nil;

			TVCLogLineType lineType = TVCLogLineTypeUndefined;

			if (commandNumeric == IRCLocalCommandMsg ||
				commandNumeric == IRCLocalCommandOmsg ||
				commandNumeric == IRCLocalCommandSmsg)
			{
				commandToSend = @"PRIVMSG";

				lineType = TVCLogLineTypePrivateMessage;

				isOperatorMessage = (commandNumeric == IRCLocalCommandOmsg);
				isSecretMessage = (commandNumeric == IRCLocalCommandSmsg);
			}
			else if (commandNumeric == IRCLocalCommandMe ||
					 commandNumeric == IRCLocalCommandSme)
			{
				commandToSend = @"PRIVMSG";

				lineType = TVCLogLineTypeAction;

				isSecretMessage = (commandNumeric == IRCLocalCommandSme);
			}
			else if (commandNumeric == IRCLocalCommandNotice || // Command: NOTICE
					 commandNumeric == IRCLocalCommandOnotice)   // Command: ONOTICE
			{
				commandToSend = @"NOTICE";

				lineType = TVCLogLineTypeNotice;

				isOperatorMessage = (commandNumeric == IRCLocalCommandOnotice);
			}

			if (isOperatorMessage) {
				channelNamePrefix = [self.supportInfo statusMessagePrefixForModeSymbol:@"o"];

				/* If the user is sending an operator message and the user mode +o does 
				 not exist, then fail here. The user may be trying to send something 
				 secret with an expectation for privacy and we cannot deliver that. */
				if (channelNamePrefix == nil) {
					[self printDebugInformation:TXTLS(@"IRC[54l-h7]", @"o")];

					break;
				}
			}

			/* Pick the best target */
			/* All actions except (SME) should use the target channel */
			/* Operator messages should use the target channel unless the
			 string in is a channel name */
			/* All other scenarios use the string in (token) */
			if (isSecretMessage == NO && lineType == TVCLogLineTypeAction && targetChannel) {
				if (targetChannel.isUtility) {
					[self printDebugInformation:TXTLS(@"sxf-qx")];

					break;
				}

				targetChannelName = targetChannel.name;
			} else if (isOperatorMessage && [self stringIsChannelName:stringIn.string] == NO && targetChannel.isChannel) {
				targetChannelName = targetChannel.name;
			} else {
				targetChannelName = stringIn.tokenAsString;
			}

			if (targetChannelName.length == 0) {
				[self printInvalidSyntaxMessageForCommand:command];

				break;
			}

			/* Actions are allowed to have an empty message but all other
			 types are not. Empty actions use a whitespace. */
			if (stringIn.length == 0) {
				if (lineType == TVCLogLineTypeAction) {
					[stringIn replaceCharactersInRange:NSMakeRange(0, 0)
											withString:@" "];
				} else {
					break;
				}
			}

			/* At this point, the following will occur:
			 1. Each destination is looped over
				1. Prefix characters are removed from the destination name
				2. Try to find channel that already exists which matches
				   the destination. If a channel does not exist, then we 
				   create one depending on whether this is a secret message.
				3. The message is then sent off.
			 */
			NSArray *destinations = [targetChannelName componentsSeparatedByString:@","];

			IRCChannel *destinationToSelect = nil;

			for (__strong NSString *destinationName in destinations) {
				/* If the user prefixed the target with a mode (e.g. +#channel)
				 to indicate that they want the message only seen by that group
				 of users, then we first have to remove that prefix to perform
				 our own processing of the target. When it comes time to send 
				 the message, then the prefix is added back to the target name. */
				NSString *destinationNamePrefix = [self.supportInfo extractStatusMessagePrefixFromChannelNamed:destinationName];

				if (destinationNamePrefix.length == 0) {
					destinationNamePrefix = channelNamePrefix;
				} else {
					destinationName = [destinationName substringFromIndex:1];
				}

				/* Locate object that matches destination */
				IRCChannel *destination = [self findChannel:destinationName];

				if (isSecretMessage == NO) {
					/* If the destination does not exist and this isn't a secret
					 message, then create a private message if the destination 
					 is believed to be a user. */
					if (destination == nil && [self stringIsNickname:destinationName]) {
						destination = [worldController() createPrivateMessage:destinationName onClient:self];
					}

					/* Define the channel that will be selected */
					if ([TPCPreferences giveFocusOnMessageCommand]) {
						if (destinationToSelect == nil) {
							destinationToSelect = destination;
						}
					}
				}

				/* Add prefix back if the destination is a channel */
				BOOL destinationIsChannel =
				(destination.isChannel || (destination == nil && [self stringIsChannelName:destinationName]));

				if (destinationNamePrefix && destinationIsChannel) {
					destinationName = [destinationNamePrefix stringByAppendingString:destinationName];
				}

				/* Break text up into substrings which can then be sent. */
				NSMutableAttributedString *lineMutable = [stringIn mutableCopy];

				while (lineMutable.length > 0)
				{
					NSString *message = [lineMutable stringFormattedForChannel:destinationName onClient:self withLineType:lineType];

					if (destination && [self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage] == NO) {
						[self print:message
								 by:self.userNickname
						  inChannel:destination
							 asType:lineType
							command:command
						 receivedAt:[NSDate date]];
					}

					if (lineType == TVCLogLineTypeAction) {
						message = [NSString stringWithFormat:@"%cACTION %@%c", 0x01, message, 0x01];
					}

					[self send:commandToSend, destinationName, message, nil];
				}
			} // destination for()

			/* Focus destination */
			if (destinationToSelect) {
				[mainWindow() select:destinationToSelect];
			}

			break;
		}
		default:
		{
			/* Find an addon responsible for this command. */
			NSString *addonPath = nil;

			BOOL pluginFound = NO;
			BOOL scriptFound = NO;

			[sharedPluginManager() findHandlerForOutgoingCommand:lowercaseCommand path:&addonPath isScript:&scriptFound isExtension:&pluginFound];

			/* Perform script or plugin. */
			if (pluginFound && scriptFound)
			{
				[self printDebugInformation:TXTLS(@"IRC[d3c-9b]", uppercaseCommand)];
				
				break;
			}
			else if (pluginFound && scriptFound == NO)
			{
				[self processBundlesUserMessage:stringIn.string command:lowercaseCommand];

				break;
			}
			else if (pluginFound == NO && scriptFound)
			{
				NSMutableDictionary<NSString *, NSString *> *context = [NSMutableDictionary dictionaryWithCapacity:3];

				[context maybeSetObject:stringIn.string forKey:@"inputString"];

				[context maybeSetObject:addonPath forKey:@"path"];

				[context maybeSetObject:targetChannel.name forKey:@"targetChannel"];

				[self executeTextualCmdScriptInContext:context];

				break;
			}

			/* Send input to server */
			[self sendCommand:uppercaseCommand withData:stringIn.string];

			break;
		}
	}
}

- (void)sendCommand:(NSString *)command withData:(NSString *)data
{
	NSParameterAssert(command != nil);
	NSParameterAssert(data != nil);

	NSString *stringToSend = [NSString stringWithFormat:@"%@ %@", command, data];

	[self sendLine:stringToSend];
}

- (void)printInvalidSyntaxMessageForCommand:(NSString *)command
{
	NSParameterAssert(command != nil);
	
	NSString *syntax = [IRCCommandIndex syntaxForLocalCommand:command];
	
	if (syntax == nil) {
		return;
	}
	
	[self printDebugInformation:TXTLS(@"IRC[atq-93]", syntax)];
}

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
	NSParameterAssert(message != nil);

	[self print:[message sequence:sequence] by:nil inChannel:channel asType:TVCLogLineTypeDebug command:message.command receivedAt:message.receivedAt];
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

	[self print:errorMessage by:nil inChannel:channel asType:TVCLogLineTypeDebug command:message.command];
}

- (void)printError:(NSString *)errorMessage asCommand:(NSString *)command
{
	[self print:errorMessage by:nil inChannel:nil asType:TVCLogLineTypeDebug command:command];
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
	[self print:message by:nil inChannel:nil asType:TVCLogLineTypeDebug command:command escapeMessage:escapeMessage];
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

	[self printDebugInformation:message inChannel:channel asCommand:TVCLogLineDefaultCommandValue escapeMessage:YES];
}

- (void)printDebugInformation:(NSString *)message inChannel:(IRCChannel *)channel
{
	[self printDebugInformation:message inChannel:channel asCommand:TVCLogLineDefaultCommandValue escapeMessage:YES];
}

- (void)printDebugInformation:(NSString *)message inChannel:(IRCChannel *)channel asCommand:(NSString *)command
{
	[self print:message by:nil inChannel:channel asType:TVCLogLineTypeDebug command:command escapeMessage:YES];
}

- (void)printDebugInformation:(NSString *)message inChannel:(IRCChannel *)channel escapeMessage:(BOOL)escapeMessage
{
	[self printDebugInformation:message inChannel:channel asCommand:TVCLogLineDefaultCommandValue escapeMessage:escapeMessage];
}

- (void)printDebugInformation:(NSString *)message inChannel:(IRCChannel *)channel asCommand:(NSString *)command escapeMessage:(BOOL)escapeMessage
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

	self.capabilities = 0;
	self.capabilityNegotiationIsPaused = NO;

	@synchronized (self.capabilitiesPending) {
		[self.capabilitiesPending removeAllObjects];
	}

	@synchronized (self.userListPrivate) {
		[self.userListPrivate removeAllObjects];
	}
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

	if (proxyType == IRCConnectionProxyTypeSocks4) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[p7h-un]", proxyHost, proxyPort)];
	} else if (proxyType == IRCConnectionProxyTypeSocks5) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[ni5-cy]", proxyHost, proxyPort)];
	} else if (proxyType == IRCConnectionProxyTypeHTTP) {
		[self printDebugInformationToConsole:TXTLS(@"IRC[oby-av]", proxyHost, proxyPort)];
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

	if (self.disconnectCallback) {
		self.disconnectCallback();
		self.disconnectCallback = nil;
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

/* This delegate call is not invoked on the main thread
 which means if it is modified to interact with UI,
 then it must invoke on the main thread eventually. */
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

	NSString *sender = m.senderNickname;

	BOOL isSelfMessage = NO;

	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage]) {
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
				[self notifyText:TXNotificationTypeChannelNotice lineType:lineType target:channel nickname:sender text:text];
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
					postEvent = [self notifyText:TXNotificationTypeHighlight lineType:lineType target:channel nickname:sender text:text];
				} else {
					postEvent = [self notifyText:TXNotificationTypeChannelMessage lineType:lineType target:channel nickname:sender text:text];
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
		self.isConnectedToZNC)
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
				postEvent = [self notifyText:TXNotificationTypePrivateNotice lineType:lineType target:query nickname:sender text:text];
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
					postEvent = [self notifyText:TXNotificationTypeHighlight lineType:lineType target:query nickname:sender text:text];
				} else {
					if (newPrivateMessage) {
						postEvent = [self notifyText:TXNotificationTypeNewPrivateMessage lineType:lineType target:query nickname:sender text:text];
					} else {
						postEvent = [self notifyText:TXNotificationTypePrivateMessage lineType:lineType target:query nickname:sender text:text];
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

	/* Update query status */
	if (query.isActive == NO) {
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
		__weak IRCClient *weakSelf = self;

		self.disconnectCallback = ^{
			[weakSelf printDebugInformationToConsole:TXTLS(@"IRC[5i4-qq]")];

			[weakSelf connect:IRCClientConnectModeReconnect];
		};

		[self disconnect];
	}
}

- (void)receiveCTCPQuery:(IRCMessage *)m text:(NSString *)text
{
	NSParameterAssert(m != nil);
	NSParameterAssert(text != nil);

	NSString *sender = m.senderNickname;

	BOOL myself = [self nicknameIsMyself:sender];

	IRCAddressBookEntry *ignoreInfo = nil;

	if (myself) {
		/* Ignore messages echoed back to ourselves */
		if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityEchoMessage]) {
			return;
		}
	} else {
		/* Find ignore for sender and possibly exit method */
		ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

		if (ignoreInfo.ignoreClientToClientProtocol) {
			return;
		}
	}

	/* Context */
	NSMutableString *textMutable = [text mutableCopy];

	NSString *command = textMutable.uppercaseGetToken;

	if (command.length == 0) {
		return;
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

	if (printMessage && myself == NO)
	{
		if ([TPCPreferences showJoinLeave] == NO) {
			printMessage = NO;
		} else if (channel.config.ignoreGeneralEventMessages) {
			printMessage = NO;
		} else if (ignoreInfo) {
			printMessage = (ignoreInfo.ignoreGeneralEventMessages == NO);
		}
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

	if (printMessage && myself == NO)
	{
		if ([TPCPreferences showJoinLeave] == NO) {
			printMessage = NO;
		} else if (channel.config.ignoreGeneralEventMessages) {
			printMessage = NO;
		} else {
			IRCAddressBookEntry *ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

			if (ignoreInfo) {
				printMessage = (ignoreInfo.ignoreGeneralEventMessages == NO);
			}
		}
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

				[self cancelPerformRequestsWithSelector:@selector(joinKickedChannel:) object:channel];

				[self performSelectorInCommonModes:@selector(joinKickedChannel:) withObject:channel afterDelay:3.0];
			}
		}
		else // myself
		{
			[channel removeMemberWithNickname:target];
		}
	}

	BOOL printMessage = [self postReceivedMessage:m withText:comment destinedFor:channel];

	if (printMessage && myself == NO)
	{
		if ([TPCPreferences showJoinLeave] == NO) {
			printMessage = NO;
		} else if (channel.config.ignoreGeneralEventMessages) {
			printMessage = NO;
		} else {
			IRCAddressBookEntry *ignoreInfo = [self findAddressBookEntryForHostmask:m.senderHostmask];

			if (ignoreInfo) {
				printMessage = (ignoreInfo.ignoreGeneralEventMessages == NO);
			}
		}
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

			if (printMessage && myself == NO)
			{
				if ([TPCPreferences showJoinLeave] == NO) {
					printMessage = NO;
				} else if (channel.config.ignoreGeneralEventMessages) {
					printMessage = NO;
				} else if (ignoreInfo) {
					printMessage = (ignoreInfo.ignoreGeneralEventMessages == NO);
				}
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

	NSAssertReturn([m paramsCount] == 1);

	/* Print only messages target specific channels which means
	 the index of incoming data will be different */
	BOOL isPrintOnlyMessage = m.isPrintOnlyMessage;

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
				[self updateUserTrackingStatusForEntry:oldNicknameIgnoreInfo withMessage:m];
			}

			/* Update user tracking status for new nickname */
			IRCAddressBookEntry *newNicknameIgnoreInfo = [self findUserTrackingAddressBookEntryForNickname:newNickname];

			if (newNicknameIgnoreInfo) {
				[self updateUserTrackingStatusForEntry:newNicknameIgnoreInfo withMessage:m];
			}
		}

		/* Inform style of change */
		[self postEventToViewController:@"nicknameChanged"];
	}

	/* Inform observers */
	[RZNotificationCenter() postNotificationName:IRCClientUserNicknameChangedNotification
										  object:self
										userInfo:@{
											@"oldNickname" : oldNickname,
											@"newNickname" : newNickname
										}];

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

			if (printMessage && myself == NO)
			{
				if ([TPCPreferences showJoinLeave] == NO) {
					printMessage = NO;
				} else if (channel.config.ignoreGeneralEventMessages) {
					printMessage = NO;
				} else if (oldNicknameIgnoreInfo) {
					printMessage = (oldNicknameIgnoreInfo.ignoreGeneralEventMessages == NO);
				}
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
		printMessage = ([TPCPreferences showJoinLeave] && channel.config.ignoreGeneralEventMessages == NO);
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

	NSString *channelName = [m paramAt:1];

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
		__weak IRCClient *weakSelf = self;

		self.disconnectCallback = ^{
			[weakSelf cancelReconnect];
		};
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

		batchType = thisBatchMessage.batchType;

		/* Process queued entries for this batch message. */
		/* The method used for processing queued entries will 
		 also remove it from queue once completed. */
		[self recursivelyProcessBatchMessage:thisBatchMessage];

		/* Set vendor specific flags based on BATCH command values */
		if ([batchType isEqualToString:@"znc.in/playback"]) {
			self.zncBouncerIsPlayingBackHistory = NO;
		} else if ([batchType isEqualToString:@"znc.in/tlsinfo"]) {
			self.zncBouncerIsSendingCertificateInfo = NO;
		}
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
#pragma mark BATCH Command

- (id)queuedBatchMessageWithToken:(NSString *)batchToken
{
	return [self.batchMessages queuedEntryWithBatchToken:batchToken];
}

- (BOOL)filterBatchCommandIncomingData:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

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

	if (batchMessage.batchIsOpen) {
		return;
	}

	NSArray *queuedEntries = batchMessage.queuedEntries;

	for (id queuedEntry in queuedEntries) {
		if ([queuedEntry isKindOfClass:[IRCMessage class]]) {
			[self processIncomingMessage:queuedEntry];
		} else if ([queuedEntry isKindOfClass:[IRCMessageBatchMessage class]]) {
			[self recursivelyProcessBatchMessage:queuedEntry depth:(recursionDepth + 1)];
		}
	}

	if (recursionDepth == 0) {
		[self.batchMessages dequeueEntry:batchMessage];
	}
}

#pragma mark -
#pragma mark Server Capability

- (void)enableCapability:(ClientIRCv3SupportedCapability)capability
{
	if ([self isCapabilityEnabled:capability] == NO) {
		self->_capabilities |= capability;
	}
}

- (void)disableCapability:(ClientIRCv3SupportedCapability)capability
{
	if ([self isCapabilityEnabled:capability]) {
		self->_capabilities &= ~capability;
	}
}

- (BOOL)isCapabilityEnabled:(ClientIRCv3SupportedCapability)capability
{
	return ((self->_capabilities & capability) == capability);
}

- (void)enablePendingCapability:(ClientIRCv3SupportedCapability)capability
{
	@synchronized (self.capabilitiesPending) {
		[self.capabilitiesPending addObjectWithoutDuplication:@(capability)];
	}
}

- (void)disablePendingCapability:(ClientIRCv3SupportedCapability)capability
{
	@synchronized (self.capabilitiesPending) {
		[self.capabilitiesPending removeObject:@(capability)];
	}
}

- (BOOL)isPendingCapabilityEnabled:(ClientIRCv3SupportedCapability)capability
{
	@synchronized (self.capabilitiesPending) {
		return [self.capabilitiesPending containsObject:@(capability)];
	}
}

- (nullable NSString *)capabilityStringValue:(ClientIRCv3SupportedCapability)capability
{
	NSString *stringValue = nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch"

	switch (capability) {
		case ClientIRCv3SupportedCapabilityAwayNotify:
		{
			stringValue = @"away-notify";

			break;
		}
		case ClientIRCv3SupportedCapabilityBatch:
		{
			stringValue = @"batch";

			break;
		}
		case ClientIRCv3SupportedCapabilityChangeHost:
		{
			stringValue = @"chghost";

			break;
		}
		case ClientIRCv3SupportedCapabilityEchoMessage:
		{
			stringValue = @"echo-message";

			break;
		}
		case ClientIRCv3SupportedCapabilityIdentifyCTCP:
		{
			stringValue = @"identify-ctcp";

			break;
		}
		case ClientIRCv3SupportedCapabilityIdentifyMsg:
		{
			stringValue = @"identify-msg";

			break;
		}
		case ClientIRCv3SupportedCapabilityMultiPrefix:
		{
			stringValue = @"multi-prefix";

			break;
		}
		case ClientIRCv3SupportedCapabilityPlayback:
		{
			stringValue = @"playback";

			break;
		}
		case ClientIRCv3SupportedCapabilitySASLExternal:
		case ClientIRCv3SupportedCapabilitySASLPlainText:
		case ClientIRCv3SupportedCapabilitySASLGeneric:
		case ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL:
		case ClientIRCv3SupportedCapabilityIsInSASLNegotiation:
		{
			stringValue = @"sasl";

			break;
		}
		case ClientIRCv3SupportedCapabilityServerTime:
		{
			stringValue = @"server-time";

			break;
		}
		case ClientIRCv3SupportedCapabilityUserhostInNames:
		{
			stringValue = @"userhost-in-names";

			break;
		}
		case ClientIRCv3SupportedCapabilityMonitorCommand:
		{
			stringValue = @"monitor-command";

			break;
		}
		case ClientIRCv3SupportedCapabilityWatchCommand:
		{
			stringValue = @"watch-command";

			break;
		}
		case ClientIRCv3SupportedCapabilityPlanioPlayback:
		{
			stringValue = @"plan.io/playback";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCCertInfoModule:
		{
			stringValue = @"znc.in/tlsinfo";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCPlaybackModule:
		{
			stringValue = @"znc.in/playback";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCSelfMessage:
		{
			stringValue = @"znc.in/self-message";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCServerTime:
		{
			stringValue = @"znc.in/server-time";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCServerTimeISO:
		{
			stringValue = @"znc.in/server-time-iso";

			break;
		}
	}

#pragma clang diagnostic pop

	return stringValue;
}

- (ClientIRCv3SupportedCapability)capabilityFromStringValue:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	if ([capabilityString isEqualToStringIgnoringCase:@"away-notify"]) {
		return ClientIRCv3SupportedCapabilityAwayNotify;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"batch"]) {
		return ClientIRCv3SupportedCapabilityBatch;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"chghost"]) {
		return ClientIRCv3SupportedCapabilityChangeHost;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"echo-message"]) {
		return ClientIRCv3SupportedCapabilityEchoMessage;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"multi-prefix"]) {
		return ClientIRCv3SupportedCapabilityMultiPrefix;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"identify-msg"]) {
		return ClientIRCv3SupportedCapabilityIdentifyMsg;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"identify-ctcp"]) {
		return ClientIRCv3SupportedCapabilityIdentifyCTCP;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"sasl"]) {
		return ClientIRCv3SupportedCapabilitySASLGeneric;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"server-time"]) {
		return ClientIRCv3SupportedCapabilityServerTime;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"userhost-in-names"]) {
		return ClientIRCv3SupportedCapabilityUserhostInNames;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"plan.io/playback"]) {
		return ClientIRCv3SupportedCapabilityPlanioPlayback;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/playback"]) {
		return ClientIRCv3SupportedCapabilityZNCPlaybackModule;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/self-message"]) {
		return ClientIRCv3SupportedCapabilityZNCSelfMessage;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time"]) {
		return ClientIRCv3SupportedCapabilityZNCServerTime;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time-iso"]) {
		return ClientIRCv3SupportedCapabilityZNCServerTimeISO;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/tlsinfo"]) {
		return ClientIRCv3SupportedCapabilityZNCCertInfoModule;
	}

	return 0;
}

- (NSString *)enabledCapabilitiesStringValue
{
	NSMutableArray *enabledCapabilities = [NSMutableArray array];

	void (^appendValue)(ClientIRCv3SupportedCapability) = ^(ClientIRCv3SupportedCapability capability) {
		if ([self isCapabilityEnabled:capability] == NO) {
			return;
		}

		NSString *stringValue = [self capabilityStringValue:capability];

		if (stringValue) {
			[enabledCapabilities addObject:stringValue];
		}
	};

	appendValue(ClientIRCv3SupportedCapabilityAwayNotify);
	appendValue(ClientIRCv3SupportedCapabilityBatch);
	appendValue(ClientIRCv3SupportedCapabilityChangeHost);
	appendValue(ClientIRCv3SupportedCapabilityEchoMessage);
	appendValue(ClientIRCv3SupportedCapabilityIdentifyCTCP);
	appendValue(ClientIRCv3SupportedCapabilityIdentifyMsg);
	appendValue(ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL);
	appendValue(ClientIRCv3SupportedCapabilityMultiPrefix);
	appendValue(ClientIRCv3SupportedCapabilityPlayback);
	appendValue(ClientIRCv3SupportedCapabilityServerTime);
	appendValue(ClientIRCv3SupportedCapabilityUserhostInNames);
	appendValue(ClientIRCv3SupportedCapabilityZNCCertInfoModule);
	appendValue(ClientIRCv3SupportedCapabilityZNCPlaybackModule);
	appendValue(ClientIRCv3SupportedCapabilityZNCSelfMessage);

	NSString *stringValue = [enabledCapabilities componentsJoinedByString:@", "];

	return stringValue;
}

- (void)sendNextCapability
{
	if (self.capabilityNegotiationIsPaused) {
		return;
	}

	@synchronized (self.capabilitiesPending) {
		/* -CapabilitiesPending can contain values that are used internally for state traking 
		 and should never meet the socket. To workaround this as best we can, we scan the 
		 array for the first capability that is acceptable for negotiation. */
		NSUInteger nextCapabilityIndex =
		[self.capabilitiesPending indexOfObjectPassingTest:^BOOL(NSNumber *capabilityPending, NSUInteger index, BOOL *stop) {
			ClientIRCv3SupportedCapability capability = capabilityPending.unsignedIntegerValue;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"

			return
			(capability == ClientIRCv3SupportedCapabilityAwayNotify				||
			 capability == ClientIRCv3SupportedCapabilityBatch					||
			 capability == ClientIRCv3SupportedCapabilityChangeHost				||
			 capability == ClientIRCv3SupportedCapabilityEchoMessage			||
			 capability == ClientIRCv3SupportedCapabilityIdentifyCTCP			||
			 capability == ClientIRCv3SupportedCapabilityIdentifyMsg			||
			 capability == ClientIRCv3SupportedCapabilityMultiPrefix			||
			 capability == ClientIRCv3SupportedCapabilitySASLGeneric			||
			 capability == ClientIRCv3SupportedCapabilityServerTime				||
			 capability == ClientIRCv3SupportedCapabilityUserhostInNames		||
			 capability == ClientIRCv3SupportedCapabilityPlanioPlayback			||
			 capability == ClientIRCv3SupportedCapabilityZNCCertInfoModule		||
			 capability == ClientIRCv3SupportedCapabilityZNCPlaybackModule		||
			 capability == ClientIRCv3SupportedCapabilityZNCSelfMessage			||
			 capability == ClientIRCv3SupportedCapabilityZNCServerTime			||
			 capability == ClientIRCv3SupportedCapabilityZNCServerTimeISO);

#pragma clang diagnostic pop
		}];

		if (nextCapabilityIndex == NSNotFound) {
			[self sendCapability:@"END" data:nil];

			return;
		}

		ClientIRCv3SupportedCapability capability =
		[self.capabilitiesPending unsignedIntegerAtIndex:nextCapabilityIndex];

		[self.capabilitiesPending removeObjectAtIndex:nextCapabilityIndex];

		NSString *stringValue = [self capabilityStringValue:capability];

		[self sendCapability:@"REQ" data:stringValue];
	}
}

- (void)pauseCapabilityNegotiation
{
	self.capabilityNegotiationIsPaused = YES;
}

- (void)resumeCapabilityNegotiation
{
	self.capabilityNegotiationIsPaused = NO;

	[self sendNextCapability];
}

- (BOOL)isCapabilitySupported:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	// Information about several of these supported CAP
	// extensions can be found at: http://ircv3.atheme.org

	if ([capabilityString isEqualToStringIgnoringCase:@"echo-message"]) {
		return [TPCPreferences enableEchoMessageCapability];
	}

	return
	([capabilityString isEqualToStringIgnoringCase:@"away-notify"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"batch"]					||
	 [capabilityString isEqualToStringIgnoringCase:@"chghost"]					||
	 [capabilityString isEqualToStringIgnoringCase:@"identify-ctcp"]			||
	 [capabilityString isEqualToStringIgnoringCase:@"identify-msg"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"multi-prefix"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"sasl"]						||
	 [capabilityString isEqualToStringIgnoringCase:@"server-time"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"userhost-in-names"]		||
	 [capabilityString isEqualToStringIgnoringCase:@"plan.io/playback"]			||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/playback"]			||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/self-message"]		||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time"]		||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time-iso"]	||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/tlsinfo"]);
}

- (void)toggleCapability:(NSString *)capabilityString enabled:(BOOL)enabled
{
	[self toggleCapability:capabilityString enabled:enabled isUpdateRequest:NO];
}

- (void)toggleCapability:(NSString *)capabilityString enabled:(BOOL)enabled isUpdateRequest:(BOOL)isUpdateRequest
{
	NSParameterAssert(capabilityString != nil);

	if ([capabilityString isEqualToStringIgnoringCase:@"sasl"]) {
		if (enabled) {
			if ([self sendSASLIdentificationRequest]) {
				[self pauseCapabilityNegotiation];
			}
		}

		return;
	}

	ClientIRCv3SupportedCapability capability = [self capabilityFromStringValue:capabilityString];

	if (capability == 0) {
		return;
	}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"

	if (capability == ClientIRCv3SupportedCapabilityZNCServerTime ||
		capability == ClientIRCv3SupportedCapabilityZNCServerTimeISO)
	{
		capability = ClientIRCv3SupportedCapabilityServerTime;
	}

	if (capability == ClientIRCv3SupportedCapabilityPlanioPlayback ||
		capability == ClientIRCv3SupportedCapabilityZNCPlaybackModule)
	{
		capability = ClientIRCv3SupportedCapabilityPlayback;
	}

#pragma clang diagnostic pop

	if (enabled) {
		[self enableCapability:capability];
	} else {
		[self disableCapability:capability];
	}
}

- (void)processPendingCapability:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	NSArray *components = [capabilityString componentsSeparatedByString:@"="];

	NSString *capability = capabilityString;

	NSArray<NSString *> *capabilityOptions = nil;

	if (components.count == 2) {
		capability = components[0];

		capabilityOptions = [components[1] componentsSeparatedByString:@","];
	}

	[self processPendingCapability:capability options:capabilityOptions];
}

- (void)processPendingCapability:(NSString *)capabilityString options:(nullable NSArray<NSString *> *)capabilityOptions
{
	NSParameterAssert(capabilityString != nil);

	if ([self isCapabilitySupported:capabilityString] == NO) {
		return;
	}

	if ([capabilityString isEqualToString:@"sasl"]) {
		[self processPendingCapabilityForSASL:capabilityOptions];

		return;
	}

	ClientIRCv3SupportedCapability capability = [self capabilityFromStringValue:capabilityString];

	[self enablePendingCapability:capability];
}

- (void)receiveCapabilityOrAuthenticationRequest:(IRCMessage *)m
{
	/* Implementation based off Colloquy's own. */
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	NSString *command = m.command;
	NSString *modifier = [m paramAt:0];
	NSString *subcommand = [m paramAt:1];
	NSString *actions = [m sequence:2];

	if ([command isEqualToStringIgnoringCase:@"CAP"])
	{
		if ([subcommand isEqualToStringIgnoringCase:@"LS"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self processPendingCapability:cap];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"ACK"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self toggleCapability:cap enabled:YES isUpdateRequest:NO];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"NAK"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self toggleCapability:cap enabled:NO isUpdateRequest:NO];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"NEW"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self processPendingCapability:cap];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"DEL"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self toggleCapability:cap enabled:NO isUpdateRequest:YES];
			}
		}

		[self sendNextCapability];
	}
	else if ([command isEqualToStringIgnoringCase:@"AUTHENTICATE"])
	{
		if ([modifier isEqualToString:@"+"]) {
			[self sendSASLIdentificationInformation];
		}
	}

	[self postReceivedMessage:m];
}

#pragma mark -
#pragma mark SASL Negotiation

- (void)processPendingCapabilityForSASL:(nullable NSArray<NSString *> *)capabilityOptions
{
	ClientIRCv3SupportedCapability identificationMechanism = 0;

	if (self.socket.isConnectedWithClientSideCertificate &&
		self.config.saslAuthenticationDisableExternalMechanism == NO)
	{
		if (capabilityOptions.count == 0 ||
			[capabilityOptions containsObjectIgnoringCase:@"EXTERNAL"])
		{
			identificationMechanism = ClientIRCv3SupportedCapabilitySASLExternal;

			[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLExternal];
		}
	}

	if (identificationMechanism == 0 &&
		self.config.nicknamePassword.length > 0)
	{
		if (capabilityOptions.count == 0 ||
			[capabilityOptions containsObjectIgnoringCase:@"PLAIN"])
		{
			identificationMechanism = ClientIRCv3SupportedCapabilitySASLPlainText;

			[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLPlainText];
		}
	}

	if (identificationMechanism != 0) {
		[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLGeneric];
	}
}

- (void)sendSASLIdentificationInformation
{
	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation] == NO) {
		return;
	}

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLPlainText])
	{
		NSString *authString = [NSString stringWithFormat:@"%@%C%@%C%@",
								 self.config.username, 0x00,
								 self.config.username, 0x00,
								 self.config.nicknamePassword];

		NSArray *authStrings = [authString base64EncodingWithLineLength:400];

		for (NSString *string in authStrings) {
			[self sendCapabilityAuthenticate:string];
		}

		if (authStrings.count == 0 || ((NSString *)authStrings.lastObject).length == 400) {
			[self sendCapabilityAuthenticate:@"+"];
		}
	}
	else if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLExternal])
	{
		[self sendCapabilityAuthenticate:@"+"];
	}
}

- (BOOL)sendSASLIdentificationRequest
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL]) {
		return NO;
	}

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation]) {
		return NO;
	}

	[self enablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLPlainText]) {
		[self sendCapabilityAuthenticate:@"PLAIN"];

		return YES;
	} else if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLExternal]) {
		[self sendCapabilityAuthenticate:@"EXTERNAL"];

		return YES;
	}

	return NO;
}

- (void)resetSASLNegotiation
{
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLGeneric];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLPlainText];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLExternal];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

	[self disableCapability:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL];
}

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
			[self performSelectorInCommonModes:@selector(performAutoJoin) withObject:nil afterDelay:3.0];
		} else {
			[self startAutojoinDelayedWarningTimer];
		}
	}

	/* We need time for the server to send its configuration */
	[self performSelectorInCommonModes:@selector(populateISONTrackedUsersList) withObject:nil afterDelay:10.0];
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
			NSAssertReturn([m paramsCount] >= 3);

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
			NSAssertReturn([m paramsCount] == 4);

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

				return;
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
			__weak IRCClient *weakSelf = self;

			self.disconnectCallback = ^{
				[weakSelf connect];
			};

			[self disconnect];

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
			NSAssertReturn(printMessage);

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
			NSAssertReturn(printMessage);

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
			NSAssertReturn([m paramsCount] > 1);

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
		case RPL_AWAY:
		{
			NSAssertReturn([m paramsCount] == 3);

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
			NSAssertReturn([m paramsCount] > 2);

			if (printMessage) {
				[self printReply:m inChannel:[mainWindow() selectedChannelOn:self]];
			}

			break;
		}
		case RPL_WHOISACTUALLY:
		{
			NSAssertReturn([m paramsCount] == 5);

			NSAssertReturn(printMessage);

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
			NSAssertReturn([m paramsCount] >= 6);

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
			NSAssertReturn([m paramsCount] == 4);

			NSAssertReturn(printMessage);

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
			NSAssertReturn([m paramsCount] == 5);

			NSAssertReturn(printMessage);

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
			NSAssertReturn([m paramsCount] == 3);

			NSAssertReturn(printMessage);

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
			NSAssertReturn([m paramsCount] == 4);

			NSAssertReturn(printMessage);

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
		case RPL_CHANNELMODEIS:
		{
			NSAssertReturn([m paramsCount] > 2);

			NSString *channelName = [m paramAt:1];

			NSString *modeString = [m sequence:2];

			if ([modeString isEqualToString:@"+"]) {
				return;
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
			NSAssertReturn([m paramsCount] == 3);

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
			NSAssertReturn([m paramsCount] == 4);

			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				break;
			}

			printMessage = [self postReceivedMessage:m withText:nil destinedFor:channel];

			if (printMessage == NO) {
				return;
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
			NSAssertReturn([m paramsCount] == 3);

			NSAssertReturn(printMessage);

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
		case RPL_ISON:
		{
			/* Present reply to the user if we have destination */
			BOOL visibleIsonRequest = self.requestedCommands.visibleIsonRequest;

			[self.requestedCommands recordIsonRequestClosed];

			if (visibleIsonRequest) {
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
			 treat the results as user tracking information. */
			NSString *onlineNicknamesString = m.sequence;

			NSArray *onlineNicknames = [onlineNicknamesString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

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
		case RPL_WHOREPLY:
		{
			NSAssertReturn([m paramsCount] > 6);

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

			/* Process reply */
			NSString *channelName = [m paramAt:1];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				break;
			}

			/* Example incoming data:
				<channel> <user> <host> <server> <nick> <H|G>[*][@|+] <hopcount> <real name>

				#freenode znc unaffiliated/namikaze kornbluth.freenode.net Namikaze G 0 Christian
				#freenode ~D unaffiliated/solprefixer kornbluth.freenode.net solprefixer H 0 solprefixer
			*/

			NSString *nickname = [m paramAt:5];
			NSString *username = [m paramAt:2];
			NSString *address = [m paramAt:3];
			NSString *flags = [m paramAt:6];
			NSString *realName = [m paramAt:7];

			BOOL isAway = NO;
			BOOL isIRCop = NO;

			// Field Syntax: <H|G>[*][@|+]
			// Strip G or H (away status).
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

			/* Parameter 7 includes the hop count and real name because it begins with a :
			 Therefore, we cut after the first space to get the real, real name value. */
			NSInteger realNameFirstSpace = [realName stringPosition:@" "];

			if (realNameFirstSpace > 0 && realNameFirstSpace < realName.length) {
				realName = [realName substringAfterIndex:realNameFirstSpace];
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
			userMutable.username = username;
			userMutable.address = address;

			userMutable.isAway = isAway;
			userMutable.isIRCop = isIRCop;

			userMutable.realName = realName;

			/* Insert the user into the client and return the final copy that was */
			BOOL userChanged = (user != nil && [user isEqual:userMutable] == NO);

			IRCUser *userAdded = nil;

			if (user == nil || userChanged) {
				userAdded = [self addUserAndReturn:userMutable];
			} else {
				userAdded = user;
			}

			/* Find the user associated with this channel  */
			IRCChannelUser *member = [user userAssociatedWithChannel:channel];

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
				
				BOOL resortMember = IRCopStatusChanged;

				BOOL replaceInAllChannels = (IRCopStatusChanged && [TPCPreferences memberListSortFavorsServerStaff]);

				if (resortMember) {
					[channel replaceMember:member
								withMember:member
									resort:resortMember
					  replaceInAllChannels:replaceInAllChannels];
				}
				else if (user.isAway != userAdded.isAway)
				{
					[mainWindow() updateDrawingForUserInUserList:userAdded];
				}
			}

			/* Update local cache of our hostmask */
			if ([self nicknameIsMyself:nickname]) {
				NSString *hostmask = [NSString stringWithFormat:@"%@!%@@%@", nickname, username, address];

				self.userHostmask = hostmask;
			}

			break;
		}
		case RPL_ENDOFWHO:
		{
			BOOL visibleWhoRequest = self.requestedCommands.visibleWhoRequest;

			[self.requestedCommands recordWhoRequestClosed];

			if (visibleWhoRequest && printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case RPL_NAMEREPLY:
		{
			NSAssertReturn([m paramsCount] > 3);

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
					/* If a user with this name already exists in the channel,
					 then we do not continue unless its us. We are added to the
					 channel when the JOIN is received, but we still need modes. */

					return;
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
			NSAssertReturn([m paramsCount] == 3);

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
			NSAssertReturn([m paramsCount] > 2);

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
			NSAssertReturn([m paramsCount] > 2);

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

			TDCChannelBanListSheet *listSheet = [windowController() windowFromWindowList:@"TDCChannelBanListSheet"];

			if (listSheet) {
				if (listSheet.contentAlreadyReceived) {
					listSheet.contentAlreadyReceived = NO;

					[listSheet clear];
				}

				[listSheet addEntry:entryMask setBy:entryAuthor creationDate:entryCreationDate];

				return;
			}

			if (printMessage == NO) {
				return;
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
			TDCChannelBanListSheet *listSheet = [windowController() windowFromWindowList:@"TDCChannelBanListSheet"];

			if (listSheet) {
				listSheet.contentAlreadyReceived = YES;

				break;
			}

			if (printMessage) {
				[self printReply:m];
			}

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
		case RPL_CHANNEL_URL:
		{
			NSAssertReturn([m paramsCount] == 3);

			NSAssertReturn(printMessage);

			NSString *channelName = [m paramAt:1];
			NSString *website = [m paramAt:2];

			IRCChannel *channel = [self findChannel:channelName];

			if (channel == nil) {
				return;
			}

			[self print:TXTLS(@"IRC[8tq-g6]", website)
					 by:nil
			  inChannel:channel
				 asType:TVCLogLineTypeWebsite
				command:m.command
			 receivedAt:m.receivedAt];

			break;
		}
		case RPL_WATCHSTAT:
		case RPL_WATCHLIST:
		{
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case RPL_REAWAY:
		case RPL_GONEAWAY:
		case RPL_NOTAWAY:
		{
			NSAssertReturn([m paramsCount] > 4);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			/* Process reply */
			NSString *nickname = [m paramAt:1];

			IRCAddressBookEntry *addressBookEntry =	[self findUserTrackingAddressBookEntryForNickname:nickname];

			if (addressBookEntry == nil) {
				break;
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
				default:
				{
					break;
				}
			} // switch()

			break;
		}
		case RPL_LOGON:
		case RPL_LOGOFF:
		{
			NSAssertReturn([m paramsCount] > 4);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			 /* Process reply */
			NSString *nickname = [m paramAt:1];

			IRCAddressBookEntry *addressBookEntry =	[self findUserTrackingAddressBookEntryForNickname:nickname];

			if (addressBookEntry == nil) {
				break;
			}

			switch (numeric) {
				case RPL_LOGON: // logged online
				{
					[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];

					break;
				}
				case RPL_LOGOFF: // logged offline
				{
					[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];

					break;
				}
				default:
				{
					break;
				}
			} // switch()

			break;
		}
		case RPL_NOWON:
		case RPL_NOWOFF:
		{
			NSAssertReturn([m paramsCount] > 4);

			/* Present reply to the user if we have destination */
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			/* Process reply */
			NSString *nickname = [m paramAt:1];

			IRCAddressBookEntry *addressBookEntry =	[self findUserTrackingAddressBookEntryForNickname:nickname];

			if (addressBookEntry == nil) {
				break;
			}

			switch (numeric) {
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

			break;
		}
		case RPL_WATCHOFF:
		{
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case ERR_TOOMANYWATCH:
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
//		case RPL_CLEARWATCH: /* Not implemented by any IRCd */
		case RPL_ENDOFWATCHLIST:
		{
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case RPL_MONLIST:
		{
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
			}

			break;
		}
		case RPL_MONONLINE:
		case RPL_MONOFFLINE:
		{
			NSAssertReturn([m paramsCount] == 2);

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

				IRCAddressBookEntry *addressBookEntry =	[self findUserTrackingAddressBookEntryForNickname:nickname];

				if (addressBookEntry == nil) {
					continue;
				}

				if (numeric == RPL_MONONLINE) { // logged online
					[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];
				} else {
					[self statusOfTrackedNickname:nickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];
				}
			}

			break;
		}
		case ERR_MONLISTFULL:
		{
			/* See ERR_TOOMANYWATCH for reason we always print this. */
			if (printMessage) {
				[self printErrorReply:m];
			}

			break;
		}
		case RPL_ENDOFMONLIST:
		{
			if (printMessage) {
				[self printReplyToHiddenCommandResponsesQuery:m];
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
			NSAssertReturn([m paramsCount] == 3);

			NSAssertReturn(printMessage);

			NSString *nickname = [m paramAt:1];

			[self printDebugInformation:TXTLS(@"IRC[11i-ev]", nickname)];

			break;
		}
		case RPL_UMODEGMSG:
		{
			NSAssertReturn([m paramsCount] == 4);

			NSAssertReturn(printMessage);

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
		case RPL_LOGGEDIN:
		{
			NSAssertReturn([m paramsCount] == 4);

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
			NSAssertReturn([m paramsCount] == 3);

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
		case RPL_SASLSUCCESS:
		case ERR_NICKLOCKED:
		case ERR_SASLFAIL:
		case ERR_SASLTOOLONG:
		case ERR_SASLABORTED:
		case ERR_SASLALREADY:
		case RPL_SASLMECHS: /* Treated as error */
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
			/* We will handle custom WHOIS responses here because there
			 are so many that it is impossible to cover them all above. */
			/* For those that we don't handle, give a plugin a chance first. */
			NSString *numericString = [NSString stringWithUnsignedInteger:numeric];

			if ([sharedPluginManager().supportedServerInputCommands containsObject:numericString]) {
				break;
			}

			if (printMessage) {
				/* Output custom WHOIS response to proper target */
				if (self.inWhoisResponse && m.paramsCount > 2) {
					[self printUnknownReply:m inChannel:[mainWindow() selectedChannelOn:self]];

					break;
				}

				/* Output unknown result */
				[self printUnknownReply:m];
			}

			break;
		}
	} // switch()
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

#pragma mark -
#pragma mark Autojoin

- (void)startAutojoinTimer
{
	if (self.autojoinTimer.timerIsActive) {
		return;
	}

	NSTimeInterval interval = [TPCPreferences autojoinDelayAfterIdentification];

	if (CGFloatAreEqual(interval, 0.0)) {
		[self onAutojoinTimer];

		return;
	}

	[self.autojoinTimer start:interval onRepeat:NO];
}

- (void)stopAutojoinTimer
{
	if (self.autojoinTimer.timerIsActive == NO) {
		return;
	}

	[self.autojoinTimer stop];
}

- (void)onAutojoinTimer
{
	[self startAutojoinNextJoinTimer];
}

- (void)startAutojoinDelayedWarningTimer
{
	if (self.autojoinDelayedWarningTimer.timerIsActive) {
		return;
	}

	[self.autojoinDelayedWarningTimer start:_autojoinDelayedWarningInterval onRepeat:YES];
}

- (void)stopAutojoinDelayedWarningTimer
{
	if (self.autojoinDelayedWarningTimer.timerIsActive == NO) {
		return;
	}

	[self.autojoinDelayedWarningTimer stop];
}

- (void)onAutojoinDelayedWarningTimer
{
	if (self.isLoggedIn == NO ||
		self.config.hideAutojoinDelayedWarnings ||
		self.autojoinDelayedWarningCount >= _autojoinDelayedWarningMaxCount)
	{
		[self stopAutojoinDelayedWarningTimer];

		return;
	}

	self.autojoinDelayedWarningCount += 1;

	/* This message is posted to the server console and the 
	 front most channel if it is on this server. */
	NSString *text = TXTLS(@"IRC[r5h-fj]");

	[self printDebugInformationToConsole:text];

	IRCChannel *c = [mainWindow() selectedChannelOn:self];

	if (c != nil) {
		[self printDebugInformation:text inChannel:c];
	}
}

- (void)startAutojoinNextJoinTimer
{
	if (self.autojoinNextJoinTimer.timerIsActive) {
		return;
	}

	NSTimeInterval interval = [TPCPreferences autojoinDelayBetweenChannelJoins];

	[self.autojoinNextJoinTimer start:interval onRepeat:YES];

	/* Fake first event */
	[self onAutojoinNextJoinTimer];
}

- (void)stopAutojoinNextJoinTimer
{
	if (self.autojoinNextJoinTimer.timerIsActive == NO) {
		return;
	}

	[self.autojoinNextJoinTimer stop];

	self.channelsToAutojoin = nil;
}

- (void)onAutojoinNextJoinTimer
{
	[self autojoinNextChannel];
}

- (void)autojoinNextChannel
{
	if (self.isAutojoining == NO) {
		return;
	}

	@synchronized (self.channelsToAutojoin) {
		NSUInteger numberOfChannelsRemaining = self.channelsToAutojoin.count;

		NSUInteger maximumNumberOfJoins = [TPCPreferences autojoinMaximumChannelJoins];

		NSRange arrayRange;

		BOOL endOfArray = (numberOfChannelsRemaining <= maximumNumberOfJoins);

		if (endOfArray == NO) {
			arrayRange = NSMakeRange(0, maximumNumberOfJoins);
		} else {
			arrayRange = NSMakeRange(0, numberOfChannelsRemaining);
		}

		NSArray *channelsToJoin = [self.channelsToAutojoin subarrayWithRange:arrayRange];

		[self autojoinChannels:channelsToJoin];

		if (endOfArray == NO) {
			[self.channelsToAutojoin removeObjectsInRange:arrayRange];
		} else {
			self.isAutojoining = NO;

			self.isAutojoined = YES;

			[self stopAutojoinNextJoinTimer];
		}
	}
}

- (void)autojoinChannels:(NSArray<IRCChannel *> *)channels
{
	NSParameterAssert(channels != nil);

	[self joinChannels:channels];
}

- (void)performAutoJoin
{
	[self performAutoJoinInitiatedByUser:NO];
}

- (void)performAutoJoinInitiatedByUser:(BOOL)initiatedByUser
{
	if (self.isAutojoining) {
		return;
	}

	[self stopAutojoinDelayedWarningTimer];

	if (initiatedByUser == NO) {
		/* Ignore previous invocations of this method */
		if (self.isAutojoined) {
			return;
		}

		/* Ignore autojoin based on ZNC preferences */
		if (self.isConnectedToZNC && self.config.zncIgnoreConfiguredAutojoin) {
			self.isAutojoined = YES;

			return;
		}

		/* Do nothing unless certain conditions are met */
		if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL] == NO) {
			if (self.config.autojoinWaitsForNickServ) {
				if (self.serverHasNickServ && self.userIsIdentifiedWithNickServ == NO) {
					return;
				}
			}
		}
	}

	NSMutableArray<IRCChannel *> *channelsToAutojoin = [NSMutableArray array];

	for (IRCChannel *c in self.channelList) {
		if (c.isChannel && c.isActive == NO) {
			if (c.config.autoJoin) {
				[channelsToAutojoin addObject:c];
			}
		}
	}

	if (channelsToAutojoin.count == 0) {
		self.isAutojoining = YES;

		return;
	}

	self.isAutojoining = YES;

	@synchronized (self.channelsToAutojoin) {
		[channelsToAutojoin shuffle];

		self.channelsToAutojoin = channelsToAutojoin;
	}

	[self startAutojoinTimer];
}

#pragma mark -
#pragma mark Post Events

- (void)postEventToViewController:(NSString *)eventToken
{
	if (themeSettings().js_postHandleEventNotifications == NO) {
		return; // Cancel operation...
	}

	[self postEventToViewController:eventToken forItem:self];

	for (IRCChannel *channel in self.channelList) {
		[self postEventToViewController:eventToken forItem:channel];
	}
}

- (void)postEventToViewController:(NSString *)eventToken forChannel:(IRCChannel *)channel
{
	if (themeSettings().js_postHandleEventNotifications == NO) {
		return; // Cancel operation...
	}

	[self postEventToViewController:eventToken forItem:channel];
}

- (void)postEventToViewController:(NSString *)eventToken forItem:(IRCTreeItem *)item
{
	NSParameterAssert(eventToken != nil);
	NSParameterAssert(item != nil);

	if (self.isTerminating) {
		return;
	}

	[item.viewController evaluateFunction:@"Textual.handleEvent" withArguments:@[eventToken] onQueue:NO];
}

#pragma mark -
#pragma mark Timers

- (void)startPongTimer
{
	if (self.pongTimer.timerIsActive) {
		return;
	}

	[self.pongTimer start:_pongCheckInterval onRepeat:YES];
}

- (void)stopPongTimer
{
	if (self.pongTimer.timerIsActive == NO) {
		return;
	}

	[self.pongTimer stop];
}

- (void)onPongTimer
{
	if (self.isLoggedIn == NO) {
		[self stopPongTimer];

		return;
	}

	/* Instead of stopping and starting the timer every time this changes, it
	 it is easier to check if we should do it every timer iteration.
	 The ability to disable this is important on PSYBNC connection because
	 PSYBNC doesn't respond to PING commands. There are other irc daemons that
	 don't reply to PING either and they should all be shot. */
	NSTimeInterval timeSpent = [NSDate timeIntervalSinceNow:self.lastMessageReceived];

	if (timeSpent >= _timeoutInterval)
	{
		/* If EOF Received when we were not expecting it, then timeout regardless
		 of user preference once our timeout interval is reached. */
		if (self.socket.EOFReceived || self.config.performDisconnectOnPongTimer) {
			[self printDebugInformation:TXTLS(@"IRC[bps-la]", (timeSpent / 60.0)) inChannel:nil];

			XRPerformBlockSynchronouslyOnMainQueue(^{
				[self disconnect];
			});

			return;
		}

		if (self.timeoutWarningShownToUser == NO) {
			self.timeoutWarningShownToUser = YES;

			[self printDebugInformation:TXTLS(@"IRC[gzo-54]", (timeSpent / 60.0)) inChannel:nil];
		}
	}
	else if (timeSpent >= _pingInterval)
	{
		if (self.config.performPongTimer == NO) {
			return;
		}

		[self sendPing:self.serverAddress];
	}
}

- (void)startReconnectTimer
{
	if ((self.reconnectEnabledBecauseOfSleepMode		&& self.config.autoSleepModeDisconnect == NO) ||
		(self.reconnectEnabledBecauseOfSleepMode == NO  && self.config.autoReconnect == NO))
	{
		return;
	}

	if (self.reconnectTimer.timerIsActive) {
		return;
	}

	[self.reconnectTimer start:_reconnectInterval onRepeat:YES];
}

- (void)stopReconnectTimer
{
	if (self.reconnectTimer.timerIsActive == NO) {
		return;
	}

	[self.reconnectTimer stop];
}

- (void)onReconnectTimer
{
	if (self.isConnecting || self.isConnected) {
		return;
	}

	[self connect:IRCClientConnectModeReconnect];
}

- (void)startRetryTimer
{
	if (self.retryTimer.timerIsActive) {
		return;
	}

	[self.retryTimer start:_retryInterval];
}

- (void)stopRetryTimer
{
	if (self.retryTimer.timerIsActive == NO) {
		return;
	}

	[self.retryTimer stop];
}

- (void)onRetryTimer
{
	if (self.isConnected == NO) {
		return;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		__weak IRCClient *weakSelf = self;

		self.disconnectCallback = ^{
			[weakSelf connect:IRCClientConnectModeRetry];
		};

		[self disconnect];
	});
}

#pragma mark -
#pragma mark Requested Commands

- (void)removeRequestedCommands
{
	[self.requestedCommands removeCommands];
}

- (void)createHiddenCommandResponses
{
	if (self.isTerminating) {
		return;
	}

	if (self.rawDataLogQuery != nil) {
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

#pragma mark -
#pragma mark Plugins and Scripts

- (void)outputDescriptionForError:(NSError *)error forTextualCmdScriptAtPath:(NSString *)path inputString:(NSString *)inputString
{
	NSString *filename = path.lastPathComponent;

	NSString *errorDescription = error.userInfo[NSAppleScriptErrorMessage];

	if (errorDescription == nil) {
		errorDescription = error.userInfo[NSAppleScriptErrorBriefMessage];
	}

	if (errorDescription == nil) {
		errorDescription = error.localizedFailureReason;
	}

	if (errorDescription == nil) {
		errorDescription = error.localizedDescription;
	}

	if (inputString.length == 0) {
		inputString = @"(no input)";
	}

	[self printDebugInformation:TXTLS(@"IRC[2mc-h0]", filename, inputString, errorDescription)];

	LogToConsoleError("%{public}@", TXTLS(@"IRC[ax0-mt]", errorDescription));
}

- (void)sendTextualCmdScriptResult:(nullable NSString *)resultString toChannel:(nullable NSString *)channel
{
	/* Scripts that return nothing, a non-string AppleScript result,
	 or output that is not valid UTF-8 have no output to send. */
	resultString = resultString.trim;

	if (resultString.length == 0) {
		return;
	}

	IRCTreeItem *destination = nil;

	if (channel == nil) {
		destination = self;
	} else {
		destination = [self findChannel:channel];
	}

	if (destination == nil) {
		LogToConsoleFault("A script returned a result but its destination no longer exists");

		return;
	}

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self inputText:resultString destination:destination];
	});
}

- (void)executeTextualCmdScriptInContext:(NSDictionary<NSString *, NSString *> *)context
{
	XRPerformBlockAsynchronouslyOnQueue([THOPluginDispatcher dispatchQueue], ^{
		[self _executeTextualCmdScriptInContext:context];
	});
}

- (void)_executeTextualCmdScriptInContext:(NSDictionary<NSString *, NSString *> *)context
{
	NSParameterAssert(context != nil);

	NSString *inputString = context[@"inputString"];

	NSString *path = context[@"path"];

	NSString *targetChannel = context[@"targetChannel"];

	NSParameterAssert(path != nil);

	NSURL *pathURL = [NSURL fileURLWithPath:path];

	/* Is it AppleScript? */
	if ([path hasSuffix:TPCResourceManagerScriptDocumentTypeExtension]) {
		BOOL isBuiltinScript = [path hasPrefix:[TPCPathInfo applicationResources]];

		/* /////////////////////////////////////////////////////// */
		/* Event Descriptor */
		/* /////////////////////////////////////////////////////// */

		NSAppleEventDescriptor *firstParameter = [NSAppleEventDescriptor descriptorWithString:inputString];
		NSAppleEventDescriptor *secondParameter = [NSAppleEventDescriptor descriptorWithString:targetChannel];

		NSAppleEventDescriptor *parameters = [NSAppleEventDescriptor listDescriptor];

		[parameters insertDescriptor:firstParameter atIndex:1];
		[parameters insertDescriptor:secondParameter atIndex:2];

		ProcessSerialNumber process = { 0, kCurrentProcess };

		NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber
																						bytes:&process
																					   length:sizeof(ProcessSerialNumber)];

		NSAppleEventDescriptor *handler = [NSAppleEventDescriptor descriptorWithString:@"textualcmd"];

		NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
																				 eventID:kASSubroutineEvent
																		targetDescriptor:target
																				returnID:kAutoGenerateReturnID
																		   transactionID:kAnyTransactionID];

		[event setParamDescriptor:handler forKeyword:keyASSubroutineName];

		[event setParamDescriptor:parameters forKeyword:keyDirectObject];

		/* /////////////////////////////////////////////////////// */
		/* Execute Event */
		/* /////////////////////////////////////////////////////// */
		/* NSUserAppleScriptTask expects the script to be in the Application Scripts folder 
		 which means if we want to execute scripts in the app's Resources folder, we use a
		 regular call to NSAppleScript. It's pretty safe to say that scripts we make ourselves
		 wont produce errors which means the logic for handling errors is ignored for scripts
		 that are performed in the Resources folder. */

		if (isBuiltinScript)
		{
			NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:pathURL error:NULL];

			if (appleScript == nil) {
				return;
			}

			NSAppleEventDescriptor *result = [appleScript executeAppleEvent:event error:NULL];

			if (result == nil) {
				return;
			}

			[self sendTextualCmdScriptResult:result.stringValue toChannel:targetChannel];
		}
		else // isBuiltinScript
		{
			NSError *appleScriptError = nil;

			NSUserAppleScriptTask *appleScript = [[NSUserAppleScriptTask alloc] initWithURL:pathURL error:&appleScriptError];

			if (appleScript == nil) {
				[self outputDescriptionForError:appleScriptError forTextualCmdScriptAtPath:path inputString:inputString];

				return;
			}

			[appleScript executeWithAppleEvent:event
							 completionHandler:^(NSAppleEventDescriptor *result, NSError *error)
			 {
				 if (result == nil) {
					 [self outputDescriptionForError:error forTextualCmdScriptAtPath:path inputString:inputString];
				 } else {
					 [self sendTextualCmdScriptResult:result.stringValue toChannel:targetChannel];
				 }
			 }];
		}

		return;
	}

	/* /////////////////////////////////////////////////////// */
	/* Execute Shell Script */
	/* /////////////////////////////////////////////////////// */

	/* Build list of arguments. */
	NSMutableArray *taskArguments = [NSMutableArray array];

	if (targetChannel) {
		[taskArguments addObject:targetChannel];
	} else {
		[taskArguments addObject:@""];
	}

	NSArray *inputStringComponents = [inputString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	[taskArguments addObjectsFromArray:inputStringComponents];

	/* Create task object */
	NSError *taskError = nil;

	NSUserUnixTask *task = [[NSUserUnixTask alloc] initWithURL:pathURL error:&taskError];

	if (task == nil) {
		[self outputDescriptionForError:taskError forTextualCmdScriptAtPath:path inputString:inputString];

		return;
	}

	/* Prepare pipe */
	NSPipe *standardOutputPipe = [NSPipe pipe];

	NSFileHandle *readingPipe = standardOutputPipe.fileHandleForReading;
	NSFileHandle *writingPipe = standardOutputPipe.fileHandleForWriting;

	task.standardOutput = writingPipe;

	/* Try performing task */
	[task executeWithArguments:taskArguments completionHandler:^(NSError *error) {
		if (error) {
			[self outputDescriptionForError:error forTextualCmdScriptAtPath:path inputString:inputString];

			return;
		}

		NSData *result = [readingPipe readDataToEndOfFile];

		NSString *resultString = [NSString stringWithData:result encoding:NSUTF8StringEncoding];

		[self sendTextualCmdScriptResult:resultString toChannel:targetChannel];
	}];
}

- (void)processBundlesUserMessage:(NSString *)message command:(NSString *)command
{
	NSParameterAssert(message != nil);

	[THOPluginDispatcher userInputCommandInvokedOnClient:self commandString:command messageString:message];
}

- (void)processBundlesServerMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	[THOPluginDispatcher didReceiveServerInput:message onClient:self];
}

- (BOOL)postReceivedMessage:(IRCMessage *)referenceMessage
{
	NSParameterAssert(referenceMessage != nil);

	return [self postReceivedMessage:referenceMessage
							withText:referenceMessage.sequence
						 destinedFor:nil];
}

- (BOOL)postReceivedMessage:(IRCMessage *)referenceMessage withText:(nullable NSString *)text destinedFor:(nullable IRCChannel *)textDestination
{
	NSParameterAssert(referenceMessage != nil);

	return [self postReceivedCommand:referenceMessage.command
							withText:text
						 destinedFor:textDestination
					referenceMessage:referenceMessage];
}

- (BOOL)postReceivedCommand:(NSString *)command withText:(nullable NSString *)text destinedFor:(nullable IRCChannel *)textDestination referenceMessage:(IRCMessage *)referenceMessage
{
	NSParameterAssert(command != nil);
	NSParameterAssert(referenceMessage != nil);

	return [THOPluginDispatcher receivedCommand:command
									   withText:text
									 authoredBy:referenceMessage.sender
									destinedFor:textDestination
									   onClient:self
									 receivedAt:referenceMessage.receivedAt
							   referenceMessage:referenceMessage];
}

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
	 are used too (port 6667 if none was given). Nothing else from
	 the current server configuration is read if there is a
	 temporary server. */
	NSString *serverAddress = nil;

	uint16_t serverPort = IRCConnectionDefaultServerPort;

	BOOL connectionPrefersSecuredConnection = NO;

	if (self.temporaryServerAddressOverride) {
		serverAddress = self.temporaryServerAddressOverride;

		if (self.temporaryServerPortOverride > 0 &&
			self.temporaryServerPortOverride <= TXMaximumTCPPort)
		{
			serverPort = self.temporaryServerPortOverride;
		}

		connectionPrefersSecuredConnection = self.temporaryServerPrefersSecuredConnection;
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

	/* Network.framework cannot use a custom proxy so we can only either use none
	 or allow it to automatically configure the connection using the system proxy. */
	socketConfig.connectionPrefersModernSockets = ([TPCPreferences preferModernSockets] &&
												   (proxyType == IRCConnectionProxyTypeNone ||
													proxyType == IRCConnectionProxyTypeAutomatic));

	socketConfig.cipherSuites = self.config.cipherSuites;

	socketConfig.connectionPrefersSecuredConnection = connectionPrefersSecuredConnection;
	socketConfig.connectionShouldValidateCertificateChain = self.config.validateServerCertificateChain;

	socketConfig.identityClientSideCertificate = self.config.identityClientSideCertificate;

	if (bypassProxy == NO) {
		socketConfig.proxyType = proxyType;

		if (socketConfig.proxyType == IRCConnectionProxyTypeSocks4 ||
			socketConfig.proxyType == IRCConnectionProxyTypeSocks5 ||
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

	if (afterWakeUp) {
		[self autoConnectAfterWakeUp];
	} else {
		[self autoConnect];
	}
}

- (void)autoConnect
{
	NSUInteger connectDelay = self.connectDelay;

	if (connectDelay == 0) {
		[self autoConnectPerformConnect];

		return;
	}

	[self performSelectorInCommonModes:@selector(autoConnectPerformConnect) withObject:nil afterDelay:connectDelay];
}

- (void)autoConnectPerformConnect
{
	if (self.isConnecting || self.isConnected) {
		return;
	}

	[self connect];
}

- (void)autoConnectAfterWakeUp
{
	NSUInteger connectDelay = self.connectDelay;

	if (connectDelay == 0) {
		[self autoConnectAfterWakeUpPerformConnect];

		return;
	}

	[self printDebugInformationToConsole:TXTLS(@"IRC[3s6-e6]", connectDelay)];

	[self performSelectorInCommonModes:@selector(autoConnectAfterWakeUpPerformConnect) withObject:nil afterDelay:connectDelay];
}

- (void)autoConnectAfterWakeUpPerformConnect
{
	if (self.isConnecting || self.isConnected) {
		return;
	}

	self.reconnectEnabledBecauseOfSleepMode = YES;

	[self connect:IRCClientConnectModeReconnect];
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
	[self performSelectorInCommonModes:@selector(disconnect) withObject:nil afterDelay:2.0];
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

	/* Split nicknames into fixed number per-command in case there are a lot or are long. */
	/* June 11, 2018: Disabled this because Textual expects nicknames to appear in ISON
	 response or they are considered offline. If we chunk out results, then user may
	 disappear in one ISON response and then appear in another. The long term solution
	 is to stop relying on ISON but no idea when that will come. */
//	[nicknames enumerateSubarraysOfSize:8 usingBlock:^(NSArray *objects, BOOL *stop) {
		[self _sendIsonForNicknames:nicknames hideResponse:hideResponse];
//	}];
}

- (void)_sendIsonForNicknames:(NSArray<NSString *> *)nicknames hideResponse:(BOOL)hideResponse
{
	NSParameterAssert(nicknames != nil);

	if (self.isLoggedIn == NO) {
		return;
	}

	if (nicknames.count == 0) {
		return;
	}

	if (hideResponse == NO) {
		[self.requestedCommands recordIsonRequestOpenedAsVisible];
	} else {
		[self.requestedCommands recordIsonRequestOpened];
	}

	NSString *nicknamesString = [nicknames componentsJoinedByString:@" "];

	[self send:@"ISON", nicknamesString, nil];
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
	NSParameterAssert(nickname != nil);
	NSParameterAssert(filename != nil);

	NSString *escapedFilename = [self DCCSendEscapeFilename:filename];

	NSString *stringToSend = nil;

	if (transferToken) {
		stringToSend = [NSString stringWithFormat:@"%@ %hu %lli %@", escapedFilename, port, totalFilesize, transferToken];
	} else {
		stringToSend = [NSString stringWithFormat:@"%@ %hu %lli", escapedFilename, port, totalFilesize];
	}

	[self sendCTCPQuery:nickname command:@"DCC RESUME" text:stringToSend];
}

- (void)sendFileResumeAccept:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
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

	[self sendCTCPQuery:nickname command:@"DCC ACCEPT" text:stringToSend];
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

#pragma mark -
#pragma mark Command Queue

- (NSString *)descriptionForTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	NSString *timerInterval = TXHumanReadableTimeInterval(timedCommand.timerInterval, NO, 0);

	NSString *timeRemaining = TXHumanReadableTimeInterval(timedCommand.timeRemaining, NO, 0);

	NSString *timerStatus = nil;

	if (timedCommand.timerIsActive == NO) {
		timerStatus = TXTLS(@"IRC[ww4-sn]");
	} else {
		timerStatus = TXTLS(@"IRC[bhz-9e]");
	}

	if (timedCommand.repeatTimer == NO) {
		return TXTLS(@"IRC[4n6-2x]",
					 timedCommand.identifier,
					 timerStatus,
					 timerInterval,
					 timeRemaining,
					 timedCommand.command);
	} else {
		NSUInteger repeatLimit = timedCommand.iterations;

		NSString *repeatLimitDescriptor = nil;

		if (repeatLimit == 0) {
			repeatLimitDescriptor = TXTLS(@"IRC[o26-ae]");
		} else {
			repeatLimitDescriptor = [NSString stringWithUnsignedInteger:repeatLimit];
		}

		return TXTLS(@"IRC[uw0-v2]",
					 timedCommand.identifier,
					 timerStatus,
					 timerInterval,
					 timeRemaining,
					 repeatLimitDescriptor,
					 timedCommand.currentIteration,
					 timedCommand.command);
	}
}

- (nullable IRCTimedCommand *)timedCommandWithIdentifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	@synchronized (self.timedCommands) {
		return self.timedCommands[identifier];
	}
}

- (NSArray<IRCTimedCommand *> *)listOfTimedCommands
{
	@synchronized (self.timedCommands) {
		return self.timedCommands.allValues;
	}
}

- (void)addTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	@synchronized (self.timedCommands) {
		self.timedCommands[timedCommand.identifier] = timedCommand;
	}
}

- (void)removeTimedCommands
{
	@synchronized (self.timedCommands) {
		[self.timedCommands removeAllObjects];
	}
}

- (void)removeTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	@synchronized (self.timedCommands) {
		[self.timedCommands removeObjectForKey:timedCommand.identifier];
	}
}

- (void)stopTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	[timedCommand stop];
}

- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval
{
	NSParameterAssert(timedCommand != nil);

	[self startTimedCommand:timedCommand interval:timerInterval onRepeat:NO iterations:0];
}

- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval onRepeat:(BOOL)repeatTimer
{
	NSParameterAssert(timedCommand != nil);

	[self startTimedCommand:timedCommand interval:timerInterval onRepeat:repeatTimer iterations:0];
}

- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval onRepeat:(BOOL)repeatTimer iterations:(NSUInteger)iterations
{
	NSParameterAssert(timedCommand != nil);

	[timedCommand start:timerInterval onRepeat:repeatTimer iterations:iterations];
}

- (BOOL)restartTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	return [timedCommand restart];
}

- (void)onTimedCommand:(IRCTimedCommand *)timedCommand
{
	NSParameterAssert(timedCommand != nil);

	/* Remove timer */
	if (timedCommand.timerIsActive == NO) {
		[self removeTimedCommand:timedCommand];
	}

	/* The -channelId is only a suggestion. It's okay if this returns nil.
	 The channel is what was selected at the time that the timer was created.
	 -sendCommand:completeTarget:target: may very well ignore the channel we
	 give it, even if it's non-nil, depending on format of command. */
	IRCChannel *channel = (IRCChannel *)[worldController() findItemWithId:timedCommand.channelId];

	[self sendCommand:timedCommand.command completeTarget:YES target:channel.name];
}

#pragma mark -
#pragma mark User Tracking

- (void)clearTrackedUsers
{
	[self.trackedUsers clearTrackedUsers];
}

- (void)statusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus
{
	[self statusOfTrackedNickname:nickname changedTo:newStatus notify:NO];
}

- (void)statusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus notify:(BOOL)notify
{
	NSParameterAssert(nickname != nil);

	[self.trackedUsers statusOfTrackedNickname:nickname changedTo:newStatus];

	if (notify) {
		[self notifyStatusOfTrackedNickname:nickname changedTo:newStatus];
	}
}

- (void)notifyStatusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus
{
	NSParameterAssert(nickname != nil);

	NSString *message = nil;

	if (newStatus == IRCAddressBookUserTrackingStatusSignedOn) {
		message = TXTLS(@"Notifications[xk2-1l]", nickname);
	} else if (newStatus == IRCAddressBookUserTrackingStatusSignedOff) {
		message = TXTLS(@"Notifications[rif-9r]", nickname);
	} else if (newStatus == IRCAddressBookUserTrackingStatusAvailable) {
		message = TXTLS(@"Notifications[97r-0l]", nickname);
	}

	if (message == nil) {
		return;
	}

	[self notifyEvent:TXNotificationTypeAddressBookMatch lineType:TVCLogLineTypeNotice target:nil nickname:nickname text:message];
}

- (void)populateISONTrackedUsersList
{
	if (self.isLoggedIn == NO) {
		return;
	}

	/* Additions & Removals for WATCH command. ISON does not access these. */
	NSMutableArray<NSString *> *watchAdditions = [NSMutableArray array];
	NSMutableArray<NSString *> *watchRemovals = [NSMutableArray array];

	/* Compare configuration to the list of tracked nicknames.
	 * Nicknames that are new are added to watchAdditions */
	NSDictionary *trackedUsersOld = self.trackedUsers.trackedUsers;

	NSMutableArray<NSString *> *trackedUsersNew = [NSMutableArray array];

	for (IRCAddressBookEntry *g in self.config.ignoreList) {
		if (g.trackUserActivity == NO) {
			continue;
		}

		NSString *trackingNickname = g.trackingNickname;

		IRCAddressBookUserTrackingStatus trackingStatus = [self.trackedUsers statusOfUser:trackingNickname];

		if (trackingStatus != IRCAddressBookUserTrackingStatusUnknown) {
			[trackedUsersNew addObject:trackingNickname];

			continue;
		}

		[watchAdditions addObject:trackingNickname];

		[self.trackedUsers _addTrackedUser:trackingNickname];
	}

	/* Compare old list of tracked nicknames to new list to find
	 those that no longer appear. Mark those for removal. */
	for (NSString *trackedUser in trackedUsersOld) {
		if ([trackedUsersNew containsObjectIgnoringCase:trackedUser]) {
			continue;
		}

		[watchRemovals addObject:trackedUser];

		[self.trackedUsers _removeTrackedUser:trackedUser];
	}

	/* Set new entries */
	[self modifyWatchListBy:YES nicknames:watchAdditions];

	[self modifyWatchListBy:NO nicknames:watchRemovals];

	[self startISONTimer];
}

- (void)startISONTimer
{
	if (self.isonTimer.timerIsActive) {
		return;
	}

	[self.isonTimer start:_isonCheckInterval onRepeat:YES];

	[self startWhoTimer];
}

- (void)stopISONTimer
{
	if (self.isonTimer.timerIsActive == NO) {
		return;
	}

	[self.isonTimer stop];

	[self stopWhoTimer];
}

- (void)onISONTimer
{
	if (self.isLoggedIn == NO || self.isBrokenIRCd_aka_Twitch) {
		return;
	}

	NSMutableArray<NSString *> *nicknames = [NSMutableArray array];

	// Request ISON status for tracked users
	if (self.supportsAdvancedTracking == NO) {
		for (NSString *trackedUser in self.trackedUsers.trackedUsers) {
			[nicknames addObject:trackedUser];
		}
	}

	// Request ISON status for private messages
	for (IRCChannel *channel in self.channelList) {
		if (channel.privateMessage) {
			[nicknames addObject:channel.name];
		}
	}

	[self sendIsonForNicknames:nicknames hideResponse:YES];
}

- (void)startWhoTimer
{
	if (self.whoTimer.timerIsActive) {
		return;
	}

	[self.whoTimer start:_whoCheckInterval onRepeat:YES];
}

- (void)stopWhoTimer
{
	if (self.whoTimer.timerIsActive == NO) {
		return;
	}

	[self.whoTimer stop];
}

- (void)onWhoTimer
{
	if (self.isLoggedIn == NO || self.isBrokenIRCd_aka_Twitch) {
		return;
	}

	NSArray *channelList = self.channelList;

	[self sendTimedWhoRequestsToChannels:channelList];
}

- (void)sendTimedWhoRequestsToChannels:(NSArray<IRCChannel *> *)channelList
{
	NSParameterAssert(channelList != nil);

	if (self.isLoggedIn == NO || self.isBrokenIRCd_aka_Twitch) {
		return;
	}

#define _maximumChannelCountPerWhoBatchRequest			4
#define _maximumSingleChannelSizePerWhoBatchRequest		5000
#define _maximumTotalChannelSizePerWhoBatchRequest		2000

	NSUInteger channelCount = channelList.count;

	if (channelCount == 0) {
		return;
	}

	NSUInteger startingPosition = self.lastWhoRequestChannelListIndex;

	NSUInteger endingPosition = (startingPosition + _maximumChannelCountPerWhoBatchRequest);

	if (startingPosition >= channelCount) {
		startingPosition = 0;
	}

	if (endingPosition >= channelCount) {
		endingPosition = (channelCount - 1);
	}

	NSUInteger totalMemberCount = 0;

	NSMutableArray<IRCChannel *> *channelsToQuery = nil;

	for (NSUInteger channelIndex = startingPosition; channelIndex <= endingPosition; channelIndex++) {
		IRCChannel *channel = channelList[channelIndex];

		if (channel.isActive == NO || channel.isChannel == NO) {
			continue;
		}

		/* Update internal state of flag */
		BOOL sentInitialWhoRequest = channel.sentInitialWhoRequest;

		if (sentInitialWhoRequest == NO) {
			channel.sentInitialWhoRequest = YES;
		}

		/* continue to next channel and do not break so that the
		 -sentInitialWhoRequest flag of all channels can be updated. */
		if (self.config.sendWhoCommandRequestsToChannels == NO) {
			continue;
		}

		/* Perform comparisons to know whether channel is acceptable */
		NSUInteger numberOfMembers = channel.numberOfMembers;

		if (sentInitialWhoRequest == NO) {
			if (numberOfMembers > _maximumSingleChannelSizePerWhoBatchRequest) {
				continue;
			}
		} else {
			if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityAwayNotify]) {
				continue;
			}

			if (numberOfMembers > [TPCPreferences trackUserAwayStatusMaximumChannelSize]) {
				continue;
			}
		}

		/* Add channel to list */
		if (channelsToQuery == nil) {
			channelsToQuery = [NSMutableArray new];
		}

		[channelsToQuery addObject:channel];

		/* Update total number of members and maybe break loop */
		totalMemberCount += numberOfMembers;

		if (totalMemberCount > _maximumTotalChannelSizePerWhoBatchRequest) {
			endingPosition = channelIndex;

			break;
		}
	}

	self.lastWhoRequestChannelListIndex = (endingPosition + 1);

	/* Send WHO requests */
	if (channelsToQuery == nil) {
		return;
	}

	for (IRCChannel *channel in channelsToQuery) {
		[self sendWhoToChannel:channel hideResponse:YES];
	}

#undef _maximumChannelCountPerWhoBatchRequest
#undef _maximumSingleChannelSizePerWhoBatchRequest
#undef _maximumTotalChannelSizePerWhoBatchRequest
}

- (void)updateUserTrackingStatusForEntry:(IRCAddressBookEntry *)addressBookEntry withMessage:(IRCMessage *)message
{
	NSParameterAssert(addressBookEntry != nil);
	NSParameterAssert(message != nil);

	if (self.supportsAdvancedTracking) {
		return;
	}

	IRCAddressBookUserTrackingStatus trackingStatus = [self.trackedUsers statusOfEntry:addressBookEntry];

	if (trackingStatus == IRCAddressBookUserTrackingStatusUnknown) {
		return;
	}

	BOOL ison = (trackingStatus == IRCAddressBookUserTrackingStatusAvailable);

	/* Notification Type: JOIN Command */
	if ([message.command isEqualToStringIgnoringCase:@"JOIN"]) {
		if (ison == NO) {
			[self statusOfTrackedNickname:message.senderNickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];
		}

		return;
	}

	/* Notification Type: QUIT Command */
	if ([message.command isEqualToStringIgnoringCase:@"QUIT"]) {
		if (ison) {
			[self statusOfTrackedNickname:message.senderNickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];
		}

		return;
	}

	/* Notification Type: NICK Command */
	if ([message.command isEqualToStringIgnoringCase:@"NICK"]) {
		if (ison) {
			[self statusOfTrackedNickname:message.senderNickname changedTo:IRCAddressBookUserTrackingStatusSignedOff notify:YES];
		} else {
			[self statusOfTrackedNickname:message.senderNickname changedTo:IRCAddressBookUserTrackingStatusSignedOn notify:YES];
		}

		return;
	}
}

#pragma mark -
#pragma mark Channel Ban List Dialog

- (void)createChannelInviteExceptionListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeInviteException];
}

- (void)createChannelBanExceptionListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeBanException];
}

- (void)createChannelBanListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeBan];
}

- (void)createChannelQuietListSheet
{
	[self createChannelBanListSheet:TDCChannelBanListSheetEntryTypeQuiet];
}

- (void)createChannelBanListSheet:(TDCChannelBanListSheetEntryType)entryType
{
	[windowController() popMainWindowSheetIfExists];

	IRCChannel *c = mainWindow().selectedChannel;

	if (c == nil) {
		return;
	}

	TDCChannelBanListSheet *listSheet = [[TDCChannelBanListSheet alloc] initWithEntryType:entryType inChannel:c];

	if (listSheet == nil) {
		return;
	}

	listSheet.delegate = (id)self;

	listSheet.window = mainWindow();

	[listSheet start];

	[windowController() addWindowToWindowList:listSheet];
}

- (void)channelBanListSheetOnUpdate:(TDCChannelBanListSheet *)sender
{
	IRCChannel *channel = sender.channel;

	if (channel == nil) {
		return;
	}

	NSString *modeSend = [NSString stringWithFormat:@"+%@", sender.modeSymbol];

	[self sendModes:modeSend withParametersString:nil inChannel:channel];
}

- (void)channelBanListSheetWillClose:(TDCChannelBanListSheet *)sender
{
	IRCChannel *channel = sender.channel;

	if (channel == nil) {
		return;
	}

	NSArray *listOfChanges = sender.listOfChanges;

	for (NSString *change in listOfChanges) {
		[self sendModes:change withParametersString:nil inChannel:channel];
	}

	[windowController() removeWindowFromWindowList:sender];
}

#pragma mark -
#pragma mark Network Channel List Dialog

- (NSString *)channelListDialogWindowKey
{
	return [NSString stringWithFormat:@"TDCServerChannelListDialog -> %@", self.uniqueIdentifier];
}

- (nullable TDCServerChannelListDialog *)channelListDialog
{
	return [windowController() windowFromWindowList:[self channelListDialogWindowKey]];
}

- (void)createChannelListDialog
{
	if ([windowController() maybeBringWindowForward:[self channelListDialogWindowKey]]) {
		return; // The window was brought forward already.
	}

	TDCServerChannelListDialog *channelListDialog = [[TDCServerChannelListDialog alloc] initWithClient:self];

	channelListDialog.delegate = (id)self;

	[channelListDialog show];

	[windowController() addWindowToWindowList:channelListDialog withDescription:[self channelListDialogWindowKey]];
}

- (void)serverChannelListDialogOnUpdate:(TDCServerChannelListDialog *)sender
{
	[self requestChannelList];
}

- (void)serverChannelListDialog:(TDCServerChannelListDialog *)sender joinChannels:(NSArray<NSString *> *)channels
{
	[self joinUnlistedChannelsAndSelectBestMatch:channels];
}

- (void)serverChannelDialogWillClose:(TDCServerChannelListDialog *)sender
{
	[windowController() removeWindowFromWindowList:[self channelListDialogWindowKey]];
}

@end

NS_ASSUME_NONNULL_END
