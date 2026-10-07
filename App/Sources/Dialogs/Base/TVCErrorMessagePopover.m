/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *    Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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
#import "TVCErrorMessagePopoverPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _messageMaximumWidth 			330.0
#define _messageHorizontalPadding		5.0
#define _messageVerticalPadding			5.0
#define _errorIconWidth					15.0
#define _errorIconHeight				15.0
#define _errorIconHorizontalPadding		5.0
#define _errorIconVerticalPadding		6.0

@interface TVCErrorMessagePopoverView : NSPopover
@end

@interface TVCErrorMessagePopover ()
@property (nonatomic, strong, nullable) NSPopover *popover;
@end

@implementation TVCErrorMessagePopover

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithMessage:(NSString *)message relativeToView:(NSView *)view
{
	NSParameterAssert(message != nil);
	NSParameterAssert(view != nil);

	if ((self = [super init])) {
		self->_message = [message copy];

		self->_view = view;

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self close];
}

- (void)_createPopover
{
	/* Create view controller */
	NSViewController *viewController = [NSViewController new];

	/* Create view */
	NSView *popoverView = [[NSView alloc] initWithFrame:NSZeroRect];

	popoverView.translatesAutoresizingMaskIntoConstraints = NO;

	viewController.view = popoverView;

	/* Create image view */
	NSImageView *errorIcon = [NSImageView new];

	errorIcon.translatesAutoresizingMaskIntoConstraints = NO;

	errorIcon.editable = NO;

	errorIcon.image = [NSImage imageNamed:@"ErroneousTextFieldValueIndicator"];

	[errorIcon addConstraints:
	 	@[
		 [NSLayoutConstraint constraintWithItem:errorIcon
									  attribute:NSLayoutAttributeWidth
									  relatedBy:NSLayoutRelationEqual
										 toItem:nil
									  attribute:NSLayoutAttributeNotAnAttribute
									 multiplier:1.0
									   constant:_errorIconWidth],

		 [NSLayoutConstraint constraintWithItem:errorIcon
									  attribute:NSLayoutAttributeHeight
									  relatedBy:NSLayoutRelationEqual
										 toItem:nil
									  attribute:NSLayoutAttributeNotAnAttribute
									 multiplier:1.0
									   constant:_errorIconHeight]
	 	]
	 ];

	[popoverView addSubview:errorIcon];

	[popoverView addConstraints:
	 	@[
		  [NSLayoutConstraint constraintWithItem:errorIcon
									   attribute:NSLayoutAttributeLeading
									   relatedBy:NSLayoutRelationEqual
										  toItem:popoverView
									   attribute:NSLayoutAttributeLeading
									  multiplier:1.0
										constant:_errorIconHorizontalPadding],

		  [NSLayoutConstraint constraintWithItem:errorIcon
									   attribute:NSLayoutAttributeTop
									   relatedBy:NSLayoutRelationEqual
										  toItem:popoverView
									   attribute:NSLayoutAttributeTop
									  multiplier:1.0
										constant:_errorIconVerticalPadding],
		]
	 ];

	/* Create message */
	NSTextField *errorMessage = [NSTextField new];

	errorMessage.translatesAutoresizingMaskIntoConstraints = NO;

	errorMessage.editable = NO;

	errorMessage.bordered = NO;
	errorMessage.drawsBackground = NO;

	errorMessage.stringValue = self.message;

	errorMessage.cell.wraps = YES;

	errorMessage.preferredMaxLayoutWidth = _messageMaximumWidth;

	/* Add message */
	[popoverView addSubview:errorMessage];

	[popoverView addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"H:[errorIcon]-messageHorizontalPadding-[errorMessage]-messageHorizontalPadding-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:@{@"messageHorizontalPadding" : @(_messageHorizontalPadding)}
											   views:NSDictionaryOfVariableBindings(errorIcon, errorMessage)]];

	[popoverView addConstraints:
	 [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-messageVerticalPadding-[errorMessage]-messageVerticalPadding-|"
											 options:NSLayoutFormatDirectionLeadingToTrailing
											 metrics:@{@"messageVerticalPadding" : @(_messageVerticalPadding)}
											   views:NSDictionaryOfVariableBindings(errorMessage)]];

	/* Create popover */
	NSPopover *popover = [TVCErrorMessagePopoverView new];

	popover.delegate = (id)self;

	popover.contentViewController = viewController;

	popover.behavior = NSPopoverBehaviorTransient;

	popover.animates = NO;

	self.popover = popover;
}

- (void)showRelativeToRect:(NSRect)rect
{
	[self showRelativeToRect:rect preferredEdge:NSRectEdgeMaxY];
}

- (void)showRelativeToRect:(NSRect)rect preferredEdge:(NSRectEdge)preferredEdge
{
	if (self.popover == nil) {
		[self _createPopover];
	}

	[self.popover showRelativeToRect:rect ofView:self.view preferredEdge:preferredEdge];
}

- (void)close
{
	NSPopover *popover = self.popover;

	if (popover == nil) {
		return;
	}

	[popover close];

	self.popover = nil;
}

- (void)popoverWillShow:(NSNotification *)notification
{
	if ([self.delegate respondsToSelector:@selector(errorMessagePopoverWillShow:)]) {
		[self.delegate errorMessagePopoverWillShow:self];
	}
}

- (void)popoverDidShow:(NSNotification *)notification
{
	if ([self.delegate respondsToSelector:@selector(errorMessagePopoverDidShow:)]) {
		[self.delegate errorMessagePopoverDidShow:self];
	}
}

- (void)popoverWillClose:(NSNotification *)notification
{
	if ([self.delegate respondsToSelector:@selector(errorMessagePopoverWillClose:)]) {
		[self.delegate errorMessagePopoverWillClose:self];
	}
}

- (void)popoverDidClose:(NSNotification *)notification
{
	if ([self.delegate respondsToSelector:@selector(errorMessagePopoverDidClose:)]) {
		[self.delegate errorMessagePopoverDidClose:self];
	}
}

@end

#pragma mark -

@implementation TVCErrorMessagePopoverView

- (void)mouseDown:(NSEvent *)event
{
	[self close];
}

@end

NS_ASSUME_NONNULL_END
