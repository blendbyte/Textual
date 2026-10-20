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

#import "IRCChannel.h"
#import "IRCClientPrivate.h"
#import "TLOLocalization.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMemberListPrivate.h"
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

	NSView *stateBar = [self makeStateBar];

	NSView *stack = [NSView new];

	stack.translatesAutoresizingMaskIntoConstraints = NO;

	/* Their constraints to the window's views go with them. The field
	 first, as it was: it says it's opaque, and AppKit then didn't draw
	 the bars added before it */
	for (NSView *view in @[inputArea, replyBar, uploadBar]) {
		[view removeFromSuperview];

		[stack addSubview:view];
	}

	[stack addSubview:stateBar];

	[NSLayoutConstraint activateConstraints:@[
		[uploadBar.topAnchor constraintEqualToAnchor:stack.topAnchor],
		[uploadBar.bottomAnchor constraintEqualToAnchor:replyBar.topAnchor],
		[replyBar.bottomAnchor constraintEqualToAnchor:stateBar.topAnchor],
		[stateBar.bottomAnchor constraintEqualToAnchor:inputArea.topAnchor],
		[inputArea.bottomAnchor constraintEqualToAnchor:stack.bottomAnchor]
	]];

	for (NSView *view in @[uploadBar, replyBar, stateBar, inputArea]) {
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

	[self updateStateBar];
}

#pragma mark -
#pragma mark Not Connected, Not Joined

/* "Not connected to Libera Chat [Connect]" or "You're not in #channel
 [Join]" above the input field, on the same strip; the field stays usable
 (/connect, /join, /msg) and its placeholder says why messages don't go */
- (NSView *)makeStateBar
{
	NSView *bar = [NSView new];

	bar.translatesAutoresizingMaskIntoConstraints = NO;

	bar.hidden = YES;

	NSTextField *label = [NSTextField labelWithString:@""];

	label.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	label.textColor = [NSColor secondaryLabelColor];
	label.lineBreakMode = NSLineBreakByTruncatingTail;

	[label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	/* The text takes the room up to the button */
	[label setContentHuggingPriority:(NSLayoutPriorityDefaultLow - 1) forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSButton *button = [NSButton buttonWithTitle:@"" target:self action:@selector(stateBarButtonClicked:)];

	button.controlSize = NSControlSizeSmall;
	button.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	NSStackView *stack = [NSStackView stackViewWithViews:@[label, button]];

	stack.translatesAutoresizingMaskIntoConstraints = NO;

	stack.spacing = 8;
	stack.edgeInsets = NSEdgeInsetsMake(0, 16, 0, 10);

	stack.distribution = NSStackViewDistributionFill;

	[bar addSubview:stack];

	NSLayoutConstraint *heightConstraint = [bar.heightAnchor constraintEqualToConstant:0];

	[NSLayoutConstraint activateConstraints:@[
		[stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
		[stack.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
		heightConstraint
	]];

	self.stateBar = bar;
	self.stateBarLabel = label;
	self.stateBarButton = button;
	self.stateBarHeightConstraint = heightConstraint;

	return bar;
}

/* With the title: on selection, connection, join and part changes */
- (void)updateStateBar
{
	IRCClient *client = self.selectedClient;

	IRCChannel *channel = self.selectedChannel;

	NSString *text = nil;
	NSString *buttonTitle = nil;
	NSString *placeholder = nil;

	if (client == nil) {
		;
	} else if (client.isLoggedIn == NO && (client.isConnecting || client.isConnected)) {
		text = TXTLS(@"TVCMainWindow[stb-n2]", client.name);
	} else if (client.isLoggedIn == NO) {
		text = TXTLS(@"TVCMainWindow[stb-n1]", client.name);

		buttonTitle = TXTLS(@"TVCMainWindow[stb-b1]");

		placeholder = TXTLS(@"TVCMainWindow[stb-p1]");
	} else if (channel.isChannel && channel.status == IRCChannelStatusParted) {
		text = TXTLS(@"TVCMainWindow[stb-j1]", channel.name);

		buttonTitle = TXTLS(@"TVCMainWindow[stb-b2]");

		placeholder = TXTLS(@"TVCMainWindow[stb-p2]", channel.name);
	}

	self.inputTextField.placeholderStatus = placeholder;

	/* Who's here shows once joined */
	[self.memberList setShowsNotJoinedHint:(channel.isChannel && (channel.status == IRCChannelStatusParted || client.isLoggedIn == NO))];

	NSView *bar = self.stateBar;

	if (bar == nil) {
		return;
	}

	self.stateBarLabel.stringValue = (text ?: @"");

	self.stateBarButton.title = (buttonTitle ?: @"");
	self.stateBarButton.hidden = (buttonTitle == nil);

	BOOL hidden = (text == nil);

	if (bar.hidden == hidden) {
		return;
	}

	bar.hidden = hidden;

	self.stateBarHeightConstraint.constant = ((hidden) ? 0 : 30);
}

- (void)stateBarButtonClicked:(id)sender
{
	IRCClient *client = self.selectedClient;

	IRCChannel *channel = self.selectedChannel;

	if (client == nil) {
		return;
	}

	if (client.isLoggedIn == NO) {
		[client connect];
	} else if (channel.isChannel && channel.status == IRCChannelStatusParted) {
		[client joinChannel:channel];
	}
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
