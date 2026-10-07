/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
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

#import "IRCClientPrivate.h"
#import "IRCChannel.h"
#import "NSObjectHelperPrivate.h"
#import "TLOTimer.h"
#import "IRCTimerCommandPrivate.h"

NS_ASSUME_NONNULL_BEGIN

static NSUInteger IRCTimedCommandLastIdentifier = 0;

@interface IRCTimedCommand ()
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *clientId;
@property (nonatomic, copy, nullable, readwrite) NSString *channelId;
@property (nonatomic, copy, readwrite) NSString *command;
@property (nonatomic, strong) TLOTimer *timer;
@property (nonatomic, assign) BOOL startedBefore;
@end

@implementation IRCTimedCommand

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithCommand:(NSString *)command onClient:(IRCClient *)client
{
	NSParameterAssert(command != nil);
	NSParameterAssert(client != nil);

	return [self initWithCommand:command onClient:client inChannel:nil];
}

- (instancetype)initWithCommand:(NSString *)command onClient:(IRCClient *)client inChannel:(nullable IRCChannel *)channel
{
	NSParameterAssert(command != nil);
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.clientId = client.uniqueIdentifier;
		self.channelId = channel.uniqueIdentifier;

		self.command = command;

		[self assignIdentifier];

		[self initTimerForClient:client];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self.timer stop];

	self.timer = nil;
}

- (void)assignIdentifier
{
	IRCTimedCommandLastIdentifier++;

	self.identifier = [NSString stringWithUnsignedInteger:IRCTimedCommandLastIdentifier];
}

- (void)initTimerForClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	__weak typeof(self) weakSelf = self;

	self.timer =
	[TLOTimer timerWithActionBlock:^(TLOTimer * _Nonnull sender) {
		[client onTimedCommand:weakSelf];
	}];
}

- (void)start:(NSTimeInterval)timerInterval
{
	[self start:timerInterval onRepeat:NO iterations:0];
}

- (void)start:(NSTimeInterval)timerInterval onRepeat:(BOOL)repeatTimer
{
	[self start:timerInterval onRepeat:repeatTimer iterations:0];
}

- (void)start:(NSTimeInterval)timerInterval onRepeat:(BOOL)repeatTimer iterations:(NSUInteger)iterations
{
	[self.timer start:timerInterval onRepeat:repeatTimer iterations:iterations];

	self.startedBefore = YES;
}

- (void)stop
{
	[self.timer stop];
}

- (BOOL)restart
{
	if (self.startedBefore == NO) {
		return NO;
	}

	[self start:self.timerInterval onRepeat:self.repeatTimer iterations:self.iterations];

	return YES;
}

- (NSTimeInterval)timerInterval
{
	return self.timer.interval;
}

- (BOOL)timerIsActive
{
	return self.timer.timerIsActive;
}

- (BOOL)repeatTimer
{
	return self.timer.repeatTimer;
}

- (NSUInteger)iterations
{
	return self.timer.iterations;
}

- (NSUInteger)currentIteration
{
	return self.timer.currentIteration;
}

- (NSTimeInterval)startTime
{
	return self.timer.startTime;
}

- (NSTimeInterval)timeRemaining
{
	return self.timer.timeRemaining;
}

@end

NS_ASSUME_NONNULL_END
