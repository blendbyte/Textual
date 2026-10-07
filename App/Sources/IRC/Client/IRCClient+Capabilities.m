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
#import "IRCTimerCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Capabilities)

#pragma mark -
#pragma mark Server Capability

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
	@synchronized (self.capabilitiesPending) {
		[self.capabilitiesPending addObjectWithoutDuplication:@(capability)];
	}
}

- (void)disablePendingCapability:(ClientIRCv3SupportedCapability)capability
{
	@synchronized (self.capabilitiesPending) {
		[self.capabilitiesPending removeObject:@(capability)];
	}
}

- (BOOL)isPendingCapabilityEnabled:(ClientIRCv3SupportedCapability)capability
{
	@synchronized (self.capabilitiesPending) {
		return [self.capabilitiesPending containsObject:@(capability)];
	}
}

- (nullable NSString *)capabilityStringValue:(ClientIRCv3SupportedCapability)capability
{
	NSString *stringValue = nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch"

	switch (capability) {
		case ClientIRCv3SupportedCapabilityAwayNotify:
		{
			stringValue = @"away-notify";

			break;
		}
		case ClientIRCv3SupportedCapabilityBatch:
		{
			stringValue = @"batch";

			break;
		}
		case ClientIRCv3SupportedCapabilityChangeHost:
		{
			stringValue = @"chghost";

			break;
		}
		case ClientIRCv3SupportedCapabilityEchoMessage:
		{
			stringValue = @"echo-message";

			break;
		}
		case ClientIRCv3SupportedCapabilityIdentifyCTCP:
		{
			stringValue = @"identify-ctcp";

			break;
		}
		case ClientIRCv3SupportedCapabilityIdentifyMsg:
		{
			stringValue = @"identify-msg";

			break;
		}
		case ClientIRCv3SupportedCapabilityMultiPrefix:
		{
			stringValue = @"multi-prefix";

			break;
		}
		case ClientIRCv3SupportedCapabilityPlayback:
		{
			stringValue = @"playback";

			break;
		}
		case ClientIRCv3SupportedCapabilitySASLExternal:
		case ClientIRCv3SupportedCapabilitySASLPlainText:
		case ClientIRCv3SupportedCapabilitySASLGeneric:
		case ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL:
		case ClientIRCv3SupportedCapabilityIsInSASLNegotiation:
		{
			stringValue = @"sasl";

			break;
		}
		case ClientIRCv3SupportedCapabilityServerTime:
		{
			stringValue = @"server-time";

			break;
		}
		case ClientIRCv3SupportedCapabilityUserhostInNames:
		{
			stringValue = @"userhost-in-names";

			break;
		}
		case ClientIRCv3SupportedCapabilityMonitorCommand:
		{
			stringValue = @"monitor-command";

			break;
		}
		case ClientIRCv3SupportedCapabilityWatchCommand:
		{
			stringValue = @"watch-command";

			break;
		}
		case ClientIRCv3SupportedCapabilityPlanioPlayback:
		{
			stringValue = @"plan.io/playback";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCCertInfoModule:
		{
			stringValue = @"znc.in/tlsinfo";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCPlaybackModule:
		{
			stringValue = @"znc.in/playback";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCSelfMessage:
		{
			stringValue = @"znc.in/self-message";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCServerTime:
		{
			stringValue = @"znc.in/server-time";

			break;
		}
		case ClientIRCv3SupportedCapabilityZNCServerTimeISO:
		{
			stringValue = @"znc.in/server-time-iso";

			break;
		}
	}

#pragma clang diagnostic pop

	return stringValue;
}

- (ClientIRCv3SupportedCapability)capabilityFromStringValue:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	if ([capabilityString isEqualToStringIgnoringCase:@"away-notify"]) {
		return ClientIRCv3SupportedCapabilityAwayNotify;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"batch"]) {
		return ClientIRCv3SupportedCapabilityBatch;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"chghost"]) {
		return ClientIRCv3SupportedCapabilityChangeHost;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"echo-message"]) {
		return ClientIRCv3SupportedCapabilityEchoMessage;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"multi-prefix"]) {
		return ClientIRCv3SupportedCapabilityMultiPrefix;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"identify-msg"]) {
		return ClientIRCv3SupportedCapabilityIdentifyMsg;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"identify-ctcp"]) {
		return ClientIRCv3SupportedCapabilityIdentifyCTCP;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"sasl"]) {
		return ClientIRCv3SupportedCapabilitySASLGeneric;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"server-time"]) {
		return ClientIRCv3SupportedCapabilityServerTime;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"userhost-in-names"]) {
		return ClientIRCv3SupportedCapabilityUserhostInNames;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"plan.io/playback"]) {
		return ClientIRCv3SupportedCapabilityPlanioPlayback;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/playback"]) {
		return ClientIRCv3SupportedCapabilityZNCPlaybackModule;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/self-message"]) {
		return ClientIRCv3SupportedCapabilityZNCSelfMessage;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time"]) {
		return ClientIRCv3SupportedCapabilityZNCServerTime;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time-iso"]) {
		return ClientIRCv3SupportedCapabilityZNCServerTimeISO;
	} else if ([capabilityString isEqualToStringIgnoringCase:@"znc.in/tlsinfo"]) {
		return ClientIRCv3SupportedCapabilityZNCCertInfoModule;
	}

	return 0;
}

- (NSString *)enabledCapabilitiesStringValue
{
	NSMutableArray *enabledCapabilities = [NSMutableArray array];

	void (^appendValue)(ClientIRCv3SupportedCapability) = ^(ClientIRCv3SupportedCapability capability) {
		if ([self isCapabilityEnabled:capability] == NO) {
			return;
		}

		NSString *stringValue = [self capabilityStringValue:capability];

		if (stringValue) {
			[enabledCapabilities addObject:stringValue];
		}
	};

	appendValue(ClientIRCv3SupportedCapabilityAwayNotify);
	appendValue(ClientIRCv3SupportedCapabilityBatch);
	appendValue(ClientIRCv3SupportedCapabilityChangeHost);
	appendValue(ClientIRCv3SupportedCapabilityEchoMessage);
	appendValue(ClientIRCv3SupportedCapabilityIdentifyCTCP);
	appendValue(ClientIRCv3SupportedCapabilityIdentifyMsg);
	appendValue(ClientIRCv3SupportedCapabilityIsIdentifiedWithSASL);
	appendValue(ClientIRCv3SupportedCapabilityMultiPrefix);
	appendValue(ClientIRCv3SupportedCapabilityPlayback);
	appendValue(ClientIRCv3SupportedCapabilityServerTime);
	appendValue(ClientIRCv3SupportedCapabilityUserhostInNames);
	appendValue(ClientIRCv3SupportedCapabilityZNCCertInfoModule);
	appendValue(ClientIRCv3SupportedCapabilityZNCPlaybackModule);
	appendValue(ClientIRCv3SupportedCapabilityZNCSelfMessage);

	NSString *stringValue = [enabledCapabilities componentsJoinedByString:@", "];

	return stringValue;
}

- (void)sendNextCapability
{
	if (self.capabilityNegotiationIsPaused) {
		return;
	}

	@synchronized (self.capabilitiesPending) {
		/* -CapabilitiesPending can contain values that are used internally for state traking 
		 and should never meet the socket. To workaround this as best we can, we scan the 
		 array for the first capability that is acceptable for negotiation. */
		NSUInteger nextCapabilityIndex =
		[self.capabilitiesPending indexOfObjectPassingTest:^BOOL(NSNumber *capabilityPending, NSUInteger index, BOOL *stop) {
			ClientIRCv3SupportedCapability capability = capabilityPending.unsignedIntegerValue;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"

			return
			(capability == ClientIRCv3SupportedCapabilityAwayNotify				||
			 capability == ClientIRCv3SupportedCapabilityBatch					||
			 capability == ClientIRCv3SupportedCapabilityChangeHost				||
			 capability == ClientIRCv3SupportedCapabilityEchoMessage			||
			 capability == ClientIRCv3SupportedCapabilityIdentifyCTCP			||
			 capability == ClientIRCv3SupportedCapabilityIdentifyMsg			||
			 capability == ClientIRCv3SupportedCapabilityMultiPrefix			||
			 capability == ClientIRCv3SupportedCapabilitySASLGeneric			||
			 capability == ClientIRCv3SupportedCapabilityServerTime				||
			 capability == ClientIRCv3SupportedCapabilityUserhostInNames		||
			 capability == ClientIRCv3SupportedCapabilityPlanioPlayback			||
			 capability == ClientIRCv3SupportedCapabilityZNCCertInfoModule		||
			 capability == ClientIRCv3SupportedCapabilityZNCPlaybackModule		||
			 capability == ClientIRCv3SupportedCapabilityZNCSelfMessage			||
			 capability == ClientIRCv3SupportedCapabilityZNCServerTime			||
			 capability == ClientIRCv3SupportedCapabilityZNCServerTimeISO);

#pragma clang diagnostic pop
		}];

		if (nextCapabilityIndex == NSNotFound) {
			[self sendCapability:@"END" data:nil];

			return;
		}

		ClientIRCv3SupportedCapability capability =
		[self.capabilitiesPending unsignedIntegerAtIndex:nextCapabilityIndex];

		[self.capabilitiesPending removeObjectAtIndex:nextCapabilityIndex];

		NSString *stringValue = [self capabilityStringValue:capability];

		[self sendCapability:@"REQ" data:stringValue];
	}
}

- (void)pauseCapabilityNegotiation
{
	self.capabilityNegotiationIsPaused = YES;
}

- (void)resumeCapabilityNegotiation
{
	self.capabilityNegotiationIsPaused = NO;

	[self sendNextCapability];
}

- (BOOL)isCapabilitySupported:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	// Information about several of these supported CAP
	// extensions can be found at: http://ircv3.atheme.org

	if ([capabilityString isEqualToStringIgnoringCase:@"echo-message"]) {
		return [TPCPreferences enableEchoMessageCapability];
	}

	return
	([capabilityString isEqualToStringIgnoringCase:@"away-notify"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"batch"]					||
	 [capabilityString isEqualToStringIgnoringCase:@"chghost"]					||
	 [capabilityString isEqualToStringIgnoringCase:@"identify-ctcp"]			||
	 [capabilityString isEqualToStringIgnoringCase:@"identify-msg"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"multi-prefix"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"sasl"]						||
	 [capabilityString isEqualToStringIgnoringCase:@"server-time"]				||
	 [capabilityString isEqualToStringIgnoringCase:@"userhost-in-names"]		||
	 [capabilityString isEqualToStringIgnoringCase:@"plan.io/playback"]			||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/playback"]			||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/self-message"]		||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time"]		||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/server-time-iso"]	||
	 [capabilityString isEqualToStringIgnoringCase:@"znc.in/tlsinfo"]);
}

- (void)toggleCapability:(NSString *)capabilityString enabled:(BOOL)enabled
{
	[self toggleCapability:capabilityString enabled:enabled isUpdateRequest:NO];
}

- (void)toggleCapability:(NSString *)capabilityString enabled:(BOOL)enabled isUpdateRequest:(BOOL)isUpdateRequest
{
	NSParameterAssert(capabilityString != nil);

	if ([capabilityString isEqualToStringIgnoringCase:@"sasl"]) {
		if (enabled) {
			if ([self sendSASLIdentificationRequest]) {
				[self pauseCapabilityNegotiation];
			}
		}

		return;
	}

	ClientIRCv3SupportedCapability capability = [self capabilityFromStringValue:capabilityString];

	if (capability == 0) {
		return;
	}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"

	if (capability == ClientIRCv3SupportedCapabilityZNCServerTime ||
		capability == ClientIRCv3SupportedCapabilityZNCServerTimeISO)
	{
		capability = ClientIRCv3SupportedCapabilityServerTime;
	}

	if (capability == ClientIRCv3SupportedCapabilityPlanioPlayback ||
		capability == ClientIRCv3SupportedCapabilityZNCPlaybackModule)
	{
		capability = ClientIRCv3SupportedCapabilityPlayback;
	}

#pragma clang diagnostic pop

	if (enabled) {
		[self enableCapability:capability];
	} else {
		[self disableCapability:capability];
	}
}

- (void)processPendingCapability:(NSString *)capabilityString
{
	NSParameterAssert(capabilityString != nil);

	NSArray *components = [capabilityString componentsSeparatedByString:@"="];

	NSString *capability = capabilityString;

	NSArray<NSString *> *capabilityOptions = nil;

	if (components.count == 2) {
		capability = components[0];

		capabilityOptions = [components[1] componentsSeparatedByString:@","];
	}

	[self processPendingCapability:capability options:capabilityOptions];
}

- (void)processPendingCapability:(NSString *)capabilityString options:(nullable NSArray<NSString *> *)capabilityOptions
{
	NSParameterAssert(capabilityString != nil);

	if ([self isCapabilitySupported:capabilityString] == NO) {
		return;
	}

	if ([capabilityString isEqualToString:@"sasl"]) {
		[self processPendingCapabilityForSASL:capabilityOptions];

		return;
	}

	ClientIRCv3SupportedCapability capability = [self capabilityFromStringValue:capabilityString];

	[self enablePendingCapability:capability];
}

- (void)receiveCapabilityOrAuthenticationRequest:(IRCMessage *)m
{
	/* Implementation based off Colloquy's own. */
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] > 0);

	NSString *command = m.command;
	NSString *modifier = [m paramAt:0];
	NSString *subcommand = [m paramAt:1];
	NSString *actions = [m sequence:2];

	if ([command isEqualToStringIgnoringCase:@"CAP"])
	{
		if ([subcommand isEqualToStringIgnoringCase:@"LS"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self processPendingCapability:cap];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"ACK"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self toggleCapability:cap enabled:YES isUpdateRequest:NO];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"NAK"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self toggleCapability:cap enabled:NO isUpdateRequest:NO];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"NEW"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self processPendingCapability:cap];
			}
		} else if ([subcommand isEqualToStringIgnoringCase:@"DEL"]) {
			NSArray *caps = [actions componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for (NSString *cap in caps) {
				[self toggleCapability:cap enabled:NO isUpdateRequest:YES];
			}
		}

		[self sendNextCapability];
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
		NSString *authString = [NSString stringWithFormat:@"%@%C%@%C%@",
								 self.config.username, 0x00,
								 self.config.username, 0x00,
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
