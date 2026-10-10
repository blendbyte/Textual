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
#import "TVCMainWindow.h"
#import "TVCMainWindowAppearance.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindowTitlebarAccessoryView
@end

@implementation TVCMainWindowTitlebarAccessoryViewController
@end

@interface TVCMainWindowTitlebarTitleField ()
@property (nonatomic, weak) NSWindow *titleWindow;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@end

@implementation TVCMainWindowTitlebarTitleField

- (instancetype)initInTitlebarOfWindow:(NSWindow *)window
{
	NSParameterAssert(window != nil);

	if ((self = [super initWithFrame:NSZeroRect])) {
		self.titleWindow = window;

		self.bezeled = NO;
		self.bordered = NO;
		self.drawsBackground = NO;
		self.editable = NO;
		self.selectable = NO;

		self.font = [NSFont titleBarFontOfSize:0.0];

		self.alignment = NSTextAlignmentCenter;

		self.lineBreakMode = NSLineBreakByTruncatingTail;

		self.maximumNumberOfLines = 1;

		/* VoiceOver reads the window's title */
		self.accessibilityElement = NO;

		self.translatesAutoresizingMaskIntoConstraints = NO;

		/* Shortened rather than overlapping the buttons */
		[self setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

		/* The title bar view holds the window buttons and moves with them
		 into the title bar shown at the top of the screen in full screen */
		NSView *titlebarView = [window standardWindowButton:NSWindowCloseButton].superview;

		[titlebarView addSubview:self];

		self.leadingConstraint = [self.leadingAnchor constraintGreaterThanOrEqualToAnchor:titlebarView.leadingAnchor];
		self.trailingConstraint = [self.trailingAnchor constraintLessThanOrEqualToAnchor:titlebarView.trailingAnchor];

		[NSLayoutConstraint activateConstraints:@[
			[self.centerXAnchor constraintEqualToAnchor:titlebarView.centerXAnchor],
			[self.centerYAnchor constraintEqualToAnchor:titlebarView.centerYAnchor],
			self.leadingConstraint,
			self.trailingConstraint
		]];

		[self updateTextColor];
	}

	return self;
}

- (void)setSideMargin:(CGFloat)sideMargin
{
	if (_sideMargin != sideMargin) {
		_sideMargin = sideMargin;

		self.leadingConstraint.constant = sideMargin;
		self.trailingConstraint.constant = (-sideMargin);
	}
}

- (void)updateTextColor
{
	NSWindow *window = self.titleWindow;

	/* Dimmed like the window buttons when the window is in the background */
	if (window.keyWindow || window.mainWindow) {
		self.textColor = [NSColor windowFrameTextColor];
	} else {
		self.textColor = [NSColor tertiaryLabelColor];
	}
}

/* Clicks go to the title bar: dragging the window, double-click to zoom */
- (nullable NSView *)hitTest:(NSPoint)point
{
	return nil;
}

@end

NS_ASSUME_NONNULL_END
