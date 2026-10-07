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

#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "NSViewHelper.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCISupportInfo.h"
#import "TPCPreferencesLocal.h"
#import "TLOLocalization.h"
#import "TVCLogControllerInlineMediaServicePrivate.h"
#import "TVCNotificationConfigurationViewControllerPrivate.h"
#import "TVCValidatedTextField.h"
#import "TDCAlert.h"
#import "TDCChannelPropertiesNotificationConfigurationPrivate.h"
#import "TDCChannelPropertiesSheetInternal.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TDCChannelPropertiesSheetSelection)
{
	TDCChannelPropertiesSheetSelectionGeneral = 0,
	TDCChannelPropertiesSheetSelectionDefaults = 1,
	TDCChannelPropertiesSheetSelectionNotifications = 2
};

@interface TDCChannelPropertiesSheet () <NSControlTextEditingDelegate>
@property (nonatomic, strong, readwrite, nullable) IRCClient *client;
@property (nonatomic, strong, readwrite, nullable) IRCChannel *channel;
@property (nonatomic, copy, readwrite, nullable) NSString *clientId;
@property (nonatomic, copy, readwrite, nullable) NSString *channelId;
@property (nonatomic, assign) BOOL isNewConfiguration;
@property (nonatomic, assign) BOOL secretKeyLengthAlertDisplayed;
@property (nonatomic, copy) NSArray *navigationTree;
@property (nonatomic, weak) IBOutlet NSButton *autoJoinCheck;
@property (nonatomic, weak) IBOutlet NSButton *disableInlineMediaCheck;
@property (nonatomic, weak) IBOutlet NSButton *enableInlineMediaCheck;
@property (nonatomic, weak) IBOutlet NSButton *pushNotificationsCheck;
@property (nonatomic, weak) IBOutlet NSButton *showTreeBadgeCountCheck;
@property (nonatomic, weak) IBOutlet NSButton *ignoreHighlightsCheck;
@property (nonatomic, weak) IBOutlet NSButton *ignoreGeneralEventMessagesCheck;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *contentViewTabView;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *channelNameTextField;
@property (nonatomic, weak) IBOutlet NSTextField *labelTextField;
@property (nonatomic, weak) IBOutlet NSTextField *defaultModesTextField;
@property (nonatomic, weak) IBOutlet NSTextField *defaultTopicTextField;
@property (nonatomic, weak) IBOutlet NSTextField *secretKeyTextField;
@property (nonatomic, strong) IBOutlet NSView *contentView;
@property (nonatomic, strong) IBOutlet NSView *contentViewDefaultsView;
@property (nonatomic, strong) IBOutlet NSView *contentViewGeneralView;
@property (nonatomic, strong) IBOutlet NSView *contentViewNotifications;
@property (nonatomic, strong) IBOutlet NSView *contentViewNotificationsHost;
@property (nonatomic, strong) IBOutlet TVCNotificationConfigurationViewController *notificationsController;

- (IBAction)onMenuBarItemChanged:(id)sender;

- (IBAction)onInlineMediaCheckChanged:(id)sender;
- (IBAction)onPushNotificationsCheckChanged:(id)sender;
@end

@implementation TDCChannelPropertiesSheet

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)initWithWindow:(nullable NSWindow *)window
{
	if ((self = [super initWithWindow:window])) {
		self.config = [IRCChannelConfigMutable new];

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

- (instancetype)initWithClient:(IRCClient *)client
{
	return [self initWithConfig:nil onClient:client];
}

- (instancetype)initWithClientId:(NSString *)clientId
{
	return [self initWithConfig:nil onClientWithId:clientId];
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super initWithWindow:nil])) {
		self.client = channel.associatedClient;
		self.clientId = channel.associatedClient.uniqueIdentifier;

		self.channel = channel;
		self.channelId = channel.uniqueIdentifier;

		if (channel) {
			self.config = [channel.config mutableCopy];
		} else {
			self.config = [IRCChannelConfigMutable new];
		}

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (instancetype)initWithConfig:(nullable IRCChannelConfig *)config
{
	return [self initWithConfig:config onClientWithId:nil];
}

- (instancetype)initWithConfig:(nullable IRCChannelConfig *)config onClient:(nullable IRCClient *)client
{
	if ((self = [super initWithWindow:nil])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		if (config) {
			self.config = [config mutableCopy];
		} else {
			self.config = [IRCChannelConfigMutable new];
		}

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (instancetype)initWithConfig:(nullable IRCChannelConfig *)config onClientWithId:(nullable NSString *)clientId
{
	if ((self = [self initWithWindow:nil])) {
		self.clientId = clientId;

		if (config) {
			self.config = [config mutableCopy];
		} else {
			self.config = [IRCChannelConfigMutable new];
		}

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCChannelPropertiesSheet" owner:self topLevelObjects:nil];

	self.navigationTree = @[
		//		view								first responder
		@[self.contentViewGeneralView,			self.channelNameTextField],
		@[self.contentViewDefaultsView,			self.defaultTopicTextField],
		@[self.contentViewNotifications,		[NSNull null]],
	];

	self.channelNameTextField.stringValueIsInvalidOnEmpty = YES;
	self.channelNameTextField.stringValueUsesOnlyFirstToken = YES;

	self.channelNameTextField.textDidChangeCallback = self;

	self.channelNameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isChannelName == NO) {
			return TXTLS(@"TDCChannelPropertiesSheet[1nd-7x]");
		}

		return nil;
	};

	[self addConfigurationDidChangeObserver];

	[self setupNotificationsController];
}

- (void)setupNotificationsController
{
	self.notificationsController.allowsMixedState = YES;

	NSMutableArray *notifications = [NSMutableArray array];

	[notifications addObject:[[TDCChannelPropertiesNotificationConfiguration alloc] initWithEventType:TXNotificationTypeHighlight inSheet:self]];
	[notifications addObject:@" "];
	[notifications addObject:[[TDCChannelPropertiesNotificationConfiguration alloc] initWithEventType:TXNotificationTypeChannelMessage inSheet:self]];
	[notifications addObject:[[TDCChannelPropertiesNotificationConfiguration alloc] initWithEventType:TXNotificationTypeChannelNotice inSheet:self]];
	[notifications addObject:@" "];
	[notifications addObject:[[TDCChannelPropertiesNotificationConfiguration alloc] initWithEventType:TXNotificationTypeUserJoined inSheet:self]];
	[notifications addObject:[[TDCChannelPropertiesNotificationConfiguration alloc] initWithEventType:TXNotificationTypeUserParted inSheet:self]];

	self.notificationsController.notifications = notifications;

	[self.notificationsController attachToView:self.contentViewNotificationsHost];
}

- (void)reloadNotificationsController
{
	[self.notificationsController reload];
}

- (void)updateNavigationEnabledState
{
	[self.contentViewTabView setEnabled:(self.pushNotificationsCheck.state == NSControlStateValueOn)
							 forSegment:TDCChannelPropertiesSheetSelectionNotifications];
}

- (void)loadConfig
{
	self.channelNameTextField.stringValue = self.config.channelName;
	self.channelNameTextField.editable = (self.config.channelName.length == 0);

	self.labelTextField.stringValue = self.config.label;

	self.defaultModesTextField.stringValue = self.config.defaultModes;
	self.defaultTopicTextField.stringValue = self.config.defaultTopic;

	self.secretKeyTextField.stringValue = self.config.secretKey;

	self.autoJoinCheck.state = self.config.autoJoin;
	self.pushNotificationsCheck.state = self.config.pushNotifications;
	self.showTreeBadgeCountCheck.state = self.config.showTreeBadgeCount;

	self.ignoreGeneralEventMessagesCheck.state = self.config.ignoreGeneralEventMessages;
	self.ignoreHighlightsCheck.state = self.config.ignoreHighlights;

	self.disableInlineMediaCheck.state = self.config.inlineMediaDisabled;
	self.enableInlineMediaCheck.state = self.config.inlineMediaEnabled;

	[self updateNavigationEnabledState];
}

- (void)onMenuBarItemChanged:(id)sender
{
	[self _navigateToSelection:[sender indexOfSelectedItem]];
}

- (void)navigateToSelection:(TDCChannelPropertiesSheetSelection)selection
{
	if (self.contentViewTabView.indexOfSelectedItem == selection) {
		return;
	}

	[self.contentViewTabView selectSegmentWithTag:selection];

	[self _navigateToSelection:selection];
}

- (void)_navigateToSelection:(TDCChannelPropertiesSheetSelection)selection
{
	[self selectPane:self.navigationTree[selection][0]];

	id firstResponder = self.navigationTree[selection][1];

	if ([firstResponder isKindOfClass:[NSControl class]]) {
		[self.sheet makeFirstResponder:firstResponder];
	}
}

- (void)selectPane:(NSView *)view
{
	[self.contentView replaceFirstSubview:view];
}

- (void)start
{
	[self startSheet];

	[self _navigateToSelection:TDCChannelPropertiesSheetSelectionGeneral];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if (aNotification.object == self.secretKeyTextField) {
		[self updateSecretKeyLengthAlert];
	}
}

- (void)updateSecretKeyLengthAlert
{
	NSUInteger maximumKeyLength = self.client.supportInfo.maximumKeyLength;

	if (maximumKeyLength == 0) {
		return;
	}

	NSUInteger currentKeyLength = self.secretKeyTextField.stringValue.length;

	if (currentKeyLength <= maximumKeyLength) {
		return;
	}

	if (self.secretKeyLengthAlertDisplayed == NO) {
		self.secretKeyLengthAlertDisplayed = YES;
	} else {
		return;
	}

	[TDCAlert alertSheetWithWindow:self.sheet
							  body:TXTLS(@"TDCChannelPropertiesSheet[op4-gg]")
							 title:TXTLS(@"TDCChannelPropertiesSheet[zf2-r7]", self.client.networkNameAlt, maximumKeyLength)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil
					suppressionKey:@"maximum_secret_key_length"
				   suppressionText:nil
				   completionBlock:nil];
}

- (void)addConfigurationDidChangeObserver
{
	if (self.channel == nil) {
		return;
	}

	[RZNotificationCenter() addObserver:self
							   selector:@selector(underlyingConfigurationChanged:)
								   name:IRCChannelConfigurationWasUpdatedNotification
								 object:self.channel];
}

- (void)removeConfigurationDidChangeObserver
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)underlyingConfigurationChanged:(NSNotification *)notification
{
	IRCChannel *channel = notification.object;

	NSWindow *window = self.sheet;
	
	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCChannelPropertiesSheet[qby-hi]")
							 title:TXTLS(@"TDCChannelPropertiesSheet[mvl-r5]")
					 defaultButton:TXTLS(@"Prompts[mvh-ms]")
				   alternateButton:TXTLS(@"Prompts[99q-gg]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked != TDCAlertResponseDefault) {
						   return;
					   }
					   
					   [self close];
					   
					   self.config = [channel.config copy];
					   
					   [self loadConfig];
					   
					   [self reloadNotificationsController];
					   
					   [self start];
				   }];
}

- (void)onInlineMediaCheckChanged:(id)sender
{
	if (self.enableInlineMediaCheck.state != NSControlStateValueOn) {
		return;
	}

	[TVCLogControllerInlineMediaService askPermissionToEnableInlineMediaWithCompletionBlock:^(BOOL granted) {
		if (granted == NO) {
			self.enableInlineMediaCheck.state = NSControlStateValueOff;
		}
	}];
}

- (void)onPushNotificationsCheckChanged:(id)sender
{
	[self updateNavigationEnabledState];
}

#pragma mark -
#pragma mark Actions

- (void)cancel:(id)sender
{
	[self removeConfigurationDidChangeObserver];

	[super cancel:sender];
}

- (void)ok:(id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	[self removeConfigurationDidChangeObserver];

	self.config.channelName = self.channelNameTextField.value;

	self.config.label = self.labelTextField.trimmedStringValue;

	self.config.defaultModes = self.defaultModesTextField.trimmedStringValue;
	self.config.defaultTopic = self.defaultTopicTextField.trimmedStringValue;

	self.config.secretKey = self.secretKeyTextField.trimmedFirstTokenStringValue;

	self.config.autoJoin = self.autoJoinCheck.state;
	self.config.pushNotifications = self.pushNotificationsCheck.state;
	self.config.showTreeBadgeCount = self.showTreeBadgeCountCheck.state;

	self.config.ignoreGeneralEventMessages = self.ignoreGeneralEventMessagesCheck.state;
	self.config.ignoreHighlights = self.ignoreHighlightsCheck.state;

	self.config.inlineMediaDisabled = self.disableInlineMediaCheck.state;
	self.config.inlineMediaEnabled = self.enableInlineMediaCheck.state;

	if ([self.delegate respondsToSelector:@selector(channelPropertiesSheet:onOk:)]) {
		[self.delegate channelPropertiesSheet:self onOk:[self.config copy]];
	}

	[super ok:nil];
}

- (BOOL)okOrError
{
	return [self okOrErrorForTextField:self.channelNameTextField inSelection:TDCChannelPropertiesSheetSelectionGeneral];
}

- (BOOL)okOrErrorForTextField:(TVCValidatedTextField *)textField inSelection:(TDCChannelPropertiesSheetSelection)selection
{
	if (textField.valueIsValid) {
		return YES;
	}

	[self navigateToSelection:selection];

	/* Give navigation time to settle before trying to attach popover */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[textField showValidationErrorPopover];
	});

	return NO;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.sheet makeFirstResponder:nil];

	if ([self.delegate respondsToSelector:@selector(channelPropertiesSheetWillClose:)]) {
		[self.delegate channelPropertiesSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
