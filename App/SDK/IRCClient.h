/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import "IRCCommandIndex.h"
#import "IRCConnection.h"
#import "IRCTreeItem.h"
#import "TVCLogController.h"
#import "TVCLogLine.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCChannel, IRCClientConfig, IRCHighlightLogEntry, IRCISupportInfo;
@class IRCAddressBookEntry, IRCMessage, IRCServer, IRCUser;

typedef NS_ENUM(NSUInteger, IRCClientConnectMode) {
	IRCClientConnectModeNormal = 0,
	IRCClientConnectModeRetry,
	IRCClientConnectModeReconnect,
};

typedef NS_ENUM(NSUInteger, IRCClientDisconnectMode) {
	IRCClientDisconnectModeNormal = 0,
	IRCClientDisconnectModeComputerSleep,
	IRCClientDisconnectModeBadCertificate,
	IRCClientDisconnectModeReachabilityChange,
	IRCClientDisconnectModeServerRedirect
};

typedef NS_OPTIONS(NSUInteger, ClientIRCv3SupportedCapability) {
	ClientIRCv3SupportedCapabilityAwayNotify			= 1 << 0, // YES if away-notify CAP supported
	ClientIRCv3SupportedCapabilityBatch					= 1 << 1, // YES if batch CAP supported
	ClientIRCv3SupportedCapabilityEchoMessage			= 1 << 2, // YES if echo-message CAP supported
	ClientIRCv3SupportedCapabilityIdentifyCTCP			= 1 << 3, // YES if identify-ctcp CAP supported
	ClientIRCv3SupportedCapabilityIdentifyMsg			= 1 << 4, // YES if identify-msg CAP supported
	ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL	= 1 << 5, // YES if SASL authentication was successful
	ClientIRCv3SupportedCapabilityIsInSASLNegotiation	= 1 << 6, // YES if in SASL CAP authentication request
	ClientIRCv3SupportedCapabilityMonitorCommand		= 1 << 7, // YES if the MONITOR command is supported
	ClientIRCv3SupportedCapabilityMultiPrefix			= 1 << 8, // YES if multi-prefix CAP supported
	ClientIRCv3SupportedCapabilityPlayback				= 1 << 9, // Special CAP which is subject to change
	ClientIRCv3SupportedCapabilityServerTime			= 1 << 10, // YES if server-time CAP supported
	ClientIRCv3SupportedCapabilityUserhostInNames		= 1 << 11, // YES if userhost-in-names CAP supported
	ClientIRCv3SupportedCapabilityWatchCommand			= 1 << 12, // YES if the WATCH command is supported
	ClientIRCv3SupportedCapabilityZNCCertInfoModule		= 1 << 13, // YES if the ZNC vendor specific CAP supported
	ClientIRCv3SupportedCapabilityZNCSelfMessage		= 1 << 14, // YES if the ZNC vendor specific CAP supported
	ClientIRCv3SupportedCapabilityChangeHost			= 1 << 15, // YES if the CHGHOST CAP supported
	ClientIRCv3SupportedCapabilityZNCPlaybackModule		= 1 << 27  // YES if the ZNC vendor specific CAP supported
};

TEXTUAL_EXTERN NSNotificationName const IRCClientConfigurationWasUpdatedNotification;

TEXTUAL_EXTERN NSNotificationName const IRCClientChannelListWasModifiedNotification;

TEXTUAL_EXTERN NSNotificationName const IRCClientWillConnectNotification;
TEXTUAL_EXTERN NSNotificationName const IRCClientDidConnectNotification;

TEXTUAL_EXTERN NSNotificationName const IRCClientWillSendQuitNotification;
TEXTUAL_EXTERN NSNotificationName const IRCClientWillDisconnectNotification;
TEXTUAL_EXTERN NSNotificationName const IRCClientDidDisconnectNotification;

TEXTUAL_EXTERN NSNotificationName const IRCClientUserNicknameChangedNotification;

@interface IRCClient : IRCTreeItem <IRCConnectionDelegate>
@property (readonly, copy) IRCClientConfig *config;
@property (readonly, copy, nullable) IRCServer *server; // Where is being connected to. Use -serverAddress for server address connected to.
@property (readonly) IRCISupportInfo *supportInfo;
@property (readonly) IRCClientConnectMode connectType;
@property (readonly) IRCClientDisconnectMode disconnectType;
@property (readonly) BOOL isAutojoined;					// YES if autojoin has completed
@property (readonly) BOOL isAutojoining;				// YES if autojoin is in progress
@property (readonly) BOOL isConnecting;					// YES if socket is connecting. Set to NO on raw numeric 001.
@property (readonly) BOOL isConnected;					// YES if socket is connected
@property (readonly) BOOL isConnectedToZNC;				// YES if Textual detected that this connection is ZNC
@property (readonly) BOOL isLoggedIn;					// YES if logged into server. Set to YES on raw numeric 001.
@property (readonly) BOOL isQuitting;					// YES if socket is disconnecting
@property (readonly) BOOL isReconnecting;				// YES if reconnect is pending
@property (readonly) BOOL isSecured;					// YES if socket is connected using SSL/TLS
@property (readonly) BOOL userIsAway;					// YES if local user is away
@property (readonly) BOOL userIsIRCop;					// YES if local user is IRCop
@property (readonly) BOOL userIsIdentifiedWithNickServ; // YES if NickServ identification was successful
@property (readonly) BOOL isWaitingForNickServ;			// YES if NickServ identification is pending
@property (readonly) BOOL serverHasNickServ;			// YES if NickServ service was found on server
@property (readonly) NSTimeInterval lastMessageReceived;			// The time at which the last of any incoming data was received
@property (readonly) NSTimeInterval lastMessageServerTime;			// The time of the last message received that contained a server-time CAP
@property (readonly) NSUInteger channelCount;
@property (readonly, weak) IRCChannel *lastSelectedChannel; // If this is the selected client, then the value of this property is the current selection. If the current client is not selected, then this value is either its previous selection or nil.
@property (readonly, weak) TVCLogLine *lastLine; // Last line in the server console. There is no guarantee it's visible to the user when accessed.
@property (readonly, copy) NSArray<IRCChannel *> *channelList;
@property (readonly, copy) NSArray<IRCHighlightLogEntry *> *cachedHighlights;
@property (readonly, copy, nullable) NSString *userHostmask; // The hostmask of the local user
@property (readonly, copy) NSString *userNickname; // The nickname of the local user
@property (readonly, copy, nullable) NSString *serverAddress; // The address of the server connected to or nil
@property (readonly, copy, nullable) NSString *networkName; // The name of the network connected to or nil
@property (readonly, copy) NSString *networkNameAlt; // The name of the network connected to or the configured Connection Name
@property (readonly, copy, nullable) NSString *preAwayUserNickname; // Nickname before away was set or nil
@property (readonly, copy, nullable) NSData *zncBouncerCertificateChainData;
@property (readonly) NSUInteger logFileSessionCount; // Number of lines sent to server console log file for session (from connect to disconnect)

- (instancetype)init NS_UNAVAILABLE;

- (void)connect;
- (void)connect:(IRCClientConnectMode)connectMode;
- (void)connect:(IRCClientConnectMode)connectMode bypassProxy:(BOOL)bypassProxy;

- (void)quit;
- (void)quitWithComment:(NSString *)comment;

- (void)cancelReconnect;

@property (readonly) ClientIRCv3SupportedCapability capacities;
@property (readonly, copy) NSString *enabledCapacitiesStringValue;

- (BOOL)isCapabilitySupported:(NSString *)capabilityString;

- (BOOL)isCapabilityEnabled:(ClientIRCv3SupportedCapability)capability;

- (void)joinChannel:(IRCChannel *)channel;
- (void)joinChannel:(IRCChannel *)channel password:(nullable NSString *)password;
- (void)joinChannels:(NSArray<IRCChannel *> *)channels;
- (void)joinUnlistedChannel:(NSString *)channel;
- (void)joinUnlistedChannel:(NSString *)channel password:(nullable NSString *)password;
- (void)forceJoinChannel:(NSString *)channel password:(nullable NSString *)password;

- (void)partChannel:(IRCChannel *)channel;
- (void)partChannel:(IRCChannel *)channel withComment:(nullable NSString *)comment;
- (void)partUnlistedChannel:(NSString *)channel;
- (void)partUnlistedChannel:(NSString *)channel withComment:(nullable NSString *)comment;

- (void)changeNickname:(NSString *)newNickname;

- (void)kick:(NSString *)nickname inChannel:(IRCChannel *)channel;

- (void)sendCTCPQuery:(NSString *)nickname command:(NSString *)command text:(nullable NSString *)text;
- (void)sendCTCPReply:(NSString *)nickname command:(NSString *)command text:(nullable NSString *)text;
- (void)sendCTCPPing:(NSString *)nickname;

- (void)sendWhois:(NSString *)nickname;

- (void)sendWhoToChannel:(IRCChannel *)channel;
- (void)sendWhoToChannelNamed:(NSString *)channel;

- (void)toggleAwayStatus:(BOOL)setAway;
- (void)toggleAwayStatus:(BOOL)setAway withComment:(nullable NSString *)comment;

- (void)requestModesForChannel:(IRCChannel *)channel;
- (void)requestModesForChannelNamed:(NSString *)channel;

- (void)sendModes:(nullable NSString *)modeSymbols withParameters:(nullable NSArray<NSString *> *)parameters inChannel:(IRCChannel *)channel;
- (void)sendModes:(nullable NSString *)modeSymbols withParametersString:(nullable NSString *)parametersString inChannel:(IRCChannel *)channel;

- (void)sendModes:(nullable NSString *)modeSymbols withParameters:(nullable NSArray<NSString *> *)parameters inChannelNamed:(NSString *)channel;
- (void)sendModes:(nullable NSString *)modeSymbols withParametersString:(nullable NSString *)parametersString inChannelNamed:(NSString *)channel;

- (void)sendPing:(NSString *)tokenString;
- (void)sendPong:(NSString *)tokenString;

- (void)sendInviteTo:(NSString *)nickname toJoinChannel:(IRCChannel *)channel;
- (void)sendInviteTo:(NSString *)nickname toJoinChannelNamed:(NSString *)channel;

- (void)requestTopicForChannel:(IRCChannel *)channel;
- (void)requestTopicForChannelNamed:(NSString *)channel;

- (void)sendTopicTo:(nullable NSString *)topic inChannel:(IRCChannel *)channel;
- (void)sendTopicTo:(nullable NSString *)topic inChannelNamed:(NSString *)channel;

- (void)sendCapability:(NSString *)subcommand data:(nullable NSString *)data;

- (void)sendIsonForNicknames:(NSArray<NSString *> *)nicknames;

- (void)modifyWatchListBy:(BOOL)adding nicknames:(NSArray<NSString *> *)nicknames;

- (void)requestChannelList;

- (NSArray<NSString *> *)compileListOfModeChangesForModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet parameterString:(NSString *)parameterString;
- (NSArray<NSString *> *)compileListOfModeChangesForModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet parameterString:(NSString *)parameterString characterSet:(NSCharacterSet *)characterList;

- (NSArray<NSString *> *)compileListOfModeChangesForModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet modeParameters:(NSArray<NSString *> *)modeParameters;

- (void)createChannelListDialog;
- (void)createChannelInviteExceptionListSheet;
- (void)createChannelBanExceptionListSheet;
- (void)createChannelBanListSheet;
- (void)createChannelQuietListSheet;

- (void)presentCertificateTrustInformation;

- (void)closeDialogs;

#pragma mark -

- (BOOL)userExists:(NSString *)nickname;

- (nullable IRCUser *)findUser:(NSString *)nickname;
- (IRCUser *)findUserOrCreate:(NSString *)nickname;

@property (readonly) NSUInteger numberOfUsers;

@property (readonly, copy) NSArray<IRCUser *> *userList;

- (void)addUser:(IRCUser *)user;

- (void)removeUser:(IRCUser *)user;
- (void)removeUserWithNickname:(NSString *)nickname;

@property (readonly, nullable) IRCUser *myself;

- (NSArray<IRCAddressBookEntry *> *)findIgnoresForHostmask:(NSString *)hostmask;

#pragma mark -

- (nullable IRCChannel *)findChannel:(NSString *)withName;
- (nullable IRCChannel *)findChannelOrCreate:(NSString *)withName;
- (nullable IRCChannel *)findChannelOrCreate:(NSString *)withName isPrivateMessage:(BOOL)isPrivateMessage;

/* A utility window is a private message that is never sent to the server:
 a place for a plugin to log its own messages (Chat Filter's "Filter Actions") */
- (nullable IRCChannel *)findChannelOrCreate:(NSString *)withName isUtility:(BOOL)isUtility;

- (nullable NSData *)convertToCommonEncoding:(NSString *)string;
- (nullable NSString *)convertFromCommonEncoding:(NSData *)data;

- (NSString *)formatNickname:(NSString *)nickname inChannel:(nullable IRCChannel *)channel;
- (NSString *)formatNickname:(NSString *)nickname inChannel:(nullable IRCChannel *)channel withFormat:(nullable NSString *)format;

- (BOOL)nicknameIsZNCUser:(NSString *)nickname;
- (BOOL)nickname:(NSString *)nickname isZNCUser:(NSString *)zncNickname;
- (nullable NSString *)nicknameAsZNCUser:(NSString *)nickname; // Returns nil if not connected to ZNC

- (BOOL)nicknameIsMyself:(NSString *)nickname;

- (BOOL)stringIsNickname:(NSString *)string;
- (BOOL)stringIsChannelName:(NSString *)string;

- (BOOL)outputRuleMatchedInMessage:(NSString *)message inChannel:(nullable IRCChannel *)channel;

#pragma mark -

- (void)setUnreadStateForChannel:(IRCChannel *)channel;
- (void)setUnreadStateForChannel:(IRCChannel *)channel isHighlight:(BOOL)isHighlight;

- (void)setHighlightStateForChannel:(IRCChannel *)channel;

#pragma mark -

- (void)sendCommand:(id)string;
- (void)sendCommand:(id)string completeTarget:(BOOL)completeTarget target:(nullable NSString *)targetChannelName;

- (void)sendCommand:(NSString *)command toZNCModuleNamed:(NSString *)module;

- (void)sendText:(NSAttributedString *)string asCommand:(IRCRemoteCommand)command toChannel:(IRCChannel *)channel;
- (void)sendText:(NSAttributedString *)string asCommand:(IRCRemoteCommand)command toChannel:(IRCChannel *)channel withEncryption:(BOOL)encryptText TEXTUAL_DEPRECATED("Textual no longer encrypts messages. Use -sendText:asCommand:toChannel: instead");

- (void)sendLine:(NSString *)string;
- (void)send:(NSString *)string, ...;

- (void)sendPrivmsg:(NSString *)message toChannel:(IRCChannel *)channel; // Invoke -sendText: with proper values
- (void)sendAction:(NSString *)message toChannel:(IRCChannel *)channel;
- (void)sendNotice:(NSString *)message toChannel:(IRCChannel *)channel;

#pragma mark -

// nil channel prints the message to the server console
// referenceMessage.command is used if command == nil
// referenceMessage and command cannot be nil together (this throws exceptions)
- (void)		print:(NSString *)messageBody
				   by:(nullable NSString *)nickname
			inChannel:(nullable IRCChannel *)channel
			   asType:(TVCLogLineType)lineType
			  command:(nullable NSString *)command
		   receivedAt:(NSDate *)receivedAt
		  isEncrypted:(BOOL)isEncrypted
		escapeMessage:(BOOL)escapeMessage
	 referenceMessage:(nullable IRCMessage *)referenceMessage
	  completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock;

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command;
- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command receivedAt:(NSDate *)receivedAt;
- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted;
- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted referenceMessage:(nullable IRCMessage *)referenceMessage;
- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(nullable NSString *)command receivedAt:(NSDate *)receivedAt isEncrypted:(BOOL)isEncrypted referenceMessage:(nullable IRCMessage *)referenceMessage completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock;

- (void)printDebugInformationToConsole:(NSString *)message;
- (void)printDebugInformationToConsole:(NSString *)message asCommand:(NSString *)command;

- (void)printDebugInformation:(NSString *)message;
- (void)printDebugInformation:(NSString *)message asCommand:(NSString *)command;

- (void)printDebugInformation:(NSString *)message inChannel:(IRCChannel *)channel;
- (void)printDebugInformation:(NSString *)message inChannel:(IRCChannel *)channel asCommand:(NSString *)command;

#pragma mark -

- (void)clearCachedHighlights;

/* -config may not always reflect the current state of the client.
 * This is because its too costly to mutate it for stuff that changes
 * many times a second. The client instead saves a copy of its
 * configuration periodically. This method will force it to perform
 * a save if you need to rely on most recent version. */
- (void)updateStoredConfiguration;
@end

NS_ASSUME_NONNULL_END
