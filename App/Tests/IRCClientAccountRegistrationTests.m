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

#import "IRCClientConfig.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCClientAccountRegistrationTests : XCTestCase
@end

@implementation IRCClientAccountRegistrationTests

- (nullable NSArray<NSString *> *)parametersFor:(NSArray<NSString *> *)arguments requiresEmail:(BOOL)requiresEmail allowsCustomName:(BOOL)allowsCustomName problem:(IRCClientAccountRegistrationProblem *)problem
{
	return [IRCClient accountRegistrationParametersForArguments:arguments nickname:@"bob" requiresEmail:requiresEmail allowsCustomName:allowsCustomName problem:problem];
}

/* The CAP value's flags; unknown ones are ignored */
- (void)testCapabilityValue
{
	IRCClient *client = [[IRCClient alloc] initWithConfig:[IRCClientConfig new]];

	[client processAccountRegistrationCapabilityValue:@"before-connect,email-required,future"];

	XCTAssertTrue(client.accountRegistrationRequiresEmail);
	XCTAssertFalse(client.accountRegistrationAllowsCustomName);

	[client processAccountRegistrationCapabilityValue:@"custom-account-name"];

	XCTAssertFalse(client.accountRegistrationRequiresEmail);
	XCTAssertTrue(client.accountRegistrationAllowsCustomName);

	[client processAccountRegistrationCapabilityValue:nil];

	XCTAssertFalse(client.accountRegistrationAllowsCustomName);
}

/* /register [account] <email or *> <password> → REGISTER <account or *> <email or *> <password> */
- (void)testRegisterParameters
{
	IRCClientAccountRegistrationProblem problem = IRCClientAccountRegistrationProblemNone;

	NSArray *noEmail = @[@"*", @"*", @"secret"];
	NSArray *withEmail = @[@"*", @"bob@example.com", @"secret"];
	NSArray *ownName = @[@"robert", @"*", @"secret"];
	NSArray *currentNick = @[@"BOB", @"*", @"secret"];

	NSArray *arguments1 = @[@"*", @"secret"];

	XCTAssertEqualObjects([self parametersFor:arguments1 requiresEmail:NO allowsCustomName:NO problem:&problem], noEmail);
	XCTAssertEqual(problem, IRCClientAccountRegistrationProblemNone);

	NSArray *arguments2 = @[@"bob@example.com", @"secret"];

	XCTAssertEqualObjects([self parametersFor:arguments2 requiresEmail:YES allowsCustomName:NO problem:&problem], withEmail);

	NSArray *arguments3 = @[@"robert", @"*", @"secret"];

	XCTAssertEqualObjects([self parametersFor:arguments3 requiresEmail:NO allowsCustomName:YES problem:&problem], ownName);

	/* The current nickname is always allowed by name */
	NSArray *arguments4 = @[@"BOB", @"*", @"secret"];

	XCTAssertEqualObjects([self parametersFor:arguments4 requiresEmail:NO allowsCustomName:NO problem:&problem], currentNick);

	/* Problems are found before anything is sent */
	NSArray *arguments5 = @[@"*", @"secret"];

	XCTAssertNil([self parametersFor:arguments5 requiresEmail:YES allowsCustomName:NO problem:&problem]);
	XCTAssertEqual(problem, IRCClientAccountRegistrationProblemEmailRequired);

	NSArray *arguments6 = @[@"robert", @"*", @"secret"];

	XCTAssertNil([self parametersFor:arguments6 requiresEmail:NO allowsCustomName:NO problem:&problem]);
	XCTAssertEqual(problem, IRCClientAccountRegistrationProblemCustomNameNotAllowed);

	/* A name where the address goes, a missing password, too many words */
	NSArray *arguments7 = @[@"robert", @"secret"];

	XCTAssertNil([self parametersFor:arguments7 requiresEmail:NO allowsCustomName:YES problem:&problem]);
	XCTAssertEqual(problem, IRCClientAccountRegistrationProblemSyntax);

	NSArray *arguments8 = @[@"secret"];

	XCTAssertNil([self parametersFor:arguments8 requiresEmail:NO allowsCustomName:NO problem:&problem]);
	XCTAssertEqual(problem, IRCClientAccountRegistrationProblemSyntax);

	NSArray *fourWords = @[@"robert", @"*", @"secret", @"more"];

	XCTAssertNil([self parametersFor:fourWords requiresEmail:NO allowsCustomName:YES problem:&problem]);
	XCTAssertEqual(problem, IRCClientAccountRegistrationProblemSyntax);
}

@end

NS_ASSUME_NONNULL_END
