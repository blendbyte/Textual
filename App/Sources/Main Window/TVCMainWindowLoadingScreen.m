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
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowLoadingScreenView ()
@property (nonatomic, weak) NSView *visibleView;
@property (nonatomic, strong) IBOutlet NSView *welcomeAddServerView;
@property (nonatomic, weak) IBOutlet NSButton *welcomeAddServerViewContinueButton;
@property (nonatomic, strong) IBOutlet NSView *progressView;
@property (nonatomic, weak) IBOutlet NSTextField *progressViewDescriptionTextField;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressViewIndicator;
@property (nonatomic, strong) IBOutlet NSView *trialExpiredView;
@end

@implementation TVCMainWindowLoadingScreenView

#pragma mark -
#pragma mark Display View (Public)

- (void)showWelcomeAddServerView
{
	[self displayView:self.welcomeAddServerView];
}

- (void)showProgressViewWithReason:(NSString *)progressReason
{
	NSParameterAssert(progressReason != nil);

	[self displayView:self.progressView];

	[self setProgressViewReason:progressReason];

	[self.progressViewIndicator startAnimation:nil];
}

- (void)setProgressViewReason:(NSString *)progressReason
{
	NSParameterAssert(progressReason != nil);

	self.progressViewDescriptionTextField.stringValue = progressReason;
}

- (void)showTrialExpiredView
{
	[self displayView:self.trialExpiredView];
}

#pragma mark -

- (void)hide
{
	[self hideAnimated:NO];
}

- (void)hideAnimated
{
	[self hideAnimated:YES];
}

- (void)hideAnimated:(BOOL)animated
{
	[self hideView:self.visibleView animate:animated];
}

#pragma mark -
#pragma mark Display View (Private)

- (void)displayView:(NSView *)view
{
	NSParameterAssert(view != nil);

	if (self.visibleView != nil) {
		[self.visibleView removeFromSuperview];
	}

	self.visibleView = view;

	[self disableBackgroundControlsStepOne];

	[self addSubview:view];

	NSArray *constraints = @[
	/* Center view on both axis. */
	 [NSLayoutConstraint constraintWithItem:view
								  attribute:NSLayoutAttributeCenterX
								  relatedBy:NSLayoutRelationEqual
									 toItem:self
								  attribute:NSLayoutAttributeCenterX
								 multiplier:1.0
								   constant:0.0],

	 [NSLayoutConstraint constraintWithItem:view
								  attribute:NSLayoutAttributeCenterY
								  relatedBy:NSLayoutRelationEqual
									 toItem:self
								  attribute:NSLayoutAttributeCenterY
								 multiplier:1.0
								   constant:0.0],

	 /* Constrain edges but use >= so that window does not
	  shrink to conform to it. */
	 [NSLayoutConstraint constraintWithItem:view
								  attribute:NSLayoutAttributeLeft
								  relatedBy:NSLayoutRelationGreaterThanOrEqual
									 toItem:self
								  attribute:NSLayoutAttributeLeft
								 multiplier:1.0
								   constant:0.0],

	 [NSLayoutConstraint constraintWithItem:view
								  attribute:NSLayoutAttributeTop
								  relatedBy:NSLayoutRelationGreaterThanOrEqual
									 toItem:self
								  attribute:NSLayoutAttributeTop
								 multiplier:1.0
								   constant:0.0],
	 ];

	[self addConstraints:constraints];

	self.alphaValue = 1.0;

	self.hidden = NO;

	[self displayIfNeeded];

	[self disableBackgroundControlsStepTwo];
}

#pragma mark -
#pragma mark Hide View (Private)

- (void)hideView:(NSView *)view animate:(BOOL)animate
{
	[self enableBackgroundControlsStepOne];

	/* ================================== */

	void (^phaseTwoBlock)(NSView *) = ^(NSView *viewToHide) {
		[view removeFromSuperview];

		/* We only continue with phase two if we have not
		 replaced the visible view with a new one. */
		if (self.visibleView == viewToHide) {
			self.visibleView = nil;

			self.hidden = YES;

			[self enableBackgroundControlsStepTwo];
		}
	};

	/* ================================== */

	if (animate == NO) {
		self.alphaValue = 0.0;

		phaseTwoBlock(view);

		return;
	}

	/* ================================== */

	RZAnimationCurrentContext().duration = 1.0;

	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		self.animator.alphaValue = 0.0;
	} completionHandler:^{
		phaseTwoBlock(view);
	}];
}

#pragma mark -
#pragma mark Private Utilities

- (BOOL)viewIsVisible
{
	return (self.isHidden == NO);
}

- (void)disableBackgroundControlsStepOne
{
	self.mainWindow.contentSplitView.hidden = YES;
}

- (void)disableBackgroundControlsStepTwo
{
	TVCMainWindowTextView *textField = self.mainWindow.inputTextField;

	textField.editable = NO;

	textField.selectable = NO;

	[textField updateSegmentedController];
}

- (void)enableBackgroundControlsStepOne
{
	self.mainWindow.contentSplitView.hidden = NO;
}

- (void)enableBackgroundControlsStepTwo
{
	TVCMainWindowTextView *textField = self.mainWindow.inputTextField;

	textField.editable = YES;

	textField.selectable = YES;

	[textField updateSegmentedController];
}

@end

NS_ASSUME_NONNULL_END
