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
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TDCAlert.h"
#import "TPCApplicationInfo.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLicenseManagerDownloaderPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1

/* URLs for performing certain actions with license keys. */
NSString * const TLOLicenseManagerDownloaderLicenseAPIActivationURL						= @"https://licensing.textualapp.com/activateLicense.cs";
NSString * const TLOLicenseManagerDownloaderLicenseAPISendLostLicenseURL				= @"https://licensing.textualapp.com/sendLostLicense.cs";
NSString * const TLOLicenseManagerDownloaderLicenseAPIMigrateAppStoreURL				= @"https://licensing.textualapp.com/convertReceiptToLicense.cs";
NSString * const TLOLicenseManagerDownloaderLicenseAPILicenseUpgradeEligibilityURL		= @"https://licensing.textualapp.com/upgradeEligibility.cs";
NSString * const TLOLicenseManagerDownloaderLicenseAPIReceiptUpgradeEligibilityURL		= @"https://licensing.textualapp.com/upgradeEligibilityForReceipt.cs";

/* The license API throttles requests to prevent abuse. The following HTTP status 
 code will inform Textual if it the license API has been overwhelmed. */
NSUInteger const TLOLicenseManagerDownloaderRequestHTTPStatusSuccess = 200; // OK
NSUInteger const TLOLicenseManagerDownloaderRequestHTTPStatusServiceIsBusy = 429; // Service is Busy
NSUInteger const TLOLicenseManagerDownloaderRequestHTTPStatusTryAgainLater = 503; // Service Unavailable

/* The following constants note status codes that may be returned part of the 
 contents of a license API response body. This is not a complete list. */
NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeSuccess = 0;
NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeGenericError = 2000000;
NSUInteger const TLOLicenseManagerDownloaderRequestStatusCodeServiceIsBusy = 2000001;

/* Private header */
typedef void (^TLOLicenseManagerDownloaderConnectionCompletionBlock)(TLOLicenseManagerDownloaderRequestType requestType, NSURLResponse * _Nullable response, NSData * _Nullable data);

@interface TLOLicenseManagerDownloaderConnection : NSObject <NSURLConnectionDelegate>
@property (nonatomic, weak) TLOLicenseManagerDownloader *delegate; // To be set by caller
@property (nonatomic, assign) TLOLicenseManagerDownloaderRequestType requestType; // To be set by caller
@property (nonatomic, copy) NSDictionary<NSString *, id> *requestContextInfo; // Information set by caller such as license key or e-mail address
@property (nonatomic, strong) NSURLSessionTask *sessionTask;

- (void)performRequest:(TLOLicenseManagerDownloaderConnectionCompletionBlock)completionBlock;

- (void)cancelRequest;
@end

@interface TLOLicenseManagerDownloader ()
@property (nonatomic, strong, nullable) TLOLicenseManagerDownloaderConnection *activeConnection;
@end

#define _connectionTimeoutInterval			30.0

@implementation TLOLicenseManagerDownloader

#pragma mark -
#pragma mark Public Interface

- (void)activateLicense:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	NSDictionary *contextInfo = @{@"licenseKey" : licenseKey};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeActivation
					 context:contextInfo];
}

- (void)deactivateLicense
{
	BOOL operationResult = self.actionBlock(TLOLicenseManagerDownloaderRequestStatusCodeSuccess, nil);

	if (self.completionBlock) {
		self.completionBlock(operationResult, TLOLicenseManagerDownloaderRequestStatusCodeSuccess, nil);
	}
}

- (void)checkUpgradeEligibilityOfLicense:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	NSDictionary *contextInfo = @{@"licenseKey" : licenseKey};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility
					 context:contextInfo];
}

- (void)checkUpgradeEligibilityOfReceipt:(NSString *)receiptData
{
	NSParameterAssert(receiptData != nil);

	NSString *macAddress = [XRSystemInformation formattedEthernetMacAddress];

	NSParameterAssert(macAddress != nil);

	NSDictionary *contextInfo = @{
		@"receiptData" : receiptData,
		@"licenseOwnerMacAddress" : macAddress
	};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeReceiptUpgradeEligibility
					 context:contextInfo];
}

- (void)requestLostLicenseKeyForContactAddress:(NSString *)contactAddress
{
	NSParameterAssert(contactAddress != nil);

	NSDictionary *contextInfo = @{@"licenseOwnerContactAddress" : contactAddress};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeSendLostLicense
					 context:contextInfo];
}

- (void)migrateMacAppStorePurchase:(NSString *)receiptData licenseOwnerName:(NSString *)licenseOwnerName licenseOwnerContactAddress:(NSString *)licenseOwnerContactAddress
{
	NSParameterAssert(receiptData != nil);
	NSParameterAssert(licenseOwnerName != nil);
	NSParameterAssert(licenseOwnerContactAddress != nil);

	NSString *macAddress = [XRSystemInformation formattedEthernetMacAddress];

	NSParameterAssert(macAddress != nil);

	NSDictionary *contextInfo = @{
		@"receiptData" : receiptData,
		@"licenseOwnerName"	: licenseOwnerName,
		@"licenseOwnerContactAddress" : licenseOwnerContactAddress,
		@"licenseOwnerMacAddress" : macAddress
	};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeMigrateAppStore
					 context:contextInfo];
}

- (void)performRequestType:(TLOLicenseManagerDownloaderRequestType)requestType context:(NSDictionary<NSString *, id> *)requestContext
{
	NSParameterAssert(requestContext != nil);

	if ( self.activeConnection != nil) {
		[self.activeConnection cancelRequest];
	}

	TLOLicenseManagerDownloaderConnection *connectionObject = [TLOLicenseManagerDownloaderConnection new];

	connectionObject.delegate = self;

	connectionObject.requestContextInfo = requestContext;

	connectionObject.requestType = requestType;

	__weak TLOLicenseManagerDownloader *weakSelf = self;

	[connectionObject performRequest:^(TLOLicenseManagerDownloaderRequestType requestType, NSURLResponse *response, NSData *data) {
		/* Connection uses NSURLSession which is a background task. */
		/* The result of processing the response will update the UI
		 which must always take place on the main thread. */
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			[weakSelf processResponse:response forRequestType:requestType contents:data];
		});

		weakSelf.activeConnection = nil;
	}];

	self.activeConnection = connectionObject;
}

- (void)cancelRequest
{
	if (self.activeConnection == nil) {
		return;
	}

	[self.activeConnection cancelRequest];

	self.activeConnection = nil;

	self.actionBlock = nil;
	self.errorBlock = nil;
	self.completionBlock = nil;
}

- (void)processResponse:(nullable NSURLResponse *)response forRequestType:(TLOLicenseManagerDownloaderRequestType)requestType contents:(nullable NSData *)responseContents
{
	/* We assume the response failed until proven otherwise. */
	NSUInteger responseStatusCode = TLOLicenseManagerDownloaderRequestHTTPStatusTryAgainLater;

	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		responseStatusCode = ((NSHTTPURLResponse *)response).statusCode;
	}

	[self processResponseForRequestType:requestType
						 httpStatusCode:responseStatusCode
							   contents:responseContents];
}

- (void)processResponseForRequestType:(TLOLicenseManagerDownloaderRequestType)requestType httpStatusCode:(NSUInteger)responseStatusCode contents:(nullable NSData *)responseContents
{
	/* The license API returns content as property lists, including errors.
	 This method will try to convert the returned contents into an NSDictionary
	 (assuming its a valid property list). If that fails, then the method
	 shows generic failure reason and logs to the console that the contents
	 could not parsed. */

	/* Define defaults */
	id propertyList = nil;

	__block NSUInteger apiStatusCode = TLOLicenseManagerDownloaderRequestStatusCodeGenericError;

	if (responseStatusCode == TLOLicenseManagerDownloaderRequestHTTPStatusServiceIsBusy) {
		apiStatusCode = TLOLicenseManagerDownloaderRequestStatusCodeServiceIsBusy;
	}

	__block id apiStatusContext = nil;

	/* Helper blocks */
	void (^performCompletionBlock)(BOOL) = ^(BOOL success)
	{
		if (self.completionBlock) {
			self.completionBlock(success, apiStatusCode, apiStatusContext);
		}
	};

	void (^presentError)(void) = ^(void)
	{
		if (
			/* Perform error block if it was not performed
			 by some other condition presented below. */
			(self.errorBlock == nil ||
			 self.errorBlock(apiStatusCode, apiStatusContext) == NO) &&

			/* Do we even present an error? */
			self.isSilentOnFailure == NO)
		{
			[self presentTryAgainLaterErrorDialog];
		}

		performCompletionBlock(NO);
	};

	void (^presentErrorUnconditionally)(void) = ^(void)
	{
		[self presentTryAgainLaterErrorDialog];

		performCompletionBlock(NO);
	};

	/* Convert contents into a dictionary */
	if (responseContents) {
		NSError *propertyListReadError = nil;

		propertyList = [NSPropertyListSerialization propertyListWithData:responseContents
																 options:NSPropertyListImmutable
																  format:NULL
																   error:&propertyListReadError];

		if (propertyList == nil || [propertyList isKindOfClass:[NSDictionary class]] == NO) {
			if (propertyListReadError) {
				LogToConsoleError("Failed to convert contents of request into dictionary. Error: %{public}@",
					  propertyListReadError.localizedDescription);
			}
		}
	}

	id l_statusCode = propertyList[@"Status Code"];

	if (l_statusCode == nil || [l_statusCode isKindOfClass:[NSNumber class]] == NO) {
		LogToConsoleError("'Status Code' is nil or not of kind 'NSNumber'");

		return presentError();
	}

	apiStatusCode = [l_statusCode unsignedIntegerValue];

	apiStatusContext = propertyList[@"Status Context"];

	/* Process contents */
	if (responseStatusCode == TLOLicenseManagerDownloaderRequestHTTPStatusSuccess)
	{
		/* Process successful results */
		if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSData class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSData'");

				return presentError();
			}

			if (self.actionBlock != nil && self.actionBlock(apiStatusCode, apiStatusContext) == NO) {
				LogToConsoleError("Failed to write user license file contents");

				return presentError();
			}

			if (self.isSilentOnSuccess == NO) {
				[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[k39-7l]")
										  title:TXTLS(@"TLOLicenseManager[jbs-64]")
								  defaultButton:TXTLS(@"Prompts[c7s-dq]")
								alternateButton:nil];
			}

			return performCompletionBlock(YES);
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeSendLostLicense && apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'");

				return presentError();
			}

			if (self.actionBlock != nil && self.actionBlock(apiStatusCode, apiStatusContext) == NO) {
				LogToConsoleError("Action blocked returned error");

				return presentError();
			}

			NSString *licenseOwnerContactAddress = apiStatusContext[@"licenseOwnerContactAddress"];

			if (licenseOwnerContactAddress.length == 0) {
				LogToConsoleError("'licenseOwnerContactAddress' is nil or of zero length");

				return presentError();
			}

			if (self.isSilentOnSuccess == NO) {
				[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[fxj-s6]", licenseOwnerContactAddress)
										  title:TXTLS(@"TLOLicenseManager[m4q-ul]", licenseOwnerContactAddress)
								  defaultButton:TXTLS(@"Prompts[c7s-dq]")
								alternateButton:nil];
			}

			return performCompletionBlock(YES);
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore && apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'");

				return presentError();
			}

			if (self.actionBlock != nil && self.actionBlock(apiStatusCode, apiStatusContext) == NO) {
				LogToConsoleError("Action blocked returned error");

				return presentError();
			}

			NSString *licenseOwnerContactAddress = apiStatusContext[@"licenseOwnerContactAddress"];

			if (licenseOwnerContactAddress.length == 0) {
				LogToConsoleError("'licenseOwnerContactAddress' is nil or of zero length");

				return presentError();
			}

			if (self.isSilentOnSuccess == NO) {
				[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[yxk-ej]", licenseOwnerContactAddress)
										  title:TXTLS(@"TLOLicenseManager[vxq-oa]", licenseOwnerContactAddress)
								  defaultButton:TXTLS(@"Prompts[c7s-dq]")
								alternateButton:nil];
			}

			return performCompletionBlock(YES);
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility && apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'");

				return presentError();
			}

			if (self.actionBlock != nil) {
				(void)self.actionBlock(apiStatusCode, apiStatusContext);
			}

			return performCompletionBlock(YES);
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeReceiptUpgradeEligibility && apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'");

				return presentError();
			}

			if (self.actionBlock != nil) {
				(void)self.actionBlock(apiStatusCode, apiStatusContext);
			}

			return performCompletionBlock(YES);
		}
	}
	else // TLOLicenseManagerDownloaderRequestStatusCodeSuccess
	{
		if ((self.errorBlock != nil &&
			 self.errorBlock(apiStatusCode, apiStatusContext)) ||
			self.isSilentOnFailure)
		{
			if (self.completionBlock) {
				self.completionBlock(NO, apiStatusCode, apiStatusContext);
			}

			return;
		}

		/* Errors related to license activation. */
		BOOL presentError = NO;

		if (apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeServiceIsBusy)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[fvx-90]")
									  title:TXTLS(@"TLOLicenseManager[13u-4p]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 6500000)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[wc7-mn]")
									  title:TXTLS(@"TLOLicenseManager[fg6-gf]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 6500001)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' kind is not of 'NSDictionary'");

				return presentErrorUnconditionally();
			}

			NSString *licenseKey = apiStatusContext[@"licenseKey"];

			if (licenseKey.length == 0) {
				LogToConsoleError("'licenseKey' is nil or of zero length");

				return presentErrorUnconditionally();
			}

			BOOL userResponse = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[w1n-n0]")
														  title:TXTLS(@"TLOLicenseManager[u8h-qv]", licenseKey.prettyLicenseKey)
												  defaultButton:TXTLS(@"Prompts[c7s-dq]")
												alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")];

			if (userResponse == NO) { // NO = alternate button
				[self contactSupport];
			}
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 6500002)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' kind is not of 'NSDictionary'");

				return presentErrorUnconditionally();
			}

			NSString *licenseKey = apiStatusContext[@"licenseKey"];

			if (licenseKey.length == 0) {
				LogToConsoleError("'licenseKey' is nil or of zero length");

				return presentErrorUnconditionally();
			}

			NSInteger licenseKeyActivationLimit = [apiStatusContext integerForKey:@"licenseKeyActivationLimit"];

			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[6aa-ow]", licenseKeyActivationLimit)
									  title:TXTLS(@"TLOLicenseManager[o66-ox]", licenseKey.prettyLicenseKey)
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}

		/* Errors related to lost license recovery. */
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeSendLostLicense && apiStatusCode == 6400000)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[dio-y9]")
									  title:TXTLS(@"TLOLicenseManager[ocm-03]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeSendLostLicense && apiStatusCode == 6400001)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' kind is not of 'NSDictionary'");

				return presentErrorUnconditionally();
			}

			NSString *originalInput = apiStatusContext[@"originalInput"];

			if (originalInput.length == 0) {
				LogToConsoleError("'originalInput' is nil or of zero length");

				return presentErrorUnconditionally();
			}

			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[6zh-jr]", originalInput)
									  title:TXTLS(@"TLOLicenseManager[r87-jw]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}

		/* Error messages related to Mac App Store migration. */
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore && apiStatusCode == 6600002)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[bu4-zk]")
									  title:TXTLS(@"TLOLicenseManager[ztd-5y]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore && apiStatusCode == 6600003)
		{
			/* We do not present a custom dialog for this error, but we still log
			 the contents of the context to the console to help diagnose issues. */
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' kind is not of 'NSDictionary'");

				return presentErrorUnconditionally();
			}

			NSString *errorMessage = apiStatusContext[@"Error Message"];

			if (errorMessage.length == 0) {
				LogToConsoleError("'errorMessage' is nil or of zero length");

				return presentErrorUnconditionally();
			}

			LogToConsoleError("Receipt validation failed:\n%{public}@", errorMessage);

			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[ujo-cd]", errorMessage)
									  title:TXTLS(@"TLOLicenseManager[p9s-ak]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore && apiStatusCode == 6600004)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[36y-49]")
									  title:TXTLS(@"TLOLicenseManager[enb-hw]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore && apiStatusCode == 6600006)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[do9-8x]")
									  title:TXTLS(@"TLOLicenseManager[f49-rk]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore && apiStatusCode == 6600007)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[4n2-ps]")
									  title:TXTLS(@"TLOLicenseManager[t28-j9]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else
		{
			presentError = YES;
		}

		/* presentError defaults to NO because all conditions are caught above
		 except those that may be added in future versions of the API not yet
		 supported by this code. */
		if (presentError) {
			presentErrorUnconditionally();
		} else {
			performCompletionBlock(NO);
		}
	} // TLOLicenseManagerDownloaderRequestStatusCodeSuccess
}

- (void)presentTryAgainLaterErrorDialog
{
	BOOL userResponse = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[1cv-0v]")
												  title:TXTLS(@"TLOLicenseManager[nhh-ts]")
										  defaultButton:TXTLS(@"Prompts[c7s-dq]")
										alternateButton:TXTLS(@"TLOLicenseManager[bqw-cv]")];

	if (userResponse == NO) { // NO = alternate button
		[self contactSupport];
	}
}

- (void)contactSupport
{
	[menuController() contactSupport:nil];
}

@end

#pragma mark -
#pragma mark Connection Assistant

@implementation TLOLicenseManagerDownloaderConnection

- (NSURL *)requestURL
{
	NSString *requestURLString = nil;

	if (self.requestType == TLOLicenseManagerDownloaderRequestTypeActivation) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPIActivationURL;
	} else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeSendLostLicense) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPISendLostLicenseURL;
	} else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPIMigrateAppStoreURL;
	} else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPILicenseUpgradeEligibilityURL;
	} else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeReceiptUpgradeEligibility) {
		requestURLString = TLOLicenseManagerDownloaderLicenseAPIReceiptUpgradeEligibilityURL;
	}

	return [NSURL URLWithString:requestURLString];
}

- (NSString *)encodedRequestContextValue:(NSString *)contextKey
{
	NSParameterAssert(contextKey != nil);

	NSString *contextValue = self.requestContextInfo[contextKey];

	return contextValue.percentEncodedString;
}

- (BOOL)populateRequestPostData:(NSMutableURLRequest *)connectionRequest
{
	NSParameterAssert(connectionRequest != nil);

	/* Post parameter(s) defined by this method are subject to change at
	 any time because obviously, the license API is not public interface */

	/* Post data is sent as form values with key/value pairs. */
	NSString *currentUserLanguage = [NSLocale currentLocale].localeIdentifier;

	NSString *applicationVersion = [TPCApplicationInfo applicationVersion].percentEncodedString;

	NSString *authorization = TLOLicenseManagerAuthorizationCode();

	NSString *requestBodyString = nil;

	if (self.requestType == TLOLicenseManagerDownloaderRequestTypeActivation)
	{
		NSString *encodedContextInfo = [self encodedRequestContextValue:@"licenseKey"];

		requestBodyString = [NSString stringWithFormat:@"licenseKey=%@&lang=%@&version=%@&authorization=%@",
							 encodedContextInfo, currentUserLanguage, applicationVersion, authorization];
	}
	else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeSendLostLicense)
	{
		NSString *encodedContextInfo = [self encodedRequestContextValue:@"licenseOwnerContactAddress"];

		requestBodyString = [NSString stringWithFormat:@"licenseOwnerContactAddress=%@&lang=%@&version=%@&authorization=%@",
				 encodedContextInfo, currentUserLanguage, applicationVersion, authorization];
	}
	else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeMigrateAppStore)
	{
		NSString *receiptData = [self encodedRequestContextValue:@"receiptData"];
		NSString *licenseOwnerName = [self encodedRequestContextValue:@"licenseOwnerName"];
		NSString *licenseOwnerContactAddress = [self encodedRequestContextValue:@"licenseOwnerContactAddress"];
		NSString *licenseOwnerMacAddress = [self encodedRequestContextValue:@"licenseOwnerMacAddress"];

		requestBodyString =
		[NSString stringWithFormat:@"receiptData=%@&licenseOwnerMacAddress=%@&licenseOwnerContactAddress=%@&licenseOwnerName=%@&lang=%@&version=%@&authorization=%@",
				receiptData, licenseOwnerMacAddress, licenseOwnerContactAddress, licenseOwnerName, currentUserLanguage, applicationVersion, authorization];
	}
	else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility)
	{
		NSString *encodedContextInfo = [self encodedRequestContextValue:@"licenseKey"];

		requestBodyString = [NSString stringWithFormat:@"licenseKey=%@&lang=%@&version=%@&authorization=%@",
				 encodedContextInfo, currentUserLanguage, applicationVersion, authorization];
	}
	else if (self.requestType == TLOLicenseManagerDownloaderRequestTypeReceiptUpgradeEligibility)
	{
		NSString *receiptData = [self encodedRequestContextValue:@"receiptData"];
		NSString *licenseOwnerMacAddress = [self encodedRequestContextValue:@"licenseOwnerMacAddress"];

		requestBodyString = [NSString stringWithFormat:@"receiptData=%@&licenseOwnerMacAddress=%@&lang=%@&version=%@&authorization=%@",
				 receiptData, licenseOwnerMacAddress, currentUserLanguage, applicationVersion, authorization];
	}

	if (requestBodyString == nil) {
		return NO;
	}

	NSData *requestBodyData = [requestBodyString dataUsingEncoding:NSASCIIStringEncoding];

	connectionRequest.HTTPMethod = @"POST";

	[connectionRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

	connectionRequest.HTTPBody = requestBodyData;

	return YES;
}

- (void)dealloc
{
	self.delegate = nil;
}

- (void)cancelRequest
{
	if ( self.sessionTask) {
		[self.sessionTask cancel];
	}
}

- (void)performRequest:(TLOLicenseManagerDownloaderConnectionCompletionBlock)completionBlock
{
	/* Setup request including HTTP POST data. Return NO on failure */
	NSURL *requestURL = [self requestURL];

	if (requestURL == nil) {
		return;
	}

	NSMutableURLRequest *baseRequest = [NSMutableURLRequest requestWithURL:requestURL
															   cachePolicy:NSURLRequestReloadIgnoringCacheData
														   timeoutInterval:_connectionTimeoutInterval];

	if ([self populateRequestPostData:baseRequest] == NO) {
		return;
	}

	/* Create the connection and start it */
	TLOLicenseManagerDownloaderRequestType requestType = self.requestType;

	__weak TLOLicenseManagerDownloaderConnection *weakSelf = self;

	NSURLSession *session = [NSURLSession sharedSession];

	NSURLSessionTask *task = [session dataTaskWithRequest:baseRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
	{
		if (data == nil) {
			if (error) {
				LogToConsoleError("Request failed with error: %{public}@",
					error.localizedDescription);
			}

			completionBlock(requestType, nil, nil);

			return;
		}

		completionBlock(requestType, response, data);

		weakSelf.sessionTask = nil;
	}];

	[task resume];

	self.sessionTask = task;
}

@end

#endif

NS_ASSUME_NONNULL_END
