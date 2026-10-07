/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#include <objc/message.h>

#import "NSObjectHelperPrivate.h"
#import "TXMasterController.h"
#import "TXWindowControllerPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMemberListAppearance.h"
#import "TVCMemberListPrivate.h"
#import "TVCMemberListCellPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TDCSharedProtocolDefinitionsPrivate.h"
#import "TDCSheetBase.h"
#import "TPCPreferencesLocal.h"
#import "TLOFileLoggerPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "IRCClientPrivate.h"
#import "IRCChannelConfigPrivate.h"
#import "IRCChannelModePrivate.h"
#import "IRCChannelMemberListPrivate.h"
#import "IRCChannelUserPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUser.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "IRCChannelPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCChannelConfigurationWasUpdatedNotification = @"IRCChannelConfigurationWasUpdatedNotification";

@interface IRCChannel ()
@property (readonly) BOOL isSelectedChannel;
@property (nonatomic, assign) BOOL statusChangedByAction;
@property (nonatomic, copy, readwrite) IRCChannelConfig *config;
@property (nonatomic, assign, readwrite) NSTimeInterval channelJoinTime;
@property (nonatomic, strong, readwrite, nullable) IRCChannelMode *modeInfo;
@property (nonatomic, strong, readwrite, nullable) IRCChannelMemberList *memberInfo;
@property (nonatomic, strong, nullable) TLOFileLogger *logFile;
@property (nonatomic, assign, readwrite) NSUInteger logFileSessionCount;
@end

@implementation IRCChannel

@synthesize associatedClient = _associatedClient;

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithConfigDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	IRCChannelConfig *config = [[IRCChannelConfig alloc] initWithDictionary:dic];

	return [self initWithConfig:config];
}

- (instancetype)initWithConfig:(IRCChannelConfig *)config
{
	if ((self = [super init])) {
		self.config = config;

		[self.config writeSecretKeyToKeychain];
	}

	return self;
}

- (void)updateConfig:(IRCChannelConfig *)config
{
	[self updateConfig:config fireChangedNotification:YES updateStoredChannelList:YES];
}

- (void)updateConfig:(IRCChannelConfig *)config fireChangedNotification:(BOOL)fireChangedNotification
{
	[self updateConfig:config fireChangedNotification:fireChangedNotification updateStoredChannelList:YES];
}

- (void)updateConfig:(IRCChannelConfig *)config fireChangedNotification:(BOOL)fireChangedNotification updateStoredChannelList:(BOOL)updateStoredChannelList
{
	NSParameterAssert(config != nil);

	IRCChannelConfig *currentConfig = self.config;

	if ([config isEqual:currentConfig]) {
		return;
	}

	if (currentConfig.type != config.type ||
		[currentConfig.channelName isEqualToString:config.channelName] == NO ||
		[currentConfig.uniqueIdentifier isEqualToString:config.uniqueIdentifier] == NO)
	{
		LogToConsoleError("Tried to load configuration for incorrect channel");

		return;
	}

	self.config = config;

	[self.config writeSecretKeyToKeychain];

	if (updateStoredChannelList) {
		[self.associatedClient updateStoredChannelList];
	}

	if (fireChangedNotification) {
		[RZNotificationCenter() postNotificationName:IRCChannelConfigurationWasUpdatedNotification object:self];
	}
}

- (NSDictionary<NSString *, id> *)configurationDictionary
{
	return [self.config dictionaryValue];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	/* Implement this method to allow channel to be 
	 used as a dictionary key. */

	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<IRCChannel [%@]: %@>", self.associatedClient.description, self.name];
}

#pragma mark -
#pragma mark Property Getter

- (NSString *)uniqueIdentifier
{
	return self.config.uniqueIdentifier;
}

- (NSString *)name
{
	return self.config.channelName;
}

- (nullable NSString *)secretKey
{
	return self.config.secretKey;
}

- (BOOL)autoJoin
{
	return self.config.autoJoin;
}

- (BOOL)isChannel
{
	return (self.config.type == IRCChannelTypeChannel);
}

- (BOOL)isPrivateMessage
{
	return (self.config.type == IRCChannelTypePrivateMessage);
}

- (BOOL)isUtility
{
	return (self.config.type == IRCChannelTypeUtility);
}

- (BOOL)isPrivateMessageForZNCUser
{
	if (self.isPrivateMessage == NO) {
		return NO;
	}

	IRCClient *client = self.associatedClient;

	return [client nicknameIsZNCUser:self.name];
}

- (IRCChannelType)type
{
	return self.config.type;
}

- (NSString *)channelTypeString
{
	switch (self.config.type) {
		case IRCChannelTypeChannel:
		{
			return @"channel";
		}
		case IRCChannelTypePrivateMessage:
		{
			return @"query";
		}
		case IRCChannelTypeUtility:
		{
			return @"utility";
		}
	}
}

- (nullable NSURL *)logFilePath
{
	NSString *writePath = [TLOFileLogger writePathForItem:self];

	if (writePath == nil) {
		return nil;
	}

	return [NSURL fileURLWithPath:writePath];
}

- (nullable TVCLogLine *)lastLine
{
	return self.viewController.lastLine;
}

#pragma mark -
#pragma mark Property Setter

- (void)setAutoJoin:(BOOL)autoJoin
{
	if (self.isChannel == NO) {
		return;
	}

	if (self.autoJoin == autoJoin) {
		return;
	}

	IRCChannelConfigMutable *mutableConfig = [self.config mutableCopy];

	mutableConfig.autoJoin = autoJoin;

	self.config = mutableConfig;
}

- (void)setName:(NSString *)name
{
	NSParameterAssert(name != nil);

	if (self.isChannel) {
		return;
	}

	if ([self.name isEqualToString:name]) {
		return;
	}

	IRCChannelConfigMutable *mutableConfig = [self.config mutableCopy];

	mutableConfig.channelName = name;

	self.config = mutableConfig;
}

- (void)setTopic:(nullable NSString *)topic
{
	if (self->_topic != topic) {
		self->_topic = [topic copy];

		[self.viewController setTopic:self->_topic];
	}
}

#pragma mark -
#pragma mark Utilities

- (void)preferencesChanged
{
	if ([TPCPreferences displayPublicMessageCountOnDockBadge] == NO) {
		if (self.isChannel) {
			self.dockUnreadCount = 0;
		}
	}
}

#pragma mark -
#pragma mark Channel Status

- (void)setStatus:(IRCChannelStatus)status
{
	if (self->_status != status) {
		self->_status = status;

		[self performActionOnStatusChange];
	}
}

- (void)performActionOnStatusChange
{
	if (self.statusChangedByAction) {
		self.statusChangedByAction = NO;

		return;
	}

	if (self.status == IRCChannelStatusJoined) {
		[self activate];
	} else if (self.status == IRCChannelStatusParted) {
		[self deactivate];
	}
}

- (void)resetStatus:(IRCChannelStatus)toStatus
{
	if (toStatus == IRCChannelStatusJoining) {
		return;
	}

	self.channelModesReceived = NO;
	self.channelNamesReceived = NO;
	self.errorOnLastJoinAttempt = NO;
	self.sentInitialWhoRequest = NO;

	self.channelJoinTime = 0;

	self.modeInfo = nil;

	self.status = toStatus;

	self.topic = nil;

	/* Clearing members, instead of just declaring memberInfo nil,
	 is important so that all users can be properly disassociated
	 with this channel. There are many relations. */
	[self clearMembers];

	self.memberInfo = nil;
}

- (void)activate
{
	self.statusChangedByAction = YES;

	[self resetStatus:IRCChannelStatusJoined];

	IRCClient *client = self.associatedClient;

	if (self.isUtility == NO) {
		self.memberInfo = [[IRCChannelMemberList alloc] initWithChannel:self];

		/* A channel is only assigned by TVCMainWindow when it's switched to.
		 Because of that we have to assign it here as the user already has
		 the channel selected, but it was never assigned because the member
		 list did not exist up to this point. */
		if (self.isSelectedChannel) {
			[mainWindowMemberList() assignToChannel:self];
		}
	}

	if (self.isChannel) {
		[client postEventToViewController:@"channelJoined" forChannel:self];

		self.modeInfo = [[IRCChannelMode alloc] initWithChannel:self];
	}

	if (self.isPrivateMessage) {
		IRCUser *user1 = [self.associatedClient findUserOrCreate:self.name];

		[self addUser:user1];

		IRCUser *user2 = [self.associatedClient findUserOrCreate:client.userNickname];

		[self addUser:user2];
	}

	self.channelJoinTime = [NSDate timeIntervalSince1970];
}

- (void)deactivate
{
	self.statusChangedByAction = YES;

	[self resetStatus:IRCChannelStatusParted];

	if (self.isChannel) {
		[self.associatedClient postEventToViewController:@"channelParted" forChannel:self];
	}
}

- (void)prepareForPermanentDestruction
{
	self.statusChangedByAction = YES;

	[self resetStatus:IRCChannelStatusTerminated];

	[self closeLogFile];

	[self.config destroySecretKeyKeychainItem];

	NSArray *openWindows = [windowController()
							windowsFromWindowList:@[@"TDCChannelPropertiesSheet",
													@"TDCChannelModifyTopicSheet",
													@"TDCChannelModifyModesSheet",
													@"TDCChannelBanListSheet"]];

	for (TDCSheetBase <TDCChannelPrototype> *windowObject in openWindows) {
		if ([windowObject.channelId isEqualToString:self.uniqueIdentifier]) {
			[windowObject close];
		}
	}

	[[mainWindow() inputHistoryManager] destroy:self];

	[self.viewController prepareForPermanentDestruction];
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Preparing channel: <%{public}@>", self.uniqueIdentifier);

	self.statusChangedByAction = YES;

	LogToConsoleTerminationProgress("[%{public}@] Resetting status to terminated", self.uniqueIdentifier);

	[self resetStatus:IRCChannelStatusTerminated];

	LogToConsoleTerminationProgress("[%{public}@] Closing log file", self.uniqueIdentifier);

	[self closeLogFile];

	if (self.isPrivateMessage) {
		LogToConsoleTerminationProgress("[%{public}@] Destroying keychain items for private message", self.uniqueIdentifier);

		[self.config destroySecretKeyKeychainItem];
	}

	LogToConsoleTerminationProgress("[%{public}@] Preparing view controller: <%{public}@>", self.uniqueIdentifier, self.viewController.uniqueIdentifier);

	[self.viewController prepareForApplicationTermination];
}

#pragma mark -
#pragma mark Log File

- (void)reopenLogFileIfNeeded
{
	if ([TPCPreferences logToDiskIsEnabled] && self.isUtility == NO) {
		if ( self.logFile) {
			[self.logFile reopenIfNeeded];
		}
	} else {
		[self closeLogFile];
	}
}

- (void)closeLogFile
{
	if (self.logFile == nil) {
		return;
	}

	[self.logFile close];
}

- (void)logFileWriteSessionBegin
{
	[self.associatedClient logFileRecordSessionChanged:YES inChannel:self];
}

- (void)logFileWriteSessionEnd
{
	[self.associatedClient logFileRecordSessionChanged:NO inChannel:self];

	self.logFileSessionCount = 0;
}

#pragma mark -
#pragma mark Printing

- (void)writeToLogLineToLogFile:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	if (self.isUtility || [TPCPreferences logToDiskIsEnabled] == NO) {
		return;
	}

	// Perform addition before if statement to avoid infinite loop
	self.logFileSessionCount += 1;

	if (self.logFileSessionCount == 1) {
		[self logFileWriteSessionBegin];
	}

	if (self.logFile == nil) {
		self.logFile = [[TLOFileLogger alloc] initWithChannel:self];
	}

	[self.logFile writeLogLine:logLine];
}

- (void)print:(TVCLogLine *)logLine
{
	[self print:logLine completionBlock:nil];
}

- (void)print:(TVCLogLine *)logLine completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock
{
	NSParameterAssert(logLine != nil);

	[self.viewController print:logLine completionBlock:completionBlock];

	[self writeToLogLineToLogFile:logLine];
}

#pragma mark -
#pragma mark Member List

- (void)addUser:(IRCUser *)user
{
	[self.memberInfo addUser:user];
}

- (void)addMember:(IRCChannelUser *)member
{
	[self.memberInfo addMember:member];
}

- (void)addMember:(IRCChannelUser *)member checkForDuplicates:(BOOL)checkForDuplicates
{
	[self.memberInfo addMember:member checkForDuplicates:checkForDuplicates];
}

- (void)removeMemberWithNickname:(NSString *)nickname
{
	[self.memberInfo removeMemberWithNickname:nickname];
}

- (void)removeMember:(IRCChannelUser *)member
{
	[self.memberInfo removeMember:member];
}

- (void)resortMember:(IRCChannelUser *)member
{
	[self.memberInfo resortMember:member];
}

- (void)replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2
{
	[self.memberInfo replaceMember:member1 withMember:member2];
}

- (void)replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2 resort:(BOOL)resort
{
	[self.memberInfo replaceMember:member1 withMember:member2 resort:resort];
}

- (void)replaceMember:(IRCChannelUser *)member1 withMember:(IRCChannelUser *)member2 resort:(BOOL)resort replaceInAllChannels:(BOOL)replaceInAllChannels
{
	[self.memberInfo replaceMember:member1 withMember:member2 resort:resort replaceInAllChannels:replaceInAllChannels];
}

- (void)changeMember:(NSString *)nickname mode:(NSString *)mode value:(BOOL)value
{
	[self.memberInfo changeMember:nickname mode:mode value:value];
}

- (void)clearMembers
{
	[self.memberInfo clearMembers];
}

- (NSUInteger)numberOfMembers
{
	return self.memberInfo.numberOfMembers;
}

- (nullable NSArray<IRCChannelUser *> *)memberList
{
	return self.memberInfo.memberList;
}

- (NSData *)pasteboardDataForMembers:(NSArray<IRCChannelUser *> *)members
{
	return [self.memberInfo pasteboardDataForMembers:members];
}

+ (BOOL)readNicknamesFromPasteboardData:(NSData *)pasteboardData withBlock:(void (NS_NOESCAPE ^)(IRCChannel *channel, NSArray<NSString *> *nicknames))callbackBlock
{
	return [IRCChannelMemberList readNicknamesFromPasteboardData:pasteboardData withBlock:callbackBlock];
}

+ (BOOL)readMembersFromPasteboardData:(NSData *)pasteboardData withBlock:(void (NS_NOESCAPE ^)(IRCChannel *channel, NSArray<IRCChannelUser *> *members))callbackBlock
{
	return [IRCChannelMemberList readMembersFromPasteboardData:pasteboardData withBlock:callbackBlock];
}

- (BOOL)memberExists:(NSString *)nickname
{
	return [self.memberInfo memberExists:nickname];
}

- (nullable IRCChannelUser *)findMember:(NSString *)nickname
{
	return [self.memberInfo findMember:nickname];
}

- (void)sortMembers
{
	[self.memberInfo sortMembers];
}

#pragma mark -
#pragma mark Table View Delegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSView *newView = [tableView makeViewWithIdentifier:@"GroupView" owner:self];

	return newView;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	TVCMemberListRowCell *rowView = [[TVCMemberListRowCell alloc] initWithMemberList:(id)tableView];

	return rowView;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	[mainWindowMemberList() refreshDrawingForRow:row];
}

#pragma mark -
#pragma mark IRCTreeItem Properties

- (BOOL)isSelectedChannel
{
	return (self == mainWindow().selectedItem);
}

- (BOOL)isActive
{
	return (self.status == IRCChannelStatusJoined);
}

- (BOOL)isClient
{
	return NO;
}

- (NSUInteger)numberOfChildren
{
	return 0;
}

- (nullable id)childAtIndex:(NSUInteger)index
{
	return nil;
}

- (NSString *)label
{
	NSString *customLabel = self.config.label;

	if (customLabel.length > 0) {
		return customLabel;
	}

	return self.name;
}

- (nullable IRCClient *)associatedClient
{
	return self->_associatedClient;
}

- (nullable IRCChannel *)associatedChannel
{
	return self;
}

@end

NS_ASSUME_NONNULL_END
