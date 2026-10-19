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

#import "TLOLocalization.h"
#import "ICLHelpers.h"
#import "ICMInlineVideo.h"
#import "ICMYouTube.h"

NS_ASSUME_NONNULL_BEGIN

/* A video card from YouTube's oEmbed (title, channel); the thumbnail's
 address is YouTube's fixed one, so the card has a picture even when oEmbed
 fails. The video ID and start time are kept on the card for click-to-play
. */
@implementation ICMYouTube

- (void)_performActionForVideo:(NSString *)videoIdentifier startTime:(NSTimeInterval)startTime
{
	NSParameterAssert(videoIdentifier != nil);

	NSString *watchAddress = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", videoIdentifier];

	/* The privacy-enhanced domain, like the player */
	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://www.youtube-nocookie.com/oembed"];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"url" value:watchAddress],
	  [NSURLQueryItem queryItemWithName:@"format" value:@"json"]
	];

	[ICLHelpers requestJSONDataFromURL:requestComponents.URL
							   session:self.payload.session
					   completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStyleVideo;

		card.targetURL = self.payload.url;

		card.title = [data stringForKey:@"title"];

		card.imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/hqdefault.jpg", videoIdentifier]];

		NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:@"YouTube"];

		NSString *channel = [data stringForKey:@"author_name"];

		if (channel) {
			[details addObject:channel];
		}

		card.details = details;

		card.dataAttributes =
		@{
		  @"youtube-video" : videoIdentifier,
		  @"youtube-start" : [NSString stringWithFormat:@"%.0f", startTime]
		};

		card.playsInWindow = YES;

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSTimeInterval startTime = 0;

	NSString *videoIdentifier = [self _videoIdentifierForURL:url startTime:&startTime];

	if (videoIdentifier == nil) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		__weak ICMYouTube *moduleTyped = (id)module;

		[moduleTyped _performActionForVideo:videoIdentifier startTime:startTime];
	} copy];
}

/* youtu.be/ID, youtube.com/watch?v=ID, /shorts/ID, /live/ID, /embed/ID */
+ (nullable NSString *)_videoIdentifierForURL:(NSURL *)url startTime:(NSTimeInterval *)startTime
{
	NSString *videoIdentifier = nil;

	NSString *urlHost = url.host.lowercaseString;
	NSString *urlPath = url.path.percentEncodedURLPath;

	NSDictionary *queryItems = url.query.percentEncodedURLQuery.URLQueryItems;

	NSArray<NSString *> *pathComponents = [[urlPath trimCharacters:@"/"] componentsSeparatedByString:@"/"];

	if ([urlHost isEqualToString:@"youtu.be"])
	{
		videoIdentifier = pathComponents.firstObject;
	}
	else if ([urlHost isDomainOrSubdomain:@"youtube.com"])
	{
		if ([urlPath isEqualToString:@"/watch"]) {
			videoIdentifier = queryItems[@"v"];
		} else if (pathComponents.count >= 2 &&
				   ([pathComponents[0] isEqualToString:@"shorts"] ||
					[pathComponents[0] isEqualToString:@"live"] ||
					[pathComponents[0] isEqualToString:@"embed"]))
		{
			videoIdentifier = pathComponents[1];
		}
	}

	/* IDs are 11 characters of letters, digits, - and _ */
	if (videoIdentifier.length < 11) {
		return nil;
	}

	videoIdentifier = [videoIdentifier substringToIndex:11];

	if ([videoIdentifier onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"]] == NO) {
		return nil;
	}

	NSString *timestamp = queryItems[@"t"];

	if (timestamp) {
		*startTime = [ICMInlineVideoFoundation parseYouTubeEsqueTimestamp:timestamp];
	}

	return videoIdentifier;
}

+ (nullable NSArray<NSString *> *)domains
{
	static NSArray<NSString *> *domains = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		domains =
		@[
		  @"youtube.com",
		  @"www.youtube.com",
		  @"m.youtube.com",
		  @"music.youtube.com",
		  @"youtu.be"
		];
	});

	return domains;
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"YouTube");
}

@end

NS_ASSUME_NONNULL_END
