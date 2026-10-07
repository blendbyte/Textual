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

NS_ASSUME_NONNULL_BEGIN

#define TXCalibratedRGBColor(r, g, b)		([NSColor calibratedColorWithRed:r green:g blue:b alpha:1.0])

@implementation NSColor (TXColorHelper)

#pragma mark -
#pragma mark IRC Text Formatting Color Codes

+ (NSArray<NSColor *> *)formatterColors
{
	static NSArray<NSColor *> *colors = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		colors = @[
			/* 0 */  [NSColor formatterWhiteColor],
			/* 1 */  [NSColor formatterBlackColor],
			/* 2 */  [NSColor formatterNavyBlueColor],
			/* 3 */  [NSColor formatterDarkGreenColor],
			/* 4 */  [NSColor formatterRedColor],
			/* 5 */  [NSColor formatterBrownColor],
			/* 6 */  [NSColor formatterPurpleColor],
			/* 7 */  [NSColor formatterOrangeColor],
			/* 8 */  [NSColor formatterYellowColor],
			/* 9 */  [NSColor formatterLimeGreenColor],
			/* 10 */ [NSColor formatterTealColor],
			/* 11 */ [NSColor formatterAquaCyanColor],
			/* 12 */ [NSColor formatterLightBlueColor],
			/* 13 */ [NSColor formatterFuchsiaPinkColor],
			/* 14 */ [NSColor formatterNormalGrayColor],
			/* 15 */ [NSColor formatterLightGrayColor],
			/* 16 */ [NSColor colorWithHexadecimalValue:@"#470000"],
			/* 17 */ [NSColor colorWithHexadecimalValue:@"#472100"],
			/* 18 */ [NSColor colorWithHexadecimalValue:@"#474700"],
			/* 19 */ [NSColor colorWithHexadecimalValue:@"#324700"],
			/* 20 */ [NSColor colorWithHexadecimalValue:@"#004700"],
			/* 21 */ [NSColor colorWithHexadecimalValue:@"#00472c"],
			/* 22 */ [NSColor colorWithHexadecimalValue:@"#004747"],
			/* 23 */ [NSColor colorWithHexadecimalValue:@"#002747"],
			/* 24 */ [NSColor colorWithHexadecimalValue:@"#000047"],
			/* 25 */ [NSColor colorWithHexadecimalValue:@"#2e0047"],
			/* 26 */ [NSColor colorWithHexadecimalValue:@"#470047"],
			/* 27 */ [NSColor colorWithHexadecimalValue:@"#47002a"],
			/* 28 */ [NSColor colorWithHexadecimalValue:@"#740000"],
			/* 29 */ [NSColor colorWithHexadecimalValue:@"#743a00"],
			/* 30 */ [NSColor colorWithHexadecimalValue:@"#747400"],
			/* 31 */ [NSColor colorWithHexadecimalValue:@"#517400"],
			/* 32 */ [NSColor colorWithHexadecimalValue:@"#007400"],
			/* 33 */ [NSColor colorWithHexadecimalValue:@"#007449"],
			/* 34 */ [NSColor colorWithHexadecimalValue:@"#007474"],
			/* 35 */ [NSColor colorWithHexadecimalValue:@"#004074"],
			/* 36 */ [NSColor colorWithHexadecimalValue:@"#000074"],
			/* 37 */ [NSColor colorWithHexadecimalValue:@"#4b0074"],
			/* 38 */ [NSColor colorWithHexadecimalValue:@"#740074"],
			/* 39 */ [NSColor colorWithHexadecimalValue:@"#740045"],
			/* 40 */ [NSColor colorWithHexadecimalValue:@"#b50000"],
			/* 41 */ [NSColor colorWithHexadecimalValue:@"#b56300"],
			/* 42 */ [NSColor colorWithHexadecimalValue:@"#b5b500"],
			/* 43 */ [NSColor colorWithHexadecimalValue:@"#7db500"],
			/* 44 */ [NSColor colorWithHexadecimalValue:@"#00b500"],
			/* 45 */ [NSColor colorWithHexadecimalValue:@"#00b571"],
			/* 46 */ [NSColor colorWithHexadecimalValue:@"#00b5b5"],
			/* 47 */ [NSColor colorWithHexadecimalValue:@"#0063b5"],
			/* 48 */ [NSColor colorWithHexadecimalValue:@"#0000b5"],
			/* 49 */ [NSColor colorWithHexadecimalValue:@"#7500b5"],
			/* 50 */ [NSColor colorWithHexadecimalValue:@"#b500b5"],
			/* 51 */ [NSColor colorWithHexadecimalValue:@"#b5006b"],
			/* 52 */ [NSColor colorWithHexadecimalValue:@"#ff0000"],
			/* 53 */ [NSColor colorWithHexadecimalValue:@"#ff8c00"],
			/* 54 */ [NSColor colorWithHexadecimalValue:@"#ffff00"],
			/* 55 */ [NSColor colorWithHexadecimalValue:@"#b2ff00"],
			/* 56 */ [NSColor colorWithHexadecimalValue:@"#00ff00"],
			/* 57 */ [NSColor colorWithHexadecimalValue:@"#00ffa0"],
			/* 58 */ [NSColor colorWithHexadecimalValue:@"#00ffff"],
			/* 59 */ [NSColor colorWithHexadecimalValue:@"#008cff"],
			/* 60 */ [NSColor colorWithHexadecimalValue:@"#0000ff"],
			/* 61 */ [NSColor colorWithHexadecimalValue:@"#a500ff"],
			/* 62 */ [NSColor colorWithHexadecimalValue:@"#ff00ff"],
			/* 63 */ [NSColor colorWithHexadecimalValue:@"#ff0098"],
			/* 64 */ [NSColor colorWithHexadecimalValue:@"#ff5959"],
			/* 65 */ [NSColor colorWithHexadecimalValue:@"#ffb459"],
			/* 66 */ [NSColor colorWithHexadecimalValue:@"#ffff71"],
			/* 67 */ [NSColor colorWithHexadecimalValue:@"#cfff60"],
			/* 68 */ [NSColor colorWithHexadecimalValue:@"#6fff6f"],
			/* 69 */ [NSColor colorWithHexadecimalValue:@"#65ffc9"],
			/* 70 */ [NSColor colorWithHexadecimalValue:@"#6dffff"],
			/* 71 */ [NSColor colorWithHexadecimalValue:@"#59b4ff"],
			/* 72 */ [NSColor colorWithHexadecimalValue:@"#5959ff"],
			/* 73 */ [NSColor colorWithHexadecimalValue:@"#c459ff"],
			/* 74 */ [NSColor colorWithHexadecimalValue:@"#ff66ff"],
			/* 75 */ [NSColor colorWithHexadecimalValue:@"#ff59bc"],
			/* 76 */ [NSColor colorWithHexadecimalValue:@"#ff9c9c"],
			/* 77 */ [NSColor colorWithHexadecimalValue:@"#ffd39c"],
			/* 78 */ [NSColor colorWithHexadecimalValue:@"#ffff9c"],
			/* 79 */ [NSColor colorWithHexadecimalValue:@"#e2ff9c"],
			/* 80 */ [NSColor colorWithHexadecimalValue:@"#9cff9c"],
			/* 81 */ [NSColor colorWithHexadecimalValue:@"#9cffdb"],
			/* 82 */ [NSColor colorWithHexadecimalValue:@"#9cffff"],
			/* 83 */ [NSColor colorWithHexadecimalValue:@"#9cd3ff"],
			/* 84 */ [NSColor colorWithHexadecimalValue:@"#9c9cff"],
			/* 85 */ [NSColor colorWithHexadecimalValue:@"#dc9cff"],
			/* 86 */ [NSColor colorWithHexadecimalValue:@"#ff9cff"],
			/* 87 */ [NSColor colorWithHexadecimalValue:@"#ff94d3"],
			/* 88 */ [NSColor colorWithHexadecimalValue:@"#000000"],
			/* 89 */ [NSColor colorWithHexadecimalValue:@"#131313"],
			/* 90 */ [NSColor colorWithHexadecimalValue:@"#282828"],
			/* 91 */ [NSColor colorWithHexadecimalValue:@"#363636"],
			/* 92 */ [NSColor colorWithHexadecimalValue:@"#4d4d4d"],
			/* 93 */ [NSColor colorWithHexadecimalValue:@"#656565"],
			/* 94 */ [NSColor colorWithHexadecimalValue:@"#818181"],
			/* 95 */ [NSColor colorWithHexadecimalValue:@"#9f9f9f"],
			/* 96 */ [NSColor colorWithHexadecimalValue:@"#bcbcbc"],
			/* 97 */ [NSColor colorWithHexadecimalValue:@"#e2e2e2"],
			/* 98 */ [NSColor colorWithHexadecimalValue:@"#ffffff"],
		];
	});

	return colors;
}

+ (NSColor *)formatterWhiteColor
{
	return TXCalibratedRGBColor(1.00, 1.00, 1.00);
}

+ (NSColor *)formatterBlackColor
{
	return TXCalibratedRGBColor(0.00, 0.00, 0.00);
}

+ (NSColor *)formatterNavyBlueColor
{
	return TXCalibratedRGBColor(0.04, 0.00, 0.52);
}

+ (NSColor *)formatterDarkGreenColor
{
	return TXCalibratedRGBColor(0.00, 0.54, 0.08);
}

+ (NSColor *)formatterRedColor
{
	return TXCalibratedRGBColor(1.00, 0.05, 0.04);
}

+ (NSColor *)formatterBrownColor
{
	return TXCalibratedRGBColor(0.55, 0.02, 0.02);
}

+ (NSColor *)formatterPurpleColor
{
	return TXCalibratedRGBColor(0.55, 0.00, 0.53);
}

+ (NSColor *)formatterOrangeColor
{
	return TXCalibratedRGBColor(1.00, 0.54, 0.09);
}

+ (NSColor *)formatterYellowColor
{
	return TXCalibratedRGBColor(1.00, 1.00, 0.15);
}

+ (NSColor *)formatterLimeGreenColor
{
	return TXCalibratedRGBColor(0.00, 1.00, 0.15);
}

+ (NSColor *)formatterTealColor
{
	return TXCalibratedRGBColor(0.00, 0.53, 0.53);
}

+ (NSColor *)formatterAquaCyanColor
{
	return TXCalibratedRGBColor(0.00, 1.00, 1.00);
}

+ (NSColor *)formatterLightBlueColor
{
	return TXCalibratedRGBColor(0.07, 0.00, 0.98);
}

+ (NSColor *)formatterFuchsiaPinkColor
{
	return TXCalibratedRGBColor(1.00, 0.00, 0.98);
}

+ (NSColor *)formatterNormalGrayColor
{
	return TXCalibratedRGBColor(0.53, 0.53, 0.53);
}

+ (NSColor *)formatterLightGrayColor
{
	return TXCalibratedRGBColor(0.80, 0.80, 0.80);
}

@end

NS_ASSUME_NONNULL_END
