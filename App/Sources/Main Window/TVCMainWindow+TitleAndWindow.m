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
#import "NSStringHelper.h"
#import "IRCChannelPrivate.h"
#import "IRCChannelMode.h"
#import "IRCClientConfig.h"
#import "IRCClientPrivate.h"
#import "IRCTreeItemPrivate.h"
#import "IRCUserRelationsPrivate.h"
#import "IRCWorldPrivate.h"
#import "TVCDockIconPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogViewPrivate.h"
#import "TVCMainWindowAppearancePrivate.h"
#import "TVCMainWindowChannelViewPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"
#import "TVCServerListPrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCServerListCellPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCTextViewIRCFormattingMenuPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TPCApplicationInfo.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCThemeControllerPrivate.h"
#import "TPCTheme.h"
#import "TXGlobalModels.h"
#import "TXMasterControllerPrivate.h"
#import "TXMenuControllerPrivate.h"
#import "THOPluginDispatcherPrivate.h"
#import "TLOKeyEventHandler.h"
#import "TLOInputHistoryPrivate.h"
#import "TLOLocalization.h"
#import "TLOLicenseManagerPrivate.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "TLONotificationControllerPrivate.h"
#import "TLOSpeechSynthesizerPrivate.h"
#import "TDCLicenseManagerDialogPrivate.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TVCMainWindow (TitleAndWindow)

#pragma mark -
#pragma mark License Manager

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
- (void)licenseManagerActivatedLicense:(NSNotification *)notification
{
	[self reloadLoadingScreen];
}

- (void)licenseManagerDeactivatedLicense:(NSNotification *)notification
{
	[self reloadLoadingScreen];
}

- (void)licenseManagerTrialExpired:(NSNotification *)notification
{
	[self reloadLoadingScreen];
}
#endif

#pragma mark -
#pragma mark Loading Screen

- (void)setLoadingScreenProgressViewReason:(NSString *)progressReason
{
	NSParameterAssert(progressReason != nil);

	[self.loadingScreen setProgressViewReason:progressReason];
}

- (BOOL)reloadLoadingScreen
{
	/* This method returns YES (success) if the loading screen is dismissed
	 when called. NO indicates an error that resulted in it staying on screen. */
	if (worldController().isImportingConfiguration) {
		return NO;
	}

	if (masterController().applicationIsLaunched == NO) {
		[self.loadingScreen showProgressViewWithReason:TXTLS(@"TVCMainWindow[iph-a9]")];

		return NO;
	}

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	if (TLOLicenseManagerTextualIsRegistered() == NO && TLOLicenseManagerIsTrialExpired()) {
		[self.loadingScreen showTrialExpiredView];

		return NO;
	}
#endif

	if (worldController().clientCount <= 0) {
		[self.loadingScreen showWelcomeAddServerView];

		return NO;
	}

	[self.loadingScreen hideAnimated];

	return YES;
}

#pragma mark -
#pragma mark Window Extras

- (void)presentCertificateTrustInformation:(nullable id)sender
{
	IRCClient *u = self.selectedClient;

	if (u) {
		[u presentCertificateTrustInformation];
	}
}

- (void)updateAccessoryViewLockButton
{
	IRCClient *u = self.selectedClient;

	self.titlebarAccessoryViewLockButton.action = @selector(presentCertificateTrustInformation:);

	[self.titlebarAccessoryViewLockButton disableDrawingCustomBackgroundColor];

	[self.titlebarAccessoryViewLockButton positionImageOverContent];

	self.titlebarAccessoryViewLockButton.title = @"";

	if (u.isSecured) {
		[self.titlebarAccessoryViewLockButton setIconAsLocked];

		self.titlebarAccessoryView.hidden = NO;
	} else {
		self.titlebarAccessoryView.hidden = YES;
	}

	if (self.titlebarAccessoryView.hidden == NO) {
		[self.titlebarAccessoryViewLockButton sizeToFit];
	}
}

- (void)addAccessoryViewsToTitlebar
{
	NSThemeFrame *themeFrame = (NSThemeFrame *)self.contentView.superview;

	themeFrame.usesCustomTitlebarTitlePositioning = YES;

	NSTitlebarAccessoryViewController *accessoryView = self.titlebarAccessoryViewController;

	accessoryView.layoutAttribute = NSLayoutAttributeRight;

	[self addTitlebarAccessoryViewController:accessoryView];
}

/* Servers pass themselves for nickname, away and connection changes, which
 show while one of their channels is selected too. Many changes at once
 (joins and parts) make one update. */
- (void)updateTitleFor:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if ([self isItemSelected:item] == NO && item != self.selectedClient) {
		return;
	}

	[self cs_reschedulePerformSelectorInCommonModes:@selector(updateTitle) withObject:nil afterDelay:0.0];
}

- (void)updateTitle
{
	[self updateAccessoryViewLockButton];

	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil && c == nil) {
		self.title = [TPCApplicationInfo applicationName];

		return;
	}

	NSMutableString *title = [NSMutableString string];

	if (u.isConnected == NO && u.isConnecting == NO) {
		if (u.isReconnecting) {
			[title appendString:TXTLS(@"TVCMainWindow[3yn-wd]")];
		} else {
			[title appendString:TXTLS(@"TVCMainWindow[q42-an]")];
		}
	} else if (u.isConnecting && u.isLoggedIn == NO) {
		if (u.connectType == IRCClientConnectModeRetry || u.connectType == IRCClientConnectModeReconnect) {
			[title appendString:TXTLS(@"TVCMainWindow[s23-zd]")];
		} else {
			[title appendString:TXTLS(@"TVCMainWindow[8eu-c7]")];
		}
	} else if (u.isConnected && u.isLoggedIn == NO) {
		[title appendString:TXTLS(@"TVCMainWindow[wcb-y8]")];
	} else if (u.isQuitting) {
		[title appendString:TXTLS(@"TVCMainWindow[xqd-h9]")];
	}
	
	NSString *awayStatus = ((u.userIsAway) ? TXTLS(@"TVCMainWindow[nxz-l9]") : @"");

	[title appendString:TXTLS(@"TVCMainWindow[19v-bc]", u.userNickname, awayStatus, u.networkNameAlt)];

	if (c == nil) // = Client
	{
		/* If we have the actual server that the client is connected
		 to, then we we append that. Otherwise, we just leave it blank. */
		NSString *serverAddress = u.serverAddress;

		if (serverAddress) {
			[title appendString:TXTLS(@"TVCMainWindow[jqk-ha]")]; // divider

			[title appendString:serverAddress];
		}
	}
	else
	{
		[title appendString:TXTLS(@"TVCMainWindow[jqk-ha]")]; // divider

		NSString *channelName = c.name;

		switch (c.type) {
			case IRCChannelTypeChannel:
			{
				[title appendString:channelName];

				NSString *userCount = TXFormattedNumber(c.numberOfMembers);

				[title appendString:TXTLS(@"TVCMainWindow[v6i-zb]", userCount)];

				NSString *modeSymbols = c.modeInfo.stringWithMaskedPassword;

				if (modeSymbols.length > 1) {
					[title appendString:TXTLS(@"TVCMainWindow[cyg-g9]", modeSymbols)];
				}

				break;
			}
			case IRCChannelTypePrivateMessage:
			{
				/* Textual defines the topic of a private message as the user host. */
				/* If it is not defined yet, then we just use the channel name
				 which is equal to the nickname of the private message owner. */
				IRCUser *user = [u findUser:channelName];

				NSString *hostmask = user.hostmaskFragment;

				if (hostmask) {
					[title appendString:TXTLS(@"TVCMainWindow[6wz-pd]", channelName, hostmask)];
				} else {
					[title appendString:channelName];
				}

				break;
			}
			case IRCChannelTypeUtility:
			{
				[title appendString:channelName];

				break;
			}
		}
	}

	if ([self.title isEqualToString:title]) {
		return;
	}

	self.title = title;

	[self setAccessibilityTitle:TXTLS(@"Accessibility[k79-1a]")];
}

@end

NS_ASSUME_NONNULL_END
