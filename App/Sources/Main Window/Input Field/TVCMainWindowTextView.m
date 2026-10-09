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

#import "NSViewHelperPrivate.h"
#import "IRCColorFormat.h"
#import "TLOLocalization.h"
#import "TPCResourceManagerPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowSegmentedControllerPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TVCMainWindowTextViewAppearancePrivate.h"
#import "TVCMainWindowTextViewInternal.h"

NS_ASSUME_NONNULL_BEGIN

#define _KeyObservingArray 	@[	@"TextFieldAutomaticSpellCheck", \
								@"TextFieldAutomaticGrammarCheck", \
								@"TextFieldAutomaticSpellCorrection", \
								@"TextFieldSmartCopyPaste", \
								@"TextFieldSmartQuotes", \
								@"TextFieldSmartDashes", \
								@"TextFieldSmartLinks", \
								@"TextFieldDataDetectors", \
								@"TextFieldTextReplacement"]

@implementation TVCMainWindowTextView

#pragma mark -
#pragma mark Drawing

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.backgroundColor = [NSColor clearColor];

	[self updateTextDirection];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];

	/* This can come with a window more than once: observe once */
	BOOL observe = (self.window != nil);

	if (self.observingUserDefaults == observe) {
		return;
	}

	self.observingUserDefaults = observe;

	for (NSString *key in _KeyObservingArray) {
		if (observe) {
			[RZUserDefaults() addObserver:self forKeyPath:key options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:NULL];
		} else {
			[RZUserDefaults() removeObserver:self forKeyPath:key];
		}
	}
}

- (void)updateVibrancyWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	self.backgroundView.needsDisplay = YES;

	self.contentView.needsDisplay = YES;
}

- (void)applicationAppearanceChanged
{
	TVCMainWindowTextViewAppearance *appearance = self.mainWindow.userInterfaceObjects.textView;

	[self _updateAppearance:appearance];
}

/*
- (void)systemAppearanceChanged
{

}
*/

- (void)_updateAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	self.userInterfaceObjects = appearance;

	[self updateVibrancyWithAppearance:appearance];

	self.textContainerInset = appearance.textViewInset;

	self.preferredFontColor = appearance.textViewTextColor;

	[self reloadOriginPoints];

	[self updateTextBoxCachedPreferredFontSize];

	[self resetTypeSetterAttributes];

	[self updateAllFontColorsToMatchTheDefaultFont];
}

#pragma mark -
#pragma mark Segmented Controller

- (void)reloadOriginPointsAndRecalculateSize
{
	[self reloadOriginPoints];

	/* Reload size on next go around to allow constraint layout to occur before so */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self recalculateTextViewSizeForced];
	});
}

- (void)reloadOriginPoints
{
	[self.segmentedController updateSegmentedControllerOrigin];
}

- (void)updateSegmentedController
{
	[self.segmentedController updateSegmentedController];
}

#pragma mark -
#pragma mark Spelling

- (void)resetSpellingIgnores
{
	/* When performing nickname completion, completions are
	 added to the ignore list. The main window then resets
	 the entire spelling ignore list, by calling this method
	 when the selection changes. */
	/* Because the main window will eventually call this for us,
	 we allow it to happen lazily, instead of in awake from nib. */
	[RZSpellChecker() setIgnoredWords:self.defaultSpellingIgnores inSpellDocumentWithTag:self.spellCheckerDocumentTag];
}

- (NSArray<NSString *> *)defaultSpellingIgnores
{
	return [TPCResourceManager arrayFromResources:@"StaticStore" key:@"Spelling Ignores"];
}

#pragma mark -
#pragma mark Utilities

- (void)updateAllFontColorsToMatchTheDefaultFont
{
	[self.textStorage beginEditing];

	[self.textStorage enumerateAttributesInRange:self.range
										 options:0
									  usingBlock:^(NSDictionary *attributes, NSRange effectiveRange, BOOL *stop)
		{
			if ([attributes containsKey:IRCTextFormatterForegroundColorAttributeName]) {
				return;
			}

			[self resetFontColorInRange:effectiveRange];
		}];

	[self.textStorage endEditing];
}

- (void)setAttributedStringValue:(NSAttributedString *)attributedStringValue
{
	super.attributedStringValue = attributedStringValue;

	[self updateAllFontColorsToMatchTheDefaultFont];
}

- (void)updateTextDirection
{
	if ([TPCPreferences rightToLeftFormatting]) {
		self.baseWritingDirection = NSWritingDirectionRightToLeft;
	} else {
		self.baseWritingDirection = NSWritingDirectionLeftToRight;
	}
}

- (void)textDidChange:(NSNotification *)aNotification
{
	[super textDidChange:aNotification];

	[self recalculateTextViewSize];

	[self.mainWindow inputTextDidChange];
}

- (void)paste:(nullable id)sender
{
	[super paste:self];

	[self recalculateTextViewSize];
}

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
	if (aSelector == @selector(insertNewline:)) {
		[self.mainWindow textEntered];

		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Multi-line Text Box Drawing

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect] == NO) {
		return;
	}

	/* The place holder string is not drawn for right to left users */
	if (self.stringLength > 0 || self.baseWritingDirection != NSWritingDirectionLeftToRight) {
		[super drawRect:dirtyRect];

		return;
	}

	// TODO: Don't used fix positions
	NSRect selectedRect = self.selectedRect;

	TVCMainWindowTextViewFontSize preferredFontSize = self.userInterfaceObjects.textViewPreferredFontSize;

	if (preferredFontSize == TVCMainWindowTextViewFontSizeNormal ||
		preferredFontSize == TVCMainWindowTextViewFontSizeLarge)
	{
		selectedRect.origin.y -= 1;
	}

	[self.placeholderAttributedString drawAtPoint:selectedRect.origin];
}

- (void)updateTextBoxCachedPreferredFontSize
{
	/* Update font */
	TVCMainWindowTextViewAppearance *appearance = self.userInterfaceObjects;

	if ([appearance preferredTextViewFontChanged] == NO) {
		return;
	}

	NSFont *preferredFont = appearance.textViewPreferredFont;

	self.preferredFont = preferredFont;

	/* Update the placeholder string */
	NSColor *placeholderTextColor = appearance.textViewPlaceholderTextColor;

	NSDictionary *placeholderStringAttributes = @{
		NSFontAttributeName	: preferredFont,
		NSForegroundColorAttributeName : placeholderTextColor
	};

	self.placeholderAttributedString =
	[NSAttributedString attributedStringWithString:TXTLS(@"TVCMainWindow[8r3-ih]") attributes:placeholderStringAttributes];

	self.needsDisplay = YES;
}

- (void)updateTextBasedOnPreferredFontSize
{
	TVCMainWindowTextViewAppearance *appearance = self.userInterfaceObjects;

	TVCMainWindowTextViewFontSize preferredFontSize = appearance.textViewPreferredFontSize;

	[self updateTextBoxCachedPreferredFontSize];

	if (appearance.textViewPreferredFontSize != preferredFontSize) {
		[self updateAllFontSizesToMatchTheDefaultFont];
	}

	[self recalculateTextViewSizeForced];
}

- (CGFloat)defaultLineHeight
{
	return [self.layoutManager defaultLineHeightForFont:self.preferredFont];
}

- (void)recalculateTextViewSize
{
	[self recalculateTextViewSizeForced:NO];
}

- (void)recalculateTextViewSizeForced
{
	[self recalculateTextViewSizeForced:YES];
}

- (void)recalculateTextViewSizeForced:(BOOL)forceRecalculate
{
	TVCMainWindowTextViewAppearance *appearance = self.userInterfaceObjects;

	NSWindow *window = self.window;

	NSRect windowFrame = window.frame;

	CGFloat contentBorderPadding = appearance.backgroundViewContentBorderPadding;

	CGFloat backgroundHeight = 0;

	CGFloat backgroundHeightDefault = [self defaultLineHeight];

	if (self.stringLength < 1) {
		backgroundHeight = (backgroundHeightDefault + contentBorderPadding);
	} else {
		CGFloat backgroundHeightMaximum = (NSHeight(windowFrame) - (self.windowContentViewMinimumHeight.constant + contentBorderPadding));

		backgroundHeight = [self highestHeightBelowHeight:backgroundHeightMaximum withPadding:contentBorderPadding];

		if ((backgroundHeight - contentBorderPadding) < backgroundHeightDefault) {
			backgroundHeight = (backgroundHeightDefault + contentBorderPadding);
		}
	}

	self.textViewHeightConstraint.constant = backgroundHeight;

	id scrollViewContentView = self.enclosingScrollView.contentView;

	NSRect contentViewBounds = [scrollViewContentView bounds];

	if (contentViewBounds.origin.x > 0) {
		contentViewBounds.origin.x = 0;

		[scrollViewContentView scrollToPoint:contentViewBounds.origin];
	}
}

#pragma mark -
#pragma mark NSTextView Context Menu Preferences

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"TextFieldAutomaticSpellCheck"]) {
		self.continuousSpellCheckingEnabled = [TPCPreferences textFieldAutomaticSpellCheck];
	} else if ([keyPath isEqualToString:@"TextFieldAutomaticGrammarCheck"]) {
		self.grammarCheckingEnabled = [TPCPreferences textFieldAutomaticGrammarCheck];
	} else if ([keyPath isEqualToString:@"TextFieldAutomaticSpellCorrection"]) {
		self.automaticSpellingCorrectionEnabled = [TPCPreferences textFieldAutomaticSpellCorrection];
	} else if ([keyPath isEqualToString:@"TextFieldSmartCopyPaste"]) {
		self.smartInsertDeleteEnabled = [TPCPreferences textFieldSmartCopyPaste];
	} else if ([keyPath isEqualToString:@"TextFieldSmartQuotes"]) {
		self.automaticQuoteSubstitutionEnabled = [TPCPreferences textFieldSmartQuotes];
	} else if ([keyPath isEqualToString:@"TextFieldSmartDashes"]) {
		self.automaticDashSubstitutionEnabled = [TPCPreferences textFieldSmartDashes];
	} else if ([keyPath isEqualToString:@"TextFieldSmartLinks"]) {
		self.automaticLinkDetectionEnabled = [TPCPreferences textFieldSmartLinks];
	} else if ([keyPath isEqualToString:@"TextFieldDataDetectors"]) {
		self.automaticDataDetectionEnabled = [TPCPreferences textFieldDataDetectors];
	} else if ([keyPath isEqualToString:@"TextFieldTextReplacement"]) {
		self.automaticTextReplacementEnabled = [TPCPreferences textFieldTextReplacement];
	} else if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)setContinuousSpellCheckingEnabled:(BOOL)continuousSpellCheckingEnabled
{
	[TPCPreferences setTextFieldAutomaticSpellCheck:continuousSpellCheckingEnabled];

	super.continuousSpellCheckingEnabled = continuousSpellCheckingEnabled;
}

- (void)setGrammarCheckingEnabled:(BOOL)grammarCheckingEnabled
{
	[TPCPreferences setTextFieldAutomaticGrammarCheck:grammarCheckingEnabled];

	super.grammarCheckingEnabled = grammarCheckingEnabled;
}

- (void)setAutomaticSpellingCorrectionEnabled:(BOOL)automaticSpellingCorrectionEnabled
{
	[TPCPreferences setTextFieldAutomaticSpellCorrection:automaticSpellingCorrectionEnabled];

	super.automaticSpellingCorrectionEnabled = automaticSpellingCorrectionEnabled;
}

- (void)setSmartInsertDeleteEnabled:(BOOL)smartInsertDeleteEnabled
{
	[TPCPreferences setTextFieldSmartCopyPaste:smartInsertDeleteEnabled];

	super.smartInsertDeleteEnabled = smartInsertDeleteEnabled;
}

- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)automaticQuoteSubstitutionEnabled
{
	[TPCPreferences setTextFieldSmartQuotes:automaticQuoteSubstitutionEnabled];

	super.automaticQuoteSubstitutionEnabled = automaticQuoteSubstitutionEnabled;
}

- (void)setAutomaticDashSubstitutionEnabled:(BOOL)automaticDashSubstitutionEnabled
{
	[TPCPreferences setTextFieldSmartDashes:automaticDashSubstitutionEnabled];

	super.automaticDashSubstitutionEnabled = automaticDashSubstitutionEnabled;
}

- (void)setAutomaticLinkDetectionEnabled:(BOOL)automaticLinkDetectionEnabled
{
	[TPCPreferences setTextFieldSmartLinks:automaticLinkDetectionEnabled];

	super.automaticLinkDetectionEnabled = automaticLinkDetectionEnabled;
}

- (void)setAutomaticDataDetectionEnabled:(BOOL)automaticDataDetectionEnabled
{
	[TPCPreferences setTextFieldDataDetectors:automaticDataDetectionEnabled];

	super.automaticDataDetectionEnabled = automaticDataDetectionEnabled;
}

- (void)setAutomaticTextReplacementEnabled:(BOOL)automaticTextReplacementEnabled
{
	[TPCPreferences setTextFieldTextReplacement:automaticTextReplacementEnabled];

	super.automaticTextReplacementEnabled = automaticTextReplacementEnabled;
}

@end

NS_ASSUME_NONNULL_END
