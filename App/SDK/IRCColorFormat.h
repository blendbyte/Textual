/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IRCTextFormatterEffectType) {
	IRCTextFormatterEffectNone = 0,
	IRCTextFormatterEffectBold,
	IRCTextFormatterEffectItalic,
	IRCTextFormatterEffectMonospace,
	IRCTextFormatterEffectStrikethrough,
	IRCTextFormatterEffectUnderline,
	IRCTextFormatterEffectForegroundColor,
	IRCTextFormatterEffectBackgroundColor,
	IRCTextFormatterEffectSpoiler,
};

typedef NSString *IRCTextFormatterAttributeName NS_EXTENSIBLE_STRING_ENUM;

TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterBoldAttributeName; // BOOL
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterItalicAttributeName; // BOOL
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterMonospaceAttributeName; // BOOL
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterStrikethroughAttributeName; // BOOL
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterUnderlineAttributeName; // BOOL
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterForegroundColorAttributeName; // NSNumber, 0-15 - or, NSColor
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterBackgroundColorAttributeName; // NSNumber, 0-15 - or, NSColor
TEXTUAL_EXTERN IRCTextFormatterAttributeName const IRCTextFormatterSpoilerAttributeName; // BOOL

#define IRCTextFormatterEffectColorAsDigitCharacter		0x03
#define IRCTextFormatterEffectColorAsHexCharacter		0x04
#define IRCTextFormatterEffectBoldCharacter				0x02
#define IRCTextFormatterEffectItalicCharacter			0x1d
#define IRCTextFormatterEffectItalicCharacterOld		0x16
#define IRCTextFormatterEffectMonospaceCharacter		0x11
#define IRCTextFormatterEffectStrikethroughCharacter	0x1e
#define IRCTextFormatterEffectUnderlineCharacter		0x1F
#define IRCTextFormatterTerminatingCharacter			0x0F

#define IRCTextFormatterEffectColorHighestDigit			98

@class IRCTextFormatterEffects;

@interface IRCTextFormatterEffect : NSObject
@property (readonly) IRCTextFormatterEffectType type;
@property (readonly, copy, nullable) NSString *value;
@property (readonly) UniChar controlCharacter;

/* Number of bytes needed to support this effect.
 Open control character + value + close control character.
 For background color, only the comma and color value is counted. */
@property (readonly) NSUInteger length;

+ (nullable instancetype)effectWithType:(IRCTextFormatterEffectType)type;
+ (nullable instancetype)effectWithType:(IRCTextFormatterEffectType)type withValue:(nullable id)value;

- (nullable instancetype)initWithEffect:(IRCTextFormatterEffectType)type;
- (nullable instancetype)initWithEffect:(IRCTextFormatterEffectType)type withValue:(nullable id)value NS_DESIGNATED_INITIALIZER;

/* Appends control character and value for the effect.
 For background color, appends comma and color value instead. */
- (void)appendToStartOf:(NSMutableString *)string;

/* Appends control character for the effect.
 For background color, does nothing. */
- (void)appendToEndOf:(NSMutableString *)string;
@end

@interface IRCTextFormatterEffects : NSObject
@property (readonly, copy) NSArray<IRCTextFormatterEffect *> *effects;

/* Number of bytes needed to support all effects. */
@property (readonly) NSUInteger maximumLength;

+ (instancetype)effectsInAttributes:(NSDictionary<NSString *, id> *)attributes;

- (instancetype)initWithAttributes:(NSDictionary<NSString *, id> *)attributes NS_DESIGNATED_INITIALIZER;

- (void)appendToStartOf:(NSMutableString *)string;
- (void)appendToEndOf:(NSMutableString *)string;
@end

#pragma mark -

@interface NSAttributedString (IRCTextFormatter)
- (BOOL)IRCFormatterAttributeSetInRange:(IRCTextFormatterEffectType)effect
								  range:(NSRange)limitRange;

/* Returns an NSString with appropriate formatting characters. */
@property (readonly, copy) NSString *stringFormattedForIRC;
@end

#pragma mark -

@interface NSMutableAttributedString (IRCTextFormatter)
- (void)setIRCFormatterAttribute:(IRCTextFormatterEffectType)effect 
						   value:(id)value 
						   range:(NSRange)limitRange;

- (void)removeIRCFormatterAttribute:(IRCTextFormatterEffectType)effect 
							  range:(NSRange)limitRange;
@end

NS_ASSUME_NONNULL_END
