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

@implementation XRRegularExpression

+ (BOOL)string:(NSString *)haystack isMatchedByRegex:(NSString *)needle
{
	return [self string:haystack isMatchedByRegex:needle withoutCase:NO];
}

+ (BOOL)string:(NSString *)haystack isMatchedByRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	NSParameterAssert(haystack != nil);
	NSParameterAssert(needle != nil);

    NSRange strRange = NSMakeRange(0, haystack.length);

	NSRegularExpression *regex;

	if (caseless) {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:NSRegularExpressionCaseInsensitive error:NULL];
	} else {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:0 error:NULL];
	}

	NSUInteger numMatches = [regex numberOfMatchesInString:haystack options:0 range:strRange];

	return (numMatches >= 1);
}

+ (NSRange)string:(NSString *)haystack rangeOfRegex:(NSString *)needle
{
	return [self string:haystack rangeOfRegex:needle withoutCase:NO];
}

+ (NSRange)string:(NSString *)haystack rangeOfRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	NSParameterAssert(haystack != nil);
	NSParameterAssert(needle != nil);

    NSRange strRange = NSMakeRange(0, haystack.length);

	NSRegularExpression *regex;

	if (caseless) {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:NSRegularExpressionCaseInsensitive error:NULL];
	} else {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:0 error:NULL];
	}

	NSRange resultRange = [regex rangeOfFirstMatchInString:haystack options:0 range:strRange];

	return resultRange;
}

+ (NSString *)string:(NSString *)haystack replacedByRegex:(NSString *)needle withString:(NSString *)puppy
{
	NSParameterAssert(haystack != nil);
	NSParameterAssert(needle != nil);
	NSParameterAssert(puppy != nil);

	NSRange strRange = NSMakeRange(0, haystack.length);

	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:needle options:0 error:NULL];

	NSString *newString = [regex stringByReplacingMatchesInString:haystack options:0 range:strRange withTemplate:puppy];

	return newString;
}

+ (NSUInteger)totalNumberOfMatchesInString:(NSString *)haystack withRegex:(NSString *)needle
{
	return [self totalNumberOfMatchesInString:haystack withRegex:needle withoutCase:NO];
}

+ (NSUInteger)totalNumberOfMatchesInString:(NSString *)haystack withRegex:(NSString *)needle withoutCase:(BOOL)caseless
{
	NSParameterAssert(haystack != nil);
	NSParameterAssert(needle != nil);

    NSRange strRange = NSMakeRange(0, haystack.length);
	
	NSRegularExpression *regex;
	
	if (caseless) {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:NSRegularExpressionCaseInsensitive error:NULL];
	} else {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:0 error:NULL];
	}
	
	NSArray *matches = [regex matchesInString:haystack options:0 range:strRange];

	return matches.count;
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
	NSParameterAssert(haystack != nil);
	NSParameterAssert(needle != nil);

    NSRange strRange = NSMakeRange(0, haystack.length);

	NSRegularExpression *regex;

	if (caseless) {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:NSRegularExpressionCaseInsensitive error:NULL];
	} else {
		regex = [NSRegularExpression regularExpressionWithPattern:needle options:0 error:NULL];
	}

	NSArray *matches = [regex matchesInString:haystack options:0 range:strRange];

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
