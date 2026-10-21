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

NS_ASSUME_NONNULL_BEGIN

@class IRCBouncerNetwork, IRCBouncerNetworkList, IRCClientConfig, IRCServer;

/* Which bouncer an account logs in to: found when it is added */
typedef NS_ENUM(NSUInteger, IRCBouncerKind) {
	IRCBouncerKindUnknown = 0,
	IRCBouncerKindZNC,
	IRCBouncerKindSoju
};

/* A login to a bouncer (ZNC or soju). Each of its networks is a normal server
 (IRCClientConfig) linked to it by -bouncerAccountIdentifier; when such a
 server connects, it takes the address, port, TLS and login from here, so a
 change reaches every network. The password is in the Keychain. */
@interface IRCBouncerAccount : XRPortablePropertyDict
@property (readonly, copy) NSString *uniqueIdentifier;
@property (readonly, copy, nullable) NSString *name; // chosen in Edit Bouncer; nil shows the address
@property (readonly, copy) NSString *displayName; // the name, else the address
@property (readonly) IRCBouncerKind kind;
@property (readonly, copy) NSString *serverAddress;
@property (readonly) uint16_t serverPort;
@property (readonly) BOOL prefersSecuredConnection;
@property (readonly, copy) NSString *username; // the bouncer's own, without a network
@property (readonly, copy, nullable) NSString *password; // from the Keychain unless changed in this copy
@property (readonly, copy, nullable) NSData *identityClientSideCertificate; // a Keychain reference, as in IRCClientConfig; logs in without the password once registered
@property (readonly, copy, nullable) NSData *trustedServerCertificate; // the bouncer's own (DER), trusted in Add or Edit Bouncer: its networks take exactly that one without asking
@property (readonly) BOOL checksForNetworkChanges; // tells when networks are added or removed (on by default)
@property (readonly, copy) NSArray<NSString *> *ignoredNetworks; // networks whose change notices were ignored

/* The server a linked network connects to: the account's address, port and
 TLS, and for ZNC the login "username/network:password" as the server
 password (ZNC offers SASL only with an extra module), or "username/network:"
 without a password when its client certificate logs in (certauth). soju logs in with
 SASL (EXTERNAL with the certificate). */
- (IRCServer *)serverForNetwork:(nullable NSString *)network;

/* The network a server added by hand reaches through this bouncer: its
 address and port are the account's, and its username or server password
 is "username/network" (ZNC's and soju's login, "@client" ignored); nil
 for anything else */
- (nullable NSString *)networkOfServerAddedByHand:(IRCClientConfig *)config;

/* The bouncer logins of a server added by hand: "user/network" as its
 username or before ":" in its server password ("@client" left out), as
 pairs of user and network; and the password the bouncer gets (after ":",
 else the server password) */
+ (NSArray<NSArray<NSString *> *> *)bouncerLoginsOfServerAddedByHand:(IRCClientConfig *)config;
+ (nullable NSString *)bouncerPasswordOfServerAddedByHand:(IRCClientConfig *)config;

/* What changed on the bouncer, from its list of networks: its networks
 without a server in Textual (knownNetworks: the networks of the servers
 linked to it or added by hand, identifiers or names), and the networks of
 linked servers it doesn't have any more. Ignored networks are left out;
 for ZNC a name matches in any case, as ZNC finds them. */
- (NSArray<IRCBouncerNetwork *> *)networksAddedIn:(IRCBouncerNetworkList *)networkList knownNetworks:(NSArray<NSString *> *)knownNetworks;
- (NSArray<NSString *> *)networksRemovedFrom:(IRCBouncerNetworkList *)networkList linkedNetworks:(NSArray<NSString *> *)linkedNetworks;

- (BOOL)isNetwork:(NSString *)network sameAsNetwork:(NSString *)otherNetwork;
- (BOOL)isNetwork:(NSString *)network inNetworks:(NSArray<NSString *> *)networks;

- (void)writePasswordToKeychain;
- (void)destroyPasswordKeychainItem;
@end

@interface IRCBouncerAccountMutable : IRCBouncerAccount
@property (nonatomic, copy, readwrite, nullable) NSString *name;
@property (nonatomic, assign, readwrite) IRCBouncerKind kind;
@property (nonatomic, copy, readwrite) NSString *serverAddress;
@property (nonatomic, assign, readwrite) uint16_t serverPort;
@property (nonatomic, assign, readwrite) BOOL prefersSecuredConnection;
@property (nonatomic, copy, readwrite) NSString *username;
@property (nonatomic, copy, readwrite, nullable) NSString *password;
@property (nonatomic, copy, readwrite, nullable) NSData *identityClientSideCertificate;
@property (nonatomic, copy, readwrite, nullable) NSData *trustedServerCertificate;
@property (nonatomic, assign, readwrite) BOOL checksForNetworkChanges;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *ignoredNetworks;
@end

/* A network on a bouncer as soju describes it (soju.im/bouncer-networks):
 an identifier that never changes and attributes such as name, state
 (connected, connecting, disconnected), host, port, tls, nickname, error */
@interface IRCBouncerNetwork : NSObject
- (instancetype)initWithIdentifier:(NSString *)networkIdentifier attributes:(NSDictionary<NSString *, NSString *> *)attributes;

@property (readonly, copy) NSString *networkIdentifier;
@property (readonly, copy) NSDictionary<NSString *, NSString *> *attributes;
@property (readonly, copy) NSString *name; // the name attribute, else the host, else the identifier
@property (readonly, copy, nullable) NSString *state;
@end

typedef NS_ENUM(NSUInteger, IRCBouncerNetworkChange) {
	IRCBouncerNetworkChangeNone = 0,
	IRCBouncerNetworkChangeAdded,
	IRCBouncerNetworkChangeChanged,
	IRCBouncerNetworkChangeRemoved
};

/* The networks of a bouncer, kept from BOUNCER NETWORK messages */
@interface IRCBouncerNetworkList : NSObject
@property (readonly, copy) NSArray<IRCBouncerNetwork *> *networks; // in the order the bouncer named them

- (nullable IRCBouncerNetwork *)networkWithIdentifier:(NSString *)networkIdentifier;

/* Added at the end, or in place of one with the same identifier */
- (void)addNetwork:(IRCBouncerNetwork *)network;

/* BOUNCER NETWORK <netid> <attributes>: "*" removes the network; otherwise
 the attributes are added to it (a new one is added), and an attribute
 without a value is removed */
- (IRCBouncerNetworkChange)updateNetwork:(NSString *)networkIdentifier attributes:(NSString *)attributes;

/* "name=My\sNetwork;state=connected" as a dictionary, values unescaped as
 message tags; an attribute without a value is an empty string */
+ (NSDictionary<NSString *, NSString *> *)attributesFromString:(NSString *)attributes;
@end

/* ZNC's answer to ListNetworks, read by its layout only (the headers, Yes and
 No are translated): a border of + and -, the header, a border, one row per
 network, a border. A network's identifier is its name (the first column);
 it is connected when the IRC Server column is filled, its nickname is the
 IRC User column's up to "!". Without networks, ZNC sends one line instead. */
@interface IRCZNCNetworkListReader : NSObject
@property (readonly) BOOL finished;
@property (readonly, strong) IRCBouncerNetworkList *networkList;

/* A line from *status; NO when it isn't part of the answer */
- (BOOL)readLine:(NSString *)line;
@end

NS_ASSUME_NONNULL_END
