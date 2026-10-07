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

#import "TPCPathInfo.h"
#import "TPCPreferencesUserDefaults.h"
#import "TLOLicenseManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* 
*
*  TLOLicenseManager is designed to enforce remote license signatures, but
*  Textual is open source so it does not make much sense to design it in such
*  a way that tries to prevent copying.
*
*  The license manager is designed to work in very specific ways:
*
*  1. Given a documented public key, then the public key is used to verify the
*     signature that is present in license files.
*
*  2. A hash of the public key is hardcoded into a function. On launch, the hash
*     of the expected public key and the activate public key are compared. If they
*     are not equal, then this copy of Textual is not "Genuine" — in this case, the
*     user is presented a small prompt informing that Textual is open source and they
*     should prefer the open source version over a possibly pirated version.
*
*  3. At no time shall the license manager make an attempt to lock a user out of
*     application. At most, limit functionality to trial-mode level.
*
*/

/* 
 *	This source file does not contain source code from, but is designed
 *	around concepts of, the open source project known as "AquaticPrime"
 *
 *	<https://github.com/bdrister/AquaticPrime>
*/
#pragma mark -
#pragma mark Private Implementation

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
static SecKeyRef TLOLicenseManagerPublicKey = NULL;
static BOOL TLOLicenseManagerPublicKeyIsGenuineResult = YES;

static NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerCachedLicenseDictionary = nil;

NSString * const TLOLicenseManagerHashOfGenuinePublicKey = @"2e14fea44d634095e91a8048404c4ea90d9487a0676f48e89b846a6926b2f4c1";
NSString * const TLOLicenseManagerLicenseKeyRegularExpression = @"^([a-z]{1,12})\\-([a-z]{1,12})\\-([a-z]{1,12})\\-([0-9]{1,35})$";
NSUInteger const TLOLicenseManagerLicenseKeyExpectedLength = 45;
NSInteger const TLOLicenseManagerTrialModeMaximumLifespan = (-2592000); // 30 days in seconds
NSUInteger const TLOLicenseManagerCurrentLicenseGeneration = 1;

void TLOLicenseManagerDeleteLicenseFileIfBlacklisted(void);
BOOL TLOLicenseManagerLicenseKeyBlacklisted(NSString *licenseKey);
BOOL TLOLicenseManagerLicenseDictionaryIsValid(NSDictionary<NSString *, id> *licenseDictionary);
void TLOLicenseManagerPopulatePublicKeyRef(void);
void TLOLicenseManagerSetPublicKeyIsGenuine(void);
BOOL TLOLicenseManagerLicenseFileExists(void);
CFDataRef TLOLicenseManagerExportContentsOfKeyRef(SecKeyRef theKeyRef, BOOL isPublicKey);
NSData * _Nullable TLOLicenseManagerPublicKeyContents(void);
NSData * _Nullable TLOLicenseManagerLicenseFileContents(void);
TLOLicenseManagerActionResult TLOLicenseManagerLoadLicenseDictionary(void);
TLOLicenseManagerActionResult TLOLicenseManagerLoadLicenseDictionaryWithData(NSData *licenseContents);
NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerLicenseDictionary(void);
NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerLicenseDictionaryWithData(NSData *licenseContents);
NSURL * _Nullable TLOLicenseManagerTrialModeInformationFilePath(void);
void TLOLicenseManagerMigrateLicenseFiles(void);
NSURL * _Nullable TLOLicenseManagerLicenseFilePath(void);
NSNumberFormatter *TLOLicenseManagerStringValueNumberFormatter(void);
NSString *TLOLicenseManagerStringValueForObject(id object);

NSString * const TLOLicenseManagerLicenseDictionaryKeyCreationDate			= @"licenseCreationDate";
NSString * const TLOLicenseManagerLicenseDictionaryKeyGeneration			= @"licenseGeneration";
NSString * const TLOLicenseManagerLicenseDictionaryKeyLicenseKey			= @"licenseKey";
NSString * const TLOLicenseManagerLicenseDictionaryKeyProductName			= @"licenseProductName";
NSString * const TLOLicenseManagerLicenseDictionaryKeyOwnerContactAddress	= @"licenseOwnerContactAddress";
NSString * const TLOLicenseManagerLicenseDictionaryKeyOwnerName				= @"licenseOwnerName";
NSString * const TLOLicenseManagerLicenseDictionaryKeySignature				= @"licenseSignature";
NSString * const TLOLicenseManagerLicenseDictionaryKeySignatureGeneration	= @"licenseSignatureGeneration";
#endif

#pragma mark -
#pragma mark Implementation

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
void TLOLicenseManagerSetup(void)
{
	static BOOL _setupComplete = NO;

	if (_setupComplete == NO) {
		_setupComplete = YES;

		TLOLicenseManagerPopulatePublicKeyRef();

		TLOLicenseManagerMigrateLicenseFiles();

		(void)TLOLicenseManagerLoadLicenseDictionary();

		XRPerformBlockAsynchronouslyOnGlobalQueue(^{
			TLOLicenseManagerSetPublicKeyIsGenuine();

			TLOLicenseManagerDeleteLicenseFileIfBlacklisted();
		});
	}
}

#pragma mark -
#pragma mark Trial Mode

BOOL TLOLicenseManagerTextualIsRegistered(void)
{
	if (TLOLicenseManagerPublicKeyIsGenuineResult == NO) {
		return NO;
	} else if (TLOLicenseManagerLicenseFileExists() == NO) {
		return NO;
	}

	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionary();

	return (licenseDictionary != nil);
}

BOOL TLOLicenseManagerIsTrialExpired(void)
{
	NSTimeInterval timeLeft = TLOLicenseManagerTimeRemainingTrial();

	return (timeLeft >= 0);
}

NSTimeInterval TLOLicenseManagerTimeRemainingTrial(void)
{
	/* Determine where trial information will be stored on disk. */
	NSURL *trialInformationFilePath = TLOLicenseManagerTrialModeInformationFilePath();

	if (trialInformationFilePath == nil) {
		return 0;
	}

	/* If the trial information file does not exist yet, then create a new
	 one which will define when the trial period began. */
	/* NSPropertyListSerialization is used by this function, in place of the built
	 in NSData read & write methods, for better error reporting. */
	if ([RZFileManager() fileExistsAtURL:trialInformationFilePath] == NO)
	{
		NSDictionary *trialInformation = @{
			@"trialPeriodStartDate" : [NSDate date]
		};

		NSError *trialInformationPropertyListError = nil;

		NSData *trialInformationPropertyList =
		[NSPropertyListSerialization dataWithPropertyList:trialInformation
												   format:NSPropertyListBinaryFormat_v1_0
												  options:0
													error:&trialInformationPropertyListError];

		if (trialInformationPropertyList == nil) {
			LogToConsoleError("Failed to create trial information property list: %{public}@", trialInformationPropertyListError.localizedDescription);

			return 0; // Cannot continue function...
		}

		NSError *trialInformationWriteError = nil;

		if ([trialInformationPropertyList writeToURL:trialInformationFilePath options:NSDataWritingAtomic error:&trialInformationWriteError] == NO) {
			LogToConsoleError("Failed to write trial information to disk: %{public}@", trialInformationWriteError.localizedDescription);

			return 0; // Cannot continue function...
		}

		NSError *modifyTrialInformationAttributesError = nil;

		if ([trialInformationFilePath setResourceValue:@(YES) forKey:NSURLIsHiddenKey error:&modifyTrialInformationAttributesError] == NO) {
			LogToConsoleError("Failed to modify attributes of trial information file: %{public}@", modifyTrialInformationAttributesError.localizedDescription);

			return 0; // Cannot continue function...
		}

		NSError *lockTrialInformationFileError = nil;

		if ([RZFileManager() lockItemAtPath:trialInformationFilePath.path error:&lockTrialInformationFileError] == NO) {
			LogToConsoleError("Failed to lock the trial information file: %{public}@", lockTrialInformationFileError.localizedDescription);

			return 0; // Cannot continue function...
		}
	}

	/* Read trial information from disk. */
	NSError *trialInformationDataReadError = nil;

	NSData *trialInformationData = [NSData dataWithContentsOfURL:trialInformationFilePath options:0 error:&trialInformationDataReadError];

	if (trialInformationData == nil) {
		LogToConsoleError("Failed to read contents of trial information file: %{public}@", trialInformationDataReadError.localizedDescription);

		return 0; // Cannot continue function...
	}

	NSError *trialInformationPropertyListError = nil;

	NSDictionary *trialInformation =
	[NSPropertyListSerialization propertyListWithData:trialInformationData
											  options:NSPropertyListImmutable
											   format:NULL
												error:&trialInformationPropertyListError];

	if (trialInformation == nil) {
		LogToConsoleError("Failed to convert property list to NSDictionary: %{public}@", trialInformationPropertyListError.localizedDescription);

		return 0; // Cannot continue function...
	}

	/* Given dictionary, get start date of trial and return time left. */
	NSDate *trialPeriodStartDate = trialInformation[@"trialPeriodStartDate"];

	if (trialPeriodStartDate == nil || [trialPeriodStartDate isKindOfClass:[NSDate class]] == NO) {
		LogToConsoleError("The value of 'trialPeriodStartDate' is nil or not of kind 'NSDate'");

		return 0; // Cannot continue function...
	}

	/* trialPeriodStartInterval will be negative because it is in the past. */
	NSTimeInterval trialPeriodStartInterval = trialPeriodStartDate.timeIntervalSinceNow;

	if (trialPeriodStartInterval > 0) {
		/* Return expired date for those who try to be clever by setting future time. */

		return 0;
	} else if (trialPeriodStartInterval < TLOLicenseManagerTrialModeMaximumLifespan) {
		return 0;
	} else {
		return (TLOLicenseManagerTrialModeMaximumLifespan - trialPeriodStartInterval);
	}
}

NSURL * _Nullable TLOLicenseManagerTrialModeInformationFilePath(void)
{
	NSURL *sourceURL = [TPCPathInfo applicationSupportURL];

	if (sourceURL == nil) {
		return nil;
	}

	NSURL *baseURL = [sourceURL URLByAppendingPathComponent:@"/Textual_Trial_Information_v2.plist"];

	return baseURL;
}

#pragma mark -
#pragma mark User License File Validation

BOOL TLOLicenseManagerLicenseKeyIsValid(NSString *licenseKey)
{
	NSCParameterAssert(licenseKey != nil);

	if (licenseKey.length != TLOLicenseManagerLicenseKeyExpectedLength) {
		return NO;
	}

	if ([XRRegularExpression string:licenseKey isMatchedByRegex:TLOLicenseManagerLicenseKeyRegularExpression withoutCase:YES] == NO) {
		return NO;
	} else {
		return YES;
	}
}

NSNumberFormatter *TLOLicenseManagerStringValueNumberFormatter(void)
{
	/*
		 Regardless of whether a number in returned dictionary is an
		 integer or double, it is formatted in the signature with four
		 fraction digits. This allows us to avoid having to determine
		 what type of number NSNumber is actually storing. Just format
		 everything the same exact way.

		 Integer 1 = "1.0000",
		 Double 2.43561 = "2.4356"
	 */
	static NSNumberFormatter *numberFormatter = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		numberFormatter = [NSNumberFormatter new];

		numberFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
		numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
		numberFormatter.alwaysShowsDecimalSeparator = YES;
		numberFormatter.usesGroupingSeparator = NO;
		numberFormatter.minimumFractionDigits = 4;
		numberFormatter.maximumFractionDigits = 4;
	});

	return numberFormatter;
}

NSString *TLOLicenseManagerStringValueForObject(id object)
{
	/* The license dictionary can contain more than strings as of Textual 7.
	 The license signature is the sum of all objects in the license dictionary,
	 in alphabetical order, concatenated as strings. */
	/* This method returns the string representation of an object. */
	if ([object isKindOfClass:[NSArray class]])
	{
		NSMutableString *stringValue = [NSMutableString new];

		[object enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
			NSString *objectValue = TLOLicenseManagerStringValueForObject(object);

			[stringValue appendFormat:@"%lu%@", index, objectValue];
		}];

		return [stringValue copy];
	}
	else if ([object isKindOfClass:[NSDictionary class]])
	{
		NSMutableString *stringValue = [NSMutableString new];

		NSArray *sortedDictionaryKeys = [[object allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

		for (NSString *key in sortedDictionaryKeys) {
			NSString *objectValue = TLOLicenseManagerStringValueForObject(object[key]);

			[stringValue appendFormat:@"%@%@", key, objectValue];
		}

		return [stringValue copy];
	}
	else if ([object isKindOfClass:[NSString class]])
	{
		return object;
	}
	else if ([object isKindOfClass:[NSNumber class]])
	{
		if ([object isBooleanValue]) {
			if ([object boolValue]) {
				return @"YES";
			} else {
				return @"NO";
			}
		} else {
			NSNumberFormatter *numberFormatter = TLOLicenseManagerStringValueNumberFormatter();

			return [numberFormatter stringFromNumber:object];
		}
	}

	return @"";
}

TLOLicenseManagerActionResult TLOLicenseManagerVerifyLicenseSignatureWithDictionary(NSDictionary<NSString *, id> *licenseDictionary)
{
	NSCParameterAssert(licenseDictionary != nil);

	/* Attempt to populate public key information. */
	if (TLOLicenseManagerPublicKey == NULL) {
		return TLOLicenseManagerActionResultOther;
	}

	/* Retrieve license signature information */
	NSData *licenseSignature = licenseDictionary[TLOLicenseManagerLicenseDictionaryKeySignature];

	if (licenseSignature == nil) {
		LogToConsoleError("Missing license signature in license dictionary");

		return TLOLicenseManagerActionResultMalformedData;
	}

	/* Retrieve license generation */
	NSUInteger licenseGeneration = [licenseDictionary unsignedIntegerForKey:TLOLicenseManagerLicenseDictionaryKeyGeneration];

	if (licenseGeneration < TLOLicenseManagerCurrentLicenseGeneration) {
		return TLOLicenseManagerActionResultGenerationPrevious;
	} else if (licenseGeneration > TLOLicenseManagerCurrentLicenseGeneration) {
		return TLOLicenseManagerActionResultGenerationNext;
	}

	CFDataRef cfLicenseSignature = (__bridge CFDataRef)(licenseSignature);

	/* Combine all contents of the dictionary, in sorted order, excluding
	 the license dictionary signature because thats used for comparison. */
	NSMutableDictionary *licenseDictionaryToCombine = [licenseDictionary mutableCopy];

	[licenseDictionaryToCombine removeObjectForKey:TLOLicenseManagerLicenseDictionaryKeySignature];
	[licenseDictionaryToCombine removeObjectForKey:TLOLicenseManagerLicenseDictionaryKeySignatureGeneration];

	NSString *combinedLicenseDataString = TLOLicenseManagerStringValueForObject(licenseDictionaryToCombine);

	if (combinedLicenseDataString.length <= 0) {
		LogToConsoleError("Length of combinedLicenseDataString is below or equal to zero (0)");

		return TLOLicenseManagerActionResultMalformedData;
	}

	NSData *combinedLicenseData = [combinedLicenseDataString dataUsingEncoding:NSUTF8StringEncoding];

	CFDataRef cfCombinedLicenseData = (__bridge CFDataRef)(combinedLicenseData);

	/* Setup transform function for verifying signature */
	SecTransformRef verifyFunction = SecVerifyTransformCreate(TLOLicenseManagerPublicKey, cfLicenseSignature, NULL);

	if (verifyFunction == NULL) {
		LogToConsoleError("Failed to create transform using SecVerifyTransformCreate()");

		return TLOLicenseManagerActionResultInvalidSignature;
	}

	/* Setup transform attributes */
	if (SecTransformSetAttribute(verifyFunction, kSecTransformInputAttributeName, cfCombinedLicenseData, NULL)		== false ||
		SecTransformSetAttribute(verifyFunction, kSecDigestTypeAttribute, kSecDigestSHA2, NULL)						== false ||
		SecTransformSetAttribute(verifyFunction, kSecDigestLengthAttribute, (__bridge CFNumberRef)@(256), NULL)		== false)
	{
		CFRelease(verifyFunction);

		LogToConsoleError("Failed to modify transform attributes using SecTransformSetAttribute()");

		return TLOLicenseManagerActionResultInvalidSignature;
	}

	/* Perform signature verification */
	CFTypeRef cfVerifyResult = SecTransformExecute(verifyFunction, NULL);

	CFRelease(verifyFunction);

	BOOL verifyResult = NO;

	if (CFGetTypeID(cfVerifyResult) == CFBooleanGetTypeID()) {
		verifyResult = (cfVerifyResult == kCFBooleanTrue);
	} else {
		LogToConsoleError("SecTransformExecute() returned a result that is not of type: CFBooleanRef");
	}

	if (cfVerifyResult != NULL) {
		CFRelease(cfVerifyResult);
	}

	if (verifyResult == NO) {
		return TLOLicenseManagerActionResultInvalidSignature;
	}

	return TLOLicenseManagerActionResultSuccess;
}

#pragma mark -
#pragma mark Reading & Writing User License File

void TLOLicenseManagerMigrateLicenseFiles(void)
{
	NSURL *newLocation = [TPCPathInfo applicationSupportURL];

	NSURL *oldTrialData = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:@"/Library/Application Support/Textual/Textual_Trial_Information_v2.plist"];
	NSURL *newTrialData = [newLocation URLByAppendingPathComponent:@"Textual_Trial_Information_v2.plist"];

	NSError *moveError = nil;

	if ([RZFileManager() fileExistsAtURL:newTrialData] == NO &&
		[RZFileManager() fileExistsAtURL:oldTrialData]) {
		if ([RZFileManager() copyItemAtURL:oldTrialData toURL:newTrialData error:&moveError]) {
			LogToConsole("Moved trial data file to new location");
		} else {
			LogToConsoleError("Moving trial data file to new location failed: %{public}@", moveError.localizedDescription);

			moveError = nil; // nil out for next move
		}
	}

	NSURL *oldLicenseData = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:@"/Library/Application Support/Textual/Textual_User_License_v2.plist"];
	NSURL *newLicenseData = [newLocation URLByAppendingPathComponent:@"Textual_User_License_v2.plist"];

	if ([RZFileManager() fileExistsAtURL:newLicenseData] == NO &&
		[RZFileManager() fileExistsAtURL:oldLicenseData]) {
		if ([RZFileManager() copyItemAtURL:oldLicenseData toURL:newLicenseData error:&moveError]) {
			LogToConsole("Moved license data file to new location");
		} else {
			LogToConsoleError("Moving license data file to new location failed: %{public}@", moveError.localizedDescription);
		}
	}
}

NSURL * _Nullable TLOLicenseManagerLicenseFilePath(void)
{
	NSURL *sourceURL = [TPCPathInfo applicationSupportURL];

	if (sourceURL == nil) {
		return nil;
	}

	NSURL *baseURL = [sourceURL URLByAppendingPathComponent:@"/Textual_User_License_v2.plist"];

	return baseURL;
}

TLOLicenseManagerActionResult TLOLicenseManagerDeleteLicenseFile(void)
{
	return TLOLicenseManagerWriteLicenseFileContents(nil);
}

TLOLicenseManagerActionResult TLOLicenseManagerWriteLicenseFileContents(NSData * _Nullable newContents)
{
	NSURL *licenseFilePath = TLOLicenseManagerLicenseFilePath();

	if (newContents) {
		TLOLicenseManagerActionResult loadResult =
		TLOLicenseManagerLoadLicenseDictionaryWithData(newContents);

		if (loadResult != TLOLicenseManagerActionResultSuccess) {
			LogToConsoleError("Verify for new license file contents failed");

			return loadResult;
		}

		NSError *writeFileError = nil;

		if ([newContents writeToURL:licenseFilePath options:NSDataWritingAtomic error:&writeFileError] == NO) {
			LogToConsoleError("Failed to write user license file with error: %{public}@", writeFileError.localizedDescription);

			return TLOLicenseManagerActionResultCannotWrite;
		}
	} else {
		TLOLicenseManagerCachedLicenseDictionary = nil;

		NSError *deleteError = nil;

		if ([RZFileManager() removeItemAtURL:licenseFilePath error:&deleteError] == NO) {
			LogToConsoleError("Failed to delete user license file with error: %{public}@", deleteError.localizedDescription);

			return TLOLicenseManagerActionResultCannotWrite;
		}
	}

	return TLOLicenseManagerActionResultSuccess;
}

BOOL TLOLicenseManagerLicenseFileExists(void)
{
	NSURL *licenseFilePath = TLOLicenseManagerLicenseFilePath();

	if (licenseFilePath == nil) {
		return NO;
	}

	BOOL isDirectory = NO;

	BOOL fileExists = [RZFileManager() fileExistsAtPath:licenseFilePath.path isDirectory:&isDirectory];

	return (fileExists && isDirectory == NO);
}

NSData * _Nullable TLOLicenseManagerLicenseFileContents(void)
{
	NSURL *licenseFilePath = TLOLicenseManagerLicenseFilePath();

	if (licenseFilePath == nil) {
		LogToConsoleError("Unable to determine the path to retrieve license information from");

		return nil;
	}

	if (TLOLicenseManagerLicenseFileExists() == NO) {
		return nil;
	}

	NSError *readError = nil;

	NSData *licenseContents = [NSData dataWithContentsOfURL:licenseFilePath options:0 error:&readError];

	if (licenseContents == nil) {
		LogToConsoleError("Unable to read user license file. Error: %{public}@", readError.localizedDescription);

		return nil;
	}

	return licenseContents;
}

TLOLicenseManagerActionResult TLOLicenseManagerLoadLicenseDictionary(void)
{
	NSData *licenseContents = TLOLicenseManagerLicenseFileContents();

	if (licenseContents == nil) {
		return NO;
	}

	return TLOLicenseManagerLoadLicenseDictionaryWithData(licenseContents);
}

TLOLicenseManagerActionResult TLOLicenseManagerLoadLicenseDictionaryWithData(NSData *licenseContents)
{
	NSCParameterAssert(licenseContents != nil);

	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionaryWithData(licenseContents);

	if (licenseDictionary == nil) {
		return TLOLicenseManagerActionResultCannotRead;
	}

	TLOLicenseManagerActionResult result =
	TLOLicenseManagerVerifyLicenseSignatureWithDictionary(licenseDictionary);

	if (result == TLOLicenseManagerActionResultSuccess) {
		TLOLicenseManagerCachedLicenseDictionary = [licenseDictionary copy];
	}

	return result;
}

NSDictionary<NSString *, id> *TLOLicenseManagerLicenseDictionaryWithData(NSData *licenseContents)
{
	NSCParameterAssert(licenseContents != nil);

	/* The contents of the user license is /supposed/ to be a properly formatted
	 property list as sent from the license system hosted on www.codeux.com */
	NSError *readError = nil;

	id licenseDictionary = [NSPropertyListSerialization propertyListWithData:licenseContents
																	 options:NSPropertyListImmutable
																	  format:NULL
																	   error:&readError];

	if (licenseDictionary == nil || [licenseDictionary isKindOfClass:[NSDictionary class]] == NO) {
		if (readError) {
			LogToConsoleError("Failed to convert contents of user license into dictionary. Error: %{public}@",
				  readError.localizedDescription);
		}

		return nil;
	}

	return licenseDictionary;
}

NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerLicenseDictionary(void)
{
	return TLOLicenseManagerCachedLicenseDictionary;
}

#pragma mark -
#pragma mark Public Key Access

NSData * _Nullable TLOLicenseManagerPublicKeyContents(void)
{
	/* Find where public key is */
	NSURL *publicKeyPath = [RZMainBundle() URLForResource:@"RemoteLicenseSystemPublicKey" withExtension:@"pub"];

	if (publicKeyPath == nil) {
		LogToConsoleError("Unable to find the public key used for verifying signatures");

		return nil;
	}

	/* Load contents of the public key */
	NSError *readError = nil;

	NSData *publicKeyContents = [NSData dataWithContentsOfURL:publicKeyPath options:0 error:&readError];

	if (publicKeyContents == nil) {
		LogToConsoleError("Unable to read contents of the public key used for verifying signatures. Error: %{public}@",
			  readError.localizedDescription);

		return nil;
	}

	return publicKeyContents;
}

void TLOLicenseManagerSetPublicKeyIsGenuine(void)
{
	NSData *publicKeyContents = TLOLicenseManagerPublicKeyContents();

	if (publicKeyContents == nil) {
		return;
	}

	NSString *publicKeyHash = publicKeyContents.sha256;

	if ([TLOLicenseManagerHashOfGenuinePublicKey isEqualToString:publicKeyHash]) {
		TLOLicenseManagerPublicKeyIsGenuineResult = YES;
	} else {
		TLOLicenseManagerPublicKeyIsGenuineResult = NO;
	}
}

void TLOLicenseManagerPopulatePublicKeyRef(void)
{
	NSData *publicKeyContents = TLOLicenseManagerPublicKeyContents();

	if (publicKeyContents == nil) {
		return;
	}

	SecItemImportExportKeyParameters importParameters;

	importParameters.flags = kSecKeyNoAccessControl;
	importParameters.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;

	importParameters.accessRef = NULL;
	importParameters.alertPrompt = NULL;
	importParameters.alertTitle = NULL;
	importParameters.passphrase = NULL;

	importParameters.keyAttributes = NULL;
	importParameters.keyUsage = NULL;

	SecExternalItemType itemType = kSecItemTypePublicKey;

	SecExternalFormat externalFormat = kSecFormatPEMSequence;

	int flags = 0;

	CFArrayRef tempArray = NULL;

	OSStatus operationStatus =
		SecItemImport((__bridge CFDataRef)(publicKeyContents), NULL, &externalFormat, &itemType, flags, &importParameters, NULL, &tempArray);

	if (operationStatus == noErr) {
		TLOLicenseManagerPublicKey = (SecKeyRef)CFArrayGetValueAtIndex(tempArray, 0);

		CFRetain(TLOLicenseManagerPublicKey);

		CFRelease(tempArray);

		return;
	}

	LogToConsoleError("SecItemImport() failed to import public key with status code: %{public}i",
		  operationStatus);
}

#pragma mark -
#pragma mark User License File Information

NSString * _Nullable TLOLicenseManagerLicenseOwnerName(void)
{
	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionary();

	if (licenseDictionary == nil) {
		return nil;
	}

	return licenseDictionary[TLOLicenseManagerLicenseDictionaryKeyOwnerName];
}

NSString * _Nullable TLOLicenseManagerLicenseOwnerContactAddress(void)
{
	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionary();

	if (licenseDictionary == nil) {
		return nil;
	}

	return licenseDictionary[TLOLicenseManagerLicenseDictionaryKeyOwnerContactAddress];
}

NSString * _Nullable TLOLicenseManagerLicenseKey(void)
{
	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionary();

	if (licenseDictionary == nil) {
		return nil;
	}

	return licenseDictionary[TLOLicenseManagerLicenseDictionaryKeyLicenseKey];
}

NSUInteger TLOLicenseManagerLicenseGeneration(void)
{
	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionary();

	if (licenseDictionary == nil) {
		return 0;
	}

	return [licenseDictionary unsignedIntegerForKey:TLOLicenseManagerLicenseDictionaryKeyGeneration];
}

NSString * _Nullable TLOLicenseManagerLicenseCreationDate(void)
{
	NSDictionary *licenseDictionary = TLOLicenseManagerLicenseDictionary();

	if (licenseDictionary == nil) {
		return nil;
	}

	return licenseDictionary[TLOLicenseManagerLicenseDictionaryKeyCreationDate];
}

NSString * _Nullable TLOLicenseManagerLicenseCreationDateFormatted(void)
{
	NSString *creationDateString = TLOLicenseManagerLicenseCreationDate();

	if (creationDateString == nil) {
		return nil;
	}

	NSDateFormatter *dateFormatter = [NSDateFormatter new];

	dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

	dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

	dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";

	NSDate *creationDate = [dateFormatter dateFromString:creationDateString];

	if (creationDate == nil) {
		return creationDateString;
	}

	dateFormatter.dateFormat = nil;

	dateFormatter.doesRelativeDateFormatting = YES;

	dateFormatter.dateStyle = NSDateFormatterLongStyle;
	dateFormatter.timeStyle = NSDateFormatterNoStyle;

	return [dateFormatter stringFromDate:creationDate];
}

#pragma mark -
#pragma mark Authorization

NSString * TLOLicenseManagerAuthorizationCode(void)
{
	NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:@"TLOLicenseManagerAuthorizationCode"];

	if (code == nil) {
		code = @"";
	}

	return code;
}

#pragma mark -
#pragma mark Blacklist

void TLOLicenseManagerDeleteLicenseFileIfBlacklisted(void)
{
	NSString *licenseKey = TLOLicenseManagerLicenseKey();

	if (licenseKey == nil) {
		return;
	}

	if (TLOLicenseManagerLicenseKeyBlacklisted(licenseKey) == NO) {
		return;
	}

	LogToConsoleInfo("License key '%{private}@' is blacklisted", licenseKey);

	TLOLicenseManagerDeleteLicenseFile();
}

BOOL TLOLicenseManagerLicenseKeyBlacklisted(NSString *licenseKey)
{
	NSCParameterAssert(licenseKey != nil);

	NSArray<NSString *> *blacklistedLicenseKeys = nil;

	if (blacklistedLicenseKeys == nil) {
		blacklistedLicenseKeys = @[
			@"mushy-argyle-oryx-428112186934176870777339608",
			@"wicked-plaid-weasel-0681043544455415517323623",
			@"juicy-cyan-toad-72508217265703758416002094229",
			@"cheerful-turquoise-zebra-81864329409734131515",
			@"many-wavy-fly-7043700524134077492967431288170",
			@"helpful-jade-quelea-7403506199409693779877124",
			@"obnoxious-onyx-bear-9755065646001620521415702",
		];
	}

	return [blacklistedLicenseKeys containsObject:licenseKey];
}

#endif

NS_ASSUME_NONNULL_END
