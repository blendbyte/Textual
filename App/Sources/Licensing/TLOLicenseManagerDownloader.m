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

/* The licensing server (docs/textual-8-licensing-api.md). Debug builds can use a
 development server instead, set with:
 defaults write com.textualapp.app.dev "Licensing Server URL" http://127.0.0.1:8088 */
NSString * const TLOLicenseManagerDownloaderLicenseServerURL							= @"https://licensing.textualapp.com";
NSString * const TLOLicenseManagerDownloaderLicenseServerURLDefaultsKey				= @"Licensing Server URL";

NSString * const TLOLicenseManagerDownloaderLicenseAPIActivationPath					= @"/v2/activate";
NSString * const TLOLicenseManagerDownloaderLicenseAPIDeactivationPath					= @"/v2/deactivate";
NSString * const TLOLicenseManagerDownloaderLicenseAPITrialPath						= @"/v2/trial";
NSString * const TLOLicenseManagerDownloaderLicenseAPILicenseUpgradeEligibilityPath		= @"/upgradeEligibility.cs";

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

@interface TLOLicenseManagerDownloaderConnection : NSObject
@property (nonatomic, weak) TLOLicenseManagerDownloader *delegate; // To be set by caller
@property (nonatomic, assign) TLOLicenseManagerDownloaderRequestType requestType; // To be set by caller
@property (nonatomic, copy) NSDictionary<NSString *, id> *requestContextInfo; // Information set by caller such as license key or e-mail address
@property (nonatomic, strong, nullable) NSURLSessionTask *sessionTask;

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
	NSString *activationID = TLOLicenseManagerActivationID();

	if (activationID == nil) {
		/* Nothing on the server to free */
		BOOL operationResult = (self.actionBlock == nil || self.actionBlock(TLOLicenseManagerDownloaderRequestStatusCodeSuccess, nil));

		if (self.completionBlock) {
			self.completionBlock(operationResult, TLOLicenseManagerDownloaderRequestStatusCodeSuccess, nil);
		}

		return;
	}

	NSDictionary *contextInfo = @{@"activationID" : activationID};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeDeactivation
					 context:contextInfo];
}

- (void)requestTrial
{
	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeTrial
					 context:@{}];
}

- (void)checkUpgradeEligibilityOfLicense:(NSString *)licenseKey
{
	NSParameterAssert(licenseKey != nil);

	NSDictionary *contextInfo = @{@"licenseKey" : licenseKey};

	[self performRequestType:TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility
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

	__weak TLOLicenseManagerDownloaderConnection *weakConnection = connectionObject;

	[connectionObject performRequest:^(TLOLicenseManagerDownloaderRequestType requestType, NSURLResponse *response, NSData *data) {
		/* Connection uses NSURLSession which is a background task. */
		/* The result of processing the response will update the UI
		 which must always take place on the main thread. */
		XRPerformBlockAsynchronouslyOnMainQueue(^{
			TLOLicenseManagerDownloader *downloader = weakSelf;

			/* On main, like every other change of it, and only if no newer request replaced it */
			if (downloader.activeConnection == weakConnection) {
				downloader.activeConnection = nil;
			}

			[downloader processResponse:response forRequestType:requestType contents:data];
		});
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

			/* A plain string or array (a proxy's error page) crashed below */
			propertyList = nil;
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
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'");

				return presentError();
			}

			if (self.actionBlock != nil && self.actionBlock(apiStatusCode, apiStatusContext) == NO) {
				LogToConsoleError("Failed to save the activation");

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
		else if ((requestType == TLOLicenseManagerDownloaderRequestTypeDeactivation ||
				  requestType == TLOLicenseManagerDownloaderRequestTypeTrial) && apiStatusCode == TLOLicenseManagerDownloaderRequestStatusCodeSuccess)
		{
			if (apiStatusContext == nil || [apiStatusContext isKindOfClass:[NSDictionary class]] == NO) {
				LogToConsoleError("'Status Context' is nil or not of kind 'NSDictionary'");

				return presentError();
			}

			if (self.actionBlock != nil && self.actionBlock(apiStatusCode, apiStatusContext) == NO) {
				LogToConsoleError("Failed to save the answer");

				return presentError();
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
	}
	else // TLOLicenseManagerDownloaderRequestStatusCodeSuccess
	{
		/* Already freed, or not known: the seat is free either way */
		if (requestType == TLOLicenseManagerDownloaderRequestTypeDeactivation && apiStatusCode == 7300000)
		{
			if (self.actionBlock != nil && self.actionBlock(apiStatusCode, apiStatusContext) == NO) {
				return presentError();
			}

			return performCompletionBlock(YES);
		}

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
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 7100000)
		{
			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[wc7-mn]")
									  title:TXTLS(@"TLOLicenseManager[fg6-gf]")
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 7100001)
		{
			NSString *licenseKey = [self licenseKeyInStatusContext:apiStatusContext];

			BOOL userResponse = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[w1n-n0]")
														  title:TXTLS(@"TLOLicenseManager[u8h-qv]", licenseKey.prettyLicenseKey)
												  defaultButton:TXTLS(@"Prompts[c7s-dq]")
												alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")];

			if (userResponse == NO) { // NO = alternate button
				[self contactSupport];
			}
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 7100002)
		{
			NSString *licenseKey = [self licenseKeyInStatusContext:apiStatusContext];

			NSInteger licenseKeyActivationLimit = 20;

			if ([apiStatusContext isKindOfClass:[NSDictionary class]]) {
				licenseKeyActivationLimit = [apiStatusContext integerForKey:@"licenseKeyActivationLimit" orUseDefault:20];
			}

			[TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[6aa-ow]", licenseKeyActivationLimit)
									  title:TXTLS(@"TLOLicenseManager[o66-ox]", licenseKey.prettyLicenseKey)
							  defaultButton:TXTLS(@"Prompts[c7s-dq]")
							alternateButton:nil];
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 7100003)
		{
			BOOL userResponse = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[s2m-f1]")
														  title:TXTLS(@"TLOLicenseManager[s2m-f0]")
												  defaultButton:TXTLS(@"Prompts[c7s-dq]")
												alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")];

			if (userResponse == NO) { // NO = alternate button
				[self contactSupport];
			}
		}
		else if (requestType == TLOLicenseManagerDownloaderRequestTypeActivation && apiStatusCode == 7100007)
		{
			BOOL userResponse = [TDCAlert modalAlertWithMessage:TXTLS(@"TLOLicenseManager[p3v-r1]")
														  title:TXTLS(@"TLOLicenseManager[p3v-r0]")
												  defaultButton:TXTLS(@"Prompts[c7s-dq]")
												alternateButton:TXTLS(@"TLOLicenseManager[vgp-j6]")];

			if (userResponse == NO) { // NO = alternate button
				[self contactSupport];
			}
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

- (nullable NSString *)licenseKeyInStatusContext:(nullable id)statusContext
{
	if ([statusContext isKindOfClass:[NSDictionary class]] == NO) {
		return nil;
	}

	NSString *licenseKey = statusContext[@"licenseKey"];

	if ([licenseKey isKindOfClass:[NSString class]] == NO) {
		return nil;
	}

	return licenseKey;
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

- (nullable NSURL *)requestURL
{
	NSString *requestPath = nil;

	switch (self.requestType) {
		case TLOLicenseManagerDownloaderRequestTypeActivation:
		{
			requestPath = TLOLicenseManagerDownloaderLicenseAPIActivationPath;

			break;
		}
		case TLOLicenseManagerDownloaderRequestTypeDeactivation:
		{
			requestPath = TLOLicenseManagerDownloaderLicenseAPIDeactivationPath;

			break;
		}
		case TLOLicenseManagerDownloaderRequestTypeTrial:
		{
			requestPath = TLOLicenseManagerDownloaderLicenseAPITrialPath;

			break;
		}
		case TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility:
		{
			requestPath = TLOLicenseManagerDownloaderLicenseAPILicenseUpgradeEligibilityPath;

			break;
		}
	}

	NSString *serverURL = TLOLicenseManagerDownloaderLicenseServerURL;

#ifdef DEBUG
	NSString *developmentServerURL = [[NSUserDefaults standardUserDefaults] stringForKey:TLOLicenseManagerDownloaderLicenseServerURLDefaultsKey];

	if (developmentServerURL.length > 0) {
		serverURL = developmentServerURL;
	}
#endif

	return [NSURL URLWithString:[serverURL stringByAppendingString:requestPath]];
}

- (BOOL)populateRequestPostData:(NSMutableURLRequest *)connectionRequest
{
	NSParameterAssert(connectionRequest != nil);

	/* Post parameter(s) defined by this method are subject to change at
	 any time because obviously, the license API is not public interface */

	/* Post data is sent as form values with key/value pairs. */
	NSMutableDictionary<NSString *, NSString *> *formValues = [NSMutableDictionary dictionary];

	formValues[@"version"] = [TPCApplicationInfo applicationVersion];

	switch (self.requestType) {
		case TLOLicenseManagerDownloaderRequestTypeActivation:
		{
			formValues[@"licenseKey"] = self.requestContextInfo[@"licenseKey"];
			formValues[@"machineHash"] = TLOLicenseManagerMachineHash();
			formValues[@"macModel"] = TLOLicenseManagerMacModel();

			break;
		}
		case TLOLicenseManagerDownloaderRequestTypeDeactivation:
		{
			formValues[@"activationID"] = self.requestContextInfo[@"activationID"];
			formValues[@"machineHash"] = TLOLicenseManagerMachineHash();

			break;
		}
		case TLOLicenseManagerDownloaderRequestTypeTrial:
		{
			formValues[@"machineHash"] = TLOLicenseManagerMachineHash();

			break;
		}
		case TLOLicenseManagerDownloaderRequestTypeLicenseUpgradeEligibility:
		{
			formValues[@"licenseKey"] = self.requestContextInfo[@"licenseKey"];

			break;
		}
	}

	NSMutableArray<NSString *> *formPairs = [NSMutableArray arrayWithCapacity:formValues.count];

	[formValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		[formPairs addObject:[NSString stringWithFormat:@"%@=%@", key, value.percentEncodedString]];
	}];

	NSString *requestBodyString = [formPairs componentsJoinedByString:@"&"];

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
