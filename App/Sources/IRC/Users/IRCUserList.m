/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "IRCISupportInfo.h"
#import "IRCUserPrivate.h"
#import "TLOTimer.h"
#import "IRCUserListPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* A user in no channel is forgotten after five minutes (checked every minute) */
#define _unusedUserLifetime			(60 * 5)
#define _expiryCheckInterval		60

@interface IRCUserList ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IRCUser *> *usersByKey;
@property (nonatomic, strong) TLOTimer *expiryTimer;
@end

@implementation IRCUserList

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;

		self.usersByKey = [NSMutableDictionary dictionary];

		__weak IRCUserList *weakSelf = self;

		self.expiryTimer =
		[TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
			[weakSelf removeUsersUnusedFor:_unusedUserLifetime];
		}];

		[self.expiryTimer start:_expiryCheckInterval onRepeat:YES];
	}

	return self;
}

- (void)dealloc
{
	[self stopExpiryTimer];
}

- (void)stopExpiryTimer
{
	[self.expiryTimer stop];
}

- (NSString *)keyForNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCClient *client = self.client;

	if (client == nil) {
		return nickname.lowercaseString;
	}

	return [client.supportInfo foldedString:nickname];
}

- (NSUInteger)count
{
	@synchronized (self.usersByKey) {
		return self.usersByKey.count;
	}
}

- (NSArray<IRCUser *> *)users
{
	@synchronized (self.usersByKey) {
		return self.usersByKey.allValues;
	}
}

- (nullable IRCUser *)userWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	NSString *key = [self keyForNickname:nickname];

	@synchronized (self.usersByKey) {
		return self.usersByKey[key];
	}
}

- (void)setUser:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	NSString *key = [self keyForNickname:user.nickname];

	@synchronized (self.usersByKey) {
		self.usersByKey[key] = user;
	}
}

- (void)removeUserWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	NSString *key = [self keyForNickname:nickname];

	@synchronized (self.usersByKey) {
		[self.usersByKey removeObjectForKey:key];
	}
}

- (void)removeAllUsers
{
	@synchronized (self.usersByKey) {
		[self.usersByKey removeAllObjects];
	}
}

- (void)removeUsersUnusedFor:(NSTimeInterval)interval
{
	IRCClient *client = self.client;

	if (client == nil) {
		return;
	}

	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

	for (IRCUser *user in self.users) {
		CFAbsoluteTime unusedSince = user.unusedSince;

		if (unusedSince == 0 || (now - unusedSince) < interval) {
			continue;
		}

		/* Someone you have a private message with stays known (R3.19: their
		 address and away state were lost after five minutes) */
		IRCChannel *privateMessage = [client findChannel:user.nickname];

		if (privateMessage.isPrivateMessage) {
			continue;
		}

		[client removeUser:user];
	}
}

@end

NS_ASSUME_NONNULL_END
