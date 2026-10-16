/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "NSObjectHelperPrivate.h"
#import "NSStringHelper.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowAppearancePrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListCellPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCTextViewIRCFormattingMenuPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCTheme.h"
#import "TXGlobalModels.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "THOPluginDispatcherPrivate.h"
#import "TLOKeyEventHandler.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TVCInputCompletionPrivate.h"
#import "TVCMainWindowTextViewInternal.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

#define _replyBarHeight		24.0

/* More… for reactions: a field with the emoji picker open next to it */
@interface TVCReactionPickerController : NSViewController <NSTextFieldDelegate, NSPopoverDelegate>
@property (nonatomic, copy) NSString *msgid;
@property (nonatomic, weak) IRCChannel *channel;
@property (nonatomic, strong) NSTextField *field;
@property (nonatomic, strong, nullable) NSPopover *popover;
@end

static TVCReactionPickerController * _Nullable _reactionPicker = nil;

@implementation TVCReactionPickerController

- (void)loadView
{
	NSTextField *field = [NSTextField textFieldWithString:@""];

	field.placeholderString = TXTLS(@"TVCMainWindow[rct-p1]");

	field.accessibilityLabel = TXTLS(@"TVCMainWindow[rct-a1]");

	field.delegate = self;

	field.font = [NSFont systemFontOfSize:18];

	field.alignment = NSTextAlignmentCenter;

	field.translatesAutoresizingMaskIntoConstraints = NO;

	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 44)];

	[view addSubview:field];

	[NSLayoutConstraint activateConstraints:@[
		[field.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:10],
		[field.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-10],
		[field.centerYAnchor constraintEqualToAnchor:view.centerYAnchor]
	]];

	self.field = field;

	self.view = view;
}

- (void)sendReaction:(NSString *)reaction
{
	IRCChannel *channel = self.channel;

	if (channel) {
		[channel.associatedClient sendReaction:reaction toMessage:self.msgid inChannel:channel removing:NO];
	}

	[self close];
}

/* The picker inserts one emoji: that is the choice */
- (void)controlTextDidChange:(NSNotification *)notification
{
	NSString *text = self.field.stringValue;

	if (text.length == 0) {
		return;
	}

	NSRange first = [text rangeOfComposedCharacterSequenceAtIndex:0];

	if (first.length == text.length && [text canBeConvertedToEncoding:NSASCIIStringEncoding] == NO) {
		[self sendReaction:text];
	}
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
	if (commandSelector == @selector(insertNewline:)) {
		NSString *reaction = [IRCClient validatedReaction:self.field.stringValue];

		if (reaction) {
			[self sendReaction:reaction];
		} else {
			NSBeep();
		}

		return YES;
	}

	if (commandSelector == @selector(cancelOperation:)) {
		[self close];

		return YES;
	}

	return NO;
}

- (void)close
{
	[self.popover close];
}

- (void)popoverDidClose:(NSNotification *)notification
{
	if (_reactionPicker == self) {
		_reactionPicker = nil;
	}
}

@end

@implementation TVCMainWindow (Replies)

/* The bar sits between the chat view and the input field: what sat on
 the input field's top edge sits on the bar instead */
- (void)setUpReplyBar
{
	NSView *inputArea = self.inputTextField.contentView;

	NSView *windowContentView = inputArea.superview;

	if (inputArea == nil || windowContentView == nil || self.replyBar) {
		return;
	}

	NSView *bar = [NSView new];

	bar.translatesAutoresizingMaskIntoConstraints = NO;

	bar.hidden = YES;

	[windowContentView addSubview:bar];

	for (NSLayoutConstraint *constraint in [windowContentView.constraints copy]) {
		id otherItem = nil;

		if (constraint.firstItem == inputArea && constraint.firstAttribute == NSLayoutAttributeTop &&
			constraint.secondAttribute == NSLayoutAttributeBottom)
		{
			otherItem = constraint.secondItem;
		} else if (constraint.secondItem == inputArea && constraint.secondAttribute == NSLayoutAttributeTop &&
				   constraint.firstAttribute == NSLayoutAttributeBottom)
		{
			otherItem = constraint.firstItem;
		}

		if (otherItem == nil) {
			continue;
		}

		NSLayoutConstraint *replacement =
		[NSLayoutConstraint constraintWithItem:bar
									 attribute:NSLayoutAttributeTop
									 relatedBy:NSLayoutRelationEqual
										toItem:otherItem
									 attribute:NSLayoutAttributeBottom
									multiplier:1.0
									  constant:0.0];

		replacement.priority = constraint.priority;

		constraint.active = NO;

		replacement.active = YES;
	}

	NSLayoutConstraint *heightConstraint = [bar.heightAnchor constraintEqualToConstant:0];

	[NSLayoutConstraint activateConstraints:@[
		[bar.bottomAnchor constraintEqualToAnchor:inputArea.topAnchor],
		[bar.leadingAnchor constraintEqualToAnchor:windowContentView.leadingAnchor],
		[bar.trailingAnchor constraintEqualToAnchor:windowContentView.trailingAnchor],
		heightConstraint
	]];

	/* ↩ Replying to alice: the message…   ⓧ */
	NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"arrowshape.turn.up.left" accessibilityDescription:nil]];

	icon.contentTintColor = [NSColor secondaryLabelColor];

	NSTextField *label = [NSTextField labelWithString:@""];

	label.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	label.textColor = [NSColor secondaryLabelColor];
	label.lineBreakMode = NSLineBreakByTruncatingTail;

	[label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	/* The text takes the room between the arrow and the button */
	[label setContentHuggingPriority:(NSLayoutPriorityDefaultLow - 1) forOrientation:NSLayoutConstraintOrientationHorizontal];

	NSButton *cancelButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark.circle.fill" accessibilityDescription:TXTLS(@"TVCMainWindow[rpl-c1]")]
												target:self
												action:@selector(cancelReplyButtonClicked:)];

	cancelButton.bordered = NO;
	cancelButton.contentTintColor = [NSColor tertiaryLabelColor];
	cancelButton.toolTip = TXTLS(@"TVCMainWindow[rpl-c1]");

	NSStackView *stack = [NSStackView stackViewWithViews:@[icon, label, cancelButton]];

	stack.translatesAutoresizingMaskIntoConstraints = NO;

	stack.spacing = 6;
	stack.edgeInsets = NSEdgeInsetsMake(0, 12, 0, 10);

	stack.distribution = NSStackViewDistributionFill;

	[bar addSubview:stack];

	[NSLayoutConstraint activateConstraints:@[
		[stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
		[stack.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor]
	]];

	self.replyBar = bar;
	self.replyBarLabel = label;
	self.replyBarHeightConstraint = heightConstraint;
}

- (void)updateReplyBar
{
	NSDictionary<NSString *, NSString *> *reply = self.selectedChannel.pendingReply;

	BOOL hidden = (reply == nil);

	if (hidden == NO) {
		NSFont *font = self.replyBarLabel.font;

		NSFont *boldFont = [NSFont boldSystemFontOfSize:font.pointSize];

		NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:TXTLS(@"TVCMainWindow[rpl-l1]") attributes:@{NSFontAttributeName : font}];

		[text appendAttributedString:[[NSAttributedString alloc] initWithString:reply[@"nickname"] attributes:@{NSFontAttributeName : boldFont}]];

		NSString *excerpt = reply[@"excerpt"];

		if (excerpt.length > 0) {
			[text appendAttributedString:[[NSAttributedString alloc] initWithString:[@": " stringByAppendingString:excerpt] attributes:@{NSFontAttributeName : font}]];
		}

		[text addAttribute:NSForegroundColorAttributeName value:[NSColor secondaryLabelColor] range:NSMakeRange(0, text.length)];

		self.replyBarLabel.attributedStringValue = text;
	}

	if (self.replyBar.hidden == hidden) {
		return;
	}

	self.replyBar.hidden = hidden;

	self.replyBarHeightConstraint.constant = ((hidden) ? 0 : _replyBarHeight);
}

- (void)replyToMessage:(NSString *)msgid from:(NSString *)nickname excerpt:(NSString *)excerpt inChannel:(IRCChannel *)channel
{
	NSParameterAssert(msgid != nil);
	NSParameterAssert(nickname != nil);
	NSParameterAssert(excerpt != nil);
	NSParameterAssert(channel != nil);

	if (channel.associatedClient.canSendReplies == NO) {
		return;
	}

	channel.pendingReply = @{
		@"msgid" : msgid,
		@"nickname" : nickname,
		@"excerpt" : excerpt
	};

	if (channel != self.selectedChannel) {
		return;
	}

	[self updateReplyBar];

	[self.inputTextField focus];
}

- (BOOL)cancelPendingReply
{
	IRCChannel *channel = self.selectedChannel;

	if (channel.pendingReply == nil) {
		return NO;
	}

	channel.pendingReply = nil;

	[self updateReplyBar];

	return YES;
}

- (void)showReactionPickerForMessage:(NSString *)msgid inChannel:(IRCChannel *)channel
{
	NSParameterAssert(msgid != nil);
	NSParameterAssert(channel != nil);

	if (channel.associatedClient.canSendReactions == NO) {
		return;
	}

	[_reactionPicker close];

	TVCReactionPickerController *picker = [TVCReactionPickerController new];

	picker.msgid = msgid;
	picker.channel = channel;

	NSPopover *popover = [NSPopover new];

	popover.contentViewController = picker;
	popover.behavior = NSPopoverBehaviorApplicationDefined; // the emoji picker is another window
	popover.delegate = picker;

	picker.popover = popover;

	_reactionPicker = picker;

	/* Where the pointer is: over the message's actions */
	NSView *contentView = self.contentView;

	NSPoint location = [contentView convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];

	[popover showRelativeToRect:NSMakeRect(location.x, location.y, 1, 1) ofView:contentView preferredEdge:NSRectEdgeMinY];

	[popover.contentViewController.view.window makeFirstResponder:picker.field];

	dispatch_async(dispatch_get_main_queue(), ^{
		[NSApp orderFrontCharacterPalette:picker.field];
	});
}

- (void)cancelReplyButtonClicked:(id)sender
{
	[self cancelPendingReply];

	[self.inputTextField focus];
}

@end

NS_ASSUME_NONNULL_END
