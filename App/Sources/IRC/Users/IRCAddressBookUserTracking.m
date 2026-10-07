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

#import "IRCClient.h"
#import "IRCAddressBookUserTracking.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCAddressBookUserTrackingStatusChangedNotification = @"IRCAddressBookUserTrackingStatusChangedNotification";

NSString * const IRCAddressBookUserTrackingAddedTrackedUserNotification = @"IRCAddressBookUserTrackingAddedTrackedUserNotification";

NSString * const IRCAddressBookUserTrackingRemovedTrackedUserNotification = @"IRCAddressBookUserTrackingRemovedTrackedUserNotification";
NSString * const IRCAddressBookUserTrackingRemovedAllTrackedUsersNotification = @"IRCAddressBookUserTrackingRemovedAllTrackedUsersNotification";

@interface IRCAddressBookUserTrackingContainer ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *trackedUsersInt;
@end

@implementation IRCAddressBookUserTrackingContainer

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.trackedUsersInt = [NSMutableDictionary dictionary];
}

- (void)addTrackedUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	@synchronized (self.trackedUsersInt) {
		NSString *trackingNickname = [self.trackedUsersInt keyIgnoringCase:nickname];

		if (trackingNickname != nil) {
			return;
		}

		[self _addTrackedUser:nickname];
	}
}

- (void)_addTrackedUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	@synchronized (self.trackedUsersInt) {
		self.trackedUsersInt[nickname] = @(NO);

		[RZNotificationCenter() postNotificationName:IRCAddressBookUserTrackingAddedTrackedUserNotification
											  object:self
											userInfo:@{@"nickname" : nickname}];
	}
}

- (void)removeTrackedUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	@synchronized (self.trackedUsersInt) {
		NSString *trackingNickname = [self.trackedUsersInt keyIgnoringCase:nickname];

		if (trackingNickname == nil) {
			return;
		}

		[self _removeTrackedUser:trackingNickname];
	}
}

- (void)_removeTrackedUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	@synchronized (self.trackedUsersInt) {
		[self.trackedUsersInt removeObjectForKey:nickname];

		[RZNotificationCenter() postNotificationName:IRCAddressBookUserTrackingRemovedTrackedUserNotification
											  object:self
											userInfo:@{@"nickname" : nickname}];
	}
}

- (void)clearTrackedUsers
{
	@synchronized (self.trackedUsersInt) {
		[self.trackedUsersInt removeAllObjects];

		[RZNotificationCenter() postNotificationName:IRCAddressBookUserTrackingRemovedAllTrackedUsersNotification
											  object:self];
	}
}

- (IRCAddressBookUserTrackingStatus)statusOfUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	@synchronized (self.trackedUsersInt) {
		NSString *trackingNickname = [self.trackedUsersInt keyIgnoringCase:nickname];

		if (trackingNickname == nil) {
			return IRCAddressBookUserTrackingStatusUnknown;
		}

		return [self _statusOfUser:nickname];
	}
}

- (IRCAddressBookUserTrackingStatus)_statusOfUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	@synchronized (self.trackedUsersInt) {
		BOOL ison = self.trackedUsersInt[nickname].boolValue;

		if (ison) {
			return IRCAddressBookUserTrackingStatusAvailable;
		} else {
			return IRCAddressBookUserTrackingStatusNotAvailable;
		}
	}
}

- (IRCAddressBookUserTrackingStatus)statusOfEntry:(IRCAddressBookEntry *)addressBookEntry
{
	NSParameterAssert(addressBookEntry != nil);

	NSString *trackingNickname = addressBookEntry.trackingNickname;

	if (trackingNickname == nil) {
		return IRCAddressBookUserTrackingStatusUnknown;
	}

	return [self statusOfUser:trackingNickname];
}

- (NSDictionary<NSString *, NSNumber *> *)trackedUsers
{
	@synchronized (self.trackedUsersInt) {
		return [self.trackedUsersInt copy];
	}
}

- (void)statusOfTrackedNickname:(NSString *)nickname changedTo:(IRCAddressBookUserTrackingStatus)newStatus
{
	NSParameterAssert(nickname != nil);

	if (newStatus == IRCAddressBookUserTrackingStatusUnknown) {
		return;
	}

	@synchronized (self.trackedUsersInt) {
		NSString *trackingNickname = [self.trackedUsersInt keyIgnoringCase:nickname];

		if (newStatus == IRCAddressBookUserTrackingStatusAvailable ||
			newStatus == IRCAddressBookUserTrackingStatusSignedOn)
		{
			if (trackingNickname == nil) {
				trackingNickname = nickname;
			}

			self.trackedUsersInt[trackingNickname] = @(YES);
		}
		else if (newStatus == IRCAddressBookUserTrackingStatusNotAvailable ||
				 newStatus == IRCAddressBookUserTrackingStatusSignedOff)
		{
			if (trackingNickname == nil) {
				return;
			}

			self.trackedUsersInt[trackingNickname] = @(NO);
		}
		else if (newStatus == IRCAddressBookUserTrackingStatusNotAway ||
				 newStatus == IRCAddressBookUserTrackingStatusAway)
		{
			if (trackingNickname == nil) {
				return;
			}
		}

		[RZNotificationCenter() postNotificationName:IRCAddressBookUserTrackingStatusChangedNotification
											  object:self
											userInfo:@{@"nickname" : nickname,
													   @"status" : @(newStatus)}];
	}
}

@end

NS_ASSUME_NONNULL_END
