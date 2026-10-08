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

#import "IRCStrictTransportSecurityPrivate.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const IRCStrictTransportSecurityTestsSuite = @"IRCStrictTransportSecurityTests";

@interface IRCStrictTransportSecurityTests : XCTestCase
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) IRCStrictTransportSecurity *policies;
@end

@implementation IRCStrictTransportSecurityTests

- (void)setUp
{
	self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:IRCStrictTransportSecurityTestsSuite];

	[self.userDefaults removePersistentDomainForName:IRCStrictTransportSecurityTestsSuite];

	self.policies = [[IRCStrictTransportSecurity alloc] initWithUserDefaults:self.userDefaults];
}

- (void)tearDown
{
	[self.userDefaults removePersistentDomainForName:IRCStrictTransportSecurityTestsSuite];
}

/* port and duration are numbers; anything else counts as missing */
- (void)testValueParsing
{
	NSInteger port = 0;
	NSInteger duration = 0;

	[IRCStrictTransportSecurity parseValue:@"port=6697,duration=2592000,preload" port:&port duration:&duration];

	XCTAssertEqual(port, 6697);
	XCTAssertEqual(duration, 2592000);

	[IRCStrictTransportSecurity parseValue:@"duration=0" port:&port duration:&duration];

	XCTAssertEqual(port, -1);
	XCTAssertEqual(duration, 0);

	[IRCStrictTransportSecurity parseValue:@"port=99999,duration=soon" port:&port duration:&duration];

	XCTAssertEqual(port, -1);
	XCTAssertEqual(duration, -1);
}

/* A policy lasts for its duration from when it was received, by host name in any case */
- (void)testPolicyExpires
{
	NSDate *received = [NSDate dateWithTimeIntervalSince1970:1000000];

	[self.policies storePolicyForHost:@"IRC.Example.net" port:6697 duration:60 atDate:received];

	XCTAssertEqual([self.policies portForHost:@"irc.example.net" atDate:[received dateByAddingTimeInterval:59]], 6697);

	XCTAssertEqual([self.policies portForHost:@"irc.example.net" atDate:[received dateByAddingTimeInterval:61]], 0);

	XCTAssertEqual([self.policies portForHost:@"irc.example.net" atDate:received], 0, @"An expired policy is removed");
}

/* duration=0 deletes a policy; IP addresses never get one */
- (void)testZeroDurationRemovesAndAddressesAreIgnored
{
	NSDate *received = [NSDate dateWithTimeIntervalSince1970:1000000];

	[self.policies storePolicyForHost:@"irc.example.net" port:6697 duration:60 atDate:received];
	[self.policies storePolicyForHost:@"irc.example.net" port:6697 duration:0 atDate:received];

	XCTAssertEqual([self.policies portForHost:@"irc.example.net" atDate:received], 0);

	[self.policies storePolicyForHost:@"192.0.2.1" port:6697 duration:60 atDate:received];

	XCTAssertEqual([self.policies portForHost:@"192.0.2.1" atDate:received], 0);
}

@end

NS_ASSUME_NONNULL_END
