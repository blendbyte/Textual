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

#import "TDCServerPropertiesSheetPrivate.h"
#import "TXMenuController.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCTreeItem;

@interface TXMenuController ()
@property (nonatomic, copy, nullable) NSString *pointedNickname; // Takes priority if sender of an action returns nil userInfo value

- (IBAction)emptyAction:(nullable id)sender TEXTUAL_DEPRECATED("Do not target this method");
@end

@interface TXMenuController (ServerChannelPrivate)
- (IBAction)joinChannelClicked:(nullable id)sender;
@end

@interface TXMenuController (MembersPrivate)
- (void)memberInChannelViewDoubleClicked:(nullable id)sender;
- (void)memberInMemberListDoubleClicked:(nullable id)sender;

- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files to:(NSString *)nickname;
- (void)memberSendDroppedFiles:(NSArray<NSString *> *)files row:(NSUInteger)row;
- (void)memberSendDroppedFilesToSelectedChannel:(NSArray<NSString *> *)files; // Only works if -selectedChannel is a private message
@end

@interface TXMenuController (WindowPrivate)
- (void)populateNavigationChannelList;

- (IBAction)performNavigationAction:(nullable id)sender;

- (void)navigateToTreeItemAtURL:(NSURL *)url;
- (void)navigateToTreeItemWithIdentifier:(NSString *)identifier;
- (void)navigateToTreeItem:(IRCTreeItem *)item;
@end

@interface TXMenuController (AppPrivate)
- (IBAction)openHelpMenuItem:(nullable id)sender;

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
- (void)manageLicense:(nullable id)sender activateLicenseKeyWithURL:(NSURL *)licenseKeyURL;

- (void)manageLicense:(nullable id)sender activateLicenseKey:(nullable NSString *)licenseKey;
- (void)manageLicense:(nullable id)sender activateLicenseKey:(nullable NSString *)licenseKey licenseKeyPassedByArgument:(BOOL)licenseKeyPassedByArgument;
#endif

- (void)toggleMuteOnNotificationsShortcutOn:(BOOL)toggleOn;
- (void)toggleMuteOnNotificationSoundsShortcutOn:(BOOL)toggleOn;
@end

@interface TXMenuController (SheetsPrivate)
- (void)memberChangeColor:(NSString *)nickname;

- (void)showServerPropertiesSheetForClient:(IRCClient *)client withSelection:(TDCServerPropertiesSheetSelection)selection context:(nullable id)context;
@end

@interface TXMenuControllerMainWindowProxy : NSObject
- (IBAction)showWelcomeSheet:(nullable id)sender;

- (IBAction)manageLicense:(nullable id)sender;

- (IBAction)openStandaloneStoreWebpage:(nullable id)sender;
@end

NS_ASSUME_NONNULL_END
