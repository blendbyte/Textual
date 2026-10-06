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

#import <CommonCrypto/CommonDigest.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSData (CSDataHelper)

- (NSRange)range
{
	return NSMakeRange(0, self.length);
}

+ (NSData *)lineFeed
{
	return [NSData dataWithBytes:"\x0a" length:1];
}

+ (NSData *)carriageReturn
{
	return [NSData dataWithBytes:"\x0d" length:1];
}

+ (NSData *)carriageReturnPlusLineFeed
{
	return [NSData dataWithBytes:"\x0d\x0a" length:2];
}

+ (NSData *)emptyObject
{
	return [NSData dataWithBytes:"" length:1];
}

- (BOOL)isValidUTF8
{
	NSUInteger length = self.length;
	
	const unsigned char *bytes = self.bytes;
	
	NSUInteger rest = 0;
	NSUInteger code = 0;
	
	NSRange range;
	
	for (NSUInteger i = 0; i < length; i++) {
		unsigned char c = bytes[i];
		
		if (rest <= 0) {
			if (0x1 <= c && c <= 0x7F) {
				rest = 0;
			} else if (0xC0 <= c && c <= 0xDF) {
				rest = 1;
				code = (c & 0x1F);
				range = NSMakeRange(0x00080, (0x000800 - 0x00080));
			} else if (0xE0 <= c && c <= 0xEF) {
				rest = 2;
				code = (c & 0x0F);
				range = NSMakeRange(0x00800, (0x010000 - 0x00800));
			} else if (0xF0 <= c && c <= 0xF7) {
				rest = 3;
				code = (c & 0x07);
				range = NSMakeRange(0x10000, (0x110000 - 0x10000));
			} else {
				return NO;
			}
		} else if (0x80 <= c && c <= 0xBF) {
			code = ((code << 6) | (c & 0x3F));
			
			if (--rest <= 0) {
				if (NSLocationInRange(code, range) == NO || (0xD800 <= code && code <= 0xDFFF)) {
					return NO;
				}
			}
		} else {
			return NO;
		}
	}
	
	return YES;
}

- (NSString *)sha1
{
	uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
    CC_SHA1(self.bytes, (CC_LONG)self.length, digest);
	
    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_SHA1_DIGEST_LENGTH * 2)];
	
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
	
	return output;
}

- (NSString *)sha256
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(self.bytes, (CC_LONG)self.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_SHA256_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (NSString *)sha512
{
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];

    CC_SHA512(self.bytes, (CC_LONG)self.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_SHA512_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (NSString *)md5
{
    uint8_t digest[CC_MD5_DIGEST_LENGTH ];

COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
    CC_MD5(self.bytes, (CC_LONG)self.length, digest);
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_MD5_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_MD5_DIGEST_LENGTH ; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (void)enumerateMatchesOfData:(NSData *)data withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock
{
	[self enumerateMatchesOfData:data withBlock:enumerationBlock options:0];
}

- (void)enumerateMatchesOfData:(NSData *)data withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock options:(NSDataSearchOptions)options
{
	NSParameterAssert(data != nil);
	NSParameterAssert(enumerationBlock != nil);

	BOOL searchBackwards = ((options & NSDataSearchBackwards) == NSDataSearchBackwards);

	NSUInteger searchLength = self.length;

	NSUInteger currentPosition = 0;

	while ((searchBackwards == NO && currentPosition < searchLength) ||
		   (searchBackwards && searchLength > 0))
	{
		NSRange range = [self rangeOfData:data
								  options:options
									range:NSMakeRange(currentPosition, (searchLength - currentPosition))];

		if (range.location == NSNotFound) {
			break;
		}

		BOOL stop = NO;

		enumerationBlock(range, &stop);

		if (stop) {
			break;
		}

		if (searchBackwards) {
			searchLength = range.location;
		} else {
			currentPosition = (NSMaxRange(range) + 1);
		}
	}
}

@end

NS_ASSUME_NONNULL_END
