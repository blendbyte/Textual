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

#import "IRCClientConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientConfig ()
/* To provide user with similar behavior, when migrating -connectionPrefersIPv4
 in IRCClientConfig, we set the address type to IRCConnectionAddressTypeIPv4.
 We check if both values are set to offer the user a warning that the preference
 they had has changed in a way they may not want. When user changes the address
 type in Server Properties, we unset -connectionPrefersIPv4 so that the warning
 does not appear again, ever. */
@property (readonly) BOOL showConnectionPrefersIPv4Warning;
@property (readonly) BOOL connectionPrefersIPv4 TEXTUAL_DEPRECATED("Use -addressType instead");

- (void)writeNicknamePasswordToKeychain;
- (void)writeProxyPasswordToKeychain;

- (void)destroyNicknamePasswordKeychainItem;
- (void)destroyProxyPasswordKeychainItem;

- (void)destroyServerPasswordKeychainItemAfterMigration;
@end

@interface IRCClientConfigMutable ()
@property (nonatomic, assign, readwrite) BOOL connectionPrefersIPv4 TEXTUAL_DEPRECATED("Use -addressType instead");
@end

NS_ASSUME_NONNULL_END
