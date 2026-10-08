/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
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

#import "TLOKeychainPrivate.h"
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "IRC.h"
#import "IRCAddressBook.h"
#import "IRCChannelConfig.h"
#import "IRCHighlightMatchCondition.h"
#import "IRCNetworkList.h"
#import "IRCServerPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TLOLocalization.h"
#import "IRCClientConfigInternal.h"

NS_ASSUME_NONNULL_BEGIN

#define IRCClientConfigDictionaryVersionLatest		710

@interface IRCClientConfig ()
@property (readonly) BOOL prefersSecuredConnection_;
@property (readonly) uint16_t serverPort_;
@property (readonly, copy, nullable) NSString *serverAddress_;
@property (readonly) BOOL connectionPrefersModernCiphers_;
@end

@implementation IRCClientConfig

#pragma mark -
#pragma mark Defaults

- (void)populateDefaultsPreflight
{
	if (self.initializedAsCopy) {
		return;
	}

	/* Even if a value is NO, include it as a default. */
	/* This allows NO values to be stripped from output dictionary. */
	NSMutableDictionary<NSString *, id> *defaults = [NSMutableDictionary dictionary];

	defaults[@"addressType"] = @(IRCConnectionAddressTypeDefault);
	defaults[@"autoConnect"] = @(NO);
	defaults[@"autoReconnect"] = @(NO);
	defaults[@"autoSleepModeDisconnect"] = @(YES);
	defaults[@"autojoinWaitsForNickServ"] = @(NO);
	defaults[@"cachedLastServerTimeCapabilityReceivedAtTimestamp"] = @(0);
	defaults[@"cipherSuites"] = @(RCMCipherSuiteCollectionDefault);
	defaults[@"connectionName"] = TXTLS(@"BasicLanguage[vfu-c0]");
	defaults[@"fallbackEncoding"] = @(TXDefaultFallbackStringEncoding);
	defaults[@"floodControlDelayTimerInterval"] = @(IRCConnectionConfigFloodControlDefaultDelayInterval);
	defaults[@"floodControlMaximumMessages"] = @(IRCConnectionConfigFloodControlDefaultMessageCount);
	defaults[@"hideAutojoinDelayedWarnings"] = @(NO);
	defaults[@"hideNetworkUnavailabilityNotices"] = @(NO);
	defaults[@"normalLeavingComment"] = TXTLS(@"BasicLanguage[1dd-0f]");
	defaults[@"performDisconnectOnPongTimer"] = @(NO);
	defaults[@"performDisconnectOnReachabilityChange"] = @(YES);
	defaults[@"performPongTimer"] = @(YES);
	defaults[@"prefersSecuredConnection"] = @(NO);
	defaults[@"primaryEncoding"] = @(TXDefaultPrimaryStringEncoding);
	defaults[@"proxyPort"] = @(IRCConnectionDefaultProxyPort);
	defaults[@"proxyType"] = @(IRCConnectionProxyTypeAutomatic);
	defaults[@"saslAuthenticationDisableExternalMechanism"] = @(NO);
	defaults[@"sendAuthenticationRequestsToUserServ"] = @(NO);
	defaults[@"sendWhoCommandRequestsToChannels"] = @(YES);
	defaults[@"serverPort"] = @(IRCConnectionDefaultServerPort);
	defaults[@"setInvisibleModeOnConnect"] = @(NO);
	defaults[@"sidebarItemExpanded"] = @(YES);
	defaults[@"sleepModeLeavingComment"] = TXTLS(@"BasicLanguage[qi7-5y]");
	defaults[@"validateServerCertificateChain"] = @(YES);
	defaults[@"zncIgnoreConfiguredAutojoin"] = @(NO);
	defaults[@"zncIgnorePlaybackNotifications"] = @(YES);
	defaults[@"zncIgnoreUserNotifications"] = @(NO);
	defaults[@"zncOnlyPlaybackLatest"] = @(YES);

	self->_defaults = [defaults copy];
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy) {
		return;
	}

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])

	SetVariableIfNil(self->_nickname, [TPCPreferences defaultNickname])
	SetVariableIfNil(self->_awayNickname, [TPCPreferences defaultAwayNickname])
	SetVariableIfNil(self->_username, [TPCPreferences defaultUsername])
	SetVariableIfNil(self->_realName, [TPCPreferences defaultRealName])

	SetVariableIfNil(self->_ignoreList, @[])
	SetVariableIfNil(self->_channelList, @[])
	SetVariableIfNil(self->_highlightList, @[])
	SetVariableIfNil(self->_serverList, @[])

	SetVariableIfNil(self->_alternateNicknames, @[])

	SetVariableIfNil(self->_loginCommands, @[])
}

#pragma mark -
#pragma mark Server Configuration

- (instancetype)init
{
	return [self initWithDictionary:@{}];
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dic
{
	return [self initWithDictionary:dic ignorePrivateMessages:NO];
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dic ignorePrivateMessages:(BOOL)ignorePrivateMessages
{
	if ((self = [super init])) {
		[self populateDefaultsPreflight];

		[self populateDictionaryValue:dic
				ignorePrivateMessages:ignorePrivateMessages
						applyDefaults:YES
					bypassIsCopyCheck:NO];

		[self populateDefaultsPostflight];

		[self initializedClassHealthCheck];

		return self;
	}

	return nil;
}

- (void)initializedClassHealthCheck
{
	if (self.initializedAsCopy) {
		return;
	}

	if (self->_proxyPort == 0) {
		self->_proxyPort = IRCConnectionDefaultProxyPort;
	}

	if ([self isMutable]) {
		return;
	}

	NSParameterAssert(self->_connectionName.length > 0);
}

+ (instancetype)newConfigByMerging:(IRCClientConfig *)config1 with:(IRCClientConfig *)config2
{
	NSParameterAssert(config1 != nil);
	NSParameterAssert(config2 != nil);

	IRCClientConfigMutable *config1Mutable = [config1 mutableCopy];

	[config1Mutable populateDictionaryValue:config2.dictionaryValue
					  ignorePrivateMessages:NO
							  applyDefaults:NO
						  bypassIsCopyCheck:YES];

	if ([self isMutable]) {
		return config1Mutable;
	}

	return [config1Mutable copy];
}

+ (instancetype)newConfigWithNetwork:(IRCNetwork *)network
{
	NSParameterAssert(network != nil);

	IRCClientConfigMutable *configMutable = [IRCClientConfigMutable new];

	configMutable.connectionName = network.networkName;

	IRCServerMutable *server = [IRCServerMutable new];

	server.serverAddress = network.serverAddress;
	server.serverPort = network.serverPort;

	server.prefersSecuredConnection = network.prefersSecuredConnection;

	configMutable.serverList = @[[server copy]];

	if ([self isMutable]) {
		return configMutable;
	}

	return [configMutable copy];
}

- (void)populateDictionaryValue:(NSDictionary<NSString *, id> *)dic ignorePrivateMessages:(BOOL)ignorePrivateMessages applyDefaults:(BOOL)applyDefaults bypassIsCopyCheck:(BOOL)bypassIsCopyCheck
{
	NSParameterAssert(dic != nil);

	NSMutableDictionary<NSString *, id> *defaultsMutable = nil;

	if (applyDefaults) {
		defaultsMutable = [self->_defaults mutableCopy];

		[defaultsMutable addEntriesFromDictionary:dic];
	} else {
		defaultsMutable = [dic mutableCopy];
	}

	/* Load the newest set of keys. */
	[defaultsMutable assignUnsignedIntegerTo:&self->_dictionaryVersion forKey:@"dictionaryVersion"];

	[defaultsMutable assignArrayTo:&self->_alternateNicknames forKey:@"alternateNicknames"];
	[defaultsMutable assignArrayTo:&self->_loginCommands forKey:@"onConnectCommands"];

	[defaultsMutable assignBoolTo:&self->_autoConnect forKey:@"autoConnect"];
	[defaultsMutable assignBoolTo:&self->_autoReconnect forKey:@"autoReconnect"];
	[defaultsMutable assignBoolTo:&self->_autoSleepModeDisconnect forKey:@"autoSleepModeDisconnect"];
	[defaultsMutable assignBoolTo:&self->_autojoinWaitsForNickServ forKey:@"autojoinWaitsForNickServ"];
	[defaultsMutable assignBoolTo:&self->_hideAutojoinDelayedWarnings forKey:@"hideAutojoinDelayedWarnings"];
	[defaultsMutable assignBoolTo:&self->_hideNetworkUnavailabilityNotices forKey:@"hideNetworkUnavailabilityNotices"];
	[defaultsMutable assignBoolTo:&self->_performDisconnectOnPongTimer forKey:@"performDisconnectOnPongTimer"];
	[defaultsMutable assignBoolTo:&self->_performDisconnectOnReachabilityChange forKey:@"performDisconnectOnReachabilityChange"];
	[defaultsMutable assignBoolTo:&self->_performPongTimer forKey:@"performPongTimer"];
	[defaultsMutable assignBoolTo:&self->_prefersSecuredConnection forKey:@"prefersSecuredConnection"];
	[defaultsMutable assignBoolTo:&self->_saslAuthenticationDisableExternalMechanism forKey:@"saslAuthenticationDisableExternalMechanism"];
	[defaultsMutable assignBoolTo:&self->_sendAuthenticationRequestsToUserServ forKey:@"sendAuthenticationRequestsToUserServ"];
	[defaultsMutable assignBoolTo:&self->_sendWhoCommandRequestsToChannels forKey:@"sendWhoCommandRequestsToChannels"];
	[defaultsMutable assignBoolTo:&self->_setInvisibleModeOnConnect forKey:@"setInvisibleModeOnConnect"];
	[defaultsMutable assignBoolTo:&self->_sidebarItemExpanded forKey:@"sidebarItemExpanded"];
	[defaultsMutable assignBoolTo:&self->_validateServerCertificateChain forKey:@"validateServerCertificateChain"];
	[defaultsMutable assignBoolTo:&self->_zncIgnoreConfiguredAutojoin forKey:@"zncIgnoreConfiguredAutojoin"];
	[defaultsMutable assignBoolTo:&self->_zncIgnorePlaybackNotifications forKey:@"zncIgnorePlaybackNotifications"];
	[defaultsMutable assignBoolTo:&self->_zncIgnoreUserNotifications forKey:@"zncIgnoreUserNotifications"];
	[defaultsMutable assignBoolTo:&self->_zncOnlyPlaybackLatest forKey:@"zncOnlyPlaybackLatest"];

	[defaultsMutable assignDoubleTo:&self->_lastMessageServerTime forKey:@"cachedLastServerTimeCapabilityReceivedAtTimestamp"];
	[defaultsMutable assignObjectTo:&self->_identityClientSideCertificate forKey:@"identityClientSideCertificate"];
	[defaultsMutable assignStringTo:&self->_awayNickname forKey:@"awayNickname"];
	[defaultsMutable assignStringTo:&self->_nickServHost forKey:@"nickServHost"];
	[defaultsMutable assignStringTo:&self->_connectionName forKey:@"connectionName"];
	[defaultsMutable assignStringTo:&self->_nickname forKey:@"nickname"];
	[defaultsMutable assignStringTo:&self->_normalLeavingComment forKey:@"normalLeavingComment"];
	[defaultsMutable assignStringTo:&self->_proxyAddress forKey:@"proxyAddress"];
	[defaultsMutable assignStringTo:&self->_proxyUsername forKey:@"proxyUsername"];
	[defaultsMutable assignStringTo:&self->_realName forKey:@"realName"];
	[defaultsMutable assignStringTo:&self->_serverAddress forKey:@"serverAddress"];
	[defaultsMutable assignStringTo:&self->_sleepModeLeavingComment forKey:@"sleepModeLeavingComment"];
	[defaultsMutable assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];
	[defaultsMutable assignStringTo:&self->_username forKey:@"username"];

	[defaultsMutable assignUnsignedIntegerTo:&self->_addressType forKey:@"addressType"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_cipherSuites forKey:@"cipherSuites"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_fallbackEncoding forKey:@"fallbackEncoding"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_floodControlDelayTimerInterval forKey:@"floodControlDelayTimerInterval"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_floodControlMaximumMessages forKey:@"floodControlMaximumMessages"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_primaryEncoding forKey:@"primaryEncoding"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_proxyType forKey:@"proxyType"];

	/* SOCKS4 was removed in Textual 8; most SOCKS servers also speak SOCKS5 */
	if (self->_proxyType == IRCConnectionProxyTypeSocks4) {
		self->_proxyType = IRCConnectionProxyTypeSocks5;
	}

	[defaultsMutable assignUnsignedShortTo:&self->_proxyPort forKey:@"proxyPort"];
	[defaultsMutable assignUnsignedShortTo:&self->_serverPort forKey:@"serverPort"];

	/* -connectionPrefersIPv4 is a special exception to legacy support.
	 We still load its value, regardless of dictionary version, so that
	 we can show a user a warning when -connectionPrefersIPv4 == YES
	 and -addressType == IPv6 (which is automatically migrates to).
	 We then change value to NO when user modifies -addressType. */
	[defaultsMutable assignBoolTo:&self->_connectionPrefersIPv4 forKey:@"connectionPrefersIPv4"];

	/* If this is a copy operation, then we can just stop here. The rest of the data processed below,
	 such as other configurations and backwards keys are already taken care of. */
	if (self.initializedAsCopy && bypassIsCopyCheck == NO) {
		return;
	}

	/* Channel list */
	NSMutableArray<IRCChannelConfig *> *channelListOut = [NSMutableArray array];

	NSArray<NSDictionary *> *channelListIn = [defaultsMutable arrayForKey:@"channelList"];

	for (NSDictionary<NSString *, id> *e in channelListIn) {
		IRCChannelConfig *c = [[IRCChannelConfig alloc] initWithDictionary:e];

		if (c.type == IRCChannelTypePrivateMessage) {
			if (ignorePrivateMessages == NO) {
				[channelListOut addObject:c];
			}
		} else {
			[channelListOut addObject:c];
		}
	}

	self->_channelList = [channelListOut copy];

	/* Ignore list */
	NSMutableArray<IRCAddressBookEntry *> *ignoreListOut = [NSMutableArray array];

	NSArray<NSDictionary *> *ignoreListIn = [defaultsMutable arrayForKey:@"ignoreList"];

	for (NSDictionary<NSString *, id> *e in ignoreListIn) {
		IRCAddressBookEntry *c = [[IRCAddressBookEntry alloc] initWithDictionary:e];

		[ignoreListOut addObject:c];
	}

	self->_ignoreList = [ignoreListOut copy];

	/* Highlight list */
	NSMutableArray<IRCHighlightMatchCondition *> *highlightListOut = [NSMutableArray array];

	NSArray<NSDictionary *> *highlightListIn = [defaultsMutable arrayForKey:@"highlightList"];

	for (NSDictionary<NSString *, id> *e in highlightListIn) {
		IRCHighlightMatchCondition *c = [[IRCHighlightMatchCondition alloc] initWithDictionary:e];

		[highlightListOut addObject:c];
	}

	self->_highlightList = [highlightListOut copy];

	/* Server List */
	NSMutableArray<IRCServer *> *serverListOut = [NSMutableArray array];

	NSArray<NSDictionary *> *serverListIn = [defaultsMutable arrayForKey:@"serverList"];

	for (NSDictionary<NSString *, id> *e in serverListIn) {
		IRCServer *c = [[IRCServer alloc] initWithDictionary:e];

		[serverListOut addObject:c];
	}

	self->_serverList = [serverListOut copy];

	/* Perform migration */
	/* If legacy keys were assigned before new keys, then a transition would not occur properly. */
	/* Since the new keys will read from -defaults if they are not present in /dic/, then those
	 would override legacy keys when performing a first pass. */

	/* Is everything up to date? */
	NSUInteger dictionaryVersion = self->_dictionaryVersion;

	if (dictionaryVersion == IRCClientConfigDictionaryVersionLatest) {
		return;
	}

	/* 710 is latest version which means we migrate it at all times */
	[self _migrate710Dictionary:dic withDefaults:defaultsMutable];

	/* 704 is no longer the latest version but there was no version before
	 it which means we only have to migrate it when the version is unknown. */
	if (dictionaryVersion == 0) {
		[self _migrate704Dictionary:dic withDefaults:defaultsMutable];
	}

	/* Update version */
	self->_dictionaryVersion = IRCClientConfigDictionaryVersionLatest;
}

- (void)_migrate710Dictionary:(NSDictionary *)dic withDefaults:(NSMutableDictionary *)defaultsMutable
{
	NSParameterAssert(dic != nil);
	NSParameterAssert(defaultsMutable != nil);

TEXTUAL_IGNORE_DEPRECATION_BEGIN
	if (self.connectionPrefersIPv4) {
TEXTUAL_IGNORE_DEPRECATION_END

		self->_addressType = IRCConnectionAddressTypeIPv4;
	}
}

- (void)_migrate704Dictionary:(NSDictionary *)dic withDefaults:(NSMutableDictionary *)defaultsMutable
{
	NSParameterAssert(dic != nil);
	NSParameterAssert(defaultsMutable != nil);

	[defaultsMutable assignArrayTo:&self->_alternateNicknames forKey:@"identityAlternateNicknames"];

	[defaultsMutable assignBoolTo:&self->_autoConnect forKey:@"connectOnLaunch"];
	[defaultsMutable assignBoolTo:&self->_autoReconnect forKey:@"connectOnDisconnect"];
	[defaultsMutable assignBoolTo:&self->_autoSleepModeDisconnect forKey:@"disconnectOnSleepMode"];
	[defaultsMutable assignBoolTo:&self->_autojoinWaitsForNickServ forKey:@"autojoinWaitsForNickServIdentification"];
	[defaultsMutable assignBoolTo:&self->_prefersSecuredConnection forKey:@"connectUsingSSL"];
	[defaultsMutable assignBoolTo:&self->_setInvisibleModeOnConnect forKey:@"setInvisibleOnConnect"];
	[defaultsMutable assignBoolTo:&self->_sidebarItemExpanded forKey:@"serverListItemIsExpanded"];
	[defaultsMutable assignBoolTo:&self->_validateServerCertificateChain forKey:@"validateServerSideSSLCertificate"];

	[defaultsMutable assignObjectTo:&self->_identityClientSideCertificate forKey:@"IdentitySSLCertificate"];

	[defaultsMutable assignStringTo:&self->_awayNickname forKey:@"identityAwayNickname"];
	[defaultsMutable assignStringTo:&self->_nickname forKey:@"identityNickname"];
	[defaultsMutable assignStringTo:&self->_normalLeavingComment forKey:@"connectionDisconnectDefaultMessage"];
	[defaultsMutable assignStringTo:&self->_proxyAddress forKey:@"proxyServerAddress"];
	[defaultsMutable assignStringTo:&self->_proxyUsername forKey:@"proxyServerUsername"];
	[defaultsMutable assignStringTo:&self->_realName forKey:@"identityRealname"];
	[defaultsMutable assignStringTo:&self->_sleepModeLeavingComment forKey:@"connectionDisconnectSleepModeMessage"];
	[defaultsMutable assignStringTo:&self->_username forKey:@"identityUsername"];

	[defaultsMutable assignUnsignedIntegerTo:&self->_primaryEncoding forKey:@"characterEncodingDefault"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_fallbackEncoding forKey:@"characterEncodingFallback"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_proxyType forKey:@"proxyServerType"];

	if (self->_proxyType == IRCConnectionProxyTypeSocks4) {
		self->_proxyType = IRCConnectionProxyTypeSocks5;
	}

	[defaultsMutable assignUnsignedShortTo:&self->_proxyPort forKey:@"proxyServerPort"];

	[defaultsMutable assignDoubleTo:&self->_lastMessageServerTime forKey:@"cachedLastServerTimeCapacityReceivedAtTimestamp"];

	/* Flood control */
	/* This is here to migrate to the new properties. Saving these values
	 in this dictionary key is no longer preferred. */
	BOOL floodControlSetToDisabled = NO;

	NSDictionary *floodControlDic = [defaultsMutable dictionaryForKey:@"floodControl"];

	if (floodControlDic) {
		NSNumber *serviceEnabled = floodControlDic[@"serviceEnabled"];

		if (serviceEnabled && serviceEnabled.boolValue == NO) {
			floodControlSetToDisabled = YES;
		}

		[floodControlDic assignUnsignedIntegerTo:&self->_floodControlDelayTimerInterval forKey:@"delayTimerInterval"];
		[floodControlDic assignUnsignedIntegerTo:&self->_floodControlMaximumMessages forKey:@"maximumMessageCount"];
	}

	if (floodControlSetToDisabled == NO) {
		NSNumber *floodControlEnabled = defaultsMutable[@"isOutgoingFloodControlEnabled"];

		if (floodControlEnabled && floodControlEnabled.boolValue == NO) {
			floodControlSetToDisabled = YES;
		}
	}

	/* An option to disable flood control no longer exists.
	 If the user had flood control disabled when the option did exist,
	 then set the the current values to appear disabled. */
	if (floodControlSetToDisabled) {
		self->_floodControlDelayTimerInterval = IRCConnectionConfigFloodControlMinimumDelayInterval;
		self->_floodControlMaximumMessages = IRCConnectionConfigFloodControlMaximumMessageCount;
	}

	/* Migrate to keychain. */
	NSString *proxyPassword = [defaultsMutable stringForKey:@"proxyServerPassword"];

	if (proxyPassword) {
		self->_proxyPassword = [proxyPassword copy];

		[self writeProxyPasswordToKeychain];
	}

	/* Cipher suites */
	/* The dictionary excludes defaults which means we need to be cautious
	 about reading the value of dic when performing migration. */
	if (dic[@"cipherSuites"] == nil) {
		NSNumber *connectionPrefersModernCiphers = dic[@"connectionPrefersModernCiphers"];

		if (connectionPrefersModernCiphers && connectionPrefersModernCiphers.boolValue == NO) {
			self->_cipherSuites = RCMCipherSuiteCollectionNone;
		}
	}

	/* Migrate servers */
	[self _migrateDictionaryToServerListV1Layout:defaultsMutable];
}

- (void)_migrateDictionaryToServerListV1Layout:(NSDictionary *)dic
{
	NSParameterAssert(dic != nil);

	/* This key is no longer assigned. We still check it so that
	 clients that did not set dictionaryVersion but did set this
	 key wont trigger migration again. */
	id migratedToServerListV1Layout = dic[@"migratedToServerListV1Layout"];

	if (migratedToServerListV1Layout && [migratedToServerListV1Layout boolValue]) {
		return;
	}

	/* Do not perform migration if already one server exists. */
	/* IRCClientConfig inserts these values back into the exported dictionary 
	 for backwards compatibility which means once we imported them and have
	 at least one server, then importing again will not help. */
	if (self.serverList.count > 0) {
		return;
	}

	/* Perform migration */
	NSString *serverAddress = [dic stringForKey:@"serverAddress"];

	if (serverAddress.isValidInternetAddress == NO) {
		LogToConsoleDebug("Migration cancelled because of bad server address");

		return;
	}

	uint16_t serverPort = [dic unsignedShortForKey:@"serverPort"];

	if (serverPort == 0 || serverPort > TXMaximumTCPPort) {
		LogToConsoleDebug("Migration cancelled because of bad server port");

		return;
	}

	BOOL prefersSecuredConnection = [dic boolForKey:@"prefersSecuredConnection"];

	NSString *serverPassword = [TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:self.uniqueIdentifier];

	IRCServerMutable *server = [IRCServerMutable new];

	server.serverAddress = serverAddress;
	server.serverPort = serverPort;

	server.serverPassword = serverPassword;

	server.prefersSecuredConnection = prefersSecuredConnection;

	[server writeServerPasswordToKeychain];

	self->_serverList = @[[server copy]];

	self->_migratedServerPasswordPendingDestroy = YES;
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[IRCClientConfig class]] == NO) {
		return NO;
	}

	IRCClientConfig *objectCast = (IRCClientConfig *)object;

	NSDictionary *s1 = self.dictionaryValue;

	NSDictionary *s2 = objectCast.dictionaryValue;

	return ([s1 isEqualToDictionary:s2] &&
			
			((self->_nicknamePassword == nil && objectCast->_nicknamePassword == nil) ||
			 [self->_nicknamePassword isEqualToString:objectCast->_nicknamePassword]) &&

			((self->_proxyPassword == nil && objectCast->_proxyPassword == nil) ||
			 [self->_proxyPassword isEqualToString:objectCast->_proxyPassword]));
}

- (NSUInteger)hash
{
	return self.uniqueIdentifier.hash;
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCClientConfig *config = [self allocForCopyAsMutable:mutableCopy];

	config->_nicknamePassword = self->_nicknamePassword;
	config->_proxyPassword = self->_proxyPassword;

	config->_defaults = self->_defaults;

	config->_migratedServerPasswordPendingDestroy = self->_migratedServerPasswordPendingDestroy;

	if (uniquing) {
		NSMutableArray *channelList = [self.channelList mutableCopy];
		NSMutableArray *highlightList = [self.highlightList mutableCopy];
		NSMutableArray *ignoreList = [self.ignoreList mutableCopy];
		NSMutableArray *serverList = [self.serverList mutableCopy];

		[channelList performSelectorOnObjectValueAndReplace:@selector(uniqueCopy)];
		[highlightList performSelectorOnObjectValueAndReplace:@selector(uniqueCopy)];
		[ignoreList performSelectorOnObjectValueAndReplace:@selector(uniqueCopy)];
		[serverList performSelectorOnObjectValueAndReplace:@selector(uniqueCopy)];

		config->_channelList = [channelList copy];
		config->_highlightList = [highlightList copy];
		config->_ignoreList = [ignoreList copy];
		config->_serverList = [serverList copy];
	} 
	else // uniquing
	{
		config->_channelList = self->_channelList;
		config->_highlightList = self->_highlightList;
		config->_ignoreList = self->_ignoreList;
		config->_serverList = self->_serverList;
	}

	config = [config initWithDictionary:self.dictionaryValueForCopy ignorePrivateMessages:NO];

	/* After initialization (see IRCChannelConfig, R2.2): the NickServ and
	 proxy passwords come along to be saved under the new identifier */
	if (uniquing) {
		config->_nicknamePassword = self.nicknamePassword;
		config->_proxyPassword = self.proxyPassword;

		config->_migratedServerPasswordPendingDestroy = NO;

		config->_uniqueIdentifier = [NSString stringWithUUID];
	}

	return config;
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [IRCClientConfigMutable self];
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	[dic setUnsignedInteger:self->_dictionaryVersion forKey:@"dictionaryVersion"];

	[dic maybeSetObject:self.alternateNicknames forKey:@"alternateNicknames"];
	[dic maybeSetObject:self.awayNickname forKey:@"awayNickname"];
	[dic maybeSetObject:self.nickServHost forKey:@"nickServHost"];
	[dic maybeSetObject:self.connectionName forKey:@"connectionName"];
	[dic maybeSetObject:self.loginCommands forKey:@"onConnectCommands"];
	[dic maybeSetObject:self.nickname forKey:@"nickname"];
	[dic maybeSetObject:self.normalLeavingComment forKey:@"normalLeavingComment"];
	[dic maybeSetObject:self.proxyAddress forKey:@"proxyAddress"];
	[dic maybeSetObject:self.proxyUsername forKey:@"proxyUsername"];
	[dic maybeSetObject:self.realName forKey:@"realName"];
	[dic maybeSetObject:self.sleepModeLeavingComment forKey:@"sleepModeLeavingComment"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];
	[dic maybeSetObject:self.username forKey:@"username"];

	[dic setBool:self.autoConnect forKey:@"autoConnect"];
	[dic setBool:self.autoReconnect forKey:@"autoReconnect"];
	[dic setBool:self.autoSleepModeDisconnect forKey:@"autoSleepModeDisconnect"];
	[dic setBool:self.autojoinWaitsForNickServ forKey:@"autojoinWaitsForNickServ"];
	[dic setBool:self.hideAutojoinDelayedWarnings forKey:@"hideAutojoinDelayedWarnings"];
	[dic setBool:self.hideNetworkUnavailabilityNotices forKey:@"hideNetworkUnavailabilityNotices"];
	[dic setBool:self.performDisconnectOnPongTimer forKey:@"performDisconnectOnPongTimer"];
	[dic setBool:self.performDisconnectOnReachabilityChange forKey:@"performDisconnectOnReachabilityChange"];
	[dic setBool:self.performPongTimer forKey:@"performPongTimer"];
	[dic setBool:self.saslAuthenticationDisableExternalMechanism forKey:@"saslAuthenticationDisableExternalMechanism"];
	[dic setBool:self.sendAuthenticationRequestsToUserServ forKey:@"sendAuthenticationRequestsToUserServ"];
	[dic setBool:self.sendWhoCommandRequestsToChannels forKey:@"sendWhoCommandRequestsToChannels"];
	[dic setBool:self.setInvisibleModeOnConnect forKey:@"setInvisibleModeOnConnect"];
	[dic setBool:self.validateServerCertificateChain forKey:@"validateServerCertificateChain"];
	[dic setBool:self.zncIgnoreConfiguredAutojoin forKey:@"zncIgnoreConfiguredAutojoin"];
	[dic setBool:self.zncIgnorePlaybackNotifications forKey:@"zncIgnorePlaybackNotifications"];
	[dic setBool:self.zncIgnoreUserNotifications forKey:@"zncIgnoreUserNotifications"];
	[dic setBool:self.zncOnlyPlaybackLatest forKey:@"zncOnlyPlaybackLatest"];

	[dic setUnsignedInteger:self.addressType forKey:@"addressType"];
	[dic setUnsignedInteger:self.cipherSuites forKey:@"cipherSuites"];
	[dic setUnsignedInteger:self.fallbackEncoding forKey:@"fallbackEncoding"];
	[dic setUnsignedInteger:self.floodControlDelayTimerInterval forKey:@"floodControlDelayTimerInterval"];
	[dic setUnsignedInteger:self.floodControlMaximumMessages forKey:@"floodControlMaximumMessages"];
	[dic setUnsignedInteger:self.primaryEncoding forKey:@"primaryEncoding"];
	[dic setUnsignedInteger:self.proxyType forKey:@"proxyType"];

	[dic setUnsignedShort:self.proxyPort forKey:@"proxyPort"];

	/* These are items that cannot be synced over iCloud because they access data specific to 
	 this device or only contain state information which is not useful to other devices. */
	[dic maybeSetObject:self.identityClientSideCertificate forKey:@"identityClientSideCertificate"];

	[dic setBool:self.sidebarItemExpanded forKey:@"sidebarItemExpanded"];

	[dic setDouble:self.lastMessageServerTime forKey:@"cachedLastServerTimeCapabilityReceivedAtTimestamp"];

	/* Deprecated */
	/* These values are inserted here for backwards compatibility 
	 with earlier versions of Textual */
TEXTUAL_IGNORE_DEPRECATION_BEGIN
	[dic setBool:self.connectionPrefersIPv4 forKey:@"connectionPrefersIPv4"];
TEXTUAL_IGNORE_DEPRECATION_END

	[dic setBool:self.legacyConnectionPrefersModernCiphers forKey:@"connectionPrefersModernCiphers"];

	[dic maybeSetObject:self.legacyServerAddress forKey:@"serverAddress"];

	[dic setBool:self.legacyPrefersSecuredConnection forKey:@"prefersSecuredConnection"];

	[dic setUnsignedShort:self.legacyServerPort forKey:@"serverPort"];

	/* During a copy operation, it is faster to copy these arrays as a whole.
	 It also preserves -secretKey value in IRCChannelConfig since that will
	 be lost when reconstructing from dictionary value. */
	if (target == XRPortablePropertyDictTargetCopy ||
		target == XRPortablePropertyDictTargetMutableCopy)
	{
		return [dic copy];
	}

	/* Channel List */
	NSMutableArray<NSDictionary *> *channelListOut = [NSMutableArray array];

	for (IRCChannelConfig *e in self.channelList) {
		NSDictionary *d = e.dictionaryValue;

		[channelListOut addObject:d];
	}

	if (channelListOut.count > 0) {
		dic[@"channelList"] = [channelListOut copy];
	}

	/* Highlight list */
	NSMutableArray<NSDictionary *> *highlightListOut = [NSMutableArray array];

	for (IRCHighlightMatchCondition *e in self.highlightList) {
		NSDictionary *d = e.dictionaryValue;

		[highlightListOut addObject:d];
	}

	if (highlightListOut.count > 0) {
		dic[@"highlightList"] = [highlightListOut copy];
	}

	/* Ignore list */
	NSMutableArray<NSDictionary *> *ignoreListOut = [NSMutableArray array];

	for (IRCAddressBookEntry *e in self.ignoreList) {
		NSDictionary *d = e.dictionaryValue;

		[ignoreListOut addObject:d];
	}

	if (ignoreListOut.count > 0) {
		dic[@"ignoreList"] = [ignoreListOut copy];
	}

	/* Servers */
	NSMutableArray<NSDictionary *> *serverListOut = [NSMutableArray array];

	for (IRCServer *e in self.serverList) {
		NSDictionary *d = e.dictionaryValue;

		[serverListOut addObject:d];
	}

	if (serverListOut.count > 0) {
		dic[@"serverList"] = [serverListOut copy];
	}

	return [dic dictionaryByRemovingDefaults:self->_defaults allowEmptyValues:YES];
}

#pragma mark -
#pragma mark Keychain Management

- (nullable NSString *)nicknamePassword
{
	if (self->_nicknamePassword) {
		return self->_nicknamePassword;
	}

	return self.nicknamePasswordFromKeychain;
}

- (nullable NSString *)nicknamePasswordFromKeychain
{
	return [TLOKeychain passwordOfKind:TLOKeychainItemKindNicknamePassword forIdentifier:self.uniqueIdentifier];
}

- (nullable NSString *)proxyPassword
{
	if (self->_proxyPassword) {
		return self->_proxyPassword;
	}

	return self.proxyPasswordFromKeychain;
}

- (nullable NSString *)proxyPasswordFromKeychain
{
	return [TLOKeychain passwordOfKind:TLOKeychainItemKindProxyPassword forIdentifier:self.uniqueIdentifier];
}

- (void)writeNicknamePasswordToKeychain
{
	if (self->_nicknamePassword == nil) {
		return;
	}

	/* Kept in memory if the Keychain refuses it */
	if ([TLOKeychain setPassword:self->_nicknamePassword ofKind:TLOKeychainItemKindNicknamePassword forIdentifier:self.uniqueIdentifier]) {
		self->_nicknamePassword = nil;
	}
}

- (void)writeProxyPasswordToKeychain
{
	if (self->_proxyPassword == nil) {
		return;
	}

	/* Kept in memory if the Keychain refuses it */
	if ([TLOKeychain setPassword:self->_proxyPassword ofKind:TLOKeychainItemKindProxyPassword forIdentifier:self.uniqueIdentifier]) {
		self->_proxyPassword = nil;
	}
}

- (void)destroyNicknamePasswordKeychainItem
{
	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindNicknamePassword forIdentifier:self.uniqueIdentifier];

	self->_nicknamePassword = nil;
}

- (void)destroyProxyPasswordKeychainItem
{
	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindProxyPassword forIdentifier:self.uniqueIdentifier];

	self->_proxyPassword = nil;
}

- (void)destroyServerPasswordKeychainItemAfterMigration
{
	if (self->_migratedServerPasswordPendingDestroy == NO) {
		return;
	}

	self->_migratedServerPasswordPendingDestroy = NO;

	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindServerPassword forIdentifier:self.uniqueIdentifier];
}

#pragma mark -
#pragma mark Deprecated Properties

- (nullable NSString *)legacyServerAddress
{
	IRCServer *server = self.serverList.firstObject;

	if (server == nil) {
		return self->_serverAddress;
	}

	return server.serverAddress;
}

- (uint16_t)legacyServerPort
{
	IRCServer *server = self.serverList.firstObject;

	if (server == nil) {
		return self->_serverPort;
	}

	return server.serverPort;
}

- (BOOL)legacyPrefersSecuredConnection
{
	IRCServer *server = self.serverList.firstObject;

	if (server == nil) {
		return self->_prefersSecuredConnection;
	}

	return server.prefersSecuredConnection;
}

- (BOOL)legacyConnectionPrefersModernCiphers
{
	return (self.cipherSuites != RCMCipherSuiteCollectionNone);
}

- (BOOL)showConnectionPrefersIPv4Warning
{
TEXTUAL_IGNORE_DEPRECATION_BEGIN
	return (self.addressType == IRCConnectionAddressTypeIPv4 && self.connectionPrefersIPv4);
TEXTUAL_IGNORE_DEPRECATION_END
}

@end

#pragma mark -

@implementation IRCClientConfigMutable

@dynamic addressType;
@dynamic alternateNicknames;
@dynamic autoConnect;
@dynamic autoReconnect;
@dynamic autoSleepModeDisconnect;
@dynamic autojoinWaitsForNickServ;
@dynamic awayNickname;
@dynamic nickServHost;
@dynamic channelList;
@dynamic cipherSuites;
@dynamic connectionName;
@dynamic connectionPrefersIPv4;
@dynamic fallbackEncoding;
@dynamic floodControlDelayTimerInterval;
@dynamic floodControlMaximumMessages;
@dynamic hideAutojoinDelayedWarnings;
@dynamic hideNetworkUnavailabilityNotices;
@dynamic highlightList;
@dynamic identityClientSideCertificate;
@dynamic ignoreList;
@dynamic lastMessageServerTime;
@dynamic loginCommands;
@dynamic nickname;
@dynamic nicknamePassword;
@dynamic normalLeavingComment;
@dynamic performDisconnectOnPongTimer;
@dynamic performDisconnectOnReachabilityChange;
@dynamic performPongTimer;
@dynamic primaryEncoding;
@dynamic proxyAddress;
@dynamic proxyPassword;
@dynamic proxyPort;
@dynamic proxyType;
@dynamic proxyUsername;
@dynamic realName;
@dynamic saslAuthenticationDisableExternalMechanism;
@dynamic sendAuthenticationRequestsToUserServ;
@dynamic sendWhoCommandRequestsToChannels;
@dynamic serverList;
@dynamic setInvisibleModeOnConnect;
@dynamic sidebarItemExpanded;
@dynamic sleepModeLeavingComment;
@dynamic username;
@dynamic validateServerCertificateChain;
@dynamic zncIgnoreConfiguredAutojoin;
@dynamic zncIgnorePlaybackNotifications;
@dynamic zncIgnoreUserNotifications;
@dynamic zncOnlyPlaybackLatest;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [IRCClientConfig self];
}

- (void)setAutoConnect:(BOOL)autoConnect
{
	if (self->_autoConnect != autoConnect) {
		self->_autoConnect = autoConnect;
	}
}

- (void)setAutoReconnect:(BOOL)autoReconnect
{
	if (self->_autoReconnect != autoReconnect) {
		self->_autoReconnect = autoReconnect;
	}
}

- (void)setAutoSleepModeDisconnect:(BOOL)autoSleepModeDisconnect
{
	if (self->_autoSleepModeDisconnect != autoSleepModeDisconnect) {
		self->_autoSleepModeDisconnect = autoSleepModeDisconnect;
	}
}

- (void)setAutojoinWaitsForNickServ:(BOOL)autojoinWaitsForNickServ
{
	if (self->_autojoinWaitsForNickServ != autojoinWaitsForNickServ) {
		self->_autojoinWaitsForNickServ = autojoinWaitsForNickServ;
	}
}

- (void)setConnectionPrefersIPv4:(BOOL)connectionPrefersIPv4
{
	TEXTUAL_DEPRECATED_WARNING

	if (self->_connectionPrefersIPv4 != connectionPrefersIPv4) {
		self->_connectionPrefersIPv4 = connectionPrefersIPv4;
	}
}

- (void)setHideAutojoinDelayedWarnings:(BOOL)hideAutojoinDelayedWarnings
{
	if (self->_hideAutojoinDelayedWarnings != hideAutojoinDelayedWarnings) {
		self->_hideAutojoinDelayedWarnings = hideAutojoinDelayedWarnings;
	}
}

- (void)setHideNetworkUnavailabilityNotices:(BOOL)hideNetworkUnavailabilityNotices
{
	if (self->_hideNetworkUnavailabilityNotices != hideNetworkUnavailabilityNotices) {
		self->_hideNetworkUnavailabilityNotices = hideNetworkUnavailabilityNotices;
	}
}

- (void)setPerformDisconnectOnPongTimer:(BOOL)performDisconnectOnPongTimer
{
	if (self->_performDisconnectOnPongTimer != performDisconnectOnPongTimer) {
		self->_performDisconnectOnPongTimer = performDisconnectOnPongTimer;
	}
}

- (void)setPerformDisconnectOnReachabilityChange:(BOOL)performDisconnectOnReachabilityChange
{
	if (self->_performDisconnectOnReachabilityChange != performDisconnectOnReachabilityChange) {
		self->_performDisconnectOnReachabilityChange = performDisconnectOnReachabilityChange;
	}
}

- (void)setPerformPongTimer:(BOOL)performPongTimer
{
	if (self->_performPongTimer != performPongTimer) {
		self->_performPongTimer = performPongTimer;
	}
}

- (void)setSaslAuthenticationDisableExternalMechanism:(BOOL)saslAuthenticationDisableExternalMechanism
{
	if (self->_saslAuthenticationDisableExternalMechanism != saslAuthenticationDisableExternalMechanism) {
		self->_saslAuthenticationDisableExternalMechanism = saslAuthenticationDisableExternalMechanism;
	}
}

- (void)setSendAuthenticationRequestsToUserServ:(BOOL)sendAuthenticationRequestsToUserServ
{
	if (self->_sendAuthenticationRequestsToUserServ != sendAuthenticationRequestsToUserServ) {
		self->_sendAuthenticationRequestsToUserServ = sendAuthenticationRequestsToUserServ;
	}
}

- (void)setSendWhoCommandRequestsToChannels:(BOOL)sendWhoCommandRequestsToChannels
{
	if (self->_sendWhoCommandRequestsToChannels != sendWhoCommandRequestsToChannels) {
		self->_sendWhoCommandRequestsToChannels = sendWhoCommandRequestsToChannels;
	}
}

- (void)setSetInvisibleModeOnConnect:(BOOL)setInvisibleModeOnConnect
{
	if (self->_setInvisibleModeOnConnect != setInvisibleModeOnConnect) {
		self->_setInvisibleModeOnConnect = setInvisibleModeOnConnect;
	}
}

- (void)setSidebarItemExpanded:(BOOL)sidebarItemExpanded
{
	if (self->_sidebarItemExpanded != sidebarItemExpanded) {
		self->_sidebarItemExpanded = sidebarItemExpanded;
	}
}

- (void)setValidateServerCertificateChain:(BOOL)validateServerCertificateChain
{
	if (self->_validateServerCertificateChain != validateServerCertificateChain) {
		self->_validateServerCertificateChain = validateServerCertificateChain;
	}
}

- (void)setZncIgnoreConfiguredAutojoin:(BOOL)zncIgnoreConfiguredAutojoin
{
	if (self->_zncIgnoreConfiguredAutojoin != zncIgnoreConfiguredAutojoin) {
		self->_zncIgnoreConfiguredAutojoin = zncIgnoreConfiguredAutojoin;
	}
}

- (void)setZncIgnorePlaybackNotifications:(BOOL)zncIgnorePlaybackNotifications
{
	if (self->_zncIgnorePlaybackNotifications != zncIgnorePlaybackNotifications) {
		self->_zncIgnorePlaybackNotifications = zncIgnorePlaybackNotifications;
	}
}

- (void)setZncIgnoreUserNotifications:(BOOL)zncIgnoreUserNotifications
{
	if (self->_zncIgnoreUserNotifications != zncIgnoreUserNotifications) {
		self->_zncIgnoreUserNotifications = zncIgnoreUserNotifications;
	}
}

- (void)setZncOnlyPlaybackLatest:(BOOL)zncOnlyPlaybackLatest
{
	if (self->_zncOnlyPlaybackLatest != zncOnlyPlaybackLatest) {
		self->_zncOnlyPlaybackLatest = zncOnlyPlaybackLatest;
	}
}

- (void)setAddressType:(IRCConnectionAddressType)addressType
{
	if (self->_addressType != addressType) {
		self->_addressType = addressType;
	}
}

- (void)setProxyType:(IRCConnectionProxyType)proxyType
{
	if (self->_proxyType != proxyType) {
		self->_proxyType = proxyType;
	}
}

- (void)setIgnoreList:(NSArray<IRCAddressBookEntry *> *)ignoreList
{
	NSParameterAssert(ignoreList != nil);

	if (self->_ignoreList != ignoreList) {
		self->_ignoreList = [ignoreList copy];
	}
}

- (void)setChannelList:(NSArray<IRCChannelConfig *> *)channelList
{
	NSParameterAssert(channelList != nil);

	if (self->_channelList != channelList) {
		self->_channelList = [channelList copy];
	}
}

- (void)setHighlightList:(NSArray<IRCHighlightMatchCondition *> *)highlightList
{
	NSParameterAssert(highlightList != nil);

	if (self->_highlightList != highlightList) {
		self->_highlightList = [highlightList copy];
	}
}

- (void)setAlternateNicknames:(NSArray<NSString *> *)alternateNicknames
{
	NSParameterAssert(alternateNicknames != nil);

	if (self->_alternateNicknames != alternateNicknames) {
		self->_alternateNicknames = [alternateNicknames copy];
	}
}

- (void)setLoginCommands:(NSArray<NSString *> *)loginCommands
{
	NSParameterAssert(loginCommands != nil);

	if (self->_loginCommands != loginCommands) {
		self->_loginCommands = [loginCommands copy];
	}
}

- (void)setServerList:(NSArray<IRCServer *> *)serverList
{
	NSParameterAssert(serverList != nil);

	if (self->_serverList != serverList) {
		self->_serverList = [serverList copy];
	}
}

- (void)setIdentityClientSideCertificate:(nullable NSData *)identityClientSideCertificate
{
	if (self->_identityClientSideCertificate != identityClientSideCertificate) {
		self->_identityClientSideCertificate = [identityClientSideCertificate copy];
	}
}

- (void)setNickServHost:(nullable NSString *)nickServHost
{
	if (self->_nickServHost != nickServHost) {
		self->_nickServHost = [nickServHost copy];
	}
}

- (void)setAwayNickname:(nullable NSString *)awayNickname
{
	if (self->_awayNickname != awayNickname) {
		self->_awayNickname = [awayNickname copy];
	}
}

- (void)setConnectionName:(NSString *)connectionName
{
	NSParameterAssert(connectionName != nil);

	if (self->_connectionName != connectionName) {
		self->_connectionName = [connectionName copy];
	}
}

- (void)setNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self->_nickname != nickname) {
		self->_nickname = [nickname copy];
	}
}

- (void)setNicknamePassword:(nullable NSString *)nicknamePassword
{
	if (self->_nicknamePassword != nicknamePassword) {
		self->_nicknamePassword = [nicknamePassword copy];
	}
}

- (void)setNormalLeavingComment:(NSString *)normalLeavingComment
{
	NSParameterAssert(normalLeavingComment != nil);

	if (self->_normalLeavingComment != normalLeavingComment) {
		self->_normalLeavingComment = [normalLeavingComment copy];
	}
}

- (void)setProxyAddress:(nullable NSString *)proxyAddress
{
	if (self->_proxyAddress != proxyAddress) {
		self->_proxyAddress = [proxyAddress copy];
	}
}

- (void)setProxyPassword:(nullable NSString *)proxyPassword
{
	if (self->_proxyPassword != proxyPassword) {
		self->_proxyPassword = [proxyPassword copy];
	}
}

- (void)setProxyUsername:(nullable NSString *)proxyUsername
{
	if (self->_proxyUsername != proxyUsername) {
		self->_proxyUsername = [proxyUsername copy];
	}
}

- (void)setRealName:(NSString *)realName
{
	NSParameterAssert(realName != nil);

	if (self->_realName != realName) {
		self->_realName = [realName copy];
	}
}

- (void)setSleepModeLeavingComment:(NSString *)sleepModeLeavingComment
{
	NSParameterAssert(sleepModeLeavingComment != nil);

	if (self->_sleepModeLeavingComment != sleepModeLeavingComment) {
		self->_sleepModeLeavingComment = [sleepModeLeavingComment copy];
	}
}

- (void)setUsername:(NSString *)username
{
	NSParameterAssert(username != nil);

	if (self->_username != username) {
		self->_username = [username copy];
	}
}

- (void)setFallbackEncoding:(NSStringEncoding)fallbackEncoding
{
	if (self->_fallbackEncoding != fallbackEncoding) {
		self->_fallbackEncoding = fallbackEncoding;
	}
}

- (void)setPrimaryEncoding:(NSStringEncoding)primaryEncoding
{
	if (self->_primaryEncoding != primaryEncoding) {
		self->_primaryEncoding = primaryEncoding;
	}
}

- (void)setLastMessageServerTime:(NSTimeInterval)lastMessageServerTime
{
	if (self->_lastMessageServerTime != lastMessageServerTime) {
		self->_lastMessageServerTime = lastMessageServerTime;
	}
}

- (void)setFloodControlDelayTimerInterval:(NSUInteger)floodControlDelayTimerInterval
{
	NSParameterAssert(floodControlDelayTimerInterval >= IRCConnectionConfigFloodControlMinimumDelayInterval &&
					  floodControlDelayTimerInterval <= IRCConnectionConfigFloodControlMaximumDelayInterval);

	if (self->_floodControlDelayTimerInterval != floodControlDelayTimerInterval) {
		self->_floodControlDelayTimerInterval = floodControlDelayTimerInterval;
	}
}

- (void)setFloodControlMaximumMessages:(NSUInteger)floodControlMaximumMessages
{
	NSParameterAssert(floodControlMaximumMessages >= IRCConnectionConfigFloodControlMinimumMessageCount &&
					  floodControlMaximumMessages <= IRCConnectionConfigFloodControlMaximumMessageCount);

	if (self->_floodControlMaximumMessages != floodControlMaximumMessages) {
		self->_floodControlMaximumMessages = floodControlMaximumMessages;
	}
}

- (void)setProxyPort:(uint16_t)proxyPort
{
	if (self->_proxyPort != proxyPort) {
		self->_proxyPort = proxyPort;
	}
}

- (void)setCipherSuites:(RCMCipherSuiteCollection)cipherSuites
{
	if (self->_cipherSuites != cipherSuites) {
		self->_cipherSuites = cipherSuites;
	}
}

@end

NS_ASSUME_NONNULL_END
