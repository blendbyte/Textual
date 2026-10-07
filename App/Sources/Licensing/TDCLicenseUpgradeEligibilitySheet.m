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
#import "TXGlobalModels.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLicenseManagerDownloaderPrivate.h"
#import "TDCAlert.h"
#import "TDCProgressIndicatorSheetPrivate.h"
#import "TDCLicenseUpgradeEligibilitySheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
@interface TDCLicenseUpgradeEligibilitySheet ()
@property (nonatomic, copy, readwrite) NSString *licenseKey;
@property (nonatomic, assign, readwrite) TLOLicenseUpgradeEligibility eligibility;
@property (nonatomic, strong) TLOLicenseManagerDownloader *licenseManagerDownloader;
@property (nonatomic, strong) TDCProgressIndicatorSheet *progressIndicator;
@property (nonatomic, strong) IBOutlet NSWindow *sheetNotEligible;
@property (nonatomic, strong) IBOutlet NSWindow *sheetEligibleDiscount;
@property (nonatomic, strong) IBOutlet NSWindow *sheetEligibleFree;
@property (nonatomic, assign) BOOL checkingEligibility;

- (IBAction)actionContactSupport:(id)sender;
- (IBAction)actionActivateLicense:(id)sender;
- (IBAction)actionPurchaseUpgrade:(id)sender;
- (IBAction)actionPurchaseStandalone:(id)sender;
- (IBAction)actionClose:(id)sender;
@end

@implementation TDCLicenseUpgradeEligibilitySheet

#pragma mark -
#pragma mark Dialog Foundation

- (instancetype)initWithLicenseKey:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	if ((self = [super initWithWindow:nil])) {
		self.licenseKey = licenseKey;

		[self prepareInitialState];

		return self;
	}

	return self;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCLicenseUpgradeEligibilitySheet" owner:self topLevelObjects:nil];

	self.eligibility = TLOLicenseUpgradeEligibilityUnknown;
}

- (void)startSheet
{
	LogToConsoleError("This method does nothing. Use -checkEligibility instead");
	LogStackTrace();
}

- (void)endSheet
{
	[self _cancelEligibilityCheck];

	[super endSheet];
}

- (void)endSheetEarly
{
	/* If we end sheet early, before self.sheet is ever defined,
	 then trying to close it wont fire this delegate call.
	 We fake the call to the delegate so that the sheet can be released. */
	[self windowWillClose:nil];
}

- (void)checkEligibility
{
	[self _checkEligibility];
}

#pragma mark -
#pragma mark Utilities

- (void)_beginProgressIndicator
{
	[self _beginProgressIndicatorInWindow:self.window];
}

- (void)_beginProgressIndicatorInWindow:(NSWindow *)window
{
	self.progressIndicator = [[TDCProgressIndicatorSheet alloc] initWithWindow:window];

	[self.progressIndicator start];
}

- (void)_endProgressIndicator
{
	if (self.progressIndicator == nil) {
		return;
	}

	[self.progressIndicator stop];

	self.progressIndicator = nil;
}

#pragma mark -
#pragma mark Eligibility Sheet Actions

- (void)_presentEligibilityCheckFailedSheetWithError:(NSString *)errorMessage
{
	NSParameterAssert(errorMessage != nil);

	[TDCAlert alertSheetWithWindow:self.window
							  body:TXTLS(@"TDCLicenseUpgradeEligibilitySheet[8hb-y3]", errorMessage)
							 title:TXTLS(@"TDCLicenseUpgradeEligibilitySheet[wmk-xg]", self.licenseKey.prettyLicenseKey)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:TXTLS(@"TDCLicenseUpgradeEligibilitySheet[dn3-4r]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked == TDCAlertResponseAlternate) {
						   [self actionContactSupport:nil];
					   }
					   
					   [self endSheetEarly];
				   }];
}

- (void)_cancelEligibilityCheck
{
	if (self.checkingEligibility == NO) {
		return;
	}

	[self.licenseManagerDownloader cancelRequest];

	[self _checkEligibilityCompletionBlock];
}

- (void)_checkEligibility
{
	if (self.eligibility != TLOLicenseUpgradeEligibilityUnknown) {
		[self _eligibilityDetermined];

		return;
	}

	[self _checkEligibilityOfLicense:self.licenseKey];
}

- (void)_checkEligibilityOfLicense:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	if (self.checkingEligibility == NO) {
		self.checkingEligibility = YES;
	} else {
		return;
	}

	[self _beginProgressIndicator];

	__weak TDCLicenseUpgradeEligibilitySheet *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		[weakSelf _checkEligibilityCompletionBlock];

		[weakSelf _extractEligibilityFromResponseWithStatusCode:statusCode statusContext:statusContext];
	};

	licenseManagerDownloader.isSilentOnFailure = YES;
	licenseManagerDownloader.isSilentOnSuccess = YES;

	[licenseManagerDownloader checkUpgradeEligibilityOfLicense:licenseKey];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

- (void)_checkEligibilityCompletionBlock
{
	self.licenseManagerDownloader = nil;

	[self _endProgressIndicator];

	self.checkingEligibility = NO;
}

- (void)_extractEligibilityFromResponseWithStatusCode:(NSUInteger)statusCode statusContext:(nullable NSDictionary<NSString *, id> *)statusContext
{
	LogToConsoleDebug("Status code: %{public}lu", statusCode);

#define _presentEligibilityCheckFailedSheet 	\
	[self _presentEligibilityCheckFailedSheetWithError:errorMessage]; 	\
	return;

	/* Check for common status codes. */
	if (statusCode != 0) {
		NSString *errorMessage = nil;

		if (statusCode == TLOLicenseManagerDownloaderRequestStatusCodeServiceIsBusy) {
			errorMessage = TXTLS(@"TDCLicenseUpgradeEligibilitySheet[9uu-go]");
		} else {
			errorMessage = TXTLS(@"TDCLicenseUpgradeEligibilitySheet[awy-4i]", statusCode);
		}

		_presentEligibilityCheckFailedSheet
	}

	/* There is never a time a status context should be nil for this check. */
	if (statusContext == nil) {
		NSString *errorMessage = TXTLS(@"TDCLicenseUpgradeEligibilitySheet[z70-6s]");

		_presentEligibilityCheckFailedSheet
	}

	/* Ensure the response we received is a type we support. */
	id eligibilityObject = statusContext[@"licenseUpgradeEligibility"];

	if (eligibilityObject == nil || [eligibilityObject isKindOfClass:[NSNumber class]] == NO) {
		LogToConsoleError("'licenseUpgradeEligibility' is nil or not of kind 'NSNumber'");

		NSString *errorMessage = TXTLS(@"TDCLicenseUpgradeEligibilitySheet[gc5-ko]");

		_presentEligibilityCheckFailedSheet
	}

	/* Save eligibility */
	NSUInteger eligibility = [eligibilityObject unsignedIntegerValue];

	if (eligibility != TLOLicenseUpgradeEligibilityDiscount &&
		eligibility != TLOLicenseUpgradeEligibilityFree &&
		eligibility != TLOLicenseUpgradeEligibilityNot &&
		eligibility != TLOLicenseUpgradeEligibilityAlreadyUpgraded)
	{
		NSString *errorMessage = TXTLS(@"TDCLicenseUpgradeEligibilitySheet[5s6-sb]", eligibility);

		_presentEligibilityCheckFailedSheet
	}

	self.eligibility = eligibility;

	/* Present sheet */
	[self _eligibilityDetermined];

	/* Inform delegate */
	[self.delegate upgradeEligibilitySheetChanged:self];

#undef _presentEligibilityCheckFailedSheet
}

- (void)_eligibilityDetermined
{
	if (self.eligibility == TLOLicenseUpgradeEligibilityDiscount) {
		self.sheet = self.sheetEligibleDiscount;
	} else if (self.eligibility == TLOLicenseUpgradeEligibilityNot) {
		self.sheet = self.sheetNotEligible;
	} else if (self.eligibility == TLOLicenseUpgradeEligibilityFree ||
			   self.eligibility == TLOLicenseUpgradeEligibilityAlreadyUpgraded)
	{
		self.sheet = self.sheetEligibleFree;
	}

	[super startSheet];
}

- (void)actionContactSupport:(id)sender
{
	[self.delegate upgradeEligibilitySheetContactSupport:self];
}

- (void)actionActivateLicense:(id)sender
{
	[self.delegate upgradeEligibilitySheetActivateLicense:self];
}

- (void)actionPurchaseUpgrade:(id)sender
{
	[self.delegate upgradeEligibilitySheetPurchaseUpgrade:self];
}

- (void)actionPurchaseStandalone:(id)sender
{
	[self.delegate upgradeEligibilitySheetPurchaseStandalone:self];
}

- (void)actionClose:(id)sender
{
	[self endSheet];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.delegate upgradeEligibilitySheetWillClose:self];
}

@end
#endif

NS_ASSUME_NONNULL_END
