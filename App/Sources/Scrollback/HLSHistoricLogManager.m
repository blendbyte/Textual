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

#import <CoreData/CoreData.h>

#import "TXMasterController.h"
#import "IRCTreeItem.h"
#import "IRCWorld.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogLinePrivate.h"
#import "HLSHistoricLogManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Lines are saved to disk every two minutes (and at termination) */
#define _saveInterval				(2 * 60)

/* A view is trimmed to the scrollback limit at a random time in the
 30 minutes after it exceeds it, so views don't all trim at once */
#define _resizeIntervalMaximum		(30 * 60)

/* Upper bound for fetches that don't ask for a limit */
#define _fetchLimitCap				10000

#define _storeFilename				@"Historic Log.sqlite"
#define _importedStoreFilename		@"Historic Log (Imported).sqlite"

typedef NS_ENUM(NSUInteger, HLSHistoricLogFetchDirection)
{
	HLSHistoricLogFetchDirectionBefore,
	HLSHistoricLogFetchDirectionAfter
};

/* One child context per view, with the view's line count and newest
 entry identifier cached. Only touched on its own queue. */
@interface HLSHistoricLogViewContext : NSManagedObjectContext
@property (nonatomic, copy) NSString *hls_viewId;
@property (nonatomic, assign) NSUInteger hls_totalLineCount;
@property (nonatomic, assign) NSUInteger hls_newestIdentifier;
@property (nonatomic, strong, nullable) dispatch_source_t hls_resizeTimer;
@end

@implementation HLSHistoricLogViewContext
@end

@interface HLSHistoricLogManager ()
@property (atomic, assign, readwrite) BOOL isSaving;
@property (nonatomic, strong) dispatch_queue_t queue;
/* The properties below are only used on -queue */
@property (nonatomic, strong, nullable) NSManagedObjectContext *managedObjectContext; // nil if the store failed to open
@property (nonatomic, strong, nullable) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HLSHistoricLogViewContext *> *contextObjects;
@property (nonatomic, assign) NSUInteger maximumLineCount;
@property (nonatomic, strong, nullable) dispatch_source_t saveTimer;
@end

@implementation HLSHistoricLogManager

+ (HLSHistoricLogManager *)sharedInstance
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedSelf = [[self alloc] init];
	});

	return sharedSelf;
}

- (instancetype)init
{
	if ((self = [super init])) {
		self.queue = dispatch_queue_create("com.textualapp.historic-log", DISPATCH_QUEUE_SERIAL);

		self.contextObjects = [NSMutableDictionary dictionary];

		self.maximumLineCount = MAX([TPCPreferences scrollbackSaveLimit], 1);

		/* First on the queue: everything else waits for the store */
		dispatch_async(self.queue, ^{
			[self _openDatabase];
		});

		return self;
	}

	return nil;
}

#pragma mark -
#pragma mark Store

- (nullable NSURL *)_storeURL
{
	NSString *directory = [TPCPathInfo applicationSupport];

	if (directory == nil) {
		return nil;
	}

	return [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:_storeFilename]];
}

+ (nullable NSURL *)importedStoreURL
{
	NSString *directory = [TPCPathInfo applicationSupport];

	if (directory == nil) {
		return nil;
	}

	return [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:_importedStoreFilename]];
}

+ (NSArray<NSString *> *)_storeFileSuffixes
{
	return @[@"", @"-wal", @"-shm"];
}

/* An import can't replace the store while it is open, so it leaves the
 imported files next to it and they take its place here */
- (void)_replaceStoreWithImportedStoreAtURL:(NSURL *)storeURL
{
	NSParameterAssert(storeURL != nil);

	NSURL *importedStoreURL = [self.class importedStoreURL];

	if (importedStoreURL == nil || [RZFileManager() fileExistsAtURL:importedStoreURL] == NO) {
		return;
	}

	[self _destroyStoreAtURL:storeURL];

	for (NSString *suffix in [self.class _storeFileSuffixes]) {
		NSString *source = [importedStoreURL.path stringByAppendingString:suffix];

		if ([RZFileManager() fileExistsAtPath:source] == NO) {
			continue;
		}

		NSError *moveError = nil;

		if ([RZFileManager() moveItemAtPath:source toPath:[storeURL.path stringByAppendingString:suffix] error:&moveError] == NO) {
			LogToConsoleError("Failed to use the imported historic log: %{public}@", moveError.localizedDescription);
		}
	}

	LogToConsole("Replaced the historic log with the imported one");
}

- (void)_destroyStoreAtURL:(NSURL *)storeURL
{
	NSParameterAssert(storeURL != nil);

	for (NSString *suffix in [self.class _storeFileSuffixes]) {
		[RZFileManager() removeItemAtPath:[storeURL.path stringByAppendingString:suffix] error:NULL];
	}
}

- (void)_openDatabase
{
	NSURL *storeURL = [self _storeURL];

	if (storeURL == nil) {
		LogToConsoleError("No folder for the historic log");

		return;
	}

	[self _replaceStoreWithImportedStoreAtURL:storeURL];

	NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"HistoricLogFileStorageModel" withExtension:@"momd"];

	NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

	if (managedObjectModel == nil) {
		LogToConsoleFault("The historic log data model is missing");

		return;
	}

	NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];

	NSDictionary *persistentStoreOptions = @{
		NSMigratePersistentStoresAutomaticallyOption : @(YES),
		NSInferMappingModelAutomaticallyOption : @(YES),
		NSSQLitePragmasOption : @{
			@"synchronous" : @"NORMAL",
			@"journal_mode" : @"WAL"
		}
	};

	LogToConsole("Opening the historic log at %{public}@", storeURL.path.standardizedTildePath);

	for (NSUInteger attempt = 0; attempt < 2; attempt++) {
		NSError *addPersistentStoreError = nil;

		NSPersistentStore *persistentStore =
		[persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
												 configuration:nil
														   URL:storeURL
													   options:persistentStoreOptions
														 error:&addPersistentStoreError];

		if (persistentStore) {
			NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];

			managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator;

			managedObjectContext.undoManager = nil;

			self.managedObjectContext = managedObjectContext;
			self.managedObjectModel = managedObjectModel;

			[self _scheduleSaveTimer];

			return;
		}

		LogToConsoleError("Failed to open the historic log: %{public}@", addPersistentStoreError.localizedDescription);

		/* A store that can't be opened or migrated (damaged, or from a very
		 old version) is replaced by an empty one: it only holds scrollback */
		if (attempt == 0) {
			[self _destroyStoreAtURL:storeURL];
		}
	}
}

#pragma mark -
#pragma mark Fetch Requests

- (NSFetchRequest *)_fetchRequestForView:(NSString *)viewId
							   ascending:(BOOL)ascending
							  fetchLimit:(NSUInteger)fetchLimit
				   lowestEntryIdentifier:(NSInteger)lowestEntryIdentifier
				  highestEntryIdentifier:(NSInteger)highestEntryIdentifier
							 limitToDate:(nullable NSDate *)limitToDate
{
	NSParameterAssert(viewId != nil);

	if (limitToDate == nil) {
		limitToDate = [NSDate distantFuture];
	}

	NSDictionary *substitutionVariables = @{
		@"view_id" : viewId,
		@"entry_id_lowest" : @(lowestEntryIdentifier),
		@"entry_id_highest" : @(highestEntryIdentifier),
		@"creation_date" : @([limitToDate timeIntervalSince1970])
	};

	NSFetchRequest *fetchRequest =
	[self.managedObjectModel fetchRequestFromTemplateWithName:@"GenericConditional"
										substitutionVariables:substitutionVariables];

	if (fetchLimit == 0 || fetchLimit > _fetchLimitCap) {
		fetchLimit = _fetchLimitCap;
	}

	fetchRequest.fetchLimit = fetchLimit;

	fetchRequest.includesPendingChanges = YES;
	fetchRequest.returnsObjectsAsFaults = NO;

	fetchRequest.resultType = NSManagedObjectResultType;

	/* Entry identifiers are the order lines were written in; creation
	 dates can repeat and run backwards when the clock changes */
	fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"entryIdentifier" ascending:ascending]];

	return fetchRequest;
}

- (NSFetchRequest *)_fetchRequestForView:(NSString *)viewId
							   ascending:(BOOL)ascending
							  fetchLimit:(NSUInteger)fetchLimit
							 limitToDate:(nullable NSDate *)limitToDate
{
	return [self _fetchRequestForView:viewId
							ascending:ascending
						   fetchLimit:fetchLimit
				lowestEntryIdentifier:0
			   highestEntryIdentifier:NSIntegerMax
						  limitToDate:limitToDate];
}

/* Fetches on the view context's queue and completes on a background queue,
 with an empty array on every failure */
- (void)_fetchInViewContext:(HLSHistoricLogViewContext *)viewContext
			   fetchRequest:(NSFetchRequest *)fetchRequest
			completionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	NSParameterAssert(viewContext != nil);
	NSParameterAssert(fetchRequest != nil);
	NSParameterAssert(completionBlock != nil);

	__block NSArray<NSDictionary *> *records = @[];

	[viewContext performBlockAndWait:^{
		NSError *fetchRequestError = nil;

		NSArray<NSManagedObject *> *fetchedObjects = [viewContext executeFetchRequest:fetchRequest error:&fetchRequestError];

		if (fetchedObjects == nil) {
			LogToConsoleError("Failed to fetch from the historic log: %{public}@", fetchRequestError.localizedDescription);

			return;
		}

		/* Copy the values out: managed objects stay on their context's queue */
		NSMutableArray<NSDictionary *> *recordsMutable = [NSMutableArray arrayWithCapacity:fetchedObjects.count];

		for (NSManagedObject *object in fetchedObjects) {
			NSData *data = [object valueForKey:@"logLineData"];

			if (data == nil) {
				continue;
			}

			NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:2];

			record[@"data"] = data;

			[record maybeSetObject:[object valueForKey:@"logLineUniqueIdentifier"] forKey:@"uniqueIdentifier"];

			[recordsMutable addObject:record];
		}

		/* No -reset here: it would drop lines written since the last save */
		records = [recordsMutable copy];
	}];

	XRPerformBlockAsynchronouslyOnGlobalQueue(^{
		NSMutableArray<TVCLogLine *> *entries = [NSMutableArray arrayWithCapacity:records.count];

		for (NSDictionary *record in records) {
			TVCLogLine *logLine = [TVCLogLine logLineWithData:record[@"data"] uniqueIdentifier:record[@"uniqueIdentifier"]];

			if (logLine == nil) {
				LogToConsoleError("Skipped a historic log line that can't be read");

				continue;
			}

			[entries addObject:logLine];
		}

		completionBlock([entries copy]);
	});
}

/* The entry identifier of the line with this unique identifier, or NSNotFound.
 Call on the view context's queue. */
- (NSInteger)_entryIdentifierInViewContext:(HLSHistoricLogViewContext *)viewContext forUniqueIdentifier:(NSString *)uniqueIdentifier
{
	NSParameterAssert(viewContext != nil);
	NSParameterAssert(uniqueIdentifier != nil);

	NSFetchRequest *fetchRequest =
	[self.managedObjectModel fetchRequestFromTemplateWithName:@"UniqueIdToEntryId"
										substitutionVariables:@{
											@"view_id" : viewContext.hls_viewId,
											@"unique_id" : uniqueIdentifier
										}];

	fetchRequest.includesPendingChanges = YES;

	/* Without the archived line */
	fetchRequest.propertiesToFetch = @[@"entryIdentifier"];

	NSError *fetchRequestError = nil;

	NSArray<NSManagedObject *> *fetchedObjects = [viewContext executeFetchRequest:fetchRequest error:&fetchRequestError];

	if (fetchedObjects == nil) {
		LogToConsoleError("Failed to look up a historic log line: %{public}@", fetchRequestError.localizedDescription);

		return NSNotFound;
	}

	NSNumber *entryIdentifier = [fetchedObjects.firstObject valueForKey:@"entryIdentifier"];

	if (entryIdentifier == nil) {
		return NSNotFound;
	}

	return entryIdentifier.integerValue;
}

#pragma mark -
#pragma mark View Contexts

/* Call on -queue */
- (nullable HLSHistoricLogViewContext *)_contextForView:(NSString *)viewId
{
	NSParameterAssert(viewId != nil);

	NSManagedObjectContext *parentContext = self.managedObjectContext;

	if (parentContext == nil) {
		return nil;
	}

	HLSHistoricLogViewContext *viewContext = self.contextObjects[viewId];

	if (viewContext) {
		return viewContext;
	}

	viewContext = [[HLSHistoricLogViewContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];

	viewContext.parentContext = parentContext;

	viewContext.undoManager = nil;

	viewContext.hls_viewId = viewId;

	[viewContext performBlockAndWait:^{
		/* Line count */
		NSFetchRequest *countRequest = [self _fetchRequestForView:viewId ascending:YES fetchLimit:0 limitToDate:nil];

		countRequest.fetchLimit = 0;

		countRequest.resultType = NSCountResultType;

		NSError *countError = nil;

		NSUInteger lineCount = [viewContext countForFetchRequest:countRequest error:&countError];

		if (lineCount == NSNotFound) {
			LogToConsoleError("Failed to count historic log lines: %{public}@", countError.localizedDescription);

			lineCount = 0;
		}

		viewContext.hls_totalLineCount = lineCount;

		/* Newest entry identifier */
		NSFetchRequest *newestRequest = [self _fetchRequestForView:viewId ascending:NO fetchLimit:1 limitToDate:nil];

		newestRequest.propertiesToFetch = @[@"entryIdentifier"];

		newestRequest.returnsObjectsAsFaults = YES;

		NSArray<NSManagedObject *> *newestObjects = [viewContext executeFetchRequest:newestRequest error:NULL];

		viewContext.hls_newestIdentifier = [[newestObjects.firstObject valueForKey:@"entryIdentifier"] unsignedIntegerValue];

		[viewContext reset];
	}];

	LogToConsoleDebug("Context created for %{public}@ - Line count: %{public}lu, Newest identifier: %{public}lu",
		viewId, viewContext.hls_totalLineCount, viewContext.hls_newestIdentifier);

	self.contextObjects[viewId] = viewContext;

	return viewContext;
}

#pragma mark -
#pragma mark Saving

- (void)_scheduleSaveTimer
{
	if (self.saveTimer) {
		XRCancelScheduledBlock(self.saveTimer);
	}

	dispatch_source_t saveTimer =
	XRScheduleBlockOnQueue(self.queue, ^{
		[self _saveData];
	}, _saveInterval, YES);

	XRResumeScheduledBlock(saveTimer);

	self.saveTimer = saveTimer;
}

/* Call on the context's queue */
- (void)_saveContext:(NSManagedObjectContext *)context
{
	NSParameterAssert(context != nil);

	if (context.hasChanges) {
		NSError *saveError = nil;

		if ([context save:&saveError] == NO) {
			LogToConsoleError("Failed to save the historic log: %{public}@", saveError.localizedDescription);
		}
	}

	[context reset];
}

/* Call on -queue. Saves each view context into the parent on the view's
 own queue, then the parent to disk on its queue. */
- (void)_saveData
{
	NSManagedObjectContext *parentContext = self.managedObjectContext;

	if (parentContext == nil) {
		return;
	}

	LogToConsoleDebug("Saving the historic log");

	for (HLSHistoricLogViewContext *viewContext in self.contextObjects.allValues) {
		[viewContext performBlockAndWait:^{
			[self _saveContext:viewContext];
		}];
	}

	[parentContext performBlockAndWait:^{
		[self _saveContext:parentContext];
	}];
}

- (void)saveData
{
	if (self.isSaving) {
		LogToConsoleDebug("Cancelled save because a save is already saving");

		return;
	}

	self.isSaving = YES;

	dispatch_async(self.queue, ^{
		[self _saveData];

		self.isSaving = NO;
	});
}

- (void)prepareForApplicationTermination
{
	[self saveData];
}

- (void)resetMaximumLineCount
{
	NSUInteger maximumLineCount = MAX([TPCPreferences scrollbackSaveLimit], 1);

	dispatch_async(self.queue, ^{
		self.maximumLineCount = maximumLineCount;
	});
}

#pragma mark -
#pragma mark Deleting

/* Call on -queue. Deletes the view's lines with entry identifiers up to
 highestEntryIdentifier (NSIntegerMax: all of them) and tells the view
 which lines went. Returns the number deleted. */
- (NSUInteger)_deleteLinesInViewContext:(HLSHistoricLogViewContext *)viewContext upToEntryIdentifier:(NSInteger)highestEntryIdentifier
{
	NSParameterAssert(viewContext != nil);

	NSManagedObjectContext *parentContext = self.managedObjectContext;

	/* Pending lines are written out first: a batch delete only sees the store */
	[viewContext performBlockAndWait:^{
		[self _saveContext:viewContext];
	}];

	__block NSArray<NSString *> *uniqueIdentifiers = @[];

	[parentContext performBlockAndWait:^{
		[self _saveContext:parentContext];

		NSPredicate *predicate =
		[NSPredicate predicateWithFormat:@"logLineViewIdentifier == %@ AND entryIdentifier <= %ld",
			viewContext.hls_viewId, (long)highestEntryIdentifier];

		/* The unique identifiers, without the archived lines */
		NSFetchRequest *identifiersRequest = [NSFetchRequest fetchRequestWithEntityName:@"LogLine2"];

		identifiersRequest.predicate = predicate;

		identifiersRequest.resultType = NSDictionaryResultType;

		identifiersRequest.propertiesToFetch = @[@"logLineUniqueIdentifier"];

		NSError *fetchError = nil;

		NSArray<NSDictionary *> *identifiers = [parentContext executeFetchRequest:identifiersRequest error:&fetchError];

		if (identifiers == nil) {
			LogToConsoleError("Failed to fetch historic log lines to delete: %{public}@", fetchError.localizedDescription);

			return;
		}

		NSFetchRequest *deleteFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LogLine2"];

		deleteFetchRequest.predicate = predicate;

		NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteFetchRequest];

		NSError *deleteError = nil;

		if ([parentContext executeRequest:deleteRequest error:&deleteError] == nil) {
			LogToConsoleError("Failed to delete historic log lines: %{public}@", deleteError.localizedDescription);

			return;
		}

		NSMutableArray<NSString *> *uniqueIdentifiersMutable = [NSMutableArray arrayWithCapacity:identifiers.count];

		for (NSDictionary *identifier in identifiers) {
			NSString *uniqueIdentifier = identifier[@"logLineUniqueIdentifier"];

			if (uniqueIdentifier) {
				[uniqueIdentifiersMutable addObject:uniqueIdentifier];
			}
		}

		uniqueIdentifiers = [uniqueIdentifiersMutable copy];
	}];

	NSUInteger rowsDeleted = uniqueIdentifiers.count;

	LogToConsoleDebug("Deleted %{public}lu rows in %{public}@", rowsDeleted, viewContext.hls_viewId);

	if (rowsDeleted == 0) {
		return 0;
	}

	NSString *viewId = viewContext.hls_viewId;

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		IRCTreeItem *item = [worldController() findItemWithId:viewId];

		[item.viewController notifyHistoricLogWillDeleteLines:uniqueIdentifiers];
	});

	return rowsDeleted;
}

- (void)_cancelResizeInViewContext:(HLSHistoricLogViewContext *)viewContext
{
	NSParameterAssert(viewContext != nil);

	if (viewContext.hls_resizeTimer == nil) {
		return;
	}

	XRCancelScheduledBlock(viewContext.hls_resizeTimer);

	viewContext.hls_resizeTimer = nil;
}

/* Call on -queue */
- (void)_scheduleResizeInViewContext:(HLSHistoricLogViewContext *)viewContext lineCount:(NSUInteger)lineCount
{
	NSParameterAssert(viewContext != nil);

	if (viewContext.hls_resizeTimer != nil || lineCount < self.maximumLineCount) {
		return;
	}

	NSString *viewId = viewContext.hls_viewId;

	NSTimeInterval resizeInterval = (NSTimeInterval)arc4random_uniform(_resizeIntervalMaximum);

	dispatch_source_t resizeTimer =
	XRScheduleBlockOnQueue(self.queue, ^{
		[self _resizeView:viewId];
	}, resizeInterval, NO);

	XRResumeScheduledBlock(resizeTimer);

	viewContext.hls_resizeTimer = resizeTimer;

	LogToConsoleDebug("Scheduled to resize %{public}@ in %{public}f seconds", viewId, resizeInterval);
}

/* Call on -queue */
- (void)_resizeView:(NSString *)viewId
{
	NSParameterAssert(viewId != nil);

	HLSHistoricLogViewContext *viewContext = self.contextObjects[viewId];

	if (viewContext == nil) {
		return;
	}

	viewContext.hls_resizeTimer = nil;

	__block NSInteger highestEntryIdentifier = 0;

	[viewContext performBlockAndWait:^{
		highestEntryIdentifier = ((NSInteger)viewContext.hls_newestIdentifier - (NSInteger)self.maximumLineCount);
	}];

	if (highestEntryIdentifier <= 0) {
		return;
	}

	LogToConsoleDebug("Resizing view %{public}@", viewId);

	NSUInteger rowsDeleted = [self _deleteLinesInViewContext:viewContext upToEntryIdentifier:highestEntryIdentifier];

	[viewContext performBlockAndWait:^{
		viewContext.hls_totalLineCount -= MIN(rowsDeleted, viewContext.hls_totalLineCount);
	}];
}

- (void)forgetItem:(IRCTreeItem *)item
{
	NSString *viewId = item.uniqueIdentifier;

	dispatch_async(self.queue, ^{
		HLSHistoricLogViewContext *viewContext = [self _contextForView:viewId];

		if (viewContext == nil) {
			return;
		}

		LogToConsoleDebug("Forgetting view: %{public}@", viewId);

		[self _cancelResizeInViewContext:viewContext];

		[self _deleteLinesInViewContext:viewContext upToEntryIdentifier:NSIntegerMax];

		[self.contextObjects removeObjectForKey:viewId];
	});
}

- (void)resetDataForItem:(IRCTreeItem *)item
{
	NSString *viewId = item.uniqueIdentifier;

	dispatch_async(self.queue, ^{
		HLSHistoricLogViewContext *viewContext = [self _contextForView:viewId];

		if (viewContext == nil) {
			return;
		}

		LogToConsoleDebug("Resetting the contents of view: %{public}@", viewId);

		[self _cancelResizeInViewContext:viewContext];

		[self _deleteLinesInViewContext:viewContext upToEntryIdentifier:NSIntegerMax];

		/* Entry identifiers keep counting up, so a fetch by identifier
		 range never mixes old and new lines */
		[viewContext performBlockAndWait:^{
			viewContext.hls_totalLineCount = 0;
		}];
	});
}

#pragma mark -
#pragma mark Writing

- (void)writeNewEntryWithLogLine:(TVCLogLine *)logLine forItem:(IRCTreeItem *)item
{
	NSParameterAssert(logLine != nil);
	NSParameterAssert(item != nil);

	/* Archived here: the line is immutable, the caller is off the main thread */
	NSData *data = [logLine archivedData];

	if (data == nil) {
		LogToConsoleError("Failed to archive a line for the historic log");

		return;
	}

	NSString *uniqueIdentifier = logLine.uniqueIdentifier;
	NSUInteger sessionIdentifier = logLine.sessionIdentifier;

	NSString *viewId = item.uniqueIdentifier;

	dispatch_async(self.queue, ^{
		HLSHistoricLogViewContext *viewContext = [self _contextForView:viewId];

		if (viewContext == nil) {
			return;
		}

		__block NSUInteger lineCount = 0;

		[viewContext performBlockAndWait:^{
			NSManagedObject *newEntry = [NSEntityDescription insertNewObjectForEntityForName:@"LogLine2" inManagedObjectContext:viewContext];

			viewContext.hls_totalLineCount += 1;
			viewContext.hls_newestIdentifier += 1;

			[newEntry setValue:@(viewContext.hls_newestIdentifier) forKey:@"entryIdentifier"];
			[newEntry setValue:@([[NSDate date] timeIntervalSince1970]) forKey:@"entryCreationDate"];
			[newEntry setValue:viewId forKey:@"logLineViewIdentifier"];
			[newEntry setValue:data forKey:@"logLineData"];
			[newEntry setValue:uniqueIdentifier forKey:@"logLineUniqueIdentifier"];
			[newEntry setValue:@(sessionIdentifier) forKey:@"sessionIdentifier"];

			lineCount = viewContext.hls_totalLineCount;
		}];

		[self _scheduleResizeInViewContext:viewContext lineCount:lineCount];
	});
}

#pragma mark -
#pragma mark Fetching

- (void)fetchEntriesForItem:(IRCTreeItem *)item
				  ascending:(BOOL)ascending
				 fetchLimit:(NSUInteger)fetchLimit
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	NSParameterAssert(item != nil);
	NSParameterAssert(completionBlock != nil);

	NSString *viewId = item.uniqueIdentifier;

	dispatch_async(self.queue, ^{
		HLSHistoricLogViewContext *viewContext = [self _contextForView:viewId];

		if (viewContext == nil) {
			completionBlock(@[]);

			return;
		}

		NSFetchRequest *fetchRequest = [self _fetchRequestForView:viewId
														ascending:ascending
													   fetchLimit:fetchLimit
													  limitToDate:limitToDate];

		[self _fetchInViewContext:viewContext fetchRequest:fetchRequest completionBlock:completionBlock];
	});
}

/* Fetches the entry identifier range that rangeBlock returns for the entry
 identifiers of the given unique identifiers (NSNotFound when missing) */
- (void)_fetchEntriesForItem:(IRCTreeItem *)item
		   uniqueIdentifiers:(NSArray<NSString *> *)uniqueIdentifiers
				  fetchLimit:(NSUInteger)fetchLimit
				 limitToDate:(nullable NSDate *)limitToDate
				  rangeBlock:(NSRange (^)(NSArray<NSNumber *> *entryIdentifiers))rangeBlock
		 withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	NSParameterAssert(item != nil);
	NSParameterAssert(uniqueIdentifiers != nil);
	NSParameterAssert(rangeBlock != nil);
	NSParameterAssert(completionBlock != nil);

	NSString *viewId = item.uniqueIdentifier;

	dispatch_async(self.queue, ^{
		HLSHistoricLogViewContext *viewContext = [self _contextForView:viewId];

		if (viewContext == nil) {
			completionBlock(@[]);

			return;
		}

		__block NSRange range = NSMakeRange(NSNotFound, 0);

		[viewContext performBlockAndWait:^{
			NSMutableArray<NSNumber *> *entryIdentifiers = [NSMutableArray arrayWithCapacity:uniqueIdentifiers.count];

			for (NSString *uniqueIdentifier in uniqueIdentifiers) {
				NSInteger entryIdentifier = [self _entryIdentifierInViewContext:viewContext forUniqueIdentifier:uniqueIdentifier];

				if (entryIdentifier == NSNotFound) {
					return;
				}

				[entryIdentifiers addObject:@(entryIdentifier)];
			}

			range = rangeBlock([entryIdentifiers copy]);
		}];

		if (range.location == NSNotFound || range.length == 0) {
			completionBlock(@[]);

			return;
		}

		NSFetchRequest *fetchRequest = [self _fetchRequestForView:viewId
														ascending:YES
													   fetchLimit:fetchLimit
											lowestEntryIdentifier:range.location
										   highestEntryIdentifier:(NSMaxRange(range) - 1)
													  limitToDate:limitToDate];

		[self _fetchInViewContext:viewContext fetchRequest:fetchRequest completionBlock:completionBlock];
	});
}

/* The line with the unique identifier and up to the given numbers of lines around it */
- (void)fetchEntriesForItem:(IRCTreeItem *)item
	   withUniqueIdentifier:(NSString *)uniqueId
		   beforeFetchLimit:(NSUInteger)fetchLimitBefore
			afterFetchLimit:(NSUInteger)fetchLimitAfter
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	NSParameterAssert(uniqueId != nil);

	fetchLimitBefore = MIN(fetchLimitBefore, _fetchLimitCap);
	fetchLimitAfter = MIN(fetchLimitAfter, _fetchLimitCap);

	[self _fetchEntriesForItem:item
			 uniqueIdentifiers:@[uniqueId]
					fetchLimit:(fetchLimitBefore + fetchLimitAfter + 1)
				   limitToDate:limitToDate
					rangeBlock:^NSRange(NSArray<NSNumber *> *entryIdentifiers) {
						NSInteger entryIdentifier = entryIdentifiers[0].integerValue;

						NSInteger lowest = MAX((entryIdentifier - (NSInteger)fetchLimitBefore), 0);

						return NSMakeRange(lowest, (entryIdentifier + fetchLimitAfter - lowest + 1));
					}
		   withCompletionBlock:completionBlock];
}

- (void)_fetchEntriesForItem:(IRCTreeItem *)item
		withUniqueIdentifier:(NSString *)uniqueId
				   direction:(HLSHistoricLogFetchDirection)direction
				  fetchLimit:(NSUInteger)fetchLimit
				 limitToDate:(nullable NSDate *)limitToDate
		 withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	NSParameterAssert(uniqueId != nil);
	NSParameterAssert(fetchLimit > 0);

	fetchLimit = MIN(fetchLimit, _fetchLimitCap);

	[self _fetchEntriesForItem:item
			 uniqueIdentifiers:@[uniqueId]
					fetchLimit:fetchLimit
				   limitToDate:limitToDate
					rangeBlock:^NSRange(NSArray<NSNumber *> *entryIdentifiers) {
						NSInteger entryIdentifier = entryIdentifiers[0].integerValue;

						/* The line itself is not part of the result */
						if (direction == HLSHistoricLogFetchDirectionBefore) {
							NSInteger lowest = MAX((entryIdentifier - (NSInteger)fetchLimit), 0);

							return NSMakeRange(lowest, (entryIdentifier - lowest));
						} else {
							return NSMakeRange((entryIdentifier + 1), fetchLimit);
						}
					}
		   withCompletionBlock:completionBlock];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	 beforeUniqueIdentifier:(NSString *)uniqueId
				 fetchLimit:(NSUInteger)fetchLimit
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self _fetchEntriesForItem:item
		  withUniqueIdentifier:uniqueId
					 direction:HLSHistoricLogFetchDirectionBefore
					fetchLimit:fetchLimit
				   limitToDate:limitToDate
		   withCompletionBlock:completionBlock];
}

- (void)fetchEntriesForItem:(IRCTreeItem *)item
	  afterUniqueIdentifier:(NSString *)uniqueId
				 fetchLimit:(NSUInteger)fetchLimit
				limitToDate:(nullable NSDate *)limitToDate
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	[self _fetchEntriesForItem:item
		  withUniqueIdentifier:uniqueId
					 direction:HLSHistoricLogFetchDirectionAfter
					fetchLimit:fetchLimit
				   limitToDate:limitToDate
		   withCompletionBlock:completionBlock];
}

/* The lines between two unique identifiers, without those two */
- (void)fetchEntriesForItem:(IRCTreeItem *)item
	  afterUniqueIdentifier:(NSString *)uniqueIdAfter
	 beforeUniqueIdentifier:(NSString *)uniqueIdBefore
				 fetchLimit:(NSUInteger)fetchLimit
		withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	NSParameterAssert(uniqueIdAfter != nil);
	NSParameterAssert(uniqueIdBefore != nil);

	[self _fetchEntriesForItem:item
			 uniqueIdentifiers:@[uniqueIdAfter, uniqueIdBefore]
					fetchLimit:fetchLimit
				   limitToDate:nil
					rangeBlock:^NSRange(NSArray<NSNumber *> *entryIdentifiers) {
						NSInteger lowest = (entryIdentifiers[0].integerValue + 1);
						NSInteger highest = (entryIdentifiers[1].integerValue - 1);

						if (highest < lowest) {
							return NSMakeRange(NSNotFound, 0);
						}

						return NSMakeRange(lowest, (highest - lowest + 1));
					}
		   withCompletionBlock:completionBlock];
}

@end

NS_ASSUME_NONNULL_END
