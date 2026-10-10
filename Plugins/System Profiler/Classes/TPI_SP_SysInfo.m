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


#import "TPI_SP_SysInfo.h"

NS_ASSUME_NONNULL_BEGIN

#define _localVolumeBaseDirectory		@"/Volumes"

@interface TPI_SP_SysInfo : NSObject
+ (nullable NSString *)modelIdentifier;
+ (nullable NSString *)productName;

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
+ (NSString *)formattedMemorySize:(uint64_t)memorySize;
+ (NSString *)formattedCPUFrequency:(double)frequency;

+ (NSString *)descriptionForSidebarAppearance;
+ (NSString *)descriptionForThemeAppearance;
+ (NSString *)descriptionForThemeAppearance:(TPCThemeAppearanceType)appearance;

+ (uint64_t)memoryUseForProcess:(pid_t)processIdentifier;


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
		} else if ((modelTitle = [TPI_SP_SysInfo productName])) {
			/* Apple silicon names itself ("MacBook Air (M2, 2022)"): the
			 model list stays for Intel Macs and virtual machines */
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

	if (totalMemory == 0) {
		return TPILocalizedString(@"BasicLanguage[li1-vn]");
	}

	/* Never more than the total: the bar below draws (10 - used) segments
	 as an unsigned count, which wrapped around and drew for ever */
	freeMemory = MIN(freeMemory, totalMemory);

	uint64_t usedMemory = (totalMemory - freeMemory);

	long double memoryUsedPercent = (((long double)usedMemory / (long double)totalMemory) * 100.0);

	NSMutableString *resultString = [NSMutableString string];

	/* ======================================== */

	[resultString appendFormat:@"%c04", 0x03];

	NSUInteger leftCount = MIN((NSUInteger)(memoryUsedPercent / 10), (NSUInteger)10);

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
			[TPI_SP_SysInfo formattedMemorySize:freeMemory],
			[TPI_SP_SysInfo formattedMemorySize:usedMemory],
			[TPI_SP_SysInfo formattedMemorySize:totalMemory],
					resultString);
}

+ (NSString *)systemNetworkInformation
{
	/* The routing table's 64-bit counters, as top does (the counters
	 getifaddrs gives are 32-bit and wrapped every 4 GB; an interface
	 without an address crashed) */
	NSMutableString *resultString = [NSMutableString string];

	int mib[6] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};

	size_t bufferLength = 0;

	if (sysctl(mib, 6, NULL, &bufferLength, NULL, 0) != 0 || bufferLength == 0) {
		return TPILocalizedString(@"BasicLanguage[li1-vn]");
	}

	NSMutableData *buffer = [NSMutableData dataWithLength:bufferLength];

	if (sysctl(mib, 6, buffer.mutableBytes, &bufferLength, NULL, 0) != 0) {
		return TPILocalizedString(@"BasicLanguage[li1-vn]");
	}

	NSUInteger objectIndex = 0;

	char *bufferStart = buffer.mutableBytes;
	char *bufferEnd = (bufferStart + bufferLength);

	for (char *next = bufferStart; next < bufferEnd; ) {
		struct if_msghdr *message = (struct if_msghdr *)next;

		if (message->ifm_msglen == 0) {
			break;
		}

		next += message->ifm_msglen;

		if (message->ifm_type != RTM_IFINFO2) {
			continue;
		}

		struct if_msghdr2 *interfaceMessage = (struct if_msghdr2 *)message;

		/* Up and running, not loopback */
		if ((interfaceMessage->ifm_flags & IFF_UP) == 0 ||
			(interfaceMessage->ifm_flags & IFF_RUNNING) == 0 ||
			(interfaceMessage->ifm_flags & IFF_LOOPBACK) != 0)
		{
			continue;
		}

		struct sockaddr_dl *linkAddress = (struct sockaddr_dl *)(interfaceMessage + 1);

		NSString *interfaceName = [[NSString alloc] initWithBytes:linkAddress->sdl_data length:linkAddress->sdl_nlen encoding:NSASCIIStringEncoding];

		uint64_t bytesIn = interfaceMessage->ifm_data.ifi_ibytes;
		uint64_t bytesOut = interfaceMessage->ifm_data.ifi_obytes;

		if (interfaceName.length == 0 || bytesIn < 20000000 || bytesOut < 2000000) {
			continue;
		}

		if (objectIndex == 0) {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[ca4-25]",
										 interfaceName,
										 [TPI_SP_SysInfo formattedDiskSize:bytesIn],
										 [TPI_SP_SysInfo formattedDiskSize:bytesOut])];
		} else {
			[resultString appendString:TPILocalizedString(@"BasicLanguage[mjo-o0]",
										 interfaceName,
										 [TPI_SP_SysInfo formattedDiskSize:bytesIn],
										 [TPI_SP_SysInfo formattedDiskSize:bytesOut])];
		}

		objectIndex += 1;
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

/* Memory in binary units, as Activity Monitor shows it (16 GB of RAM is
 17.18 GB in the decimal units used for disks; the total was divided to
 hide that, while free memory wasn't, so "used" mixed both) */
+ (NSString *)formattedMemorySize:(uint64_t)memorySize
{
	return [NSByteCountFormatter stringFromByteCount:(long long)memorySize countStyle:NSByteCountFormatterCountStyleMemory];
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
	return [self formattedMemorySize:[self totalMemorySize]];
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

+ (NSArray<NSString *> *)graphicsCardModelsOfClass:(const char *)className requiringDisplayClassCode:(BOOL)requireClassCode
{
	io_iterator_t entryIterator = IO_OBJECT_NULL;

	if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &entryIterator) != kIOReturnSuccess) {
		return @[];
	}

	NSMutableArray<NSString *> *models = [NSMutableArray array];

	io_object_t serviceObject;

	while ((serviceObject = IOIteratorNext(entryIterator))) {
		CFMutableDictionaryRef serviceDictionary = NULL;

		kern_return_t status =
		IORegistryEntryCreateCFProperties(serviceObject,
										  &serviceDictionary,
										  kCFAllocatorDefault,
										  kNilOptions);

		IOObjectRelease(serviceObject);

		if (status != kIOReturnSuccess || serviceDictionary == NULL) {
			continue;
		}

		NSDictionary *properties = (__bridge_transfer NSDictionary *)serviceDictionary;

		/* Display controllers (class code 0x03xxxx); a missing class code
		 crashed (the type check had lost its "else") */
		if (requireClassCode) {
			id classCode = properties[@"class-code"];

			if ([classCode isKindOfClass:[NSData class]] == NO || [classCode length] < sizeof(UInt32)) {
				continue;
			}

			UInt32 classCodeValue = 0;

			[classCode getBytes:&classCodeValue length:sizeof(classCodeValue)];

			if (classCodeValue != 0x30000) {
				continue;
			}
		}

		/* Data on PCI devices, a string on Apple silicon */
		id model = properties[@"model"];

		NSString *modelString = nil;

		if ([model isKindOfClass:[NSData class]]) {
			modelString = [[NSString alloc] initWithData:model encoding:NSASCIIStringEncoding];
		} else if ([model isKindOfClass:[NSString class]]) {
			modelString = model;
		}

		modelString = [modelString stringByReplacingOccurrencesOfString:@"\0" withString:@""].trim;

		if (modelString.length > 0 && [models containsObject:modelString] == NO) {
			[models addObject:modelString];
		}
	}

	IOObjectRelease(entryIterator);

	return [models copy];
}

/* PCI graphics cards (Intel Macs), else the GPU's IORegistry entry (Apple
 silicon has no PCI graphics device) */
+ (nullable NSString *)formattedGraphicsCardInformation
{
	NSMutableArray<NSString *> *gpuModels = [NSMutableArray new];

	[gpuModels addObjectsFromArray:[self graphicsCardModelsOfClass:"IOPCIDevice" requiringDisplayClassCode:YES]];

	if (gpuModels.count == 0) {
		[gpuModels addObjectsFromArray:[self graphicsCardModelsOfClass:"IOAccelerator" requiringDisplayClassCode:NO]];
	}

	if (gpuModels.count == 0) {
		return nil;
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

/* The marketing name Apple silicon Macs keep in the device tree */
+ (nullable NSString *)productName
{
	io_registry_entry_t productEntry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product");

	if (productEntry == IO_OBJECT_NULL) {
		return nil;
	}

	CFTypeRef property = IORegistryEntryCreateCFProperty(productEntry, CFSTR("product-name"), kCFAllocatorDefault, kNilOptions);

	IOObjectRelease(productEntry);

	id value = CFBridgingRelease(property);

	NSString *name = nil;

	if ([value isKindOfClass:[NSData class]]) {
		name = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
	} else if ([value isKindOfClass:[NSString class]]) {
		name = value;
	}

	name = [name stringByReplacingOccurrencesOfString:@"\0" withString:@""].trim;

	return ((name.length > 0) ? name : nil);
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

/* Total minus what is in use the way Activity Monitor counts it (app memory,
 wired and compressed), from the 64-bit statistics */
+ (uint64_t)freeMemorySize
{
	vm_size_t pageSize = 0;

	if (host_page_size(mach_host_self(), &pageSize) != KERN_SUCCESS) {
		return 0;
	}

	vm_statistics64_data_t statistics;

	mach_msg_type_number_t statisticsCount = HOST_VM_INFO64_COUNT;

	if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&statistics, &statisticsCount) != KERN_SUCCESS) {
		return 0;
	}

	uint64_t usedPages = ((uint64_t)statistics.internal_page_count - statistics.purgeable_count) + statistics.wire_count + statistics.compressor_page_count;

	uint64_t usedMemory = (usedPages * pageSize);

	uint64_t totalMemory = [self totalMemorySize];

	if (usedMemory >= totalMemory) {
		return 0;
	}

	return (totalMemory - usedMemory);
}

+ (uint64_t)totalMemorySize
{
	uint64_t memoryTotal = 0L;

	size_t memoryTotalSize = sizeof(memoryTotal);

	if (sysctlbyname("hw.memsize", &memoryTotal, &memoryTotalSize, NULL, 0) != 0) {
		return 0;
	}

	return memoryTotal;
}

+ (uint64_t)applicationMemoryInformation
{
	pid_t processIdentifier = (pid_t)[NSProcessInfo processInfo].processIdentifier;

	return [TPI_SP_SysInfo memoryUseForProcess:processIdentifier];
}

/* The memory footprint Activity Monitor shows. The region walk it replaces
 used the result of a failed lookup and counted the last region twice. */
+ (uint64_t)memoryUseForProcess:(pid_t)processIdentifier
{
	if (processIdentifier == 0) {
		return 0;
	}

	struct rusage_info_v4 usage;

	if (proc_pid_rusage(processIdentifier, RUSAGE_INFO_V4, (rusage_info_t *)&usage) != 0) {
		return 0;
	}

	return usage.ri_phys_footprint;
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

NS_ASSUME_NONNULL_END
