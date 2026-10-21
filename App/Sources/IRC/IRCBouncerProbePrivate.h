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

#import "IRCBouncerAccountPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCBouncerNetworkList;
@protocol IRCBouncerProbeDelegate;

/* What went wrong, in the order a connection gets there */
typedef NS_ENUM(NSUInteger, IRCBouncerProbeError) {
	IRCBouncerProbeErrorNone = 0,
	IRCBouncerProbeErrorCannotConnect, // errorDetail: the system's words
	IRCBouncerProbeErrorCertificateNotTrusted, // asked (wantsCertificateTrust) or declined; -trustCertificateInWindow: asks
	IRCBouncerProbeErrorTimedOut,
	IRCBouncerProbeErrorWrongLogin, // errorDetail: the bouncer's words
	IRCBouncerProbeErrorNotABouncer, // an IRC server, but neither soju nor ZNC
	IRCBouncerProbeErrorClosed // the bouncer ended the connection; errorDetail: its words
};

/* A certificate login (the account has a client certificate) */
typedef NS_ENUM(NSUInteger, IRCBouncerProbeCertificateLogin) {
	IRCBouncerProbeCertificateLoginNone = 0, // no certificate, or not known yet
	IRCBouncerProbeCertificateLoginSettingUp, // being registered, then tried alone
	IRCBouncerProbeCertificateLoginWorks, // the bouncer logged in with the certificate alone
	IRCBouncerProbeCertificateLoginUnsupported // it doesn't take it (no certauth, soju's client-cert-auth off): the password stays
};

/* A short connection for the Add Bouncer sheet: logs in to a bouncer with
 an account's address, port, TLS, username and password, recognises soju
 (soju.im/bouncer-networks) or ZNC (irc.znc.in), reads its networks
 (BOUNCER LISTNETWORKS, or ListNetworks to *status) and quits. Nothing is
 saved and no server is added (a certificate may be registered on the
 bouncer, see certificateLogin). It uses the defaults of a new server
 (proxy, ciphers, certificate checks). */
@interface IRCBouncerProbe : NSObject
- (instancetype)initWithAccount:(IRCBouncerAccount *)account NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, weak, nullable) id <IRCBouncerProbeDelegate> delegate;

/* Each step as it is reached */
@property (readonly) BOOL isConnected;
@property (readonly) BOOL isSecured;
@property (readonly) BOOL isLoggedIn;
@property (readonly) IRCBouncerKind kind; // known once the bouncer answers CAP LS
@property (readonly, copy, nullable) NSString *bouncerVersion; // soju's RPL_MYINFO version, when it has one
@property (readonly) BOOL finished; // the networks were read (networkList), or an error
@property (readonly, strong, nullable) IRCBouncerNetworkList *networkList;

/* With a client certificate and a password, the certificate is registered on
 the bouncer once the networks are read (ZNC: *certauth add; soju: BouncerServ
 device-certificate create), then a second connection logs in with it alone:
 it works only if that succeeds. With a certificate and no password, the
 login is the certificate's (soju: SASL EXTERNAL; ZNC: PASS without a
 password), and a refusal is a wrong login. */
@property (readonly) IRCBouncerProbeCertificateLogin certificateLogin;

@property (readonly) IRCBouncerProbeError error;
@property (readonly, copy, nullable) NSString *errorDetail;

- (void)start;
- (void)cancel; // quits; no more delegate calls

/* The bouncer's certificate (DER) when it was trusted in -trustCertificateInWindow:
 (or was the account's trustedServerCertificate): kept in the account, so its
 networks don't ask again */
@property (readonly, copy, nullable) NSData *trustedCertificate;

/* The certificate isn't trusted and nobody was asked yet: show it now */
@property (readonly) BOOL wantsCertificateTrust;

/* After IRCBouncerProbeErrorCertificateNotTrusted: shows the certificate in a
 sheet on the window. Trusting it goes on; when the bouncer hung up while
 waiting for the answer (some give the handshake seconds only), the probe
 starts again and accepts that certificate. Declining ends with that error. */
- (void)trustCertificateInWindow:(NSWindow *)window;
@end

@protocol IRCBouncerProbeDelegate <NSObject>
- (void)bouncerProbeDidChange:(IRCBouncerProbe *)probe;
@end

NS_ASSUME_NONNULL_END
