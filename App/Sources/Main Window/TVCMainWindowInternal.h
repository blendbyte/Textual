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

@interface TVCMainWindow ()
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowChannelView *channelView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryView *titlebarAccessoryView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryViewController *titlebarAccessoryViewController;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryViewLockButton *titlebarAccessoryViewLockButton;
@property (nonatomic, strong) TVCMainWindowTitlebarTitleField *titlebarTitleField;
@property (nonatomic, strong, readwrite) IBOutlet TXMenuControllerMainWindowProxy *mainMenuProxy;
@property (nonatomic, strong, readwrite) IBOutlet TVCTextViewIRCFormattingMenu *formattingMenu;
@property (nonatomic, unsafe_unretained, readwrite) IBOutlet TVCMainWindowTextView *inputTextField;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowSplitView *contentSplitView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowLoadingScreenView *loadingScreen;
@property (nonatomic, weak, readwrite) IBOutlet TVCMemberList *memberList;
@property (nonatomic, weak, readwrite) IBOutlet TVCServerList *serverList;
@property (nonatomic, strong) TLOInputHistory *inputHistoryManager;
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
- (void)inputTextAsCommand:(IRCRemoteCommand)command;
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
@end

@interface TVCMainWindow (TitleAndWindowInternal)
- (void)addAccessoryViewsToTitlebar;
- (void)licenseManagerActivatedLicense:(NSNotification *)notification;
- (void)licenseManagerDeactivatedLicense:(NSNotification *)notification;
- (void)licenseManagerTrialExpired:(NSNotification *)notification;
@end

NS_ASSUME_NONNULL_END
