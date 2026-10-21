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

#import "TVCMainWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Shared by TVCMainWindow.m and its category files (TVCMainWindow+*.m) only */

#define _treeDragItemType		TVCServerListDragType

#define _treeDragItemTypes		[NSArray arrayWithObject:_treeDragItemType]

#define _bouncerHeadingDragPrefix	@"bouncer-heading " // a bouncer's heading being dragged: this and its account's identifier

@class IRCBouncerAccount, IRCBouncerNetwork, TVCInputCompletionController, TVCMainWindowSearchPanel;

@interface TVCMainWindow ()
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowChannelView *channelView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryView *titlebarAccessoryView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryViewController *titlebarAccessoryViewController;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryViewLockButton *titlebarAccessoryViewLockButton;
@property (nonatomic, strong) TVCMainWindowTitlebarTitleField *titlebarTitleField;
@property (nonatomic, strong, nullable) NSView *titlebarBackgroundView; // the unified title bar's band
@property (nonatomic, strong, readwrite) IBOutlet TXMenuControllerMainWindowProxy *mainMenuProxy;
@property (nonatomic, strong, readwrite) IBOutlet TVCTextViewIRCFormattingMenu *formattingMenu;
@property (nonatomic, unsafe_unretained, readwrite) IBOutlet TVCMainWindowTextView *inputTextField;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowSplitView *contentSplitView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowLoadingScreenView *loadingScreen;
@property (nonatomic, weak, readwrite) IBOutlet TVCMemberList *memberList;
@property (nonatomic, weak, readwrite) IBOutlet TVCServerList *serverList;
@property (nonatomic, strong) TLOInputHistory *inputHistoryManager;
@property (nonatomic, strong) TVCInputCompletionController *inputCompletion;
@property (nonatomic, strong) TLONicknameCompletionStatus *nicknameCompletionStatus;
@property (nonatomic, strong, readwrite) TVCMainWindowAppearance *userInterfaceObjects;
@property (nonatomic, readwrite, copy) NSArray *selectedItems;
@property (nonatomic, readwrite, strong, nullable) IRCTreeItem *selectedItem;
@property (nonatomic, copy, nullable) NSArray *previousSelectedItemsId;
@property (nonatomic, copy, nullable) NSString *previousSelectedItemId;
@property (nonatomic, assign) NSTimeInterval lastKeyWindowStateChange;
@property (nonatomic, assign) BOOL lastKeyWindowRedrawFailedBecauseOfOcclusion;
@property (nonatomic, strong) TLOKeyEventHandler *keyEventHandler;
@property (nonatomic, copy, nullable) NSValue *cachedSwipeOriginPoint;
@property (nonatomic, assign, readwrite) double textSizeMultiplier;
@property (nonatomic, assign, readwrite) BOOL reloadingTheme;
@property (nonatomic, assign) BOOL inputDraftBeingRestored;
@property (nonatomic, assign) BOOL awakened; // set up once (-awakeFromNib comes again with nib reloads)
@property (nonatomic, strong, nullable) IRCTreeItem *popOutItem; // a pop-out's one item; nil for the main window
@property (nonatomic, copy, nullable) NSArray *popOutTopLevelObjects; // keeps a pop-out's nib objects alive
@property (nonatomic, assign) BOOL popOutClosingQuietly; // its item is going away, or Textual is quitting: not put back
@property (nonatomic, strong, nullable) NSView *replyBar; // "Replying to …" above the input field
@property (nonatomic, strong, nullable) NSTextField *replyBarLabel;
@property (nonatomic, strong, nullable) NSLayoutConstraint *replyBarHeightConstraint;
@property (nonatomic, strong, nullable) NSView *uploadBar; // "Uploading …" above the reply bar
@property (nonatomic, strong, nullable) NSTextField *uploadBarLabel;
@property (nonatomic, strong, nullable) NSProgressIndicator *uploadBarProgress;
@property (nonatomic, strong, nullable) NSLayoutConstraint *uploadBarHeightConstraint;
@property (nonatomic, strong, nullable) NSButton *uploadButton; // the paperclip beside the input field
@property (nonatomic, strong, nullable) NSLayoutConstraint *uploadButtonTrailingConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *uploadButtonBesideConstraint;
@property (nonatomic, strong, nullable) NSMutableArray *uploadQueue; // waiting, oldest first
@property (nonatomic, strong, nullable) IRCFileUpload *currentUpload;
@property (nonatomic, assign) NSUInteger uploadsDone; // of this round
@property (nonatomic, strong, nullable) TVCMainWindowSearchPanel *searchPanel; // in the member list's column
@property (nonatomic, weak) IBOutlet NSView *chatColumn; // the split view's middle column, holding the channel view
@property (nonatomic, strong, nullable) NSView *inputFieldStack; // the input field with the upload and reply bars above it
@property (nonatomic, strong, nullable) NSVisualEffectView *inputFieldBackgroundView; // behind the stack: the sidebars' material
@property (nonatomic, copy, nullable) NSArray<NSLayoutConstraint *> *inputFieldPlacementConstraints; // under the whole window or the chat
@property (nonatomic, strong, nullable) NSView *stateBar; // "Not connected to …" or "You're not in …" above the input field
@property (nonatomic, strong, nullable) NSTextField *stateBarLabel;
@property (nonatomic, strong, nullable) NSButton *stateBarButton;
@property (nonatomic, strong, nullable) NSLayoutConstraint *stateBarHeightConstraint;
@property (nonatomic, strong, nullable) NSView *bouncerBar; // "Your bouncer has 2 new networks: …" above the state bar
@property (nonatomic, strong, nullable) NSTextField *bouncerBarLabel;
@property (nonatomic, strong, nullable) NSButton *bouncerBarIgnoreButton; // Ignore, Keep, Not Now
@property (nonatomic, strong, nullable) NSButton *bouncerBarActionButton; // Add…, Remove from Textual, Link…
@property (nonatomic, strong, nullable) NSLayoutConstraint *bouncerBarHeightConstraint;
@property (nonatomic, strong, nullable) IRCBouncerAccount *bouncerBarAccount; // the bouncer it tells about
@property (nonatomic, copy, nullable) NSArray<IRCBouncerNetwork *> *bouncerBarAddedNetworks; // its new networks, or
@property (nonatomic, copy, nullable) NSArray<IRCClient *> *bouncerBarRemovedClients; // the servers of its removed ones
@property (nonatomic, copy, nullable) NSArray<IRCClient *> *bouncerBarLinkableClients; // or servers added by hand to offer linking
@property (nonatomic, copy, nullable) NSArray *serverListTopLevelItemsCache; // servers and bouncer headings, while there are headings
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, id> *serverListBouncerHeadings; // account identifier → its heading (the same object across reloads)
- (void)inputTextAsCommand:(IRCRemoteCommand)command;
- (void)inputTextAsCommand:(IRCRemoteCommand)command applyingMarkdown:(BOOL)applyMarkdown;
@end

@interface TVCMainWindow (ServerListInternal)
- (void)saveSelection;
- (void)setupTrees;
- (void)storeLastSelectedChannel;
- (void)storePreviousSelection;
@end

@interface TVCMainWindow (ChannelViewInternal)
- (void)restoreSavedContentSplitViewState;
- (void)saveContentSplitViewState;
- (void)selectionDidChangePostflight;
- (void)selectionDidChangeToRows:(NSIndexSet *)selectedRows;
- (void)selectionDidChangeToRows:(NSIndexSet *)selectedRows selectedItem:(nullable IRCTreeItem *)selectedItem;
@end

@interface TVCMainWindow (NavigationInternal)
@end

@interface TVCMainWindow (InputInternal)
- (void)registerKeyHandlers;

/* Pop-out windows */
+ (void)unregisterWindow:(TVCMainWindow *)window;
+ (BOOL)isLoadingPopOut;
- (void)awakeFromNibAsPopOut;
- (void)showPoppedOutItem:(IRCTreeItem *)item memberListHidden:(BOOL)memberListHidden;
- (void)stopShowingPoppedOutItem:(IRCTreeItem *)item;
+ (nullable TVCMainWindow *)popOutItem:(IRCTreeItem *)item frame:(nullable NSValue *)frameValue memberListHidden:(BOOL)memberListHidden makeKey:(BOOL)makeKey;
- (void)adjustSelectionWithItems:(NSArray<IRCTreeItem *> *)selectedItems selectedItem:(nullable IRCTreeItem *)selectedItem;
@end

@interface TVCMainWindow (InputPlacementInternal)
- (void)updateStateBar;
@end

@interface TVCMainWindow (TitleAndWindowInternal)
- (void)addAccessoryViewsToTitlebar;
- (void)licenseManagerActivatedLicense:(NSNotification *)notification;
- (void)licenseManagerDeactivatedLicense:(NSNotification *)notification;
- (void)licenseManagerTrialExpired:(NSNotification *)notification;
@end

NS_ASSUME_NONNULL_END
