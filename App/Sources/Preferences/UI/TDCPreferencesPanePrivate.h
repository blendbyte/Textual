/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

NS_ASSUME_NONNULL_BEGIN

/* One section of the Preferences window, from the nib of the same name
 (TDCPreferencesGeneralPane → TDCPreferencesGeneral.xib), loaded the first
 time it is shown. A view controller, not an NSObject, as the nib's owner:
 bindings to it then don't retain it, so it goes away with the window.
 Sections whose controls are only bound to preferences use this class with
 their own nib. */
@interface TDCPreferencesPane : NSViewController
- (instancetype)initWithNibName:(NSString *)nibName NS_DESIGNATED_INITIALIZER;
- (instancetype)init; // the nib named after the class

- (instancetype)initWithNibName:(nullable NSNibName)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/* The window is closing (only for a section that was shown) */
- (void)paneWillClose;

/* Shared by several sections: redraws the chat views */
- (IBAction)onChangedTheme:(nullable id)sender;

/* A style is reloading (bound in nibs to disable controls meanwhile) */
@property (readonly) BOOL reloadingTheme;

/* For subclasses (call super) */
- (void)themeWillReload:(NSNotification *)notification;
- (void)themeDidReload:(NSNotification *)notification;

/* The colour panel keeps sending changes to an active colour well */
- (void)deactivateColorWells;

/* A folder pop-up button: item 0 shows the folder (or the placeholder), the
 item tagged 2 chooses another, the one tagged 3 resets it */
- (void)showFolder:(nullable NSURL *)folderURL inPopUpButton:(NSPopUpButton *)popUpButton placeholder:(NSString *)placeholder;

/* For the pop-up button's action: the block gets the chosen folder's bookmark,
 or nil to reset; it isn't called when the open panel is cancelled */
- (void)chooseFolderFromPopUpButton:(NSPopUpButton *)popUpButton completionBlock:(void (^)(NSData * _Nullable bookmark))completionBlock;
@end

@interface TDCPreferencesGeneralPane : TDCPreferencesPane
@end

@interface TDCPreferencesControlsPane : TDCPreferencesPane
@end

@interface TDCPreferencesCommandScopePane : TDCPreferencesPane
@end

@interface TDCPreferencesHighlightsPane : TDCPreferencesPane <NSTableViewDelegate>
@end

@interface TDCPreferencesNotificationsPane : TDCPreferencesPane
@end

@interface TDCPreferencesInterfacePane : TDCPreferencesPane
@end

@interface TDCPreferencesStylePane : TDCPreferencesPane
@end

@interface TDCPreferencesFileTransfersPane : TDCPreferencesPane
@end

@interface TDCPreferencesInlineMediaPane : TDCPreferencesPane
@end

/* The message archive and text logs (10.9 F) */
@interface TDCPreferencesHistoryPane : TDCPreferencesPane
@end

@interface TDCPreferencesInstalledAddonsPane : TDCPreferencesPane
@end

@interface TDCPreferencesHiddenPane : TDCPreferencesPane
@end

NS_ASSUME_NONNULL_END
