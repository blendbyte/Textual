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

#import "IRCCapabilityNegotiatorPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Leaves room for "CAP REQ :" and the prefix servers add when relaying */
#define _requestDataMaximumLength		400

@interface IRCCapabilityNegotiator ()
@property (readwrite) BOOL isPaused;
@property (nonatomic, assign) BOOL registered;
@property (nonatomic, assign) BOOL ended;
@property (nonatomic, assign) BOOL listReceived;
@property (nonatomic, assign) NSUInteger openRequestCount;
@property (nonatomic, strong) NSMutableArray<NSString *> *offeredCapabilities;
@end

@implementation IRCCapabilityNegotiator

- (instancetype)init
{
	if ((self = [super init])) {
		[self reset];
	}

	return self;
}

- (void)reset
{
	self.isPaused = NO;
	self.registered = NO;
	self.ended = NO;
	self.listReceived = NO;
	self.openRequestCount = 0;
	self.offeredCapabilities = [NSMutableArray array];
}

- (void)registrationCompleted
{
	self.registered = YES;
}

- (void)pause
{
	self.isPaused = YES;
}

- (void)resume
{
	self.isPaused = NO;

	[self endIfDone];
}

#pragma mark -
#pragma mark Replies

- (void)receiveCapabilityReply:(NSString *)subcommand parameters:(NSArray<NSString *> *)parameters
{
	NSParameterAssert(subcommand != nil);
	NSParameterAssert(parameters != nil);

	id <IRCCapabilityNegotiatorDelegate> delegate = self.delegate;

	/* CAP 302: all but the last line of a multi-line reply carry "*"
	 before the capability list */
	BOOL moreLinesFollow = (parameters.count > 1 && [parameters.firstObject isEqualToString:@"*"]);

	if (moreLinesFollow) {
		parameters = [parameters subarrayWithRange:NSMakeRange(1, (parameters.count - 1))];
	}

	NSArray<NSString *> *capabilities = [self capabilitiesInParameters:parameters];

	if ([subcommand isEqualToStringIgnoringCase:@"LS"])
	{
		[self.offeredCapabilities addObjectsFromArray:capabilities];

		if (moreLinesFollow) {
			return;
		}

		NSArray *offeredCapabilities = [self.offeredCapabilities copy];

		[self.offeredCapabilities removeAllObjects];

		self.listReceived = YES;

		[self requestCapabilities:offeredCapabilities];

		[self endIfDone];
	}
	else if ([subcommand isEqualToStringIgnoringCase:@"NEW"])
	{
		[self requestCapabilities:capabilities];
	}
	else if ([subcommand isEqualToStringIgnoringCase:@"ACK"])
	{
		for (NSString *capability in capabilities) {
			if ([capability hasPrefix:@"-"]) {
				[delegate capabilityNegotiator:self didDisableCapability:[capability substringFromIndex:1]];
			} else {
				[delegate capabilityNegotiator:self didEnableCapability:capability];
			}
		}

		[self requestAnswered:moreLinesFollow];
	}
	else if ([subcommand isEqualToStringIgnoringCase:@"NAK"])
	{
		for (NSString *capability in capabilities) {
			[delegate capabilityNegotiator:self didDisableCapability:capability];
		}

		[self requestAnswered:moreLinesFollow];
	}
	else if ([subcommand isEqualToStringIgnoringCase:@"DEL"])
	{
		for (NSString *capability in capabilities) {
			[delegate capabilityNegotiator:self didDisableCapability:capability];
		}
	}
}

- (NSArray<NSString *> *)capabilitiesInParameters:(NSArray<NSString *> *)parameters
{
	NSMutableArray<NSString *> *capabilities = [NSMutableArray array];

	for (NSString *parameter in parameters) {
		for (NSString *capability in [parameter componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
			if (capability.length > 0) {
				[capabilities addObject:capability];
			}
		}
	}

	return [capabilities copy];
}

- (void)requestAnswered:(BOOL)moreLinesFollow
{
	if (moreLinesFollow) {
		return;
	}

	if (self.openRequestCount > 0) {
		self.openRequestCount -= 1;
	}

	[self endIfDone];
}

#pragma mark -
#pragma mark Requests

- (void)requestCapabilities:(NSArray<NSString *> *)offeredCapabilities
{
	id <IRCCapabilityNegotiatorDelegate> delegate = self.delegate;

	NSMutableArray<NSString *> *wantedCapabilities = [NSMutableArray array];

	for (NSString *offeredCapability in offeredCapabilities) {
		NSString *value = nil;

		NSString *capability = [self.class capabilityName:offeredCapability value:&value];

		if ([wantedCapabilities containsObject:capability]) {
			continue;
		}

		if ([delegate capabilityNegotiator:self shouldRequestCapability:capability value:value]) {
			[wantedCapabilities addObject:capability];
		}
	}

	NSArray *requests = [self.class requestDataForCapabilities:wantedCapabilities maximumLength:_requestDataMaximumLength];

	self.openRequestCount += requests.count;

	for (NSString *request in requests) {
		[delegate capabilityNegotiator:self sendCapabilityCommand:@"REQ" data:request];
	}
}

/* Registration waits for CAP END: sent once, before registration, after
 the whole LS arrived, every request was answered and SASL is done */
- (void)endIfDone
{
	if (self.registered || self.ended || self.listReceived == NO || self.isPaused || self.openRequestCount > 0) {
		return;
	}

	self.ended = YES;

	[self.delegate capabilityNegotiator:self sendCapabilityCommand:@"END" data:nil];
}

#pragma mark -
#pragma mark Utilities

+ (NSString *)capabilityName:(NSString *)capability value:(NSString * _Nullable * _Nullable)value
{
	NSParameterAssert(capability != nil);

	NSRange separator = [capability rangeOfString:@"="];

	if (separator.location == NSNotFound) {
		if (value) {
			*value = nil;
		}

		return capability;
	}

	if (value) {
		*value = [capability substringFromIndex:NSMaxRange(separator)];
	}

	return [capability substringToIndex:separator.location];
}

+ (NSArray<NSString *> *)requestDataForCapabilities:(NSArray<NSString *> *)capabilities maximumLength:(NSUInteger)maximumLength
{
	NSParameterAssert(capabilities != nil);

	NSMutableArray<NSString *> *requests = [NSMutableArray array];

	NSMutableString *request = [NSMutableString string];

	for (NSString *capability in capabilities) {
		if (request.length > 0 && (request.length + 1 + capability.length) > maximumLength) {
			[requests addObject:[request copy]];

			[request setString:@""];
		}

		if (request.length > 0) {
			[request appendString:@" "];
		}

		[request appendString:capability];
	}

	if (request.length > 0) {
		[requests addObject:[request copy]];
	}

	return [requests copy];
}

@end

NS_ASSUME_NONNULL_END
