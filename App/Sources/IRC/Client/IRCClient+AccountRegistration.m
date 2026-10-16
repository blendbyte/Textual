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

#import "NSStringHelper.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TLOLocalization.h"
#import "IRCClientConfig.h"
#import "IRCMessage.h"
#import "IRCWorld.h"
#import "IRCClientPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* draft/account-registration (https://ircv3.net/specs/extensions/account-registration):
 /register and /verify create an account on networks that offer it, and once
 it exists its name and password are saved for logging in (SASL). */

@implementation IRCClient (AccountRegistration)

- (void)processAccountRegistrationCapabilityValue:(nullable NSString *)value
{
	BOOL requiresEmail = NO;
	BOOL allowsCustomName = NO;

	/* Flags not understood are ignored */
	for (NSString *flag in [value componentsSeparatedByString:@","]) {
		if ([flag isEqualToString:@"email-required"]) {
			requiresEmail = YES;
		} else if ([flag isEqualToString:@"custom-account-name"]) {
			allowsCustomName = YES;
		}
	}

	self.accountRegistrationRequiresEmail = requiresEmail;
	self.accountRegistrationAllowsCustomName = allowsCustomName;
}

+ (nullable NSArray<NSString *> *)accountRegistrationParametersForArguments:(NSArray<NSString *> *)arguments nickname:(NSString *)nickname requiresEmail:(BOOL)requiresEmail allowsCustomName:(BOOL)allowsCustomName problem:(IRCClientAccountRegistrationProblem *)problem
{
	NSParameterAssert(arguments != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(problem != NULL);

	*problem = IRCClientAccountRegistrationProblemSyntax;

	if (arguments.count < 2 || arguments.count > 3) {
		return nil;
	}

	/* "*" for the account is the current nickname */
	NSString *account = ((arguments.count == 3) ? arguments[0] : @"*");

	NSString *email = arguments[arguments.count - 2];

	NSString *password = arguments.lastObject;

	/* Without an @, the address is more likely a name in the wrong place */
	if ([email isEqualToString:@"*"] == NO && [email contains:@"@"] == NO) {
		return nil;
	}

	if ([account isEqualToString:@"*"] == NO && [account isEqualToStringIgnoringCase:nickname] == NO && allowsCustomName == NO) {
		*problem = IRCClientAccountRegistrationProblemCustomNameNotAllowed;

		return nil;
	}

	if ([email isEqualToString:@"*"] && requiresEmail) {
		*problem = IRCClientAccountRegistrationProblemEmailRequired;

		return nil;
	}

	*problem = IRCClientAccountRegistrationProblemNone;

	return @[account, email, password];
}

#pragma mark -
#pragma mark Commands

- (BOOL)accountRegistrationOffered
{
	if ([self isCapabilityEnabled:ClientIRCv3SupportedCapabilityAccountRegistration]) {
		return YES;
	}

	[self printDebugInformation:TXTLS(@"IRC[acr-n1]") inChannel:[self channelForReplyWithFallback:nil]];

	return NO;
}

- (void)registerAccountWithArguments:(NSArray<NSString *> *)arguments
{
	NSParameterAssert(arguments != nil);

	if ([self accountRegistrationOffered] == NO) {
		return;
	}

	IRCClientAccountRegistrationProblem problem = IRCClientAccountRegistrationProblemNone;

	NSArray *parameters = [IRCClient accountRegistrationParametersForArguments:arguments
																	  nickname:self.userNickname
																 requiresEmail:self.accountRegistrationRequiresEmail
															  allowsCustomName:self.accountRegistrationAllowsCustomName
																	   problem:&problem];

	if (parameters == nil) {
		NSString *message = nil;

		switch (problem) {
			case IRCClientAccountRegistrationProblemEmailRequired:
			{
				message = TXTLS(@"IRC[acr-e1]");

				break;
			}
			case IRCClientAccountRegistrationProblemCustomNameNotAllowed:
			{
				message = TXTLS(@"IRC[acr-c1]", self.userNickname);

				break;
			}
			default:
			{
				message = TXTLS(@"IRC[acr-u1]");

				break;
			}
		}

		[self printDebugInformation:message inChannel:[self channelForReplyWithFallback:nil]];

		return;
	}

	NSString *account = parameters[0];

	self.accountRegistrationAccount = (([account isEqualToString:@"*"]) ? self.userNickname : account);
	self.accountRegistrationPassword = parameters[2];

	[self send:@"REGISTER", parameters[0], parameters[1], parameters[2], nil];
}

- (void)verifyAccountWithArguments:(NSArray<NSString *> *)arguments
{
	NSParameterAssert(arguments != nil);

	if ([self accountRegistrationOffered] == NO) {
		return;
	}

	if (arguments.count < 1 || arguments.count > 2) {
		[self printDebugInformation:TXTLS(@"IRC[acr-u2]") inChannel:[self channelForReplyWithFallback:nil]];

		return;
	}

	/* The account just registered, unless named */
	NSString *account = ((arguments.count == 2) ? arguments[0] : (self.accountRegistrationAccount ?: self.userNickname));

	[self send:@"VERIFY", account, arguments.lastObject, nil];
}

#pragma mark -
#pragma mark Replies

/* REGISTER SUCCESS <account> <message>, REGISTER VERIFICATION_REQUIRED <account> <message>,
 VERIFY SUCCESS <account> <message> */
- (void)receiveAccountRegistrationReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	NSAssertReturn([m paramsCount] >= 3);

	NSString *status = [m paramAt:0];

	NSString *account = [m paramAt:1];

	IRCChannel *channel = [self channelForReplyWithFallback:nil];

	[self printDebugInformation:[m paramAt:2] inChannel:channel asCommand:m.command];

	if ([status isEqualToStringIgnoringCase:@"SUCCESS"]) {
		[self saveRegisteredAccount:account];
	} else if ([status isEqualToStringIgnoringCase:@"VERIFICATION_REQUIRED"]) {
		self.accountRegistrationAccount = account;

		[self printDebugInformation:TXTLS(@"IRC[acr-v1]") inChannel:channel];
	}
}

/* A failed REGISTER ends it (a wrong code can be tried again) */
- (void)noteAccountRegistrationStandardReply:(IRCMessage *)m
{
	NSParameterAssert(m != nil);

	if ([m.command isEqualToStringIgnoringCase:@"FAIL"] && [[m paramAt:0] isEqualToStringIgnoringCase:@"REGISTER"]) {
		self.accountRegistrationAccount = nil;
		self.accountRegistrationPassword = nil;
	}
}

- (void)saveRegisteredAccount:(NSString *)account
{
	NSParameterAssert(account != nil);

	NSString *password = self.accountRegistrationPassword;

	self.accountRegistrationAccount = nil;
	self.accountRegistrationPassword = nil;

	if (password.length == 0 || account.length == 0) {
		return;
	}

	IRCClientConfigMutable *config = [self.config mutableCopy];

	config.nicknamePassword = password;

	/* SASL logs in with the username, or the nickname without one */
	if ([account isEqualToStringIgnoringCase:[self saslUsername]] == NO) {
		config.username = account;
	}

	[self updateConfig:config];

	[worldController() save];

	[self printDebugInformation:TXTLS(@"IRC[acr-k1]", account) inChannel:[self channelForReplyWithFallback:nil]];
}

@end

NS_ASSUME_NONNULL_END
