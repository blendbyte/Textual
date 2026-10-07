/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *      Please see Acknowledgements.pdf for additional information.
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

#import <objc/message.h>
#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCResourceManager.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOPluginManagerPrivate.h"
#import "THOPluginProtocol.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOpenLink.h"
#import "TLOSoundPlayer.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TLOSpokenNotificationPrivate.h"
#import "TLOTimer.h"
#import "TXGlobalModelsPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "TXWindowControllerPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCLogControllerOperationQueuePrivate.h"
#import "TVCLogRenderer.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelBanListSheetPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "IRC.h"
#import "IRCAddressBook.h"
#import "IRCAddressBookMatchCachePrivate.h"
#import "IRCAddressBookUserTrackingPrivate.h"
#import "IRCChannelConfig.h"
#import "IRCChannelModePrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientRequestedCommandsPrivate.h"
#import "IRCColorFormatPrivate.h"
#import "IRCConnectionPrivate.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCExtrasPrivate.h"
#import "IRCHighlightLogEntryPrivate.h"
#import "IRCHighlightMatchCondition.h"
#import "IRCISupportInfoPrivate.h"
#import "IRCMessagePrivate.h"
#import "IRCMessageBatchPrivate.h"
#import "IRCModeInfo.h"
#import "IRCPrefix.h"
#import "IRCNumerics.h"
#import "IRCSendingMessage.h"
#import "IRCServerPrivate.h"
#import "IRCTimedCommandPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCClientInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCClient (Users)

#pragma mark -
#pragma mark Address Book

- (NSArray<IRCAddressBookEntry *> *)findIgnoresForHostmask:(NSString *)hostmask
{
	return [self.addressBookMatchCache findIgnoresForHostmask:hostmask];
}

- (nullable IRCAddressBookEntry *)findUserTrackingAddressBookEntryForHostmask:(NSString *)hostmask
{
	/* We chop off the nickname from the host and only use that in the
	 matching to keep everything a little more consistent internally. */
	NSString *nickname = hostmask.nicknameFromHostmask;
	
	if (nickname == nil) {
		return nil;
	}
	
	return [self findUserTrackingAddressBookEntryForNickname:nickname];
}

- (nullable IRCAddressBookEntry *)findUserTrackingAddressBookEntryForNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	NSString *hostmask = [NSString stringWithFormat:@"%@!*@*", nickname];
	
	return [self findAddressBookEntryForHostmask:hostmask];
}

- (nullable IRCAddressBookEntry *)findAddressBookEntryForHostmask:(NSString *)hostmask
{
	return [self.addressBookMatchCache findAddressBookEntryForHostmask:hostmask];
}

- (void)clearAddressBookCache
{
	[self.addressBookMatchCache clearCachedMatches];
}

- (void)clearAddressBookCacheForHostmask:(NSString *)hostmask
{
	/* Clear host */
	[self.addressBookMatchCache clearCachedMatchesForHostmask:hostmask];

	/* Clear nickname */
	NSString *nickname = hostmask.nicknameFromHostmask;

	NSString *nicknameHostmask = [NSString stringWithFormat:@"%@!*@*", nickname];
	
	[self.addressBookMatchCache clearCachedMatchesForHostmask:nicknameHostmask];
}

#pragma mark -
#pragma mark User List 

- (BOOL)userExists:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	return ([self findUser:nickname] != nil);
}

- (nullable IRCUser *)findUser:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	nickname = nickname.lowercaseString;

	@synchronized (self.userListPrivate) {
		return self.userListPrivate[nickname];
	}
}

- (IRCUserMutable *)mutableCopyOfUserWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCUser *user = [self findUser:nickname];

	if (user == nil) {
		return [[IRCUserMutable alloc] initWithNickname:nickname onClient:self];
	} else {
		return [user mutableCopy];
	}
}

- (void)addUser:(IRCUser *)user
{
	[self addUserAndReturn:user];
}

- (IRCUser *)addUserAndReturn:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	if ([user isKindOfClass:[IRCUserMutable class]]) {
		user = [user copy];
	}

	NSString *nickname = user.lowercaseNickname;

	@synchronized (self.userListPrivate) {
		self.userListPrivate[nickname] = user;
	}

	[user becamePrimaryUser];

	return user;
}

- (IRCUser *)findUserOrCreate:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	IRCUser *user = [self findUser:nickname];

	if (user == nil) {
		user = [[IRCUser alloc] initWithNickname:nickname onClient:self];

		[self addUser:user];
	}

	return user;
}

- (void)removeUser:(IRCUser *)user
{
	NSParameterAssert(user != nil);

	[user cancelRemoveUserTimer];
	
	NSString *hostmask = user.hostmask;

	if (hostmask) {
		[self clearAddressBookCacheForHostmask:hostmask];
	}

	[self removeUserWithNickname:user.nickname];
}

- (void)removeUserWithNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	nickname = nickname.lowercaseString;

	@synchronized (self.userListPrivate) {
		[self.userListPrivate removeObjectForKey:nickname];
	}
}

- (void)renameUser:(IRCUser *)user to:(NSString *)toNickname
{
	NSParameterAssert(user != nil);
	NSParameterAssert(toNickname != nil);

	[self modifyUser:user withBlock:^(IRCUserMutable *userMutable) {
		userMutable.nickname = toNickname;
	}];
}

- (void)renameUserWithNickname:(NSString *)fromNickname to:(NSString *)toNickname
{
	NSParameterAssert(fromNickname != nil);
	NSParameterAssert(toNickname != nil);

	IRCUser *user = [self findUser:fromNickname];

	if (user == nil) {
		return;
	}

	[self renameUser:user to:toNickname];
}

- (void)modifyUser:(IRCUser *)user withBlock:(void(NS_NOESCAPE ^)(IRCUserMutable *userMutable))block
{
	NSParameterAssert(user != nil);
	NSParameterAssert(block != nil);

	IRCUserMutable *userMutable = [user mutableCopy];

	block(userMutable);

	if ([user.nickname isEqualToString:userMutable.nickname] == NO) {
		[self removeUser:user];
	}

	[self addUser:userMutable];
}

- (void)modifyUserUserWithNickname:(NSString *)nickname withBlock:(void(NS_NOESCAPE ^)(IRCUserMutable *userMutable))block
{
	NSParameterAssert(nickname != nil);
	NSParameterAssert(block != nil);

	IRCUser *user = [self findUser:nickname];

	if (user == nil) {
		return;
	}

	[self modifyUser:user withBlock:block];
}

- (void)modifyUserWithNickname:(NSString *)nickname asAway:(BOOL)away
{
	NSParameterAssert(nickname != nil);
	
	IRCUser *user = [self findUser:nickname];
	
	if (user == nil) {
		return;
	}

	[self modifyUser:user asAway:away];
}

- (void)modifyUser:(IRCUser *)user asAway:(BOOL)away
{
	NSParameterAssert(user != nil);
	
	if (self.monitorAwayStatus == NO) {
		return;
	}

	if (away) {
		[user markAsAway];
	} else {
		[user markAsReturned];
	}
	
	[mainWindow() updateDrawingForUserInUserList:user];
}

- (void)resetAwayStatusForUsers
{
	[self.userList makeObjectsPerformSelector:@selector(markAsReturned)];
}

@end

NS_ASSUME_NONNULL_END
