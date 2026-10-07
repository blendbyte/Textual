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
#import "TVCValidatedTextField.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCValidatedTextField ()
/* Maintain cached value so that the drawing does not call
 the validation block every time that it is called. */
@property (nonatomic, assign) BOOL cachedValidValue;
@property (nonatomic, assign) BOOL validationPerformed;
@property (nonatomic, copy, nullable, readwrite) NSString *lastValidationErrorDescription;
@end

@interface TVCValidatedTextFieldCell ()
@property (readonly) NSColor *erroneousValueBackgroundColor;
@property (readonly) BOOL parentValueIsValid;
@property (readonly) TVCValidatedTextField *parentField;
@end

@implementation TVCValidatedTextField

#pragma mark -
#pragma mark Public API (Normal Text Field)

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.cachedValidValue = NO;
}

- (void)dealloc
{
	[self closeValidationErrorPopover];
}

- (BOOL)drawsBackground
{
	return NO;
}

- (NSString *)value
{
	NSString *stringValue = self.stringValue;

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

- (void)textDidChange:(NSNotification *)notification
{
	[self _valueChangedAction];
}

- (void)setStringValue:(NSString *)stringValue
{
	super.stringValue = stringValue;

	[self _valueChangedAction];
}

- (void)_valueChangedAction
{
	[self performValidation];

	[self _valueChangedActionPostflight];
}

- (void)_valueChangedActionPostflight
{
	[self closeValidationErrorPopover];

	[self informCallbackTextDidChange];
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

@implementation TVCValidatedTextFieldCell

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

- (TVCValidatedTextField *)parentField
{
	return (TVCValidatedTextField *)self.controlView;
}

- (BOOL)parentValueIsValid
{
	return self.parentField.valueIsValid;
}

@end

NS_ASSUME_NONNULL_END
