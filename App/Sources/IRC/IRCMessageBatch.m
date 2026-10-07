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

#import "IRCMessage.h"
#import "IRCMessageBatchPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCMessageBatchMessageContainer ()
@property (nonatomic, strong) NSMutableDictionary *internalBatchEntries;
@end

@interface IRCMessageBatchMessage ()
@property (nonatomic, strong) NSMutableArray *internalBatchEntries;
@end

#pragma mark -

@implementation IRCMessageBatchMessageContainer

- (NSDictionary *)queuedEntries
{
	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return @{};
		}

		return [self.internalBatchEntries copy];
	}
}

- (void)dequeueEntries
{
	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return;
		}

		[self.internalBatchEntries removeAllObjects];
	}
}

- (void)dequeueEntry:(id)entry
{
	NSParameterAssert(entry != nil);

	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return;
		}

		NSString *batchToken = nil;

		if ([entry isKindOfClass:[IRCMessageBatchMessage class]]) {
			batchToken = [entry batchToken];
		} else if ([entry isKindOfClass:[NSString class]]) {
			batchToken = entry;

			entry = self.internalBatchEntries[batchToken];
		}

		if (batchToken == nil) {
			return;
		}

		[entry dequeueEntries];

		[self.internalBatchEntries removeObjectForKey:batchToken];
	}
}

- (void)queueEntry:(id)entry
{
	NSParameterAssert(entry != nil);

	if ([entry isKindOfClass:[IRCMessageBatchMessage class]] == NO) {
		return;
	}

	NSString *batchToken = [entry batchToken];

	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			self.internalBatchEntries = [NSMutableDictionary dictionary];
		}

		self.internalBatchEntries[batchToken] = entry;
	}
}

- (id)queuedEntryWithBatchToken:(NSString *)batchToken
{
	NSParameterAssert(batchToken != nil);

	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return nil;
		}

		return self.internalBatchEntries[batchToken];
	}
}

@end

#pragma mark -

@implementation IRCMessageBatchMessage

- (NSArray *)queuedEntries
{
	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return @[];
		}

		return [self.internalBatchEntries copy];
	}
}

- (void)dequeueEntries
{
	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return;
		}

		[self.internalBatchEntries removeAllObjects];
	}
}

- (void)queueEntry:(id)entry
{
	NSParameterAssert(entry != nil);

	if ([entry isKindOfClass:[IRCMessage class]] == NO &&
		[entry isKindOfClass:[IRCMessageBatchMessage class]] == NO)
	{
		return;
	}

	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			self.internalBatchEntries = [NSMutableArray array];
		}

		[self.internalBatchEntries addObject:entry];
	}
}

- (void)dequeueEntry:(id)entry
{
	NSParameterAssert(entry != nil);

	if ([entry isKindOfClass:[IRCMessage class]] == NO &&
		[entry isKindOfClass:[IRCMessageBatchMessage class]] == NO)
	{
		return;
	}

	@synchronized(self.internalBatchEntries) {
		if (self.internalBatchEntries == nil) {
			return;
		}

		[self.internalBatchEntries removeObject:entry];
	}
}

@end

NS_ASSUME_NONNULL_END
