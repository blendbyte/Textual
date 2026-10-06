/* *********************************************************************
 *
 *         Copyright (c) 2016 - 2018 Codeux Software, LLC
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

@implementation NSCoder (CSCoderHelper)

- (nullable NSArray *)decodeArrayForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSArray *value = [self decodeObjectOfClass:[NSArray class] forKey:key];

	if (value == nil) {
		return nil;
	}

	return value;
}

- (nullable NSDictionary *)decodeDictionaryForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSDictionary *value = [self decodeObjectOfClass:[NSDictionary class] forKey:key];

	if (value == nil) {
		return nil;
	}

	return value;
}

- (nullable NSData *)decodeDataForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSData *value = [self decodeObjectOfClass:[NSData class] forKey:key];

	if (value == nil) {
		return nil;
	}

	return value;
}

- (nullable NSString *)decodeStringForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSString *value = [self decodeObjectOfClass:[NSString class] forKey:key];

	if (value == nil) {
		return nil;
	}

	return value;
}

- (NSUInteger)decodeUnsignedIntegerForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.unsignedIntegerValue;
}

- (short)decodeShortForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.shortValue;
}

- (unsigned short)decodeUnsignedShortForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.unsignedShortValue;
}

- (long)decodeLongForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.longValue;
}

- (unsigned long)decodeUnsignedLongForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.unsignedLongValue;
}

- (long long)decodeLongLongForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.longLongValue;
}

- (unsigned long long)decodeUnsignedLongLongForKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	NSNumber *value = [self decodeObjectOfClass:[NSNumber class] forKey:key];

	if (value == nil) {
		return 0;
	}

	return value.unsignedLongLongValue;
}

- (void)encodeArray:(NSArray *)value forKey:(NSString *)key
{
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);

	[self encodeObject:value forKey:key];
}

- (void)encodeDictionary:(NSDictionary *)value forKey:(NSString *)key
{
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);

	[self encodeObject:value forKey:key];
}

- (void)encodeData:(NSData *)value forKey:(NSString *)key
{
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);

	[self encodeObject:value forKey:key];
}

- (void)encodeString:(NSString *)value forKey:(NSString *)key
{
	NSParameterAssert(value != nil);
	NSParameterAssert(key != nil);

	[self encodeObject:value forKey:key];
}

- (void)encodeUnsignedInteger:(NSUInteger)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)encodeShort:(short)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)encodeUnsignedShort:(unsigned short)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)encodeLong:(long)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)encodeUnsignedLong:(unsigned long)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)encodeLongLong:(long long)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)encodeUnsignedLongLong:(unsigned long long)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	[self encodeObject:@(value) forKey:key];
}

- (void)maybeEncodeObject:(nullable id)value forKey:(NSString *)key
{
	NSParameterAssert(key != nil);

	if (value == nil) {
		return;
	}

	[self encodeObject:value forKey:key];
}

@end

NS_ASSUME_NONNULL_END
