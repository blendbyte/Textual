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
#import "ICMTweet.h"

NS_ASSUME_NONNULL_BEGIN

/* The embed HTML is read up to this length */
#define _maximumEmbedLength			(32 * 1024)

/* A post card for X (twitter.com and x.com): author and text from X's official
 oEmbed, no image, no script. When oEmbed fails, a card built from the
 address alone ("Post by @handle on X"). */
@implementation ICMTweet

- (void)_loadPostOfAccount:(NSString *)account
{
	NSParameterAssert(account != nil);

	NSURLComponents *addressComponents = [NSURLComponents componentsWithURL:self.payload.url resolvingAgainstBaseURL:NO];

	addressComponents.scheme = @"https";
	addressComponents.host = @"x.com";
	addressComponents.query = nil;
	addressComponents.fragment = nil;

	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://publish.x.com/oembed"];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"dnt" value:@"true"], /* DO NOT TRACK */
	  [NSURLQueryItem queryItemWithName:@"omit_script" value:@"true"],
	  [NSURLQueryItem queryItemWithName:@"url" value:addressComponents.URL.absoluteString]
	];

	[ICLHelpers requestJSONDataFromURL:requestComponents.URL
							   session:self.payload.session
					   completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePost;

		card.targetURL = self.payload.url;

		card.authorHandle = [@"@" stringByAppendingString:account];

		NSString *html = [data stringForKey:@"html"];

		NSDictionary<NSString *, NSString *> *post = ((html) ? [self.class postFromEmbedHTML:html] : nil);

		if (post) {
			card.authorName = [data stringForKey:@"author_name"];

			card.text = post[@"text"];

			card.details = @[@"X", (post[@"date"] ?: @"")];
		} else {
			card.text = [NSString stringWithFormat:@"Post by @%@ on X", account];

			card.details = @[@"X"];
		}

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Extraction

+ (nullable NSDictionary<NSString *, NSString *> *)postFromEmbedHTML:(NSString *)html
{
	NSParameterAssert(html != nil);

	if (html.length > _maximumEmbedLength) {
		html = [html substringToIndex:_maximumEmbedLength];
	}

	/* The text: inside the first <p …> … </p> */
	NSRange paragraphStart = [html rangeOfString:@"<p" options:NSCaseInsensitiveSearch];

	if (paragraphStart.location == NSNotFound) {
		return nil;
	}

	NSRange tagEnd = [html rangeOfString:@">" options:0 range:NSMakeRange(NSMaxRange(paragraphStart), (html.length - NSMaxRange(paragraphStart)))];

	if (tagEnd.location == NSNotFound) {
		return nil;
	}

	NSUInteger textStart = NSMaxRange(tagEnd);

	NSRange paragraphEnd = [html rangeOfString:@"</p>" options:NSCaseInsensitiveSearch range:NSMakeRange(textStart, (html.length - textStart))];

	if (paragraphEnd.location == NSNotFound) {
		return nil;
	}

	NSString *text = [ICLHelpers plainTextFromHTMLFragment:[html substringWithRange:NSMakeRange(textStart, (paragraphEnd.location - textStart))]];

	if (text.length == 0) {
		return nil;
	}

	NSMutableDictionary<NSString *, NSString *> *post = [NSMutableDictionary dictionary];

	post[@"text"] = text;

	/* The date: the last link's text before </blockquote> */
	NSUInteger afterText = NSMaxRange(paragraphEnd);

	NSRange lastLinkEnd = [html rangeOfString:@"</a>" options:(NSCaseInsensitiveSearch | NSBackwardsSearch) range:NSMakeRange(afterText, (html.length - afterText))];

	if (lastLinkEnd.location != NSNotFound) {
		NSRange lastLinkTagEnd = [html rangeOfString:@">" options:NSBackwardsSearch range:NSMakeRange(afterText, (lastLinkEnd.location - afterText))];

		if (lastLinkTagEnd.location != NSNotFound) {
			NSString *date = [ICLHelpers plainTextFromHTMLFragment:[html substringWithRange:NSMakeRange(NSMaxRange(lastLinkTagEnd), (lastLinkEnd.location - NSMaxRange(lastLinkTagEnd)))]];

			if (date.length > 0 && date.length <= 40) {
				post[@"date"] = date;
			}
		}
	}

	return [post copy];
}

#pragma mark -
#pragma mark Action Block

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *account = [self _accountOfPostAtURL:url];

	if (account == nil) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		__weak ICMTweet *moduleTyped = (id)module;

		[moduleTyped _loadPostOfAccount:account];
	} copy];
}

/* /<account>/status/<number>: the account, or nil */
+ (nullable NSString *)_accountOfPostAtURL:(NSURL *)url
{
	NSString *urlPath = url.path.percentEncodedURLPath;

	if (urlPath.length <= 1) {
		return nil;
	}

	NSArray<NSString *> *components = [[urlPath substringFromIndex:1] componentsSeparatedByString:@"/"];

	if (components.count < 3) {
		return nil;
	}

	if ([components[1] isEqualToString:@"status"] == NO || components[2].isNumericOnly == NO) {
		return nil;
	}

	NSString *account = components[0];

	if (account.length == 0 || account.length > 50 ||
		[account onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]] == NO)
	{
		return nil;
	}

	return account;
}

+ (nullable NSArray<NSString *> *)domains
{
	static NSArray<NSString *> *domains = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		domains =
		@[
		  @"twitter.com",
		  @"www.twitter.com",
		  @"mobile.twitter.com",
		  @"x.com",
		  @"www.x.com",
		  @"mobile.x.com"
		];
	});

	return domains;
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"X");
}

@end

NS_ASSUME_NONNULL_END
