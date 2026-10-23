/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2018 Codeux Software, LLC
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

#define NSDictionaryNilValue(s)							(((s) == nil) ? [NSNull null] : (s))
#define NSDictionaryNilValueSubstitute(s, r)			(((s) == nil) ? (r) : (s))

@interface NSDictionary (CSDictionaryHelper)
- (NSDictionary *)dictionaryByAddingEntries:(NSDictionary *)entries;

- (BOOL)boolForKey:(id)key;
- (nullable NSArray *)arrayForKey:(id)key;
- (nullable NSDictionary *)dictionaryForKey:(id)key;
- (nullable NSString *)stringForKey:(id)key;
- (NSInteger)integerForKey:(id)key;
- (NSUInteger)unsignedIntegerForKey:(id)key;
- (short)shortForKey:(id)key;
- (unsigned short)unsignedShortForKey:(id)key;
- (long)longForKey:(id)key;
- (unsigned long)unsignedLongForKey:(id)key;
- (long long)longLongForKey:(id)key;
- (unsigned long long)unsignedLongLongForKey:(id)key;
- (double)doubleForKey:(id)key;
- (float)floatForKey:(id)key;
- (nullable void *)pointerForKey:(id)key NS_RETURNS_INNER_POINTER;

- (nullable id)objectForKey:(id)key orUseDefault:(nullable id)defaultValue;
- (BOOL)boolForKey:(id)key orUseDefault:(BOOL)defaultValue;
- (nullable NSArray *)arrayForKey:(id)key orUseDefault:(nullable NSArray *)defaultValue;
- (nullable NSDictionary *)dictionaryForKey:(id)key orUseDefault:(nullable NSDictionary *)defaultValue;
- (nullable NSString *)stringForKey:(id)key orUseDefault:(nullable NSString *)defaultValue;
- (NSInteger)integerForKey:(id)key orUseDefault:(NSInteger)defaultValue;
- (NSUInteger)unsignedIntegerForKey:(id)key orUseDefault:(NSUInteger)defaultValue;
- (short)shortForKey:(id)key orUseDefault:(short)defaultValue;
- (unsigned short)unsignedShortForKey:(id)key orUseDefault:(unsigned short)defaultValue;
- (long)longForKey:(id)key orUseDefault:(long)defaultValue;
- (unsigned long)unsignedLongForKey:(id)key orUseDefault:(unsigned long)defaultValue;
- (long long)longLongForKey:(id)key orUseDefault:(long long)defaultValue;
- (unsigned long long)unsignedLongLongForKey:(id)key orUseDefault:(unsigned long long)defaultValue;
- (double)doubleForKey:(id)key orUseDefault:(double)defaultValue;
- (float)floatForKey:(id)key orUseDefault:(float)defaultValue;

/* Objects are copied to the pointer using -copy */
- (void)assignObjectTo:(__strong _Nonnull id * _Nonnull)pointer forKey:(id)key;
- (void)assignObjectTo:(__strong _Nonnull id * _Nonnull)pointer forKey:(id)key performCopy:(BOOL)copyValue;
- (void)assignBoolTo:(BOOL *)pointer forKey:(id)key;
- (void)assignArrayTo:(__strong NSArray * _Nonnull * _Nonnull)pointer forKey:(id)key;
- (void)assignDictionaryTo:(__strong NSDictionary * _Nonnull * _Nonnull)pointer forKey:(id)key;
- (void)assignStringTo:(__strong NSString * _Nonnull * _Nonnull)pointer forKey:(id)key;
- (void)assignIntegerTo:(NSInteger *)pointer forKey:(id)key;
- (void)assignUnsignedIntegerTo:(NSUInteger *)pointer forKey:(id)key;
- (void)assignShortTo:(short *)pointer forKey:(id)key;
- (void)assignUnsignedShortTo:(unsigned short *)pointer forKey:(id)key;
- (void)assignLongTo:(long *)pointer forKey:(id)key;
- (void)assignUnsignedLongTo:(unsigned long *)pointer forKey:(id)key;
- (void)assignLongLongTo:(long long *)pointer forKey:(id)key;
- (void)assignUnsignedLongLongTo:(unsigned long long *)pointer forKey:(id)key;
- (void)assignDoubleTo:(double *)pointer forKey:(id)key;
- (void)assignFloatTo:(float *)pointer forKey:(id)key;

- (nullable id)firstKeyForObject:(id)anObject;

- (BOOL)containsKey:(id)key;
- (BOOL)containsKeyIgnoringCase:(id)key;

- (nullable id)keyIgnoringCase:(id)key;

@property (readonly, copy) NSArray *sortedDictionaryKeys;
@property (readonly, copy) NSArray *sortedDictionaryKeysReversed;

/* Returns a new dictionary without values that are already defined by "defaults" 
 or are empty (zero length, or zero count). This method is not recursive which 
 means it only performs one pass on all top level objects. */
/* "defaults" is allowed to be nil in which case only empty objects are removed. */
- (NSDictionary *)dictionaryByRemovingDefaults:(nullable NSDictionary *)defaults;
- (NSDictionary *)dictionaryByRemovingDefaults:(nullable NSDictionary *)defaults allowEmptyValues:(BOOL)allowEmptyValues;

/* Abstraction of query items that uses a custom
 separator and allows for custom encoding logic. */
/* Regular URL encoding is used by -formDataUsingSeparator: */
/* Key types that are accepted: NSString, NSNumber */
/* Object types that are accepted: NSString, NSNumber, NSNull */
- (NSString *)formDataUsingSeparator:(NSString *)separator;
- (NSString *)formDataUsingSeparator:(NSString *)separator encodingBlock:(NSString *(NS_NOESCAPE ^)(NSString *value))encodingBlock;
@end

@interface NSMutableDictionary (CSMutableDictionaryHelper)
/* maybeSetObject provides nil checks for inserted objects. */
- (void)maybeSetObject:(nullable id)value forKey:(id)key;

- (void)setObjectWithoutOverride:(id)value forKey:(id)key;

- (void)setBool:(BOOL)value forKey:(id)key;
- (void)setInteger:(NSInteger)value forKey:(id)key;
- (void)setUnsignedInteger:(NSUInteger)value forKey:(id)key;
- (void)setShort:(short)value forKey:(id)key;
- (void)setUnsignedShort:(unsigned short)value forKey:(id)key;
- (void)setLong:(long)value forKey:(id)key;
- (void)setUnsignedLong:(unsigned long)value forKey:(id)key;
- (void)setLongLong:(long long)value forKey:(id)key;
- (void)setUnsignedLongLong:(unsigned long long)value forKey:(id)key;
- (void)setDouble:(double)value forKey:(id)key;
- (void)setFloat:(float)value forKey:(id)key;
- (void)setPointer:(void *)value forKey:(id)key;

- (void)performSelectorOnObjectValueAndReplace:(SEL)performSelector;
@end

NS_ASSUME_NONNULL_END
