/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "TVCMainWindowAppearance.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCChannel, IRCTreeItem;
@class TVCMainWindowLoadingScreenView;
@class TVCMainWindowSplitView, TVCMainWindowTextView;
@class TVCServerList, TVCMemberList;
@class TVCLogController;

typedef NS_ENUM(NSUInteger, TVCServerListNavigationMovementType) {
	TVCServerListNavigationMovementTypeAll = 0,	// Move to next item
	TVCServerListNavigationMovementTypeActive,  // Move to next active item
	TVCServerListNavigationMovementTypeUnread,  // Move to next unread item
};

typedef NS_ENUM(NSUInteger, TVCServerListNavigationSelectionType) {
	TVCServerListNavigationSelectionTypeAny = 0,	// Move to next item
	TVCServerListNavigationSelectionTypeChannel,	// Move to next channel item
	TVCServerListNavigationSelectionTypeServer,		// Move to next server item
};

TEXTUAL_EXTERN NSNotificationName const TVCMainWindowAppearanceChangedNotification;
TEXTUAL_EXTERN NSNotificationName const TVCMainWindowRedrawSubviewsNotification;

TEXTUAL_EXTERN NSNotificationName const TVCMainWindowWillReloadThemeNotification;
TEXTUAL_EXTERN NSNotificationName const TVCMainWindowDidReloadThemeNotification;

TEXTUAL_EXTERN NSNotificationName const TVCMainWindowSelectionChangedNotification;

TEXTUAL_EXTERN NSString * const TVCServerListDragType;

@interface TVCMainWindow : NSWindow
@property (readonly, getter=isDisabled) BOOL disabled;

@property (readonly) TVCMainWindowAppearance *userInterfaceObjects;

@property (readonly, weak) TVCMainWindowLoadingScreenView *loadingScreen;
@property (readonly, weak) TVCMainWindowSplitView *contentSplitView;
@property (readonly, unsafe_unretained) TVCMainWindowTextView *inputTextField;
@property (readonly, weak) TVCMemberList *memberList;
@property (readonly, weak) TVCServerList *serverList;

@property (readonly) BOOL multipleItemsSelected;
@property (readonly, nullable) IRCTreeItem *selectedItem;
@property (readonly, copy) NSArray<IRCTreeItem *> *selectedItems;
@property (readonly, nullable) IRCClient *selectedClient;
@property (readonly, nullable) IRCChannel *selectedChannel;
@property (readonly, nullable) TVCLogController *selectedViewController;

@property (readonly, nullable) IRCTreeItem *previouslySelectedItem;

- (void)select:(nullable IRCTreeItem *)item;
- (void)selectPreviousItem;
- (void)deselect:(IRCTreeItem *)item;
- (void)deselectGroup:(IRCTreeItem *)item;

- (BOOL)isItemVisible:(IRCTreeItem *)item;
- (BOOL)isItemSelected:(IRCTreeItem *)item;
- (BOOL)isItemInSelectedGroup:(IRCTreeItem *)item;

- (void)expandClient:(IRCClient *)client;

- (nullable IRCChannel *)selectedChannelOn:(IRCClient *)client;

- (void)navigateServerEntries:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType;
- (void)navigateChannelEntries:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType;
- (void)navigateToNextEntry:(BOOL)isMovingDown;

- (void)selectNextServer:(NSEvent *)e;
- (void)selectNextChannel:(NSEvent *)e;
- (void)selectNextWindow:(NSEvent *)e;
- (void)selectPreviousServer:(NSEvent *)e;
- (void)selectPreviousChannel:(NSEvent *)e;
- (void)selectPreviousWindow:(NSEvent *)e;
- (void)selectNextActiveServer:(NSEvent *)e;
- (void)selectNextUnreadChannel:(NSEvent *)e;
- (void)selectNextActiveChannel:(NSEvent *)e;
- (void)selectPreviousSelection:(NSEvent *)e;
- (void)selectPreviousActiveServer:(NSEvent *)e;
- (void)selectPreviousUnreadChannel:(NSEvent *)e;
- (void)selectPreviousActiveChannel:(NSEvent *)e;

@property (getter=isUsingDarkAppearance, readonly) BOOL usingDarkAppearance;

@property (readonly) double textSizeMultiplier;

- (void)changeTextSize:(BOOL)bigger;

- (void)markAllAsRead;
- (void)markAllAsReadInGroup:(nullable IRCTreeItem *)item;

- (void)reloadTheme; // reloaded asynchronously

- (void)clearContentsOfClient:(IRCClient *)client;
- (void)clearContentsOfChannel:(IRCChannel *)channel;

- (void)clearAllViews;

- (void)textEntered;

@property (getter=isMemberListVisible, readonly) BOOL memberListVisible;
@property (getter=isServerListVisible, readonly) BOOL serverListVisible;

- (NSRect)defaultWindowFrame;
@end

NS_ASSUME_NONNULL_END
