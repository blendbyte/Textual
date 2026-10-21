/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "NSStringHelper.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "IRCClientConfig.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionTransportPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCCapabilityNegotiatorPrivate.h"
#import "IRCBouncerAccountPrivate.h"
#import "IRCBouncerProbePrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Without an answer by then, the bouncer is given up on (not while the
 certificate is being looked at) */
static NSTimeInterval const IRCBouncerProbeTimeout = 20.0;

/* How long the answer to registering a certificate is waited for; the
 login with it alone decides either way */
static NSTimeInterval const IRCBouncerProbeRegistrationTimeout = 5.0;

@interface IRCBouncerProbe () <IRCConnectionTransportDelegate>
@property (nonatomic, copy) IRCBouncerAccount *account;
@property (nonatomic, strong, nullable) IRCConnectionTransport *transport;
@property (nonatomic, strong) NSMutableArray<NSString *> *offeredCapabilities;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, copy, nullable) NSString *networksBatchToken;
@property (nonatomic, strong, nullable) IRCZNCNetworkListReader *zncReader;
@property (nonatomic, copy, nullable) RCMTrustResponse pendingTrustBlock; // while the connection waits for the answer
@property (nonatomic, strong, nullable) SFCertificateTrustPanel *trustPanel;
@property (nonatomic, copy, nullable) NSString *untrustedPolicyName; // the certificate asked about, kept for the panel
@property (nonatomic, copy, nullable) NSArray<NSData *> *untrustedCertificateChain;
@property (nonatomic, assign) BOOL certificateQuestionShown;
@property (nonatomic, copy, nullable) NSData *acceptedCertificate; // trusted after the bouncer hung up: accepted on the next try
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, assign, readwrite) BOOL isSecured;
@property (nonatomic, assign, readwrite) BOOL isLoggedIn;
@property (nonatomic, assign, readwrite) IRCBouncerKind kind;
@property (nonatomic, copy, readwrite, nullable) NSString *bouncerVersion;
@property (nonatomic, assign, readwrite) BOOL finished;
@property (nonatomic, strong, readwrite, nullable) IRCBouncerNetworkList *networkList;
@property (nonatomic, assign, readwrite) IRCBouncerProbeError error;
@property (nonatomic, copy, readwrite, nullable) NSString *errorDetail;
@property (nonatomic, assign, readwrite) IRCBouncerProbeCertificateLogin certificateLogin;
@property (nonatomic, assign) BOOL triesCertificateAlone; // the second connection, after registering it
@property (nonatomic, assign) BOOL awaitsRegistrationReply;
@property (nonatomic, assign) BOOL usesExternalLogin; // SASL EXTERNAL asked for
@end

@implementation IRCBouncerProbe

- (instancetype)initWithAccount:(IRCBouncerAccount *)account
{
	NSParameterAssert(account != nil);

	if ((self = [super init])) {
		self.account = account;

		/* Trusted before: not asked again */
		self.acceptedCertificate = account.trustedServerCertificate;

		self.offeredCapabilities = [NSMutableArray array];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark -
#pragma mark Starting and Ending

- (void)start
{
	NSAssert((self.transport == nil), @"Not while connected");

	IRCBouncerAccount *account = self.account;

	/* As a new server would connect */
	IRCClientConfig *defaults = [IRCClientConfig new];

	IRCConnectionConfigMutable *socketConfig = [IRCConnectionConfigMutable new];

	socketConfig.serverAddress = account.serverAddress;
	socketConfig.serverPort = account.serverPort;

	socketConfig.connectionPrefersSecuredConnection = account.prefersSecuredConnection;
	socketConfig.connectionShouldValidateCertificateChain = defaults.validateServerCertificateChain;

	socketConfig.identityClientSideCertificate = account.identityClientSideCertificate;
	socketConfig.connectionPrefersModernCiphersOnly = [TPCPreferences preferModernCiphers];

	socketConfig.cipherSuites = defaults.cipherSuites;

	socketConfig.proxyType = defaults.proxyType;

	socketConfig.floodControlDelayInterval = defaults.floodControlDelayTimerInterval;
	socketConfig.floodControlMaximumMessages = defaults.floodControlMaximumMessages;

	self.transport = [[IRCConnectionTransport alloc] initWithConfig:socketConfig delegate:self];

	[self.transport open];

	[self restartTimeout];
}

- (void)cancel
{
	self.cancelled = YES;

	[self closeConnection];
}

- (void)closeConnection
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timedOut) object:nil];

	if (self.trustPanel) {
		[RCMTrustPanel dismissTrustPanel:self.trustPanel];

		self.trustPanel = nil;
	}

	if (self.pendingTrustBlock) {
		self.pendingTrustBlock(NO);

		self.pendingTrustBlock = nil;
	}

	if (self.isLoggedIn) {
		[self sendLine:@"QUIT"];
	}

	[self.transport close];

	self.transport = nil;
}

- (void)finishWithNetworks:(IRCBouncerNetworkList *)networkList
{
	if (self.finished) {
		return;
	}

	self.networkList = networkList;

	/* The networks are read: now the certificate is registered */
	if (self.setsUpCertificate && self.triesCertificateAlone == NO) {
		[self registerCertificate];

		return;
	}

	if (self.logsInWithCertificateAlone) {
		self.certificateLogin = IRCBouncerProbeCertificateLoginWorks;
	}

	self.finished = YES;

	[self closeConnection];

	[self changed];
}

- (void)failWithError:(IRCBouncerProbeError)error detail:(nullable NSString *)detail
{
	if (self.finished) {
		return;
	}

	/* The certificate alone, after registering it, wasn't taken: the
	 networks were read with the password, which stays */
	if (self.triesCertificateAlone && self.setsUpCertificate && error != IRCBouncerProbeErrorCertificateNotTrusted) {
		LogToConsoleInfo("Bouncer probe: the certificate alone wasn't taken (%ld)", (long)error);

		[self finishWithCertificateLogin:IRCBouncerProbeCertificateLoginUnsupported];

		return;
	}

	self.error = error;
	self.errorDetail = detail;

	self.finished = YES;

	[self closeConnection];

	[self changed];
}

- (void)changed
{
	if (self.cancelled) {
		return;
	}

	[self.delegate bouncerProbeDidChange:self];
}

- (void)restartTimeout
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timedOut) object:nil];

	[self performSelector:@selector(timedOut) withObject:nil afterDelay:IRCBouncerProbeTimeout];
}

- (void)timedOut
{
	/* Not while the certificate is being looked at */
	if (self.error == IRCBouncerProbeErrorCertificateNotTrusted) {
		return;
	}

	[self failWithError:IRCBouncerProbeErrorTimedOut detail:nil];
}

#pragma mark -
#pragma mark Certificate

- (nullable NSData *)trustedCertificate
{
	return self.acceptedCertificate;
}

- (BOOL)wantsCertificateTrust
{
	return (self.untrustedCertificateChain != nil && self.certificateQuestionShown == NO);
}

- (void)trustCertificateInWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	NSString *policyName = self.untrustedPolicyName;
	NSArray<NSData *> *certificateChain = self.untrustedCertificateChain;

	if (policyName == nil || certificateChain.count == 0 || self.trustPanel != nil) {
		return;
	}

	self.certificateQuestionShown = YES;

	SecTrustRef trustRef = [RCMSecureTransport trustFromCertificateChain:certificateChain withPolicyName:policyName];

	if (trustRef == NULL) {
		[self certificateTrusted:NO];

		return;
	}

	__weak IRCBouncerProbe *weakSelf = self;

	self.trustPanel =
	[RCMTrustPanel presentTrustPanelInWindow:window
										body:TXTLS(@"Prompts[85z-qw]", policyName)
									   title:TXTLS(@"Prompts[m8b-58]", policyName)
							   defaultButton:TXTLS(@"Prompts[zjw-bd]")
							 alternateButton:TXTLS(@"Prompts[qso-2g]")
									trustRef:trustRef
							 completionBlock:^(SecTrustRef trustRef, BOOL trusted, id contextInfo) {
								 CFRelease(trustRef);

								 [weakSelf certificateTrusted:trusted];
							 }];

	if (self.trustPanel == nil) {
		[self certificateTrusted:NO];
	}
}

- (void)certificateTrusted:(BOOL)trusted
{
	self.trustPanel = nil;

	RCMTrustResponse trustBlock = self.pendingTrustBlock;

	self.pendingTrustBlock = nil;

	if (trusted == NO) {
		self.finished = NO;

		[self failWithError:IRCBouncerProbeErrorCertificateNotTrusted detail:nil];

		if (trustBlock) {
			trustBlock(NO);
		}

		return;
	}

	/* Not asked again on the next connection (the certificate login's second) */
	self.acceptedCertificate = self.untrustedCertificateChain.firstObject;

	/* The bouncer is still waiting */
	if (trustBlock && self.transport) {
		self.error = IRCBouncerProbeErrorNone;

		[self restartTimeout];

		trustBlock(YES);

		[self changed];

		return;
	}

	/* It hung up meanwhile: again, accepting this certificate */
	[self startAgainAcceptingCertificate:self.untrustedCertificateChain.firstObject];
}

- (void)startAgainAcceptingCertificate:(nullable NSData *)certificate
{
	[self closeConnection];

	self.acceptedCertificate = certificate;

	self.untrustedPolicyName = nil;
	self.untrustedCertificateChain = nil;
	self.certificateQuestionShown = NO;

	self.offeredCapabilities = [NSMutableArray array];
	self.networksBatchToken = nil;
	self.zncReader = nil;

	self.isConnected = NO;
	self.isSecured = NO;
	self.isLoggedIn = NO;
	self.kind = IRCBouncerKindUnknown;
	self.bouncerVersion = nil;
	self.networkList = nil;
	self.error = IRCBouncerProbeErrorNone;
	self.errorDetail = nil;
	self.finished = NO;

	[self start];

	[self changed];
}

#pragma mark -
#pragma mark Certificate Login

/* A certificate and a password: the password logs in, the certificate is registered */
- (BOOL)setsUpCertificate
{
	return (self.account.identityClientSideCertificate != nil && self.account.password.length > 0);
}

- (BOOL)logsInWithCertificateAlone
{
	if (self.account.identityClientSideCertificate == nil) {
		return NO;
	}

	return (self.triesCertificateAlone || self.account.password.length == 0);
}

- (void)registerCertificate
{
	self.certificateLogin = IRCBouncerProbeCertificateLoginSettingUp;

	switch (self.kind) {
		case IRCBouncerKindSoju:
		{
			/* Offered only with client-cert-auth on */
			if ([self.offeredCapabilities containsObject:@"soju.im/client-cert"] == NO) {
				[self finishWithCertificateLogin:IRCBouncerProbeCertificateLoginUnsupported];

				return;
			}

			[self sendLine:@"PRIVMSG BouncerServ :device-certificate create -label Textual"];

			break;
		}
		case IRCBouncerKindZNC:
		{
			[self sendLine:@"PRIVMSG *certauth :add"];

			break;
		}
		default:
		{
			[self finishWithCertificateLogin:IRCBouncerProbeCertificateLoginUnsupported];

			return;
		}
	}

	self.awaitsRegistrationReply = YES;

	[self restartTimeout];

	[self performSelector:@selector(registrationReplyTimedOut) withObject:nil afterDelay:IRCBouncerProbeRegistrationTimeout];

	[self changed];
}

/* *certauth or BouncerServ answered (in any language): the login with the
 certificate alone tells whether it took. *status answers for a module
 ZNC doesn't have. */
- (BOOL)receiveRegistrationReply:(IRCMessage *)m
{
	if (self.awaitsRegistrationReply == NO) {
		return NO;
	}

	NSString *sender = m.senderNickname;

	if (self.kind == IRCBouncerKindZNC && [sender isEqualToString:@"*status"]) {
		self.awaitsRegistrationReply = NO;

		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registrationReplyTimedOut) object:nil];

		LogToConsoleInfo("Bouncer probe: ZNC has no certauth");

		[self finishWithCertificateLogin:IRCBouncerProbeCertificateLoginUnsupported];

		return YES;
	}

	if ([sender isEqualToString:@"*certauth"] == NO && [sender isEqualToString:@"BouncerServ"] == NO) {
		return NO;
	}

	[self registrationReplyTimedOut];

	return YES;
}

- (void)registrationReplyTimedOut
{
	if (self.awaitsRegistrationReply == NO) {
		return;
	}

	self.awaitsRegistrationReply = NO;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registrationReplyTimedOut) object:nil];

	[self startWithCertificateAlone];
}

/* A second connection, the networks kept */
- (void)startWithCertificateAlone
{
	[self closeConnection];

	self.triesCertificateAlone = YES;

	self.offeredCapabilities = [NSMutableArray array];
	self.networksBatchToken = nil;
	self.zncReader = nil;
	self.usesExternalLogin = NO;

	self.isConnected = NO;
	self.isSecured = NO;
	self.isLoggedIn = NO;

	[self start];

	[self changed];
}

/* Done, with the networks read before */
- (void)finishWithCertificateLogin:(IRCBouncerProbeCertificateLogin)certificateLogin
{
	if (self.finished) {
		return;
	}

	self.certificateLogin = certificateLogin;

	self.awaitsRegistrationReply = NO;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(registrationReplyTimedOut) object:nil];

	self.finished = YES;

	[self closeConnection];

	[self changed];
}

#pragma mark -
#pragma mark Transport Delegate

- (void)ircConnectionWillConnectToProxy:(NSString *)proxyHost port:(uint16_t)proxyPort
{
}

- (void)ircConnectionDidConnectToHost:(nullable NSString *)host
{
	if (self.finished) {
		return;
	}

	self.isConnected = YES;

	NSString *username = self.account.username;

	/* A nickname for the bouncer to accept until it has its own */
	NSString *nickname = (([username onlyContainsCharactersFromCharacterSet:[NSCharacterSet Ato9UnderscoreDash]]) ? username : @"Textual");

	[self sendLine:@"CAP LS 302"];
	[self sendLine:[NSString stringWithFormat:@"NICK %@", nickname]];
	[self sendLine:[NSString stringWithFormat:@"USER %@ 0 * :Textual", nickname]];

	[self changed];
}

- (void)ircConnectionDidSecureConnectionWithProtocolType:(tls_protocol_version_t)protocolType cipherSuite:(tls_ciphersuite_t)cipherSuite
{
	self.isSecured = YES;

	[self changed];
}

- (void)ircConnectionDidCloseReadStream
{
	if (self.finished || self.error == IRCBouncerProbeErrorCertificateNotTrusted) {
		return;
	}

	[self failWithError:IRCBouncerProbeErrorClosed detail:nil];
}

- (void)ircConnectionDidDisconnectWithError:(nullable NSError *)disconnectError
{
	if (self.finished) {
		return;
	}

	/* Waiting for the answer about the certificate: it decides what comes next */
	if (self.error == IRCBouncerProbeErrorCertificateNotTrusted) {
		self.pendingTrustBlock = nil;

		self.transport = nil;

		return;
	}

	if (self.isConnected) {
		[self failWithError:IRCBouncerProbeErrorClosed detail:disconnectError.localizedDescription];
	} else {
		[self failWithError:IRCBouncerProbeErrorCannotConnect detail:disconnectError.localizedDescription];
	}
}

- (void)ircConnectionRequestInsecureCertificateTrust:(RCMTrustResponse)trustBlock
{
	if (self.finished || self.cancelled) {
		trustBlock(NO);

		return;
	}

	__block NSString *policyName = nil;
	__block NSArray<NSData *> *certificateChain = nil;

	[self.transport exportSecureConnectionInformation:^(NSString * _Nullable policy, tls_protocol_version_t protocolType, tls_ciphersuite_t cipherSuite, NSArray<NSData *> *chain) {
		policyName = policy;
		certificateChain = chain;
	}];

	/* Trusted already, before the bouncer hung up */
	if (self.acceptedCertificate && [certificateChain.firstObject isEqualToData:self.acceptedCertificate]) {
		trustBlock(YES);

		return;
	}

	if (policyName == nil || certificateChain.count == 0) {
		trustBlock(NO);

		return;
	}

	self.pendingTrustBlock = trustBlock;

	self.untrustedPolicyName = policyName;
	self.untrustedCertificateChain = certificateChain;

	self.error = IRCBouncerProbeErrorCertificateNotTrusted;

	[self changed];
}

- (void)ircConnectionWillSendData:(NSData *)data
{
}

- (void)ircConnectionDidSendData
{
}

/* One line each, without its line break (the socket splits them) */
- (void)ircConnectionDidReceiveData:(NSData *)data
{
	if (self.finished) {
		return;
	}

	NSString *line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if (line == nil) {
		line = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	}

	line = [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	if (line.length == 0) {
		return;
	}

	LogToConsoleDebug("Bouncer probe received: %{private}@", line);

	IRCMessage *message = [[IRCMessage alloc] initWithLine:line];

	if (message) {
		[self receiveMessage:message];
	}
}

#pragma mark -
#pragma mark Messages

- (void)sendLine:(NSString *)line
{
	NSParameterAssert(line != nil);

	LogToConsoleDebug("Bouncer probe sent: %{private}@", ([line hasPrefix:@"PASS "] || [line hasPrefix:@"AUTHENTICATE "] ? [line substringToIndex:4] : line));

	NSData *data = [[line stringByAppendingString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding];

	[self.transport sendData:data priority:NO];
}

- (void)receiveMessage:(IRCMessage *)m
{
	NSString *command = m.command.uppercaseString;

	if ([command isEqualToString:@"PING"]) {
		[self sendLine:[NSString stringWithFormat:@"PONG :%@", [m paramAt:0]]];

		return;
	}

	if ([command isEqualToString:@"CAP"]) {
		[self receiveCapability:m];

		return;
	}

	if ([command isEqualToString:@"AUTHENTICATE"]) {
		if (self.usesExternalLogin) {
			[self sendLine:@"AUTHENTICATE +"];
		} else {
			[self sendPlainLogin];
		}

		return;
	}

	if ([command isEqualToString:@"BATCH"]) {
		[self receiveBatch:m];

		return;
	}

	if ([command isEqualToString:@"BOUNCER"]) {
		[self receiveBouncer:m];

		return;
	}

	if ([command isEqualToString:@"PRIVMSG"]) {
		if ([self receiveRegistrationReply:m] == NO) {
			[self receiveZNCStatusMessage:m];
		}

		return;
	}

	if ([command isEqualToString:@"ERROR"]) {
		[self failWithError:((self.isLoggedIn) ? IRCBouncerProbeErrorClosed : IRCBouncerProbeErrorWrongLogin) detail:[m sequence:0]];

		return;
	}

	switch (m.commandNumeric) {
		case 1: // RPL_WELCOME
		{
			[self registered];

			break;
		}
		case 4: // RPL_MYINFO: <name> <version> …
		{
			if (self.kind == IRCBouncerKindSoju && m.paramsCount > 2) {
				self.bouncerVersion = [m paramAt:2];
			}

			break;
		}
		case 903: // RPL_SASLSUCCESS
		{
			self.isLoggedIn = YES;

			[self sendLine:@"CAP END"];

			[self changed];

			break;
		}
		case 464: // ERR_PASSWDMISMATCH (ZNC)
		case 902: // ERR_NICKLOCKED
		case 904: // ERR_SASLFAIL
		case 905: // ERR_SASLTOOLONG
		case 906: // ERR_SASLABORTED
		{
			[self failWithError:IRCBouncerProbeErrorWrongLogin detail:[m sequence:1]];

			break;
		}
		default:
		{
			break;
		}
	}
}

/* CAP LS 302 may come in several lines ("CAP * LS * :…" until the last) */
- (void)receiveCapability:(IRCMessage *)m
{
	if (m.paramsCount < 3) {
		return;
	}

	NSString *subcommand = [m paramAt:1].uppercaseString;

	if ([subcommand isEqualToString:@"LS"]) {
		BOOL moreFollow = (m.paramsCount > 3 && [[m paramAt:2] isEqualToString:@"*"]);

		NSString *capabilities = [m paramAt:(moreFollow ? 3 : 2)];

		for (NSString *capability in [capabilities componentsSeparatedByString:@" "]) {
			if (capability.length > 0) {
				[self.offeredCapabilities addObject:[IRCCapabilityNegotiator capabilityName:capability value:NULL]];
			}
		}

		if (moreFollow == NO) {
			[self recognise:m];
		}

		return;
	}

	if ([subcommand isEqualToString:@"ACK"]) {
		NSArray *acknowledged = [[m paramAt:2] componentsSeparatedByString:@" "];

		if ([acknowledged containsObject:@"sasl"]) {
			self.usesExternalLogin = self.logsInWithCertificateAlone;

			[self sendLine:((self.usesExternalLogin) ? @"AUTHENTICATE EXTERNAL" : @"AUTHENTICATE PLAIN")];
		} else {
			[self sendLine:@"CAP END"];
		}

		return;
	}

	if ([subcommand isEqualToString:@"NAK"]) {
		[self sendLine:@"CAP END"];
	}
}

/* soju says so with its capability, ZNC with its name (irc.znc.in) */
- (void)recognise:(IRCMessage *)m
{
	NSArray<NSString *> *offered = self.offeredCapabilities;

	if ([offered containsObject:@"soju.im/bouncer-networks"]) {
		self.kind = IRCBouncerKindSoju;

		NSMutableArray *request = [NSMutableArray arrayWithObject:@"soju.im/bouncer-networks"];

		for (NSString *capability in @[@"sasl", @"batch", @"message-tags"]) {
			if ([offered containsObject:capability]) {
				[request addObject:capability];
			}
		}

		[self sendLine:[NSString stringWithFormat:@"CAP REQ :%@", [request componentsJoinedByString:@" "]]];
	} else if ([m.senderNickname isEqualToString:@"irc.znc.in"]) {
		/* By its name only: other servers offer znc.in/ capabilities too (Ergo's playback) */
		self.kind = IRCBouncerKindZNC;

		/* Without a network: ZNC picks the first, or none. With certauth
		 the certificate logs in, and PASS only names the user (the colon
		 keeps ZNC from taking the user from USER). */
		if (self.logsInWithCertificateAlone) {
			[self sendLine:[NSString stringWithFormat:@"PASS %@:", self.account.username]];
		} else {
			[self sendLine:[NSString stringWithFormat:@"PASS %@:%@", self.account.username, (self.account.password ?: @"")]];
		}

		[self sendLine:@"CAP END"];
	} else {
		[self failWithError:IRCBouncerProbeErrorNotABouncer detail:nil];

		return;
	}

	[self changed];
}

- (void)sendPlainLogin
{
	NSString *username = self.account.username;

	NSString *login = [NSString stringWithFormat:@"%@%C%@%C%@", username, 0x00, username, 0x00, (self.account.password ?: @"")];

	NSString *encoded = [[login dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];

	for (NSString *part in [encoded splitWithMaximumLength:400]) {
		[self sendLine:[@"AUTHENTICATE " stringByAppendingString:part]];
	}

	if ((encoded.length % 400) == 0) {
		[self sendLine:@"AUTHENTICATE +"];
	}
}

- (void)registered
{
	/* Logged in with the certificate alone, after registering it */
	if (self.triesCertificateAlone && self.setsUpCertificate) {
		self.isLoggedIn = YES;

		[self finishWithCertificateLogin:IRCBouncerProbeCertificateLoginWorks];

		return;
	}

	switch (self.kind) {
		case IRCBouncerKindSoju:
		{
			[self sendLine:@"BOUNCER LISTNETWORKS"];

			break;
		}
		case IRCBouncerKindZNC:
		{
			self.isLoggedIn = YES;

			self.zncReader = [IRCZNCNetworkListReader new];

			[self sendLine:@"PRIVMSG *status :ListNetworks"];

			break;
		}
		default:
		{
			/* No CAP at all */
			[self failWithError:IRCBouncerProbeErrorNotABouncer detail:nil];

			return;
		}
	}

	[self changed];
}

- (void)receiveBatch:(IRCMessage *)m
{
	NSString *token = [m paramAt:0];

	if ([token hasPrefix:@"+"] && [[m paramAt:1] isEqualToString:@"soju.im/bouncer-networks"]) {
		self.networksBatchToken = [token substringFromIndex:1];

		self.networkList = [IRCBouncerNetworkList new];
	} else if ([token hasPrefix:@"-"] && [[token substringFromIndex:1] isEqualToString:self.networksBatchToken]) {
		[self finishWithNetworks:self.networkList];
	}
}

- (void)receiveBouncer:(IRCMessage *)m
{
	if (m.paramsCount < 3 || [[m paramAt:0] isEqualToStringIgnoringCase:@"NETWORK"] == NO) {
		return;
	}

	if (self.networkList == nil) {
		self.networkList = [IRCBouncerNetworkList new];
	}

	[self.networkList updateNetwork:[m paramAt:1] attributes:[m paramAt:2]];

	/* Without batch, each network comes alone; the list is complete when nothing follows */
	if (self.networksBatchToken == nil) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(networksWithoutBatchComplete) object:nil];

		[self performSelector:@selector(networksWithoutBatchComplete) withObject:nil afterDelay:1.0];
	}
}

- (void)networksWithoutBatchComplete
{
	[self finishWithNetworks:self.networkList];
}

- (void)receiveZNCStatusMessage:(IRCMessage *)m
{
	IRCZNCNetworkListReader *reader = self.zncReader;

	if (reader == nil || [m.senderNickname isEqualToString:@"*status"] == NO || m.paramsCount < 2) {
		return;
	}

	[reader readLine:[m paramAt:1]];

	if (reader.finished) {
		self.zncReader = nil;

		[self finishWithNetworks:reader.networkList];
	}
}

@end

NS_ASSUME_NONNULL_END
