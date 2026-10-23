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

#import "TLOKeychainPrivate.h"
#import "NSObjectHelperPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "IRCChannelConfigInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCChannelConfig

#pragma mark -
#pragma mark Defaults

- (void)populateDefaultsPreflight
{	
	if (self.initializedAsCopy) {
		return;
	}

	self->_defaults = @{
	  @"autoJoin" : @(YES),
	  @"channelType" : @(IRCChannelTypeChannel),
	  @"ignoreGeneralEventMessages"	: @(NO),
	  @"ignoreHighlights" : @(NO),
	  @"inlineMediaEnabled" : @(NO),
	  @"inlineMediaDisabled" : @(NO),
	  @"pushNotifications" : @(YES),
	  @"showTreeBadgeCount" : @(YES)
	};
}

- (void)populateDefaultsPostflight
{	
	if (self.initializedAsCopy) {
		return;
	}

	SetVariableIfNil(self->_channelName, @"")

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])

	SetVariableIfNil(self->_notificationsMutable, [NSMutableDictionary dictionary])
}

- (void)populateDefaultsByAppendingDictionary:(NSDictionary<NSString *, id> *)defaultsToAppend
{
	NSParameterAssert(defaultsToAppend != nil);

	self->_defaults = [self->_defaults dictionaryByAddingEntries:defaultsToAppend];
}

#pragma mark -
#pragma mark Channel Configuration

+ (IRCChannelConfig *)seedWithName:(NSString *)channelName
{
	NSParameterAssert(channelName != nil);

	NSDictionary *dic = @{@"channelName" : channelName};

	IRCChannelConfig *config = [[self alloc] initWithDictionary:dic];

	return config;
}

- (instancetype)init
{
	return [super initWithDictionary:@{}];
}

- (void)initializedClassHealthCheck
{
	if (self.mutable || self.initializedAsCopy) {
		return;
	}

	NSParameterAssert(self->_channelName.length > 0);
}

- (void)populateDictionaryValues:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	NSMutableDictionary<NSString *, id> *defaultsMutable = [self->_defaults mutableCopy];

	[defaultsMutable addEntriesFromDictionary:dic];

	[defaultsMutable assignBoolTo:&self->_pushNotifications forKey:@"pushNotifications"];
	[defaultsMutable assignBoolTo:&self->_showTreeBadgeCount forKey:@"showTreeBadgeCount"];

	[defaultsMutable assignStringTo:&self->_channelName forKey:@"channelName"];
	[defaultsMutable assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];

	[defaultsMutable assignUnsignedIntegerTo:&self->_type forKey:@"channelType"];

	if (self->_type != IRCChannelTypeChannel) {
		return;
	}

	/* Load the newest set of keys */
	[defaultsMutable assignBoolTo:&self->_autoJoin forKey:@"autoJoin"];
	[defaultsMutable assignBoolTo:&self->_ignoreGeneralEventMessages forKey:@"ignoreGeneralEventMessages"];
	[defaultsMutable assignBoolTo:&self->_ignoreHighlights forKey:@"ignoreHighlights"];
	[defaultsMutable assignBoolTo:&self->_inlineMediaDisabled forKey:@"inlineMediaDisabled"];
	[defaultsMutable assignBoolTo:&self->_inlineMediaEnabled forKey:@"inlineMediaEnabled"];

	[defaultsMutable assignStringTo:&self->_label forKey:@"label"];

	[defaultsMutable assignStringTo:&self->_defaultModes forKey:@"defaultMode"];
	[defaultsMutable assignStringTo:&self->_defaultTopic forKey:@"defaultTopic"];

	NSDictionary *notifications = [defaultsMutable dictionaryForKey:@"notifications"];

	if (notifications != nil) {
		self->_notificationsMutable = [notifications mutableCopy];
	}

	/* Load legacy keys (if they exist) */
	if (self.initializedAsCopy) {
		return;
	}

	[defaultsMutable assignBoolTo:&self->_autoJoin forKey:@"joinOnConnect"];
	[defaultsMutable assignBoolTo:&self->_ignoreGeneralEventMessages forKey:@"ignoreJPQActivity"];
	[defaultsMutable assignBoolTo:&self->_pushNotifications forKey:@"enableNotifications"];
	[defaultsMutable assignBoolTo:&self->_showTreeBadgeCount forKey:@"enableTreeBadgeCountDrawing"];

	/* Migrate inline media */
	/* Old behavior was to store a single property named "ignoreInlineMedia"
	 Depending on the value of the global preference, the value of this
	 property was used to determine whether to hide inline media per-channel
	 or to show it per-channel. That is stupid idea because if someone
	 has it enabled globally, has it turned off in a channel, turns it
	 off globally, then it is turned on in that channel. We split it
	 up into two properties and this logic performs migration. */
	{
		/* Do new keys exist in incoming dictionary/ */
		if (dic[@"inlineMediaEnabled"] != nil &&
			dic[@"inlineMediaDisabled"] != nil)
		{
			return;
		}

		NSNumber *ignoreInlineMedia = dic[@"ignoreInlineMedia"]; // old key

		/* If old value is NO, then we do not have to continue
		 because the default value for the new values is NO. */
		if (ignoreInlineMedia == nil || ignoreInlineMedia.boolValue == NO) {
			return;
		}

		BOOL inlineEnabledGlobally = [TPCPreferences showInlineMedia];

		/* Old property was the inverse of the global */
		/* Global enabled = local disabled,
		   Global disabled = local enabled */
		self->_inlineMediaDisabled = inlineEnabledGlobally;
		self->_inlineMediaEnabled = !inlineEnabledGlobally;
	}
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	[dic setBool:self.pushNotifications	forKey:@"pushNotifications"];
	[dic setBool:self.showTreeBadgeCount forKey:@"showTreeBadgeCount"];

	if (self.type == IRCChannelTypeChannel) {
		[dic maybeSetObject:self.label forKey:@"label"];

		[dic maybeSetObject:self.defaultModes forKey:@"defaultMode"];
		[dic maybeSetObject:self.defaultTopic forKey:@"defaultTopic"];

		[dic maybeSetObject:self.notifications forKey:@"notifications"];

		[dic setBool:self.autoJoin forKey:@"autoJoin"];

		[dic setBool:self.ignoreGeneralEventMessages forKey:@"ignoreGeneralEventMessages"];
		[dic setBool:self.ignoreHighlights forKey:@"ignoreHighlights"];

		[dic setBool:self.inlineMediaDisabled forKey:@"inlineMediaDisabled"];
		[dic setBool:self.inlineMediaEnabled forKey:@"inlineMediaEnabled"];
	}

	[dic maybeSetObject:self.channelName forKey:@"channelName"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	[dic setUnsignedInteger:self.type forKey:@"channelType"];

	if (target == XRPortablePropertyDictTargetCopy ||
		target == XRPortablePropertyDictTargetMutableCopy)
	{
		return [dic copy];
	}

	return [dic dictionaryByRemovingDefaults:self->_defaults allowEmptyValues:YES];
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[IRCChannelConfig class]] == NO) {
		return NO;
	}

	IRCChannelConfig *objectCast = (IRCChannelConfig *)object;

	NSDictionary *s1 = self.dictionaryValue;

	NSDictionary *s2 = objectCast.dictionaryValue;

	return ([s1 isEqualToDictionary:s2] &&
			((self->_secretKey == nil && objectCast->_secretKey == nil) ||
			 [self->_secretKey isEqualToString:objectCast->_secretKey]));
}

- (NSUInteger)hash
{
	return self.uniqueIdentifier.hash;
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCChannelConfig *config = [self allocForCopyAsMutable:mutableCopy];

	config->_defaults = self->_defaults;

	config->_secretKey = self->_secretKey;

	config = [config initWithDictionary:self.dictionaryValueForCopy];

	/* After initialization, which reads the identifier from the dictionary:
	 set before, the copy kept the original's identifier and shared its
	 Keychain items (R2.2). The key comes along to be saved under the new
	 identifier. */
	if (uniquing) {
		config->_secretKey = self.secretKey;

		config->_uniqueIdentifier = [NSString stringWithUUID];
	}

	return config;
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [IRCChannelConfigMutable self];
}

- (NSDictionary<NSString *, NSNumber *> *)notifications
{
	@synchronized (self->_notificationsMutable) {
		return [self->_notificationsMutable copy];
	}
}

#pragma mark -
#pragma mark Keychain Management

- (nullable NSString *)secretKey
{
	if (self->_secretKey) {
		return self->_secretKey;
	}

	return self.secretKeyFromKeychain;
}

- (nullable NSString *)secretKeyFromKeychain
{
	return [TLOKeychain passwordOfKind:TLOKeychainItemKindChannelKey forIdentifier:self.uniqueIdentifier];
}

- (void)writeSecretKeyToKeychain
{
	if (self->_secretKey == nil) {
		return;
	}

	/* Kept in memory if the Keychain refuses it */
	if ([TLOKeychain setPassword:self->_secretKey ofKind:TLOKeychainItemKindChannelKey forIdentifier:self.uniqueIdentifier]) {
		self->_secretKey = nil;
	}
}

- (void)destroySecretKeyKeychainItem
{
	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindChannelKey forIdentifier:self.uniqueIdentifier];

	/* Reset temporary value */
	self->_secretKey = nil;
}

#pragma mark -
#pragma mark Notifications

- (nullable NSString *)soundForEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Sound"];

	if (eventKey == nil) {
		return nil;
	}

	/* @synchronized is used here because IRCChannelConfigMutable can modify
	 this value underneath us. */
	@synchronized (self->_notificationsMutable) {
		return self->_notificationsMutable[eventKey];
	}
}

- (NSControlStateValue)_stateForEventKey:(NSString *)eventKey
{
	NSParameterAssert(eventKey != nil);

	@synchronized (self->_notificationsMutable) {
		NSNumber *value = self->_notificationsMutable[eventKey];

		if (value == nil) {
			return NSControlStateValueMixed;
		}

		if (value.boolValue == NO) {
			return NSControlStateValueOff;
		}

		return NSControlStateValueOn;
	}
}

- (NSControlStateValue)notificationEnabledForEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Enabled"];

	if (eventKey == nil) {
		return NO;
	}

	return [self _stateForEventKey:eventKey];
}

- (NSControlStateValue)disabledWhileAwayForEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Disable While Away"];

	if (eventKey == nil) {
		return NO;
	}

	return [self _stateForEventKey:eventKey];
}

- (NSControlStateValue)bounceDockIconForEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Bounce Dock Icon"];

	if (eventKey == nil) {
		return NO;
	}

	return [self _stateForEventKey:eventKey];
}

- (NSControlStateValue)bounceDockIconRepeatedlyForEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Bounce Dock Icon Repeatedly"];

	if (eventKey == nil) {
		return NO;
	}

	return [self _stateForEventKey:eventKey];
}

- (NSControlStateValue)speakEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Speak"];

	if (eventKey == nil) {
		return NO;
	}

	return [self _stateForEventKey:eventKey];
}

@end

#pragma mark -

@implementation IRCChannelConfigMutable

@dynamic type;
@dynamic autoJoin;
@dynamic channelName;
@dynamic label;
@dynamic defaultModes;
@dynamic defaultTopic;
@dynamic ignoreGeneralEventMessages;
@dynamic ignoreHighlights;
@dynamic inlineMediaDisabled;
@dynamic inlineMediaEnabled;
@dynamic pushNotifications;
@dynamic secretKey;
@dynamic showTreeBadgeCount;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [IRCChannelConfig self];
}

- (void)setType:(IRCChannelType)type
{
	if (self->_type != type) {
		self->_type = type;
	}
}

- (void)setAutoJoin:(BOOL)autoJoin
{
	if (self->_autoJoin != autoJoin) {
		self->_autoJoin = autoJoin;
	}
}

- (void)setIgnoreGeneralEventMessages:(BOOL)ignoreGeneralEventMessages
{
	if (self->_ignoreGeneralEventMessages != ignoreGeneralEventMessages) {
		self->_ignoreGeneralEventMessages = ignoreGeneralEventMessages;
	}
}

- (void)setIgnoreHighlights:(BOOL)ignoreHighlights
{
	if (self->_ignoreHighlights != ignoreHighlights) {
		self->_ignoreHighlights = ignoreHighlights;
	}
}

- (void)setInlineMediaDisabled:(BOOL)inlineMediaDisabled
{
	if (self->_inlineMediaDisabled != inlineMediaDisabled) {
		self->_inlineMediaDisabled = inlineMediaDisabled;
	}
}

- (void)setInlineMediaEnabled:(BOOL)inlineMediaEnabled
{
	if (self->_inlineMediaEnabled != inlineMediaEnabled) {
		self->_inlineMediaEnabled = inlineMediaEnabled;
	}
}

- (void)setPushNotifications:(BOOL)pushNotifications
{
	if (self->_pushNotifications != pushNotifications) {
		self->_pushNotifications = pushNotifications;
	}
}

- (void)setShowTreeBadgeCount:(BOOL)showTreeBadgeCount
{
	if (self->_showTreeBadgeCount != showTreeBadgeCount) {
		self->_showTreeBadgeCount = showTreeBadgeCount;
	}
}

- (void)setChannelName:(NSString *)channelName
{
	NSParameterAssert(channelName != nil);

	if (self->_channelName != channelName) {
		self->_channelName = [channelName copy];
	}
}

- (void)setLabel:(nullable NSString *)label
{
	if (self->_label != label) {
		self->_label = [label copy];
	}
}

- (void)setDefaultModes:(nullable NSString *)defaultModes
{
	if (self->_defaultModes != defaultModes) {
		self->_defaultModes = [defaultModes copy];
	}
}

- (void)setDefaultTopic:(nullable NSString *)defaultTopic
{
	if (self->_defaultTopic != defaultTopic) {
		self->_defaultTopic = [defaultTopic copy];
	}
}

- (void)setSecretKey:(nullable NSString *)secretKey
{
	if (self->_secretKey != secretKey) {
		self->_secretKey = [secretKey copy];
	}
}

- (void)setSound:(nullable NSString *)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Sound"];

	if (eventKey == nil) {
		return;
	}

	@synchronized (self->_notificationsMutable) {
		if (value == nil) {
			[self->_notificationsMutable removeObjectForKey:eventKey];
		} else {
			self->_notificationsMutable[eventKey] = value;
		}
	}
}

- (void)_setState:(NSControlStateValue)state forEventKey:(NSString *)eventKey
{
	NSParameterAssert(eventKey != nil);

	@synchronized (self->_notificationsMutable) {
		switch (state) {
			case NSControlStateValueOn:
			{
				self->_notificationsMutable[eventKey] = @(YES);

				break;
			}
			case NSControlStateValueOff:
			{
				self->_notificationsMutable[eventKey] = @(NO);

				break;
			}
			case NSControlStateValueMixed:
			{
				[self->_notificationsMutable removeObjectForKey:eventKey];

				break;
			}
			default:
			{
				NSAssert(NO, @"Bad 'state'");
			}
		}
	}
}

- (void)setNotificationEnabled:(NSControlStateValue)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Enabled"];

	if (eventKey == nil) {
		return;
	}

	[self _setState:value forEventKey:eventKey];
}

- (void)setDisabledWhileAway:(NSControlStateValue)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Disable While Away"];

	if (eventKey == nil) {
		return;
	}

	[self _setState:value forEventKey:eventKey];
}

- (void)setBounceDockIcon:(NSControlStateValue)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Bounce Dock Icon"];

	if (eventKey == nil) {
		return;
	}

	[self _setState:value forEventKey:eventKey];
}

- (void)setBounceDockIconRepeatedly:(NSControlStateValue)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Bounce Dock Icon Repeatedly"];

	if (eventKey == nil) {
		return;
	}

	[self _setState:value forEventKey:eventKey];
}

- (void)setEventIsSpoken:(NSControlStateValue)value forEvent:(TXNotificationType)event
{
	NSString *eventKey = [TPCPreferences keyForEvent:event category:@"Speak"];

	if (eventKey == nil) {
		return;
	}

	[self _setState:value forEventKey:eventKey];
}

@end

NS_ASSUME_NONNULL_END
