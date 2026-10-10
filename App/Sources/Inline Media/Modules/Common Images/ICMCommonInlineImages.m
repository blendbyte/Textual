/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2020 Codeux Software, LLC & respective contributors.
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

#import "TPCPreferences.h"
#import "ICLHelpers.h"
#import "ICMCommonInlineImages.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMCommonInlineImages ()
@property (readonly, copy, class) NSArray<NSString *> *validFileExtensions;
@end

@implementation ICMCommonInlineImages

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
		if ([urlHost isDomainOrSubdomain:@"wikipedia.org"]) {
			/* Wikipedia URLs end with a file extension but tend to be a web page.
			 There was no easy way hotlink these images at the time this exception
			 was added. This should be revisited at a later time... */

			return nil;
		} else if ([urlHost isDomainOrSubdomain:@"dropbox.com"]) {
			/* Processed below */
		} else {
			return url.absoluteString;
		}
	}

	NSString *urlScheme = url.scheme;
	NSString *urlQuery = url.query.percentEncodedURLQuery;

	NSString *urlPathCombined = urlPath;

	if (urlQuery) {
		urlPathCombined = [urlPathCombined stringByAppendingFormat:@"?%@", urlQuery];
	}

	if ([urlHost isDomainOrSubdomain:@"dropbox.com"])
	{
		if ([urlPathCombined hasPrefix:@"/s/"] && hasFileExtension) {
			return [@"https://dl.dropboxusercontent.com" stringByAppendingString:urlPathCombined];
		}
	}
	else if ([urlHost isDomain:@"pbs.twimg.com"])
	{
		if (urlPath.length == 0) {
			return nil;
		}

		urlPath = [urlPath
				   stringByReplacingOccurrencesOfString:@"\\:(large|medium|orig|small|thumb)$"
											 withString:@""
												options:NSRegularExpressionSearch
												  range:urlPath.range];

		return [NSString stringWithFormat:@"https://pbs.twimg.com%@:orig", urlPath];
	}
	else if ([urlHost isDomain:@"docs.google.com"])
	{
		if ([urlPath hasPrefix:@"/file/d/"] == NO) {
			return nil;
		}

		NSString *photoId = nil;

		NSArray *components = [urlPath componentsSeparatedByString:@"/"];

		if (components.count == 5) {
			if ([components[4] isEqualToString:@"edit"]) { // Add a little validation
				photoId = components[3];
			}
		} else if (components.count == 4) {
			photoId = components[3];
		} else {
			return nil;
		}

		if (photoId) {
			return [@"https://docs.google.com/uc?id=" stringByAppendingString:photoId];
		}
	}
	else if ([urlHost isDomainOrSubdomain:@"twitpic.com"])
	{
		if (urlPath.length == 0) {
			return nil;
		}

		NSString *s = [urlPath substringFromIndex:1];

		if ([s hasSuffix:@"/full"]) {
			s = [s substringToIndex:(s.length - 5)];
		}

		if (s.alphabeticNumericOnly) {
			return [NSString stringWithFormat:@"http://twitpic.com/show/large/%@", s];
		}
	}
	else if ([urlHost isDomainOrSubdomain:@"instagram.com"] ||
			 [urlHost isDomainOrSubdomain:@"instagr.am"])
	{
		if ([urlPath hasPrefix:@"/p/"] == NO) {
			return nil;
		}

		NSString *s = [urlPath substringFromIndex:3];

		if ([s onlyContainsCharactersFromCharacterSet:[NSCharacterSet Ato9UnderscoreDash]]) {
			return [NSString stringWithFormat:@"https://www.instagram.com/p/%@/media/?size=l", s];
		}
	}
	else if ([urlHost isDomainOrSubdomain:@"i.4cdn.org"])
	{
		if ([urlPath hasSuffix:@".webm"] == NO) {
			return nil;
		}

		NSString *filenameWithoutExtension = urlPath.stringByDeletingPathExtension;

		return [NSString stringWithFormat:@"%@://%@%@s.jpg", urlScheme, urlHost, filenameWithoutExtension];
	}
	else if ([urlHost isDomainOrSubdomain:@"8ch.net"])
	{
		if ([urlPath hasSuffix:@".webm"] == NO) {
			return nil;
		}

		NSString *filename = urlPath.lastPathComponent;

		NSString *filenameWithoutExtension = filename.stringByDeletingPathExtension;

		return [NSString stringWithFormat:@"%@://%@/webm/thumb/%@.jpg", urlScheme, urlHost, filenameWithoutExtension];
	}
	else if ([urlHost isDomainOrSubdomain:@"f.hatena.ne.jp"])
	{
		NSArray *components = [urlPath componentsSeparatedByString:@"/"];

		if (components.count < 3) {
			return nil;
		}

		NSString *userId = components[1];
		NSString *photoId = components[2];

		if (userId.length == 0 || photoId.length < 8) {
			return nil;
		}

		if (photoId.numericOnly == NO) {
			return nil;
		}

		NSString *userIdHead = [userId substringToIndex:1];
		NSString *photoIdHead = [photoId substringToIndex:8];

		return [NSString stringWithFormat:@"http://img.f.hatena.ne.jp/images/fotolife/%@/%@/%@/%@.jpg", userIdHead, userId, photoIdHead, photoId];
	}
	else if ([urlHost isDomain:@"puu.sh"])
	{
		if (urlPath.length == 0) {
			return nil;
		}

		NSString *s = [urlPath substringFromIndex:1];

		if (s.alphabeticNumericOnly) {
			return [NSString stringWithFormat:@"http://puu.sh/%@.jpg", s];
		}
	}
	else if ([urlHost isDomainOrSubdomain:@"d.pr"])
	{
		if ([urlPath hasPrefix:@"/i/"] == NO) {
			return nil;
		}

		NSString *s = [urlPath substringFromIndex:3];

		if (s.alphabeticNumericOnly) {
			return [NSString stringWithFormat:@"http://d.pr/i/%@.png", s];
		}
	}
	else if ([urlHost isDomainOrSubdomain:@"nicovideo.jp"] ||
			 [urlHost isDomain:@"nico.ms"])
	{
		if (urlPath.length == 0) {
			return nil;
		}

		NSString *videoId = nil;

		NSString *s = nil;

		if ([urlHost isDomain:@"nico.ms"]) {
			s = [urlPath substringFromIndex:1];
		} else if ([urlPath hasPrefix:@"/watch/"]) {
			s = [urlPath substringFromIndex:7];
		}

		if ([s hasPrefix:@"sm"] || [s hasPrefix:@"nm"]) {
			videoId = s;
		}

		if (videoId.length < 3) {
			return nil;
		}

		long long videoNumber = [videoId substringFromIndex:2].longLongValue;

		return [NSString stringWithFormat:@"http://tn-skr%lli.smilevideo.jp/smile?i=%lli", ((videoNumber % 4) + 1), videoNumber];
	}
	else if ([urlHost isDomain:@"i.reddituploads.com"])
	{
		if (urlPath.length == 0) {
			return nil;
		}

		NSString *s = [urlPath substringFromIndex:1];

		if (s.alphabeticNumericOnly) {
			return url.absoluteString;
		}
	}
	else if ([urlHost isDomainOrSubdomain:@"youtube.com"] ||
			 [urlHost isDomain:@"youtu.be"])
	{
		/* If we aren't allowed to embed YouTube,
		 at least show show the thumbnail for the video. */
		if ([TPCPreferences inlineMediaLimitBasicsToFiles] == NO) {
			return nil;
		}

		if (urlPath.length == 0) {
			return nil;
		}

		NSString *videoId = nil;

		if ([urlHost isDomain:@"youtu.be"]) {
			videoId = [urlPath substringFromIndex:1];
		} else {
			NSDictionary *queryItems = urlQuery.URLQueryItems;

			videoId = queryItems[@"v"];
		}

		if (videoId.length < 11) {
			return nil;
		}

		if (videoId.length > 11) {
			videoId = [videoId substringToIndex:11];
		}

		return [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg", videoId];
	}
	else if ([urlHost isDomainOrSubdomain:@"speedtest.net"])
	{
		NSArray *components = [urlPath componentsSeparatedByString:@"/"];

		if (components.count < 3) {
			return nil;
		}

		if ([components[1] isEqualToString:@"result"] == NO) {
			return nil;
		}

		NSString *resultId = components[2];

		if (resultId.numericOnly == NO) {
			return nil;
		}

		return [NSString stringWithFormat:@"https://www.speedtest.net/result/%@.png", resultId];
	}
	else if ([urlHost isDomain:@"fuelrats.cloud"])
	{
		if ([urlPath hasPrefix:@"/s/"] == NO) {
			return nil;
		}

		NSString *s = [urlPath substringFromIndex:3];

		if (s.alphabeticNumericOnly) {
			return [NSString stringWithFormat:@"https://fuelrats.cloud/s/%@/preview", s];
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
		@[@"jpg",
		  @"jpeg",
		  @"png",
		  @"gif",
		  @"tif",
		  @"tiff",
		  @"svg",
		  @"bmp"];
	});

	return cachedValue;
}

+ (BOOL)contentIsFile
{
	return YES;
}

@end

NS_ASSUME_NONNULL_END
