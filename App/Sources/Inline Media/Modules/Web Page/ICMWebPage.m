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

#import "TPCPreferencesLocalPrivate.h"
#import "ICLHelpers.h"
#import "ICLMediaAssessor.h"
#import "ICMWebPage.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICMWebPage

- (void)_performAction
{
	ICLPayloadMutable *payload = self.payload;

	__block ICLMediaType mediaType = ICLMediaTypeUnknown;

	__block NSURL *mediaURL = nil;

	[ICLHelpers requestPageMetadataFromURL:payload.url
								   session:payload.session
							 responseBlock:^BOOL(NSHTTPURLResponse *response) {
								 ICLMediaType responseType = [ICLMediaAssessor mediaTypeForContentType:response.MIMEType.lowercaseString];

								 /* A page, or nothing to show */
								 if (responseType == ICLMediaTypeOther) {
									 return YES;
								 }

								 /* Audio turned off: a link like any other that isn't a page */
								 if (responseType == ICLMediaTypeAudio && [TPCPreferences inlineMediaAudio] == NO) {
									 return NO;
								 }

								 /* An image over the size limit is left as a link */
								 if (responseType == ICLMediaTypeImage &&
									 response.expectedContentLength > (long long)[TPCPreferences inlineImagesMaxFilesize])
								 {
									 return NO;
								 }

								 mediaType = responseType;

								 mediaURL = response.URL;

								 return NO;
							 }
						   completionBlock:^(NSDictionary<NSString *, NSString *> * _Nullable metadata, NSURL * _Nullable pageURL) {
							   if (mediaType != ICLMediaTypeUnknown && mediaURL != nil) {
								   payload.urlToInline = mediaURL;

								   /* Images and videos are fetched with every check when shown. Audio
									is checked again for its type, which WebKit is asked about. */
								   [self deferAsType:mediaType performCheck:(mediaType == ICLMediaTypeAudio)];

								   return;
							   }

							   ICMPreviewCardContent *card = nil;

							   if (metadata && pageURL) {
								   card = [self.class cardForPageMetadata:metadata atURL:pageURL linkURL:payload.url];
							   }

							   if (card == nil) {
								   [self notifyUnableToPresentCard];

								   return;
							   }

							   [self performActionForCard:card];
						   }];
}

+ (nullable ICMPreviewCardContent *)cardForPageMetadata:(NSDictionary<NSString *, NSString *> *)metadata atURL:(NSURL *)pageURL linkURL:(NSURL *)linkURL
{
	NSParameterAssert(metadata != nil);
	NSParameterAssert(pageURL != nil);
	NSParameterAssert(linkURL != nil);

	NSString *title = (metadata[@"og:title"] ?: metadata[@"twitter:title"] ?: metadata[@"title"]).trim;

	if (title.length == 0) {
		return nil;
	}

	ICMPreviewCardContent *card = [ICMPreviewCardContent new];

	card.style = ICMPreviewCardStylePage;
	card.targetURL = linkURL;
	card.title = title;

	NSString *text = (metadata[@"og:description"] ?: metadata[@"twitter:description"] ?: metadata[@"description"]).trim;

	if (text.length > 0 && [text isEqualToString:title] == NO) {
		card.text = text;
	}

	NSString *image = (metadata[@"og:image"] ?: metadata[@"og:image:url"] ?: metadata[@"og:image:secure_url"] ?: metadata[@"twitter:image"] ?: metadata[@"twitter:image:src"]);

	if (image) {
		card.imageURL = [NSURL URLWithString:image relativeToURL:pageURL].absoluteURL;
	}

	/* Always the link's real host (where a click goes), as the page can claim
	 any og:site_name ("github.com" on a lookalike); the name only beside it */
	NSString *host = [self.class shownHostOfURL:linkURL];

	NSString *siteName = metadata[@"og:site_name"].trim;

	if (host && siteName.length > 0 && [siteName isEqualToStringIgnoringCase:host] == NO) {
		card.details = @[[NSString stringWithFormat:@"%@ · %@", siteName, host]];
	} else if (host) {
		card.details = @[host];
	}

	return card;
}

/* Lowercase, without "www.", and in its ASCII (IDNA) form when it has other
 characters: a lookalike in another script shows as xn--… */
+ (nullable NSString *)shownHostOfURL:(NSURL *)url
{
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];

	NSString *host = components.host.lowercaseString;

	if (host.length == 0) {
		return nil;
	}

	if ([host canBeConvertedToEncoding:NSASCIIStringEncoding] == NO) {
		NSString *encodedHost = components.encodedHost.lowercaseString;

		if (encodedHost.length > 0) {
			host = encodedHost;
		}
	}

	if ([host hasPrefix:@"www."]) {
		host = [host substringFromIndex:4];
	}

	return host;
}

#pragma mark -
#pragma mark Action

/* A page card for "see example.com" would be noise */
+ (BOOL)requiresAddressWithScheme
{
	return YES;
}

+ (nullable SEL)actionForURL:(NSURL *)url
{
	if ([TPCPreferences inlineMediaWebPageCards] == NO) {
		return NULL;
	}

	return @selector(_performAction);
}

@end

NS_ASSUME_NONNULL_END
