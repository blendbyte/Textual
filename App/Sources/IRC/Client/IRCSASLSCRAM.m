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

#import <CommonCrypto/CommonCrypto.h>

#import "IRCSASLSCRAMPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Iteration counts beyond this are refused (a server could make PBKDF2 run for hours) */
static NSUInteger const IRCSASLSCRAMMaximumIterations = 1000000;

@interface IRCSASLSCRAM ()
@property (nonatomic, assign, readwrite) IRCSASLSCRAMHash hashAlgorithm;
@property (nonatomic, copy, readwrite) NSString *mechanismName;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *clientNonce;
@property (nonatomic, copy) NSString *clientFirstMessageBare;
@property (nonatomic, copy, nullable) NSString *serverFirstMessage;
@property (nonatomic, copy, nullable) NSString *combinedNonce;
@property (nonatomic, copy, nullable) NSData *salt;
@property (nonatomic, assign) NSUInteger iterations;
@property (nonatomic, copy, nullable) NSData *expectedServerSignature;
@end

@implementation IRCSASLSCRAM

+ (nullable NSString *)mechanismNameForHash:(IRCSASLSCRAMHash)hash
{
	switch (hash) {
		case IRCSASLSCRAMHashSHA256:
			return @"SCRAM-SHA-256";
		case IRCSASLSCRAMHashSHA512:
			return @"SCRAM-SHA-512";
	}

	return nil;
}

+ (BOOL)hash:(IRCSASLSCRAMHash *)hash forMechanismName:(NSString *)mechanismName
{
	NSParameterAssert(hash != NULL);
	NSParameterAssert(mechanismName != nil);

	if ([mechanismName caseInsensitiveCompare:@"SCRAM-SHA-256"] == NSOrderedSame) {
		*hash = IRCSASLSCRAMHashSHA256;
	} else if ([mechanismName caseInsensitiveCompare:@"SCRAM-SHA-512"] == NSOrderedSame) {
		*hash = IRCSASLSCRAMHashSHA512;
	} else {
		return NO;
	}

	return YES;
}

+ (NSString *)preparedString:(NSString *)string
{
	NSParameterAssert(string != nil);

	NSMutableString *mapped = [NSMutableString stringWithCapacity:string.length];

	[string enumerateSubstringsInRange:NSMakeRange(0, string.length)
							   options:NSStringEnumerationByComposedCharacterSequences
							usingBlock:^(NSString *character, NSRange range, NSRange enclosingRange, BOOL *stop) {
		unichar first = [character characterAtIndex:0];

		/* RFC 3454 B.1: soft hyphen, joiners, variation selectors… map to nothing */
		if (first == 0x00AD || first == 0x034F || first == 0x1806 || first == 0x180B || first == 0x180C ||
			first == 0x180D || first == 0x200B || first == 0x200C || first == 0x200D || first == 0x2060 ||
			(first >= 0xFE00 && first <= 0xFE0F) || first == 0xFEFF)
		{
			return;
		}

		/* RFC 3454 C.1.2: non-ASCII spaces map to SPACE */
		if (first == 0x00A0 || first == 0x1680 || (first >= 0x2000 && first <= 0x200A) ||
			first == 0x202F || first == 0x205F || first == 0x3000)
		{
			[mapped appendString:@" "];

			return;
		}

		[mapped appendString:character];
	}];

	return mapped.precomposedStringWithCompatibilityMapping;
}

- (instancetype)initWithHash:(IRCSASLSCRAMHash)hash username:(NSString *)username password:(NSString *)password clientNonce:(nullable NSString *)clientNonce
{
	NSParameterAssert(username != nil);
	NSParameterAssert(password != nil);

	if ((self = [super init])) {
		self.hashAlgorithm = hash;

		self.mechanismName = [self.class mechanismNameForHash:hash];

		self.username = [self.class preparedString:username];
		self.password = [self.class preparedString:password];

		if (clientNonce == nil) {
			uint8_t bytes[24];

			(void)SecRandomCopyBytes(kSecRandomDefault, sizeof(bytes), bytes);

			clientNonce = [[NSData dataWithBytes:bytes length:sizeof(bytes)] base64EncodedStringWithOptions:0];
		}

		self.clientNonce = clientNonce;

		/* saslname: "=" and "," are escaped */
		NSString *saslName = [[self.username stringByReplacingOccurrencesOfString:@"=" withString:@"=3D"]
										   stringByReplacingOccurrencesOfString:@"," withString:@"=2C"];

		self.clientFirstMessageBare = [NSString stringWithFormat:@"n=%@,r=%@", saslName, clientNonce];

		return self;
	}

	return nil;
}

- (NSString *)clientFirstMessage
{
	/* GS2 header: no channel binding, no authorization identity */
	return [@"n,," stringByAppendingString:self.clientFirstMessageBare];
}

/* "a=1,b=2" → attributes; the value is everything after the first "=" */
- (NSDictionary<NSString *, NSString *> *)attributesOfMessage:(NSString *)message
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

	for (NSString *pair in [message componentsSeparatedByString:@","]) {
		if (pair.length < 2 || [pair characterAtIndex:1] != '=') {
			continue;
		}

		NSString *key = [pair substringToIndex:1];

		if (attributes[key] == nil) {
			attributes[key] = [pair substringFromIndex:2];
		}
	}

	return attributes;
}

- (BOOL)processServerFirstMessage:(NSString *)serverFirstMessage
{
	NSParameterAssert(serverFirstMessage != nil);

	NSDictionary *attributes = [self attributesOfMessage:serverFirstMessage];

	NSString *nonce = attributes[@"r"];
	NSString *saltString = attributes[@"s"];
	NSString *iterationsString = attributes[@"i"];

	/* "m=" names a mandatory extension this client doesn't know */
	if (attributes[@"m"] || nonce == nil || saltString == nil || iterationsString == nil) {
		return NO;
	}

	if (nonce.length <= self.clientNonce.length || [nonce hasPrefix:self.clientNonce] == NO) {
		return NO;
	}

	NSData *salt = [[NSData alloc] initWithBase64EncodedString:saltString options:0];

	NSInteger iterations = iterationsString.integerValue;

	if (salt.length == 0 || iterations <= 0 || iterations > IRCSASLSCRAMMaximumIterations) {
		return NO;
	}

	self.serverFirstMessage = serverFirstMessage;
	self.combinedNonce = nonce;
	self.salt = salt;
	self.iterations = iterations;

	return YES;
}

- (CCHmacAlgorithm)hmacAlgorithm
{
	return ((self.hashAlgorithm == IRCSASLSCRAMHashSHA512) ? kCCHmacAlgSHA512 : kCCHmacAlgSHA256);
}

- (NSUInteger)digestLength
{
	return ((self.hashAlgorithm == IRCSASLSCRAMHashSHA512) ? CC_SHA512_DIGEST_LENGTH : CC_SHA256_DIGEST_LENGTH);
}

- (NSData *)hmacWithKey:(NSData *)key data:(NSData *)data
{
	NSMutableData *result = [NSMutableData dataWithLength:self.digestLength];

	CCHmac(self.hmacAlgorithm, key.bytes, key.length, data.bytes, data.length, result.mutableBytes);

	return result;
}

- (NSData *)digestOfData:(NSData *)data
{
	NSMutableData *result = [NSMutableData dataWithLength:self.digestLength];

	if (self.hashAlgorithm == IRCSASLSCRAMHashSHA512) {
		CC_SHA512(data.bytes, (CC_LONG)data.length, result.mutableBytes);
	} else {
		CC_SHA256(data.bytes, (CC_LONG)data.length, result.mutableBytes);
	}

	return result;
}

- (nullable NSString *)clientFinalMessage
{
	NSData *salt = self.salt;

	if (salt == nil) {
		return nil;
	}

	NSData *passwordData = [self.password dataUsingEncoding:NSUTF8StringEncoding];

	NSMutableData *saltedPassword = [NSMutableData dataWithLength:self.digestLength];

	CCPseudoRandomAlgorithm prf = ((self.hashAlgorithm == IRCSASLSCRAMHashSHA512) ? kCCPRFHmacAlgSHA512 : kCCPRFHmacAlgSHA256);

	int status = CCKeyDerivationPBKDF(kCCPBKDF2,
									  passwordData.bytes, passwordData.length,
									  salt.bytes, salt.length,
									  prf, (unsigned int)self.iterations,
									  saltedPassword.mutableBytes, saltedPassword.length);

	if (status != kCCSuccess) {
		return nil;
	}

	NSData *clientKey = [self hmacWithKey:saltedPassword data:[@"Client Key" dataUsingEncoding:NSUTF8StringEncoding]];

	NSData *storedKey = [self digestOfData:clientKey];

	/* "biws" is base64 of the GS2 header "n,," */
	NSString *clientFinalWithoutProof = [NSString stringWithFormat:@"c=biws,r=%@", self.combinedNonce];

	NSString *authMessage = [NSString stringWithFormat:@"%@,%@,%@", self.clientFirstMessageBare, self.serverFirstMessage, clientFinalWithoutProof];

	NSData *authMessageData = [authMessage dataUsingEncoding:NSUTF8StringEncoding];

	NSData *clientSignature = [self hmacWithKey:storedKey data:authMessageData];

	NSMutableData *clientProof = [clientKey mutableCopy];

	uint8_t *proofBytes = clientProof.mutableBytes;

	const uint8_t *signatureBytes = clientSignature.bytes;

	for (NSUInteger i = 0; i < clientProof.length; i++) {
		proofBytes[i] ^= signatureBytes[i];
	}

	NSData *serverKey = [self hmacWithKey:saltedPassword data:[@"Server Key" dataUsingEncoding:NSUTF8StringEncoding]];

	self.expectedServerSignature = [self hmacWithKey:serverKey data:authMessageData];

	return [NSString stringWithFormat:@"%@,p=%@", clientFinalWithoutProof, [clientProof base64EncodedStringWithOptions:0]];
}

- (BOOL)verifyServerFinalMessage:(NSString *)serverFinalMessage
{
	NSParameterAssert(serverFinalMessage != nil);

	NSData *expected = self.expectedServerSignature;

	if (expected == nil) {
		return NO;
	}

	NSString *verifier = [self attributesOfMessage:serverFinalMessage][@"v"];

	if (verifier == nil) {
		return NO;
	}

	NSData *received = [[NSData alloc] initWithBase64EncodedString:verifier options:0];

	if (received.length != expected.length) {
		return NO;
	}

	/* Constant time */
	const uint8_t *a = received.bytes;
	const uint8_t *b = expected.bytes;

	uint8_t difference = 0;

	for (NSUInteger i = 0; i < expected.length; i++) {
		difference |= (a[i] ^ b[i]);
	}

	return (difference == 0);
}

@end

NSString * const IRCSASLECDSAMechanismName = @"ECDSA-NIST256P-CHALLENGE";

NSArray<NSString *> *IRCSASLMechanismsToTry(NSArray<NSString *> *offered, BOOL canUseExternal, BOOL haveECDSAKey, BOOL havePassword)
{
	NSCParameterAssert(offered != nil);

	BOOL (^isOffered)(NSString *) = ^BOOL(NSString *mechanism) {
		for (NSString *name in offered) {
			if ([name caseInsensitiveCompare:mechanism] == NSOrderedSame) {
				return YES;
			}
		}

		return NO;
	};

	NSMutableArray *mechanisms = [NSMutableArray array];

	/* Without a list from the server only EXTERNAL and PLAIN are assumed */
	BOOL anyOffered = (offered.count == 0);

	if (canUseExternal && (anyOffered || isOffered(@"EXTERNAL"))) {
		[mechanisms addObject:@"EXTERNAL"];
	}

	if (haveECDSAKey && isOffered(IRCSASLECDSAMechanismName)) {
		[mechanisms addObject:IRCSASLECDSAMechanismName];
	}

	if (havePassword) {
		if (isOffered(@"SCRAM-SHA-512")) {
			[mechanisms addObject:@"SCRAM-SHA-512"];
		}

		if (isOffered(@"SCRAM-SHA-256")) {
			[mechanisms addObject:@"SCRAM-SHA-256"];
		}

		if (anyOffered || isOffered(@"PLAIN")) {
			[mechanisms addObject:@"PLAIN"];
		}
	}

	return mechanisms;
}

NS_ASSUME_NONNULL_END
