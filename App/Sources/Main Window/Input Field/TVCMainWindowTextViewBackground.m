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

/* A rounded field with a faint fill and a hairline edge, like the system's
 text fields: quieter than the bright block (dark) and the shadows (light)
 it was */
- (void)drawControllerForWithAppearance:(TVCMainWindowTextViewAppearance *)appearance
{
	NSParameterAssert(appearance != nil);

	BOOL isWindowActive = self.mainWindow.activeForDrawing;

	NSColor *fillColor = ((isWindowActive) ? appearance.textViewBackgroundColorActiveWindow : appearance.textViewBackgroundColorInactiveWindow);

	NSColor *edgeColor = ((isWindowActive) ? appearance.textViewOutsidePrimaryShadowColorActiveWindow : appearance.textViewOutsidePrimaryShadowColorInactiveWindow);

	CGFloat lineWidth = (1.0 / MAX(self.window.backingScaleFactor, 1.0));

	NSRect fieldRect = NSInsetRect(self.bounds, (lineWidth / 2.0), (lineWidth / 2.0));

	NSBezierPath *fieldPath = [NSBezierPath bezierPathWithRoundedRect:fieldRect xRadius:8.0 yRadius:8.0];

	[fillColor setFill];

	[fieldPath fill];

	fieldPath.lineWidth = lineWidth;

	[edgeColor setStroke];

	[fieldPath stroke];
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
