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

#import "NSViewHelperPrivate.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TPCPreferencesLocal.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowLoadingScreen.h"
#import "IRCClient.h"
#import "IRCWorld.h"
#import "TVCMainWindowSegmentedControlPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowSegmentedController ()
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *segmentedControllerLeadingConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *segmentedControllerWidthConstraint;
@end

@implementation TVCMainWindowSegmentedController

- (void)segmentedCellClicked:(id)sender
{
	NSInteger selectedSegment = self.selectedSegment;

	if (selectedSegment == 2) {
		[menuController() showAddressBook:sender];
	}
}

- (void)updateSegmentedControllerOrigin
{
	if ([TPCPreferences hideMainWindowSegmentedController]) {
		[self.segmentedControllerLeadingConstraint archiveConstantAndZeroOut];
		[self.segmentedControllerWidthConstraint archiveConstantAndZeroOut];
	} else {
		[self.segmentedControllerLeadingConstraint restoreArchivedConstant];
		[self.segmentedControllerWidthConstraint restoreArchivedConstant];
	}
}

- (void)updateSegmentedController
{
	if ([TPCPreferences hideMainWindowSegmentedController]) {
		return;
	}

	TVCMainWindow *mainWindow = self.mainWindow;

	IRCClient *selectedClient = mainWindow.selectedClient;
	IRCChannel *selectedChannel = mainWindow.selectedChannel;

	/* Enable controller */
	self.enabled = (worldController().clientCount > 0 &&
				mainWindow.loadingScreen.viewIsVisible == NO);

	// Cell 0
	NSMenu *cell0Menu = menuController().mainWindowSegmentedControllerCellMenu;

	[self setMenu:cell0Menu forSegment:0];

	// Cell 1
	NSMenuItem *cell1MenuItem = nil;

	if (selectedChannel == nil) {
		cell1MenuItem = menuController().mainMenuServerMenuItem;
	} else {
		cell1MenuItem = menuController().mainMenuChannelMenuItem;
	}

	[self setMenu:cell1MenuItem.submenu forSegment:1];

	// Cell 2
	[self setEnabled:(selectedClient.isConnected) forSegment:2];
}

@end

#pragma mark -

@implementation TVCMainWindowSegmentedControllerCell

- (nullable SEL)action
{
	NSInteger selectedSegment = self.selectedSegment;

	if ([self menuForSegment:selectedSegment] == nil) {
		return super.action;
	} else {
		return nil;
	}
}

@end

NS_ASSUME_NONNULL_END
