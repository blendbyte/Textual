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

#include <sys/stat.h>

#import "NSObjectHelperPrivate.h"
#import "GCDAsyncSocket.h"
#import "TXGlobalModels.h"
#import "IRCClientPrivate.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaultsPrivate.h"
#import "TLOEncryptionManagerPrivate.h"
#import "TLOLocalization.h"
#import "TDCFileTransferDialogTableCellPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCFileTransferDialogInternal.h"

NS_ASSUME_NONNULL_BEGIN

#define RECORDS_LENGTH  10
#define MAX_QUEUE_SIZE  2
#define BUFFER_SIZE	 (1024 * 64)
#define RATE_LIMIT	  (1024 * 1024 * 10)

#define _connectTimeout			30.0
#define _sendDataTimeout		30.0
#define _readDataTimeout		120.0
#define _resumeAcceptTimeout	10.0
#define _peerResponseTimeout	600.0 // To accept an offer or connect to the listening port

/* Textual's own unfinished downloads, by path: the file (device and inode)
 and the transfer it belongs to. */
static NSString * const _partialDownloadsDefaultsKey = @"File Transfers -> Partial Downloads";

/* Files are only ever looked at with stat(). Reading extended attributes (as
 -attributesOfItemAtPath: does) of a file another app created can block the
 sandboxed app indefinitely (seen on macOS 27 with com.apple.macl). */
static BOOL _statFileAtPath(NSString *path, struct stat *fileInfo)
{
	return (stat(path.fileSystemRepresentation, fileInfo) == 0 && S_ISREG(fileInfo->st_mode));
}

/* Size of a regular file, or 0 if there is none */
static uint64_t _sizeOfFileAtPath(NSString *path)
{
	struct stat fileInfo;

	if (_statFileAtPath(path, &fileInfo) == NO) {
		return 0;
	}

	return (uint64_t)fileInfo.st_size;
}

/* Identifies the file itself, so that a file replaced under the same name doesn't match */
static NSString * _Nullable _identityOfFileAtPath(NSString *path)
{
	struct stat fileInfo;

	if (_statFileAtPath(path, &fileInfo) == NO) {
		return nil;
	}

	return [NSString stringWithFormat:@"%lld:%llu", (long long)fileInfo.st_dev, (unsigned long long)fileInfo.st_ino];
}

@interface TDCFileTransferDialogTransferController ()
@property (nonatomic, strong, readwrite) IRCClient *client;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, assign, readwrite) BOOL isResume;
@property (nonatomic, assign, readwrite) BOOL isReversed;
@property (nonatomic, assign, readwrite) BOOL isSender;
@property (nonatomic, assign, readwrite) TDCFileTransferDialogTransferStatus transferStatus;
@property (nonatomic, assign, readwrite) uint64_t totalFilesize;
@property (nonatomic, assign, readwrite) uint64_t processedFilesize;
@property (nonatomic, assign, readwrite) uint64_t currentRecord;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *speedRecordsPrivate;
@property (nonatomic, copy, readwrite, nullable) NSString *errorMessageDescription;
@property (nonatomic, copy, readwrite, nullable) NSString *path;
@property (nonatomic, copy, readwrite) NSString *filename;
@property (nonatomic, copy, readwrite) NSString *hostAddress;
@property (nonatomic, copy, readwrite) NSString *peerNickname;
@property (nonatomic, copy, readwrite, nullable) NSString *transferToken;
@property (nonatomic, copy, readwrite) NSString *uniqueIdentifier;
@property (nonatomic, assign, readwrite) uint16_t hostPort;
@property (nonatomic, strong, nullable) NSFileHandle *fileHandle;
@property (nonatomic, strong, nullable) XRPortMapper *portMapping;
@property (nonatomic, assign) NSUInteger sendQueueSize;
@property (nonatomic, strong, nullable) dispatch_queue_t serverDispatchQueue;
@property (nonatomic, strong, nullable) dispatch_queue_t serverSocketQueue;
@property (nonatomic, strong, nullable) GCDAsyncSocket *listeningServer;
@property (nonatomic, strong, nullable) GCDAsyncSocket *listeningServerConnectedClient;
@property (nonatomic, strong, nullable) GCDAsyncSocket *connectionToRemoteServer;
@property (nonatomic, strong, nullable) id transferProgressHandler; // Used to prevent system sleep
@property (atomic, assign) NSUInteger peerResponseTimeoutGeneration; // Changes on close, so older timeouts do nothing
@property (readonly) uint64_t currentFilesize;
@property (readonly) TDCFileTransferDialog *transferDialog;
@property (readonly, nullable) GCDAsyncSocket *readSocket;
@property (readonly, nullable) GCDAsyncSocket *writeSocket;
@end

@implementation TDCFileTransferDialogTransferController

#pragma mark -
#pragma mark Initialization

+ (nullable instancetype)receiverForClient:(IRCClient *)client nickname:(NSString *)nickname address:(NSString *)hostAddress port:(uint16_t)hostPort filename:(NSString *)filename filesize:(uint64_t)totalFilesize token:(nullable NSString *)transferToken
{
	NSParameterAssert(client != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(hostAddress != nil);
	NSParameterAssert(filename != nil);

	/* Construct controller */
	TDCFileTransferDialogTransferController *controller = [[self alloc] initWithClient:client];

	if (transferToken.length > 0) {
		controller.transferToken = transferToken;

		controller.isReversed = YES;
	}

	controller.isSender = NO;

	controller.peerNickname = nickname;

	controller.hostAddress = hostAddress;
	controller.hostPort = hostPort;

	controller.filename = filename;

	controller.totalFilesize = totalFilesize;

	return controller;
}

+ (nullable instancetype)senderForClient:(IRCClient *)client nickname:(NSString *)nickname path:(NSString *)path
{
	NSParameterAssert(client != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(path != nil);

	NSString *filename = path.lastPathComponent;

#if TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION == 1
	if ([TPCPreferences textEncryptionIsEnabled]) {
		/* Ask whether we should be allowed to add the file. */
		BOOL allowWithOTR = [sharedEncryptionManager()
							 safeToTransferFile:filename
											 to:[client encryptionAccountNameForUser:nickname]
										   from:[client encryptionAccountNameForLocalUser]
						 isIncomingFileTransfer:NO];

		if (allowWithOTR == NO) {
			return nil; // This operation is not allowed...
		}
	}
#endif

	/* Gather file information */
	uint64_t totalFilesize = _sizeOfFileAtPath(path);

	if (totalFilesize == 0) {
		LogToConsoleError("Fatal error: Cannot create sender because filesize == 0");

		return nil;
	}

	NSString *filePath = path.stringByDeletingLastPathComponent;

	/* Construct controller */
	TDCFileTransferDialogTransferController *controller = [[self alloc] initWithClient:client];

	controller.isReversed = [TPCPreferences fileTransferRequestsAreReversed];

	controller.isSender = YES;

	controller.peerNickname = nickname;

	controller.path = filePath;
	controller.filename = filename;

	controller.totalFilesize = totalFilesize;

	return controller;
}

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.speedRecordsPrivate = [NSMutableArray array];

	self.transferStatus = TDCFileTransferDialogTransferStatusStopped;

	self.uniqueIdentifier = [NSString stringWithUUID];

	[RZNotificationCenter() addObserver:self selector:@selector(clientDisconnected:) name:IRCClientDidDisconnectNotification object:self.client];
	[RZNotificationCenter() addObserver:self selector:@selector(peerNicknameChanged:) name:IRCClientUserNicknameChangedNotification object:self.client];
}

- (void)prepareForPermanentDestruction
{
	self.transferTableCell = nil;

	[self closeAndPostNotification:NO];

	[RZNotificationCenter() removeObserver:self];
}

#pragma mark -
#pragma mark Error Handling

- (void)failWithNoSpaceLeftOnDevice
{
	[self closeWithLocalizedError:@"TDCFileTransferDialog[79f-s0]"];
}

- (void)closeWithLocalizedError:(NSString *)errorLocalization
{
	[self closeWithLocalizedError:errorLocalization description:nil isFatalError:NO];
}

- (void)closeWithLocalizedError:(NSString *)errorLocalization isFatalError:(BOOL)isFatalError
{
	[self closeWithLocalizedError:errorLocalization description:nil isFatalError:isFatalError];
}

- (void)closeWithLocalizedError:(NSString *)errorLocalization description:(nullable NSString *)errorDescription
{
	[self closeWithLocalizedError:errorLocalization description:errorDescription isFatalError:NO];
}

- (void)closeWithLocalizedError:(NSString *)errorLocalization description:(nullable NSString *)errorDescription isFatalError:(BOOL)isFatalError
{
	NSParameterAssert(errorLocalization != nil);

	if (errorDescription == nil) {
		self.errorMessageDescription = TXTLS(errorLocalization, self.peerNickname);
	} else {
		self.errorMessageDescription = TXTLS(errorLocalization, self.peerNickname, errorDescription);
	}

	if (isFatalError) {
		self.transferStatus = TDCFileTransferDialogTransferStatusFatalError;
	} else {
		self.transferStatus = TDCFileTransferDialogTransferStatusRecoverableError;
	}

	[self close];
}

#pragma mark -
#pragma mark Dispatch Queue Management

- (void)createDispatchQueues
{
	NSString *uniqueId = [NSString stringWithUUID];

	NSString *dispatchQueueName = [NSString stringWithFormat:@"Textual.TDCFileTransferDialogTransferController.DCC-SocketDispatchQueue-%@", uniqueId];

	self.serverDispatchQueue =
	XRCreateDispatchQueueWithPriority(dispatchQueueName.UTF8String, DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT);

	NSString *socketQueueName = [NSString stringWithFormat:@"Textual.TDCFileTransferDialogTransferController.DCC-SocketReadWriteQueue-%@", uniqueId];

	self.serverSocketQueue =
	XRCreateDispatchQueueWithPriority(socketQueueName.UTF8String, DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT);
}

- (void)destroyDispatchQueues
{
	self.serverDispatchQueue = nil;

	self.serverSocketQueue = nil;
}

#pragma mark -
#pragma mark Opening/Closing Transfer

- (void)disableSystemSleep
{
	self.transferProgressHandler = [RZProcessInfo() beginActivityWithOptions:NSActivityUserInitiated reason:@"Transferring file"];
}

- (void)enableSystemSleep
{
	if (self.transferProgressHandler == nil) {
		return;
	}

	[RZProcessInfo() endActivity:self.transferProgressHandler];

	self.transferProgressHandler = nil;
}

- (BOOL)receiveUnencryptedFile
{
#if TEXTUAL_BUILT_WITH_ADVANCED_ENCRYPTION == 1
	if ([TPCPreferences textEncryptionIsEnabled]) {
		BOOL allowWithOTR = [sharedEncryptionManager()
							 safeToTransferFile:self.filename
											 to:[self.client encryptionAccountNameForUser:self.peerNickname]
										   from:[self.client encryptionAccountNameForLocalUser]
						 isIncomingFileTransfer:YES];

		if (allowWithOTR == NO) {
			return NO; // This operation is not allowed...
		}
	}
#endif

	return YES;
}

- (void)open
{
	[self openWithPath:nil];
}

- (void)openWithPathOrUserDownloads
{
	NSString *path = nil;

	if (self.path == nil) {
		path = [TPCPathInfo userDownloads];
	}

	[self openWithPath:path];
}

- (void)openWithPath:(nullable NSString *)path
{
	if (self.path == nil) {
		self.path = path;
	}

	if (self.client.isLoggedIn == NO) {
		[self _closeWithClientDisconnectedError];

		return;
	}

	if (self.isSender) {
		[self openTransfer];
	} else {
		if ([self receiveUnencryptedFile] == NO) {
			return;
		}

		[self sendTransferResumeRequestToClient];
	}
}

- (void)openTransfer
{
	if (self.isSender) {
		if (self.isReversed) {
			[self updateIPAddress];
		} else {
			[self openConnectionAsServer];
		}
	} else {
		if (self.isReversed) {
			[self openConnectionAsServer];
		} else {
			[self openConnectionToHost];
		}
	}
}

- (void)openConnectionToHost
{
	[self closeAndPostNotification:NO];

	[self resetProperties];

	[self createDispatchQueues];

	self.transferStatus = TDCFileTransferDialogTransferStatusConnecting;

	GCDAsyncSocket *connectionToRemoteServer =
	[[GCDAsyncSocket alloc] initWithDelegate:(id)self
							   delegateQueue:self.serverDispatchQueue
								 socketQueue:self.serverSocketQueue];

	/* Set before connecting: callbacks are ignored for sockets that aren't current */
	self.connectionToRemoteServer = connectionToRemoteServer;

	NSError *connectionError = nil;

	BOOL isConnected = NO;

	/* Use the interface of the configured IP address instead of the default. */
	/* Default interface is used if IP address is not found locally. */
	NSString *networkInterface = [self networkInterfaceMatchingAddress];

	if (networkInterface) {
		isConnected = [connectionToRemoteServer connectToHost:self.hostAddress onPort:self.hostPort viaInterface:networkInterface withTimeout:_connectTimeout error:&connectionError];
	} else {
		isConnected = [connectionToRemoteServer connectToHost:self.hostAddress onPort:self.hostPort withTimeout:_connectTimeout error:&connectionError];
	}

	if (isConnected == NO) {
		if (connectionError) {
			LogToConsoleError("DCC Connect Error: %{public}@", connectionError.localizedDescription);
		}

		[self closeWithLocalizedError:@"TDCFileTransferDialog[fn8-sx]"];

		return;
	}

	[self disableSystemSleep];
}

- (void)openConnectionAsServer
{
	[self closeAndPostNotification:NO];

	[self resetProperties];

	[self createDispatchQueues];

	self.transferStatus = TDCFileTransferDialogTransferStatusInitializing;

	uint16_t portRangeStart = [TPCPreferences fileTransferPortRangeStart];
	uint16_t portRangeEnd = [TPCPreferences fileTransferPortRangeEnd];

	/* A wider counter, so that a range ending at 65535 cannot wrap to port 0 */
	for (uint32_t port = portRangeStart; port <= portRangeEnd; port++) {
		self.hostPort = (uint16_t)port;

		if ([self tryToOpenConnectionAsServer]) {
			[self disableSystemSleep];

			return;
		}
	}

	[self closeWithLocalizedError:@"TDCFileTransferDialog[vxc-sd]"];
}

- (BOOL)tryToOpenConnectionAsServer
{
	GCDAsyncSocket *listeningServer =
	[[GCDAsyncSocket alloc] initWithDelegate:(id)self
							   delegateQueue:self.serverDispatchQueue
								 socketQueue:self.serverSocketQueue];

	BOOL isActive = [listeningServer acceptOnPort:self.hostPort error:NULL];

	if (isActive == NO) {
		return NO;
	}

	self.listeningServer = listeningServer;

	/* Try to map the port */
	XRPortMapper *portMapping = [[XRPortMapper alloc] initWithPort:self.hostPort];

	portMapping.mapTCP = YES;
	portMapping.mapUDP = NO;

	portMapping.desiredPublicPort = self.hostPort;

	self.portMapping = portMapping;

	[RZNotificationCenter() addObserver:self selector:@selector(portMapperDidFinishWork:) name:XRPortMapperDidChangedNotification object:self.portMapping];

	self.transferStatus = TDCFileTransferDialogTransferStatusMappingListeningPort;

	if ([self.portMapping open] == NO) {
		[self portMapperDidFinishWork:nil];
	}

	return YES;
}

- (nullable NSString *)networkInterfaceMatchingAddress
{
	return [TPCPreferences fileTransferIPAddressInterfaceName];
}

- (void)portMapperDidFinishWork:(NSNotification *)aNotification
{
	NSAssertReturn(self.transferStatus == TDCFileTransferDialogTransferStatusMappingListeningPort);

	if (self.portMapping.isMapped) {
		[self updateIPAddress];

		LogToConsoleInfo("Successful port mapping on port %{public}hu", self.hostPort);

		return;
	}

	LogToConsoleError("Port mapping failed with error code: %{public}i", self.portMapping.error);

	if (self.isReversed) {
		[self closeWithLocalizedError:@"TDCFileTransferDialog[vxc-sd]"];

		return;
	}

	/* If mapping fails, we silently fail */
	/* We tried and it was successful, then that is good, but if we
	 did not, still start listening just incase other conditions allow
	 the transfer to still take place. */
	[self updateIPAddress];
}

- (void)updateIPAddress
{
	LogStackTraceWithType(LogToConsoleTypeDebug);

	NSString *address = self.transferDialog.IPAddress;

	LogToConsoleDebug("TDCFileTransferDialog cached IP address: %{private}@", address);

	TXFileTransferIPAddressMethodDetection detectionMethod = [TPCPreferences fileTransferIPAddressDetectionMethod];
	
	BOOL manuallyDetect = (detectionMethod == TXFileTransferIPAddressMethodManual);
	
	if (address == nil && manuallyDetect == NO) {
		NSString *publicAddress = self.portMapping.publicAddress;

		LogToConsoleDebug("Port mapper public IP address: %{private}@", publicAddress);

		if (publicAddress.isIPAddress) {
			self.transferDialog.IPAddress = publicAddress;

			address = publicAddress;
		}
	}

	/* Request address? */
	if (address == nil) {
		if (manuallyDetect || detectionMethod == TXFileTransferIPAddressMethodRouterOnly) {
			LogToConsoleError("User has set IP address detection to be manual but have no address set");

			[self noteIPAddressLookupFailed];
		} else {
			LogToConsoleDebug("Performing IP address lookup using the Internet");

			[self.transferDialog requestIPAddress];

			self.transferStatus = TDCFileTransferDialogTransferStatusWaitingForLocalIPAddress;
		}

		return;
	}

	[self noteIPAddressLookupSucceeded];
}

- (void)closePortMapping
{
	if (self.portMapping == nil) {
		return;
	}

	[RZNotificationCenter() removeObserver:self name:XRPortMapperDidChangedNotification object:self.portMapping];

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self.portMapping close];

		self.portMapping = nil;
	});
}

- (void)noteIPAddressLookupSucceeded
{
	LogStackTraceWithType(LogToConsoleTypeDebug);

	if (self.isSender) {
		if (self.isReversed) {
			self.transferStatus = TDCFileTransferDialogTransferStatusWaitingForReceiverToAccept;
		} else {
			self.transferStatus = TDCFileTransferDialogTransferStatusIsListeningAsSender;
		}
	} else {
		if (self.isReversed) {
			self.transferStatus = TDCFileTransferDialogTransferStatusIsListeningAsReceiver;
		} else {
			return;
		}
	}

	[self startPeerResponseTimeout];

	[self sendTransferRequestToClient];
}

- (void)startPeerResponseTimeout
{
	NSUInteger generation = self.peerResponseTimeoutGeneration;

	__weak TDCFileTransferDialogTransferController *weakSelf = self;

	XRPerformDelayedBlockOnMainQueue(^{
		[weakSelf peerResponseTimeoutForGeneration:generation];
	}, _peerResponseTimeout);
}

- (void)peerResponseTimeoutForGeneration:(NSUInteger)generation
{
	/* The transfer was closed or reopened since */
	if (generation != self.peerResponseTimeoutGeneration) {
		return;
	}

	TDCFileTransferDialogTransferStatus transferStatus = self.transferStatus;

	if (transferStatus != TDCFileTransferDialogTransferStatusIsListeningAsSender &&
		transferStatus != TDCFileTransferDialogTransferStatusIsListeningAsReceiver &&
		transferStatus != TDCFileTransferDialogTransferStatusWaitingForReceiverToAccept)
	{
		return;
	}

	[self closeWithLocalizedError:@"TDCFileTransferDialog[dr5-tq]"];
}

- (void)noteIPAddressLookupFailed
{
	[self closeWithLocalizedError:@"TDCFileTransferDialog[47s-1s]"];
}

- (void)didReceiveResumeRequest:(uint64_t)proposedPosition
{
	uint64_t currentFilesize = self.currentFilesize;

	if (proposedPosition == 0 || currentFilesize < proposedPosition) {
		return;
	}

	self.isResume = YES;

	self.processedFilesize = proposedPosition;

	[self sendTransferResumeAcceptToClient];
}

- (void)didReceiveResumeAccept:(uint64_t)proposedPosition
{
	[self cancelPerformRequestsWithSelector:@selector(transferResumeRequestTimeout) object:nil];

	uint64_t currentFilesize = self.currentFilesize;

	if (currentFilesize != proposedPosition) {
		[self closeWithLocalizedError:@"TDCFileTransferDialog[0ov-tr]" isFatalError:YES];

		return;
	}

	self.isResume = YES;

	self.processedFilesize = currentFilesize;

	[self openTransfer];
}

- (void)didReceiveSendRequest:(NSString *)hostAddress hostPort:(uint16_t)hostPort
{
	NSParameterAssert(hostAddress != nil);

	self.hostAddress = hostAddress;

	self.hostPort = hostPort;

	self.processedFilesize = 0;

	[self openConnectionToHost];
}

- (void)buildTransferToken
{
	NSUInteger loopedCount = 0;

	do {
		/* Unguessable, and within a signed 32-bit integer for other clients */
		NSString *transferToken = [NSString stringWithUnsignedInteger:(TXRandomNumber(INT32_MAX - 1) + 1)];

		BOOL transferExists = [self.transferDialog fileTransferExistsWithToken:transferToken];

		if (transferExists == NO) {
			self.transferToken = transferToken;

			break;
		}

		loopedCount += 1;
	} while (loopedCount < 300);
}

- (void)sendTransferRequestToClient
{
	if (self.isSender) {
		uint64_t currentFilesize = self.currentFilesize;

		if (self.isReversed) {
			[self buildTransferToken];

			[self.client sendFile:self.peerNickname port:0 filename:self.filename filesize:currentFilesize token:self.transferToken];
		} else {
			[self.client sendFile:self.peerNickname port:self.hostPort filename:self.filename filesize:currentFilesize token:nil];
		}
	} else {
		if (self.isReversed) {
			[self.client sendFile:self.peerNickname port:self.hostPort filename:self.filename filesize:self.totalFilesize token:self.transferToken];
		}
	}
}

- (void)sendTransferResumeRequestToClient
{
	uint64_t currentFilesize = self.currentFilesize;

	/* Only resume Textual's own partial download of this file from this peer.
	 Anything else is saved under a new name, so that a peer can neither append
	 to nor learn the size of an unrelated file of the same name. */
	BOOL canResume = (currentFilesize > 0 &&
					  currentFilesize < self.totalFilesize &&
					  [self.class fileAtPath:self.filePath
		isPartialDownloadForClientIdentifier:self.clientId
										peer:self.peerNickname
									filename:self.filename
									filesize:self.totalFilesize]);

	if (canResume == NO) {
		[self openTransfer];

		return;
	}

	[self cancelPerformRequestsWithSelector:@selector(transferResumeRequestTimeout)];

	[self performSelectorInCommonModes:@selector(transferResumeRequestTimeout) withObject:nil afterDelay:_resumeAcceptTimeout];

	self.transferStatus = TDCFileTransferDialogTransferStatusWaitingForResumeAccept;

	if (self.isReversed) {
		[self.client sendFileResume:self.peerNickname port:0 filename:self.filename filesize:currentFilesize token:self.transferToken];
	} else {
		[self.client sendFileResume:self.peerNickname port:self.hostPort filename:self.filename filesize:currentFilesize token:nil];
	}
}

- (void)sendTransferResumeAcceptToClient
{
	if (self.isReversed) {
		[self.client sendFileResumeAccept:self.peerNickname port:0 filename:self.filename filesize:self.processedFilesize token:self.transferToken];
	} else {
		[self.client sendFileResumeAccept:self.peerNickname port:self.hostPort filename:self.filename filesize:self.processedFilesize token:nil];
	}
}

- (void)transferResumeRequestTimeout
{
	if (self.transferStatus != TDCFileTransferDialogTransferStatusWaitingForResumeAccept) {
		return;
	}

	[self openTransfer];
}

- (void)peerNicknameChanged:(NSNotification *)notification
{
	NSDictionary *userInfo = notification.userInfo;

	NSString *oldNickname = userInfo[@"oldNickname"];

	if ([self.peerNickname isEqualToString:oldNickname] == NO) {
		return;
	}

	self.peerNickname = userInfo[@"newNickname"];
}

- (void)clientDisconnected:(NSNotification *)notification
{
	[self closeWithClientDisconnectedError];
}

- (void)closeWithClientDisconnectedError
{
	/* If the controller is already sending or receiving data, then a connection
	 is already established to the peer which can function without a connection
	 to IRC. If data is not being transferred then fail immediately. */
	if (self.isAwaitingPeer == NO) {
		return;
	}

	[self _closeWithClientDisconnectedError];
}

- (void)_closeWithClientDisconnectedError
{
	[self closeWithLocalizedError:@"TDCFileTransferDialog[12p-0v]" isFatalError:NO];
}

- (void)close
{
	[self closeAndPostNotification:YES];
}

- (void)closeAndPostNotification:(BOOL)postNotification
{
	[self cancelPerformRequests];

	self.peerResponseTimeoutGeneration += 1;

	if ( self.listeningServer) {
		[self.listeningServer disconnect];
		 self.listeningServer = nil;
	}

	if ( self.listeningServerConnectedClient) {
		[self.listeningServerConnectedClient disconnect];
		 self.listeningServerConnectedClient = nil;
	}

	if ( self.connectionToRemoteServer) {
		[self.connectionToRemoteServer disconnect];
		 self.connectionToRemoteServer = nil;
	}

	dispatch_queue_t dispatchQueue = self.serverDispatchQueue;

	[self destroyDispatchQueues];

	[self closePortMapping];

	[self closeFileHandleOnQueue:dispatchQueue];

	if (self.transferStatus != TDCFileTransferDialogTransferStatusComplete &&
		self.transferStatus != TDCFileTransferDialogTransferStatusFatalError &&
		self.transferStatus != TDCFileTransferDialogTransferStatusRecoverableError)
	{
		self.transferStatus = TDCFileTransferDialogTransferStatusStopped;
	}

	if (postNotification) {
		if (self.transferStatus == TDCFileTransferDialogTransferStatusFatalError ||
			self.transferStatus == TDCFileTransferDialogTransferStatusRecoverableError)
		{
			if (self.isSender) {
				[self.client notifyFileTransfer:TXNotificationTypeFileTransferSendFailed nickname:self.peerNickname filename:self.filename filesize:self.totalFilesize requestIdentifier:self.uniqueIdentifier];
			} else {
				[self.client notifyFileTransfer:TXNotificationTypeFileTransferReceiveFailed nickname:self.peerNickname filename:self.filename filesize:self.totalFilesize requestIdentifier:self.uniqueIdentifier];
			}
		}
		else if (self.transferStatus == TDCFileTransferDialogTransferStatusComplete)
		{
			if (self.isSender) {
				[self.client notifyFileTransfer:TXNotificationTypeFileTransferSendSuccessful nickname:self.peerNickname filename:self.filename filesize:self.totalFilesize requestIdentifier:self.uniqueIdentifier];
			} else {
				[self.client notifyFileTransfer:TXNotificationTypeFileTransferReceiveSuccessful nickname:self.peerNickname filename:self.filename filesize:self.totalFilesize requestIdentifier:self.uniqueIdentifier];
			}
		}
	}

	[self.transferDialog updateMaintenanceTimer];

	[self enableSystemSleep];
}

#pragma mark -
#pragma mark Timer

- (void)onMaintenanceTimer
{
	/* All transfer state changes happen on the transfer's queue, which
	 is gone once the transfer is closed. */
	dispatch_queue_t dispatchQueue = self.serverDispatchQueue;

	if (dispatchQueue == nil) {
		return;
	}

	dispatch_async(dispatchQueue, ^{
		if (self.isActive == NO) {
			return;
		}

		@synchronized(self.speedRecordsPrivate) {
			[self.speedRecordsPrivate addObject:@(self.currentRecord)];

			if (self.speedRecordsPrivate.count > RECORDS_LENGTH) {
				[self.speedRecordsPrivate removeObjectAtIndex:0];
			}
		}

		self.currentRecord = 0;

		[self reloadStatusInformation];

		[self send];
	});
}

#pragma mark -
#pragma mark File Handle

- (void)setNonexistentFilename
{
	NSString *filePath = self.filePath;

	if ([RZFileManager() fileExistsAtPath:filePath] == NO) {
		return;
	}

	NSString *filenameExtension = self.filename.pathExtension;

	NSString *filenameWithoutExtension = self.filename.stringByDeletingPathExtension;

	NSUInteger i = 1;

	do {
		NSString *newFilename = nil;

		if (filenameExtension.length == 0) {
			newFilename = [NSString stringWithFormat:@"%@_%lu", filenameWithoutExtension, i];
		} else {
			newFilename = [NSString stringWithFormat:@"%@_%lu.%@", filenameWithoutExtension, i, filenameExtension];
		}

		filePath = [self.path stringByAppendingPathComponent:newFilename];

		i += 1;
	} while ([RZFileManager() fileExistsAtPath:filePath]);

	self.filename = filePath.lastPathComponent;
}

- (BOOL)openFileHandle
{
	NSString *filePath = self.filePath;

	if (self.isSender == NO && self.isResume == NO) {
		[self setNonexistentFilename];

		filePath = self.filePath;

		[RZFileManager() createFileAtPath:filePath contents:[NSData data] attributes:nil];

		[self.class recordPartialDownloadAtPath:filePath
							   clientIdentifier:self.clientId
										   peer:self.peerNickname
									   filename:self.filename
									   filesize:self.totalFilesize];
	}

	NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];

	if (fileHandle == nil) {
		[self closeWithLocalizedError:@"TDCFileTransferDialog[nab-dx]"];

		return NO;
	}

	if (self.isResume) {
		[fileHandle seekToFileOffset:self.processedFilesize];
	}

	self.fileHandle = fileHandle;

	return YES;
}

- (void)closeFileHandleOnQueue:(nullable dispatch_queue_t)dispatchQueue
{
	NSFileHandle *fileHandle = self.fileHandle;

	if (fileHandle == nil) {
		return;
	}

	self.fileHandle = nil;

	/* A socket callback may be using the file on the transfer's queue right now */
	if (dispatchQueue) {
		dispatch_async(dispatchQueue, ^{
			[fileHandle closeFile];
		});
	} else {
		[fileHandle closeFile];
	}
}

#pragma mark -
#pragma mark Socket Delegate

- (BOOL)isCurrentSocket:(GCDAsyncSocket *)socket
{
	return (socket == self.listeningServer ||
			socket == self.listeningServerConnectedClient ||
			socket == self.connectionToRemoteServer);
}

/* Callbacks of a socket that was closed (and maybe replaced by a reopened
 transfer) can still be queued; they must not touch the current transfer. */
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	if (self.isActingAsServer == NO || [self isCurrentSocket:sock] == NO) {
		return;
	}

	if (self.listeningServerConnectedClient == nil) {
		self.listeningServerConnectedClient = newSocket;
	} else {
		[newSocket disconnect];

		return;
	}

	if (self.isReversed) {
		self.transferStatus = TDCFileTransferDialogTransferStatusReceiving;
	} else {
		self.transferStatus = TDCFileTransferDialogTransferStatusSending;
	}

	[self.transferDialog updateMaintenanceTimer];

	if ([self openFileHandle] == NO) {
		return;
	}

	if (self.isReversed) {
		[self.readSocket readDataWithTimeout:_readDataTimeout tag:0];
	} else {
		[self send];
	}
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
	if (self.isActingAsClient == NO || [self isCurrentSocket:sock] == NO) {
		return;
	}

	if (self.isReversed == NO) {
		self.transferStatus = TDCFileTransferDialogTransferStatusReceiving;
	} else {
		self.transferStatus = TDCFileTransferDialogTransferStatusSending;
	}

	[self.transferDialog updateMaintenanceTimer];

	if ([self openFileHandle] == NO) {
		return;
	}

	if (self.isReversed == NO) {
		[self.readSocket readDataWithTimeout:_readDataTimeout tag:0];
	} else {
		[self send];
	}
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error
{
	if ([self isCurrentSocket:sock] == NO) {
		return;
	}

	if (self.transferStatus == TDCFileTransferDialogTransferStatusComplete ||
		self.transferStatus == TDCFileTransferDialogTransferStatusFatalError ||
		self.transferStatus == TDCFileTransferDialogTransferStatusRecoverableError)
	{
		return;
	}

	if (error) {
		[self closeWithLocalizedError:@"TDCFileTransferDialog[s79-3a]" description:error.localizedDescription];
	} else {
		[self close];
	}
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	if (self.isSender != NO || [self isCurrentSocket:sock] == NO) {
		return;
	}

	/* Never write more than the peer announced */
	uint64_t remainingFilesize = (self.totalFilesize - self.processedFilesize);

	if (data.length > remainingFilesize) {
		data = [data subdataWithRange:NSMakeRange(0, (NSUInteger)remainingFilesize)];
	}

	/* Update progress */
	self.currentRecord += data.length;

	self.processedFilesize += data.length;

	if (data.length > 0) {
		@try {
			[self.fileHandle writeData:data];
		}
		@catch (NSException *exception) {
			LogToConsoleError("Caught exception: %{public}@", exception.reason);
			LogStackTrace();

			if ([exception.reason contains:@"No space left on device"]) {
				[self failWithNoSpaceLeftOnDevice];

				return;
			}

			[self closeWithLocalizedError:@"TDCFileTransferDialog[05g-c8]"];

			return;
		} // @catch
	}

	/* Send acknowledgement back to server */
	uint32_t processedFilesize = (self.processedFilesize & 0xFFFFFFFF);

	unsigned char ackPacket[4];

	ackPacket[0] = ((processedFilesize >> 24) & 0xFF);
	ackPacket[1] = ((processedFilesize >> 16) & 0xFF);
	ackPacket[2] = ((processedFilesize >> 8) & 0xFF);
	ackPacket[3] =  (processedFilesize & 0xFF);

	NSData *ackPacketData = [NSData dataWithBytes:ackPacket length:4];

	[self.readSocket writeData:ackPacketData withTimeout:_sendDataTimeout tag:0];

	/* Continue requesting data if the transfer is not complete */
	if (self.processedFilesize < self.totalFilesize) {
		[self.readSocket readDataWithTimeout:_readDataTimeout tag:0];

		return;
	}

	/* Update status and tear down transfer */
	[self.class forgetPartialDownloadAtPath:self.filePath];

	self.transferStatus = TDCFileTransferDialogTransferStatusComplete;

	[self close];
}

#pragma mark -
#pragma mark Socket Write

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	if (self.isSender == NO || [self isCurrentSocket:sock] == NO) {
		return;
	}

	/* Acknowledge sent data */
	self.sendQueueSize -= 1;

	/* Continue sending data if the transfer is not complete */
	if (self.processedFilesize < self.totalFilesize) {
		[self send];

		return;
	}

	/* Wait until the send queue has cleared before closing 
	 connection. Just because we finished processing the 
	 data here doesn't mean it has been sent yet. */
	if (self.sendQueueSize > 0) {
		return;
	}

	/* Update status and tear down transfer */
	self.transferStatus = TDCFileTransferDialogTransferStatusComplete;

	[self close];
}

- (void)send
{
	if (self.isSender == NO) {
		return;
	}

	if (self.transferStatus != TDCFileTransferDialogTransferStatusSending) {
		return;
	}

	do {
		if (self.currentRecord >= RATE_LIMIT) {
			return;
		}

		if (self.sendQueueSize >= MAX_QUEUE_SIZE) {
			return;
		}

		if (self.processedFilesize >= self.totalFilesize) {
			return;
		}

		/* Never send more than was announced, even if the file has grown since */
		NSUInteger lengthToRead = (NSUInteger)MIN(BUFFER_SIZE, (self.totalFilesize - self.processedFilesize));

		NSData *dataToWrite = nil;

		@try {
			dataToWrite = [self.fileHandle readDataOfLength:lengthToRead];
		}
		@catch (NSException *exception) {
			LogToConsoleError("Caught exception: %{public}@", exception.reason);
		}

		/* The file can no longer be read, or became shorter */
		if (dataToWrite.length == 0) {
			[self closeWithLocalizedError:@"TDCFileTransferDialog[nab-dx]"];

			return;
		}

		self.currentRecord += dataToWrite.length;

		self.processedFilesize += dataToWrite.length;

		self.sendQueueSize += 1;

		[self.writeSocket writeData:dataToWrite withTimeout:_sendDataTimeout tag:0];
	} while (1);
}

#pragma mark -
#pragma mark Actions

- (void)updateClearButton
{
	[self.transferDialog updateClearButton];
}

- (void)reloadStatusInformation
{
	TDCFileTransferDialogTableCell *transferTableCell = self.transferTableCell;

	if (transferTableCell == nil) {
		return;
	}

	[transferTableCell reloadStatusInformation];
}

#pragma mark -
#pragma mark Matching and Status

- (BOOL)isWithClient:(IRCClient *)client peer:(NSString *)nickname
{
	NSParameterAssert(client != nil);
	NSParameterAssert(nickname != nil);

	return (self.client == client && [self.peerNickname isEqualToStringIgnoringCase:nickname]);
}

- (BOOL)isActive
{
	TDCFileTransferDialogTransferStatus transferStatus = self.transferStatus;

	return (transferStatus == TDCFileTransferDialogTransferStatusSending ||
			transferStatus == TDCFileTransferDialogTransferStatusReceiving);
}

- (BOOL)isAwaitingPeer
{
	switch (self.transferStatus) {
		case TDCFileTransferDialogTransferStatusInitializing:
		case TDCFileTransferDialogTransferStatusMappingListeningPort:
		case TDCFileTransferDialogTransferStatusWaitingForLocalIPAddress:
		case TDCFileTransferDialogTransferStatusIsListeningAsSender:
		case TDCFileTransferDialogTransferStatusIsListeningAsReceiver:
		case TDCFileTransferDialogTransferStatusWaitingForReceiverToAccept:
		case TDCFileTransferDialogTransferStatusWaitingForResumeAccept:
		case TDCFileTransferDialogTransferStatusConnecting:
			return YES;
		default:
			return NO;
	}
}

- (BOOL)isStopped
{
	TDCFileTransferDialogTransferStatus transferStatus = self.transferStatus;

	return (transferStatus == TDCFileTransferDialogTransferStatusStopped ||
			transferStatus == TDCFileTransferDialogTransferStatusComplete ||
			transferStatus == TDCFileTransferDialogTransferStatusFatalError ||
			transferStatus == TDCFileTransferDialogTransferStatusRecoverableError);
}

#pragma mark -
#pragma mark Offered Files

+ (NSString *)filenameForOfferedFilename:(NSString *)filename
{
	NSParameterAssert(filename != nil);

	NSString *safeFilename = filename.safeFilename;

	/* A leading dot would hide the file, or with the home folder as the
	 download folder, put it in place of a dotfile such as .zshrc */
	if ([safeFilename hasPrefix:@"."]) {
		safeFilename = [@"_" stringByAppendingString:safeFilename];
	}

	return safeFilename;
}

+ (NSString *)partialDownloadTransferWithClientIdentifier:(NSString *)clientIdentifier peer:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize
{
	return [NSString stringWithFormat:@"%@\n%@\n%@\n%llu", clientIdentifier, nickname.lowercaseString, filename, totalFilesize];
}

+ (void)recordPartialDownloadAtPath:(NSString *)path clientIdentifier:(NSString *)clientIdentifier peer:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize
{
	NSParameterAssert(path != nil);

	NSString *fileIdentity = _identityOfFileAtPath(path);

	if (fileIdentity == nil) {
		return;
	}

	@synchronized (_partialDownloadsDefaultsKey) {
		NSMutableDictionary<NSString *, NSDictionary *> *records = [NSMutableDictionary dictionary];

		/* Drop records of files that are gone or were replaced */
		[[RZUserDefaults() dictionaryForKey:_partialDownloadsDefaultsKey] enumerateKeysAndObjectsUsingBlock:^(NSString *recordPath, NSDictionary *record, BOOL *stop) {
			if ([recordPath isKindOfClass:[NSString class]] == NO || [record isKindOfClass:[NSDictionary class]] == NO) {
				return;
			}

			if ([record[@"file"] isEqual:_identityOfFileAtPath(recordPath)]) {
				records[recordPath] = record;
			}
		}];

		records[path] = @{
			@"file" : fileIdentity,
			@"transfer" : [self partialDownloadTransferWithClientIdentifier:clientIdentifier peer:nickname filename:filename filesize:totalFilesize]
		};

		[RZUserDefaults() setObject:records forKey:_partialDownloadsDefaultsKey postNotification:NO];
	}
}

+ (void)forgetPartialDownloadAtPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	@synchronized (_partialDownloadsDefaultsKey) {
		NSMutableDictionary *records = [[RZUserDefaults() dictionaryForKey:_partialDownloadsDefaultsKey] mutableCopy];

		if (records[path] == nil) {
			return;
		}

		[records removeObjectForKey:path];

		[RZUserDefaults() setObject:records forKey:_partialDownloadsDefaultsKey postNotification:NO];
	}
}

+ (BOOL)fileAtPath:(NSString *)path isPartialDownloadForClientIdentifier:(NSString *)clientIdentifier peer:(NSString *)nickname filename:(NSString *)filename filesize:(uint64_t)totalFilesize
{
	NSParameterAssert(path != nil);

	NSDictionary *record = nil;

	@synchronized (_partialDownloadsDefaultsKey) {
		record = [RZUserDefaults() dictionaryForKey:_partialDownloadsDefaultsKey][path];
	}

	if ([record isKindOfClass:[NSDictionary class]] == NO) {
		return NO;
	}

	NSString *transfer = [self partialDownloadTransferWithClientIdentifier:clientIdentifier peer:nickname filename:filename filesize:totalFilesize];

	return ([record[@"transfer"] isEqual:transfer] &&
			[record[@"file"] isEqual:_identityOfFileAtPath(path)]);
}

#pragma mark -
#pragma mark Properties

- (nullable GCDAsyncSocket *)writeSocket
{
	if (self.isReversed) {
		return self.connectionToRemoteServer;
	} else {
		return self.listeningServerConnectedClient;
	}
}

- (nullable GCDAsyncSocket *)readSocket
{
	if (self.isReversed) {
		return self.listeningServerConnectedClient;
	} else {
		return self.connectionToRemoteServer;
	}
}

- (BOOL)isActingAsServer
{
	return ((self.isSender		 && self.isReversed == NO) ||
			(self.isSender == NO && self.isReversed));
}

- (BOOL)isActingAsClient
{
	return ((self.isSender == NO && self.isReversed == NO) ||
			(self.isSender		 && self.isReversed));
}

- (TDCFileTransferDialog *)transferDialog
{
	return [TXSharedApplication sharedFileTransferDialog];
}

- (NSArray<NSNumber *> *)speedRecords
{
	@synchronized (self.speedRecordsPrivate) {
		return [self.speedRecordsPrivate copy];
	}
}

- (nullable NSString *)filePath
{
	NSString *path = self.path;

	NSString *filename = self.filename;

	if (path == nil || filename == nil) {
		return nil;
	}

	return [path stringByAppendingPathComponent:filename];
}

- (nullable NSURL *)fileURL
{
	NSString *filePath = self.filePath;

	if (filePath == nil) {
		return nil;
	}

	return [NSURL fileURLWithPath:filePath];
}

- (uint64_t)currentFilesize
{
	NSString *filePath = self.filePath;

	if (filePath == nil) {
		return 0;
	}

	return _sizeOfFileAtPath(filePath);
}

- (void)setTransferStatus:(TDCFileTransferDialogTransferStatus)transferStatus
{
	if (self->_transferStatus != transferStatus) {
		self->_transferStatus = transferStatus;

		[self reloadStatusInformation];
	}
}

- (void)resetProperties
{
	if (self.isResume == NO) {
		self.processedFilesize = 0;
	}

	self.currentRecord = 0;

	self.errorMessageDescription = nil;

	self.sendQueueSize = 0;

	@synchronized(self.speedRecordsPrivate) {
		[self.speedRecordsPrivate removeAllObjects];
	}
}

@end

NS_ASSUME_NONNULL_END
