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

#import "NSObjectHelperPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCChannelUser.h"
#import "IRCExtrasPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "IRCWorldPrivate.h"
#import "TVCBasicTableView.h"
#import "TVCLogController.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMemberList.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextView.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TDCAboutDialogPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelInviteSheetPrivate.h"
#import "TDCChannelModifyModesSheetPrivate.h"
#import "TDCChannelModifyTopicSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TDCChannelSpotlightControllerPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCInputPrompt.h"
#import "TDCLegacyImportAssistantPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TDCNicknameColorSheetPrivate.h"
#import "TDCPreferencesControllerPrivate.h"
#import "TDCServerChangeNicknameSheetPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TDCWelcomeSheetPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesImportExport.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TXMasterControllerPrivate.h"
#import "TXWindowControllerPrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif
#import "TXMenuControllerInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TXMenuController (App)

#pragma mark -
#pragma mark Help

- (void)openAcknowledgements:(id)sender
{
	NSURL *Acknowledgements = [RZMainBundle() URLForResource:@"Acknowledgements" withExtension:@"pdf" subdirectory:@"Documentation"];

	[RZWorkspace() openURL:Acknowledgements];
}

- (void)openHelpMenuItem:(id)sender
{
	NSParameterAssert(sender != nil);

	NSDictionary *_helpMenuLinks = @{
	   @(MTMMHelpLicenseAgreement) 					: @"https://help.codeux.com/textual/End-User-License-Agreement.kb",
	   @(MTMMHelpPrivacyPolicy) 					: @"https://help.codeux.com/textual/Privacy-Policy.kb",
	   @(MTMMHelpFrequentlyAskedQuestions) 			: @"https://help.codeux.com/textual/Frequently-Asked-Questions.kb",
	   @(MTMMHelpKBMenuKnowledgeBaseHome) 			: @"https://help.codeux.com/textual/home.kb",
	   @(MTMMHelpKBMenuCommandReference) 			: @"https://help.codeux.com/textual/Command-Reference.kb",
	   @(MTMMHelpKBMenuFeatureRequests) 			: @"https://help.codeux.com/textual/Support.kb",
	   @(MTMMHelpKBMenuKeyboardShortcuts) 			: @"https://help.codeux.com/textual/Keyboard-Shortcuts.kb",
	   @(MTMMHelpKBMenuMemoryManagement) 			: @"https://help.codeux.com/textual/Memory-Management.kb",
	   @(MTMMHelpKBMenuNetworkTimeouts)				: @"https://help.codeux.com/textual/Network-Timeouts.kb",
	   @(MTMMHelpKBMenuTextFormatting) 				: @"https://help.codeux.com/textual/Text-Formatting.kb",
	   @(MTMMHelpKBMenuStylingInformation) 			: @"https://help.codeux.com/textual/Styles.kb",
	   @(MTMMHelpKBMenuConnectingWithCertificate) 	: @"https://help.codeux.com/textual/Using-CertFP.kb",
	   @(MTMMHelpKBMenuConnectingToBouncer)			: @"https://help.codeux.com/textual/Connecting-to-ZNC-Bouncer.kb",
	   @(MTMMHelpKBMenuDCCFileTransferInformation) 	: @"https://help.codeux.com/textual/DCC-File-Transfer-Information.kb"
	};

	NSString *link = _helpMenuLinks[@([sender tag])];

	[TLOpenLink openWithString:link inBackground:NO];
}

- (void)openStandaloneStoreWebpage:(id)sender
{
	[TLOpenLink openWithString:@"https://www.textualapp.com/standalone-store" inBackground:NO];
}

- (void)contactSupport:(id)sender
{
	[TLOpenLink openWithString:@"https://contact.codeux.com/" inBackground:NO];
}

- (void)connectToTextualHelpChannel:(id)sender
{
	[IRCExtras createConnectionToServer:@"irc.libera.chat +6697" channelList:@"#textual" connectWhenCreated:YES mergeConnectionIfPossible:YES selectFirstChannelAdded:YES];
}

- (void)connectToTextualTestingChannel:(id)sender
{
	[IRCExtras createConnectionToServer:@"irc.libera.chat +6697" channelList:@"#textual-testing" connectWhenCreated:YES mergeConnectionIfPossible:YES selectFirstChannelAdded:YES];
}

#pragma mark -
#pragma mark Preferences

- (void)importPreferences:(id)sender
{
	[TPCPreferencesImportExport importInWindow:mainWindow()];
}

- (void)exportPreferences:(id)sender
{
	[TPCPreferencesImportExport exportInWindow:mainWindow()];
}

- (void)importSettingsFromTextual7:(id)sender
{
	[TDCLegacyImportAssistant importFromMenu];
}

#pragma mark -
#pragma mark Notifications

- (void)toggleMuteOnNotificationsShortcutOn:(BOOL)toggleOn
{
	sharedNotificationController().areNotificationsDisabled = toggleOn;

	NSControlStateValue state = ((toggleOn) ? NSControlStateValueOn : NSControlStateValueOff);

	self.muteNotificationsFileMenuItem.state = state;

	self.muteNotificationsDockMenuItem.state = state;
}

- (void)toggleMuteOnNotificationSoundsShortcutOn:(BOOL)toggleOn
{
	[TPCPreferences setSoundIsMuted:toggleOn];

	NSControlStateValue state = ((toggleOn) ? NSControlStateValueOn : NSControlStateValueOff);

	self.muteNotificationsSoundsDockMenuItem.state = state;

	self.muteNotificationsSoundsFileMenuItem.state = state;
}

- (void)toggleMuteOnNotificationSounds:(id)sender
{
	if ([TPCPreferences soundIsMuted]) {
		[self toggleMuteOnNotificationSoundsShortcutOn:NO];
	} else {
		[self toggleMuteOnNotificationSoundsShortcutOn:YES];
	}
}

- (void)toggleMuteOnNotifications:(id)sender
{
	if (sharedNotificationController().areNotificationsDisabled) {
		[self toggleMuteOnNotificationsShortcutOn:NO];
	} else {
		[self toggleMuteOnNotificationsShortcutOn:YES];
	}
}

#pragma mark -
#pragma mark Appearance

- (void)resetMainWindowAppearance:(id)sender
{
	[TPCPreferences setAppearance:TXPreferredAppearanceInherited];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionAppearance];
}

- (void)toggleMainWindowAppearance:(id)sender
{
	TXPreferredAppearance appearance = [TPCPreferences appearance];

	switch (appearance) {
		case TXPreferredAppearanceInherited:
		{
			TXAppearance *appAppearance = [TXSharedApplication sharedAppearance];

			if (appAppearance.properties.isDarkAppearance == NO) {
				appearance = TXPreferredAppearanceDark;
			} else {
				appearance = TXPreferredAppearanceLight;
			}

			break;
		}
		case TXPreferredAppearanceLight:
		{
			appearance = TXPreferredAppearanceDark;

			break;
		}
		case TXPreferredAppearanceDark:
		{
			appearance = TXPreferredAppearanceLight;

			break;
		}
	} // switch()

	[TPCPreferences setAppearance:appearance];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionAppearance];
}

- (void)toggleServerListVisibility:(id)sender
{
	[mainWindow().contentSplitView toggleServerListVisibility];
}

- (void)toggleMemberListVisibility:(id)sender
{
	mainWindowMemberList().isHiddenByUser = (mainWindowMemberList().isHiddenByUser == NO);

	[mainWindow().contentSplitView toggleMemberListVisibility];
}

- (void)forceReloadTheme:(id)sender
{
	[mainWindow() reloadTheme];
}

#pragma mark -
#pragma mark License Manager

- (void)manageLicense:(id)sender
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	[self manageLicense:sender activateLicenseKey:nil licenseKeyPassedByArgument:NO];
#endif
}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
- (void)manageLicense:(id)sender activateLicenseKey:(nullable NSString *)licenseKey
{
	[self manageLicense:sender activateLicenseKey:licenseKey licenseKeyPassedByArgument:NO];
}

- (void)manageLicense:(id)sender activateLicenseKeyWithURL:(NSURL *)licenseKeyURL
{
	NSParameterAssert(licenseKeyURL != nil);

	NSString *path = licenseKeyURL.path;

	if (path == nil) {
		return;
	}

	NSCharacterSet *slashCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];

	NSString *licenseKey = [path stringByTrimmingCharactersInSet:slashCharacterSet];

	if (licenseKey.length == 0) {
		return;
	}

	/* A link can come from anywhere, so activation is always confirmed */
	NSString *currentLicenseOwner = TLOLicenseManagerLicenseOwnerName();

	NSString *message = nil;

	if (currentLicenseOwner.length > 0) {
		message = TXTLS(@"TLOLicenseManager[q7w-k2]", licenseKey, currentLicenseOwner);
	} else {
		message = TXTLS(@"TLOLicenseManager[q7w-k1]", licenseKey);
	}

	BOOL activateLicense = [TDCAlert modalAlertWithMessage:message
													 title:TXTLS(@"TLOLicenseManager[q7w-k0]")
											 defaultButton:TXTLS(@"TLOLicenseManager[q7w-k3]")
										   alternateButton:TXTLS(@"Prompts[qso-2g]")];

	if (activateLicense == NO) {
		return;
	}

	[self manageLicense:sender activateLicenseKey:licenseKey licenseKeyPassedByArgument:NO];
}

- (void)manageLicense:(id)sender activateLicenseKey:(nullable NSString *)licenseKey licenseKeyPassedByArgument:(BOOL)licenseKeyPassedByArgument
{
	TDCLicenseManagerDialog *licenseDialog = [TXSharedApplication sharedLicenseManagerDialog];

	[licenseDialog show];

	if (licenseKey) {
		[licenseDialog activateLicenseKey:licenseKey silently:licenseKeyPassedByArgument];
	}
}
#endif

#pragma mark -
#pragma mark Developer

- (void)toggleDeveloperMode:(id)sender
{
	[TPCPreferences setDeveloperModeEnabled:([TPCPreferences developerModeEnabled] == NO)];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionIRCCommandCache];
}

- (void)resetDoNotAskMePopupWarnings:(id)sender
{
	NSDictionary *settings = [RZUserDefaults() dictionaryRepresentation];

	for (NSString *key in settings) {
		if ([key hasPrefix:TDCAlertSuppressionPrefix] == NO) {
			continue;
		}

		[RZUserDefaults() setBool:NO forKey:key];
	}
}

#pragma mark -
#pragma mark Sparkle Framework

- (void)checkForUpdates:(id)sender
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUStandardUpdaterController *controller = masterController().updateController;

	[controller checkForUpdates:sender];
#endif
}

@end

NS_ASSUME_NONNULL_END
