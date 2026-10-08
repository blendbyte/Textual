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

#include <stdatomic.h>

#import "IRCAddressBook.h"
#import "IRCClientPrivate.h"
#import "IRCCapabilityNegotiatorPrivate.h"
#import "IRCISupportInfo.h"

@class IRCAddressBookMatchCache, IRCClientRequestedCommands, IRCConnection, IRCMessageBatchMessageContainer;
@class TDCServerChannelListDialog, TLOFileLogger, TLOTimer;
@class IRCUserList;

NS_ASSUME_NONNULL_BEGIN

/* Shared by IRCClient.m and its category files (IRCClient+*.m) only */

#define _autojoinDelayedWarningInterval		90 // max delay after identification is 10 so keep this above that
#define _autojoinDelayedWarningMaxCount		3

#define _isonCheckInterval			30
#define _pingInterval				270
#define _pongCheckInterval			30
#define _reconnectInterval			20
#define _retryInterval				240
#define _timeoutInterval			360
#define _whoCheckInterval			120
#define _batchFlushTimeout			60 // a batch that never closes is processed after this many seconds
#define _isonLineMaximumLength		400 // bytes of nicknames per ISON line (lines are limited to 512)

#define _CTCPReplyLimit				5 // replies per _CTCPReplyLimitInterval
#define _CTCPReplyLimitPerSender	2 // replies to one host per _CTCPReplyLimitInterval
#define _CTCPReplyLimitInterval		10

@interface IRCClient ()
{
@protected
	/* Declared here so the categories can change it directly */
	ClientIRCv3SupportedCapability _capabilities;

	/* Capabilities being negotiated and the SASL state (any thread) */
	_Atomic(NSUInteger) _capabilitiesPending;
}

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
@property (nonatomic, assign) BOOL invokingISONCommandForFirstTime;
@property (nonatomic, assign) BOOL isTerminating; // Is being destroyed
@property (nonatomic, assign) BOOL inWhoisResponse;
@property (nonatomic, assign) BOOL inWhowasResponse;
@property (nonatomic, assign) BOOL reconnectEnabled;
@property (nonatomic, assign) BOOL reconnectEnabledBecauseOfSleepMode;
@property (nonatomic, assign) BOOL timeoutWarningShownToUser;
@property (nonatomic, assign) BOOL zncBouncerIsSendingCertificateInfo;
@property (nonatomic, assign) BOOL zncBouncerIsPlayingBackHistory;
@property (nonatomic, strong) IRCCapabilityNegotiator *capabilityNegotiator;
@property (nonatomic, copy, nullable) dispatch_block_t terminationCallback; // run on disconnect instead of disconnectCallback; only termination sets it
@property (nonatomic, strong) NSMutableArray<NSString *> *isonReplyNicknames; // online nicknames of a hidden ISON request so far
@property (nonatomic, assign) NSUInteger connectDelay;
@property (nonatomic, assign) NSUInteger lastServerSelected;
@property (nonatomic, assign) NSUInteger lastWhoRequestChannelListIndex;
@property (nonatomic, assign) NSUInteger successfulConnects;
@property (nonatomic, assign) NSUInteger tryingNicknameNumber;
@property (nonatomic, assign) NSUInteger autojoinDelayedWarningCount;
@property (nonatomic, copy, nullable) NSString *tryingNicknameSentNickname;
@property (nonatomic, strong) NSMutableArray<IRCChannel *> *channelListPrivate;
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, IRCChannel *> *channelMap; // folded name → channel; nil until needed, guarded by channelListPrivate
@property (nonatomic, assign) IRCISupportInfoCaseMapping channelMapCaseMapping;
@property (nonatomic, strong, nullable) NSMutableArray<IRCChannel *> *channelsToAutojoin;
@property (nonatomic, strong) IRCAddressBookMatchCache *addressBookMatchCache;
@property (nonatomic, strong) IRCAddressBookUserTrackingContainer *trackedUsers;
@property (nonatomic, strong) IRCClientRequestedCommands *requestedCommands;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IRCTimedCommand *> *timedCommands;
@property (nonatomic, strong, nullable) IRCUserList *knownUsers;
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
- (BOOL)messageIsFromMyself:(IRCMessage *)message;
- (void)printReplyToHiddenCommandResponsesQuery:(IRCMessage *)message;
- (void)createHiddenCommandResponses;
- (BOOL)stringIsChannelNameOrZero:(NSString *)string;
- (TDCFileTransferDialog *)fileTransferController;
- (void)removeRequestedCommands;
@end

@interface IRCClient (NotificationsInternal)
- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCChannel *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text;
- (void)clearEventsToSpeak;
- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType;
- (BOOL)notifyEvent:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(null_unspecified IRCChannel *)target nickname:(null_unspecified NSString *)nickname text:(null_unspecified NSString *)text userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;
- (BOOL)notifyText:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(IRCChannel *)target nickname:(NSString *)nickname text:(NSString *)text;
@end

@interface IRCClient (ZNCInternal)
- (void)zncPlaybackClearChannel:(IRCChannel *)channel;
- (BOOL)isSafeToPostNotificationForMessage:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel;
- (void)requestPlayback;
- (void)updateConnectedToZNCPropertyWithMessage:(IRCMessage *)message;
@end

@interface IRCClient (UsersInternal)
- (void)clearAddressBookCache;
- (void)resetAwayStatusForUsers;
- (IRCUser *)addUserAndReturn:(IRCUser *)user;
- (nullable IRCAddressBookEntry *)findAddressBookEntryForHostmask:(NSString *)hostmask;
- (nullable IRCAddressBookEntry *)findUserTrackingAddressBookEntryForNickname:(NSString *)nickname;
- (void)modifyUser:(IRCUser *)user asAway:(BOOL)away;
- (void)modifyUserWithNickname:(NSString *)nickname asAway:(BOOL)away;
- (void)renameUser:(IRCUser *)user to:(NSString *)toNickname;
- (void)clearAddressBookCacheForHostmask:(NSString *)hostmask;
@end

@interface IRCClient (UserTrackingInternal)
- (void)clearTrackedUsers;
- (void)onISONTimer;
- (void)onWhoTimer;
- (void)populateISONTrackedUsersList;
- (void)stopISONTimer;
- (void)statusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus notify:(BOOL)notify;
- (void)updateUserTrackingStatusForEntry:(IRCAddressBookEntry *)addressBookEntry withMessage:(IRCMessage *)message;
- (void)updateUserTrackingStatusForEntry:(IRCAddressBookEntry *)addressBookEntry nickname:(NSString *)nickname withMessage:(IRCMessage *)message;
@end

@interface IRCClient (SendingInternal)
- (void)sendTextLine:(NSAttributedString *)line asCommand:(NSString *)command lineType:(TVCLogLineType)lineType toDestination:(NSString *)destinationName printIn:(nullable IRCChannel *)channel printAsCommand:(NSString *)printCommand;
@end

@interface IRCClient (CommandsInternal)
- (void)sendIsonForNicknames:(NSArray<NSString *> *)nicknames hideResponse:(BOOL)hideResponse;
- (void)sendWhoToChannel:(IRCChannel *)channel hideResponse:(BOOL)hideResponse;
- (void)disconnect;
- (void)sendPassword:(NSString *)password;
- (void)joinUnlistedChannelsWithStringAndSelectBestMatch:(NSString *)channels passwords:(nullable NSString *)passwords;
- (void)toggleAwayStatusWithComment:(nullable NSString *)comment;
- (void)joinUnlistedChannelsAndSelectBestMatch:(NSArray<NSString *> *)channels;
- (void)sendCapabilityAuthenticate:(NSString *)data;
- (void)joinKickedChannel:(IRCChannel *)channel;
@end

@interface IRCClient (LoggingInternal)
- (void)endLoggingSessions;
- (void)printError:(NSString *)errorMessage asCommand:(NSString *)command;
- (void)rawDataLogIncomingTraffic:(NSString *)data;
- (void)printReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel;
- (void)printErrorReply:(IRCMessage *)message;
- (void)printReply:(IRCMessage *)message;
- (void)printUnknownReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel;
- (void)createRawDataLogQuery;
- (void)destroyRawDataLogQuery;
- (void)printDebugInformationMultiline:(NSString *)message;
- (void)printErrorReply:(IRCMessage *)message inChannel:(nullable IRCChannel *)channel withSequence:(NSUInteger)sequence;
- (void)printUnknownReply:(IRCMessage *)message;
- (void)rawDataLogOutgoingTraffic:(NSString *)data;
@end

@interface IRCClient (ConnectionInternal)
- (void)processIncomingMessage:(IRCMessage *)message;
@end

@interface IRCClient (ReceiveCommandsInternal)
- (BOOL)filterBatchCommandIncomingData:(IRCMessage *)m;
- (void)receiveBatch:(IRCMessage *)m;
- (void)receiveError:(IRCMessage *)m;
- (void)receiveInvite:(IRCMessage *)m;
- (void)receiveJoin:(IRCMessage *)m;
- (void)receiveKick:(IRCMessage *)m;
- (void)receiveKill:(IRCMessage *)m;
- (void)receiveMode:(IRCMessage *)m;
- (void)receiveNick:(IRCMessage *)m;
- (void)receivePart:(IRCMessage *)m;
- (void)receivePrivmsgAndNotice:(IRCMessage *)m;
- (void)receiveQuit:(IRCMessage *)m;
- (void)receiveTopic:(IRCMessage *)m;
- (void)receiveWallops:(IRCMessage *)m;
- (void)receiveCertInfo:(IRCMessage *)m;
- (void)receiveChangeHost:(IRCMessage *)m;
- (void)receiveAccount:(IRCMessage *)m;
- (void)receiveSetName:(IRCMessage *)m;
- (void)processAccountTagInMessage:(IRCMessage *)m;
- (void)updateUser:(IRCUserMutable *)userMutable fromExtendedJoin:(IRCMessage *)m;
@end

@interface IRCClient (CapabilitiesInternal) <IRCCapabilityNegotiatorDelegate>
- (void)resetCapabilities;
- (void)disablePendingCapability:(ClientIRCv3SupportedCapability)capability;
- (BOOL)isPendingCapabilityEnabled:(ClientIRCv3SupportedCapability)capability;
- (void)resetSASLNegotiation;
- (void)resumeCapabilityNegotiation;
- (void)receiveCapabilityOrAuthenticationRequest:(IRCMessage *)m;
@end

@interface IRCClient (NumericsInternal)
- (void)receiveAwayNotifyCapability:(IRCMessage *)m;
- (void)receiveNumericReply:(IRCMessage *)m;
- (void)receivePing:(IRCMessage *)m;
@end

@interface IRCClient (AutojoinInternal)
- (void)onAutojoinDelayedWarningTimer;
- (void)onAutojoinNextJoinTimer;
- (void)onAutojoinTimer;
- (void)onPongTimer;
- (void)onReconnectTimer;
- (void)onRetryTimer;
- (void)startReconnectTimer;
- (void)startRetryTimer;
- (void)stopAutojoinDelayedWarningTimer;
- (void)stopAutojoinNextJoinTimer;
- (void)stopAutojoinTimer;
- (void)stopPongTimer;
- (void)stopRetryTimer;
- (void)performAutoJoin;
- (void)startAutojoinDelayedWarningTimer;
- (void)startPongTimer;
- (void)performAutoJoinInitiatedByUser:(BOOL)initiatedByUser;
- (void)stopReconnectTimer;
@end

@interface IRCClient (ScriptsInternal)
- (void)processBundlesUserMessage:(NSString *)message command:(NSString *)command;
- (BOOL)postReceivedCommand:(NSString *)command withText:(nullable NSString *)text destinedFor:(nullable IRCChannel *)textDestination referenceMessage:(IRCMessage *)referenceMessage;
- (BOOL)postReceivedMessage:(IRCMessage *)referenceMessage;
- (BOOL)postReceivedMessage:(IRCMessage *)referenceMessage withText:(nullable NSString *)text destinedFor:(nullable IRCChannel *)textDestination;
- (void)executeTextualCmdScriptInContext:(NSDictionary<NSString *, NSString *> *)context;
- (void)processBundlesServerMessage:(IRCMessage *)message;
@end

@interface IRCClient (DCCInternal)
- (void)receivedDCCQuery:(IRCMessage *)m text:(NSString *)text ignoreInfo:(nullable IRCAddressBookEntry *)ignoreInfo;
@end

@interface IRCClient (TimedCommandsInternal)
- (void)removeTimedCommands;
- (void)stopTimedCommand:(IRCTimedCommand *)timedCommand;
- (nullable IRCTimedCommand *)timedCommandWithIdentifier:(NSString *)identifier;
- (void)addTimedCommand:(IRCTimedCommand *)timedCommand;
- (NSString *)descriptionForTimedCommand:(IRCTimedCommand *)timedCommand;
- (NSArray<IRCTimedCommand *> *)listOfTimedCommands;
- (void)removeTimedCommand:(IRCTimedCommand *)timedCommand;
- (BOOL)restartTimedCommand:(IRCTimedCommand *)timedCommand;
- (void)startTimedCommand:(IRCTimedCommand *)timedCommand interval:(NSUInteger)timerInterval onRepeat:(BOOL)repeatTimer iterations:(NSUInteger)iterations;
@end

@interface IRCClient (DialogsInternal)
- (nullable TDCServerChannelListDialog *)channelListDialog;
@end

NS_ASSUME_NONNULL_END
