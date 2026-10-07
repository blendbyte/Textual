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

#import "TPISystemProfiler.h"
#import "TPI_SP_SysInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPISystemProfiler ()
@property (nonatomic, strong) NSView *preferencePaneView;
@end

@implementation TPISystemProfiler

#pragma mark -
#pragma mark Memory Allocation & Deallocation

/* Allocation & Deallocation */
- (void)pluginLoadedIntoMemory
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		NSDictionary *defaults = @{
			@"System Profiler Extension -> Feature Disabled -> GPU Model" : @(YES),
			@"System Profiler Extension -> Feature Disabled -> Disk Information" : @(YES),
			@"System Profiler Extension -> Feature Disabled -> System Uptime" : @(YES),
			@"System Profiler Extension -> Feature Disabled -> Memory Information" : @(YES),
			@"System Profiler Extension -> Feature Disabled -> Screen Resolution" : @(YES),
		};

		[RZUserDefaults() registerDefaults:defaults];

		[TPIBundleFromClass() loadNibNamed:@"TPISystemProfiler" owner:self topLevelObjects:nil];
	});
}

#pragma mark -
#pragma mark Preference Pane

/* Preference Pane */
- (NSView *)pluginPreferencesPaneView
{
	return self.preferencePaneView;
}

- (NSString *)pluginPreferencesPaneMenuItemName
{
	return TPILocalizedString(@"BasicLanguage[dff-13]");
}

#pragma mark -
#pragma mark User Input

- (NSArray *)subscribedUserInputCommands
{
	return @[@"sysinfo", @"memory", @"uptime", @"netstats", 
	@"msgcount", @"diskspace", @"style", @"screens",
	@"runcount", @"sysmem"];
}

- (void)printDebugInformation:(NSString *)message onClient:(IRCClient *)client inChannel:(IRCChannel *)channel
{
	NSArray *messages = [message componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	for (NSString *messageSplit in messages) {
		[client printDebugInformation:messageSplit inChannel:channel];
	}
}

- (void)sendMessage:(NSString *)message onClient:(IRCClient *)client toChannel:(IRCChannel *)channel
{
	NSArray *messages = [message componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	for (NSString *messageSplit in messages) {
		[client sendPrivmsg:messageSplit toChannel:channel];
	}
}

- (void)userInputCommandInvokedOnClient:(IRCClient *)client
						  commandString:(NSString *)commandString
						  messageString:(NSString *)messageString
{
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self _userInputCommandInvokedOnClient:client
								 commandString:commandString
								 messageString:messageString];
	});
}

- (void)_userInputCommandInvokedOnClient:(IRCClient *)client
						   commandString:(NSString *)commandString
						   messageString:(NSString *)messageString
{
	IRCChannel *channel = mainWindow().selectedChannel;

	if (channel == nil) {
		return;
	}

	BOOL quietMessage = [messageString isEqualIgnoringCase:@"quiet"];

	NSString *messageOut = nil;

	if ([commandString isEqualToString:@"SYSINFO"]) {
		messageOut = [TPI_SP_CompiledOutput systemInformation];
	} else if ([commandString isEqualToString:@"MEMORY"]) {
		NSString *memoryMessage = [TPI_SP_CompiledOutput applicationMemoryUsage];

		if (quietMessage) {
			[self printDebugInformation:memoryMessage onClient:client inChannel:channel];
		} else {
			[self sendMessage:memoryMessage onClient:client toChannel:channel];
		}

		NSString *webKitMemoryUse = [TPI_SP_CompiledOutput webKitFrameworkMemoryUsage];

		if (webKitMemoryUse) {
			[self printDebugInformation:webKitMemoryUse onClient:client inChannel:channel];
		}
	} else if ([commandString isEqualToString:@"UPTIME"]) {
		messageOut = [TPI_SP_CompiledOutput applicationAndSystemUptime];
	} else if ([commandString isEqualToString:@"NETSTATS"]) {
		messageOut = [TPI_SP_CompiledOutput systemNetworkInformation];
	} else if ([commandString isEqualToString:@"MSGCOUNT"]) {
		messageOut = [TPI_SP_CompiledOutput applicationBandwidthStatistics];
	} else if ([commandString isEqualToString:@"DISKSPACE"]) {
		messageOut = [TPI_SP_CompiledOutput systemDiskspaceInformation];
	} else if ([commandString isEqualToString:@"STYLE"]) {
		messageOut = [TPI_SP_CompiledOutput applicationActiveStyle];
	} else if ([commandString isEqualToString:@"SCREENS"]) {
		messageOut = [TPI_SP_CompiledOutput systemDisplayInformation];
	} else if ([commandString isEqualToString:@"RUNCOUNT"]) {
		messageOut = [TPI_SP_CompiledOutput applicationRuntimeStatistics];
	} else if ([commandString isEqualToString:@"SYSMEM"]) {
		messageOut = [TPI_SP_CompiledOutput systemMemoryInformation];
	}

	if (messageOut) {
		if (quietMessage) {
			[self printDebugInformation:messageOut onClient:client inChannel:channel];
		} else {
			[self sendMessage:messageOut onClient:client toChannel:channel];
		}
	}
}

@end

NS_ASSUME_NONNULL_END
