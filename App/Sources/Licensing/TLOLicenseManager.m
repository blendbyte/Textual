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

#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>

#import "TPCPathInfo.h"
#import "TLOLicenseManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/*
 *  Textual 8 licences are activations of a licence key on one Mac, made by
 *  Blendbyte's licensing server. Its answers are signed (ECDSA P-256 over the
 *  exact bytes of a binary property list) and kept as they came, so the
 *  activation file is checked again at every launch.
 *
 *  Textual is open source, so none of this tries to prevent copying. At most
 *  the licence manager limits Textual to what the trial allows; it never
 *  locks anyone out.
 *
 *  The server's API: docs/textual-8-licensing-api.md (in the development notes).
 */

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
NSString * const TLOLicenseManagerLicenseKeyRegularExpression = @"^([a-z]{1,12})\\-([a-z]{1,12})\\-([a-z]{1,12})\\-([0-9]{1,35})$";
NSUInteger const TLOLicenseManagerLicenseKeyExpectedLength = 45;
NSTimeInterval const TLOLicenseManagerTrialLength = 2592000; // 30 days in seconds
NSUInteger const TLOLicenseManagerCurrentLicenseGeneration = 2;

NSString * const TLOLicenseManagerSignedAnswerKeySigningKeyID = @"signingKeyID";
NSString * const TLOLicenseManagerSignedAnswerKeyPayload = @"payload";
NSString * const TLOLicenseManagerSignedAnswerKeySignature = @"signature";

NSString * const TLOLicenseManagerPayloadTypeActivation = @"activation";
NSString * const TLOLicenseManagerPayloadTypeActivationState = @"activationState";
NSString * const TLOLicenseManagerPayloadTypeTrial = @"trial";

static NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerCachedActivation = nil;
static NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerCachedTrial = nil;

NSURL * _Nullable TLOLicenseManagerActivationFilePath(void);
NSURL * _Nullable TLOLicenseManagerTrialFilePath(void);
NSURL * _Nullable TLOLicenseManagerLocalTrialFilePath(void);
NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerLoadSignedAnswerAtURL(NSURL *fileURL, NSString *payloadType);
BOOL TLOLicenseManagerWriteSignedAnswerToURL(NSDictionary<NSString *, id> *signedAnswer, NSURL *fileURL);
NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerActivationPayload(void);
NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerTrialPayload(void);
NSDate * _Nullable TLOLicenseManagerLocalTrialStartDate(void);

#pragma mark -
#pragma mark Setup

void TLOLicenseManagerSetup(void)
{
	static BOOL _setupComplete = NO;

	if (_setupComplete) {
		return;
	}

	_setupComplete = YES;

	(void)TLOLicenseManagerActivationPayload();
}

BOOL TLOLicenseManagerTextualIsRegistered(void)
{
	return (TLOLicenseManagerActivationPayload() != nil);
}

#pragma mark -
#pragma mark This Mac

NSString *TLOLicenseManagerMachineHash(void)
{
	static NSString *machineHash = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSString *platformUUID = nil;

		io_service_t platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"));

		if (platformExpert != IO_OBJECT_NULL) {
			CFTypeRef uuidRef = IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);

			IOObjectRelease(platformExpert);

			id uuid = CFBridgingRelease(uuidRef);

			if ([uuid isKindOfClass:[NSString class]]) {
				platformUUID = uuid;
			}
		}

		if (platformUUID.length == 0) {
			LogToConsoleError("Unable to read the hardware UUID of this Mac");

			platformUUID = @"";
		}

		/* The server only stores and compares this; the hardware UUID never leaves the Mac */
		NSString *saltedUUID = [@"textual-8-license-machine:" stringByAppendingString:platformUUID];

		machineHash = [saltedUUID dataUsingEncoding:NSUTF8StringEncoding].sha256;
	});

	return machineHash;
}

NSString *TLOLicenseManagerMacModel(void)
{
	char modelBuffer[256];

	size_t modelBufferSize = sizeof(modelBuffer);

	if (sysctlbyname("hw.model", modelBuffer, &modelBufferSize, NULL, 0) != 0) {
		return @"Mac";
	}

	modelBuffer[(sizeof(modelBuffer) - 1)] = 0;

	NSString *model = @(modelBuffer);

	if (model.length == 0) {
		return @"Mac";
	}

	return model;
}

#pragma mark -
#pragma mark Signed Answers

NSDictionary<NSString *, NSData *> *TLOLicenseManagerSigningKeys(void)
{
	/* Public keys (X9.63, uncompressed P-256 points) by the ID the server names.
	 Release builds ship only the production key. */
	static NSMutableDictionary<NSString *, NSData *> *signingKeys = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMutableDictionary *keys = [NSMutableDictionary dictionary];

		keys[@"t8-2026-1"] = [[NSData alloc] initWithBase64EncodedString:@"BNu7Lz6XtfeaiKHJBB0eOJNdyo4kDboheL/FqFtjcJKtIIybp5F3mGvBMelVMPMFDGR7mJt/+ZjIWmWrGUqrHFQ=" options:0];

#ifdef DEBUG
		/* A development server's key */
		keys[@"t8-development"] = [[NSData alloc] initWithBase64EncodedString:@"BMyaeiMzVU6dIETmW4dj/Mb/I6h4lqCwpwDzo2A8FdzaQV2/d8O52fC7FkquXhX6WGpruCgx3NZwHtlDLjFp6DU=" options:0];
#endif

		signingKeys = keys;
	});

	return signingKeys;
}

#ifdef DEBUG
void TLOLicenseManagerSetSigningKeyForTesting(NSString *signingKeyID, NSData * _Nullable publicKey)
{
	NSCParameterAssert(signingKeyID != nil);

	((NSMutableDictionary *)TLOLicenseManagerSigningKeys())[signingKeyID] = publicKey;
}
#endif

NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerVerifiedPayload(id signedAnswer, NSString *payloadType)
{
	NSCParameterAssert(payloadType != nil);

	if ([signedAnswer isKindOfClass:[NSDictionary class]] == NO) {
		LogToConsoleError("The signed answer is not a dictionary");

		return nil;
	}

	NSString *signingKeyID = signedAnswer[TLOLicenseManagerSignedAnswerKeySigningKeyID];
	NSData *payload = signedAnswer[TLOLicenseManagerSignedAnswerKeyPayload];
	NSData *signature = signedAnswer[TLOLicenseManagerSignedAnswerKeySignature];

	if ([signingKeyID isKindOfClass:[NSString class]] == NO ||
		[payload isKindOfClass:[NSData class]] == NO ||
		[signature isKindOfClass:[NSData class]] == NO)
	{
		LogToConsoleError("The signed answer is incomplete");

		return nil;
	}

	/* 1. A key this copy of Textual ships */
	NSData *publicKeyData = TLOLicenseManagerSigningKeys()[signingKeyID];

	if (publicKeyData == nil) {
		LogToConsoleError("The answer is signed with an unknown key: %{public}@", signingKeyID);

		return nil;
	}

	NSDictionary *publicKeyAttributes = @{
		(__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
		(__bridge id)kSecAttrKeyClass : (__bridge id)kSecAttrKeyClassPublic,
		(__bridge id)kSecAttrKeySizeInBits : @(256)
	};

	CFErrorRef keyError = NULL;

	SecKeyRef publicKey = SecKeyCreateWithData((__bridge CFDataRef)publicKeyData, (__bridge CFDictionaryRef)publicKeyAttributes, &keyError);

	if (publicKey == NULL) {
		LogToConsoleError("Unable to load the public key %{public}@: %{public}@", signingKeyID, ((__bridge_transfer NSError *)keyError).localizedDescription);

		return nil;
	}

	/* 2. The signature over the exact payload bytes */
	CFErrorRef verifyError = NULL;

	Boolean signatureValid = SecKeyVerifySignature(publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)payload, (__bridge CFDataRef)signature, &verifyError);

	CFRelease(publicKey);

	if (signatureValid == false) {
		LogToConsoleError("The answer's signature is not valid: %{public}@", ((__bridge_transfer NSError *)verifyError).localizedDescription);

		return nil;
	}

	/* 3. Only then read it, and only as the answer that was asked for, for this Mac */
	NSError *payloadReadError = nil;

	id payloadDictionary = [NSPropertyListSerialization propertyListWithData:payload options:NSPropertyListImmutable format:NULL error:&payloadReadError];

	if ([payloadDictionary isKindOfClass:[NSDictionary class]] == NO) {
		LogToConsoleError("The signed payload is not a dictionary: %{public}@", payloadReadError.localizedDescription);

		return nil;
	}

	if ([payloadType isEqual:payloadDictionary[@"payloadType"]] == NO) {
		LogToConsoleError("The signed payload is not of type '%{public}@'", payloadType);

		return nil;
	}

	if ([TLOLicenseManagerMachineHash() isEqual:payloadDictionary[@"machineHash"]] == NO) {
		LogToConsoleInfo("The signed payload is for another Mac");

		return nil;
	}

	return payloadDictionary;
}

BOOL TLOLicenseManagerWriteSignedAnswerToURL(NSDictionary<NSString *, id> *signedAnswer, NSURL *fileURL)
{
	NSCParameterAssert(signedAnswer != nil);
	NSCParameterAssert(fileURL != nil);

	NSError *serializeError = nil;

	NSData *fileContents = [NSPropertyListSerialization dataWithPropertyList:signedAnswer format:NSPropertyListBinaryFormat_v1_0 options:0 error:&serializeError];

	if (fileContents == nil) {
		LogToConsoleError("Unable to serialize the signed answer: %{public}@", serializeError.localizedDescription);

		return NO;
	}

	NSError *writeError = nil;

	if ([fileContents writeToURL:fileURL options:NSDataWritingAtomic error:&writeError] == NO) {
		LogToConsoleError("Unable to write %{public}@: %{public}@", fileURL.lastPathComponent, writeError.localizedDescription);

		return NO;
	}

	return YES;
}

NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerLoadSignedAnswerAtURL(NSURL *fileURL, NSString *payloadType)
{
	NSCParameterAssert(fileURL != nil);
	NSCParameterAssert(payloadType != nil);

	NSData *fileContents = [NSData dataWithContentsOfURL:fileURL];

	if (fileContents == nil) {
		return nil;
	}

	id signedAnswer = [NSPropertyListSerialization propertyListWithData:fileContents options:NSPropertyListImmutable format:NULL error:NULL];

	return TLOLicenseManagerVerifiedPayload(signedAnswer, payloadType);
}

#pragma mark -
#pragma mark Activation

NSURL * _Nullable TLOLicenseManagerActivationFilePath(void)
{
	return [[TPCPathInfo applicationSupportURL] URLByAppendingPathComponent:@"Textual_License_Activation.plist"];
}

NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerActivationPayload(void)
{
	if (TLOLicenseManagerCachedActivation) {
		return TLOLicenseManagerCachedActivation;
	}

	NSURL *activationFilePath = TLOLicenseManagerActivationFilePath();

	if (activationFilePath == nil || [RZFileManager() fileExistsAtURL:activationFilePath] == NO) {
		return nil;
	}

	/* A copied file (another Mac, Migration Assistant) is for another Mac's hash */
	NSDictionary *payload = TLOLicenseManagerLoadSignedAnswerAtURL(activationFilePath, TLOLicenseManagerPayloadTypeActivation);

	if (payload == nil) {
		return nil;
	}

	if ([payload unsignedIntegerForKey:@"licenseGeneration"] != TLOLicenseManagerCurrentLicenseGeneration ||
		[payload[@"activationID"] isKindOfClass:[NSString class]] == NO ||
		[payload[@"licenseKey"] isKindOfClass:[NSString class]] == NO)
	{
		LogToConsoleError("The activation is incomplete or for another license generation");

		return nil;
	}

	TLOLicenseManagerCachedActivation = payload;

	return payload;
}

TLOLicenseManagerActionResult TLOLicenseManagerSaveActivation(id signedAnswer, NSString *licenseKey)
{
	NSCParameterAssert(licenseKey != nil);

	NSDictionary *payload = TLOLicenseManagerVerifiedPayload(signedAnswer, TLOLicenseManagerPayloadTypeActivation);

	if (payload == nil) {
		return TLOLicenseManagerActionResultInvalidSignature;
	}

	/* The answer to this request, not another one */
	if ([payload[@"licenseKey"] isKindOfClass:[NSString class]] == NO ||
		[payload[@"licenseKey"] isEqualToString:licenseKey] == NO ||
		[payload[@"activationID"] isKindOfClass:[NSString class]] == NO ||
		[payload unsignedIntegerForKey:@"licenseGeneration"] != TLOLicenseManagerCurrentLicenseGeneration)
	{
		LogToConsoleError("The activation doesn't match the request");

		return TLOLicenseManagerActionResultMalformedData;
	}

	NSURL *activationFilePath = TLOLicenseManagerActivationFilePath();

	if (activationFilePath == nil || TLOLicenseManagerWriteSignedAnswerToURL(signedAnswer, activationFilePath) == NO) {
		return TLOLicenseManagerActionResultCannotWrite;
	}

	TLOLicenseManagerCachedActivation = payload;

	return TLOLicenseManagerActionResultSuccess;
}

TLOLicenseManagerActionResult TLOLicenseManagerDeleteActivation(void)
{
	TLOLicenseManagerCachedActivation = nil;

	NSURL *activationFilePath = TLOLicenseManagerActivationFilePath();

	if (activationFilePath == nil || [RZFileManager() fileExistsAtURL:activationFilePath] == NO) {
		return TLOLicenseManagerActionResultSuccess;
	}

	NSError *deleteError = nil;

	if ([RZFileManager() removeItemAtURL:activationFilePath error:&deleteError] == NO) {
		LogToConsoleError("Unable to delete the activation: %{public}@", deleteError.localizedDescription);

		return TLOLicenseManagerActionResultCannotWrite;
	}

	return TLOLicenseManagerActionResultSuccess;
}

BOOL TLOLicenseManagerActivationFileExists(void)
{
	NSURL *activationFilePath = TLOLicenseManagerActivationFilePath();

	return (activationFilePath != nil && [RZFileManager() fileExistsAtURL:activationFilePath]);
}

NSString * _Nullable TLOLicenseManagerLicenseKey(void)
{
	return TLOLicenseManagerActivationPayload()[@"licenseKey"];
}

NSString * _Nullable TLOLicenseManagerActivationID(void)
{
	return TLOLicenseManagerActivationPayload()[@"activationID"];
}

NSDate * _Nullable TLOLicenseManagerLicenseDate(void)
{
	NSDate *licenseDate = TLOLicenseManagerActivationPayload()[@"licenseDate"];

	if ([licenseDate isKindOfClass:[NSDate class]] == NO) {
		return nil;
	}

	return licenseDate;
}

NSString * _Nullable TLOLicenseManagerLicenseDateFormatted(void)
{
	NSDate *licenseDate = TLOLicenseManagerLicenseDate();

	if (licenseDate == nil) {
		return nil;
	}

	return [NSDateFormatter localizedStringFromDate:licenseDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
}

NSString *TLOLicenseManagerCleanedLicenseKey(NSString *licenseKey)
{
	NSCParameterAssert(licenseKey != nil);

	/* Keys are lowercase letters, digits and hyphens. A pasted key often brings
	 spaces, line breaks or quotes along, and email apps turn hyphens into dashes. */
	NSMutableString *cleanedLicenseKey = [NSMutableString stringWithCapacity:licenseKey.length];

	for (NSUInteger i = 0; i < licenseKey.length; i++) {
		unichar character = [licenseKey characterAtIndex:i];

		if ((character >= 0x2010 && character <= 0x2015) || character == 0x2212) { // Dashes, minus sign
			character = '-';
		} else if (character >= 'A' && character <= 'Z') {
			character = (character - 'A' + 'a');
		}

		if ((character >= 'a' && character <= 'z') ||
			(character >= '0' && character <= '9') ||
			 character == '-')
		{
			[cleanedLicenseKey appendFormat:@"%C", character];
		}
	}

	return [cleanedLicenseKey copy];
}

BOOL TLOLicenseManagerLicenseKeyIsValid(NSString *licenseKey)
{
	NSCParameterAssert(licenseKey != nil);

	if (licenseKey.length != TLOLicenseManagerLicenseKeyExpectedLength) {
		return NO;
	}

	return [XRRegularExpression string:licenseKey isMatchedByRegex:TLOLicenseManagerLicenseKeyRegularExpression withoutCase:YES];
}

#pragma mark -
#pragma mark Trial

NSURL * _Nullable TLOLicenseManagerTrialFilePath(void)
{
	return [[TPCPathInfo applicationSupportURL] URLByAppendingPathComponent:@"Textual_Trial.plist"];
}

NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerTrialPayload(void)
{
	if (TLOLicenseManagerCachedTrial) {
		return TLOLicenseManagerCachedTrial;
	}

	NSURL *trialFilePath = TLOLicenseManagerTrialFilePath();

	if (trialFilePath == nil || [RZFileManager() fileExistsAtURL:trialFilePath] == NO) {
		return nil;
	}

	NSDictionary *payload = TLOLicenseManagerLoadSignedAnswerAtURL(trialFilePath, TLOLicenseManagerPayloadTypeTrial);

	if ([payload[@"trialEndsAt"] isKindOfClass:[NSDate class]] == NO) {
		return nil;
	}

	TLOLicenseManagerCachedTrial = payload;

	return payload;
}

BOOL TLOLicenseManagerSaveTrial(id signedAnswer)
{
	NSDictionary *payload = TLOLicenseManagerVerifiedPayload(signedAnswer, TLOLicenseManagerPayloadTypeTrial);

	if ([payload[@"trialEndsAt"] isKindOfClass:[NSDate class]] == NO) {
		return NO;
	}

	NSURL *trialFilePath = TLOLicenseManagerTrialFilePath();

	if (trialFilePath == nil || TLOLicenseManagerWriteSignedAnswerToURL(signedAnswer, trialFilePath) == NO) {
		return NO;
	}

	TLOLicenseManagerCachedTrial = payload;

	return YES;
}

BOOL TLOLicenseManagerTrialIsFromServer(void)
{
	return (TLOLicenseManagerTrialPayload() != nil);
}

NSURL * _Nullable TLOLicenseManagerLocalTrialFilePath(void)
{
	return [[TPCPathInfo applicationSupportURL] URLByAppendingPathComponent:@"Textual_Trial_Information_v2.plist"];
}

NSDate * _Nullable TLOLicenseManagerLocalTrialStartDate(void)
{
	/* Until the server answers, the trial counts from this Mac's first launch */
	NSURL *localTrialFilePath = TLOLicenseManagerLocalTrialFilePath();

	if (localTrialFilePath == nil) {
		return nil;
	}

	if ([RZFileManager() fileExistsAtURL:localTrialFilePath] == NO) {
		NSDictionary *trialInformation = @{@"trialPeriodStartDate" : [NSDate date]};

		NSData *trialInformationData = [NSPropertyListSerialization dataWithPropertyList:trialInformation format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];

		NSError *writeError = nil;

		if (trialInformationData == nil || [trialInformationData writeToURL:localTrialFilePath options:NSDataWritingAtomic error:&writeError] == NO) {
			LogToConsoleError("Unable to write the trial information: %{public}@", writeError.localizedDescription);

			return nil;
		}
	}

	NSData *trialInformationData = [NSData dataWithContentsOfURL:localTrialFilePath];

	if (trialInformationData == nil) {
		return nil;
	}

	NSDictionary *trialInformation = [NSPropertyListSerialization propertyListWithData:trialInformationData options:NSPropertyListImmutable format:NULL error:NULL];

	if ([trialInformation isKindOfClass:[NSDictionary class]] == NO) {
		return nil;
	}

	NSDate *trialPeriodStartDate = trialInformation[@"trialPeriodStartDate"];

	if ([trialPeriodStartDate isKindOfClass:[NSDate class]] == NO) {
		return nil;
	}

	return trialPeriodStartDate;
}

NSTimeInterval TLOLicenseManagerTimeRemainingTrial(void)
{
	/* Negative: the time left, as Textual 7 counted it; 0 once the trial is over */
	NSDate *trialEndDate = TLOLicenseManagerTrialPayload()[@"trialEndsAt"];

	if (trialEndDate == nil) {
		NSDate *trialStartDate = TLOLicenseManagerLocalTrialStartDate();

		/* A start in the future means the clock was set back */
		if (trialStartDate == nil || trialStartDate.timeIntervalSinceNow > 0) {
			return 0;
		}

		trialEndDate = [trialStartDate dateByAddingTimeInterval:TLOLicenseManagerTrialLength];
	}

	NSTimeInterval timeLeft = trialEndDate.timeIntervalSinceNow;

	if (timeLeft <= 0) {
		return 0;
	}

	return MIN(timeLeft, TLOLicenseManagerTrialLength) * (-1.0);
}

BOOL TLOLicenseManagerIsTrialExpired(void)
{
	return (TLOLicenseManagerTimeRemainingTrial() >= 0);
}

#pragma mark -
#pragma mark Textual 7

BOOL TLOLicenseManagerImportTextual7LicenseFile(NSData *licenseContents)
{
	NSCParameterAssert(licenseContents != nil);

	/* Kept as it is, to send as proof for the upgrade; it doesn't license Textual 8 */
	NSDictionary *licenseDictionary = [NSPropertyListSerialization propertyListWithData:licenseContents options:NSPropertyListImmutable format:NULL error:NULL];

	if ([licenseDictionary isKindOfClass:[NSDictionary class]] == NO ||
		[licenseDictionary[@"licenseKey"] isKindOfClass:[NSString class]] == NO ||
		TLOLicenseManagerLicenseKeyIsValid(licenseDictionary[@"licenseKey"]) == NO)
	{
		LogToConsoleError("The Textual 7 license file has no license key");

		return NO;
	}

	NSURL *licenseFilePath = TLOLicenseManagerTextual7LicenseFilePath();

	if (licenseFilePath == nil) {
		return NO;
	}

	NSError *writeError = nil;

	if ([licenseContents writeToURL:licenseFilePath options:NSDataWritingAtomic error:&writeError] == NO) {
		LogToConsoleError("Unable to write the Textual 7 license file: %{public}@", writeError.localizedDescription);

		return NO;
	}

	return YES;
}

NSURL * _Nullable TLOLicenseManagerTextual7LicenseFilePath(void)
{
	return [[TPCPathInfo applicationSupportURL] URLByAppendingPathComponent:@"Textual_User_License_v2.plist"];
}

BOOL TLOLicenseManagerTextual7LicenseFileExists(void)
{
	NSURL *licenseFilePath = TLOLicenseManagerTextual7LicenseFilePath();

	return (licenseFilePath != nil && [RZFileManager() fileExistsAtURL:licenseFilePath]);
}

NSData * _Nullable TLOLicenseManagerTextual7LicenseFileContents(void)
{
	NSURL *licenseFilePath = TLOLicenseManagerTextual7LicenseFilePath();

	if (licenseFilePath == nil) {
		return nil;
	}

	return [NSData dataWithContentsOfURL:licenseFilePath];
}

NSString * _Nullable TLOLicenseManagerTextual7LicenseKey(void)
{
	NSData *licenseContents = TLOLicenseManagerTextual7LicenseFileContents();

	if (licenseContents == nil) {
		return nil;
	}

	NSDictionary *licenseDictionary = [NSPropertyListSerialization propertyListWithData:licenseContents options:NSPropertyListImmutable format:NULL error:NULL];

	if ([licenseDictionary isKindOfClass:[NSDictionary class]] == NO) {
		return nil;
	}

	NSString *licenseKey = licenseDictionary[@"licenseKey"];

	if ([licenseKey isKindOfClass:[NSString class]] == NO || TLOLicenseManagerLicenseKeyIsValid(licenseKey) == NO) {
		return nil;
	}

	return licenseKey;
}
#endif

NS_ASSUME_NONNULL_END
