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

#import "TLOTimer.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLOTimer ()
@property (nonatomic, copy, readwrite) TLOTimerActionBlock actionBlock;
@property (nonatomic, assign, readwrite) NSTimeInterval startTime;
@property (nonatomic, assign, readwrite) NSTimeInterval interval;
@property (nonatomic, assign, readwrite) BOOL repeatTimer;
@property (nonatomic, assign, readwrite) NSUInteger iterations;
@property (nonatomic, assign, readwrite) NSUInteger currentIteration;
@property (nonatomic, strong, nullable) dispatch_source_t timerSource;
@end

@implementation TLOTimer

+ (instancetype)timerWithActionBlock:(TLOTimerActionBlock)actionBlock
{
	NSParameterAssert(actionBlock != NULL);

	return [[self alloc] initWithActionBlock:actionBlock onQueue:nil];
}

+ (instancetype)timerWithActionBlock:(TLOTimerActionBlock)actionBlock onQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(actionBlock != NULL);
	NSParameterAssert(queue != NULL);

	return [[self alloc] initWithActionBlock:actionBlock onQueue:queue];
}

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithActionBlock:(TLOTimerActionBlock)actionBlock
{
	return [self initWithActionBlock:actionBlock onQueue:nil];
}

- (instancetype)initWithActionBlock:(TLOTimerActionBlock)actionBlock onQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(actionBlock != NULL);

	if ((self = [super init])) {
		self.actionBlock = actionBlock;

		self.queue = queue;

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self stop];
}

- (BOOL)timerIsActive
{
	return (self.timerSource != nil);
}

- (NSTimeInterval)timeRemaining
{
	return (self.interval - (CFAbsoluteTimeGetCurrent() - self.startTime));
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
	NSParameterAssert(timerInterval > 0);

	[self stop];

	dispatch_queue_t sourceQueue = self.queue;

	if (sourceQueue == nil) {
		sourceQueue = dispatch_get_main_queue();
	}

	dispatch_source_t timerSource = XRScheduleBlockOnQueue(sourceQueue, ^{
		[self fireTimer];
	}, timerInterval, repeatTimer);

	self.interval = timerInterval;
	self.repeatTimer = repeatTimer;
	self.iterations = iterations;
	self.currentIteration = 0;

	self.timerSource = timerSource;

	XRResumeScheduledBlock(timerSource);

	self.startTime = CFAbsoluteTimeGetCurrent();
}

- (void)stop
{
	dispatch_source_t timerSource = self.timerSource;

	if (timerSource == nil) {
		return;
	}

	XRCancelScheduledBlock(timerSource);

	self.timerSource = nil;
}

- (void)stopIfNeeded
{
	if (self.iterations > 0 &&
		self.iterations == self.currentIteration)
	{
		[self stop];
	}
}

- (void)fireTimer
{
	self.currentIteration += 1;

	/* In the logic presented below, we call
	 -stopIfNeeded before the action. */
	/* We should probably always keep this progression so
	 that the action can know when the iterations limit
	 has been reached by the fact the timer has stopped. */

	/* Perform block */
	TLOTimerActionBlock actionBlock = self.actionBlock;

	[self stopIfNeeded];

	actionBlock(self);
}

@end

NS_ASSUME_NONNULL_END
