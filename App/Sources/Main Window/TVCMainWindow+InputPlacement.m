/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "IRCClientPrivate.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowTextViewInternal.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindow (InputPlacement)

/* The input field, with the upload and reply bars above it, is under the
 whole window or under the chat only (Settings › Typing). The split view
 keeps its columns the same height, so the chat's column is a view of its
 own holding the channel view, and under the chat only the field moves into
 it, below the channel view. (Laid over the column instead, it took the
 clicks, and AppKit stopped drawing the columns: the field says it's
 opaque.) The field and its bars move as one: a view holding them, set up
 once the bars are there. */
- (void)setUpInputFieldPlacement
{
	if (self.inputFieldStack) {
		return;
	}

	NSView *contentView = self.contentView;

	NSView *uploadBar = self.uploadBar;

	NSView *replyBar = self.replyBar;

	NSView *inputArea = self.inputTextField.contentView;

	if (contentView == nil || uploadBar == nil || replyBar == nil || inputArea == nil) {
		return;
	}

	NSView *stack = [NSView new];

	stack.translatesAutoresizingMaskIntoConstraints = NO;

	/* Their constraints to the window's views go with them. The field
	 first, as it was: it says it's opaque, and AppKit then didn't draw
	 the bars added before it */
	for (NSView *view in @[inputArea, replyBar, uploadBar]) {
		[view removeFromSuperview];

		[stack addSubview:view];
	}

	[NSLayoutConstraint activateConstraints:@[
		[uploadBar.topAnchor constraintEqualToAnchor:stack.topAnchor],
		[uploadBar.bottomAnchor constraintEqualToAnchor:replyBar.topAnchor],
		[replyBar.bottomAnchor constraintEqualToAnchor:inputArea.topAnchor],
		[inputArea.bottomAnchor constraintEqualToAnchor:stack.bottomAnchor]
	]];

	for (NSView *view in @[uploadBar, replyBar, inputArea]) {
		[view.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor].active = YES;
		[view.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor].active = YES;
	}

	/* One strip of the sidebars' material behind the field and the bars
	 above it, like the title bar's band, so the chat sits in one frame */
	NSVisualEffectView *backgroundView = [NSVisualEffectView new];

	backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
	backgroundView.blendingMode = NSVisualEffectBlendingModeBehindWindow;

	[self.class applySidebarTranslucencyToView:backgroundView];

	[stack addSubview:backgroundView positioned:NSWindowBelow relativeTo:nil];

	[NSLayoutConstraint activateConstraints:@[
		[backgroundView.topAnchor constraintEqualToAnchor:stack.topAnchor],
		[backgroundView.bottomAnchor constraintEqualToAnchor:stack.bottomAnchor],
		[backgroundView.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor],
		[backgroundView.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor]
	]];

	self.inputFieldBackgroundView = backgroundView;

	self.inputFieldStack = stack;

	[self updateInputFieldPlacement];
}

- (void)updateInputFieldPlacement
{
	NSView *stack = self.inputFieldStack;

	NSView *contentView = self.contentView;

	NSView *column = self.chatColumn;

	TVCMainWindowSplitView *splitView = self.contentSplitView;

	TVCMainWindowChannelView *channelView = self.channelView;

	NSView *loadingScreen = self.loadingScreen;

	if (stack == nil || contentView == nil || column == nil || splitView == nil || channelView == nil || loadingScreen == nil) {
		return;
	}

	BOOL underChat = ([TPCPreferences inputFieldPlacement] == TXInputFieldPlacementChat);

	NSView *host = ((underChat) ? column : contentView);

	[NSLayoutConstraint deactivateConstraints:self.inputFieldPlacementConstraints];

	if (stack.superview != host) {
		/* Typing goes on where it was */
		NSTextView *textView = self.inputTextField;

		BOOL wasTyping = (self.firstResponder == textView);

		[stack removeFromSuperview];

		/* Below the other views: nothing is drawn over the lists */
		[host addSubview:stack positioned:NSWindowBelow relativeTo:nil];

		if (wasTyping) {
			[self makeFirstResponder:textView];
		}
	}

	NSArray *constraints = nil;

	if (underChat) {
		/* The lists (and the loading screen) go down to the bottom,
		 the chat stops where the field begins */
		CGFloat chatMinimumHeight = self.inputTextField.windowContentViewMinimumHeight.constant;

		constraints = @[
			[stack.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
			[stack.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
			[stack.bottomAnchor constraintEqualToAnchor:column.bottomAnchor],
			[channelView.bottomAnchor constraintEqualToAnchor:stack.topAnchor],
			[channelView.heightAnchor constraintGreaterThanOrEqualToConstant:chatMinimumHeight],
			[splitView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
			[loadingScreen.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
		];
	} else {
		constraints = @[
			[stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
			[stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
			[stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
			[splitView.bottomAnchor constraintEqualToAnchor:stack.topAnchor],
			[loadingScreen.bottomAnchor constraintEqualToAnchor:stack.topAnchor],
			[channelView.bottomAnchor constraintEqualToAnchor:column.bottomAnchor]
		];
	}

	[NSLayoutConstraint activateConstraints:constraints];

	self.inputFieldPlacementConstraints = constraints;

	/* Its width changed: the lines wrap anew */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[self.inputTextField recalculateTextViewSizeForced];
	});
}

@end

NS_ASSUME_NONNULL_END
