/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

NS_ASSUME_NONNULL_BEGIN

/* The license window (TDCLicenseWindow.swift): TDCLicenseManagerDialog
 fills in the model and sets what its buttons do */

typedef NS_ENUM(NSInteger, TDCLicenseWindowBusy) {
	TDCLicenseWindowBusyNone = 0,
	TDCLicenseWindowBusyActivating,
	TDCLicenseWindowBusyDeactivating,
	TDCLicenseWindowBusyCheckingUpgrade,
	TDCLicenseWindowBusyUpgrading
};

@interface TDCLicenseWindowSeat : NSObject
- (instancetype)initWithActivationID:(NSString *)activationID title:(NSString *)title detail:(NSString *)detail;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, copy) NSString *activationID;
@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *detail;
@end

@interface TDCLicenseWindowModel : NSObject
/* The top: the trial, or the license */
@property (nonatomic, assign) BOOL registered;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, assign) double trialFraction; // Below 0: no bar

/* Licensed */
@property (nonatomic, copy) NSString *licenseKey;
@property (nonatomic, copy) NSString *licenseDate;
@property (nonatomic, copy) NSString *macModel;
@property (nonatomic, copy, nullable) NSString *deactivateError;

/* Activating */
@property (nonatomic, copy) NSString *keyText;
@property (nonatomic, copy, nullable) NSString *keyError;
@property (nonatomic, assign) BOOL keyErrorOffersSupport;
@property (nonatomic, assign) TDCLicenseWindowBusy busy;

/* Both seats taken */
@property (nonatomic, copy) NSArray<TDCLicenseWindowSeat *> *seats;
@property (nonatomic, copy, nullable) NSString *selectedSeatID;
@property (nonatomic, copy) NSString *seatsNote;

/* Textual 7 */
@property (nonatomic, copy, nullable) NSString *textual7LicenseKey;
@property (nonatomic, copy, nullable) NSString *upgradeError;

/* An upgrade offer */
@property (nonatomic, copy, nullable) NSString *offerTitle;
@property (nonatomic, copy, nullable) NSString *offerMessage;
@property (nonatomic, copy, nullable) NSString *offerLicenseKey;
@property (nonatomic, copy, nullable) NSString *offerPrimaryTitle;
@property (nonatomic, copy, nullable) NSString *offerSecondaryTitle;

/* What the buttons do */
@property (nonatomic, copy, nullable) NSString *(^cleanKey)(NSString *licenseKey);
@property (nonatomic, copy, nullable) BOOL (^isValidKey)(NSString *licenseKey);
@property (nonatomic, copy, nullable) void (^activate)(NSString *licenseKey);
@property (nonatomic, copy, nullable) void (^lostKey)(void);
@property (nonatomic, copy, nullable) void (^buy)(void);
@property (nonatomic, copy, nullable) void (^upgrade)(void);
@property (nonatomic, copy, nullable) void (^moveSeat)(NSString *activationID);
@property (nonatomic, copy, nullable) void (^cancelSeats)(void);
@property (nonatomic, copy, nullable) void (^offerPrimary)(void);
@property (nonatomic, copy, nullable) void (^offerSecondary)(void);
@property (nonatomic, copy, nullable) void (^deactivate)(void);
@property (nonatomic, copy, nullable) void (^contactSupport)(void);
@end

/* What the main window shows instead of the chat once the trial has ended */
@interface TDCLicenseTrialEndedView : NSObject
+ (NSView *)viewWithTextual7License:(BOOL)textual7License activate:(void (^)(void))activate buy:(void (^)(void))buy upgrade:(void (^)(void))upgrade;
@end

@interface TDCLicenseWindow : NSObject
- (instancetype)initWithModel:(TDCLicenseWindowModel *)model;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly) NSWindow *window;
@end

NS_ASSUME_NONNULL_END
