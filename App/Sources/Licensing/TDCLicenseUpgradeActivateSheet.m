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
#import "NSStringHelper.h"
#import "TDCLicenseUpgradeActivateSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
@interface TDCLicenseUpgradeActivateSheet ()
@property (nonatomic, copy, readwrite) NSString *licenseKey;
@property (nonatomic, assign, readwrite) TLOLicenseUpgradeEligibility eligibility;
@property (nonatomic, strong) IBOutlet NSWindow *sheetEligibleDiscount;
@property (nonatomic, strong) IBOutlet NSWindow *sheetEligibleFree;
@property (nonatomic, weak) IBOutlet NSTextField *sheetEligibleDiscountTitleTextField;
@property (nonatomic, weak) IBOutlet NSTextField *sheetEligibleFreeTitleTextField;
@property (nonatomic, weak) IBOutlet NSButton *sheetEligibleDiscountSuppressionButton;
@property (nonatomic, weak) IBOutlet NSButton *sheetEligibleFreeSuppressionButton;

- (IBAction)actionActivateLicense:(id)sender;
- (IBAction)actionPurchaseUpgrade:(id)sender;
- (IBAction)actionCancel:(id)sender;
@end

@implementation TDCLicenseUpgradeActivateSheet

#pragma mark -
#pragma mark Dialog Foundation

- (instancetype)initWithLicenseKey:(NSString *)licenseKey eligibility:(TLOLicenseUpgradeEligibility)eligibility
{
	NSParameterAssert(licenseKey != nil);

	if ((self = [super initWithWindow:nil])) {
		self.licenseKey = licenseKey;

		self.eligibility = eligibility;

		[self prepareInitialState];

		return self;
	}

	return self;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCLicenseUpgradeActivateSheet" owner:self topLevelObjects:nil];
}

- (void)start
{
	[self startSheet];
}

- (void)startSheet
{
	NSTextField *sheetTitleTextField = nil;

	if (self.eligibility == TLOLicenseUpgradeEligibilityDiscount)
	{
		self.sheet = self.sheetEligibleDiscount;

		sheetTitleTextField = self.sheetEligibleDiscountTitleTextField;
	}
	else if (self.eligibility == TLOLicenseUpgradeEligibilityFree ||
			 self.eligibility == TLOLicenseUpgradeEligibilityAlreadyUpgraded)
	{
		self.sheet = self.sheetEligibleFree;

		sheetTitleTextField = self.sheetEligibleFreeTitleTextField;
	}
	else
	{
		NSAssert(NO, @"Cannot display a sheet for this type of eligibility");
	}

	sheetTitleTextField.stringValue =
	[NSString stringWithFormat:
		 sheetTitleTextField.stringValue, self.licenseKey.prettyLicenseKey];

	[super startSheet];
}

- (void)actionActivateLicense:(id)sender
{
	[self.delegate upgradeActivateSheetActivateLicense:self];
}

- (void)actionPurchaseUpgrade:(id)sender
{
	[self.delegate upgradeActivateSheetPurchaseUpgrade:self];
}

- (void)actionCancel:(id)sender
{
	/* Only one of two sheets can ever be visible so just check if one is on. */
	if (self.sheetEligibleDiscountSuppressionButton.state == NSControlStateValueOn ||
		self.sheetEligibleFreeSuppressionButton.state == NSControlStateValueOn)
	{
		[self.delegate upgradeActivateSheetSuppressed:self];
	}

	[self endSheet];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.delegate upgradeActivateSheetWillClose:self];
}

@end
#endif

NS_ASSUME_NONNULL_END
