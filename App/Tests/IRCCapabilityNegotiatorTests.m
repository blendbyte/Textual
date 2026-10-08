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

#import "IRCCapabilityNegotiatorPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Stands in for the client: wants some capabilities, records what is sent
 and enabled, and pauses negotiation for SASL like the client does */
@interface IRCCapabilityNegotiatorTestClient : NSObject <IRCCapabilityNegotiatorDelegate>
@property (nonatomic, copy) NSSet<NSString *> *wanted;
@property (nonatomic, strong) NSMutableArray<NSString *> *sent;
@property (nonatomic, strong) NSMutableArray<NSString *> *enabled;
@property (nonatomic, strong) NSMutableArray<NSString *> *disabled;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *offeredValues;
@end

@implementation IRCCapabilityNegotiatorTestClient

- (instancetype)init
{
	if ((self = [super init])) {
		self.wanted = [NSSet set];
		self.sent = [NSMutableArray array];
		self.enabled = [NSMutableArray array];
		self.disabled = [NSMutableArray array];
		self.offeredValues = [NSMutableDictionary dictionary];
	}

	return self;
}

- (BOOL)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator shouldRequestCapability:(NSString *)capability value:(nullable NSString *)value
{
	if (value) {
		self.offeredValues[capability] = value;
	}

	return ([self.wanted containsObject:capability] && [self.enabled containsObject:capability] == NO);
}

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator didEnableCapability:(NSString *)capability
{
	[self.enabled addObject:capability];

	if ([capability isEqualToString:@"sasl"]) {
		[negotiator pause];
	}
}

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator didDisableCapability:(NSString *)capability
{
	[self.disabled addObject:capability];

	[self.enabled removeObject:capability];
}

- (void)capabilityNegotiator:(IRCCapabilityNegotiator *)negotiator sendCapabilityCommand:(NSString *)subcommand data:(nullable NSString *)data
{
	[self.sent addObject:(data ? [NSString stringWithFormat:@"%@ %@", subcommand, data] : subcommand)];
}

@end

@interface IRCCapabilityNegotiatorTests : XCTestCase
@property (nonatomic, strong) IRCCapabilityNegotiator *negotiator;
@property (nonatomic, strong) IRCCapabilityNegotiatorTestClient *client;
@end

@implementation IRCCapabilityNegotiatorTests

- (void)setUp
{
	self.client = [IRCCapabilityNegotiatorTestClient new];

	self.negotiator = [IRCCapabilityNegotiator new];

	self.negotiator.delegate = self.client;
}

/* A multi-line LS is only answered after its last line, with one request
 covering every line, and negotiation ends only once that is answered */
- (void)testMultiLineListIsRequestedOnceAfterTheLastLine
{
	self.client.wanted = [NSSet setWithArray:@[@"batch", @"server-time", @"away-notify"]];

	[self.negotiator receiveCapabilityReply:@"LS" parameters:@[@"*", @"batch multi-prefix"]];

	XCTAssertEqualObjects(self.client.sent, @[]);

	[self.negotiator receiveCapabilityReply:@"LS" parameters:@[@"server-time away-notify"]];

	XCTAssertEqualObjects(self.client.sent, @[@"REQ batch server-time away-notify"]);

	[self.negotiator receiveCapabilityReply:@"ACK" parameters:@[@"batch server-time away-notify"]];

	XCTAssertEqualObjects(self.client.enabled, (@[@"batch", @"server-time", @"away-notify"]));
	XCTAssertEqualObjects(self.client.sent.lastObject, @"END");
}

/* Nothing wanted: registration must not wait */
- (void)testListWithNothingWantedEndsNegotiation
{
	[self.negotiator receiveCapabilityReply:@"LS" parameters:@[@"draft/unknown"]];

	XCTAssertEqualObjects(self.client.sent, @[@"END"]);
}

/* Long requests are split, and END waits for the answer to each part,
 including a refusal */
- (void)testSplitRequestEndsAfterEveryPartIsAnswered
{
	NSMutableArray *capabilities = [NSMutableArray array];

	for (NSUInteger i = 0; i < 60; i++) {
		[capabilities addObject:[NSString stringWithFormat:@"vendor.example/capability-%lu", i]];
	}

	self.client.wanted = [NSSet setWithArray:capabilities];

	[self.negotiator receiveCapabilityReply:@"LS" parameters:@[[capabilities componentsJoinedByString:@" "]]];

	NSArray *requests = [self.client.sent copy];

	XCTAssertGreaterThan(requests.count, 1);

	for (NSString *request in requests) {
		XCTAssertTrue([request hasPrefix:@"REQ "]);
		XCTAssertLessThanOrEqual(request.length - 4, 400);
	}

	for (NSUInteger i = 0; i < requests.count; i++) {
		XCTAssertFalse([self.client.sent containsObject:@"END"]);

		NSString *answer = ((i == 0) ? @"NAK" : @"ACK");

		[self.negotiator receiveCapabilityReply:answer parameters:@[[requests[i] substringFromIndex:4]]];
	}

	XCTAssertEqualObjects(self.client.sent.lastObject, @"END");
}

/* SASL pauses negotiation; END follows only when authentication is done */
- (void)testSASLHoldsEndUntilAuthenticationIsDone
{
	self.client.wanted = [NSSet setWithArray:@[@"sasl", @"batch"]];

	[self.negotiator receiveCapabilityReply:@"LS" parameters:@[@"sasl=PLAIN,EXTERNAL batch"]];

	XCTAssertEqualObjects(self.client.offeredValues[@"sasl"], @"PLAIN,EXTERNAL");

	[self.negotiator receiveCapabilityReply:@"ACK" parameters:@[@"sasl batch"]];

	XCTAssertTrue(self.negotiator.isPaused);
	XCTAssertFalse([self.client.sent containsObject:@"END"]);

	[self.negotiator resume];

	XCTAssertEqualObjects(self.client.sent.lastObject, @"END");
}

/* After registration, NEW is requested and DEL disables, without END */
- (void)testNewAndDeleteAfterRegistrationNeverEnd
{
	self.client.wanted = [NSSet setWithArray:@[@"away-notify"]];

	[self.negotiator receiveCapabilityReply:@"LS" parameters:@[@"batch"]];
	[self.negotiator registrationCompleted];

	[self.client.sent removeAllObjects];

	[self.negotiator receiveCapabilityReply:@"NEW" parameters:@[@"away-notify"]];

	XCTAssertEqualObjects(self.client.sent, @[@"REQ away-notify"]);

	[self.negotiator receiveCapabilityReply:@"ACK" parameters:@[@"away-notify"]];
	[self.negotiator receiveCapabilityReply:@"DEL" parameters:@[@"away-notify"]];

	XCTAssertEqualObjects(self.client.disabled, @[@"away-notify"]);
	XCTAssertEqualObjects(self.client.sent, @[@"REQ away-notify"]);
}

/* Values are split at the first "=" only */
- (void)testValueIsSplitAtTheFirstEqualsSign
{
	NSString *value = nil;

	XCTAssertEqualObjects([IRCCapabilityNegotiator capabilityName:@"sts=port=6697,duration=300" value:&value], @"sts");
	XCTAssertEqualObjects(value, @"port=6697,duration=300");

	XCTAssertEqualObjects([IRCCapabilityNegotiator capabilityName:@"batch" value:&value], @"batch");
	XCTAssertNil(value);
}

@end

NS_ASSUME_NONNULL_END
