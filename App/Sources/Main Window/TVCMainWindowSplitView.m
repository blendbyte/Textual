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

#import "NSViewHelperPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCServerList.h"
#import "TVCServerListAppearance.h"
#import "TVCMemberList.h"
#import "TVCMemberListAppearance.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowAppearance.h"
#import "TVCMainWindowSplitViewPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const _userDefaultsKey	  = @"Window -> Main Window -> Split Channel View Saved Frames";

@interface TVCMainWindowSplitView ()
@property (nonatomic, assign) BOOL restoredPositions;
@property (nonatomic, assign) BOOL stopFrameUpdatesForServerList;
@property (nonatomic, assign) BOOL stopFrameUpdatesForMemberList;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *serverListWidthMinConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *serverListWidthMaxConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *memberListWidthMinConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *memberListWidthMaxConstraint;
@end

@implementation TVCMainWindowSplitView

- (void)applicationAppearanceChanged
{
	TVCMainWindowAppearance *appearance = self.mainWindow.userInterfaceObjects;

	TVCServerListAppearance *serverList = appearance.serverList;

	self.serverListWidthMinConstraint.constant = serverList.minimumWidth;
	self.serverListWidthMaxConstraint.constant = serverList.maximumWidth;

	TVCMemberListAppearance *memberList = appearance.memberList;

	self.memberListWidthMinConstraint.constant = memberList.minimumWidth;
	self.memberListWidthMaxConstraint.constant = memberList.maximumWidth;
}

- (NSColor *)dividerColor
{
	TVCMainWindowAppearance *appearance = self.mainWindow.userInterfaceObjects;

	NSColor *dividerColor = appearance.splitViewDividerColor;

	if (appearance.isDarkAppearance) {
		dividerColor = dividerColor.invertedColor;
	}

	return dividerColor;
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.delegate = (id)self;
}

- (void)restorePositions
{
	if (self.restoredPositions) {
		return;
	}

	[self expandMemberList];

	[self expandServerList];

	// Set after expanding views so that -resizeWithOldSuperviewSize:
	// does not save the views' frames prematurely
	self.restoredPositions = YES;
}

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	if (dividerIndex == 0) {
		if (self.serverListCollapsed) {
			return NSZeroRect;
		}
	} else if (dividerIndex == 1) {
		if (self.memberListCollapsed) {
			return NSZeroRect;
		}
	}

	return proposedEffectiveRect;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	if (self.restoredPositions) {
		[self updateSavedFrames];
	}
}

- (BOOL)allowsVibrancy
{
	return YES;
}

- (void)expandServerList
{
	NSScrollView *scrollView = self.mainWindow.serverList.enclosingScrollView;

	scrollView.hasVerticalScroller = YES;

	NSView *subview = self.subviews[0];

	subview.hidden = NO;

	[self setPosition:[self positionToRestoreServerListAt] ofDividerAtIndex:0];

	self.serverListWidthMinConstraint.active = YES;

	self.stopFrameUpdatesForServerList = NO;
}

- (void)expandMemberList
{
	NSScrollView *scrollView = self.mainWindow.memberList.enclosingScrollView;

	scrollView.hasVerticalScroller = YES;

	NSView *subview = self.subviews[2];

	subview.hidden = NO;

	[self setPosition:[self positionToRestoreMemberListAt] ofDividerAtIndex:1];

	self.memberListWidthMinConstraint.active = YES;

	self.stopFrameUpdatesForMemberList = NO;
}

- (void)collapseServerList
{
	self.stopFrameUpdatesForServerList = YES;

	self.serverListWidthMinConstraint.active = NO;

	NSScrollView *scrollView = self.mainWindow.serverList.enclosingScrollView;

	scrollView.hasVerticalScroller = NO;

	NSView *subview = self.subviews[0];

	[self setPosition:0.0 ofDividerAtIndex:0];

	subview.hidden = YES;
}

- (void)collapseMemberList
{
	self.stopFrameUpdatesForMemberList = YES;

	self.memberListWidthMinConstraint.active = NO;

	NSView *subview = self.subviews[2];

	TVCMainWindow *mainWindow = self.mainWindow;

	NSScrollView *scrollView = mainWindow.memberList.enclosingScrollView;

	scrollView.hasVerticalScroller = NO;

	NSRect windowFrame = mainWindow.frame;

	[self setPosition:NSWidth(windowFrame) ofDividerAtIndex:1];

	subview.hidden = YES;
}

- (void)toggleServerListVisibility
{
	if (self.serverListCollapsed) {
		[self expandServerList];
	} else {
		[self collapseServerList];
	}
}

- (void)toggleMemberListVisibility
{
	if (self.memberListCollapsed) {
		[self expandMemberList];
	} else {
		[self collapseMemberList];
	}
}

- (CGFloat)positionForDividerAtIndex:(NSInteger)index
{
	NSRect subviewFrame = self.subviews[index].frame;

	return (NSMaxX(subviewFrame) + (self.dividerThickness * index));
}

- (CGFloat)positionToRestoreServerListAt
{
	NSDictionary *frames = [self savedFrames];

	CGFloat position = [frames doubleForKey:@"serverList"];

	TVCServerListAppearance *appearance = self.mainWindow.userInterfaceObjects.serverList;

	if (position < appearance.minimumWidth) {
		position = appearance.defaultWidth;
	} else if (position > appearance.maximumWidth) {
		position = appearance.defaultWidth;
	}

	return position;
}

- (CGFloat)positionToRestoreMemberListAt
{
	return [self positionToRestoreMemberListAt:YES];
}

- (CGFloat)positionToRestoreMemberListAt:(BOOL)correctedFrame
{
	NSDictionary *frames = [self savedFrames];

	CGFloat position = [frames doubleForKey:@"memberList"];

	TVCMemberListAppearance *appearance = self.mainWindow.userInterfaceObjects.memberList;

	if (position < appearance.minimumWidth) {
		position = appearance.defaultWidth;
	} else if (position > appearance.maximumWidth) {
		position = appearance.defaultWidth;
	}

	if (correctedFrame) {
		NSRect windowFrame = self.mainWindow.frame;

		return ((NSWidth(windowFrame) - position) - self.dividerThickness);
	}

	return position;
}

- (CGFloat)positionOfServerListForSaving
{
	CGFloat position = [self positionForDividerAtIndex:0];

	TVCServerListAppearance *appearance = self.mainWindow.userInterfaceObjects.serverList;

	if (position < appearance.minimumWidth) {
		position = appearance.defaultWidth;
	} else if (position > appearance.maximumWidth) {
		position = appearance.defaultWidth;
	}

	return position;
}

- (CGFloat)positionOfMemberListForSaving
{
	CGFloat position = [self positionForDividerAtIndex:1];

	NSRect windowFrame = self.mainWindow.frame;

	position = ((position - NSWidth(windowFrame)) * (-1));

	TVCMemberListAppearance *appearance = self.mainWindow.userInterfaceObjects.memberList;

	if (position < appearance.minimumWidth) {
		position = appearance.defaultWidth;
	} else if (position > appearance.maximumWidth) {
		position = appearance.defaultWidth;
	}

	return position;
}

- (void)updateSavedFrames
{
	CGFloat serverListPosition = 0;

	if (self.stopFrameUpdatesForServerList) {
		serverListPosition = [self positionToRestoreServerListAt];
	} else {
		serverListPosition = [self positionOfServerListForSaving];
	}

	CGFloat memberListPosition = 0;

	if (self.stopFrameUpdatesForMemberList) {
		memberListPosition = [self positionToRestoreMemberListAt:NO];
	} else {
		memberListPosition = [self positionOfMemberListForSaving];
	}

	NSDictionary *newFrames = @{
		@"serverList" : @(serverListPosition),
		@"memberList" : @(memberListPosition),
	};

	[RZUserDefaults() setObject:newFrames forKey:_userDefaultsKey];
}

- (nullable NSDictionary<NSString *, NSNumber *> *)savedFrames
{
	return [RZUserDefaults() objectForKey:_userDefaultsKey];
}

- (BOOL)isServerListCollapsed
{
	return [self isSubviewCollapsed:self.subviews[0]];
}

- (BOOL)isMemberListCollapsed
{
	return [self isSubviewCollapsed:self.subviews[2]];
}

@end

NS_ASSUME_NONNULL_END
