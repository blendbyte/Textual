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

NS_ASSUME_NONNULL_BEGIN

#define IRCConnectionConfigFloodControlDefaultDelayInterval					2
#define IRCConnectionConfigFloodControlMinimumDelayInterval					1
#define IRCConnectionConfigFloodControlMaximumDelayInterval					60
#define IRCConnectionConfigFloodControlDefaultMessageCount					6
#define IRCConnectionConfigFloodControlMinimumMessageCount					1
#define IRCConnectionConfigFloodControlMaximumMessageCount					60

TEXTUAL_EXTERN uint16_t const IRCConnectionDefaultServerPort;
TEXTUAL_EXTERN uint16_t const IRCConnectionDefaultProxyPort;

typedef NS_ENUM(NSUInteger, IRCConnectionProxyType) {
	IRCConnectionProxyTypeNone = 0,
	IRCConnectionProxyTypeAutomatic = 1,
	IRCConnectionProxyTypeSocks4 = 4, // No longer supported: treated as SOCKS5
	IRCConnectionProxyTypeSocks5 = 5,
	IRCConnectionProxyTypeHTTP = 6,
	IRCConnectionProxyTypeHTTPS = 7,
	IRCConnectionProxyTypeTor = 8
};

/* Select specific protocol to use. This does not define preference.
 When a specific protocol is enabled, its counterpart is disabled. */
typedef NS_ENUM(NSUInteger, IRCConnectionAddressType)
{
	IRCConnectionAddressTypeDefault = 0, // enable both
	IRCConnectionAddressTypeIPv4 NS_SWIFT_NAME(v4) = 1,
	IRCConnectionAddressTypeIPv6 NS_SWIFT_NAME(v6) = 2
};

#pragma mark -
#pragma mark Immutable Object

@interface IRCConnectionConfig : XRPortablePropertyObject
@property (readonly) BOOL connectionPrefersModernCiphersOnly;
@property (readonly) BOOL connectionPrefersModernSockets; // Ignored: always Network.framework
@property (readonly) BOOL connectionPrefersSecuredConnection;
@property (readonly) BOOL connectionShouldValidateCertificateChain;
@property (readonly) IRCConnectionAddressType addressType;
@property (readonly) IRCConnectionProxyType proxyType;
@property (readonly) NSUInteger floodControlDelayInterval;
@property (readonly) NSUInteger floodControlMaximumMessages;
@property (readonly) uint16_t proxyPort;
@property (readonly) uint16_t serverPort;
@property (readonly, copy) NSString *serverAddress;
@property (readonly, copy, nullable) NSString *proxyAddress;
@property (readonly, copy, nullable) NSString *proxyPassword;
@property (readonly, copy, nullable) NSString *proxyUsername;
@property (readonly, copy, nullable) NSData *identityClientSideCertificate;
@property (readonly) NSStringEncoding primaryEncoding NS_UNAVAILABLE;
@property (readonly) NSStringEncoding fallbackEncoding NS_UNAVAILABLE;
@property (readonly) RCMCipherSuiteCollection cipherSuites;
@end

#pragma mark -
#pragma mark Mutable Object

@interface IRCConnectionConfigMutable : IRCConnectionConfig
@property (nonatomic, assign, readwrite) BOOL connectionPrefersModernCiphersOnly;
@property (nonatomic, assign, readwrite) BOOL connectionPrefersModernSockets;
@property (nonatomic, assign, readwrite) BOOL connectionPrefersSecuredConnection;
@property (nonatomic, assign, readwrite) BOOL connectionShouldValidateCertificateChain;
@property (nonatomic, assign, readwrite) IRCConnectionAddressType addressType;
@property (nonatomic, assign, readwrite) IRCConnectionProxyType proxyType;
@property (nonatomic, assign, readwrite) NSUInteger floodControlDelayInterval;
@property (nonatomic, assign, readwrite) NSUInteger floodControlMaximumMessages;
@property (nonatomic, assign, readwrite) uint16_t proxyPort;
@property (nonatomic, assign, readwrite) uint16_t serverPort;
@property (nonatomic, copy, readwrite) NSString *serverAddress;
@property (nonatomic, copy, readwrite, nullable) NSString *proxyAddress;
@property (nonatomic, copy, readwrite, nullable) NSString *proxyPassword;
@property (nonatomic, copy, readwrite, nullable) NSString *proxyUsername;
@property (nonatomic, copy, readwrite, nullable) NSData *identityClientSideCertificate;
@property (nonatomic, assign, readwrite) NSStringEncoding primaryEncoding NS_UNAVAILABLE;
@property (nonatomic, assign, readwrite) NSStringEncoding fallbackEncoding NS_UNAVAILABLE;
@property (nonatomic, assign, readwrite) RCMCipherSuiteCollection cipherSuites;
@end

NS_ASSUME_NONNULL_END
