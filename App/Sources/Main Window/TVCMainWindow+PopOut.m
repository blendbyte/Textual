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
#import "TXGlobalModels.h"
#import "TLONicknameCompletionStatusPrivate.h"
#import "IRCClientPrivate.h"
#import "TXMasterControllerPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCTreeItem.h"
#import "IRCWorldPrivate.h"
#import "TLOInputHistoryPrivate.h"
#import "TVCLogControllerPrivate.h"
#import "TVCMainWindowLoadingScreenPrivate.h"
#import "TVCMainWindowSplitViewPrivate.h"
#import "TVCMainWindowTextViewPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCMainWindowPrivate.h"
#import "TVCMainWindowInternal.h"

NS_ASSUME_NONNULL_BEGIN

/* Pop-out windows: this class from the same nib, set up as a window
 only (the application is up already), its server list hidden and its one
 item selected for good. The item's view moves into it as it is (a WKWebView
 keeps its page when it changes window). */

static NSString * const _popOutsDefaultsKey = @"Window -> Pop-out Windows";

#define _popOutDefaultWidth			720.0
#define _popOutDefaultHeight		520.0

/* Stands in for the master controller as the nib's owner, whose only outlet
 is the window */
@interface TVCMainWindowPopOutOwner : NSObject
@property (nonatomic, strong, nullable) IBOutlet TVCMainWindow *mainWindow;
@end

@implementation TVCMainWindowPopOutOwner
@end

static BOOL _loadingPopOut = NO;
static BOOL _restoringPopOuts = NO;

@implementation TVCMainWindow (PopOut)

#pragma mark -
#pragma mark Windows

+ (BOOL)isLoadingPopOut
{
	return _loadingPopOut;
}

- (BOOL)isPopOut
{
	return (self.popOutItem != nil);
}

+ (nullable TVCMainWindow *)popOutWindowForItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	for (TVCMainWindow *window in self.windows) {
		if (window.popOutItem == item) {
			return window;
		}
	}

	return nil;
}

#pragma mark -
#pragma mark Opening

+ (void)popOutItem:(IRCTreeItem *)item
{
	[self popOutItem:item frame:nil memberListHidden:NO makeKey:YES];
}

+ (void)popOutItem:(IRCTreeItem *)item atScreenPoint:(NSPoint)point
{
	/* The title bar where the row was let go */
	NSRect frame = NSMakeRect((point.x - 80.0), (point.y - _popOutDefaultHeight + 12.0), _popOutDefaultWidth, _popOutDefaultHeight);

	[self popOutItem:item frame:[NSValue valueWithRect:frame] memberListHidden:NO makeKey:YES];
}

+ (nullable TVCMainWindow *)popOutItem:(IRCTreeItem *)item frame:(nullable NSValue *)frameValue memberListHidden:(BOOL)memberListHidden makeKey:(BOOL)makeKey
{
	NSParameterAssert(item != nil);

	TVCMainWindow *window = [self popOutWindowForItem:item];

	if (window) {
		[window makeKeyAndOrderFront:nil];

		return window;
	}

	TVCMainWindow *mainWindow = mainWindow();

	/* One place at a time: the main window lets go of it first, keeping
	 what was typed there as its draft */
	[mainWindow stopShowingPoppedOutItem:item];

	TVCMainWindowPopOutOwner *owner = [TVCMainWindowPopOutOwner new];

	NSArray *topLevelObjects = nil;

	_loadingPopOut = YES;

	BOOL loaded = [RZMainBundle() loadNibNamed:@"TVCMainWindow" owner:owner topLevelObjects:&topLevelObjects];

	_loadingPopOut = NO;

	window = owner.mainWindow;

	if (loaded == NO || window == nil) {
		LogToConsoleError("Could not load a pop-out window");

		return nil;
	}

	window.popOutTopLevelObjects = topLevelObjects;

	window.textSizeMultiplier = mainWindow.textSizeMultiplier;

	[window showPoppedOutItem:item memberListHidden:memberListHidden];

	/* Its draft comes along */
	NSAttributedString *draft = [mainWindow.inputHistoryManager draftForTreeItem:item];

	if (draft.length > 0) {
		[mainWindow.inputHistoryManager setDraft:nil forTreeItem:item];

		[window restoreInputDraft:draft];
	}

	NSRect frame = NSZeroRect;

	if (frameValue) {
		frame = frameValue.rectValue;
	} else {
		/* Beside the main window's top left, stepping on for each */
		NSUInteger popOutCount = (self.windows.count - 1);

		NSRect mainFrame = mainWindow.frame;

		CGFloat offset = (32.0 * popOutCount);

		frame = NSMakeRect((NSMinX(mainFrame) + offset), (NSMaxY(mainFrame) - _popOutDefaultHeight - offset), _popOutDefaultWidth, _popOutDefaultHeight);
	}

	NSScreen *screen = (mainWindow.screen ?: [NSScreen mainScreen]);

	for (NSScreen *candidate in [NSScreen screens]) {
		if (NSIntersectsRect(candidate.visibleFrame, frame)) {
			screen = candidate;

			break;
		}
	}

	[window setFrame:[window constrainFrameRect:frame toScreen:screen] display:NO];

	if (makeKey) {
		[window makeKeyAndOrderFront:nil];
	} else {
		[window orderFront:nil];
	}

	[self savePopOuts];

	return window;
}

- (void)showPoppedOutItem:(IRCTreeItem *)item memberListHidden:(BOOL)memberListHidden
{
	NSParameterAssert(item != nil);

	self.popOutItem = item;

	[item.viewController setAttachedWindow:self];

	self.memberList.isHiddenByUser = memberListHidden;

	self.selectedItems = @[item];
	self.selectedItem = item;

	[self updateChannelViewBoxContentViewSelection];

	[item.viewController notifyDidBecomeVisible];

	[self selectionDidChangePostflight];

	[self updateTitle];

	[self updateUploadButton];
}

/* The main window: it's selected, or among several selected */
- (void)stopShowingPoppedOutItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	if ([self isItemVisible:item] == NO) {
		return;
	}

	NSMutableArray<IRCTreeItem *> *items = [self.selectedItems mutableCopy];

	[items removeObject:item];

	/* A channel alone: its server console instead */
	if (items.count == 0 && item.isClient == NO) {
		IRCClient *client = item.associatedClient;

		if ([self.class popOutWindowForItem:client] == nil) {
			[items addObject:client];
		}
	}

	IRCTreeItem *selectedItem = self.selectedItem;

	if (selectedItem == item || [items containsObject:selectedItem] == NO) {
		selectedItem = items.lastObject;
	}

	[self adjustSelectionWithItems:items selectedItem:selectedItem];
}

#pragma mark -
#pragma mark Closing

- (void)windowWillClose:(NSNotification *)notification
{
	if (self.isPopOut == NO) {
		return;
	}

	IRCTreeItem *item = self.popOutItem;

	BOOL putBack = (self.popOutClosingQuietly == NO);

	/* What was typed stays as its draft in the main window */
	TVCMainWindow *mainWindow = mainWindow();

	NSAttributedString *text = self.inputTextField.attributedStringValue;

	if (putBack) {
		[mainWindow.inputHistoryManager setDraft:text forTreeItem:item];
	}

	self.popOutItem = nil;

	[self.class unregisterWindow:self];

	[RZNotificationCenter() removeObserver:self];

	self.selectedItems = @[];
	self.selectedItem = nil;

	[self updateChannelViewBoxContentViewSelection];

	[self.memberList assignToChannel:nil];

	[item.viewController notifyDidBecomeHidden];

	[item.viewController setAttachedWindow:mainWindow];

	if (putBack) {
		[self.class savePopOuts];

		[mainWindow select:item];
	}

	/* The nib's objects go once the window is done closing */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		self.popOutTopLevelObjects = nil;
	});
}

+ (void)closePopOutsForItem:(IRCTreeItem *)item
{
	NSParameterAssert(item != nil);

	for (TVCMainWindow *window in self.windows) {
		IRCTreeItem *popOutItem = window.popOutItem;

		if (popOutItem == nil) {
			continue;
		}

		if (popOutItem == item || (item.isClient && popOutItem.associatedClient == item)) {
			window.popOutClosingQuietly = YES;

			[window close];
		}
	}

	[self savePopOuts];
}

+ (void)closePopOutsForTermination
{
	[self savePopOuts];

	for (TVCMainWindow *window in self.windows) {
		if (window.isPopOut == NO) {
			continue;
		}

		window.popOutClosingQuietly = YES;

		[window close];
	}
}

#pragma mark -
#pragma mark Keeping

+ (void)savePopOuts
{
	if (_restoringPopOuts || masterController().applicationIsTerminating) {
		return;
	}

	NSMutableArray *records = [NSMutableArray array];

	for (TVCMainWindow *window in self.windows) {
		IRCTreeItem *item = window.popOutItem;

		if (item == nil) {
			continue;
		}

		[records addObject:@{
			@"item" : item.uniqueIdentifier,
			@"frame" : NSStringFromRect(window.frame),
			@"memberListHidden" : @(window.memberList.isHiddenByUser)
		}];
	}

	[RZUserDefaults() setObject:[records copy] forKey:_popOutsDefaultsKey];
}

+ (void)restorePopOuts
{
	NSArray *records = [RZUserDefaults() arrayForKey:_popOutsDefaultsKey];

	if (records.count == 0) {
		return;
	}

	_restoringPopOuts = YES;

	for (NSDictionary *record in records) {
		if ([record isKindOfClass:[NSDictionary class]] == NO) {
			continue;
		}

		NSString *itemId = record[@"item"];

		/* Its channel or server is gone: not this one */
		IRCTreeItem *item = (([itemId isKindOfClass:[NSString class]]) ? [worldController() findItemWithId:itemId] : nil);

		if (item == nil) {
			continue;
		}

		NSString *frameString = record[@"frame"];

		NSValue *frame = (([frameString isKindOfClass:[NSString class]]) ? [NSValue valueWithRect:NSRectFromString(frameString)] : nil);

		[self popOutItem:item frame:frame memberListHidden:[record[@"memberListHidden"] boolValue] makeKey:NO];
	}

	_restoringPopOuts = NO;

	[self savePopOuts];
}

@end

NS_ASSUME_NONNULL_END
