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

#import "IRCChannel.h"
#import "IRCUserRelationsPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCUserRelations ()
@property (nonatomic, strong, nullable) NSMutableDictionary<IRCChannel *, IRCChannelUser *> *relationsPrivate;
@end

@implementation IRCUserRelations

- (NSDictionary<IRCChannel *, IRCChannelUser *> *)relations
{
	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return @{};
		}

		return [self.relationsPrivate copy];
	}
}

- (NSArray<IRCChannel *> *)relatedChannels
{
	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return @[];
		}

		return self.relationsPrivate.allKeys;
	}
}

- (NSArray<IRCChannelUser *> *)relatedUsers
{
	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return @[];
		}

		return self.relationsPrivate.allValues;
	}
}

- (void)enumerateRelations:(void (NS_NOESCAPE ^)(IRCChannel *channel, IRCChannelUser *member, BOOL *stop))block
{
	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return;
		}

		[self.relationsPrivate enumerateKeysAndObjectsUsingBlock:block];
	}
}

- (NSUInteger)numberOfRelations
{
	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return 0;
		}

		return self.relationsPrivate.count;
	}
}

- (void)associateUser:(IRCChannelUser *)user withChannel:(IRCChannel *)channel
{
	NSParameterAssert(user != nil);
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO) {
		return;
	}

	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			self.relationsPrivate = [NSMutableDictionary dictionary];
		}

		/* IRCChannel does not really support copying. It returns self.
		 The protocol is declared here in a cast, instead of in the
		 header for IRCChannel, so plugin author's don't make a mistake. */
		self.relationsPrivate[(IRCChannel <NSCopying> *)channel] = user;
	}
}

- (void)disassociateUserWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO) {
		return;
	}

	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return;
		}

		[self.relationsPrivate removeObjectForKey:channel];

		if (self.relationsPrivate.count == 0) {
			self.relationsPrivate = nil;
		}
	}
}

- (nullable IRCChannelUser *)userAssociatedWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if (channel.isChannel == NO) {
		return nil;
	}

	@synchronized (self.relationsPrivate) {
		if (self.relationsPrivate == nil) {
			return nil;
		}

		return self.relationsPrivate[channel];
	}
}

@end

NS_ASSUME_NONNULL_END
