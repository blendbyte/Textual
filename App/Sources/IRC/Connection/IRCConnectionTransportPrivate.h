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

#import <Security/Security.h>

#import <CocoaExtensions/CocoaExtensions.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IRCConnectionSecureInformationBlock)(NSString * _Nullable policyName,
													tls_protocol_version_t protocolType,
													tls_ciphersuite_t cipherSuite,
													NSArray<NSData *> *certificateChain);

/* The connection transport (IRCConnectionTransport.swift) does all socket work
 on its own serial queue and reports to its delegate on the main queue, in the
 order things happened. */
@protocol IRCConnectionTransportDelegate <NSObject>
@required
- (void)ircConnectionWillConnectToProxy:(NSString *)proxyHost port:(uint16_t)proxyPort;

/* host is nil when connected through a proxy */
- (void)ircConnectionDidConnectToHost:(nullable NSString *)host;
- (void)ircConnectionDidSecureConnectionWithProtocolType:(tls_protocol_version_t)protocolType
											 cipherSuite:(tls_ciphersuite_t)cipherSuite;
- (void)ircConnectionDidCloseReadStream;
- (void)ircConnectionDidDisconnectWithError:(nullable NSError *)disconnectError;
- (void)ircConnectionDidReceiveData:(NSData *)data;

/* trustBlock must be called exactly once, on any queue */
- (void)ircConnectionRequestInsecureCertificateTrust:(RCMTrustResponse)trustBlock;
- (void)ircConnectionWillSendData:(NSData *)data;
- (void)ircConnectionDidSendData;
@end

@class IRCConnectionConfig;

/* Implemented in IRCConnectionTransport.swift */
@interface IRCConnectionTransport : NSObject
- (instancetype)initWithConfig:(IRCConnectionConfig *)config delegate:(id <IRCConnectionTransportDelegate>)delegate;

- (void)open;
- (void)close;

/* data must end in CRLF. Priority lines (PONG) go first and ignore flood control. */
- (void)sendData:(NSData *)data priority:(BOOL)priority;

- (void)clearSendQueue;

- (void)enforceFloodControl;

/* Main queue only; the receiver is called before this returns, if at all */
- (void)exportSecureConnectionInformation:(IRCConnectionSecureInformationBlock)receiver;
@end

NS_ASSUME_NONNULL_END
