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

#import <XCTest/XCTest.h>

#import "IRCSASLECDSAPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCSASLECDSATests : XCTestCase
@end

@implementation IRCSASLECDSATests

/* RFC 6979 A.2.5's P-256 key, as `openssl ecparam -genkey` writes it (with its
 parameters first) and as `openssl pkcs8 -topk8 -nocrypt` writes it */
static NSString * const IRCSASLECDSATestsSEC1 =
	@"-----BEGIN EC PARAMETERS-----\n"
	@"BggqhkjOPQMBBw==\n"
	@"-----END EC PARAMETERS-----\n"
	@"-----BEGIN EC PRIVATE KEY-----\n"
	@"MHcCAQEEIMmvqdhFunUWa1whV2ex1pNOUMPbNuibEnuKYisSD2choAoGCCqGSM49\n"
	@"AwEHoUQDQgAEYP7UuiVanTHJYet0xjVtaMBJuJI7Yfps5mliLmDyn7Z5A/4QCLi8\n"
	@"maQa6elWKLxk8vGyDC1+n1F3o8KU1EYimQ==\n"
	@"-----END EC PRIVATE KEY-----\n";

static NSString * const IRCSASLECDSATestsPKCS8 =
	@"-----BEGIN PRIVATE KEY-----\n"
	@"MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgya+p2EW6dRZrXCFX\n"
	@"Z7HWk05Qw9s26JsSe4piKxIPZyGhRANCAARg/tS6JVqdMclh63TGNW1owEm4kjth\n"
	@"+mzmaWIuYPKftnkD/hAIuLyZpBrp6VYovGTy8bIMLX6fUXejwpTURiKZ\n"
	@"-----END PRIVATE KEY-----\n";

/* Compressed: 0x03 (y is odd), then x */
static NSString * const IRCSASLECDSATestsPublicKey = @"A2D+1LolWp0xyWHrdMY1bWjASbiSO2H6bOZpYi5g8p+2";

/* Uncompressed (0x04, x, y), which SecKeyCreateWithData takes */
static NSString * const IRCSASLECDSATestsPublicKeyX963 = @"BGD+1LolWp0xyWHrdMY1bWjASbiSO2H6bOZpYi5g8p+2eQP+EAi4vJmkGunpVii8ZPLxsgwtfp9Rd6PClNRGIpk=";

/* Both PEM forms give the key NickServ knows; the Keychain value gives it back */
- (void)testImportAndPublicKey
{
	IRCSASLECDSAKey *sec1 = [IRCSASLECDSAKey keyWithPEM:IRCSASLECDSATestsSEC1];
	IRCSASLECDSAKey *pkcs8 = [IRCSASLECDSAKey keyWithPEM:IRCSASLECDSATestsPKCS8];

	XCTAssertEqualObjects(sec1.publicKey, IRCSASLECDSATestsPublicKey);
	XCTAssertEqualObjects(pkcs8.publicKey, IRCSASLECDSATestsPublicKey);

	XCTAssertEqualObjects([IRCSASLECDSAKey keyWithStoredValue:sec1.storedValue].publicKey, IRCSASLECDSATestsPublicKey);

	XCTAssertNil([IRCSASLECDSAKey keyWithPEM:@"-----BEGIN EC PARAMETERS-----\nBggqhkjOPQMBBw==\n-----END EC PARAMETERS-----\n"]);
	XCTAssertNil([IRCSASLECDSAKey keyWithStoredValue:@"not a key"]);
}

/* The challenge is signed as it is (as the server's digest), so the public key verifies it as one */
- (void)testSignatureVerifies
{
	IRCSASLECDSAKey *key = [IRCSASLECDSAKey keyWithPEM:IRCSASLECDSATestsSEC1];

	NSMutableData *challenge = [NSMutableData dataWithLength:32];

	((uint8_t *)challenge.mutableBytes)[0] = 0x42;

	NSData *signature = [key signatureForChallenge:challenge];

	XCTAssertNotNil(signature);

	NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:IRCSASLECDSATestsPublicKeyX963 options:0];

	NSDictionary *attributes = @{
		(id)kSecAttrKeyType : (id)kSecAttrKeyTypeECSECPrimeRandom,
		(id)kSecAttrKeyClass : (id)kSecAttrKeyClassPublic
	};

	SecKeyRef publicKey = SecKeyCreateWithData((__bridge CFDataRef)publicKeyData, (__bridge CFDictionaryRef)attributes, NULL);

	XCTAssertTrue(publicKey != NULL);

	if (publicKey == NULL) {
		return;
	}

	XCTAssertTrue(SecKeyVerifySignature(publicKey, kSecKeyAlgorithmECDSASignatureDigestX962SHA256, (__bridge CFDataRef)challenge, (__bridge CFDataRef)signature, NULL));

	((uint8_t *)challenge.mutableBytes)[0] = 0x43;

	XCTAssertFalse(SecKeyVerifySignature(publicKey, kSecKeyAlgorithmECDSASignatureDigestX962SHA256, (__bridge CFDataRef)challenge, (__bridge CFDataRef)signature, NULL));

	CFRelease(publicKey);

	XCTAssertNil([key signatureForChallenge:[NSData dataWithBytes:"short" length:5]]);
}

@end

NS_ASSUME_NONNULL_END
