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

#import "NSObjectHelperPrivate.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCChannelUser.h"
#import "IRCExtrasPrivate.h"
#import "IRCISupportInfo.h"
#import "IRCUser.h"
#import "IRCWorldPrivate.h"
#import "TVCBasicTableView.h"
#import "TVCLogController.h"
#import "TVCLogViewPrivate.h"
#import "TVCLogViewInternalWK2.h"
#import "TVCMemberList.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowSplitView.h"
#import "TVCMainWindowTextView.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TDCAboutDialogPrivate.h"
#import "TDCAlert.h"
#import "TDCChannelInviteSheetPrivate.h"
#import "TDCChannelModifyModesSheetPrivate.h"
#import "TDCChannelModifyTopicSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TDCChannelSpotlightControllerPrivate.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCInputPrompt.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TDCNicknameColorSheetPrivate.h"
#import "TDCPreferencesControllerPrivate.h"
#import "TDCServerChangeNicknameSheetPrivate.h"
#import "TDCServerHighlightListSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TDCWelcomeSheetPrivate.h"
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesImportExport.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "TXMasterControllerPrivate.h"
#import "TXWindowControllerPrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif
#import "TXMenuControllerInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TXMenuController (Edit)

#pragma mark -
#pragma mark Find Panel

- (void)_showFindPromptOpenDialog:(nullable id)sender
{
	void (^promptCompletionBlock)(NSString *) = ^(NSString *resultString)
	{
		if ([self.currentSearchPhrase isEqualToString:resultString]) {
			return;
		}

		self.currentSearchPhrase = resultString;

		TVCLogView *webView = self.selectedViewControllerBackingView;

		[webView findString:resultString movingForward:YES];
	};

	NSString *resultString = nil;

	TVCAlertResponseButton response =
	[TDCInputPrompt promptWithMessage:TXTLS(@"Prompts[d2w-4o]")
								title:TXTLS(@"Prompts[akr-eh]")
						defaultButton:TXTLS(@"Prompts[q5h-xx]")
					  alternateButton:TXTLS(@"Prompts[qso-2g]")
						prefillString:self.currentSearchPhrase
						 resultString:&resultString];

	if (response == TVCAlertResponseButtonFirst) {
		promptCompletionBlock(resultString);
	}
}

- (void)showFindPrompt:(nullable id)sender
{
	NSParameterAssert(sender != nil);

	if (mainWindow().keyWindow == NO) {
		return;
	}

	if ([sender tag] == MTMMEditFindMenuFind || self.currentSearchPhrase.length == 0) {
		[self _showFindPromptOpenDialog:sender];

		return;
	}

	TVCLogView *webView = self.selectedViewControllerBackingView;

	if ([sender tag] == MTMMEditFindMenuFindNext) {
		[webView findString:self.currentSearchPhrase movingForward:YES];
	} else {
		[webView findString:self.currentSearchPhrase movingForward:NO];
	}
}

#pragma mark -
#pragma mark Edit

- (void)copy:(nullable id)sender
{
	id firstResponder = [NSApp keyWindow].firstResponder;

	if ([firstResponder respondsToSelector:@selector(copy:)]) {
		[firstResponder performSelector:@selector(copy:) withObject:sender];
	}
}

- (void)paste:(nullable id)sender
{
	if (mainWindow().keyWindow) {
		[mainWindowTextField() focus];

		[mainWindowTextField() paste:sender];

		return;
	}

	id firstResponder = [NSApp keyWindow].firstResponder;

	if ([firstResponder respondsToSelector:@selector(paste:)]) {
		[firstResponder performSelector:@selector(paste:) withObject:sender];
	}
}

- (void)print:(nullable id)sender
{
	if (mainWindow().keyWindow) {
		TVCLogView *webView = self.selectedViewControllerBackingView;

		if (webView == nil) {
			return;
		}

		[webView print];

		return;
	}

	id firstResponder = [NSApp keyWindow].firstResponder;

	if ([firstResponder respondsToSelector:@selector(print:)]) {
		[firstResponder performSelector:@selector(print:) withObject:sender];
	}
}

#pragma mark -
#pragma mark Backing View

- (void)copyLogAsHtml:(nullable id)sender
{
	TVCLogView *webView = self.selectedViewControllerBackingView;

	if (webView == nil) {
		return;
	}

	[webView copyContentString];
}

- (void)openWebInspector:(nullable id)sender
{
	/* "Inspect Element" in the chat view's context menu (Developer Mode)
	 opens the inspector; there is no public API to open it from here. */
}

- (void)markScrollback:(nullable id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController mark];
}

- (void)gotoScrollbackMarker:(nullable id)sender
{
	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	[viewController goToMark];
}

- (void)clearScrollback:(nullable id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil) {
		return;
	}

	if (c) {
		[mainWindow() clearContentsOfChannel:c];
	} else {
		[mainWindow() clearContentsOfClient:u];
	}
}

- (void)increaseLogFontSize:(nullable id)sender
{
	[mainWindow() changeTextSize:YES];
}

- (void)decreaseLogFontSize:(nullable id)sender
{
	[mainWindow() changeTextSize:NO];
}

- (NSString *)searchProviderName
{
	NSDictionary *preferredWebServices =
	[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"NSPreferredWebServices"];

	NSDictionary *defaultSearchProvider = [preferredWebServices dictionaryForKey:@"NSWebServicesProviderWebSearch"];

	NSString *searchProviderName = [defaultSearchProvider stringForKey:@"NSDefaultDisplayName"];

	if (searchProviderName == nil) {
		return @"Google";
	}

	return searchProviderName;
}

- (void)searchGoogle:(nullable id)sender
{
	TVCLogView *webView = self.selectedViewControllerBackingView;

	if (webView == nil) {
		return;
	}

	NSString *selection = webView.selection;

	if (selection.length == 0) {
		return;
	}

	NSPasteboard *searchPasteboard = [NSPasteboard pasteboardWithUniqueName];

	searchPasteboard.stringContent = selection;

	NSPerformService(@"Search With %WebSearchProvider@", searchPasteboard);
}

- (void)lookUpInDictionary:(nullable id)sender
{
	TVCLogView *webView = self.selectedViewControllerBackingView;

	if (webView == nil) {
		return;
	}

	NSString *selection = webView.selection;

	if (selection.length == 0) {
		return;
	}

	NSString *urlString = [NSString stringWithFormat:@"dict://%@", selection.percentEncodedString];

	[TLOpenLink openWithString:urlString];
}

@end

NS_ASSUME_NONNULL_END
