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

#import "TDCSharedProtocolDefinitionsPrivate.h"
#import "TDCFileTransferDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, TDCFileTransferDialogTableCell;

@interface TDCFileTransferDialogTransferController : NSObject <TDCClientPrototype>
@property (nonatomic, weak) TDCFileTransferDialogTableCell *transferTableCell;

@property (readonly) BOOL isResume;
@property (readonly) BOOL isReversed;
@property (readonly) BOOL isSender;
@property (readonly) TDCFileTransferDialogTransferStatus transferStatus;
@property (readonly) uint64_t totalFilesize;
@property (readonly) uint64_t processedFilesize;
@property (readonly) uint64_t currentRecord;
@property (readonly, copy) NSArray<NSNumber *> *speedRecords;
@property (readonly, copy, nullable) NSString *errorMessageDescription;
@property (readonly, copy, nullable) NSString *path;
@property (readonly, copy) NSString *filename;
@property (readonly, copy, nullable) NSString *filePath;
@property (readonly, copy, nullable) NSURL *fileURL;
@property (readonly, copy) NSString *hostAddress;
@property (readonly, copy) NSString *peerNickname;
@property (readonly, copy, nullable) NSString *transferToken;
@property (readonly, copy) NSString *uniqueIdentifier;
@property (readonly) uint16_t hostPort;
@property (getter=isActingAsClient, readonly) BOOL actingAsClient;
@property (getter=isActingAsServer, readonly) BOOL actingAsServer;

/* Sending or receiving data */
@property (readonly) BOOL isActive;
/* Set up and waiting for the peer: listening, connecting, or waiting for a reply */
@property (readonly) BOOL isAwaitingPeer;
/* Not started, stopped, complete or failed */
@property (readonly) BOOL isStopped;

- (BOOL)isWithClient:(IRCClient *)client peer:(NSString *)nickname;

/* A file name offered by a peer, safe to create in the download folder */
+ (NSString *)filenameForOfferedFilename:(NSString *)filename;

/* Downloads are recorded while incomplete so that only Textual's own partial
 downloads from the same peer are ever resumed. */
+ (void)recordPartialDownloadAtPath:(NSString *)path clientIdentifier:(NSString *)clientIdentifier peer:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize;
+ (void)forgetPartialDownloadAtPath:(NSString *)path;
+ (BOOL)fileAtPath:(NSString *)path isPartialDownloadForClientIdentifier:(NSString *)clientIdentifier peer:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize;

+ (nullable instancetype)receiverForClient:(IRCClient *)client
								  nickname:(NSString *)nickname
								   address:(NSString *)hostAddress
									  port:(uint16_t)hostPort
								  filename:(NSString *)filename
								  filesize:(uint64_t)totalFilesize
									 token:(nullable NSString *)transferToken;

+ (nullable instancetype)senderForClient:(IRCClient *)client
								nickname:(NSString *)nickname
									path:(NSString *)path;

- (instancetype)init NS_UNAVAILABLE;

- (void)open;
- (void)openWithPathOrUserDownloads;
- (void)openWithPath:(nullable NSString *)path; // Only changes path if self.path == nil

- (void)close;
- (void)closeAndPostNotification:(BOOL)postNotification;

- (void)sendTransferRequestToClient;

- (void)noteIPAddressLookupFailed;
- (void)noteIPAddressLookupSucceeded;

- (void)didReceiveSendRequest:(NSString *)hostAddress hostPort:(uint16_t)hostPort;

- (void)didReceiveResumeAccept:(uint64_t)proposedPosition;
- (void)didReceiveResumeRequest:(uint64_t)proposedPosition;

- (void)onMaintenanceTimer;

- (void)updateClearButton;

- (void)reloadStatusInformation;
@end

NS_ASSUME_NONNULL_END
