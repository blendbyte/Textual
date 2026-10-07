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

@class IRCClient;

TEXTUAL_EXTERN NSStringEncoding const TXDefaultPrimaryStringEncoding;
TEXTUAL_EXTERN NSStringEncoding const TXDefaultFallbackStringEncoding;

@interface NSString (TXStringHelper)
@property (readonly, copy) NSString *stringByAppendingIRCFormattingStop;

@property (readonly, copy, nullable) NSString *channelNameWithoutBang; // "#channel" -> "channel", "##channel" -> "#channel"
- (nullable NSString *)channelNameWithoutBangOn:(IRCClient *)client;

@property (readonly, copy, nullable) NSString *nicknameFromHostmask;
@property (readonly, copy, nullable) NSString *usernameFromHostmask;
@property (readonly, copy, nullable) NSString *addressFromHostmask;

- (nullable NSAttributedString *)attributedStringWithIRCFormatting:(NSFont *)preferredFont preferredFontColor:(nullable NSColor *)preferredFontColor;
- (nullable NSAttributedString *)attributedStringWithIRCFormatting:(NSFont *)preferredFont preferredFontColor:(nullable NSColor *)preferredFontColor honorFormattingPreference:(BOOL)formattingPreference;

@property (readonly, copy) NSString *stripIRCEffects;

@property (getter=isValidInternetAddress, readonly) BOOL validInternetAddress;
@property (getter=isValidInternetPort, readonly) BOOL validInternetPort;

@property (getter=isHostmask, readonly) BOOL hostmask;

@property (getter=isIPv4Address, readonly) BOOL IPv4Address;
@property (getter=isIPv6Address, readonly) BOOL IPv6Address;
@property (getter=isIPAddress, readonly) BOOL IPAddress;

- (BOOL)hostmaskComponents:(NSString * _Nullable * _Nullable)nickname
				  username:(NSString * _Nullable * _Nullable)username
				   address:(NSString * _Nullable * _Nullable)address;

- (BOOL)hostmaskComponents:(NSString * _Nullable * _Nullable)nickname
				  username:(NSString * _Nullable * _Nullable)username
				   address:(NSString * _Nullable * _Nullable)address
				  onClient:(nullable IRCClient *)client;

@property (getter=isHostmaskNickname, readonly) BOOL hostmaskNickname;
@property (getter=isHostmaskAddress, readonly) BOOL hostmaskAddress;
@property (getter=isHostmaskUsername, readonly) BOOL hostmaskUsername;

/* By handing a client to -isHostmask[*]On:, greater validity
 is promised as configuration options from ISUPPORT (005) and
 other contextual information can be accessed. */
- (BOOL)isHostmaskNicknameOn:(nullable IRCClient *)client;
- (BOOL)isHostmaskUsernameOn:(nullable IRCClient *)client;
- (BOOL)isHostmaskAddressOn:(nullable IRCClient *)client;

@property (getter=isChannelName, readonly) BOOL channelName;
- (BOOL)isChannelNameOn:(IRCClient *)client; // Client to parse CHANTYPES from

@property (readonly, copy, nullable) NSString *stringWithValidURIScheme;

- (NSArray<NSString *> *)base64EncodingWithLineLength:(NSUInteger)lineLength;

- (NSUInteger)colorComponentsOfCharacter:(UniChar)character
							  startingAt:(NSUInteger)rangeStart
						 foregroundColor:(id _Nullable * _Nullable)foregroundColor
						 backgroundColor:(id _Nullable * _Nullable)backgroundColor;

- (nullable NSString *)padNicknameWithCharacter:(UniChar)padCharacter maximumLength:(NSUInteger)maximumLength;

@property (readonly, copy, nullable) NSString *prettyLicenseKey;

@property (readonly, copy) NSString *encodedMessageTagString;
@property (readonly, copy) NSString *decodedMessageTagString;

@property (getter=isModeSymbol, readonly) BOOL modeSymbol;
@end

NS_ASSUME_NONNULL_END
