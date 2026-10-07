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
#import "IRCColorFormat.h"
#import "TLOLocalization.h"
#import "TPCResourceManagerPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowSegmentedControllerPrivate.h"
#import "TVCTextViewWithIRCFormatterPrivate.h"
#import "TVCMainWindowTextViewAppearancePrivate.h"
#import "TVCMainWindowTextViewInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowTextViewBackground ()
@property (nonatomic, unsafe_unretained) IBOutlet TVCMainWindowTextView *textView;
@end

#pragma mark -
#pragma mark Background Drawing

@implementation TVCMainWindowTextViewBackground

- (void)drawControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	if (appearance.isDarkAppearance == NO) {
		[self drawLightControllerForWithAppearance:appearance];
	} else {
		[self drawDarkControllerForWithAppearance:appearance];
	}
}

- (void)drawDarkControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	BOOL isWindowActive = self.mainWindow.activeForDrawing;

	NSRect cellBounds = self.frame;

	NSRect controlFrame = NSMakeRect(0.0, 1.0,   cellBounds.size.width,
												(cellBounds.size.height - 2.0));

	/* Inner background color */
	NSColor *backgroundColor = nil;

	if (isWindowActive) {
		backgroundColor = appearance.textViewBackgroundColorActiveWindow;
	} else {
		backgroundColor = appearance.textViewBackgroundColorInactiveWindow;
	} // isWindowActive

	/* Shadow colors */
	NSShadow *outsideShadow = [NSShadow new];

	outsideShadow.shadowBlurRadius = 0.0;
	outsideShadow.shadowOffset = NSMakeSize(0.0, (-1.0));

	if (isWindowActive) {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorActiveWindow;
	} else {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorInactiveWindow;
	} // isWindowActive

	/* Rectangle drawing */
	NSBezierPath *rectanglePath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:3.0 yRadius:3.0];

	[NSGraphicsContext saveGraphicsState];

	[outsideShadow set];

	[backgroundColor setFill];

	[rectanglePath fill];

	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawLightControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	/* To be honest, I don't remember what any of this does. */

	BOOL isWindowActive = self.mainWindow.activeForDrawing;

	NSRect cellBounds = self.frame;

	NSRect controlFrame = NSMakeRect(0.0, 1.0,   cellBounds.size.width,
												(cellBounds.size.height - 2.0));

	CGContextRef context = RZGraphicsCurrentContext().CGContext;

	/* Inner gradient color */
	NSGradient *insideGradient = nil;

	if (isWindowActive) {
		insideGradient = appearance.textViewInsideGradientActiveWindow;
	} else {
		insideGradient = appearance.textViewInsideGradientInactiveWindow;
	} // isWindowActive

	/* Inside shadow */
	NSShadow *insideShadow = [NSShadow new];

	insideShadow.shadowBlurRadius = 0.0;
	insideShadow.shadowOffset = NSMakeSize(0.0, (-1.0));

	NSColor *insideShadowColor = nil;

	if (isWindowActive) {
		insideShadowColor = appearance.textViewInsideShadowColorActiveWindow;
	} else {
		insideShadowColor = appearance.textViewInsideShadowColorInactiveWindow;
	}

	insideShadow.shadowColor = insideShadowColor;

	/* Outside shadow */
	NSShadow *outsideShadow = [NSShadow new];

	if (appearance.isHighResolutionAppearance == NO) {
		outsideShadow.shadowBlurRadius = 0.0;
		outsideShadow.shadowOffset = NSMakeSize(0.0, (-1.0));
	} else {
		outsideShadow.shadowBlurRadius = 0.0;
		outsideShadow.shadowOffset = NSMakeSize(0.0, (-0.5));
	} // high resolution

	if (isWindowActive) {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorActiveWindow;
	} else {
		outsideShadow.shadowColor = appearance.textViewOutsidePrimaryShadowColorInactiveWindow;
	} // isWindowActive

	/* Rectangle drawing */
	NSBezierPath *rectanglePath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:3.0 yRadius:3.0];

	[outsideShadow set];

	CGContextBeginTransparencyLayer(context, NULL);

	[insideGradient drawInBezierPath:rectanglePath angle:(-90)];

	CGContextEndTransparencyLayer(context);

	/* Prepare drawing for inside shadow */
	CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);

	CGContextSetAlpha(context, insideShadowColor.alphaComponent);

	CGContextBeginTransparencyLayer(context, NULL);

	{
		/* Inside shadow drawing */
		[insideShadow set];

		CGContextSetBlendMode(context, kCGBlendModeSourceOut);

		CGContextBeginTransparencyLayer(context, NULL);

		/* Fill shadow */
		[insideShadowColor setFill];

		[rectanglePath fill];

		/* Complete drawing */
		CGContextEndTransparencyLayer(context);
	}

	CGContextEndTransparencyLayer(context);

	/* On retina, we fake a second shadow under the bottommost one */
	if (appearance.isHighResolutionAppearance) {
		NSColor *controlColor = nil;

		if (isWindowActive) {
			controlColor = appearance.textViewOutsideSecondaryShadowColorActiveWindow;
		} else {
			controlColor = appearance.textViewOutsideSecondaryShadowColorInactiveWindow;
		} // isWindowActive

		[controlColor setStroke];

		NSPoint linePoint1 = NSMakePoint(2.0, 0.0);
		NSPoint linePoint2 = NSMakePoint((cellBounds.size.width - 2.0), 0.0);

		[NSBezierPath strokeLineFromPoint:linePoint1 toPoint:linePoint2];
	} // high resolution
}

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect] == NO) {
		return;
	}

	TVCMainWindowTextViewAppearance *appearance = self.textView.userInterfaceObjects;

	if (appearance == nil) {
		return;
	}

	[self drawControllerForWithAppearance:appearance];
}

@end

NS_ASSUME_NONNULL_END
