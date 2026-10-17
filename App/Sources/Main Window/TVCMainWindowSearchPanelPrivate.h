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

#import "TVCMainWindow.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TVCMainWindowSearchScope)
{
	TVCMainWindowSearchScopeChannel = 0, // the selected channel, query or console
	TVCMainWindowSearchScopeServer = 1,
	TVCMainWindowSearchScopeEverywhere = 2
};

/* The search panel (10.9 D): searches the message archive from the right
 sidebar (the member list's column, which comes back when it closes). A
 result still in the chat's scrollback is scrolled to and flashed there; an
 older one is shown in its conversation from the archive, in the panel. */
@interface TVCMainWindowSearchPanel : NSViewController
- (instancetype)initWithWindow:(TVCMainWindow *)mainWindow;

/* The Mentions window's list (10.9 E): highlights of every network, newest
 first; what is typed narrows them down */
- (instancetype)initForMentions;
- (instancetype)initWithNibName:(nullable NSNibName)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, weak, nullable) TVCMainWindow *mainWindow; // nil for Mentions

@property (readonly) BOOL mentionsMode;

/* Mentions: those that came after this one (archive row; 0: none) are
 marked new. By arrival, not time: a bouncer's playback brings old times. */
@property (nonatomic, assign) int64_t markedNewAfterRowId;

/* The newest of the results shown (archive row), or 0 */
@property (readonly) int64_t newestResultRowId;

- (void)search; // again, now

@property (nonatomic, assign) TVCMainWindowSearchScope scope; // searches again

- (void)focusSearchField; // its text selected

- (void)loadArchivedNames; // for suggestions

/* ⌘G and ⌘⇧G: the next or previous result, opened */
- (void)openAdjacentResult:(BOOL)forward;

/* The window selected another item: a search in it follows */
- (void)selectedItemChanged;
@end

/* Mentions (10.9 E, ⌘⇧M): the highlights of every network, from the message
 archive, in a window of their own; a click goes to the message. Those that
 came since the window was last closed are marked new. */
@interface TVCMentionsWindowController : NSWindowController <NSWindowDelegate>
+ (void)showMentions;
@end

@interface TVCMainWindow (SearchPrivate)
@property (readonly) BOOL isSearchPanelVisible;

- (void)showSearchPanelWithScope:(TVCMainWindowSearchScope)scope;
- (void)closeSearchPanel;

/* ⌘G and ⌘⇧G: the next or previous result (the panel opens when closed) */
- (void)openAdjacentSearchResult:(BOOL)forward;
@end

NS_ASSUME_NONNULL_END
