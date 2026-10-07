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

NS_ASSUME_NONNULL_BEGIN

@class TLOTimer;

typedef void (^TLOTimerActionBlock)(TLOTimer *sender);

@interface TLOTimer : NSObject
@property (readonly, copy) TLOTimerActionBlock actionBlock;
@property (nonatomic, strong, nullable) dispatch_queue_t queue; // Defaults to main queue. Changed ignored while active.
@property (nonatomic, strong, nullable) id context;

@property (readonly) NSTimeInterval startTime;
@property (readonly) NSTimeInterval timeRemaining;

@property (readonly) NSTimeInterval interval;
@property (readonly) BOOL timerIsActive;
@property (readonly) BOOL repeatTimer;
@property (readonly) NSUInteger iterations;

@property (readonly) NSUInteger currentIteration;

+ (instancetype)timerWithActionBlock:(TLOTimerActionBlock)actionBlock;
+ (instancetype)timerWithActionBlock:(TLOTimerActionBlock)actionBlock onQueue:(dispatch_queue_t)queue;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActionBlock:(TLOTimerActionBlock)actionBlock;
- (instancetype)initWithActionBlock:(TLOTimerActionBlock)actionBlock onQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (void)start:(NSTimeInterval)interval; // repeatTimer = NO
- (void)start:(NSTimeInterval)timerInterval onRepeat:(BOOL)repeatTimer; // iterations = 0
- (void)start:(NSTimeInterval)timerInterval onRepeat:(BOOL)repeatTimer iterations:(NSUInteger)iterations; // 0 iterations = infinite

- (void)stop;
@end

NS_ASSUME_NONNULL_END
