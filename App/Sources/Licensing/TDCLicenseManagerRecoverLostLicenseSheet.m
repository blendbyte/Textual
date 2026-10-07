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

#import "TLOLocalization.h"
#import "TVCValidatedTextField.h"
#import "TDCLicenseManagerRecoverLostLicenseSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
#define _licenseOwnerContactAddressMaximumLength			2000

@interface TDCLicenseManagerRecoverLostLicenseSheet ()
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *contactAddressTextField;
@end

@implementation TDCLicenseManagerRecoverLostLicenseSheet

- (instancetype)initWithWindow:(nullable NSWindow *)window
{
	if ((self = [super initWithWindow:window])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCLicenseManagerRecoverLostLicenseSheet" owner:self topLevelObjects:nil];
}

- (void)start
{
	self.contactAddressTextField.stringValueIsInvalidOnEmpty = YES;
	self.contactAddressTextField.stringValueUsesOnlyFirstToken = YES;

	self.contactAddressTextField.textDidChangeCallback = self;

	self.contactAddressTextField.stringValue = [XRAddressBook myEmailAddress];

	self.contactAddressTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([currentValue containsCharactersFromCharacterSet:[NSCharacterSet newlineCharacterSet]]) {
			return TXTLS(@"CommonErrors[gas-v8]");
		}

		if (currentValue.length > _licenseOwnerContactAddressMaximumLength) {
			return TXTLS(@"CommonErrors[2cb-af]", _licenseOwnerContactAddressMaximumLength);
		}

		return nil;
	};

	[self startSheet];
}

- (void)ok:(id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	NSString *contactAddress = self.contactAddressTextField.value;

	[self.delegate licenseManagerRecoverLostLicenseSheet:self onOk:contactAddress];

	[super ok:sender];
}

- (BOOL)okOrError
{
	return [self okOrErrorForTextField:self.contactAddressTextField];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.delegate licenseManagerRecoverLostLicenseSheetWillClose:self];
}

@end
#endif

NS_ASSUME_NONNULL_END
