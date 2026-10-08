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

#import "IRCClientPrivate.h"
#import "IRCClientConfig.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCUser.h"
#import "IRCChannelUserPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCChannelUserTests : XCTestCase
@property (nonatomic, strong) IRCClient *client;
@end

@implementation IRCChannelUserTests

- (void)setUp
{
	self.client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];
}

- (IRCChannelUser *)memberWithModes:(NSString *)modes
{
	IRCUser *user = [[IRCUser alloc] initWithNickname:@"someone" onClient:self.client];

	IRCChannelUserMutable *member = [[IRCChannelUserMutable alloc] initWithUser:user];

	member.modes = modes;

	return [member copy];
}

/* Ranks follow the server's PREFIX order, measured from the operator mode */
- (void)testRanksFollowThePrefixOrder
{
	[self.client.supportInfo processConfigurationData:@"me PREFIX=(Yqaohv)!~&@%+ :are supported by this server"];

	XCTAssertEqual([self memberWithModes:@"Y"].rank, IRCUserRankIRCopByMode);
	XCTAssertEqual([self memberWithModes:@"q"].rank, IRCUserRankChannelOwner);
	XCTAssertEqual([self memberWithModes:@"a"].rank, IRCUserRankSuperOperator);
	XCTAssertEqual([self memberWithModes:@"o"].rank, IRCUserRankNormalOperator);
	XCTAssertEqual([self memberWithModes:@"h"].rank, IRCUserRankHalfOperator);
	XCTAssertEqual([self memberWithModes:@"v"].rank, IRCUserRankVoiced);

	XCTAssertTrue([self memberWithModes:@"q"].isOp);
	XCTAssertFalse([self memberWithModes:@"h"].isOp);
	XCTAssertTrue([self memberWithModes:@"h"].isHalfOp);
	XCTAssertFalse([self memberWithModes:@"v"].isHalfOp);
}

/* A network with only op and voice */
- (void)testRanksWithOnlyOperatorAndVoice
{
	[self.client.supportInfo processConfigurationData:@"me PREFIX=(ov)@+ :are supported by this server"];

	XCTAssertEqual([self memberWithModes:@"o"].rank, IRCUserRankNormalOperator);
	XCTAssertEqual([self memberWithModes:@"v"].rank, IRCUserRankVoiced);
	XCTAssertTrue([self memberWithModes:@"o"].isOp);
	XCTAssertTrue([self memberWithModes:@"o"].isHalfOp);
	XCTAssertFalse([self memberWithModes:@"v"].isOp);
	XCTAssertEqual([self memberWithModes:@""].rank, IRCUserRankNone);
}

@end

NS_ASSUME_NONNULL_END
