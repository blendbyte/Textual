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
#import "ICMDailymotion.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICMDailymotion

/* A video card from Dailymotion's API: title, owner, thumbnail and length */
- (void)_performActionForVideo:(NSString *)videoIdentifier
{
	NSParameterAssert(videoIdentifier != nil);

	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://api.dailymotion.com/video/"];

	requestComponents.path = [requestComponents.path stringByAppendingString:videoIdentifier];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"fields" value:@"title,owner.screenname,thumbnail_480_url,duration"]
	];

	[ICLHelpers requestJSONDataFromURL:requestComponents.URL
							   session:self.payload.session
					   completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		if (success == NO || [data stringForKey:@"title"] == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStyleVideo;

		card.targetURL = self.payload.url;

		card.title = [data stringForKey:@"title"];

		NSString *thumbnail = [data stringForKey:@"thumbnail_480_url"];

		if (thumbnail) {
			card.imageURL = [ICLHelpers URLWithString:thumbnail];
		}

		card.duration = [data doubleForKey:@"duration"];

		NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:@"Dailymotion"];

		NSString *owner = [data stringForKey:@"owner.screenname"];

		if (owner) {
			[details addObject:owner];
		}

		card.details = details;

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *videoIdentifier = [self _videoIdentifierForURL:url];

	if (videoIdentifier == nil) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		__weak ICMDailymotion *moduleTyped = (id)module;

		[moduleTyped _performActionForVideo:videoIdentifier];
	} copy];
}

+ (nullable NSString *)_videoIdentifierForURL:(NSURL *)url
{
	NSString *urlPath = url.path.percentEncodedURLPath;

	if ([urlPath hasPrefix:@"/video/"] == NO) {
		return nil;
	}

	urlPath = [urlPath substringFromIndex:7]; // "/video/"

	/* Cut after first underscore so that URLs such as:
	 http://www.dailymotion.com/video/x19pvwt_the-fantastic-four-1994-unreleased-roger-corman_shortfilms
	 Automatically translate to their parent:
	 http://www.dailymotion.com/video/x19pvwt */
	NSInteger underscorePosition = [urlPath stringPosition:@"_"];

	if (underscorePosition > 0) {
		urlPath = [urlPath substringToIndex:underscorePosition];
	}

	NSString *videoIdentifier = urlPath;

	if (videoIdentifier.isAlphabeticNumericOnly == NO) {
		return nil;
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
		  @"dailymotion.com",
		  @"www.dailymotion.com",
		  @"mobile.dailymotion.com"
		];
	});

	return domains;
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"Dailymotion");
}

+ (nullable NSArray<NSString *> *)serviceHosts
{
	return @[@"dmcdn.net", @"dai.ly"];
}

@end

NS_ASSUME_NONNULL_END
