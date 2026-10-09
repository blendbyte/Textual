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

/* A portion of this source file contains copyrighted work derived from one or more
 3rd-party, open source projects. The use of this work is hereby acknowledged. */

/* This source file contains work that originated from the Chat Core 
 framework of the Colloquy project. The source in question is in relation
 to the handling of SASL authentication requests. The license of the 
 Chat Core project is as follows: 

 This document can be found mirrored at the author's website:
 <http://colloquy.info/project/browser/trunk/Resources/BSD%20License.txt>

 No actual copyright is presented in the license file or the actual 
 source file in which this work was obtained so the work is assumed to
 be Copyright © 2000 - 2012 the Colloquy IRC Client

 ------- License -------

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:

 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote
 products derived from this software without specific prior written
 permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
 NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <objc/message.h>
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocol.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOpenLink.h"
#import "TLOSoundPlayer.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TLOSpokenNotificationPrivate.h"
#import "TLOTimer.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelBanListSheetPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "IRC.h"
#import "IRCAddressBook.h"
#import "IRCAddressBookMatchCachePrivate.h"
#import "IRCAddressBookUserTrackingPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannelModePrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientRequestedCommandsPrivate.h"
#import "IRCColorFormatPrivate.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCExtrasPrivate.h"
#import "IRCHighlightLogEntryPrivate.h"
#import "IRCHighlightMatchCondition.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCModeInfo.h"
#import "IRCPrefix.h"
#import "IRCNumerics.h"
#import "IRCSendingMessage.h"
#import "IRCServerPrivate.h"
#import "IRCTimedCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCSASLECDSAPrivate.h"
#import "IRCSASLSCRAMPrivate.h"
#import "IRCStrictTransportSecurityPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Capability Table

/* Every capability Textual requests: its name, the bit that stands for it
 while negotiating, and the bit enabled when the server acknowledges it
 (the ZNC and plan.io variants enable the standard one) */
typedef struct {
	const char *name;
	ClientIRCv3SupportedCapability request;
	ClientIRCv3SupportedCapability enables;
} IRCClientCapabilityTableEntry;

static const IRCClientCapabilityTableEntry IRCClientCapabilityTable[] = {
	{ "account-notify",			ClientIRCv3SupportedCapabilityAccountNotify,		ClientIRCv3SupportedCapabilityAccountNotify },
	{ "account-tag",			ClientIRCv3SupportedCapabilityAccountTag,			ClientIRCv3SupportedCapabilityAccountTag },
	{ "away-notify",			ClientIRCv3SupportedCapabilityAwayNotify,			ClientIRCv3SupportedCapabilityAwayNotify },
	{ "batch",					ClientIRCv3SupportedCapabilityBatch,				ClientIRCv3SupportedCapabilityBatch },
	{ "chghost",				ClientIRCv3SupportedCapabilityChangeHost,			ClientIRCv3SupportedCapabilityChangeHost },
	{ "draft/chathistory",		ClientIRCv3SupportedCapabilityChatHistory,			ClientIRCv3SupportedCapabilityChatHistory },
	{ "draft/read-marker",		ClientIRCv3SupportedCapabilityReadMarker,			ClientIRCv3SupportedCapabilityReadMarker },
	{ "echo-message",			ClientIRCv3SupportedCapabilityEchoMessage,			ClientIRCv3SupportedCapabilityEchoMessage },
	{ "extended-join",			ClientIRCv3SupportedCapabilityExtendedJoin,			ClientIRCv3SupportedCapabilityExtendedJoin },
	{ "identify-ctcp",			ClientIRCv3SupportedCapabilityIdentifyCTCP,			ClientIRCv3SupportedCapabilityIdentifyCTCP },
	{ "identify-msg",			ClientIRCv3SupportedCapabilityIdentifyMsg,			ClientIRCv3SupportedCapabilityIdentifyMsg },
	{ "invite-notify",			ClientIRCv3SupportedCapabilityInviteNotify,			ClientIRCv3SupportedCapabilityInviteNotify },
	{ "message-tags",			ClientIRCv3SupportedCapabilityMessageTags,			ClientIRCv3SupportedCapabilityMessageTags },
	{ "multi-prefix",			ClientIRCv3SupportedCapabilityMultiPrefix,			ClientIRCv3SupportedCapabilityMultiPrefix },
	{ "sasl",					ClientIRCv3SupportedCapabilitySASLGeneric,			ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL }, // enabled once authenticated
	{ "server-time",			ClientIRCv3SupportedCapabilityServerTime,			ClientIRCv3SupportedCapabilityServerTime },
	{ "setname",				ClientIRCv3SupportedCapabilitySetName,				ClientIRCv3SupportedCapabilitySetName },
	{ "standard-replies",		ClientIRCv3SupportedCapabilityStandardReplies,		ClientIRCv3SupportedCapabilityStandardReplies },
	{ "userhost-in-names",		ClientIRCv3SupportedCapabilityUserhostInNames,		ClientIRCv3SupportedCapabilityUserhostInNames },
	{ "plan.io/playback",		ClientIRCv3SupportedCapabilityPlanioPlayback,		ClientIRCv3SupportedCapabilityPlayback },
	{ "znc.in/playback",		ClientIRCv3SupportedCapabilityZNCPlaybackModule,	ClientIRCv3SupportedCapabilityPlayback },
	{ "znc.in/self-message",	ClientIRCv3SupportedCapabilityZNCSelfMessage,		ClientIRCv3SupportedCapabilityZNCSelfMessage },
	{ "znc.in/server-time",		ClientIRCv3SupportedCapabilityZNCServerTime,		ClientIRCv3SupportedCapabilityServerTime },
	{ "znc.in/server-time-iso",	ClientIRCv3SupportedCapabilityZNCServerTimeISO,		ClientIRCv3SupportedCapabilityServerTime },
	{ "znc.in/tlsinfo",			ClientIRCv3SupportedCapabilityZNCCertInfoModule,	ClientIRCv3SupportedCapabilityZNCCertInfoModule }
};

static const IRCClientCapabilityTableEntry * _Nullable IRCClientCapabilityTableEntryNamed(NSString *capabilityString)
{
	for (size_t i = 0; i < (sizeof(IRCClientCapabilityTable) / sizeof(IRCClientCapabilityTable[0])); i++) {
		if ([capabilityString isEqualToStringIgnoringCase:@(IRCClientCapabilityTable[i].name)]) {
			return &IRCClientCapabilityTable[i];
		}
	}

	return NULL;
}

@implementation IRCClient (Capabilities)

#pragma mark -
#pragma mark Strict Transport Security

/* A policy is kept only from a secure connection whose certificate passed
 validation (not one the user accepted anyway); offered over plaintext,
 it only moves this connection to TLS, once */
- (void)processStrictTransportSecurityValue:(nullable NSString *)value
{
	IRCConnectionConfig *socketConfig = self.socket.config;

	NSString *host = socketConfig.serverAddress;

	if (host.length == 0 || host.isIPAddress) {
		return;
	}

	NSInteger port = 0;
	NSInteger duration = 0;

	[IRCStrictTransportSecurity parseValue:value port:&port duration:&duration];

	if (self.socket.isSecured) {
		if (duration < 0 ||
			socketConfig.connectionShouldValidateCertificateChain == NO ||
			self.socket.certificateTrustedByUser)
		{
			return;
		}

		[[IRCStrictTransportSecurity sharedPolicies] storePolicyForHost:host port:socketConfig.serverPort duration:duration];

		return;
	}

	if (port < 0 || self.isTerminating) {
		return;
	}

	[self printDebugInformationToConsole:TXTLS(@"IRC[st5-u1]", host, port)];

	[self disconnectThen:^(IRCClient *client) {
		[client connect];
	}];

	/* -disconnect would destroy these so we set them after... */
	self.temporaryServerAddressOverride = host;
	self.temporaryServerPortOverride = (uint16_t)port;
	self.temporaryServerPrefersSecuredConnection = YES;
}

#pragma mark -
#pragma mark Server Capability

- (ClientIRCv3SupportedCapability)capacities
{
	return self.capabilities;
}

- (NSString *)enabledCapacitiesStringValue
{
	return self.enabledCapabilitiesStringValue;
}

- (void)enableCapability:(ClientIRCv3SupportedCapability)capability
{
	if ([self isCapabilityEnabled:capability] == NO) {
		self->_capabilities |= capability;
	}
}

- (void)disableCapability:(ClientIRCv3SupportedCapability)capability
{
	if ([self isCapabilityEnabled:capability]) {
		self->_capabilities &= ~capability;
	}
}

- (BOOL)isCapabilityEnabled:(ClientIRCv3SupportedCapability)capability
{
	return ((self->_capabilities & capability) == capability);
}

- (void)enablePendingCapability:(ClientIRCv3SupportedCapability)capability
{
	atomic_fetch_or(&self->_capabilitiesPending, capability);
}

- (void)disablePendingCapability:(ClientIRCv3SupportedCapability)capability
{
	atomic_fetch_and(&self->_capabilitiesPending, ~capability);
}

- (BOOL)isPendingCapabilityEnabled:(ClientIRCv3SupportedCapability)capability
{
	return ((atomic_load(&self->_capabilitiesPending) & capability) == capability);
}

- (void)resetCapabilities
{
	self.capabilities = 0;

	atomic_store(&self->_capabilitiesPending, 0);

	self.saslMechanismsToTry = nil;
	self.saslMechanism = nil;
	self.saslSCRAM = nil;
	self.saslECDSAKey = nil;
	self.saslIncomingData = nil;

	[self.capabilityNegotiator reset];
}

- (NSString *)enabledCapabilitiesStringValue
{
	NSMutableArray *enabledCapabilities = [NSMutableArray array];

	void (^appendValue)(ClientIRCv3SupportedCapability, NSString *) = ^(ClientIRCv3SupportedCapability capability, NSString *stringValue) {
		if ([self isCapabilityEnabled:capability]) {
			[enabledCapabilities addObject:stringValue];
		}
	};

	appendValue(ClientIRCv3SupportedCapabilityAccountNotify, @"account-notify");
	appendValue(ClientIRCv3SupportedCapabilityAccountTag, @"account-tag");
	appendValue(ClientIRCv3SupportedCapabilityAwayNotify, @"away-notify");
	appendValue(ClientIRCv3SupportedCapabilityBatch, @"batch");
	appendValue(ClientIRCv3SupportedCapabilityChangeHost, @"chghost");
	appendValue(ClientIRCv3SupportedCapabilityChatHistory, @"draft/chathistory");
	appendValue(ClientIRCv3SupportedCapabilityReadMarker, @"draft/read-marker");
	appendValue(ClientIRCv3SupportedCapabilityEchoMessage, @"echo-message");
	appendValue(ClientIRCv3SupportedCapabilityExtendedJoin, @"extended-join");
	appendValue(ClientIRCv3SupportedCapabilityIdentifyCTCP, @"identify-ctcp");
	appendValue(ClientIRCv3SupportedCapabilityIdentifyMsg, @"identify-msg");
	appendValue(ClientIRCv3SupportedCapabilityInviteNotify, @"invite-notify");
	appendValue(ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL, @"sasl");
	appendValue(ClientIRCv3SupportedCapabilityMessageTags, @"message-tags");
	appendValue(ClientIRCv3SupportedCapabilityMultiPrefix, @"multi-prefix");
	appendValue(ClientIRCv3SupportedCapabilityPlayback, @"playback");
	appendValue(ClientIRCv3SupportedCapabilityServerTime, @"server-time");
	appendValue(ClientIRCv3SupportedCapabilitySetName, @"setname");
	appendValue(ClientIRCv3SupportedCapabilityStandardReplies, @"standard-replies");
	appendValue(ClientIRCv3SupportedCapabilityUserhostInNames, @"userhost-in-names");
	appendValue(ClientIRCv3SupportedCapabilityZNCCertInfoModule, @"znc.in/tlsinfo");
	appendValue(ClientIRCv3SupportedCapabilityZNCSelfMessage, @"znc.in/self-message");

	return [enabledCapabilities componentsJoinedByString:@", "];
}

- (void)pauseCapabilityNegotiation
{
	[self.capabilityNegotiator pause];
}

- (void)resumeCapabilityNegotiation
{
	[self.capabilityNegotiator resume];
}

- (BOOL)isCapabilitySupported:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	const IRCClientCapabilityTableEntry *entry = IRCClientCapabilityTableEntryNamed(capabilityString);

	return (entry != NULL);
}

- (void)receiveCapabilityOrAuthenticationRequest:(IRCMessage *)m
{
	/* Implementation based off Colloquy's own. */
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	NSString *command = m.command;
	NSString *modifier = [m paramAt:0];

	if ([command isEqualToStringIgnoringCase:@"CAP"])
	{
		NSAssertReturn([m paramsCount] > 1);

		NSString *subcommand = [m paramAt:1];

		NSArray *parameters = [m.params subarrayWithRange:NSMakeRange(2, (m.paramsCount - 2))];

		[self.capabilityNegotiator receiveCapabilityReply:subcommand parameters:parameters];
	}
	else if ([command isEqualToStringIgnoringCase:@"AUTHENTICATE"])
	{
		[self receiveSASLData:modifier];
	}

	[self postReceivedMessage:m];
}

#pragma mark -
#pragma mark Capability Negotiator Delegate

- (BOOL)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator shouldRequestCapability:(NSString *)capability value:(nullable NSString *)value
{
	/* sts is never requested, only acted on */
	if ([capability isEqualToStringIgnoringCase:@"sts"]) {
		[self processStrictTransportSecurityValue:value];

		return NO;
	}

	if ([self isCapabilitySupported:capability] == NO) {
		return NO;
	}

	const IRCClientCapabilityTableEntry *entry = IRCClientCapabilityTableEntryNamed(capability);

	/* Already enabled (a repeated LS or NEW) */
	if ([self isCapabilityEnabled:entry->enables]) {
		return NO;
	}

	/* SASL only with a mechanism Textual can use */
	if (entry->request == ClientIRCv3SupportedCapabilitySASLGeneric) {
		[self processPendingCapabilityForSASL:[value componentsSeparatedByString:@","]];

		return [self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLGeneric];
	}

	return YES;
}

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator didEnableCapability:(NSString *)capability
{
	const IRCClientCapabilityTableEntry *entry = IRCClientCapabilityTableEntryNamed(capability);

	if (entry == NULL) {
		return;
	}

	/* Negotiation waits while SASL authenticates */
	if (entry->request == ClientIRCv3SupportedCapabilitySASLGeneric) {
		if ([self sendSASLIdentificationRequest]) {
			[self pauseCapabilityNegotiation];
		}

		return;
	}

	[self enableCapability:entry->enables];
}

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator didDisableCapability:(NSString *)capability
{
	const IRCClientCapabilityTableEntry *entry = IRCClientCapabilityTableEntryNamed(capability);

	if (entry == NULL || entry->request == ClientIRCv3SupportedCapabilitySASLGeneric) {
		return;
	}

	[self disableCapability:entry->enables];
}

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator sendCapabilityCommand:(NSString *)subcommand data:(nullable NSString *)data
{
	[self sendCapability:subcommand data:data];
}

#pragma mark -
#pragma mark SASL Negotiation

- (void)processPendingCapabilityForSASL:(nullable NSArray<NSString *> *)capabilityOptions
{
	BOOL canUseExternal = (self.socket.isConnectedWithClientSideCertificate &&
						   self.config.saslAuthenticationDisableExternalMechanism == NO);

	BOOL haveECDSAKey = (self.config.saslECDSAKey.length > 0);

	BOOL havePassword = (self.config.nicknamePassword.length > 0);

	NSArray *mechanisms = IRCSASLMechanismsToTry((capabilityOptions ?: @[]), canUseExternal, haveECDSAKey, havePassword);

	self.saslMechanismsToTry = [mechanisms mutableCopy];

	if (mechanisms.count > 0) {
		[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLGeneric];
	}
}

/* Like registration (USER), an empty username means the nickname (R3.14) */
- (NSString *)saslUsername
{
	NSString *username = self.config.username;

	if (username.length == 0) {
		username = self.config.nickname;
	}

	return username;
}

- (BOOL)sendSASLIdentificationRequest
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL]) {
		return NO;
	}

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation]) {
		return NO;
	}

	[self enablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

	if ([self sendNextSASLMechanism] == NO) {
		[self disablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

		return NO;
	}

	return YES;
}

/* Starts the next mechanism (EXTERNAL, ECDSA-NIST256P-CHALLENGE, SCRAM-SHA-512,
 SCRAM-SHA-256, PLAIN); NO when none is left */
- (BOOL)sendNextSASLMechanism
{
	self.saslSCRAM = nil;
	self.saslECDSAKey = nil;
	self.saslStep = 0;
	self.saslIncomingData = nil;

	NSString *mechanism = self.saslMechanismsToTry.firstObject;

	if (mechanism == nil) {
		self.saslMechanism = nil;

		return NO;
	}

	[self.saslMechanismsToTry removeObjectAtIndex:0];

	self.saslMechanism = mechanism;

	IRCSASLSCRAMHash hash = IRCSASLSCRAMHashSHA256;

	if ([IRCSASLSCRAM hash:&hash forMechanismName:mechanism]) {
		self.saslSCRAM = [[IRCSASLSCRAM alloc] initWithHash:hash
												   username:[self saslUsername]
												   password:self.config.nicknamePassword
												clientNonce:nil];
	} else if ([mechanism isEqualToString:IRCSASLECDSAMechanismName]) {
		NSString *storedKey = self.config.saslECDSAKey;

		self.saslECDSAKey = ((storedKey) ? [IRCSASLECDSAKey keyWithStoredValue:storedKey] : nil);

		if (self.saslECDSAKey == nil) {
			LogToConsoleError("The SASL login key in the Keychain is not a P-256 key");

			return [self sendNextSASLMechanism];
		}
	}

	[self sendCapabilityAuthenticate:mechanism];

	return YES;
}

/* RPL_SASLMECHS: only these are worth trying after the current one fails */
- (void)receiveSASLMechanismList:(NSString *)mechanisms
{
	NSParameterAssert(mechanisms != nil);

	NSArray *offered = [mechanisms componentsSeparatedByString:@","];

	[self.saslMechanismsToTry filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *mechanism, id bindings) {
		return [offered containsObjectIgnoringCase:mechanism];
	}]];
}

/* AUTHENTICATE from the server: base64 in parts of 400 characters, a part
 shorter than 400 (or "+") ending it */
- (void)receiveSASLData:(NSString *)data
{
	NSParameterAssert(data != nil);

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation] == NO) {
		return;
	}

	NSMutableString *buffer = self.saslIncomingData;

	if (buffer == nil) {
		buffer = [NSMutableString string];
	}

	if ([data isEqualToString:@"+"] == NO) {
		[buffer appendString:data];
	}

	if (data.length == 400) {
		self.saslIncomingData = buffer;

		return;
	}

	self.saslIncomingData = nil;

	NSData *challenge = [NSData data];

	if (buffer.length > 0) {
		challenge = [[NSData alloc] initWithBase64EncodedString:buffer options:0];

		if (challenge == nil) {
			[self abortSASLAuthentication];

			return;
		}
	}

	[self respondToSASLChallenge:challenge];
}

- (void)sendSASLResponse:(NSString *)response
{
	NSParameterAssert(response != nil);

	[self sendSASLResponseData:[response dataUsingEncoding:NSUTF8StringEncoding]];
}

/* A response in base64 parts of 400, followed by "+" when empty or when the last part is exactly 400 */
- (void)sendSASLResponseData:(NSData *)response
{
	NSParameterAssert(response != nil);

	NSArray *parts = @[];

	if (response.length > 0) {
		parts = [[response base64EncodedStringWithOptions:0] splitWithMaximumLength:400];
	}

	for (NSString *part in parts) {
		[self sendCapabilityAuthenticate:part];
	}

	if (parts.count == 0 || ((NSString *)parts.lastObject).length == 400) {
		[self sendCapabilityAuthenticate:@"+"];
	}
}

- (void)abortSASLAuthentication
{
	self.saslSCRAM = nil;
	self.saslECDSAKey = nil;

	/* The server answers with ERR_SASLABORTED, which ends negotiation */
	[self sendCapabilityAuthenticate:@"*"];
}

- (void)respondToSASLChallenge:(NSData *)challenge
{
	NSParameterAssert(challenge != nil);

	NSString *mechanism = self.saslMechanism;

	if ([mechanism isEqualToString:@"PLAIN"]) {
		NSString *username = [self saslUsername];

		[self sendSASLResponse:[NSString stringWithFormat:@"%@%C%@%C%@", username, 0x00, username, 0x00, self.config.nicknamePassword]];
	} else if ([mechanism isEqualToString:@"EXTERNAL"]) {
		[self sendCapabilityAuthenticate:@"+"];
	} else if (self.saslECDSAKey) {
		[self respondToECDSAChallenge:challenge];
	} else if (self.saslSCRAM) {
		NSString *challengeString = [[NSString alloc] initWithData:challenge encoding:NSUTF8StringEncoding];

		if (challengeString == nil) {
			[self abortSASLAuthentication];

			return;
		}

		[self respondToSCRAMChallenge:challengeString];
	}
}

- (void)respondToECDSAChallenge:(NSData *)challenge
{
	switch (self.saslStep) {
		case 0: // the server is ready: the account to log in to
		{
			self.saslStep = 1;

			[self sendSASLResponse:[self saslUsername]];

			break;
		}
		case 1: // the challenge, signed
		{
			NSData *signature = [self.saslECDSAKey signatureForChallenge:challenge];

			if (signature == nil) {
				[self abortSASLAuthentication];

				return;
			}

			self.saslStep = 2;

			[self sendSASLResponseData:signature];

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)respondToSCRAMChallenge:(NSString *)challenge
{
	IRCSASLSCRAM *scram = self.saslSCRAM;

	switch (self.saslStep) {
		case 0: // the server is ready
		{
			self.saslStep = 1;

			[self sendSASLResponse:scram.clientFirstMessage];

			break;
		}
		case 1: // server-first
		{
			if ([scram processServerFirstMessage:challenge] == NO) {
				[self abortSASLAuthentication];

				return;
			}

			self.saslStep = 2;

			/* PBKDF2 can take a while */
			__weak IRCClient *weakSelf = self;

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
				NSString *clientFinalMessage = [scram clientFinalMessage];

				dispatch_async(dispatch_get_main_queue(), ^{
					IRCClient *client = weakSelf;

					if (client == nil || client.saslSCRAM != scram) {
						return;
					}

					if (clientFinalMessage == nil) {
						[client abortSASLAuthentication];

						return;
					}

					client.saslStep = 3;

					[client sendSASLResponse:clientFinalMessage];
				});
			});

			break;
		}
		case 3: // server-final
		{
			/* Never continue (or fall back to PLAIN) with a server that can't prove it knows the password */
			if ([scram verifyServerFinalMessage:challenge] == NO) {
				[self printDebugInformationToConsole:TXTLS(@"IRC[sc7-v1]", scram.mechanismName)];

				[self abortSASLAuthentication];

				return;
			}

			self.saslStep = 4;

			[self sendCapabilityAuthenticate:@"+"];

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)resetSASLNegotiation
{
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLGeneric];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

	self.saslMechanismsToTry = nil;
	self.saslMechanism = nil;
	self.saslSCRAM = nil;
	self.saslECDSAKey = nil;
	self.saslIncomingData = nil;

	[self disableCapability:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL];
}

@end

NS_ASSUME_NONNULL_END
