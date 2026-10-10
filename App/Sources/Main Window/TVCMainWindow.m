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

NSString * const TVCMainWindowAppearanceChangedNotification = @"TVCMainWindowAppearanceChangedNotification";
NSString * const TVCMainWindowRedrawSubviewsNotification = @"TVCMainWindowRedrawSubviewsNotification";

NSString * const TVCMainWindowWillReloadThemeNotification = @"TVCMainWindowWillReloadThemeNotification";
NSString * const TVCMainWindowDidReloadThemeNotification = @"TVCMainWindowDidReloadThemeNotification";

NSString * const TVCMainWindowSelectionChangedNotification = @"TVCMainWindowSelectionChangedNotification";

@implementation TVCMainWindow

#pragma mark -
#pragma mark Awakening

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	if ((self = [super initWithContentRect:contentRect styleMask:style backing:bufferingType defer:flag])) {
		[self prepareInitialState];
	}

	return self;
}

- (void)prepareInitialState
{
	self.inputHistoryManager = [[TLOInputHistory alloc] initWithWindow:self];

	self.keyEventHandler = [[TLOKeyEventHandler alloc] initWithTarget:self];

	self.nicknameCompletionStatus = [[TLONicknameCompletionStatus alloc] initWithWindow:self];

	self.previousSelectedItemsId = @[];

	self.selectedItems = @[];

	self.textSizeMultiplier = 1.0;
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	/* -awakeFromNib is called multiple times because of reloads */
	static BOOL _awakeFromNibCalled = NO;

	if (_awakeFromNibCalled == NO) {
		_awakeFromNibCalled = YES;

		[self _awakeFromNib];
	}
}

- (void)_awakeFromNib
{
	self.delegate = (id)self;

	self.allowsConcurrentViewDrawing = NO;

	self.alphaValue = [TPCPreferences mainWindowTransparency];

	[self addAccessoryViewsToTitlebar];

	[self updateAppearance];

	[self reloadLoadingScreen];

	[self makeMainWindow];

	[self makeKeyAndOrderFront:nil];

	[self loadWindowState];

	[self updateChannelViewArrangement];

	[masterController() applicationWakeStepOne];

	[themeController() load];

	[menuController() prepareInitialState];

	[self registerKeyHandlers];

	[self addFormattingMenuToInputTextField];

	[worldController() setupConfiguration];

	[self setupTrees];

	[TVCDockIcon drawWithoutCount];

	[self observeNotifications];

	[masterController() applicationWakeStepTwo];
}

- (void)observeNotifications
{
#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
	[RZNotificationCenter() addObserver:self
							   selector:@selector(licenseManagerActivatedLicense:)
								   name:TDCLicenseManagerActivatedLicenseNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(licenseManagerDeactivatedLicense:)
								   name:TDCLicenseManagerDeactivatedLicenseNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(licenseManagerTrialExpired:)
								   name:TDCLicenseManagerTrialExpiredNotification
								 object:nil];
#endif

	[RZNotificationCenter() addObserver:self
							   selector:@selector(applicationAppearanceChanged:)
								   name:TXApplicationAppearanceChangedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(systemAppearanceChanged:)
								   name:TXSystemAppearanceChangedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeVarietyChanged:)
								   name:TPCThemeAppearanceChangedNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(themeVarietyChanged:)
								   name:TPCThemeVarietyChangedNotification
								 object:nil];
}

- (void)maybeToggleFullscreenAfterLaunch
{
	BOOL isFullscreen = [RZUserDefaults() boolForKey:@"Window -> Main Window Is Fullscreen'd"];

	if (isFullscreen == NO) {
		return;
	}

	/* Called again before the second is up: still one toggle, or the window leaves full screen right away */
	[self cs_reschedulePerformSelectorInCommonModes:@selector(toggleFullscreenAfterLaunch) withObject:nil afterDelay:1.0];
}

- (void)toggleFullscreenAfterLaunch
{
	if (self.inFullscreenMode) {
		return;
	}

	[self toggleFullScreen:nil];
}

- (void)themeVarietyChanged:(NSNotification *)notification
{
	[self reloadTheme];
}

- (void)applicationAppearanceChanged:(NSNotification *)notification
{
	[self updateAppearance];
}

- (void)systemAppearanceChanged:(NSNotification *)notification
{
	[self notifySystemAppearanceChanged];
}

- (BOOL)isUsingDarkAppearance
{
	return self.userInterfaceObjects.isDarkAppearance;
}

- (void)updateAppearance
{
	TVCMainWindowAppearance *appearance = [[TVCMainWindowAppearance alloc] initWithWindow:self];

	self.userInterfaceObjects = appearance;

	[self updateVibrancyWithAppearance:appearance];

	[self notifyApplicationAppearanceChanged];
}

- (void)updateVibrancyWithAppearance:(TVCMainWindowAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	NSAppearance *appKitAppearance = nil;

	if (appearance.appKitAppearanceTarget == TXAppKitAppearanceTargetWindow) {
		appKitAppearance = appearance.appKitAppearance;
	}

	self.appearance = appKitAppearance;
}

- (void)notifyApplicationAppearanceChanged
{
	[super notifyApplicationAppearanceChanged];

	[RZNotificationCenter() postNotificationName:TVCMainWindowAppearanceChangedNotification object:self];
}

- (void)updateAlphaValueToReflectPreferences
{
	[self updateAlphaValueToReflectPreferencesAnimated:NO];
}

- (void)updateAlphaValueToReflectPreferencesAnimated:(BOOL)animate
{
	if (self.inFullscreenMode) {
		return;
	}

	double alphaValue = [TPCPreferences mainWindowTransparency];

	if (animate) {
		[self animator].alphaValue = alphaValue;
	} else {
		self.alphaValue = alphaValue;
	}
}

- (void)loadWindowState
{
	[self restoreWindowStateUsingKeyword:@"Main Window"];

	[self restoreSavedContentSplitViewState];
}

- (void)saveWindowState
{
	[RZUserDefaults() setBool:self.isInFullscreenMode forKey:@"Window -> Main Window Is Fullscreen'd"];

	[self saveWindowStateUsingKeyword:@"Main Window"];

	[self.contentSplitView writeSavedFrames];

	[self saveContentSplitViewState];

	[self saveSelection];
}

- (void)prepareForApplicationTermination
{
	LogToConsoleTerminationProgress("Removing main window observers");

	[RZNotificationCenter() removeObserver:self];

	LogToConsoleTerminationProgress("Saving window state");

	[self saveWindowState];

	LogToConsoleTerminationProgress("Giving up server list & member list delegation");

	self.serverList.dataSource = nil;
	self.serverList.delegate = nil;
	self.serverList.keyDelegate = nil;

	self.memberList.keyDelegate = nil;

	[self.memberList assignToChannel:nil];

	/* No window delegate calls (selection, resizing) while closing */
	self.delegate = nil;

	self.selectedItems = @[];
	self.selectedItem = nil;

	LogToConsoleTerminationProgress("Closing main window");

	[self close];
}

#pragma mark -
#pragma mark Item Update

- (void)reloadMainWindowFrameOnScreenChange
{
	if (masterController().applicationIsTerminating) {
		return;
	}

	[TVCDockIcon resetCachedCount];

	[TVCDockIcon updateDockIcon];

	[self updateAppearance];
}

- (void)resetSelectedItemState
{
	if (masterController().applicationIsTerminating) {
		return;
	}

	IRCTreeItem *selectedItem = self.selectedItem;

	if (selectedItem) {
		[selectedItem resetState];

		if (selectedItem.isClient == NO) {
			[selectedItem.associatedClient markChannelAsRead:(IRCChannel *)selectedItem];
		}
	}

	[TVCDockIcon updateDockIcon];
}

- (void)reloadSubviewDrawings
{
	[RZNotificationCenter() postNotificationName:TVCMainWindowRedrawSubviewsNotification object:self];
}

#pragma mark -
#pragma mark NSWindow Delegate

/* The appearance (four files) depends on the scale only: moving to another
 screen with the same scale rebuilt it for nothing */
- (void)windowDidChangeBackingProperties:(NSNotification *)notification
{
	NSNumber *oldScaleFactor = notification.userInfo[NSBackingPropertyOldScaleFactorKey];

	if (oldScaleFactor && oldScaleFactor.doubleValue == self.backingScaleFactor) {
		return;
	}

	[self reloadMainWindowFrameOnScreenChange];
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification
{
	if (self.occluded) {
		return;
	}

	if (self.lastKeyWindowRedrawFailedBecauseOfOcclusion) {
		self.lastKeyWindowRedrawFailedBecauseOfOcclusion = NO;

		[self reloadSubviewDrawings];
	} else {
		/* We keep track of the last subview redraw so that we do
		 not draw too often. Current maximum is 1.0 second. */
		NSTimeInterval timeDifference = ([NSDate timeIntervalSince1970] - self.lastKeyWindowStateChange);

		if (timeDifference > 1.0) {
			[self reloadSubviewDrawings];
		}
	}
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	[self.titlebarTitleField updateTextColor];
}

- (void)windowDidResignMain:(NSNotification *)notification
{
	[self.titlebarTitleField updateTextColor];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	self.lastKeyWindowStateChange = [NSDate timeIntervalSince1970];

	[self.titlebarTitleField updateTextColor];

	[self resetSelectedItemState];

	if (self.occluded) {
		self.lastKeyWindowRedrawFailedBecauseOfOcclusion = YES;

		return;
	}

	[self reloadSubviewDrawings];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	self.lastKeyWindowStateChange = [NSDate timeIntervalSince1970];

	[self.titlebarTitleField updateTextColor];

	[self reloadSubviewDrawings];
}

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu
{
	return NO;
}

- (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard
{
	return NO;
}

- (void)windowDidResize:(NSNotification *)notification
{
	[self.inputTextField recalculateTextViewSize];
}

- (BOOL)windowShouldZoom:(NSWindow *)awindow toFrame:(NSRect)newFrame
{
	return (self.inFullscreenMode == NO);
}

- (NSSize)window:(NSWindow *)window willUseFullScreenContentSize:(NSSize)proposedSize
{
	return proposedSize;
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
	return proposedOptions;
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	[self updateAlphaValueToReflectPreferencesAnimated:YES];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
	[self animator].alphaValue = 1.0;
}

/* The Format menu at the end of the input field's context menu. This was done
 by making the input field the field editor of every text field in the window. */
- (void)addFormattingMenuToInputTextField
{
	NSMenu *editorMenu = self.inputTextField.menu;

	NSMenuItem *formatterMenu = self.formattingMenu.formatterMenu;

	if (editorMenu == nil || formatterMenu == nil) {
		return;
	}

	if ([editorMenu indexOfItem:formatterMenu] >= 0) {
		return;
	}

	[editorMenu addItem:[NSMenuItem separatorItem]];

	[editorMenu addItem:formatterMenu];

	self.inputTextField.menu = editorMenu;
}

#pragma mark -
#pragma mark View Controls

- (void)changeTextSize:(BOOL)bigger
{
#define MinimumZoomMultiplier	   0.5
#define MaximumZoomMultiplier	   3.0

#define ZoomMultiplierRatio			1.2

	double textSizeMultiplier = self.textSizeMultiplier;

	if (bigger) {
		textSizeMultiplier *= ZoomMultiplierRatio;

		if (textSizeMultiplier > MaximumZoomMultiplier) {
			return;
		}

		self.textSizeMultiplier = textSizeMultiplier;
	} else {
		textSizeMultiplier /= ZoomMultiplierRatio;

		if (textSizeMultiplier < MinimumZoomMultiplier) {
			return;
		}

		self.textSizeMultiplier = textSizeMultiplier;
	}

	for (IRCClient *u in worldController().clientList) {
		[u.viewController changeTextSize:bigger];

		for (IRCChannel *c in u.channelList) {
			[c.viewController changeTextSize:bigger];
		}
	}

#undef MinimumZoomMultiplier
#undef MaximumZoomMultiplier

#undef ZoomMultiplierRatio
}

- (void)markAllAsRead
{
	[self markAllAsReadInGroup:nil];
}

/* With an item: only its server and that server's channels. Without: everything. */
- (void)markAllAsReadInGroup:(nullable IRCTreeItem *)item
{
	BOOL markScrollback = [TPCPreferences autoAddScrollbackMark];

	NSArray<IRCClient *> *clientList = worldController().clientList;

	if (item) {
		IRCClient *client = item.associatedClient;

		clientList = ((client) ? @[client] : @[]);
	}

	for (IRCClient *u in clientList) {
		if (markScrollback) {
			[u.viewController mark];
		}

		for (IRCChannel *c in u.channelList) {
			if (markScrollback) {
				[c.viewController mark];
			}

			[c resetState];
		}
	}

	[TVCDockIcon updateDockIcon];

	if (item) {
		[self reloadTreeGroup:item];
	} else {
		[self reloadTree];
	}
}

- (void)reloadTheme
{
	if (self.reloadingTheme == NO) {
		self.reloadingTheme = YES;
	} else {
		return;
	}

	[RZNotificationCenter() postNotificationName:TVCMainWindowWillReloadThemeNotification object:self];

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		if (masterController().applicationIsTerminating) {
			return;
		}

		[TVCLogView emptyCaches];

		[self _reloadTheme_performReload];
	});
}

- (void)_reloadTheme_performReload
{
	for (IRCClient *u in worldController().clientList) {
		[u.viewController reloadTheme];

		for (IRCChannel *c in u.channelList) {
			[c.viewController reloadTheme];
		}
	}

	self.reloadingTheme = NO;

	[RZNotificationCenter() postNotificationName:TVCMainWindowDidReloadThemeNotification object:self];
}

- (void)clearContentsOfClient:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	[client resetState];

	[client.viewController clear];

	[self reloadTreeItem:client];
}

- (void)clearContentsOfChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	[channel resetState];

	[channel.viewController clear];

	[self reloadTreeItem:channel];
}

- (void)clearAllViews
{
	for (IRCClient *u in worldController().clientList) {
		[self clearContentsOfClient:u];

		for (IRCChannel *c in u.channelList) {
			[self clearContentsOfChannel:c];
		}
	}

	[self markAllAsRead];
}

#pragma mark -
#pragma mark Utilities

- (void)textEntered
{
	[self inputTextAsCommand:IRCRemoteCommandPrivmsg];
}

- (void)inputTextAsCommand:(IRCRemoteCommand)command
{
	[self.nicknameCompletionStatus clear];

	NSAttributedString *stringValue = self.inputTextField.attributedStringValue;

	if (stringValue.length == 0) {
		return;
	}

	/* The message itself ends typing: forget the "active" before clearing
	 the field, whose change would otherwise send a needless "done" */
	IRCTreeItem *selectedItem = self.selectedItem;

	if (selectedItem && selectedItem.isClient == NO) {
		[selectedItem.associatedClient typingMessageSentInChannel:(IRCChannel *)selectedItem];
	}

	self.inputTextField.attributedStringValue = [NSAttributedString attributedString];

	[self.inputHistoryManager add:stringValue];

	[self inputText:stringValue asCommand:command];
}

- (void)inputText:(id)string asCommand:(IRCRemoteCommand)command
{
	NSParameterAssert(string != nil);

	if (self.selectedItem == nil) {
		return;
	}

	NSString *stringValue = [THOPluginDispatcher interceptUserInput:string command:command];
	
	if (stringValue == nil) {
		return;
	}

	[self.selectedClient inputText:stringValue asCommand:command];
}

#pragma mark -
#pragma mark Misc

- (TVCMainWindowMouseLocation)locationOfMouseInWindow
{
	NSPoint mouseLocation = [NSEvent mouseLocation];

	return [self locationOfMouse:mouseLocation];
}

- (TVCMainWindowMouseLocation)locationOfMouse:(NSPoint)mouseLocation
{
	TVCMainWindowMouseLocation mouseLocationEnum = 0;

	NSRect windowFrame = self.frame;

	if (NSPointInRect(mouseLocation, windowFrame) == NO) {
		return mouseLocationEnum;
	}

	mouseLocationEnum |= TVCMainWindowMouseLocationInsideWindow;

	NSRect titlebarFrame = self.titlebarFrame;

	if (NSPointInRect(mouseLocation, titlebarFrame) == NO) {
		return mouseLocationEnum;
	}

	mouseLocationEnum |= TVCMainWindowMouseLocationInsideWindowTitle;

#define ConvertRectToScreen(rect)	\
	NSMakeRect( (titlebarFrame.origin.x + rect.origin.x),	\
				(titlebarFrame.origin.y + rect.origin.y),	\
				rect.size.width,	\
				rect.size.height)	\

#define PointInRect(view)	\
	NSPointInRect(mouseLocation, ConvertRectToScreen(view.frame))

	if (PointInRect([self standardWindowButton:NSWindowCloseButton]) ||
		PointInRect([self standardWindowButton:NSWindowMiniaturizeButton]) ||
		PointInRect([self standardWindowButton:NSWindowZoomButton]))
	{
		mouseLocationEnum |= TVCMainWindowMouseLocationOnTopOfWindowTitleControl;

		return mouseLocationEnum;
	}

	for (NSTitlebarAccessoryViewController *viewController in self.titlebarAccessoryViewControllers) {
		/* NSTitlebarAccessoryViewController will have an origin of 0,0 which means we have
		 to check the frame of it's superview, NSTitlebarAccessoryViewClipView */
		if (PointInRect(viewController.view.superview) == NO) {
			continue;
		}

		mouseLocationEnum |= TVCMainWindowMouseLocationOnTopOfWindowTitleControl;

		return mouseLocationEnum;
	}

	return mouseLocationEnum;

#undef ConvertRectToScreen

#undef PointInRect
}

- (void)preferencesChanged
{
	if ([TPCPreferences displayDockBadge] == NO) {
		[TVCDockIcon drawWithoutCount];
	} else {
		[TVCDockIcon resetCachedCount];

		[TVCDockIcon updateDockIcon];
	}
}

- (void)endEditingFor:(nullable id)object
{
	/* WebHTMLView results in this method being called.
	 *
	 * The documentation states "The endEditingFor: method should be used only as a
	 * last resort if the field editor refuses to resign first responder status."
	 *
	 * The documentation then goes to say how you should try setting makeFirstResponder first.
	 */

	if ([self makeFirstResponder:self] == NO) {
		[super endEditingFor:object];
	}
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}

- (BOOL)isDisabled
{
	return NO;
}

- (void)makeKeyAndOrderFront:(nullable id)sender
{
	if (self.disabled) {
		return;
	}

	[super makeKeyAndOrderFront:nil];
}

- (void)orderFront:(nullable id)sender
{
	if (self.disabled) {
		return;
	}

	[super orderFront:nil];
}

- (NSRect)defaultWindowFrame
{
	NSRect windowFrame = self.frame;

	windowFrame.size = self.userInterfaceObjects.defaultWindowSize;

	return windowFrame;
}

#pragma mark -
#pragma mark Channel View Box

- (BOOL)multipleItemsSelected
{
	return (self.selectedItems.count > 1);
}

#pragma mark -
#pragma mark Split View

- (BOOL)isMemberListVisible
{
	return (self.contentSplitView.memberListCollapsed == NO);
}

- (BOOL)isServerListVisible
{
	return (self.contentSplitView.serverListCollapsed == NO);
}

#pragma mark -
#pragma mark Server List

- (nullable IRCClient *)selectedClient
{
	if (	   self.selectedItem) {
		return self.selectedItem.associatedClient;
	} else {
		return nil;
	}
}

- (nullable IRCChannel *)selectedChannel
{
	if (	self.selectedItem) {
		if (self.selectedItem.isClient) {
			return nil;
		} else {
			return (id)self.selectedItem;
		}
	} else {
		return nil;
	}
}

- (nullable TVCLogController *)selectedViewController
{
	if (	   self.selectedChannel) {
		return self.selectedChannel.viewController;
	} else if (self.selectedClient) {
		return self.selectedClient.viewController;
	} else {
		return nil;
	}
}

- (nullable IRCTreeItem *)previouslySelectedItem
{
	NSString *itemIdentifier = self.previousSelectedItemId;

	if (itemIdentifier) {
		return [worldController() findItemWithId:itemIdentifier];
	}

	return nil;
}

@end

NS_ASSUME_NONNULL_END
