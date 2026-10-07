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

#import "NSStringHelper.h"
#import "NSViewHelper.h"
#import "TXGlobalModels.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TPCPreferencesUserDefaults.h"
#import "TDCLicenseManagerMigrateAppStoreSheetPrivate.h"
#import "TDCLicenseManagerRecoverLostLicenseSheetPrivate.h"
#import "TDCLicenseUpgradeActivateSheetPrivate.h"
#import "TDCLicenseUpgradeCommonActionsPrivate.h"
#import "TDCLicenseUpgradeDialogPrivate.h"
#import "TDCLicenseUpgradeEligibilitySheetPrivate.h"
#import "TDCProgressIndicatorSheetPrivate.h"
#import "TLOTimer.h"
#import "TLOLicenseManagerDownloaderPrivate.h"
#import "TLOLicenseManagerLastGenPrivate.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationController.h"
#import "TDCAlert.h"
#import "TDCLicenseManagerDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
NSString * const TDCLicenseManagerActivatedLicenseNotification = @"TDCLicenseManagerActivatedLicenseNotification";
NSString * const TDCLicenseManagerDeactivatedLicenseNotification = @"TDCLicenseManagerDeactivatedLicenseNotification";
NSString * const TDCLicenseManagerTrialExpiredNotification = @"TDCLicenseManagerTrialExpiredNotification";

#define _upgradeDialogRemindMeInterval 		345600 // 4 days

@interface TDCLicenseManagerDialog () <NSControlTextEditingDelegate>
@property (nonatomic, strong) IBOutlet NSView *contentViewUnregisteredTextualView;
@property (nonatomic, strong) IBOutlet NSView *contentViewRegisteredTextualView;
@property (nonatomic, weak) IBOutlet NSTextField *unregisteredViewLicenseKeyTextField;
@property (nonatomic, weak) IBOutlet NSTextField *unregisteredViewTrialInformationTextField;
@property (nonatomic, weak) IBOutlet NSTextField *registeredViewLicenseKeyTextField;
@property (nonatomic, weak) IBOutlet NSTextField *registeredViewLicenseOwnerTextField;
@property (nonatomic, weak) IBOutlet NSTextField *registeredViewLicensePurchaseDateTextField;
@property (nonatomic, weak) IBOutlet NSButton *registeredViewDeactivateTextualButton;
@property (nonatomic, weak) IBOutlet NSButton *unregisteredViewActivateTextualButton;
@property (nonatomic, weak) IBOutlet NSButton *unregisteredViewCancelButton;
@property (nonatomic, weak) IBOutlet NSButton *unregisteredViewRecoveryLostLicenseButton;
@property (nonatomic, weak) IBOutlet NSImageView *unregisteredViewMacAppStoreIconImageView;
@property (nonatomic, strong, nullable) TDCProgressIndicatorSheet *progressIndicator;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *licenseManagerDownloader;
@property (nonatomic, strong, nullable) TDCLicenseManagerMigrateAppStoreSheet *migrateAppStoreSheet;
@property (nonatomic, strong, nullable) TDCLicenseManagerRecoverLostLicenseSheet *recoverLostLicenseSheet;
@property (nonatomic, strong, nullable) TDCLicenseUpgradeDialog *upgradeDialog;
@property (nonatomic, strong, nullable) TDCLicenseUpgradeActivateSheet *upgradeActivateSheet;
@property (nonatomic, assign) BOOL textualIsRegistered;
@property (nonatomic, assign) BOOL isSilentOnSuccess;
@property (nonatomic, assign) BOOL operationInProgress;
@property (nonatomic, strong) TLOTimer *trialTimer;

- (IBAction)unregisteredViewActivateTextual:(id)sender;
- (IBAction)unregisteredViewCancel:(id)sender;
- (IBAction)unregisteredViewMigrateMacAppStorePurchase:(id)sender;
- (IBAction)unregisteredViewPurchaseTextual:(id)sender;
- (IBAction)unregisteredViewRecoveryLostLicense:(id)sender;

- (IBAction)registeredViewDeactivateTextual:(id)sender;
@end

@interface TLONotificationController ()
- (void)scheduleLicenseManagerNotificationWithTitle:(NSString *)title message:(NSString *)message;
@end

@implementation TDCLicenseManagerDialog

#pragma mark -
#pragma mark Dialog Foundation

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return self;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCLicenseManagerDialog" owner:self topLevelObjects:nil];

	[self populateMacAppStoreIconImageView];

	[self updateSelectedPane];
}

- (void)show
{
	BOOL windowVisible = self.window.visible;

	[super show];

	if (windowVisible == NO) {
		[self.window restoreWindowStateForClass:self.class];
	}
}

- (void)applicationDidFinishLaunching
{
	[self scheduleTimeRemainingInTrialNotification];

	[self toggleTrialTimer];

	[self activateLicenseKeyUsingArgumentDictionary];

	[self upgradeDialogAppFinishedLaunchingRoutine];
}

- (void)populateMacAppStoreIconImageView
{
	/* Read the app store icon image from the actual App Store app so 
	 that we do not have to update it if Apple does. */
	NSBundle *appStoreApplication = [NSBundle bundleWithPath:@"/Applications/App Store.app"];

	if (appStoreApplication == nil) {
		appStoreApplication = [NSBundle bundleWithPath:@"/System/Applications/App Store.app"];
	}

	if (appStoreApplication == nil) {
		return;
	}

	NSString *appStoreIconPath = [appStoreApplication pathForResource:@"AppIcon" ofType:@"icns"];

	if (appStoreIconPath == nil) {
		return;
	}

	NSImage *appStoreIconImage = [[NSImage alloc] initWithContentsOfFile:appStoreIconPath];

	self.unregisteredViewMacAppStoreIconImageView.image = appStoreIconImage;
}

- (void)updateSelectedPane
{
	NSView *contentView = nil;

	self.textualIsRegistered = TLOLicenseManagerTextualIsRegistered();

	if (self.textualIsRegistered)
	{
		NSString *licenseKey = TLOLicenseManagerLicenseKey();
		NSString *licenseKeyOwner = TLOLicenseManagerLicenseOwnerName();
		NSString *licenseKeyCreationDate = TLOLicenseManagerLicenseCreationDateFormatted();

		self.registeredViewLicenseKeyTextField.stringValue = licenseKey;
		self.registeredViewLicenseOwnerTextField.stringValue = licenseKeyOwner;
		self.registeredViewLicensePurchaseDateTextField.stringValue = licenseKeyCreationDate;

		contentView = self.contentViewRegisteredTextualView;
	}
	else // textualIsRegistered
	{
		contentView = self.contentViewUnregisteredTextualView;

		NSString *formattedTrialInformation = [self timeRemainingInTrialFormattedMessage];

		self.unregisteredViewTrialInformationTextField.stringValue = formattedTrialInformation;
	}

	[self.window replaceContentView:contentView];
}

#pragma mark -
#pragma mark Trial Timer

- (void)toggleTrialTimer
{
	if (TLOLicenseManagerTextualIsRegistered()) {
		[self stopTrialTimer];
	} else {
		[self startTrialTimer];
	}
}

- (void)startTrialTimer
{
	if (self.trialTimer != nil) {
		return;
	}

	NSTimeInterval timeRemaining = (TLOLicenseManagerTimeRemainingTrial() * (-1.0));

	if (timeRemaining == 0) {
		return;
	}

	TLOTimer *trialTimer = [TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
		[self onTrialTimer];
	}];

	self.trialTimer = trialTimer;

	[trialTimer start:timeRemaining];
}

- (void)stopTrialTimer
{
	if (self.trialTimer == nil) {
		return;
	}

	[self.trialTimer stop];
	self.trialTimer = nil;
}

- (void)onTrialTimer
{
	[self stopTrialTimer];

	[RZNotificationCenter() postNotificationName:TDCLicenseManagerTrialExpiredNotification object:self];
}

#pragma mark -
#pragma mark Activate License

- (void)unregisteredViewPurchaseTextual:(id)sender
{
	NSString *lastGenLicenseKey = [TLOLicenseManagerLastGen licenseKey];

	if (lastGenLicenseKey != nil) {
		BOOL upgradeLicense =
		[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[dpo-ln]", lastGenLicenseKey.prettyLicenseKey)
								  title:TXTLS(@"TLOLicenseManager[12h-3w]")
						  defaultButton:TXTLS(@"TLOLicenseManager[qrx-aq]")
						alternateButton:TXTLS(@"TLOLicenseManager[zp8-8q]")];

		if (upgradeLicense) {
			[self showUpgradeDialogForLicenseKey:lastGenLicenseKey];

			return;
		}
	}

	[menuController() openStandaloneStoreWebpage:nil];
}

- (void)unregisteredViewCancel:(id)sender
{
	[self close];
}

- (void)updateUnregisteredViewActivationButton
{
	if (self.textualIsRegistered) {
		return; // Cancel operation...
	}

	NSString *licenseKeyValue = self.unregisteredViewLicenseKeyTextField.stringValue.trim;

	if (TLOLicenseManagerLicenseKeyIsValid(licenseKeyValue)) {
		self.unregisteredViewActivateTextualButton.enabled = YES;
	} else {
		self.unregisteredViewActivateTextualButton.enabled = NO;
	}
}

- (void)unregisteredViewActivateTextual:(id)sender
{
	NSString *licenseKeyValue = self.unregisteredViewLicenseKeyTextField.stringValue;

	[self attemptToActivateLicenseKey:licenseKeyValue];
}

- (void)activateLicenseKeyUsingArgumentDictionary
{
	if (TLOLicenseManagerTextualIsRegistered()) {
		return; // Nothing to do here...
	}

	NSDictionary *commandLineArguments = [[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain];

	NSString *argumentLicenseKey = commandLineArguments[@"-licenseKey"];

	if (argumentLicenseKey == nil) {
		return;
	}

	[self activateLicenseKey:argumentLicenseKey silently:YES];
}

- (void)activateLicenseKey:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	[self activateLicenseKey:licenseKey silently:NO];
}

- (void)activateLicenseKey:(NSString *)licenseKey silently:(BOOL)silently
{
	NSParameterAssert(licenseKey != nil);

	/* This method is allowed to be invoked by another class in order
	 to activate a license. It is not invoked by this class on its own. */
	if (TLOLicenseManagerLicenseKeyIsValid(licenseKey)) {
		[self attemptToActivateLicenseKey:licenseKey silently:silently];
	}
}

- (void)attemptToActivateLicenseKey:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	[self attemptToActivateLicenseKey:licenseKey silently:NO];
}

- (void)attemptToActivateLicenseKey:(NSString *)licenseKey silently:(BOOL)silently
{
	NSParameterAssert(licenseKey != nil);

	/* User can click a link or do something else while an activation is already in
	 progress, so we try to recognize when that happens so that we can prevent
	 confusion when an operation is already in progress. */
	/* This is the only place in the dialog where user can perform an action by
	 outside influence. Everything else is internalized which means this check is
	 only necessary here... at least for now. */
	if (self.operationInProgress) {
		[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[vnu-5e]")
								  title:TXTLS(@"TLOLicenseManager[0uc-io]", licenseKey.prettyLicenseKey)
						  defaultButton:TXTLS(@"Prompts[c7s-dq]")
						alternateButton:nil];

		return;
	}

	/* Do not activate license we are already using. */
	if (licenseKey == TLOLicenseManagerLicenseKey()) {
		[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[fxu-su]")
								  title:TXTLS(@"TLOLicenseManager[bw3-sc]", licenseKey.prettyLicenseKey)
						  defaultButton:TXTLS(@"Prompts[c7s-dq]")
						alternateButton:nil];

		return;
	}

	/* The activate sheet will close itself when user clicks to make purchase,
	 but if user activates a license by other means (such as clicking the link
	 in their e-mail), then we dismiss it here, so that we can do activation. */
	[self closeUpgradeActivateSheet];

	/* Perform activation */
	self.isSilentOnSuccess = silently;

	[self beginProgressIndicator];

	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	licenseManagerDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return (TLOLicenseManagerWriteLicenseFileContents(statusContext) == TLOLicenseManagerActionResultSuccess);
	};

	licenseManagerDownloader.errorBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		if (statusCode != 0 || statusContext == nil) {
			return NO;
		}

		/* lastGenLicenseKey will only be non-nil if the contents of licenseContents
		 are for a license that have not been upgraded to Textual 7 yet. */
		NSString *lastGenLicenseKey = [TLOLicenseManagerLastGen licenseKeyForLicenseContents:statusContext];

		if (lastGenLicenseKey != nil) {
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[5bu-ov]")
									  title:TXTLS(@"TLOLicenseManager[pmv-qp]", lastGenLicenseKey.prettyLicenseKey)
							  defaultButton:TXTLS(@"TLOLicenseManager[53u-lt]")
							alternateButton:nil];

			[weakSelf showUpgradeDialogForLicenseKey:lastGenLicenseKey];

			/* We return YES so no error is displayed except the one above. */
			return YES;
		}

		/* We did not handle the error. */
		return NO;
	};

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		[weakSelf licenseManagerDownloaderCompletionBlock];

		if (operationSuccessful) {
			weakSelf.unregisteredViewLicenseKeyTextField.stringValue = @"";

			[weakSelf toggleTrialTimer];

			[RZNotificationCenter() postNotificationName:TDCLicenseManagerActivatedLicenseNotification object:weakSelf];

			/* We close the upgrade dialog if a key is activated because
			 why would we keep it around under that condition? */
			[weakSelf closeUpgradeDialog];

			/* Reset context for activate sheet. */
			[weakSelf resetUpgradeActivateSheetContext];
		}

		weakSelf.operationInProgress = NO;
	};

	self.operationInProgress = YES;

	licenseManagerDownloader.isSilentOnSuccess = self.isSilentOnSuccess;

	[licenseManagerDownloader activateLicense:licenseKey.trim];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

#pragma mark -
#pragma mark License Upgrade Launch Routine

- (void)upgradeDialogAppFinishedLaunchingRoutine
{
	/* There is no reason to perform this check if this copy of Textual
	 is already registered. */
	if (TLOLicenseManagerTextualIsRegistered()) {
		/* If Textual is registered, then we reset these values because
		 there is no reason to have them hanging around. */
		[self resetUpgradeActivateSheetContext];

		return;
	}

	/* Check if we have license key saved from Textual 6 upgrade dialog. */
	if ([self showUpgradeActivateSheet]) {
		return;
	}

	/* Show upgrade dialog */
	[self showUpgradeDialogForLastGenLicense];
}

- (void)showUpgradeDialogForLastGenLicense
{
	/* Is there even a last generation key? */
	NSString *lastGenLicenseKey = [TLOLicenseManagerLastGen licenseKey];

	if (lastGenLicenseKey == nil) {
		return;
	}

	/* When was the last time the user was nagged? */
	/* Unless user hits "Remind Me Later", then the upgrade dialog is
	 not hidden due to time limit. This change was made so that if the
	 user is performing some type of action that causes them to miss the
	 dialog, such as installing an update, it will show next launch. */
	BOOL remindMeLater = [RZUserDefaults() boolForKey:@"Textual 7 Upgrade -> Tv7 -> Remind Me Later"];

	NSTimeInterval lastCheckTime = [RZUserDefaults() doubleForKey:@"Textual 7 Upgrade -> Tv7 -> Last Dialog Presentation (LMD)"];

	NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

	if (lastCheckTime > 0 && remindMeLater) {
		if ((currentTime - lastCheckTime) < _upgradeDialogRemindMeInterval) {
			LogToConsoleInfo("Not enough time has passed since last presentation");

			return;
		}
	}

	[RZUserDefaults() setDouble:currentTime forKey:@"Textual 7 Upgrade -> Tv7 -> Last Dialog Presentation (LMD)"];

	[RZUserDefaults() removeObjectForKey:@"Textual 7 Upgrade -> Tv7 -> Remind Me Later"];

	/* Nag user */
	[self showUpgradeDialogForLicenseKey:lastGenLicenseKey];
}

#pragma mark -
#pragma mark License Upgrade Dialog

- (void)showUpgradeDialogForLicenseKey:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	if (self.upgradeDialog) {
		if ([self.upgradeDialog.licenseKey isEqualToString:licenseKey]) {
			[self.upgradeDialog show];

			return;
		} else {
			[self.upgradeDialog close];
		}
	}

	  TDCLicenseUpgradeDialog *upgradeDialog =
	[[TDCLicenseUpgradeDialog alloc] initWithLicenseKey:licenseKey];

	upgradeDialog.delegate = self;

	[upgradeDialog show];

	self.upgradeDialog = upgradeDialog;
}

- (void)closeUpgradeDialog
{
	if (self.upgradeDialog) {
		[self.upgradeDialog close];
	}
}

- (void)licenseUpgradeDialogEligibilityChanged:(TDCLicenseUpgradeDialog *)sender
{
	/* Record eligibility status so that we might present an activate sheet
	 next time the user opens the app. */
	[self setUpgradeActivateSheetContextWithDialog:sender];
}

- (void)licenseUpgradeDialogWRemindMeLater:(TDCLicenseUpgradeDialog *)sender
{
	[RZUserDefaults() setBool:YES forKey:@"Textual 7 Upgrade -> Tv7 -> Remind Me Later"];
}

- (void)licenseUpgradeDialogWillClose:(TDCLicenseUpgradeDialog *)sender
{
	self.upgradeDialog = nil;
}

#pragma mark -
#pragma mark Upgrade Activate Sheet

- (BOOL)showUpgradeActivateSheet
{
	/* Do we have a properly formatted license key? */
	NSString *licenseKey = [RZUserDefaults() objectForKey:@"Textual 7 Upgrade -> Tv7 -> Eligible License Key"];

	if (licenseKey == nil) {
		return NO;
	}

	if (TLOLicenseManagerLicenseKeyIsValid(licenseKey) == NO) {
		return NO;
	}

	/* Do we have an eligibility that is acceptable? */
	NSUInteger eligibility = [RZUserDefaults() unsignedIntegerForKey:@"Textual 7 Upgrade -> Tv7 -> Eligibility"];

	if (eligibility != TLOLicenseUpgradeEligibilityDiscount &&
		eligibility != TLOLicenseUpgradeEligibilityFree &&
		eligibility != TLOLicenseUpgradeEligibilityAlreadyUpgraded)
	{
		return NO;
	}

	/* Show ourselves because we will place the sheet on self. */
	[self show];

	/* Create sheet and start it. */
	  TDCLicenseUpgradeActivateSheet *activateSheet =
	[[TDCLicenseUpgradeActivateSheet alloc] initWithLicenseKey:licenseKey eligibility:eligibility];

	activateSheet.delegate = self;

	activateSheet.window = self.window;

	[activateSheet start];

	self.upgradeActivateSheet = activateSheet;

	/* Inform launch routine to do nothing more. */
	return YES;
}

- (void)closeUpgradeActivateSheet
{
	if (self.upgradeActivateSheet) {
		[self.upgradeActivateSheet endSheet];
	}
}

- (void)setUpgradeActivateSheetContextWithDialog:(TDCLicenseUpgradeDialog *)upgradeDialog
{
	NSParameterAssert(upgradeDialog != nil);

	[RZUserDefaults() setUnsignedInteger:upgradeDialog.eligibility forKey:@"Textual 7 Upgrade -> Tv7 -> Eligibility"];

	[RZUserDefaults() setObject:upgradeDialog.licenseKey forKey:@"Textual 7 Upgrade -> Tv7 -> Eligible License Key"];
}

- (void)resetUpgradeActivateSheetContext
{
	/* We reset these values for any successful activation.
	 It is probably more proper to compare the key activated to the context,
	 but I don't think it will matter in the real world. */
	[RZUserDefaults() removeObjectForKey:@"Textual 7 Upgrade -> Tv7 -> Eligibility"];

	[RZUserDefaults() removeObjectForKey:@"Textual 7 Upgrade -> Tv7 -> Eligible License Key"];
}

- (void)upgradeActivateSheetActivateLicense:(TDCLicenseUpgradeActivateSheet *)sender
{
	NSString *licenseKey = sender.licenseKey;

	[sender endSheet];

	[self attemptToActivateLicenseKey:licenseKey];
}

- (void)upgradeActivateSheetPurchaseUpgrade:(TDCLicenseUpgradeActivateSheet *)sender
{
	[TDCLicenseUpgradeCommonActions purchaseUpgradeForLicense:sender.licenseKey];
}

- (void)upgradeActivateSheetSuppressed:(TDCLicenseUpgradeActivateSheet *)sender
{
	[self resetUpgradeActivateSheetContext];
}

- (void)upgradeActivateSheetWillClose:(TDCLicenseUpgradeActivateSheet *)sender
{
	self.upgradeActivateSheet = nil;
}

#pragma mark -
#pragma mark Recover Lost License

- (void)unregisteredViewRecoveryLostLicense:(id)sender
{
	  TDCLicenseManagerRecoverLostLicenseSheet *recoverLostLicenseSheet =
	[[TDCLicenseManagerRecoverLostLicenseSheet alloc] initWithWindow:self.window];

	recoverLostLicenseSheet.delegate = self;

	[recoverLostLicenseSheet start];

	self.recoverLostLicenseSheet = recoverLostLicenseSheet;
}

- (void)licenseManagerRecoverLostLicenseSheet:(TDCLicenseManagerRecoverLostLicenseSheet *)sender onOk:(NSString *)contactAddress
{
	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		[weakSelf licenseManagerDownloaderCompletionBlock];
	};

	licenseManagerDownloader.isSilentOnSuccess = self.isSilentOnSuccess;

	[licenseManagerDownloader requestLostLicenseKeyForContactAddress:contactAddress];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

- (void)licenseManagerRecoverLostLicenseSheetWillClose:(TDCLicenseManagerRecoverLostLicenseSheet *)sender
{
	self.recoverLostLicenseSheet = nil;

	if (self.licenseManagerDownloader) {
		[self beginProgressIndicator];
	}
}

#pragma mark -
#pragma mark Deactivate License

- (void)registeredViewDeactivateTextual:(id)sender
{
	BOOL deactivateCopy = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[z87-wb]")
													title:TXTLS(@"TLOLicenseManager[pg1-a9]")
											defaultButton:TXTLS(@"Prompts[mvh-ms]")
										  alternateButton:TXTLS(@"Prompts[99q-gg]")];

	if (deactivateCopy == NO) {
		return; // Cancel operation...
	}

	/* License deactivation does not use a progress indicator because
	 it does not have to touch the network. It will only delete a file
	 on the hard drive which is typically instant. */
	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	licenseManagerDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return (TLOLicenseManagerDeleteLicenseFile() == TLOLicenseManagerActionResultSuccess);
	};

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		[weakSelf licenseManagerDownloaderCompletionBlock];

		[weakSelf toggleTrialTimer];

		[RZNotificationCenter() postNotificationName:TDCLicenseManagerDeactivatedLicenseNotification object:weakSelf];
	};

	licenseManagerDownloader.isSilentOnSuccess = self.isSilentOnSuccess;

	[licenseManagerDownloader deactivateLicense];

//	self.licenseManagerDownloader = licenseManagerDownloader;
}

#pragma mark -
#pragma mark Mac App Store Receipt Processing

- (void)unregisteredViewMigrateMacAppStorePurchase:(id)sender
{
	  TDCLicenseManagerMigrateAppStoreSheet *migrateAppStoreSheet =
	[[TDCLicenseManagerMigrateAppStoreSheet alloc] initWithWindow:self.window];

	migrateAppStoreSheet.delegate = self;

	[migrateAppStoreSheet start];

	self.migrateAppStoreSheet = migrateAppStoreSheet;
}

- (void)licenseManagerMigrateAppStoreSheet:(TDCLicenseManagerMigrateAppStoreSheet *)sender
							convertReceipt:(NSString *)receiptData
						  licenseOwnerName:(NSString *)licenseOwnerName
				licenseOwnerContactAddress:(NSString *)licenseOwnerContactAddress
{
	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		[weakSelf licenseManagerDownloaderCompletionBlock];
	};

	licenseManagerDownloader.isSilentOnSuccess = self.isSilentOnSuccess;

	[licenseManagerDownloader migrateMacAppStorePurchase:receiptData
											 licenseOwnerName:licenseOwnerName
								   licenseOwnerContactAddress:licenseOwnerContactAddress];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

- (void)licenseManagerMigrateAppStoreSheetWillClose:(TDCLicenseManagerMigrateAppStoreSheet *)sender
{
	self.migrateAppStoreSheet = nil;

	if (self.licenseManagerDownloader) {
		[self beginProgressIndicator];
	}
}

#pragma mark -
#pragma mark NSTextField Delegate

- (void)controlTextDidChange:(NSNotification *)obj
{
	if (obj.object == self.unregisteredViewLicenseKeyTextField) {
		[self updateUnregisteredViewActivationButton];
	}
}

#pragma mark -
#pragma mark Helper Methods

- (void)licenseManagerDownloaderCompletionBlock
{
	self.licenseManagerDownloader = nil;

	[self endProgressIndicator];

	[self updateSelectedPane];

	[self updateUnregisteredViewActivationButton];

	self.isSilentOnSuccess = NO; // Reset flag regardless of state.
								 // This flag is one-time use.
}

- (void)beginProgressIndicator
{
	self.progressIndicator = [[TDCProgressIndicatorSheet alloc] initWithWindow:self.window];

	[self.progressIndicator start];
}

- (void)endProgressIndicator
{
	if (self.progressIndicator == nil) {
		return;
	}

	[self.progressIndicator stop];

	self.progressIndicator = nil;
}

#pragma mark -
#pragma mark Notification Center

- (NSString *)timeRemainingInTrialFormattedMessage
{
	NSTimeInterval timeLeft = TLOLicenseManagerTimeRemainingTrial();

	if (timeLeft >= 0) {
		return TXTLS(@"TLOLicenseManager[kn7-ju]");
	}

	NSString *formattedTimeRemainingString = TXHumanReadableTimeInterval(timeLeft, YES, NSCalendarUnitDay);

	return TXTLS(@"TLOLicenseManager[wdl-3f]", formattedTimeRemainingString);
}

- (void)scheduleTimeRemainingInTrialNotification
{
	if (TLOLicenseManagerTextualIsRegistered() || TLOLicenseManagerIsTrialExpired()) {
		return; // Do not schedule notification...
	}

	NSString *title = [self timeRemainingInTrialFormattedMessage];

	NSString *message = TXTLS(@"TLOLicenseManager[ccj-ag]");

	[sharedNotificationController() scheduleLicenseManagerNotificationWithTitle:title message:message];
}

#pragma mark -
#pragma mark Window Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.window saveWindowStateForClass:self.class];
}

@end
#endif

NS_ASSUME_NONNULL_END
