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

#import "IRCConnectionConfig.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCAddressBookEntry, IRCChannelConfig, IRCHighlightMatchCondition;
@class IRCNetwork, IRCServer;

#pragma mark -
#pragma mark Immutable Object

@interface IRCClientConfig : XRPortablePropertyDict
@property (readonly) BOOL autoConnect;
@property (readonly) BOOL autoReconnect;
@property (readonly) BOOL autoSleepModeDisconnect;
@property (readonly) BOOL autojoinWaitsForNickServ;
@property (readonly) BOOL hideAutojoinDelayedWarnings;
@property (readonly) BOOL hideNetworkUnavailabilityNotices;
@property (readonly) BOOL performDisconnectOnPongTimer;
@property (readonly) BOOL performDisconnectOnReachabilityChange;
@property (readonly) BOOL performPongTimer;
@property (readonly) BOOL saslAuthenticationDisableExternalMechanism;
@property (readonly) BOOL sendAuthenticationRequestsToUserServ;
@property (readonly) BOOL sendWhoCommandRequestsToChannels;
@property (readonly) BOOL setInvisibleModeOnConnect;
@property (readonly) BOOL sidebarItemExpanded;
@property (readonly) BOOL validateServerCertificateChain;
@property (readonly) BOOL zncIgnoreConfiguredAutojoin;
@property (readonly) BOOL zncIgnorePlaybackNotifications;
@property (readonly) BOOL zncIgnoreUserNotifications;
@property (readonly) BOOL zncOnlyPlaybackLatest;
@property (readonly) IRCConnectionAddressType addressType;
@property (readonly) IRCConnectionProxyType proxyType;
@property (readonly) NSStringEncoding fallbackEncoding;
@property (readonly) NSStringEncoding primaryEncoding;
@property (readonly) NSTimeInterval lastMessageServerTime;
@property (readonly) NSUInteger floodControlDelayTimerInterval;
@property (readonly) NSUInteger floodControlMaximumMessages;
@property (readonly) uint16_t proxyPort;
@property (readonly, copy) NSArray<IRCChannelConfig *> *channelList;
@property (readonly, copy) NSArray<IRCHighlightMatchCondition *> *highlightList;
@property (readonly, copy) NSArray<IRCAddressBookEntry *> *ignoreList;
@property (readonly, copy) NSArray<NSString *> *alternateNicknames;
@property (readonly, copy) NSArray<NSString *> *loginCommands;
@property (readonly, copy) NSArray<IRCServer *> *serverList;
@property (readonly, copy) NSString *connectionName;
@property (readonly, copy) NSString *nickname;
@property (readonly, copy) NSString *normalLeavingComment;
@property (readonly, copy) NSString *realName;
@property (readonly, copy) NSString *sleepModeLeavingComment;
@property (readonly, copy) NSString *uniqueIdentifier;
@property (readonly, copy) NSString *username;
@property (readonly, copy, nullable) NSData *identityClientSideCertificate;
@property (readonly, copy, nullable) NSString *awayNickname;
@property (readonly, copy, nullable) NSString *nicknamePassword;
@property (readonly, copy, nullable) NSString *nickServHost; // Host NickServ must have before the password is sent; nil = built-in host for known networks
@property (readonly, copy, nullable) NSString *nicknamePasswordFromKeychain;
@property (readonly, copy, nullable) NSString *proxyAddress;
@property (readonly, copy, nullable) NSString *proxyPassword;
@property (readonly, copy, nullable) NSString *proxyPasswordFromKeychain;
@property (readonly, copy, nullable) NSString *proxyUsername;
@property (readonly) RCMCipherSuiteCollection cipherSuites;

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dic ignorePrivateMessages:(BOOL)ignorePrivateMessages NS_DESIGNATED_INITIALIZER;

+ (instancetype)newConfigByMerging:(IRCClientConfig *)config1 with:(IRCClientConfig *)config2;

+ (instancetype)newConfigWithNetwork:(IRCNetwork *)network;
@end

#pragma mark -
#pragma mark Mutable Object

@interface IRCClientConfigMutable : IRCClientConfig
@property (nonatomic, assign, readwrite) BOOL autoConnect;
@property (nonatomic, assign, readwrite) BOOL autoReconnect;
@property (nonatomic, assign, readwrite) BOOL autoSleepModeDisconnect;
@property (nonatomic, assign, readwrite) BOOL autojoinWaitsForNickServ;
@property (nonatomic, assign, readwrite) BOOL hideAutojoinDelayedWarnings;
@property (nonatomic, assign, readwrite) BOOL hideNetworkUnavailabilityNotices;
@property (nonatomic, assign, readwrite) BOOL performDisconnectOnPongTimer;
@property (nonatomic, assign, readwrite) BOOL performDisconnectOnReachabilityChange;
@property (nonatomic, assign, readwrite) BOOL performPongTimer;
@property (nonatomic, assign, readwrite) BOOL saslAuthenticationDisableExternalMechanism;
@property (nonatomic, assign, readwrite) BOOL sendAuthenticationRequestsToUserServ;
@property (nonatomic, assign, readwrite) BOOL sendWhoCommandRequestsToChannels;
@property (nonatomic, assign, readwrite) BOOL setInvisibleModeOnConnect;
@property (nonatomic, assign, readwrite) BOOL sidebarItemExpanded;
@property (nonatomic, assign, readwrite) BOOL validateServerCertificateChain;
@property (nonatomic, assign, readwrite) BOOL zncIgnoreConfiguredAutojoin;
@property (nonatomic, assign, readwrite) BOOL zncIgnorePlaybackNotifications;
@property (nonatomic, assign, readwrite) BOOL zncIgnoreUserNotifications;
@property (nonatomic, assign, readwrite) BOOL zncOnlyPlaybackLatest;
@property (nonatomic, assign, readwrite) IRCConnectionAddressType addressType;
@property (nonatomic, assign, readwrite) IRCConnectionProxyType proxyType;
@property (nonatomic, assign, readwrite) NSStringEncoding fallbackEncoding;
@property (nonatomic, assign, readwrite) NSStringEncoding primaryEncoding;
@property (nonatomic, assign, readwrite) NSTimeInterval lastMessageServerTime;
@property (nonatomic, assign, readwrite) NSUInteger floodControlDelayTimerInterval;
@property (nonatomic, assign, readwrite) NSUInteger floodControlMaximumMessages;
@property (nonatomic, assign, readwrite) uint16_t proxyPort;
@property (nonatomic, copy, readwrite) NSArray<IRCChannelConfig *> *channelList;
@property (nonatomic, copy, readwrite) NSArray<IRCHighlightMatchCondition *> *highlightList;
@property (nonatomic, copy, readwrite) NSArray<IRCAddressBookEntry *> *ignoreList;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *alternateNicknames;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *loginCommands;
@property (nonatomic, copy, readwrite) NSArray<IRCServer *> *serverList;
@property (nonatomic, copy, readwrite) NSString *connectionName;
@property (nonatomic, copy, readwrite) NSString *nickname;
@property (nonatomic, copy, readwrite) NSString *normalLeavingComment;
@property (nonatomic, copy, readwrite) NSString *realName;
@property (nonatomic, copy, readwrite) NSString *sleepModeLeavingComment;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy, readwrite, nullable) NSData *identityClientSideCertificate;
@property (nonatomic, copy, readwrite, nullable) NSString *awayNickname;
@property (nonatomic, copy, readwrite, nullable) NSString *nicknamePassword;
@property (nonatomic, copy, readwrite, nullable) NSString *nickServHost;
@property (nonatomic, copy, readwrite, nullable) NSString *proxyAddress;
@property (nonatomic, copy, readwrite, nullable) NSString *proxyPassword;
@property (nonatomic, copy, readwrite, nullable) NSString *proxyUsername;
@property (nonatomic, assign, readwrite) RCMCipherSuiteCollection cipherSuites;
@end

NS_ASSUME_NONNULL_END
