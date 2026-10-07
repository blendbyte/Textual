/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

#import "ICLHelpers.h"
#import "ICMCommonInlineVideos.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMCommonInlineVideos ()
@property (readonly, copy, class) NSArray<NSString *> *validFileExtensions;
@end

@implementation ICMCommonInlineVideos

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSString *address = [self _finalAddressForURL:url];

	if (address == nil) {
		return nil;
	}

	return [super actionBlockForAddress:address];
}

+ (nullable NSString *)_finalAddressForURL:(NSURL *)url
{
	NSString *urlHost = url.host;
	NSString *urlPath = url.path.percentEncodedURLPath;
	NSString *urlPathExtension = urlPath.pathExtension.lowercaseString;

	BOOL hasFileExtension = [self.validFileExtensions containsObject:urlPathExtension];

	if (hasFileExtension) {
		if ([urlHost isDomain:@"video.nest.com"]) {
			/* Processed below */
		} else {
			return url.absoluteString;
		}
	}

	if ([urlHost isDomain:@"video.nest.com"])
	{
		if ([urlPath hasPrefix:@"/clip/"] == NO) {
			return nil;
		}

		NSString *filename = urlPath.lastPathComponent;

		NSString *filenameWithoutExtension = filename.stringByDeletingPathExtension;

		if (filenameWithoutExtension.alphabeticNumericOnly) {
			return [NSString stringWithFormat:@"http://clips.dropcam.com/%@", filename];
		}
	}

	return nil;
}

+ (NSArray<NSString *> *)validFileExtensions
{
	static NSArray<NSString *> *cachedValue = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		cachedValue =
		@[@"mp4",
		  @"mov",
		  @"m4v",
		  @"3gp",
		  @"3g2"];
	});

	return cachedValue;
}

+ (BOOL)contentIsFile
{
	return YES;
}

@end

NS_ASSUME_NONNULL_END
