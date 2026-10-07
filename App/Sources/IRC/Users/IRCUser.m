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

#import "NSObjectHelperPrivate.h"
#import "TPCPreferencesLocal.h"
#import "IRCClient.h"
#import "IRCUserPersistentStorePrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCUserInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* IRCUser has an internal timer that is started when relations reach zero.
 This timer runs for five minutes, using a GCD timer. When the timer fires,
 it removes the user from the client, thus remove any trace of it. */
#define _removeUserTimerInterval					(60 * 5) // 5 minutes

#define _presentAwayMessageFor301Threshold			300.0

@interface IRCUser ()
@property (nonatomic, weak, readwrite) IRCClient *client;
@property (nonatomic, strong) IRCUserPersistentStore *persistentStore;
@property (readonly) IRCUserRelations *relationsInt;
@end

@implementation IRCUser

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithNickname:(NSString *)nickname onClient:(IRCClient *)client
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self->_nickname = [nickname copy];

		self.client = client;

		[self createNewPersistentStoreObject];
	}

	return self;
}

- (void)createNewPersistentStoreObject
{
	self.persistentStore = [IRCUserPersistentStore new];

	self.persistentStore.relations = [IRCUserRelations new];
}

- (void)dealloc
{
	[self cancelRemoveUserTimer];
}

- (IRCUserRelations *)relationsInt
{
	return self.persistentStore.relations;
}

- (void)markAsAway
{
	[self setIsAway:YES];
}

- (void)markAsReturned
{
	[self setIsAway:NO];
}

- (void)setIsAway:(BOOL)isAway
{
	if (self->_isAway != isAway) {
		self->_isAway = isAway;
	}
}

- (BOOL)presentAwayMessageFor301
{
	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

	if ((self.persistentStore.presentAwayMessageFor301LastEvent + _presentAwayMessageFor301Threshold) < now) {
		 self.persistentStore.presentAwayMessageFor301LastEvent = now;

		return YES;
	}

	return NO;
}

- (nullable NSString *)hostmaskFragment
{
	NSString *username = self.username;
	NSString *address = self.address;

	if (username == nil || address == nil) {
		return nil;
	}

	return [NSString stringWithFormat:@"%@@%@", username, address];
}

- (nullable NSString *)hostmask
{
	NSString *nickname = self.nickname;
	NSString *username = self.username;
	NSString *address = self.address;

	if (username == nil || address == nil) {
		return nil;
	}

	return [NSString stringWithFormat:@"%@!%@@%@", nickname, username, address];
}

- (NSString *)banMask
{
	NSString *nickname = self.nickname;
	NSString *username = self.username;
	NSString *address = self.address;

	if (username == nil || address == nil) {
		return [NSString stringWithFormat:@"%@!*@*", nickname];
	}

	switch ([TPCPreferences banFormat]) {
		case TXHostmaskBanFormatWHNIN:
		{
			return [NSString stringWithFormat:@"*!*@%@", address];
		}
		case TXHostmaskBanFormatWHAINN:
		{
			return [NSString stringWithFormat:@"*!%@@%@", username, address];
		}
		case TXHostmaskBanFormatWHANNI:
		{
			return [NSString stringWithFormat:@"%@!*%@", nickname, address];
		}
		case TXHostmaskBanFormatExact:
		{
			return [NSString stringWithFormat:@"%@!%@@%@", nickname, username, address];
		}
	}

	return nil;
}

- (NSString *)lowercaseNickname
{
	return self.nickname.lowercaseString;
}

- (NSString *)uppercaseNickname
{
	return self.nickname.uppercaseString;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<IRCUser %@>", self.nickname];
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[IRCUser class]] == NO) {
		return NO;
	}

	IRCUser *objectCast = (IRCUser *)object;

	return (self.client == objectCast.client &&

			((self.nickname == nil && objectCast.nickname == nil) ||
			 [self.nickname isEqualToString:objectCast.nickname]) &&

			((self.username == nil && objectCast.username == nil) ||
			 [self.username isEqualToString:objectCast.username]) &&

			((self.address == nil && objectCast.address == nil) ||
			 [self.address isEqualToString:objectCast.address]) &&

			((self.realName == nil && objectCast.realName == nil) ||
			 [self.realName isEqualToString:objectCast.realName]) &&

			self.isAway == objectCast.isAway &&
			self.isIRCop == objectCast.isIRCop);
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCUser *object = [self allocForCopyAsMutable:mutableCopy];

	object->_client = self->_client;

	object->_persistentStore = self->_persistentStore;

	object->_nickname = self->_nickname;
	object->_username = self->_username;
	object->_address = self->_address;

	object->_realName = self->_realName;

	object->_isAway = self->_isAway;
	object->_isIRCop = self->_isIRCop;

	return [object initOnCopy];
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [IRCUserMutable self];
}

- (void)updateRemoveUserTimerBlockToFire
{
	/* If the timer is already active, we reset the block that is scheduled
	 so that the user that is targeted is always the primary */
	dispatch_source_t removeUserTimer = self.persistentStore.removeUserTimer;

	if (removeUserTimer == nil) {
		return;
	}

	dispatch_block_t blockToFire = [self removeUserTimerBlockToFire];

	dispatch_source_set_event_handler(removeUserTimer, blockToFire);
}

- (void)toggleRemoveUserTimer
{
	if (self.relationsInt.numberOfRelations > 0) {
		[self cancelRemoveUserTimer];
	} else {
		[self startRemoveUserTimer];
	}
}

- (void)startRemoveUserTimer
{
	dispatch_source_t removeUserTimer = self.persistentStore.removeUserTimer;

	if (removeUserTimer != NULL) {
		return;
	}

	dispatch_block_t blockToFire = [self removeUserTimerBlockToFire];

	removeUserTimer = XRScheduleBlockOnGlobalQueue(blockToFire, _removeUserTimerInterval);

	XRResumeScheduledBlock(removeUserTimer);

	if (removeUserTimer == NULL) {
		LogToConsoleFault("Failed to create timer to remove user");

		blockToFire(); // Remove user if timer isn't available

		return;
	}

	self.persistentStore.removeUserTimer = removeUserTimer;
}

- (void)cancelRemoveUserTimer
{
	dispatch_source_t removeUserTimer = self.persistentStore.removeUserTimer;

	if (removeUserTimer == nil) {
		return;
	}

	XRCancelScheduledBlock(removeUserTimer);

	self.persistentStore.removeUserTimer = nil;
}

- (dispatch_block_t)removeUserTimerBlockToFire
{
	/* Using weak references means that the object can be deallocated when 
	 the timer is active. -dealloc will cancel the timer if it is active. */

	__weak IRCClient *client = self.client;

	__weak IRCUser *user = self;

	return [^{
		[client removeUser:user];
	} copy];
}

@end

#pragma mark -

@implementation IRCUser (IRCUserRelationsPrivate)

- (void)associateUser:(IRCChannelUser *)user withChannel:(IRCChannel *)channel
{
	[self.relationsInt associateUser:user withChannel:channel];

	[self toggleRemoveUserTimer];
}

- (void)disassociateUserWithChannel:(IRCChannel *)channel
{
	[self.relationsInt disassociateUserWithChannel:channel];

	[self toggleRemoveUserTimer];
}

- (nullable IRCChannelUser *)userAssociatedWithChannel:(IRCChannel *)channel
{
	return [self.relationsInt userAssociatedWithChannel:channel];
}

- (void)relinkRelations
{
	NSArray *relatedUsers = self.relationsInt.relatedUsers;

	[relatedUsers makeObjectsPerformSelector:@selector(changeUserToUser:) withObject:self];
}

- (void)becamePrimaryUser
{
	[self updateRemoveUserTimerBlockToFire];

	[self relinkRelations];
}

- (void)enumerateRelations:(void (NS_NOESCAPE ^)(IRCChannel *channel, IRCChannelUser *member, BOOL *stop))block
{
	[self.relationsInt enumerateRelations:block];
}

@end

#pragma mark -

@implementation IRCUser (IRCUserRelations)

- (NSDictionary<IRCChannel *, IRCChannelUser *> *)relations
{
	return self.relationsInt.relations;
}

@end

#pragma mark -

@implementation IRCUserMutable

@dynamic nickname;
@dynamic username;
@dynamic address;
@dynamic realName;
@dynamic isAway;
@dynamic isIRCop;

- (instancetype)initWithClient:(IRCClient *)client
{
	return [self initWithNickname:@"" onClient:client];
}

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [IRCUser self];
}

- (void)setNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self->_nickname	!= nickname) {
		self->_nickname = [nickname copy];
	}
}

- (void)setUsername:(nullable NSString *)username
{
	if (self->_username != username) {
		self->_username = [username copy];
	}
}

- (void)setAddress:(nullable NSString *)address
{
	if (self->_address != address) {
		self->_address = [address copy];
	}
}

- (void)setRealName:(nullable NSString *)realName
{
	if (self->_realName != realName) {
		self->_realName = [realName copy];
	}
}

- (void)setIsAway:(BOOL)isAway
{
	if (self->_isAway != isAway) {
		self->_isAway = isAway;
	}
}

- (void)setIsIRCop:(BOOL)isIRCop
{
	if (self->_isIRCop != isIRCop) {
		self->_isIRCop = isIRCop;
	}
}

@end

NS_ASSUME_NONNULL_END
