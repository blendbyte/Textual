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


#import <XCTest/XCTest.h>

#import "TLOLicenseManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
static NSString * const TLOLicenseManagerTestsKeyID = @"t8-tests";

@interface TLOLicenseManagerTests : XCTestCase
@property (nonatomic, assign, nullable) SecKeyRef privateKey;
@end

@implementation TLOLicenseManagerTests

- (void)setUp
{
	NSDictionary *keyAttributes = @{
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecAttrKeySizeInBits : @(256)
	};

	self.privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyAttributes, NULL);

	SecKeyRef publicKey = SecKeyCopyPublicKey(self.privateKey);

	NSData *publicKeyData = (__bridge_transfer NSData *)SecKeyCopyExternalRepresentation(publicKey, NULL);

	CFRelease(publicKey);

	TLOLicenseManagerSetSigningKeyForTesting(TLOLicenseManagerTestsKeyID, publicKeyData);
}

- (void)tearDown
{
	TLOLicenseManagerSetSigningKeyForTesting(TLOLicenseManagerTestsKeyID, nil);

	if (self.privateKey) {
		CFRelease(self.privateKey);

		self.privateKey = NULL;
	}
}

/* An answer as the licensing server sends it: a binary property list and a
 signature over exactly its bytes */
- (NSDictionary *)signedAnswerWithPayload:(NSDictionary *)payload signingKey:(SecKeyRef)signingKey
{
	NSData *payloadData = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];

	NSData *signature = (__bridge_transfer NSData *)SecKeyCreateSignature(signingKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)payloadData, NULL);

	return @{@"signingKeyID" : TLOLicenseManagerTestsKeyID, @"payload" : payloadData, @"signature" : signature};
}

- (NSDictionary *)activationPayloadForMachineHash:(NSString *)machineHash
{
	return @{
		@"payloadType" : @"activation",
		@"licenseKey" : @"mushy-argyle-oryx-428112186934176870777339608",
		@"licenseGeneration" : @(2),
		@"activationID" : @"8a6e0c1e-6a0b-4c7e-9a43-1b2f3c4d5e6f",
		@"machineHash" : machineHash,
		@"issuedAt" : [NSDate date]
	};
}

- (void)testMachineHashIsLowercaseHex
{
	NSString *machineHash = TLOLicenseManagerMachineHash();

	XCTAssertEqual(machineHash.length, 64);

	NSCharacterSet *notLowercaseHex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet;

	XCTAssertEqual([machineHash rangeOfCharacterFromSet:notLowercaseHex].location, NSNotFound);
}

- (void)testAcceptsAnswerSignedForThisMac
{
	NSDictionary *signedAnswer = [self signedAnswerWithPayload:[self activationPayloadForMachineHash:TLOLicenseManagerMachineHash()] signingKey:self.privateKey];

	NSDictionary *payload = TLOLicenseManagerVerifiedPayload(signedAnswer, @"activation");

	XCTAssertEqualObjects(payload[@"activationID"], @"8a6e0c1e-6a0b-4c7e-9a43-1b2f3c4d5e6f");
}

- (void)testRefusesChangedPayload
{
	NSMutableDictionary *signedAnswer = [[self signedAnswerWithPayload:[self activationPayloadForMachineHash:TLOLicenseManagerMachineHash()] signingKey:self.privateKey] mutableCopy];

	NSMutableData *payloadData = [signedAnswer[@"payload"] mutableCopy];

	uint8_t *bytes = payloadData.mutableBytes;

	bytes[payloadData.length / 2] ^= 0x01;

	signedAnswer[@"payload"] = payloadData;

	XCTAssertNil(TLOLicenseManagerVerifiedPayload(signedAnswer, @"activation"));
}

- (void)testRefusesAnswerSignedWithAnotherKey
{
	NSDictionary *keyAttributes = @{
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecAttrKeySizeInBits : @(256)
	};

	SecKeyRef otherKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyAttributes, NULL);

	NSDictionary *signedAnswer = [self signedAnswerWithPayload:[self activationPayloadForMachineHash:TLOLicenseManagerMachineHash()] signingKey:otherKey];

	CFRelease(otherKey);

	XCTAssertNil(TLOLicenseManagerVerifiedPayload(signedAnswer, @"activation"));
}

- (void)testRefusesUnknownSigningKeyID
{
	NSMutableDictionary *signedAnswer = [[self signedAnswerWithPayload:[self activationPayloadForMachineHash:TLOLicenseManagerMachineHash()] signingKey:self.privateKey] mutableCopy];

	signedAnswer[@"signingKeyID"] = @"t8-unknown";

	XCTAssertNil(TLOLicenseManagerVerifiedPayload(signedAnswer, @"activation"));
}

/* A signed trial must not stand in for an activation */
- (void)testRefusesAnotherPayloadType
{
	NSDictionary *signedAnswer = [self signedAnswerWithPayload:[self activationPayloadForMachineHash:TLOLicenseManagerMachineHash()] signingKey:self.privateKey];

	XCTAssertNil(TLOLicenseManagerVerifiedPayload(signedAnswer, @"trial"));
}

/* An activation copied from another Mac doesn't license this one */
- (void)testRefusesAnotherMac
{
	NSString *otherMachineHash = [@"" stringByPaddingToLength:64 withString:@"0" startingAtIndex:0];

	NSDictionary *signedAnswer = [self signedAnswerWithPayload:[self activationPayloadForMachineHash:otherMachineHash] signingKey:self.privateKey];

	XCTAssertNil(TLOLicenseManagerVerifiedPayload(signedAnswer, @"activation"));
}

@end
#endif

NS_ASSUME_NONNULL_END
