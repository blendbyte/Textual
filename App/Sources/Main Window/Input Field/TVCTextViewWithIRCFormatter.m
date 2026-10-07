/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "NSStringHelper.h"
#import "IRCColorFormat.h"
#import "TPCPreferencesLocal.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define TVCTextViewWithIRCFormatterWidthPadding		1.0
#define TVCTextViewWithIRCFormatterHeightPadding	2.0

@interface TVCTextViewWithIRCFormatter ()
@property (nonatomic, strong) TLOKeyEventHandler *keyEventHandler;
@end

@implementation TVCTextViewWithIRCFormatter

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	self.delegate = (id)self;

	if ([TPCPreferences rightToLeftFormatting]) {
		self.baseWritingDirection = NSWritingDirectionRightToLeft;
	} else {
		self.baseWritingDirection = NSWritingDirectionLeftToRight;
	}

	self.textContainerInset =
	 NSMakeSize(TVCTextViewWithIRCFormatterWidthPadding,
				TVCTextViewWithIRCFormatterHeightPadding);

	self.keyEventHandler = [[TLOKeyEventHandler alloc] initWithTarget:self];

	// The following serve as defaults and are supposed to be replaced
	self.preferredFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	self.preferredFontColor = [NSColor textColor];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self.window makeFirstResponder:self];

	[super mouseDown:theEvent];
}

#pragma mark -
#pragma mark Keyboard Shortcuts

- (void)setKeyHandlerTarget:(id)target
{
	[self.keyEventHandler setKeyHandlerTarget:target];
}

- (void)registerSelector:(SEL)selector key:(NSUInteger)keyCode modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector key:keyCode modifiers:modifiers];
}

- (void)registerSelector:(SEL)selector character:(UniChar)character modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector character:character modifiers:modifiers];
}

- (void)registerSelector:(SEL)selector characters:(NSRange)characterRange modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector characters:characterRange modifiers:modifiers];
}

- (BOOL)performedCustomKeyboardEvent:(NSEvent *)e
{
	if ([self.keyEventHandler processKeyEvent:e]) {
		return YES;
	}

	return NO;
}

- (void)keyDownToSuper:(NSEvent *)e
{
	[super keyDown:e];
}

#pragma mark -
#pragma mark Value Management

- (NSArray<NSString *> *)readablePasteboardTypes
{
	return @[NSPasteboardTypeString, NSFilenamesPboardType];
}

- (NSArray<NSString *> *)acceptableDragTypes
{
	return @[NSPasteboardTypeString, NSFilenamesPboardType];
}

- (NSString *)stringValue
{
	return [self.string copy];
}

- (NSString *)stringValueWithIRCFormatting
{
	return self.attributedString.stringFormattedForIRC;
}

- (void)setStringValue:(NSString *)stringValue
{
	NSParameterAssert(stringValue != nil);

	[self.textStorage replaceCharactersInRange:self.range withString:stringValue];

	[self didChangeText];
}

- (NSAttributedString *)attributedStringValue
{
	return [[self attributedString] copy];
}

- (void)setAttributedStringValue:(NSAttributedString *)attributedStringValue
{
	NSParameterAssert(attributedStringValue != nil);

	[self.undoManager removeAllActions];

	[self.textStorage replaceCharactersInRange:self.range withAttributedString:attributedStringValue];

	[self didChangeText];
}

- (void)setStringValueWithIRCFormatting:(NSString *)stringValueWithIRCFormatting
{
	NSParameterAssert(stringValueWithIRCFormatting != nil);

	NSAttributedString *formattedValue =
	[stringValueWithIRCFormatting attributedStringWithIRCFormatting:self.preferredFont
												 preferredFontColor:self.preferredFontColor
										  honorFormattingPreference:NO];

	if (formattedValue) {
		self.attributedStringValue = formattedValue;
	}
}

#pragma mark -

- (void)textDidChange:(NSNotification *)aNotification
{
	if (self.stringLength < 1) {
		[self resetTypeSetterAttributes];
	}
}

#pragma mark -

- (void)updateAllFontSizesToMatchTheDefaultFont
{
	CGFloat newPointSize = self.preferredFont.pointSize;

	[self.textStorage beginEditing];

	[self.textStorage enumerateAttribute:NSFontAttributeName
								 inRange:self.range
								 options:0
							  usingBlock:^(id value, NSRange range, BOOL *stop)
	{
		if (fabs([value pointSize]) == fabs(newPointSize)) {
			return;
		}

		NSFont *font = [RZFontManager() convertFont:value toSize:newPointSize];

		if (font) {
			[self.textStorage removeAttribute:NSFontAttributeName range:range];

			[self.textStorage addAttribute:NSFontAttributeName value:font range:range];
		}
	}];

	[self.textStorage endEditing];
}

- (void)setPreferredFont:(NSFont *)preferredFont
{
	NSParameterAssert(preferredFont != nil);

	if (self->_preferredFont != preferredFont) {
		self->_preferredFont = [preferredFont copy];

		[self modifyTypingAttributes:@{
			NSFontAttributeName : self->_preferredFont
		}];
	}
}

- (void)setPreferredFontColor:(NSColor *)preferredFontColor
{
	NSParameterAssert(preferredFontColor != nil);

	if (self->_preferredFontColor != preferredFontColor) {
		self->_preferredFontColor = [preferredFontColor copy];

		[self modifyTypingAttributes:@{
			NSForegroundColorAttributeName : self->_preferredFontColor
		}];

		self.insertionPointColor = self->_preferredFontColor;
	}
}

- (void)resetTypeSetterAttributes
{
	self.typingAttributes = @{
		NSFontAttributeName : self.preferredFont,
		NSForegroundColorAttributeName : self.preferredFontColor
	};
}

- (void)modifyTypingAttributes:(NSDictionary<NSString *, id> *)typingAttributes
{
	NSMutableDictionary *typingAttributesMutable = [self.typingAttributes mutableCopy];

	[typingAttributesMutable addEntriesFromDictionary:typingAttributes];

	self.typingAttributes = typingAttributesMutable;
}

- (void)resetFontInRange:(NSRange)range
{
	NSDictionary *newAttributes = @{
		NSFontAttributeName : self.preferredFont
	};

	[self.textStorage addAttributes:newAttributes range:range];
}

- (void)resetFontColorInRange:(NSRange)range
{
	NSDictionary *newAttributes = @{
		NSForegroundColorAttributeName : self.preferredFontColor
	};

	[self.textStorage addAttributes:newAttributes range:range];
}

#pragma mark -
#pragma mark Line Counting

- (NSRect)selectedRect
{
	NSLayoutManager *layoutManager = self.layoutManager;

	NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:self.selectedRange actualCharacterRange:NULL];
	NSRect boundingRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];

	NSPoint containerOrigin = [self textContainerOrigin];

	return NSInsetRect(boundingRect, containerOrigin.x, containerOrigin.y);
}

- (TVCTextViewCaretLocation)caretLocation
{
	NSUInteger stringLength = self.stringLength;

	if (stringLength == 0) {
		return TVCTextViewCaretLocationOnlyLine;
	}

	NSRange selectedRange = self.selectedRange;

	NSLayoutManager *layoutManager = self.layoutManager;

	/* Check first line */
	BOOL inFirstLine = (selectedRange.location == 0);

	if (inFirstLine == NO) {
		NSRange firstLineRange;

		[layoutManager lineFragmentRectForGlyphAtIndex:0 effectiveRange:&firstLineRange];

		inFirstLine = (selectedRange.location <= NSMaxRange(firstLineRange));
	}

	/* Check last line */
	BOOL inLastLine = (NSMaxRange(selectedRange) == stringLength);

	if (inLastLine == NO) {
		NSRange lastLineRange;

		[layoutManager lineFragmentRectForGlyphAtIndex:(stringLength - 1) effectiveRange:&lastLineRange];

		inLastLine = (selectedRange.location >= lastLineRange.location);
	}

	/* Process results */
	if (inFirstLine && inLastLine) {
		return TVCTextViewCaretLocationOnlyLine;
	} else if (inFirstLine) {
		return TVCTextViewCaretLocationFirstLine;
	} else if (inLastLine) {
		return TVCTextViewCaretLocationLastLine;
	}

	return TVCTextViewCaretLocationMiddle;
}

- (CGFloat)highestHeightBelowHeight:(CGFloat)maximumHeight withPadding:(CGFloat)valuePadding
{
	NSLayoutManager *layoutManager = self.layoutManager;

	BOOL skipLastFragmentCheck = NO;

	NSUInteger numberOfGlyphs = layoutManager.numberOfGlyphs;

	NSUInteger totalLineHeight = valuePadding;

	for (NSUInteger i = 0; i < numberOfGlyphs; i++) {
		NSRange lineRange;

		NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:i effectiveRange:&lineRange];

		if ((totalLineHeight +  rect.size.height) <= maximumHeight) {
			totalLineHeight  += rect.size.height;
		} else {
			skipLastFragmentCheck = YES;

			break;
		}

		i = NSMaxRange(lineRange);
	}

	if (skipLastFragmentCheck) {
		return totalLineHeight;
	}

	NSRect lastFragmentRect = layoutManager.extraLineFragmentRect;

	if ((totalLineHeight +  lastFragmentRect.size.height) <= maximumHeight) {
		totalLineHeight  += lastFragmentRect.size.height;
	}

	return totalLineHeight;
}

@end

NS_ASSUME_NONNULL_END
