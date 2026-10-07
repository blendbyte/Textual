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
#import "TVCTextFormatterMenuPrivate.h"
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
#import "TVCMainWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TVCMainWindowAppearanceChangedNotification = @"TVCMainWindowAppearanceChangedNotification";
NSString * const TVCMainWindowRedrawSubviewsNotification = @"TVCMainWindowRedrawSubviewsNotification";

NSString * const TVCMainWindowWillReloadThemeNotification = @"TVCMainWindowWillReloadThemeNotification";
NSString * const TVCMainWindowDidReloadThemeNotification = @"TVCMainWindowDidReloadThemeNotification";

NSString * const TVCMainWindowSelectionChangedNotification = @"TVCMainWindowSelectionChangedNotification";

@interface TVCMainWindow ()
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowChannelView *channelView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryView *titlebarAccessoryView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryViewController *titlebarAccessoryViewController;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowTitlebarAccessoryViewLockButton *titlebarAccessoryViewLockButton;
@property (nonatomic, strong, readwrite) IBOutlet TXMenuControllerMainWindowProxy *mainMenuProxy;
@property (nonatomic, strong, readwrite) IBOutlet TVCTextViewIRCFormattingMenu *formattingMenu;
@property (nonatomic, unsafe_unretained, readwrite) IBOutlet TVCMainWindowTextView *inputTextField;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowSplitView *contentSplitView;
@property (nonatomic, weak, readwrite) IBOutlet TVCMainWindowLoadingScreenView *loadingScreen;
@property (nonatomic, weak, readwrite) IBOutlet TVCMemberList *memberList;
@property (nonatomic, weak, readwrite) IBOutlet TVCServerList *serverList;
@property (nonatomic, strong) TLOInputHistory *inputHistoryManager;
@property (nonatomic, strong) TLONicknameCompletionStatus *nicknameCompletionStatus;
@property (nonatomic, strong, readwrite) TVCMainWindowAppearance *userInterfaceObjects;
@property (nonatomic, readwrite, copy) NSArray *selectedItems;
@property (nonatomic, readwrite, strong, nullable) IRCTreeItem *selectedItem;
@property (nonatomic, copy, nullable) NSArray *previousSelectedItemsId;
@property (nonatomic, copy, nullable) NSString *previousSelectedItemId;
@property (nonatomic, assign) NSTimeInterval lastKeyWindowStateChange;
@property (nonatomic, assign) BOOL lastKeyWindowRedrawFailedBecauseOfOcclusion;
@property (nonatomic, strong) TLOKeyEventHandler *keyEventHandler;
@property (nonatomic, copy, nullable) NSValue *cachedSwipeOriginPoint;
@property (nonatomic, assign, readwrite) double textSizeMultiplier;
@property (nonatomic, assign, readwrite) BOOL reloadingTheme;
@end

#define _treeDragItemType		TVCServerListDragType

#define _treeDragItemTypes		[NSArray arrayWithObject:_treeDragItemType]

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

	[self performSelectorInCommonModes:@selector(toggleFullscreenAfterLaunch) withObject:nil afterDelay:1.0];
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

	self.delegate = (id)self;

	self.selectedItems = nil;
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

	id selectedItem = self.selectedItem;

	if (selectedItem) {
		[selectedItem resetState];
	}

	[TVCDockIcon updateDockIcon];
}

- (void)reloadSubviewDrawings
{
	[RZNotificationCenter() postNotificationName:TVCMainWindowRedrawSubviewsNotification object:self];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowDidChangeScreen:(NSNotification *)notification
{
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

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	self.lastKeyWindowStateChange = [NSDate timeIntervalSince1970];

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

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSMenu *editorMenu = self.inputTextField.menu;

		NSMenuItem *formatterMenu = self.formattingMenu.formatterMenu;

		NSInteger formatterMenuIndex = [editorMenu indexOfItemWithTitle:formatterMenu.title];

		if (formatterMenuIndex < 0) {
			[editorMenu addItem:[NSMenuItem separatorItem]];

			[editorMenu addItem:formatterMenu];
		}

		self.inputTextField.menu = editorMenu;
	});

	return self.inputTextField;
}

#pragma mark -
#pragma mark Keyboard Shortcuts

- (void)setKeyHandlerTarget:(id)target
{
	[self.keyEventHandler setKeyHandlerTarget:target];
}

- (void)registerSelector:(SEL)selector key:(NSUInteger)keyCode modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector key:keyCode modifiers:modifiers];
}

- (void)registerSelector:(SEL)selector character:(UniChar)character modifiers:(NSUInteger)modifiers
{
	[self.keyEventHandler registerSelector:selector character:character modifiers:modifiers];
}

- (void)registerInputSelector:(SEL)selector key:(NSUInteger)keyCode modifiers:(NSUInteger)modifiers
{
	[self.inputTextField registerSelector:selector key:keyCode modifiers:modifiers];
}

- (void)registerInputSelector:(SEL)selector character:(UniChar)character modifiers:(NSUInteger)modifiers
{
	[self.inputTextField registerSelector:selector character:character modifiers:modifiers];
}

- (BOOL)performedCustomKeyboardEvent:(NSEvent *)e
{
	if ([self.keyEventHandler processKeyEvent:e]) {
		return YES;
	}

	return NO;
}

- (void)redirectKeyDown:(NSEvent *)e
{
	[self.inputTextField focus];

	if (e.keyCode == TXKeyEnterCode ||
		e.keyCode == TXKeyReturnCode)
	{
		return;
	}

	[self.inputTextField keyDown:e];
}

- (void)memberListKeyDown:(NSEvent *)e
{
	[self redirectKeyDown:e];
}

- (void)serverListKeyDown:(NSEvent *)e
{
	[self redirectKeyDown:e];
}

- (void)registerKeyHandlers
{
	[self.inputTextField setKeyHandlerTarget:self];

	/* Window keyboard shortcuts */
	[self registerSelector:@selector(exitFullscreenMode:) key:TXKeyEscapeCode modifiers:0];

	[self registerSelector:@selector(tab:) key:TXKeyTabCode modifiers:0];
	[self registerSelector:@selector(shiftTab:)	key:TXKeyTabCode modifiers:NSEventModifierFlagShift];

	[self registerSelector:@selector(selectPreviousSelection:) key:TXKeyTabCode modifiers:NSEventModifierFlagOption];

	[self registerSelector:@selector(textFormattingBold:) character:'b' modifiers:NSEventModifierFlagCommand];
	[self registerSelector:@selector(textFormattingUnderline:) character:'u' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];
	[self registerSelector:@selector(textFormattingItalic:)	character:'i' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];
	[self registerSelector:@selector(textFormattingForegroundColor:) character:'c' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];
	[self registerSelector:@selector(textFormattingBackgroundColor:) character:'h' modifiers:(NSEventModifierFlagControl | NSEventModifierFlagShift)];

	[self registerSelector:@selector(speakPendingNotifications:) character:'.' modifiers:NSEventModifierFlagCommand];

	[self registerSelector:@selector(inputHistoryUp:) character:'p' modifiers:NSEventModifierFlagControl];
	[self registerSelector:@selector(inputHistoryDown:)	character:'n' modifiers:NSEventModifierFlagControl];

	/* Text field keyboard shortcuts */
	[self registerInputSelector:@selector(sendControlEnterMessageMaybe:) key:TXKeyEnterCode modifiers:NSEventModifierFlagControl];

	[self registerInputSelector:@selector(sendMessageAsAction:) key:TXKeyReturnCode modifiers:NSEventModifierFlagCommand];
	[self registerInputSelector:@selector(sendMessageAsAction:) key:TXKeyEnterCode modifiers:NSEventModifierFlagCommand];

	[self registerInputSelector:@selector(focusWebview:) character:'l' modifiers:(NSEventModifierFlagOption | NSEventModifierFlagCommand)];

	[self registerInputSelector:@selector(inputHistoryUpWithScrollCheck:) key:TXKeyUpArrowCode modifiers:0];
	[self registerInputSelector:@selector(inputHistoryUpWithScrollCheck:) key:TXKeyUpArrowCode modifiers:NSEventModifierFlagOption];

	[self registerInputSelector:@selector(inputHistoryDownWithScrollCheck:) key:TXKeyDownArrowCode modifiers:0];
	[self registerInputSelector:@selector(inputHistoryDownWithScrollCheck:) key:TXKeyDownArrowCode modifiers:NSEventModifierFlagOption];
}

#pragma mark -
#pragma mark Navigation

- (void)navigateServerListEntries:(nullable NSArray<IRCTreeItem *> *)scannedRows
					   entryCount:(NSInteger)entryCount
					startingPoint:(NSInteger)startingPoint
					 isMovingDown:(BOOL)isMovingDown
				   navigationType:(TVCServerListNavigationMovementType)navigationType
					selectionType:(TVCServerListNavigationSelectionType)selectionType
{
	NSParameterAssert(entryCount > 0);
	NSParameterAssert(startingPoint >= 0);

	NSInteger currentPosition = startingPoint;

	while (1) {
		/* Move to next selection */
		if (isMovingDown) {
			currentPosition += 1;
		} else {
			currentPosition -= 1;
		}

		/* Make sure selection is within our bounds */
		if (currentPosition >= entryCount || currentPosition < 0) {
			if (isMovingDown == NO && currentPosition < 0) {
				currentPosition = (entryCount - 1);
			} else {
				currentPosition = 0;
			}
		}

		if (currentPosition == startingPoint) {
			break;
		}

		/* Get next selection depending on data source */
		id item;

		if (scannedRows) {
			item = scannedRows[currentPosition];
		} else {
			item = [self.serverList itemAtRow:currentPosition];
		}

		/* Skip entries depending on navigation type */
		if (selectionType == TVCServerListNavigationSelectionTypeChannel)
		{
			if ([item isChannel] == NO && [item isPrivateMessage] == NO) {
				continue;
			}
		}
		else if (selectionType == TVCServerListNavigationSelectionTypeServer)
		{
			if ([item isClient] == NO) {
				continue;
			}
		}

		/* Select current item if it is matched by our condition */
		if (navigationType == TVCServerListNavigationMovementTypeAll)
		{
			[self select:item];

			break;
		}
		else if (navigationType == TVCServerListNavigationMovementTypeActive)
		{
			if ([item isActive]) {
				[self select:item];

				break;
			}
		}
		else if (navigationType == TVCServerListNavigationMovementTypeUnread)
		{
			if ([item isUnread]) {
				[self select:item];

				break;
			}
		}
	}
}

- (void)navigateChannelEntries:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	if ([TPCPreferences channelNavigationIsServerSpecific]) {
		[self navigateChannelEntriesWithinServerScope:isMovingDown withNavigationType:navigationType];
	} else {
		[self navigateChannelEntriesOutsideServerScope:isMovingDown withNavigationType:navigationType];
	}
}

- (void)navigateChannelEntriesOutsideServerScope:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	NSInteger entryCount = self.serverList.numberOfRows;

	NSInteger startingPoint = [self.serverList rowForItem:self.selectedItem];

	[self navigateServerListEntries:nil
						 entryCount:entryCount
					  startingPoint:startingPoint
					   isMovingDown:isMovingDown
					 navigationType:navigationType
					  selectionType:TVCServerListNavigationSelectionTypeChannel];
}

- (void)navigateChannelEntriesWithinServerScope:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	NSArray *scannedRows = [self.serverList itemsFromParentGroup:self.selectedItem];

	/* We add selected server so navigation falls within its scope if its the selected item */
	scannedRows = [scannedRows arrayByAddingObject:self.selectedClient];

	[self navigateServerListEntries:scannedRows
						 entryCount:scannedRows.count
					  startingPoint:[scannedRows indexOfObject:self.selectedItem]
					   isMovingDown:isMovingDown
					 navigationType:navigationType
					  selectionType:TVCServerListNavigationSelectionTypeChannel];
}

- (void)navigateServerEntries:(BOOL)isMovingDown withNavigationType:(TVCServerListNavigationMovementType)navigationType
{
	NSArray *scannedRows = self.serverList.groupItems;

	[self navigateServerListEntries:scannedRows
						 entryCount:scannedRows.count
					  startingPoint:[scannedRows indexOfObject:self.selectedClient]
					   isMovingDown:isMovingDown
					 navigationType:navigationType
					  selectionType:TVCServerListNavigationSelectionTypeServer];
}

- (void)navigateToNextEntry:(BOOL)isMovingDown
{
	NSInteger entryCount = self.serverList.numberOfRows;

	NSInteger startingPoint = [self.serverList rowForItem:self.selectedItem];

	[self navigateServerListEntries:nil
						 entryCount:entryCount
					  startingPoint:startingPoint
					   isMovingDown:isMovingDown
					 navigationType:TVCServerListNavigationMovementTypeAll
					  selectionType:TVCServerListNavigationSelectionTypeAny];
}

- (void)selectPreviousChannel:(NSEvent *)e
{
	[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectNextChannel:(NSEvent *)e
{
	[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectPreviousUnreadChannel:(NSEvent *)e
{
	[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeUnread];
}

- (void)selectNextUnreadChannel:(NSEvent *)e
{
	[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeUnread];
}

- (void)selectPreviousActiveChannel:(NSEvent *)e
{
	[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectNextActiveChannel:(NSEvent *)e
{
	[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectPreviousServer:(NSEvent *)e
{
	[self navigateServerEntries:NO withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectNextServer:(NSEvent *)e
{
	[self navigateServerEntries:YES withNavigationType:TVCServerListNavigationMovementTypeAll];
}

- (void)selectPreviousActiveServer:(NSEvent *)e
{
	[self navigateServerEntries:NO withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectNextActiveServer:(NSEvent *)e
{
	[self navigateServerEntries:YES withNavigationType:TVCServerListNavigationMovementTypeActive];
}

- (void)selectPreviousSelection:(NSEvent *)e
{
	[self selectPreviousItem];
}

- (void)selectNextWindow:(NSEvent *)e
{
	[self navigateToNextEntry:YES];
}

- (void)selectPreviousWindow:(NSEvent *)e
{
	[self navigateToNextEntry:NO];
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

- (void)markAllAsReadInGroup:(nullable IRCTreeItem *)item
{
	BOOL markScrollback = [TPCPreferences autoAddScrollbackMark];

	for (IRCClient *u in worldController().clientList) {
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
#pragma mark Actions

- (void)completeNickname:(BOOL)movingForward
{
	[self.nicknameCompletionStatus completeNickname:movingForward];
}

- (void)tab:(NSEvent *)e
{
	TXTabKeyAction tabKeyAction = [TPCPreferences tabKeyAction];

	if (tabKeyAction == TXTabKeyActionNicknameComplete) {
		[self completeNickname:YES];
	} else if (tabKeyAction == TXTabKeyActionUnreadChannel) {
		[self navigateChannelEntries:YES withNavigationType:TVCServerListNavigationMovementTypeUnread];
	}
}

- (void)shiftTab:(NSEvent *)e
{
	TXTabKeyAction tabKeyAction = [TPCPreferences tabKeyAction];

	if (tabKeyAction == TXTabKeyActionNicknameComplete) {
		[self completeNickname:NO];
	} else if (tabKeyAction == TXTabKeyActionUnreadChannel) {
		[self navigateChannelEntries:NO withNavigationType:TVCServerListNavigationMovementTypeUnread];
	}
}

- (void)sendControlEnterMessageMaybe:(NSEvent *)e
{
	if ([TPCPreferences controlEnterSendsMessage]) {
		[self textEntered];

		return;
	}

	[self.inputTextField keyDownToSuper:e];
}

- (void)sendMessageAsAction:(NSEvent *)e
{
	if ([TPCPreferences commandReturnSendsMessageAsAction]) {
		[self inputTextAsCommand:IRCRemoteCommandPrivmsgAction];

		return;
	}

	[self textEntered];
}

- (void)moveInputHistory:(BOOL)movingUp checkScroller:(BOOL)checkScroller event:(NSEvent *)event
{
	if (checkScroller) {
		TVCTextViewCaretLocation caretLocation = self.inputTextField.caretLocation;

		if (caretLocation != TVCTextViewCaretLocationOnlyLine) {
			BOOL atTop = (caretLocation == TVCTextViewCaretLocationFirstLine);
			BOOL atBottom = (caretLocation == TVCTextViewCaretLocationLastLine);

			if ((atTop			&& event.keyCode == TXKeyDownArrowCode) ||
				(atBottom		&& event.keyCode == TXKeyUpArrowCode) ||
				(atTop == NO	&& atBottom == NO))
			{
				[self.inputTextField keyDownToSuper:event];

				return;
			}
		}
	}

	NSAttributedString *stringValue = self.inputTextField.attributedStringValue;

	if (movingUp) {
		stringValue = [self.inputHistoryManager up:stringValue];
	} else {
		stringValue = [self.inputHistoryManager down:stringValue];
	}

	if (stringValue == nil) {
		return;
	}

	self.inputTextField.attributedStringValue = stringValue;

	[self.inputTextField focus];

	if (movingUp == NO) {
		self.inputTextField.selectedRange = NSMakeRange(0, 0);
	}
}

- (void)inputHistoryUp:(NSEvent *)e
{
	[self moveInputHistory:YES checkScroller:NO event:e];
}

- (void)inputHistoryDown:(NSEvent *)e
{
	[self moveInputHistory:NO checkScroller:NO event:e];
}

- (void)inputHistoryUpWithScrollCheck:(NSEvent *)e
{
	[self moveInputHistory:YES checkScroller:YES event:e];
}

- (void)inputHistoryDownWithScrollCheck:(NSEvent *)e
{
	[self moveInputHistory:NO checkScroller:YES event:e];
}

- (void)textFormattingBold:(NSEvent *)e
{
	if (self.formattingMenu.textIsBold) {
		[self.formattingMenu removeBoldCharFromTextBox:nil];
	} else {
		[self.formattingMenu insertBoldCharIntoTextBox:nil];
	}
}

- (void)textFormattingItalic:(NSEvent *)e
{
	if (self.formattingMenu.textIsItalicized) {
		[self.formattingMenu removeItalicCharFromTextBox:nil];
	} else {
		[self.formattingMenu insertItalicCharIntoTextBox:nil];
	}
}

- (void)textFormattingStrikethrough:(NSEvent *)e
{
	if (self.formattingMenu.textIsStruckthrough) {
		[self.formattingMenu removeStrikethroughCharFromTextBox:nil];
	} else {
		[self.formattingMenu insertStrikethroughCharIntoTextBox:nil];
	}
}

- (void)textFormattingUnderline:(NSEvent *)e
{
	if (self.formattingMenu.textIsUnderlined) {
		[self.formattingMenu removeUnderlineCharFromTextBox:nil];
	} else {
		[self.formattingMenu insertUnderlineCharIntoTextBox:nil];
	}
}

- (void)textFormattingForegroundColor:(NSEvent *)e
{
	if (self.formattingMenu.textHasSpoiler) {
		return;
	}

	if (self.formattingMenu.textHasForegroundColor) {
		[self.formattingMenu removeForegroundColorCharFromTextBox:nil];

		return;
	}

	NSRect textFieldFrame = self.inputTextField.frame;

	textFieldFrame.origin.y -= 200;
	textFieldFrame.origin.x += 100;

	[self.formattingMenu.foregroundColorMenu popUpMenuPositioningItem:nil atLocation:textFieldFrame.origin inView:self.inputTextField];
}

- (void)textFormattingBackgroundColor:(NSEvent *)e
{
	if (self.formattingMenu.textHasSpoiler) {
		return;
	}

	if (self.formattingMenu.textHasForegroundColor == NO) {
		return;
	}

	if (self.formattingMenu.textHasBackgroundColor) {
		[self.formattingMenu removeForegroundColorCharFromTextBox:nil];

		return;
	}

	NSRect textFieldFrame = self.inputTextField.frame;

	textFieldFrame.origin.y -= 200;
	textFieldFrame.origin.x += 100;

	[self.formattingMenu.backgroundColorMenu popUpMenuPositioningItem:nil atLocation:textFieldFrame.origin inView:self.inputTextField];
}

- (void)exitFullscreenMode:(NSEvent *)e // escape key
{
	if (self.inFullscreenMode) {
		[self toggleFullScreen:nil];

		return;
	}

	[self.inputTextField keyDown:e];
}

- (void)speakPendingNotifications:(NSEvent *)e
{
	[[TXSharedApplication sharedSpeechSynthesizer] stopSpeakingAndMoveForward];
}

- (void)focusWebview:(NSEvent *)e
{
	if (self.attachedSheet != nil) {
		return;
	}

	TVCLogController *viewController = self.selectedViewController;

	if (viewController == nil) {
		return;
	}

	NSView *webView = viewController.backingView.webView;

	[self makeFirstResponder:webView];
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
#pragma mark Swipe Events

/* Three Finger Swipe Event
	This event will only work if 
		System Settings -> Trackpad -> More Gestures -> Swipe between full-screen apps
	is not set to "Swipe left or right with three fingers"
 */
- (void)swipeWithEvent:(NSEvent *)event
{
	CGFloat x = event.deltaX;

	BOOL invertedScrollingDirection = [RZUserDefaults() boolForKey:@"com.apple.swipescrolldirection"];

	if (invertedScrollingDirection) {
		x = (x * (-1));
	}

	if (x > 0) {
		[self selectNextWindow:nil];
	} else if (x < 0) {
		[self selectPreviousWindow:nil];
	}
}

- (void)beginGestureWithEvent:(NSEvent *)event
{
	CGFloat swipeMinimumLength = [TPCPreferences swipeMinimumLength];

	if (swipeMinimumLength < 1.0) {
		return;
	}

	NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:nil];

	if (touches.count != 2) {
		return;
	}

	NSArray *touchArray = touches.allObjects;

	self.cachedSwipeOriginPoint = [self touchesToPoint:touchArray[0] fingerB:touchArray[1]];
}

- (NSValue *)touchesToPoint:(NSTouch *)fingerA fingerB:(NSTouch *)fingerB
{
	NSParameterAssert(fingerA != nil);
	NSParameterAssert(fingerB != nil);

	NSSize deviceSize = fingerA.deviceSize;

	CGFloat x = ((fingerA.normalizedPosition.x + fingerB.normalizedPosition.x) / 2.0 * deviceSize.width);
	CGFloat y = ((fingerA.normalizedPosition.y + fingerB.normalizedPosition.y) / 2.0 * deviceSize.height);

	return [NSValue valueWithPoint:NSMakePoint(x, y)];
}

- (void)endGestureWithEvent:(NSEvent *)event
{
	CGFloat swipeMinimumLength = [TPCPreferences swipeMinimumLength];

	if (swipeMinimumLength < 1.0) {
		return;
	}

	NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];

	if (self.cachedSwipeOriginPoint == nil || touches.count != 2) {
		self.cachedSwipeOriginPoint = nil;

		return;
	}

	NSArray *touchArray = touches.allObjects;

	NSPoint origin = self.cachedSwipeOriginPoint.pointValue;

	NSPoint destination = [self touchesToPoint:touchArray[0] fingerB:touchArray[1]].pointValue;

	self.cachedSwipeOriginPoint = nil;

	NSPoint delta = NSMakePoint((origin.x - destination.x),
								(origin.y - destination.y));

	if (fabs(delta.y) > fabs(delta.x)) {
		return;
	}

	if (fabs(delta.x) < swipeMinimumLength) {
		return;
	}

	CGFloat x = delta.x;

	BOOL invertedScrollingDirection = [RZUserDefaults() boolForKey:@"com.apple.swipescrolldirection"];

	if (invertedScrollingDirection) {
		x = (x * (-1));
	}

	if (x > 0) {
		[self selectPreviousWindow:nil];
	} else {
		[self selectNextWindow:nil];
	}
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

- (void)channelViewSelectionChangeTo:(IRCTreeItem *)selectedItem
{
	[self selectItemInSelectedItems:selectedItem refreshChannelView:NO];
}

- (void)updateChannelViewArrangement
{
	[self.channelView updateArrangement];
}

- (void)updateChannelViewBoxContentViewSelection
{
	[self.channelView populateSubviews];
}

- (BOOL)isItemVisible:(IRCTreeItem *)item
{
	if (item == nil) {
		return NO;
	}

	return ([self isItemSelected:item] || [self isItemInSelectedGroup:item]);
}

- (BOOL)isItemSelected:(IRCTreeItem *)item
{
	if (item == nil) {
		return NO;
	}

	return (self.selectedItem == item);
}

- (BOOL)isItemInSelectedGroup:(IRCTreeItem *)item
{
	if (item == nil) {
		return NO;
	}

	return ([self.selectedItems containsObject:item]);
}

- (void)selectionDidChangeToRows:(NSIndexSet *)selectedRows
{
	[self selectionDidChangeToRows:selectedRows selectedItem:nil];
}

- (void)selectionDidChangeToRows:(NSIndexSet *)selectedRows selectedItem:(nullable IRCTreeItem *)selectedItem
{
	NSParameterAssert(selectedRows != nil);

	/* Create list of selected items and notify those newly selected items
	 that they are now visible + part of a stacked view */
	NSArray *selectedItems = self.serverList.selectedObjects;

	/* Update selected item even if group hasn't changed */
	if ([selectedItems isEqualToArray:self.selectedItems]) { /* Update selected item even if group hasn't changed */
		if (selectedItem) {
			[self selectItemInSelectedItems:selectedItem];
		}

		return;
	}

	NSUInteger selectedItemsCount = selectedItems.count;

	/* Store previous selection */
	[self storePreviousSelection];

	/* Update properties */
	NSArray *selectedItemsPrevious = nil;

	if (self.selectedItems) {
		selectedItemsPrevious = [self.selectedItems copy];
	}

	if (selectedItemsCount > 0) {
		self.selectedItems = selectedItems;

		if (selectedItem == nil) {
			selectedItem = self.selectedItem;
		}

		if (selectedItem && [self isItemInSelectedGroup:selectedItem]) {
			self.selectedItem = selectedItem;
		} else {
			self.selectedItem = selectedItems[(selectedItemsCount - 1)];
		}
	} else {
		self.selectedItem = nil;
		self.selectedItems = @[];
	}

	/* Update split view */
	[self updateChannelViewBoxContentViewSelection];

	/* Inform views that are currently selected that no longer will be that they
	 are now hidden. We wait until after -updateChannelViewBoxContentViewSelection
	 is called to do this so that the views that are hidden are actually hidden
	 before informing the views of this fact. */
	for (IRCTreeItem *item in selectedItemsPrevious) {
		if (selectedItems == nil || [selectedItems containsObject:item] == NO) {
			[item.viewController notifyDidBecomeHidden];
		}
	}

	/* Inform new views that they are visible now that they are visible. */
	for (IRCTreeItem *item in selectedItems) {
		if (selectedItemsPrevious == nil || [selectedItemsPrevious containsObject:item] == NO) {
			[item.viewController notifyDidBecomeVisible];

			if (item != self.selectedItem) {
				[item.viewController notifySelectionChanged];
			}
		}
	}

	selectedItems = nil;
	selectedItemsPrevious = nil;

	/* Perform postflight routines */
	[self selectionDidChangePostflight];
}

- (void)selectionDidChangePostflight
{
	/* If the selection hasn't changed, then do nothing. */
	IRCTreeItem *itemChangedTo = self.selectedItem;

	IRCTreeItem *itemChangedFrom = self.previouslySelectedItem;

	if (itemChangedTo == itemChangedFrom) {
		return;
	}

	/* Reset state of selections */
	if (itemChangedFrom) {
		[itemChangedFrom resetState];
	}

	if (itemChangedTo) {
		if (self.multipleItemsSelected) {
			[self.serverList refreshMessageCountForItem:itemChangedTo];
		}

		[itemChangedTo resetState];
	}

	/* Notify WebKit its selection status has changed */
	if (itemChangedFrom) {
		[itemChangedFrom.viewController notifySelectionChanged];
	}

	/* Destroy member list if we have no selection */
	if (itemChangedTo == nil) {
		[self.memberList assignToChannel:nil];

		self.serverList.menu = nil;

		[self updateTitle];

		return; // Nothing more to do for empty selections
	}

	/* Prepare the member list for the selection */
	BOOL isClient = itemChangedTo.isClient;

	BOOL isChannel = itemChangedTo.isChannel;

	/* The right click menu follows selection so let's update
	 the menu we will show depending on the selection. */
	if (isClient) {
		self.serverList.menu = menuController().mainMenuServerMenuItem.submenu;
	} else if (isChannel) {
		self.serverList.menu = menuController().mainMenuChannelMenu;
	} else {
		self.serverList.menu = menuController().mainMenuQueryMenu;
	}

	/* Update table view data sources */
	if (isChannel) {
		[self.memberList assignToChannel:(id)itemChangedTo];
	} else {
		[self.memberList assignToChannel:nil];
	}

	/* Begin work on text field */
	BOOL autoFocusInputTextField = [TPCPreferences focusMainTextViewOnSelectionChange];

	if (autoFocusInputTextField && [XRAccessibility isVoiceOverEnabled] == NO) {
		[self.inputTextField focus];
	}

	[self.inputTextField updateSegmentedController];

	/* Setup text field value with history item when we have
	 history setup to be channel specific. */
	[self.inputHistoryManager moveFocusTo:itemChangedTo];

	/* Reset spelling for text field */
	[self.inputTextField resetSpellingIgnores];

	/* Update splitter view depending on selection */
	if (isChannel) {
		if (self.memberList.isHiddenByUser == NO) {
			[self.contentSplitView expandMemberList];
		}
	} else {
		[self.contentSplitView collapseMemberList];
	}

	/* Notify WebKit its selection status has changed */
	[itemChangedTo.viewController notifySelectionChanged];

	/* Finish up */
	[self storeLastSelectedChannel];

	[RZNotificationCenter() postNotificationName:TVCMainWindowSelectionChangedNotification object:self];

	[TVCDockIcon updateDockIcon];

	[self updateTitle];
}

#pragma mark -
#pragma mark Split View

- (void)saveContentSplitViewState
{
	[RZUserDefaults() setBool:self.serverListVisible
					   forKey:@"Window -> Main Window -> Server List is Visible"];

	[RZUserDefaults() setBool:(self.memberList.isHiddenByUser == NO)
					   forKey:@"Window -> Main Window -> Member List is Visible"];
}

- (void)restoreSavedContentSplitViewState
{
	/* Make server list and member list visible + restore saved position. */
	[self.contentSplitView restorePositions];

	/* Collapse one or more items if they were collapsed when closing Textual. */
	id makeMemberListVisible = [RZUserDefaults() objectForKey:@"Window -> Main Window -> Member List is Visible"];

	if (makeMemberListVisible && [makeMemberListVisible boolValue] == NO) {
		self.memberList.isHiddenByUser = YES;

		[self.contentSplitView collapseMemberList];
	}

	id makeServerListVisible = [RZUserDefaults() objectForKey:@"Window -> Main Window -> Server List is Visible"];

	if (makeServerListVisible && [makeServerListVisible boolValue] == NO) {
		[self.contentSplitView collapseServerList];
	}
}

- (BOOL)isMemberListVisible
{
	return (self.contentSplitView.memberListCollapsed == NO);
}

- (BOOL)isServerListVisible
{
	return (self.contentSplitView.serverListCollapsed == NO);
}

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

- (void)presentCertificateTrustInformation:(id)sender
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

- (void)updateTitleFor:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if ([self isItemSelected:item] == NO) {
		return;
	}

	[self updateTitle];
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

	self.title = title;

	[self setAccessibilityTitle:TXTLS(@"Accessibility[k79-1a]")];
}

#pragma mark -
#pragma mark User List

- (void)updateDrawingForUserInUserList:(IRCUser *)user
{
	IRCChannel *selectedChannel = self.selectedChannel;

	if (selectedChannel == nil) {
		return;
	}

	IRCChannelUser *channelUser = [user userAssociatedWithChannel:selectedChannel];

	if (channelUser == nil) {
		return;
	}

	[self.memberList refreshDrawingForMember:channelUser];
}

#pragma mark -
#pragma mark Server List

- (void)saveSelection
{
	NSMutableArray<NSString *> *selectedIdentifiers = [NSMutableArray array];

	for (IRCTreeItem *item in self.selectedItems) {
		[selectedIdentifiers addObject:item.uniqueIdentifier];
	}

	[RZUserDefaults() setObject:[selectedIdentifiers copy]
						 forKey:@"Window -> Main Window -> Server List Selection"];
}

- (void)restoreExpandedClients
{
	for (IRCClient *e in worldController().clientList) {
		if (e.config.sidebarItemExpanded) {
			[self expandClient:e];
		}
	}
}

- (void)restoreSelectionDuringSetup
{
	NSArray *selectedIdentifiers = [RZUserDefaults() objectForKey:@"Window -> Main Window -> Server List Selection"];

	if (selectedIdentifiers == nil || selectedIdentifiers.count == 0) {
		[self selectBestChoiceDuringSetup];

		return;
	}

	NSArray *selection = [worldController() findItemsWithIds:selectedIdentifiers];

	if (selection.count == 0) {
		[self selectBestChoiceDuringSetup];

		return;
	}

	[self adjustSelectionWithItems:selection selectedItem:nil];
}

- (void)selectBestChoiceDuringSetup
{
	IRCClient *firstSelection = nil;

	for (IRCClient *e in worldController().clientList) {
		if (e.config.autoConnect && e.config.sidebarItemExpanded) {
			if (firstSelection == nil) {
				firstSelection = e;
			}
		}
	}

	if (firstSelection) {
		NSInteger n = [self.serverList rowForItem:firstSelection];

		if (firstSelection.channelCount > 0) {
			n++;
		}

		[self.serverList selectItemAtIndex:n];
	} else {
		[self.serverList selectItemAtIndex:0];
	}
}

- (void)setupTrees
{
	self.memberList.keyDelegate = self;

	self.memberList.target = menuController();
	self.memberList.doubleAction = @selector(memberInMemberListDoubleClicked:);

	self.serverList.keyDelegate = self;

	self.serverList.delegate = (id)self;
	self.serverList.dataSource = (id)self;

	self.serverList.target = self;
	self.serverList.doubleAction = @selector(outlineViewDoubleClicked:);

	/* Inform the table we want drag events */
	[self.serverList registerForDraggedTypes:_treeDragItemTypes];

	/* Prepare our first selection */
	[self restoreExpandedClients];

	[self restoreSelectionDuringSetup];

	/* Fake the delegate call */
	[self outlineViewSelectionDidChange:nil];

	/* Populate navigation list */
	[menuController() populateNavigationChannelList];
}

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

- (nullable IRCChannel *)selectedChannelOn:(IRCClient *)c
{
	if (self.selectedClient == c) {
		return self.selectedChannel;
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

- (void)reloadTreeItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	[self.serverList refreshDrawingForItem:item];
}

- (void)reloadTreeGroup:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if (item.isClient == NO) {
		return;
	}

	[self reloadTreeItem:item];

	for (IRCChannel *channel in ((IRCClient *)item).channelList) {
		[self reloadTreeItem:channel];
	}
}

- (void)reloadTree
{
	[self.serverList refreshAllDrawings];
}

- (void)expandClient:(IRCClient *)client
{
	[[self.serverList animator] expandItem:client];
}

- (void)adjustSelection
{
	[self adjustSelectionWithItems:self.selectedItems selectedItem:self.selectedItem];
}

- (void)adjustSelectionWithItems:(NSArray<IRCTreeItem *> *)selectedItems selectedItem:(nullable IRCTreeItem *)selectedItem
{
	NSParameterAssert(selectedItems != nil);

	NSMutableIndexSet *itemRows = [NSMutableIndexSet indexSet];

	for (IRCTreeItem *item in selectedItems) {
		/* Expand the parent of the item if its not already expanded. */
		if (item.isClient == NO) {
			IRCClient *itemClient = item.associatedClient;

			[self.serverList expandItem:itemClient];
		}

		/* Find the row of the item */
		NSInteger itemRow = [self.serverList rowForItem:item];

		if ( itemRow >= 0) {
			[itemRows addIndex:itemRow];
		}
	}

	/* If the selected rows have not changed, then only select the one item */
	NSIndexSet *selectedRows = self.serverList.selectedRowIndexes;

	if ([selectedRows isEqualToIndexSet:itemRows] == NO) {
		/* Selection updates are disabled and selection changes are faked so that
		 the correct next item is selected when moving to previous group. */
		self.ignoreNextOutlineViewSelectionChange = YES;

		[self.serverList selectRowIndexes:itemRows
					 byExtendingSelection:NO
						scrollToSelection:YES];
	}

	/* Perform selection logic */
	[self selectionDidChangeToRows:itemRows selectedItem:selectedItem];
}

- (void)storePreviousSelection
{
	self.previousSelectedItemId = self.selectedItem.uniqueIdentifier;

	[self storePreviousSelections];
}

- (void)storePreviousSelections
{
	NSMutableArray<NSString *> *previousSelectedItems = [NSMutableArray array];

	for (IRCTreeItem *item in self.selectedItems) {
		[previousSelectedItems addObject:item.uniqueIdentifier];
	}

	self.previousSelectedItemsId = previousSelectedItems;
}

- (void)storeLastSelectedChannel
{
	if (self.selectedClient) {
		self.selectedClient.lastSelectedChannel = self.selectedChannel;
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

- (void)selectPreviousItem
{
	/* Do not try to browse backwards without these items */
	if (self.previousSelectedItemId == nil ||
		self.previousSelectedItemsId == nil)
	{
		return;
	}

	/* Get previously selected item and cancel if its missing */
	IRCTreeItem *itemPrevious = self.previouslySelectedItem;

	if (itemPrevious == nil) {
		return;
	}

	/* Build list of rows in the table view that contain previous group */
	NSMutableArray<IRCTreeItem *> *itemsPrevious = [NSMutableArray array];

	for (NSString *itemIdentifier in self.previousSelectedItemsId) {
		IRCTreeItem *item = [worldController() findItemWithId:itemIdentifier];

		if ( item) {
			[itemsPrevious addObject:item];
		}
	}

	[self adjustSelectionWithItems:itemsPrevious selectedItem:itemPrevious];
}

- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem
{
	[self selectItemInSelectedItems:selectedItem refreshChannelView:YES];
}

- (void)selectItemInSelectedItems:(IRCTreeItem *)selectedItem refreshChannelView:(BOOL)refreshChannelView
{
	NSParameterAssert(selectedItem != nil);

	/* Do nothing if items are the same */
	if ([self isItemSelected:selectedItem]) {
		return;
	}

	/* Select item if its in the current group */
	if ([self isItemInSelectedGroup:selectedItem] == NO) {
		return;
	}

	[self storePreviousSelection];

	self.selectedItem = selectedItem;

	if (refreshChannelView) {
		[self updateChannelViewBoxContentViewSelection];
	}

	[self selectionDidChangePostflight];
}

- (void)select:(nullable IRCTreeItem *)item
{
	[self shiftSelection:self.selectedItem
				  toItem:item
				 options:(TVCMainWindowShiftSelectionFlagMaintainGrouping |
						  TVCMainWindowShiftSelectionFlagPerformDeselect)];
}

- (void)deselect:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	[self shiftSelection:item
				  toItem:nil
				 options:TVCMainWindowShiftSelectionFlagPerformDeselect];
}

- (void)deselectGroup:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if (item.isClient == NO) {
		return;
	}

	[self shiftSelection:item
				  toItem:nil
				 options:(TVCMainWindowShiftSelectionFlagPerformDeselect |
						  TVCMainWindowShiftSelectionFlagPerformDeselectChildren)];
}

- (void)shiftSelection:(nullable IRCTreeItem *)oldItem toItem:(nullable IRCTreeItem *)newItem options:(TVCMainWindowShiftSelectionFlags)selectionOptions
{
	if (oldItem == newItem) {
		return;
	}

	/* If the next item is a channel, then make sure the client
	 it is associated with is expanded, or we can't switch to it. */
	if (newItem && newItem.isClient == NO) {
		IRCClient *itemClient = newItem.associatedClient;

		[self expandClient:itemClient];
	}

	/* Context */
	BOOL optionMaintainGrouping = ((selectionOptions & TVCMainWindowShiftSelectionFlagMaintainGrouping) == TVCMainWindowShiftSelectionFlagMaintainGrouping);

	BOOL optionPerformDeselectAll = NO;
	BOOL optionPerformDeselectOld = ((selectionOptions & TVCMainWindowShiftSelectionFlagPerformDeselect) == TVCMainWindowShiftSelectionFlagPerformDeselect);
	BOOL optionPerformDeselectChildren = ((selectionOptions & TVCMainWindowShiftSelectionFlagPerformDeselectChildren) == TVCMainWindowShiftSelectionFlagPerformDeselectChildren);

	BOOL optionPerformDeselect = (optionPerformDeselectChildren || optionPerformDeselectOld);

	/* Do nothing if item is not group */
	NSInteger itemIndexOld = [self.serverList rowForItem:oldItem];
	NSInteger itemIndexNew = [self.serverList rowForItem:newItem];

	NSIndexSet *selectedRows = self.serverList.selectedRowIndexes;

	NSIndexSet *selectedRowsForbidden = nil;

	/* Maybe do nothing at all */
	if (optionPerformDeselect && itemIndexOld >= 0 && [selectedRows containsIndex:itemIndexOld] == NO) {
		return;
	}

	/* If we are not performing a deselect for the old item and both items
	 are selected, then simply update selection inside grouping. */
	if (optionMaintainGrouping &&
		(itemIndexOld >= 0 && [selectedRows containsIndex:itemIndexOld]) &&
		(itemIndexNew >= 0 && [selectedRows containsIndex:itemIndexNew]) &&
		newItem != nil) // This condition is impossible but static analyzer doesn't know that.
						// Condition is impossible because itemIndexNew will never return
						// greater to or equal zero unless item is non-nil.
	{
		[self selectItemInSelectedItems:newItem];

		return;
	} else {
		if (optionPerformDeselectOld) {
			optionPerformDeselectAll = YES;
		}
	}

	/* Create a mutable copy of the current selection */
	NSMutableIndexSet *selectedRowsNew = [selectedRows mutableCopy];

	if (optionPerformDeselectAll) {
		[selectedRowsNew removeAllIndexes];
	} else if (optionPerformDeselectOld) {
		[selectedRowsNew removeIndex:itemIndexOld];
	}

	/* optionPerformDeselectChildren is still performed even if optionPerformDeselectAll
	 is set so that the list of forbidden rows can be defined by it. */
	if (optionPerformDeselectChildren) {
		NSIndexSet *childrenRowRange = [self.serverList indexesOfItemsInGroup:oldItem];

		if (childrenRowRange) {
			[selectedRowsNew removeIndexes:childrenRowRange];

			selectedRowsForbidden = childrenRowRange;
		}
	}

	/* If the next item is not nil and is a row, then select that */
	if (newItem) {
		if (itemIndexNew >= 0) {
			[selectedRowsNew addIndex:itemIndexNew];
		} else {
			LogToConsoleDebug("Tried to shift selection to an item not in the server list");

			return;
		}
	}

	/* If no item to switch to is specified, then the current action is 
	 treated as a deselect for the old item. In that case, we pick the 
	 next best item to remain selected. */
	if (newItem == nil) {
		/* If there is an item in the current selection that is before 
		 or after the row removed, then we can use that. */
		BOOL selectedRowsComplete =
		([selectedRowsNew indexLessThanIndex:itemIndexOld] != NSNotFound ||
		 [selectedRowsNew indexGreaterThanIndex:itemIndexOld] != NSNotFound);

		/* If there is not an item in the current selection that can take over,
		 then the first step is to try to find an item newer than the current. */
		if (selectedRowsComplete == NO) {
			NSInteger numberOfRows = self.serverList.numberOfRows;

			NSInteger nextSelectionRow = (itemIndexOld + 1);

			/* Next row is in forbidden range */
			if (selectedRowsForbidden && [selectedRowsForbidden containsIndex:nextSelectionRow]) {
				nextSelectionRow = (selectedRowsForbidden.lastIndex + 1);
			}

			/* Next row is above number of rows. Try to go one below instead. */
			if (nextSelectionRow >= numberOfRows) {
				nextSelectionRow = (itemIndexOld - 1);
			}

			/* Previous row is in forbidden range */
			if (selectedRowsForbidden && [selectedRowsForbidden containsIndex:nextSelectionRow]) {
				nextSelectionRow = (selectedRowsForbidden.firstIndex - 1);
			}

			/* Previous row is less than zero. There is no where else to go. */
			if (nextSelectionRow < 0) {
				nextSelectionRow = (-1);
			}

			/* Add new selection index if there is one. */
			if (nextSelectionRow >= 0) {
				[selectedRowsNew addIndex:nextSelectionRow];
			}
		}
	}

	/* Save selection */
	if (selectedRowsNew.count == 0) {
		[self storePreviousSelection];

		self.selectedItem = nil;
		self.selectedItems = @[];

		[self selectionDidChangePostflight];

		return;
	}

	[self.serverList selectRowIndexes:selectedRowsNew
				 byExtendingSelection:NO
					scrollToSelection:YES];
}

#pragma mark -
#pragma mark Server List Delegate

- (void)outlineViewDoubleClicked:(id)sender
{
	IRCClient *u = self.selectedClient;
	IRCChannel *c = self.selectedChannel;

	if (u == nil && c == nil) {
		return;
	}

	if (u && c == nil)
	{
		if (u.isConnecting || u.isConnected)
		{
			if ([TPCPreferences disconnectOnDoubleclick]) {
				[u quit];
			}
		}
		else if (u.isQuitting)
		{
			LogToConsole("Double click event ignored because client is quitting");
		}
		else
		{
			if ([TPCPreferences connectOnDoubleclick]) {
				[u connect];
			}
		}

		[self expandClient:u];
	}
	else
	{
		if (u.isLoggedIn == NO) {
			return;
		}

		if (c.isActive)
		{
			if ([TPCPreferences leaveOnDoubleclick]) {
				[u partChannel:c];
			}
		}
		else
		{
			if ([TPCPreferences joinOnDoubleclick]) {
				[u joinChannel:c];
			}
		}
	}
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item
{
	if (item) {
		return [item numberOfChildren];
	}

	return worldController().clientCount;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return ([item numberOfChildren] > 0);
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	if (item) {
		return [item childAtIndex:index];
	}

	return worldController().clientList[index];
}

- (nullable id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable id)item
{
	return item;
}

- (nullable NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
	if (item == nil || [item isClient]) {
		return [[TVCServerListGroupRowCell alloc] initWithServerList:(id)outlineView];
	} else {
		return [[TVCServerListChildRowCell alloc] initWithServerList:(id)outlineView];
	}
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
	NSString *viewIdentifier = nil;

	if (item == nil || [item isClient]) {
		viewIdentifier = @"GroupView";
	} else {
		viewIdentifier = @"ChildView";
	}

	NSView *newView = [outlineView makeViewWithIdentifier:viewIdentifier owner:self];

	return newView;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	[self.serverList refreshDrawingForRow:row];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	id itemBeingCollapsed = notification.userInfo[@"NSObject"];

	IRCClient *u = [itemBeingCollapsed associatedClient];

	u.sidebarItemIsExpanded = NO;
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	id itemBeingCollapsed = notification.userInfo[@"NSObject"];

	IRCClient *u = [itemBeingCollapsed associatedClient];

	u.sidebarItemIsExpanded = YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	return YES;
}

- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{

}

- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView
{
	TVCServerList *serverList = (id)outlineView;

	/* Allow rows to be deselected during redrawing */
	/* See logic in -updateAppearance in TVCServerList */
	if (serverList.invalidatingBackgroundForSelection) {
		return YES;
	}

	/* If the window is not focused, don't allow change. */
	if (self.keyWindow == NO) {
		return NO;
	}

	/* If the server list does not have a mouse down event, allow change. */
	if (serverList.leftMouseIsDownInView == NO) {
		return YES;
	}

	/* If command or shift are held down, allow change. */
	NSUInteger keyboardKeys = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);

	if ((keyboardKeys & NSEventModifierFlagCommand) == NSEventModifierFlagCommand ||
		(keyboardKeys & NSEventModifierFlagShift) == NSEventModifierFlagShift)
	{
		return YES;
	}

	/* Find which row is beneath the mouse */
	NSInteger rowBeneathMouse = outlineView.rowBeneathMouse;

	/* If a row is not beneath the mouse or the row that is, is not
	 selected, then the selection is allowed to be changed. */
	if (rowBeneathMouse < 0) {
		return YES;
	}

	if ([outlineView isRowSelected:rowBeneathMouse] == NO) {
		return YES;
	}

	/* If the item beneath the mouse is already selected and we did not 
	 try to unselect it by holding command or shift, then tell the table
	 view not to change the selection. That will be handled by us. */
	IRCTreeItem *itemUnderMouse = [outlineView itemAtRow:rowBeneathMouse];

	[self selectItemInSelectedItems:itemUnderMouse];

	return NO;
}

- (NSIndexSet *)outlineView:(NSOutlineView *)outlineView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
#define _maximumSelectedRows	6

	return [outlineView selectionIndexesForProposedSelection:proposedSelectionIndexes maximumNumberOfSelections:_maximumSelectedRows];

#undef _maximumSelectedRows
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	TVCServerList *serverList = (id)((notification.object) ?: self.serverList);

	if (serverList.invalidatingBackgroundForSelection) {
		return;
	}

	if (self.ignoreNextOutlineViewSelectionChange) {
		self.ignoreNextOutlineViewSelectionChange = NO;

		return;
	}

	if (self.ignoreOutlineViewSelectionChanges) {
		return;
	}

	NSIndexSet *selectedRows = serverList.selectedRowIndexes;

	IRCTreeItem *selectedItem = nil;

	NSUInteger keyboardKeys = ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);

	if (keyboardKeys == NSEventModifierFlagCommand) {
		NSInteger rowBeneathMouse = serverList.rowBeneathMouse;

		if (rowBeneathMouse >= 0 && [selectedRows containsIndex:rowBeneathMouse]) {
			selectedItem = [serverList itemAtRow:rowBeneathMouse];
		}
	}

	if (selectedItem) {
		[self selectionDidChangeToRows:selectedRows selectedItem:selectedItem];
	} else {
		[self selectionDidChangeToRows:selectedRows];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard
{
	/* TODO (March 27, 2016): Support dragging multiple items */
	if (items.count == 1) {
		NSString *itemToken = [worldController() pasteboardStringForItem:items[0]];

		[pasteboard declareTypes:_treeDragItemTypes owner:self];

		[pasteboard setString:itemToken forType:_treeDragItemType];
	}

	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(nullable id)item proposedChildIndex:(NSInteger)index
{
	if (index < 0) {
		return NSDragOperationNone;
	}

	NSPasteboard *pasteboard = [info draggingPasteboard];

	if ([pasteboard availableTypeFromArray:_treeDragItemTypes] == nil) {
		return NSDragOperationNone;
	}

	NSString *draggedItemToken = [pasteboard stringForType:_treeDragItemType];

	if (draggedItemToken == nil) {
		return NSDragOperationNone;
	}

	IRCTreeItem *draggedItem = [worldController() findItemWithPasteboardString:draggedItemToken];

	if (draggedItem == nil) {
		return NSDragOperationNone;
	}

	if (draggedItem.isClient)
	{
		if (item) {
			return NSDragOperationNone;
		}
	}
	else
	{
		IRCChannel *channel = (IRCChannel *)draggedItem;

		if (channel.associatedClient != item) {
			return NSDragOperationNone;
		}

		IRCClient *client = (IRCClient *)item;

		NSArray *channelList = client.channelList;

		IRCChannel *previousItem = nil;

		if ((index - 1) >= 0) {
			previousItem = channelList[(index - 1)];
		}

		IRCChannel *nextItem = nil;

		if (index < channelList.count) {
			nextItem = channelList[index];
		}

		if (channel.isChannel) {
			if (previousItem && previousItem.isChannel == NO) {
				return NSDragOperationNone;
			}
		} else {
			if (nextItem.isChannel) {
				return NSDragOperationNone;
			}
		}
	}

	return NSDragOperationGeneric;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(nullable id)item childIndex:(NSInteger)index
{
	if (index < 0) {
		return NSDragOperationNone;
	}

	NSPasteboard *pasteboard = [info draggingPasteboard];

	if ([pasteboard availableTypeFromArray:_treeDragItemTypes] == nil) {
		return NSDragOperationNone;
	}

	NSString *draggedItemToken = [pasteboard stringForType:_treeDragItemType];

	if (draggedItemToken == nil) {
		return NSDragOperationNone;
	}

	IRCTreeItem *draggedItem = [worldController() findItemWithPasteboardString:draggedItemToken];

	if (draggedItem == nil) {
		return NSDragOperationNone;
	}

	TVCServerList *serverList = (id)outlineView;

	if (draggedItem.isClient)
	{
		NSArray *clientList = worldController().clientList;

		NSMutableArray *clientListMutable = [clientList mutableCopy];

		NSUInteger originalIndex = [clientList indexOfObjectIdenticalTo:draggedItem];

		[clientListMutable moveObjectAtIndex:originalIndex toIndex:index];

		worldController().clientList = clientListMutable;

		[serverList moveItemAtIndex:originalIndex inParent:nil toIndex:index inParent:nil];
	}
	else
	{
		if (item == nil || item != draggedItem.associatedClient) {
			return NO;
		}

		IRCClient *client = (IRCClient *)item;

		NSArray *channelList = client.channelList;

		NSMutableArray *channelListMutable = [channelList mutableCopy];

		NSUInteger originalIndex = [channelList indexOfObjectIdenticalTo:draggedItem];

		[channelListMutable moveObjectAtIndex:originalIndex toIndex:index];

		client.channelList = channelListMutable;

		[serverList moveItemAtIndex:originalIndex inParent:client toIndex:index inParent:client];
	}

	[menuController() populateNavigationChannelList];

	return YES;
}

@end

NS_ASSUME_NONNULL_END
