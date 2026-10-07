/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "NSObjectHelperPrivate.h"
#import "TXGlobalModels.h"
#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TLOTimer.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesLocal.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "TVCLogLinePrivate.h"
#import "TLOFileLoggerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* How frequent to display alert for no disk space */
#define _noSpaceLeftOnDeviceAlertInterval		300 // 5 minutes

/* How long a file handle is allowed to be idle */
#define _fileHandleIdleLimit		1200 // 20 minutes

/* The frequency by which idle is checked for */
#define _idleTimerInterval			600 // 10 minutes

NSString * const TLOFileLoggerConsoleDirectoryName				= @"Console";
NSString * const TLOFileLoggerChannelDirectoryName				= @"Channels";
NSString * const TLOFileLoggerPrivateMessageDirectoryName		= @"Queries";

NSString * const TLOFileLoggerUndefinedNicknameFormat	= @"<%@%n>";
NSString * const TLOFileLoggerActionNicknameFormat		= @"\u2022 %n:";
NSString * const TLOFileLoggerNoticeNicknameFormat		= @"-%n-";

NSString * const TLOFileLoggerISOStandardClockFormat		= @"[%Y-%m-%dT%H:%M:%S%z]"; // 2008-07-09T16:13:30+12:00

NSString * const TLOFileLoggerIdleTimerNotification		= @"TLOFileLoggerIdleTimerNotification";

@interface TLOFileLogger ()
@property (nonatomic, weak) IRCClient *client;
@property (nonatomic, weak) IRCChannel *channel;
@property (nonatomic, strong, nullable) NSFileHandle *fileHandle;
@property (nonatomic, copy, readwrite, nullable) NSString *filePath;
@property (readonly, copy, readonly, nullable) NSString *filePathComputed;
@property (nonatomic, copy, nullable) NSDate *dateOpened;
@property (nonatomic, assign) NSTimeInterval lastWriteTime;
@property (readonly) BOOL fileHandleIdle;
@property (readonly, class) TLOTimer *idleTimer;
@end

static NSUInteger _numberOfOpenFileHandles = 0;

@implementation TLOFileLogger

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ((self = [super init])) {
		self.client = client;

		return self;
	}

	return nil;
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super init])) {
		self.client = channel.associatedClient;
		self.channel = channel;

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self close];
}

#pragma mark -
#pragma mark Plain Text API

- (void)writeLogLine:(TVCLogLine *)logLine
{
	NSParameterAssert(logLine != nil);

	NSString *stringToWrite = nil;

	if (self.channel) {
		stringToWrite = [logLine renderedBodyForTranscriptLogInChannel:self.channel];
	} else {
		stringToWrite = [logLine renderedBodyForTranscriptLog];
	}

	[self writePlainText:stringToWrite];
}

- (void)writePlainText:(NSString *)string
{
	NSParameterAssert(string != nil);

	[self reopenIfNeeded];

	if (self.fileHandle == nil) {
		LogToConsoleError("File handle is closed");

		return;
	}

	NSString *stringToWrite = [string stringByAppendingString:@"\n"];

	NSData *dataToWrite = [stringToWrite dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];

	if (dataToWrite) {
		@try {
			self.lastWriteTime = [NSDate timeIntervalSince1970];

			[self.fileHandle writeData:dataToWrite];
		}
		@catch (NSException *exception) {
			LogToConsoleError("Caught exception: %{public}@", exception.reason);
			LogStackTrace();

			if ([exception.reason contains:@"No space left on device"]) {
				[self failWithNoSpaceLeftOnDevice];
			}

			[self close];
		} // @catch
	}
}

#pragma mark -
#pragma mark File Handle Management

- (void)failWithNoSpaceLeftOnDevice
{
	static BOOL alertVisible = NO;

	if (alertVisible) {
		return;
	}

	static NSTimeInterval lastFailTime = 0;

	NSTimeInterval currentTime = [NSDate timeIntervalSince1970];

	if (lastFailTime > 0) {
		if ((currentTime - lastFailTime) < _noSpaceLeftOnDeviceAlertInterval) {
			return;
		}
	}

	lastFailTime = currentTime;

	alertVisible = YES;

	/* Present alert as non-blocking because there is no need for it to disrupt UI */
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[v9e-jy]")
						 title:TXTLS(@"Prompts[bi7-ah]")
				 defaultButton:TXTLS(@"Prompts[c7s-dq]")
			   alternateButton:nil
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
				   alertVisible = NO;
			   }];
}

- (void)reset
{
	if (self.fileHandle == nil) {
		return;
	}

	[self.fileHandle truncateFileAtOffset:0];
}

- (void)close
{
	if (self.fileHandle == nil) {
		return;
	}

	@try {
		[self.fileHandle synchronizeFile];
	}
	@catch (NSException *exception) {
		LogToConsoleError("Caught exception: %{public}@", exception.reason);
		LogStackTrace();
	}

	[self.fileHandle closeFile];

	self.fileHandle = nil;

	self.filePath = nil;

	self.lastWriteTime = 0;

	self.dateOpened = nil;

	[self removeIdleTimerObserver];
}

- (void)reopenIfNeeded
{
	/* Implementation discussion: we already have a notification called
	IRCWorldDateHasChangedNotification that is fired by IRCWorld when
	the user changes the date of the system or after time has naturally
	reached midnight. Do we rely on this? I chose not to and here is why:
	Race conditions. There is no guarantee we will receive notification
	on time to beat the current write. Of which there can be multiple. */
	if (self.fileHandle != nil && [self.dateOpened isInSameDayAsDate:[NSDate date]]) {
		return;
	}

	[self reopen];
}

- (void)reopen
{
	[self close];

	[self open];
}

- (void)open
{
	if (self.fileHandle != nil) {
		LogToConsoleError("Tried to open log file when a file handle already exists");

		return;
	}

	if ([self buildFilePath] == NO) {
		return;
	}

	NSString *filePath = self.filePath;

	NSString *writePath = self.writePath;

	if ([RZFileManager() fileExistsAtPath:writePath] == NO) {
		NSError *createDirectoryError = nil;

		if ([RZFileManager() createDirectoryAtPath:writePath withIntermediateDirectories:YES attributes:nil error:&createDirectoryError] == NO) {
			LogToConsoleError("Error Creating Folder: %{public}@",
				 createDirectoryError.localizedDescription);

			return;
		}
	}

	if ([RZFileManager() fileExistsAtPath:filePath] == NO) {
		NSError *writeFileError = nil;

		if ([@"" writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:&writeFileError] == NO) {
			LogToConsoleError("Error Creating File: %{public}@",
				  writeFileError.localizedDescription);

			return;
		}
	}

	NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];

	if (fileHandle == nil) {
		LogToConsoleError("Failed to open file handle at path '%{public}@'", filePath.standardizedTildePath);

		return;
	}

	[fileHandle seekToEndOfFile];

	self.fileHandle = fileHandle;

	self.dateOpened = [NSDate date];

	[self addIdleTimerObserver];
}

#pragma mark -
#pragma mark Idle Timer

- (BOOL)fileHandleIdle
{
	NSTimeInterval lastWriteTime = self.lastWriteTime;

	NSTimeInterval currentTime = [NSDate timeIntervalSince1970];

	if (lastWriteTime > 0) {
		if ((currentTime - lastWriteTime) > _fileHandleIdleLimit) {
			return YES;
		}
	}

	return NO;
}

+ (TLOTimer *)idleTimer
{
	static TLOTimer *idleTimer = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		idleTimer = [TLOTimer timerWithActionBlock:^(TLOTimer *sender) {
			[self idleTimerFired];
		} onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
	});

	return idleTimer;
}

+ (void)idleTimerFired
{
	if (_numberOfOpenFileHandles == 0) {
		[self stopIdleTimer];

		return;
	}

	[RZNotificationCenter() postNotificationName:TLOFileLoggerIdleTimerNotification object:nil];
}

+ (void)startIdleTimer
{
	TLOTimer *idleTimer = self.idleTimer;

	if (idleTimer.timerIsActive) {
		return;
	}

	[idleTimer start:_idleTimerInterval onRepeat:YES];
}

+ (void)stopIdleTimer
{
	TLOTimer *idleTimer = self.idleTimer;

	if (idleTimer.timerIsActive == NO) {
		return;
	}

	[idleTimer stop];
}

- (void)idleTimerFired:(NSNotification *)notification
{
	if (self.fileHandleIdle == NO) {
		return;
	}

	LogToConsoleDebug("Closing %{public}@ because it's idle", self);

	[self close];
}

- (void)updateIdleTimer
{
	if (_numberOfOpenFileHandles == 0) {
		[self.class stopIdleTimer];
	} else {
		[self.class startIdleTimer];
	}
}

- (void)addIdleTimerObserver
{
	_numberOfOpenFileHandles += 1;

	[RZNotificationCenter() addObserver:self selector:@selector(idleTimerFired:) name:TLOFileLoggerIdleTimerNotification object:nil];

	[self updateIdleTimer];
}

- (void)removeIdleTimerObserver
{
	_numberOfOpenFileHandles -= 1;

	[RZNotificationCenter() removeObserver:self name:TLOFileLoggerIdleTimerNotification object:nil];

	[self updateIdleTimer];
}

#pragma mark -
#pragma mark Paths

- (nullable NSString *)writePath
{
	return self.filePath.stringByDeletingLastPathComponent;
}

- (nullable NSString *)fileName
{
	return self.filePath.lastPathComponent;
}

+ (nullable NSString *)writePathForItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	NSString *sourcePath = [TPCPathInfo transcriptFolder];

	if (sourcePath == nil) {
		return nil;
	}

	return [self writePathForItem:item relativeTo:sourcePath];
}

+ (nullable NSString *)writePathForItem:(IRCTreeItem *)item relativeTo:(NSString *)sourcePath
{
	NSParameterAssert(sourcePath != nil);
	NSParameterAssert(item != nil);

	IRCChannel *channel = item.associatedChannel;

	if (channel && channel.isUtility) {
		return nil;
	}
	
	IRCClient *client = item.associatedClient;

	NSString *clientIdentifier = [client.uniqueIdentifier substringToIndex:5];
	
	NSString *clientName = [NSString stringWithFormat:@"%@ (%@)", client.name, clientIdentifier];

	NSString *basePath = nil;
	
	if (channel == nil) {
		basePath = [NSString stringWithFormat:@"/%@/%@/", clientName.safeFilename, TLOFileLoggerConsoleDirectoryName];
	} else if (channel.isChannel) {
		basePath = [NSString stringWithFormat:@"/%@/%@/%@/", clientName.safeFilename, TLOFileLoggerChannelDirectoryName, channel.name.safeFilename];
	} else if (channel.isPrivateMessage) {
		basePath = [NSString stringWithFormat:@"/%@/%@/%@/", clientName.safeFilename, TLOFileLoggerPrivateMessageDirectoryName, channel.name.safeFilename];
	}
	
	return [sourcePath stringByAppendingPathComponent:basePath];
}

- (nullable NSString *)writePathRelativeTo:(NSString *)sourcePath
{
	NSParameterAssert(sourcePath != nil);

	IRCClient *client = self.client;
	IRCChannel *channel = self.channel;

	IRCTreeItem *item = ((channel) ?: client);

	return [self.class writePathForItem:item relativeTo:sourcePath];
}

- (BOOL)buildFilePath
{
	NSString *sourcePath = [TPCPathInfo transcriptFolder];

	if (sourcePath == nil) {
		return NO;
	}

	NSString *writePath = [self writePathRelativeTo:sourcePath];

	if (writePath == nil) {
		return NO;
	}

	NSString *dateTime = TXFormattedTimestamp([NSDate date], @"%Y-%m-%d");

	NSString *fileName = [NSString stringWithFormat:@"%@.txt", dateTime];

	NSString *filePath = [writePath stringByAppendingPathComponent:fileName];

	self.filePath = filePath;

	return YES;
}

@end

NS_ASSUME_NONNULL_END
