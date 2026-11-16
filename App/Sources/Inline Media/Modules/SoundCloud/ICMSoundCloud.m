/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "ICMSoundCloud.h"

NS_ASSUME_NONNULL_BEGIN

/* Page cards for SoundCloud tracks and sets: title, artist, artwork and
 description from SoundCloud's oEmbed */
@implementation ICMSoundCloud

- (void)_performAction
{
	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://soundcloud.com/oembed"];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"format" value:@"json"],
	  [NSURLQueryItem queryItemWithName:@"url" value:self.payload.address]
	];

	[ICLHelpers requestJSONDataFromURL:requestComponents.URL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSString *title = [data stringForKey:@"title"];

		if (title == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePage;
		card.targetURL = self.payload.url;
		card.title = title;

		NSString *description = [data stringForKey:@"description"];

		if (description) {
			card.text = [ICLHelpers plainTextFromHTMLFragment:description];
		}

		NSString *thumbnail = [data stringForKey:@"thumbnail_url"];

		if (thumbnail) {
			card.imageURL = [ICLHelpers URLWithString:thumbnail];
		}

		card.details = @[@"SoundCloud", ([data stringForKey:@"author_name"] ?: @"")];

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

/* soundcloud.com/<artist>/<track or sets/…>, not SoundCloud's own pages */
+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSArray<NSString *> *components = [[url.path.percentEncodedURLPath trimCharacters:@"/"] componentsSeparatedByString:@"/"];

	if (components.count < 2 || components[0].length == 0 || components[1].length == 0) {
		return nil;
	}

	NSArray *reserved = @[@"discover", @"stream", @"you", @"search", @"upload", @"pages", @"terms-of-use", @"settings", @"messages", @"notifications", @"charts", @"jobs", @"imprint", @"mobile"];

	if ([reserved containsObject:components[0].lowercaseString]) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		[(ICMSoundCloud *)module _performAction];
	} copy];
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"soundcloud.com", @"www.soundcloud.com", @"m.soundcloud.com"];
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"SoundCloud");
}

+ (nullable NSArray<NSString *> *)serviceHosts
{
	return @[@"sndcdn.com"];
}

@end

NS_ASSUME_NONNULL_END
