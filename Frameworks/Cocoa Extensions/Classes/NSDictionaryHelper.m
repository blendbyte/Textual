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

/* A portion of this source file contains copyrighted work derived from one or more
 3rd party, open source projects. The use of this work is hereby acknowledged. */

/*
 The New BSD License

 Copyright (c) 2008 - 2010 Satoshi Nakagawa < psychs AT limechat DOT net >
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.
 */

NS_ASSUME_NONNULL_BEGIN

@implementation NSDictionary (CSDictionaryHelper)

- (BOOL)boolForKey:(id)key
{
	return [self boolForKey:key orUseDefault:NO];
}

- (NSInteger)integerForKey:(id)key
{
	return [self integerForKey:key orUseDefault:0];
}

- (NSUInteger)unsignedIntegerForKey:(id)key
{
	return [self unsignedIntegerForKey:key orUseDefault:0];
}

- (short)shortForKey:(id)key
{
	return [self shortForKey:key orUseDefault:0];
}

- (unsigned short)unsignedShortForKey:(id)key
{
	return [self unsignedShortForKey:key orUseDefault:0];
}

- (long)longForKey:(id)key
{
	return [self longForKey:key orUseDefault:0];
}

- (unsigned long)unsignedLongForKey:(id)key
{
	return [self unsignedLongForKey:key orUseDefault:0];
}

- (long long)longLongForKey:(id)key
{
	return [self longLongForKey:key orUseDefault:0];
}

- (unsigned long long)unsignedLongLongForKey:(id)key
{
	return [self unsignedLongLongForKey:key orUseDefault:0];
}

- (double)doubleForKey:(id)key
{
	return [self doubleForKey:key orUseDefault:0];
}

- (float)floatForKey:(id)key
{
	return [self floatForKey:key orUseDefault:0];
}

- (nullable NSString *)stringForKey:(id)key
{
	return [self stringForKey:key orUseDefault:nil];
}

- (nullable NSDictionary *)dictionaryForKey:(id)key
{
	return [self dictionaryForKey:key orUseDefault:nil];
}

- (nullable NSArray *)arrayForKey:(id)key
{
	return [self arrayForKey:key orUseDefault:nil];
}

- (nullable void *)pointerForKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object isKindOfClass:[NSValue class]]) {
			return [object pointerValue];
		}

		return nil;
	}
}

- (nullable id)objectForKey:(id)key orUseDefault:(nullable id)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if (object) {
			return object;
		}

		return defaultValue;
	}
}

- (nullable NSString *)stringForKey:(id)key orUseDefault:(nullable NSString *)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object isKindOfClass:[NSString class]]) {
			return object;
		}

		return defaultValue;
	}
}

- (BOOL)boolForKey:(id)key orUseDefault:(BOOL)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(boolValue)]) {
			return [object boolValue];
		}

		return defaultValue;
	}
}

- (nullable NSArray *)arrayForKey:(id)key orUseDefault:(nullable NSArray *)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object isKindOfClass:[NSArray class]]) {
			return object;
		}

		return defaultValue;
	}
}

- (nullable NSDictionary *)dictionaryForKey:(id)key orUseDefault:(nullable NSDictionary *)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object isKindOfClass:[NSDictionary class]]) {
			return object;
		}

		return defaultValue;
	}
}

- (NSInteger)integerForKey:(id)key orUseDefault:(NSInteger)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(integerValue)]) {
			return [object integerValue];
		}

		return defaultValue;
	}
}

- (NSUInteger)unsignedIntegerForKey:(id)key orUseDefault:(NSUInteger)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(unsignedIntegerValue)]) {
			return [object unsignedIntegerValue];
		}

		return defaultValue;
	}
}

- (short)shortForKey:(id)key orUseDefault:(short)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object shortValue];
		}

		return defaultValue;
	}
}

- (unsigned short)unsignedShortForKey:(id)key orUseDefault:(unsigned short)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object unsignedShortValue];
		}

		return defaultValue;
	}
}

- (long)longForKey:(id)key orUseDefault:(long)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object longValue];
		}

		return defaultValue;
	}
}

- (unsigned long)unsignedLongForKey:(id)key orUseDefault:(unsigned long)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object unsignedLongValue];
		}

		return defaultValue;
	}
}

- (long long)longLongForKey:(id)key orUseDefault:(long long)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object longLongValue];
		}

		return defaultValue;
	}
}

- (unsigned long long)unsignedLongLongForKey:(id)key orUseDefault:(unsigned long long)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(longLongValue)]) {
			return [object unsignedLongLongValue];
		}

		return defaultValue;
	}
}

- (double)doubleForKey:(id)key orUseDefault:(double)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(doubleValue)]) {
			return [object doubleValue];
		}

		return defaultValue;
	}
}

- (float)floatForKey:(id)key orUseDefault:(float)defaultValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if ([object respondsToSelector:@selector(floatValue)]) {
			return [object floatValue];
		}

		return defaultValue;
	}
}

- (void)assignObjectTo:(__strong id *)pointer forKey:(id)key
{
	[self assignObjectTo:pointer forKey:key performCopy:YES];
}

- (void)assignObjectTo:(__strong id *)pointer forKey:(id)key performCopy:(BOOL)copyValue
{
	NSParameterAssert(key != nil);

	@synchronized(self) {
		id object = self[key];

		if (copyValue == NO) {
			*pointer = object;
		} else {
			if ([object conformsToProtocol:@protocol(NSCopying)]) {
				*pointer = [object copy];
			}
		}
	}
}

- (void)assignStringTo:(__strong NSString **)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	NSString *object = [self stringForKey:key];

	if (object) {
		*pointer = [object copy];
	}
}

- (void)assignBoolTo:(BOOL *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object boolValue];
		}
	}
}

- (void)assignArrayTo:(__strong NSArray **)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	NSArray *object = [self arrayForKey:key];

	if (object) {
		*pointer = [object copy];
	}
}

- (void)assignDictionaryTo:(__strong NSDictionary **)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	NSDictionary *object = [self dictionaryForKey:key];

	if (object) {
		*pointer = [object copy];
	}
}

- (void)assignIntegerTo:(NSInteger *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object integerValue];
		}
	}
}

- (void)assignUnsignedIntegerTo:(NSUInteger *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object unsignedIntegerValue];
		}
	}
}

- (void)assignShortTo:(short *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object shortValue];
		}
	}
}

- (void)assignUnsignedShortTo:(unsigned short *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object unsignedShortValue];
		}
	}
}

- (void)assignLongTo:(long *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object longValue];
		}
	}
}

- (void)assignUnsignedLongTo:(unsigned long *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object unsignedLongValue];
		}
	}
}

- (void)assignLongLongTo:(long long *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object longLongValue];
		}
	}
}

- (void)assignUnsignedLongLongTo:(unsigned long long *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object unsignedLongLongValue];
		}
	}
}

- (void)assignDoubleTo:(double *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object doubleValue];
		}
	}
}

- (void)assignFloatTo:(float *)pointer forKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		id object = self[key];

		if ([object isKindOfClass:[NSNumber class]]) {
			*pointer = [object floatValue];
		}
	}
}

- (BOOL)containsKey:(id)key
{
	NSParameterAssert(key != nil);

	@synchronized (self) {
		return (self[key] != nil);
	}
}
	
- (BOOL)containsKeyIgnoringCase:(id)key
{
	id caselessKey = [self keyIgnoringCase:key];
	
	return (caselessKey != nil);
}

- (nullable id)firstKeyForObject:(id)anObject
{
	NSParameterAssert(anObject != nil);

	if (self.count == 0) {
		return nil;
	}

	NSSet *keys =
	[self keysOfEntriesPassingTest:^BOOL(id key, id object, BOOL *stop) {
		if (NSObjectsAreEqual(object, anObject)) {
			*stop = YES;

			return YES;
		} else {
			return NO;
		}
	}];

	if (keys.count == 0) {
		return nil;
	}

	return [keys anyObject];
}

- (nullable id)keyIgnoringCase:(id)key
{
	if (self.count == 0) {
		return nil;
	}

	NSSet *keys =
	[self keysOfEntriesPassingTest:^BOOL(id objectKey, id object, BOOL *stop) {
		if ([objectKey isEqualIgnoringCase:key]) {
			*stop = YES;

			return YES;
		} else {
			return NO;
		}
	}];

	if (keys.count == 0) {
		return nil;
	}

	return [keys anyObject];
}

- (NSArray *)sortedDictionaryKeys
{
	return [self sortedDictionaryKeys:NO];
}

- (NSArray *)sortedDictionaryKeysReversed
{
	return [self sortedDictionaryKeys:YES];
}

- (NSArray *)sortedDictionaryKeys:(BOOL)reversed
{
	if (self.count == 0) {
		return @[];
	}

	NSArray *keys = [self.allKeys sortedArrayUsingSelector:@selector(compare:)];
	
	if (reversed) {
		return [keys reverseObjectEnumerator].allObjects;
	}

	return keys;
}

- (NSDictionary *)dictionaryByRemovingDefaults:(nullable NSDictionary *)defaults
{
	return [self dictionaryByRemovingDefaults:defaults allowEmptyValues:NO];
}

- (NSDictionary *)dictionaryByRemovingDefaults:(nullable NSDictionary *)defaults allowEmptyValues:(BOOL)allowEmptyValues
{
	if (self.count == 0) {
		return self;
	}

	if (defaults == nil && allowEmptyValues == YES) {
		return self;
	}

	NSMutableDictionary *newDictionary = [NSMutableDictionary dictionary];

	@synchronized (self) {
		[self enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
			if (NSObjectIsEmpty(object)) {
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

				if (allowEmptyValues == NO) {
					return;
				}
			} else if (defaults && NSObjectsAreEqual(object, defaults[key])) {
				return;
			}

			newDictionary[key] = object;
		}];
	}

	return [newDictionary copy];
}

- (NSDictionary *)dictionaryByAddingEntries:(NSDictionary *)entries
{
	NSParameterAssert(entries != nil);

	if (self.count == 0) {
		return [entries copy];
	}

	@synchronized (self) {
		NSMutableDictionary *dictionary = [self mutableCopy];

		[dictionary addEntriesFromDictionary:entries];

		return [dictionary copy];
	}
}

- (NSString *)formDataUsingSeparator:(NSString *)separator
{
	return [self formDataUsingSeparator:separator encodingBlock:^NSString *(NSString *value) {
		return value.percentEncodedString;
	}];
}

- (NSString *)formDataUsingSeparator:(NSString *)separator encodingBlock:(NSString *(NS_NOESCAPE ^)(NSString *value))encodingBlock
{
	if (self.count == 0) {
		return @"";
	}
	
	NSMutableArray<NSString *> *queryItems = [NSMutableArray array];

	@synchronized (self) {
		[self enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
			/* Key */
			NSString *stringKey = nil;

			if ([key isKindOfClass:[NSString class]]) {
				stringKey = key;
			} else if ([key isKindOfClass:[NSNumber class]]) {
				stringKey = ((NSNumber *)key).stringValue;
			}
			
			if (stringKey == nil) {
				return;
			}
			
			/* Object */
			NSString *stringObject = nil;

			if ([object isKindOfClass:[NSString class]]) {
				stringObject = object;
			} else if ([object isKindOfClass:[NSNumber class]]) {
				stringObject = ((NSNumber *)object).stringValue;
			} else if ([object isKindOfClass:[NSNull class]]) {
				stringObject = @"";
			}
			
			if (stringObject == nil) {
				return;
			}
			
			/* Query item */
			NSString *queryItem = [NSString stringWithFormat:@"%@=%@", stringKey, encodingBlock(stringObject)];
			
			[queryItems addObject:queryItem];
		}];
	}
	
	return [queryItems componentsJoinedByString:separator];
}

@end

@implementation NSMutableDictionary (CSMutableDictionaryHelper)

- (void)setObjectWithoutOverride:(id)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	if (value == nil) {
		return;
	}

	if (self[key] == nil) {
		self[key] = value;
	}
}

- (void)maybeSetObject:(nullable id)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	if (value == nil) {
		return;
	}

	self[key] = value;
}

- (void)setBool:(BOOL)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setInteger:(NSInteger)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setUnsignedInteger:(NSUInteger)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setShort:(short)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setUnsignedShort:(unsigned short)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setLong:(long)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setUnsignedLong:(unsigned long)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setLongLong:(long long)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setUnsignedLongLong:(unsigned long long)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setDouble:(double)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setFloat:(float)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = @(value);
}

- (void)setPointer:(void *)value forKey:(id)key
{
	NSParameterAssert(key != nil);

	self[key] = [NSValue valueWithPointer:value];
}

- (void)performSelectorOnObjectValueAndReplace:(SEL)performSelector
{
	NSParameterAssert(performSelector != NULL);

	if (self.count == 0) {
		return;
	}

	@synchronized(self) {
		NSDictionary *oldDictionary = [self copy];

		[oldDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
			NSMethodSignature *methodSignature = [object methodSignatureForSelector:performSelector];

			NSAssert1((*(methodSignature.methodReturnType) == '@'),
				@"Selector '%@' does not return an object value.",
				NSStringFromSelector(performSelector));

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
			id newObject = [object performSelector:performSelector];
#pragma GCC diagnostic pop

			NSAssert2((newObject != nil),
				@"Object %@ returned a nil value when performing selector '%@'",
				[object description], NSStringFromSelector(performSelector));

			self[key] = newObject;
		}];
	}
}

@end

NS_ASSUME_NONNULL_END
