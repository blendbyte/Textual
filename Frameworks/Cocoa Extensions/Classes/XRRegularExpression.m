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

/* Patterns often come from users (highlights, ignores, filters) and are run
 against text from the network, so: compiled patterns are cached, invalid
 patterns never match, only the first XRRegularExpressionMaximumInputLength
 characters are searched, and a search that takes longer than
 XRRegularExpressionTimeLimit (catastrophic backtracking) counts as no match. */
#define XRRegularExpressionMaximumInputLength		8192
#define XRRegularExpressionTimeLimit				0.05

@implementation XRRegularExpression

+ (nullable NSRegularExpression *)regularExpressionWithPattern:(NSString *)pattern caseless:(BOOL)caseless
{
	static NSCache<NSString *, id> *cache = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cache = [NSCache new];

		cache.countLimit = 500;
	});

	NSString *cacheKey = [NSString stringWithFormat:@"%d:%@", caseless, pattern];

	id cachedValue = [cache objectForKey:cacheKey];

	if (cachedValue == nil) {
		NSRegularExpressionOptions options = ((caseless) ? NSRegularExpressionCaseInsensitive : 0);

		cachedValue = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:NULL];

		if (cachedValue == nil) {
			cachedValue = [NSNull null]; // Invalid patterns are remembered too
		}

		[cache setObject:cachedValue forKey:cacheKey];
	}

	if (cachedValue == [NSNull null]) {
		return nil;
	}

	return cachedValue;
}

+ (BOOL)isValidRegex:(NSString *)pattern
{
	NSParameterAssert(pattern != nil);

	return ([self regularExpressionWithPattern:pattern caseless:NO] != nil);
}

/* All matches (or only the first) within the searched part of the string;
 empty for an invalid pattern or a search that exceeds the time limit. */
+ (NSArray<NSTextCheckingResult *> *)resultsInString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless firstOnly:(BOOL)firstOnly
{
	NSParameterAssert(haystack != nil);
	NSParameterAssert(needle != nil);

	NSRegularExpression *regex = [self regularExpressionWithPattern:needle caseless:caseless];

	if (regex == nil) {
		return @[];
	}

	NSRange searchRange = NSMakeRange(0, MIN(haystack.length, XRRegularExpressionMaximumInputLength));

	NSMutableArray<NSTextCheckingResult *> *results = [NSMutableArray array];

	/* Monotonic: wall-clock changes must not cut a search short */
	NSTimeInterval deadline = ([NSProcessInfo processInfo].systemUptime + XRRegularExpressionTimeLimit);

	__block BOOL timedOut = NO;

	/* NSMatchingReportProgress calls the block periodically during a long search */
	[regex enumerateMatchesInString:haystack options:NSMatchingReportProgress range:searchRange usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop) {
		if (result) {
			[results addObject:result];

			if (firstOnly) {
				*stop = YES;

				return;
			}
		}

		if ([NSProcessInfo processInfo].systemUptime > deadline) {
			timedOut = YES;

			*stop = YES;
		}
	}];

	if (timedOut) {
		NSLog(@"Regular expression took too long and was treated as no match: %@", needle);

		return @[];
	}

	return [results copy];
}

+ (BOOL)string:(NSString *)haystack isMatchedByRegex:(NSString *)needle
{
	return [self string:haystack isMatchedByRegex:needle withoutCase:NO];
}

+ (BOOL)string:(NSString *)haystack isMatchedByRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	return ([self resultsInString:haystack withRegex:needle withoutCase:caseless firstOnly:YES].count > 0);
}

+ (NSRange)string:(NSString *)haystack rangeOfRegex:(NSString *)needle
{
	return [self string:haystack rangeOfRegex:needle withoutCase:NO];
}

+ (NSRange)string:(NSString *)haystack rangeOfRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	NSTextCheckingResult *result = [self resultsInString:haystack withRegex:needle withoutCase:caseless firstOnly:YES].firstObject;

	if (result == nil) {
		return NSMakeRange(NSNotFound, 0);
	}

	return result.range;
}

+ (NSString *)string:(NSString *)haystack replacedByRegex:(NSString *)needle withString:(NSString *)puppy
{
	NSParameterAssert(puppy != nil);

	NSRegularExpression *regex = [self regularExpressionWithPattern:needle caseless:NO];

	NSArray<NSTextCheckingResult *> *results = [self resultsInString:haystack withRegex:needle withoutCase:NO firstOnly:NO];

	if (regex == nil || results.count == 0) {
		return haystack;
	}

	NSMutableString *newString = [haystack mutableCopy];

	/* Back to front, so that earlier ranges stay valid */
	for (NSTextCheckingResult *result in results.reverseObjectEnumerator) {
		NSString *replacement = [regex replacementStringForResult:result inString:haystack offset:0 template:puppy];

		[newString replaceCharactersInRange:result.range withString:replacement];
	}

	return [newString copy];
}

+ (NSUInteger)totalNumberOfMatchesInString:(NSString *)haystack withRegex:(NSString *)needle
{
	return [self totalNumberOfMatchesInString:haystack withRegex:needle withoutCase:NO];
}

+ (NSUInteger)totalNumberOfMatchesInString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	return [self resultsInString:haystack withRegex:needle withoutCase:caseless firstOnly:NO].count;
}

+ (NSArray *)matchesInString:(NSString *)haystack withRegex:(NSString *)needle
{
	return [self matchesInString:haystack withRegex:needle withoutCase:NO substringGroups:NO];
}

+ (NSArray *)matchesInString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	return [self matchesInString:haystack withRegex:needle withoutCase:caseless substringGroups:NO];
}

+ (NSArray *)matchesInString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless substringGroups:(BOOL)substringGroups
{
	NSArray<NSTextCheckingResult *> *matches = [self resultsInString:haystack withRegex:needle withoutCase:caseless firstOnly:NO];

	NSMutableArray<NSString *> *realMatches = [NSMutableArray array];

	for (NSTextCheckingResult *result in matches) {
		NSString *parentGroup = [haystack substringWithRange:result.range];

		[realMatches addObject:parentGroup];
		
		if (substringGroups == NO) {
			continue;
		}
		
		for (NSUInteger i = 1; i < result.numberOfRanges; i++) {
			NSRange childGroupRange = [result rangeAtIndex:i];
			
			if (childGroupRange.location == NSNotFound) {
				continue;
			}
			
			NSString *childGroup = [haystack substringWithRange:childGroupRange];
			
			[realMatches addObject:childGroup];
		}
	}

	return [realMatches copy];
}

+ (NSUInteger)matches:(NSArray * _Nullable * _Nonnull)matches inString:(NSString *)haystack withRegex:(NSString *)needle
{
	return [self matches:matches inString:haystack withRegex:needle withoutCase:NO substringGroups:NO];
}

+ (NSUInteger)matches:(NSArray * _Nullable * _Nonnull)matches inString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	return [self matches:matches inString:haystack withRegex:needle withoutCase:caseless substringGroups:NO];
}

+ (NSUInteger)matches:(NSArray * _Nullable * _Nonnull)matches inString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless substringGroups:(BOOL)substringGroups
{
	NSArray *matchesOut = [self matchesInString:haystack withRegex:needle withoutCase:caseless substringGroups:substringGroups];
	
	if (matches) {
		*matches = matchesOut;
	}
	
	return matchesOut.count;
}
@end

NS_ASSUME_NONNULL_END
