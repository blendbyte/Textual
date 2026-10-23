/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2020 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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
#import <IOKit/pwr_mgt/IOPM.h>

#include <sys/sysctl.h>

#include <dlfcn.h>

/* Private IOKit function */
typedef uint32_t IOPMCapabilityBits;

static NSUInteger _highestRecognizedMajorOSVersion = 26; // macOS Tahoe

NS_ASSUME_NONNULL_BEGIN

@implementation XRSystemInformation

#pragma mark -
#pragma mark Public

+ (BOOL)systemIsAppleSilicon
{
	/* I haven't tested this. Is it really this easy? */
#if TARGET_CPU_ARM64
	return YES;
#endif

	return NO;
}

+ (nullable NSString *)formattedEthernetMacAddress
{
	CFDataRef macAddressRef = nil;

	/* Mach port used to initiate communication with IOKit. */
	mach_port_t masterPort;

	kern_return_t machPortResult = IOMasterPort(MACH_PORT_NULL, &masterPort);

	if (machPortResult != KERN_SUCCESS) {
		return nil;
	}

	/* Create a matching dictionary */
	CFMutableDictionaryRef matchingDict = IOBSDNameMatching(masterPort, 0, "en0");

	if (matchingDict == NULL) {
		return nil;
	}

	/* Look up registered objects that match a matching dictionary. */
	io_iterator_t iterator;

	kern_return_t getMatchResult = IOServiceGetMatchingServices(masterPort, matchingDict, &iterator);

	if (getMatchResult != KERN_SUCCESS) {
		return nil;
	}

	/* Iterate over services */
	io_object_t service;

	while ((service = IOIteratorNext(iterator)) > 0) {
		io_object_t parentService;

		kern_return_t kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService);

		if (kernResult == KERN_SUCCESS) {
			if (macAddressRef) {
				CFRelease(macAddressRef);
			}

			macAddressRef = (CFDataRef)IORegistryEntryCreateCFProperty(parentService, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);

			IOObjectRelease(parentService);
		}

		IOObjectRelease(service);
	}

	IOObjectRelease(iterator);

	/* If we have a MAC address, convert it into a formatted string. */
	if (macAddressRef) {
		unsigned char macAddressBytes[6];

		CFDataGetBytes(macAddressRef, CFRangeMake(0, 6), macAddressBytes);

		CFRelease(macAddressRef);

		NSString *formattedMacAddress =
		[NSString stringWithFormat:
			 @"%02x:%02x:%02x:%02x:%02x:%02x",
			 macAddressBytes[0], macAddressBytes[1], macAddressBytes[2],
			 macAddressBytes[3], macAddressBytes[4], macAddressBytes[5]];

		return formattedMacAddress;
	}

	return nil;
}

+ (BOOL)systemIsSleeping
{
	IOPMCapabilityBits bits = [self systemPowerCapabilities];

	if (bits == INT_MAX) {
		return NO;
	}

	return ((bits & kIOPMSystemCapabilityCPU) == 0);
}

+ (nullable NSString *)systemBuildVersion
{
	static id cachedValue = nil;
	
	if (cachedValue == nil) {
		cachedValue = [self retrieveSystemInformationKey:@"ProductBuildVersion"];
	}
	
	return cachedValue;
}

+ (nullable NSString *)systemStandardVersion
{
	static id cachedValue = nil;
	
	if (cachedValue == nil) {
		cachedValue = [self retrieveSystemInformationKey:@"ProductVersion"];
	}
	
	return cachedValue;
}

+ (nullable NSString *)systemOperatingSystemName
{
	/* I know that this can be optimized but it is only ran once. */
	static id cachedValue = nil;

	if (cachedValue == nil) {
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];

		if (XRRunningOnUnrecognizedOSVersion()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS", @"XRSystemInformation", bundle, nil);
		} else if (XRRunningOnOSXTahoeOrLater()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS Tahoe", @"XRSystemInformation", bundle, nil);
		} else if (XRRunningOnOSXSequoiaOrLater()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS Sequoia", @"XRSystemInformation", bundle, nil);
		} else if (XRRunningOnOSXSonomaOrLater()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS Sonoma", @"XRSystemInformation", bundle, nil);
 		} else if (XRRunningOnOSXVenturaOrLater()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS Ventura", @"XRSystemInformation", bundle, nil);
		} else if (XRRunningOnOSXMontereyOrLater()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS Monterey", @"XRSystemInformation", bundle, nil);
		} else if (XRRunningOnOSXBigSurOrLater()) {
			cachedValue = NSLocalizedStringFromTableInBundle(@"macOS Big Sur", @"XRSystemInformation", bundle, nil);
		}
	}

	return cachedValue;
}

#pragma mark -
#pragma mark Private

+ (IOPMCapabilityBits)systemPowerCapabilities
{
	static IOPMCapabilityBits (*_functionAddress) (void) = NULL;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSString *managedName = [@"IOPM" stringByAppendingString:@"ConnectionGetSystemCapabilities"];

		_functionAddress = dlsym(RTLD_DEFAULT, [managedName cStringUsingEncoding:NSASCIIStringEncoding]);
	});

	if (_functionAddress) {
		return _functionAddress();
	}

	return INT_MAX;
}

+ (nullable NSString *)systemModelToken
{
	static id cachedValue = nil;
	
	if (cachedValue == nil) {
		char modelBuffer[256];
		
		size_t sz = sizeof(modelBuffer);
		
		if (sysctlbyname("hw.model", modelBuffer, &sz, NULL, 0) == 0) {
			modelBuffer[(sizeof(modelBuffer) - 1)] = 0;
			
			cachedValue = @(modelBuffer);
		}
	}
	
	return cachedValue;
}

+ (nullable NSString *)systemModelName
{
	/* June 11, 2024: This method identifies a model based on the prefix 
	 of its identifier. New Macs no longer have a model specific prefix
	 and instead simply begin with "Mac" — This method is typically used
	 as a last resort to identify an unknown model and it is not worth
	 the effort to redesign it to accommodate this change. */
	static id cachedValue = nil;
	
	if (cachedValue == nil) {
		/* This method is not returning very detailed information. Only
		the model being ran on. Therefore, not much love will be put into
		it. As can be seen below, we are defining our models inline instead
		of using a dictionary that will have to be loaded from a file. */
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];

		NSDictionary *modelPrefixes = @{
			@"macbookpro"	: NSLocalizedStringFromTableInBundle(@"MacBook Pro", @"XRSystemInformation", bundle, nil),
			@"macbookair"	: NSLocalizedStringFromTableInBundle(@"MacBook Air", @"XRSystemInformation", bundle, nil),
			@"macbook"		: NSLocalizedStringFromTableInBundle(@"MacBook", @"XRSystemInformation", bundle, nil),
			@"macpro"		: NSLocalizedStringFromTableInBundle(@"Mac Pro", @"XRSystemInformation", bundle, nil),
			@"macmini"		: NSLocalizedStringFromTableInBundle(@"Mac Mini", @"XRSystemInformation", bundle, nil),
			@"imac"			: NSLocalizedStringFromTableInBundle(@"iMac", @"XRSystemInformation", bundle, nil),
			@"xserve"		: NSLocalizedStringFromTableInBundle(@"Xserve", @"XRSystemInformation", bundle, nil)
		};
		
		NSString *modelToken = [self systemModelToken];
		
		if (modelToken.length <= 0) {
			return nil;
		}
		
		modelToken = modelToken.lowercaseString;
		
		for (NSString *modelPrefix in modelPrefixes) {
			if ([modelToken hasPrefix:modelPrefix]) {
				cachedValue = modelPrefixes[modelPrefix];
			}
		}
		
		if (cachedValue == nil) {
			cachedValue = NSLocalizedStringFromTable(@"Mac", @"XRSystemInformation", nil);
		}
	}
	
	return cachedValue;
}

+ (nullable NSString *)retrieveSystemInformationKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSDictionary *sysinfo = [self systemInformationDictionary];

	NSString *infos = sysinfo[key];

	if (infos.length <= 0) {
		return nil;
	}

	return infos;
}

+ (nullable NSDictionary<NSString *, id> *)createDictionaryFromFileAtPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	NSFileManager *fileManger = [NSFileManager defaultManager];

	if ([fileManger fileExistsAtPath:path]) {
		return [NSDictionary dictionaryWithContentsOfFile:path];
	}

	return nil;
}

+ (nullable NSDictionary *)systemInformationDictionary
{
	NSDictionary *systemInfo = [self createDictionaryFromFileAtPath:@"/System/Library/CoreServices/SystemVersion.plist"];

	if (systemInfo == nil) {
		systemInfo = [self createDictionaryFromFileAtPath:@"/System/Library/CoreServices/ServerVersion.plist"];
	}

	return systemInfo;
}

@end

BOOL XRRunningOnOSXLionOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXMountainLionOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXMavericksOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXYosemiteOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXElCapitanOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXSierraOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXHighSierraOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXMojaveOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXCatalinaOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXBigSurOrLater(void)
{
	return YES; // SDK targets greater OS version
}

BOOL XRRunningOnOSXMontereyOrLater(void)
{
	static BOOL cachedValue = NO;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSOperatingSystemVersion compareVersion;

		compareVersion.majorVersion = 12;
		compareVersion.minorVersion = 0;
		compareVersion.patchVersion = 0;

		cachedValue = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:compareVersion];
	});

	return cachedValue;
}

BOOL XRRunningOnOSXVenturaOrLater(void)
{
	static BOOL cachedValue = NO;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSOperatingSystemVersion compareVersion;

		compareVersion.majorVersion = 13;
		compareVersion.minorVersion = 0;
		compareVersion.patchVersion = 0;

		cachedValue = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:compareVersion];
	});

	return cachedValue;
}

BOOL XRRunningOnOSXSonomaOrLater(void)
{
	static BOOL cachedValue = NO;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSOperatingSystemVersion compareVersion;

		compareVersion.majorVersion = 14;
		compareVersion.minorVersion = 0;
		compareVersion.patchVersion = 0;

		cachedValue = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:compareVersion];
	});

	return cachedValue;
}

BOOL XRRunningOnOSXSequoiaOrLater(void)
{
	static BOOL cachedValue = NO;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSOperatingSystemVersion compareVersion;

		compareVersion.majorVersion = 15;
		compareVersion.minorVersion = 0;
		compareVersion.patchVersion = 0;

		cachedValue = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:compareVersion];
	});

	return cachedValue;
}

BOOL XRRunningOnOSXTahoeOrLater(void)
{
	static BOOL cachedValue = NO;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSOperatingSystemVersion compareVersion;

		compareVersion.majorVersion = 26;
		compareVersion.minorVersion = 0;
		compareVersion.patchVersion = 0;

		cachedValue = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:compareVersion];
	});

	return cachedValue;
}

BOOL XRRunningOnUnrecognizedOSVersion(void)
{
	static BOOL cachedValue = YES;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSOperatingSystemVersion compareVersion;

		compareVersion.majorVersion = (_highestRecognizedMajorOSVersion + 1);
		compareVersion.minorVersion = 0;
		compareVersion.patchVersion = 0;

		cachedValue = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:compareVersion];
	});

	return cachedValue;
}

NS_ASSUME_NONNULL_END
