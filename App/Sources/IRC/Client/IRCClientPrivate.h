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

#import "TLONotificationController.h"
#import "IRCClient.h"

NS_ASSUME_NONNULL_BEGIN

@class TLOSpokenNotification;
@class IRCAddressBookUserTrackingContainer, IRCTimedCommand, IRCUserMutable;

enum {
	ClientIRCv3SupportedCapabilitySASLGeneric			= 1 << 22,
	ClientIRCv3SupportedCapabilitySASLPlainText			= 1 << 23, // YES if SASL=plain CAP is supported
	ClientIRCv3SupportedCapabilitySASLExternal			= 1 << 24, // YES if SASL=external CAP is supported
	ClientIRCv3SupportedCapabilityZNCServerTime			= 1 << 25, // YES if the ZNC vendor specific CAP supported
	ClientIRCv3SupportedCapabilityZNCServerTimeISO		= 1 << 26, // YES if the ZNC vendor specific CAP supported
	/* 1 << 27 is ClientIRCv3SupportedCapabilityZNCPlaybackModule (IRCClient.h, which has the bit allocation table) */
	ClientIRCv3SupportedCapabilityPlanioPlayback		= 1 << 28  // YES if the plan.io vendor specific CAP supported.
};

@interface IRCClient ()
@property (nonatomic, copy, nullable) dispatch_block_t disconnectCallback;
@property (nonatomic, assign, readwrite) IRCClientConnectMode connectType;
@property (nonatomic, assign, readwrite) IRCClientDisconnectMode disconnectType;
@property (nonatomic, assign) BOOL sidebarItemIsExpanded;
@property (nonatomic, copy, readwrite) NSArray<IRCChannel *> *channelList;
@property (nonatomic, weak, readwrite) IRCChannel *lastSelectedChannel;

- (instancetype)initWithConfig:(IRCClientConfig *)config NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithConfigDictionary:(NSDictionary<NSString *, id> *)dic;

- (void)updateConfig:(IRCClientConfig *)config;
- (void)updateConfig:(IRCClientConfig *)config updateSelection:(BOOL)updateSelection;

- (NSDictionary<NSString *, id> *)configurationDictionary;

- (void)addChannel:(IRCChannel *)channel;
- (void)addChannel:(IRCChannel *)channel atPosition:(NSUInteger)position;

/* Window → Sort Channel List's order: channels before private messages, by name */
+ (NSComparisonResult)compareChannel:(IRCChannel *)channel1 toChannel:(IRCChannel *)channel2;

- (BOOL)sortChannelList; // NO when already sorted
- (void)moveChannelToSortedPosition:(IRCChannel *)channel; // a renamed query, with "Keep channel list sorted" on

- (void)removeChannel:(IRCChannel *)channel; // This only removes the channel from channel array. Use world controller to properly destroy a channel.

- (void)channelNameChanged; // A query was renamed; drops the name lookup map

- (NSUInteger)indexOfChannel:(IRCChannel *)channel;

- (void)selectFirstChannelInChannelList;

- (void)reloadServerListItems;

- (void)updateStoredChannelList;

- (void)cacheHighlightInChannel:(IRCChannel *)channel withLogLine:(TVCLogLine *)logLine;

/* Joined channels (not queries) the nickname is in too */
- (NSArray<IRCChannel *> *)channelsSharedWithNickname:(NSString *)nickname;

- (void)updateQueryInfoBarsForNickname:(nullable NSString *)nickname;

- (void)noteReachabilityChanged:(BOOL)reachable;

- (IRCAddressBookUserTrackingContainer *)trackedUsers;
@end

@interface IRCClient (NotificationsPrivate)
- (void)postEventToViewController:(NSString *)eventToken;
- (void)postEventToViewController:(NSString *)eventToken forChannel:(IRCChannel *)channel;

- (nullable NSString *)formatNotificationToSpeak:(TLOSpokenNotification *)notification;

/* draft/read-marker: tells the server a channel being viewed is read up to its newest message */
- (void)markChannelAsRead:(IRCChannel *)channel;

/* Typing notifications, from the input field */
- (void)typingInputChanged:(NSString *)text inChannel:(IRCChannel *)channel;
- (void)sendTypingDoneToChannel:(IRCChannel *)channel;
- (void)sendTypingPausedToChannel:(IRCChannel *)channel;
- (void)typingMessageSentInChannel:(IRCChannel *)channel;
+ (nullable NSString *)typingIndicatorTextForNicknames:(NSArray<NSString *> *)nicknames;

/* For print completion blocks: the message was printed, so the output rules already passed */
- (BOOL)notifyPrintedText:(TXNotificationType)eventType lineType:(TVCLogLineType)lineType target:(IRCChannel *)target nickname:(NSString *)nickname text:(NSString *)text;

/* A highlight; the keyword that matched picks its own sound, if it has one */
- (BOOL)notifyHighlightText:(NSString *)text lineType:(TVCLogLineType)lineType target:(IRCChannel *)target nickname:(NSString *)nickname keyword:(nullable NSString *)keyword;
@end

@interface IRCClient (UsersPrivate)
- (IRCUserMutable *)mutableCopyOfUserWithNickname:(NSString *)nickname;

- (void)modifyUser:(IRCUser *)user withBlock:(void (NS_NOESCAPE ^)(IRCUserMutable *userMutable))block;
- (void)modifyUserUserWithNickname:(NSString *)nickname withBlock:(void (NS_NOESCAPE ^)(IRCUserMutable *userMutable))block;

/* An address book ignore entry for this person turns off previews of their
 links. Main thread (the match cache isn't thread safe). */
- (BOOL)ignoresInlineMediaFromNickname:(NSString *)nickname;

/* "Don't Preview Links from …": on sets it on the one ignore entry
 that matches the person, or adds an entry that only does this; off clears
 it, removing entries that did nothing else */
- (void)setIgnoresInlineMedia:(BOOL)ignoresInlineMedia fromNickname:(NSString *)nickname;
@end

@interface IRCClient (MutePrivate)
/* A channel, query or (the client itself) the whole network: no
 notifications or sounds; highlights per a preference. Saved; the row dims. */
- (BOOL)isTreeItemMuted:(IRCTreeItem *)item;
- (void)setMuted:(BOOL)muted forTreeItem:(IRCTreeItem *)item;
@end

@interface IRCClient (SendingPrivate)
/* +reply: set around sending what was typed, so its first message
 answers this message ID (and a line printed locally shows it) */
@property (nonatomic, copy, nullable) NSString *outgoingReplyMsgid;

@property (readonly) BOOL canSendReplies; // message-tags, and the server doesn't deny +reply

- (void)updateMessageActionsInViews; // the views' Reply, React, Delete follow the connection

- (void)inputText:(id)string destination:(IRCTreeItem *)destination;

- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command;
- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command destination:(IRCTreeItem *)destination;
@end

@interface IRCClient (CommandsPrivate)
/* Run the block with this client once it has disconnected (it replaces any
 block set before); a deleted client runs nothing */
- (void)afterDisconnectPerform:(void (^)(IRCClient *client))block;
- (void)disconnectThen:(void (^)(IRCClient *client))block;
- (void)quitThen:(void (^)(IRCClient *client))block;

- (void)autoConnectWithDelay:(NSUInteger)delay afterWakeUp:(BOOL)afterWakeUp;
@end

@interface IRCClient (LoggingPrivate)
- (void)reopenLogFileIfNeeded;
- (void)closeLogFile;

- (void)print:(NSString *)messageBody by:(nullable NSString *)nickname inChannel:(nullable IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command escapeMessage:(BOOL)escapeMessage;

- (void)printGeneralEvent:(NSString *)messageBody aboutNicknames:(NSArray<NSString *> *)nicknames inChannel:(IRCChannel *)channel asType:(TVCLogLineType)lineType command:(NSString *)command receivedAt:(NSDate *)receivedAt;

- (void)logFileRecordSessionChanged:(BOOL)toNewSession inChannel:(nullable IRCChannel *)channel;

/* modeSymbol nil: the member's current one in the channel */
- (NSString *)formatNickname:(NSString *)nickname inChannel:(nullable IRCChannel *)channel withFormat:(nullable NSString *)format modeSymbol:(nullable NSString *)modeSymbol;
@end

@interface IRCClient (ReceiveCommandsPrivate)
- (id)queuedBatchMessageWithToken:(NSString *)batchToken;

+ (nullable NSString *)knownNickServHostForServerAddress:(nullable NSString *)serverAddress;
@end

@interface IRCClient (CapabilitiesPrivate)
- (void)enableCapability:(ClientIRCv3SupportedCapability)capability;
- (void)disableCapability:(ClientIRCv3SupportedCapability)capability;
@end

@interface IRCClient (DCCPrivate)
- (void)sendFile:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken;
- (void)sendFileResume:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken;
- (void)sendFileResumeAccept:(NSString *)nickname port:(uint16_t)port filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken;

- (void)notifyFileTransfer:(TXNotificationType)type nickname:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize requestIdentifier:(NSString *)identifier;
@end

@interface IRCClient (NetworkIconPrivate)
/* The icon in front of the server's name in the server list, 16 points:
 the one chosen in Server Properties, else the network's (draft/ICON); nil for none */
@property (readonly, nullable) NSImage *networkIcon;

@property (readonly, nullable) NSImage *networkProvidedIcon; // draft/ICON only

/* A picture as config.customIcon (a PNG square, see-through parts on white); nil if it isn't one */
+ (nullable NSData *)customIconDataFromImageData:(NSData *)data;

+ (nullable NSImage *)serverListIconWithData:(NSData *)data; // 16 points
@end

/* Reactions (IRCClient+Reactions.m) */
@interface IRCClient (ReactionsPrivate)
@property (readonly) BOOL canSendReactions; // message-tags, and the server doesn't deny +draft/react

/* An emoji (or other short text) as a reaction: nil when empty, too long, or with a line break */
+ (nullable NSString *)validatedReaction:(nullable id)value;

- (BOOL)receiveReactionTagmsg:(IRCMessage *)m; // NO when it isn't a reaction

- (void)sendReaction:(NSString *)reaction toMessage:(NSString *)msgid inChannel:(IRCChannel *)channel removing:(BOOL)removing;

/* After registration: why Reply and React are missing on this network, once */
- (void)noteUnavailableMessageActions;

/* Deleting: draft/message-redaction */
@property (readonly) BOOL canDeleteMessages;

- (void)receiveRedact:(IRCMessage *)m;

- (void)deleteMessage:(NSString *)msgid inChannel:(IRCChannel *)channel;
@end

@class TLOUploadDestination;

/* File uploads (IRCClient+FileUpload.m): one file to the network's upload address */
@interface IRCFileUpload : NSObject
@property (readonly, copy) NSString *filePath;
@property (readonly, copy) NSString *fileName;
@property (readonly, copy) NSURL *address;
@property (readonly) double progress; // 0 to 1, of sending
@property (readonly, copy, nullable) NSURL *link; // once uploaded
@property (readonly, copy, nullable) NSString *failureReason; // nil and no link: cancelled
@property (nonatomic, copy, nullable) void (^progressBlock)(IRCFileUpload *upload);

- (void)startWithCompletionBlock:(void (^)(IRCFileUpload *upload))completionBlock; // on the main thread
- (void)cancel;

+ (NSString *)contentDispositionForFileName:(NSString *)fileName;
+ (nullable NSURL *)linkFromLocation:(nullable NSString *)location relativeToAddress:(NSURL *)address;

/* A copy without location, camera and capture details (the orientation stays); nil if not a picture */
+ (nullable NSURL *)copyOfImageWithoutMetadataAtURL:(NSURL *)url inFolder:(NSURL *)folder;
+ (BOOL)imageHasMetadataAtURL:(NSURL *)url;
@end

@interface IRCClient (FileUploadPrivate)
@property (readonly, copy, nullable) NSURL *fileUploadAddress; // the network's (draft/FILEHOST), if this connection may use it

/* The login only goes to the server's own domain: irc.example.org → example.org and *.example.org */
+ (BOOL)uploadHost:(NSString *)uploadHost sharesDomainWithHost:(NSString *)serverHost;

/* "Basic …" for a password login (PLAIN, SCRAM) to an HTTPS address on the server's domain; otherwise nil */
+ (nullable NSString *)fileUploadAuthorizationForAddress:(NSURL *)address
											  serverHost:(nullable NSString *)serverHost
											   mechanism:(nullable NSString *)mechanism
												username:(nullable NSString *)username
												password:(nullable NSString *)password;

- (nullable IRCFileUpload *)fileUploadForPath:(NSString *)path; // nil without an upload address

/* The network's, else the user's own (the server's choice, or the one in Preferences) */
@property (readonly) BOOL fileUploadsAvailable;
@property (readonly) BOOL customUploadDestinationConfigured; // without reading the Keychain
@property (readonly, copy, nullable) TLOUploadDestination *customUploadDestination; // with its tokens
@property (readonly, copy, nullable) NSString *fileUploadDestinationDescription; // "files.example.org (offered by the network)"

/* Long pastes as a link: where file uploads go, else dpaste.com if turned on (not where uploads are off) */
- (nullable IRCFileUpload *)textUploadForPath:(NSString *)path;
@property (readonly, copy, nullable) NSString *textUploadDestinationDescription;
@end

/* Failed sends (IRCClient+FailedSends.m) */
@interface IRCClient (FailedSendsPrivate)
/* Resend on a message the server refused: NO when it can't be sent now */
- (BOOL)resendFailedLine:(TVCLogLine *)logLine inChannel:(IRCChannel *)channel;
@end

@interface IRCClient (TimedCommandsPrivate)
- (void)onTimedCommand:(IRCTimedCommand *)timedCommand;
@end

NS_ASSUME_NONNULL_END
