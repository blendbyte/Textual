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
#import "ICMTweet.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICMTweet

- (void)_loadTweetContents
{
	NSString *tweetAddress = self.payload.address;

	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://publish.twitter.com/oembed"];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"dnt" value:@"true"], /* DO NOT TRACK */
	  [NSURLQueryItem queryItemWithName:@"maxwidth" value:@"500"],
	  [NSURLQueryItem queryItemWithName:@"omit_script" value:@"true"],
	  [NSURLQueryItem queryItemWithName:@"url" value:tweetAddress]
	];

	NSURL *requestURL = requestComponents.URL;

	[ICLHelpers requestJSONObject:@"html"
						   ofType:[NSString class]
					  inHierarchy:nil
						  fromURL:requestURL
						  session:self.payload.session
				  completionBlock:^(id object) {
				if (object == nil) {
					[self notifyUnableToPresentHTML];

					return;
				}

				[self performActionForHTML:object];
			}];
}

#pragma mark -
#pragma mark Action Block

+ (nullable SEL)actionForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	if ([self _URLIsTweet:url] == NO) {
		return NULL;
	}

	return @selector(_loadTweetContents);
}

+ (BOOL)_URLIsTweet:(NSURL *)url
{
	NSString *urlPath = url.path.percentEncodedURLPath;

	if (urlPath.length <= 1) {
		return NO;
	}

	urlPath = [urlPath substringFromIndex:1]; // "/"

	NSArray<NSString *> *components = [urlPath componentsSeparatedByString:@"/"];

	if (components.count < 3) {
		return NO;
	}

	if ([components[1] isEqualToString:@"status"] == NO) {
		return NO;
	}

	if (components[2].isNumericOnly == NO) {
		return NO;
	}

	return YES;
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
		  @"mobile.twitter.com"
		];
	});

	return domains;
}

#pragma mark -
#pragma mark Utilities

- (nullable NSArray<NSURL *> *)scriptResources
{
	return
	[[super scriptResources] arrayByAddingObjectsFromArray:
	@[
	  [NSURL URLWithString:@"https://platform.twitter.com/widgets.js"],
	  ICLResourceURL(@"ICMTweet", @"js")
	]];
}

- (nullable NSString *)entrypoint
{
	return @"_ICMTweet";
}

- (void)finalizePreflight
{
	self.payload.classAttribute = @"inlineTweet";
}

@end

NS_ASSUME_NONNULL_END
