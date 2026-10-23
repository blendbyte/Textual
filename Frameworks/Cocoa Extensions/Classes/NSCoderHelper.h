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

@interface NSCoder (CSCoderHelper)
- (nullable NSArray *)decodeArrayForKey:(NSString *)key;
- (nullable NSDictionary *)decodeDictionaryForKey:(NSString *)key;
- (nullable NSData *)decodeDataForKey:(NSString *)key;
- (nullable NSString *)decodeStringForKey:(NSString *)key;
- (NSUInteger)decodeUnsignedIntegerForKey:(NSString *)key;
- (short)decodeShortForKey:(NSString *)key;
- (unsigned short)decodeUnsignedShortForKey:(NSString *)key;
- (long)decodeLongForKey:(NSString *)key;
- (unsigned long)decodeUnsignedLongForKey:(NSString *)key;
- (long long)decodeLongLongForKey:(NSString *)key;
- (unsigned long long)decodeUnsignedLongLongForKey:(NSString *)key;

- (void)encodeArray:(NSArray *)value forKey:(NSString *)key;
- (void)encodeDictionary:(NSDictionary *)value forKey:(NSString *)key;
- (void)encodeData:(NSData *)value forKey:(NSString *)key;
- (void)encodeString:(NSString *)value forKey:(NSString *)key;
- (void)encodeUnsignedInteger:(NSUInteger)value forKey:(NSString *)key;
- (void)encodeShort:(short)value forKey:(NSString *)key;
- (void)encodeUnsignedShort:(unsigned short)value forKey:(NSString *)key;
- (void)encodeLong:(long)value forKey:(NSString *)key;
- (void)encodeUnsignedLong:(unsigned long)value forKey:(NSString *)key;
- (void)encodeLongLong:(long long)value forKey:(NSString *)key;
- (void)encodeUnsignedLongLong:(unsigned long long)value forKey:(NSString *)key;

- (void)maybeEncodeObject:(nullable id)value forKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
