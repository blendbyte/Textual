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

- (BOOL)boolAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (nullable NSArray *)arrayAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (nullable NSString *)stringAtIndex:(NSUInteger)n;
- (nullable NSDictionary *)dictionaryAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (NSInteger)integerAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (NSUInteger)unsignedIntegerAtIndex:(NSUInteger)n;
- (short)shortAtIndex:(NSUInteger)n;
- (unsigned short)unsignedShortAtIndex:(NSUInteger)n;
- (long)longAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (unsigned long)unsignedLongAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (long long)longLongAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (unsigned long long)unsignedLongLongAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (double)doubleAtIndex:(NSUInteger)n;
- (float)floatAtIndex:(NSUInteger)n COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
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

- (void)addBool:(BOOL)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addInteger:(NSInteger)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addUnsignedInteger:(NSUInteger)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addShort:(short)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addUnsignedShort:(unsigned short)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addLong:(long)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addUnsignedLong:(unsigned long)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addLongLong:(long long)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addUnsignedLongLong:(unsigned long long)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addDouble:(double)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addFloat:(float)value COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)addPointer:(void *)value;

- (void)insertBool:(BOOL)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertInteger:(NSInteger)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertUnsignedInteger:(NSUInteger)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertShort:(short)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertUnsignedShort:(unsigned short)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertLong:(long)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertUnsignedLong:(unsigned long)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertLongLong:(long long)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertUnsignedLongLong:(unsigned long long)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertDouble:(double)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertFloat:(float)value atIndex:(NSUInteger)index COCOA_EXTENSIONS_DEPRECATED("Unused; will be removed in a future version");
- (void)insertPointer:(void *)value atIndex:(NSUInteger)index;

- (void)performSelectorOnObjectValueAndReplace:(SEL)performSelector;

- (NSUInteger)insertSortedObject:(id)object usingComparator:(NSComparator)comparator;

- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

- (void)shuffle;
@end

NS_ASSUME_NONNULL_END
