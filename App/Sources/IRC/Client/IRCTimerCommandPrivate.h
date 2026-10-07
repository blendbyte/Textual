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

@class IRCClient, IRCChannel;

@interface IRCTimedCommand : NSObject
@property (readonly, copy) NSString *identifier;

@property (readonly, copy) NSString *clientId;
@property (readonly, copy, nullable) NSString *channelId;

@property (readonly, copy) NSString *command;

@property (readonly) NSTimeInterval startTime;
@property (readonly) NSTimeInterval timeRemaining;

@property (readonly) NSTimeInterval timerInterval;
@property (readonly) BOOL timerIsActive;
@property (readonly) BOOL repeatTimer;
@property (readonly) NSUInteger iterations;

@property (readonly) NSUInteger currentIteration;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCommand:(NSString *)command onClient:(IRCClient *)client;
- (instancetype)initWithCommand:(NSString *)command onClient:(IRCClient *)client inChannel:(nullable IRCChannel *)channel NS_DESIGNATED_INITIALIZER;

- (void)start:(NSTimeInterval)interval; // repeatTimer = NO
- (void)start:(NSTimeInterval)timerInterval onRepeat:(BOOL)repeatTimer; // iterations = 0
- (void)start:(NSTimeInterval)timerInterval onRepeat:(BOOL)repeatTimer iterations:(NSUInteger)iterations; // 0 iterations = infinite

- (void)stop;

/* If the timer has been started before, then
 we already know the values to pass to -start:
 In that case, we return YES.
 If we don't know this information yet, then
 we return NO. */
/* Restarting the timer resets the iteration count. */
- (BOOL)restart;
@end

NS_ASSUME_NONNULL_END
