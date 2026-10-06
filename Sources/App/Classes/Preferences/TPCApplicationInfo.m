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

#import "BuildConfig.h"

#import "TPCPreferencesUserDefaults.h"
#import "TPCApplicationInfoPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TPCApplicationInfo

+ (NSString *)applicationName
{
	return TXBundleBuildProductName;
}

+ (NSString *)applicationNameWithoutVersion
{
	NSString *applicationName = TXBundleBuildProductName;

	NSInteger spacePosition = [applicationName stringPosition:@" "];

	if (spacePosition > 0) {
		return [applicationName substringToIndex:spacePosition];
	} else {
		return applicationName;
	}
}

+ (NSString *)applicationVersion
{
	return TXBundleBuildVersion;
}

+ (NSString *)applicationVersionShort
{
	return TXBundleBuildVersionShort;
}

+ (int)applicationProcessID
{
	return RZProcessInfo().processIdentifier;
}

+ (NSString *)applicationBundleIdentifier
{
	return TXBundleBuildProductIdentifier;
}

+ (NSString *)applicationBuildScheme
{
	return TXBundleBuildScheme;
}

+ (NSDictionary<NSString *, id> *)applicationInfoPlist
{
	return RZMainBundle().infoDictionary;
}

+ (BOOL)sandboxEnabled
{
	return YES;
}

+ (nullable NSDate *)applicationLaunchDate
{
	NSRunningApplication *runningApp = [NSRunningApplication currentApplication];

	return runningApp.launchDate;
}

+ (NSTimeInterval)timeIntervalSinceApplicationLaunch
{
	NSDate *launchDate = [self applicationLaunchDate];

	if (launchDate == nil) {
		return 0;
	}

	return (launchDate.timeIntervalSinceNow * (-1));
}

+ (NSTimeInterval)timeIntervalSinceApplicationInstall
{
	NSTimeInterval runTime = [self timeIntervalSinceApplicationLaunch];

	NSTimeInterval runTimeTotal = [RZUserDefaults() doubleForKey:@"TXRunTime"];

	return (runTimeTotal + runTime);
}

+ (void)saveTimeIntervalSinceApplicationInstall
{
	NSTimeInterval timeInterval = [self timeIntervalSinceApplicationInstall];

	[RZUserDefaults() setDouble:timeInterval forKey:@"TXRunTime"];
}

+ (NSUInteger)applicationRunCount
{
	return [RZUserDefaults() unsignedIntegerForKey:@"TXRunCount"];
}

+ (void)incrementApplicationRunCount
{
	NSUInteger runCount = ([self applicationRunCount] + 1);

	[RZUserDefaults() setUnsignedInteger:runCount forKey:@"TXRunCount"];
}

+ (NSTimeInterval)applicationBirthday
{
	/* The reference date is the date & time of the first commit to the
	 Textual repo. Textual existed before then, of course, but the date
	 will remain as the official reference date for its birthday. */
	/* The date decodes to July 23, 2010 03:53:00 AM */

	return 1279871580.000000;
}

@end

NS_ASSUME_NONNULL_END
