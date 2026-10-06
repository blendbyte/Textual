/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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

#import "RCMConnectionManagerProtocol.h"

#import <objc/message.h>

#import "NSObjectHelperPrivate.h"
#import "GCDAsyncSocketExtensions.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "IRCClient.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCConnectionPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCConnection ()
@property (nonatomic, weak, readwrite) IRCClient *client;
@property (nonatomic, strong) NSXPCConnection *serviceConnection;
@property (nonatomic, strong, nullable) SFCertificateTrustPanel *trustPanel;
@property (nonatomic, assign) BOOL trustPanelDoNotInvokeCompletionBlock;
@property (nonatomic, assign) BOOL connectionInvalidatedVoluntarily;
@property (nonatomic, copy, readwrite) NSString *uniqueIdentifier;
@end

@implementation IRCConnection

#pragma mark -
#pragma mark Initialization 

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithConfig:(IRCConnectionConfig *)config onClient:(IRCClient *)client
{
	NSParameterAssert(config != nil);
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;

		self.config = config;
		
		self.uniqueIdentifier = [NSString stringWithUUID];
	}

	return self;
}

- (void)resetState
{
	self.isConnecting = NO;
	self.isConnected = NO;
	self.isConnectedWithClientSideCertificate = NO;
	self.isDisconnecting = NO;
	self.EOFReceived = NO;
	self.isSecured = NO;
	self.isSending = NO;

	self.connectedAddress = nil;

	self.connectionInvalidatedVoluntarily = NO;
}

#pragma mark -
#pragma mark Process Management

- (void)invalidateProcess
{
	if (self.serviceConnection == nil) {
		return;
	}

	LogToConsoleDebug("Invalidating process...");

	[self.serviceConnection invalidate];
}

- (void)warmProcessIfNeeded
{
	if (self.serviceConnection != nil) {
		return;
	}

	LogToConsoleDebug("Warming process...");

	[self warmProcess];
}

- (void)warmProcess
{
	NSXPCConnection *serviceConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.textualapp.app.IRCConnectionHost"];

	NSXPCInterface *remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(RCMConnectionManagerServerProtocol)];

	serviceConnection.remoteObjectInterface = remoteObjectInterface;

	NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(RCMConnectionManagerClientProtocol)];

	serviceConnection.exportedInterface = exportedInterface;

	serviceConnection.exportedObject = self;

	serviceConnection.interruptionHandler = ^{
		[self interruptionHandler];

		LogToConsole("Interruption handler called");
	};

	serviceConnection.invalidationHandler = ^{
		[self invalidationHandler];

		LogToConsole("Invalidation handler called");
	};

	[serviceConnection resume];

	self.serviceConnection = serviceConnection;
}

- (void)interruptionHandler
{
	[self invalidateProcess];
}

- (void)invalidationHandler
{
	self.serviceConnection = nil;

	/* -ircConnectionDidDisconnectWithError: instructs the process to
	 voluntarily invalidate, so if we reach here, then its pretty certain
	 something big happened and we need to let the client know. */
	if ((self.isConnecting || self.isConnected) &&
		self.connectionInvalidatedVoluntarily == NO)
	{
		NSString *errorMessage = TXTLS(@"IRC[vdy-jk]");

		NSError *error = [NSError errorWithDomain:IRCConnectionErrorDomain
											 code:IRCConnectionErrorCodeOther
										 userInfo:@{ NSLocalizedDescriptionKey : errorMessage }];

		[self _ircConnectionDidDisconnectWithError:error];
	}

	[self resetState];
}

- (id <RCMConnectionManagerServerProtocol>)remoteObjectProxy
{
	return [self remoteObjectProxyWithErrorHandler:nil];
}

- (id <RCMConnectionManagerServerProtocol>)remoteObjectProxyWithErrorHandler:(void (^ _Nullable)(NSError *error))handler
{
	return [self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		LogToConsoleError("Error occurred while communicating with service: %{public}@",
			  error.localizedDescription);

		if (handler) {
			handler(error);
		}
	}];
}

#pragma mark -
#pragma mark Open/Close Connection

- (void)open
{
	if (self.isConnecting || self.isConnected || self.isDisconnecting) {
		return;
	}

	[self warmProcessIfNeeded];

	self.isConnecting = YES;

	[[self remoteObjectProxy] openWithConfig:self.config];

	if ([TPCPreferences appNapEnabled] == NO) {
		[[self remoteObjectProxy] disableAppNap];
	}

	[[self remoteObjectProxy] disableSuddenTermination];
}

- (void)close
{
	if (self.isDisconnecting) {
		return;
	}

	if (self.isConnecting || self.isConnected) {
		/* Disconnect caused by calling -close on the service will
		 cause -ircConnectionDidDisconnectWithError: to invoke
		 -invalidateProcess for us, so don't call it on this condition. */
		self.isDisconnecting = YES;

		[[self remoteObjectProxy] close];
	} else {
		[self invalidateProcess];
	}
}

#pragma mark -
#pragma mark Utilities

- (void)enforceFloodControl
{
	if (self.isConnected == NO) {
		return;
	}

	[[self remoteObjectProxy] enforceFloodControl];
}

- (void)openSecuredConnectionCertificateModal
{
	[[self remoteObjectProxy] exportSecureConnectionInformation:^(NSString * _Nullable policyName, tls_protocol_version_t protocolType, tls_ciphersuite_t cipherSuites, NSArray<NSData *> *certificateChain) {
		if (policyName == nil) {
			return;
		}

		SecTrustRef trustRef = [RCMSecureTransport trustFromCertificateChain:certificateChain withPolicyName:policyName];

		if (trustRef == NULL) {
			return;
		}

		NSString *protocolDescription = [RCMSecureTransport descriptionForProtocolType:protocolType];

		NSString *cipherDescription = [RCMSecureTransport descriptionForCipherSuite:cipherSuites];

		if (protocolDescription == nil || cipherDescription == nil) {
			CFRelease(trustRef);

			return;
		}

		NSString *protocolSummary = nil;

		if ([RCMSecureTransport isCipherSuiteDeprecated:cipherSuites] == NO) {
			protocolSummary = TXTLS(@"Prompts[2jq-t5]", protocolDescription, cipherDescription);
		} else {
			protocolSummary = TXTLS(@"Prompts[8ou-pu]", protocolDescription, cipherDescription);
		}

		NSString *defaultButtonTitle = TXTLS(@"Prompts[aqw-q1]");
		NSString *alternateButtonTitle = nil;

		NSString *promptTitleText = TXTLS(@"Prompts[sfx-xx]", policyName);
		NSString *promptInformativeText = nil;

		if (protocolSummary == nil) {
			promptInformativeText = TXTLS(@"Prompts[ihy-mz]", policyName);
		} else {
			promptInformativeText = TXTLS(@"Prompts[iun-45]", policyName, protocolSummary);
		}

		__block NSWindow *window = nil;

		XRPerformBlockSynchronouslyOnMainQueue(^{
			window = [NSApp keyWindow];
		});

		(void)
		[RCMTrustPanel presentTrustPanelInWindow:window
											body:promptInformativeText
										   title:promptTitleText
								   defaultButton:defaultButtonTitle
								 alternateButton:alternateButtonTitle
										trustRef:trustRef
								 completionBlock:^(SecTrustRef trustRef, BOOL trusted, id contextInfo) {
									 CFRelease(trustRef);
								 }];
	}];
}

- (void)openInsecureCertificateTrustPanel:(RCMTrustResponse)trustBlock
{
	if (self.trustPanel != nil) {
		return;
	}

	[[self remoteObjectProxy] exportSecureConnectionInformation:^(NSString * _Nullable policyName, tls_protocol_version_t protocolType, tls_ciphersuite_t cipherSuites, NSArray<NSData *> *certificateChain) {
		if (policyName == nil) {
			return;
		}

		SecTrustRef trustRef = [RCMSecureTransport trustFromCertificateChain:certificateChain withPolicyName:policyName];

		if (trustRef == NULL) {
			return;
		}

		NSString *defaultButtonTitle = TXTLS(@"Prompts[zjw-bd]");
		NSString *alternateButtonTitle = TXTLS(@"Prompts[qso-2g]");

		NSString *promptTitleText = TXTLS(@"Prompts[m8b-58]", policyName);
		NSString *promptInformativeText = TXTLS(@"Prompts[85z-qw]", policyName);

		__weak typeof(self) weakSelf = self;

		self.trustPanel =
		[RCMTrustPanel presentTrustPanelInWindow:nil
											body:promptInformativeText
										   title:promptTitleText
								   defaultButton:defaultButtonTitle
								 alternateButton:alternateButtonTitle
										trustRef:trustRef
								 completionBlock:^(SecTrustRef trustRef, BOOL trusted, id contextInfo) {
									 CFRelease(trustRef);

									 weakSelf.trustPanel = nil;

									 if (weakSelf.trustPanelDoNotInvokeCompletionBlock) {
										 weakSelf.trustPanelDoNotInvokeCompletionBlock = NO;

										 return;
									 }

									 ((RCMTrustResponse)contextInfo)(trusted);
								 }
									 contextInfo:trustBlock];
	}];
}

- (void)closeInsecureCertificateTrustPanel
{
	if (self.trustPanel == nil) {
		return;
	}

	SEL dismissSelector = NSSelectorFromString(@"_dismissWithCode:");

	if ([self.trustPanel respondsToSelector:dismissSelector]) {
		self.trustPanelDoNotInvokeCompletionBlock = YES;

		NSMethodSignature *signature = [self.trustPanel methodSignatureForSelector:dismissSelector];

		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setTarget:self.trustPanel];
		[invocation setSelector:dismissSelector];

		NSModalResponse cancel = NSModalResponseCancel;
		[invocation setArgument:&cancel atIndex:2];

		[invocation invoke];
	}
}

#pragma mark -
#pragma mark Encode Data

- (nullable NSString *)convertFromCommonEncoding:(NSData *)data
{
	return [self.client convertFromCommonEncoding:data];
}

- (nullable NSData *)convertToCommonEncoding:(NSString *)data
{
	return [self.client convertToCommonEncoding:data];
}

#pragma mark -
#pragma mark Send Data

- (void)sendLine:(NSString *)line
{
	NSParameterAssert(line != nil);

	line = [line stringByAppendingString:@"\x0d\x0a"];

	NSData *dataToSend = [self convertToCommonEncoding:line];

	if (dataToSend == nil) {
		return;
	}

	self.isSending = YES;

	/* PONG replies are extremely important. There is no reason they should be
	 placed in the flood control queue. This writes them directly to the socket
	 instead of actually waiting for the queue. We only need this check if
	 we actually have flood control enabled. */
	if ([line hasPrefix:@"PONG"]) {
		[[self remoteObjectProxy] sendData:dataToSend bypassQueue:YES];

		return;
	}

	[[self remoteObjectProxy] sendData:dataToSend];
}

- (void)clearSendQueue
{
	[[self remoteObjectProxy] clearSendQueue];
}

#pragma mark -
#pragma mark Socket Delegate

- (void)ircConnectionWillConnectToProxy:(NSString *)proxyHost port:(uint16_t)proxyPort
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self.client ircConnection:self willConnectToProxy:proxyHost port:proxyPort];
	});
}

- (void)ircConnectionDidConnectToHost:(nullable NSString *)host
{
	self.connectedAddress = host;

	self.isConnecting = NO;
	self.isConnected = YES;

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self.client ircConnectionDidConnect:self];
	});
}

- (void)ircConnectionDidSecureConnectionWithProtocolType:(tls_protocol_version_t)protocolType cipherSuite:(tls_ciphersuite_t)cipherSuite
{
	self.isSecured = YES;

	if (self.config.identityClientSideCertificate != nil) {
		self.isConnectedWithClientSideCertificate = YES;
	}

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self.client ircConnectionDidSecureConnection:self withProtocolType:protocolType cipherSuite:cipherSuite];
	});
}

- (void)ircConnectionDidCloseReadStream
{
	self.EOFReceived = YES;

	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self.client ircConnectionDidCloseReadStream:self];
	});
}

- (void)ircConnectionDidDisconnectWithError:(nullable NSError *)disconnectError
{
	self.connectionInvalidatedVoluntarily = YES;

	[self invalidateProcess];

	[self _ircConnectionDidDisconnectWithError:disconnectError];
}

- (void)_ircConnectionDidDisconnectWithError:(nullable NSError *)disconnectError
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self closeInsecureCertificateTrustPanel];

		[self.client ircConnection:self didDisconnectWithError:disconnectError];
	});
}

- (void)ircConnectionDidReceiveData:(NSData *)data
{
	/* IRCClient performs call to main thread later in stack. */
	NSString *dataString = [self convertFromCommonEncoding:data];

	if (dataString == nil) {
		return;
	}

	[self.client ircConnection:self didReceiveData:dataString];
}

- (void)ircConnectionRequestInsecureCertificateTrust:(RCMTrustResponse)trustBlock
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		[self openInsecureCertificateTrustPanel:trustBlock];
	});
}

- (void)ircConnectionWillSendData:(NSData *)data
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		NSString *dataString = [self convertFromCommonEncoding:data];

		if (dataString == nil) {
			return;
		}

		[self.client ircConnection:self willSendData:dataString];
	});
}

- (void)ircConnectionDidSendData
{
	self.isSending = NO;
}

@end

NS_ASSUME_NONNULL_END
