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

#import <SecurityInterface/SFChooseIdentityPanel.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "NSStringHelper.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCNetworkList.h"
#import "IRCSASLECDSAPrivate.h"
#import "IRCServer.h"
#import "IRCStrictTransportSecurityPrivate.h"
#import "TLOKeychainPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TPCPreferencesLocal.h"
#import "TVCValidatedComboBox.h"
#import "TVCValidatedTextField.h"
#import "TDCAlert.h"
#import "TDCServerPropertiesPanePrivate.h"
#import "TXWebsiteLinks.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark General

@interface TDCServerPropertiesGeneralPane () <NSControlTextEditingDelegate>
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *connectionNameTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedComboBox *serverAddressComboBox;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *serverPortTextField;
@property (nonatomic, weak) IBOutlet NSButton *prefersSecuredConnectionCheck;
@property (nonatomic, weak) IBOutlet NSTextField *serverPasswordTextField;
@property (nonatomic, weak) IBOutlet NSButton *autoConnectCheck;
@property (nonatomic, weak) IBOutlet NSButton *autoReconnectCheck;
@property (nonatomic, weak) IBOutlet NSButton *autoDisconnectOnSleepCheck;
@property (nonatomic, strong) IRCNetworkList *networkList;
@property (nonatomic, copy, readwrite) NSArray<IRCServer *> *serverList;
@property (nonatomic, strong, nullable) TDCServerEndpointListSheet *serverEndpointSheet;
@property (nonatomic, assign) BOOL populatingPrimaryServer;
@property (nonatomic, copy, nullable) NSString *lastServerAddressValue;
@property (nonatomic, copy, nullable) IRCServer *previousPrimaryServer;
@property (nonatomic, strong, nullable) NSGridRow *strictTransportSecurityRow;
@property (nonatomic, strong, nullable) NSTextField *strictTransportSecurityField;
@property (nonatomic, copy, nullable) NSData *customIcon;
@property (nonatomic, strong, nullable) NSImageView *iconWell;
@property (nonatomic, strong, nullable) NSButton *iconRemoveButton;
@property (nonatomic, strong, nullable) NSTextField *iconNoteField;

- (IBAction)useSSLCheckChanged:(nullable id)sender;
@end

@implementation TDCServerPropertiesGeneralPane

- (void)prepareInitialState
{
	self.serverList = @[];

	/* Populate server list combo box */
	self.networkList = [IRCNetworkList new];

	for (IRCNetwork *network in self.networkList.listOfNetworks) {
		[self.serverAddressComboBox addItemWithObjectValue:network.networkName];
	}

	/* Connection name */
	self.connectionNameTextField.stringValueIsInvalidOnEmpty = YES;
	self.connectionNameTextField.stringValueIsTrimmed = YES;
	self.connectionNameTextField.stringValueUsesOnlyFirstToken = NO;

	self.connectionNameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([currentValue containsCharactersFromCharacterSet:[NSCharacterSet newlineCharacterSet]]) {
			return TXTLS(@"CommonErrors[gas-v8]");
		}

		return nil;
	};

	/* Server address */
	self.serverAddressComboBox.textDidChangeCallback = self;

	self.serverAddressComboBox.stringValueIsInvalidOnEmpty = YES;
	self.serverAddressComboBox.stringValueIsTrimmed = YES;
	self.serverAddressComboBox.stringValueUsesOnlyFirstToken = YES;

	self.serverAddressComboBox.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isValidInternetAddress == NO) {
			return TXTLS(@"CommonErrors[yyx-l3]");
		}

		return nil;
	};

	/* Server port */
	self.serverPortTextField.textDidChangeCallback = self;

	self.serverPortTextField.stringValueIsInvalidOnEmpty = YES;
	self.serverPortTextField.stringValueIsTrimmed = YES;
	self.serverPortTextField.stringValueUsesOnlyFirstToken = NO;

	self.serverPortTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isValidInternetPort == NO) {
			return TXTLS(@"CommonErrors[l0c-nb]");
		}

		return nil;
	};

	[self addStrictTransportSecurityRow];

	[self addIconRow];
}

#pragma mark -
#pragma mark Icon

/* Under the connection name: the icon in front of the server's name in the
 server list, chosen here (a file, or a picture dropped on the well) or else
 the network's own (draft/ICON) */
- (void)addIconRow
{
	NSView *nameRowView = self.connectionNameTextField;

	while (nameRowView.superview && [nameRowView.superview isKindOfClass:[NSGridView class]] == NO) {
		nameRowView = nameRowView.superview;
	}

	NSGridView *grid = (NSGridView *)nameRowView.superview;

	if (grid == nil) {
		return;
	}

	NSInteger nameRow = [grid indexOfRow:[grid cellForView:nameRowView].row];

	NSTextField *label = [NSTextField labelWithString:TXTLS(@"TDCServerPropertiesSheet[icn-l1]")];

	label.alignment = NSTextAlignmentRight;

	NSImageView *well = [NSImageView new];

	well.translatesAutoresizingMaskIntoConstraints = NO;

	well.imageFrameStyle = NSImageFrameGrayBezel;
	well.imageScaling = NSImageScaleProportionallyUpOrDown;
	well.editable = YES;

	well.target = self;
	well.action = @selector(iconWellChanged:);

	well.toolTip = TXTLS(@"TDCServerPropertiesSheet[icn-t1]");

	well.accessibilityLabel = TXTLS(@"TDCServerPropertiesSheet[icn-a1]");

	[well.widthAnchor constraintEqualToConstant:40].active = YES;
	[well.heightAnchor constraintEqualToConstant:40].active = YES;

	NSButton *chooseButton = [NSButton buttonWithTitle:TXTLS(@"TDCServerPropertiesSheet[icn-b1]") target:self action:@selector(chooseIcon:)];

	NSButton *removeButton = [NSButton buttonWithTitle:TXTLS(@"TDCServerPropertiesSheet[icn-b2]") target:self action:@selector(removeIcon:)];

	NSTextField *note = [NSTextField labelWithString:@""];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	NSStackView *buttons = [NSStackView stackViewWithViews:@[chooseButton, removeButton]];

	buttons.spacing = 8;

	NSStackView *column = [NSStackView stackViewWithViews:@[buttons, note]];

	column.orientation = NSUserInterfaceLayoutOrientationVertical;
	column.alignment = NSLayoutAttributeLeading;
	column.spacing = 4;

	NSStackView *stack = [NSStackView stackViewWithViews:@[well, column]];

	stack.alignment = NSLayoutAttributeCenterY;
	stack.spacing = 10;

	NSGridRow *row = [grid insertRowAtIndex:(nameRow + 1) withViews:@[label, stack]];

	row.rowAlignment = NSGridRowAlignmentNone;
	row.yPlacement = NSGridCellPlacementCenter;

	[row cellAtIndex:1].xPlacement = NSGridCellPlacementLeading;

	self.iconWell = well;
	self.iconRemoveButton = removeButton;
	self.iconNoteField = note;
}

/* The well shows what the server list will: the chosen icon, else the network's */
- (void)updateIconRow
{
	NSData *customIcon = self.customIcon;

	NSImage *icon = nil;

	NSString *note = nil;

	if (customIcon) {
		icon = [[NSImage alloc] initWithData:customIcon];

		note = TXTLS(@"TDCServerPropertiesSheet[icn-n1]");
	} else {
		icon = self.propertiesSheet.client.networkProvidedIcon;

		if (icon) {
			note = TXTLS(@"TDCServerPropertiesSheet[icn-n2]");
		} else {
			note = TXTLS(@"TDCServerPropertiesSheet[icn-n3]");
		}
	}

	self.iconWell.image = icon;

	self.iconNoteField.stringValue = note;

	self.iconRemoveButton.enabled = (customIcon != nil);
}

- (void)setCustomIconFromImageData:(NSData *)data fileName:(nullable NSString *)fileName
{
	NSParameterAssert(data != nil);

	NSData *iconData = [IRCClient customIconDataFromImageData:data];

	if (iconData) {
		self.customIcon = iconData;

		[self updateIconRow];

		return;
	}

	[self updateIconRow];

	if (fileName == nil) {
		NSBeep();

		return;
	}

	[TDCAlert alertSheetWithWindow:self.propertiesSheet.sheet
							  body:TXTLS(@"TDCServerPropertiesSheet[icn-e2]")
							 title:TXTLS(@"TDCServerPropertiesSheet[icn-e1]", fileName)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil];
}

- (void)chooseIcon:(nullable id)sender
{
	NSWindow *window = self.propertiesSheet.sheet;

	NSOpenPanel *panel = [NSOpenPanel openPanel];

	panel.canChooseDirectories = NO;
	panel.canChooseFiles = YES;
	panel.allowsMultipleSelection = NO;

	panel.allowedContentTypes = @[UTTypeImage];

	panel.message = TXTLS(@"TDCServerPropertiesSheet[icn-m1]");

	[panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
		NSURL *url = panel.URL;

		if (response != NSModalResponseOK || url == nil) {
			return;
		}

		/* After the panel is gone, so an alert can take its place */
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			NSData *data = [NSData dataWithContentsOfURL:url];

			[self setCustomIconFromImageData:((data) ?: [NSData data]) fileName:url.lastPathComponent];
		});
	}];
}

- (void)removeIcon:(nullable id)sender
{
	self.customIcon = nil;

	[self updateIconRow];
}

/* A picture dropped or pasted on the well, or the well emptied (Delete) */
- (void)iconWellChanged:(nullable id)sender
{
	NSImage *image = self.iconWell.image;

	NSData *data = image.TIFFRepresentation;

	if (data == nil) {
		[self removeIcon:nil];

		return;
	}

	[self setCustomIconFromImageData:data fileName:nil];
}

#pragma mark -
#pragma mark Strict Transport Security

/* 10.7 (from 9.4): under the port, whether a server told Textual to connect
 only securely and until when, with Forget (what /sts clear does) */
- (void)addStrictTransportSecurityRow
{
	NSView *portRowView = self.prefersSecuredConnectionCheck;

	while (portRowView.superview && [portRowView.superview isKindOfClass:[NSGridView class]] == NO) {
		portRowView = portRowView.superview;
	}

	NSGridView *grid = (NSGridView *)portRowView.superview;

	if (grid == nil) {
		return;
	}

	NSInteger portRow = [grid indexOfRow:[grid cellForView:portRowView].row];

	NSTextField *field = [NSTextField wrappingLabelWithString:@""];

	field.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	field.textColor = [NSColor secondaryLabelColor];

	[field.widthAnchor constraintLessThanOrEqualToConstant:300].active = YES;

	NSButton *forgetButton = [NSButton buttonWithTitle:TXTLS(@"TDCServerPropertiesSheet[sts-b1]") target:self action:@selector(forgetStrictTransportSecurity:)];

	forgetButton.controlSize = NSControlSizeSmall;
	forgetButton.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	NSStackView *stack = [NSStackView stackViewWithViews:@[field, forgetButton]];

	stack.alignment = NSLayoutAttributeFirstBaseline;
	stack.spacing = 8;

	NSGridRow *row = [grid insertRowAtIndex:(portRow + 1) withViews:@[[NSGridCell emptyContentView], stack]];

	[row cellAtIndex:1].xPlacement = NSGridCellPlacementLeading;

	row.hidden = YES;

	self.strictTransportSecurityRow = row;
	self.strictTransportSecurityField = field;
}

- (NSArray<NSString *> *)_serverHosts
{
	NSMutableOrderedSet<NSString *> *hosts = [NSMutableOrderedSet orderedSet];

	for (IRCServer *server in self.serverList) {
		NSString *host = server.serverAddress.lowercaseString;

		if (host.length > 0) {
			[hosts addObject:host];
		}
	}

	return hosts.array;
}

- (void)updateStrictTransportSecurityRow
{
	IRCStrictTransportSecurity *policies = [IRCStrictTransportSecurity sharedPolicies];

	NSDate *expiry = nil;
	uint16_t port = 0;

	for (NSString *host in [self _serverHosts]) {
		expiry = [policies expiryForHost:host];

		if (expiry) {
			port = [policies portForHost:host];

			break;
		}
	}

	self.strictTransportSecurityRow.hidden = (expiry == nil);

	if (expiry == nil) {
		return;
	}

	NSString *expiryString = [NSDateFormatter localizedStringFromDate:expiry dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];

	self.strictTransportSecurityField.stringValue = TXTLS(@"TDCServerPropertiesSheet[sts-l1]", port, expiryString);
}

- (void)forgetStrictTransportSecurity:(nullable id)sender
{
	IRCStrictTransportSecurity *policies = [IRCStrictTransportSecurity sharedPolicies];

	for (NSString *host in [self _serverHosts]) {
		[policies removePolicyForHost:host];
	}

	[self updateStrictTransportSecurityRow];
}

#pragma mark -

- (void)loadFromConfig:(IRCClientConfig *)config
{
	self.connectionNameTextField.stringValue = config.connectionName;

	self.autoConnectCheck.state = config.autoConnect;
	self.autoReconnectCheck.state = config.autoReconnect;
	self.autoDisconnectOnSleepCheck.state = config.autoSleepModeDisconnect;

	self.serverList = config.serverList;

	[self loadPrimaryServerEndpoint];

	NSData *customIcon = config.customIcon;

	self.customIcon = (([customIcon isKindOfClass:[NSData class]]) ? customIcon : nil);

	[self updateIconRow];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.connectionName = self.connectionNameTextField.value;

	config.autoConnect = (self.autoConnectCheck.state == NSControlStateValueOn);
	config.autoReconnect = (self.autoReconnectCheck.state == NSControlStateValueOn);
	config.autoSleepModeDisconnect = (self.autoDisconnectOnSleepCheck.state == NSControlStateValueOn);

	config.serverList = self.serverList;

	config.customIcon = self.customIcon;
}

- (nullable NSControl *)firstInvalidField
{
	if (self.connectionNameTextField.valueIsValid == NO) {
		return self.connectionNameTextField;
	} else if (self.serverAddressComboBox.valueIsValid == NO) {
		return self.serverAddressComboBox;
	} else if (self.serverPortTextField.valueIsValid == NO) {
		return self.serverPortTextField;
	}

	return nil;
}

- (void)closeChildSheets
{
	[self.serverEndpointSheet close];
}

#pragma mark -
#pragma mark Primary Server

- (void)loadPrimaryServerEndpoint
{
	IRCServer *server = self.serverList.firstObject;

	if (server == nil) {
		self.serverAddressComboBox.stringValue = @"";

		self.serverPortTextField.integerValue = IRCConnectionDefaultServerPort;

		self.prefersSecuredConnectionCheck.state = NSControlStateValueOff;

		self.serverPasswordTextField.stringValue = @"";

		return;
	}

	self.populatingPrimaryServer = YES;

	NSString *serverAddress = server.serverAddress;

	if (serverAddress) {
		IRCNetwork *serverAddressNetwork = [self.networkList networkWithServerAddress:serverAddress];

		if (serverAddressNetwork) {
			self.serverAddressComboBox.stringValue = serverAddressNetwork.networkName;
		} else {
			self.serverAddressComboBox.stringValue = serverAddress;
		}
	}

	self.serverPortTextField.integerValue = server.serverPort;

	self.prefersSecuredConnectionCheck.state = server.prefersSecuredConnection;

	self.serverPasswordTextField.stringValue = (server.serverPassword ?: @"");

	self.populatingPrimaryServer = NO;

	[self updateStrictTransportSecurityRow];
}

- (void)restorePreviousValuesForPrimaryServer
{
	IRCServer *previousServer = self.previousPrimaryServer;

	if (previousServer == nil) {
		return;
	}

	self.populatingPrimaryServer = YES;

	self.serverPortTextField.integerValue = previousServer.serverPort;

	self.prefersSecuredConnectionCheck.state = previousServer.prefersSecuredConnection;

	self.previousPrimaryServer = nil;

	self.populatingPrimaryServer = NO;
}

- (void)saveCurrentValuesForPrimaryServer
{
	/* Do not change the previous primary server between predefined servers. */
	if (self.previousPrimaryServer != nil) {
		return;
	}

	IRCServer *server = self.serverList.firstObject;

	if (server) {
		self.previousPrimaryServer = server;

		return;
	}

	IRCServerMutable *serverMutable = [IRCServerMutable new];

	serverMutable.serverPort = self.serverPortTextField.integerValue;

	serverMutable.prefersSecuredConnection = (self.prefersSecuredConnectionCheck.state == NSControlStateValueOn);

	self.previousPrimaryServer = serverMutable;
}

- (void)populateDefaultsForPreconfiguredNetwork
{
	if (self.populatingPrimaryServer) {
		return;
	}

	NSString *serverAddress = self.serverAddressComboBox.value;

	if ([serverAddress isEqualToString:self.lastServerAddressValue]) {
		return;
	}

	self.lastServerAddressValue = serverAddress;

	IRCNetwork *network = [self.networkList networkNamed:serverAddress];

	if (network == nil) {
		network = [self.networkList networkWithServerAddress:serverAddress];
	}

	if (network == nil) {
		[self restorePreviousValuesForPrimaryServer];

		return;
	}

	self.populatingPrimaryServer = YES;

	/* The predefined list in the combo box is only the network name.
	 IRCNetwork is also capable of matching known server addresses.
	 If we have a known network but it's not a predefined value,
	 then it very might be a server address. */
	/* Let's replace the given input that matches a network with the
	 network name itself. */
	if (self.serverAddressComboBox.valueIsPredefined == NO) {
		NSString *networkName = network.networkName;

		self.serverAddressComboBox.stringValue = networkName;

		self.lastServerAddressValue = networkName;
	}

	/* Populate other defaults */
	[self saveCurrentValuesForPrimaryServer];

	self.serverPortTextField.integerValue = network.serverPort;

	self.prefersSecuredConnectionCheck.state = (network.prefersSecuredConnection == NSControlStateValueOn);

	self.populatingPrimaryServer = NO;
}

/* The primary server is the first of the server list: it follows these fields */
- (void)rebuildPrimaryServer
{
	if (self.populatingPrimaryServer) {
		return;
	}

	IRCServer *server = self.serverList.firstObject;

	IRCServerMutable *serverMutable = nil;

	if (server == nil) {
		serverMutable = [IRCServerMutable new];
	} else {
		serverMutable = [server mutableCopy];
	}

	{
		NSString *serverAddress = self.serverAddressComboBox.value;

		IRCNetwork *serverAddressNetwork = [self.networkList networkNamed:serverAddress];

		if (serverAddressNetwork) {
			serverMutable.serverAddress = serverAddressNetwork.serverAddress;
		} else {
			serverMutable.serverAddress = serverAddress.lowercaseString;
		}
	}

	serverMutable.serverPort = self.serverPortTextField.integerValue;

	serverMutable.prefersSecuredConnection = (self.prefersSecuredConnectionCheck.state == NSControlStateValueOn);

	serverMutable.serverPassword = self.serverPasswordTextField.trimmedStringValue;

	NSMutableArray *serverList = [self.serverList mutableCopy];

	if (serverList.count == 0) {
		[serverList addObject:[serverMutable copy]];
	} else {
		serverList[0] = [serverMutable copy];
	}

	self.serverList = serverList;
}

- (void)rebuildPrimaryServerIfNeeded
{
	/* We only want to rebuild the IRCServer at index 0 when the
	 user changes it. This method is invoked whenever something
	 changes related to that server. If it was not changed while
	 the server endpoint sheet was open, then we must update the
	 mutable server list to include the change. */
	if (self.serverEndpointSheet != nil) {
		return;
	}

	[self rebuildPrimaryServer];
}

- (void)useSSLCheckChanged:(nullable id)sender
{
	NSInteger serverPort = self.serverPortTextField.integerValue;

	BOOL useSSL = (self.prefersSecuredConnectionCheck.state == NSControlStateValueOn);

	if (useSSL) {
		if (serverPort == 6667) {
			self.serverPortTextField.stringValue = TXLocalizationNotNeeded(@"6697");
		}
	} else {
		if (serverPort == 6697) {
			self.serverPortTextField.stringValue = TXLocalizationNotNeeded(@"6667");
		}
	}

	[self rebuildPrimaryServerIfNeeded];
}

- (void)turnOnSecuredConnection
{
	if (self.prefersSecuredConnectionCheck.state == NSControlStateValueOn) {
		return;
	}

	self.prefersSecuredConnectionCheck.state = NSControlStateValueOn;

	[self useSSLCheckChanged:nil];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	if (notification.object == self.serverPasswordTextField) {
		[self rebuildPrimaryServerIfNeeded];
	}
}

- (void)validatedTextFieldTextDidChange:(nullable id)sender
{
	if (sender == self.serverAddressComboBox) {
		[self populateDefaultsForPreconfiguredNetwork];
	}

	[self rebuildPrimaryServerIfNeeded];

	[self updateStrictTransportSecurityRow];
}

#pragma mark -
#pragma mark Alternate Servers

- (void)editServerEndpoints:(nullable id)sender
{
	TDCServerEndpointListSheet *sheet = [[TDCServerEndpointListSheet alloc] initWithWindow:self.propertiesSheet.sheet];

	sheet.delegate = self;

	[sheet startWithServerList:self.serverList];

	self.serverEndpointSheet = sheet;
}

- (void)serverEndpointListSheet:(TDCServerEndpointListSheet *)sender onOk:(NSArray<IRCServer *> *)serverList
{
	self.serverList = serverList;

	[self loadPrimaryServerEndpoint];
}

- (void)serverEndpointListSheetWillClose:(TDCServerEndpointListSheet *)sender
{
	self.serverEndpointSheet = nil;
}

@end

#pragma mark -
#pragma mark Identity

@interface TDCServerPropertiesIdentityPane ()
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *nicknameTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *awayNicknameTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *alternateNicknamesTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *usernameTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *realNameTextField;
@property (nonatomic, weak) IBOutlet NSTextField *nicknamePasswordTextField;
@property (nonatomic, weak) IBOutlet NSTextField *nickServHostTextField;
@property (nonatomic, weak) IBOutlet NSButton *autojoinWaitsForNickServCheck;
@property (nonatomic, weak) IBOutlet NSButton *hideAutojoinDelayedWarningsCheck;
@property (nonatomic, weak) IBOutlet NSPopUpButton *saslECDSAKeyButton;
@property (nonatomic, weak) IBOutlet NSTextField *saslECDSAKeyField;

/* The configuration's value until saved: nil leaves the Keychain as it is, empty removes the key */
@property (nonatomic, copy, nullable) NSString *saslECDSAKey;
@property (nonatomic, strong, nullable) IRCSASLECDSAKey *currentSASLECDSAKey;

- (IBAction)autojoinWaitsForNickServChanged:(nullable id)sender;

- (IBAction)onSASLECDSAKeyGenerateRequested:(nullable id)sender;
- (IBAction)onSASLECDSAKeyImportRequested:(nullable id)sender;
- (IBAction)onSASLECDSAKeyCopyPublicKeyRequested:(nullable id)sender;
- (IBAction)onSASLECDSAKeyCopyNickServCommandRequested:(nullable id)sender;
- (IBAction)onSASLECDSAKeyRemoveRequested:(nullable id)sender;
@end

@implementation TDCServerPropertiesIdentityPane

- (void)prepareInitialState
{
	/* Alternate nicknames */
	self.alternateNicknamesTextField.stringValueIsInvalidOnEmpty = NO;
	self.alternateNicknamesTextField.stringValueIsTrimmed = YES;

	self.alternateNicknamesTextField.validationBlock = ^NSString *(NSString *currentValue) {
		NSArray *nicknames = [currentValue componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		for (NSString *nickname in nicknames) {
			if (nickname.isHostmaskNickname == NO) {
				return TXTLS(@"TDCServerPropertiesSheet[wlz-tb]", nickname);
			}
		}

		return nil;
	};

	/* Away nickname */
	self.awayNicknameTextField.stringValueIsInvalidOnEmpty = NO;
	self.awayNicknameTextField.stringValueIsTrimmed = YES;
	self.awayNicknameTextField.stringValueUsesOnlyFirstToken = YES;

	self.awayNicknameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isHostmaskNickname == NO) {
			return TXTLS(@"CommonErrors[och-j5]");
		}

		return nil;
	};

	/* Nickname */
	self.nicknameTextField.stringValueIsInvalidOnEmpty = YES;
	self.nicknameTextField.stringValueIsTrimmed = YES;
	self.nicknameTextField.stringValueUsesOnlyFirstToken = YES;

	self.nicknameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isHostmaskNickname == NO) {
			return TXTLS(@"CommonErrors[och-j5]");
		}

		return nil;
	};

	/* Username */
	self.usernameTextField.stringValueIsInvalidOnEmpty = YES;
	self.usernameTextField.stringValueIsTrimmed = YES;
	self.usernameTextField.stringValueUsesOnlyFirstToken = YES;

	self.usernameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isHostmaskUsername == NO) {
			return TXTLS(@"TDCServerPropertiesSheet[8iw-q8]");
		}

		return nil;
	};

	/* Real name */
	self.realNameTextField.stringValueIsInvalidOnEmpty = YES;
	self.realNameTextField.stringValueIsTrimmed = YES;
	self.realNameTextField.stringValueUsesOnlyFirstToken = NO;

	self.realNameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([currentValue containsCharactersFromCharacterSet:[NSCharacterSet newlineCharacterSet]]) {
			return TXTLS(@"TDCServerPropertiesSheet[agy-bp]");
		}

		return nil;
	};
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	if (config.nickname.length > 0) {
		self.nicknameTextField.stringValue = config.nickname;
	} else {
		self.nicknameTextField.stringValue = [TPCPreferences defaultNickname];
	}

	self.awayNicknameTextField.stringValue = (config.awayNickname ?: @"");

	self.alternateNicknamesTextField.stringValue = [config.alternateNicknames componentsJoinedByString:@" "];

	if (config.username.length > 0) {
		self.usernameTextField.stringValue = config.username;
	} else {
		self.usernameTextField.stringValue = [TPCPreferences defaultUsername];
	}

	if (config.realName.length > 0) {
		self.realNameTextField.stringValue = config.realName;
	} else {
		self.realNameTextField.stringValue = [TPCPreferences defaultRealName];
	}

	self.nicknamePasswordTextField.stringValue = (config.nicknamePassword ?: @"");

	self.nickServHostTextField.stringValue = (config.nickServHost ?: @"");

	NSString *knownNickServHost = [IRCClient knownNickServHostForServerAddress:config.serverList.firstObject.serverAddress];

	if (knownNickServHost) {
		self.nickServHostTextField.placeholderString = knownNickServHost;
	}

	self.autojoinWaitsForNickServCheck.state = config.autojoinWaitsForNickServ;

	self.hideAutojoinDelayedWarningsCheck.state = (config.hideAutojoinDelayedWarnings == NO);

	self.saslECDSAKey = config.saslECDSAKey;

	[self updateIdentityPage];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.nickname = self.nicknameTextField.value;
	config.username = self.usernameTextField.value;
	config.realName = self.realNameTextField.value;

	config.awayNickname = self.awayNicknameTextField.value;

	NSArray *alternateNicknames = [self.alternateNicknamesTextField.value componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	config.alternateNicknames = [alternateNicknames arrayByRemovingEmptyValuesAndUniquing];

	config.nicknamePassword = self.nicknamePasswordTextField.trimmedStringValue;

	NSString *nickServHost = self.nickServHostTextField.trimmedStringValue;

	config.nickServHost = ((nickServHost.length > 0) ? nickServHost : nil);

	config.autojoinWaitsForNickServ = (self.autojoinWaitsForNickServCheck.state == NSControlStateValueOn);

	config.hideAutojoinDelayedWarnings = (self.hideAutojoinDelayedWarningsCheck.state != NSControlStateValueOn);

	/* Written to (or removed from) the Keychain when the configuration is saved */
	config.saslECDSAKey = self.saslECDSAKey;
}

- (nullable NSControl *)firstInvalidField
{
	for (TVCValidatedTextField *textField in @[self.nicknameTextField,
											   self.awayNicknameTextField,
											   self.alternateNicknamesTextField,
											   self.usernameTextField,
											   self.realNameTextField])
	{
		if (textField.valueIsValid == NO) {
			return textField;
		}
	}

	return nil;
}

- (void)updateIdentityPage
{
	self.hideAutojoinDelayedWarningsCheck.hidden =
	(self.autojoinWaitsForNickServCheck.state == NSControlStateValueOff);

	[self updateSASLECDSAKey];
}

- (void)autojoinWaitsForNickServChanged:(nullable id)sender
{
	[self updateIdentityPage];

	if (self.autojoinWaitsForNickServCheck.state != NSControlStateValueOn) {
		return;
	}

	if (self.nicknamePasswordTextField.stringValue.length > 0 ||
		self.clientCertificatePane.hasCertificate ||
		self.currentSASLECDSAKey != nil)
	{
		return;
	}

	[TDCAlert modalAlertWithMessage:TXTLS(@"TDCServerPropertiesSheet[26u-j8]")
							  title:TXTLS(@"TDCServerPropertiesSheet[94r-eq]")
					  defaultButton:TXTLS(@"Prompts[c7s-dq]")
					alternateButton:nil];
}

#pragma mark -
#pragma mark Login Key

- (void)updateSASLECDSAKey
{
	NSString *storedKey = self.saslECDSAKey;

	IRCSASLECDSAKey *key = ((storedKey.length > 0) ? [IRCSASLECDSAKey keyWithStoredValue:storedKey] : nil);

	self.currentSASLECDSAKey = key;

	if (key) {
		self.saslECDSAKeyField.stringValue = key.publicKey;
		self.saslECDSAKeyField.textColor = [NSColor labelColor];
	} else {
		self.saslECDSAKeyField.stringValue = TXTLS(@"TDCServerPropertiesSheet[ek1-n0]");
		self.saslECDSAKeyField.textColor = [NSColor secondaryLabelColor];
	}

	/* Copy (3, 4) and Remove (5) need a key */
	for (NSInteger tag = 3; tag <= 5; tag++) {
		[self.saslECDSAKeyButton.menu itemWithTag:tag].enabled = (key != nil);
	}
}

- (void)setSASLECDSAKey:(nullable IRCSASLECDSAKey *)key
{
	self.saslECDSAKey = ((key) ? key.storedValue : @"");

	[self updateSASLECDSAKey];
}

/* The old key is gone once the sheet is saved: the network must be given the new one */
- (void)confirmReplacingSASLECDSAKey:(void (^)(void))replaceBlock
{
	[self confirmReplacingSASLECDSAKeyWithTitle:TXTLS(@"TDCServerPropertiesSheet[ek1-r0]")
								  defaultButton:TXTLS(@"TDCServerPropertiesSheet[ek1-r2]")
								   replaceBlock:replaceBlock];
}

- (void)confirmReplacingSASLECDSAKeyWithTitle:(NSString *)title defaultButton:(NSString *)defaultButton replaceBlock:(void (^)(void))replaceBlock
{
	if (self.currentSASLECDSAKey == nil) {
		replaceBlock();

		return;
	}

	[TDCAlert alertSheetWithWindow:self.propertiesSheet.sheet
							  body:TXTLS(@"TDCServerPropertiesSheet[ek1-r1]")
							 title:title
					 defaultButton:defaultButton
				   alternateButton:TXTLS(@"Prompts[qso-2g]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked != TDCAlertResponseDefault) {
						   return;
					   }

					   /* After this alert has left the sheet */
					   XRPerformBlockAsynchronouslyOnMainQueue(replaceBlock);
				   }];
}

- (void)onSASLECDSAKeyGenerateRequested:(nullable id)sender
{
	[self confirmReplacingSASLECDSAKey:^{
		[self setSASLECDSAKey:[IRCSASLECDSAKey generatedKey]];
	}];
}

- (void)onSASLECDSAKeyImportRequested:(nullable id)sender
{
	[self confirmReplacingSASLECDSAKey:^{
		NSWindow *window = self.propertiesSheet.sheet;

		NSOpenPanel *panel = [NSOpenPanel openPanel];

		panel.canChooseDirectories = NO;
		panel.canChooseFiles = YES;
		panel.allowsMultipleSelection = NO;

		panel.message = TXTLS(@"TDCServerPropertiesSheet[ek1-i0]");

		[panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
			if (response != NSModalResponseOK || panel.URL == nil) {
				return;
			}

			NSString *pem = [NSString stringWithContentsOfURL:panel.URL encoding:NSUTF8StringEncoding error:NULL];

			IRCSASLECDSAKey *key = ((pem) ? [IRCSASLECDSAKey keyWithPEM:pem] : nil);

			if (key) {
				[self setSASLECDSAKey:key];

				return;
			}

			XRPerformBlockAsynchronouslyOnMainQueue(^{
				[TDCAlert alertSheetWithWindow:window
										  body:TXTLS(@"TDCServerPropertiesSheet[ek1-i2]")
										 title:TXTLS(@"TDCServerPropertiesSheet[ek1-i1]", panel.URL.lastPathComponent)
								 defaultButton:TXTLS(@"Prompts[c7s-dq]")
							   alternateButton:nil
								   otherButton:nil];
			});
		}];
	}];
}

- (void)onSASLECDSAKeyCopyPublicKeyRequested:(nullable id)sender
{
	NSString *publicKey = self.currentSASLECDSAKey.publicKey;

	if (publicKey == nil) {
		return;
	}

	RZPasteboard().stringContent = publicKey;
}

- (void)onSASLECDSAKeyCopyNickServCommandRequested:(nullable id)sender
{
	NSString *publicKey = self.currentSASLECDSAKey.publicKey;

	if (publicKey == nil) {
		return;
	}

	RZPasteboard().stringContent = [NSString stringWithFormat:@"/msg NickServ SET PUBKEY %@", publicKey];
}

- (void)onSASLECDSAKeyRemoveRequested:(nullable id)sender
{
	[self confirmReplacingSASLECDSAKeyWithTitle:TXTLS(@"TDCServerPropertiesSheet[ek1-x0]")
								  defaultButton:TXTLS(@"TDCServerPropertiesSheet[ek1-x2]")
								   replaceBlock:^{
		[self setSASLECDSAKey:nil];
	}];
}

@end

#pragma mark -
#pragma mark Client Certificate

@interface TDCServerPropertiesClientCertificatePane ()
@property (nonatomic, weak) IBOutlet NSTextField *clientCertificateCommonNameField;
@property (nonatomic, weak) IBOutlet NSTextField *clientCertificateSHA512FingerprintField;
@property (nonatomic, weak) IBOutlet NSTextField *clientCertificateSHA2FingerprintField;
@property (nonatomic, weak) IBOutlet NSTextField *clientCertificateSHA1FingerprintField;
@property (nonatomic, weak) IBOutlet NSTextField *clientCertificateMD5FingerprintField;
@property (nonatomic, weak) IBOutlet NSButton *clientCertificateSHA512FingerprintCopyButton;
@property (nonatomic, weak) IBOutlet NSButton *clientCertificateSHA2FingerprintCopyButton;
@property (nonatomic, weak) IBOutlet NSButton *clientCertificateSHA1FingerprintCopyButton;
@property (nonatomic, weak) IBOutlet NSButton *clientCertificateMD5FingerprintCopyButton;
@property (nonatomic, weak) IBOutlet NSButton *clientCertificateChangeCertificateButton;
@property (nonatomic, weak) IBOutlet NSButton *clientCertificateResetCertificateButton;
@property (nonatomic, weak, nullable) NSPanel *clientCertificateSelectCertificatePanel;

/* The configuration's Keychain reference until saved */
@property (nonatomic, copy, nullable) NSData *certificateReference;

- (IBAction)onClientCertificateResetRequested:(nullable id)sender;
- (IBAction)onClientCertificateChangeRequested:(nullable id)sender;
- (IBAction)onClientCertificateFingerprintSHA512CopyRequested:(nullable id)sender;
- (IBAction)onClientCertificateFingerprintSHA2CopyRequested:(nullable id)sender;
- (IBAction)onClientCertificateFingerprintSHA1CopyRequested:(nullable id)sender;
- (IBAction)onClientCertificateFingerprintMD5CopyRequested:(nullable id)sender;
@end

@implementation TDCServerPropertiesClientCertificatePane

- (void)loadFromConfig:(IRCClientConfig *)config
{
	self.certificateReference = config.identityClientSideCertificate;

	[self updateClientCertificatePage];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	config.identityClientSideCertificate = self.certificateReference;
}

- (void)closeChildSheets
{
	if (self.clientCertificateSelectCertificatePanel) {
		[NSApp stopModalWithCode:NSModalResponseCancel];
	}
}

- (BOOL)hasCertificate
{
	return (self.certificateReference != nil);
}

- (void)copyNickServCommandForFingerprintField:(NSTextField *)textField
{
	RZPasteboard().stringContent = [NSString stringWithFormat:@"/msg NickServ cert add %@", textField.stringValue];
}

- (void)onClientCertificateFingerprintSHA512CopyRequested:(nullable id)sender
{
	[self copyNickServCommandForFingerprintField:self.clientCertificateSHA512FingerprintField];
}

- (void)onClientCertificateFingerprintSHA2CopyRequested:(nullable id)sender
{
	[self copyNickServCommandForFingerprintField:self.clientCertificateSHA2FingerprintField];
}

- (void)onClientCertificateFingerprintSHA1CopyRequested:(nullable id)sender
{
	[self copyNickServCommandForFingerprintField:self.clientCertificateSHA1FingerprintField];
}

- (void)onClientCertificateFingerprintMD5CopyRequested:(nullable id)sender
{
	[self copyNickServCommandForFingerprintField:self.clientCertificateMD5FingerprintField];
}

- (void)readClientCertificateCommonName:(NSString **)commonNameOut
					  sha512Fingerprint:(NSString **)sha512FingerprintOut
						sha2Fingerprint:(NSString **)sha2FingerprintOut
						sha1Fingerprint:(NSString **)sha1FingerprintOut
						 md5Fingerprint:(NSString **)md5FingerprintOut
{
	NSData *certificateDataIn = self.certificateReference;

	if (certificateDataIn == nil) {
		return;
	}

	/* ====================================== */

	SecIdentityRef identityRef = [TLOKeychain copyClientCertificateIdentityForReference:certificateDataIn];

	if (identityRef == NULL) {
		return;
	}

	SecCertificateRef certificateRef;

	OSStatus status = SecIdentityCopyCertificate(identityRef, &certificateRef);

	CFRelease(identityRef);

	if (status != noErr) {
		return;
	}

	/* ====================================== */

	CFStringRef commonNameRef;

	status = SecCertificateCopyCommonName(certificateRef, &commonNameRef);

	if (status != noErr) {
		CFRelease(certificateRef);

		return;
	}

	*commonNameOut = (__bridge_transfer NSString *)commonNameRef;

	/* ====================================== */

	CFDataRef certificateDataRef = SecCertificateCopyData(certificateRef);

	if (certificateDataRef) {
		NSData *certificateData = (__bridge NSData *)certificateDataRef;

		*sha512FingerprintOut = certificateData.sha512;
		*sha2FingerprintOut = certificateData.sha256;
		*sha1FingerprintOut = certificateData.sha1;
		*md5FingerprintOut = certificateData.md5;

		CFRelease(certificateDataRef);
	}

	/* ====================================== */

	CFRelease(certificateRef);
}

- (void)saveClientCertificateWithIdentity:(SecIdentityRef)identityInRef
{
	if (identityInRef == NULL) {
		return;
	}

	NSData *certificateReference = [TLOKeychain referenceForClientCertificateIdentity:identityInRef];

	if (certificateReference == nil) {
		return;
	}

	self.certificateReference = certificateReference;

	[self.generalPane turnOnSecuredConnection];
}

- (void)updateClientCertificatePage
{
	NSString *commonName = nil;

	NSString *sha512Fingerprint = nil;
	NSString *sha2Fingerprint = nil;
	NSString *sha1Fingerprint = nil;
	NSString *md5Fingerprint = nil;

	[self readClientCertificateCommonName:&commonName
						sha512Fingerprint:&sha512Fingerprint
						  sha2Fingerprint:&sha2Fingerprint
						  sha1Fingerprint:&sha1Fingerprint
						   md5Fingerprint:&md5Fingerprint];

	BOOL hasNoCertificate = (commonName.length == 0);

	/* Saved, but its identity is no longer in the Keychain: choose it again or remove it */
	BOOL certificateMissing = (hasNoCertificate && self.certificateReference != nil);

	if (hasNoCertificate) {
		if (certificateMissing) {
			self.clientCertificateCommonNameField.stringValue = TXTLS(@"TDCServerPropertiesSheet[c3r-m1]");
		} else {
			self.clientCertificateCommonNameField.stringValue = TXTLS(@"TDCServerPropertiesSheet[6xz-ec]");
		}

		self.clientCertificateSHA512FingerprintField.stringValue = TXTLS(@"TDCServerPropertiesSheet[6xz-ec]");
		self.clientCertificateSHA2FingerprintField.stringValue = TXTLS(@"TDCServerPropertiesSheet[6xz-ec]");
		self.clientCertificateSHA1FingerprintField.stringValue = TXTLS(@"TDCServerPropertiesSheet[6xz-ec]");
		self.clientCertificateMD5FingerprintField.stringValue = TXTLS(@"TDCServerPropertiesSheet[6xz-ec]");
	} else {
		self.clientCertificateCommonNameField.stringValue = commonName;

		self.clientCertificateSHA512FingerprintField.stringValue = (sha512Fingerprint.uppercaseString ?: @"");
		self.clientCertificateSHA2FingerprintField.stringValue = (sha2Fingerprint.uppercaseString ?: @"");
		self.clientCertificateSHA1FingerprintField.stringValue = (sha1Fingerprint.uppercaseString ?: @"");
		self.clientCertificateMD5FingerprintField.stringValue = (md5Fingerprint.uppercaseString ?: @"");
	}

	self.clientCertificateResetCertificateButton.enabled = (hasNoCertificate == NO || certificateMissing);

	self.clientCertificateSHA512FingerprintCopyButton.enabled = (hasNoCertificate == NO);
	self.clientCertificateSHA2FingerprintCopyButton.enabled = (hasNoCertificate == NO);
	self.clientCertificateSHA1FingerprintCopyButton.enabled = (hasNoCertificate == NO);
	self.clientCertificateMD5FingerprintCopyButton.enabled = (hasNoCertificate == NO);
}

- (void)onClientCertificateResetRequested:(nullable id)sender
{
	self.certificateReference = nil;

	[self updateClientCertificatePage];
}

- (void)onClientCertificateChangeRequested:(nullable id)sender
{
	CFArrayRef identities = NULL;

	NSDictionary *queryFlags = @{
		(id)kSecClass		: (id)kSecClassIdentity,
		(id)kSecMatchLimit	: (id)kSecMatchLimitAll,
		(id)kSecReturnRef	: (id)kCFBooleanTrue
	};

	OSStatus queryStatus = SecItemCopyMatching((__bridge CFDictionaryRef)queryFlags, (CFTypeRef *)&identities);

	if (queryStatus != noErr) {
		LogToConsoleError("Operation Failed (1): %{public}i", queryStatus);
	}

	if (identities == NULL || CFArrayGetCount(identities) == 0) {
		[TDCAlert alertWithMessage:TXTLS(@"TDCServerPropertiesSheet[489-hG]")
							 title:TXTLS(@"TDCServerPropertiesSheet[pmk-os]")
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:TXTLS(@"TDCServerPropertiesSheet[3ju-lo]")
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
			if (buttonClicked == TDCAlertResponseOther) {
				[TLOpenLink openWithString:TXWebsiteClientCertificates inBackground:NO];
			}
		}];

		if (identities) {
			CFRelease(identities);
		}

		return;
	}

	SFChooseIdentityPanel *panel = [SFChooseIdentityPanel sharedChooseIdentityPanel];

	self.clientCertificateSelectCertificatePanel = panel;

	[panel setInformativeText:TXTLS(@"TDCServerPropertiesSheet[mi4-fd]")];

	[panel setAlternateButtonTitle:TXTLS(@"Prompts[qso-2g]")];

	NSInteger panelResponse =
	[panel runModalForIdentities:(__bridge NSArray *)(identities)
						 message:TXTLS(@"TDCServerPropertiesSheet[6wq-i4]")];

	CFRelease(identities);

	if (panelResponse == NSModalResponseOK) {
		SecIdentityRef identity = [panel identity];

		[self saveClientCertificateWithIdentity:identity];

		[self updateClientCertificatePage];
	}

	self.clientCertificateSelectCertificatePanel = nil;
}

@end

NS_ASSUME_NONNULL_END
