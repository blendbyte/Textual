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
#import "TVCMainWindow.h"
#import "TVCMainWindowSegmentedControlPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TVCMainWindowTextViewAppearancePrivate.h"
#import "TVCMainWindowTextViewPrivate.h"

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

@interface TVCMainWindowTextView ()
@property (nonatomic, copy) NSAttributedString *placeholderAttributedString;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *windowContentViewMinimumHeight;
@property (nonatomic, weak) IBOutlet TVCMainWindowTextViewBackground *backgroundView;
@property (nonatomic, weak) IBOutlet TVCMainWindowTextViewContentView *contentView;
@property (nonatomic, weak) IBOutlet TVCMainWindowSegmentedController *segmentedController;
@property (nonatomic, weak) IBOutlet TVCMainWindowSegmentedControllerCell *segmentedControllerCell;
@property (nonatomic, strong) TVCMainWindowTextViewAppearance *userInterfaceObjects;
@property (readonly) NSArray<NSString *> *defaultSpellingIgnores;
@end

@interface TVCMainWindowTextViewBackground ()
@property (nonatomic, unsafe_unretained) IBOutlet TVCMainWindowTextView *textView;
@end

@interface TVCMainWindowTextViewContentView ()
@property (nonatomic, unsafe_unretained) IBOutlet TVCMainWindowTextView *textView;
@property (nonatomic, weak) IBOutlet TVCMainWindowSegmentedController *segmentedController;
@end

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

	NSWindow *window = self.window;

	if (window)
	{
		for (NSString *key in _KeyObservingArray) {
			[RZUserDefaults() addObserver:self forKeyPath:key options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:NULL];
		}
	}
	else // window
	{
		for (NSString *key in _KeyObservingArray) {
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

#pragma mark -
#pragma mark Background Drawing

@implementation TVCMainWindowTextViewBackground

- (void)drawControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	if (appearance.isDarkAppearance == NO) {
		[self drawLightControllerForWithAppearance:appearance];
	} else {
		[self drawDarkControllerForWithAppearance:appearance];
	}
}

- (void)drawDarkControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	BOOL isWindowActive = self.mainWindow.activeForDrawing;

	NSRect cellBounds = self.frame;

	NSRect controlFrame = NSMakeRect(0.0, 1.0,   cellBounds.size.width,
												(cellBounds.size.height - 2.0));

	/* Inner background color */
	NSColor *backgroundColor = nil;

	if (isWindowActive) {
		backgroundColor = appearance.textViewBackgroundColorActiveWindow;
	} else {
		backgroundColor = appearance.textViewBackgroundColorInactiveWindow;
	} // isWindowActive

	/* Shadow colors */
	NSShadow *outsideShadow = [NSShadow new];

	outsideShadow.shadowBlurRadius = 0.0;
	outsideShadow.shadowOffset = NSMakeSize(0.0, (-1.0));

	if (isWindowActive) {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorActiveWindow;
	} else {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorInactiveWindow;
	} // isWindowActive

	/* Rectangle drawing */
	NSBezierPath *rectanglePath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:3.0 yRadius:3.0];

	[NSGraphicsContext saveGraphicsState];

	[outsideShadow set];

	[backgroundColor setFill];

	[rectanglePath fill];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawLightControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	/* To be honest, I don't remember what any of this does. */

	BOOL isWindowActive = self.mainWindow.activeForDrawing;

	NSRect cellBounds = self.frame;

	NSRect controlFrame = NSMakeRect(0.0, 1.0,   cellBounds.size.width,
												(cellBounds.size.height - 2.0));

	CGContextRef context = RZGraphicsCurrentContext().CGContext;

	/* Inner gradient color */
	NSGradient *insideGradient = nil;

	if (isWindowActive) {
		insideGradient = appearance.textViewInsideGradientActiveWindow;
	} else {
		insideGradient = appearance.textViewInsideGradientInactiveWindow;
	} // isWindowActive

	/* Inside shadow */
	NSShadow *insideShadow = [NSShadow new];

	insideShadow.shadowBlurRadius = 0.0;
	insideShadow.shadowOffset = NSMakeSize(0.0, (-1.0));

	NSColor *insideShadowColor = nil;

	if (isWindowActive) {
		insideShadowColor = appearance.textViewInsideShadowColorActiveWindow;
	} else {
		insideShadowColor = appearance.textViewInsideShadowColorInactiveWindow;
	}

	insideShadow.shadowColor = insideShadowColor;

	/* Outside shadow */
	NSShadow *outsideShadow = [NSShadow new];

	if (appearance.isHighResolutionAppearance == NO) {
		outsideShadow.shadowBlurRadius = 0.0;
		outsideShadow.shadowOffset = NSMakeSize(0.0, (-1.0));
	} else {
		outsideShadow.shadowBlurRadius = 0.0;
		outsideShadow.shadowOffset = NSMakeSize(0.0, (-0.5));
	} // high resolution

	if (isWindowActive) {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorActiveWindow;
	} else {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorInactiveWindow;
	} // isWindowActive

	/* Rectangle drawing */
	NSBezierPath *rectanglePath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:3.0 yRadius:3.0];

	[outsideShadow set];

	CGContextBeginTransparencyLayer(context, NULL);

	[insideGradient drawInBezierPath:rectanglePath angle:(-90)];

	CGContextEndTransparencyLayer(context);

	/* Prepare drawing for inside shadow */
	CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);

	CGContextSetAlpha(context, insideShadowColor.alphaComponent);

	CGContextBeginTransparencyLayer(context, NULL);

	{
		/* Inside shadow drawing */
		[insideShadow set];

		CGContextSetBlendMode(context, kCGBlendModeSourceOut);

		CGContextBeginTransparencyLayer(context, NULL);

		/* Fill shadow */
		[insideShadowColor setFill];

		[rectanglePath fill];

		/* Complete drawing */
		CGContextEndTransparencyLayer(context);
	}

	CGContextEndTransparencyLayer(context);

	/* On retina, we fake a second shadow under the bottommost one */
	if (appearance.isHighResolutionAppearance) {
		NSColor *controlColor = nil;

		if (isWindowActive) {
			controlColor = appearance.textViewOutsideSecondaryShadowColorActiveWindow;
		} else {
			controlColor = appearance.textViewOutsideSecondaryShadowColorInactiveWindow;
		} // isWindowActive

		[controlColor setStroke];

		NSPoint linePoint1 = NSMakePoint(2.0, 0.0);
		NSPoint linePoint2 = NSMakePoint((cellBounds.size.width - 2.0), 0.0);

		[NSBezierPath strokeLineFromPoint:linePoint1 toPoint:linePoint2];
	} // high resolution
}

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect] == NO) {
		return;
	}

	TVCMainWindowTextViewAppearance *appearance = self.textView.userInterfaceObjects;

	if (appearance == nil) {
		return;
	}

	[self drawControllerForWithAppearance:appearance];
}

@end

#pragma mark -
#pragma mark Text Field Background Vibrant View

@implementation TVCMainWindowTextViewContentView

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect] == NO) {
		return;
	}

	TVCMainWindowTextViewAppearance *appearance = self.textView.userInterfaceObjects;

	if (appearance == nil) {
		return;
	}

	/* Draw background color */
	NSColor *backgroundColor = appearance.backgroundViewBackgroundColor;

	[backgroundColor set];

	NSRectFill(dirtyRect);

	/* Draw divider */
	NSRect contentViewFrame = self.frame;

	contentViewFrame.origin.x = 0.0;
	contentViewFrame.origin.y = (NSMaxY(contentViewFrame) - 1.0);

	contentViewFrame.size.height = 1.0;

	NSBezierPath *dividerPath = [NSBezierPath bezierPathWithRect:contentViewFrame];

	NSColor *dividerColor = appearance.backgroundViewDividerColor;

	[dividerColor set];

	[dividerPath fill];
}

- (BOOL)allowsVibrancy
{
	return NO;
}

- (BOOL)isOpaque
{
	return YES;
}

@end

NS_ASSUME_NONNULL_END
