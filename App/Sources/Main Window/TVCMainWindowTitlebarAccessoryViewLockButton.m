/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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
#import "TVCMainWindow.h"
#import "TVCMainWindowAppearance.h"
#import "TVCMainWindowTitlebarAccessoryViewPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowTitlebarAccessoryViewLockButton ()
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *lockButtonLeftMarginConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *lockButtonRightMarginConstraint;

/* Accessory views are wrapped around an NSToolbarFullScreenWindow object
 when in full screen. That means the view cannot use the helper property
 in NSView named -mainWindow which wraps around -window. Instead, we have
 to be explicit and use a reference. */

@property (nonatomic, weak) IBOutlet TVCMainWindow *mainWindowRef;
@end

@implementation TVCMainWindowTitlebarAccessoryViewLockButton

- (void)sizeToFit
{
	[super sizeToFit];

	/* NSTitlebarAccessoryViewController is not very friendly when it comes
	 to allowing us to specify an NSLayoutConstraint based width for our view
	 and updating the width of its clip view based on changes to that. Lucky
	 for us NSTitlebarAccessoryViewController at least monitors the frame
	 value for its associated view which means if we manually specify the 
	 width in its frame, then we can at least force a resize then. */
	CGFloat buttonWidth = NSWidth(self.frame);

	CGFloat buttonLeftMargin = self.lockButtonLeftMarginConstraint.constant;
	CGFloat buttonRightMargin = self.lockButtonRightMarginConstraint.constant;

	CGFloat totalViewWidth = (buttonLeftMargin + buttonWidth + buttonRightMargin);

	NSRect superviewFrame = self.superview.frame;

	superviewFrame.size.width = totalViewWidth;

	self.superview.frame = superviewFrame;

	return;
}

- (void)awakeFromNib
{
	[super awakeFromNib];

	self.cell.backgroundStyle = NSBackgroundStyleRaised;
}

- (void)positionImageOverContent
{
	[self.cell setImagePosition:NSImageOverlaps];
}

- (void)setIconAsLocked
{
	NSImage *iconImage = [NSImage imageNamed:@"NSLockLockedTemplate"];

	self.image = iconImage;
}

- (void)applicationAppearanceChanged
{
	TVCMainWindowAppearance *appearance = self.mainWindowRef.userInterfaceObjects;

	[self _updateAppearance:appearance];
}

- (void)_updateAppearance:(TVCMainWindowAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	self.lockButtonLeftMarginConstraint.constant = appearance.titlebarAccessoryViewLeftMargin;
	self.lockButtonRightMarginConstraint.constant = appearance.titlebarAccessoryViewRightMargin;

	[self sizeToFit];

	self.needsDisplay = YES;
}

@end

NS_ASSUME_NONNULL_END
