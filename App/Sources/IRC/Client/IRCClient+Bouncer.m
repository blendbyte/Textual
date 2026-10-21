/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "IRCBouncerAccountPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCClientBouncerNetworksDidChangeNotification = @"IRCClientBouncerNetworksDidChangeNotification";

@implementation IRCClient (Bouncer)

/* soju.im/bouncer-networks: a server linked to a soju account logs in to
 the account with SASL and is bound to its network (BOUNCER BIND) before
 registration ends; the bouncer's networks are kept in bouncerNetworks
 (all of them when a list arrives, then each change soju reports).
 ZNC has no such interface: its networks come from ListNetworks to *status,
 a table read by its layout (IRCZNCNetworkListReader) and kept out of view. */

/* How long the answer to an automatic ListNetworks is waited for */
static NSTimeInterval const IRCClientZNCNetworkListTimeout = 30.0;

- (BOOL)isLinkedToSojuAccount
{
	return (self.bouncerAccount.kind == IRCBouncerKindSoju);
}

- (BOOL)shouldRequestBouncerCapability:(ClientIRCv3SupportedCapability)capability
{
	/* Asked only for linked servers: on a connection that isn't bound,
	 soju then stops showing every network's channels in one */
	IRCBouncerAccount *account = self.bouncerAccount;

	if (account.kind != IRCBouncerKindSoju) {
		return NO;
	}

	if (capability == ClientIRCv3SupportedCapabilityBouncerNetworksNotify) {
		return account.checksForNetworkChanges;
	}

	return YES;
}

/* The bouncer's login only until it succeeded: once bound, soju offers
 the network's SASL (CAP NEW, even before registration ends) and passes
 it on, so that one is the network's own account, from the server's settings */
- (BOOL)usesBouncerLogin
{
	return (self.isLoggedIn == NO && self.isAuthenticatedWithSASL == NO && self.isLinkedToSojuAccount);
}

- (nullable NSString *)bouncerSASLUsername
{
	if (self.usesBouncerLogin == NO) {
		return nil;
	}

	return self.bouncerAccount.username;
}

- (nullable NSString *)bouncerSASLPassword
{
	if (self.usesBouncerLogin == NO) {
		return nil;
	}

	return self.bouncerAccount.password;
}

- (void)bindBouncerNetworkBeforeRegistration
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBouncerNetworks] == NO) {
		return;
	}

	NSString *networkIdentifier = self.config.bouncerNetwork;

	if (networkIdentifier.length == 0 || self.isLinkedToSojuAccount == NO) {
		return;
	}

	[self send:@"BOUNCER", @"BIND", networkIdentifier, nil];
}

- (void)requestBouncerNetworks
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityBouncerNetworks]) {
		[self send:@"BOUNCER", @"LISTNETWORKS", nil];

		return;
	}

	if (self.isConnectedToZNC && self.bouncerAccount.kind == IRCBouncerKindZNC) {
		self.zncNetworkListReader = [IRCZNCNetworkListReader new];
		self.zncNetworkListRequestDate = [NSDate date];

		[self sendCommand:@"ListNetworks" toZNCModuleNamed:@"status"];
	}
}

/* soju sends its list unasked (-notify); ZNC is asked once registered */
- (void)requestBouncerNetworksAfterRegistration
{
	IRCBouncerAccount *account = self.bouncerAccount;

	if (account.kind != IRCBouncerKindZNC || account.checksForNetworkChanges == NO) {
		return;
	}

	[self requestBouncerNetworks];
}

/* A line of the answer to our ListNetworks: read, not shown */
- (BOOL)receiveZNCNetworkListLine:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	IRCZNCNetworkListReader *reader = self.zncNetworkListReader;

	if (reader == nil) {
		return NO;
	}

	if ([m.command isEqualToString:@"PRIVMSG"] == NO || m.paramsCount < 2 || [self nickname:m.senderNickname isZNCUser:@"status"] == NO) {
		return NO;
	}

	if ([self.zncNetworkListRequestDate timeIntervalSinceNow] < (-IRCClientZNCNetworkListTimeout)) {
		self.zncNetworkListReader = nil;

		return NO;
	}

	if ([reader readLine:[m paramAt:1]] == NO) {
		return NO;
	}

	if (reader.finished) {
		self.zncNetworkListReader = nil;

		self.bouncerNetworksReceived = reader.networkList;

		[self bouncerNetworksChanged];
	}

	return YES;
}

- (nullable IRCBouncerNetworkList *)bouncerNetworks
{
	return self.bouncerNetworksReceived;
}

- (void)resetBouncerNetworks
{
	self.bouncerNetworksReceived = nil;
	self.bouncerNetworksBatchList = nil;

	self.zncNetworkListReader = nil;
	self.zncNetworkListRequestDate = nil;
}

/* BOUNCER NETWORK <netid> <attributes>; the other replies (BIND and the
 ADDNETWORK family) carry nothing to keep */
- (void)receiveBouncer:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if (m.paramsCount < 3 || [[m paramAt:0] isEqualToStringIgnoringCase:@"NETWORK"] == NO) {
		return;
	}

	NSString *networkIdentifier = [m paramAt:1];
	NSString *attributes = [m paramAt:2];

	/* Part of a whole list (a batch being processed) */
	IRCBouncerNetworkList *batchList = self.bouncerNetworksBatchList;

	if (batchList) {
		[batchList updateNetwork:networkIdentifier attributes:attributes];

		return;
	}

	IRCBouncerNetworkList *list = self.bouncerNetworksReceived;

	if (list == nil) {
		list = [IRCBouncerNetworkList new];

		self.bouncerNetworksReceived = list;
	}

	if ([list updateNetwork:networkIdentifier attributes:attributes] == IRCBouncerNetworkChangeNone) {
		return;
	}

	[self bouncerNetworksChanged];
}

/* A soju.im/bouncer-networks batch is the whole list: it replaces the one kept */
- (void)processBouncerNetworksBatchMessage:(IRCMessageBatchMessage *)batchMessage
{
	NSParameterAssert(batchMessage != nil);

	IRCBouncerNetworkList *list = [IRCBouncerNetworkList new];

	self.bouncerNetworksBatchList = list;

	[self recursivelyProcessBatchMessage:batchMessage];

	self.bouncerNetworksBatchList = nil;

	self.bouncerNetworksReceived = list;

	[self bouncerNetworksChanged];
}

- (void)bouncerNetworksChanged
{
	LogToConsoleInfo("Bouncer networks: %{public}@", [self.bouncerNetworksReceived.networks componentsJoinedByString:@", "]);

	[RZNotificationCenter() postNotificationName:IRCClientBouncerNetworksDidChangeNotification object:self];
}

@end

NS_ASSUME_NONNULL_END
