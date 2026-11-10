/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
 *  * Neither the name of Textual, "Codeux Software, LLC", nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
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

#import "IRCColorFormat.h"
#import "TVCInputMarkdownPrivate.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TVCInputMarkdownEffect) {
	TVCInputMarkdownEffectCode = 0,
	TVCInputMarkdownEffectSpoiler,
	TVCInputMarkdownEffectBold,
	TVCInputMarkdownEffectItalic
};

@implementation TVCInputMarkdown

+ (NSAttributedString *)attributedStringByApplyingMarkdown:(NSAttributedString *)string
{
	return [self attributedStringByApplyingMarkdown:string protectingNicknames:nil];
}

+ (NSAttributedString *)attributedStringByApplyingMarkdown:(NSAttributedString *)string protectingNicknames:(nullable NSArray<NSString *> *)nicknames
{
	NSParameterAssert(string != nil);

	/* Only those a marker could take apart */
	NSCharacterSet *markerCharacters = [NSCharacterSet characterSetWithCharactersInString:@"`_*|"];

	NSMutableArray<NSString *> *protectedNicknames = [NSMutableArray array];

	for (NSString *nickname in nicknames) {
		if ([nickname rangeOfCharacterFromSet:markerCharacters].location != NSNotFound) {
			[protectedNicknames addObject:nickname];
		}
	}

	NSMutableAttributedString *result = [NSMutableAttributedString new];

	NSString *text = string.string;

	__block NSUInteger lineStart = 0;

	/* Line by line: each line is its own message */
	while (lineStart <= text.length) {
		NSRange newline = [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:0 range:NSMakeRange(lineStart, (text.length - lineStart))];

		NSUInteger lineEnd = ((newline.location == NSNotFound) ? text.length : newline.location);

		NSAttributedString *line = [string attributedSubstringFromRange:NSMakeRange(lineStart, (lineEnd - lineStart))];

		[result appendAttributedString:[self _lineByApplyingMarkdown:line protectingNicknames:protectedNicknames]];

		if (newline.location == NSNotFound) {
			break;
		}

		[result appendAttributedString:[string attributedSubstringFromRange:newline]];

		lineStart = NSMaxRange(newline);
	}

	return [result copy];
}

+ (NSAttributedString *)_lineByApplyingMarkdown:(NSAttributedString *)line protectingNicknames:(NSArray<NSString *> *)nicknames
{
	NSString *text = line.string;

	/* Commands are left alone, except an action's text and a message that
	 starts with a slash (//) */
	NSUInteger contentStart = 0;

	if ([text hasPrefix:@"//"]) {
		contentStart = 2;
	} else if ([text hasPrefix:@"/"]) {
		if ([text.lowercaseString hasPrefix:@"/me "] == NO) {
			return line;
		}

		contentStart = 4;
	}

	NSMutableAttributedString *result = [line mutableCopy];

	/* Links stay as they are */
	NSMutableIndexSet *protectedIndexes = [NSMutableIndexSet indexSet];

	NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];

	[linkDetector enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
		[protectedIndexes addIndexesInRange:match.range];
	}];

	/* So do nicknames of the channel, as whole words */
	NSMutableCharacterSet *nicknameCharacters = [NSMutableCharacterSet alphanumericCharacterSet];

	[nicknameCharacters addCharactersInString:@"_-[]\\`^{}|"];

	for (NSString *nickname in nicknames) {
		NSUInteger searchFrom = contentStart;

		while (searchFrom < text.length) {
			NSRange found = [text rangeOfString:nickname options:NSCaseInsensitiveSearch range:NSMakeRange(searchFrom, (text.length - searchFrom))];

			if (found.location == NSNotFound) {
				break;
			}

			searchFrom = NSMaxRange(found);

			BOOL startsWord = (found.location == 0 || [nicknameCharacters characterIsMember:[text characterAtIndex:(found.location - 1)]] == NO);

			BOOL endsWord = (NSMaxRange(found) == text.length || [nicknameCharacters characterIsMember:[text characterAtIndex:NSMaxRange(found)]] == NO);

			if (startsWord && endsWord) {
				[protectedIndexes addIndexesInRange:found];
			}
		}
	}

	NSArray<NSString *> *markers = @[@"`", @"||", @"**", @"_"];

	/* Found spans: marker ranges to remove and the effect for the content */
	NSMutableArray<NSArray *> *spans = [NSMutableArray array];

	for (TVCInputMarkdownEffect effect = TVCInputMarkdownEffectCode; effect <= TVCInputMarkdownEffectItalic; effect++) {
		NSString *marker = markers[effect];

		NSUInteger searchFrom = contentStart;

		while (searchFrom < text.length) {
			NSRange opening = [text rangeOfString:marker options:0 range:NSMakeRange(searchFrom, (text.length - searchFrom))];

			if (opening.location == NSNotFound) {
				break;
			}

			searchFrom = NSMaxRange(opening);

			if ([self _index:opening.location isAvailableIn:protectedIndexes length:opening.length] == NO ||
				[self _isOpening:opening inText:text contentStart:contentStart] == NO)
			{
				continue;
			}

			NSRange closing = NSMakeRange(NSNotFound, 0);

			NSUInteger closeSearchFrom = NSMaxRange(opening);

			while (closeSearchFrom < text.length) {
				NSRange candidate = [text rangeOfString:marker options:0 range:NSMakeRange(closeSearchFrom, (text.length - closeSearchFrom))];

				if (candidate.location == NSNotFound) {
					break;
				}

				closeSearchFrom = NSMaxRange(candidate);

				if ([self _index:candidate.location isAvailableIn:protectedIndexes length:candidate.length] &&
					[self _isClosing:candidate inText:text])
				{
					closing = candidate;

					break;
				}
			}

			if (closing.location == NSNotFound) {
				continue;
			}

			NSRange content = NSMakeRange(NSMaxRange(opening), (closing.location - NSMaxRange(opening)));

			if (content.length == 0) {
				continue;
			}

			/* Nothing inside code changes; nothing is found twice */
			if (effect == TVCInputMarkdownEffectCode) {
				[protectedIndexes addIndexesInRange:content];
			}

			[protectedIndexes addIndexesInRange:opening];
			[protectedIndexes addIndexesInRange:closing];

			[spans addObject:@[@(effect), [NSValue valueWithRange:opening], [NSValue valueWithRange:content], [NSValue valueWithRange:closing]]];

			searchFrom = NSMaxRange(closing);
		}
	}

	if (spans.count == 0) {
		return line;
	}

	for (NSArray *span in spans) {
		TVCInputMarkdownEffect effect = [span[0] unsignedIntegerValue];

		NSRange content = [span[2] rangeValue];

		switch (effect) {
			case TVCInputMarkdownEffectCode:
			{
				[result addAttribute:IRCTextFormatterMonospaceAttributeName value:@(YES) range:content];

				break;
			}
			case TVCInputMarkdownEffectSpoiler:
			{
				/* The classic IRC spoiler: black on black */
				[result addAttribute:IRCTextFormatterSpoilerAttributeName value:@(YES) range:content];
				[result addAttribute:IRCTextFormatterForegroundColorAttributeName value:@(1) range:content];
				[result addAttribute:IRCTextFormatterBackgroundColorAttributeName value:@(1) range:content];

				break;
			}
			case TVCInputMarkdownEffectBold:
			{
				[result addAttribute:IRCTextFormatterBoldAttributeName value:@(YES) range:content];

				break;
			}
			case TVCInputMarkdownEffectItalic:
			{
				[result addAttribute:IRCTextFormatterItalicAttributeName value:@(YES) range:content];

				break;
			}
		}
	}

	/* The markers go, from the end so ranges stay valid */
	NSMutableArray<NSValue *> *markerRanges = [NSMutableArray array];

	for (NSArray *span in spans) {
		[markerRanges addObject:span[1]];
		[markerRanges addObject:span[3]];
	}

	[markerRanges sortUsingComparator:^NSComparisonResult(NSValue *value1, NSValue *value2) {
		NSUInteger location1 = value1.rangeValue.location;
		NSUInteger location2 = value2.rangeValue.location;

		return ((location1 > location2) ? NSOrderedAscending : ((location1 < location2) ? NSOrderedDescending : NSOrderedSame));
	}];

	for (NSValue *markerRange in markerRanges) {
		[result deleteCharactersInRange:markerRange.rangeValue];
	}

	return [result copy];
}

+ (BOOL)_index:(NSUInteger)index isAvailableIn:(NSIndexSet *)protectedIndexes length:(NSUInteger)length
{
	return ([protectedIndexes intersectsIndexesInRange:NSMakeRange(index, length)] == NO);
}

/* After the start, a space, an opening bracket or quote or another marker
 (**_both_**); followed by text */
+ (BOOL)_isOpening:(NSRange)marker inText:(NSString *)text contentStart:(NSUInteger)contentStart
{
	if (marker.location > contentStart) {
		unichar before = [text characterAtIndex:(marker.location - 1)];

		/* "__init__": not a marker right after the same character */
		if (before == [text characterAtIndex:marker.location]) {
			return NO;
		}

		if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:before] == NO &&
			[[NSCharacterSet characterSetWithCharactersInString:@"([{\"'“‘*_|`"] characterIsMember:before] == NO)
		{
			return NO;
		}
	}

	if (NSMaxRange(marker) >= text.length) {
		return NO;
	}

	unichar after = [text characterAtIndex:NSMaxRange(marker)];

	if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:after]) {
		return NO;
	}

	/* "____" or "***" is not a marker followed by text */
	if (after == [text characterAtIndex:marker.location]) {
		return NO;
	}

	return YES;
}

/* After text; then the end, a space, closing punctuation or another marker */
+ (BOOL)_isClosing:(NSRange)marker inText:(NSString *)text
{
	unichar before = [text characterAtIndex:(marker.location - 1)];

	if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:before]) {
		return NO;
	}

	if (before == [text characterAtIndex:marker.location]) {
		return NO;
	}

	if (NSMaxRange(marker) == text.length) {
		return YES;
	}

	unichar after = [text characterAtIndex:NSMaxRange(marker)];

	if (after == [text characterAtIndex:marker.location]) {
		return NO;
	}

	return ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:after] ||
			[[NSCharacterSet characterSetWithCharactersInString:@".,;:!?)]}\"'”’-*_|`"] characterIsMember:after]);
}

@end

NS_ASSUME_NONNULL_END
