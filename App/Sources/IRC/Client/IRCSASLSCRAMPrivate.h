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

typedef NS_ENUM(NSUInteger, IRCSASLSCRAMHash) {
	IRCSASLSCRAMHashSHA256,
	IRCSASLSCRAMHashSHA512
};

/* The client side of SASL SCRAM (RFC 5802, RFC 7677) without channel
 binding: client-first, client-final from the server-first, and the
 check of the server's signature. Names and passwords are prepared with
 an approximation of SASLprep (RFC 4013): non-ASCII spaces become spaces,
 characters mapped to nothing are removed, then NFKC; prohibited
 characters are not refused. */
@interface IRCSASLSCRAM : NSObject
@property (readonly) IRCSASLSCRAMHash hashAlgorithm;
@property (readonly, copy) NSString *mechanismName; // SCRAM-SHA-256, SCRAM-SHA-512

+ (nullable NSString *)mechanismNameForHash:(IRCSASLSCRAMHash)hash;
+ (BOOL)hash:(IRCSASLSCRAMHash *)hash forMechanismName:(NSString *)mechanismName;

+ (NSString *)preparedString:(NSString *)string; // the SASLprep approximation

/* clientNonce is for tests; nil makes a random one */
- (instancetype)initWithHash:(IRCSASLSCRAMHash)hash username:(NSString *)username password:(NSString *)password clientNonce:(nullable NSString *)clientNonce NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, copy) NSString *clientFirstMessage;

/* NO when the server-first is malformed or doesn't extend our nonce */
- (BOOL)processServerFirstMessage:(NSString *)serverFirstMessage;

/* Runs PBKDF2: call off the main thread. nil before a valid server-first */
- (nullable NSString *)clientFinalMessage;

/* YES only for v= with the expected server signature */
- (BOOL)verifyServerFinalMessage:(NSString *)serverFinalMessage;
@end

TEXTUAL_EXTERN NSString * const IRCSASLECDSAMechanismName; // ECDSA-NIST256P-CHALLENGE

/* SASL mechanisms to try in order: EXTERNAL, ECDSA-NIST256P-CHALLENGE, then the strongest
 SCRAM, then PLAIN. offered is the server's list (empty when it gave none: then neither
 ECDSA nor SCRAM is guessed). */
TEXTUAL_EXTERN NSArray<NSString *> *IRCSASLMechanismsToTry(NSArray<NSString *> *offered, BOOL canUseExternal, BOOL haveECDSAKey, BOOL havePassword);

NS_ASSUME_NONNULL_END
