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

#import "TLOLocalization.h"
#import "TVCErrorMessagePopoverControllerPrivate.h"
#import "TVCValidatedComboBox.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCValidatedComboBox ()
/* Maintain cached value so that the drawing does not call
 the validation block every time that it is called. */
@property (nonatomic, assign) BOOL cachedValidValue;
@property (nonatomic, assign, readwrite) BOOL valueIsPredefined;
@property (nonatomic, assign) BOOL validationPerformed;
@property (nonatomic, assign) BOOL listVisible;
@property (nonatomic, assign) BOOL selectionChangedWhileListVisible;
@property (nonatomic, assign) BOOL selectionChangedWhileSetting;
@property (nonatomic, copy, nullable, readwrite) NSString *lastValidationErrorDescription;
@end

@interface TVCValidatedComboBoxCell ()
@property (readonly) NSColor *erroneousValueBackgroundColor;
@property (readonly) BOOL parentValueIsValid;
@property (readonly) TVCValidatedComboBox *parentField;
@end

@implementation TVCValidatedComboBox

#pragma mark -
#pragma mark Public API (Combo Box Text Field)

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.cachedValidValue = NO;

	[RZNotificationCenter() addObserver:self
							   selector:@selector(comboBoxSelectionDidChange:)
								   name:NSComboBoxSelectionDidChangeNotification
								 object:self];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(comboBoxWillPopUp:)
								   name:NSComboBoxWillPopUpNotification
								 object:self];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(comboBoxWillDismiss:)
								   name:NSComboBoxWillDismissNotification
								 object:self];

}

- (void)dealloc
{
	[self closeValidationErrorPopover];

	[RZNotificationCenter() removeObserver:self];
}

- (BOOL)drawsBackground
{
	return NO;
}

- (NSString *)value
{
	NSString *stringValue = self.objectValueOfSelectedItem;

	if (stringValue) {
		return stringValue;
	}

	stringValue = self.stringValue;

	if (self.stringValueUsesOnlyFirstToken) {
		stringValue = stringValue.trimAndGetFirstToken;
	} else if (self.stringValueIsTrimmed) {
		stringValue = stringValue.trim;
	}

	if (stringValue.length == 0) {
		if (	   self.defaultValue && self.stringValueIsInvalidOnEmpty == NO) {
			return self.defaultValue;
		}
	}

	return stringValue;
}

- (NSString *)lowercaseValue
{
	return self.value.lowercaseString;
}

- (NSString *)uppercaseValue
{
	return self.value.uppercaseString;
}

- (NSInteger)integerValue
{
	return self.value.integerValue;
}

- (void)setIntegerValue:(NSInteger)integerValue
{
	self.stringValue = [NSString stringWithInteger:integerValue];
}

- (BOOL)valueIsEmpty
{
	return (self.stringValue.length == 0);
}

- (BOOL)valueIsValid
{
	return self.cachedValidValue;
}

#pragma mark -
#pragma mark Interval Validation

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	self.selectionChangedWhileListVisible = self.listVisible;

	if (self.selectionChangedWhileSetting) {
		self.selectionChangedWhileSetting = NO;

		[self recalculateSelection];
	}
}

- (void)comboBoxWillPopUp:(NSNotification *)notification
{
	self.listVisible = YES;
}

- (void)comboBoxWillDismiss:(NSNotification *)notification
{
	self.listVisible = NO;

	if (self.selectionChangedWhileListVisible) {
		self.selectionChangedWhileListVisible = NO;

		[self recalculateSelection];
	}
}

- (void)textDidChange:(NSNotification *)notification
{
	/* NSComboBoxCell observes NSTextDidChangeNotification to know
	 when to update the selection index. */
	/* Our observance of this notification is competing with theirs
	 which causes a race condition. To work around this, we wait until
	 the next pass of the main loop to perform our validation because
	 the internals of the cell should have selection index up to date
	 by then to reflect the string value. */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self recalculateSelection];
	});
}

- (void)setStringValue:(NSString *)stringValue
{
	super.stringValue = stringValue;

	NSUInteger objectIndex = [self indexOfItemWithObjectValue:stringValue];

	if (objectIndex != NSNotFound) {
		self.selectionChangedWhileSetting = YES;

		[self selectItemAtIndex:objectIndex];

		return;
	}

	[self resetSelection];
}

- (void)resetSelection
{
	self.valueIsPredefined = NO;

	[self _valueChangedAction];
}

- (void)recalculateSelection
{
	self.valueIsPredefined = (self.indexOfSelectedItem >= 0);

	[self _valueChangedAction];
}

- (void)_valueChangedAction
{
	if (self.valueIsPredefined) {
		/* If predefined selection, then the value is valid
		 no matter what because it is a value WE defined. */
		self.cachedValidValue = YES;

		self.lastValidationErrorDescription = nil;
	} else {
		[self performValidation];
	}

	[self _valueChangedActionPostflight];
}

- (void)_valueChangedActionPostflight
{
	[self closeValidationErrorPopover];

	[self informCallbackTextDidChange];

	[self setNeedsDisplay:YES];
}

- (void)informCallbackTextDidChange
{
	if (self.textDidChangeCallback == nil) {
		return;
	}

	if ([self.textDidChangeCallback respondsToSelector:@selector(validatedTextFieldTextDidChange:)]) {
		[self.textDidChangeCallback performSelector:@selector(validatedTextFieldTextDidChange:) withObject:self];
	}
}

- (void)performValidation
{
	NSString *stringToValidate = self.stringValue;

	NSString *errorDescription = nil;

	if (stringToValidate.length > 0) {
		if (self.validationBlock) {
			errorDescription = self.validationBlock(stringToValidate);
		}
	} else {
		if (self.performValidationWhenEmpty) {
			errorDescription = self.validationBlock(stringToValidate);
		} else if (self.stringValueIsInvalidOnEmpty) {
			errorDescription = TXTLS(@"BasicLanguage[fo8-1h]");
		}
	}

	self.cachedValidValue = (errorDescription == nil);

	self.lastValidationErrorDescription = errorDescription;

	self.validationPerformed = YES;
}

- (BOOL)showValidationErrorPopover
{
	if (self.validationPerformed == NO) {
		[self performValidation];
	}

	NSString *errorDescription = self.lastValidationErrorDescription;

	if (errorDescription == nil) {
		return NO;
	}

	if (self.window == nil) {
		return NO;
	}

	[[TVCErrorMessagePopoverController sharedController] showMessage:errorDescription forView:self];

	return YES;
}

- (void)closeValidationErrorPopover
{
	[[TVCErrorMessagePopoverController sharedController] closeMessageForView:self];
}

- (void)viewWillMoveToWindow:(nullable NSWindow *)newWindow
{
	/* While outside logic is responsible for displaying the
	 validation error message, it would not hurt to help it a
	 little bit by dismissing the message when the view is no
	 longer on a window. */
	if (newWindow == nil) {
		[self closeValidationErrorPopover];
	}
}

@end

#pragma mark -
#pragma mark Text Field Cell

@implementation TVCValidatedComboBoxCell

- (NSColor *)erroneousValueBackgroundColor
{
	return [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.05];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if (self.parentValueIsValid == NO) {
		NSRect backgroundFrame = cellFrame;

		backgroundFrame.origin.x += 1.0;
		backgroundFrame.origin.y += 1.0;

		backgroundFrame.size.width -= 2.0;
		backgroundFrame.size.height -= 2.0;

		NSColor *backgroundColor = self.erroneousValueBackgroundColor;

		NSBezierPath *backgroundFill = [NSBezierPath bezierPathWithRect:backgroundFrame];

		[backgroundColor set];

		[backgroundFill fill];
	}

	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (TVCValidatedComboBox *)parentField
{
	return (TVCValidatedComboBox *)self.controlView;
}

- (BOOL)parentValueIsValid
{
	return self.parentField.valueIsValid;
}

@end

NS_ASSUME_NONNULL_END
