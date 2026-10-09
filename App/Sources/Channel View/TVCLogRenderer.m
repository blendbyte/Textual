/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
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

#import "GTMEncodeHTML.h"
#import "NSColorHelper.h"
#import "NSStringHelper.h"
#import "IRCClientConfig.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCChannelUser.h"
#import "IRCColorFormat.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "IRCUserNicknameColorStyleGeneratorPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TPCThemeController.h"
#import "TPCTheme.h"
#import "THOPluginDispatcherPrivate.h"
#import "THOUnicodeHelper.h"
#import "TLOLinkParser.h"
#import "TVCLogController.h"
#import "TVCLogLine.h"
#import "TVCLogRendererPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogRenderer ()
@property (nonatomic, copy, nullable) NSString *body;
@property (nonatomic, copy, nullable) id finalResult;
@property (nonatomic, strong, nullable) NSMutableAttributedString *bodyWithAttributes;
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, id> *renderedBodyOpenAttributes;
@property (nonatomic, copy) NSDictionary<NSString *, id> *rendererAttributes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *outputDictionary;
@property (nonatomic, weak) TVCLogController *viewController;
@property (nonatomic, assign) TVCLogLineType lineType;
@property (nonatomic, assign) TVCLogLineMemberType memberType;
@property (nonatomic, assign) BOOL escapeBody;
@end

NSString * const TVCLogRendererFormattingForegroundColorAttribute = @"TVCLogRendererFormattingForegroundColorAttribute";
NSString * const TVCLogRendererFormattingBackgroundColorAttribute = @"TVCLogRendererFormattingBackgroundColorAttribute";
NSString * const TVCLogRendererFormattingBoldTextAttribute = @"TVCLogRendererFormattingBoldTextAttribute";
NSString * const TVCLogRendererFormattingItalicTextAttribute = @"TVCLogRendererFormattingItalicTextAttribute";
NSString * const TVCLogRendererFormattingMonospaceTextAttribute = @"TVCLogRendererFormattingMonospaceTextAttribute";
NSString * const TVCLogRendererFormattingStrikethroughTextAttribute = @"TVCLogRendererFormattingStrikethroughTextAttribute";
NSString * const TVCLogRendererFormattingUnderlineTextAttribute = @"TVCLogRendererFormattingUnderlineTextAttribute";
NSString * const TVCLogRendererFormattingChannelNameAttribute = @"TVCLogRendererFormattingChannelNameAttribute";
NSString * const TVCLogRendererFormattingConversationTrackingAttribute = @"TVCLogRendererFormattingConversationTrackingAttribute";
NSString * const TVCLogRendererFormattingKeywordHighlightAttribute = @"TVCLogRendererFormattingKeywordHighlightAttribute";
NSString * const TVCLogRendererFormattingURLAttribute = @"TVCLogRendererFormattingURLAttribute";

NSString * const TVCLogRendererConfigurationRenderLinksAttribute = @"TVCLogRendererConfigurationRenderLinksAttribute";
NSString * const TVCLogRendererConfigurationLineTypeAttribute = @"TVCLogRendererConfigurationLineTypeAttribute";
NSString * const TVCLogRendererConfigurationMemberTypeAttribute = @"TVCLogRendererConfigurationMemberTypeAttribute";
NSString * const TVCLogRendererConfigurationHighlightKeywordsAttribute = @"TVCLogRendererConfigurationHighlightKeywordsAttribute";
NSString * const TVCLogRendererConfigurationExcludedKeywordsAttribute = @"TVCLogRendererConfigurationExcludedKeywordsAttribute";
NSString * const TVCLogRendererConfigurationDoNotEscapeBodyAttribute = @"TVCLogRendererConfigurationDoNotEscapeBodyAttribute";

NSString * const TVCLogRendererConfigurationAttributedStringPreferredFontAttribute = @"TVCLogRendererConfigurationAttributedStringPreferredFontAttribute";
NSString * const TVCLogRendererConfigurationAttributedStringPreferredFontColorAttribute = @"TVCLogRendererConfigurationAttributedStringPreferredFontColorAttribute";

NSString * const TVCLogRendererResultsListOfLinksInBodyAttribute = @"TVCLogRendererResultsListOfLinksInBodyAttribute";
NSString * const TVCLogRendererResultsListOfLinksMappedInBodyAttribute = @"TVCLogRendererResultsListOfLinksMappedInBodyAttribute";
NSString * const TVCLogRendererResultsKeywordMatchFoundAttribute = @"TVCLogRendererResultsKeywordMatchFoundAttribute";
NSString * const TVCLogRendererResultsListOfUsersFoundAttribute = @"TVCLogRendererResultsListOfUsersFoundAttribute";
NSString * const TVCLogRendererResultsOriginalBodyWithoutEffectsAttribute = @"TVCLogRendererResultsOriginalBodyWithoutEffectsAttribute";

@implementation TVCLogRenderer

+ (BOOL)isClickableLinkLocation:(NSString *)linkLocation
{
	NSParameterAssert(linkLocation != nil);

	/* The link scanner only finds schemes it permits (http, https and the
	 app's and user's list); opening them goes through TLOpenLink's policy.
	 These are never made clickable, even if the user permits any scheme:
	 they run script or reach local content. */
	static NSSet<NSString *> *forbiddenSchemes = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		forbiddenSchemes = [NSSet setWithArray:@[@"javascript", @"vbscript", @"data", @"file", @"blob", @"about"]];
	});

	/* Read textually: NSURL rejects many links that are fine to click */
	NSRange schemeEnd = [linkLocation rangeOfString:@":"];

	if (schemeEnd.location == NSNotFound || schemeEnd.location == 0) {
		return NO;
	}

	NSString *scheme = [linkLocation substringToIndex:schemeEnd.location].trim.lowercaseString;

	return ([forbiddenSchemes containsObject:scheme] == NO);
}

- (instancetype)init
{
	if ((self = [super init])) {
		self->_outputDictionary = [NSMutableDictionary dictionary];
	}

	return self;
}

- (void)buildEffectsDictionary
{
	NSString *body = self->_body;

	NSUInteger bodyLength = body.length;

	/* On the heap: a long line on the stack could overflow it */
	NSMutableData *charactersBuffer = [NSMutableData dataWithLength:(bodyLength * sizeof(UniChar))];

	UniChar *charactersIn = charactersBuffer.mutableBytes;

	[body getCharacters:charactersIn range:body.range];

	NSMutableAttributedString *bodyWithAttributes = [[NSMutableAttributedString alloc] initWithString:body attributes:nil];

	[bodyWithAttributes beginEditing];

	NSUInteger characterOffset = 0;

	for (NSUInteger i = 0; i < bodyLength; i++) {
		UniChar character = charactersIn[i];

		NSUInteger characterPosition = (i - characterOffset);

		if (character < 0x20) {
			switch (character) {
				case IRCTextFormatterEffectBoldCharacter:
				{
					if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingBoldTextAttribute atIndex:characterPosition]) {
						[bodyWithAttributes removeAttribute:TVCLogRendererFormattingBoldTextAttribute startingAt:characterPosition];
					} else {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingBoldTextAttribute value:@(YES) startingAt:characterPosition];
					}

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, 1)];

					characterOffset++;

					continue;
				}
				case IRCTextFormatterEffectColorAsDigitCharacter:
				case IRCTextFormatterEffectColorAsHexCharacter:
				{
					id foregroundColor = nil;
					id backgroundColor = nil;

					NSUInteger colorOffset = [bodyWithAttributes.string
											  colorComponentsOfCharacter:character
															  startingAt:characterPosition
														 foregroundColor:&foregroundColor
														 backgroundColor:&backgroundColor];

					if (foregroundColor != nil) {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingForegroundColorAttribute value:foregroundColor startingAt:characterPosition];
					} else if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingForegroundColorAttribute atIndex:characterPosition]) {
						[bodyWithAttributes removeAttribute:TVCLogRendererFormattingForegroundColorAttribute startingAt:characterPosition];
					}

					if (backgroundColor != nil) {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingBackgroundColorAttribute value:backgroundColor startingAt:characterPosition];
					} else if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingBackgroundColorAttribute atIndex:characterPosition]) {
						/* We only strip the background color if there is no longer a foreground color. A end character. */
						if (foregroundColor == nil) {
							[bodyWithAttributes removeAttribute:TVCLogRendererFormattingBackgroundColorAttribute startingAt:characterPosition];
						}
					}

					i += (colorOffset - 1); // For loop will increase this by one so we minus by one

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, colorOffset)];

					characterOffset += colorOffset;

					continue;
				}
				case IRCTextFormatterTerminatingCharacter:
				{
					[bodyWithAttributes resetAttributesStaringAt:characterPosition];

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, 1)];

					characterOffset++;

					continue;
				}
				case IRCTextFormatterEffectItalicCharacter:
				case IRCTextFormatterEffectItalicCharacterOld:
				{
					if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingItalicTextAttribute atIndex:characterPosition]) {
						[bodyWithAttributes removeAttribute:TVCLogRendererFormattingItalicTextAttribute startingAt:characterPosition];
					} else {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingItalicTextAttribute value:@(YES) startingAt:characterPosition];
					}

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, 1)];

					characterOffset++;

					continue;
				}
				case IRCTextFormatterEffectMonospaceCharacter:
				{
					if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingMonospaceTextAttribute atIndex:characterPosition]) {
						[bodyWithAttributes removeAttribute:TVCLogRendererFormattingMonospaceTextAttribute startingAt:characterPosition];
					} else {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingMonospaceTextAttribute value:@(YES) startingAt:characterPosition];
					}

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, 1)];

					characterOffset++;

					continue;
				}
				case IRCTextFormatterEffectStrikethroughCharacter:
				{
					if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingStrikethroughTextAttribute atIndex:characterPosition]) {
						[bodyWithAttributes removeAttribute:TVCLogRendererFormattingStrikethroughTextAttribute startingAt:characterPosition];
					} else {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingStrikethroughTextAttribute value:@(YES) startingAt:characterPosition];
					}

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, 1)];

					characterOffset++;

					continue;
				}
				case IRCTextFormatterEffectUnderlineCharacter:
				{
					if (characterPosition > 0 && [bodyWithAttributes isAttributeSet:TVCLogRendererFormattingUnderlineTextAttribute atIndex:characterPosition]) {
						[bodyWithAttributes removeAttribute:TVCLogRendererFormattingUnderlineTextAttribute startingAt:characterPosition];
					} else {
						[bodyWithAttributes addAttribute:TVCLogRendererFormattingUnderlineTextAttribute value:@(YES) startingAt:characterPosition];
					}

					[bodyWithAttributes deleteCharactersInRange:NSMakeRange(characterPosition, 1)];

					characterOffset++;

					continue;
				} // case
			} // switch
		} // character < 0x20
	} // for loop

	[bodyWithAttributes endEditing];

	NSString *stringWithoutEffects = bodyWithAttributes.string;

	self->_outputDictionary[TVCLogRendererResultsOriginalBodyWithoutEffectsAttribute] = stringWithoutEffects;

	self->_body = stringWithoutEffects;

	self->_bodyWithAttributes = bodyWithAttributes;
}

- (BOOL)isRenderingPRIVMSG
{
	return (self->_lineType == TVCLogLineTypePrivateMessage || self->_lineType == TVCLogLineTypeAction);
}

- (BOOL)isRenderingPRIVMSG_or_NOTICE
{
	return (self->_lineType == TVCLogLineTypePrivateMessage || self->_lineType == TVCLogLineTypeAction || self->_lineType == TVCLogLineTypeNotice);
}

- (BOOL)scanForKeywords
{
	return ([self isRenderingPRIVMSG] && self->_memberType == TVCLogLineMemberTypeNormal);
}

- (void)stripDangerousUnicodeCharactersFromBody
{
	if ([TPCPreferences automaticallyFilterUnicodeTextSpam] == NO) {
		return;
	}

	if (self->_lineType != TVCLogLineTypeAction			&&
		self->_lineType != TVCLogLineTypeCTCP			&&
		self->_lineType != TVCLogLineTypeCTCPQuery		&&
		self->_lineType != TVCLogLineTypeCTCPReply		&&
		self->_lineType != TVCLogLineTypeDCCFileTransfer	&&
		self->_lineType != TVCLogLineTypeNotice			&&
		self->_lineType != TVCLogLineTypePrivateMessage	&&
		self->_lineType != TVCLogLineTypeTopic)
	{
		return;
	}

	self->_body =
	[XRRegularExpression string:self->_body
				replacedByRegex:@"([\\p{InCombining_Diacritical_Marks}]{3,})"
					 withString:CS_UnicodeReplacementCharacter];
}

- (void)buildListOfLinksInBody
{
	BOOL renderLinks = [self->_rendererAttributes boolForKey:TVCLogRendererConfigurationRenderLinksAttribute];

	if (renderLinks == NO) {
		return;
	}

	NSMutableDictionary<NSString *, NSString *> *linksMapped = [NSMutableDictionary dictionary];

	NSArray *links = [TLOLinkParser locateLinksInString:self->_body];

	for (AHHyperlinkScannerResult *link in links) {
		NSRange linkRange = link.range;

		NSString *linkString = link.stringValue;

		[self->_bodyWithAttributes addAttribute:TVCLogRendererFormattingURLAttribute value:link range:linkRange];

		if (linksMapped[linkString] == nil) {
			linksMapped[linkString] = link.uniqueIdentifier;
		}
	}

	self->_outputDictionary[TVCLogRendererResultsListOfLinksInBodyAttribute] = links;
	self->_outputDictionary[TVCLogRendererResultsListOfLinksMappedInBodyAttribute] = [linksMapped copy];
}

- (void)matchKeywords
{
	if ([self scanForKeywords] == NO) {
		return;
	}

	id excludedKeywords = [self->_rendererAttributes arrayForKey:TVCLogRendererConfigurationExcludedKeywordsAttribute];
	id highlightKeywords = [self->_rendererAttributes arrayForKey:TVCLogRendererConfigurationHighlightKeywordsAttribute];

	if ([highlightKeywords count] == 0) {
		self->_outputDictionary[TVCLogRendererResultsKeywordMatchFoundAttribute] = @(NO);

		return;
	}

	NSMutableArray<NSValue *> *excludeRanges = [NSMutableArray array];

	for (NSString *excludeKeyword in excludedKeywords) {
		[self->_body enumerateMatchesOfString:excludeKeyword withBlock:^(NSRange range, BOOL *stop) {
			[excludeRanges addObject:[NSValue valueWithRange:range]];
		} options:NSCaseInsensitiveSearch];
	}

	BOOL foundKeyword = NO;

	TXNicknameHighlightMatchType matchingMethod = [TPCPreferences highlightMatchingMethod];

	switch (matchingMethod) {
		case TXNicknameHighlightMatchTypeExact:
		case TXNicknameHighlightMatchTypePartial:
		{
			foundKeyword = [self matchKeywordsUsingNormalMatching:highlightKeywords excludedRanges:excludeRanges exactMatching:(matchingMethod == TXNicknameHighlightMatchTypeExact)];

			break;
		}
		case TXNicknameHighlightMatchTypeRegularExpression:
		{
			foundKeyword = [self matchKeywordsUsingRegularExpression:highlightKeywords excludedRanges:excludeRanges];

			break;
		}
	}

	self->_outputDictionary[TVCLogRendererResultsKeywordMatchFoundAttribute] = @(foundKeyword);
}

- (BOOL)matchKeywordsUsingNormalMatching:(NSArray<NSString *> *)keywords excludedRanges:(NSArray<NSValue *> *)excludedRanges exactMatching:(BOOL)exactMatching
{
	NSParameterAssert(keywords != nil);
	NSParameterAssert(excludedRanges != nil);

	NSString *body = self->_body;

	__block BOOL foundKeyword = NO;

	for (NSString *keyword in keywords) {
		[body enumerateMatchesOfString:keyword withBlock:^(NSRange range, BOOL *stop) {
			for (NSValue *excludedRange in excludedRanges) {
				if (NSIntersectionRange(range, excludedRange.rangeValue).length > 0) {
					return;
				}
			}

			if (exactMatching) {
				if ([self sectionOfBodyIsSurroundedByNonAlphabeticals:range] == NO) {
					return;
				}
			}

			if ([self->_bodyWithAttributes isAttributeSet:TVCLogRendererFormattingURLAttribute inRange:range] == NO) {
				[self->_bodyWithAttributes addAttribute:TVCLogRendererFormattingKeywordHighlightAttribute value:@(YES) range:range];

				foundKeyword = YES;

				*stop = YES;
			}
		} options:NSCaseInsensitiveSearch];

		if (foundKeyword) {
			break;
		}
	}

	return foundKeyword;
}

- (BOOL)matchKeywordsUsingRegularExpression:(NSArray<NSString *> *)keywords excludedRanges:(NSArray<NSValue *> *)excludedRanges
{
	NSParameterAssert(keywords != nil);
	NSParameterAssert(excludedRanges != nil);

	NSString *body = self->_body;

	BOOL foundKeyword = NO;

	for (NSString *keyword in keywords) {
		NSRange range = [XRRegularExpression string:body rangeOfRegex:keyword withoutCase:YES];

		if (range.location == NSNotFound) {
			continue;
		}

		BOOL enabled = YES;

		for (NSValue *excludedRange in excludedRanges) {
			if (NSIntersectionRange(range, excludedRange.rangeValue).length > 0) {
				enabled = NO;

				break;
			}
		}

		if (enabled == NO) {
			continue;
		}

		if ([self->_bodyWithAttributes isAttributeSet:TVCLogRendererFormattingURLAttribute inRange:range] == NO) {
			[self->_bodyWithAttributes addAttribute:TVCLogRendererFormattingKeywordHighlightAttribute value:@(YES) range:range];

			foundKeyword = YES;

			break;
		}
	}

	return foundKeyword;
}

/* A channel name starts with one of the server's channel prefixes (CHANTYPES) and
 runs until a space, comma or BEL, which a name can't contain */
+ (nullable NSRegularExpression *)channelNameExpressionForPrefixes:(NSArray<NSString *> *)prefixes
{
	NSParameterAssert(prefixes != nil);

	static NSCache<NSString *, NSRegularExpression *> *cache = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cache = [NSCache new];
	});

	NSString *prefixCharacters = [prefixes componentsJoinedByString:@""];

	NSRegularExpression *expression = [cache objectForKey:prefixCharacters];

	if (expression) {
		return expression;
	}

	NSMutableString *prefixClass = [NSMutableString string];

	[prefixCharacters enumerateSubstringsInRange:prefixCharacters.range
										 options:NSStringEnumerationByComposedCharacterSequences
									  usingBlock:^(NSString * _Nullable character, NSRange characterRange, NSRange enclosingRange, BOOL *stop) {
		if (character == nil) {
			return;
		}

		/* Punctuation is escaped inside the character class; letters and digits can't be */
		if ([character rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location == NSNotFound) {
			[prefixClass appendString:@"\\"];
		}

		[prefixClass appendString:character];
	}];

	NSString *pattern = [NSString stringWithFormat:@"[%@][^\\s,\\x07]+", prefixClass];

	expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];

	if (expression) {
		[cache setObject:expression forKey:prefixCharacters];
	}

	return expression;
}

/* Punctuation that ends a sentence ("join #textual.") isn't part of the name */
+ (NSArray<NSValue *> *)channelNameRangesInString:(NSString *)string withPrefixes:(NSArray<NSString *> *)prefixes
{
	NSParameterAssert(string != nil);
	NSParameterAssert(prefixes != nil);

	if (prefixes.count == 0) {
		prefixes = @[@"#"];
	}

	NSRegularExpression *expression = [self channelNameExpressionForPrefixes:prefixes];

	if (expression == nil) {
		return @[];
	}

	NSCharacterSet *trailingCharacters = [NSCharacterSet characterSetWithCharactersInString:@".,;:!?'\")]}>"];

	NSMutableArray<NSValue *> *ranges = [NSMutableArray array];

	[expression enumerateMatchesInString:string options:0 range:string.range usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop) {
		NSRange range = result.range;

		while (range.length > 1 && [trailingCharacters characterIsMember:[string characterAtIndex:(NSMaxRange(range) - 1)]]) {
			range.length -= 1;
		}

		if (range.length < 2) {
			return;
		}

		[ranges addObject:[NSValue valueWithRange:range]];
	}];

	return [ranges copy];
}

- (void)findAllChannelNames
{
	if ([self isRenderingPRIVMSG_or_NOTICE] == NO) {
		return;
	}

	NSArray *prefixes = self->_viewController.associatedClient.supportInfo.channelNamePrefixes;

	NSArray *ranges = [self.class channelNameRangesInString:self->_body withPrefixes:(prefixes ?: @[])];

	for (NSValue *rangeValue in ranges) {
		NSRange range = rangeValue.rangeValue;

		if ([self sectionOfBodyIsSurroundedByNonAlphabeticals:range] == NO) {
			continue;
		}

		if ([self->_bodyWithAttributes isAttributeSet:TVCLogRendererFormattingURLAttribute inRange:range] == NO) {
			[self->_bodyWithAttributes addAttribute:TVCLogRendererFormattingChannelNameAttribute value:@(YES) range:range];
		}
	}
}

- (BOOL)sectionOfBodyIsSurroundedByNonAlphabeticals:(NSRange)range
{
	NSString *body = self->_body;

	NSUInteger bodyLength = body.length;

	UniChar aa = [body characterAtIndex:range.location];

	if (CS_StringIsBase10Numeric(aa) || [THOUnicodeHelper isAlphabeticalCodePoint:aa]) {
		NSInteger leftLocation = (range.location - 1);

		if (leftLocation >= 0 && leftLocation < bodyLength) {
			UniChar bb = [body characterAtIndex:leftLocation];

			if (CS_StringIsBase10Numeric(bb) || [THOUnicodeHelper isAlphabeticalCodePoint:bb]) {
				return NO;
			}
		}
	}

	UniChar cc = [body characterAtIndex:(NSMaxRange(range) - 1)];

	if (CS_StringIsBase10Numeric(cc) || [THOUnicodeHelper isAlphabeticalCodePoint:cc]) {
		NSInteger rightLocation = NSMaxRange(range);

		if (rightLocation < bodyLength) {
			UniChar dd = [body characterAtIndex:rightLocation];

			if (CS_StringIsBase10Numeric(dd) || [THOUnicodeHelper isAlphabeticalCodePoint:dd]) {
				return NO;
			}
		}
	}

	return YES;
}

/* Letters and digits; next to each other they make one word */
static BOOL _isWordCharacter(UniChar character)
{
	return (CS_StringIsBase10Numeric(character) || [THOUnicodeHelper isAlphabeticalCodePoint:character]);
}

/* The other characters a nickname can contain (RFC 2812) */
static BOOL _isNicknameSpecialCharacter(UniChar character)
{
	switch (character) {
		case '[': case ']': case '\\': case '`': case '_': case '^': case '{': case '|': case '}': case '-':
		{
			return YES;
		}
	}

	return NO;
}

/* Every part of the message that could be a whole nickname: a run of nickname
 characters, or a piece of one that begins and ends next to a special character
 (so "[bob]" and "ab-cd" still find "bob" and "ab"), never part of a word */
+ (NSArray<NSValue *> *)nicknameCandidateRangesInString:(NSString *)string
{
	NSParameterAssert(string != nil);

	static const NSUInteger maximumNicknameLength = 64;

	NSUInteger length = string.length;

	NSMutableArray<NSValue *> *ranges = [NSMutableArray array];

	NSUInteger position = 0;

	while (position < length) {
		UniChar character = [string characterAtIndex:position];

		if (_isWordCharacter(character) == NO && _isNicknameSpecialCharacter(character) == NO) {
			position += 1;

			continue;
		}

		/* One run of nickname characters */
		NSUInteger runStart = position;

		while (position < length) {
			character = [string characterAtIndex:position];

			if (_isWordCharacter(character) == NO && _isNicknameSpecialCharacter(character) == NO) {
				break;
			}

			position += 1;
		}

		NSUInteger runEnd = position;

		/* Where a candidate can start or end inside the run: at its edges and next to a special character */
		NSMutableIndexSet *starts = [NSMutableIndexSet indexSetWithIndex:runStart];
		NSMutableIndexSet *ends = [NSMutableIndexSet indexSetWithIndex:runEnd];

		for (NSUInteger i = runStart; i < runEnd; i++) {
			if (_isNicknameSpecialCharacter([string characterAtIndex:i])) {
				[starts addIndex:i];
				[starts addIndex:(i + 1)];

				[ends addIndex:i];
				[ends addIndex:(i + 1)];
			}
		}

		[starts enumerateIndexesUsingBlock:^(NSUInteger start, BOOL *stopStarts) {
			if (start >= runEnd) {
				return;
			}

			[ends enumerateIndexesUsingBlock:^(NSUInteger end, BOOL *stopEnds) {
				if (end <= start || (end - start) > maximumNicknameLength) {
					return;
				}

				[ranges addObject:[NSValue valueWithRange:NSMakeRange(start, (end - start))]];
			}];
		}];
	}

	return [ranges copy];
}

- (void)scanBodyForChannelMembers
{
	if ([self isRenderingPRIVMSG] == NO) {
		return;
	}

	NSString *body = self->_body;

	NSUInteger bodyLength = body.length;

	if (bodyLength == 0) {
		self->_outputDictionary[TVCLogRendererResultsListOfUsersFoundAttribute] = [NSSet set];

		return;
	}

	IRCChannel *channel = self->_viewController.associatedChannel;

	NSUInteger totalNicknameCount = 0;
	NSUInteger totalNicknameLength = 0;

	NSMutableSet<IRCChannelUser *> *userSet = [NSMutableSet set];

	/* The words in the message that could be nicknames are looked up, instead of
	 searching the message once for every member (thousands in a big channel) */
	for (NSValue *rangeValue in [self.class nicknameCandidateRangesInString:body]) {
		NSRange range = rangeValue.rangeValue;

		IRCChannelUser *user = [channel findMember:[body substringWithRange:range]];

		if (user == nil) {
			continue;
		}

		if ([self->_bodyWithAttributes isAttributeSet:TVCLogRendererFormattingURLAttribute inRange:range]) {
			continue;
		}

		[self->_bodyWithAttributes addAttribute:TVCLogRendererFormattingConversationTrackingAttribute value:@(YES) range:range];

		[userSet addObject:user];

		if ([self->_bodyWithAttributes isAttributeSet:TVCLogRendererFormattingKeywordHighlightAttribute inRange:range] == NO) {
			totalNicknameCount += 1;
			totalNicknameLength += range.length;
		}
	}

	/* Calculate how much of the message is just nicknames.
	 This is used when trying to stop highlight spam.
	 Textual counts anything above 75% spam. */
	if ([TPCPreferences automaticallyDetectHighlightSpam]) {
		double nicknamePercent = (((double)totalNicknameLength / bodyLength) * 100.0);

		if ((nicknamePercent > 75.0 && totalNicknameCount > 10) ||
			(nicknamePercent > 50.0 && totalNicknameCount > 20))
		{
			self->_outputDictionary[TVCLogRendererResultsKeywordMatchFoundAttribute] = @(NO);
		}
	}

	self->_outputDictionary[TVCLogRendererResultsListOfUsersFoundAttribute] = [userSet copy];
}

#pragma mark -

- (NSDictionary<NSString *, id> *)appKitAttributesFromRendererAttributes:(NSDictionary<NSString *, id> *)attributesIn
{
	NSParameterAssert(attributesIn != nil);

	NSMutableDictionary<NSString *, id> *attributesOut = [NSMutableDictionary dictionary];

	NSFont *defaultFont = self->_rendererAttributes[TVCLogRendererConfigurationAttributedStringPreferredFontAttribute];

	NSColor *defaultFontColor = self->_rendererAttributes[TVCLogRendererConfigurationAttributedStringPreferredFontColorAttribute];

	NSFont *boldItalicFont = defaultFont;

	if ([attributesIn containsKey:TVCLogRendererFormattingMonospaceTextAttribute]) {
		boldItalicFont = [RZFontManager() convertFont:boldItalicFont toFamily:@"Menlo"];

		attributesOut[IRCTextFormatterMonospaceAttributeName] = @(YES);
	}

	if ([attributesIn containsKey:TVCLogRendererFormattingBoldTextAttribute]) {
		boldItalicFont = [RZFontManager() convertFont:boldItalicFont toHaveTrait:NSBoldFontMask];

		attributesOut[IRCTextFormatterBoldAttributeName] = @(YES);
	}

	if ([attributesIn containsKey:TVCLogRendererFormattingItalicTextAttribute]) {
		boldItalicFont = [RZFontManager() convertFont:boldItalicFont toHaveTrait:NSItalicFontMask];

		if ([boldItalicFont fontTraitSet:NSItalicFontMask] == NO) {
			boldItalicFont = boldItalicFont.convertToItalics;
		}

		attributesOut[IRCTextFormatterItalicAttributeName] = @(YES);
	}

	if (boldItalicFont) {
		attributesOut[NSFontAttributeName] = boldItalicFont;
	}

	if ([attributesIn containsKey:TVCLogRendererFormattingStrikethroughTextAttribute]) {
		attributesOut[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);

		attributesOut[IRCTextFormatterStrikethroughAttributeName] = @(YES);
	}

	if ([attributesIn containsKey:TVCLogRendererFormattingUnderlineTextAttribute]) {
		attributesOut[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);

		attributesOut[IRCTextFormatterUnderlineAttributeName] = @(YES);
	}

	if ([attributesIn containsKey:TVCLogRendererFormattingForegroundColorAttribute]) {
		id foregroundColor = attributesIn[TVCLogRendererFormattingForegroundColorAttribute];

		attributesOut[NSForegroundColorAttributeName] = [self.class mapColor:foregroundColor];

		attributesOut[IRCTextFormatterForegroundColorAttributeName] = foregroundColor;
	} else {
		if (defaultFontColor) {
			attributesOut[NSForegroundColorAttributeName] = defaultFontColor;
		}
	}

	if ([attributesIn containsKey:TVCLogRendererFormattingBackgroundColorAttribute]) {
		id backgroundColor = attributesIn[TVCLogRendererFormattingBackgroundColorAttribute];

		attributesOut[NSBackgroundColorAttributeName] = [self.class mapColor:backgroundColor];

		attributesOut[IRCTextFormatterBackgroundColorAttributeName] = backgroundColor;
	}

	return [attributesOut copy];
}

- (nullable NSString *)renderStringAsHTML:(NSString *)string withAttributes:(NSDictionary<NSString *, id> *)stringAttributes inRange:(NSRange)attributesRange isFirstFragment:(BOOL)isFirstFragment isLastFragment:(BOOL)isLastFragment
{
	NSParameterAssert(string != nil);
	NSParameterAssert(stringAttributes != nil);

	NSString *html = nil;

	NSString *fragment = [string substringWithRange:attributesRange];

	NSMutableDictionary<NSString *, id> *templateTokens = [NSMutableDictionary dictionary];

	AHHyperlinkScannerResult *link = stringAttributes[TVCLogRendererFormattingURLAttribute];

	/* Links with a script or local scheme (javascript:, data:, …) are shown as text */
	if (link && [self.class isClickableLinkLocation:link.stringValue])
	{
		NSString *linkLocation = link.stringValue;

		if (self->_viewController.inlineMediaEnabledForView) {
			NSDictionary *linksMapped = self->_outputDictionary[TVCLogRendererResultsListOfLinksMappedInBodyAttribute];

			NSString *uniqueIdentifier = linksMapped[linkLocation];

			if (uniqueIdentifier) {
				templateTokens[@"anchorInlineMediaAvailable"] = @(YES);
				templateTokens[@"anchorInlineMediaUniqueID"] = uniqueIdentifier;
			}
		}

		templateTokens[@"anchorLocation"] = linkLocation;

		templateTokens[@"anchorTitle"] = [self.class escapeString:fragment];

		html = [self.class renderTemplateNamed:@"renderedStandardAnchorLinkResource" attributes:templateTokens];
	}
	else if ([stringAttributes containsKey:TVCLogRendererFormattingChannelNameAttribute])
	{
		templateTokens[@"channelName"] = [self.class escapeString:fragment];

		html = [self.class renderTemplateNamed:@"renderedChannelNameLinkResource" attributes:templateTokens];
	}
	else if ([stringAttributes containsKey:TVCLogRendererFormattingConversationTrackingAttribute])
	{
		if ([TPCPreferences disableNicknameColorHashing]) {
			templateTokens[@"inlineNicknameMatchFound"] = @(NO);
		} else {
			IRCChannel *channel = self->_viewController.associatedChannel;

			IRCChannelUser *member = [channel findMember:fragment];

			NSString *nickname = member.user.nickname;

			if (nickname.length > 1) {
				NSString *modeSymbol = @"";

				if ([TPCPreferences conversationTrackingIncludesUserModeSymbol]) {
					NSString *modeSymbolTemp = member.mark;

					if (attributesRange.location > 0) {
						NSString *leftCharacter = [string stringCharacterAtIndex:(attributesRange.location - 1)];

						if ([leftCharacter isEqualToString:modeSymbolTemp] == NO) {
							modeSymbol = modeSymbolTemp;
						}
					} else {
						modeSymbol = modeSymbolTemp;
					}
				}

				NSString *nicknameColorStyle = [IRCUserNicknameColorStyleGenerator nicknameColorStyleForString:nickname];

				templateTokens[@"inlineNicknameMatchFound"] = @(YES);

				templateTokens[@"inlineNicknameColorStyle"] = nicknameColorStyle;

				templateTokens[@"inlineNicknameUserModeSymbol"] = modeSymbol;
			}
		}

		html = [self.class escapeString:fragment];
	}

	BOOL escapeBody = self.escapeBody;

	templateTokens[@"messageFragmentEscaped"] = @(escapeBody);

	if (html == nil) {
		if (escapeBody) {
			html = [self.class escapeString:fragment];
		} else {
			html = fragment;
		}
	}

	// --- //

	if (self->_renderedBodyOpenAttributes == nil) {
		self->_renderedBodyOpenAttributes = [NSMutableDictionary dictionary];
	}

	void (^processToggleEffectsAttribute)(NSString *, NSString *) = ^(NSString *effectAttribute, NSString *effectTokenName)
	{
		if ([stringAttributes containsKey:effectAttribute]) {
			templateTokens[effectTokenName] = @(YES); // backwards compatibility

			if ([self->_renderedBodyOpenAttributes boolForKey:effectAttribute] == NO) {
				[self->_renderedBodyOpenAttributes setBool:YES forKey:effectAttribute];

				NSString *openedTokenName = [NSString stringWithFormat:@"%@Opened", effectTokenName];

				templateTokens[openedTokenName] = @(YES);
			}

			if (isLastFragment) {
				NSString *closedTokenName = [NSString stringWithFormat:@"%@ClosedAtEnd", effectTokenName];

				templateTokens[closedTokenName] = @(YES);
			}
		} else {
			if ([self->_renderedBodyOpenAttributes boolForKey:effectAttribute]) {
				[self->_renderedBodyOpenAttributes removeObjectForKey:effectAttribute];

				NSString *closedTokenName = [NSString stringWithFormat:@"%@ClosedAtStart", effectTokenName];

				templateTokens[closedTokenName] = @(YES);
			}
		}
	};

	processToggleEffectsAttribute(TVCLogRendererFormattingBoldTextAttribute, @"fragmentIsBold");
	processToggleEffectsAttribute(TVCLogRendererFormattingItalicTextAttribute, @"fragmentIsItalicized");
	processToggleEffectsAttribute(TVCLogRendererFormattingMonospaceTextAttribute, @"fragmentIsMonospace");
	processToggleEffectsAttribute(TVCLogRendererFormattingStrikethroughTextAttribute, @"fragmentIsStruckthrough");
	processToggleEffectsAttribute(TVCLogRendererFormattingUnderlineTextAttribute, @"fragmentIsUnderlined");

	// --- //

	id foregroundColorNew = stringAttributes[TVCLogRendererFormattingForegroundColorAttribute];
	id backgroundColorNew = stringAttributes[TVCLogRendererFormattingBackgroundColorAttribute];

	id foregroundColorOld = self->_renderedBodyOpenAttributes[TVCLogRendererFormattingForegroundColorAttribute];
	id backgroundColorOld = self->_renderedBodyOpenAttributes[TVCLogRendererFormattingBackgroundColorAttribute];

	NSString *foregroundColor = nil;
	NSString *backgroundColor = nil;

	BOOL setNewColors = YES;

	if (foregroundColorOld || backgroundColorOld)
	{
		/* There is no need to open a new HTML segment if the color hasn't changed. */
		if ([foregroundColorNew isEqual:foregroundColorOld] &&
			 [backgroundColorNew isEqual:backgroundColorOld])
		{
			setNewColors = NO;
		} else {
			templateTokens[@"fragmentTextColorClosedAtStart"] = @(isFirstFragment == NO);
			templateTokens[@"fragmentTextColorClosedAtEnd"] = @(isLastFragment);
		}

		if (foregroundColorOld && foregroundColorNew == nil) {
			[self->_renderedBodyOpenAttributes removeObjectForKey:TVCLogRendererFormattingForegroundColorAttribute];
		}

		if (backgroundColorOld && backgroundColorNew == nil) {
			[self->_renderedBodyOpenAttributes removeObjectForKey:TVCLogRendererFormattingBackgroundColorAttribute];
		}
	}

	if (setNewColors && foregroundColorNew) {
		self->_renderedBodyOpenAttributes[TVCLogRendererFormattingForegroundColorAttribute] = foregroundColorNew;

		BOOL usesStyleTag = NO;

		foregroundColor = [self.class stringValueForColor:foregroundColorNew usesStyleTag:&usesStyleTag];

		templateTokens[@"fragmentTextColorOpened"] = @(YES);
		templateTokens[@"fragmentForegroundColor"] = foregroundColor;
		templateTokens[@"fragmentForegroundColorIsSet"] = @(YES);
		templateTokens[@"fragmentTextColorUsesStyleTag"] = @(usesStyleTag);

		// backwards compatibility
		templateTokens[@"fragmentTextColorIsSet"] = @(YES);
		templateTokens[@"fragmentTextColor"] = templateTokens[@"fragmentForegroundColor"];
	}

	if (setNewColors && backgroundColorNew) {
		self->_renderedBodyOpenAttributes[TVCLogRendererFormattingBackgroundColorAttribute] = backgroundColorNew;

		BOOL usesStyleTag = NO;

		backgroundColor =  [self.class stringValueForColor:backgroundColorNew usesStyleTag:&usesStyleTag];

		templateTokens[@"fragmentTextColorOpened"] = @(YES);
		templateTokens[@"fragmentBackgroundColor"] = backgroundColor;
		templateTokens[@"fragmentBackgroundColorIsSet"] = @(YES);
		templateTokens[@"fragmentTextColorUsesStyleTag"] = @(usesStyleTag);

		// backwards compatibility
		templateTokens[@"fragmentTextColorIsSet"] = @(YES);
	}

	if ([self isRenderingPRIVMSG_or_NOTICE]) {
		templateTokens[@"fragmentIsSpoiler"] = @(setNewColors && [foregroundColor isEqualToString:backgroundColor]);
	} else {
		templateTokens[@"fragmentIsSpoiler"] = @(NO);
	}

	// --- //

	/* Escape spaces that are prefix and suffix characters */
	if (escapeBody) {
		if ([html hasPrefix:@" "]) {
			html = [html stringByReplacingCharactersInRange:NSMakeRange(0, 1)
												 withString:@"&nbsp;"];
		}

		if ([html hasSuffix:@" "]) {
			html = [html stringByReplacingCharactersInRange:NSMakeRange((html.length - 1), 1)
												 withString:@"&nbsp;"];
		}
	}

	// --- //

	templateTokens[@"messageFragment"] = html;

	NSString *plainRender = [self.class renderPlainFragment:html withTemplateTokens:templateTokens];

	if (plainRender) {
		return plainRender;
	}

	return [self.class renderTemplateNamed:@"formattedMessageFragment" attributes:templateTokens];
}

/* Most of a message is plain text: no effect, color, link or nickname. For such a
 fragment the template's output is the same around any text, so it is rendered
 once per template (a style can have its own) and reused. nil when the fragment
 isn't plain or the template uses the text other than once. */
+ (nullable NSString *)renderPlainFragment:(NSString *)html withTemplateTokens:(NSDictionary<NSString *, id> *)templateTokens
{
	NSParameterAssert(html != nil);
	NSParameterAssert(templateTokens != nil);

	for (NSString *key in templateTokens) {
		if ([key isEqualToString:@"messageFragment"] || [key isEqualToString:@"messageFragmentEscaped"]) {
			continue;
		}

		if ([key isEqualToString:@"fragmentIsSpoiler"] && [templateTokens boolForKey:key] == NO) {
			continue;
		}

		return nil;
	}

	GRMustacheTemplate *template = [theme() templateWithName:@"formattedMessageFragment"];

	if (template == nil) {
		return nil;
	}

	static NSMapTable<GRMustacheTemplate *, NSMutableDictionary *> *wrappers = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		wrappers = [NSMapTable weakToStrongObjectsMapTable];
	});

	BOOL escaped = [templateTokens boolForKey:@"messageFragmentEscaped"];

	NSArray *wrapper = nil;

	@synchronized (wrappers) {
		NSMutableDictionary *templateWrappers = [wrappers objectForKey:template];

		if (templateWrappers == nil) {
			templateWrappers = [NSMutableDictionary dictionary];

			[wrappers setObject:templateWrappers forKey:template];
		}

		wrapper = templateWrappers[@(escaped)];

		if (wrapper == nil) {
			NSString *placeholder = @"\uFFFFTextualMessageFragment\uFFFF";

			NSString *render = [self renderTemplate:template attributes:@{
				@"messageFragment" : placeholder,
				@"messageFragmentEscaped" : @(escaped),
				@"fragmentIsSpoiler" : @(NO)
			}];

			NSArray *parts = [render componentsSeparatedByString:placeholder];

			if (parts.count == 2) {
				wrapper = parts;
			} else {
				wrapper = (id)[NSNull null];
			}

			templateWrappers[@(escaped)] = wrapper;
		}
	}

	if ([wrapper isKindOfClass:[NSArray class]] == NO) {
		return nil;
	}

	/* The template's render loses its newlines, the text's included */
	return [NSString stringWithFormat:@"%@%@%@", wrapper[0], html.removeAllNewlines, wrapper[1]];
}

#pragma mark -

- (void)renderFinalResultsAsHTML
{
	NSMutableString *finalResult = [NSMutableString string];

	NSString *string = self->_bodyWithAttributes.string;

	NSUInteger stringLength = string.length;

	[self->_bodyWithAttributes
	 enumerateAttributesInRange:NSMakeRange(0, stringLength)
						options:0
					 usingBlock:^(NSDictionary<NSString *, id> *attributes, NSRange range, BOOL *stop) {
		 BOOL isFirstFragment = (range.location == 0);
		 BOOL isLastFragment = ((range.location + range.length) == stringLength);

		 NSString *html = [self renderStringAsHTML:string
									withAttributes:attributes
										   inRange:range
								   isFirstFragment:isFirstFragment
									isLastFragment:isLastFragment];

		 if (html) {
			 [finalResult appendString:html];
		 }
	 }];

	self.finalResult = finalResult;
}

- (void)renderFinalResultsForAttributedBody
{
	NSMutableAttributedString *finalResult = [self->_bodyWithAttributes mutableCopy];

	NSString *string = self->_bodyWithAttributes.string;

	[self->_bodyWithAttributes
		 enumerateAttributesInRange:NSMakeRange(0, string.length)
							options:0
						 usingBlock:^(NSDictionary<NSString *, id> *attributes, NSRange range, BOOL *stop) {
			 NSDictionary *attributesToAdd = [self appKitAttributesFromRendererAttributes:attributes];

			 [finalResult addAttributes:attributesToAdd range:range];
		 }];

	self.finalResult = finalResult;
}

#pragma mark -

- (void)cleanupResources
{
	self->_body = nil;
	self->_bodyWithAttributes = nil;
	self->_renderedBodyOpenAttributes = nil;
	self->_viewController = nil;
}

+ (NSString *)renderBody:(NSString *)body forViewController:(TVCLogController *)viewController withAttributes:(NSDictionary<NSString *, id> *)inputDictionary resultInfo:(NSDictionary<NSString *, id> * _Nullable * _Nullable)outputDictionary
{
	NSParameterAssert(body != nil);
	NSParameterAssert(viewController != nil);
	NSParameterAssert(inputDictionary != nil);

	if (body.length == 0) {
		return @"";
	}

	TVCLogLineType lineType = [inputDictionary unsignedIntegerForKey:TVCLogRendererConfigurationLineTypeAttribute];

	TVCLogLineMemberType memberType = [inputDictionary unsignedIntegerForKey:TVCLogRendererConfigurationMemberTypeAttribute];

	BOOL escapeBody = ([inputDictionary boolForKey:TVCLogRendererConfigurationDoNotEscapeBodyAttribute] == NO);

	TVCLogRenderer *renderer = [self new];

	renderer.body =
	[THOPluginDispatcher willRenderMessage:body
						 forViewController:viewController
								  lineType:lineType
								memberType:memberType];

	renderer.lineType = lineType;

	renderer.memberType = memberType;

	renderer.escapeBody = escapeBody;

	renderer.rendererAttributes = inputDictionary;

	renderer.viewController = viewController;

	/* Call -stripDangerousUnicodeCharactersFromBody first because it modifies the body. */
	[renderer stripDangerousUnicodeCharactersFromBody];

	[renderer buildEffectsDictionary];

	[renderer buildListOfLinksInBody];

	[renderer matchKeywords];

	[renderer findAllChannelNames];

	[renderer scanBodyForChannelMembers];

	if ( outputDictionary) {
		*outputDictionary = [renderer.outputDictionary copy];
	}

	[renderer renderFinalResultsAsHTML];

	[renderer cleanupResources];

	return renderer.finalResult;
}

+ (NSAttributedString *)renderBodyAsAttributedString:(NSString *)body withAttributes:(NSDictionary<NSString *, id> *)inputDictionary
{
	NSParameterAssert(body != nil);
	NSParameterAssert(inputDictionary != nil);

	if (body.length == 0) {
		return [NSAttributedString attributedString];
	}

	NSFont *defaultFont = inputDictionary[TVCLogRendererConfigurationAttributedStringPreferredFontAttribute];

	NSAssert((defaultFont != nil),
		@"FATAL ERROR: TVCLogRenderer cannot be supplied with a nil 'TVCLogRendererAttributedStringPreferredFontAttribute' attribute when rendering an attributed string");

	TVCLogRenderer *renderer = [self new];

	renderer.body = body;

	renderer.lineType = [inputDictionary unsignedIntegerForKey:TVCLogRendererConfigurationLineTypeAttribute];

	renderer.memberType = [inputDictionary unsignedIntegerForKey:TVCLogRendererConfigurationMemberTypeAttribute];

	renderer.rendererAttributes = inputDictionary;

	[renderer stripDangerousUnicodeCharactersFromBody];

	[renderer buildEffectsDictionary];

	[renderer renderFinalResultsForAttributedBody];

	[renderer cleanupResources];

	return renderer.finalResult;
}

#pragma mark -

+ (nullable NSString *)renderTemplateNamed:(NSString *)templateName
{
	return [self renderTemplateNamed:templateName attributes:nil];
}

+ (nullable NSString *)renderTemplateNamed:(NSString *)templateName attributes:(nullable NSDictionary<NSString *, id> *)templateTokens
{
	NSParameterAssert(templateName != nil);

	GRMustacheTemplate *template = [theme() templateWithName:templateName];

	if (template == nil) {
		return nil;
	}

	return [self renderTemplate:template attributes:templateTokens];
}

+ (nullable NSString *)renderTemplate:(GRMustacheTemplate *)template
{
	return [self renderTemplate:template attributes:nil];
}

+ (nullable NSString *)renderTemplate:(GRMustacheTemplate *)template attributes:(nullable NSDictionary<NSString *, id> *)templateTokens
{
	NSParameterAssert(template != nil);

	NSString *templateRender = [template renderObject:templateTokens error:NULL];

	if (templateRender == nil) {
		return nil;
	}

	return templateRender.removeAllNewlines;
}

+ (NSString *)escapeHTML:(NSString *)html
{
	NSParameterAssert(html != nil);

	NSString *stringEscaped = html.gtm_stringByEscapingForHTML;

	if (stringEscaped == nil) {
		stringEscaped = @"";
	}

	return stringEscaped;
}

+ (NSString *)escapeStringSimple:(NSString *)string
{
	NSParameterAssert(string != nil);

	string = [string stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
	string = [string stringByReplacingOccurrencesOfString:@"  " withString:@"&nbsp;&nbsp;"];

	return string;
}

+ (NSString *)escapeString:(NSString *)string
{
	NSParameterAssert(string != nil);

	NSString *stringEscaped = [self escapeHTML:string];

	return [self escapeStringSimple:stringEscaped];
}

+ (nullable NSString *)stringValueForColor:(id)color usesStyleTag:(BOOL *)usesStyleTag
{
	NSParameterAssert(color != nil);

	if ([color isKindOfClass:[NSColor class]])
	{
		*usesStyleTag = YES;

		return [color hexadecimalValue];
	}
	else if ([color isKindOfClass:[NSNumber class]])
	{
		return [color stringValue];
	}

	return nil;
}

+ (nullable NSColor *)mapColor:(id)color
{
	NSParameterAssert(color != nil);

	if ([color isKindOfClass:[NSColor class]])
	{
		return color;
	}
	else if ([color isKindOfClass:[NSNumber class]])
	{
		return [self mapColorCode:[color unsignedIntegerValue]];
	}

	return nil;
}

+ (NSColor *)mapColorCode:(NSUInteger)colorCode
{
	NSParameterAssert(colorCode <= IRCTextFormatterEffectColorHighestDigit);

	return [NSColor formatterColors][colorCode];
}

@end

NS_ASSUME_NONNULL_END
