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

@implementation NSUserDefaults (CSUserDefaultsHelper)

- (void)setColor:(nullable NSColor *)value forKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	if (value == nil) {
		[self setObject:nil forKey:defaultName];
	} else {
		NSError *error;

		NSData *archivedValue = [NSKeyedArchiver archivedDataWithRootObject:value
													  requiringSecureCoding:YES
																	  error:&error];
		
		NSAssert((error != nil), @"Failed to write contents of '%@': %@",
				 defaultName, error.description);
		
		[self setObject:archivedValue forKey:defaultName];
	}
}

- (void)setUnsignedInteger:(NSUInteger)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (void)setShort:(short)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (void)setUnsignedShort:(unsigned short)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (void)setLong:(long)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (void)setUnsignedLong:(unsigned long)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (void)setLongLong:(long long)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (void)setUnsignedLongLong:(unsigned long long)value forKey:(NSString *)defaultName
{
	[self setObject:@(value) forKey:defaultName];
}

- (nullable NSColor *)colorForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSData class]]) {
		NSColor *color =
		[NSKeyedUnarchiver legacyCompatUnarchivedObjectOfClass:[NSColor class]
													  fromData:object];
		
		return color;
	}

	return nil;
}

- (NSUInteger)unsignedIntegerForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object unsignedIntegerValue];
	}

	return 0;
}

- (short)shortForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object shortValue];
	}

	return 0;
}

- (unsigned short)unsignedShortForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object unsignedShortValue];
	}

	return 0;
}

- (long)longForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object longValue];
	}

	return 0;
}

- (unsigned long)unsignedLongForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object unsignedLongValue];
	}

	return 0;
}

- (long long)longLongForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object longLongValue];
	}

	return 0;
}

- (unsigned long long)unsignedLongLongForKey:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	id object = [self objectForKey:defaultName];

	if ([object isKindOfClass:[NSNumber class]]) {
		return [object unsignedLongLongValue];
	}

	return 0;
}

@end

NS_ASSUME_NONNULL_END
