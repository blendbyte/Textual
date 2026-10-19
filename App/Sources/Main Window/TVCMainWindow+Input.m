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
#import "TVCMainWindowSearchPanelPrivate.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindow (Input)

#pragma mark -
#pragma mark Keyboard Shortcuts

- (void)setKeyHandlerTarget:(id)target
{
	[self.keyEventHandler setKeyHandlerTarget:target];
}

- (void)registerSelector:(SEL)selector key:(NSUInteger)keyCode modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector key:keyCode modifiers:modifiers];
}

- (void)registerSelector:(SEL)selector character:(UniChar)character modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector character:character modifiers:modifiers];
}

- (void)registerInputSelector:(SEL)selector key:(NSUInteger)keyCode modifiers:(NSUInteger)modifiers
{
	[self.inputTextField registerSelector:selector key:keyCode modifiers:modifiers];
}

- (void)registerInputSelector:(SEL)selector character:(UniChar)character modifiers:(NSUInteger)modifiers
{
	[self.inputTextField registerSelector:selector character:character modifiers:modifiers];
}

- (BOOL)performedCustomKeyboardEvent:(NSEvent *)e
{
	NSResponder *firstResponder = self.firstResponder;

	/* The search panel's field and list take their keys as they are:
	 the shortcuts here are the input field's and the chat's */
	if (self.isSearchPanelVisible) {
		id responder = firstResponder;

		if ([responder isKindOfClass:[NSTextView class]] && [responder isFieldEditor]) {
			responder = [(NSTextView *)responder delegate];
		}

		if ([responder isKindOfClass:[NSView class]] && [responder isDescendantOf:self.searchPanel.view]) {
			return NO;
		}
	}

	/* Keyboard focus on messages takes its keys first */
	if ([self handleMessageFocusKey:e]) {
		return YES;
	}

	/* The suggestion list takes ↑ ↓ Tab Return Esc while it is open */
	if (firstResponder == self.inputTextField && [self.inputCompletion handleKeyEvent:e]) {
		return YES;
	}

	/* With Full Keyboard Access, Tab outside the input field moves the focus */
	if (e.keyCode == TXKeyTabCode &&
		(e.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) == 0 &&
		NSApp.fullKeyboardAccessEnabled &&
		firstResponder != self.inputTextField)
	{
		return NO;
	}

	if ([self.keyEventHandler processKeyEvent:e]) {
		return YES;
	}

	return NO;
}

- (void)redirectKeyDown:(NSEvent *)e
{
	/* With Full Keyboard Access, Tab moves the focus instead of being typed */
	if (e.keyCode == TXKeyTabCode && NSApp.fullKeyboardAccessEnabled) {
		if ((e.modifierFlags & NSEventModifierFlagShift) == NSEventModifierFlagShift) {
			[self selectPreviousKeyView:nil];
		} else {
			[self selectNextKeyView:nil];
		}

		return;
	}

	[self.inputTextField focus];

	if (e.keyCode == TXKeyEnterCode ||
		e.keyCode == TXKeyReturnCode)
	{
		return;
	}

	[self.inputTextField keyDown:e];
}

- (void)memberListKeyDown:(NSEvent *)e
{
	[self redirectKeyDown:e];
}

- (void)serverListKeyDown:(NSEvent *)e
{
	[self redirectKeyDown:e];
}

- (void)registerKeyHandlers
{
	[self.inputTextField setKeyHandlerTarget:self];

	/* Window keyboard shortcuts */
	[self registerSelector:@selector(exitFullscreenMode:) key:TXKeyEscapeCode modifiers:0];

	[self registerSelector:@selector(tab:) key:TXKeyTabCode modifiers:0];
	[self registerSelector:@selector(shiftTab:)	key:TXKeyTabCode modifiers:NSEventModifierFlagShift];

	[self registerSelector:@selector(selectPreviousSelection:) key:TXKeyTabCode modifiers:NSEventModifierFlagOption];

	[self registerSelector:@selector(textFormattingBold:) character:'b' modifiers:NSEventModifierFlagCommand];
	[self registerSelector:@selector(textFormattingUnderline:) character:'u' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];
	[self registerSelector:@selector(textFormattingItalic:)	character:'i' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];
	[self registerSelector:@selector(textFormattingForegroundColor:) character:'c' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];
	[self registerSelector:@selector(textFormattingBackgroundColor:) character:'h' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];

	[self registerSelector:@selector(speakPendingNotifications:) character:'.' modifiers:NSEventModifierFlagCommand];

	[self registerSelector:@selector(inputHistoryUp:) character:'p' modifiers:NSEventModifierFlagControl];
	[self registerSelector:@selector(inputHistoryDown:)	character:'n' modifiers:NSEventModifierFlagControl];

	/* Text field keyboard shortcuts */
	[self registerInputSelector:@selector(sendControlEnterMessageMaybe:) key:TXKeyEnterCode modifiers:NSEventModifierFlagControl];

	[self registerInputSelector:@selector(sendMessageAsTyped:) key:TXKeyReturnCode modifiers:(NSEventModifierFlagOption | NSEventModifierFlagShift)];
	[self registerInputSelector:@selector(sendMessageAsTyped:) key:TXKeyEnterCode modifiers:(NSEventModifierFlagOption | NSEventModifierFlagShift)];

	[self registerInputSelector:@selector(sendMessageAsAction:) key:TXKeyReturnCode modifiers:NSEventModifierFlagCommand];
	[self registerInputSelector:@selector(sendMessageAsAction:) key:TXKeyEnterCode modifiers:NSEventModifierFlagCommand];

	[self registerInputSelector:@selector(focusWebview:) character:'l' modifiers:(NSEventModifierFlagOption | NSEventModifierFlagCommand)];

	[self registerInputSelector:@selector(inputHistoryUpWithScrollCheck:) key:TXKeyUpArrowCode modifiers:0];
	/* ⌥↑: into the messages (↑ and ⌃P still go back through what was typed) */
	[self registerInputSelector:@selector(focusMessages:) key:TXKeyUpArrowCode modifiers:NSEventModifierFlagOption];

	[self registerInputSelector:@selector(inputHistoryDownWithScrollCheck:) key:TXKeyDownArrowCode modifiers:0];
	[self registerInputSelector:@selector(inputHistoryDownWithScrollCheck:) key:TXKeyDownArrowCode modifiers:NSEventModifierFlagOption];
}

#pragma mark -
#pragma mark Actions

- (void)completeNickname:(BOOL)movingForward
{
	[self.nicknameCompletionStatus completeNickname:movingForward];
}

- (void)tab:(NSEvent *)e
{
	TXTabKeyAction tabKeyAction = [TPCPreferences tabKeyAction];

	if (tabKeyAction == TXTabKeyActionNicknameComplete) {
		[self completeNickname:YES];
	} else if (tabKeyAction == TXTabKeyActionUnreadChannel) {
		[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeUnread];
	}
}

- (void)shiftTab:(NSEvent *)e
{
	TXTabKeyAction tabKeyAction = [TPCPreferences tabKeyAction];

	if (tabKeyAction == TXTabKeyActionNicknameComplete) {
		[self completeNickname:NO];
	} else if (tabKeyAction == TXTabKeyActionUnreadChannel) {
		[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeUnread];
	}
}

- (void)sendControlEnterMessageMaybe:(NSEvent *)e
{
	if ([TPCPreferences controlEnterSendsMessage]) {
		[self textEntered];

		return;
	}

	[self.inputTextField keyDownToSuper:e];
}

/* ⌥⇧↩: this message without Markdown */
- (void)sendMessageAsTyped:(NSEvent *)e
{
	[self inputTextAsCommand:IRCRemoteCommandPrivmsg applyingMarkdown:NO];
}

- (void)sendMessageAsAction:(NSEvent *)e
{
	if ([TPCPreferences commandReturnSendsMessageAsAction]) {
		[self inputTextAsCommand:IRCRemoteCommandPrivmsgAction];

		return;
	}

	[self textEntered];
}

- (void)moveInputHistory:(BOOL)movingUp checkScroller:(BOOL)checkScroller event:(NSEvent *)event
{
	if (checkScroller) {
		TVCTextViewCaretLocation caretLocation = self.inputTextField.caretLocation;

		if (caretLocation != TVCTextViewCaretLocationOnlyLine) {
			BOOL atTop = (caretLocation == TVCTextViewCaretLocationFirstLine);
			BOOL atBottom = (caretLocation == TVCTextViewCaretLocationLastLine);

			if ((atTop			&& event.keyCode == TXKeyDownArrowCode) ||
				(atBottom		&& event.keyCode == TXKeyUpArrowCode) ||
				(atTop == NO	&& atBottom == NO))
			{
				[self.inputTextField keyDownToSuper:event];

				return;
			}
		}
	}

	NSAttributedString *stringValue = self.inputTextField.attributedStringValue;

	if (movingUp) {
		stringValue = [self.inputHistoryManager up:stringValue];
	} else {
		stringValue = [self.inputHistoryManager down:stringValue];
	}

	if (stringValue == nil) {
		return;
	}

	self.inputTextField.attributedStringValue = stringValue;

	[self.inputTextField focus];

	if (movingUp == NO) {
		self.inputTextField.selectedRange = NSMakeRange(0, 0);
	}
}

- (void)inputHistoryUp:(NSEvent *)e
{
	[self moveInputHistory:YES checkScroller:NO event:e];
}

- (void)inputHistoryDown:(NSEvent *)e
{
	[self moveInputHistory:NO checkScroller:NO event:e];
}

- (void)inputHistoryUpWithScrollCheck:(NSEvent *)e
{
	[self moveInputHistory:YES checkScroller:YES event:e];
}

- (void)inputHistoryDownWithScrollCheck:(NSEvent *)e
{
	[self moveInputHistory:NO checkScroller:YES event:e];
}

- (void)textFormattingBold:(NSEvent *)e
{
	[self.formattingMenu toggleEffect:IRCTextFormatterEffectBold];
}

- (void)textFormattingItalic:(NSEvent *)e
{
	[self.formattingMenu toggleEffect:IRCTextFormatterEffectItalic];
}

- (void)textFormattingStrikethrough:(NSEvent *)e
{
	[self.formattingMenu toggleEffect:IRCTextFormatterEffectStrikethrough];
}

- (void)textFormattingUnderline:(NSEvent *)e
{
	[self.formattingMenu toggleEffect:IRCTextFormatterEffectUnderline];
}

- (void)textFormattingForegroundColor:(NSEvent *)e
{
	if (self.formattingMenu.textHasSpoiler) {
		return;
	}

	if (self.formattingMenu.textHasForegroundColor) {
		[self.formattingMenu removeForegroundColorCharFromTextBox:nil];

		return;
	}

	[self popUpTextFormattingColorMenu:self.formattingMenu.foregroundColorMenu];
}

- (void)textFormattingBackgroundColor:(NSEvent *)e
{
	if (self.formattingMenu.textHasSpoiler) {
		return;
	}

	if (self.formattingMenu.textHasForegroundColor == NO) {
		return;
	}

	if (self.formattingMenu.textHasBackgroundColor) {
		[self.formattingMenu removeBackgroundColorCharFromTextBox:nil];

		return;
	}

	[self popUpTextFormattingColorMenu:self.formattingMenu.backgroundColorMenu];
}

- (void)popUpTextFormattingColorMenu:(NSMenu *)menu
{
	NSParameterAssert(menu != nil);

	NSRect textFieldFrame = self.inputTextField.frame;

	textFieldFrame.origin.y -= 200;
	textFieldFrame.origin.x += 100;

	[menu popUpMenuPositioningItem:nil atLocation:textFieldFrame.origin inView:self.inputTextField];
}

- (void)exitFullscreenMode:(NSEvent *)e // escape key
{
	if (self.inFullscreenMode) {
		[self toggleFullScreen:nil];

		return;
	}

	/* Escape stops replying first */
	if ([self cancelPendingReply]) {
		return;
	}

	[self.inputTextField keyDown:e];
}

- (void)speakPendingNotifications:(NSEvent *)e
{
	[[TXSharedApplication sharedSpeechSynthesizer] stopSpeakingAndMoveForward];
}

- (void)focusMessages:(NSEvent *)e
{
	if (self.attachedSheet != nil) {
		return;
	}

	TVCLogController *viewController = self.selectedViewController;

	NSView *webView = viewController.backingView.webView;

	if (webView == nil) {
		return;
	}

	[self.inputCompletion close];

	[self makeFirstResponder:webView];

	viewController.messageFocusActive = YES;

	[viewController evaluateFunction:@"_MessageActions.focusMessages" withArguments:nil];
}

- (void)leaveMessageFocusInViewController:(nullable TVCLogController *)viewController
{
	if (viewController == nil || viewController.messageFocusActive == NO) {
		return;
	}

	viewController.messageFocusActive = NO;

	[viewController evaluateFunction:@"_MessageActions.blurMessages" withArguments:nil];

	if (viewController == self.selectedViewController) {
		[self.inputTextField focus];
	}
}

/* ↑ ↓ ← → Return Escape Delete R E go to the focused messages; any other
 key leaves them and is typed into the input field */
- (BOOL)handleMessageFocusKey:(NSEvent *)e
{
	if (e.type != NSEventTypeKeyDown) {
		return NO;
	}

	TVCLogController *viewController = self.selectedViewController;

	if (viewController.messageFocusActive == NO) {
		return NO;
	}

	NSView *webView = viewController.backingView.webView;

	NSResponder *firstResponder = self.firstResponder;

	BOOL inWebView = (webView && [firstResponder isKindOfClass:[NSView class]] && [(NSView *)firstResponder isDescendantOf:webView]);

	/* Somewhere else now (a click, another window): no longer focused */
	if (inWebView == NO) {
		viewController.messageFocusActive = NO;

		[viewController evaluateFunction:@"_MessageActions.blurMessages" withArguments:nil];

		return NO;
	}

	NSEventModifierFlags modifiers = (e.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption));

	if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) != 0) {
		return NO; // menu shortcuts
	}

	NSString *command = nil;

	switch (e.keyCode) {
		case TXKeyUpArrowCode:
			command = @"up";
			break;
		case TXKeyDownArrowCode:
			command = @"down";
			break;
		case TXKeyLeftArrowCode:
			command = @"left";
			break;
		case TXKeyRightArrowCode:
			command = @"right";
			break;
		case TXKeyReturnCode:
		case TXKeyEnterCode:
			command = @"return";
			break;
		case TXKeyEscapeCode:
			command = @"escape";
			break;
		case TXKeyBackspaceCode:
		case TXKeyDeleteCode:
			command = @"delete";
			break;
		default:
		{
			NSString *character = e.charactersIgnoringModifiers.lowercaseString;

			if ([character isEqualToString:@"r"]) {
				command = @"reply";
			} else if ([character isEqualToString:@"e"]) {
				command = @"react";
			}

			break;
		}
	}

	if (command) {
		[viewController evaluateFunction:@"_MessageActions.keyboardCommand" withArguments:@[command]];

		return YES;
	}

	/* Typing: back to the input field with the key */
	if (modifiers == 0) {
		[self leaveMessageFocusInViewController:viewController];

		[self redirectKeyDown:e];

		return YES;
	}

	return NO;
}

- (void)focusWebview:(NSEvent *)e
{
	if (self.attachedSheet != nil) {
		return;
	}

	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	NSView *webView = viewController.backingView.webView;

	[self makeFirstResponder:webView];
}

@end

NS_ASSUME_NONNULL_END
