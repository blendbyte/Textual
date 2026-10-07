/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "TVCAppearancePrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCMemberListAppearancePrivate.h"
#import "TVCMainWindowTextViewAppearancePrivate.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowAppearancePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowAppearance ()
@property (nonatomic, strong, readwrite) TVCServerListAppearance *serverList;
@property (nonatomic, strong, readwrite) TVCMemberListAppearance *memberList;
@property (nonatomic, strong, readwrite) TVCMainWindowTextViewAppearance *textView;
@property (nonatomic, assign, readwrite) NSSize defaultWindowSize;
@property (nonatomic, copy, nullable, readwrite) NSColor *channelViewOverlayDefaultBackgroundColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *channelViewOverlayDefaultBackgroundColorInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *loadingScreenBackgroundColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *splitViewDividerColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *titlebarAccessoryViewBackgroundColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *titlebarAccessoryViewBackgroundColorInactiveWindow;
@property (nonatomic, assign, readwrite) CGFloat titlebarAccessoryViewLeftMargin;
@property (nonatomic, assign, readwrite) CGFloat titlebarAccessoryViewRightMargin;
@end

@implementation TVCMainWindowAppearance

#pragma mark -
#pragma mark Initialization

- (nullable instancetype)initWithWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	NSURL *appearanceLocation = [self.class appearanceLocation];

	BOOL forRetinaDisplay = mainWindow.runningInHighResolutionMode;

	if ((self = [super initWithAppearanceAtURL:appearanceLocation forRetinaDisplay:forRetinaDisplay])) {
		[self prepareInitialStateWithWindow:mainWindow];

		return self;
	}

	return nil;
}

+ (NSURL *)appearanceLocation
{
	return [RZMainBundle() URLForResource:@"TVCMainWindowAppearance" withExtension:@"plist"];
}

- (void)prepareInitialStateWithWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	self.defaultWindowSize = [self sizeForKey:@"defaultWindowSize"];

	self.channelViewOverlayDefaultBackgroundColorActiveWindow = [self colorForKey:@"channelViewOverlayDefaultBackgroundColor" forActiveWindow:YES];
	self.channelViewOverlayDefaultBackgroundColorInactiveWindow = [self colorForKey:@"channelViewOverlayDefaultBackgroundColor" forActiveWindow:NO];

	self.loadingScreenBackgroundColor = [self colorForKey:@"loadingScreenBackgroundColor"];

	self.splitViewDividerColor = [self colorForKey:@"splitViewDividerColor"];

	self.titlebarAccessoryViewBackgroundColorActiveWindow = [self colorForKey:@"titlebarAccessoryViewBackgroundColor" forActiveWindow:YES];
	self.titlebarAccessoryViewBackgroundColorInactiveWindow = [self colorForKey:@"titlebarAccessoryViewBackgroundColor" forActiveWindow:NO];

	self.titlebarAccessoryViewLeftMargin = [self measurementForKey:@"titlebarAccessoryViewLeftMargin"];
	self.titlebarAccessoryViewRightMargin = [self measurementForKey:@"titlebarAccessoryViewRightMargin"];

	self.serverList = [[TVCServerListAppearance alloc] initWithServerList:mainWindow.serverList inWindow:mainWindow];
	self.memberList = [[TVCMemberListAppearance alloc] initWithMemberList:mainWindow.memberList inWindow:mainWindow];
	self.textView = [[TVCMainWindowTextViewAppearance alloc] initWithWindow:mainWindow];

	[self flushAppearanceProperties];
}

@end

NS_ASSUME_NONNULL_END
