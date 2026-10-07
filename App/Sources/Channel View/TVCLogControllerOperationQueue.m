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

#import "TXMasterController.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TVCLogController.h"
#import "TVCLogControllerOperationQueuePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Define Private Header

@interface TVCLogControllerPrintingOperation : NSOperation
@property (nonatomic, copy, nullable) TVCLogControllerPrintingBlock executionBlock;
@property (nonatomic, weak) TVCLogController *viewController;
@property (readonly, getter=isPending) BOOL pending;
@property (nonatomic, assign, getter=isStandalone) BOOL standalone;
@end

@interface TVCLogControllerPrintingOperationQueue ()
/* This queue is application wide and stores all printing operations. 
 Having a single queue gives us greater control over what happens,
 instead of trying to optimize one queue per-server. */
/* One problem of having a single queue through, is indexing which
 operations are associated with which view controller. To make this
 task easier, we maintain our own internal cache of pending operations
 which we can query at any time to know whats happening. The queue
 then observes the isFinished property to know when to remove the
 operations from our internal cache. */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pendingOperations;
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

	self.pendingOperations = [NSMutableDictionary dictionary];

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

	TVCLogControllerPrintingOperation *operation = [TVCLogControllerPrintingOperation new];

	operation.executionBlock = callbackBlock;

	operation.standalone = isStandalone;

	operation.viewController = viewController;

	[self addPendingOperation:operation];
}

#pragma mark -
#pragma mark Internal Operation Management

- (NSArray<TVCLogControllerPrintingOperation *> *)pendingOperationsForViewController:(TVCLogController *)viewController
{
	NSParameterAssert(viewController != nil);

	NSString *pendingOperationsKey = viewController.description;

	NSArray<TVCLogControllerPrintingOperation *> *pendingOperations = nil;

	@synchronized (self.pendingOperations) {
		pendingOperations = self.pendingOperations[pendingOperationsKey];
	}

	if (pendingOperations == nil) {
		return @[];
	}

	return [pendingOperations copy];
}

- (void)addPendingOperation:(TVCLogControllerPrintingOperation *)operation
{
	NSParameterAssert(operation != nil);

	TVCLogControllerPrintingOperation *operationDependency = nil;

	/* Add operation to list of pending operations and while we have those,
	 also pick out what will be its dependency. */
	NSString *pendingOperationsKey = operation.viewController.description;

	@synchronized (self.pendingOperations) {
		NSMutableArray *pendingOperations = self.pendingOperations[pendingOperationsKey];

		if (pendingOperations == nil) {
			pendingOperations = [NSMutableArray array];

			self.pendingOperations[pendingOperationsKey] = pendingOperations;
		} else {
			for (TVCLogControllerPrintingOperation *pendingOperation in pendingOperations.reverseObjectEnumerator) {
				if (pendingOperation.isCancelled || pendingOperation.isStandalone) {
					continue;
				}

				operationDependency = pendingOperation;

				break;
			}
		}

		[pendingOperations addObject:operation];
	}

	/* Add dependency to operation */
	if (operationDependency) {
		[operation addDependency:operationDependency];
	}

	/* Begin observing when the status of the operation changes */
	[operation addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:nil];

	/* Add operation to the queue */
	[super addOperation:operation];
}

- (void)removePendingOperation:(TVCLogControllerPrintingOperation *)operation
{
	NSParameterAssert(operation != nil);

	/* Remove operation from list of pending operations */
	NSString *pendingOperationsKey = operation.viewController.description;

	@synchronized (self.pendingOperations) {
		NSMutableArray *pendingOperations = self.pendingOperations[pendingOperationsKey];

		if (pendingOperations == nil) {
			LogToConsoleError("'pendingOperations' is nil when it's not supposed to be. wat?");

			return;
		}

		[pendingOperations removeObjectIdenticalTo:operation];
	}

	/* Remove dependency to operation */
	/* Having a ton of chained dependencies can cause a stack overflow
	 when they deallocate. Manually removing dependencies fixes this pattern:

	 0   CoreFoundation                       0x00007fffa2694d1e -[__NSArrayM dealloc] + 14
	 1   Foundation                           0x00007fffa410d79b -[__NSOperationInternal dealloc] + 177
	 2   Foundation                           0x00007fffa410d664 -[NSOperation dealloc] + 58
	 3   CoreFoundation                       0x00007fffa27e237e common_removeAllObjects + 254
	 4   CoreFoundation                       0x00007fffa2694d23 -[__NSArrayM dealloc] + 19
	 5   Foundation                           0x00007fffa410d79b -[__NSOperationInternal dealloc] + 177
	 6   Foundation                           0x00007fffa410d664 -[NSOperation dealloc] + 58
	 7   CoreFoundation                       0x00007fffa27e237e common_removeAllObjects + 254

	 ... repeated for a total of 512 hops before crashing. */
	NSOperation *operationDependency = operation.dependencies.firstObject;

	if (operationDependency) {
		[operation removeDependency:operationDependency];
	}

	/* End observing when the status of the operation changes */
	[operation removeObserver:self forKeyPath:@"isFinished"];
}

#pragma mark -
#pragma mark cancelAllOperations Substitute

- (void)cancelOperationsForViewController:(TVCLogController *)viewController
{
	NSParameterAssert(viewController != nil);

	NSArray *operations = [self pendingOperationsForViewController:viewController];

	[operations makeObjectsPerformSelector:@selector(cancel)];
}

- (void)cancelOperationsForClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	[self cancelOperationsForViewController:client.viewController];
}

- (void)cancelOperationsForChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	[self cancelOperationsForViewController:channel.viewController];
}

#pragma mark -
#pragma mark State Changes

- (void)updateReadinessState:(TVCLogController *)viewController
{
	NSParameterAssert(viewController != nil);

	NSArray *operations = [self pendingOperationsForViewController:viewController];

	for (TVCLogControllerPrintingOperation *operation in operations) {
		if (operation.isPending == NO || operation.dependencies.count > 0) {
			continue;
		}

		[operation willChangeValueForKey:@"isReady"];
		[operation didChangeValueForKey:@"isReady"];
	}
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"isFinished"]) {
		[self removePendingOperation:object];
	}
}

@end

#pragma mark -
#pragma mark Operation Queue Items

@implementation TVCLogControllerPrintingOperation

- (BOOL)isPending
{
	return (self.isCancelled == NO && self.isExecuting == NO && self.isFinished == NO);
}

- (void)main
{
	[self executeBlock];
}

- (void)executeBlock
{
	if (self.isCancelled) {
		return;
	}

	self.executionBlock(self);
}

- (BOOL)isReady
{
	if (self.dependencies.count < 1 || self.isStandalone) {
		return (super.isReady && self.viewController.viewIsLoaded);
	} else {
		return  super.isReady;
	}
}

@end

NS_ASSUME_NONNULL_END
