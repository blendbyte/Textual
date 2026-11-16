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
#import "ICMBandcamp.h"

NS_ASSUME_NONNULL_BEGIN

/* Page cards for Bandcamp albums, tracks and artists from the page's Open
 Graph tags (Bandcamp has no API): read with a bounded string search of the
 page's head, never an HTML parser */
@implementation ICMBandcamp

- (void)_performAction
{
	[ICLHelpers requestPageMetadataFromURL:self.payload.url session:self.payload.session completionBlock:^(NSDictionary<NSString *, NSString *> * _Nullable metadata) {
		NSString *title = (metadata[@"og:title"] ?: metadata[@"title"]);

		if (title == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePage;
		card.targetURL = self.payload.url;
		card.title = title;
		card.text = metadata[@"og:description"];

		NSString *image = metadata[@"og:image"];

		if (image) {
			card.imageURL = [ICLHelpers URLWithString:image];
		}

		card.details = @[@"Bandcamp", (metadata[@"og:site_name"] ?: @"")];

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	return [^(ICLInlineContentModule *module) {
		[(ICMBandcamp *)module _performAction];
	} copy];
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"*.bandcamp.com"];
}

+ (nullable NSString *)serviceName
{
	return TXLocalizationNotNeeded(@"Bandcamp");
}

+ (nullable NSArray<NSString *> *)serviceHosts
{
	return @[@"bandcamp.com", @"bcbits.com"];
}

@end

NS_ASSUME_NONNULL_END
