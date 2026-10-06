/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2018 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

COCOA_EXTENSIONS_EXTERN BOOL NSObjectIsEmpty(id _Nullable obj) COCOA_EXTENSIONS_DEPRECATED("Use -length or -count");
COCOA_EXTENSIONS_EXTERN BOOL NSObjectIsNotEmpty(id _Nullable obj) COCOA_EXTENSIONS_DEPRECATED("Use -length or -count");

COCOA_EXTENSIONS_INLINE
BOOL NSObjectsAreEqual(id _Nullable obj1, id _Nullable obj2)
{
	return ((obj1 == nil && obj2 == nil) || [obj1 isEqual:obj2]);
}

#pragma mark -
#pragma mark Grand Central Dispatch

COCOA_EXTENSIONS_INLINE 
void XRPerformBlockSynchronouslyOnQueue(dispatch_queue_t queue, DISPATCH_NOESCAPE dispatch_block_t block)
{
	dispatch_sync(queue, ^{
		@autoreleasepool {
			block();
		}
	});
}

COCOA_EXTENSIONS_INLINE 
void XRPerformBlockAsynchronouslyOnQueue(dispatch_queue_t queue, dispatch_block_t block)
{
	dispatch_async(queue, ^{
		@autoreleasepool {
			block();
		}
	});
}

COCOA_EXTENSIONS_INLINE
void XRPerformBlockSynchronouslyOnMainQueue(DISPATCH_NOESCAPE dispatch_block_t block)
{
	/* Check thread we are on. */
	/* If we are already on the main thread and performing a synchronous action,
	 then all we have to do is invoke the block supplied to us. */
	if ([NSThread isMainThread]) {
		block(); // Perform block.
	} else {
		XRPerformBlockSynchronouslyOnQueue(dispatch_get_main_queue(), block);
	}
}

COCOA_EXTENSIONS_INLINE
void XRPerformBlockAsynchronouslyOnMainQueue(dispatch_block_t block)
{
	XRPerformBlockAsynchronouslyOnQueue(dispatch_get_main_queue(), block);
}

COCOA_EXTENSIONS_INLINE
void XRPerformBlockSynchronouslyOnGlobalQueueWithPriority(DISPATCH_NOESCAPE dispatch_block_t block, dispatch_queue_priority_t priority)
{
	XRPerformBlockSynchronouslyOnQueue(dispatch_get_global_queue(priority, 0), block);
}

COCOA_EXTENSIONS_INLINE
void XRPerformBlockSynchronouslyOnGlobalQueue(DISPATCH_NOESCAPE dispatch_block_t block)
{
	XRPerformBlockSynchronouslyOnGlobalQueueWithPriority(block, DISPATCH_QUEUE_PRIORITY_DEFAULT);
}

COCOA_EXTENSIONS_INLINE
void XRPerformBlockAsynchronouslyOnGlobalQueueWithPriority(dispatch_block_t block, dispatch_queue_priority_t priority)
{
	XRPerformBlockAsynchronouslyOnQueue(dispatch_get_global_queue(priority, 0), block);
}

COCOA_EXTENSIONS_INLINE
void XRPerformBlockAsynchronouslyOnGlobalQueue(dispatch_block_t block)
{
	XRPerformBlockAsynchronouslyOnGlobalQueueWithPriority(block, DISPATCH_QUEUE_PRIORITY_DEFAULT);
}

COCOA_EXTENSIONS_EXTERN dispatch_queue_t XRCreateDispatchQueue(const char *label, dispatch_queue_attr_t attributes);
COCOA_EXTENSIONS_EXTERN dispatch_queue_t XRCreateDispatchQueueWithPriority(const char *label, dispatch_queue_attr_t attributes, dispatch_qos_class_t priority);

COCOA_EXTENSIONS_EXTERN dispatch_source_t _Nullable XRScheduleBlockOnGlobalQueue(dispatch_block_t block, NSTimeInterval delay);
COCOA_EXTENSIONS_EXTERN dispatch_source_t _Nullable XRScheduleBlockOnGlobalQueueWithPriority(dispatch_block_t block, NSTimeInterval delay, dispatch_queue_priority_t priority);
COCOA_EXTENSIONS_EXTERN dispatch_source_t _Nullable XRScheduleBlockOnMainQueue(dispatch_block_t block, NSTimeInterval delay);
COCOA_EXTENSIONS_EXTERN dispatch_source_t _Nullable XRScheduleBlockOnQueue(dispatch_queue_t queue, dispatch_block_t block, NSTimeInterval delay, BOOL repeat);

COCOA_EXTENSIONS_EXTERN void XRResumeScheduledBlock(dispatch_source_t blockSource);
COCOA_EXTENSIONS_EXTERN void XRCancelScheduledBlock(dispatch_source_t blockSource);

COCOA_EXTENSIONS_EXTERN void XRPerformDelayedBlockOnGlobalQueue(dispatch_block_t block, NSTimeInterval delay);
COCOA_EXTENSIONS_EXTERN void XRPerformDelayedBlockOnGlobalQueueWithPriority(dispatch_block_t block, NSTimeInterval delay, dispatch_queue_priority_t priority);
COCOA_EXTENSIONS_EXTERN void XRPerformDelayedBlockOnMainQueue(dispatch_block_t block, NSTimeInterval delay);

COCOA_EXTENSIONS_EXTERN void XRPerformDelayedBlockOnQueue(dispatch_queue_t queue, dispatch_block_t block, NSTimeInterval delay);

#pragma mark -
#pragma mark Swizzling

COCOA_EXTENSIONS_EXTERN void XRExchangeInstanceMethod(NSString *className, NSString *originalMethod, NSString *replacementMethod);
COCOA_EXTENSIONS_EXTERN void XRExchangeClassMethod(NSString *className, NSString *originalMethod, NSString *replacementMethod);

NS_ASSUME_NONNULL_END
