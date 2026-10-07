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

#import "NSObjectHelperPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationConfigurationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TXDefaultAlertSoundPreferenceValue = @"Default";
NSString * const TXNoAlertSoundPreferenceValue = @"None";

@interface TLONotificationConfiguration ()
@property (nonatomic, assign, readwrite) TXNotificationType eventType;
@end

@implementation TLONotificationConfiguration

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithEventType:(TXNotificationType)aEventType
{
	if ((self = [super init])) {
		self.eventType = aEventType;

		return self;
	}

	return nil;
}

+ (instancetype)configurationWithEventType:(TXNotificationType)eventType
{
	return [[self alloc] initWithEventType:eventType];
}

+ (NSString *)localizedAlertDefaultSoundTitle
{
	return TXTLS(@"TVCNotificationConfigurationView[0rs-8l]");
}

+ (NSString *)localizedAlertNoSoundTitle
{
	return TXTLS(@"TVCNotificationConfigurationView[vje-9n]");
}

- (NSString *)displayName
{
	return [sharedNotificationController() titleForEvent:self.eventType];
}

- (nullable NSString *)alertSound
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (void)setAlertSound:(nullable NSString *)alertSound
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSUInteger)pushNotification
{
	[self doesNotRecognizeSelector:_cmd];

	return NSControlStateValueOff;
}

- (void)setPushNotification:(NSUInteger)pushNotification
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSUInteger)speakEvent
{
	[self doesNotRecognizeSelector:_cmd];

	return NSControlStateValueOff;
}

- (void)setSpeakEvent:(NSUInteger)speakEvent
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSUInteger)disabledWhileAway
{
	[self doesNotRecognizeSelector:_cmd];

	return NSControlStateValueOff;
}

- (void)setDisabledWhileAway:(NSUInteger)disabledWhileAway
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSUInteger)bounceDockIcon
{
	[self doesNotRecognizeSelector:_cmd];

	return NSControlStateValueOff;
}

- (void)setBounceDockIcon:(NSUInteger)bounceDockIcon
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSUInteger)bounceDockIconRepeatedly
{
	[self doesNotRecognizeSelector:_cmd];

	return NSControlStateValueOff;
}

- (void)setBounceDockIconRepeatedly:(NSUInteger)bounceDockIconRepeatedly
{
	[self doesNotRecognizeSelector:_cmd];
}

@end

NS_ASSUME_NONNULL_END
