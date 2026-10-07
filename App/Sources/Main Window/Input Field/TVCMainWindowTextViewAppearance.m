/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *    Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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
#import "TVCMainWindow.h"
#import "TVCAppearancePrivate.h"
#import "TVCMainWindowTextViewAppearancePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowTextViewAppearance ()
#pragma mark -
#pragma mark Text View

@property (nonatomic, assign, readwrite) NSSize textViewInset;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewTextColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewPlaceholderTextColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewBackgroundColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewBackgroundColorInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewOutlineColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewOutlineColorInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewInsideShadowColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewInsideShadowColorInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSGradient *textViewInsideGradientActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSGradient *textViewInsideGradientInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewOutsidePrimaryShadowColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewOutsidePrimaryShadowColorInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewOutsideSecondaryShadowColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *textViewOutsideSecondaryShadowColorInactiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSFont *textViewFont;
@property (nonatomic, copy, nullable, readwrite) NSFont *textViewFontLarge;
@property (nonatomic, copy, nullable, readwrite) NSFont *textViewFontExtraLarge;
@property (nonatomic, copy, nullable, readwrite) NSFont *textViewFontHumongous;

@property (nonatomic, assign, readwrite) TVCMainWindowTextViewFontSize textViewPreferredFontSize;

#pragma mark -
#pragma mark Background View

@property (nonatomic, copy, nullable, readwrite) NSColor *backgroundViewBackgroundColor;
@property (nonatomic, copy, nullable, readwrite) NSColor *backgroundViewDividerColor;
@property (nonatomic, assign, readwrite) CGFloat backgroundViewContentBorderPadding;
@end

@implementation TVCMainWindowTextViewAppearance

#pragma mark -
#pragma mark Initialization

- (nullable instancetype)initWithWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	NSURL *appearanceLocation = [self.class appearanceLocation];

	BOOL forRetinaDisplay = mainWindow.runningInHighResolutionMode;

	if ((self = [super initWithAppearanceAtURL:appearanceLocation forRetinaDisplay:forRetinaDisplay])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

+ (NSURL *)appearanceLocation
{
	return [RZMainBundle() URLForResource:@"TVCMainWindowTextViewAppearance" withExtension:@"plist"];
}

- (void)prepareInitialState
{
	NSDictionary *properties = self.appearanceProperties;

	NSDictionary *textView = properties[@"Text View"];

	self.textViewInset = [self sizeInGroup:textView withKey:@"inset"];
	self.textViewTextColor = [self colorInGroup:textView withKey:@"normalTextColor"];
	self.textViewPlaceholderTextColor = [self colorInGroup:textView withKey:@"placeholderTextColor"];
	self.textViewBackgroundColorActiveWindow = [self colorInGroup:textView withKey:@"backgroundColor" forActiveWindow:YES];
	self.textViewBackgroundColorInactiveWindow = [self colorInGroup:textView withKey:@"backgroundColor" forActiveWindow:NO];
	self.textViewOutlineColorActiveWindow = [self colorInGroup:textView withKey:@"outlineColor" forActiveWindow:YES];
	self.textViewOutlineColorInactiveWindow = [self colorInGroup:textView withKey:@"outlineColor" forActiveWindow:NO];
	self.textViewInsideShadowColorActiveWindow = [self colorInGroup:textView withKey:@"insideShadowColor" forActiveWindow:YES];
	self.textViewInsideShadowColorInactiveWindow = [self colorInGroup:textView withKey:@"insideShadowColor" forActiveWindow:NO];
	self.textViewInsideGradientActiveWindow = [self gradientInGroup:textView withKey:@"insideGradient" forActiveWindow:YES];
	self.textViewInsideGradientInactiveWindow = [self gradientInGroup:textView withKey:@"insideGradient" forActiveWindow:NO];
	self.textViewOutsidePrimaryShadowColorActiveWindow = [self colorInGroup:textView withKey:@"outsidePrimaryShadowColor" forActiveWindow:YES];
	self.textViewOutsidePrimaryShadowColorInactiveWindow = [self colorInGroup:textView withKey:@"outsidePrimaryShadowColor" forActiveWindow:NO];
	self.textViewOutsideSecondaryShadowColorActiveWindow = [self colorInGroup:textView withKey:@"outsideSecondaryShadowColor" forActiveWindow:YES];
	self.textViewOutsideSecondaryShadowColorInactiveWindow = [self colorInGroup:textView withKey:@"outsideSecondaryShadowColor" forActiveWindow:NO];
	self.textViewFont = [self fontInGroup:textView withKey:@"font"];
	self.textViewFontLarge = [self fontInGroup:textView withKey:@"fontLarge"];
	self.textViewFontExtraLarge = [self fontInGroup:textView withKey:@"fontExtraLarge"];
	self.textViewFontHumongous = [self fontInGroup:textView withKey:@"fontHumongous"];

	NSDictionary *backgroundView = properties[@"Background View"];

	self.backgroundViewBackgroundColor = [self colorInGroup:backgroundView withKey:@"backgroundColor"];
	self.backgroundViewDividerColor = [self colorInGroup:backgroundView withKey:@"dividerColor"];
	self.backgroundViewContentBorderPadding = [self measurementInGroup:backgroundView withKey:@"contentBorderPadding"];

	[self flushAppearanceProperties];
}

#pragma mark -
#pragma mark Everything Else

- (BOOL)preferredTextViewFontChanged
{
	return (self.textViewPreferredFontSize != [TPCPreferences mainTextViewFontSize]);
}

- (nullable NSFont *)textViewPreferredFont
{
	TVCMainWindowTextViewFontSize preferredFontSize = [TPCPreferences mainTextViewFontSize];

	self.textViewPreferredFontSize = preferredFontSize;

	NSFont *preferredFont = nil;

	if (preferredFontSize == TVCMainWindowTextViewFontSizeNormal) {
		preferredFont = self.textViewFont;
	} else if (preferredFontSize == TVCMainWindowTextViewFontSizeLarge) {
		preferredFont = self.textViewFontLarge;
	} else if (preferredFontSize == TVCMainWindowTextViewFontSizeExtraLarge) {
		preferredFont = self.textViewFontExtraLarge;
	} else if (preferredFontSize == TVCMainWindowTextViewFontSizeHumongous) {
		preferredFont = self.textViewFontHumongous;
	}

	return preferredFont;
}

@end

NS_ASSUME_NONNULL_END
