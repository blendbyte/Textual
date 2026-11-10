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

#import "TPCPreferences.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocalPrivate.h"
#import "ICLInlineContentLoaderPrivate.h"
#import "ICLHelpers.h"
#import "ICLMediaSchemeHandlerPrivate.h"
#import "ICMPreviewCard.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICMPreviewCardContent
@end

#pragma mark -

@implementation ICMPreviewCard

- (void)performActionForCard:(ICMPreviewCardContent *)card
{
	NSParameterAssert(card != nil);

	ICLPayloadMutable *payload = self.payload;

	NSURL *targetURL = card.targetURL;

	NSString *targetScheme = targetURL.scheme.lowercaseString;

	if ([targetScheme isEqualToString:@"https"] == NO && [targetScheme isEqualToString:@"http"] == NO) {
		[self notifyUnableToPresentCard];

		return;
	}

	NSMutableDictionary<NSString *, id> *templateAttributes = [NSMutableDictionary dictionary];

	templateAttributes[@"uniqueIdentifier"] = payload.uniqueIdentifier;
	templateAttributes[@"hideLabel"] = TXTLS(@"TVCMainWindow[icm-h1]");
	templateAttributes[@"classAttribute"] = payload.classAttribute;
	templateAttributes[@"targetURL"] = targetURL.absoluteString;

	/* A service's card comes from its HTTPS API: an http:// link to it is
	 shown as its https form (it was refused, after the API had been asked) */
	if ([self.class serviceName] && [payload.urlToInline.scheme.lowercaseString isEqualToString:@"http"]) {
		NSURLComponents *components = [NSURLComponents componentsWithURL:payload.urlToInline resolvingAgainstBaseURL:NO];

		components.scheme = @"https";

		if (components.URL) {
			payload.urlToInline = components.URL;
		}
	}

	switch (card.style) {
		case ICMPreviewCardStyleVideo:
		{
			templateAttributes[@"isVideo"] = @(YES);
			templateAttributes[@"style"] = @"video";

			break;
		}
		case ICMPreviewCardStylePost:
		{
			templateAttributes[@"isPost"] = @(YES);
			templateAttributes[@"style"] = @"post";

			break;
		}
		case ICMPreviewCardStylePage:
		{
			templateAttributes[@"isPage"] = @(YES);
			templateAttributes[@"style"] = @"page";

			break;
		}
	}

	templateAttributes[@"title"] = card.title.trim;
	templateAttributes[@"text"] = card.text.trim;
	templateAttributes[@"authorName"] = card.authorName.trim;
	templateAttributes[@"authorHandle"] = card.authorHandle.trim;

	/* Pictures load through Textual, under the image size limit */
	templateAttributes[@"imageURL"] = [self _mediaAddressForImageURL:card.imageURL];
	templateAttributes[@"avatarURL"] = [self _mediaAddressForImageURL:card.avatarURL];

	if (card.duration > 0) {
		templateAttributes[@"duration"] = [self.class formattedDuration:card.duration];
	}

	NSMutableArray<NSString *> *details = [NSMutableArray array];

	for (NSString *detail in card.details) {
		NSString *trimmedDetail = detail.trim;

		if (trimmedDetail.length > 0) {
			[details addObject:trimmedDetail];
		}
	}

	if (details.count > 0) {
		templateAttributes[@"details"] = [details componentsJoinedByString:@" · "];
	}

	NSMutableArray<NSDictionary *> *dataAttributes = [NSMutableArray array];

	[card.dataAttributes enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
		/* Names are Textual's own; only letters, digits and dashes */
		if ([name onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"]] == NO) {
			return;
		}

		[dataAttributes addObject:@{@"name" : name, @"value" : value}];
	}];

	templateAttributes[@"dataAttributes"] = dataAttributes;

	templateAttributes[@"playsInWindow"] = @(card.playsInWindow);

	NSError *templateRenderError = nil;

	NSString *html = [self.template renderObject:templateAttributes error:&templateRenderError];

	payload.html = html;

	[self finalizeWithError:templateRenderError];
}

- (nullable NSString *)_mediaAddressForImageURL:(nullable NSURL *)imageURL
{
	if (imageURL == nil || [imageURL.scheme.lowercaseString isEqualToString:@"https"] == NO) {
		return nil;
	}

	/* A page's own picture (og:image) can be on any site: the site rules
	 apply to it. A service's pictures come from its own hosts. */
	if ([self.class serviceName] == nil && imageURL.host &&
		[ICLInlineContentLoader host:imageURL.host isPreviewedWithDomains:[TPCPreferences inlineMediaDomains] mode:[TPCPreferences inlineMediaDomainRuleMode]] == NO)
	{
		return nil;
	}

	NSURL *mediaURL =
	[[ICLMediaSchemeHandler sharedHandler] URLForMediaAtURL:imageURL
													session:self.payload.session
													   type:ICLMediaTypeImage
											  maximumLength:[TPCPreferences inlineImagesMaxFilesize]];

	return mediaURL.absoluteString;
}

- (void)notifyUnableToPresentCard
{
	[self cancel];
}

+ (NSString *)formattedDuration:(NSTimeInterval)duration
{
	NSUInteger seconds = (NSUInteger)round(duration);

	NSUInteger hours = (seconds / 3600);
	NSUInteger minutes = ((seconds % 3600) / 60);

	seconds = (seconds % 60);

	if (hours > 0) {
		return [NSString stringWithFormat:@"%lu:%02lu:%02lu", hours, minutes, seconds];
	}

	return [NSString stringWithFormat:@"%lu:%02lu", minutes, seconds];
}

#pragma mark -
#pragma mark Resources

- (nullable NSURL *)templateURL
{
	return ICLResourceURL(@"ICMPreviewCard", @"mustache");
}

- (nullable NSArray<NSURL *> *)scriptResources
{
	static NSArray<NSURL *> *scriptResources = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		scriptResources =
		@[
		  ICLResourceURL(@"ICMPreviewCard", @"js")
		];
	});

	return scriptResources;
}

- (nullable NSString *)entrypoint
{
	return @"_ICMPreviewCard";
}

- (void)finalizePreflight
{
	self.payload.classAttribute = @"inlinePreviewCard";
}

@end

NS_ASSUME_NONNULL_END
