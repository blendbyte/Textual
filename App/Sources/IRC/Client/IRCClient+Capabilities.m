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

	if (entry == NULL) {
		return NO;
	}

	if (entry->request == ClientIRCv3SupportedCapabilityEchoMessage) {
		return [TPCPreferences enableEchoMessageCapability];
	}

	return YES;
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
		if ([modifier isEqualToString:@"+"]) {
			[self sendSASLIdentificationInformation];
		}
	}

	[self postReceivedMessage:m];
}

#pragma mark -
#pragma mark Capability Negotiator Delegate

- (BOOL)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator shouldRequestCapability:(NSString *)capability value:(nullable NSString *)value
{
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
	ClientIRCv3SupportedCapability identificationMechanism = 0;

	if (self.socket.isConnectedWithClientSideCertificate &&
		self.config.saslAuthenticationDisableExternalMechanism == NO)
	{
		if (capabilityOptions.count == 0 ||
			[capabilityOptions containsObjectIgnoringCase:@"EXTERNAL"])
		{
			identificationMechanism = ClientIRCv3SupportedCapabilitySASLExternal;

			[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLExternal];
		}
	}

	if (identificationMechanism == 0 &&
		self.config.nicknamePassword.length > 0)
	{
		if (capabilityOptions.count == 0 ||
			[capabilityOptions containsObjectIgnoringCase:@"PLAIN"])
		{
			identificationMechanism = ClientIRCv3SupportedCapabilitySASLPlainText;

			[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLPlainText];
		}
	}

	if (identificationMechanism != 0) {
		[self enablePendingCapability:ClientIRCv3SupportedCapabilitySASLGeneric];
	}
}

- (void)sendSASLIdentificationInformation
{
	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilityIsInSASLNegotiation] == NO) {
		return;
	}

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLPlainText])
	{
		/* Like registration (USER), an empty username means the nickname (R3.14) */
		NSString *username = self.config.username;

		if (username.length == 0) {
			username = self.config.nickname;
		}

		NSString *authString = [NSString stringWithFormat:@"%@%C%@%C%@",
								 username, 0x00,
								 username, 0x00,
								 self.config.nicknamePassword];

		NSArray *authStrings = [authString base64EncodingWithLineLength:400];

		for (NSString *string in authStrings) {
			[self sendCapabilityAuthenticate:string];
		}

		if (authStrings.count == 0 || ((NSString *)authStrings.lastObject).length == 400) {
			[self sendCapabilityAuthenticate:@"+"];
		}
	}
	else if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLExternal])
	{
		[self sendCapabilityAuthenticate:@"+"];
	}
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

	if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLPlainText]) {
		[self sendCapabilityAuthenticate:@"PLAIN"];

		return YES;
	} else if ([self isPendingCapabilityEnabled:ClientIRCv3SupportedCapabilitySASLExternal]) {
		[self sendCapabilityAuthenticate:@"EXTERNAL"];

		return YES;
	}

	return NO;
}

- (void)resetSASLNegotiation
{
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLGeneric];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLPlainText];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilitySASLExternal];
	[self disablePendingCapability:ClientIRCv3SupportedCapabilityIsInSASLNegotiation];

	[self disableCapability:ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL];
}

@end

NS_ASSUME_NONNULL_END
