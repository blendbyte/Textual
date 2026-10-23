/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TLOKeychainItemKind) {
	TLOKeychainItemKindServerPassword,
	TLOKeychainItemKindNicknamePassword,
	TLOKeychainItemKindProxyPassword,
	TLOKeychainItemKindChannelKey
};

/* The app's secrets in the Keychain (server, NickServ and proxy passwords,
 channel keys): one place for their names, result checking and errors. */
@interface TLOKeychain : NSObject
+ (nullable NSString *)passwordOfKind:(TLOKeychainItemKind)kind forIdentifier:(NSString *)identifier;

/* Returns NO if the Keychain refused the password (the user is told why, with
 the Keychain's reason). Callers then keep the password in memory, so it is
 not lost silently. */
+ (BOOL)setPassword:(NSString *)password ofKind:(TLOKeychainItemKind)kind forIdentifier:(NSString *)identifier;

+ (void)deletePasswordOfKind:(TLOKeychainItemKind)kind forIdentifier:(NSString *)identifier;
@end

#ifdef DEBUG
@interface TLOKeychain (Testing)
/* Writes return this status instead of writing (nil: write normally) */
@property (class, nonatomic, copy, nullable) NSNumber *simulatedWriteStatus;

/* Whether failed writes are shown to the user (YES by default) */
@property (class, nonatomic, assign) BOOL reportsFailures;
@end
#endif

NS_ASSUME_NONNULL_END
