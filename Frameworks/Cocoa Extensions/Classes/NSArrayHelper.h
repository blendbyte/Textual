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

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (CSArrayHelper)
@property (readonly) NSRange range;

- (BOOL)boolAtIndex:(NSUInteger)n;
- (nullable NSArray *)arrayAtIndex:(NSUInteger)n;
- (nullable NSString *)stringAtIndex:(NSUInteger)n;
- (nullable NSDictionary *)dictionaryAtIndex:(NSUInteger)n;
- (NSInteger)integerAtIndex:(NSUInteger)n;
- (NSUInteger)unsignedIntegerAtIndex:(NSUInteger)n;
- (short)shortAtIndex:(NSUInteger)n;
- (unsigned short)unsignedShortAtIndex:(NSUInteger)n;
- (long)longAtIndex:(NSUInteger)n;
- (unsigned long)unsignedLongAtIndex:(NSUInteger)n;
- (long long)longLongAtIndex:(NSUInteger)n;
- (unsigned long long)unsignedLongLongAtIndex:(NSUInteger)n;
- (double)doubleAtIndex:(NSUInteger)n;
- (float)floatAtIndex:(NSUInteger)n;
- (nullable void *)pointerAtIndex:(NSUInteger)n NS_RETURNS_INNER_POINTER;

- (BOOL)containsObjectIgnoringCase:(id)anObject; // Performs comparison using -isEqualIgnoringCase: - ignores objects that don't respond to this.

- (NSArray *)arrayByRemovingObjectAtIndex:(NSUInteger)index;

- (NSMutableArray *)mutableSubarrayWithRange:(NSRange)range;

/* -stringArrayControllerObjects returns an NSArray of NSDictionary with single key,
 named "string" which contains any NSString values in original array. */
@property (copy, readonly) NSArray<NSDictionary *> *stringArrayControllerObjects;

- (NSArray *)arrayByRemovingEmptyValues;
- (NSArray *)arrayByUniquing;
- (NSArray *)arrayByRemovingEmptyValuesAndUniquing;

- (NSArray *)arrayByRemovingEmptyValues:(BOOL)removeEmptyValues trimming:(BOOL)trimValues uniquing:(BOOL)uniqueValues;

- (nullable id)objectPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate;
- (nullable id)objectPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate withOptions:(NSEnumerationOptions)options;

- (NSArray *)objectsPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate;
- (NSArray *)objectsPassingTest:(BOOL (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))predicate withOptions:(NSEnumerationOptions)options;

- (void)enumerateSubarraysOfSize:(NSUInteger)subarraySize usingBlock:(void (NS_NOESCAPE ^)(NSArray *objects, BOOL *stop))block;
- (void)enumerateSubarraysOfSize:(NSUInteger)subarraySize usingBlock:(void (NS_NOESCAPE ^)(NSArray *objects, BOOL *stop))block withOptions:(NSEnumerationOptions)options;

- (NSArray *)arrayByApplyingBlock:(id (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))block;
- (NSArray *)arrayByApplyingBlock:(id (NS_NOESCAPE ^)(id object, NSUInteger index, BOOL *stop))block withOptions:(NSEnumerationOptions)options;
@end

@interface NSMutableArray (CSMutableArrayHelper)
- (void)addObjectWithoutDuplication:(id)anObject;

- (void)addBool:(BOOL)value;
- (void)addInteger:(NSInteger)value;
- (void)addUnsignedInteger:(NSUInteger)value;
- (void)addShort:(short)value;
- (void)addUnsignedShort:(unsigned short)value;
- (void)addLong:(long)value;
- (void)addUnsignedLong:(unsigned long)value;
- (void)addLongLong:(long long)value;
- (void)addUnsignedLongLong:(unsigned long long)value;
- (void)addDouble:(double)value;
- (void)addFloat:(float)value;
- (void)addPointer:(void *)value;

- (void)insertBool:(BOOL)value atIndex:(NSUInteger)index;
- (void)insertInteger:(NSInteger)value atIndex:(NSUInteger)index;
- (void)insertUnsignedInteger:(NSUInteger)value atIndex:(NSUInteger)index;
- (void)insertShort:(short)value atIndex:(NSUInteger)index;
- (void)insertUnsignedShort:(unsigned short)value atIndex:(NSUInteger)index;
- (void)insertLong:(long)value atIndex:(NSUInteger)index;
- (void)insertUnsignedLong:(unsigned long)value atIndex:(NSUInteger)index;
- (void)insertLongLong:(long long)value atIndex:(NSUInteger)index;
- (void)insertUnsignedLongLong:(unsigned long long)value atIndex:(NSUInteger)index;
- (void)insertDouble:(double)value atIndex:(NSUInteger)index;
- (void)insertFloat:(float)value atIndex:(NSUInteger)index;
- (void)insertPointer:(void *)value atIndex:(NSUInteger)index;

- (void)performSelectorOnObjectValueAndReplace:(SEL)performSelector;

- (NSUInteger)insertSortedObject:(id)object usingComparator:(NSComparator)comparator;

- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

- (void)shuffle;
@end

NS_ASSUME_NONNULL_END
