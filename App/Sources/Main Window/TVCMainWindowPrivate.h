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

#import "IRCCommandIndex.h"

#import "TVCMainWindow.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCUser;
@class TLOInputHistory;
@class TVCMainWindowChannelView;
@class TVCMainWindowTitlebarAccessoryView, TVCMainWindowTitlebarAccessoryViewController;
@class TVCMainWindowTitlebarAccessoryViewLockButton, TVCMainWindowTitlebarTitleField;
@class TVCTextViewIRCFormattingMenu;
@class TXMenuControllerMainWindowProxy;

typedef NS_OPTIONS(NSUInteger, TVCMainWindowShiftSelectionFlags) {
	TVCMainWindowShiftSelectionFlagMaintainGrouping			= 1 << 0,
	TVCMainWindowShiftSelectionFlagPerformDeselect			= 1 << 1, // deselect previous selection
	TVCMainWindowShiftSelectionFlagPerformDeselectChildren	= 1 << 2, // deselect previous selection + children (if group item)
//	TVCMainWindowShiftSelectionFlagPerformDeselectAll		= 1 << 2  // deselect all
};

typedef NS_OPTIONS(NSUInteger, TVCMainWindowMouseLocation) {
	TVCMainWindowMouseLocationOutsideWindow					= 0,
	TVCMainWindowMouseLocationInsideWindow					= 1 << 1,
	TVCMainWindowMouseLocationInsideWindowTitle				= 1 << 2,
	TVCMainWindowMouseLocationOnTopOfWindowTitleControl		= 1 << 3
};

@interface TVCMainWindow ()
@property (nonatomic, strong, nullable) NSTimer *typingIndicatorSweepTimer; // while someone is shown typing
@property (nonatomic, assign) BOOL ignoreOutlineViewSelectionChanges;
@property (nonatomic, assign) BOOL ignoreNextOutlineViewSelectionChange;

- (TLOInputHistory *)inputHistoryManager;
- (TVCMainWindowChannelView *)channelView;
- (TVCMainWindowTitlebarAccessoryView *)titlebarAccessoryView;
- (nullable TVCMainWindowTitlebarAccessoryViewController *)titlebarAccessoryViewController;
- (TVCMainWindowTitlebarAccessoryViewLockButton *)titlebarAccessoryViewLockButton;
- (TVCTextViewIRCFormattingMenu *)formattingMenu;
- (TXMenuControllerMainWindowProxy *)mainMenuProxy;

- (TVCMainWindowMouseLocation)locationOfMouseInWindow;
- (TVCMainWindowMouseLocation)locationOfMouse:(NSPoint)mouseLocation;

- (BOOL)reloadingTheme;

- (void)maybeToggleFullscreenAfterLaunch;

- (void)updateAlphaValueToReflectPreferences;

- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command;

/* Once, the scrollback into the message archive (10.9 B; again when it was
 turned off and on), and the scrollback of items that no longer exist out */
- (void)maintainHistoricLog;
@end

/* Windows (7.13): the main window and windows showing one channel (10.18).
 Code that used to ask the main window asks these instead; with one window
 every answer is the main window's. */
@interface TVCMainWindow (Windows)
@property (class, readonly, copy) NSArray<TVCMainWindow *> *windows; // the main window first

/* The window the user is in, or was in last (Preferences in front); else the main window */
@property (class, readonly) TVCMainWindow *currentWindow;

/* The key window, if it's one of these */
@property (class, readonly, nullable) TVCMainWindow *focusedWindow;

/* Windows where the item is selected, or among several selected */
+ (NSArray<TVCMainWindow *> *)windowsShowingItem:(IRCTreeItem *)item;

/* The window where the item is selected (one place at a time), or nil */
+ (nullable TVCMainWindow *)windowWithSelectedItem:(IRCTreeItem *)item;

/* Selected in the key window: the user is looking at it */
+ (BOOL)isUserLookingAtItem:(IRCTreeItem *)item;

/* Every window is updated (each ignores what it doesn't show) */
+ (void)updateTitleFor:(IRCTreeItem *)item;
+ (void)updateDrawingForUserInUserList:(IRCUser *)user;
+ (void)updateTypingIndicatorForChannel:(IRCChannel *)channel;
+ (void)updateUploadButton;
+ (void)updateAlphaValueToReflectPreferences;
+ (void)updateChannelViewArrangement;
+ (void)inputHistoryScopeDidChange;
+ (void)destroyInputHistoryOf:(IRCTreeItem *)item; // the channel or server is gone
@end

/* Pop-out windows (10.18): a channel, private message or server console in a
 window of its own (this class from the same nib, its server list hidden).
 It is shown in one place at a time: selecting it in the main window brings
 its window forward. Closing the window puts it back in the main window. */
@interface TVCMainWindow (PopOut)
@property (readonly) BOOL isPopOut;

+ (nullable TVCMainWindow *)popOutWindowForItem:(IRCTreeItem *)item;

+ (void)popOutItem:(IRCTreeItem *)item; // or brings its window forward
+ (void)popOutItem:(IRCTreeItem *)item atScreenPoint:(NSPoint)point; // dragged out of the server list

/* The item (and, for a server, its channels) is going away */
+ (void)closePopOutsForItem:(IRCTreeItem *)item;

+ (void)restorePopOuts; // at launch, once the servers are there
+ (void)savePopOuts; // which, where, member list shown; for the next launch
+ (void)closePopOutsForTermination; // their places are kept for the next launch
@end

@interface TVCMainWindow (ServerListPrivate)
- (void)reloadTree;
- (void)reloadTreeItem:(IRCTreeItem *)item;

- (void)adjustSelection;

- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem;
- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem refreshChannelView:(BOOL)refreshChannelView;

- (void)shiftSelection:(nullable IRCTreeItem *)oldItem toItem:(nullable IRCTreeItem *)newItem options:(TVCMainWindowShiftSelectionFlags)selectionOptions;
@end

@interface TVCMainWindow (ChannelViewPrivate)
- (void)updateChannelViewBoxContentViewSelection;
- (void)updateChannelViewArrangement;

- (void)channelViewSelectionChangeTo:(IRCTreeItem *)selectedItem;

- (void)updateDrawingForUserInUserList:(IRCUser *)user;

/* Typing notifications */
- (void)updateTypingIndicatorForChannel:(IRCChannel *)channel;
- (void)inputTextDidChange;

/* The insertion point moved: the suggestion list follows */
- (void)inputSelectionDidChange;

/* Puts a channel's draft into the input field (10.11) without it counting as
 typing: the other side is told only once you edit it */
- (void)restoreInputDraft:(nullable NSAttributedString *)draft;
@end

@interface TVCMainWindow (InputPrivate)
- (void)redirectKeyDown:(NSEvent *)e;
@end

/* File uploads (9.18): one after another, each link put in its channel's input field */
@interface TVCMainWindow (UploadsPrivate)
- (void)setUpUploads;
- (void)updateUploadButton; // shown while the selected server offers uploads

- (void)uploadFiles:(NSArray<NSString *> *)paths onClient:(IRCClient *)client toItem:(IRCTreeItem *)item;
- (void)sendText:(NSString *)text asLinkOnClient:(IRCClient *)client toItem:(IRCTreeItem *)item asCommand:(IRCRemoteCommand)command; // a long paste (9.18 D)

- (void)chooseFilesToUpload:(nullable id)sender;

/* No upload address applies here: says why and offers to set one up */
- (void)offerUploadSetupForClient:(IRCClient *)client;
- (void)editUploadDestinationForClient:(IRCClient *)client; // the server's own, or the one in Preferences
@end

/* Replies (9.15): the message being answered is kept per channel and shown
 above the input field until the next message is sent or it is cancelled */
@interface TVCMainWindow (RepliesPrivate)
- (void)setUpReplyBar;
- (void)updateReplyBar;

- (void)replyToMessage:(NSString *)msgid from:(NSString *)nickname excerpt:(NSString *)excerpt inChannel:(IRCChannel *)channel;
- (BOOL)cancelPendingReply; // NO when there was none

/* Reactions (9.15 B): a small field near the pointer with the macOS emoji
 picker open; what is chosen (or typed and Return) is sent as the reaction */
- (void)showReactionPickerForMessage:(NSString *)msgid inChannel:(IRCChannel *)channel;

/* Deleting (9.15 C): asks first, as it can't be undone */
- (void)confirmDeletingMessage:(NSString *)msgid inChannel:(IRCChannel *)channel;

/* Keyboard focus on messages (9.15 D): ⌥↑ from the input field */
- (void)leaveMessageFocusInViewController:(nullable TVCLogController *)viewController;
- (BOOL)handleMessageFocusKey:(NSEvent *)e;
@end

@interface TVCMainWindow (TitleAndWindowPrivate)
/* The sidebars carry on up into a transparent title bar (10.1) */
- (void)setUpUnifiedTitlebar;

/* Translucent or opaque, as Settings → Appearance says */
+ (void)applySidebarTranslucencyToView:(nullable NSVisualEffectView *)view;

- (BOOL)reloadLoadingScreen;

- (void)updateTitle;
- (void)updateTitleFor:(IRCTreeItem *)item;
@end

NS_ASSUME_NONNULL_END
