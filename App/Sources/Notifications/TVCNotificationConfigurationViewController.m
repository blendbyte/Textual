/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "TLOLocalization.h"
#import "TLONotificationConfigurationPrivate.h"
#import "TLOSoundPlayer.h"
#import "TVCNotificationConfigurationViewControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _alertSoundsDefaultSoundIndex			0
#define _alertSoundsNoSoundIndex				2

@interface TVCNotificationConfigurationViewController ()
@property (nonatomic, weak) NSView *attachedView;
@property (nonatomic, strong) IBOutlet NSView *contentView;
@property (nonatomic, weak) IBOutlet NSButton *alertBounceDockIconButton;
@property (nonatomic, weak) IBOutlet NSButton *alertBounceDockIconRepeatedlyButton;
@property (nonatomic, weak) IBOutlet NSButton *alertDisableWhileAwayButton;
@property (nonatomic, weak) IBOutlet NSButton *alertPushNotificationButton;
@property (nonatomic, weak) IBOutlet NSButton *alertSpeakEventButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *alertSoundChoiceButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *alertTypeChoiceButton;
@property (nonatomic, weak) IBOutlet NSTextField *alertNotificationDestinationTextField;
@property (nonatomic, strong) TLONotificationConfiguration *activeAlert;
@property (nonatomic, assign) BOOL activeAlertPropertyChangedByUser;
@property (nonatomic, copy) NSArray *alertSounds;

- (IBAction)onChangedAlertBounceDockIcon:(id)sender;
- (IBAction)onChangedAlertBounceDockIconRepeatedly:(id)sender;
- (IBAction)onChangedAlertDisableWhileAway:(id)sender;
- (IBAction)onChangedAlertPushNotification:(id)sender;
- (IBAction)onChangedAlertSound:(id)sender;
- (IBAction)onChangedAlertSpoken:(id)sender;
- (IBAction)onChangedAlertType:(id)sender;
@end

@implementation TVCNotificationConfigurationViewController

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self stopObservingActiveAlert];
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TVCNotificationConfigurationView" owner:self topLevelObjects:nil];

	[self updateAvailableSounds];

	self.alertNotificationDestinationTextField.stringValue = TXTLS(@"TVCNotificationConfigurationView[br6-di]");
}

- (void)attachToView:(NSView *)view
{
	NSParameterAssert(view != nil);

	if (self.attachedView == nil) {
		self.attachedView = view;
	} else {
		NSAssert(NO, @"View is already attached to a view");
	}

	NSView *contentView = self.contentView;

	[view addSubview:contentView];

	[view addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[contentView]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(contentView)]];

	[view addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[contentView]-0-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:nil
											   views:NSDictionaryOfVariableBindings(contentView)]];
}

- (void)setAllowsMixedState:(BOOL)allowsMixedState
{
	if (self->_allowsMixedState != allowsMixedState) {
		self->_allowsMixedState = allowsMixedState;

		[self updateMixedState];
	}
}

- (void)updateMixedState
{
	BOOL allowsMixedState = self.allowsMixedState;

	self.alertSpeakEventButton.allowsMixedState = allowsMixedState;
	self.alertBounceDockIconButton.allowsMixedState = allowsMixedState;
	self.alertBounceDockIconRepeatedlyButton.allowsMixedState = allowsMixedState;
	self.alertDisableWhileAwayButton.allowsMixedState = allowsMixedState;
	self.alertPushNotificationButton.allowsMixedState = allowsMixedState;
}

- (void)setNotifications:(NSArray *)notifications
{
	if (self->_notifications != notifications) {
		self->_notifications = [notifications copy];

		[self availableAlertsChanged];
	}
}

- (void)availableAlertsChanged
{
	if (self.notifications.count == 0) {
		[self resetControls];
	} else {
		[self updateAlertSelection];
	}
}

- (void)resetControls
{
	[self.alertTypeChoiceButton removeAllItems];

	self.alertSpeakEventButton.state = NSControlStateValueOff;
	self.alertBounceDockIconButton.state = NSControlStateValueOff;
	self.alertBounceDockIconRepeatedlyButton.enabled = NO;
	self.alertBounceDockIconRepeatedlyButton.state = NSControlStateValueOff;
	self.alertDisableWhileAwayButton.state = NSControlStateValueOff;
	self.alertPushNotificationButton.state = NSControlStateValueOff;

	[self.alertSoundChoiceButton removeAllItems];
}

- (void)updateAlertSelection
{
	[self.alertTypeChoiceButton removeAllItems];

	[self.notifications enumerateObjectsUsingBlock:^(id alert, NSUInteger index, BOOL *stop) {
		if ([alert isKindOfClass:[TLONotificationConfiguration class]]) {
			NSMenuItem *item = [NSMenuItem new];

			item.tag = index;

			item.title = [alert displayName];

			[self.alertTypeChoiceButton.menu addItem:item];
		} else {
			[self.alertTypeChoiceButton.menu addItem:[NSMenuItem separatorItem]];
		}
	}];

	[self.alertTypeChoiceButton selectItemAtIndex:0];

	[self onChangedAlertType:nil];
}

- (void)reload
{
	TLONotificationConfiguration *alert = self.activeAlert;

	self.alertSpeakEventButton.state = alert.speakEvent;
	self.alertBounceDockIconButton.state = alert.bounceDockIcon;
	self.alertBounceDockIconRepeatedlyButton.enabled = (self.alertBounceDockIconButton.state != NSControlStateValueOff);
	self.alertBounceDockIconRepeatedlyButton.state = alert.bounceDockIconRepeatedly;
	self.alertDisableWhileAwayButton.state = alert.disabledWhileAway;
	self.alertPushNotificationButton.state = alert.pushNotification;

	NSString *alertSound = alert.alertSound;

	if (alertSound == nil) {
		[self.alertSoundChoiceButton selectItemAtIndex:_alertSoundsDefaultSoundIndex];
	} else if ([alertSound isEqualToString:TXNoAlertSoundPreferenceValue]) {
		[self.alertSoundChoiceButton selectItemAtIndex:_alertSoundsNoSoundIndex];
	} else {
		NSUInteger soundIndex = [self.alertSounds indexOfObject:alert.alertSound];

		if (soundIndex == NSNotFound) {
			[self.alertSoundChoiceButton selectItemAtIndex:_alertSoundsNoSoundIndex];
		} else {
			[self.alertSoundChoiceButton selectItemAtIndex:soundIndex];
		}
	}
}

- (void)onChangedAlertType:(id)sender
{
	TXNotificationType alertTag = (TXNotificationType)self.alertTypeChoiceButton.selectedTag;

	self.activeAlert = self.notifications[alertTag];

	[self reload];
}

- (void)onChangedAlertPushNotification:(id)sender
{
	self.activeAlertPropertyChangedByUser = YES;

	TLONotificationConfiguration *alert = self.activeAlert;

	alert.pushNotification = self.alertPushNotificationButton.state;
}

- (void)onChangedAlertSpoken:(id)sender
{
	self.activeAlertPropertyChangedByUser = YES;

	TLONotificationConfiguration *alert = self.activeAlert;

	alert.speakEvent = self.alertSpeakEventButton.state;
}

- (void)onChangedAlertDisableWhileAway:(id)sender
{
	self.activeAlertPropertyChangedByUser = YES;

	TLONotificationConfiguration *alert = self.activeAlert;

	alert.disabledWhileAway = self.alertDisableWhileAwayButton.state;
}

- (void)onChangedAlertBounceDockIcon:(id)sender
{
	self.activeAlertPropertyChangedByUser = YES;

	TLONotificationConfiguration *alert = self.activeAlert;

	alert.bounceDockIcon = self.alertBounceDockIconButton.state;

	self.alertBounceDockIconRepeatedlyButton.enabled = (self.alertBounceDockIconButton.state == NSControlStateValueOn);
}

- (void)onChangedAlertBounceDockIconRepeatedly:(id)sender
{
	self.activeAlertPropertyChangedByUser = YES;

	TLONotificationConfiguration *alert = self.activeAlert;

	alert.bounceDockIconRepeatedly = self.alertBounceDockIconRepeatedlyButton.state;
}

- (void)onChangedAlertSound:(id)sender
{
	self.activeAlertPropertyChangedByUser = YES;

	TLONotificationConfiguration *alert = self.activeAlert;

	NSString *alertSound = self.alertSoundChoiceButton.titleOfSelectedItem;

	if ([alertSound isEqualToString:[TLONotificationConfiguration localizedAlertDefaultSoundTitle]]) {
		alertSound = nil;
	} else if ([alertSound isEqualToString:[TLONotificationConfiguration localizedAlertNoSoundTitle]]) {
		alertSound = TXNoAlertSoundPreferenceValue;
	}

	if (alertSound) {
		[TLOSoundPlayer playAlertSound:alertSound];
	}

	alert.alertSound = alertSound;
}

- (void)setActiveAlert:(TLONotificationConfiguration *)activeAlert
{
	NSParameterAssert(activeAlert != nil);

	if (self->_activeAlert != activeAlert) {
		[self stopObservingActiveAlert];

		self->_activeAlert = activeAlert;

		[self startObservingActiveAlert];
	}
}

- (void)startObservingActiveAlert
{
	TLONotificationConfiguration *activeAlert = self.activeAlert;

	if (activeAlert == nil) {
		return;
	}

	[activeAlert addObserver:self forKeyPath:@"alertSound" options:NSKeyValueObservingOptionNew context:NULL];
	[activeAlert addObserver:self forKeyPath:@"speakEvent" options:NSKeyValueObservingOptionNew context:NULL];
	[activeAlert addObserver:self forKeyPath:@"pushNotification" options:NSKeyValueObservingOptionNew context:NULL];
	[activeAlert addObserver:self forKeyPath:@"disableWhileAway" options:NSKeyValueObservingOptionNew context:NULL];
	[activeAlert addObserver:self forKeyPath:@"bounceDockIcon" options:NSKeyValueObservingOptionNew context:NULL];
	[activeAlert addObserver:self forKeyPath:@"bounceDockIconRepeatedly" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)stopObservingActiveAlert
{
	TLONotificationConfiguration *activeAlert = self.activeAlert;

	if (activeAlert == nil) {
		return;
	}

	[activeAlert removeObserver:self forKeyPath:@"alertSound"];
	[activeAlert removeObserver:self forKeyPath:@"speakEvent"];
	[activeAlert removeObserver:self forKeyPath:@"pushNotification"];
	[activeAlert removeObserver:self forKeyPath:@"disableWhileAway"];
	[activeAlert removeObserver:self forKeyPath:@"bounceDockIcon"];
	[activeAlert removeObserver:self forKeyPath:@"bounceDockIconRepeatedly"];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if (object == self.activeAlert) {
		if (self.activeAlertPropertyChangedByUser) {
			self.activeAlertPropertyChangedByUser = NO;

			return;
		}

		LogToConsoleDebug("Reloading user interface because key %{public}@ changed remotely", keyPath);

		[self reload];
	}
}

- (void)updateAvailableSounds
{
	[self.alertSoundChoiceButton removeAllItems];

	self.alertSounds = [self availableSounds];

	[self.alertSounds enumerateObjectsUsingBlock:^(id alertSound, NSUInteger index, BOOL *stop) {
		if ([alertSound isKindOfClass:[NSString class]]) {
			NSMenuItem *item = [NSMenuItem new];

			item.title = alertSound;

			[self.alertSoundChoiceButton.menu addItem:item];
		} else {
			[self.alertSoundChoiceButton.menu addItem:alertSound];
		}
	}];

	[self.alertSoundChoiceButton selectItemAtIndex:0];
}

- (NSArray *)availableSounds
{
	NSMutableArray *sounds = [NSMutableArray array];

	[sounds addObject:[TLONotificationConfiguration localizedAlertDefaultSoundTitle]];
	[sounds addObject:[NSMenuItem separatorItem]];
	[sounds addObject:[TLONotificationConfiguration localizedAlertNoSoundTitle]];
	[sounds addObject:[NSMenuItem separatorItem]];

	[sounds addObjectsFromArray:[TLOSoundPlayer uniqueListOfSounds]];

	return [sounds copy];
}

@end

NS_ASSUME_NONNULL_END
