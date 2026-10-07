/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2015 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TPI_ChatFilter.h"
#import "TPI_ChatFilterInternal.h"

#import "NSObjectHelperPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TPI_ChatFilter

- (void)populateDefaultsPreflight
{
	if (self.initializedAsCopy) {
		return;
	}

	self->_defaults = @{
		@"filterEvents"					: @(TPI_ChatFilterEventTypePlainTextMessage |
											TPI_ChatFilterEventTypeActionMessage),

		@"filterIgnoreContent"			: @(NO),
		@"filterIgnoresOperators"		: @(YES),
		@"filterLimitedToMyself"		: @(NO),
		@"filterLogMatch"				: @(NO),

		@"filterLimitedToValue"			: @(TPI_ChatFilterLimitToValueNoLimit),
		@"filterAgeComparator"			: @(TPI_ChatFilterAgeComparatorGreaterThan)
	};
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy) {
		return;
	}

	SetVariableIfNil(self->_filterLimitedToChannelsIDs, @[])
	SetVariableIfNil(self->_filterLimitedToClientsIDs, @[])
	SetVariableIfNil(self->_filterEventsNumerics, @[])

	SetVariableIfNil(self->_filterAction, @"")
	SetVariableIfNil(self->_filterForwardToDestination, @"")
	SetVariableIfNil(self->_filterMatch, @"")
	SetVariableIfNil(self->_filterNotes, @"")
	SetVariableIfNil(self->_filterSenderMatch, @"")
	SetVariableIfNil(self->_filterTitle, @"")

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])
}

- (instancetype)init
{
	return [self initWithDictionary:@{}];
}

- (nullable instancetype)initWithContentsOfPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	NSURL *url = [NSURL fileURLWithPath:path];

	return [self initWithContentsOfURL:url];
}

- (nullable instancetype)initWithContentsOfURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSDictionary *dic = [NSDictionary dictionaryWithContentsOfURL:url];

	if (dic == nil) {
		return nil;
	}

	return [self initWithDictionary:dic];
}

- (void)populateDictionaryValues:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	NSMutableDictionary<NSString *, id> *defaultsMutable = [self->_defaults mutableCopy];

	[defaultsMutable addEntriesFromDictionary:dic];

	/* Set regular key names */
	[defaultsMutable assignArrayTo:&self->_filterLimitedToChannelsIDs forKey:@"filterLimitedToChannelsIDs"];
	[defaultsMutable assignArrayTo:&self->_filterLimitedToClientsIDs forKey:@"filterLimitedToClientsIDs"];
	[defaultsMutable assignArrayTo:&self->_filterEventsNumerics forKey:@"filterEventsNumerics"];

	[defaultsMutable assignBoolTo:&self->_filterIgnoreContent forKey:@"filterIgnoreContent"];
	[defaultsMutable assignBoolTo:&self->_filterIgnoreOperators forKey:@"filterIgnoresOperators"];
	[defaultsMutable assignBoolTo:&self->_filterLimitedToMyself forKey:@"filterLimitedToMyself"];
	[defaultsMutable assignBoolTo:&self->_filterLogMatch forKey:@"filterLogMatch"];

	[defaultsMutable assignStringTo:&self->_filterAction forKey:@"filterAction"];
	[defaultsMutable assignStringTo:&self->_filterForwardToDestination forKey:@"filterForwardToDestination"];
	[defaultsMutable assignStringTo:&self->_filterMatch forKey:@"filterMatch"];
	[defaultsMutable assignStringTo:&self->_filterNotes forKey:@"filterNotes"];
	[defaultsMutable assignStringTo:&self->_filterSenderMatch forKey:@"filterSenderMatch"];
	[defaultsMutable assignStringTo:&self->_filterTitle forKey:@"filterTitle"];

	[defaultsMutable assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];

	[defaultsMutable assignUnsignedIntegerTo:&self->_filterActionFloodControlInterval forKey:@"filterActionFloodControlInterval"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_filterLimitedToValue forKey:@"filterLimitedToValue"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_filterAgeComparator forKey:@"filterAgeComparator"];
	[defaultsMutable assignUnsignedIntegerTo:&self->_filterAgeLimit forKey:@"filterAgeLimit"];

	/* Maintain backwards compatibility by setting old key names */
	/* dic is accessed instead of defaultsMutable because filterEvents will always 
	 exist in defaultsMutable */
	id filterEvents = dic[@"filterEvents"];

	if (filterEvents && [filterEvents isKindOfClass:[NSNumber class]])
	{
		self->_filterEvents = [filterEvents unsignedIntegerValue];
	}
	else
	{
		TPI_ChatFilterEventType filterEventsMask = (TPI_ChatFilterEventTypePlainTextMessage | TPI_ChatFilterEventTypeActionMessage);

		id filterCommandPRIVMSG = defaultsMutable[@"filterCommandPRIVMSG"];

		if (filterCommandPRIVMSG && [filterCommandPRIVMSG boolValue] == NO) {
			filterEventsMask &= ~TPI_ChatFilterEventTypePlainTextMessage;
		}

		id filterCommandPRIVMSG_ACTION = defaultsMutable[@"filterCommandPRIVMSG_ACTION"];

		if (filterCommandPRIVMSG_ACTION && [filterCommandPRIVMSG_ACTION boolValue] == NO) {
			filterEventsMask &= ~TPI_ChatFilterEventTypeActionMessage;
		}

		if ([defaultsMutable boolForKey:@"filterCommandNOTICE"]) {
			filterEventsMask |= TPI_ChatFilterEventTypeNoticeMessage;
		}

		self->_filterEvents = filterEventsMask;
	}
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	/* Maintain backwards compatibility by setting old key names */
	[dic setBool:[self isEventTypeEnabled:TPI_ChatFilterEventTypePlainTextMessage] forKey:@"filterCommandPRIVMSG"];
	[dic setBool:[self isEventTypeEnabled:TPI_ChatFilterEventTypeActionMessage]	forKey:@"filterCommandPRIVMSG_ACTION"];
	[dic setBool:[self isEventTypeEnabled:TPI_ChatFilterEventTypeNoticeMessage]	forKey:@"filterCommandNOTICE"];

	/* Set regular key names */
	[dic maybeSetObject:self.filterLimitedToChannelsIDs forKey:@"filterLimitedToChannelsIDs"];
	[dic maybeSetObject:self.filterLimitedToClientsIDs forKey:@"filterLimitedToClientsIDs"];
	[dic maybeSetObject:self.filterEventsNumerics forKey:@"filterEventsNumerics"];

	[dic maybeSetObject:self.filterAction forKey:@"filterAction"];
	[dic maybeSetObject:self.filterForwardToDestination forKey:@"filterForwardToDestination"];
	[dic maybeSetObject:self.filterMatch forKey:@"filterMatch"];
	[dic maybeSetObject:self.filterNotes forKey:@"filterNotes"];
	[dic maybeSetObject:self.filterSenderMatch forKey:@"filterSenderMatch"];
	[dic maybeSetObject:self.filterTitle forKey:@"filterTitle"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	[dic setBool:self.filterIgnoreContent forKey:@"filterIgnoreContent"];
	[dic setBool:self.filterIgnoreOperators forKey:@"filterIgnoresOperators"];
	[dic setBool:self.filterLimitedToMyself forKey:@"filterLimitedToMyself"];
	[dic setBool:self.filterLogMatch forKey:@"filterLogMatch"];

	[dic setUnsignedInteger:self.filterActionFloodControlInterval forKey:@"filterActionFloodControlInterval"];
	[dic setUnsignedInteger:self.filterEvents forKey:@"filterEvents"];
	[dic setUnsignedInteger:self.filterLimitedToValue forKey:@"filterLimitedToValue"];
	[dic setUnsignedInteger:self.filterAgeComparator forKey:@"filterAgeComparator"];
	[dic setUnsignedInteger:self.filterAgeLimit forKey:@"filterAgeLimit"];

	if (target == XRPortablePropertyDictTargetCopy ||
		target == XRPortablePropertyDictTargetMutableCopy)
	{
		return [dic copy];
	}

	return [dic dictionaryByRemovingDefaults:self->_defaults];
}

- (BOOL)isEventTypeEnabled:(TPI_ChatFilterEventType)eventType
{
	return ((self->_filterEvents & eventType) == eventType);
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	TPI_ChatFilter *config = [self allocForCopyAsMutable:mutableCopy];

	config->_defaults = self->_defaults;

	config->_cachedIsCommandEnabledResponses = self->_cachedIsCommandEnabledResponses;

	return [config initWithDictionary:self.dictionaryValueForCopy];
}

- (BOOL)isCommandEnabled:(NSString *)command
{
	NSParameterAssert(command != nil);

	if (self->_cachedIsCommandEnabledResponses == nil) {
		self->_cachedIsCommandEnabledResponses = [NSCache new];
	}

	NSNumber *cachedResponse = [self->_cachedIsCommandEnabledResponses objectForKey:command];

	if (cachedResponse == nil) {
		TPI_ChatFilterEventType filterEvents = self.filterEvents;

#define _commandMatchesEvent(_command_, _event_)	\
	if ([command isEqualToString:(_command_)]) {	\
		cachedResponse = @((filterEvents & _event_) == _event_);	\
	}

		_commandMatchesEvent(@"JOIN", TPI_ChatFilterEventTypeUserJoinedChannel)
		else _commandMatchesEvent(@"PART", TPI_ChatFilterEventTypeUserLeftChannel)
		else _commandMatchesEvent(@"KICK", TPI_ChatFilterEventTypeUserKickedFromChannel)
		else _commandMatchesEvent(@"QUIT", TPI_ChatFilterEventTypeUserDisconnected)
		else _commandMatchesEvent(@"NICK", TPI_ChatFilterEventTypeUserChangedNickname)
		else _commandMatchesEvent(@"TOPIC", TPI_ChatFilterEventTypeChannelTopicChanged)
		else _commandMatchesEvent(@"MODE", TPI_ChatFilterEventTypeChannelModeChanged)
		else _commandMatchesEvent(@"332", TPI_ChatFilterEventTypeChannelTopicReceived)
		else _commandMatchesEvent(@"333", TPI_ChatFilterEventTypeChannelTopicReceived)
		else _commandMatchesEvent(@"324", TPI_ChatFilterEventTypeChannelModeReceived)
		else
		{
			cachedResponse = @([self.filterEventsNumerics containsObject:command]);
		}

		[self->_cachedIsCommandEnabledResponses setObject:cachedResponse forKey:command];
	}

	return cachedResponse.boolValue;

#undef _commandMatchesEvent
}

- (void)purgeIsCommandEnabledResponses
{
	if (self->_cachedIsCommandEnabledResponses == nil) {
		return;
	}

	[self->_cachedIsCommandEnabledResponses removeAllObjects];
}

- (NSString *)filterDescription
{
	return TPILocalizedString(@"TPI_ChatFilterExtension[dka-bx]", self.filterTitle);
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [TPI_ChatFilterMutable self];
}

- (BOOL)writeToPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	NSURL *url = [NSURL fileURLWithPath:path];

	return [self writeToURL:url];
}

- (BOOL)writeToURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSDictionary *dictionaryValue = self.dictionaryValue;

	NSError *parseError = nil;

	NSData *propertyList =
	[NSPropertyListSerialization dataWithPropertyList:dictionaryValue format:NSPropertyListBinaryFormat_v1_0 options:0 error:&parseError];

	if (propertyList == nil) {
		if (parseError) {
			LogToConsoleErrorWithSubsystem(THOPluginLoggingSubsystem(),
				"Error Creating Property List: %@",
				parseError.localizedDescription);
		}

		return NO;
	}

	BOOL writeResult = [propertyList writeToURL:url atomically:YES];

	if (writeResult == NO) {
		LogToConsoleErrorWithSubsystem(THOPluginLoggingSubsystem(), "Write failed");

		return NO;
	}

	return YES;
}

@end

#pragma mark -

@implementation TPI_ChatFilterMutable

@dynamic filterAgeComparator;
@dynamic filterAgeLimit;
@dynamic filterIgnoreContent;
@dynamic filterIgnoreOperators;
@dynamic filterLogMatch;
@dynamic filterLimitedToMyself;
@dynamic filterEvents;
@dynamic filterLimitedToValue;
@dynamic filterLimitedToChannelsIDs;
@dynamic filterLimitedToClientsIDs;
@dynamic filterEventsNumerics;
@dynamic filterActionFloodControlInterval;
@dynamic filterAction;
@dynamic filterForwardToDestination;
@dynamic filterMatch;
@dynamic filterNotes;
@dynamic filterSenderMatch;
@dynamic filterTitle;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [TPI_ChatFilter self];
}

- (void)setFilterIgnoreContent:(BOOL)filterIgnoreContent
{
	if (self->_filterIgnoreContent != filterIgnoreContent) {
		self->_filterIgnoreContent = filterIgnoreContent;
	}
}

- (void)setFilterIgnoreOperators:(BOOL)filterIgnoreOperators
{
	if (self->_filterIgnoreOperators != filterIgnoreOperators) {
		self->_filterIgnoreOperators = filterIgnoreOperators;
	}
}

- (void)setFilterLogMatch:(BOOL)filterLogMatch
{
	if (self->_filterLogMatch != filterLogMatch) {
		self->_filterLogMatch = filterLogMatch;
	}
}

- (void)setFilterLimitedToMyself:(BOOL)filterLimitedToMyself
{
	if (self->_filterLimitedToMyself != filterLimitedToMyself) {
		self->_filterLimitedToMyself = filterLimitedToMyself;
	}
}

- (void)setFilterEvents:(TPI_ChatFilterEventType)filterEvents
{
	if (self->_filterEvents != filterEvents) {
		self->_filterEvents = filterEvents;

		[self purgeIsCommandEnabledResponses];
	}
}

- (void)setFilterLimitedToValue:(TPI_ChatFilterLimitToValue)filterLimitedToValue
{
	if (self->_filterLimitedToValue != filterLimitedToValue) {
		self->_filterLimitedToValue = filterLimitedToValue;
	}
}

- (void)setFilterLimitedToChannelsIDs:(NSArray<NSString *> *)filterLimitedToChannelsIDs
{
	NSParameterAssert(filterLimitedToChannelsIDs != nil);

	if (self->_filterLimitedToChannelsIDs != filterLimitedToChannelsIDs) {
		self->_filterLimitedToChannelsIDs = [filterLimitedToChannelsIDs copy];
	}
}

- (void)setFilterLimitedToClientsIDs:(NSArray<NSString *> *)filterLimitedToClientsIDs
{
	NSParameterAssert(filterLimitedToClientsIDs != nil);

	if (self->_filterLimitedToClientsIDs != filterLimitedToClientsIDs) {
		self->_filterLimitedToClientsIDs = [filterLimitedToClientsIDs copy];
	}
}

- (void)setFilterEventsNumerics:(NSArray<NSString *> *)filterEventsNumerics
{
	NSParameterAssert(filterEventsNumerics != nil);

	if (self->_filterEventsNumerics != filterEventsNumerics) {
		self->_filterEventsNumerics = [filterEventsNumerics copy];

		[self purgeIsCommandEnabledResponses];
	}
}

- (void)setFilterAgeComparator:(TPI_ChatFilterAgeComparator)filterAgeComparator
{
	if (self->_filterAgeComparator != filterAgeComparator) {
		self->_filterAgeComparator = filterAgeComparator;
	}
}

- (void)setFilterAgeLimit:(NSUInteger)filterAgeLimit
{
	if (self->_filterAgeLimit != filterAgeLimit) {
		self->_filterAgeLimit = filterAgeLimit;
	}
}

- (void)setFilterActionFloodControlInterval:(NSUInteger)filterActionFloodControlInterval
{
	if (self->_filterActionFloodControlInterval != filterActionFloodControlInterval) {
		self->_filterActionFloodControlInterval = filterActionFloodControlInterval;
	}
}

- (void)setFilterAction:(NSString *)filterAction
{
	NSParameterAssert(filterAction != nil);

	if (self->_filterAction != filterAction) {
		self->_filterAction = [filterAction copy];
	}
}

- (void)setFilterForwardToDestination:(NSString *)filterForwardToDestination
{
	NSParameterAssert(filterForwardToDestination != nil);

	if (self->_filterForwardToDestination != filterForwardToDestination) {
		self->_filterForwardToDestination = [filterForwardToDestination copy];
	}
}

- (void)setFilterMatch:(NSString *)filterMatch
{
	NSParameterAssert(filterMatch != nil);

	if (self->_filterMatch != filterMatch) {
		self->_filterMatch = [filterMatch copy];
	}
}

- (void)setFilterNotes:(NSString *)filterNotes
{
	NSParameterAssert(filterNotes != nil);

	if (self->_filterNotes != filterNotes) {
		self->_filterNotes = [filterNotes copy];
	}
}

- (void)setFilterSenderMatch:(NSString *)filterSenderMatch
{
	NSParameterAssert(filterSenderMatch != nil);

	if (self->_filterSenderMatch != filterSenderMatch) {
		self->_filterSenderMatch = [filterSenderMatch copy];
	}
}

- (void)setFilterTitle:(NSString *)filterTitle
{
	NSParameterAssert(filterTitle != nil);

	if (self->_filterTitle != filterTitle) {
		self->_filterTitle = [filterTitle copy];
	}
}

@end

NS_ASSUME_NONNULL_END
