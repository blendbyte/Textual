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
	TLOLicenseManagerActionResultGenerationPrevious, // License is for previous version. Discount available?
	TLOLicenseManagerActionResultGenerationNext, // License is for next version. Maybe they should update.
	TLOLicenseManagerActionResultInvalidSignature, // License signature is invalid
	TLOLicenseManagerActionResultCannotRead, // License cannot be read from disk
	TLOLicenseManagerActionResultCannotWrite, // License cannot be written to disk
	TLOLicenseManagerActionResultMalformedData, // License data is not correct or complete
	TLOLicenseManagerActionResultOther // Other failure reason
};

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
typedef NSString *TLOLicenseManagerLicenseDictionaryKey NS_EXTENSIBLE_STRING_ENUM;

TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeyCreationDate;
TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeyGeneration;
TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeyLicenseKey;
TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeyProductName;
TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeyOwnerContactAddress;
TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeyOwnerName;
TEXTUAL_EXTERN TLOLicenseManagerLicenseDictionaryKey const TLOLicenseManagerLicenseDictionaryKeySignature;

TEXTUAL_EXTERN NSUInteger const TLOLicenseManagerCurrentLicenseGeneration;

TEXTUAL_EXTERN void TLOLicenseManagerSetup(void);

TEXTUAL_EXTERN BOOL TLOLicenseManagerTextualIsRegistered(void);

TEXTUAL_EXTERN BOOL TLOLicenseManagerIsTrialExpired(void);
TEXTUAL_EXTERN NSTimeInterval TLOLicenseManagerTimeRemainingTrial(void);

TEXTUAL_EXTERN TLOLicenseManagerActionResult TLOLicenseManagerDeleteLicenseFile(void);
TEXTUAL_EXTERN TLOLicenseManagerActionResult TLOLicenseManagerWriteLicenseFileContents(NSData * _Nullable newContents);

TEXTUAL_EXTERN BOOL TLOLicenseManagerLicenseKeyIsValid(NSString *licenseKey);

TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseCreationDate(void);
TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseCreationDateFormatted(void);
TEXTUAL_EXTERN NSUInteger TLOLicenseManagerLicenseGeneration(void);
TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseKey(void);
TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseOwnerContactAddress(void);
TEXTUAL_EXTERN NSString * _Nullable TLOLicenseManagerLicenseOwnerName(void);

TEXTUAL_EXTERN NSString * TLOLicenseManagerAuthorizationCode(void);
#endif

NS_ASSUME_NONNULL_END
