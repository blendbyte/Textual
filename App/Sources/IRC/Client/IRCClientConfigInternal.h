/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "IRCClientConfigPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientConfig ()
{
@protected
	BOOL _autoConnect;
	BOOL _autoReconnect;
	BOOL _autoSleepModeDisconnect;
	BOOL _autojoinWaitsForNickServ;
	BOOL _connectionPrefersIPv4;
	BOOL _hideAutojoinDelayedWarnings;
	BOOL _hideNetworkUnavailabilityNotices;
	BOOL _performDisconnectOnPongTimer;
	BOOL _performDisconnectOnReachabilityChange;
	BOOL _performPongTimer;
	BOOL _prefersSecuredConnection;
	BOOL _saslAuthenticationDisableExternalMechanism;
	BOOL _sendAuthenticationRequestsToUserServ;
	BOOL _sendWhoCommandRequestsToChannels;
	BOOL _setInvisibleModeOnConnect;
	BOOL _sidebarItemExpanded;
	BOOL _validateServerCertificateChain;
	BOOL _zncIgnoreConfiguredAutojoin;
	BOOL _zncIgnorePlaybackNotifications;
	BOOL _zncIgnoreUserNotifications;
	BOOL _zncOnlyPlaybackLatest;
	IRCConnectionAddressType _addressType;
	IRCConnectionProxyType _proxyType;
	NSArray<IRCAddressBookEntry *> *_ignoreList;
	NSArray<IRCChannelConfig *> *_channelList;
	NSArray<IRCHighlightMatchCondition *> *_highlightList;
	NSArray<NSString *> *_alternateNicknames;
	NSArray<NSString *> *_loginCommands;
	NSArray<IRCServer *> *_serverList;
	NSData *_identityClientSideCertificate;
	NSString *_awayNickname;
	NSString *_connectionName;
	NSString *_nickname;
	NSString *_nicknamePassword;
	NSString *_nickServHost;
	NSString *_normalLeavingComment;
	NSString *_proxyAddress;
	NSString *_proxyPassword;
	NSString *_proxyUsername;
	NSString *_realName;
	NSString *_saslECDSAKey;
	NSString *_serverAddress;
	NSString *_sleepModeLeavingComment;
	NSString *_username;
	NSStringEncoding _fallbackEncoding;
	NSStringEncoding _primaryEncoding;
	NSTimeInterval _lastMessageServerTime;
	NSUInteger _floodControlDelayTimerInterval;
	NSUInteger _floodControlMaximumMessages;
	uint16_t _proxyPort;
	uint16_t _serverPort;
	RCMCipherSuiteCollection _cipherSuites;

@private
	BOOL _migratedServerPasswordPendingDestroy;
	NSUInteger _dictionaryVersion;
	NSString *_uniqueIdentifier;
	NSDictionary *_defaults;
}

@end

NS_ASSUME_NONNULL_END
