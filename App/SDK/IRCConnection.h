/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCConnectionConfig;

@interface IRCConnection : NSObject
@property (readonly, weak) IRCClient *client;
@property (readonly, copy) IRCConnectionConfig *config;
@property (readonly) BOOL isConnected;
@property (readonly) BOOL isConnectedWithClientSideCertificate;
@property (readonly) BOOL isConnecting;
@property (readonly) BOOL isDisconnecting;
@property (readonly) BOOL isSecured;
@property (readonly) BOOL isSending;
@property (readonly) BOOL EOFReceived;
@property (readonly, nullable) NSString *connectedAddress; // nil if connected to a proxy
@property (readonly, copy) NSString *uniqueIdentifier;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfig:(IRCConnectionConfig *)config onClient:(IRCClient *)client NS_DESIGNATED_INITIALIZER;

- (void)open;
- (void)close;

- (void)sendLine:(NSString *)line;

- (void)clearSendQueue;
@end

@protocol IRCConnectionDelegate <NSObject>
@required

- (void)ircConnection:(IRCConnection *)sender
   willConnectToProxy:(NSString *)proxyHost
				 port:(uint16_t)proxyPort;
- (void)ircConnectionDidConnect:(IRCConnection *)sender;
- (void)ircConnectionDidSecureConnection:(IRCConnection *)sender
						withProtocolType:(tls_protocol_version_t)protocolType
							 cipherSuite:(tls_ciphersuite_t)cipherSuite;
- (void)ircConnectionDidCloseReadStream:(IRCConnection *)sender;
- (void)ircConnection:(IRCConnection *)sender didDisconnectWithError:(nullable NSError *)disconnectError;
- (void)ircConnection:(IRCConnection *)sender didReceiveData:(NSString *)data;
- (void)ircConnection:(IRCConnection *)sender willSendData:(NSString *)data;
@end

NS_ASSUME_NONNULL_END
