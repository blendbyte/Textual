/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/* A window for one piece of inline media (images; YouTube's
 player builds on it): its own web view, sized to the media up to the
 screen, resizable and full screen, closed with Esc or ⌘W. It floats above
 Textual's windows (decided 2026-10-14) and hides while another app is in
 front. The toolbar
 and the context menu open or copy the link the media came from;
 subclasses add their own items and load their content. An open viewer
 keeps itself alive until it is closed. */
@interface ICLMediaViewer : NSWindowController <NSWindowDelegate, NSToolbarDelegate>
- (instancetype)initWithLinkURL:(NSURL *)linkURL title:(NSString *)title contentSize:(NSSize)contentSize; // -webViewConfiguration
- (instancetype)initWithLinkURL:(NSURL *)linkURL title:(NSString *)title contentSize:(NSSize)contentSize webViewConfiguration:(WKWebViewConfiguration *)webViewConfiguration;

@property (readonly, copy) NSURL *linkURL;
@property (readonly) WKWebView *webView;

/* An open viewer that passes the test */
+ (nullable __kindof ICLMediaViewer *)openViewerPassingTest:(BOOL (NS_NOESCAPE ^)(__kindof ICLMediaViewer *viewer))test;

/* Loads the content, then shows the window on the screen of the main window */
- (void)showViewer;

/* A content size that fits on the screen, scaled down keeping its shape */
+ (NSSize)contentSizeForMediaSize:(NSSize)mediaSize onScreen:(nullable NSScreen *)screen;

- (IBAction)openInBrowser:(nullable id)sender;
- (IBAction)copyLink:(nullable id)sender;

#pragma mark For Subclasses

/* No JavaScript, no website data kept, textual-media: addresses */
- (WKWebViewConfiguration *)webViewConfiguration;

- (void)loadContent;

/* Super's: Open in Browser, Copy Link */
- (NSArray<NSToolbarItemIdentifier> *)toolbarItemIdentifiers;
- (nullable NSToolbarItem *)toolbarItemForIdentifier:(NSToolbarItemIdentifier)identifier;
- (NSToolbarItem *)toolbarItemWithIdentifier:(NSToolbarItemIdentifier)identifier label:(NSString *)label symbolName:(NSString *)symbolName action:(SEL)action;

/* Super's: Open in Browser, Copy Link */
- (NSArray<NSMenuItem *> *)contextMenuItems;
@end

NS_ASSUME_NONNULL_END
