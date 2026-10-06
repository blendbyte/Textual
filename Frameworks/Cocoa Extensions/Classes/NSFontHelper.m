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

@implementation NSFont (CSFontHelper)

const CGFloat kRotationForItalicText = -14.0;   

- (nullable NSFont *)convertToItalics
{ 
	NSFont *theFont = [[NSFontManager sharedFontManager] convertFont:self toHaveTrait:NSItalicFontMask];
	
	if ([self fontTraitSet:NSItalicFontMask] == NO) {       
		NSAffineTransform *fontTransform = [NSAffineTransform transform];    
		NSAffineTransform *italicTransform = [NSAffineTransform transform];  
		
		[fontTransform scaleBy:self.pointSize];
		
		NSAffineTransformStruct italicTransformData;   
		
		italicTransformData.m11 = 1;       
		italicTransformData.m12 = 0;       
		italicTransformData.m21 = (-tan(kRotationForItalicText * (acos(0) / 90)));
		italicTransformData.m22 = 1;         
		italicTransformData.tX = 0;       
		italicTransformData.tY = 0;      
		     
		italicTransform.transformStruct = italicTransformData;
		
		[fontTransform appendTransform:italicTransform]; 
		
		theFont = [NSFont fontWithDescriptor:theFont.fontDescriptor textTransform:fontTransform];  
		
		if (theFont) {
			return theFont;
		}
	}
	
	return self;
}

- (BOOL)fontTraitSet:(NSFontTraitMask)trait
{
	NSFontTraitMask fontTraits = [[NSFontManager sharedFontManager] traitsOfFont:self];
	
	return ((fontTraits & trait) == trait);
}

+ (BOOL)fontIsAvailable:(NSString *)fontName
{
	NSParameterAssert(fontName != nil);

	if ([NSFont fontWithName:fontName size:9.0]) {
		return YES;
	}
	
	NSArray *systemFonts = [NSFontManager sharedFontManager].availableFonts;
	
	return ([systemFonts containsObjectIgnoringCase:fontName]);
}

- (BOOL)fontMatchesName:(NSString *)fontName
{
	return ([self.fontName isEqualIgnoringCase:fontName]);
}

@end

NS_ASSUME_NONNULL_END
