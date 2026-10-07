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

#import "NSObjectHelperPrivate.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocalPrivate.h"
#import "IRCClient.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionTransportPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCConnection () <IRCConnectionTransportDelegate>
@property (nonatomic, weak, readwrite) IRCClient *client;
@property (nonatomic, strong, nullable) IRCConnectionTransport *transport;
@property (nonatomic, strong, nullable) SFCertificateTrustPanel *trustPanel;
@property (nonatomic, assign) BOOL trustPanelDoNotInvokeCompletionBlock;
@property (nonatomic, copy, readwrite) NSString *uniqueIdentifier;
@property (nonatomic, strong, nullable) id <NSObject> connectionActivity;
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

- (void)dealloc
{
	[self endConnectionActivity];
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
}

#pragma mark -
#pragma mark Activity

/* While connected: no App Nap (timers keep firing, so pings are answered
 on time) and no sudden termination. The Mac may still sleep when idle,
 unless "Keep the Mac awake while connected to a server" is on. */
- (void)beginConnectionActivity
{
	if (self.connectionActivity) {
		return;
	}

	[self _beginActivityToken];

	[[NSProcessInfo processInfo] disableSuddenTermination];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(preventSleepPreferenceChanged:)
								   name:TPCPreferencesPreventSleepWhileConnectedChangedNotification
								 object:nil];
}

- (void)_beginActivityToken
{
	NSActivityOptions options = NSActivityUserInitiatedAllowingIdleSystemSleep;

	if ([TPCPreferences preventSleepWhileConnected]) {
		options = NSActivityUserInitiated;
	}

	self.connectionActivity =
	[[NSProcessInfo processInfo] beginActivityWithOptions:options
												   reason:@"Connected to an IRC server"];
}

- (void)preventSleepPreferenceChanged:(NSNotification *)notification
{
	if (self.connectionActivity == nil) {
		return;
	}

	/* The new token is taken before the old one ends, so there is no gap */
	id <NSObject> previousActivity = self.connectionActivity;

	[self _beginActivityToken];

	[[NSProcessInfo processInfo] endActivity:previousActivity];
}

- (void)endConnectionActivity
{
	if (self.connectionActivity == nil) {
		return;
	}

	[RZNotificationCenter() removeObserver:self
									  name:TPCPreferencesPreventSleepWhileConnectedChangedNotification
									object:nil];

	[[NSProcessInfo processInfo] endActivity:self.connectionActivity];

	self.connectionActivity = nil;

	[[NSProcessInfo processInfo] enableSuddenTermination];
}

#pragma mark -
#pragma mark Open/Close Connection

- (void)open
{
	if (self.isConnecting || self.isConnected || self.isDisconnecting) {
		return;
	}

	self.isConnecting = YES;

	[self beginConnectionActivity];

	IRCConnectionTransport *transport = [[IRCConnectionTransport alloc] initWithConfig:self.config delegate:self];

	self.transport = transport;

	[transport open];
}

- (void)close
{
	if (self.isDisconnecting) {
		return;
	}

	if (self.isConnecting || self.isConnected) {
		self.isDisconnecting = YES;

		[self.transport close];
	}
}

#pragma mark -
#pragma mark Utilities

- (void)enforceFloodControl
{
	if (self.isConnected == NO) {
		return;
	}

	[self.transport enforceFloodControl];
}

- (void)openSecuredConnectionCertificateModal
{
	[self.transport exportSecureConnectionInformation:^(NSString * _Nullable policyName, tls_protocol_version_t protocolType, tls_ciphersuite_t cipherSuites, NSArray<NSData *> *certificateChain) {
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

		(void)
		[RCMTrustPanel presentTrustPanelInWindow:[NSApp keyWindow]
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

/* trustBlock is called exactly once: with the user's answer, or with NO
 when the panel can't be shown or the connection goes away first */
- (void)openInsecureCertificateTrustPanel:(RCMTrustResponse)trustBlock
{
	if (self.trustPanel != nil) {
		trustBlock(NO);

		return;
	}

	__block BOOL panelPresented = NO;

	[self.transport exportSecureConnectionInformation:^(NSString * _Nullable policyName, tls_protocol_version_t protocolType, tls_ciphersuite_t cipherSuites, NSArray<NSData *> *certificateChain) {
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

									 IRCConnection *strongSelf = weakSelf;

									 strongSelf.trustPanel = nil;

									 /* Dismissed because the connection closed */
									 if (strongSelf.trustPanelDoNotInvokeCompletionBlock) {
										 strongSelf.trustPanelDoNotInvokeCompletionBlock = NO;

										 trusted = NO;
									 }

									 ((RCMTrustResponse)contextInfo)(trusted);
								 }
									 contextInfo:trustBlock];

		panelPresented = (self.trustPanel != nil);
	}];

	if (panelPresented == NO) {
		LogToConsoleError("Couldn't show the certificate trust panel; refusing the certificate");

		trustBlock(NO);
	}
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

	/* PONG replies go to the head of the send queue and don't
	 wait for flood control: a late PONG gets us disconnected */
	BOOL priority = [line hasPrefix:@"PONG"];

	[self.transport sendData:dataToSend priority:priority];
}

- (void)clearSendQueue
{
	[self.transport clearSendQueue];
}

#pragma mark -
#pragma mark Transport Delegate (main queue)

- (void)ircConnectionWillConnectToProxy:(NSString *)proxyHost port:(uint16_t)proxyPort
{
	[self.client ircConnection:self willConnectToProxy:proxyHost port:proxyPort];
}

- (void)ircConnectionDidConnectToHost:(nullable NSString *)host
{
	self.connectedAddress = host;

	self.isConnecting = NO;
	self.isConnected = YES;

	[self.client ircConnectionDidConnect:self];
}

- (void)ircConnectionDidSecureConnectionWithProtocolType:(tls_protocol_version_t)protocolType cipherSuite:(tls_ciphersuite_t)cipherSuite
{
	self.isSecured = YES;

	if (self.config.identityClientSideCertificate != nil) {
		self.isConnectedWithClientSideCertificate = YES;
	}

	[self.client ircConnectionDidSecureConnection:self withProtocolType:protocolType cipherSuite:cipherSuite];
}

- (void)ircConnectionDidCloseReadStream
{
	self.EOFReceived = YES;

	[self.client ircConnectionDidCloseReadStream:self];
}

- (void)ircConnectionDidDisconnectWithError:(nullable NSError *)disconnectError
{
	[self closeInsecureCertificateTrustPanel];

	[self endConnectionActivity];

	[self resetState];

	self.transport = nil;

	[self.client ircConnection:self didDisconnectWithError:disconnectError];
}

- (void)ircConnectionDidReceiveData:(NSData *)data
{
	NSString *dataString = [self convertFromCommonEncoding:data];

	if (dataString == nil) {
		return;
	}

	[self.client ircConnection:self didReceiveData:dataString];
}

- (void)ircConnectionRequestInsecureCertificateTrust:(RCMTrustResponse)trustBlock
{
	[self openInsecureCertificateTrustPanel:trustBlock];
}

- (void)ircConnectionWillSendData:(NSData *)data
{
	NSString *dataString = [self convertFromCommonEncoding:data];

	if (dataString == nil) {
		return;
	}

	[self.client ircConnection:self willSendData:dataString];
}

- (void)ircConnectionDidSendData
{
	self.isSending = NO;
}

@end

NS_ASSUME_NONNULL_END
