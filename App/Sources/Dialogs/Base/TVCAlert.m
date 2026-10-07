/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional informative.
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
#import "TLOLocalization.h"
#import "TVCAlert.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TVCAlertLaunchedAs) {
	TVCAlertLaunchedAsNonblockingPanel = 0,
	TVCAlertLaunchedAsModal,
	TVCAlertLaunchedAsSheet
};

@interface TVCAlert ()
@property (nonatomic, strong, readwrite) IBOutlet NSPanel *panel;
@property (nonatomic, weak) IBOutlet NSImageView *iconImageView;
@property (nonatomic, weak) IBOutlet NSImageView *warningIconImageView;
@property (nonatomic, weak) IBOutlet NSTextField *messageTextField;
@property (nonatomic, weak) IBOutlet NSTextField *informativeTextField;
@property (nonatomic, weak) IBOutlet NSButton *firstButton;
@property (nonatomic, weak) IBOutlet NSButton *secondButton;
@property (nonatomic, weak) IBOutlet NSButton *thirdButton;
@property (nonatomic, weak, readwrite) IBOutlet NSButton *suppressionButton;
@property (nonatomic, assign) BOOL alertFinished;
@property (nonatomic, assign) BOOL alertImmutable;
@property (nonatomic, assign) BOOL alertVisible;
@property (nonatomic, assign) BOOL layoutPerformed;
@property (nonatomic, assign) TVCAlertLaunchedAs launchedAs;
@property (nonatomic, copy, nullable) TVCAlertCompletionBlock completionBlock;
@property (nonatomic, copy, nullable) TVCAlertButtonClickedBlock firstButtonAction;
@property (nonatomic, copy, nullable) TVCAlertButtonClickedBlock secondButtonAction;
@property (nonatomic, copy, nullable) TVCAlertButtonClickedBlock thirdButtonAction;

- (IBAction)buttonPressed:(id)sender;
@end

@implementation TVCAlert

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TVCAlert" owner:self topLevelObjects:nil];

	self.panel.floatingPanel = YES;

	LogToConsoleDebug("[%{public}@] Creating alert host", self);
}

- (void)showAlert
{
	[self showAlertWithCompletionBlock:nil];
}

- (void)showAlertWithCompletionBlock:(nullable TVCAlertCompletionBlock)completionBlock
{
	[self _showAlertInWindow:nil withCompletionBlock:completionBlock];
}

- (void)showAlertInWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	[self showAlertInWindow:window withCompletionBlock:nil];
}

- (void)showAlertInWindow:(NSWindow *)window withCompletionBlock:(nullable TVCAlertCompletionBlock)completionBlock
{
	NSParameterAssert(window != nil);

	[self _showAlertInWindow:window withCompletionBlock:completionBlock];
}

- (void)_showAlertInWindow:(nullable NSWindow *)window withCompletionBlock:(nullable TVCAlertCompletionBlock)completionBlock
{
	NSAssert((self.alertFinished == NO),
		@"Cannot show alert because it has already finished");

	/* Bring window forward if -showAlert is called more than once */
	if (self.alertVisible) {
		[self.panel makeKeyAndOrderFront:nil];

		return;
	}

	/* Do not allow changes to be made to the alert */
	self.alertImmutable = YES;

	/* Non-blocking alerts which are created through this initializer
	 should not stay on top of other apps when app is not key. */
	if (window == nil) {
		self.window.hidesOnDeactivate = YES;
	}

	/* Perform layout */
	[self _layout];

	/* Present alert */
	self.completionBlock = completionBlock;

	self.alertVisible = YES;

	if (window) {
		LogToConsoleDebug("[%{public}@] Running alert sheet in window: %{public}@", self, window);
	} else {
		LogToConsoleDebug("[%{public}@] Running non-blocking alert", self);
	}

	if (window) {
		self.launchedAs = TVCAlertLaunchedAsSheet;

		[window beginSheet:self.panel
		 completionHandler:^(NSModalResponse returnCode) {
			[self _alertSheetDidEndWithReturnCode:returnCode];
		}];
	} else {
		self.launchedAs = TVCAlertLaunchedAsNonblockingPanel;

		[self.panel makeKeyAndOrderFront:nil];
	}
}

- (TVCAlertResponseButton)runModal
{
	NSAssert((self.alertFinished == NO),
		@"Cannot show alert because it has already finished");

	/* Do not allow this method to be called while modal is running */
	NSAssert((self.alertVisible == NO),
		@"Cannot show alert because it's already visible");

	/* Do not allow changes to be made to the alert */
	self.alertImmutable = YES;

	/* Perform layout */
	[self _layout];

	/* Present alert */
	self.alertVisible = YES;

	self.launchedAs = TVCAlertLaunchedAsModal;

	LogToConsoleDebug("[%{public}@] Running modal alert", self);

	return [NSApp runModalForWindow:self.panel];
}

#pragma mark -
#pragma mark Layout

- (void)_layout
{
	/* Do not perform more than once */
	NSAssert((self.layoutPerformed == NO),
		@"Cannot perform layout multiple times");

	/* Context */
	self.warningIconImageView.hidden = (self.type != TVCAlertTypeWarning);

	NSView *contentView = self.panel.contentView;

	NSTextField *messageTextField = self.messageTextField;
	NSTextField *informativeTextField = self.informativeTextField;

	NSView *accessoryView = self.accessoryView;

	NSButton *suppressionButton = self.suppressionButton;
	BOOL showsSuppressionButton = self.showsSuppressionButton;

	NSView *firstButtonAnchor = nil;

	/* Toggle accessory view */
	if (accessoryView) {
		[contentView addSubview:accessoryView];

		[contentView addConstraints:
		 @[
		   /* Align top of accessory view to bottom of informative text field */
		   [NSLayoutConstraint constraintWithItem:accessoryView
										attribute:NSLayoutAttributeTop
										relatedBy:NSLayoutRelationEqual
										   toItem:informativeTextField
										attribute:NSLayoutAttributeBottom
									   multiplier:1.0
										 constant:16.0],

		   /* Align leading of accessory view to leading of message text field */
		   [NSLayoutConstraint constraintWithItem:accessoryView
										attribute:NSLayoutAttributeLeading
										relatedBy:NSLayoutRelationEqual
										   toItem:messageTextField
										attribute:NSLayoutAttributeLeading
									   multiplier:1.0
										 constant:0.0],

		   /* Align trailing of accessory view to trailing of content view */
		   [NSLayoutConstraint constraintWithItem:contentView
										attribute:NSLayoutAttributeTrailing
										relatedBy:NSLayoutRelationGreaterThanOrEqual
										   toItem:accessoryView
										attribute:NSLayoutAttributeTrailing
									   multiplier:1.0
										 constant:20.0]
		   ]
		 ];

		firstButtonAnchor = accessoryView;
	}

	/* Toggle suppression button */
	if (showsSuppressionButton) {
		NSView *buttonAnchor = ((accessoryView) ?: informativeTextField);

		[contentView addConstraint:
		 /* Align top of suppression button with top of anchor */
		 [NSLayoutConstraint constraintWithItem:suppressionButton
									  attribute:NSLayoutAttributeTop
									  relatedBy:NSLayoutRelationEqual
										 toItem:buttonAnchor
									  attribute:NSLayoutAttributeBottom
									 multiplier:1.0
									   constant:16.0]
		 ];

		firstButtonAnchor = suppressionButton;
	} else {
		[suppressionButton removeFromSuperviewWithoutNeedingDisplay];
	}

	/* Add first button */
	NSAssert((self.firstButton.hidden == NO),
		@"At least one button must be added to alert before presentation");

	firstButtonAnchor = ((firstButtonAnchor) ?: informativeTextField);

	[contentView addConstraint:
	 /* Align top of first button with top of anchor */
	 [NSLayoutConstraint constraintWithItem:self.firstButton
								  attribute:NSLayoutAttributeTop
								  relatedBy:NSLayoutRelationEqual
									 toItem:firstButtonAnchor
								  attribute:NSLayoutAttributeBottom
								 multiplier:1.0
								   constant:20.0]
	 ];

	/* Remove buttons we aren't using */
	/* We do this because even when hidden, their constraints
	 still apply to the layout. We could remove the constraints
	 themselves, but this is an easier solution. */
	if (self.thirdButton.hidden) {
		[self.thirdButton removeFromSuperviewWithoutNeedingDisplay];
	}

	if (self.secondButton.hidden) {
		[self.secondButton removeFromSuperviewWithoutNeedingDisplay];
	}

	/* Update state */
	self.layoutPerformed = YES;

	LogToConsoleDebug("[%{public}@] Layout performed", self);
}

#pragma mark -
#pragma mark Buttons

- (void)buttonPressed:(id)sender
{
	NSInteger buttonClicked = [sender tag];

	LogToConsoleDebug("[%{public}@] Button pressed: %ld", self, buttonClicked);

	TVCAlertButtonClickedBlock actionBlock = nil;

	if (buttonClicked == TVCAlertResponseButtonFirst) {
		actionBlock = self.firstButtonAction;
	} else if (buttonClicked == TVCAlertResponseButtonSecond) {
		actionBlock = self.secondButtonAction;
	} else if (buttonClicked == TVCAlertResponseButtonThird) {
		actionBlock = self.thirdButtonAction;
	}

	if (actionBlock != nil &&
		actionBlock(self, buttonClicked) == NO) {

		LogToConsoleDebug("[%{public}@] Button action block denied alert dismissal", self);

		return;
	}

	[self endAlertWithResponse:buttonClicked];
}

- (NSArray<NSButton *> *)buttons
{
	NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:3];

	if (self.firstButton.hidden == NO) {
		[buttons addObject:self.firstButton];
	}

	if (self.secondButton.hidden == NO) {
		[buttons addObject:self.secondButton];
	}

	if (self.secondButton.hidden == NO) {
		[buttons addObject:self.secondButton];
	}

	return [buttons copy];
}

- (NSButton *)setTitle:(NSString *)title forButton:(TVCAlertResponseButton)button
{
	switch (button) {
		case TVCAlertResponseButtonFirst:
			[self setTitle:title forButtonAtIndex:0];

			break;
		case TVCAlertResponseButtonSecond:
			[self setTitle:title forButtonAtIndex:1];

			break;
		case TVCAlertResponseButtonThird:
			[self setTitle:title forButtonAtIndex:2];

			break;
		default:
			NSAssert(NO, @"Invalid button type");

			break;
	}

	return nil;
}

- (NSButton *)setTitle:(NSString *)title forButtonAtIndex:(NSUInteger)index
{
	NSAssert((index >= 0 && index <= 2),
		@"Index of button is out of bounds. "
		"Index: %lu, Range: 0 - 2", index);

	NSButton *button = nil;

	if (index == 0) {
		button = self.firstButton;
	} else if (index == 1) {
		button = self.secondButton;
	} else if (index == 2) {
		button = self.thirdButton;
	}

	return [self _setTitle:title forButton:button];
}

- (NSButton *)_setTitle:(NSString *)title forButton:(NSButton *)button
{
	NSParameterAssert(title != nil);

	NSAssert((self.alertImmutable == NO),
		@"Cannot add button because alert is immutable");

	if (button.hidden) {
		button.hidden = NO;
	}

	button.title = title;

	button.accessibilityTitle = TXTLS(@"Accessibility[wbj-gr]", title);

	return button;
}

- (void)setButtonClickedBlock:(nullable TVCAlertButtonClickedBlock)block forButton:(TVCAlertResponseButton)button
{
	switch (button) {
		case TVCAlertResponseButtonFirst:
			[self setButtonClickedBlock:block forButtonAtIndex:0];

			break;
		case TVCAlertResponseButtonSecond:
			[self setButtonClickedBlock:block forButtonAtIndex:1];

			break;
		case TVCAlertResponseButtonThird:
			[self setButtonClickedBlock:block forButtonAtIndex:2];

			break;
		default:
			NSAssert(NO, @"Invalid button type");

			break;
	}
}

- (void)setButtonClickedBlock:(nullable TVCAlertButtonClickedBlock)block forButtonAtIndex:(NSUInteger)index
{
	NSAssert((self.alertFinished == NO),
		@"Cannot set button clicked block because alert is finished");

	NSAssert((index >= 0 && index <= 2),
		@"Index of button is out of bounds. "
		"Index: %lu, Range: 0 - 2", index);

	if (index == 0) {
		self.firstButtonAction = block;
	} else if (index == 1) {
		self.secondButtonAction = block;
	} else if (index == 2) {
		self.thirdButtonAction = block;
	}

	LogToConsoleDebug("[%{public}@] Setting button action block at index: %lu", self, index);
}

- (void)endAlert
{
	[self endAlertWithResponse:TVCAlertResponseButtonFirst];
}

- (void)endAlertWithResponse:(TVCAlertResponseButton)response
{
	NSAssert((self.alertFinished == NO),
		@"Cannot end alert because it has already finished");

	NSAssert(self.alertVisible,
		@"Cannot end alert because it isn't visible");

	self.alertFinished = YES;

	switch (self.launchedAs) {
		case TVCAlertLaunchedAsNonblockingPanel:
		{
			[self _postCompletionBlockWithResponse:response];

			[self.panel orderOut:nil];

			break;
		}
		case TVCAlertLaunchedAsSheet:
		{
			[NSApp endSheet:self.panel returnCode:response];

			break;
		}
		case TVCAlertLaunchedAsModal:
		{
			[NSApp stopModalWithCode:response];

			[self.panel orderOut:nil];

			break;
		}
	}

	LogToConsoleDebug("[%{public}@] Alert dismissed", self);

	self.alertVisible = NO;

	// Dereference completion block when finished because the
	// completion block may be the only reference to self.
	self.completionBlock = nil;
}

#pragma mark -
#pragma mark Setter/Getter

- (NSImage *)icon
{
	return self.iconImageView.image;
}

- (void)setIcon:(nullable NSImage *)icon
{
	NSAssert((self.alertImmutable == NO),
		@"Cannot change value because alert is immutable");

	if (icon == nil) {
		icon = [NSImage imageNamed:@"NSApplicationIcon"];
	}

	self.iconImageView.image = icon;
}

- (NSString *)messageText
{
	return self.messageTextField.stringValue;
}

- (void)setMessageText:(NSString *)messageText
{
	NSParameterAssert(messageText != nil);

	NSAssert((self.alertImmutable == NO),
		@"Cannot change value because alert is immutable");

	self.messageTextField.stringValue = messageText;
}

- (NSString *)informativeText
{
	return self.informativeTextField.stringValue;
}

- (void)setInformativeText:(NSString *)informativeText
{
	NSParameterAssert(informativeText != nil);

	NSAssert((self.alertImmutable == NO),
		@"Cannot change value because alert is immutable");

	self.informativeTextField.stringValue = informativeText;
}

- (void)setShowsSuppressionButton:(BOOL)showsSuppressionButton
{
	NSAssert((self.alertImmutable == NO),
		@"Cannot change value because alert is immutable");

	if (self->_showsSuppressionButton != showsSuppressionButton) {
		self->_showsSuppressionButton = showsSuppressionButton;
	}
}

- (void)setAccessoryView:(nullable NSView *)accessoryView
{
	NSAssert((self.alertImmutable == NO),
		@"Cannot change value because alert is immutable");

	if (self->_accessoryView != accessoryView) {
		self->_accessoryView = accessoryView;
	}
}

- (NSWindow *)window
{
	return self.panel;
}

#pragma mark -
#pragma mark Utilities

- (void)_postCompletionBlockWithResponse:(TVCAlertResponseButton)response
{
	if (self.completionBlock) {
		self.completionBlock(self, response);
	}
}

#pragma mark -
#pragma mark Panel Delegate

- (void)_alertSheetDidEndWithReturnCode:(NSInteger)returnCode
{
	[self _postCompletionBlockWithResponse:returnCode];

	[self.panel orderOut:nil];
}

@end

NS_ASSUME_NONNULL_END
