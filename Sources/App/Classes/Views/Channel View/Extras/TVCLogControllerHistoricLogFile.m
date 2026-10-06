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

#import "HLSHistoricLogProtocol.h"

#import "TXMasterController.h"
#import "IRCTreeItem.h"
#import "IRCWorld.h"
#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogLinePrivate.h"
#import "TVCLogLineXPCPrivate.h"
#import "TVCLogControllerHistoricLogFilePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogControllerHistoricLogFile ()
@property (nonatomic, assign, readwrite) BOOL isSaving;
@property (nonatomic, assign, readwrite) BOOL isTerminating;
@property (nonatomic, assign, readwrite) BOOL processLoaded;
@property (nonatomic, assign, readwrite) BOOL processLoading;
@property (nonatomic, strong) NSXPCConnection *serviceConnection;
@property (nonatomic, assign) BOOL connectionInvalidatedVoluntarily;
@property (nonatomic, assign) BOOL connectionInvalidatedErrorDialogDisplayed;
@property (nonatomic, copy, nullable) NSError *lastServiceConnectionError;
@end

@implementation TVCLogControllerHistoricLogFile

+ (TVCLogControllerHistoricLogFile *)sharedInstance
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedSelf = [[self alloc] init];
	});

	return sharedSelf;
}

#pragma mark -
#pragma mark Save Path

- (NSString *)databaseSavePath
{
	return [TPCPathInfo groupContainerApplicationCaches];
}

#pragma mark -
#pragma mark Construction

- (void)warmProcessIfNeeded
{
	if (self.processLoading || self.processLoaded) {
		return;
	}

	LogToConsoleDebug("Warming process...");

	self.processLoading = YES;

	[self connectToService];

	[self openDatabase];

	[self resetMaximumLineCount];
}

- (void)invalidateProcess
{
	if (self.processLoading == NO && self.processLoaded == NO) {
		return;
	}

	LogToConsoleDebug("Invalidating process...");

	self.connectionInvalidatedVoluntarily = YES;

	[self.serviceConnection invalidate];
}

- (void)openDatabase
{
	[[self remoteObjectProxyWithErrorHandler:^(NSError *error) {
		self.processLoading = NO;
		self.processLoaded = NO;

		LogToConsoleError("Failed to communicate with process to open database");
	}] openDatabaseInDirectory:[self databaseSavePath] withCompletionBlock:^(BOOL success) {
		if (success) {
			LogToConsoleDebug("Successfully opened database");
		} else {
			LogToConsoleError("Failed to open database");
		}

		self.processLoading = NO;
		self.processLoaded = success;
	}];
}

- (void)connectToService
{
	NSXPCConnection *serviceConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.textualapp.app.ScrollbackHistoryManager"];

	NSXPCInterface *remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HLSHistoricLogServerProtocol)];

	[remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [TVCLogLineXPC class], nil]
						  forSelector:@selector(fetchEntriesForView:ascending:fetchLimit:limitToDate:withCompletionBlock:)
						argumentIndex:0
							  ofReply:YES];

	[remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [TVCLogLineXPC class], nil]
						  forSelector:@selector(fetchEntriesForView:withUniqueIdentifier:beforeFetchLimit:afterFetchLimit:limitToDate:withCompletionBlock:)
						argumentIndex:0
							  ofReply:YES];

	[remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [TVCLogLineXPC class], nil]
						  forSelector:@selector(fetchEntriesForView:beforeUniqueIdentifier:fetchLimit:limitToDate:withCompletionBlock:)
						argumentIndex:0
							  ofReply:YES];

	[remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [TVCLogLineXPC class], nil]
						  forSelector:@selector(fetchEntriesForView:afterUniqueIdentifier:fetchLimit:limitToDate:withCompletionBlock:)
						argumentIndex:0
							  ofReply:YES];

	[remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [TVCLogLineXPC class], nil]
						  forSelector:@selector(fetchEntriesForView:afterUniqueIdentifier:beforeUniqueIdentifier:fetchLimit:withCompletionBlock:)
						argumentIndex:0
							  ofReply:YES];

	serviceConnection.remoteObjectInterface = remoteObjectInterface;

	NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HLSHistoricLogClientProtocol)];

	serviceConnection.exportedInterface = exportedInterface;

	serviceConnection.exportedObject = self;

	serviceConnection.interruptionHandler = ^{
		[self interruptionHandler];

		LogToConsole("Interruption handler called");
	};

	serviceConnection.invalidationHandler = ^{
		[self invalidationHandler];

		LogToConsole("Invalidation handler called");
	};

	[serviceConnection resume];

	self.serviceConnection = serviceConnection;
}

- (void)interruptionHandler
{
	[self invalidateProcess];
}

- (void)invalidationHandler
{
	self.serviceConnection = nil;

	[self resetContext];

	if (self.connectionInvalidatedVoluntarily) {
		self.connectionInvalidatedVoluntarily = NO;

		return;
	}

	/* Error dialog is purposely only ever shown once */
	if (self.connectionInvalidatedErrorDialogDisplayed == NO) {
		self.connectionInvalidatedErrorDialogDisplayed = YES;
	} else {
		return;
	}

	NSString *lastErrorMessage = self.lastServiceConnectionError.localizedDescription;

	if (lastErrorMessage == nil) {
		lastErrorMessage = @"";
	} else {
		lastErrorMessage = TXTLS(@"Prompts[nlz-um]", lastErrorMessage);
	}

	[TDCAlert alertWithMessage:lastErrorMessage
						 title:TXTLS(@"Prompts[h99-3q]")
				 defaultButton:TXTLS(@"Prompts[c7s-dq]")
			   alternateButton:nil];
}

- (void)resetContext
{
	self.isSaving = NO;

	self.processLoading = NO;
	self.processLoaded = NO;
}

- (void)resetMaximumLineCount
{
	NSUInteger maximumLineCount = [TPCPreferences scrollbackSaveLimit];

	[[self remoteObjectProxy] setMaximumLineCount:maximumLineCount];
}

- (void)prepareForApplicationTermination
{
	self.isTerminating = YES;

	[self saveData];
}

#pragma mark -
#pragma mark Private API

- (id <HLSHistoricLogServerProtocol>)remoteObjectProxy
{
	return [self remoteObjectProxyWithErrorHandler:nil];
}

- (id <HLSHistoricLogServerProtocol>)remoteObjectProxyWithErrorHandler:(void (^ _Nullable)(NSError *error))handler
{
	return [self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		self.lastServiceConnectionError = error;

		LogToConsoleError("Error occurred while communicating with service: %{public}@",
			error.localizedDescription);

		if (handler) {
			handler(error);
		}
	}];
}

#pragma mark -
#pragma mark Public API

- (NSArray<TVCLogLine *> *)_logLinesFromXPCObjects:(NSArray<TVCLogLineXPC *> *)xpcObjects
{
	NSParameterAssert(xpcObjects != nil);

	NSMutableArray *logLines = [NSMutableArray arrayWithCapacity:xpcObjects.count];

	for (TVCLogLineXPC *xpcObject in xpcObjects) {
		TVCLogLine *logLine = [TVCLogLine logLineFromXPCObject:xpcObject];

		if (logLine == nil) {
			LogToConsoleError("Failed to initialize object %{public}@. Corrupt data?", xpcObject.description);

			continue;
		}

		[logLines addObject:logLine];
	}

	return [logLines copy];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
				  ascending:(BOOL)ascending
				  fetchLimit:(NSUInteger)fetchLimit
				 limitToDate:(nullable NSDate *)limitToDate
		 withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self warmProcessIfNeeded];

	__weak typeof(self) weakSelf = self;

	[[self remoteObjectProxy] fetchEntriesForView:item.uniqueIdentifier
										ascending:ascending
									   fetchLimit:fetchLimit
									  limitToDate:limitToDate
							  withCompletionBlock:^(NSArray<TVCLogLineXPC *> *entries) {
								  NSArray *logLines = [weakSelf _logLinesFromXPCObjects:entries];

								  completionBlock(logLines);
							  }];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	   withUniqueIdentifier:(NSString *)uniqueId
		   beforeFetchLimit:(NSUInteger)fetchLimitBefore
			afterFetchLimit:(NSUInteger)fetchLimitAfter
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self warmProcessIfNeeded];

	__weak typeof(self) weakSelf = self;

	[[self remoteObjectProxy] fetchEntriesForView:item.uniqueIdentifier
							 withUniqueIdentifier:uniqueId
								 beforeFetchLimit:fetchLimitBefore
								  afterFetchLimit:fetchLimitAfter
									  limitToDate:limitToDate
							  withCompletionBlock:^(NSArray<TVCLogLineXPC *> *entries) {
								  NSArray *logLines = [weakSelf _logLinesFromXPCObjects:entries];

								  completionBlock(logLines);
							  }];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	 beforeUniqueIdentifier:(NSString *)uniqueId
				 fetchLimit:(NSUInteger)fetchLimit
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self warmProcessIfNeeded];

	__weak typeof(self) weakSelf = self;

	[[self remoteObjectProxy] fetchEntriesForView:item.uniqueIdentifier
						   beforeUniqueIdentifier:uniqueId
									   fetchLimit:fetchLimit
									  limitToDate:limitToDate
							  withCompletionBlock:^(NSArray<TVCLogLineXPC *> *entries) {
								  NSArray *logLines = [weakSelf _logLinesFromXPCObjects:entries];

								  completionBlock(logLines);
							  }];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	  afterUniqueIdentifier:(NSString *)uniqueId
				 fetchLimit:(NSUInteger)fetchLimit
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self warmProcessIfNeeded];

	__weak typeof(self) weakSelf = self;

	[[self remoteObjectProxy] fetchEntriesForView:item.uniqueIdentifier
						   afterUniqueIdentifier:uniqueId
									   fetchLimit:fetchLimit
									  limitToDate:limitToDate
							  withCompletionBlock:^(NSArray<TVCLogLineXPC *> *entries) {
								  NSArray *logLines = [weakSelf _logLinesFromXPCObjects:entries];

								  completionBlock(logLines);
							  }];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	  afterUniqueIdentifier:(NSString *)uniqueIdAfter
	 beforeUniqueIdentifier:(NSString *)uniqueIdBefore
				 fetchLimit:(NSUInteger)fetchLimit
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self warmProcessIfNeeded];

	__weak typeof(self) weakSelf = self;

	[[self remoteObjectProxy] fetchEntriesForView:item.uniqueIdentifier
							afterUniqueIdentifier:uniqueIdAfter
						   beforeUniqueIdentifier:uniqueIdBefore
									   fetchLimit:fetchLimit
							  withCompletionBlock:^(NSArray<TVCLogLineXPC *> *entries) {
								  NSArray *logLines = [weakSelf _logLinesFromXPCObjects:entries];

								  completionBlock(logLines);
							  }];
}

- (void)saveData
{
	if (self.isTerminating) {
		if (self.processLoaded == NO && self.processLoading == NO) {
			return;
		}
	}

	if (self.isSaving == NO) {
		self.isSaving = YES;
	} else {
		LogToConsoleDebug("Cancelled save because a save is already saving");

		return;
	}

	[self warmProcessIfNeeded];

	[[self remoteObjectProxy] saveDataWithCompletionBlock:^{
		self.isSaving = NO;

		if (self.isTerminating) {
			[self invalidateProcess];
		}
	}];
}

- (void)forgetItem:(IRCTreeItem *)item
{
	[self warmProcessIfNeeded];

	[[self remoteObjectProxy] forgetView:item.uniqueIdentifier];
}

- (void)resetDataForItem:(IRCTreeItem *)item
{
	[self warmProcessIfNeeded];

	[[self remoteObjectProxy] resetDataForView:item.uniqueIdentifier];
}

- (void)writeNewEntryWithLogLine:(TVCLogLine *)logLine forItem:(IRCTreeItem *)item
{
	[self warmProcessIfNeeded];

	TVCLogLineXPC *newEntry = [logLine xpcObjectForTreeItem:item];

	[[self remoteObjectProxy] writeLogLine:newEntry];
}

#pragma mark -
#pragma mark Private API (Client)

- (void)willDeleteUniqueIdentifiers:(NSArray<NSString *> *)uniqueIdentifiers
							 inView:(NSString *)viewId
{
	IRCTreeItem *item = [worldController() findItemWithId:viewId];

	if (item == nil) {
		return;
	}

	[item.viewController notifyHistoricLogWillDeleteLines:uniqueIdentifiers];
}

@end

NS_ASSUME_NONNULL_END
