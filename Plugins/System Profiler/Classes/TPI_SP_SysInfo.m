/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2012 - 2020 Codeux Software, LLC & respective contributors.
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

#import <WebKit/WebKit.h>

#import "TPI_SP_SysInfo.h"

NS_ASSUME_NONNULL_BEGIN

#define _localVolumeBaseDirectory		@"/Volumes"

#define _systemMemoryDivisor			1.073741824

@interface WKWebView ()
@property (nonatomic, readonly) pid_t _webProcessIdentifier;
@end

@interface TPI_SP_WebViewProcessInfo : NSObject
@property (nonatomic, assign) pid_t processIdentifier;
@property (nonatomic, assign) uint64_t processMemoryUse;
@property (nonatomic, strong) NSArray<NSString *> *processViewNames;
@end

@interface TPI_SP_SysInfo : NSObject
+ (nullable NSString *)modelIdentifier;

+ (nullable NSString *)processor;
+ (NSUInteger)processorPhysicalCoreCount;
+ (NSUInteger)processorVirtualCoreCount;
+ (nullable NSString *)processorClockSpeed;

+ (NSTimeInterval)systemUptime;
+ (NSTimeInterval)applicationUptime;

+ (uint64_t)freeMemorySize;
+ (uint64_t)totalMemorySize;

+ (uint64_t)applicationMemoryInformation;

+ (nullable NSString *)formattedGraphicsCardInformation;
+ (nullable NSString *)formattedLocalVolumeDiskUsage;
+ (NSString *)formattedTotalMemorySize;
+ (NSString *)formattedDiskSize:(uint64_t)diskSize;
+ (NSString *)formattedCPUFrequency:(double)frequency;

+ (NSString *)descriptionForSidebarAppearance;
+ (NSString *)descriptionForThemeAppearance;
+ (NSString *)descriptionForThemeAppearance:(TPCThemeAppearanceType)appearance;

+ (uint64_t)memoryUseForProcess:(pid_t)processIdentifier;

+ (NSArray<TPI_SP_WebViewProcessInfo *> *)webViewProcessIdentifiers;
+ (pid_t)webViewProcessIdentifierForTreeItem:(IRCTreeItem *)treeItem;

+ (nullable NSString *)refreshRateForScreen:(NSScreen *)screen;
@end

@implementation TPI_SP_CompiledOutput

+ (NSString *)applicationActiveStyle
{
	NSString *themeName = themeController().name;

	TPCThemeStorageLocation storageLocation = themeController().storageLocation;

	NSString *storageLocationLabel = [TPCThemeController descriptionForStorageLocation:storageLocation];

	NSString *sidebarAppearance = [TPI_SP_SysInfo descriptionForSidebarAppearance];
	NSString *themeAppearance = [TPI_SP_SysInfo descriptionForThemeAppearance];

	NSString *appearanceText = nil;

	if ([sidebarAppearance isEqualToString:themeAppearance]) {
		appearanceText = TPILocalizedString(@"BasicLanguage[614-dj]", sidebarAppearance);
	} else {
		appearanceText = TPILocalizedString(@"BasicLanguage[843-z4]", themeAppearance, sidebarAppearance);
	}

	return TPILocalizedString(@"BasicLanguage[z37-85]",
		   themeName, storageLocationLabel, appearanceText);
}

+ (NSString *)applicationAndSystemUptime
{
	NSUInteger dateFormat = (NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond);

	NSString *systemUptime = TXHumanReadableTimeInterval([TPI_SP_SysInfo systemUptime], NO, dateFormat);
	NSString *textualUptime = TXHumanReadableTimeInterval([TPI_SP_SysInfo applicationUptime], NO, dateFormat);

	return TPILocalizedString(@"BasicLanguage[v03-jx]", systemUptime, textualUptime);
}

+ (NSString *)applicationBandwidthStatistics
{
	IRCClient *client = mainWindow().selectedClient;

	NSTimeInterval lastMessage = [NSDate timeIntervalSinceNow:client.lastMessageReceived];

	return TPILocalizedString(@"BasicLanguage[rua-9r]",
			  TXFormattedNumber(worldController().messagesSent),
			  TXFormattedNumber(worldController().messagesReceived),
			  TXHumanReadableTimeInterval(lastMessage, YES, NSCalendarUnitSecond),
			  [TPI_SP_SysInfo formattedDiskSize:worldController().bandwidthIn],
			  [TPI_SP_SysInfo formattedDiskSize:worldController().bandwidthOut]);
}

+ (NSString *)applicationMemoryUsage
{
	NSUInteger totalScrollbackSize = 0;

	for (IRCClient *u in worldController().clientList) {
		totalScrollbackSize += u.viewController.numberOfLines;

		for (IRCChannel *c in u.channelList) {
			totalScrollbackSize += c.viewController.numberOfLines;
		}
	}

	uint64_t textualMemoryUse = [TPI_SP_SysInfo applicationMemoryInformation];

	return TPILocalizedString(@"BasicLanguage[scn-br]",
		[TPI_SP_SysInfo formattedDiskSize:textualMemoryUse],
		 TXFormattedNumber(totalScrollbackSize));
}

+ (nullable NSString *)webKitFrameworkMemoryUsage
{
	NSArray *webViewProcesses = [TPI_SP_SysInfo webViewProcessIdentifiers];

	if (webViewProcesses.count == 0) {
		return nil;
	}

	TPI_SP_WebViewProcessInfo *topProcess = webViewProcesses[0];

	NSArray *viewNameArray = topProcess.processViewNames;

	if (viewNameArray.count == 0) {
		return nil;
	}

	NSString *viewName = [viewNameArray componentsJoinedByString:@", "];

	NSMutableString *resultString = [NSMutableString string];

	if (viewNameArray.count == 1) {
		[resultString appendString:
		 TPILocalizedString(@"BasicLanguage[ioy-qc]",
			topProcess.processIdentifier,
			 viewName,
			[TPI_SP_SysInfo formattedDiskSize:topProcess.processMemoryUse])];
	} else {
		[resultString appendString:
		 TPILocalizedString(@"BasicLanguage[a00-8n]",
			topProcess.processIdentifier,
			 viewName,
			[TPI_SP_SysInfo formattedDiskSize:topProcess.processMemoryUse])];
	}

	[resultString appendString:@"\n"];

	uint64_t totalMemoryUse = 0;

	for (TPI_SP_WebViewProcessInfo *processInfo in webViewProcesses) {
		totalMemoryUse += processInfo.processMemoryUse;
	}

	[resultString appendString:
	 TPILocalizedString(@"BasicLanguage[a5u-m1]",
		webViewProcesses.count,
		[TPI_SP_SysInfo formattedDiskSize:totalMemoryUse])];

	return [resultString copy];
}

+ (NSString *)applicationRuntimeStatistics
{
	NSTimeInterval runtime = [TPCApplicationInfo timeIntervalSinceApplicationInstall];

	NSTimeInterval birthday = [NSDate timeIntervalSinceNow:[TPCApplicationInfo applicationBirthday]];

	if (runtime > birthday) {
		runtime = birthday;
	}

	return TPILocalizedString(@"BasicLanguage[6fn-xh]",
			TXFormattedNumber([TPCApplicationInfo applicationRunCount]),
			TXHumanReadableTimeInterval(runtime, NO, 0));
}

+ (NSString *)systemDiskspaceInformation
{
	NSMutableString *resultString = [NSMutableString string];

	NSArray *volumeAttributes = @[NSURLVolumeNameKey, NSURLVolumeTotalCapacityKey, NSURLVolumeAvailableCapacityKey];

	NSArray *volumes = [RZFileManager() mountedVolumeURLsIncludingResourceValuesForKeys:volumeAttributes options:NSVolumeEnumerationSkipHiddenVolumes];

	[volumes enumerateObjectsUsingBlock:^(NSURL *volume, NSUInteger index, BOOL *stop) {
		NSString *volumeName = [volume resourceValueForKey:NSURLVolumeNameKey];

		uint64_t totalSpace = [[volume resourceValueForKey:NSURLVolumeTotalCapacityKey] longLongValue];
		uint64_t freeSpace = [[volume resourceValueForKey:NSURLVolumeAvailableCapacityKey] longLongValue];

		if (index == 0) {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[bvr-wz]", volumeName,
										[TPI_SP_SysInfo formattedDiskSize:totalSpace],
										[TPI_SP_SysInfo formattedDiskSize:freeSpace])];
		} else {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[lct-7h]", volumeName,
										 [TPI_SP_SysInfo formattedDiskSize:totalSpace],
										 [TPI_SP_SysInfo formattedDiskSize:freeSpace])];
		}
	}];

	if (resultString.length == 0) {
		return TPILocalizedString(@"BasicLanguage[ler-a5]");
	} else {
		return TPILocalizedString(@"BasicLanguage[n6i-xd]", resultString);
	}
}

+ (NSString *)systemDisplayInformation
{
	NSMutableString *resultString = [NSMutableString string];

	NSArray *screens = [NSScreen screens];

	[screens enumerateObjectsUsingBlock:^(NSScreen *screen, NSUInteger index, BOOL *stop) {
		NSInteger screenNumber = (index + 1);

		NSString *refreshRate = [TPI_SP_SysInfo refreshRateForScreen:screen];

		NSString *localization = nil;

		if (screenNumber == 1) {
			if (refreshRate == nil) {
				localization = @"BasicLanguage[441-8c]";
			} else {
				localization = @"BasicLanguage[vvt-zq]";
			}
		} else {
			if (refreshRate == nil) {
				localization = @"BasicLanguage[dd1-rp]";
			} else {
				localization = @"BasicLanguage[fys-ft]";
			}
		}

		if (refreshRate == nil) {
			refreshRate = @"";
		}

		[resultString appendString:
		 TPILocalizedString(localization,
			screenNumber,
			screen.screenResolutionString,
			refreshRate)];
	}];

	return [resultString copy];
}

+ (NSString *)systemInformation
{
	BOOL showCPUModel = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> CPU Model"] == NO);

#if TARGET_CPU_ARM64
	BOOL showGPUModel = NO;
#elif TARGET_CPU_X86_64
	BOOL showGPUModel = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> GPU Model"] == NO);
#endif

	BOOL showDiskInfo = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> Disk Information"] == NO);
	BOOL showMemory = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> Memory Information"] == NO);
	BOOL showOperatingSystem = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> OS Version"] == NO);
	BOOL showScreenResolution = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> Screen Resolution"] == NO);
	BOOL showUptime = ([RZUserDefaults() boolForKey:@"System Profiler Extension -> Feature Disabled -> System Uptime"] == NO);

	NSMutableString *resultString = [NSMutableString string];

	[resultString appendString:TPILocalizedString(@"BasicLanguage[lxj-ha]")];

	NSString *modelIdentifier = [TPI_SP_SysInfo modelIdentifier];

	if (modelIdentifier.length > 0) {
		NSString *modelsDictionaryPath = [TPIBundleFromClass() pathForResource:@"MacintoshModels" ofType:@"plist"];

		NSDictionary *modelsDictionary = [NSDictionary dictionaryWithContentsOfFile:modelsDictionaryPath];

		NSString *modelTitle = nil;

		if ([modelIdentifier hasPrefix:@"VMware"]) {
			modelTitle = modelsDictionary[@"VMware"];
		} else if ([modelIdentifier hasPrefix:@"Parallels"]) {
			modelTitle = modelsDictionary[@"Parallels"];
		} else {
			modelTitle = modelsDictionary[modelIdentifier];
		}

TEXTUAL_IGNORE_DEPRECATION_BEGIN
		if (modelTitle == nil) {
			modelTitle = [XRSystemInformation systemModelName];
		}
TEXTUAL_IGNORE_DEPRECATION_END

		[resultString appendString:
		 TPILocalizedString(@"BasicLanguage[7g5-pf]", modelTitle)];
	}

	if (showCPUModel) {
		NSString *_cpu_model = [TPI_SP_SysInfo processor];

		NSUInteger _cpu_count_p	= [TPI_SP_SysInfo processorPhysicalCoreCount];
		
#if TARGET_CPU_ARM64
		
		if (_cpu_model.length > 0) {
			[resultString appendString:
			 TPILocalizedString(@"BasicLanguage[ifk-s5]",
					_cpu_model,
					_cpu_count_p)];
		}
		
#elif TARGET_CPU_X86_64

		NSString *_cpu_speed = [TPI_SP_SysInfo processorClockSpeed];

		NSUInteger _cpu_count_v	= [TPI_SP_SysInfo processorVirtualCoreCount];

		_cpu_model = [XRRegularExpression string:_cpu_model replacedByRegex:@"(\\s*@.*)|CPU|\\(R\\)|\\(TM\\)"	withString:@" "];
		_cpu_model = [XRRegularExpression string:_cpu_model replacedByRegex:@"\\s+"								withString:@" "];

		_cpu_model = _cpu_model.trim;

		if (_cpu_model.length > 0 && _cpu_speed.length > 0) {
			[resultString appendString:
			 TPILocalizedString(@"BasicLanguage[mnc-vx]",
					_cpu_model,
					_cpu_count_v,
					_cpu_count_p,
					_cpu_speed)];
		}

#endif

	}

	if (showMemory) {
		[resultString appendString:
		 TPILocalizedString(@"BasicLanguage[1am-io]",
			[TPI_SP_SysInfo formattedTotalMemorySize])];
	}

	if (showUptime) {
		[resultString appendString:
		 TPILocalizedString(@"BasicLanguage[xb6-bh]",
			TXHumanReadableTimeInterval([TPI_SP_SysInfo systemUptime], YES, 0))];
	}

	if (showDiskInfo) {
		NSString *_disk_info = [TPI_SP_SysInfo formattedLocalVolumeDiskUsage];

		if (_disk_info != nil) {
			[resultString appendString:
			 TPILocalizedString(@"BasicLanguage[yrc-6l]", _disk_info)];
		}
	}

	if (showGPUModel) {
		NSString *_gpu_model = [TPI_SP_SysInfo formattedGraphicsCardInformation];

		if (_gpu_model != nil) {
			[resultString appendString:
			 TPILocalizedString(@"BasicLanguage[q5v-uq]", _gpu_model)];
		}
	}

	if (showScreenResolution) {
		NSScreen *mainScreen = RZMainScreen();

		NSString *refreshRate = [TPI_SP_SysInfo refreshRateForScreen:mainScreen];

		if (refreshRate == nil) {
			[resultString appendString:
		     TPILocalizedString(@"BasicLanguage[22o-rg]",
			 mainScreen.screenResolutionString)];
		} else {
			[resultString appendString:
		     TPILocalizedString(@"BasicLanguage[b7c-qd]",
			 mainScreen.screenResolutionString,
			 refreshRate)];
		}
	}

	if (showOperatingSystem) {
		[resultString appendString:
		 TPILocalizedString(@"BasicLanguage[g41-p7]",
			[XRSystemInformation systemOperatingSystemName],
			[XRSystemInformation systemStandardVersion],
			[XRSystemInformation systemBuildVersion])];
	}

	if ([resultString hasSuffix:@" \002•\002"]) {
		[resultString deleteCharactersInRange:NSMakeRange((resultString.length - 4), 4)];
	}

	return [resultString copy];
}

+ (NSString *)systemMemoryInformation
{
	uint64_t totalMemory = [TPI_SP_SysInfo totalMemorySize];
	uint64_t freeMemory = [TPI_SP_SysInfo freeMemorySize];

	uint64_t usedMemory = (totalMemory - freeMemory);

	long double memoryUsedPercent = (((long double)usedMemory / (long double)totalMemory) * 100.0);

	NSMutableString *resultString = [NSMutableString string];

	/* ======================================== */

	[resultString appendFormat:@"%c04", 0x03];

	NSUInteger leftCount = (memoryUsedPercent / 10);

	for (NSUInteger i = 0; i <= leftCount; i++) {
		[resultString appendString:@"❙"];
	}

	/* ======================================== */

	[resultString appendFormat:@"%c|%c03", 0x03, 0x03];

	/* ======================================== */

	NSUInteger rightCount = (10 - leftCount);

	for (NSUInteger i = 0; i <= rightCount; i++) {
		[resultString appendString:@"❙"];
	}

	[resultString appendFormat:@"%c", 0x03];

	/* ======================================== */

	return TPILocalizedString(@"BasicLanguage[cfs-b1]",
			[TPI_SP_SysInfo formattedDiskSize:freeMemory],
			[TPI_SP_SysInfo formattedDiskSize:usedMemory],
			[TPI_SP_SysInfo formattedDiskSize:totalMemory],
					resultString);
}

+ (NSString *)systemNetworkInformation
{
	/* Based off the source code of "libtop.c" */

	NSMutableString *resultString = [NSMutableString string];

	struct ifaddrs *ifa_list = 0;

	if (getifaddrs(&ifa_list) == (-1)) {
		return TPILocalizedString(@"BasicLanguage[li1-vn]");
	}

	NSUInteger objectIndex = 0;

	for (struct ifaddrs *ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
		if ((AF_LINK == ifa->ifa_addr->sa_family) == NO) {
			continue;
		} else if ((ifa->ifa_flags & IFF_UP) == NO && (ifa->ifa_flags & IFF_RUNNING) == NO) {
			continue;
		} else if (ifa->ifa_data == 0) {
			continue;
		}

		if (strncmp(ifa->ifa_name, "lo", 2) == 0) {
			continue;
		}

		struct if_data *if_data = (struct if_data *)ifa->ifa_data;

		if (if_data->ifi_ibytes < 20000000 || if_data->ifi_obytes < 2000000) {
			continue;
		}

		if (objectIndex == 0) {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[ca4-25]",
										 @(ifa->ifa_name),
										 [TPI_SP_SysInfo formattedDiskSize:if_data->ifi_ibytes],
										 [TPI_SP_SysInfo formattedDiskSize:if_data->ifi_obytes])];
		} else {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[mjo-o0]",
										 @(ifa->ifa_name),
										 [TPI_SP_SysInfo formattedDiskSize:if_data->ifi_ibytes],
										 [TPI_SP_SysInfo formattedDiskSize:if_data->ifi_obytes])];
		}

		objectIndex += 1;
	}

	if (ifa_list) {
		freeifaddrs(ifa_list);
	}

	if (resultString.length == 0) {
		return TPILocalizedString(@"BasicLanguage[li1-vn]");
	} else {
		return TPILocalizedString(@"BasicLanguage[9f8-ej]", resultString);
	}

	return resultString;
}

@end

@implementation TPI_SP_SysInfo

#pragma mark -
#pragma mark Formatting/Processing 

+ (NSString *)formattedDiskSize:(uint64_t)diskSize
{
	return [NSByteCountFormatter stringFromByteCountWithPaddedDigits:diskSize];
}

+ (NSString *)formattedCPUFrequency:(double)frequency
{
	if ((frequency / 1000000) >= 990) {
		return TPILocalizedString(@"BasicLanguage[3iu-k8]", ((frequency / 100000000.0) / 10.0));
	} else {
		return TPILocalizedString(@"BasicLanguage[jw7-sg]", frequency);
	}
}

+ (NSString *)formattedTotalMemorySize
{
	return [self formattedDiskSize:[self totalMemorySize]];
}

+ (nullable NSString *)formattedLocalVolumeDiskUsage
{
	NSDictionary *diskInfo = [RZFileManager() attributesOfFileSystemForPath:@"/" error:nil];

	if (diskInfo == nil) {
		return nil;
	}

	uint64_t totalSpace = [diskInfo longLongForKey:NSFileSystemSize];

	return [self formattedDiskSize:totalSpace];
}

+ (nullable NSString *)formattedGraphicsCardInformation
{
	CFMutableDictionaryRef pciDevices = IOServiceMatching("IOPCIDevice");

	io_iterator_t entryIterator;

	if (IOServiceGetMatchingServices(kIOMasterPortDefault, pciDevices, &entryIterator) != kIOReturnSuccess) {
		return nil;
	}

	NSMutableArray<NSString *> *gpuModels = [NSMutableArray new];

	io_iterator_t serviceObject;

	while ((serviceObject = IOIteratorNext(entryIterator))) {
		CFMutableDictionaryRef serviceDictionary;

		kern_return_t status =
		IORegistryEntryCreateCFProperties(serviceObject,
										  &serviceDictionary,
										  kCFAllocatorDefault,
										  kNilOptions);

		if (status != kIOReturnSuccess) {
			IOObjectRelease(serviceObject);

			continue;
		}

		BOOL cleanResult = YES;

		const void *classCode = CFDictionaryGetValue(serviceDictionary, @"class-code");

		if (classCode == NULL) {
			cleanResult = NO;
		} if (CFGetTypeID(classCode) != CFDataGetTypeID()) {
			cleanResult = NO;
		} else if (CFDataGetLength(classCode) == 0) {
			cleanResult = NO;
		} else if (*(UInt32 *)CFDataGetBytePtr(classCode) != 0x30000) {
			cleanResult = NO;
		}

		const void *model = CFDictionaryGetValue(serviceDictionary, @"model");

		if (model == NULL) {
			cleanResult = NO;
		} else if (CFGetTypeID(model) != CFDataGetTypeID()) {
			cleanResult = NO;
		} else if (CFDataGetLength(model) == 0) {
			cleanResult = NO;
		}

		if (cleanResult) {
			NSString *modelString = [NSString stringWithData:(__bridge NSData *)(CFDataRef)model encoding:NSASCIIStringEncoding];

			modelString = [modelString stringByReplacingOccurrencesOfString:@"\0" withString:@""];

			[gpuModels addObject:modelString];
		}

		CFRelease(serviceDictionary);
	}

	// ---- //

	NSMutableString *resultString = [NSMutableString string];

	[gpuModels enumerateObjectsUsingBlock:^(NSString *gpuModel, NSUInteger index, BOOL *stop) {
		if (index == 0) {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[8nu-89]", gpuModel)];
		} else {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[cmk-ws]", gpuModel)];
		}
	}];

	return [resultString copy];
}

+ (NSString *)descriptionForSidebarAppearance
{
	if (mainWindow().usingDarkAppearance) {
		return TPILocalizedString(@"BasicLanguage[243-yt]"); // Dark
	}

	return TPILocalizedString(@"BasicLanguage[890-au]"); // Light
}

+ (NSString *)descriptionForThemeAppearance
{
	TPCThemeAppearanceType appearance = themeController().theme.appearance;

	return [self descriptionForThemeAppearance:appearance];
}

+ (NSString *)descriptionForThemeAppearance:(TPCThemeAppearanceType)appearance
{
	if (appearance == TPCThemeAppearanceTypeDefault) {
		TXAppearance *appAppearance = [TXSharedApplication sharedAppearance];

		if (appAppearance.properties.isDarkAppearance) {
			appearance = TPCThemeAppearanceTypeDark;
		} else {
			appearance = TPCThemeAppearanceTypeLight;
		}
	}

	if (appearance == TPCThemeAppearanceTypeDark) {
		return TPILocalizedString(@"BasicLanguage[243-yt]"); // Dark
	}

	return TPILocalizedString(@"BasicLanguage[890-au]"); // Light
}

#pragma mark -
#pragma mark System Information

+ (NSTimeInterval)systemUptime
{
	struct timeval bootTime;

	size_t bootTimeSize = sizeof(bootTime);

	if (sysctlbyname("kern.boottime", &bootTime, &bootTimeSize, NULL, 0) != 0) {
		bootTime.tv_sec = 0;
	}

	return [NSDate timeIntervalSinceNow:bootTime.tv_sec];
}

+ (NSTimeInterval)applicationUptime
{
	return [TPCApplicationInfo timeIntervalSinceApplicationLaunch];
}

+ (nullable NSString *)processor
{
	char buffer[256];

	size_t bufferSize = sizeof(buffer);

	if (sysctlbyname("machdep.cpu.brand_string", buffer, &bufferSize, NULL, 0) != 0) {
		return nil;
	}

	buffer[(bufferSize - 1)] = 0;

	return @(buffer);
}

+ (nullable NSString *)modelIdentifier
{
	char buffer[256];

	size_t bufferSize = sizeof(buffer);

	if (sysctlbyname("hw.model", buffer, &bufferSize, NULL, 0) != 0) {
		return nil;
	}

	buffer[(bufferSize - 1)] = 0;

	return @(buffer);
}

+ (NSUInteger)processorPhysicalCoreCount
{
	u_int64_t coreCount = 0L;

	size_t coreCountSize = sizeof(coreCount);

	if (sysctlbyname("hw.physicalcpu", &coreCount, &coreCountSize, NULL, 0) != 0) {
		return 0;
	}

	return coreCount;
}

+ (NSUInteger)processorVirtualCoreCount
{
	u_int64_t coreCount = 0L;

	size_t coreCountSize = sizeof(coreCount);

	if (sysctlbyname("hw.logicalcpu", &coreCount, &coreCountSize, NULL, 0) != 0) {
		return 0;
	}

	return coreCount;
}

+ (nullable NSString *)processorClockSpeed
{
	u_int64_t clockSpeed = 0L;

	size_t clockSpeedSize = sizeof(clockSpeed);

	if (sysctlbyname("hw.cpufrequency", &clockSpeed, &clockSpeedSize, NULL, 0) != 0) {
		return nil;
	}

	return [self formattedCPUFrequency:clockSpeed];
}

+ (uint64_t)freeMemorySize
{
	vm_size_t page_size;

	host_page_size(mach_host_self(), &page_size);

	vm_statistics_data_t host_info_out;

	mach_msg_type_number_t host_info_outCnt = (sizeof(vm_statistics_data_t) / sizeof(natural_t));

	if (host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&host_info_out, &host_info_outCnt) != KERN_SUCCESS) {
		return 0;
	}

	return ((host_info_out.inactive_count + host_info_out.free_count) * page_size);
}

+ (uint64_t)totalMemorySize
{
	uint64_t memoryTotal = 0L;

	size_t memoryTotalSize = sizeof(memoryTotal);

	if (sysctlbyname("hw.memsize", &memoryTotal, &memoryTotalSize, NULL, 0) != 0) {
		return 0;
	}

	return (memoryTotal / _systemMemoryDivisor);
}

+ (uint64_t)applicationMemoryInformation
{
	pid_t processIdentifier = (pid_t)[NSProcessInfo processInfo].processIdentifier;

	return [TPI_SP_SysInfo memoryUseForProcess:processIdentifier];
}

+ (uint64_t)memoryUseForProcess:(pid_t)processIdentifier
{
	if (processIdentifier == 0) {
		return 0;
	}

	int processLookupResult = 0;

	struct proc_regioninfo processRegionInfo;

	uint64_t processAddress = 0;

	uint64_t memoryUse = 0;

	int memoryPageSize = getpagesize();

	do {
		processLookupResult =
		proc_pidinfo(processIdentifier, PROC_PIDREGIONINFO, processAddress, &processRegionInfo, PROC_PIDREGIONINFO_SIZE);

		processAddress = (processRegionInfo.pri_address + processRegionInfo.pri_size);

		if (processRegionInfo.pri_share_mode == SM_PRIVATE) {
			memoryUse += (processRegionInfo.pri_private_pages_resident * memoryPageSize);
		}
	} while (processLookupResult > 0);

	return memoryUse;
}

+ (NSArray<TPI_SP_WebViewProcessInfo *> *)webViewProcessIdentifiers
{
	/* Create a dictionary with key as identifier and value as an array of 
	 views managed by the process. */
	NSMutableDictionary<NSNumber *, __kindof NSArray *> *webViewProcesses = [NSMutableDictionary dictionary];

	void (^_addEntry)(IRCTreeItem *) = ^void (IRCTreeItem *treeItem)
	{
		pid_t processIdentifier = [TPI_SP_SysInfo webViewProcessIdentifierForTreeItem:treeItem];

		if (processIdentifier == 0) {
			return;
		}

		NSNumber *processIdentifierObj = @(processIdentifier);

		NSMutableArray<NSString *> *viewArray = webViewProcesses[processIdentifierObj];

		if (viewArray == nil) {
			viewArray = [NSMutableArray array];

			webViewProcesses[processIdentifierObj] = viewArray;
		}

		if (treeItem.isClient) {
			return;
		}

		[viewArray addObject:treeItem.name];
	};

	for (IRCClient *u in worldController().clientList) {
		_addEntry(u);

		for (IRCChannel *c in u.channelList) {
			_addEntry(c);
		}
	}

	/* Create array of TPI_SP_WebViewProcessInfo objects */
	NSMutableArray<TPI_SP_WebViewProcessInfo *> *webViewProcessObjects =
	[NSMutableArray arrayWithCapacity:webViewProcesses.count];

	[webViewProcesses enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		/* Object values */
		pid_t processIdentifier = [key intValue];

		uint64_t processMemoryUse = [TPI_SP_SysInfo memoryUseForProcess:processIdentifier];

		NSArray *processViewNames = [object sortedArrayUsingSelector:@selector(compare:)];

		/* Set values */
		TPI_SP_WebViewProcessInfo *processInfoObject = [TPI_SP_WebViewProcessInfo new];

		processInfoObject.processIdentifier = processIdentifier;

		processInfoObject.processMemoryUse = processMemoryUse;

		processInfoObject.processViewNames = processViewNames;

		/* Add object */
		[webViewProcessObjects addObject:processInfoObject];
	}];

	/* Sort objects based on memory use (highest to lowest) */
	[webViewProcessObjects sortUsingComparator:^NSComparisonResult(id object1, id object2) {
		uint64_t processMemoryUse1 = [object1 processMemoryUse];
		uint64_t processMemoryUse2 = [object2 processMemoryUse];

		if (processMemoryUse1 > processMemoryUse2) {
			return NSOrderedAscending;
		} else if (processMemoryUse1 < processMemoryUse2) {
			return NSOrderedDescending;
		}

		return NSOrderedSame;
	}];

	/* Return a copy of mutable array */
	return [webViewProcessObjects copy];
}

+ (pid_t)webViewProcessIdentifierForTreeItem:(IRCTreeItem *)treeItem
{
	TVCLogView *backingView = treeItem.viewController.backingView;

	id webView = backingView.webView;

	if ([webView respondsToSelector:@selector(_webProcessIdentifier)]) {
		return [webView _webProcessIdentifier];
	}

	return 0;
}

+ (nullable NSString *)refreshRateForScreen:(NSScreen *)screen
{
	NSParameterAssert(screen != nil);

	CGFloat refreshRate = screen.screenRefreshRate;

	/* Only return a formatted refresh rate if not 60.
	 Everyone has 60. That's not interesting info. */
	/* Edited June 2024: Some displays are actually 59.
	 It annoyed me having this information displayed.
	 The values I picked below for excluding this information
	 were picked arbitrarily and do not reflect any real
	 world testing. */
//	if (fabs(refreshRate) == 60.0) {
	if (refreshRate > 58.5 && refreshRate < 61.5) {
		return nil;
	}

	return TPILocalizedString(@"BasicLanguage[zpt-sx]", refreshRate);
}

@end

#pragma mark -

@implementation TPI_SP_WebViewProcessInfo
@end

NS_ASSUME_NONNULL_END
