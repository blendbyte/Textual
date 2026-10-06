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

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSValue (CSValueHelper)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvoid-pointer-to-int-cast"

+ (id)valueWithPrimitive:(void *)value withType:(const char *)valueType
{
	/* See runtime.h header in Objective-C for return types. */
	switch (*valueType) {
		case _C_ID:
		{
			return (__bridge id)(value);
		}
		case _C_SHT:
		{
			return @((short)value);
		}
		case _C_USHT:
		{
			return @((unsigned short)value);
		}
		case _C_INT:
		{
			return @((int)value);
		}
		case _C_UINT:
		{
			return @((unsigned)value);
		}
		case _C_LNG:
		{
			return @((long)value);
		}
		case _C_ULNG:
		{
			return @((unsigned long)value);
		}
		case _C_LNG_LNG:
		{
			return @((long long)value);
		}
		case _C_ULNG_LNG:
		{
			return @((unsigned long long)value);
		}
		case _C_FLT:
		{
			return @(*(float *)value);
		}
		case _C_DBL:
		{
			return @(*(double *)value);
		}
		case _C_UCHR:
		{
			return @((unsigned char)value);
		}
		case _C_CHR:
		{
			if ((size_t)value == 1) {
				return @(YES);
			} else if (value == NULL) {
				return @(NO);
			} else {
				return @((char)value);
			}
		}
	}
	
	return [NSValue valueWithBytes:value objCType:valueType];
}

#pragma clang diagnostic pop

@end

NS_ASSUME_NONNULL_END
