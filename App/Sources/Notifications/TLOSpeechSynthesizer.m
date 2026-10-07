/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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
#import "TLOSpokenNotificationPrivate.h"
#import "TLOSpeechSynthesizerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLOSpeechSynthesizer ()
@property (nonatomic, strong) NSSpeechSynthesizer *speechSynthesizer;
@property (nonatomic, strong) NSMutableArray *itemsToBeSpoken;
@property (nonatomic, assign) BOOL isWaitingForSystemToStopSpeaking;
@end

@implementation TLOSpeechSynthesizer

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.itemsToBeSpoken = [NSMutableArray array];

	self.speechSynthesizer = [NSSpeechSynthesizer new];
	self.speechSynthesizer.delegate = (id)self;

	self.isStopped = NO;
}

- (void)dealloc
{
	self.speechSynthesizer.delegate = nil;
}

#pragma mark -
#pragma mark Public API

- (void)speak:(id)object
{
	NSParameterAssert(object != nil);

	if (self.isStopped) {
		return;
	}

	@synchronized(self.itemsToBeSpoken) {
		[self.itemsToBeSpoken addObject:object];
	}

	if (self.isSpeaking == NO) {
		[self speakNextItem];
	}
}

- (void)speakNextItemWhenSystemFinishes
{
	/* This method sleeps the thread for one second each pass then
	 to check if another application on the system is speaking. */
	while ([NSSpeechSynthesizer isAnyApplicationSpeaking]) {
		[NSThread sleepForTimeInterval:1.0];
	}

	self.isWaitingForSystemToStopSpeaking = NO;

	[self speakNextItem];
}

- (void)speakNextItem
{
	if (self.isStopped) {
		return;
	}

	@synchronized(self.itemsToBeSpoken) {
		id nextMessage = self.itemsToBeSpoken.firstObject;

		if (nextMessage == nil) {
			return;
		}

		if ([NSSpeechSynthesizer isAnyApplicationSpeaking]) {
			if (self.isWaitingForSystemToStopSpeaking == NO) {
				self.isWaitingForSystemToStopSpeaking = YES;

				XRPerformBlockAsynchronouslyOnGlobalQueueWithPriority(^{
					[self speakNextItemWhenSystemFinishes];
				}, DISPATCH_QUEUE_PRIORITY_LOW);
			}

			return;
		}

		[self.itemsToBeSpoken removeObjectAtIndex:0];

		if ([nextMessage isKindOfClass:[TLOSpokenNotification class]]) {
			nextMessage = [(IRCClient *)[nextMessage client] formatNotificationToSpeak:nextMessage];

			// Returning nil does not throw an assert so that the client can chose
			// to reject specific events for whatever reason it wants.
			if (nextMessage == nil) {
				[self speakNextItem];

				return;
			}
		}

		[self.speechSynthesizer startSpeakingString:nextMessage];
	}
}

- (void)stopSpeakingAndMoveForward
{
	if (self.isSpeaking == NO) {
		return;
	}

	[self.speechSynthesizer stopSpeaking]; // Will call delegate to do next item
}

- (void)stopSpeakingIfSet
{
	if (self.isSpeaking == NO || self.isStopped == NO) {
		return;
	}

	[self.speechSynthesizer stopSpeaking];
}

- (BOOL)isSpeaking
{
	return self.speechSynthesizer.isSpeaking;
}

- (void)setIsStopped:(BOOL)isStopped
{
	if (self->_isStopped != isStopped) {
		self->_isStopped = isStopped;

		[self stopSpeakingIfSet];
	}
}

- (void)clearQueue
{
	@synchronized(self.itemsToBeSpoken) {
		[self.itemsToBeSpoken removeAllObjects];
	}
}

- (void)clearQueueForClient:(IRCClient *)client
{
	@synchronized(self.itemsToBeSpoken) {
		NSIndexSet *indexesToRemove = [self.itemsToBeSpoken indexesOfObjectsPassingTest:^BOOL(id object, NSUInteger index, BOOL *stop) {
			if ([object isKindOfClass:[TLOSpokenNotification class]]) {
				return ((IRCClient *)[object client] == client);
			}

			return NO;
		}];

		if (indexesToRemove.count == 0) {
			return;
		}

		[self.itemsToBeSpoken removeObjectsAtIndexes:indexesToRemove];
	}
}

#pragma mark -
#pragma mark Delegate Callback

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking
{
	[self speakNextItem];
}

@end

NS_ASSUME_NONNULL_END
