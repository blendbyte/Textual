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

#import "TXMasterController.h"
#import "TPCPreferencesLocal.h"
#import "IRCClient.h"
#import "IRCChannel.h"
#import "IRCWorld.h"
#import "TVCDockIconPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _badgeSeperationSpace		1.0

@implementation TVCDockIcon

static NSInteger _cachedHighlightCount = (-1);
static NSInteger _cachedMessageCount = (-1);

/* At most four times a second: every message in a busy channel changed the
 counts and redrew the icon */
+ (void)updateDockIcon
{
	static BOOL updatePending = NO;

	if (updatePending) {
		return;
	}

	updatePending = YES;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		updatePending = NO;

		[self _updateDockIconNow];
	});
}

+ (void)_updateDockIconNow
{
	if ([TPCPreferences displayDockBadge] == NO) {
		return;
	}

	NSUInteger highlightCount = 0;
	NSUInteger messageCount = 0;

	for (IRCClient *u in worldController().clientList) {
		for (IRCChannel *c in u.channelList) {
			if (c.config.pushNotifications) {
				messageCount += c.dockUnreadCount;
			}

			highlightCount += c.nicknameHighlightCount;
		}
	}

	if (messageCount == 0 && highlightCount == 0) {
		[self drawWithoutCount];
	} else {
		[self drawWithHighlightCount:highlightCount messageCount:messageCount];
	}
}

+ (NSImage *)applicationIcon
{
	/* THIS IS A SECRET!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	 Birthday icon designed by Alex Sørlie Glomsaas. */

	NSCalendar *sysCalendar = [NSCalendar currentCalendar];

	NSDateComponents *breakdownInfo = [sysCalendar components:(NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];

	/* The first public commit of Textual occurred on July, 23, 2010. This is the day
	 that we consider the birthday of the application. */
	NSImage *icon = nil;

	if (breakdownInfo.month == 7 && breakdownInfo.day == 23) {
		icon = [NSImage imageNamed:@"applicationIconBirthday"];
	} else {
		icon = [NSImage imageNamed:@"NSApplicationIcon"];
	}

#ifdef DEBUG
	icon = [self developmentIconWithIcon:icon];
#endif

	return icon;
}

#ifdef DEBUG
/* Development builds ("Textual Dev") carry a DEV ribbon so that they
 cannot be mistaken for an installed copy of Textual in the Dock. */
+ (NSImage *)developmentIconWithIcon:(NSImage *)icon
{
	return [NSImage imageWithSize:NSMakeSize(512, 512) flipped:NO drawingHandler:^BOOL(NSRect rect) {
		[icon drawInRect:rect];

		NSRect ribbonRect = NSMakeRect(NSWidth(rect) * 0.15, NSHeight(rect) * 0.05, NSWidth(rect) * 0.70, NSHeight(rect) * 0.22);

		CGFloat ribbonRadius = (NSHeight(ribbonRect) / 2.0);

		[[NSColor systemOrangeColor] setFill];

		[[NSBezierPath bezierPathWithRoundedRect:ribbonRect xRadius:ribbonRadius yRadius:ribbonRadius] fill];

		NSDictionary *attributes = @{
			NSFontAttributeName : [NSFont systemFontOfSize:(NSHeight(ribbonRect) * 0.65) weight:NSFontWeightHeavy],
			NSForegroundColorAttributeName : [NSColor whiteColor]
		};

		NSAttributedString *label = [[NSAttributedString alloc] initWithString:@"DEV" attributes:attributes];

		NSSize labelSize = label.size;

		[label drawAtPoint:NSMakePoint((NSMidX(ribbonRect) - (labelSize.width / 2.0)), (NSMidY(ribbonRect) - (labelSize.height / 2.0)))];

		return YES;
	}];
}
#endif

+ (void)resetCachedCount
{
	_cachedMessageCount = (-1);
	_cachedHighlightCount = (-1);
}

+ (void)drawWithoutCount
{
	if (_cachedHighlightCount == 0 && _cachedMessageCount == 0) {
		return;
	}

	_cachedMessageCount = 0;
	_cachedHighlightCount = 0;

	[NSApp setApplicationIconImage:[self applicationIcon]];
}

+ (void)drawWithHighlightCount:(NSUInteger)highlightCount messageCount:(NSUInteger)messageCount
{
	if (_cachedHighlightCount == highlightCount && _cachedMessageCount == messageCount) {
		return;
	}

	_cachedHighlightCount = highlightCount;
	_cachedMessageCount = messageCount;

	if (messageCount > 9999) {
		messageCount = 9999;
	}

	if (highlightCount > 9999) {
		highlightCount = 9999;
	}

	BOOL showRedBadge = (messageCount >= 1);
	BOOL showGreenBadge = (highlightCount >= 1);

	/* ////////////////////////////////////////////////////////// */
	/* Define Text Drawing Globals */
	/* ////////////////////////////////////////////////////////// */

	NSSize badgeTextSize = NSZeroSize;

	/* A new string per badge: one object was initialized twice */
	NSAttributedString *badgeText = nil;

	CGFloat badgeTextFrameCorrection = 2.0;

	NSDictionary *badgeTextAttributes = @{
		NSFontAttributeName				: [NSFont fontWithName:@"Helvetica" size:24.0],
		NSForegroundColorAttributeName	: [NSColor whiteColor]
	};

	/* ////////////////////////////////////////////////////////// */
	/* Load Drawing Images */
	/* ////////////////////////////////////////////////////////// */

	NSImage *appIcon = [[self applicationIcon] copy];

	NSImage *redBadgeLeft = [NSImage imageNamed:@"DIRedBadgeLeft"];
	NSImage *redBadgeCenter = [NSImage imageNamed:@"DIRedBadgeCenter"];
	NSImage *redBadgeRight = [NSImage imageNamed:@"DIRedBadgeRight"];

	NSImage *greenBadgeLeft = [NSImage imageNamed:@"DIGreenBadgeLeft"];
	NSImage *greenBadgeCenter = [NSImage imageNamed:@"DIGreenBadgeCenter"];
	NSImage *greenBadgeRight = [NSImage imageNamed:@"DIGreenBadgeRight"];

	/* ////////////////////////////////////////////////////////// */
	/* Build Scaling Frames */
	/* ////////////////////////////////////////////////////////// */

	NSRect redBadgeLeftFrame, greenBadgeLeftFrame;
	NSRect redBadgeRightFrame, greenBadgeRightFrame;
	NSRect redBadgeCenterFrame, greenBadgeCenterFrame;

	[appIcon lockFocus];

	/* Red Badge Size */
	redBadgeRightFrame.size.height = 53.0;
	redBadgeCenterFrame.size.height = 53.0;
	redBadgeLeftFrame.size.height = 53.0;

	redBadgeLeftFrame.size.width = 27.0;
	redBadgeCenterFrame.size.width = [self badgeCenterTileWidth:messageCount];
	redBadgeRightFrame.size.width = 26.0;

	/* Green Badge Size */
	greenBadgeRightFrame.size.height = 53.0;
	greenBadgeCenterFrame.size.height = 53.0;
	greenBadgeLeftFrame.size.height	= 53.0;

	greenBadgeLeftFrame.size.width = 27.0;
	greenBadgeCenterFrame.size.width = [self badgeCenterTileWidth:highlightCount];
	greenBadgeRightFrame.size.width	= 26.0;

	/* ////////////////////////////////////////////////////////// */

	/* If there is no red badge, then the green one is drawn in the same
	 position of the red at the top right of the icon. The following is the
	 math required to position it correctly relative to the icon. If the
	 red icon does exist in this drawing, then we will update these points
	 of origin later on in the drawing. For now, assume it is at the top. */

	/* Green Badge Drawing Position */
	greenBadgeLeftFrame.origin =
	NSMakePoint((appIcon.size.width - (greenBadgeRightFrame.size.width +
									   greenBadgeCenterFrame.size.width +
									   greenBadgeLeftFrame.size.width)), // End X Axis
				(appIcon.size.height - greenBadgeRightFrame.size.height));

	greenBadgeCenterFrame.origin =
	NSMakePoint((appIcon.size.width - (greenBadgeRightFrame.size.width +
									   greenBadgeCenterFrame.size.width)), // End X Axis
				(appIcon.size.height - greenBadgeRightFrame.size.height));

	greenBadgeRightFrame.origin =
	NSMakePoint((appIcon.size.width - greenBadgeRightFrame.size.width), // End X Axis
				(appIcon.size.height - greenBadgeRightFrame.size.height));

	/* Update origin if red badge will be drawn */
	if (showRedBadge) {
		greenBadgeLeftFrame.origin.y =
		(appIcon.size.height - (greenBadgeLeftFrame.size.height +
								redBadgeLeftFrame.size.height +
								_badgeSeperationSpace));

		greenBadgeCenterFrame.origin.y =
		(appIcon.size.height - (greenBadgeCenterFrame.size.height +
								redBadgeCenterFrame.size.height +
								_badgeSeperationSpace));

		greenBadgeRightFrame.origin.y =
		(appIcon.size.height - (greenBadgeRightFrame.size.height +
								redBadgeRightFrame.size.height +
								_badgeSeperationSpace));
	}

	/* Red Badge Drawing Position */
	redBadgeLeftFrame.origin =
	NSMakePoint((appIcon.size.width - (redBadgeRightFrame.size.width +
									   redBadgeCenterFrame.size.width +
									   redBadgeLeftFrame.size.width)), // End X Axis
				(appIcon.size.height - redBadgeRightFrame.size.height));

	redBadgeCenterFrame.origin =
	NSMakePoint((appIcon.size.width - (redBadgeRightFrame.size.width +
									   redBadgeCenterFrame.size.width)), // End X Axis
				(appIcon.size.height - redBadgeRightFrame.size.height));

	redBadgeRightFrame.origin =
	NSMakePoint((appIcon.size.width - redBadgeRightFrame.size.width), // End X Axis
				(appIcon.size.height - redBadgeRightFrame.size.height));

	/* ////////////////////////////////////////////////////////// */
	/* Draw Badges */
	/* ////////////////////////////////////////////////////////// */

	/* Red Badge */
	if (showRedBadge) {
		[redBadgeLeft drawInRect:redBadgeLeftFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
		[redBadgeCenter drawInRect:redBadgeCenterFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
		[redBadgeRight drawInRect:redBadgeRightFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

		/* Red Badge Text */
		badgeText = [[NSAttributedString alloc] initWithString:[NSString stringWithInteger:messageCount] attributes:badgeTextAttributes];

		badgeTextSize = [badgeText size];

		CGFloat redBadgeTotalWidth = (redBadgeLeftFrame.size.width +
									  redBadgeCenterFrame.size.width +
									  redBadgeRightFrame.size.width);

		CGFloat redBadgeTotalHeight = redBadgeCenterFrame.size.height;

		CGFloat redBadgeWidthCenter  = ((redBadgeTotalWidth - badgeTextSize.width) / 2.0);
		CGFloat redBadgeHeightCenter = ((redBadgeTotalHeight - badgeTextSize.height) / 2.0);

		NSPoint badgeTextDrawPath =
		NSMakePoint((appIcon.size.width - redBadgeTotalWidth + redBadgeWidthCenter),
					(appIcon.size.height - redBadgeTotalHeight + redBadgeHeightCenter + badgeTextFrameCorrection));

		[badgeText drawAtPoint:badgeTextDrawPath];
	}

	if (showGreenBadge) {
		/* Green Badge */
		[greenBadgeLeft	drawInRect:greenBadgeLeftFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
		[greenBadgeCenter drawInRect:greenBadgeCenterFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
		[greenBadgeRight drawInRect:greenBadgeRightFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

		/* Green Badge Text */
		badgeText = [[NSAttributedString alloc] initWithString:[NSString stringWithInteger:highlightCount] attributes:badgeTextAttributes];

		badgeTextSize = [badgeText size];

		CGFloat greenBadgeTotalWidth = (greenBadgeLeftFrame.size.width +
										greenBadgeCenterFrame.size.width +
										greenBadgeRightFrame.size.width);

		CGFloat greenBadgeTotalHeight = greenBadgeCenterFrame.size.height;

		CGFloat greenBadgeWidthCenter  = ((greenBadgeTotalWidth - badgeTextSize.width) / 2.0);
		CGFloat greenBadgeHeightCenter = ((greenBadgeTotalHeight - badgeTextSize.height) / 2.0);

		NSPoint badgeTextDrawPath =
		NSMakePoint((appIcon.size.width - greenBadgeTotalWidth + greenBadgeWidthCenter),
					(appIcon.size.height - greenBadgeTotalHeight + greenBadgeHeightCenter + badgeTextFrameCorrection));

		if (showRedBadge) {
			badgeTextDrawPath.y -= (redBadgeCenterFrame.size.height + _badgeSeperationSpace);
		}

		[badgeText drawAtPoint:badgeTextDrawPath];
	}

	/* ////////////////////////////////////////////////////////// */
	/* Finish Icon */
	/* ////////////////////////////////////////////////////////// */

	[appIcon unlockFocus];

	[NSApp setApplicationIconImage:appIcon];
}

+ (CGFloat)badgeCenterTileWidth:(NSUInteger)badgeCount
{
	switch (badgeCount) {
		case 1 ... 9:
		{
			return 1.0;
		}
		case 10 ... 99:
		{
			return 1.0;
		}
		case 100 ... 999:
		{
			return 18.0;
		}
		case 1000 ... 9999:
		{
			return 28.0;
		}
	}

	return 1.0;
}

@end

NS_ASSUME_NONNULL_END
