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

#include <objc/message.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSArray (CSArrayHelper)

- (BOOL)boolAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(boolValue)]) {
			return [object boolValue];
		}

		return NO;
	}
}

- (nullable NSArray *)arrayAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object isKindOfClass:[NSArray class]]) {
			return object;
		}

		return nil;
	}
}

- (nullable NSString *)stringAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object isKindOfClass:[NSString class]]) {
			return object;
		}

		return nil;
	}
}

- (nullable NSDictionary *)dictionaryAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object isKindOfClass:[NSDictionary class]]) {
			return object;
		}

		return nil;
	}
}

- (NSInteger)integerAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(integerValue)]) {
			return [object integerValue];
		}

		return 0;
	}
}

- (NSUInteger)unsignedIntegerAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(unsignedIntegerValue)]) {
			return [object unsignedIntegerValue];
		}

		return 0;
	}
}

- (short)shortAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object shortValue];
		}

		return 0;
	}
}

- (unsigned short)unsignedShortAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object unsignedShortValue];
		}

		return 0;
	}
}

- (long)longAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object longValue];
		}

		return 0;
	}
}

- (unsigned long)unsignedLongAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object unsignedLongValue];
		}

		return 0;
	}
}

- (long long)longLongAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object longLongValue];
		}

		return 0;
	}
}

- (unsigned long long)unsignedLongLongAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object unsignedLongLongValue];
		}

		return 0;
	}
}

- (double)doubleAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object doubleValue];
		}

		return 0;
	}
}

- (float)floatAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object floatValue];
		}

		return 0;
	}
}

- (nullable void *)pointerAtIndex:(NSUInteger)n
{
	@synchronized(self) {
		id object = self[n];

		if ([object isKindOfClass:[NSValue class]]) {
			return [object pointerValue];
		}

		return NULL;
	}
}

- (BOOL)containsObjectIgnoringCase:(id)anObject
{
	NSParameterAssert(anObject != nil);

	if (self.count == 0) {
		return NO;
	}

	@synchronized(self) {
		NSUInteger objectIndex =
		[self indexOfObjectPassingTest:^BOOL(id object, NSUInteger index, BOOL *stop) {
			if ([object isEqualIgnoringCase:anObject]) {
				*stop = YES;

				return YES;
			} else {
				return NO;
			}
		}];

		return (objectIndex != NSNotFound);
	}
}

- (NSRange)range
{
	return NSMakeRange(0, self.count);
}

- (NSArray *)arrayByRemovingObjectAtIndex:(NSUInteger)index
{
	if (self.count == 0) {
		return self;
	}

	@synchronized(self) {
		NSMutableArray *array = [self mutableCopy];

		[array removeObjectAtIndex:index];

		return [array copy];
	}
}

- (NSMutableArray *)mutableSubarrayWithRange:(NSRange)range
{
	if (self.count == 0) {
		return [NSMutableArray array];
	}

	@synchronized(self) {
		NSArray *subarray = [self subarrayWithRange:range];

		return [subarray mutableCopy];
	}
}

- (NSArray *)stringArrayControllerObjects
{
	if (self.count == 0) {
		return @[];
	}

	NSMutableArray *newSet = [NSMutableArray array];

	@synchronized(self) {
		[self enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
			if ([object isKindOfClass:[NSString class]] == NO) {
				return;
			}

			[newSet addObject:@{@"string" : object}];
		}];
	}

	return [newSet copy];
}

- (NSArray *)arrayByRemovingEmptyValues
{
	return [self arrayByRemovingEmptyValues:YES trimming:NO uniquing:NO];
}

- (NSArray *)arrayByUniquing
{
	return [self arrayByRemovingEmptyValues:NO trimming:NO uniquing:YES];
}

- (NSArray *)arrayByRemovingEmptyValuesAndUniquing
{
	return [self arrayByRemovingEmptyValues:YES trimming:NO uniquing:YES];
}

- (NSArray *)arrayByRemovingEmptyValues:(BOOL)removeEmptyValues trimming:(BOOL)trimValues uniquing:(BOOL)uniqueValues
{
	if (self.count == 0) {
		return self;
	}

	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.count];

	@synchronized(self) {
		[self enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
			id objectValue = object;

			if (trimValues && [objectValue respondsToSelector:@selector(trim)]) {
				objectValue = [objectValue trim];
			}

COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
			if (removeEmptyValues && NSObjectIsEmpty(objectValue)) {
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

				return;
			} else if (uniqueValues && [newArray containsObject:objectValue]) {
				return;
			}

			[newArray addObject:objectValue];
		}];

		return [newArray copy];
	}
}

- (nullable id)objectPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate
{
	return [self objectPassingTest:predicate withOptions:0];
}

- (nullable id)objectPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate withOptions:(NSEnumerationOptions)options
{
	if (self.count == 0) {
		return nil;
	}

	NSUInteger objectIndex = [self indexOfObjectWithOptions:options passingTest:predicate];

	if (objectIndex == NSNotFound) {
		return nil;
	}

	return self[objectIndex];
}

- (NSArray *)objectsPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate
{
	return [self objectsPassingTest:predicate withOptions:0];
}

- (NSArray *)objectsPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate withOptions:(NSEnumerationOptions)options
{
	if (self.count == 0) {
		return @[];
	}

	NSIndexSet *objectIndexes = [self indexesOfObjectsWithOptions:options passingTest:predicate];

	if (objectIndexes.count == 0) {
		return @[];
	}

	return [self objectsAtIndexes:objectIndexes];
}

- (void)enumerateSubarraysOfSize:(NSUInteger)subarraySize usingBlock:(void (NS_NOESCAPE ^)(NSArray *objects, BOOL *stop))block
{
	[self enumerateSubarraysOfSize:subarraySize usingBlock:block withOptions:0];
}

- (void)enumerateSubarraysOfSize:(NSUInteger)subarraySize usingBlock:(void (NS_NOESCAPE ^)(NSArray *objects, BOOL *stop))block withOptions:(NSEnumerationOptions)options
{
	NSParameterAssert(subarraySize > 0);
	NSParameterAssert(block != nil);

	if (self.count == 0) {
		return;
	}

	NSMutableArray *subarray = [NSMutableArray arrayWithCapacity:subarraySize];

	@synchronized(self) {
		[self enumerateObjectsWithOptions:options usingBlock:^(id object, NSUInteger index, BOOL *stop) {
			[subarray addObject:object];

			if (subarray.count == subarraySize) {
				block([subarray copy], stop);

				[subarray removeAllObjects];
			}
		}];
	}

	if (subarray.count > 0) {
		block([subarray copy], NULL);
	}
}

- (NSArray *)arrayByApplyingBlock:(id (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))block
{
	return [self arrayByApplyingBlock:block withOptions:0];
}

- (NSArray *)arrayByApplyingBlock:(id (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))block withOptions:(NSEnumerationOptions)options
{
	NSParameterAssert(block != nil);

	if (self.count == 0) {
		return @[];
	}

	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.count];

	@synchronized(self) {
		[self enumerateObjectsWithOptions:options usingBlock:^(id object, NSUInteger index, BOOL *stop) {
			[newArray addObject:block(object, index, stop)];
		}];
	}

	return [newArray copy];
}

@end

@implementation NSMutableArray (CSMutableArrayHelper)

- (void)addObjectWithoutDuplication:(id)anObject
{
	NSParameterAssert(anObject != nil);

	if ([self containsObject:anObject] == NO) {
		[self addObject:anObject];
	}
}

- (void)insertBool:(BOOL)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertInteger:(NSInteger)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertUnsignedInteger:(NSUInteger)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertShort:(short)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertUnsignedShort:(unsigned short)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertLong:(long)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertUnsignedLong:(unsigned long)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertLongLong:(long long)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertUnsignedLongLong:(unsigned long long)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertDouble:(double)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertFloat:(float)value atIndex:(NSUInteger)index
{
	[self insertObject:@(value) atIndex:index];
}

- (void)insertPointer:(void *)value atIndex:(NSUInteger)index
{
	[self insertObject:[NSValue valueWithPointer:value] atIndex:index];
}

- (void)addBool:(BOOL)value
{
	[self addObject:@(value)];
}

- (void)addInteger:(NSInteger)value
{
	[self addObject:@(value)];
}

- (void)addUnsignedInteger:(NSUInteger)value
{
	[self addObject:@(value)];
}

- (void)addShort:(short)value
{
	[self addObject:@(value)];
}

- (void)addUnsignedShort:(unsigned short)value
{
	[self addObject:@(value)];
}

- (void)addLong:(long)value
{
	[self addObject:@(value)];
}

- (void)addUnsignedLong:(unsigned long)value
{
	[self addObject:@(value)];
}

- (void)addLongLong:(long long)value
{
	[self addObject:@(value)];
}

- (void)addUnsignedLongLong:(unsigned long long)value
{
	[self addObject:@(value)];
}

- (void)addDouble:(double)value
{
	[self addObject:@(value)];
}

- (void)addFloat:(float)value
{
	[self addObject:@(value)];
}

- (void)addPointer:(void *)value
{
	[self addObject:[NSValue valueWithPointer:value]];
}

- (void)performSelectorOnObjectValueAndReplace:(SEL)performSelector
{
	NSParameterAssert(performSelector != NULL);

	if (self.count == 0) {
		return;
	}

	@synchronized(self) {
		NSArray *oldArray = [self copy];

		[oldArray enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
			NSMethodSignature *methodSignature = [object methodSignatureForSelector:performSelector];

			NSAssert1((*(methodSignature.methodReturnType) == '@'),
				@"Selector '%@' does not return an object value",
				NSStringFromSelector(performSelector));

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
			id newObject = [object performSelector:performSelector];
#pragma GCC diagnostic pop

			NSAssert2((newObject != nil),
				@"Object %@ returned a nil value when performing selector '%@'",
				[object description], NSStringFromSelector(performSelector));

			self[index] = newObject;
		}];
	}
}

- (void)shuffle
{
	if (self.count == 0) {
		return;
	}

	@synchronized (self) {
		NSUInteger selfCount = self.count;

		for (NSUInteger i = (selfCount - 1); i > 0; i--) {
			NSUInteger n = arc4random_uniform((uint32_t)i + 1);

			[self exchangeObjectAtIndex:i withObjectAtIndex:n];
		}
	}
}

- (NSUInteger)insertSortedObject:(id)object usingComparator:(NSComparator)comparator
{
	NSParameterAssert(object != nil);
	NSParameterAssert(comparator != NULL);

	@synchronized(self) {
		NSUInteger index = [self indexOfObject:object
								 inSortedRange:self.range
									   options:NSBinarySearchingInsertionIndex
							   usingComparator:comparator];

		[self insertObject:object atIndex:index];

		return index;
	}
}

- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
	id object = self[fromIndex];

	[self removeObjectAtIndex:fromIndex];

	if (fromIndex < toIndex) {
		[self insertObject:object atIndex:(toIndex - 1)];
	} else {
		[self insertObject:object atIndex:toIndex];
	}
}

@end

NS_ASSUME_NONNULL_END
