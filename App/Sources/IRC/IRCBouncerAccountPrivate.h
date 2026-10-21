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

@class IRCServer;

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
@property (readonly, copy, nullable) NSData *identityClientSideCertificate; // a Keychain reference, as in IRCClientConfig
@property (readonly) BOOL checksForNetworkChanges; // tells when networks are added or removed (on by default)
@property (readonly, copy) NSArray<NSString *> *ignoredNetworks; // networks whose change notices were ignored

/* The server a linked network connects to: the account's address, port and
 TLS, and for ZNC the login "username/network:password" as the server
 password (ZNC offers SASL only with an extra module). soju logs in with SASL. */
- (IRCServer *)serverForNetwork:(nullable NSString *)network;

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
@property (nonatomic, assign, readwrite) BOOL checksForNetworkChanges;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *ignoredNetworks;
@end

NS_ASSUME_NONNULL_END
