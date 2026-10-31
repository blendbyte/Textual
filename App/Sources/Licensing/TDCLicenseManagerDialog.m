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
#import "TXGlobalModels.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TPCPreferencesUserDefaults.h"
#import "TLOpenLink.h"
#import "TLOTimer.h"
#import "TLOLicenseManagerDownloaderPrivate.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLONotificationController.h"
#import "TDCAlert.h"
#import "TDCLicenseWindowPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
NSString * const TDCLicenseManagerActivatedLicenseNotification = @"TDCLicenseManagerActivatedLicenseNotification";
NSString * const TDCLicenseManagerDeactivatedLicenseNotification = @"TDCLicenseManagerDeactivatedLicenseNotification";
NSString * const TDCLicenseManagerTrialExpiredNotification = @"TDCLicenseManagerTrialExpiredNotification";

#define _upgradeRemindMeInterval 			345600 // 4 days

#define _upgradeLastDismissedDefaultsKey 	@"License Manager -> Upgrade -> Last Dismissed"
#define _upgradeNotEligibleDefaultsKey 		@"License Manager -> Upgrade -> Not Eligible License Key"

#define _trialLength 						2592000 // 30 days

#define _trialReminderWindow 				604800 // 7 days

#define _trialReminderLastShownDefaultsKey 	@"License Manager -> Trial Reminder -> Last Shown"

#define _activationCheckInterval 			2592000 // 30 days

#define _activationLastCheckedDefaultsKey 	@"License Manager -> Activation -> Last Checked"

@interface TDCLicenseManagerDialog () <NSWindowDelegate>
@property (nonatomic, strong) TDCLicenseWindowModel *model;
@property (nonatomic, strong) TDCLicenseWindow *windowContent;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *licenseManagerDownloader;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *trialDownloader;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *previousActivationDownloader;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *upgradeDownloader;
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloader *activationCheckDownloader;
@property (nonatomic, copy, nullable) NSString *seatsLicenseKey;
@property (nonatomic, assign) BOOL operationInProgress;
@property (nonatomic, strong, nullable) TLOTimer *trialTimer;
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
	TDCLicenseWindowModel *model = [TDCLicenseWindowModel new];

	self.model = model;

	[self setUpModelActions];

	self.windowContent = [[TDCLicenseWindow alloc] initWithModel:model];

	self.window = self.windowContent.window;

	self.window.delegate = self;

	[self updateSelectedPane];
}

- (void)setUpModelActions
{
	__weak TDCLicenseManagerDialog *weakSelf = self;

	TDCLicenseWindowModel *model = self.model;

	model.cleanKey = ^NSString *(NSString *licenseKey) {
		return TLOLicenseManagerCleanedLicenseKey(licenseKey);
	};

	model.isValidKey = ^BOOL(NSString *licenseKey) {
		return TLOLicenseManagerLicenseKeyIsValid(licenseKey);
	};

	model.activate = ^(NSString *licenseKey) {
		[weakSelf attemptToActivateLicenseKey:licenseKey];
	};

	model.lostKey = ^{
		[weakSelf presentLostLicenseKey];
	};

	model.buy = ^{
		[menuController() openStandaloneStoreWebpage:nil];
	};

	model.upgrade = ^{
		[weakSelf checkUpgradeOfTextual7LicenseFile];
	};

	model.moveSeat = ^(NSString *activationID) {
		[weakSelf moveSeatToThisMac:activationID];
	};

	model.cancelSeats = ^{
		[weakSelf clearSeats];
	};

	model.deactivate = ^{
		[weakSelf confirmDeactivation];
	};

	model.contactSupport = ^{
		[menuController() contactSupport:nil];
	};
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

	[self activateCopiedActivation];

	[self checkActivationIfDue];

#ifdef DEBUG
	/* For testing the upgrade: a Textual 7 license file (base64) to import
	 as the legacy import would, since the app's container is closed to others */
	NSString *textual7LicenseFile = [[NSUserDefaults standardUserDefaults] stringForKey:@"Import Textual 7 License File"];

	if (textual7LicenseFile.length > 0) {
		NSData *licenseContents = [[NSData alloc] initWithBase64EncodedString:textual7LicenseFile options:NSDataBase64DecodingIgnoreUnknownCharacters];

		if (licenseContents && TLOLicenseManagerImportTextual7LicenseFile(licenseContents)) {
			[self updateSelectedPane];
		}
	}
#endif

	[self checkUpgradeAtLaunch];
}

- (void)updateSelectedPane
{
	TDCLicenseWindowModel *model = self.model;

	BOOL registered = TLOLicenseManagerTextualIsRegistered();

	model.registered = registered;

	if (registered)
	{
		model.statusText = TXTLS(@"TLOLicenseManager[lw-st2]");
		model.trialFraction = (-1.0);

		model.licenseKey = (TLOLicenseManagerLicenseKey() ?: @"");
		model.licenseDate = (TLOLicenseManagerLicenseDateFormatted() ?: @"");
		model.macModel = TLOLicenseManagerMacModel();
	}
	else
	{
		NSTimeInterval timeLeft = (TLOLicenseManagerTimeRemainingTrial() * (-1.0));

		if (timeLeft <= 0) {
			model.statusText = TXTLS(@"TLOLicenseManager[lw-st1]");
			model.trialFraction = (-1.0); // An empty bar says nothing more
		} else {
			model.statusText = TXTLS(@"TLOLicenseManager[lw-st0]", [self formattedDaysLeftInTrial]);
			model.trialFraction = MIN(1.0, (timeLeft / _trialLength));
		}

		/* Someone with a Textual 7 license upgrades instead of buying */
		model.textual7LicenseKey = TLOLicenseManagerTextual7LicenseKey().prettyLicenseKey;
	}
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

	[self updateSelectedPane];

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

	/* A link can ask while an activation is on its way: the first one finishes */
	if (self.operationInProgress) {
		return;
	}

	TDCLicenseWindowModel *model = self.model;

	NSString *cleanedLicenseKey = TLOLicenseManagerCleanedLicenseKey(licenseKey);

	model.keyError = nil;
	model.keyErrorOffersSupport = NO;

	/* The key this Mac uses already */
	if ([cleanedLicenseKey isEqualToString:TLOLicenseManagerLicenseKey()]) {
		model.keyError = TXTLS(@"TLOLicenseManager[lw-e0]");

		return;
	}

	/* Silently: without the window, and failures say nothing
	 (both seats taken still asks which Mac to move it from) */
	if (silently == NO) {
		model.busy = TDCLicenseWindowBusyActivating;
	}

	__weak TDCLicenseManagerDialog *weakSelf = self;

	__block BOOL errorShown = NO;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];

	/* A Mac moving to another key frees its seat on the old one afterwards */
	NSString *previousActivationID = TLOLicenseManagerActivationID();

	licenseManagerDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return (TLOLicenseManagerSaveActivation(statusContext, cleanedLicenseKey) == TLOLicenseManagerActionResultSuccess);
	};

	licenseManagerDownloader.errorBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		errorShown = YES;

		switch (statusCode) {
			case 7100003: // Both seats taken
			{
				XRPerformBlockAsynchronouslyOnMainQueue(^{
					[weakSelf presentSeatsFullForLicenseKey:cleanedLicenseKey statusContext:statusContext];
				});

				break;
			}
			case 7100004: // A Textual 7 key: the answer says how it upgrades
			{
				if ([statusContext isKindOfClass:[NSDictionary class]] == NO) {
					errorShown = NO;

					break;
				}

				XRPerformBlockAsynchronouslyOnMainQueue(^{
					[weakSelf presentUpgradeEligibility:statusContext proof:@{@"t7LicenseKey" : cleanedLicenseKey} textual7LicenseKey:cleanedLicenseKey quietly:NO];
				});

				break;
			}
			case 7100005: // No seat-freeings left
			{
				XRPerformBlockAsynchronouslyOnMainQueue(^{
					[weakSelf presentNoMovesLeftWithStatusContext:statusContext];
				});

				break;
			}
			case 7100006: // The chosen seat was freed meanwhile: try again without it
			{
				XRPerformBlockAsynchronouslyOnMainQueue(^{
					[weakSelf attemptToActivateLicenseKey:cleanedLicenseKey silently:silently];
				});

				break;
			}
			default:
			{
				if (silently) {
					break;
				}

				BOOL offersSupport = NO;

				strongSelf.model.keyError = [strongSelf activationErrorForStatusCode:statusCode statusContext:statusContext offersSupport:&offersSupport];
				strongSelf.model.keyErrorOffersSupport = offersSupport;

				break;
			}
		}

		return YES;
	};

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		strongSelf.licenseManagerDownloader = nil;

		strongSelf.operationInProgress = NO;

		strongSelf.model.busy = TDCLicenseWindowBusyNone;

		if (operationSuccessful == NO) {
			/* No answer at all */
			if (errorShown == NO && silently == NO) {
				strongSelf.model.keyError = [strongSelf activationErrorForStatusCode:statusCode statusContext:statusContext offersSupport:NULL];
			}

			return;
		}

		strongSelf.model.keyText = @"";

		[strongSelf clearSeats];

		[strongSelf clearOffer];

		[strongSelf updateSelectedPane];

		[strongSelf toggleTrialTimer];

		[strongSelf freePreviousActivation:previousActivationID];

		[RZNotificationCenter() postNotificationName:TDCLicenseManagerActivatedLicenseNotification object:strongSelf];
	};

	self.operationInProgress = YES;


	[licenseManagerDownloader activateLicense:cleanedLicenseKey replacingActivation:replaceActivationID];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

- (NSString *)activationErrorForStatusCode:(NSUInteger)statusCode statusContext:(nullable id)statusContext offersSupport:(nullable BOOL *)offersSupport
{
	BOOL support = NO;

	NSString *error = nil;

	switch (statusCode) {
		case 7100000: // Not known
		{
			error = TXTLS(@"TLOLicenseManager[lw-e1]");

			break;
		}
		case 7100001: // Revoked
		{
			error = TXTLS(@"TLOLicenseManager[lw-e2]");

			support = YES;

			break;
		}
		case 7100002: // 20 activations in a day
		{
			error = TXTLS(@"TLOLicenseManager[lw-e3]");

			support = YES;

			break;
		}
		case 7100007: // Payment in review
		{
			error = TXTLS(@"TLOLicenseManager[lw-e4]");

			support = YES;

			break;
		}
		case 2000001: // Too many requests
		{
			error = TXTLS(@"TLOLicenseManager[lw-e5]");

			break;
		}
		default:
		{
			error = TXTLS(@"TLOLicenseManager[lw-e6]");

			break;
		}
	}

	if (offersSupport) {
		*offersSupport = support;
	}

	return error;
}

- (void)freePreviousActivation:(nullable NSString *)activationID
{
	/* Nothing, or the same seat again */
	if (activationID == nil || [activationID isEqualToString:TLOLicenseManagerActivationID()]) {
		return;
	}

	/* Silent: if it fails, the old key's owner frees that seat the next
	 time both are taken, from the window */
	TLOLicenseManagerDownloader *previousActivationDownloader = [TLOLicenseManagerDownloader new];


	__weak TDCLicenseManagerDialog *weakSelf = self;

	previousActivationDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		weakSelf.previousActivationDownloader = nil;
	};

	[previousActivationDownloader deactivateActivation:activationID];

	self.previousActivationDownloader = previousActivationDownloader;
}

#pragma mark -
#pragma mark Activation Check

- (void)activateCopiedActivation
{
	/* An activation file made for another Mac (copied, Migration Assistant):
	 activate this Mac with its key, quietly */
	if (TLOLicenseManagerTextualIsRegistered() || self.operationInProgress) {
		return;
	}

	NSString *licenseKey = TLOLicenseManagerActivationFileLicenseKey();

	if (licenseKey == nil) {
		return;
	}

	LogToConsoleInfo("The activation is for another Mac; activating this one");

	[self attemptToActivateLicenseKey:licenseKey silently:YES];
}

- (void)checkActivationIfDue
{
	/* At most every 30 days since the server last confirmed this Mac's
	 activation, or since it was issued. Only a signed "freed" or "revoked"
	 for this activation changes anything; anything else waits for the next time. */
	NSString *activationID = TLOLicenseManagerActivationID();

	if (activationID == nil || self.activationCheckDownloader != nil) {
		return;
	}

	NSDate *lastConfirmed = TLOLicenseManagerActivationIssuedAt();

	NSDate *lastChecked = [RZUserDefaults() objectForKey:_activationLastCheckedDefaultsKey];

	if ([lastChecked isKindOfClass:[NSDate class]] && (lastConfirmed == nil || [lastChecked compare:lastConfirmed] == NSOrderedDescending)) {
		lastConfirmed = lastChecked;
	}

	NSTimeInterval checkInterval = _activationCheckInterval;

#ifdef DEBUG
	/* For testing: seconds instead of 30 days */
	NSTimeInterval testCheckInterval = [[NSUserDefaults standardUserDefaults] doubleForKey:@"Licensing Check Interval"];

	if (testCheckInterval > 0) {
		checkInterval = testCheckInterval;
	}
#endif

	if (lastConfirmed != nil && [[NSDate date] timeIntervalSinceDate:lastConfirmed] < checkInterval) {
		return;
	}

	__weak TDCLicenseManagerDialog *weakSelf = self;

	__block TLOLicenseManagerActivationState activationState = TLOLicenseManagerActivationStateUnknown;

	TLOLicenseManagerDownloader *activationCheckDownloader = [TLOLicenseManagerDownloader new];


	activationCheckDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		activationState = TLOLicenseManagerActivationStateInSignedAnswer(statusContext, activationID);

		return YES;
	};

	activationCheckDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		strongSelf.activationCheckDownloader = nil;

		/* Activated again or deactivated meanwhile */
		if ([activationID isEqualToString:TLOLicenseManagerActivationID()] == NO) {
			return;
		}

		[strongSelf activationChecked:activationState];
	};

	[activationCheckDownloader checkActivation:activationID];

	self.activationCheckDownloader = activationCheckDownloader;
}

- (void)activationChecked:(TLOLicenseManagerActivationState)activationState
{
	switch (activationState) {
		case TLOLicenseManagerActivationStateValid:
		{
			[RZUserDefaults() setObject:[NSDate date] forKey:_activationLastCheckedDefaultsKey];

			break;
		}
		case TLOLicenseManagerActivationStateFreed:
		case TLOLicenseManagerActivationStateRevoked:
		{
			NSString *licenseKey = TLOLicenseManagerLicenseKey();

			if (TLOLicenseManagerDeleteActivation() != TLOLicenseManagerActionResultSuccess) {
				return;
			}

			[RZUserDefaults() removeObjectForKey:_activationLastCheckedDefaultsKey];

			[self toggleTrialTimer];

			[self updateSelectedPane];

			[self requestTrialFromServer];

			[RZNotificationCenter() postNotificationName:TDCLicenseManagerDeactivatedLicenseNotification object:self];

			/* Said once, here */
			NSString *title = nil;
			NSString *body = nil;

			if (activationState == TLOLicenseManagerActivationStateFreed) {
				title = TXTLS(@"TLOLicenseManager[c5k-f0]");
				body = TXTLS(@"TLOLicenseManager[c5k-f1]");
			} else {
				title = TXTLS(@"TLOLicenseManager[u8h-qv]", licenseKey.prettyLicenseKey);
				body = TXTLS(@"TLOLicenseManager[c5k-r1]");
			}

			[self show];

			[TDCAlert alertSheetWithWindow:self.window
									  body:body
									 title:title
							 defaultButton:TXTLS(@"Prompts[c7s-dq]")
						   alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")
							   otherButton:nil
						   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
				if (buttonClicked == TDCAlertResponseAlternate) {
					[menuController() contactSupport:nil];
				}
			}];

			break;
		}
		case TLOLicenseManagerActivationStateUnknown:
		{
			break;
		}
	}
}

#pragma mark -
#pragma mark Both Seats Taken

- (void)presentSeatsFullForLicenseKey:(NSString *)licenseKey statusContext:(nullable id)statusContext
{
	NSParameterAssert(licenseKey != nil);

	/* Also after a silent activation, which has no window yet */
	[self show];

	NSArray *seatList = nil;

	NSInteger movesLeft = 0;

	if ([statusContext isKindOfClass:[NSDictionary class]]) {
		seatList = [statusContext arrayForKey:@"seats"];

		movesLeft = [statusContext integerForKey:@"remoteFreesLeft" orUseDefault:0];
	}

	/* Only seats Textual can name, the one used longest ago chosen to begin with */
	NSMutableArray<TDCLicenseWindowSeat *> *seats = [NSMutableArray array];

	NSString *leastRecentlyUsedID = nil;

	NSDate *leastRecentlyUsedDate = nil;

	for (id seat in seatList) {
		if ([seat isKindOfClass:[NSDictionary class]] == NO ||
			[seat[@"activationID"] isKindOfClass:[NSString class]] == NO ||
			[seat[@"macModel"] isKindOfClass:[NSString class]] == NO)
		{
			continue;
		}

		NSString *activationID = seat[@"activationID"];

		NSDate *lastSeenAt = seat[@"lastSeenAt"];

		NSString *detail = @"";

		if ([lastSeenAt isKindOfClass:[NSDate class]]) {
			detail = TXTLS(@"TLOLicenseManager[lw-s3]", [NSDateFormatter localizedStringFromDate:lastSeenAt dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle]);
		} else {
			lastSeenAt = nil;
		}

		[seats addObject:[[TDCLicenseWindowSeat alloc] initWithActivationID:activationID title:seat[@"macModel"] detail:detail]];

		if (leastRecentlyUsedID == nil ||
			(lastSeenAt != nil && (leastRecentlyUsedDate == nil || [lastSeenAt compare:leastRecentlyUsedDate] == NSOrderedAscending)))
		{
			leastRecentlyUsedID = activationID;

			leastRecentlyUsedDate = lastSeenAt;
		}
	}

	TDCLicenseWindowModel *model = self.model;

	if (seats.count == 0) {
		model.keyError = TXTLS(@"TLOLicenseManager[s2m-f1]");
		model.keyErrorOffersSupport = YES;

		return;
	}

	if (movesLeft <= 0) {
		[self presentNoMovesLeftWithStatusContext:statusContext];

		return;
	}

	NSString *movesLeftText = nil;

	if (movesLeft == 1) {
		movesLeftText = TXTLS(@"TLOLicenseManager[s2m-f5]");
	} else {
		movesLeftText = TXTLS(@"TLOLicenseManager[s2m-f4]", movesLeft);
	}

	self.seatsLicenseKey = licenseKey;

	[self clearOffer];

	model.keyText = licenseKey;
	model.keyError = TXTLS(@"TLOLicenseManager[s2m-f0]");
	model.keyErrorOffersSupport = NO;

	model.seatsNote = [NSString stringWithFormat:@"%@ %@", TXTLS(@"TLOLicenseManager[s2m-f2]"), movesLeftText];
	model.selectedSeatID = leastRecentlyUsedID;
	model.seats = seats;
}

- (void)moveSeatToThisMac:(NSString *)activationID
{
	NSParameterAssert(activationID != nil);

	NSString *licenseKey = self.seatsLicenseKey;

	if (licenseKey == nil) {
		return;
	}

	[self attemptToActivateLicenseKey:licenseKey silently:NO replacingActivation:activationID];
}

- (void)clearSeats
{
	TDCLicenseWindowModel *model = self.model;

	if (model.seats.count > 0) {
		model.keyError = nil;
	}

	model.seats = @[];
	model.selectedSeatID = nil;

	self.seatsLicenseKey = nil;
}

- (void)presentNoMovesLeftWithStatusContext:(nullable id)statusContext
{
	[self show];

	[self clearSeats];

	NSDate *movesResetAt = nil;

	if ([statusContext isKindOfClass:[NSDictionary class]]) {
		movesResetAt = statusContext[@"remoteFreesResetAt"];
	}

	NSString *body = nil;

	if ([movesResetAt isKindOfClass:[NSDate class]]) {
		body = TXTLS(@"TLOLicenseManager[s2m-f8]", [NSDateFormatter localizedStringFromDate:movesResetAt dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle]);
	} else {
		body = TXTLS(@"TLOLicenseManager[s2m-f9]");
	}

	self.model.keyError = [NSString stringWithFormat:@"%@. %@", TXTLS(@"TLOLicenseManager[s2m-f7]"), body];
	self.model.keyErrorOffersSupport = YES;
}

#pragma mark -
#pragma mark Upgrade from Textual 7

- (nullable NSDictionary<NSString *, NSString *> *)textual7LicenseFileProof
{
	NSData *licenseContents = TLOLicenseManagerTextual7LicenseFileContents();

	if (licenseContents == nil || TLOLicenseManagerTextual7LicenseKey() == nil) {
		return nil;
	}

	return @{@"t7LicenseFile" : [licenseContents base64EncodedStringWithOptions:0]};
}

- (void)checkUpgradeOfTextual7LicenseFile
{
	NSDictionary *upgradeProof = [self textual7LicenseFileProof];

	if (upgradeProof == nil) {
		return;
	}

	[self checkUpgradeWithProof:upgradeProof textual7LicenseKey:TLOLicenseManagerTextual7LicenseKey() quietly:NO];
}

- (void)showTextual7Upgrade
{
	[self show];

	[self checkUpgradeOfTextual7LicenseFile];
}

- (void)checkUpgradeAtLaunch
{
	/* Quietly, while unregistered with an imported Textual 7 license: the
	 answer is shown, failures aren't. Not Now waits four days. */
	if (TLOLicenseManagerTextualIsRegistered()) {
		return;
	}

	NSString *textual7LicenseKey = TLOLicenseManagerTextual7LicenseKey();

	NSDictionary *upgradeProof = [self textual7LicenseFileProof];

	if (textual7LicenseKey == nil || upgradeProof == nil) {
		return;
	}

	if ([textual7LicenseKey isEqualToString:[RZUserDefaults() stringForKey:_upgradeNotEligibleDefaultsKey]]) {
		return;
	}

	NSDate *lastDismissed = [RZUserDefaults() objectForKey:_upgradeLastDismissedDefaultsKey];

	if ([lastDismissed isKindOfClass:[NSDate class]] && [[NSDate date] timeIntervalSinceDate:lastDismissed] < _upgradeRemindMeInterval) {
		return;
	}

	[self checkUpgradeWithProof:upgradeProof textual7LicenseKey:textual7LicenseKey quietly:YES];
}

- (void)checkUpgradeWithProof:(NSDictionary<NSString *, NSString *> *)upgradeProof textual7LicenseKey:(nullable NSString *)textual7LicenseKey quietly:(BOOL)quietly
{
	NSParameterAssert(upgradeProof != nil);

	if (self.upgradeDownloader != nil) {
		return;
	}

	TDCLicenseWindowModel *model = self.model;

	model.upgradeError = nil;

	if (quietly == NO) {
		model.busy = TDCLicenseWindowBusyCheckingUpgrade;
	}

	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *upgradeDownloader = [TLOLicenseManagerDownloader new];


	upgradeDownloader.errorBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		if (quietly == NO) {
			[weakSelf presentUpgradeErrorWithStatusContext:((statusCode == 7500000) ? statusContext : nil)];
		}

		return YES;
	};

	upgradeDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		strongSelf.upgradeDownloader = nil;

		strongSelf.model.busy = TDCLicenseWindowBusyNone;

		if (operationSuccessful == NO) {
			if (quietly == NO && strongSelf.model.upgradeError == nil) {
				[strongSelf presentUpgradeErrorWithStatusContext:nil];
			}

			return;
		}

		[strongSelf presentUpgradeEligibility:statusContext proof:upgradeProof textual7LicenseKey:textual7LicenseKey quietly:quietly];
	};

	[upgradeDownloader checkUpgradeEligibilityWithProof:upgradeProof];

	self.upgradeDownloader = upgradeDownloader;
}

- (void)presentUpgradeEligibility:(NSDictionary<NSString *, id> *)eligibility proof:(NSDictionary<NSString *, NSString *> *)upgradeProof textual7LicenseKey:(nullable NSString *)textual7LicenseKey quietly:(BOOL)quietly
{
	NSParameterAssert(eligibility != nil);
	NSParameterAssert(upgradeProof != nil);

	/* Activated meanwhile, for example through a link */
	if (TLOLicenseManagerTextualIsRegistered()) {
		return;
	}

	NSInteger eligibilityValue = [eligibility integerForKey:@"licenseUpgradeEligibility" orUseDefault:(-1)];

	NSString *textual7LicenseKeyText = (textual7LicenseKey.prettyLicenseKey ?: @"");

	TDCLicenseWindowModel *model = self.model;

	__weak TDCLicenseManagerDialog *weakSelf = self;

	[self clearSeats];

	[self clearOffer];

	switch (eligibilityValue) {
		case 3: // Free
		{
			model.offerTitle = TXTLS(@"TLOLicenseManager[u7g-f0]");
			model.offerMessage = TXTLS(@"TLOLicenseManager[u7g-f1]", textual7LicenseKeyText);
			model.offerPrimaryTitle = TXTLS(@"TLOLicenseManager[u7g-f2]");
			model.offerSecondaryTitle = TXTLS(@"TLOLicenseManager[u7g-n0]");

			model.offerPrimary = ^{
				[weakSelf redeemUpgradeWithProof:upgradeProof textual7LicenseKey:textual7LicenseKey];
			};

			model.offerSecondary = ^{
				[weakSelf upgradeDismissed];
			};

			break;
		}
		case 1: // Paid
		{
			NSString *checkoutURL = [eligibility stringForKey:@"upgradeCheckoutURL"];

			if ([self isUpgradeCheckoutURL:checkoutURL] == NO) {
				LogToConsoleError("The paid upgrade came without a checkout link");

				if (quietly == NO) {
					[self presentUpgradeErrorWithStatusContext:nil];
				}

				return;
			}

			model.offerTitle = TXTLS(@"TLOLicenseManager[u7g-p0]");
			model.offerMessage = TXTLS(@"TLOLicenseManager[u7g-p1]", textual7LicenseKeyText);
			model.offerPrimaryTitle = TXTLS(@"TLOLicenseManager[u7g-p2]");

			/* Not Now once the trial is over */
			if (TLOLicenseManagerIsTrialExpired()) {
				model.offerSecondaryTitle = TXTLS(@"TLOLicenseManager[u7g-n0]");
			} else {
				model.offerSecondaryTitle = TXTLS(@"TLOLicenseManager[u7g-p3]");
			}

			model.offerPrimary = ^{
				[TLOpenLink openWithString:checkoutURL inBackground:NO];

				[weakSelf upgradeDismissed];
			};

			model.offerSecondary = ^{
				[weakSelf upgradeDismissed];
			};

			break;
		}
		case 2: // Already upgraded
		{
			NSString *upgradedLicenseKey = [eligibility stringForKey:@"upgradedLicenseKey"];

			model.offerTitle = TXTLS(@"TLOLicenseManager[u7g-u0]");

			if (upgradedLicenseKey != nil && TLOLicenseManagerLicenseKeyIsValid(upgradedLicenseKey)) {
				model.offerMessage = TXTLS(@"TLOLicenseManager[u7g-u1]");
				model.offerLicenseKey = upgradedLicenseKey;
				model.offerPrimaryTitle = TXTLS(@"TLOLicenseManager[u7g-u2]");
				model.offerSecondaryTitle = TXTLS(@"TLOLicenseManager[u7g-n0]");

				model.offerPrimary = ^{
					[weakSelf attemptToActivateLicenseKey:upgradedLicenseKey];
				};

				model.offerSecondary = ^{
					[weakSelf upgradeDismissed];
				};
			} else {
				/* A license file proof doesn't always bring the key back */
				model.offerMessage = TXTLS(@"TLOLicenseManager[u7g-u3]");
				model.offerSecondaryTitle = TXTLS(@"TLOLicenseManager[vgp-j6]");
				model.offerPrimaryTitle = TXTLS(@"Prompts[c7s-dq]");

				model.offerPrimary = ^{
					[weakSelf upgradeDismissed];
				};

				model.offerSecondary = ^{
					[menuController() contactSupport:nil];

					[weakSelf upgradeDismissed];
				};
			}

			break;
		}
		case 0: // Not eligible
		{
			/* Not again at launch for this license */
			if (textual7LicenseKey != nil) {
				[RZUserDefaults() setObject:textual7LicenseKey forKey:_upgradeNotEligibleDefaultsKey];
			}

			model.offerTitle = TXTLS(@"TLOLicenseManager[u7g-x0]", textual7LicenseKeyText);
			model.offerMessage = TXTLS(@"TLOLicenseManager[u7g-x1]");
			model.offerPrimaryTitle = TXTLS(@"Prompts[c7s-dq]");
			model.offerSecondaryTitle = TXTLS(@"TLOLicenseManager[vgp-j6]");

			model.offerPrimary = ^{
				[weakSelf clearOffer];
			};

			model.offerSecondary = ^{
				[menuController() contactSupport:nil];

				[weakSelf clearOffer];
			};

			break;
		}
		default:
		{
			LogToConsoleError("Unknown upgrade eligibility: %{public}ld", eligibilityValue);

			if (quietly == NO) {
				[self presentUpgradeErrorWithStatusContext:nil];
			}

			return;
		}
	}

	[self show];
}

- (BOOL)isUpgradeCheckoutURL:(nullable NSString *)checkoutURL
{
	if (checkoutURL == nil) {
		return NO;
	}

	NSURL *url = [NSURL URLWithString:checkoutURL];

	if ([url.scheme isEqualToString:@"https"]) {
		return YES;
	}

#ifdef DEBUG
	/* A development server's checkout link uses its own address */
	if ([url.scheme isEqualToString:@"http"]) {
		return YES;
	}
#endif

	return NO;
}

- (void)redeemUpgradeWithProof:(NSDictionary<NSString *, NSString *> *)upgradeProof textual7LicenseKey:(nullable NSString *)textual7LicenseKey
{
	NSParameterAssert(upgradeProof != nil);

	if (self.upgradeDownloader != nil) {
		return;
	}

	TDCLicenseWindowModel *model = self.model;

	model.upgradeError = nil;

	model.busy = TDCLicenseWindowBusyUpgrading;

	__weak TDCLicenseManagerDialog *weakSelf = self;

	__block NSString *redeemedLicenseKey = nil;

	TLOLicenseManagerDownloader *upgradeDownloader = [TLOLicenseManagerDownloader new];


	upgradeDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		NSString *licenseKey = [statusContext stringForKey:@"licenseKey"];

		if (licenseKey == nil || TLOLicenseManagerLicenseKeyIsValid(licenseKey) == NO) {
			LogToConsoleError("The redeemed license key is missing or malformed");

			return NO;
		}

		redeemedLicenseKey = licenseKey;

		return YES;
	};

	upgradeDownloader.errorBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		/* Not free (anymore): the answer says what it is now */
		if (statusCode == 7500001 && [statusContext isKindOfClass:[NSDictionary class]]) {
			XRPerformBlockAsynchronouslyOnMainQueue(^{
				[weakSelf presentUpgradeEligibility:statusContext proof:upgradeProof textual7LicenseKey:textual7LicenseKey quietly:NO];
			});

			return YES;
		}

		[weakSelf presentUpgradeErrorWithStatusContext:((statusCode == 7500000) ? statusContext : nil)];

		return YES;
	};

	upgradeDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		strongSelf.upgradeDownloader = nil;

		strongSelf.model.busy = TDCLicenseWindowBusyNone;

		if (operationSuccessful == NO || redeemedLicenseKey == nil) {
			if (strongSelf.model.upgradeError == nil && strongSelf.model.offerTitle != nil) {
				[strongSelf presentUpgradeErrorWithStatusContext:nil];
			}

			return;
		}

		/* The new key is licensed now; activating it shows it in the window */
		[strongSelf clearOffer];

		[strongSelf attemptToActivateLicenseKey:redeemedLicenseKey];
	};

	[upgradeDownloader redeemUpgradeWithProof:upgradeProof];

	self.upgradeDownloader = upgradeDownloader;
}

- (void)presentUpgradeErrorWithStatusContext:(nullable id)statusContext
{
	/* The server says what's wrong with the proof */
	NSString *message = nil;

	if ([statusContext isKindOfClass:[NSDictionary class]]) {
		message = [statusContext stringForKey:@"message"];
	}

	if (message.length == 0) {
		message = TXTLS(@"TLOLicenseManager[u7g-e0]");
	}

	self.model.upgradeError = message;
}

- (void)upgradeDismissed
{
	[RZUserDefaults() setObject:[NSDate date] forKey:_upgradeLastDismissedDefaultsKey];

	[self clearOffer];
}

- (void)clearOffer
{
	TDCLicenseWindowModel *model = self.model;

	model.offerTitle = nil;
	model.offerMessage = nil;
	model.offerLicenseKey = nil;
	model.offerPrimaryTitle = nil;
	model.offerSecondaryTitle = nil;
	model.offerPrimary = nil;
	model.offerSecondary = nil;
	model.upgradeError = nil;
}

#pragma mark -
#pragma mark Lost License Key

- (void)presentLostLicenseKey
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

- (void)confirmDeactivation
{
	__weak TDCLicenseManagerDialog *weakSelf = self;

	[TDCAlert alertSheetWithWindow:self.window
							  body:TXTLS(@"TLOLicenseManager[z87-wb]")
							 title:TXTLS(@"TLOLicenseManager[pg1-a9]")
					 defaultButton:TXTLS(@"TLOLicenseManager[lw-m4]")
				   alternateButton:TXTLS(@"Prompts[qso-2g]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
		if (buttonClicked == TDCAlertResponseDefault) {
			[weakSelf deactivateThisMac];
		}
	}];
}

- (void)deactivateThisMac
{
	/* The server frees this Mac's seat first; the license stays when it can't be reached */
	TDCLicenseWindowModel *model = self.model;

	model.deactivateError = nil;
	model.keyError = nil;

	model.busy = TDCLicenseWindowBusyDeactivating;

	__weak TDCLicenseManagerDialog *weakSelf = self;

	TLOLicenseManagerDownloader *licenseManagerDownloader = [TLOLicenseManagerDownloader new];


	licenseManagerDownloader.actionBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return (TLOLicenseManagerDeleteActivation() == TLOLicenseManagerActionResultSuccess);
	};

	licenseManagerDownloader.errorBlock = ^BOOL(NSUInteger statusCode, id _Nullable statusContext) {
		return YES;
	};

	licenseManagerDownloader.completionBlock = ^(BOOL operationSuccessful, NSUInteger statusCode, id _Nullable statusContext) {
		TDCLicenseManagerDialog *strongSelf = weakSelf;

		strongSelf.licenseManagerDownloader = nil;

		strongSelf.model.busy = TDCLicenseWindowBusyNone;

		if (operationSuccessful == NO) {
			strongSelf.model.deactivateError = TXTLS(@"TLOLicenseManager[lw-e7]");

			return;
		}

		[RZUserDefaults() removeObjectForKey:_activationLastCheckedDefaultsKey];

		[strongSelf updateSelectedPane];

		[strongSelf toggleTrialTimer];

		[strongSelf requestTrialFromServer];

		[RZNotificationCenter() postNotificationName:TDCLicenseManagerDeactivatedLicenseNotification object:strongSelf];
	};

	[licenseManagerDownloader deactivateLicense];

	self.licenseManagerDownloader = licenseManagerDownloader;
}

#pragma mark -
#pragma mark Notification Center

- (NSString *)formattedDaysLeftInTrial
{
	/* Whole days, rounded up: 30 days right after the trial starts, 1 on its last day.
	 Half a day more, so a daylight saving change doesn't take one away. */
	NSTimeInterval timeLeft = TLOLicenseManagerTimeRemainingTrial();

	NSTimeInterval daysLeft = ceil((timeLeft * (-1.0)) / 86400.0);

	return TXHumanReadableTimeInterval(((daysLeft * 86400.0) + 43200.0) * (-1.0), YES, NSCalendarUnitDay);
}

- (NSString *)timeRemainingInTrialFormattedMessage
{
	if (TLOLicenseManagerTimeRemainingTrial() >= 0) {
		return TXTLS(@"TLOLicenseManager[kn7-ju]");
	}

	return TXTLS(@"TLOLicenseManager[wdl-3f]", [self formattedDaysLeftInTrial]);
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

		[self updateSelectedPane];

		[self checkActivationIfDue];
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
