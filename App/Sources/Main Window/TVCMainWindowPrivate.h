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
@class TVCMainWindowTitlebarAccessoryViewLockButton;
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

- (BOOL)reloadLoadingScreen;

- (void)updateTitle;
- (void)updateTitleFor:(IRCTreeItem *)item;

- (void)reloadTree;
- (void)reloadTreeItem:(IRCTreeItem *)item;
- (void)reloadTreeGroup:(IRCTreeItem *)item;

- (void)adjustSelection;

- (void)maybeToggleFullscreenAfterLaunch;

- (void)updateAlphaValueToReflectPreferences;

- (void)updateChannelViewBoxContentViewSelection;
- (void)updateChannelViewArrangement;

- (void)redirectKeyDown:(NSEvent *)e;

- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command;

- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem;
- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem refreshChannelView:(BOOL)refreshChannelView;

- (void)shiftSelection:(nullable IRCTreeItem *)oldItem toItem:(nullable IRCTreeItem *)newItem options:(TVCMainWindowShiftSelectionFlags)selectionOptions;

- (void)channelViewSelectionChangeTo:(IRCTreeItem *)selectedItem;

- (void)updateDrawingForUserInUserList:(IRCUser *)user;
@end

NS_ASSUME_NONNULL_END
