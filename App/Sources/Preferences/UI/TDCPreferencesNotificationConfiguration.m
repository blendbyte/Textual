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

#import "TPCPreferencesLocalPrivate.h"
#import "TDCPreferencesNotificationConfigurationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TDCPreferencesNotificationConfiguration

+ (TDCPreferencesNotificationConfiguration *)objectWithEventType:(TXNotificationType)eventType
{
	return [[self alloc] initWithEventType:eventType];
}

- (nullable NSString *)alertSound
{
	NSString *sound = [TPCPreferences soundForEvent:self.eventType];

	if (sound == nil) {
		return TXNoAlertSoundPreferenceValue;
	}

	return sound;
}

- (void)setAlertSound:(nullable NSString *)alertSound
{
	[TPCPreferences setSound:alertSound forEvent:self.eventType];
}

- (NSUInteger)pushNotification
{
	return [TPCPreferences notificationEnabledForEvent:self.eventType];
}

- (void)setPushNotification:(NSUInteger)pushNotification
{
	[TPCPreferences setNotificationEnabled:pushNotification forEvent:self.eventType];
}

- (NSUInteger)speakEvent
{
	return [TPCPreferences speakEvent:self.eventType];
}

- (void)setSpeakEvent:(NSUInteger)speakEvent
{
	[TPCPreferences setEventIsSpoken:speakEvent forEvent:self.eventType];
}

- (NSUInteger)disabledWhileAway
{
	return [TPCPreferences disabledWhileAwayForEvent:self.eventType];
}

- (void)setDisabledWhileAway:(NSUInteger)disabledWhileAway
{
	[TPCPreferences setDisabledWhileAway:disabledWhileAway forEvent:self.eventType];
}

- (NSUInteger)bounceDockIcon
{
	return [TPCPreferences bounceDockIconForEvent:self.eventType];
}

- (void)setBounceDockIcon:(NSUInteger)bounceDockIcon
{
	[TPCPreferences setBounceDockIcon:bounceDockIcon forEvent:self.eventType];
}

- (NSUInteger)bounceDockIconRepeatedly
{
	return [TPCPreferences bounceDockIconRepeatedlyForEvent:self.eventType];
}

- (void)setBounceDockIconRepeatedly:(NSUInteger)bounceDockIconRepeatedly
{
	[TPCPreferences setBounceDockIconRepeatedly:bounceDockIconRepeatedly forEvent:self.eventType];
}

@end

NS_ASSUME_NONNULL_END
