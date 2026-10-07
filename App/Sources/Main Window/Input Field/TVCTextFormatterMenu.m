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

#import "NSColorHelper.h"
#import "IRCColorFormat.h"
#import "TLOLocalization.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TVCTextFormatterMenuPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _formattingMenuRainbowColorMenuItemTag			299
#define _formattingMenuHexColorMenuItemTag				300

@interface TVCTextViewIRCFormattingMenu () <NSMenuItemValidation>
@property (readonly, nullable) TVCTextViewWithIRCFormatter *textField;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *formatterMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenu *foregroundColorMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenu *backgroundColorMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *foregroundColorSetMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *backgroundColorSetMenuItem;

- (IBAction)emptyAction:(id)sender;
@end

@implementation TVCTextViewIRCFormattingMenu

#pragma mark -
#pragma mark Menu Management

- (void)awakeFromNib
{
	[super awakeFromNib];

	[self generateColorList];
}

- (nullable TVCTextViewWithIRCFormatter *)textField
{
	id firstResponder = [[NSApp keyWindow] firstResponder];

	if ([firstResponder isKindOfClass:[TVCTextViewWithIRCFormatter class]]) {
		return firstResponder;
	}

	return nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if (self.textField == nil) {
		return NO;
	}

	switch (item.tag) {
		case 100: // Bold
		{
			BOOL boldText = self.textIsBold;

			item.state = boldText;

			if (boldText) {
				item.action = @selector(removeBoldCharFromTextBox:);
			} else {
				item.action = @selector(insertBoldCharIntoTextBox:);
			}

			return YES;
		}
		case 101: // Italics
		{
			BOOL italicText = self.textIsItalicized;

			item.state = italicText;

			if (italicText) {
				item.action = @selector(removeItalicCharFromTextBox:);
			} else {
				item.action = @selector(insertItalicCharIntoTextBox:);
			}

			return YES;
		}
		case 102: // Monospace
		{
			BOOL monospaceText = self.textIsMonospace;

			item.state = monospaceText;

			if (monospaceText) {
				item.action = @selector(removeMonospaceCharFromTextBox:);
			} else {
				item.action = @selector(insertMonospaceCharIntoTextBox:);
			}

			return YES;
		}
		case 103: // Spoiler
		{
			BOOL spoilerText = self.textHasSpoiler;

			item.state = spoilerText;

			if (spoilerText) {
				item.action = @selector(removeSpoilerCharFromTextBox:);
			} else {
				item.action = @selector(insertSpoilerCharIntoTextBox:);
			}

			return YES;
		}
		case 104: // Strikethrough
		{
			BOOL struckthroughText = self.textIsStruckthrough;

			item.state = struckthroughText;

			if (struckthroughText) {
				item.action = @selector(removeStrikethroughCharFromTextBox:);
			} else {
				item.action = @selector(insertStrikethroughCharIntoTextBox:);
			}

			return YES;
		}
		case 105: // Underline
		{
			BOOL underlineText = self.textIsUnderlined;

			item.state = underlineText;

			if (underlineText) {
				item.action = @selector(removeUnderlineCharFromTextBox:);
			} else {
				item.action = @selector(insertUnderlineCharIntoTextBox:);
			}

			return YES;
		}
		case 108: // Foreground Color Missing
		{
			item.hidden = self.textHasForegroundColor;

			return YES;
		}
		case 107: // Foreground Color Set
		{
			item.hidden = (self.textHasForegroundColor == NO);

			/* Do not enable menu item when there is spoiler */
			return (self.textHasSpoiler == NO);
		}
		case 110: // Background Color Missing
		{
			item.hidden = self.textHasBackgroundColor;

			/* Require foreground color before background color can be set */
			return self.textHasForegroundColor;
		}
		case 109: // Background Color Set
		{
			item.hidden = (self.textHasBackgroundColor == NO);

			return (self.textHasSpoiler == NO);
		}
		default:
		{
			break;
		}
	}

	return YES;
}

- (void)emptyAction:(id)sender
{
	/* Empty action used to validate submenus */
}

#pragma mark -
#pragma mark Menu Generation

- (void)generateColorList
{
	/* While we could technically load this from a file; we don't need to.
	 That just adds extra space to the app when we already need to have an
	 array of colors in the binary. */
	NSColorList *colorList = [[NSColorList alloc] initWithName:TXTLS(@"iwp-cg")];

	[[NSColor formatterColors] enumerateObjectsUsingBlock:^(NSColor *color, NSUInteger index, BOOL *stop) {
		[colorList setColor:color forKey:TXTLS(@"ham-vk", index)];
	}];

	[[NSColorPanel sharedColorPanel] attachColorList:colorList];
}

#pragma mark -
#pragma mark Formatting Properties

- (BOOL)propertyIsSet:(IRCTextFormatterEffectType)formatterEffect
{
	NSRange selectedTextRange = self.textField.selectedRange;

	return [self.textField.attributedString IRCFormatterAttributeSetInRange:formatterEffect range:selectedTextRange];
}

- (BOOL)textIsBold
{
	return [self propertyIsSet:IRCTextFormatterEffectBold];
}

- (BOOL)textIsItalicized
{
	return [self propertyIsSet:IRCTextFormatterEffectItalic];
}

- (BOOL)textIsMonospace
{
	return [self propertyIsSet:IRCTextFormatterEffectMonospace];
}

- (BOOL)textIsStruckthrough
{
	return [self propertyIsSet:IRCTextFormatterEffectStrikethrough];
}

- (BOOL)textIsUnderlined
{
	return [self propertyIsSet:IRCTextFormatterEffectUnderline];
}

- (BOOL)textHasForegroundColor
{
	return [self propertyIsSet:IRCTextFormatterEffectForegroundColor];
}

- (BOOL)textHasBackgroundColor
{
	return [self propertyIsSet:IRCTextFormatterEffectBackgroundColor];
}

- (BOOL)textHasSpoiler
{
	return [self propertyIsSet:IRCTextFormatterEffectSpoiler];
}

#pragma mark -
#pragma mark Formatting Storage Helpers

- (void)applyEffectToTextBox:(IRCTextFormatterEffectType)formatterEffect withValue:(id)value inRange:(NSRange)limitRange
{
	NSMutableAttributedString *stringMutableCopy = [self mutableStringAtRange:limitRange];

	if (stringMutableCopy == nil) {
		return;
	}

	[self applyEffect:formatterEffect withValue:value toMutableString:stringMutableCopy];

	[self applyAttributedStringToTextBox:stringMutableCopy inRange:limitRange];

	if (value == nil &&
		(formatterEffect == IRCTextFormatterEffectForegroundColor ||
		 formatterEffect == IRCTextFormatterEffectSpoiler))
	{
		[self.textField resetFontColorInRange:limitRange];
	}

	if (formatterEffect == IRCTextFormatterEffectMonospace && value == nil) {
		[self.textField resetFontInRange:limitRange];
	}
}

- (nullable NSMutableAttributedString *)mutableStringAtRange:(NSRange)limitRange
{
	if (limitRange.location == NSNotFound || limitRange.length == 0) {
		return nil;
	}

	NSAttributedString *stringSubstring = [self.textField.attributedString attributedSubstringFromRange:limitRange];

	return [stringSubstring mutableCopy];
}

- (void)applyEffect:(IRCTextFormatterEffectType)formatterEffect withValue:(id)value toMutableString:(NSMutableAttributedString *)mutableString
{
	[self applyEffect:formatterEffect withValue:value inRange:mutableString.range toMutableString:mutableString];
}

- (void)applyEffect:(IRCTextFormatterEffectType)formatterEffect withValue:(id)value inRange:(NSRange)limitRange toMutableString:(NSMutableAttributedString *)mutableString
{
	if (value) {
		[mutableString setIRCFormatterAttribute:formatterEffect value:value range:limitRange];
	} else {
		[mutableString removeIRCFormatterAttribute:formatterEffect range:limitRange];
	}
}

- (void)applyAttributedStringToTextBox:(NSMutableAttributedString *)mutableString inRange:(NSRange)limitRange
{
	if ([self.textField shouldChangeTextInRange:limitRange replacementString:mutableString.string] == NO) {
		return;
	}

	[self.textField.textStorage replaceCharactersInRange:limitRange withAttributedString:mutableString];

	[self.textField didChangeText];

	[self.textField setSelectedRange:limitRange];
}

#pragma mark -
#pragma mark Add Formatting

- (void)insertBoldCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectBold withValue:@(YES) inRange:selectedTextRange];
}

- (void)insertItalicCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectItalic withValue:@(YES) inRange:selectedTextRange];
}

- (void)insertMonospaceCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectMonospace withValue:@(YES) inRange:selectedTextRange];
}

- (void)insertStrikethroughCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectStrikethrough withValue:@(YES) inRange:selectedTextRange];
}

- (void)insertUnderlineCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectUnderline withValue:@(YES) inRange:selectedTextRange];
}

- (void)insertForegroundColorCharIntoTextBox:(id)sender
{
	if ([sender tag] == _formattingMenuRainbowColorMenuItemTag) {
		[self insertRainbowColorCharInfoTextBox:sender asForegroundColor:YES];

		return;
	}
	else if ([sender tag] == _formattingMenuHexColorMenuItemTag)
	{
		NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

		[colorPanel setTarget:self];
		[colorPanel setAction:@selector(foregroundColorPanelColorChanged:)];
		[colorPanel setAlphaValue:1.0];
		[colorPanel setMode:NSColorPanelModeColorList];
		[colorPanel setColor:[NSColor formatterWhiteColor]];

		[colorPanel orderFront:nil];
	}

	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectForegroundColor withValue:@([sender tag]) inRange:selectedTextRange];
}

- (void)insertBackgroundColorCharIntoTextBox:(id)sender
{
	if ([sender tag] == _formattingMenuRainbowColorMenuItemTag)
	{
		[self insertRainbowColorCharInfoTextBox:sender asForegroundColor:NO];

		return;
	}
	else if ([sender tag] == _formattingMenuHexColorMenuItemTag)
	{
		NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

		[colorPanel setTarget:self];
		[colorPanel setAction:@selector(backgroundColorPanelColorChanged:)];
		[colorPanel setAlphaValue:1.0];
		[colorPanel setMode:NSColorPanelModeColorList];
		[colorPanel setColor:[NSColor formatterBlackColor]];

		[colorPanel orderFront:nil];
	}

	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectBackgroundColor withValue:@([sender tag]) inRange:selectedTextRange];
}

- (void)insertRainbowColorCharInfoTextBox:(id)sender asForegroundColor:(BOOL)asForegroundColor
{
	NSRange selectedTextRange = self.textField.selectedRange;

	NSMutableAttributedString *mutableStringCopy = [self mutableStringAtRange:selectedTextRange];

	if (mutableStringCopy == nil) {
		return;
	}

	[mutableStringCopy beginEditing];

	NSUInteger rainbowArrayIndex = 0;

	NSArray *colorCodes = @[@(4), @(7), @(8), @(3), @(12), @(2), @(6)];

	for (NSUInteger charCountIndex = 0; charCountIndex < mutableStringCopy.length; charCountIndex++) {
		if (rainbowArrayIndex > 6) {
			rainbowArrayIndex = 0;
		}

		NSUInteger currentColorCode = [colorCodes unsignedIntegerAtIndex:rainbowArrayIndex];

		NSRange currentCharacterRange = NSMakeRange(charCountIndex, 1);

		if (asForegroundColor) {
			[self applyEffect:IRCTextFormatterEffectForegroundColor withValue:@(currentColorCode) inRange:currentCharacterRange toMutableString:mutableStringCopy];
		} else {
			[self applyEffect:IRCTextFormatterEffectBackgroundColor withValue:@(currentColorCode) inRange:currentCharacterRange toMutableString:mutableStringCopy];
		}

		rainbowArrayIndex += 1;
	}

	[mutableStringCopy endEditing];

	[self applyAttributedStringToTextBox:mutableStringCopy inRange:selectedTextRange];
}

- (void)foregroundColorPanelColorChanged:(NSColorPanel *)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	NSColor *color = sender.color;

	NSUInteger colorDigit = [[NSColor formatterColors] indexOfObject:color];

	if (colorDigit == NSNotFound) {
		[self applyEffectToTextBox:IRCTextFormatterEffectForegroundColor withValue:color inRange:selectedTextRange];
	} else {
		[self applyEffectToTextBox:IRCTextFormatterEffectForegroundColor withValue:@(colorDigit) inRange:selectedTextRange];
	}
}

- (void)backgroundColorPanelColorChanged:(NSColorPanel *)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	NSColor *color = sender.color;

	NSUInteger colorDigit = [[NSColor formatterColors] indexOfObject:color];

	if (colorDigit == NSNotFound) {
		[self applyEffectToTextBox:IRCTextFormatterEffectBackgroundColor withValue:color inRange:selectedTextRange];
	} else {
		[self applyEffectToTextBox:IRCTextFormatterEffectBackgroundColor withValue:@(colorDigit) inRange:selectedTextRange];
	}
}

- (void)insertSpoilerCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectSpoiler withValue:@(YES) inRange:selectedTextRange];

	[self applyEffectToTextBox:IRCTextFormatterEffectForegroundColor withValue:@(14) inRange:selectedTextRange];
	[self applyEffectToTextBox:IRCTextFormatterEffectBackgroundColor withValue:@(14) inRange:selectedTextRange];
}

#pragma mark -
#pragma mark Remove Formatting

- (void)removeBoldCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectBold withValue:nil inRange:selectedTextRange];
}

- (void)removeItalicCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectItalic withValue:nil inRange:selectedTextRange];
}

- (void)removeMonospaceCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectMonospace withValue:nil inRange:selectedTextRange];
}

- (void)removeStrikethroughCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectStrikethrough withValue:nil inRange:selectedTextRange];
}

- (void)removeUnderlineCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectUnderline withValue:nil inRange:selectedTextRange];
}

- (void)removeForegroundColorCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectForegroundColor withValue:nil inRange:selectedTextRange];
}

- (void)removeBackgroundColorCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectBackgroundColor withValue:nil inRange:selectedTextRange];
}

- (void)removeSpoilerCharFromTextBox:(id)sender
{
	NSRange selectedTextRange = self.textField.selectedRange;

	[self applyEffectToTextBox:IRCTextFormatterEffectForegroundColor withValue:nil inRange:selectedTextRange];
	[self applyEffectToTextBox:IRCTextFormatterEffectBackgroundColor withValue:nil inRange:selectedTextRange];

	[self applyEffectToTextBox:IRCTextFormatterEffectSpoiler withValue:nil inRange:selectedTextRange];
}

@end

NS_ASSUME_NONNULL_END
