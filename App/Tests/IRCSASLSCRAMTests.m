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

#import "IRCSASLSCRAMPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCSASLSCRAMTests : XCTestCase
@end

@implementation IRCSASLSCRAMTests

static NSString * const IRCSASLSCRAMTestsServerFirst = @"r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096";

- (IRCSASLSCRAM *)scramWithHash:(IRCSASLSCRAMHash)hash
{
	return [[IRCSASLSCRAM alloc] initWithHash:hash username:@"user" password:@"pencil" clientNonce:@"rOprNGfwEbeRWgbNEkqO"];
}

/* RFC 7677 section 3 */
- (void)testSHA256Vector
{
	IRCSASLSCRAM *scram = [self scramWithHash:IRCSASLSCRAMHashSHA256];

	XCTAssertEqualObjects(scram.mechanismName, @"SCRAM-SHA-256");
	XCTAssertEqualObjects(scram.clientFirstMessage, @"n,,n=user,r=rOprNGfwEbeRWgbNEkqO");

	XCTAssertTrue([scram processServerFirstMessage:IRCSASLSCRAMTestsServerFirst]);

	XCTAssertEqualObjects([scram clientFinalMessage], @"c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=");

	XCTAssertTrue([scram verifyServerFinalMessage:@"v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="]);
}

/* The same exchange with SHA-512, computed with Python's hashlib the RFC 5802 way */
- (void)testSHA512Vector
{
	IRCSASLSCRAM *scram = [self scramWithHash:IRCSASLSCRAMHashSHA512];

	XCTAssertTrue([scram processServerFirstMessage:IRCSASLSCRAMTestsServerFirst]);

	XCTAssertEqualObjects([scram clientFinalMessage], @"c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=gMGXRcevScNtxZ6/8lQYpGtnsNAc3mGcmNomv+xnoOMw+3R2xNJdMNnzMlTN8PPC6wdp6dybEmDYXYTxwnYPJQ==");

	XCTAssertTrue([scram verifyServerFinalMessage:@"v=ZQnYEgWQMFmmsM8aQMF0nDDCy/AgCzkwk8CmMZYcMg0vSVlKDanekLtifDSeVGT4+5ZxXnJq199RVG2rR7N7Zw=="]);
}

/* A server that doesn't know the password, changes our nonce or asks for the impossible is refused */
- (void)testServerIsChecked
{
	IRCSASLSCRAM *scram = [self scramWithHash:IRCSASLSCRAMHashSHA256];

	XCTAssertFalse([scram verifyServerFinalMessage:@"v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="], @"Nothing computed yet");

	XCTAssertTrue([scram processServerFirstMessage:IRCSASLSCRAMTestsServerFirst]);

	XCTAssertNotNil([scram clientFinalMessage]);

	XCTAssertFalse([scram verifyServerFinalMessage:@"v=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="]);
	XCTAssertFalse([scram verifyServerFinalMessage:@"e=invalid-proof"]);

	IRCSASLSCRAM *other = [self scramWithHash:IRCSASLSCRAMHashSHA256];

	XCTAssertFalse([other processServerFirstMessage:@"r=someoneElsesNonce,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"]);
	XCTAssertFalse([other processServerFirstMessage:@"m=ext,r=rOprNGfwEbeRWgbNEkqOxyz,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"]);
	XCTAssertFalse([other processServerFirstMessage:@"r=rOprNGfwEbeRWgbNEkqOxyz,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=999999999"]);
}

/* Names escape "=" and ","; non-ASCII spaces become spaces and soft hyphens go */
- (void)testNamePreparation
{
	IRCSASLSCRAM *scram = [[IRCSASLSCRAM alloc] initWithHash:IRCSASLSCRAMHashSHA256 username:@"a=b,c" password:@"x" clientNonce:@"n"];

	XCTAssertEqualObjects(scram.clientFirstMessage, @"n,,n=a=3Db=2Cc,r=n");

	XCTAssertEqualObjects([IRCSASLSCRAM preparedString:@"pass wo­rd"], @"pass word");
}

/* EXTERNAL first, then a login key, then the strongest SCRAM, then PLAIN; nothing is guessed without a list */
- (void)testMechanismOrder
{
	NSArray *offered = @[@"PLAIN", @"EXTERNAL", @"SCRAM-SHA-256", @"ECDSA-NIST256P-CHALLENGE", @"SCRAM-SHA-512"];

	XCTAssertEqualObjects(IRCSASLMechanismsToTry(offered, NO, NO, YES), (@[@"SCRAM-SHA-512", @"SCRAM-SHA-256", @"PLAIN"]));
	XCTAssertEqualObjects(IRCSASLMechanismsToTry(offered, YES, NO, YES), (@[@"EXTERNAL", @"SCRAM-SHA-512", @"SCRAM-SHA-256", @"PLAIN"]));
	XCTAssertEqualObjects(IRCSASLMechanismsToTry(offered, YES, NO, NO), (@[@"EXTERNAL"]));
	XCTAssertEqualObjects(IRCSASLMechanismsToTry(offered, YES, YES, YES), (@[@"EXTERNAL", @"ECDSA-NIST256P-CHALLENGE", @"SCRAM-SHA-512", @"SCRAM-SHA-256", @"PLAIN"]));
	XCTAssertEqualObjects(IRCSASLMechanismsToTry(offered, NO, YES, NO), (@[@"ECDSA-NIST256P-CHALLENGE"]));
	XCTAssertEqualObjects(IRCSASLMechanismsToTry(@[], NO, YES, YES), (@[@"PLAIN"]));
}

@end

NS_ASSUME_NONNULL_END
