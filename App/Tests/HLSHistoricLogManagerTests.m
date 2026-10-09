/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>

#import "HLSHistoricLogManagerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLSHistoricLogManagerTests : XCTestCase
@property (nonatomic, strong) NSURL *storeURL;
@property (nonatomic, strong) NSManagedObjectContext *parentContext;
@property (nonatomic, strong) NSManagedObjectContext *viewContext;
@end

@implementation HLSHistoricLogManagerTests

/* A store laid out like the app's: a parent context on the store, a child
 context per view, lines written to the child and saved later */
- (void)setUp
{
	NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"HistoricLogFileStorageModel" withExtension:@"momd"];

	NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

	XCTAssertNotNil(model);

	self.storeURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];

	NSError *error = nil;

	XCTAssertNotNil([coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.storeURL options:nil error:&error], @"%@", error);

	self.parentContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	self.parentContext.persistentStoreCoordinator = coordinator;

	self.viewContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	self.viewContext.parentContext = self.parentContext;
}

- (void)tearDown
{
	for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
		[[NSFileManager defaultManager] removeItemAtPath:[self.storeURL.path stringByAppendingString:suffix] error:NULL];
	}
}

- (void)writeLinesToView:(NSString *)viewId from:(NSUInteger)first to:(NSUInteger)last inContext:(NSManagedObjectContext *)context
{
	[context performBlockAndWait:^{
		for (NSUInteger entryIdentifier = first; entryIdentifier <= last; entryIdentifier++) {
			NSManagedObject *entry = [NSEntityDescription insertNewObjectForEntityForName:@"LogLine2" inManagedObjectContext:context];

			[entry setValue:@(entryIdentifier) forKey:@"entryIdentifier"];
			[entry setValue:@([NSDate date].timeIntervalSince1970) forKey:@"entryCreationDate"];
			[entry setValue:viewId forKey:@"logLineViewIdentifier"];
			[entry setValue:[NSUUID UUID].UUIDString forKey:@"logLineUniqueIdentifier"];
		}
	}];
}

- (NSArray<NSNumber *> *)entryIdentifiersInView:(NSString *)viewId ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit lowest:(NSInteger)lowest highest:(NSInteger)highest
{
	NSFetchRequest *fetchRequest = [HLSHistoricLogManager fetchRequestForView:viewId
																	ascending:ascending
																   fetchLimit:fetchLimit
														lowestEntryIdentifier:lowest
													   highestEntryIdentifier:highest
																  limitToDate:nil];

	__block NSArray<NSNumber *> *entryIdentifiers = nil;

	[self.viewContext performBlockAndWait:^{
		NSArray<NSManagedObject *> *objects = [self.viewContext executeFetchRequest:fetchRequest error:NULL];

		entryIdentifiers = [objects valueForKey:@"entryIdentifier"];
	}];

	return entryIdentifiers;
}

- (NSArray<NSNumber *> *)numbersFrom:(NSInteger)first to:(NSInteger)last
{
	NSMutableArray<NSNumber *> *numbers = [NSMutableArray array];

	NSInteger step = ((first <= last) ? 1 : -1);

	for (NSInteger number = first; number != (last + step); number += step) {
		[numbers addObject:@(number)];
	}

	return [numbers copy];
}

/* Lines loaded back while scrolling, and the newest lines a view reloads,
 come in the order they were written, saved to disk or not */
- (void)testLinesComeBackInWrittenOrder
{
	[self writeLinesToView:@"other" from:1 to:500 inContext:self.parentContext];

	[self.parentContext performBlockAndWait:^{
		XCTAssertTrue([self.parentContext save:NULL]);
	}];

	[self writeLinesToView:@"view" from:1 to:900 inContext:self.viewContext];

	for (NSString *state in @[@"unsaved", @"saved to the parent context", @"saved to disk"]) {
		if ([state isEqualToString:@"saved to the parent context"]) {
			[self.viewContext performBlockAndWait:^{
				XCTAssertTrue([self.viewContext save:NULL]);

				[self.viewContext reset];
			}];
		} else if ([state isEqualToString:@"saved to disk"]) {
			[self.parentContext performBlockAndWait:^{
				XCTAssertTrue([self.parentContext save:NULL]);

				[self.parentContext reset];
			}];
		}

		/* 200 lines above line 733 */
		XCTAssertEqualObjects([self entryIdentifiersInView:@"view" ascending:YES fetchLimit:200 lowest:533 highest:732],
							  [self numbersFrom:533 to:732], @"%@", state);

		/* The newest 100 lines */
		XCTAssertEqualObjects([self entryIdentifiersInView:@"view" ascending:NO fetchLimit:100 lowest:0 highest:NSIntegerMax],
							  [self numbersFrom:900 to:801], @"%@", state);
	}
}

@end

NS_ASSUME_NONNULL_END
