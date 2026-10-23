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

#import <WebKit/WebKit.h>

#include <arpa/inet.h>

NS_ASSUME_NONNULL_BEGIN

NSString * const NSStringEmptyPlaceholder = @"";
NSString * const NSStringNewlinePlaceholder = @"\x0a";
NSString * const NSStringWhitespacePlaceholder = @"\x20";

NSString * const CS_UnicodeReplacementCharacter = @"�";

@implementation NSString (CStringHelper)

+ (nullable instancetype)stringWithBytes:(const void *)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding
{
	return [[NSString alloc] initWithBytes:bytes length:length encoding:encoding];
}

+ (nullable instancetype)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding
{
	return [[NSString alloc] initWithData:data encoding:encoding];
}

- (NSRange)range
{
	return NSMakeRange(0, self.length);
}

+ (NSString *)stringWithUUID
{
	CFUUIDRef uuidObj = CFUUIDCreate(nil);
	
	NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(nil, uuidObj);
	
	CFRelease(uuidObj);

	return uuidString;
}

+ (nullable NSString *)charsetRepFromStringEncoding:(NSStringEncoding)encoding
{
	CFStringEncoding foundationEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);

	CFStringRef charsetString = CFStringConvertEncodingToIANACharSetName(foundationEncoding);

	if (charsetString) {
		return (__bridge NSString *)(charsetString);
	} else {
		return nil;
	}
}

+ (NSDictionary<NSString *, NSNumber *> *)supportedStringEncodingsWithTitle:(BOOL)favorUTF8
{
    NSMutableDictionary<NSString *, NSNumber *> *encodingList = [NSMutableDictionary dictionary];

    NSArray *supportedEncodings = [NSString supportedStringEncodings:favorUTF8];

    for (NSNumber *encoding in supportedEncodings) {
        NSString *encodingTitle = [NSString localizedNameOfStringEncoding:encoding.unsignedIntegerValue];

		if (encodingTitle) {
			encodingList[encodingTitle] = encoding;
		}
    }

    return encodingList;
}

+ (NSArray<NSNumber *> *)supportedStringEncodings:(BOOL)favorUTF8
{
    NSMutableArray *encodingList = [NSMutableArray array];

    const NSStringEncoding *encodings = [NSString availableStringEncodings];

    if (favorUTF8) {
        [encodingList addObject:@(NSUTF8StringEncoding)];
    }

    while (1 == 1) {
        NSStringEncoding encoding = (*encodings++);

        if (encoding == 0) {
            break;
        }

        if (favorUTF8 && encoding == NSUTF8StringEncoding) {
            continue;
        }
		
		[encodingList addObject:@(encoding)];
    }

    return encodingList;
}

- (NSString *)stringCharacterAtIndex:(NSUInteger)anIndex
{
	UniChar strChar = [self characterAtIndex:anIndex];

	return [[NSString alloc] initWithCharacters:&strChar length:1];
}

- (NSString *)substringAfterIndex:(NSUInteger)anIndex
{
	return [self substringFromIndex:(anIndex + 1)];
}

- (NSString *)substringBeforeIndex:(NSUInteger)anIndex
{
	return [self substringFromIndex:(anIndex - 1)];
}

- (NSString *)substringAtIndex:(NSInteger)atIndex toLength:(NSInteger)toLength
{
	/* Perform normal substring */
	if (atIndex >= 0 && toLength >= 0) {
		return [self substringWithRange:NSMakeRange(atIndex, toLength)];
	}

	/* Perform negative substring */
	NSUInteger stringLength = self.length;
	
	NSInteger substringLocation = 0;
	NSInteger substringLength = 0;

	if (atIndex < 0 && toLength < 0) {
		substringLocation = (0 - atIndex);
		substringLength = ((atIndex + toLength) + stringLength);
	} else if (atIndex < 0) {
		substringLength = (stringLength + atIndex);
	} else if (toLength < 0) {
		substringLocation = (stringLength + toLength);
		substringLength = (0 - toLength);
	}

	NSAssert((substringLocation >= 0 &&
			  substringLocation <= stringLength), @"Location is out of range");
	
	NSAssert((substringLength >= 0 &&
			  substringLength <= stringLength), @"Length is out of range");
	
	return [self substringWithRange:NSMakeRange(substringLocation, substringLength)];
}

- (NSString *)substringFromIndex:(NSUInteger)atIndex toIndex:(NSUInteger)toIndex
{
	NSParameterAssert(atIndex <= toIndex);

	NSInteger substringLocation = atIndex;
	NSInteger substringLength = (toIndex - atIndex);

	return [self substringWithRange:NSMakeRange(substringLocation, substringLength)];
}

- (BOOL)isEqualIgnoringCase:(id)other
{
	if ([other isKindOfClass:[NSString class]] == NO) {
		return NO;
	}

	return [self isEqualToStringIgnoringCase:other];
}

- (BOOL)isEqualToStringIgnoringCase:(NSString *)other
{
	if (self == other) {
		return YES;
	}

	return ([self caseInsensitiveCompare:other] == NSOrderedSame);
}

- (BOOL)contains:(NSString *)string
{
	return ([self stringPosition:string] >= 0);
}

- (BOOL)containsIgnoringCase:(NSString *)string
{
	return ([self stringPositionIgnoringCase:string] >= 0);
}

- (NSArray<NSString *> *)characterStringBuffer
{
	NSUInteger selfLength = self.length;

	if (selfLength == 0) {
		return @[];
	}

	NSMutableArray<NSString *> *buffer = [NSMutableArray arrayWithCapacity:selfLength];

	[self enumerateSubstringsInRange:self.range
							 options:NSStringEnumerationByComposedCharacterSequences
						  usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
							  [buffer addObject:substring];
						  }];

	return [buffer copy];
}

- (nullable NSString *)sha1
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];

	NSParameterAssert(data != nil);

    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
	
    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_SHA1_DIGEST_LENGTH * 2)];
	
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
	
    return output;
}

- (nullable NSString *)sha256
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];

	NSParameterAssert(data != nil);

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_SHA256_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (nullable NSString *)sha512
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];

    NSParameterAssert(data != nil);

    uint8_t digest[CC_SHA512_DIGEST_LENGTH];

    CC_SHA512(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_SHA512_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (nullable NSString *)md5
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];

	NSParameterAssert(data != nil);

    uint8_t digest[CC_MD5_DIGEST_LENGTH];

COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

    NSMutableString *output = [NSMutableString stringWithCapacity:(CC_MD5_DIGEST_LENGTH * 2)];

    for (int i = 0; i < CC_MD5_DIGEST_LENGTH ; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (NSArray<NSString *> *)split:(NSString *)delimiter
{
	NSParameterAssert(delimiter != nil);

	return [self componentsSeparatedByString:delimiter];
}

- (void)enumerateSplit:(NSString *)delimiter withBlock:(void (NS_NOESCAPE ^)(NSString *sequence, BOOL *stop))enumerationBlock
{
	NSParameterAssert(delimiter != nil);
	NSParameterAssert(enumerationBlock != nil);

	NSArray *sequences = [self componentsSeparatedByString:delimiter];

	[sequences enumerateObjectsUsingBlock:^(NSString *sequence, NSUInteger idx, BOOL *stop) {
		enumerationBlock(sequence, stop);
	}];
}

- (void)enumerateSplitWithCharacterSet:(NSCharacterSet *)characterSet withBlock:(void (NS_NOESCAPE ^)(NSString *sequence, BOOL *stop))enumerationBlock
{
	NSParameterAssert(characterSet != nil);
	NSParameterAssert(enumerationBlock != nil);

	NSArray *sequences = [self componentsSeparatedByCharactersInSet:characterSet];

	[sequences enumerateObjectsUsingBlock:^(NSString *sequence, NSUInteger idx, BOOL *stop) {
		enumerationBlock(sequence, stop);
	}];
}

- (void)enumerateSplitOnNewLinesWithBlock:(void (NS_NOESCAPE ^)(NSString *sequence, BOOL *stop))enumerationBlock
{
	NSParameterAssert(enumerationBlock != nil);

	[self enumerateSplitWithCharacterSet:[NSCharacterSet newlineCharacterSet] withBlock:enumerationBlock];
}

- (NSArray<NSString *> *)splitWithCharacters:(NSString *)characters
{
	NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:characters];

	return [self splitWithCharacterSet:characterSet];
}

- (NSArray<NSString *> *)splitWithCharacterSet:(NSCharacterSet *)characterSet
{
	return [self componentsSeparatedByCharactersInSet:characterSet];
}

- (NSArray<NSString *> *)splitWithMaximumLength:(NSUInteger)maximumLength
{
	NSParameterAssert(maximumLength > 0);

	NSUInteger stringLength = self.length;

	if (stringLength == 0) {
		return @[];
	} else if (stringLength <= maximumLength) {
		return @[self];
	}

	NSMutableArray<NSString *> *splitStrings = [NSMutableArray array];

	NSUInteger processedLength = 0;

	while (processedLength < stringLength) {
		NSUInteger remainingLength = (stringLength - processedLength);

		if (remainingLength > maximumLength) {
			remainingLength = maximumLength;
		}

		NSString *line = [self substringWithRange:NSMakeRange(processedLength, remainingLength)];

		[splitStrings addObject:line];

		processedLength += remainingLength;
	}

	return [splitStrings copy];
}

- (NSString *)trim
{
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)trimNewlines
{
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (NSString *)trimCharacters:(NSString *)characters
{
	NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:characters];

	return [self stringByTrimmingCharactersInSet:characterSet];
}

- (NSString *)removeAllNewlines
{
	return [self stringByReplacingOccurrencesOfCharacterSet:[NSCharacterSet newlineCharacterSet] withString:@""];
}

- (NSString *)stringByReplacingOccurrencesOfCharacterSet:(NSCharacterSet *)characterSet withString:(NSString *)replacement
{
	NSParameterAssert(characterSet != nil);
	NSParameterAssert(replacement != nil);
	
	if (self.length == 0) {
		return self;
	}

	CFStringRef cfSelf = (__bridge CFStringRef)self;

	CFIndex cfSelfLength = CFStringGetLength(cfSelf);

	CFCharacterSetRef cfCharacterSet = (__bridge CFCharacterSetRef)characterSet;
	
	CFStringInlineBuffer inlineBuffer;
	CFStringInitInlineBuffer(cfSelf, &inlineBuffer, CFRangeMake(0, cfSelfLength));
	
	NSMutableString *mutableSelf = nil;
	
	NSUInteger replacementLength = replacement.length;
	
	/* We reverse the buffer because it allows us to perform replacement
	 in the mutableSelf buffer without accounting for length offset. */
	for (CFIndex i = (cfSelfLength - 1); i >= 0; i--) {
		UniChar c = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, i);

		if (CFCharacterSetIsCharacterMember(cfCharacterSet, c)) {
			if (mutableSelf == nil) {
				mutableSelf = [self mutableCopy];
			}
			
			if (replacementLength == 0) {
				[mutableSelf deleteCharactersInRange:NSMakeRange(i, 1)];
			} else {
				[mutableSelf replaceCharactersInRange:NSMakeRange(i, replacementLength) withString:replacement];
			}
		}
	}
	
	/* If mutableSelf is nil, we never had to perform a replacement. */
	if (mutableSelf) {
		return [mutableSelf copy];
	}
	
	return self;
}

- (BOOL)hasPrefixIgnoringCase:(NSString *)aString
{
	NSRange prefixRange = [self rangeOfString:aString options:(NSAnchoredSearch | NSLiteralSearch | NSCaseInsensitiveSearch)];
	
	return (prefixRange.location == 0 && prefixRange.length > 0);
}

- (BOOL)hasSuffixIgnoringCase:(NSString *)aString
{
	NSRange suffixRange = [self rangeOfString:aString options:(NSAnchoredSearch | NSLiteralSearch | NSCaseInsensitiveSearch | NSBackwardsSearch)];

	return ((suffixRange.length + suffixRange.location) == self.length);
}

- (BOOL)hasPrefixWithCharacterSet:(NSCharacterSet *)characterSet
{
	NSRange prefixRange = [self rangeOfCharacterFromSet:characterSet options:NSAnchoredSearch];

	return (prefixRange.location == 0 && prefixRange.length > 0);
}

- (BOOL)hasSuffixWithCharacterSet:(NSCharacterSet *)characterSet
{
	NSRange suffixRange = [self rangeOfCharacterFromSet:characterSet options:(NSAnchoredSearch | NSBackwardsSearch)];

	return ((suffixRange.length + suffixRange.location) == self.length);
}

- (CGFloat)compareWithWord:(NSString *)stringB lengthPenaltyWeight:(CGFloat)weight
{
	if (stringB == nil || stringB.length == 0) {
		return 0.0;
	}

	if (stringB.length > self.length) {
		return 0.0;
	}

	CFStringRef cfStringA = (__bridge_retained CFStringRef)self.lowercaseString;
	CFStringRef cfStringB = (__bridge_retained CFStringRef)stringB.lowercaseString;

	CFIndex cfStringALength = CFStringGetLength(cfStringA);
	CFIndex cfStringBLength = CFStringGetLength(cfStringB);

	CFStringInlineBuffer cfStringABuffer;
	CFStringInitInlineBuffer(cfStringA, &cfStringABuffer, CFRangeMake(0, cfStringALength));

	CFStringInlineBuffer cfStringBBuffer;
	CFStringInitInlineBuffer(cfStringB, &cfStringBBuffer, CFRangeMake(0, cfStringBLength));

	NSInteger commonCharacterCount = 0;

	NSInteger startPosition = 0;

	CGFloat distancePenalty = 0;

	for (NSInteger i = 0; i < cfStringBLength; i++) {
		BOOL matchFound = NO;

		for (NSInteger j = startPosition; j < cfStringALength; j++) {
			if (CFStringGetCharacterFromInlineBuffer(&cfStringBBuffer, i) !=
				CFStringGetCharacterFromInlineBuffer(&cfStringABuffer, j))
			{
				continue;
			}

			NSInteger distance = (j - startPosition);

			if (distance > 0) {
				distancePenalty += ((distance - 1.0) / distance);
			}

			commonCharacterCount++;

			startPosition = (j + 1);

			matchFound = YES;

			break;
		}

		if (matchFound == NO) {
			CFRelease(cfStringA);
			CFRelease(cfStringB);
			
			return 0.0;
		}
	}
	
	CFRelease(cfStringA);
	CFRelease(cfStringB);

	CGFloat lengthPenalty = (1.0 - (CGFloat)cfStringBLength / cfStringALength);

	return (commonCharacterCount - distancePenalty - weight * lengthPenalty);
}

- (NSInteger)stringPosition:(NSString *)needle options:(NSStringCompareOptions)options
{
	if (self.length == 0) {
		return (-1);
	}

	NSRange searchResult = [self rangeOfString:needle options:options];
	
	if (searchResult.location == NSNotFound) {
		return (-1);
	}
	
	return searchResult.location;
}

- (NSInteger)stringPosition:(NSString *)needle
{
	return [self stringPosition:needle options:NSLiteralSearch];
}

- (NSInteger)stringPositionIgnoringCase:(NSString *)needle
{
	return [self stringPosition:needle options:(NSLiteralSearch | NSCaseInsensitiveSearch)];
}

- (void)enumerateMatchesOfString:(NSString *)string withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock
{
	[self enumerateMatchesOfString:string withBlock:enumerationBlock options:0];
}

- (void)enumerateMatchesOfString:(NSString *)string withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock options:(NSStringCompareOptions)options
{
	NSParameterAssert(string != nil);
	NSParameterAssert(enumerationBlock != nil);

	NSUInteger searchLength = self.length;

	if (searchLength == 0) {
		return;
	}
	
	BOOL searchBackwards = ((options & NSBackwardsSearch) == NSBackwardsSearch);

	NSUInteger currentPosition = 0;

	while ((searchBackwards == NO && currentPosition < searchLength) ||
		   (searchBackwards && searchLength > 0))
	{
		NSRange range = [self rangeOfString:string
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
			currentPosition = NSMaxRange(range);
		}
	}
}

- (void)enumerateMatchesOfRegularExpression:(NSString *)expression withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock
{
	[self enumerateMatchesOfRegularExpression:expression withBlock:enumerationBlock options:0];
}

- (void)enumerateMatchesOfRegularExpression:(NSString *)expression withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock options:(NSStringCompareOptions)options
{
	[self enumerateMatchesOfString:expression withBlock:enumerationBlock options:(options | NSRegularExpressionSearch)];
}

- (void)enumerateFirstOccurrenceOfCharactersInString:(NSString *)string withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock
{
	[self enumerateFirstOccurrenceOfCharactersInString:string withBlock:enumerationBlock options:0];
}

- (void)enumerateFirstOccurrenceOfCharactersInString:(NSString *)string withBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))enumerationBlock options:(NSStringCompareOptions)options
{
	NSParameterAssert(string != nil);
	NSParameterAssert(enumerationBlock != nil);

	NSUInteger searchLength = self.length;

	if (searchLength == 0) {
		return;
	}

	BOOL searchBackwards = ((options & NSBackwardsSearch) == NSBackwardsSearch);

	NSUInteger currentPosition = 0;

	NSArray *stringCharacters = string.characterStringBuffer;

	for (NSString *stringCharacter in stringCharacters) {
		NSRange range = [self rangeOfString:stringCharacter
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
			currentPosition = NSMaxRange(range);
		}
	}
}

- (NSString *)stringByDeletingPrefix:(NSString *)prefix
{
	if (self.length == 0) {
		return self;
	}

	if ([self hasPrefix:prefix]) {
		return [self substringFromIndex:prefix.length];
	}
	
	return self;
}

- (BOOL)isIPAddress
{
	return (self.IPv4Address || self.IPv6Address);
}

- (BOOL)isIPv4Address
{
	return (self.IPv4AddressBytes != nil);
}

- (BOOL)isIPv6Address
{
	return (self.IPv6AddressBytes != nil);
}

- (nullable NSData *)IPv4AddressBytes
{
	if (self.length == 0) {
		return nil;
	}

	struct sockaddr_in sa;

	int result = inet_pton(AF_INET, self.UTF8String, &(sa.sin_addr));

	if (result == 1) {
		return [NSData dataWithBytes:&(sa.sin_addr.s_addr) length:4];
	} else {
		return nil;
	}
}

- (nullable NSData *)IPv6AddressBytes
{
	if (self.length == 0) {
		return nil;
	}

	struct sockaddr_in6 sa;

	int result = inet_pton(AF_INET6, self.UTF8String, &(sa.sin6_addr));

	if (result == 1) {
		return [NSData dataWithBytes:&(sa.sin6_addr) length:16];
	} else {
		return nil;
	}
}

- (NSString *)safeFilename
{
	if (self.length == 0) {
		return self;
	}

	NSString *bob = self.trim;

	bob = [bob stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	bob = [bob stringByReplacingOccurrencesOfString:@":" withString:@"_"];

    BOOL excludeBars = [[NSUserDefaults standardUserDefaults] boolForKey:@"Cocoa Extensions Framework -> Exclude Bars from Safe Filenames"];

    if (excludeBars) {
        bob = [bob stringByReplacingOccurrencesOfString:@"|" withString:@"_"];
    }

	return bob;
}

- (NSUInteger)occurrencesOfCharacter:(UniChar)character
{
	if (self.length == 0) {
		return 0;
	}

	NSUInteger characterCount = 0;

	CFStringRef cfSelf = (__bridge CFStringRef)self;

	CFIndex cfSelfLength = CFStringGetLength(cfSelf);

	CFStringInlineBuffer inlineBuffer;
	CFStringInitInlineBuffer(cfSelf, &inlineBuffer, CFRangeMake(0, cfSelfLength));

	for (CFIndex i = 0; i < cfSelfLength; i++) {
		UniChar c = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, i);

		if (c == character) {
			characterCount += 1;
		}
	}

	return characterCount;
}

- (BOOL)isPositiveWholeNumber
{
	return [self contentsIsOfType:(CSStringTypeWholeNumber | CSStringTypePositiveNumber)];
}

- (BOOL)isPositiveDecimalNumber
{
	return [self contentsIsOfType:(CSStringTypeDecimalNumber | CSStringTypePositiveNumber)];
}

- (BOOL)isAnyPositiveNumber
{
	return [self contentsIsOfType:(CSStringTypeWholeNumber | CSStringTypeDecimalNumber | CSStringTypePositiveNumber)];
}

- (BOOL)isNumericOnly
{
	return [self contentsIsOfType:(CSStringTypeWholeNumber | CSStringTypePositiveNumber)];
}

- (BOOL)isAlphabeticNumericOnly
{
	return [self contentsIsOfType:(CSStringTypeWholeNumber | CSStringTypePositiveNumber | CSStringTypeAlphabetic)];
}

- (BOOL)contentsIsOfType:(CSStringType)type
{
	if (self.length == 0) {
		return NO;
	}

	if (type == CSStringTypeAny) {
		return YES;
	}

	BOOL matchWholeNumber = ((type & CSStringTypeWholeNumber) == CSStringTypeWholeNumber);
	BOOL matchDecimalNumber = ((type & CSStringTypeDecimalNumber) == CSStringTypeDecimalNumber);
	BOOL matchPositiveNumber = ((type & CSStringTypePositiveNumber) == CSStringTypePositiveNumber);
	BOOL matchNegativeNumber = ((type & CSStringTypeNegativeNumber) == CSStringTypeNegativeNumber);
	BOOL matchNumber = (matchWholeNumber || matchDecimalNumber);

	/* If we aren't matching either type of number, we force positive. */
	if (matchPositiveNumber == NO && matchNegativeNumber == NO) {
		matchPositiveNumber = YES;
	}

	BOOL matchAlphabet = ((type & CSStringTypeAlphabetic) == CSStringTypeAlphabetic);

	BOOL decimalMatched = NO;

	CFStringRef cfSelf = (__bridge CFStringRef)self;

	CFIndex cfSelfLength = CFStringGetLength(cfSelf);

	CFStringInlineBuffer inlineBuffer;
	CFStringInitInlineBuffer(cfSelf, &inlineBuffer, CFRangeMake(0, cfSelfLength));

	for (CFIndex i = 0; i < cfSelfLength; i++) {
		UniChar c = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, i);

		if (matchNumber) {
			/* Check first character when matching number
			 so that we can return on negative or positive. */
			if (i == 0) {
				if (c == '-') {
					if (matchNegativeNumber == NO) {
						return NO;
					}
				} else {
					if (matchPositiveNumber == NO) {
						return NO;
					}
				} // c == '-'
			} // i == 0

			/* Match decimal place */
			if (c == '.') {
				/* We only match decimal place for decimal numbers */
				if (matchDecimalNumber == NO) {
					return NO;
				}

				/* Do not allow more than one decimal place to appear */
				if (decimalMatched == NO) {
					decimalMatched = YES;
				} else {
					return NO;
				}
			} // c == '.'
		} // matchNumber

		/* All other conditions */
		if ((CS_StringIsAlphabetic(c) && matchAlphabet) ||
			(CS_StringIsBase10Numeric(c) && matchNumber))
		{
			/* Continue to next character */

			continue;
		}

		/* If we get to this point, then the character
		 was one that we are not interested in. */
		return NO;
	} // for

	/* If we never matched a decimal place, that might be a problem. */
	if (matchPositiveNumber == NO && matchDecimalNumber && decimalMatched == NO) {
		return NO;
	}

	return YES;
}

- (BOOL)containsCharactersFromCharacterSet:(NSCharacterSet *)characterSet
{
	NSParameterAssert(characterSet != nil);

	NSRange searchRange = [self rangeOfCharacterFromSet:characterSet];

	return (searchRange.location != NSNotFound);
}

- (BOOL)onlyContainsCharactersFromCharacterSet:(NSCharacterSet *)characterSet
{
	NSParameterAssert(characterSet != nil);

	NSRange searchRange = [self rangeOfCharacterFromSet:characterSet.invertedSet];

	return (searchRange.location == NSNotFound);
}

- (BOOL)containsCharacters:(NSString *)characters
{
	NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:characters];

	return [self containsCharactersFromCharacterSet:characterSet];
}

- (BOOL)onlyContainsCharacters:(NSString *)characters
{
	NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:characters];

	return [self onlyContainsCharactersFromCharacterSet:characterSet];
}

- (NSRange)rangeOfNextSegmentMatchingRegularExpression:(NSString *)regex startingAt:(NSUInteger)start
{
	NSParameterAssert(regex != nil);

	NSRange emptyRange = NSEmptyRange();

	NSUInteger stringLength = self.length;

	if (stringLength == 0 || stringLength <= start) {
		return emptyRange;
	}
	
	NSString *searchString = [self substringFromIndex:start];
	
	NSRange searchRange = [XRRegularExpression string:searchString rangeOfRegex:regex];

	if (searchRange.location == NSNotFound) {
		return emptyRange;
	}

	emptyRange.location = (start + searchRange.location);
	emptyRange.length = searchRange.length;

	return emptyRange;
}

- (nullable NSURL *)URLUsingWebKitPasteboard
{
	if (self.length == 0) {
		return nil;
	}

	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];

	pasteboard.stringContent = self;

COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
	NSURL *u = [WebView URLFromPasteboard:pasteboard];
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

	if (u == nil) {
		u = [NSURL URLWithString:self];
	}

	[pasteboard releaseGlobally];

	return u;
}

- (NSDictionary<NSString *, NSString *> *)formDataUsingSeparator:(NSString *)separator
{
	return [self formDataUsingSeparator:separator decodingBlock:^NSString *(NSString *value) {
		return value.percentDecodedString;
	}];
}

- (NSDictionary<NSString *, NSString *> *)formDataUsingSeparator:(NSString *)separator decodingBlock:(NSString *(NS_NOESCAPE ^)(NSString *value))decodingBlock
{
	NSParameterAssert(separator != nil);
	NSParameterAssert(decodingBlock != nil);
	
	if (self.length == 0) {
		return @{};
	}

	NSMutableDictionary<NSString *, NSString *> *queryItems = [NSMutableDictionary dictionary];
	
	NSArray *components = [self componentsSeparatedByString:separator];
	
	for (NSString *component in components) {
		if (component.length == 0) {
			continue;
		}
		
		NSInteger equalSignPosition = [component stringPosition:@"="];
		
		if (equalSignPosition < 0) { // not found
			queryItems[component] = @"";
		} else {
			NSString *name = [component substringToIndex:equalSignPosition];
		
			NSString *value = [component substringAfterIndex:equalSignPosition];
			
			queryItems[name] = decodingBlock(value);
		}
	}
	
	return [queryItems copy];
}

- (NSDictionary<NSString *, NSString *> *)URLQueryItems
{
	return [self formDataUsingSeparator:@"&" decodingBlock:^NSString *(NSString *value) {
		return value.percentDecodedString;
	}];
}

- (nullable NSString *)callStackSymbolMethodName
{
	if (self.length == 0) {
		return nil;
	}
	
	NSMutableArray *components = [[self splitWithCharacters:@" "] mutableCopy];

	// Remove excessive blank lines between app name and memory address
	[components removeObject:@""];

	// 6 = symbol index, app name, memory address, method name, offset symbol (+), offset
	if (components.count < 6) {
		return nil;
	}

	/* To reconstruct the method name or function name, we
	 start after the memory address and work our way up until
	 the offset which is the last two indexes. */
	NSMutableString *methodName = [NSMutableString string];

	for (NSUInteger i = 3; i < (components.count - 2); i++) {
		if (i != 3) {
			[methodName appendString:@" "];
		}

		[methodName appendString:components[i]];
	}

	return [methodName copy];
}

- (NSString *)normalizeSpaces
{
	if (self.length == 0) {
		return self;
	}
	
	static NSCharacterSet *removeSet = nil;
	static NSCharacterSet *replaceSet = nil;
	
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		removeSet = [NSCharacterSet characterSetWithRange:NSMakeRange(0x200b, 1)];
		
		NSMutableCharacterSet *spaceSet = [NSMutableCharacterSet new];
		
		[spaceSet addCharactersInRange:NSMakeRange(0xa0, 1)];
		[spaceSet addCharactersInRange:NSMakeRange(0x2002, 9)]; // 0x2002 ... 0x200a
		[spaceSet addCharactersInRange:NSMakeRange(0x202f, 1)];
		[spaceSet addCharactersInRange:NSMakeRange(0x205f, 1)];
		[spaceSet addCharactersInRange:NSMakeRange(0x3000, 1)];
		[spaceSet addCharactersInRange:NSMakeRange(0xe0020, 1)];
		
		replaceSet = [spaceSet copy];
	});
	
	NSString *bob = [self stringByReplacingOccurrencesOfCharacterSet:removeSet withString:@""];
	
	bob = [bob stringByReplacingOccurrencesOfCharacterSet:replaceSet withString:@" "];
	
	return bob;
}

- (nullable NSString *)standardizedTildePath
{
	/* Have to implement -stringByAbbreviatingWithTildeInPath ourselves
	 here because in a sandbox it wont anonymize the user's actual home
	 directory because in a sandbox, the app's container is the home
	 directory to that function. */
	/* TODO: Investigate whether paths will ever have /Volumes/ prefix.
	 If they do, we might want to check into that behavior.
	 This method is currently only used for logging. */
	NSString *homeDirectory = [NSFileManager pathOfHomeDirectoryOutsideSandbox];

	NSString *bob = [self stringByStandardizingPath];

	if ([bob hasPrefix:homeDirectory] == NO) {
		return self;
	}

	NSUInteger substringIndex = homeDirectory.length;

	if (substringIndex == bob.length) {
		return @"~";
	}

	if ([bob characterAtIndex:substringIndex] != '/') {
		return bob;
	}

	bob = [bob substringFromIndex:substringIndex];

	return [@"~" stringByAppendingString:bob];
}

@end

#pragma mark -
#pragma mark String Percent Encoding Helper

@implementation NSString (CSStringPercentEncodingHelper)

- (nullable NSString *)percentEncodedStringWithAllowedCharacters:(NSString *)allowedCharacters
{
	NSCharacterSet *characterSet =
	[NSCharacterSet characterSetWithCharactersInString:allowedCharacters];

	return [self stringByAddingPercentEncodingWithAllowedCharacters:characterSet];
}

- (nullable NSString *)percentDecodedString
{
	return self.stringByRemovingPercentEncoding;
}

- (nullable NSString *)percentEncodedString
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet percentEncodedCharacterSet]];
}

- (nullable NSString *)percentEncodedURLUser
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet URLUserAllowedCharacterSet]];
}

- (nullable NSString *)percentEncodedURLPassword
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet URLPasswordAllowedCharacterSet]];
}

- (nullable NSString *)percentEncodedURLHost
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet URLHostAllowedCharacterSet]];
}

- (nullable NSString *)percentEncodedURLPath
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet URLPathAllowedCharacterSet]];
}

- (nullable NSString *)percentEncodedURLQuery
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet URLQueryAllowedCharacterSet]];
}

- (nullable NSString *)percentEncodedURLFragment
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:
			[NSCharacterSet URLFragmentAllowedCharacterSet]];
}

@end

#pragma mark -
#pragma mark String Number Formatter Helper

@implementation NSString (CSStringNumberHelper)

+ (NSString *)stringWithChar:(char)value
{
 return [NSString stringWithFormat:@"%c", value];
}

+ (NSString *)stringWithUniChar:(UniChar)value
{
	return [NSString stringWithFormat:@"%C", value];
}

+ (NSString *)stringWithUnsignedChar:(unsigned char)value
{
	return [NSString stringWithFormat:@"%c", value];
}

+ (NSString *)stringWithShort:(short)value
{
	return [NSString stringWithFormat:@"%hi", value];
}

+ (NSString *)stringWithUnsignedShort:(unsigned short)value
{
	return [NSString stringWithFormat:@"%hu", value];
}

+ (NSString *)stringWithInt:(int)value
{
	return [NSString stringWithFormat:@"%i", value];
}

+ (NSString *)stringWithInteger:(NSInteger)value
{
	return [NSString stringWithFormat:@"%ld", value];
}

+ (NSString *)stringWithUnsignedInt:(unsigned int)value
{
	return [NSString stringWithFormat:@"%u", value];
}

+ (NSString *)stringWithUnsignedInteger:(NSUInteger)value
{
	return [NSString stringWithFormat:@"%lu", value];
}

+ (NSString *)stringWithLong:(long)value
{
	return [NSString stringWithFormat:@"%ld", value];
}

+ (NSString *)stringWithUnsignedLong:(unsigned long)value
{
	return [NSString stringWithFormat:@"%lu", value];
}

+ (NSString *)stringWithLongLong:(long long)value
{
	return [NSString stringWithFormat:@"%qi", value];
}

+ (NSString *)stringWithUnsignedLongLong:(unsigned long long)value
{
	return [NSString stringWithFormat:@"%qu", value];
}

+ (NSString *)stringWithFloat:(float)value
{
	return [NSString stringWithFormat:@"%f", value];
}

+ (NSString *)stringWithDouble:(double)value
{
	return [NSString stringWithFormat:@"%f", value];
}

@end

#pragma mark -
#pragma mark Attributed String Helper

@implementation NSAttributedString (NSAttributedStringHelper)

+ (NSAttributedString *)attributedString
{
	return [NSAttributedString attributedStringWithString:@""];
}

+ (NSAttributedString *)attributedStringWithString:(NSString *)string
{
	return [[NSAttributedString alloc] initWithString:string];
}

+ (NSAttributedString *)attributedStringWithString:(NSString *)string attributes:(NSDictionary<NSString *, id> *)stringAttributes
{
	return [[NSAttributedString alloc] initWithString:string attributes:stringAttributes];
}

- (NSDictionary<NSString *, id> *)attributes
{
	return [self attributesAtIndex:0 longestEffectiveRange:NULL inRange:NSMakeRange(0, self.length)];
}

- (NSAttributedString *)attributedSubstringFromIndex:(NSUInteger)from
{
	NSRange range = NSMakeRange(from, (self.length - from));

	return [self attributedSubstringFromRange:range];
}

- (NSAttributedString *)attributedSubstringToIndex:(NSUInteger)to
{
	NSRange range = NSMakeRange(0, (self.length - to));

	return [self attributedSubstringFromRange:range];
}

- (NSRange)range
{
	return NSMakeRange(0, self.length);
}

- (NSArray<NSAttributedString *> *)splitIntoLines
{
	NSString *string = self.string;

    NSUInteger stringLength = string.length;

	if (stringLength == 0) {
		return @[];
	}

	NSMutableAttributedString *mutableSelf = nil;
	
	NSMutableArray<NSAttributedString *> *lines = nil;
	
    NSUInteger rangeStartIn = 0;
    
    while (rangeStartIn < stringLength) {
		NSRange searchRange = NSMakeRange(rangeStartIn, (stringLength - rangeStartIn));
     
		NSRange lineRange = [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:0 range:searchRange];
        
        if (lineRange.location == NSNotFound) {
            break;
        }
		
		if (mutableSelf == nil) {
			mutableSelf = [self mutableCopy];
		}
		
		if (lines == nil) {
			lines = [NSMutableArray array];
		}
        
        NSRange rangeToDelete = NSMakeRange(0, ((lineRange.location - rangeStartIn) + 1));

		NSRange rangeToSubstring = NSMakeRange(rangeStartIn, (lineRange.location - rangeStartIn));
        
        NSAttributedString *line = [self attributedSubstringFromRange:rangeToSubstring];
        
		[lines addObject:line];
		
        [mutableSelf deleteCharactersInRange:rangeToDelete];

        rangeStartIn = NSMaxRange(lineRange);
    }

	if (lines) {
		if (mutableSelf.length > 0) {
			[lines addObject:mutableSelf];
		}

		return [lines copy];
	}
	
	return @[self];
}

- (BOOL)isAttributeSet:(NSString *)attribute atIndex:(NSUInteger)index
{
	return [self isAttributeSet:attribute atIndex:index attributeValue:NULL];
}

- (BOOL)isAttributeSet:(NSString *)attribute atIndex:(NSUInteger)index attributeValue:(id _Nonnull * _Nullable)attributeValue
{
	NSParameterAssert(attribute != nil);

	id attributeValue_1 = [self attribute:attribute atIndex:index effectiveRange:NULL];

	if (attributeValue_1) {
		if (attributeValue) {
			*attributeValue = attributeValue_1;
		}

		return YES;
	}

	return NO;
}

- (BOOL)isAttributeSet:(NSString *)attribute inRange:(NSRange)range
{
	return [self isAttributeSet:attribute inRange:range attributeValue:NULL];
}

- (BOOL)isAttributeSet:(NSString *)attribute inRange:(NSRange)range attributeValue:(id _Nonnull * _Nullable)attributeValue
{
	return [self isAttributeSet:attribute atIndex:range.location attributeValue:attributeValue];
}

@end

#pragma mark -
#pragma mark Mutable Attributed String Helper

@implementation NSMutableAttributedString (NSMutableAttributedStringHelper)

+ (NSMutableAttributedString *)mutableAttributedString
{
	return [NSMutableAttributedString mutableAttributedStringWithString:@""];
}

+ (NSMutableAttributedString *)mutableAttributedStringWithString:(NSString *)string
{
	return [[NSMutableAttributedString alloc] initWithString:string attributes:nil];
}

+ (NSMutableAttributedString *)mutableAttributedStringWithString:(NSString *)string attributes:(NSDictionary<NSString *, id> *)stringAttributes
{
	return [[NSMutableAttributedString alloc] initWithString:string attributes:stringAttributes];
}

- (NSString *)trimmedString
{
	return self.string.trim;
}

- (void)appendString:(NSString *)string
{
	[self appendAttributedString:
	 [NSAttributedString attributedStringWithString:string]];
}

- (void)appendString:(NSString *)string attributes:(NSDictionary<NSString *, id> *)stringAttributes
{
	[self appendAttributedString:
	 [NSAttributedString attributedStringWithString:string attributes:stringAttributes]];
}

- (void)addAttribute:(NSString *)attribute value:(id)value startingAt:(NSUInteger)index
{
	NSParameterAssert(attribute != nil);
	NSParameterAssert(value != nil);

	[self addAttributes:@{attribute : value} startingAt:index];
}

- (void)addAttributes:(NSDictionary<NSString *, id> *)attributes startingAt:(NSUInteger)index
{
	NSParameterAssert(attributes != nil);

	NSRange range = NSMakeRange(index, (self.length - index));

	[self addAttributes:attributes range:range];
}

- (void)removeAttribute:(NSString *)attribute startingAt:(NSUInteger)index
{
	NSParameterAssert(attribute != nil);

	NSRange range = NSMakeRange(index, (self.length - index));

	[self removeAttribute:attribute range:range];
}

- (void)resetAttributesStaringAt:(NSUInteger)index
{
	NSRange range = NSMakeRange(index, (self.length - index));

	[self setAttributes:@{} range:range];
}

@end

NS_ASSUME_NONNULL_END
