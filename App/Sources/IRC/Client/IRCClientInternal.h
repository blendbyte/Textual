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

@class IRCAddressBookMatchCache, IRCClientRequestedCommands, IRCConnection, IRCMessageBatchMessage, IRCMessageBatchMessageContainer;
@class TDCServerChannelListDialog, TLOFileLogger, TLOTimer;
@class IRCSASLECDSAKey, IRCSASLSCRAM;
@class IRCUserList;
@class IRCBouncerNetworkList;

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
#define _labeledRequestTimeout		300 // a labeled command whose reply never came is forgotten after this many seconds
#define _outgoingMessageTimeout		60 // a message sent with a label whose answer never came is forgotten after this many seconds
#define _outgoingMessageErrorWindow	5 // without labels, an error about a message's target counts this many seconds after it
#define _isonLineMaximumLength		400 // bytes of nicknames per ISON line (lines are limited to 512)

#define _CTCPReplyLimit				5 // replies per _CTCPReplyLimitInterval
#define _CTCPReplyLimitPerSender	2 // replies to one host per _CTCPReplyLimitInterval
#define _CTCPReplyLimitInterval		10

/* labeled-response (IRCClient+LabeledResponse.m): a command typed in a window,
 waiting for its reply */
@interface IRCClientLabeledRequest : NSObject
@property (readonly, copy) NSString *label;
@property (readonly, copy) NSString *command; // uppercase: "WHO", "JOIN", …
@property (readonly, weak, nullable) IRCChannel *channel;
@property (readonly) BOOL toConsole; // typed in the console (or another server's window)
@property (readonly, copy) NSDate *sentAt;

- (instancetype)initWithLabel:(NSString *)label command:(NSString *)command channel:(nullable IRCChannel *)channel;
@end

/* Failed sends (IRCClient+FailedSends.m): a message we sent, until the server
 took it or refused it */
@interface IRCClientOutgoingMessage : NSObject
@property (nonatomic, copy) NSString *target;
@property (nonatomic, copy) NSString *text; // as shown (formatting codes, no CTCP)
@property (nonatomic, copy) NSString *command; // "PRIVMSG" or "NOTICE"
@property (nonatomic, assign) TVCLogLineType lineType;
@property (nonatomic, copy, nullable) NSString *replyToMsgid;
@property (nonatomic, weak, nullable) IRCChannel *channel;
@property (nonatomic, copy) NSDate *sentAt;
@property (nonatomic, copy, nullable) NSString *label; // labeled-response: its answer is matched exactly
@property (nonatomic, assign) BOOL printedLocally; // shown at once (no echo-message)
@property (nonatomic, copy, nullable) NSString *lineNumber; // that line
@property (nonatomic, copy, nullable) NSString *failedReason;
@end

@interface IRCClient ()
{
@protected
	/* Declared here so the categories can change it directly */
	ClientIRCv3SupportedCapability _capabilities;

	/* Capabilities being negotiated and the SASL state (any thread) */
	_Atomic(NSUInteger) _capabilitiesPending;
}

// Properties that are public in IRCClient.h
@property (atomic, copy, readwrite) IRCClientConfig *config; // atomic: renderers read it while joins and parts replace it
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
@property (nonatomic, copy, readwrite, null_resettable) NSString *userNickname; // nil falls back to the configured nickname
@property (nonatomic, copy, readwrite) NSString *serverAddress;
@property (nonatomic, copy, readwrite, nullable) NSString *preAwayUserNickname;
@property (nonatomic, copy, nullable) NSString *awayMessageToRestore; // set by us; sent again after a reconnect
@property (nonatomic, assign) BOOL awayRestoredBeforeRegistration; // draft/pre-away
@property (nonatomic, assign, readwrite) NSUInteger logFileSessionCount;

// Properties private
@property (nonatomic, assign) BOOL configurationIsStale;
@property (nonatomic, strong, nullable) IRCConnection *socket;
@property (nonatomic, strong) IRCMessageBatchMessageContainer *batchMessages;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IRCClientLabeledRequest *> *labeledRequests; // label → request
@property (nonatomic, assign) NSUInteger labeledRequestCount;
@property (nonatomic, assign) NSUInteger labelingDepth; // > 0 while a typed command runs
@property (nonatomic, weak, nullable) IRCChannel *labelingChannel; // its window; nil = the console
@property (nonatomic, strong, nullable) IRCClientLabeledRequest *labeledReplyRequest; // while its reply is processed
@property (nonatomic, assign) BOOL capturingLabel; // the first label given while set goes into capturedLabel
@property (nonatomic, copy, nullable) NSString *capturedLabel;
@property (nonatomic, strong) NSMutableArray<IRCClientOutgoingMessage *> *outgoingMessages; // oldest first
@property (nonatomic, strong, nullable) IRCClientOutgoingMessage *printingOutgoingMessage; // print: takes its reply, failure and line number
@property (nonatomic, weak, nullable) IRCMessageBatchMessage *lastEchoedBatch;
@property (nonatomic, assign) NSUInteger multilineMaxBytes; // draft/multiline limits from the CAP value
@property (nonatomic, assign) NSUInteger multilineMaxLines; // 0: no line limit
@property (nonatomic, assign) NSUInteger multilineBatchCount;
@property (nonatomic, assign) BOOL accountRegistrationRequiresEmail; // draft/account-registration flags from the CAP value
@property (nonatomic, assign) BOOL accountRegistrationAllowsCustomName;
@property (nonatomic, copy, nullable) NSString *accountRegistrationAccount; // a REGISTER sent, until it succeeds or fails
@property (nonatomic, copy, nullable) NSString *accountRegistrationPassword;
@property (nonatomic, copy, nullable) NSString *outgoingReplyMsgidValue; // backs outgoingReplyMsgid
@property (nonatomic, assign) BOOL messageActionsNoteShown; // "This network doesn't pass on replies…", once per connection
@property (nonatomic, strong, nullable) NSImage *networkIconImage; // draft/ICON: the icon shown, from the caches folder or downloaded
@property (nonatomic, copy, nullable) NSString *networkIconSavedAddress; // the address it came from
@property (nonatomic, copy, nullable) NSString *networkIconRequestAddress; // being downloaded
@property (nonatomic, assign) BOOL networkIconLoaded; // the caches folder was read
@property (nonatomic, strong, nullable) NSImage *customIconImage; // config.customIcon, drawn
@property (nonatomic, copy, nullable) NSData *customIconSourceData; // the data it was drawn from
@property (nonatomic, strong, nullable) IRCMessageBatchMessage *netsplitBatch; // while a netsplit or netjoin batch is processed
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *netsplitNicknames; // channel name → who quit or came back
@property (nonatomic, strong, nullable) IRCBouncerNetworkList *bouncerNetworksReceived; // backs bouncerNetworks
@property (nonatomic, strong, nullable) IRCBouncerNetworkList *bouncerNetworksBatchList; // while a soju.im/bouncer-networks batch is processed
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
@property (nonatomic, assign) BOOL clientCertificateMissingAlertShown;
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
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *saslMechanismsToTry; // left to try, in order
@property (nonatomic, copy, nullable) NSString *saslMechanism; // being tried
@property (nonatomic, strong, nullable) IRCSASLSCRAM *saslSCRAM;
@property (nonatomic, strong, nullable) IRCSASLECDSAKey *saslECDSAKey;
@property (nonatomic, assign) NSUInteger saslStep; // of a mechanism with several exchanges
@property (nonatomic, strong, nullable) NSMutableString *saslIncomingData; // an AUTHENTICATE message arriving in 400-byte parts
@property (nonatomic, strong, nullable) NSMutableSet<NSString *> *secretMessageTargets; // folded names sent /SMSG or /SME without a query; their echoes open none
@property (nonatomic, strong) NSMutableSet<NSString *> *chatHistoryPendingTargets; // folded names with an automatic CHATHISTORY request open
@property (nonatomic, copy, nullable) NSDate *chatHistoryDisconnectTime; // when the last connection ended
@property (nonatomic, assign) NSTimeInterval lastAnsweredLagCheckTime; // the "time" of the last /LAGCHECK answered
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

@interface IRCClient (BouncerInternal)
- (BOOL)shouldRequestBouncerCapability:(ClientIRCv3SupportedCapability)capability;
- (nullable NSString *)bouncerSASLUsername; // a server linked to a soju account logs in with the account's, until that succeeded
- (nullable NSString *)bouncerSASLPassword;
- (void)bindBouncerNetworkBeforeRegistration; // right before CAP END
- (void)resetBouncerNetworks;
- (void)receiveBouncer:(IRCMessage *)m;
- (void)processBouncerNetworksBatchMessage:(IRCMessageBatchMessage *)batchMessage;
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
- (void)recursivelyProcessBatchMessage:(IRCMessageBatchMessage *)batchMessage;
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
- (void)printAwayChangeOfUser:(IRCUser *)user toAway:(BOOL)away message:(IRCMessage *)m;
- (void)processStrictTransportSecurityValue:(nullable NSString *)value;

/* Typing notifications (IRCClient+Typing.m) */
- (BOOL)canSendTypingNotificationsToChannel:(IRCChannel *)channel;
- (void)receiveTagmsg:(IRCMessage *)m;
- (void)typingEndedByMessageFrom:(NSString *)nickname inChannel:(IRCChannel *)channel;

/* draft/read-marker (IRCClient+ReadMarker.m) */
- (void)readMarkerNoteMessageAt:(NSDate *)receivedAt inChannel:(IRCChannel *)channel;
- (nullable NSString *)readMarkerRequestForChannel:(IRCChannel *)channel;
- (BOOL)applyReadMarker:(IRCMessage *)m;

/* draft/event-playback: an event (JOIN, QUIT, …) from history as one to print
 only, in the channel the history is for; nil when it was seen live, is ours
 or has nowhere to go; other messages unchanged */
- (nullable IRCMessage *)chatHistoryEventMessage:(IRCMessage *)m;

/* Away kept across reconnects: before registration ends (draft/pre-away) or after */
- (void)restoreAwayStatusBeforeRegistration;
- (void)restoreAwayStatusAfterRegistration;
- (void)receiveMarkRead:(IRCMessage *)m;
+ (nullable NSString *)readMarkerTimestampForDate:(NSDate *)date;

/* draft/chathistory gap-fill (IRCClient+ChatHistory.m) */
- (BOOL)isChatHistoryMessage:(IRCMessage *)m;
- (BOOL)chatHistoryShouldSkipMessage:(IRCMessage *)m inChannel:(IRCChannel *)channel;
- (BOOL)chatHistoryShouldSkipMessage:(IRCMessage *)m inChannel:(IRCChannel *)channel fromHistory:(BOOL)fromHistory;
- (nullable NSString *)chatHistoryRequestForChannel:(IRCChannel *)channel;
- (void)requestChatHistoryForChannel:(IRCChannel *)channel;
- (void)requestChatHistoryForQueries;
- (BOOL)chatHistoryHidesStandardReply:(IRCMessage *)m;
- (void)chatHistoryBatchOpenedForTarget:(nullable NSString *)target;
- (void)receiveStandardReply:(IRCMessage *)m;
- (void)scheduleWhoRequestPass;
- (NSString *)standardReplyText:(IRCMessage *)m;
- (void)receiveAccount:(IRCMessage *)m;
- (void)receiveSetName:(IRCMessage *)m;
- (void)processAccountTagInMessage:(IRCMessage *)m;
- (void)processBotTagInMessage:(IRCMessage *)m; // bot mode: the bot tag marks the sender
- (void)markUserWithNickname:(NSString *)nickname asBot:(BOOL)isBot;

/* A quit or join of a netsplit or netjoin batch: noted for the batch's summary
 line instead of a line of its own */
- (BOOL)collectNetsplitNickname:(NSString *)nickname inChannel:(IRCChannel *)channel forMessage:(IRCMessage *)m;

/* "Netsplit between a and b: alice, bob and 40 others quit" */
+ (NSString *)netsplitSummaryForNicknames:(NSArray<NSString *> *)nicknames servers:(NSArray<NSString *> *)servers joined:(BOOL)joined;

/* +channel-context: the channel a private message to us is about, when we and
 the sender are both in it */
- (nullable IRCChannel *)channelForChannelContextOfMessage:(IRCMessage *)m;
- (void)updateUser:(IRCUserMutable *)userMutable fromExtendedJoin:(IRCMessage *)m;
@end

@interface IRCClient (FailedSendsInternal)
/* A message to channel (shown in it), sent while block runs */
- (IRCClientOutgoingMessage *)outgoingMessageWithText:(NSString *)text target:(NSString *)target command:(NSString *)command lineType:(TVCLogLineType)lineType channel:(IRCChannel *)channel;
- (void)sendOutgoingMessage:(IRCClientOutgoingMessage *)outgoing usingBlock:(void (NS_NOESCAPE ^)(void))block;

/* print: inside block shows outgoing (its reply; the line number is kept) */
- (void)printOutgoingMessage:(IRCClientOutgoingMessage *)outgoing usingBlock:(void (NS_NOESCAPE ^)(void))block;

/* Our message echoed (echo-message) without a label: the oldest to its target is taken */
- (void)outgoingMessageEchoed:(IRCMessage *)m;

/* An error numeric or FAIL: YES when it refused a message of ours, which is
 then shown as not sent (and the reply not printed on its own) */
- (BOOL)outgoingMessageFailedWithReply:(IRCMessage *)m;

- (void)outgoingMessageAnsweredWithLabel:(NSString *)label; // echo or ACK: taken
- (void)removeOutgoingMessages;
@end

@interface IRCClient (LabeledResponseInternal)
/* labeled-response and batch are on: typed commands carry a label */
@property (readonly) BOOL labeledResponsesUsable;

/* Lines sent while block runs carry labels; their replies go to channel (nil: the console) */
- (void)performLabeledCommandFromChannel:(nullable IRCChannel *)channel block:(void (NS_NOESCAPE ^)(void))block;

/* line with a label, if a typed command is sending it; the request is remembered */
- (NSString *)lineByLabelingLine:(NSString *)line;

/* "@label=x CMD", or the label added to the tags already there */
+ (NSString *)line:(NSString *)line withLabel:(NSString *)label;

/* The request a message answers: its own label, or its batch's */
- (nullable IRCClientLabeledRequest *)labeledRequestForMessage:(IRCMessage *)m;

- (void)labeledMessageProcessed:(IRCMessage *)m; // a single reply or ACK: the request is done
- (void)labeledBatchFinished:(IRCMessageBatchMessage *)batch;
- (void)removeLabeledRequests;

/* While a labeled reply is processed: the window its command came from (nil
 for the console); otherwise fallback */
- (nullable IRCChannel *)channelForReplyWithFallback:(nullable IRCChannel *)fallback;
@property (readonly, nullable) IRCChannel *selectedChannelForReplies; // fallback: the selected channel of this server
@property (readonly) BOOL processingLabeledReply;

/* Processing the answer to this command, typed by the user (WHO, ISON, …):
 printed in its window instead of "Hidden Responses" or taken as our own polling */
- (BOOL)processingLabeledReplyToCommand:(NSString *)command;
@property (readonly) BOOL processingLabeledReplyToListCommand; // NAMES, WHO, ISON, WATCH or MONITOR
@end

/* draft/multiline (IRCClient+Multiline.m) */
@interface IRCClientMultilinePart : NSObject
@property (readonly, copy) NSString *text;
@property (readonly) BOOL concat; // joined to the part before without a line break

+ (instancetype)partWithText:(NSString *)text concat:(BOOL)concat;
@end

@interface IRCClient (MultilineInternal)
/* Takes "max-bytes=4096,max-lines=24"; NO (don't request it) without max-bytes */
- (BOOL)processMultilineCapabilityValue:(nullable NSString *)value;

@property (readonly) BOOL multilineUsable;

/* Typed or pasted lines (no commands) for one or more batches within the
 server's limits; nil when they can't go as multi-line messages */
- (nullable NSArray<NSArray<IRCClientMultilinePart *> *> *)multilineBatchesForLines:(NSArray<NSAttributedString *> *)lines target:(NSString *)target lineType:(TVCLogLineType)lineType;

/* Packs parts into batches of at most maxBytes (text and line breaks) and maxLines (0: any) */
+ (NSArray<NSArray<IRCClientMultilinePart *> *> *)multilineBatchesOfParts:(NSArray<IRCClientMultilinePart *> *)parts maxBytes:(NSUInteger)maxBytes maxLines:(NSUInteger)maxLines;

/* "line one\nline two" from the parts as a receiver puts them together */
+ (NSString *)multilineTextOfParts:(NSArray<IRCClientMultilinePart *> *)parts;

- (void)sendMultilineBatch:(NSArray<IRCClientMultilinePart *> *)parts command:(NSString *)command target:(NSString *)target replyTo:(nullable NSString *)replyMsgid;

/* A received draft/multiline batch as the one message it stands for */
- (nullable IRCMessage *)messageCombiningMultilineBatch:(IRCMessageBatchMessage *)batch;
@end

/* draft/account-registration (IRCClient+AccountRegistration.m) */
typedef NS_ENUM(NSUInteger, IRCClientAccountRegistrationProblem) {
	IRCClientAccountRegistrationProblemNone = 0,
	IRCClientAccountRegistrationProblemSyntax,
	IRCClientAccountRegistrationProblemEmailRequired,
	IRCClientAccountRegistrationProblemCustomNameNotAllowed
};

@interface IRCClient (AccountRegistrationInternal)
- (void)processAccountRegistrationCapabilityValue:(nullable NSString *)value;

/* /register's arguments ([account] <email or *> <password>) as REGISTER's
 parameters, or nil with the problem */
+ (nullable NSArray<NSString *> *)accountRegistrationParametersForArguments:(NSArray<NSString *> *)arguments nickname:(NSString *)nickname requiresEmail:(BOOL)requiresEmail allowsCustomName:(BOOL)allowsCustomName problem:(IRCClientAccountRegistrationProblem *)problem;

- (void)registerAccountWithArguments:(NSArray<NSString *> *)arguments;
- (void)verifyAccountWithArguments:(NSArray<NSString *> *)arguments;

- (void)receiveAccountRegistrationReply:(IRCMessage *)m;
- (void)noteAccountRegistrationStandardReply:(IRCMessage *)m;
@end

/* draft/ICON (IRCClient+NetworkIcon.m) */
@interface IRCClient (NetworkIconInternal)
/* The address with {size} filled in; nil unless it's HTTPS */
+ (nullable NSURL *)networkIconURLForAddress:(NSString *)address pixelSize:(NSUInteger)pixelSize;

- (void)updateNetworkIcon; // after each ISUPPORT line
- (void)finishNetworkIconAfterRegistration; // at the end of the MOTD
- (void)removeNetworkIconFile;
@end

@interface IRCClient (CapabilitiesInternal) <IRCCapabilityNegotiatorDelegate>
- (void)resetCapabilities;
@property (readonly, copy) NSString *saslUsername;
- (void)disablePendingCapability:(ClientIRCv3SupportedCapability)capability;
- (BOOL)isPendingCapabilityEnabled:(ClientIRCv3SupportedCapability)capability;
- (void)resetSASLNegotiation;
- (BOOL)sendNextSASLMechanism;
- (void)receiveSASLMechanismList:(NSString *)mechanisms;
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
- (void)processBundlesUserMessage:(NSString *)message command:(NSString *)command inChannel:(nullable IRCChannel *)channel;
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
