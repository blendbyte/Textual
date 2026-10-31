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

#define _trialReminderWindow 				604800 // 7 days

#define _trialReminderLastShownDefaultsKey 	@"License Manager -> Trial Reminder -> Last Shown"

@interface TDCLicenseManagerDialog () <NSControlTextEditingDelegate>
@property (nonatomic, strong) IBOutlet NSView *contentViewUnregisteredTextualView;
@property (nonatomic, strong) IBOutlet NSView *contentViewRegisteredTextualView;
@property (nonatomic, weak) IBOutlet NSTextField *unregisteredViewLicenseKeyTextField;
@property (nonatomic, weak) IBOutlet NSTextField *unregisteredViewTrialInformationTextField;
@property (nonatomic, weak) IBOutlet NSTextField *registeredViewLicenseKeyTextField;
@property (nonatomic, weak) IBOutlet NSTextField *registeredViewLicenseDateTextField;
@property (nonatomic, weak) IBOutlet NSButton *registeredViewDeactivateTextualButton;
@property (nonatomic, weak) IBOutlet NSButton *unregisteredViewActivateTextualButton;
@property (nonatomic, weak) IBOutlet NSButton *unregisteredViewCancelButton;
@property (nonatomic, weak) IBOutlet NSButton *unregisteredViewRecoveryLostLicenseButton;
@property (nonatomic, strong, nullable) TDCProgressIndicatorSheet *progressIndicator;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *licenseManagerDownloader;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *trialDownloader;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *previousActivationDownloader;
@property (nonatomic, strong, nullable) TDCLicenseUpgradeDialog *upgradeDialog;
@property (nonatomic, strong, nullable) TDCLicenseUpgradeActivateSheet *upgradeActivateSheet;
@property (nonatomic, assign) BOOL textualIsRegistered;
@property (nonatomic, assign) BOOL isSilentOnSuccess;
@property (nonatomic, assign) BOOL operationInProgress;
@property (nonatomic, strong, nullable) TLOTimer *trialTimer;

- (IBAction)unregisteredViewActivateTextual:(nullable id)sender;
- (IBAction)unregisteredViewCancel:(nullable id)sender;
- (IBAction)unregisteredViewPurchaseTextual:(nullable id)sender;
- (IBAction)unregisteredViewRecoveryLostLicense:(nullable id)sender;

- (IBAction)registeredViewDeactivateTextual:(nullable id)sender;
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
	[self loadNib];

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

	/* The reminder is once a day, so a Textual left open for days
	 checks again each time the calendar day changes. */
	[RZNotificationCenter() addObserver:self selector:@selector(calendarDayChanged:) name:NSCalendarDayChangedNotification object:nil];

	[self toggleTrialTimer];

	[self requestTrialFromServer];

	[self activateLicenseKeyUsingArgumentDictionary];

	[self upgradeDialogAppFinishedLaunchingRoutine];
}

- (void)updateSelectedPane
{
	NSView *contentView = nil;

	self.textualIsRegistered = TLOLicenseManagerTextualIsRegistered();

	if (self.textualIsRegistered)
	{
		NSString *licenseKey = TLOLicenseManagerLicenseKey();
		NSString *licenseDate = TLOLicenseManagerLicenseDateFormatted();

		self.registeredViewLicenseKeyTextField.stringValue = (licenseKey ?: @"");
		self.registeredViewLicenseDateTextField.stringValue = (licenseDate ?: @"");

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
#pragma mark Trial

- (void)requestTrialFromServer
{
	/* The server keeps one trial per Mac; until it answers, the trial counts
	 from this Mac's first launch. Failures change nothing and say nothing. */
	if (TLOLicenseManagerTextualIsRegistered()) {
		return;
	}

	TLOLicenseManagerDownloader *trialDownloader = [TLOLicenseManagerDownloader new];

	trialDownloader.isSilentOnFailure = YES;
	trialDownloader.isSilentOnSuccess = YES;

	trialDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return TLOLicenseManagerSaveTrial(statusContext);
	};

	__weak TDCLicenseManagerDialog *weakSelf = self;

	trialDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		strongSelf.trialDownloader = nil;

		if (operationSuccessful == NO) {
			return;
		}

		[strongSelf trialChanged];
	};

	[trialDownloader requestTrial];

	self.trialDownloader = trialDownloader;
}

- (void)trialChanged
{
	[self stopTrialTimer];

	[self toggleTrialTimer];

	[self updateSelectedPane];

	if (TLOLicenseManagerTextualIsRegistered() == NO && TLOLicenseManagerIsTrialExpired()) {
		[RZNotificationCenter() postNotificationName:TDCLicenseManagerTrialExpiredNotification object:self];
	}
}

#pragma mark -
#pragma mark Activate License

- (void)unregisteredViewPurchaseTextual:(nullable id)sender
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

- (void)unregisteredViewCancel:(nullable id)sender
{
	[self close];
}

- (void)updateUnregisteredViewActivationButton
{
	if (self.textualIsRegistered) {
		return; // Cancel operation...
	}

	NSString *licenseKeyValue = self.unregisteredViewLicenseKeyTextField.stringValue;

	if (TLOLicenseManagerLicenseKeyIsValid(licenseKeyValue)) {
		self.unregisteredViewActivateTextualButton.enabled = YES;
	} else {
		self.unregisteredViewActivateTextualButton.enabled = NO;
	}
}

- (void)unregisteredViewActivateTextual:(nullable id)sender
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
	licenseKey = TLOLicenseManagerCleanedLicenseKey(licenseKey);

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
	[self attemptToActivateLicenseKey:licenseKey silently:silently replacingActivation:nil];
}

- (void)attemptToActivateLicenseKey:(NSString *)licenseKey silently:(BOOL)silently replacingActivation:(nullable NSString *)replaceActivationID
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

	NSString *cleanedLicenseKey = TLOLicenseManagerCleanedLicenseKey(licenseKey);

	/* Do not activate license we are already using. */
	if ([cleanedLicenseKey isEqualToString:TLOLicenseManagerLicenseKey()]) {
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

	/* A Mac moving to another key frees its seat on the old one afterwards */
	NSString *previousActivationID = TLOLicenseManagerActivationID();

	licenseManagerDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return (TLOLicenseManagerSaveActivation(statusContext, cleanedLicenseKey) == TLOLicenseManagerActionResultSuccess);
	};

	licenseManagerDownloader.errorBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		/* Both seats taken: shown once the progress sheet is gone */
		if (statusCode == 7100003) {
			XRPerformBlockAsynchronouslyOnMainQueue(^{
				[weakSelf presentSeatsFullForLicenseKey:cleanedLicenseKey statusContext:statusContext silently:silently];
			});

			return YES;
		}

		/* No seat-freeings left */
		if (statusCode == 7100005) {
			XRPerformBlockAsynchronouslyOnMainQueue(^{
				[weakSelf presentNoMovesLeftWithStatusContext:statusContext];
			});

			return YES;
		}

		/* The chosen seat was freed meanwhile: try again without it */
		if (statusCode == 7100006) {
			XRPerformBlockAsynchronouslyOnMainQueue(^{
				[weakSelf attemptToActivateLicenseKey:cleanedLicenseKey silently:silently];
			});

			return YES;
		}

		/* A Textual 7 key: it can be upgraded */
		if (statusCode != 7100004) {
			return NO;
		}

		[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[5bu-ov]")
								  title:TXTLS(@"TLOLicenseManager[pmv-qp]", cleanedLicenseKey.prettyLicenseKey)
						  defaultButton:TXTLS(@"TLOLicenseManager[53u-lt]")
						alternateButton:nil];

		[weakSelf showUpgradeDialogForLicenseKey:cleanedLicenseKey];

		return YES;
	};

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		[strongSelf licenseManagerDownloaderCompletionBlock];

		if (operationSuccessful) {
			strongSelf.unregisteredViewLicenseKeyTextField.stringValue = @"";

			[strongSelf toggleTrialTimer];

			[strongSelf freePreviousActivation:previousActivationID];

			[RZNotificationCenter() postNotificationName:TDCLicenseManagerActivatedLicenseNotification object:strongSelf];

			/* We close the upgrade dialog if a key is activated because
			 why would we keep it around under that condition? */
			[strongSelf closeUpgradeDialog];

			/* Reset context for activate sheet. */
			[strongSelf resetUpgradeActivateSheetContext];
		}

		strongSelf.operationInProgress = NO;
	};

	self.operationInProgress = YES;

	licenseManagerDownloader.isSilentOnSuccess = self.isSilentOnSuccess;

	[licenseManagerDownloader activateLicense:cleanedLicenseKey replacingActivation:replaceActivationID];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

- (void)freePreviousActivation:(nullable NSString *)activationID
{
	/* Nothing, or the same seat again */
	if (activationID == nil || [activationID isEqualToString:TLOLicenseManagerActivationID()]) {
		return;
	}

	/* Silent: if it fails, the old key's owner frees that seat the next
	 time both are taken, from the sheet below */
	TLOLicenseManagerDownloader *previousActivationDownloader = [TLOLicenseManagerDownloader new];

	previousActivationDownloader.isSilentOnFailure = YES;
	previousActivationDownloader.isSilentOnSuccess = YES;

	__weak TDCLicenseManagerDialog *weakSelf = self;

	previousActivationDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		weakSelf.previousActivationDownloader = nil;
	};

	[previousActivationDownloader deactivateActivation:activationID];

	self.previousActivationDownloader = previousActivationDownloader;
}

#pragma mark -
#pragma mark Both Seats Taken

- (void)presentSeatsFullForLicenseKey:(NSString *)licenseKey statusContext:(nullable id)statusContext silently:(BOOL)silently
{
	NSParameterAssert(licenseKey != nil);

	NSArray *seatList = nil;

	NSInteger movesLeft = 0;

	if ([statusContext isKindOfClass:[NSDictionary class]]) {
		seatList = [statusContext arrayForKey:@"seats"];

		movesLeft = [statusContext integerForKey:@"remoteFreesLeft" orUseDefault:0];
	}

	/* Only seats Textual can name */
	NSMutableArray<NSDictionary *> *seats = [NSMutableArray array];

	for (id seat in seatList) {
		if ([seat isKindOfClass:[NSDictionary class]] &&
			[seat[@"activationID"] isKindOfClass:[NSString class]] &&
			[seat[@"macModel"] isKindOfClass:[NSString class]])
		{
			[seats addObject:seat];
		}
	}

	if (seats.count == 0) {
		[TDCAlert alertSheetWithWindow:self.window
								  body:TXTLS(@"TLOLicenseManager[s2m-f1]")
								 title:TXTLS(@"TLOLicenseManager[s2m-f0]")
						 defaultButton:TXTLS(@"Prompts[c7s-dq]")
					   alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")
						   otherButton:nil
					   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
			if (buttonClicked == TDCAlertResponseAlternate) {
				[menuController() contactSupport:nil];
			}
		}];

		return;
	}

	if (movesLeft <= 0) {
		[self presentNoMovesLeftWithStatusContext:statusContext];

		return;
	}

	/* One choice per Mac; the one used longest ago is chosen to begin with */
	NSMutableArray<NSButton *> *seatButtons = [NSMutableArray arrayWithCapacity:seats.count];

	NSButton *leastRecentlyUsedButton = nil;

	NSDate *leastRecentlyUsedDate = nil;

	for (NSDictionary *seat in seats) {
		NSString *title = seat[@"macModel"];

		NSDate *lastSeenAt = seat[@"lastSeenAt"];

		if ([lastSeenAt isKindOfClass:[NSDate class]]) {
			NSString *lastSeenAtText = [NSDateFormatter localizedStringFromDate:lastSeenAt dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];

			title = TXTLS(@"TLOLicenseManager[s2m-f3]", title, lastSeenAtText);
		} else {
			lastSeenAt = nil;
		}

		NSButton *seatButton = [NSButton radioButtonWithTitle:title target:self action:@selector(seatsFullSeatChosen:)];

		[seatButtons addObject:seatButton];

		if (leastRecentlyUsedButton == nil ||
			(lastSeenAt != nil && (leastRecentlyUsedDate == nil || [lastSeenAt compare:leastRecentlyUsedDate] == NSOrderedAscending)))
		{
			leastRecentlyUsedButton = seatButton;

			leastRecentlyUsedDate = lastSeenAt;
		}
	}

	leastRecentlyUsedButton.state = NSControlStateValueOn;

	NSString *movesLeftText = nil;

	if (movesLeft == 1) {
		movesLeftText = TXTLS(@"TLOLicenseManager[s2m-f5]");
	} else {
		movesLeftText = TXTLS(@"TLOLicenseManager[s2m-f4]", movesLeft);
	}

	NSTextField *movesLeftField = [NSTextField wrappingLabelWithString:movesLeftText];

	movesLeftField.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	movesLeftField.textColor = [NSColor secondaryLabelColor];
	movesLeftField.preferredMaxLayoutWidth = 280.0;

	NSStackView *accessoryView = [NSStackView stackViewWithViews:seatButtons];

	accessoryView.orientation = NSUserInterfaceLayoutOrientationVertical;
	accessoryView.alignment = NSLayoutAttributeLeading;
	accessoryView.spacing = 6.0;

	[accessoryView addView:movesLeftField inGravity:NSStackViewGravityTop];

	[accessoryView setCustomSpacing:12.0 afterView:seatButtons.lastObject];

	accessoryView.frame = NSMakeRect(0.0, 0.0, 280.0, accessoryView.fittingSize.height);

	__weak TDCLicenseManagerDialog *weakSelf = self;

	[TDCAlert alertSheetWithWindow:self.window
							  body:TXTLS(@"TLOLicenseManager[s2m-f2]")
							 title:TXTLS(@"TLOLicenseManager[s2m-f0]")
					 defaultButton:TXTLS(@"TLOLicenseManager[s2m-f6]")
				   alternateButton:TXTLS(@"Prompts[qso-2g]")
					   otherButton:nil
					 accessoryView:accessoryView
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked != TDCAlertResponseDefault) {
			return;
		}

		NSUInteger chosenIndex = [seatButtons indexOfObjectPassingTest:^BOOL(NSButton *seatButton, NSUInteger index, BOOL *stop) {
			return (seatButton.state == NSControlStateValueOn);
		}];

		if (chosenIndex == NSNotFound) {
			return;
		}

		NSString *activationID = seats[chosenIndex][@"activationID"];

		[weakSelf attemptToActivateLicenseKey:licenseKey silently:silently replacingActivation:activationID];
	}];
}

- (void)seatsFullSeatChosen:(id)sender
{
	/* Radio buttons with the same action in one view choose one of them */
}

- (void)presentNoMovesLeftWithStatusContext:(nullable id)statusContext
{
	NSDate *movesResetAt = nil;

	if ([statusContext isKindOfClass:[NSDictionary class]]) {
		movesResetAt = statusContext[@"remoteFreesResetAt"];
	}

	NSString *movesResetAtText = nil;

	if ([movesResetAt isKindOfClass:[NSDate class]]) {
		movesResetAtText = [NSDateFormatter localizedStringFromDate:movesResetAt dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
	}

	NSString *body = nil;

	if (movesResetAtText) {
		body = TXTLS(@"TLOLicenseManager[s2m-f8]", movesResetAtText);
	} else {
		body = TXTLS(@"TLOLicenseManager[s2m-f9]");
	}

	[TDCAlert alertSheetWithWindow:self.window
							  body:body
							 title:TXTLS(@"TLOLicenseManager[s2m-f7]")
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseAlternate) {
			[menuController() contactSupport:nil];
		}
	}];
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

- (void)unregisteredViewRecoveryLostLicense:(nullable id)sender
{
	/* The licensing server doesn't send lost keys by email: they're in the
	 purchase email, Textual 7 keys show the Textual 8 key they became, and
	 support finds the rest */
	[TDCAlert alertSheetWithWindow:self.window
							  body:TXTLS(@"TLOLicenseManager[r5k-l1]")
							 title:TXTLS(@"TLOLicenseManager[r5k-l0]")
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseAlternate) {
			[menuController() contactSupport:nil];
		}
	}];
}

#pragma mark -
#pragma mark Deactivate License

- (void)registeredViewDeactivateTextual:(nullable id)sender
{
	BOOL deactivateCopy = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[z87-wb]")
													title:TXTLS(@"TLOLicenseManager[pg1-a9]")
											defaultButton:TXTLS(@"Prompts[mvh-ms]")
										  alternateButton:TXTLS(@"Prompts[99q-gg]")];

	if (deactivateCopy == NO) {
		return; // Cancel operation...
	}

	/* The server frees this Mac's seat first; the licence stays when it can't be reached */
	[self beginProgressIndicator];

	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	licenseManagerDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return (TLOLicenseManagerDeleteActivation() == TLOLicenseManagerActionResultSuccess);
	};

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		[strongSelf licenseManagerDownloaderCompletionBlock];

		if (operationSuccessful == NO) {
			return;
		}

		[strongSelf toggleTrialTimer];

		[strongSelf requestTrialFromServer];

		[RZNotificationCenter() postNotificationName:TDCLicenseManagerDeactivatedLicenseNotification object:strongSelf];
	};

	licenseManagerDownloader.isSilentOnSuccess = self.isSilentOnSuccess;

	[licenseManagerDownloader deactivateLicense];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

#pragma mark -
#pragma mark NSTextField Delegate

- (void)controlTextDidChange:(NSNotification *)obj
{
	if (obj.object == self.unregisteredViewLicenseKeyTextField) {
		[self cleanUpUnregisteredViewLicenseKey];

		[self updateUnregisteredViewActivationButton];
	}
}

- (void)cleanUpUnregisteredViewLicenseKey
{
	/* As it's typed or pasted, keeping the insertion point where it was */
	NSTextField *textField = self.unregisteredViewLicenseKeyTextField;

	NSString *licenseKey = textField.stringValue;

	NSString *cleanedLicenseKey = TLOLicenseManagerCleanedLicenseKey(licenseKey);

	if ([cleanedLicenseKey isEqualToString:licenseKey]) {
		return;
	}

	NSText *fieldEditor = textField.currentEditor;

	NSUInteger insertionPoint = NSMaxRange(fieldEditor.selectedRange);

	if (insertionPoint > licenseKey.length) {
		insertionPoint = licenseKey.length;
	}

	NSUInteger cleanedInsertionPoint = TLOLicenseManagerCleanedLicenseKey([licenseKey substringToIndex:insertionPoint]).length;

	textField.stringValue = cleanedLicenseKey;

	fieldEditor.selectedRange = NSMakeRange(cleanedInsertionPoint, 0);
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

	/* Whole days, rounded up: 30 days right after the trial starts, 1 on its last day.
	 Half a day more, so a daylight saving change doesn't take one away. */
	NSTimeInterval daysLeft = ceil((timeLeft * (-1.0)) / 86400.0);

	NSString *formattedTimeRemainingString = TXHumanReadableTimeInterval(((daysLeft * 86400.0) + 43200.0) * (-1.0), YES, NSCalendarUnitDay);

	return TXTLS(@"TLOLicenseManager[wdl-3f]", formattedTimeRemainingString);
}

- (void)scheduleTimeRemainingInTrialNotification
{
	if (TLOLicenseManagerTextualIsRegistered() || TLOLicenseManagerIsTrialExpired()) {
		return; // Do not schedule notification...
	}

	/* Only in the trial's last week, and at most once a calendar day */
	NSTimeInterval timeLeft = (TLOLicenseManagerTimeRemainingTrial() * (-1.0));

	if (timeLeft > _trialReminderWindow) {
		return;
	}

	NSDate *lastShown = [RZUserDefaults() objectForKey:_trialReminderLastShownDefaultsKey];

	if ([lastShown isKindOfClass:[NSDate class]] && [[NSCalendar currentCalendar] isDateInToday:lastShown]) {
		return;
	}

	[RZUserDefaults() setObject:[NSDate date] forKey:_trialReminderLastShownDefaultsKey];

	NSString *title = [self timeRemainingInTrialFormattedMessage];

	NSString *message = TXTLS(@"TLOLicenseManager[ccj-ag]");

	[sharedNotificationController() scheduleLicenseManagerNotificationWithTitle:title message:message];
}

- (void)calendarDayChanged:(NSNotification *)notification
{
	/* Not posted on the main thread */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self scheduleTimeRemainingInTrialNotification];
	});
}

#pragma mark -
#pragma mark Window Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.window saveWindowStateForClass:self.class];

	[super windowWillClose:note];
}

@end
#endif

NS_ASSUME_NONNULL_END
