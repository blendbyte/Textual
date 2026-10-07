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
#import "TLOLicenseManagerPrivate.h"
#import "TLOLicenseManagerLastGenPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
@implementation TLOLicenseManagerLastGen

#pragma mark -
#pragma mark Public Interface

+ (nullable NSString *)licenseKey
{
	NSDictionary *licenseDictionary = [self lastGenLicenseDictionary];

	if (licenseDictionary == nil) {
		return nil;
	}

	return [self lastGenLicenseKeyWithLicenseDictionary:licenseDictionary];
}

+ (nullable NSString *)licenseKeyForLicenseContents:(NSData *)licenseContents
{
	NSParameterAssert(licenseContents != nil);

	NSDictionary *licenseDictionary = [self lastGenLicenseDictionaryWithData:licenseContents];

	if (licenseDictionary == nil) {
		return nil;
	}

	NSString *licenseKey = [self lastGenLicenseKeyWithLicenseDictionary:licenseDictionary];

	return licenseKey;
}

#pragma mark -
#pragma mark Public Interface

+ (nullable NSString *)lastGenLicenseKeyWithLicenseDictionary:(NSDictionary<NSString *, id> *)licenseDictionary
{
	NSParameterAssert(licenseDictionary != nil);

	/* The integrity of the file and whether it is properly signed does not
	 matter for this class. We are only interested in whether the dictionary
	 we have is last gen and whether it has a valid license key. If both are
	 true, then we can advise user that they need to upgrade. Nothing more. */
	NSString *licenseKey = licenseDictionary[@"licenseKey"];

	if (TLOLicenseManagerLicenseKeyIsValid(licenseKey) == NO) {
		return nil;
	}

	/* Last gen license dictionary did not have a license generation value. */
	/* If that is not present, than consider the dictionary last gen. */
	id licenseGeneration = licenseDictionary[@"licenseGeneration"];

	if (licenseGeneration == nil || [licenseGeneration isKindOfClass:[NSNumber class]] == NO) {
		return licenseKey;
	}

	if ([licenseGeneration unsignedIntegerValue] != TLOLicenseManagerCurrentLicenseGeneration) {
		return licenseKey;
	}

	return nil;
}

+ (nullable NSURL *)lastGenLicenseFilePath
{
	NSURL *sourceURL = [TPCPathInfo applicationSupportURL];

	if (sourceURL == nil) {
		return nil;
	}

	NSURL *baseURL = [sourceURL URLByAppendingPathComponent:@"/Textual_User_License.plist"];

	return baseURL;
}

+ (nullable NSData *)lastGenLicenseFileContents
{
	NSURL *licenseFilePath = [self lastGenLicenseFilePath];

	if (licenseFilePath == nil) {
		LogToConsoleError("Unable to determine the path to retrieve license information from");

		return nil;
	}

	if ([RZFileManager() fileExistsAtURL:licenseFilePath] == NO) {
		return nil;
	}

	NSError *readError = nil;

	NSData *licenseContents = [NSData dataWithContentsOfURL:licenseFilePath options:0 error:&readError];

	if (licenseContents == nil) {
		LogToConsoleError("Unable to read user license file (%{public}@). Error: %{public}@", licenseFilePath.standardizedTildePath, readError.localizedDescription);

		return nil;
	}

	return licenseContents;
}

+ (nullable NSDictionary<NSString *, id> *)lastGenLicenseDictionary
{
	NSData *licenseContents = [self lastGenLicenseFileContents];

	if (licenseContents == nil) {
		return nil;
	}

	return [self lastGenLicenseDictionaryWithData:licenseContents];
}

+ (nullable NSDictionary<NSString *, id> *)lastGenLicenseDictionaryWithData:(NSData *)licenseContents
{
	NSParameterAssert(licenseContents != nil);

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

@end
#endif

NS_ASSUME_NONNULL_END
