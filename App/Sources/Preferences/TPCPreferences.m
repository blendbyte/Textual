/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "TPCPreferencesUserDefaults.h"
#import "TPCPreferencesPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TPCPreferences

#pragma mark -
#pragma mark Inline Image Size

+ (uint64_t)inlineImagesMaxFilesize
{
	NSUInteger filesizeTag = [RZUserDefaults() unsignedIntegerForKey:@"InlineMediaMaximumFilesize"];

	switch (filesizeTag) {
#define _dv(key, value)		case (key): { return (value); }

		_dv(1, (uint64_t)1048576) // 1 MB
		_dv(2, (uint64_t)2097152) // 2 MB
		_dv(3, (uint64_t)3145728) // 3 MB
		_dv(4, (uint64_t)4194304) // 4 MB
		_dv(5, (uint64_t)5242880) // 5 MB
		_dv(6, (uint64_t)10485760) // 10 MB
		_dv(7, (uint64_t)15728640) // 15 MB
		_dv(8, (uint64_t)20971520) // 20 MB
		_dv(9, (uint64_t)52428800) // 50 MB
		_dv(10, (uint64_t)104857600) // 100 MB

#undef _dv
	}

	return (uint64_t)2097152; // 2 MB
}

+ (NSUInteger)inlineMediaMaxWidth
{
	return [RZUserDefaults() unsignedIntegerForKey:@"InlineMediaScalingWidth"];
}

+ (NSUInteger)inlineMediaMaxHeight
{
	return [RZUserDefaults() unsignedIntegerForKey:@"InlineMediaMaximumHeight"];
}

+ (void)setInlineMediaMaxWidth:(NSUInteger)value
{
	[RZUserDefaults() setUnsignedInteger:value forKey:@"InlineMediaScalingWidth"];
}

+ (void)setInlineMediaMaxHeight:(NSUInteger)value
{
	[RZUserDefaults() setUnsignedInteger:value forKey:@"InlineMediaMaximumHeight"];
}

+ (BOOL)inlineMediaLimitToBasics
{
	return [RZUserDefaults() boolForKey:@"InlineMediaLimitToBasics"];
}

+ (void)setInlineMediaLimitToBasics:(BOOL)inlineMediaLimitToBasics
{
	[RZUserDefaults() setBool:inlineMediaLimitToBasics forKey:@"InlineMediaLimitToBasics"];
}

+ (BOOL)inlineMediaLimitBasicsToFiles
{
	return [RZUserDefaults() boolForKey:@"InlineMediaLimitBasicsToFiles"];
}

+ (void)setInlineMediaLimitBasicsToFiles:(BOOL)inlineMediaLimitBasicsToFiles
{
	[RZUserDefaults() setBool:inlineMediaLimitBasicsToFiles forKey:@"InlineMediaLimitBasicsToFiles"];
}

+ (BOOL)inlineMediaLimitInsecureContent
{
	return [RZUserDefaults() boolForKey:@"InlineMediaLimitInsecureContent"];
}

+ (BOOL)inlineMediaLimitNaughtyContent
{
	return [RZUserDefaults() boolForKey:@"InlineMediaLimitNaughtyContent"];
}

+ (BOOL)inlineMediaLimitUnsafeContent
{
	return [RZUserDefaults() boolForKey:@"InlineMediaLimitUnsafeContent"];
}

+ (BOOL)inlineMediaCheckEverything
{
	return [RZUserDefaults() boolForKey:@"InlineMediaCheckEverything"];
}

@end

NS_ASSUME_NONNULL_END
