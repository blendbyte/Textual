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
#import "ICMWikipedia.h"

NS_ASSUME_NONNULL_BEGIN

/* Page cards for Wikipedia articles in any language, from Wikipedia's page
 summary API: title, the first sentences, the lead image and a short description */
@implementation ICMWikipedia

- (void)_performActionForArticle:(NSString *)article onHost:(NSString *)host
{
	NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/rest_v1/page/summary/%@", host, article]];

	if (requestURL == nil) {
		[self notifyUnableToPresentCard];

		return;
	}

	[ICLHelpers requestJSONDataFromURL:requestURL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSString *title = [data stringForKey:@"title"];

		if (title == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePage;
		card.targetURL = self.payload.url;
		card.title = title;
		card.text = [data stringForKey:@"extract"];

		NSString *thumbnail = [[data dictionaryForKey:@"thumbnail"] stringForKey:@"source"];

		if (thumbnail) {
			card.imageURL = [ICLHelpers URLWithString:thumbnail];
		}

		card.details = @[@"Wikipedia", ([data stringForKey:@"description"] ?: @"")];

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

/* <language>.wikipedia.org/wiki/<article> and the mobile site */
+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *path = url.path.percentEncodedURLPath;

	if ([path hasPrefix:@"/wiki/"] == NO || path.length <= 6) {
		return nil;
	}

	NSString *article = [path substringFromIndex:6];

	if ([article containsString:@"/"] || article.length > 300) {
		return nil;
	}

	NSString *host = [url.host.lowercaseString stringByReplacingOccurrencesOfString:@".m.wikipedia.org" withString:@".wikipedia.org"];

	if ([host hasSuffix:@".wikipedia.org"] == NO) {
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		[(ICMWikipedia *)module _performActionForArticle:article onHost:host];
	} copy];
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"*.wikipedia.org"];
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"Wikipedia");
}

+ (nullable NSArray<NSString *> *)serviceHosts
{
	return @[@"wikimedia.org"];
}

@end

NS_ASSUME_NONNULL_END
