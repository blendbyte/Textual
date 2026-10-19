/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "NSStringHelper.h"
#import "IRCClientConfigPrivate.h"
#import "TLOLocalization.h"
#import "TLOMessageArchivePrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCValidatedTextField.h"
#import "TDCAlert.h"
#import "TDCServerPropertiesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark Connect Commands

@interface TDCServerPropertiesConnectCommandsPane ()
@property (nonatomic, unsafe_unretained) IBOutlet NSTextView *connectCommandsField;
@property (nonatomic, weak) IBOutlet NSButton *setInvisibleModeOnConnectCheck;
@end

@implementation TDCServerPropertiesConnectCommandsPane

- (void)prepareInitialState
{
	/* Connect commands text box better font */
	self.connectCommandsField.font = [NSFont systemFontOfSize:13.0];

	self.connectCommandsField.textContainerInset = NSMakeSize(1, 3);
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	self.connectCommandsField.string = [config.loginCommands componentsJoinedByString:@"\n"];

	self.setInvisibleModeOnConnectCheck.state = config.setInvisibleModeOnConnect;
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	NSArray *connectCommands = [self.connectCommandsField.string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	config.loginCommands = [connectCommands arrayByRemovingEmptyValues:YES trimming:YES uniquing:NO];

	config.setInvisibleModeOnConnect = (self.setInvisibleModeOnConnectCheck.state == NSControlStateValueOn);
}

@end

#pragma mark -
#pragma mark Encoding

@interface TDCServerPropertiesEncodingPane ()
@property (nonatomic, weak) IBOutlet NSPopUpButton *primaryEncodingButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *fallbackEncodingButton;
@property (nonatomic, copy) NSDictionary *encodingList;

- (IBAction)toggleAdvancedEncodings:(nullable id)sender;
@end

@implementation TDCServerPropertiesEncodingPane

- (void)prepareInitialState
{
	[self populateEncodings];
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	NSString *primaryEncodingTitle = [self.encodingList firstKeyForObject:@(config.primaryEncoding)];

	[self.primaryEncodingButton selectItemWithTitle:primaryEncodingTitle];

	NSString *fallbackEncodingTitle = [self.encodingList firstKeyForObject:@(config.fallbackEncoding)];

	[self.fallbackEncodingButton selectItemWithTitle:fallbackEncodingTitle];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.primaryEncoding = [self.encodingList unsignedIntegerForKey:self.primaryEncodingButton.title];

	config.fallbackEncoding = [self.encodingList unsignedIntegerForKey:self.fallbackEncodingButton.title];
}

- (void)populateEncodings
{
	[self.primaryEncodingButton removeAllItems];

	[self.fallbackEncodingButton removeAllItems];

	/* Build list of encodings */
	self.encodingList = [NSString supportedStringEncodingsWithTitle:NO];

	NSArray *encodingNames = self.encodingList.sortedDictionaryKeys;

	/* What we are basically doing now is sorting all the encodings, then removing
	 UTF-8 from the sorted list and inserting it at the top of the list. */
	NSString *utf8title = [NSString localizedNameOfStringEncoding:NSUTF8StringEncoding];

	NSMutableArray *encodingsToAdd = [encodingNames mutableCopy];

	[encodingsToAdd removeObject:utf8title];

	[self.primaryEncodingButton addItemWithTitle:utf8title];

	[self.fallbackEncodingButton addItemWithTitle:utf8title];

	/* Add the encodings to the popup list. This for loop will find the first
	 parentheses opening and compare everything before it to the one found for
	 the previous encoding. If the prefix has changed, then a separator is
	 inserted. This groups the encodings.*/
	/* We do this two times. The first time setups up preferred encodings at
	 the top of the list. The next handles everything else. */
	NSArray *favoredEncodings = @[@"Unicode", @"Western", @"Central European"];

	[self populateEncodingPopup:encodingsToAdd preferredEncodings:favoredEncodings ignoreFavored:NO];

	if ([RZUserDefaults() boolForKey:@"Server Properties Window Sheet -> Include Advanced Encodings"]) {
		[self populateEncodingPopup:encodingsToAdd preferredEncodings:favoredEncodings ignoreFavored:YES];
	}
}

- (void)populateEncodingPopup:(NSArray<NSString *> *)encodingsToAdd preferredEncodings:(NSArray<NSString *> *)favoredEncodings ignoreFavored:(BOOL)ignoreFavored
{
	NSString *encodingPrefixPrevious = nil;

	for (NSString *encoding in encodingsToAdd) {
		NSInteger parenthesisPosition = [encoding stringPosition:@" ("];

		if (parenthesisPosition <= 0) {
			continue;
		}

		NSString *encodingPrefix = [encoding substringToIndex:parenthesisPosition];

		if (ignoreFavored && [favoredEncodings containsObject:encodingPrefix]) {
			continue;
		} else if (ignoreFavored == NO && [favoredEncodings containsObject:encodingPrefix] == NO) {
			continue;
		}

		if (encodingPrefixPrevious == nil || [encodingPrefix isEqualToString:encodingPrefixPrevious] == NO) {
			encodingPrefixPrevious = encodingPrefix;

			[self.primaryEncodingButton.menu addItem:[NSMenuItem separatorItem]];

			[self.fallbackEncodingButton.menu addItem:[NSMenuItem separatorItem]];
		}

		[self.primaryEncodingButton addItemWithTitle:encoding];

		[self.fallbackEncodingButton addItemWithTitle:encoding];
	}
}

- (void)toggleAdvancedEncodings:(nullable id)sender
{
	NSString *primaryEncoding = self.primaryEncodingButton.titleOfSelectedItem;

	NSString *fallbackEncoding = self.fallbackEncodingButton.titleOfSelectedItem;

	[self populateEncodings];

	NSMenuItem *primaryEncodingItem = nil;

	if (primaryEncoding) {
		primaryEncodingItem = [self.primaryEncodingButton itemWithTitle:primaryEncoding];
	}

	if (primaryEncodingItem == nil) {
		primaryEncoding = [NSString localizedNameOfStringEncoding:TXDefaultPrimaryStringEncoding];
	}

	NSMenuItem *fallbackEncodingItem = nil;

	if (fallbackEncoding) {
		fallbackEncodingItem = [self.fallbackEncodingButton itemWithTitle:fallbackEncoding];
	}

	if (fallbackEncodingItem == nil) {
		fallbackEncoding = [NSString localizedNameOfStringEncoding:TXDefaultFallbackStringEncoding];
	}

	[self.primaryEncodingButton selectItemWithTitle:primaryEncoding];

	[self.fallbackEncodingButton selectItemWithTitle:fallbackEncoding];
}

@end

#pragma mark -
#pragma mark Messages

@interface TDCServerPropertiesMessagesPane ()
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *normalLeavingCommentTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *sleepModeQuitMessageTextField;
@property (nonatomic, strong) NSButton *keepInArchiveCheck;
@property (nonatomic, strong) NSButton *deleteArchivedMessagesButton;
@property (nonatomic, copy, nullable) NSString *serverId;
@property (nonatomic, copy, nullable) NSString *serverName;
@end

@implementation TDCServerPropertiesMessagesPane

- (void)prepareInitialState
{
	NSString *(^validationBlock)(NSString *) = ^NSString *(NSString *currentValue) {
		if ([currentValue containsCharactersFromCharacterSet:[NSCharacterSet newlineCharacterSet]]) {
			return TXTLS(@"CommonErrors[gas-v8]");
		}

		if (currentValue.length > 390) {
			return TXTLS(@"CommonErrors[2cb-af]", 390);
		}

		return nil;
	};

	for (TVCValidatedTextField *textField in @[self.normalLeavingCommentTextField, self.sleepModeQuitMessageTextField]) {
		textField.stringValueIsInvalidOnEmpty = NO;
		textField.stringValueIsTrimmed = YES;
		textField.stringValueUsesOnlyFirstToken = NO;

		textField.validationBlock = validationBlock;
	}

	[self addArchiveRows];
}

/* The message archive: below the messages, which move up for it */
- (void)addArchiveRows
{
	NSView *view = self.view;

	NSView *lastField = self.sleepModeQuitMessageTextField;

	for (NSLayoutConstraint *constraint in view.constraints) {
		if (constraint.firstAttribute == NSLayoutAttributeTop && constraint.secondItem == view && constraint.constant == 60) {
			constraint.constant = 30;
		}
	}

	NSButton *keepInArchiveCheck = [NSButton checkboxWithTitle:TXTLS(@"TDCServerPropertiesSheet[arc-c1]") target:self action:@selector(keepInArchiveChanged:)];

	NSButton *deleteButton = [NSButton buttonWithTitle:TXTLS(@"TDCServerPropertiesSheet[arc-b1]") target:self action:@selector(deleteArchivedMessages:)];

	keepInArchiveCheck.translatesAutoresizingMaskIntoConstraints = NO;
	deleteButton.translatesAutoresizingMaskIntoConstraints = NO;

	[view addSubview:keepInArchiveCheck];
	[view addSubview:deleteButton];

	[NSLayoutConstraint activateConstraints:@[
		[keepInArchiveCheck.topAnchor constraintEqualToAnchor:lastField.bottomAnchor constant:20],
		[keepInArchiveCheck.leadingAnchor constraintEqualToAnchor:lastField.leadingAnchor],
		[deleteButton.topAnchor constraintEqualToAnchor:keepInArchiveCheck.bottomAnchor constant:8],
		[deleteButton.leadingAnchor constraintEqualToAnchor:lastField.leadingAnchor constant:14]
	]];

	self.keepInArchiveCheck = keepInArchiveCheck;
	self.deleteArchivedMessagesButton = deleteButton;
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	self.normalLeavingCommentTextField.stringValue = config.normalLeavingComment;

	self.sleepModeQuitMessageTextField.stringValue = config.sleepModeLeavingComment;

	self.keepInArchiveCheck.state = ((config.excludedFromArchive) ? NSControlStateValueOff : NSControlStateValueOn);

	self.serverId = config.uniqueIdentifier;
	self.serverName = config.connectionName;

	[self updateArchiveControls];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.normalLeavingComment = self.normalLeavingCommentTextField.value;

	config.sleepModeLeavingComment = self.sleepModeQuitMessageTextField.value;

	config.excludedFromArchive = (self.keepInArchiveCheck.state == NSControlStateValueOff);
}

- (void)keepInArchiveChanged:(nullable id)sender
{
	[self updateArchiveControls];
}

/* While the archive is off there's nothing to leave out; the delete button
 when it has this server's messages */
- (void)updateArchiveControls
{
	self.keepInArchiveCheck.enabled = ([TPCPreferences messageArchiveKeepPeriod] != TPCMessageArchiveKeepPeriodOff);

	self.deleteArchivedMessagesButton.enabled = NO;

	NSString *serverId = self.serverId;

	if (serverId == nil) {
		return;
	}

	[sharedMessageArchive() countMessagesOfServer:serverId inView:nil completionHandler:^(NSUInteger count) {
		self.deleteArchivedMessagesButton.enabled = (count > 0);
	}];
}

- (void)deleteArchivedMessages:(nullable id)sender
{
	NSString *serverId = self.serverId;

	if (serverId == nil) {
		return;
	}

	[sharedMessageArchive() countMessagesOfServer:serverId inView:nil completionHandler:^(NSUInteger count) {
		NSAlert *alert = [NSAlert new];

		alert.alertStyle = NSAlertStyleWarning;
		alert.messageText = TXTLS(@"TDCServerPropertiesSheet[arc-d1]", self.serverName);
		alert.informativeText = TXTLS(@"TDCServerPropertiesSheet[arc-d2]", [NSNumberFormatter localizedStringFromNumber:@(count) numberStyle:NSNumberFormatterDecimalStyle]);

		[alert addButtonWithTitle:TXTLS(@"TDCServerPropertiesSheet[arc-d3]")];
		[alert addButtonWithTitle:TXTLS(@"Prompts[qso-2g]")];

		alert.buttons.firstObject.hasDestructiveAction = YES;

		[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
			if (response != NSAlertFirstButtonReturn) {
				return;
			}

			[sharedMessageArchive() deleteMessagesOfServer:serverId inView:nil completionHandler:^{
				[self updateArchiveControls];
			}];
		}];
	}];
}

- (nullable NSControl *)firstInvalidField
{
	if (self.normalLeavingCommentTextField.valueIsValid == NO) {
		return self.normalLeavingCommentTextField;
	} else if (self.sleepModeQuitMessageTextField.valueIsValid == NO) {
		return self.sleepModeQuitMessageTextField;
	}

	return nil;
}

@end

#pragma mark -
#pragma mark ZNC Bouncer

@interface TDCServerPropertiesZncBouncerPane ()
@property (nonatomic, weak) IBOutlet NSButton *zncIgnoreConfiguredAutojoinCheck;
@property (nonatomic, weak) IBOutlet NSButton *zncIgnorePlaybackNotificationsCheck;
@property (nonatomic, weak) IBOutlet NSButton *zncOnlyPlaybackLatestCheck;
@end

@implementation TDCServerPropertiesZncBouncerPane

- (void)loadFromConfig:(IRCClientConfig *)config
{
	self.zncIgnoreConfiguredAutojoinCheck.state = config.zncIgnoreConfiguredAutojoin;
	self.zncIgnorePlaybackNotificationsCheck.state = config.zncIgnorePlaybackNotifications;
	self.zncOnlyPlaybackLatestCheck.state = config.zncOnlyPlaybackLatest;
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.zncIgnoreConfiguredAutojoin = (self.zncIgnoreConfiguredAutojoinCheck.state == NSControlStateValueOn);
	config.zncIgnorePlaybackNotifications = (self.zncIgnorePlaybackNotificationsCheck.state == NSControlStateValueOn);
	config.zncOnlyPlaybackLatest = (self.zncOnlyPlaybackLatestCheck.state == NSControlStateValueOn);
}

@end

#pragma mark -
#pragma mark Flood Control

@interface TDCServerPropertiesFloodControlPane ()
@property (nonatomic, weak) IBOutlet NSSlider *floodControlDelayTimerSlider;
@property (nonatomic, weak) IBOutlet NSSlider *floodControlMessageCountSlider;

/* The sliders and their labels are bound to these */
@property (nonatomic, assign) NSUInteger floodControlDelayTimerSliderTempValue;
@property (nonatomic, assign) NSUInteger floodControlMessageCountSliderTempValue;
@end

@implementation TDCServerPropertiesFloodControlPane

- (void)loadFromConfig:(IRCClientConfig *)config
{
	self.floodControlDelayTimerSliderTempValue = config.floodControlDelayTimerInterval;
	self.floodControlMessageCountSliderTempValue = config.floodControlMaximumMessages;
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.floodControlMaximumMessages = self.floodControlMessageCountSlider.integerValue;
	config.floodControlDelayTimerInterval = self.floodControlDelayTimerSlider.integerValue;
}

@end

#pragma mark -
#pragma mark Network Socket

@interface TDCServerPropertiesNetworkSocketPane ()
@property (nonatomic, weak) IBOutlet NSButton *connectionDefaultAddressTypeCheck;
@property (nonatomic, weak) IBOutlet NSButton *connectionIPv4AddressTypeCheck;
@property (nonatomic, weak) IBOutlet NSButton *connectionIPv6AddressTypeCheck;
@property (nonatomic, weak) IBOutlet NSButton *pongTimerCheck;
@property (nonatomic, weak) IBOutlet NSButton *performDisconnectOnPongTimerCheck;
@property (nonatomic, weak) IBOutlet NSButton *disconnectOnReachabilityChangeCheck;
@property (nonatomic, weak) IBOutlet NSButton *validateServerCertificateChainCheck;
@property (nonatomic, weak) IBOutlet NSPopUpButton *preferredCipherSuitesButton;
@property (nonatomic, weak) IBOutlet NSButton *viewListOfPreferredCipherSuitesButton;

/* Only saved when chosen: saving it also forgets the old "prefers IPv4" setting */
@property (nonatomic, assign) IRCConnectionAddressType addressType;
@property (nonatomic, assign) BOOL addressTypeChanged;

- (IBAction)preferredInternetProtocolChanged:(nullable id)sender;
- (IBAction)preferredCipherSuitesChanged:(nullable id)sender;
- (IBAction)preferredCipherSuitesViewList:(nullable id)sender;
@end

@implementation TDCServerPropertiesNetworkSocketPane

- (void)loadFromConfig:(IRCClientConfig *)config
{
	IRCConnectionAddressType addressType = config.addressType;

	self.addressType = addressType;

	self.connectionIPv4AddressTypeCheck.state = (addressType == IRCConnectionAddressTypeIPv4);
	self.connectionIPv6AddressTypeCheck.state = (addressType == IRCConnectionAddressTypeIPv6);
	self.connectionDefaultAddressTypeCheck.state = (addressType == IRCConnectionAddressTypeDefault);

	self.pongTimerCheck.state = config.performPongTimer;
	self.performDisconnectOnPongTimerCheck.state = config.performDisconnectOnPongTimer;

	self.disconnectOnReachabilityChangeCheck.state = config.performDisconnectOnReachabilityChange;

	self.validateServerCertificateChainCheck.state = config.validateServerCertificateChain;

	[self.preferredCipherSuitesButton selectItemWithTag:config.cipherSuites];

	[self preferredCipherSuitesChanged:nil];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	if (self.addressTypeChanged) {
TEXTUAL_IGNORE_DEPRECATION_BEGIN
		/* Changing the property triggers a deprecation log to console
		 which is just unnecessary output when it isn't set. */
		if (config.connectionPrefersIPv4) {
			config.connectionPrefersIPv4 = NO;
		}
TEXTUAL_IGNORE_DEPRECATION_END

		config.addressType = self.addressType;
	}

	config.performPongTimer = (self.pongTimerCheck.state == NSControlStateValueOn);
	config.performDisconnectOnPongTimer = (self.performDisconnectOnPongTimerCheck.state == NSControlStateValueOn);

	config.performDisconnectOnReachabilityChange = (self.disconnectOnReachabilityChangeCheck.state == NSControlStateValueOn);

	config.validateServerCertificateChain = (self.validateServerCertificateChainCheck.state == NSControlStateValueOn);

	config.cipherSuites = self.preferredCipherSuitesButton.selectedTag;
}

- (void)preferredInternetProtocolChanged:(nullable id)sender
{
	self.addressType = [sender tag];

	self.addressTypeChanged = YES;
}

- (void)preferredCipherSuitesChanged:(nullable id)sender
{
	NSInteger cipherSuites = self.preferredCipherSuitesButton.selectedTag;

	self.viewListOfPreferredCipherSuitesButton.enabled =
	(cipherSuites != RCMCipherSuiteCollectionNone);
}

- (void)preferredCipherSuitesViewList:(nullable id)sender
{
	NSInteger cipherSuites = self.preferredCipherSuitesButton.selectedTag;

	NSArray *cipherSuitesDescriptions = [RCMSecureTransport descriptionsForCipherListCollection:cipherSuites withProtocol:YES];

	NSString *cipherSuitesDescription = [cipherSuitesDescriptions componentsJoinedByString:@"\n"];

	NSString *cipherSuitesTitle = self.preferredCipherSuitesButton.titleOfSelectedItem;

	[TDCAlert alertSheetWithWindow:self.propertiesSheet.sheet
							  body:TXTLS(@"TDCServerPropertiesSheet[k50-8n]", cipherSuitesDescription)
							 title:TXTLS(@"TDCServerPropertiesSheet[yko-5g]", cipherSuitesTitle)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil];
}

@end

#pragma mark -
#pragma mark Proxy Server

@interface TDCServerPropertiesProxyServerPane ()
@property (nonatomic, weak) IBOutlet NSPopUpButton *proxyTypeButton;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *proxyAddressTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *proxyPortTextField;
@property (nonatomic, weak) IBOutlet NSTextField *proxyUsernameTextField;
@property (nonatomic, weak) IBOutlet NSTextField *proxyPasswordTextField;

/* One of them shows, depending on the type */
@property (nonatomic, strong) IBOutlet NSView *proxyServerInputView;
@property (nonatomic, strong) IBOutlet NSView *proxyServerSystemSocksView;
@property (nonatomic, strong) IBOutlet NSView *proxyServerTorBrowserView;

@property (readonly) BOOL proxyTypeTakesAddress;

- (IBAction)proxyTypeChanged:(nullable id)sender;
- (IBAction)openProxySettingsInSystemPreferences:(nullable id)sender;
@end

@implementation TDCServerPropertiesProxyServerPane

- (void)prepareInitialState
{
	/* Proxy address */
	self.proxyAddressTextField.stringValueIsInvalidOnEmpty = NO;
	self.proxyAddressTextField.stringValueIsTrimmed = YES;
	self.proxyAddressTextField.stringValueUsesOnlyFirstToken = YES;

	self.proxyAddressTextField.performValidationWhenEmpty = YES;

	/* Weak: the pane owns the fields that keep these blocks */
	__weak typeof(self) weakSelf = self;

	self.proxyAddressTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (weakSelf.proxyTypeTakesAddress && currentValue.isValidInternetAddress == NO) {
			return TXTLS(@"TDCServerPropertiesSheet[tlo-b6]");
		}

		return nil;
	};

	/* Proxy port */
	self.proxyPortTextField.stringValueIsInvalidOnEmpty = NO;
	self.proxyPortTextField.stringValueIsTrimmed = YES;
	self.proxyPortTextField.stringValueUsesOnlyFirstToken = NO;

	self.proxyPortTextField.performValidationWhenEmpty = YES;

	self.proxyPortTextField.defaultValue = [NSString stringWithUnsignedInteger:IRCConnectionDefaultProxyPort];

	self.proxyPortTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (weakSelf.proxyTypeTakesAddress && currentValue.isValidInternetPort == NO) {
			return TXTLS(@"CommonErrors[l0c-nb]");
		}

		return nil;
	};
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	[self.proxyTypeButton selectItemWithTag:config.proxyType];

	self.proxyAddressTextField.stringValue = (config.proxyAddress ?: @"");
	self.proxyPortTextField.integerValue = config.proxyPort;
	self.proxyUsernameTextField.stringValue = (config.proxyUsername ?: @"");
	self.proxyPasswordTextField.stringValue = (config.proxyPassword ?: @"");

	[self proxyTypeChanged:nil];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.proxyType = self.proxyTypeButton.selectedTag;

	config.proxyAddress = self.proxyAddressTextField.lowercaseValue;
	config.proxyPort = self.proxyPortTextField.integerValue;
	config.proxyUsername = self.proxyUsernameTextField.trimmedFirstTokenStringValue;
	config.proxyPassword = self.proxyPasswordTextField.trimmedStringValue;
}

- (nullable NSControl *)firstInvalidField
{
	if (self.proxyAddressTextField.valueIsValid == NO) {
		return self.proxyAddressTextField;
	} else if (self.proxyPortTextField.valueIsValid == NO) {
		return self.proxyPortTextField;
	}

	return nil;
}

/* SOCKS5 and HTTP(S) CONNECT proxies are given an address, a port and
 optionally a username and password */
- (BOOL)proxyTypeTakesAddress
{
	NSInteger proxyType = self.proxyTypeButton.selectedTag;

	return (proxyType == IRCConnectionProxyTypeSocks5 ||
			proxyType == IRCConnectionProxyTypeHTTP ||
			proxyType == IRCConnectionProxyTypeHTTPS);
}

- (void)proxyTypeChanged:(nullable id)sender
{
	NSInteger proxyType = self.proxyTypeButton.selectedTag;

	BOOL enabled = self.proxyTypeTakesAddress;

	self.proxyServerInputView.hidden = (enabled == NO);
	self.proxyServerTorBrowserView.hidden = (proxyType != IRCConnectionProxyTypeTor);
	self.proxyServerSystemSocksView.hidden = (proxyType != IRCConnectionProxyTypeAutomatic);

	self.proxyAddressTextField.enabled = enabled;
	self.proxyPortTextField.enabled = enabled;

	self.proxyUsernameTextField.enabled = enabled;
	self.proxyPasswordTextField.enabled = enabled;

	[self.proxyAddressTextField performValidation];
	[self.proxyPortTextField performValidation];
}

/* Opens Network → (current service) Details → Proxies */
- (void)openProxySettingsInSystemPreferences:(nullable id)sender
{
	NSURL *settingsURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.Network-Settings.extension?Proxies"];

	[RZWorkspace() openURL:settingsURL];
}

@end

NS_ASSUME_NONNULL_END
