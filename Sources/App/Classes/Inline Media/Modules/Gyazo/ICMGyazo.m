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
#import "ICMGyazo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMGyazo ()
@property (nonatomic, copy) NSString *contentIdentifier;
@end

@implementation ICMGyazo

- (void)_loadContent
{
	NSString *contentAddress = self.payload.address;

	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://api.gyazo.com/api/oembed"];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"url" value:contentAddress]
	];

	NSURL *requestURL = requestComponents.URL;

	[ICLHelpers requestJSONDataFromURL:requestURL
					   completionBlock:^(BOOL success, NSDictionary<NSString *, id> *data) {
						   if (success == NO) {
							   [self _unsafeToLoadMedia];

							   return;
						   }

						   [self _processJSONData:data];
					   }];
}

- (void)_processJSONData:(NSDictionary<NSString *, id> *)data
{
	NSParameterAssert(data != nil);

	/* Get "type" */
	NSString *typeString = data[@"type"];

	if (typeString == nil || [typeString isKindOfClass:[NSString class]] == NO) {
		[self _unsafeToLoadMedia];

		return;
	}

	/* Check "type" */
	if ([typeString isEqualToString:@"photo"]) {
		[self _processJSONDataForImage:data];
	} else if ([typeString isEqualToString:@"video"]) {
		[self _processJSONDataForVideo:data];
	} else {
		[self _unsafeToLoadMedia];
	}
}

- (void)_processJSONDataForImage:(NSDictionary<NSString *, id> *)data
{
	NSParameterAssert(data != nil);

	/* Get "url" */
	NSString *urlString = data[@"url"];

	if (urlString == nil || [urlString isKindOfClass:[NSString class]] == NO) {
		[self _unsafeToLoadMedia];

		return;
	}

	/* Check "url" */
	NSURL *url = [ICLHelpers URLWithString:urlString];

	if (url == nil) {
		[self _unsafeToLoadMedia];

		return;
	}

	/* Finish */
	[self _safeToLoadMediaOfType:ICLMediaTypeImage atURL:url];
}

- (void)_processJSONDataForVideo:(NSDictionary<NSString *, id> *)data
{
	NSParameterAssert(data != nil);

	/* Get "url" */
	NSString *urlString = [NSString stringWithFormat:@"https://i.gyazo.com/%@.mp4", self.contentIdentifier];

	/* Check "url" */
	NSURL *url = [ICLHelpers URLWithString:urlString];

	if (url == nil) {
		[self _unsafeToLoadMedia];

		return;
	}

	/* Finish */
	[self _safeToLoadMediaOfType:ICLMediaTypeVideoGif atURL:url];
}

- (void)_safeToLoadMediaOfType:(ICLMediaType)type atURL:(NSURL *)url
{
	self.payload.urlToInline = url;

	[self deferAsType:type];
}

- (void)_unsafeToLoadMedia
{
	[self cancel];
}

#pragma mark -
#pragma mark Action Block

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *contentIdentifier = [self _contentIdentifierForURL:url];

	if (contentIdentifier == nil) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		__weak ICMGyazo *moduleTyped = (id)module;

		moduleTyped.contentIdentifier = contentIdentifier;

		[moduleTyped _loadContent];
	} copy];
}

+ (nullable NSString *)_contentIdentifierForURL:(NSURL *)url
{
	NSString *urlPath = url.path.percentEncodedURLPath;

	if (urlPath.length != 33) { // Includes leading slash
		return nil;
	}

	NSString *contentIdentifier = [urlPath substringFromIndex:1];

	if (contentIdentifier.alphabeticNumericOnly == NO) {
		return nil;
	}

	return contentIdentifier;
}

+ (nullable NSArray<NSString *> *)domains
{
	static NSArray<NSString *> *domains = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		domains =
		@[
		  @"gyazo.com",
		  @"www.gyazo.com"
		];
	});

	return domains;
}

#pragma mark -
#pragma mark Utilities

+ (BOOL)contentImageOrVideo
{
	return YES;
}

+ (BOOL)contentIsFile
{
	return YES;
}

- (void)finalizePreflight
{
	self.payload.classAttribute = @"inlineGyazo";
}

@end

NS_ASSUME_NONNULL_END
