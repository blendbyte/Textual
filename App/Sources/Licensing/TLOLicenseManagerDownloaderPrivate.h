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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TLOLicenseManagerDownloaderRequestType) {
	TLOLicenseManagerDownloaderRequestTypeActivation,
	TLOLicenseManagerDownloaderRequestTypeMigrateAppStore,
	TLOLicenseManagerDownloaderRequestTypeSendLostLicense,
	TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility,
	TLOLicenseManagerDownloaderRequestTypeReceiptUpgradeEligibility
};

TEXTUAL_EXTERN NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeSuccess;
TEXTUAL_EXTERN NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeGenericError;
TEXTUAL_EXTERN NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeServiceIsBusy;

typedef BOOL (^TLOLicenseManagerDownloaderActionBlock)(NSUInteger statusCode, id _Nullable statusContext);
typedef BOOL (^TLOLicenseManagerDownloaderErrorBlock)(NSUInteger statusCode, id _Nullable statusContext);
typedef void (^TLOLicenseManagerDownloaderCompletionBlock)(BOOL resultSuccessful, NSUInteger statusCode, id _Nullable statusContext);

@interface TLOLicenseManagerDownloader : NSObject
@property (nonatomic, copy, nullable) TLOLicenseManagerDownloaderActionBlock actionBlock;
@property (nonatomic, copy, nullable) TLOLicenseManagerDownloaderActionBlock errorBlock;
@property (nonatomic, copy, nullable) TLOLicenseManagerDownloaderCompletionBlock completionBlock;
@property (nonatomic, assign) BOOL isSilentOnFailure;
@property (nonatomic, assign) BOOL isSilentOnSuccess;

- (void)activateLicense:(NSString *)licenseKey;

- (void)deactivateLicense;

- (void)checkUpgradeEligibilityOfLicense:(NSString *)licenseKey;
- (void)checkUpgradeEligibilityOfReceipt:(NSString *)receiptData;

- (void)requestLostLicenseKeyForContactAddress:(NSString *)contactAddress;

- (void)migrateMacAppStorePurchase:(NSString *)receiptData
				  licenseOwnerName:(NSString *)licenseOwnerName
		licenseOwnerContactAddress:(NSString *)licenseOwnerContactAddress;

- (void)cancelRequest;
@end

NS_ASSUME_NONNULL_END
