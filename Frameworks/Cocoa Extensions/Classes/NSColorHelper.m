/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2018 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

NS_ASSUME_NONNULL_BEGIN

@implementation NSColor (CSColorHelper)

#pragma mark -
#pragma mark Custom Methods

+ (NSColor *)calibratedColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
	if (red > 1.0) {
		red /= 0xff;
	}
	
	if (green > 1.0) {
		green /= 0xff;
	}
	
	if (blue > 1.0) {
		blue /= 0xff;
	}

	if (alpha > 1.0) {
		alpha /= 0xff;
	}

	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

+ (NSColor *)calibratedDeviceColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
	if (red > 1.0) {
		red /= 0xff;
	}
	
	if (green > 1.0) {
		green /= 0xff;
	}
	
	if (blue > 1.0) {
		blue /= 0xff;
	}

	if (alpha > 1.0) {
		alpha /= 0xff;
	}
	
	return [NSColor colorWithDeviceRed:red green:green blue:blue alpha:alpha];
}

- (NSColor *)invertedColor
{
	NSColor *obj = [self colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];

	return [NSColor colorWithCalibratedRed:(1.0 - obj.redComponent)
									 green:(1.0 - obj.greenComponent)
									  blue:(1.0 - obj.blueComponent)
									 alpha:obj.alphaComponent];
}

- (BOOL)isInRGBColorSpace
{
COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
	NSString *colorSpaceName = self.colorSpaceName;
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

	return ([colorSpaceName isEqualToString:@"NSDeviceRGBColorSpace"] ||
			[colorSpaceName isEqualToString:@"NSCalibratedRGBColorSpace"]);
}

- (BOOL)isInGrayColorSpace
{
COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
	NSString *colorSpaceName = self.colorSpaceName;
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

	return ([colorSpaceName isEqualToString:@"NSDeviceWhiteColorSpace"] ||
			[colorSpaceName isEqualToString:@"NSDeviceBlackColorSpace"] ||
			[colorSpaceName isEqualToString:@"NSCalibratedWhiteColorSpace"] ||
			[colorSpaceName isEqualToString:@"NSCalibratedBlackColorSpace"]);
}

#pragma mark -
#pragma mark Hexadecimal Conversion

- (NSString *)hexadecimalValue
{
	return [self hexadecimalValueWithAlpha:NO];
}

- (NSString *)hexadecimalValueWithAlpha
{
	return [self hexadecimalValueWithAlpha:YES];
}

- (NSString *)hexadecimalValueWithAlpha:(BOOL)withAlpha
{
	CGFloat redValue = 0.0;
	CGFloat greenValue = 0.0;
	CGFloat blueValue = 0.0;

	if ([self isInGrayColorSpace]) {
		redValue = self.whiteComponent;
		greenValue = self.whiteComponent;
		blueValue = self.whiteComponent;
	} else {
		redValue = self.redComponent;
		greenValue = self.greenComponent;
		blueValue = self.blueComponent;
	}

	if (withAlpha) {
		CGFloat alphaValue = self.alphaComponent;

		return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
				(NSInteger)(redValue * 0xff),
				(NSInteger)(greenValue * 0xff),
				(NSInteger)(blueValue * 0xff),
				(NSInteger)(alphaValue * 0xff)];
	} else {
		return [NSString stringWithFormat:@"#%02X%02X%02X",
				(NSInteger)(redValue * 0xff),
				(NSInteger)(greenValue * 0xff),
				(NSInteger)(blueValue * 0xff)];
	}
}

+ (nullable NSColor *)colorWithHexadecimalValue:(NSString *)string
{
	if ([string hasPrefix:@"#"]) {
		 string = [string substringFromIndex:1];
	}

	if (string.length == 0 ||
		string.length > 8 ||
		(string.length % 2) != 0)
	{
		return nil;
	}

	long colorTotal = strtol(string.UTF8String, NULL, 16);

	if (string.length < 8) {
		colorTotal <<= 8;

		colorTotal |= 0xFF;
	}

	NSInteger r = ((colorTotal & 0xff000000) >> 24);
	NSInteger g = ((colorTotal & 0x00ff0000) >> 16);
	NSInteger b = ((colorTotal & 0x0000ff00) >> 8);
	NSInteger a =  (colorTotal & 0x000000ff);

	return [NSColor calibratedDeviceColorWithRed:r green:g blue:b alpha:a];
}

- (BOOL)isShadeOfGray
{
	if ([self isInRGBColorSpace]) {
		CGFloat redValue = self.redComponent;
		CGFloat greenValue = self.greenComponent;
		CGFloat blueValue = self.blueComponent;

		if (CGFloatAreEqual(redValue, greenValue) &&
			CGFloatAreEqual(greenValue, blueValue) &&
			CGFloatAreEqual(redValue, blueValue))
		{
			return YES;
		}
	} else if ([self isInGrayColorSpace]) {
		return YES;
	}

	return NO;
}

@end

#pragma mark -

@implementation NSGradient (CSGradientHelper)

+ (nullable NSGradient *)gradientWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor
{
	return [[self alloc] initWithStartingColor:startingColor endingColor:endingColor];
}

@end

NS_ASSUME_NONNULL_END
