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
#import "ICMReddit.h"

NS_ASSUME_NONNULL_BEGIN

/* Post cards for Reddit posts: title and author from Reddit's oEmbed, the
 subreddit from the address */
@implementation ICMReddit

- (void)_performActionForPost:(NSString *)post inSubreddit:(nullable NSString *)subreddit
{
	NSString *postAddress = ((subreddit) ?
		[NSString stringWithFormat:@"https://www.reddit.com/r/%@/comments/%@/", subreddit, post] :
		[NSString stringWithFormat:@"https://www.reddit.com/comments/%@/", post]);

	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://www.reddit.com/oembed"];

	requestComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"url" value:postAddress]];

	[ICLHelpers requestJSONDataFromURL:requestComponents.URL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSString *title = [data stringForKey:@"title"];

		if (title == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePost;
		card.targetURL = self.payload.url;
		card.text = title;

		NSString *author = [data stringForKey:@"author_name"];

		if (author) {
			card.authorName = [@"u/" stringByAppendingString:author];
		}

		card.details = @[@"Reddit", ((subreddit) ? [@"r/" stringByAppendingString:subreddit] : @"")];

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

/* /r/<subreddit>/comments/<post>/…, /comments/<post>/…, redd.it/<post> */
+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSArray<NSString *> *components = [[url.path.percentEncodedURLPath trimCharacters:@"/"] componentsSeparatedByString:@"/"];

	NSString *subreddit = nil;
	NSString *post = nil;

	if ([url.host.lowercaseString isEqualToString:@"redd.it"]) {
		post = components.firstObject;
	} else if (components.count >= 4 && [components[0] isEqualToString:@"r"] && [components[2] isEqualToString:@"comments"]) {
		subreddit = components[1];
		post = components[3];
	} else if (components.count >= 2 && [components[0] isEqualToString:@"comments"]) {
		post = components[1];
	}

	NSCharacterSet *identifierCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789"];

	if (post.length == 0 || post.length > 12 || [post onlyContainsCharactersFromCharacterSet:identifierCharacters] == NO) {
		return nil;
	}

	if (subreddit && (subreddit.length > 30 || [subreddit onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]] == NO)) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		[(ICMReddit *)module _performActionForPost:post inSubreddit:subreddit];
	} copy];
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"reddit.com", @"www.reddit.com", @"old.reddit.com", @"new.reddit.com", @"m.reddit.com", @"redd.it"];
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"Reddit");
}

+ (nullable NSArray<NSString *> *)serviceHosts
{
	return @[@"redditmedia.com", @"redditstatic.com"];
}

@end

NS_ASSUME_NONNULL_END
