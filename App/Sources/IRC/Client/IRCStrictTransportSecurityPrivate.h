/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
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

/* IRCv3 strict-transport-security (sts): policies learned on secure
 connections, by host name, so later connections to that host use TLS.
 https://ircv3.net/specs/extensions/sts */
@interface IRCStrictTransportSecurity : NSObject
@property (class, readonly) IRCStrictTransportSecurity *sharedPolicies;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/* The value of the sts capability, such as "port=6697,duration=2592000";
 a key that is missing or not a number comes back as -1 */
+ (void)parseValue:(nullable NSString *)value port:(NSInteger *)port duration:(NSInteger *)duration;

/* The TLS port to use for host, or 0 without an unexpired policy (expired ones are removed) */
- (uint16_t)portForHost:(NSString *)host;
- (uint16_t)portForHost:(NSString *)host atDate:(NSDate *)date;

/* Remembers a policy received on a secure connection to host:port for
 duration seconds; a duration of 0 removes it. IP addresses never get one. */
- (void)storePolicyForHost:(NSString *)host port:(uint16_t)port duration:(NSUInteger)duration;
- (void)storePolicyForHost:(NSString *)host port:(uint16_t)port duration:(NSUInteger)duration atDate:(NSDate *)date;

/* When the policy for host expires, or nil */
- (nullable NSDate *)expiryForHost:(NSString *)host;

- (void)removePolicyForHost:(NSString *)host;
@end

NS_ASSUME_NONNULL_END
