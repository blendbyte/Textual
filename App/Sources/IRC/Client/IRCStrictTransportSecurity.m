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
#import "TPCPreferencesUserDefaults.h"
#import "IRCStrictTransportSecurityPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* host (lower case) → { port, expiresAt } */
static NSString * const IRCStrictTransportSecurityPoliciesKey = @"IRCClient Strict Transport Security Policies";

@interface IRCStrictTransportSecurity ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation IRCStrictTransportSecurity

+ (IRCStrictTransportSecurity *)sharedPolicies
{
	static IRCStrictTransportSecurity *sharedPolicies = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedPolicies = [[self alloc] initWithUserDefaults:RZUserDefaults()];
	});

	return sharedPolicies;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
{
	NSParameterAssert(userDefaults != nil);

	if ((self = [super init])) {
		self.userDefaults = userDefaults;

		return self;
	}

	return nil;
}

+ (void)parseValue:(nullable NSString *)value port:(NSInteger *)port duration:(NSInteger *)duration
{
	NSParameterAssert(port != NULL);
	NSParameterAssert(duration != NULL);

	*port = (-1);
	*duration = (-1);

	for (NSString *pair in [value componentsSeparatedByString:@","]) {
		NSRange equalSign = [pair rangeOfString:@"="];

		if (equalSign.location == NSNotFound) {
			continue;
		}

		NSString *key = [pair substringToIndex:equalSign.location];

		NSString *number = [pair substringFromIndex:NSMaxRange(equalSign)];

		if (number.length == 0 || number.isNumericOnly == NO) {
			continue;
		}

		if ([key isEqualToString:@"port"]) {
			NSInteger portValue = number.integerValue;

			if (portValue > 0 && portValue <= UINT16_MAX) {
				*port = portValue;
			}
		} else if ([key isEqualToString:@"duration"]) {
			*duration = number.integerValue;
		}
	}
}

- (NSDictionary<NSString *, NSDictionary *> *)policies
{
	NSDictionary *policies = [self.userDefaults dictionaryForKey:IRCStrictTransportSecurityPoliciesKey];

	if (policies == nil) {
		return @{};
	}

	return policies;
}

- (void)setPolicy:(nullable NSDictionary *)policy forHost:(NSString *)host
{
	NSMutableDictionary *policies = [[self policies] mutableCopy];

	policies[host.lowercaseString] = policy;

	if (policies.count == 0) {
		[self.userDefaults removeObjectForKey:IRCStrictTransportSecurityPoliciesKey];
	} else {
		[self.userDefaults setObject:policies forKey:IRCStrictTransportSecurityPoliciesKey];
	}
}

- (uint16_t)portForHost:(NSString *)host
{
	return [self portForHost:host atDate:[NSDate date]];
}

- (uint16_t)portForHost:(NSString *)host atDate:(NSDate *)date
{
	NSParameterAssert(host != nil);
	NSParameterAssert(date != nil);

	@synchronized (self) {
		NSDictionary *policy = [self policies][host.lowercaseString];

		if (policy == nil) {
			return 0;
		}

		NSDate *expiresAt = [policy objectForKey:@"expiresAt"];

		NSInteger port = [policy integerForKey:@"port"];

		if ([expiresAt isKindOfClass:[NSDate class]] == NO || [expiresAt compare:date] != NSOrderedDescending ||
			port <= 0 || port > UINT16_MAX)
		{
			[self setPolicy:nil forHost:host];

			return 0;
		}

		return (uint16_t)port;
	}
}

- (void)storePolicyForHost:(NSString *)host port:(uint16_t)port duration:(NSUInteger)duration
{
	[self storePolicyForHost:host port:port duration:duration atDate:[NSDate date]];
}

- (void)storePolicyForHost:(NSString *)host port:(uint16_t)port duration:(NSUInteger)duration atDate:(NSDate *)date
{
	NSParameterAssert(host != nil);
	NSParameterAssert(date != nil);

	if (host.isIPAddress) {
		return;
	}

	@synchronized (self) {
		if (duration == 0 || port == 0) {
			[self setPolicy:nil forHost:host];

			return;
		}

		[self setPolicy:@{
			@"port" : @(port),
			@"expiresAt" : [date dateByAddingTimeInterval:duration]
		} forHost:host];
	}
}

- (nullable NSDate *)expiryForHost:(NSString *)host
{
	NSParameterAssert(host != nil);

	if ([self portForHost:host] == 0) {
		return nil;
	}

	@synchronized (self) {
		return [self policies][host.lowercaseString][@"expiresAt"];
	}
}

- (void)removePolicyForHost:(NSString *)host
{
	NSParameterAssert(host != nil);

	@synchronized (self) {
		[self setPolicy:nil forHost:host];
	}
}

@end

NS_ASSUME_NONNULL_END
