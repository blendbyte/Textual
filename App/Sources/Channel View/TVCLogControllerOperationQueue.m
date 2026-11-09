/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import <os/lock.h>

#import "TXMasterController.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TVCLogController.h"
#import "TVCLogControllerOperationQueuePrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* How many lines of a view are printed before other views get their turn */
#define _blocksPerTurn		32

#pragma mark -
#pragma mark Define Private Header

@interface TVCLogControllerPrintingOperation : NSOperation
@property (nonatomic, copy, nullable) TVCLogControllerPrintingBlock executionBlock;
@end

@interface TVCLogControllerPrintingEntry : NSObject
@property (nonatomic, copy) TVCLogControllerPrintingBlock block;
@property (nonatomic, assign) BOOL standalone;
@end

/* What a view has waiting. Its entries are printed in order by one operation
 at a time (its turn), which the queue only sees while the view can print:
 a bouncer's backlog is one operation per few dozen lines, not one per line,
 which had the main thread and every worker waiting on the queue's lock. */
@interface TVCLogControllerPrintingLane : NSObject
@property (nonatomic, weak) TVCLogController *viewController;
@property (nonatomic, strong) NSMutableArray<TVCLogControllerPrintingEntry *> *entries;
@property (nonatomic, strong, nullable) TVCLogControllerPrintingOperation *turn;
@property (nonatomic, strong) NSHashTable<TVCLogControllerPrintingOperation *> *standaloneOperations;
@end

@interface TVCLogControllerPrintingOperationQueue ()
{
	os_unfair_lock _lanesLock;
}

/* Keys are weak: a lane goes when its view controller does. Guarded by the lock. */
@property (nonatomic, strong) NSMapTable<TVCLogController *, TVCLogControllerPrintingLane *> *lanes;
@end

#pragma mark -
#pragma mark Operation Queue

@implementation TVCLogControllerPrintingOperationQueue

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
	self.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;

	self.name = @"TVCLogControllerPrintingOperationQueue";

	self->_lanesLock = OS_UNFAIR_LOCK_INIT;

	self.lanes = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality)
									   valueOptions:NSPointerFunctionsStrongMemory];

	self.qualityOfService = NSQualityOfServiceDefault;
 }

#pragma mark -
#pragma mark Queue Additions

- (void)enqueueMessageBlock:(TVCLogControllerPrintingBlock)callbackBlock for:(TVCLogController *)viewController
{
	[self enqueueMessageBlock:callbackBlock for:viewController isStandalone:NO];
}

- (void)enqueueMessageBlock:(TVCLogControllerPrintingBlock)callbackBlock for:(TVCLogController *)viewController isStandalone:(BOOL)isStandalone
{
	NSParameterAssert(callbackBlock != nil);
	NSParameterAssert(viewController != nil);

	if (masterController().applicationIsTerminating) {
		return;
	}

	TVCLogControllerPrintingEntry *entry = [TVCLogControllerPrintingEntry new];

	entry.block = callbackBlock;

	entry.standalone = isStandalone;

	os_unfair_lock_lock(&self->_lanesLock);

	TVCLogControllerPrintingLane *lane = [self.lanes objectForKey:viewController];

	if (lane == nil) {
		lane = [TVCLogControllerPrintingLane new];

		lane.viewController = viewController;

		[self.lanes setObject:lane forKey:viewController];
	}

	[lane.entries addObject:entry];

	os_unfair_lock_unlock(&self->_lanesLock);

	[self _beginTurnInLane:lane ofViewController:viewController];
}

#pragma mark -
#pragma mark Turns

- (void)_beginTurnInLane:(TVCLogControllerPrintingLane *)lane ofViewController:(TVCLogController *)viewController
{
	/* Lines wait for the view; -updateReadinessState: starts them */
	if (viewController.viewIsLoaded == NO) {
		return;
	}

	TVCLogControllerPrintingOperation *turn = nil;

	os_unfair_lock_lock(&self->_lanesLock);

	if (lane.turn == nil && lane.entries.count > 0) {
		turn = [TVCLogControllerPrintingOperation new];

		lane.turn = turn;
	}

	os_unfair_lock_unlock(&self->_lanesLock);

	if (turn == nil) {
		return;
	}

	__weak TVCLogControllerPrintingOperation *weakTurn = turn;

	turn.executionBlock = ^(NSOperation *sender) {
		TVCLogControllerPrintingOperation *strongTurn = weakTurn;

		if (strongTurn) {
			[self _takeTurn:strongTurn inLane:lane];
		}
	};

	[super addOperation:turn];
}

- (void)_takeTurn:(TVCLogControllerPrintingOperation *)turn inLane:(TVCLogControllerPrintingLane *)lane
{
	NSArray<TVCLogControllerPrintingEntry *> *entries = nil;

	os_unfair_lock_lock(&self->_lanesLock);

	if (lane.turn == turn) {
		NSRange range = NSMakeRange(0, MIN(_blocksPerTurn, lane.entries.count));

		entries = [lane.entries subarrayWithRange:range];

		[lane.entries removeObjectsInRange:range];
	}

	os_unfair_lock_unlock(&self->_lanesLock);

	for (TVCLogControllerPrintingEntry *entry in entries) {
		if (turn.isCancelled) {
			break;
		}

		if (entry.standalone) {
			[self _startStandaloneEntry:entry duringTurn:turn inLane:lane];

			continue;
		}

		@autoreleasepool {
			entry.block(turn);
		}
	}

	os_unfair_lock_lock(&self->_lanesLock);

	if (lane.turn == turn) {
		lane.turn = nil;
	}

	os_unfair_lock_unlock(&self->_lanesLock);

	TVCLogController *viewController = lane.viewController;

	if (viewController && turn.isCancelled == NO) {
		[self _beginTurnInLane:lane ofViewController:viewController];
	}
}

/* Runs beside the lines that follow it, after the lines before it */
- (void)_startStandaloneEntry:(TVCLogControllerPrintingEntry *)entry duringTurn:(TVCLogControllerPrintingOperation *)turn inLane:(TVCLogControllerPrintingLane *)lane
{
	TVCLogControllerPrintingOperation *operation = [TVCLogControllerPrintingOperation new];

	operation.executionBlock = entry.block;

	os_unfair_lock_lock(&self->_lanesLock);

	BOOL cancelled = (lane.turn != turn);

	if (cancelled == NO) {
		[lane.standaloneOperations addObject:operation];
	}

	os_unfair_lock_unlock(&self->_lanesLock);

	if (cancelled == NO) {
		[super addOperation:operation];
	}
}

#pragma mark -
#pragma mark cancelAllOperations Substitute

- (void)cancelOperationsForViewController:(TVCLogController *)viewController
{
	NSParameterAssert(viewController != nil);

	/* Taken out so that what they hold on to isn't released inside the lock */
	NS_VALID_UNTIL_END_OF_SCOPE NSArray *entries = nil;

	TVCLogControllerPrintingOperation *turn = nil;

	NSArray<TVCLogControllerPrintingOperation *> *standaloneOperations = nil;

	os_unfair_lock_lock(&self->_lanesLock);

	TVCLogControllerPrintingLane *lane = [self.lanes objectForKey:viewController];

	if (lane) {
		entries = lane.entries;

		lane.entries = [NSMutableArray array];

		turn = lane.turn;

		lane.turn = nil;

		standaloneOperations = lane.standaloneOperations.allObjects;
	}

	os_unfair_lock_unlock(&self->_lanesLock);

	[turn cancel];

	for (TVCLogControllerPrintingOperation *operation in standaloneOperations) {
		[operation cancel];
	}
}

#pragma mark -
#pragma mark State Changes

- (void)updateReadinessState:(TVCLogController *)viewController
{
	NSParameterAssert(viewController != nil);

	os_unfair_lock_lock(&self->_lanesLock);

	TVCLogControllerPrintingLane *lane = [self.lanes objectForKey:viewController];

	os_unfair_lock_unlock(&self->_lanesLock);

	if (lane) {
		[self _beginTurnInLane:lane ofViewController:viewController];
	}
}

@end

#pragma mark -
#pragma mark Operation Queue Items

@implementation TVCLogControllerPrintingEntry
@end

@implementation TVCLogControllerPrintingLane

- (instancetype)init
{
	if ((self = [super init])) {
		self.entries = [NSMutableArray array];

		self.standaloneOperations = [NSHashTable weakObjectsHashTable];

		return self;
	}

	return nil;
}

@end

@implementation TVCLogControllerPrintingOperation

- (void)main
{
	if (self.isCancelled) {
		return;
	}

	self.executionBlock(self);

	self.executionBlock = nil;
}

@end

NS_ASSUME_NONNULL_END
