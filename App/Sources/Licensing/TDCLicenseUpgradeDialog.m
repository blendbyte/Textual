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
#import "TLOLicenseManagerPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TDCLicenseUpgradeCommonActionsPrivate.h"
#import "TDCLicenseUpgradeDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
@interface TDCLicenseUpgradeDialog ()
@property (nonatomic, copy, readwrite) NSString *licenseKey;
@property (nonatomic, assign, readwrite) TLOLicenseUpgradeEligibility eligibility;
@property (nonatomic, strong, nullable) TDCLicenseUpgradeEligibilitySheet *EligibilitySheet;
@property (nonatomic, weak) IBOutlet NSButton *upgradeDialogContinueTrialButton;
@property (nonatomic, weak) IBOutlet NSTextField *upgradeDialogTrialPeriodTextField;

- (IBAction)actionLearnMore:(id)sender;
- (IBAction)actionPurchaseUpgrade:(id)sender;
- (IBAction)actionContinueTrial:(id)sender;
- (IBAction)actionRemindMeLater:(id)sender;
@end

@implementation TDCLicenseUpgradeDialog

#pragma mark -
#pragma mark Dialog Foundation

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithLicenseKey:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	if ((self = [super init])) {
		self.licenseKey = licenseKey;

		[self prepareInitialState];

		return self;
	}

	return self;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCLicenseUpgradeDialog" owner:self topLevelObjects:nil];

	self.eligibility = TLOLicenseUpgradeEligibilityUnknown;
}

- (void)show
{
	self.upgradeDialogContinueTrialButton.enabled = (TLOLicenseManagerIsTrialExpired() == NO);

	self.upgradeDialogTrialPeriodTextField.stringValue = [[TXSharedApplication sharedLicenseManagerDialog] timeRemainingInTrialFormattedMessage];

	[super show];
}

#pragma mark -
#pragma mark Eligibility Sheet Actions

- (void)checkEligibility
{
	if (self.EligibilitySheet != nil) {
		return;
	}

	  TDCLicenseUpgradeEligibilitySheet *eligibilitySheet =
	[[TDCLicenseUpgradeEligibilitySheet alloc] initWithLicenseKey:self.licenseKey];

	eligibilitySheet.delegate = self;

	eligibilitySheet.window = self.window;

	[eligibilitySheet checkEligibility];

	self.EligibilitySheet = eligibilitySheet;
}

- (void)closeEligibilitySheet
{
	if (self.EligibilitySheet) {
		[self.EligibilitySheet endSheet];
	}
}

- (void)upgradeEligibilitySheetContactSupport:(TDCLicenseUpgradeEligibilitySheet *)sender
{
	[TDCLicenseUpgradeCommonActions contactSupport];
}

- (void)upgradeEligibilitySheetActivateLicense:(TDCLicenseUpgradeEligibilitySheet *)sender
{
	[TDCLicenseUpgradeCommonActions activateLicense:sender.licenseKey];
}

- (void)upgradeEligibilitySheetPurchaseUpgrade:(TDCLicenseUpgradeEligibilitySheet *)sender
{
	[TDCLicenseUpgradeCommonActions purchaseUpgradeForLicense:sender.licenseKey];
}

- (void)upgradeEligibilitySheetPurchaseStandalone:(TDCLicenseUpgradeEligibilitySheet *)sender
{
	[TDCLicenseUpgradeCommonActions openStandaloneStore];
}

- (void)upgradeEligibilitySheetChanged:(TDCLicenseUpgradeEligibilitySheet *)sender
{
	self.eligibility = sender.eligibility;

	[self.delegate licenseUpgradeDialogEligibilityChanged:self];
}

- (void)upgradeEligibilitySheetWillClose:(TDCLicenseUpgradeEligibilitySheet *)sender
{
	self.EligibilitySheet = nil;
}

#pragma mark -
#pragma mark Upgrade Dialog Actions

- (void)actionLearnMore:(id)sender
{
	[TDCLicenseUpgradeCommonActions learnMore];
}

- (void)actionPurchaseUpgrade:(id)sender
{
	[self checkEligibility];
}

- (void)actionContinueTrial:(id)sender
{
	[self.delegate licenseUpgradeDialogWRemindMeLater:self];

	[self close];
}

- (void)actionRemindMeLater:(id)sender
{
	[self.delegate licenseUpgradeDialogWRemindMeLater:self];

	[self close];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self closeEligibilitySheet];

	[self.delegate licenseUpgradeDialogWillClose:self];
}

@end
#endif

NS_ASSUME_NONNULL_END
