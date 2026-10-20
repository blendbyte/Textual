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

#import "TLOUploadDestinationPrivate.h"
#import "TDCUploadDestinationSheetPrivate.h"
#import <SecurityInterface/SFChooseIdentityPanel.h>

#import "NSStringHelper.h"
#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCSASLECDSAPrivate.h"
#import "IRCServerPrivate.h"
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

	[self.serverPane turnOnSecuredConnection];
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

#pragma mark -
#pragma mark Uploads

/* Where files go on this network if it offers no uploads: the
 address in Settings, none, or this server's own */
@interface TDCServerPropertiesUploadsPane ()
@property (nonatomic, strong) NSPopUpButton *uploadModeButton;
@property (nonatomic, strong) NSButton *uploadEditButton;
@property (nonatomic, strong) NSTextField *ownDestinationLabel;
@property (nonatomic, strong) NSGridRow *ownDestinationRow;
@property (nonatomic, copy, nullable) TLOUploadDestination *ownUploadDestination;
@end

@implementation TDCServerPropertiesUploadsPane

- (instancetype)init
{
	if ((self = [super init])) {
		[self buildView];

		return self;
	}

	return nil;
}

- (void)buildView
{
	NSView *view = [NSView new];

	/* Pinned to the sheet's content area with constraints */
	view.translatesAutoresizingMaskIntoConstraints = NO;

	NSTextField *label = [NSTextField labelWithString:TXTLS(@"TDCServerPropertiesSheet[upl-l1]")];

	NSPopUpButton *modeButton = [NSPopUpButton new];

	[modeButton addItemsWithTitles:@[
		TXTLS(@"TDCServerPropertiesSheet[upl-m1]"), // IRCClientUploadDestinationModeDefault
		TXTLS(@"TDCServerPropertiesSheet[upl-m2]"), // …Off
		TXTLS(@"TDCServerPropertiesSheet[upl-m3]") // …Own
	]];

	modeButton.target = self;
	modeButton.action = @selector(uploadModeChanged:);

	NSTextField *ownLabel = [NSTextField labelWithString:@""];

	ownLabel.textColor = [NSColor secondaryLabelColor];

	NSButton *editButton = [NSButton buttonWithTitle:TXTLS(@"TDCServerPropertiesSheet[upl-b1]") target:self action:@selector(editOwnUploadDestination:)];

	NSStackView *ownRow = [NSStackView stackViewWithViews:@[ownLabel, editButton]];

	ownRow.spacing = 8;

	NSTextField *note = [NSTextField wrappingLabelWithString:TXTLS(@"TDCServerPropertiesSheet[upl-n1]")];

	note.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	note.textColor = [NSColor secondaryLabelColor];

	[note.widthAnchor constraintLessThanOrEqualToConstant:340].active = YES;

	NSGridView *grid = [NSGridView gridViewWithViews:@[
		@[label, modeButton],
		@[[NSGridCell emptyContentView], ownRow],
		@[[NSGridCell emptyContentView], note]
	]];

	grid.translatesAutoresizingMaskIntoConstraints = NO;
	grid.rowSpacing = 8;
	grid.columnSpacing = 8;
	grid.rowAlignment = NSGridRowAlignmentFirstBaseline;

	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

	[view addSubview:grid];

	[NSLayoutConstraint activateConstraints:@[
		[grid.topAnchor constraintEqualToAnchor:view.topAnchor constant:20],
		[grid.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
		[grid.leadingAnchor constraintGreaterThanOrEqualToAnchor:view.leadingAnchor constant:20],
		[grid.bottomAnchor constraintLessThanOrEqualToAnchor:view.bottomAnchor constant:-20]
	]];

	self.view = view;

	self.uploadModeButton = modeButton;
	self.uploadEditButton = editButton;
	self.ownDestinationLabel = ownLabel;
	self.ownDestinationRow = [grid rowAtIndex:1];
}

- (void)updateUploadRow
{
	BOOL own = (self.uploadModeButton.indexOfSelectedItem == IRCClientUploadDestinationModeOwn);

	TLOUploadDestination *destination = self.ownUploadDestination;

	self.ownDestinationRow.hidden = (own == NO);

	self.ownDestinationLabel.stringValue = ((destination) ? destination.name : TXTLS(@"TDCServerPropertiesSheet[upl-o1]"));

	self.uploadEditButton.title = ((destination) ? TXTLS(@"TDCServerPropertiesSheet[upl-b1]") : TXTLS(@"TDCServerPropertiesSheet[upl-b2]"));
}

- (void)uploadModeChanged:(nullable id)sender
{
	[self updateUploadRow];

	/* Own, but none yet: set it up now */
	if (self.uploadModeButton.indexOfSelectedItem == IRCClientUploadDestinationModeOwn && self.ownUploadDestination == nil) {
		[self editOwnUploadDestination:nil];
	}
}

- (void)editOwnUploadDestination:(nullable id)sender
{
	NSWindow *window = self.view.window;

	if (window == nil) {
		return;
	}

	[TDCUploadDestinationSheet editDestination:self.ownUploadDestination
									  inWindow:window
							   showsHideOption:NO
							   completionBlock:^(TLOUploadDestination * _Nullable destination) {
								   self.ownUploadDestination = destination;

								   /* Removed: back to the one in Preferences */
								   if (destination == nil) {
									   [self.uploadModeButton selectItemAtIndex:IRCClientUploadDestinationModeDefault];
								   }

								   [self updateUploadRow];
							   }];
}

- (void)loadFromConfig:(IRCClientConfig *)config
{
	NSDictionary *uploadDestination = config.uploadDestination;

	self.ownUploadDestination = ((uploadDestination) ? [TLOUploadDestination destinationWithPropertyList:uploadDestination secretsIdentifier:config.uniqueIdentifier] : nil);

	IRCClientUploadDestinationMode uploadMode = config.uploadDestinationMode;

	if (uploadMode > IRCClientUploadDestinationModeOwn || (uploadMode == IRCClientUploadDestinationModeOwn && self.ownUploadDestination == nil)) {
		uploadMode = IRCClientUploadDestinationModeDefault;
	}

	[self.uploadModeButton selectItemAtIndex:uploadMode];

	[self updateUploadRow];
}

- (void)saveToConfig:(IRCClientConfigMutable *)config
{
	/* The tokens go to the Keychain now, the rest with the server */
	TLOUploadDestination *ownUploadDestination = self.ownUploadDestination;

	if (ownUploadDestination) {
		[ownUploadDestination saveSecretsWithIdentifier:config.uniqueIdentifier];

		config.uploadDestination = ownUploadDestination.propertyList;
	} else {
		[TLOUploadDestination removeSecretsWithIdentifier:config.uniqueIdentifier];

		config.uploadDestination = nil;
	}

	IRCClientUploadDestinationMode uploadMode = self.uploadModeButton.indexOfSelectedItem;

	if (uploadMode == IRCClientUploadDestinationModeOwn && ownUploadDestination == nil) {
		uploadMode = IRCClientUploadDestinationModeDefault;
	}

	config.uploadDestinationMode = uploadMode;
}

@end

NS_ASSUME_NONNULL_END
