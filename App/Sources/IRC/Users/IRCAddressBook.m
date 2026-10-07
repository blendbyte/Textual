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
 *	* Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 *	* Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual and/or Codeux Software, nor the names of
 *    its contributors may be used to endorse or promote products derived
 * 	  from this software without specific prior written permission.
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

#import "NSStringHelper.h"
#import "IRCAddressBookInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCAddressBookEntry

- (void)populateDefaultsPreflight
{
	if (self.initializedAsCopy) {
		return;
	}

	self->_defaults = @{
		@"entryType" : @(IRCAddressBookEntryTypeIgnore),
		@"ignoreClientToClientProtocol" : @(NO),
		@"ignoreFileTransferRequests"	: @(NO),
		@"ignoreGeneralEventMessages"	: @(NO),
		@"ignoreInlineMedia" : @(NO),
		@"ignoreNoticeMessages" : @(NO),
		@"ignorePrivateMessageHighlights" : @(NO),
		@"ignorePrivateMessages" : @(NO),
		@"ignorePublicMessageHighlights" : @(NO),
		@"ignorePublicMessages" : @(NO),
		@"trackUserActivity" : @(NO)
	};
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy) {
		return;
	}

	SetVariableIfNil(self->_hostmask, @"")
	SetVariableIfNil(self->_hostmaskRegularExpression, @"")

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])
}

- (void)initializedClassHealthCheck
{
	if (self.initializedAsCopy) {
		return;
	}

	[self rebuildCache];
}

+ (instancetype)newIgnoreEntry
{
	return [self newIgnoreEntryForHostmask:nil];
}

+ (instancetype)newIgnoreEntryForHostmask:(nullable NSString *)hostmask
{
	if (hostmask == nil) {
		hostmask = @"";
	}

	NSDictionary *dic = @{
		@"hostmask" : hostmask,
		@"entryType" : @(IRCAddressBookEntryTypeIgnore),
		@"ignoreClientToClientProtocol" : @(YES),
		@"ignoreFileTransferRequests" : @(YES),
		@"ignoreGeneralEventMessages" : @(YES),
		@"ignoreInlineMedia" : @(YES),
		@"ignoreNoticeMessages" : @(YES),
		@"ignorePrivateMessageHighlights" : @(YES),
		@"ignorePrivateMessages" : @(YES),
		@"ignorePublicMessageHighlights" : @(YES),
		@"ignorePublicMessages" : @(YES)
	};

	IRCAddressBookEntry *object = [[self alloc] initWithDictionary:dic];

	return object;
}

+ (instancetype)newUserTrackingEntry
{
	NSDictionary *dic = @{
		@"entryType" : @(IRCAddressBookEntryTypeUserTracking),
		@"trackUserActivity" : @(YES)
	};

	IRCAddressBookEntry *object = [[self alloc] initWithDictionary:dic];

	return object;
}

- (void)populateDictionaryValues:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	NSMutableDictionary<NSString *, id> *defaultsMutable = [self->_defaults mutableCopy];

	[defaultsMutable addEntriesFromDictionary:dic];

	[dic assignUnsignedIntegerTo:&self->_entryType forKey:@"entryType"];

	IRCAddressBookEntryType entryType = self->_entryType;

	if (entryType == IRCAddressBookEntryTypeIgnore ||
		entryType == IRCAddressBookEntryTypeMixed)
	{
		/* Load the newest set of keys */
		[dic assignBoolTo:&self->_ignoreClientToClientProtocol forKey:@"ignoreClientToClientProtocol"];
		[dic assignBoolTo:&self->_ignoreFileTransferRequests forKey:@"ignoreFileTransferRequests"];
		[dic assignBoolTo:&self->_ignoreGeneralEventMessages forKey:@"ignoreGeneralEventMessages"];
		[dic assignBoolTo:&self->_ignoreInlineMedia forKey:@"ignoreInlineMedia"];
		[dic assignBoolTo:&self->_ignoreNoticeMessages forKey:@"ignoreNoticeMessages"];
		[dic assignBoolTo:&self->_ignorePrivateMessageHighlights forKey:@"ignorePrivateMessageHighlights"];
		[dic assignBoolTo:&self->_ignorePrivateMessages forKey:@"ignorePrivateMessages"];
		[dic assignBoolTo:&self->_ignorePublicMessageHighlights forKey:@"ignorePublicMessageHighlights"];
		[dic assignBoolTo:&self->_ignorePublicMessages forKey:@"ignorePublicMessages"];

		/* Load legacy keys (if they exist) */
		[dic assignBoolTo:&self->_ignoreClientToClientProtocol forKey:@"ignoreCTCP"];
		[dic assignBoolTo:&self->_ignoreGeneralEventMessages forKey:@"ignoreJPQE"];
		[dic assignBoolTo:&self->_ignoreNoticeMessages forKey:@"ignoreNotices"];
		[dic assignBoolTo:&self->_ignorePrivateMessageHighlights forKey:@"ignorePMHighlights"];
		[dic assignBoolTo:&self->_ignorePrivateMessages forKey:@"ignorePrivateMsg"];
		[dic assignBoolTo:&self->_ignorePublicMessageHighlights forKey:@"ignoreHighlights"];
		[dic assignBoolTo:&self->_ignorePublicMessages forKey:@"ignorePublicMsg"];
	}

	if (entryType == IRCAddressBookEntryTypeUserTracking ||
		entryType == IRCAddressBookEntryTypeMixed)
	{
		/* Load the newest set of keys */
		[dic assignBoolTo:&self->_trackUserActivity forKey:@"trackUserActivity"];

		/* Load legacy keys (if they exist) */
		[dic assignBoolTo:&self->_trackUserActivity forKey:@"notifyJoins"];
	}

	[dic assignStringTo:&self->_hostmask forKey:@"hostmask"];
	[dic assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];
}

- (void)rebuildCache
{
	[self rebuildHostmaskRegularExpression];

	[self rebuildTrackingNickname];
}

- (void)rebuildHostmaskRegularExpression
{
	NSString *hostmask = self.hostmask;

	if (self.entryType == IRCAddressBookEntryTypeIgnore)
	{
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"}" withString:@"\\}"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"~" withString:@"\\~"];
		hostmask = [hostmask stringByReplacingOccurrencesOfString:@"*" withString:@"(.*?)"];
	}
	else if (self.entryType == IRCAddressBookEntryTypeUserTracking)
	{
		hostmask = [NSString stringWithFormat:@"^%@!(.*?)@(.*?)$", hostmask];
	}
	else
	{
		return;
	}

	self->_hostmaskRegularExpression = [hostmask copy];
}

- (void)rebuildTrackingNickname
{
	if (self.entryType != IRCAddressBookEntryTypeUserTracking) {
		return;
	}

	NSString *hostmask = self.hostmask;

	hostmask = hostmask.nicknameFromHostmask;

	self->_trackingNickname = [hostmask copy];
}

- (BOOL)checkMatch:(NSString *)hostmask
{
	NSParameterAssert(hostmask != nil);

	return [XRRegularExpression string:hostmask isMatchedByRegex:self.hostmaskRegularExpression withoutCase:YES];
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	[dic maybeSetObject:self.hostmask forKey:@"hostmask"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	IRCAddressBookEntryType entryType = self.entryType;

	if (entryType == IRCAddressBookEntryTypeIgnore ||
		entryType == IRCAddressBookEntryTypeMixed)
	{
		[dic setBool:self.ignoreClientToClientProtocol forKey:@"ignoreClientToClientProtocol"];
		[dic setBool:self.ignoreFileTransferRequests forKey:@"ignoreFileTransferRequests"];
		[dic setBool:self.ignoreGeneralEventMessages forKey:@"ignoreGeneralEventMessages"];
		[dic setBool:self.ignoreInlineMedia forKey:@"ignoreInlineMedia"];
		[dic setBool:self.ignoreNoticeMessages forKey:@"ignoreNoticeMessages"];
		[dic setBool:self.ignorePrivateMessageHighlights forKey:@"ignorePrivateMessageHighlights"];
		[dic setBool:self.ignorePrivateMessages forKey:@"ignorePrivateMessages"];
		[dic setBool:self.ignorePublicMessageHighlights forKey:@"ignorePublicMessageHighlights"];
		[dic setBool:self.ignorePublicMessages forKey:@"ignorePublicMessages"];
	}

	if (entryType == IRCAddressBookEntryTypeUserTracking ||
		entryType == IRCAddressBookEntryTypeMixed)
	{
		[dic setBool:self.trackUserActivity forKey:@"trackUserActivity"];
	}

	[dic setUnsignedInteger:entryType forKey:@"entryType"];

	if (target == XRPortablePropertyDictTargetCopy ||
		target == XRPortablePropertyDictTargetMutableCopy)
	{
		return [dic copy];
	}

	return [dic dictionaryByRemovingDefaults:self->_defaults];
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCAddressBookEntry *config = [self allocForCopyAsMutable:mutableCopy];

	config->_defaults = self->_defaults;

	config->_hostmaskRegularExpression = self->_hostmaskRegularExpression;
	config->_trackingNickname = self->_trackingNickname;

	config->_parentEntries = self->_parentEntries;

	if (uniquing) {
		config->_uniqueIdentifier = [NSString stringWithUUID];
	}

	return [config initWithDictionary:self.dictionaryValueForCopy];
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [IRCAddressBookEntryMutable self];
}

@end

#pragma mark -

@implementation IRCAddressBookEntryMutable

@dynamic entryType;
@dynamic hostmask;
@dynamic ignoreClientToClientProtocol;
@dynamic ignoreFileTransferRequests;
@dynamic ignoreGeneralEventMessages;
@dynamic ignoreInlineMedia;
@dynamic ignoreNoticeMessages;
@dynamic ignorePrivateMessageHighlights;
@dynamic ignorePrivateMessages;
@dynamic ignorePublicMessageHighlights;
@dynamic ignorePublicMessages;
@dynamic trackUserActivity;
@dynamic parentEntries;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [IRCAddressBookEntry self];
}

- (void)setEntryType:(IRCAddressBookEntryType)entryType
{
	if (self->_entryType != entryType) {
		self->_entryType = entryType;

		[self rebuildCache];
	}
}

- (void)setHostmask:(NSString *)hostmask
{
	NSParameterAssert(hostmask != nil);

	if (self->_hostmask != hostmask) {
		self->_hostmask = [hostmask copy];

		[self rebuildCache];
	}
}

- (void)setIgnoreClientToClientProtocol:(BOOL)ignoreClientToClientProtocol
{
	if (self->_ignoreClientToClientProtocol != ignoreClientToClientProtocol) {
		self->_ignoreClientToClientProtocol = ignoreClientToClientProtocol;
	}
}

- (void)setIgnoreFileTransferRequests:(BOOL)ignoreFileTransferRequests
{
	if (self->_ignoreFileTransferRequests != ignoreFileTransferRequests) {
		self->_ignoreFileTransferRequests = ignoreFileTransferRequests;
	}
}

- (void)setIgnoreGeneralEventMessages:(BOOL)ignoreGeneralEventMessages
{
	if (self->_ignoreGeneralEventMessages != ignoreGeneralEventMessages) {
		self->_ignoreGeneralEventMessages = ignoreGeneralEventMessages;
	}
}

- (void)setIgnoreInlineMedia:(BOOL)ignoreInlineMedia
{
	if (self->_ignoreInlineMedia != ignoreInlineMedia) {
		self->_ignoreInlineMedia = ignoreInlineMedia;
	}
}

- (void)setIgnoreNoticeMessages:(BOOL)ignoreNoticeMessages
{
	if (self->_ignoreNoticeMessages != ignoreNoticeMessages) {
		self->_ignoreNoticeMessages = ignoreNoticeMessages;
	}
}

- (void)setIgnorePrivateMessageHighlights:(BOOL)ignorePrivateMessageHighlights
{
	if (self->_ignorePrivateMessageHighlights != ignorePrivateMessageHighlights) {
		self->_ignorePrivateMessageHighlights = ignorePrivateMessageHighlights;
	}
}

- (void)setIgnorePrivateMessages:(BOOL)ignorePrivateMessages
{
	if (self->_ignorePrivateMessages != ignorePrivateMessages) {
		self->_ignorePrivateMessages = ignorePrivateMessages;
	}
}

- (void)setIgnorePublicMessageHighlights:(BOOL)ignorePublicMessageHighlights
{
	if (self->_ignorePublicMessageHighlights != ignorePublicMessageHighlights) {
		self->_ignorePublicMessageHighlights = ignorePublicMessageHighlights;
	}
}

- (void)setIgnorePublicMessages:(BOOL)ignorePublicMessages
{
	if (self->_ignorePublicMessages != ignorePublicMessages) {
		self->_ignorePublicMessages = ignorePublicMessages;
	}
}

- (void)setTrackUserActivity:(BOOL)trackUserActivity
{
	if (self->_trackUserActivity != trackUserActivity) {
		self->_trackUserActivity = trackUserActivity;
	}
}

- (void)setParentEntries:(nullable NSArray<IRCAddressBookEntry *> *)childrenEntries
{
	if (self->_parentEntries != childrenEntries) {
		self->_parentEntries = [childrenEntries copy];
	}
}

@end

NS_ASSUME_NONNULL_END
