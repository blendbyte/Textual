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

#import "TXMenuControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* Shared by TXMenuController.m and its category files (TXMenuController+*.m) only */

#define	_popWindowViewIfExists(c)	if ([windowController() maybeBringWindowForward:(c)]) {		\
										return;													\
									}

@interface TXMenuController () <NSMenuItemValidation>
@property (nonatomic, assign) BOOL menuIsOpen;
@property (nonatomic, assign) BOOL menuPerformedActionLastOpen;
@property (nonatomic, weak) IRCClient *pointedClient;
@property (nonatomic, weak) IRCChannel *pointedChannel;
@property (nonatomic, copy) NSString *currentSearchPhrase;
@property (readonly, nullable) TVCLogController *selectedViewController;
@property (readonly, nullable) TVCLogView *selectedViewControllerBackingView;
@property (readonly) TDCFileTransferDialog *fileTransferController;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *channelViewChannelNameMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *channelViewGeneralMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *channelViewURLMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *dockMenu;

@property (nonatomic, weak, readwrite) IBOutlet NSMenu *mainMenuNavigationChannelListMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenu *mainMenuChannelMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenu *mainMenuQueryMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuChannelMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuQueryMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuServerMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *mainMenuWindowMenuItem;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *mainWindowSegmentedControllerCellMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *serverListNoSelectionMenu;
@property (nonatomic, strong, readwrite) IBOutlet NSMenu *userControlMenu;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsDockMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsFileMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsSoundsDockMenuItem;
@property (nonatomic, weak, readwrite) IBOutlet NSMenuItem *muteNotificationsSoundsFileMenuItem;
@end

@interface TXMenuController (EditInternal)
- (NSString *)searchProviderName;
@end

@interface TXMenuController (ServerChannelInternal)
@end

@interface TXMenuController (MembersInternal)
@end

@interface TXMenuController (WindowInternal)
@end

@interface TXMenuController (AppInternal)
@end

@interface TXMenuController (SheetsInternal)
@end

NS_ASSUME_NONNULL_END
