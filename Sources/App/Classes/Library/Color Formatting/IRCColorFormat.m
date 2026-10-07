/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "NSObjectHelperPrivate.h"
#import "TVCLogRenderer.h"
#import "IRC.h"
#import "IRCClientConfig.h"
#import "IRCClient.h"
#import "IRCColorFormatPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const IRCTextFormatterBoldAttributeName = @"IRCTextFormatterBoldAttributeName";
NSString * const IRCTextFormatterItalicAttributeName = @"IRCTextFormatterItalicAttributeName";
NSString * const IRCTextFormatterMonospaceAttributeName = @"IRCTextFormatterMonospaceAttributeName";
NSString * const IRCTextFormatterStrikethroughAttributeName = @"IRCTextFormatterStrikethroughAttributeName";
NSString * const IRCTextFormatterUnderlineAttributeName = @"IRCTextFormatterUnderlineAttributeName";
NSString * const IRCTextFormatterForegroundColorAttributeName = @"IRCTextFormatterForegroundColorAttributeName";
NSString * const IRCTextFormatterBackgroundColorAttributeName = @"IRCTextFormatterBackgroundColorAttributeName";
NSString * const IRCTextFormatterSpoilerAttributeName = @"IRCTextFormatterSpoilerAttributeName";

#pragma mark -
#pragma mark Private Headers

@interface NSMutableString (IRCTextFormatterPrivate)
- (NSUInteger)wrapIRCTextFormatterResultWith:(NSUInteger)minimumIndex maxDistance:(NSUInteger)maxDistance;
@end

#pragma mark -
#pragma mark Effects Container

@interface IRCTextFormatterEffect ()
@property (nonatomic, assign, readwrite) IRCTextFormatterEffectType type;
@property (nonatomic, copy, nullable, readwrite) NSString *value;
@property (nonatomic, assign, readwrite) UniChar controlCharacter;
@property (nonatomic, assign, readwrite) NSUInteger length;
@end

@interface IRCTextFormatterEffects ()
@property (nonatomic, copy, readwrite) NSArray<IRCTextFormatterEffect *> *effects;
@property (nonatomic, assign, readwrite) NSUInteger maximumLength;
@end

@implementation IRCTextFormatterEffect

+ (nullable instancetype)effectWithType:(IRCTextFormatterEffectType)type
{
	return [[self alloc] initWithEffect:type withValue:nil];
}

+ (nullable instancetype)effectWithType:(IRCTextFormatterEffectType)type withValue:(nullable id)value
{
	return [[self alloc] initWithEffect:type withValue:value];
}

- (instancetype)init
{
	return [self initWithEffect:IRCTextFormatterEffectNone withValue:nil];
}

- (nullable instancetype)initWithEffect:(IRCTextFormatterEffectType)type
{
	return [self initWithEffect:type withValue:nil];
}

- (nullable instancetype)initWithEffect:(IRCTextFormatterEffectType)type withValue:(nullable id)value
{
	if ((self = [super init])) {
		return [self _setupWithEffect:type withValue:value];
	}

	return nil;
}

- (nullable instancetype)_setupWithEffect:(IRCTextFormatterEffectType)type withValue:(nullable id)value
{
	UniChar controlCharacter = 0x00;

	NSUInteger valueLength = 0;

	NSString *valueOut = nil;

	switch (type) {
		case IRCTextFormatterEffectNone:
		{
			break;
		}
		case IRCTextFormatterEffectBold:
		{
			controlCharacter = IRCTextFormatterEffectBoldCharacter;

			valueLength = 2; // opening and closing

			break;
		}
		case IRCTextFormatterEffectItalic:
		{
			controlCharacter = IRCTextFormatterEffectItalicCharacter;

			valueLength = 2; // opening and closing

			break;
		}
		case IRCTextFormatterEffectMonospace:
		{
			controlCharacter = IRCTextFormatterEffectMonospaceCharacter;

			valueLength = 2; // opening and closing

			break;
		}
		case IRCTextFormatterEffectStrikethrough:
		{
			controlCharacter = IRCTextFormatterEffectStrikethroughCharacter;

			valueLength = 2; // opening and closing

			break;
		}
		case IRCTextFormatterEffectUnderline:
		{
			controlCharacter = IRCTextFormatterEffectUnderlineCharacter;

			valueLength = 2; // opening and closing

			break;
		}
		case IRCTextFormatterEffectForegroundColor:
		case IRCTextFormatterEffectBackgroundColor:
		{
			if ([value isKindOfClass:[NSColor class]])
			{
				controlCharacter = IRCTextFormatterEffectColorAsHexCharacter;

				valueOut = [[value hexadecimalValue] substringFromIndex:1]; // Remove leading #
			}
			else if ([value isKindOfClass:[NSNumber class]])
			{
				controlCharacter = IRCTextFormatterEffectColorAsDigitCharacter;

				valueOut = [value integerStringValueWithLeadingZero];
			}

			if (valueOut == nil) {
				return nil;
			}

			if (type == IRCTextFormatterEffectForegroundColor) {
				valueLength = (valueOut.length + 2); // opening and closing
			} else {
				valueLength = (valueOut.length + 1); // leading comma
			}

			break;
		}
		default:
		{
			/* We return nil because all other formatters are just aliases.
			 For example, spoiler is an alias for foreground and background. */

			return nil;
		}
	}

	self.type = type;

	self.controlCharacter = controlCharacter;

	self.value = valueOut;

	self.length = valueLength;

	return self;
}

- (void)appendToStartOf:(NSMutableString *)string
{
	NSParameterAssert(string != nil);

	IRCTextFormatterEffectType type = self.type;

	NSString *value = self.value;

	if (type == IRCTextFormatterEffectBackgroundColor) {
		[string appendFormat:@",%@", value];

		return;
	}

	UniChar controlCharacter = self.controlCharacter;

	if (value == nil) {
		[string appendFormat:@"%c", controlCharacter];
	} else {
		[string appendFormat:@"%c%@", controlCharacter, value];
	}
}

- (void)appendToEndOf:(NSMutableString *)string
{
	NSParameterAssert(string != nil);

	if (self.type == IRCTextFormatterEffectBackgroundColor) {
		return;
	}

	[string appendFormat:@"%c", self.controlCharacter];
}

@end

#pragma mark -

@implementation IRCTextFormatterEffects

+ (instancetype)effectsInAttributes:(NSDictionary<NSString *, id> *)attributes
{
	return [[self alloc] initWithAttributes:attributes];
}

- (instancetype)init
{
	return [self initWithAttributes:@{}];
}

- (instancetype)initWithAttributes:(NSDictionary<NSString *, id> *)attributes
{
	if ((self = [super init])) {
		return [self _setupWithAttributes:attributes];
	}

	return nil;
}

- (instancetype)_setupWithAttributes:(NSDictionary<NSString *, id> *)attributes
{
	NSUInteger maximumLength = 0;

	NSMutableArray *effects = [NSMutableArray arrayWithCapacity:7];

	IRCTextFormatterEffect *foregroundColor = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectForegroundColor withValue:attributes[IRCTextFormatterForegroundColorAttributeName]];
	IRCTextFormatterEffect *backgroundColor = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectBackgroundColor withValue:attributes[IRCTextFormatterBackgroundColorAttributeName]];

	if (foregroundColor) {
		[effects addObject:foregroundColor];

		maximumLength += foregroundColor.length;

		/* It's important that the background color ALWAYS follows the foreground
		 color because the array will be enumerated in order to append the effects. */
		/* Type of values must be the same. Can't mix and match integer color with hex. */
		if (foregroundColor.controlCharacter ==
			backgroundColor.controlCharacter)
		{
			[effects addObject:backgroundColor];

			maximumLength += backgroundColor.length;
		}
	}

	BOOL textIsBold = [attributes boolForKey:IRCTextFormatterBoldAttributeName];
	BOOL textIsItalicized = [attributes boolForKey:IRCTextFormatterItalicAttributeName];
	BOOL textIsMonospace = [attributes boolForKey:IRCTextFormatterMonospaceAttributeName];
	BOOL textIsStruckthrough = [attributes boolForKey:IRCTextFormatterStrikethroughAttributeName];
	BOOL textIsUnderlined = [attributes boolForKey:IRCTextFormatterUnderlineAttributeName];

	if (textIsBold) {
		IRCTextFormatterEffect *effect = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectBold];

		[effects addObject:effect];

		maximumLength += effect.length;
	}

	if (textIsItalicized) {
		IRCTextFormatterEffect *effect = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectItalic];

		[effects addObject:effect];

		maximumLength += effect.length;
	}

	if (textIsMonospace) {
		IRCTextFormatterEffect *effect = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectMonospace];

		[effects addObject:effect];

		maximumLength += effect.length;
	}

	if (textIsStruckthrough) {
		IRCTextFormatterEffect *effect = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectStrikethrough];

		[effects addObject:effect];

		maximumLength += effect.length;
	}

	if (textIsUnderlined) {
		IRCTextFormatterEffect *effect = [IRCTextFormatterEffect effectWithType:IRCTextFormatterEffectUnderline];

		[effects addObject:effect];

		maximumLength += effect.length;
	}

	self.effects = effects;

	self.maximumLength = maximumLength;

	return self;
}

- (void)appendToStartOf:(NSMutableString *)string
{
	NSParameterAssert(string != nil);

	for (IRCTextFormatterEffect *effect in self.effects) {
		[effect appendToStartOf:string];
	}
}

- (void)appendToEndOf:(NSMutableString *)string
{
	NSParameterAssert(string != nil);

	/* Remember to use a reverse enumerator when closing because
	 we need to close in the same order in which we opened. */
	for (IRCTextFormatterEffect *effect in self.effects.reverseObjectEnumerator) {
		[effect appendToEndOf:string];
	}
}

@end

#pragma mark -
#pragma mark Text Truncation

@implementation NSAttributedString (IRCTextFormatterPrivate)

- (NSString *)stringFormattedForChannel:(NSString *)channelName onClient:(IRCClient *)client withLineType:(TVCLogLineType)lineType effectiveRange:(NSRange * _Nullable)effectiveRange
{
	NSParameterAssert(channelName != nil);
	NSParameterAssert(client != nil);

	/* ///////////////////////////////////////////////////// */
	/*
	 Server-side truncation does not count the total number of characters
	 in the received message alone. It also counts everything that precedes
	 it including hostmask, channel name, and command, and newline.

	 Example: ":<nickname>!<username>@<address> PRIVMSG #<channel> :<message>\r\n"

	 The following math takes into account this information.

	 Do not extend this method to support anything more than plain text
	 messages such as PRIVMSG, ACTION, and NOTICE.
	 */
	/* ///////////////////////////////////////////////////// */

#define	_textTruncationPRIVMSGCommandConstant			9  // "PRIVMSG" + surrounding spaces
#define	_textTruncationACTIONCommandConstant			17 // "PRIVMSG" + surrounding spaces + 0x01 + "ACTION" + 0x01
#define _textTruncationNOTICECommandConstant			8  // "NOTICE" + surrounding spaces

#define _textTruncationHostmaskConstant					60 // Used if local hostmask is unknown

	/* Maximum distance from end of string that we will
	 locate a character to perform wrapping on. */
#define	_textTruncationWrapMaxDistance			25

	/* Add length of colon (":") */
	NSUInteger minimumLength = 1;

	/* Add length of hostmask */
	NSString *userHostmask = client.userHostmask;

	if (userHostmask == nil) {
		minimumLength += _textTruncationHostmaskConstant; // It's better to have something rather than nothing
	} else {
		minimumLength += userHostmask.length;
	}

	/* Add length of command */
	if (lineType == TVCLogLineTypePrivateMessage || lineType == TVCLogLineTypePrivateMessageNoHighlight) {
		minimumLength += _textTruncationPRIVMSGCommandConstant;
	} else if (lineType == TVCLogLineTypeAction || lineType == TVCLogLineTypeActionNoHighlight) {
		minimumLength += _textTruncationACTIONCommandConstant;
	} else if (lineType == TVCLogLineTypeNotice) {
		minimumLength += _textTruncationNOTICECommandConstant;
	} else {
		NSAssert(NO, @"Line type not supported");
	}

	/* Add length of channel name */
	minimumLength += channelName.length;

	/* Add length of space trailing channel name and colon (" :") */
	minimumLength += 2;

	/* Add length of trailing \r\n */
	minimumLength += 2;

	/* Calculate maximum length */
	NSUInteger maximumLength = TXMaximumIRCBodyLength;

	/* Perform truncation */
	NSString *string = self.string;

	NSStringEncoding encoding = client.config.primaryEncoding;

	NSMutableString *result = [NSMutableString string];

	// Length of result with formatters
	__block NSUInteger resultLength = minimumLength;

	// Length of result without formatters
	__block NSUInteger deletionLength  = 0;

	// Range of attribute segment being worked on
	NSRange segmentRange;

	// Maximum range to find next attribute segment within.
	// Defaults to string length because we don't know where
	// the first attribute segment may be until first pass.
	NSRange limitRange = NSMakeRange(0, string.length);

	/* Enumerate attributes */
	while (limitRange.length > 0) {
		BOOL breakLoopAfterAppend = NO;

		/* ///////////////////////////////////////////////////// */
		/* Gather information about the formatters and calculate
		 the total number of bytes necessary to support them. */
		/* ///////////////////////////////////////////////////// */

		NSDictionary *attributes = [self attributesAtIndex:limitRange.location
									 longestEffectiveRange:&segmentRange
												   inRange:limitRange];

		IRCTextFormatterEffects *formatters = [IRCTextFormatterEffects effectsInAttributes:attributes];

		NSUInteger formattersLength = formatters.maximumLength;

		/* ///////////////////////////////////////////////////// */
		/* Now that we know the minimum length and number of bytes
		 for the formatters, we can start building the result. */
		/* ///////////////////////////////////////////////////// */

		/* At this point we do not care what the actual length of this segment is.
		 The math only checks two things: Whether the formatter bytes found above
		 will fit into this segment as well as at least one unicode character with
		 a length of two. If neither of those can fit, then this segment is junk
		 and we can break from it. */

		/* If the location of this segment is 0, then we don't have to worry
		 about checking the length yet. Since the formatter bytes will occupy
		 at maximum X entries at location 0, we can do our append until the
		 next, middle, or end segment. */

		if (segmentRange.location > 0) {   // Length calculations for the middle of our string.
										   // Sally sold seashells down by the seashore.
										   //        |----------------------| <--- section we have to find

			NSUInteger
			newLength = (resultLength			+ // Length of what we have already formatted.
						 formattersLength		+ // The formatter bytes for this segment.
						 2);					  // The sad little two. A single unicode character.

			/* Will this new segment exceed the maximum size? */
			if (newLength > maximumLength) {
				break;
			}
		}

		/* Update math */
		resultLength += formattersLength;

		/* Append formatter openers */
		[formatters appendToStartOf:result];

		/* We now go character by character and append that. We keep appending until
		 the segment is completed or we run out  of space. When that happens, we break.
		 We have already added the formatter bytes into the math so any math checked in
		 the loop will only be count towards the appended characters. */
		for (NSUInteger i = 0; i < segmentRange.length;) {
			NSUInteger characterIndex = (segmentRange.location + i);

			/* While an emoji looks like only one character, it can be multiple bytes.
			 We use -rangeOfComposedCharacterSequenceAtIndex: to know the true length
			 of the character we are about to append. */
			NSRange characterRange = [string rangeOfComposedCharacterSequenceAtIndex:characterIndex];

			NSString *character = [string substringWithRange:characterRange];

			/* Update math */
			NSInteger characterSize = [character lengthOfBytesUsingEncoding:encoding];

			if (characterSize == 0) {
				characterSize = characterRange.length; // Just incase...
			}

			resultLength += characterSize;

			/* Would this character go over the max length? */
			if (resultLength > maximumLength) {
				/* Look for best character to wrap on */
				NSUInteger indexDifference = [result wrapIRCTextFormatterResultWith:segmentRange.location maxDistance:_textTruncationWrapMaxDistance];

				if (indexDifference != NSNotFound) {
					deletionLength -= indexDifference;
				}

				/* Break attribute enumeration using stater variable
				 because we are in nested statements. */
				breakLoopAfterAppend = YES;

				break; // Break instead of return so that we can close formatters
			}

			/* Only update if we aren't at max */
			deletionLength += characterRange.length;

			i += characterRange.length;

			/* Perform append */
			[result appendString:character];
		}

		/* Close formatters */
		[formatters appendToEndOf:result];

		/* Break from enumeration */
		if (breakLoopAfterAppend) {
			break;
		}

		/* Calculate next range to find an attribute segment within. */
		NSUInteger segmentRangeNewLength = (string.length - deletionLength);

		if (segmentRangeNewLength <= 0) {
			break;
		}

		segmentRange.location = deletionLength;

		segmentRange.length = segmentRangeNewLength;

		limitRange = segmentRange;
	} // attribute enumeration

	/* Return length that can be deleted to occupy the result */
	if ( effectiveRange) {
		*effectiveRange = NSMakeRange(0, deletionLength);
	}

	/* Debug information */
	LogToConsoleDebug("Minimum length: %{public}ld; Final length: %{public}ld; Difference: %{public}ld;",
		 minimumLength, resultLength, (maximumLength - resultLength));

#undef _textTruncationPRIVMSGCommandConstant
#undef _textTruncationACTIONCommandConstant
#undef _textTruncationNOTICECommandConstant

#undef _textTruncationHostmaskConstant

#undef _textTruncationWrapMaxDistance

	return result;
}

@end

#pragma mark -

@implementation NSMutableAttributedString (IRCTextFormatterPrivate)

- (NSString *)stringFormattedForChannel:(NSString *)channelName onClient:(IRCClient *)client withLineType:(TVCLogLineType)lineType
{
	NSParameterAssert(channelName != nil);
	NSParameterAssert(client != nil);

	NSRange effectiveRange;

	NSString *result = [self stringFormattedForChannel:channelName onClient:client withLineType:lineType effectiveRange:&effectiveRange];

	[self deleteCharactersInRange:effectiveRange];

	return result;
}

@end

#pragma mark -

@implementation NSAttributedString (IRCTextFormatter)

#pragma mark -
#pragma mark Text Truncation

- (NSString *)stringFormattedForIRC
{
	NSString *string = self.string;

	NSMutableString *result = [NSMutableString string];

	[self enumerateAttributesInRange:self.range
							 options:0
						  usingBlock:^(NSDictionary *attributes, NSRange effectiveRange, BOOL *stop)
	 {
		 IRCTextFormatterEffects *formatters = [IRCTextFormatterEffects effectsInAttributes:attributes];

		 [formatters appendToStartOf:result];

		 NSString *segment = [string substringWithRange:effectiveRange];

		 [result appendString:segment];

		 [formatters appendToEndOf:result];
	 }];

	return result;
}

- (BOOL)IRCFormatterAttributeSetInRange:(IRCTextFormatterEffectType)effect
								  range:(NSRange)limitRange
{
	__block BOOL returnValue = NO;

	[self enumerateAttributesInRange:limitRange
							 options:0
						  usingBlock:^(NSDictionary *attributes, NSRange effectiveRange, BOOL *stop)
	 {
		 switch (effect) {
			 case IRCTextFormatterEffectNone:
			 {
					break;
			 }
			 case IRCTextFormatterEffectBold:
			 {
				 if ([attributes boolForKey:IRCTextFormatterBoldAttributeName] == NO) {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectItalic:
			 {
				 if ([attributes boolForKey:IRCTextFormatterItalicAttributeName] == NO) {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectMonospace:
			 {
				 if ([attributes boolForKey:IRCTextFormatterMonospaceAttributeName] == NO) {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectUnderline:
			 {
				 if ([attributes boolForKey:IRCTextFormatterUnderlineAttributeName] == NO) {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectStrikethrough:
			 {
				 if ([attributes boolForKey:IRCTextFormatterStrikethroughAttributeName] == NO) {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectForegroundColor:
			 {
				 id foregroundColor = attributes[IRCTextFormatterForegroundColorAttributeName];

				 if (foregroundColor == nil) {
					 return;
				 }

				 if ([foregroundColor isKindOfClass:[NSNumber class]])
				 {
					 NSInteger colorCode = [foregroundColor integerValue];

					 if (colorCode < 0 || colorCode > IRCTextFormatterEffectColorHighestDigit) {
						 return;
					 }
				 }
				 else if ([foregroundColor isKindOfClass:[NSColor class]] == NO)
				 {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectBackgroundColor:
			 {
				 id backgroundColor = attributes[IRCTextFormatterBackgroundColorAttributeName];

				 if (backgroundColor == nil) {
					 return;
				 }

				 if ([backgroundColor isKindOfClass:[NSNumber class]])
				 {
					 NSInteger colorCode = [backgroundColor integerValue];

					 if (colorCode < 0 || colorCode > IRCTextFormatterEffectColorHighestDigit) {
						 return;
					 }
				 }
				 else if ([backgroundColor isKindOfClass:[NSColor class]] == NO)
				 {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
			 case IRCTextFormatterEffectSpoiler:
			 {
				 if ([attributes boolForKey:IRCTextFormatterSpoilerAttributeName] == NO) {
					 return;
				 }

				 returnValue = YES;

				 *stop = YES;

				 break;
			 }
		 }
	 }];

	return returnValue;
}

@end

#pragma mark -
#pragma mark Adding/Removing Formatting

@implementation NSMutableAttributedString (IRCTextFormatter)

- (void)setIRCFormatterAttribute:(IRCTextFormatterEffectType)effect
						   value:(id)value
						   range:(NSRange)limitRange
{
	[self enumerateAttributesInRange:limitRange
							 options:NSAttributedStringEnumerationReverse
						  usingBlock:^(NSDictionary *attributes, NSRange effectiveRange, BOOL *stop)
	 {
		 NSFont *baseFont = attributes[NSFontAttributeName];

		 switch (effect) {
			 case IRCTextFormatterEffectNone:
			 {
					break;
			 }
			 case IRCTextFormatterEffectBold:
			 {
				 if ([baseFont fontTraitSet:NSBoldFontMask] == NO) {
					 baseFont = [RZFontManager() convertFont:baseFont toHaveTrait:NSBoldFontMask];
				 }

				 if (baseFont) {
					 [self addAttribute:IRCTextFormatterBoldAttributeName value:@(YES) range:effectiveRange];

					 [self addAttribute:NSFontAttributeName value:baseFont range:effectiveRange];
				 }

				 break;
			 }
			 case IRCTextFormatterEffectItalic:
			 {
				 if ([baseFont fontTraitSet:NSItalicFontMask] == NO) {
					 baseFont = [RZFontManager() convertFont:baseFont toHaveTrait:NSItalicFontMask];
				 }

				 if (baseFont) {
					 [self addAttribute:IRCTextFormatterItalicAttributeName value:@(YES) range:effectiveRange];

					 [self addAttribute:NSFontAttributeName value:baseFont range:effectiveRange];
				 }

				 break;
			 }
			 case IRCTextFormatterEffectMonospace:
			 {
				 baseFont = [RZFontManager() convertFont:baseFont toFamily:@"Menlo"];

				 [self addAttribute:IRCTextFormatterMonospaceAttributeName value:@(YES) range:effectiveRange];

				 [self addAttribute:NSFontAttributeName value:baseFont range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectUnderline:
			 {
				 [self addAttribute:IRCTextFormatterUnderlineAttributeName value:@(YES) range:effectiveRange];

				 [self addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectStrikethrough:
			 {
				 [self addAttribute:IRCTextFormatterStrikethroughAttributeName value:@(YES) range:effectiveRange];

				 [self addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectForegroundColor:
			 {
				 if (value == nil) {
					 break;
				 }

				 if ([value isKindOfClass:[NSNumber class]])
				 {
					 NSInteger colorCode = [value integerValue];

					 if (colorCode >= 0 && colorCode <= IRCTextFormatterEffectColorHighestDigit) {
						 [self addAttribute:IRCTextFormatterForegroundColorAttributeName value:@(colorCode) range:effectiveRange];

						 [self addAttribute:NSForegroundColorAttributeName value:[TVCLogRenderer mapColorCode:colorCode] range:effectiveRange];
					 }
				 }
				 else if ([value isKindOfClass:[NSColor class]])
				 {
					 [self addAttribute:IRCTextFormatterForegroundColorAttributeName value:value range:effectiveRange];

					 [self addAttribute:NSForegroundColorAttributeName value:value range:effectiveRange];
				 }

				 break;
			 }
			 case IRCTextFormatterEffectBackgroundColor:
			 {
				 if (value == nil) {
					 break;
				 }

				 if ([value isKindOfClass:[NSNumber class]])
				 {
					 NSInteger colorCode = [value integerValue];

					 if (colorCode >= 0 && colorCode <= IRCTextFormatterEffectColorHighestDigit) {
						 [self addAttribute:IRCTextFormatterBackgroundColorAttributeName value:@(colorCode) range:effectiveRange];

						 [self addAttribute:NSBackgroundColorAttributeName value:[TVCLogRenderer mapColorCode:colorCode] range:effectiveRange];
					 }
				 }
				 else if ([value isKindOfClass:[NSColor class]])
				 {
					 [self addAttribute:IRCTextFormatterBackgroundColorAttributeName value:value range:effectiveRange];

					 [self addAttribute:NSBackgroundColorAttributeName value:value range:effectiveRange];
				 }

				 break;
			 }
			 case IRCTextFormatterEffectSpoiler:
			 {
				 [self addAttribute:IRCTextFormatterSpoilerAttributeName value:value range:effectiveRange];

				 break;
			 }
		 }
	 }];
}

- (void)removeIRCFormatterAttribute:(IRCTextFormatterEffectType)effect
							  range:(NSRange)limitRange
{
	[self enumerateAttributesInRange:limitRange
							 options:NSAttributedStringEnumerationReverse
						  usingBlock:^(NSDictionary *attributes, NSRange effectiveRange, BOOL *stop)
	 {
		 NSFont *baseFont = attributes[NSFontAttributeName];

		 if (baseFont == nil) {
			 return;
		 }

		 switch (effect) {
			 case IRCTextFormatterEffectNone:
			 {
				 break;
			 }
			 case IRCTextFormatterEffectBold:
			 {
				 if ([baseFont fontTraitSet:NSBoldFontMask]) {
					 baseFont = [RZFontManager() convertFont:baseFont toNotHaveTrait:NSBoldFontMask];

					 if (baseFont) {
						 [self addAttribute:NSFontAttributeName value:baseFont range:effectiveRange];
					 }

					 [self removeAttribute:IRCTextFormatterBoldAttributeName range:effectiveRange];
				 }

				 break;
			 }
			 case IRCTextFormatterEffectItalic:
			 {
				 if ([baseFont fontTraitSet:NSItalicFontMask]) {
					 baseFont = [RZFontManager() convertFont:baseFont toNotHaveTrait:NSItalicFontMask];

					 if (baseFont) {
						 [self addAttribute:NSFontAttributeName value:baseFont range:effectiveRange];
					 }

					 [self removeAttribute:IRCTextFormatterItalicAttributeName range:effectiveRange];
				 }

				 break;
			 }
			 case IRCTextFormatterEffectMonospace:
			 {
				 [self removeAttribute:NSFontAttributeName range:effectiveRange];

				 [self removeAttribute:IRCTextFormatterMonospaceAttributeName range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectUnderline:
			 {
				 [self removeAttribute:NSUnderlineStyleAttributeName range:effectiveRange];

				 [self removeAttribute:IRCTextFormatterUnderlineAttributeName range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectStrikethrough:
			 {
				 [self removeAttribute:NSStrikethroughStyleAttributeName range:effectiveRange];

				 [self removeAttribute:IRCTextFormatterStrikethroughAttributeName range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectForegroundColor:
			 {
				 [self removeAttribute:NSBackgroundColorAttributeName range:effectiveRange];

				 [self removeAttribute:IRCTextFormatterForegroundColorAttributeName range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectBackgroundColor:
			 {
				 [self removeAttribute:NSBackgroundColorAttributeName range:effectiveRange];

				 [self removeAttribute:IRCTextFormatterBackgroundColorAttributeName range:effectiveRange];

				 break;
			 }
			 case IRCTextFormatterEffectSpoiler:
			 {
				 [self removeAttribute:IRCTextFormatterSpoilerAttributeName range:effectiveRange];

				 break;
			 }
		 }
	 }];
}

@end

#pragma mark -
#pragma mark Truncation Helpers

@implementation NSMutableString (IRCTextFormatterPrivate)

/* Look for best character to wrap on */
/* Now this is where the append gets a little technical. We want clean
 truncation. Not half-assed ones. Therefore, if we have space character
 and it is within a certain range of the end of the line, then we will
 stop append at that instead of breaking inside of a word. */
/* Returns number of characters deleted from self or NSNotFound if none. */
/* minimumIndex is index we can't pass so that we always wrap within our
 own segment and not within another. */
/* maxDistance is how far back we search backwards from the end.
 While similar, this value is different compared to minimumIndex.
 maxDistance is a suggestion whereas minimumIndex is a must. */
- (NSUInteger)wrapIRCTextFormatterResultWith:(NSUInteger)minimumIndex maxDistance:(NSUInteger)maxDistance
{
	NSParameterAssert(maxDistance > 0);

	NSUInteger selfLength = self.length;

	NSUInteger searchIndex = ((self.length - 1) - maxDistance);

	NSRange searchRange = NSMakeRange(searchIndex, maxDistance);

	NSRange spaceRange = [self rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]
											   options:NSBackwardsSearch
												 range:searchRange];

	if (spaceRange.location == NSNotFound ||
		spaceRange.location < minimumIndex)
	{
		return NSNotFound;
	}

	NSInteger indexDifference = (selfLength - spaceRange.location);

	[self deleteCharactersInRange:NSMakeRange(spaceRange.location, indexDifference)];

	return indexDifference;
}

@end

NS_ASSUME_NONNULL_END
