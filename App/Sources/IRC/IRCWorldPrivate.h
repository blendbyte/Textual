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

#import "IRCChannelConfigPrivate.h"
#import "IRCWorld.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCBouncerAccount, IRCBouncerNetwork, IRCBouncerNetworkList;

TEXTUAL_EXTERN NSString * const IRCWorldBouncerAccountsDefaultsKey;

@interface IRCWorld ()
@property (nonatomic, assign, readwrite) NSUInteger messagesSent;
@property (nonatomic, assign, readwrite) NSUInteger messagesReceived;
@property (nonatomic, assign, readwrite) uint64_t bandwidthIn;
@property (nonatomic, assign, readwrite) uint64_t bandwidthOut;
@property (nonatomic, assign) BOOL isImportingConfiguration;
/* Set by the Textual 7 import once it wrote its servers: the app restarts
 and must not save the old list over them meanwhile */
@property (nonatomic, assign) BOOL savingSuspended;
@property (nonatomic, copy, readwrite) NSArray<IRCClient *> *clientList;

- (void)setupConfiguration;

- (nullable IRCTreeItem *)findItemWithPasteboardString:(NSString *)string;
- (NSString *)pasteboardStringForItem:(IRCTreeItem *)item;

- (void)autoConnectAfterWakeup:(BOOL)afterWakeUp;

- (void)prepareForSleep;

- (void)prepareForScreenSleep;
- (void)wakeFromScreenSleep;

- (void)noteReachabilityChanged:(BOOL)reachable;

/* Quitting stops waiting for clients that are still disconnecting */
- (void)prepareForApplicationTerminationWithoutWaiting;

- (IRCClient *)createClientWithConfig:(IRCClientConfig *)config reload:(BOOL)reload;
- (IRCChannel *)createChannelWithConfig:(IRCChannelConfig *)config onClient:(IRCClient *)client add:(BOOL)add adjust:(BOOL)adjust reload:(BOOL)reload;

- (IRCChannel *)createPrivateMessage:(NSString *)nickname onClient:(IRCClient *)client asType:(IRCChannelType)type;

- (void)destroyClient:(IRCClient *)client;

- (void)destroyChannel:(IRCChannel *)channel reload:(BOOL)reload;
- (void)destroyChannel:(IRCChannel *)channel reload:(BOOL)reload part:(BOOL)partChannel;

/* Bouncer accounts: saved with the server list, their servers linked by identifier */
@property (readonly, copy) NSArray<IRCBouncerAccount *> *bouncerAccounts;

- (nullable IRCBouncerAccount *)findBouncerAccountWithId:(NSString *)identifier;

/* The servers linked to it, in the server list's order */
- (NSArray<IRCClient *> *)clientsOfBouncerAccount:(IRCBouncerAccount *)account;

/* Adds it, or replaces the account with its identifier; saves its password to the Keychain */
- (void)addBouncerAccount:(IRCBouncerAccount *)account;

/* Its servers stay as normal servers (unlinked, same address and login) or go too */
- (void)removeBouncerAccount:(IRCBouncerAccount *)account keepServers:(BOOL)keepServers;

/* The Add Bouncer sheet: the account (or the one for the same bouncer and
 login, updated), and a server for each network (named
 after it, the bouncer's nickname, no autojoin of its own: the bouncer
 rejoins); a network in linkedClients (by identifier) links that server added
 by hand instead. Returns the servers added and linked, in that order. */
- (NSArray<IRCClient *> *)addBouncerAccount:(IRCBouncerAccount *)account
							   withNetworks:(NSArray<IRCBouncerNetwork *> *)networks
							  linkedClients:(NSDictionary<NSString *, IRCClient *> *)linkedClients
									connect:(BOOL)connect;

/* A server for this network of the bouncer already: linked to an account for
 the same bouncer and login, or added by hand (see -[IRCBouncerAccount networkOfServerAddedByHand:]) */
- (nullable IRCClient *)clientAddedByHandForNetwork:(IRCBouncerNetwork *)network ofAccount:(IRCBouncerAccount *)account;

/* Read again from the preferences (after an import) */
- (void)reloadBouncerAccounts;

/* Network changes on a bouncer, from the list one of its connected servers
 has (soju's as they happen, ZNC's from when the server connected); none
 when the account doesn't check for them. New: networks without a server in
 Textual; removed: linked servers whose network the bouncer doesn't have. */
- (nullable IRCBouncerNetworkList *)networkListOfBouncerAccount:(IRCBouncerAccount *)account;
- (NSArray<IRCBouncerNetwork *> *)networksAddedToBouncerAccount:(IRCBouncerAccount *)account;
- (NSArray<IRCClient *> *)clientsRemovedFromBouncerAccount:(IRCBouncerAccount *)account;

/* Not told about again (Ignore, Keep): kept in the account's ignoredNetworks */
- (void)ignoreChangesOfNetworks:(NSArray<NSString *> *)networks ofBouncerAccount:(IRCBouncerAccount *)account;

/* The notices of its servers' windows again */
- (void)bouncerNetworksOfAccountChanged:(IRCBouncerAccount *)account;

/* Servers added by hand that go through one bouncer (the same address and
 port, the same user before "/" in their logins), offered once for linking:
 two or more with this one, else none */
- (NSArray<IRCClient *> *)clientsToOfferLinkingWith:(IRCClient *)client;

/* Not offered again (Link… or Not Now) */
- (void)rememberLinkingOfferedForClients:(NSArray<IRCClient *> *)clients;
@end

NS_ASSUME_NONNULL_END
