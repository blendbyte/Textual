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

typedef NS_ENUM(NSUInteger, TLOLicenseManagerActionResult) {
	TLOLicenseManagerActionResultSuccess, // Validated successfully and saved
	TLOLicenseManagerActionResultInvalidSignature, // Not signed by a key Textual knows, or for another Mac
	TLOLicenseManagerActionResultCannotWrite, // Cannot be written to disk
	TLOLicenseManagerActionResultMalformedData // Not the answer to the request
};

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
TEXTUAL_EXTERN NSUInteger const TLOLicenseManagerCurrentLicenseGeneration;

TEXTUAL_EXTERN void TLOLicenseManagerSetup(void);

/* Activated on this Mac, by an activation the server signed */
TEXTUAL_EXTERN BOOL TLOLicenseManagerTextualIsRegistered(void);

/* What the licensing server is told about this Mac */
TEXTUAL_EXTERN NSString *TLOLicenseManagerMachineHash(void);
TEXTUAL_EXTERN NSString *TLOLicenseManagerMacModel(void);

/* The payload of a signed answer (signingKeyID, payload, signature), once its
 signature, payload type and machine hash check out; nil otherwise */
TEXTUAL_EXTERN NSDictionary<NSString *, id> * _Nullable TLOLicenseManagerVerifiedPayload(id signedAnswer, NSString *payloadType);

#ifdef DEBUG
/* Tests sign answers with a key of their own; nil removes it */
TEXTUAL_EXTERN void TLOLicenseManagerSetSigningKeyForTesting(NSString *signingKeyID, NSData * _Nullable publicKey);
#endif

TEXTUAL_EXTERN TLOLicenseManagerActionResult TLOLicenseManagerSaveActivation(id signedAnswer, NSString *licenseKey);
TEXTUAL_EXTERN TLOLicenseManagerActionResult TLOLicenseManagerDeleteActivation(void);
TEXTUAL_EXTERN BOOL TLOLicenseManagerActivationFileExists(void);

TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseKey(void);
TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerActivationID(void);
TEXTUAL_EXTERN NSDate * _Nullable TLOLicenseManagerLicenseDate(void);
TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseDateFormatted(void);

TEXTUAL_EXTERN BOOL TLOLicenseManagerLicenseKeyIsValid(NSString *licenseKey);

TEXTUAL_EXTERN BOOL TLOLicenseManagerSaveTrial(id signedAnswer);
TEXTUAL_EXTERN BOOL TLOLicenseManagerTrialIsFromServer(void);
TEXTUAL_EXTERN BOOL TLOLicenseManagerIsTrialExpired(void);
TEXTUAL_EXTERN NSTimeInterval TLOLicenseManagerTimeRemainingTrial(void);

/* The Textual 7 licence file, kept as proof for the upgrade */
TEXTUAL_EXTERN BOOL TLOLicenseManagerImportTextual7LicenseFile(NSData *licenseContents);
TEXTUAL_EXTERN NSURL * _Nullable TLOLicenseManagerTextual7LicenseFilePath(void);
TEXTUAL_EXTERN BOOL TLOLicenseManagerTextual7LicenseFileExists(void);
#endif

NS_ASSUME_NONNULL_END
