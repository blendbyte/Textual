/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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

#import <XCTest/XCTest.h>

#import "ICLHelpers.h"
#import "ICLImageViewer.h"
#import "ICLYouTubePlayer.h"
#import "ICMPreviewCard.h"
#import "ICMTweet.h"
#import "ICMWebPage.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMPreviewCardTests : XCTestCase
@end

@implementation ICMPreviewCardTests

/* X's oEmbed blockquote, as X sends it: the post's text (links and line breaks
 inside), then the author and a dated link */
- (void)testPostTextAndDateFromEmbedHTML
{
	NSString *html = @"<blockquote class=\"twitter-tweet\"><p lang=\"en\" dir=\"ltr\">Fish &amp; chips<br>at <a href=\"https://t.co/x\">t.co/x</a> &#8212; &quot;yes&quot; &#x1F600;</p>&mdash; Jack (@jack) <a href=\"https://x.com/jack/status/20?ref_src=twsrc%5Etfw\">March 21, 2006</a></blockquote>\n";

	NSDictionary<NSString *, NSString *> *post = [ICMTweet postFromEmbedHTML:html];

	XCTAssertEqualObjects(post[@"text"], @"Fish & chips\nat t.co/x \u2014 \"yes\" \U0001F600");
	XCTAssertEqualObjects(post[@"date"], @"March 21, 2006");

	/* Not what X sends: nothing, rather than markup */
	XCTAssertNil([ICMTweet postFromEmbedHTML:@"<div>no paragraph</div>"]);
	XCTAssertNil([ICMTweet postFromEmbedHTML:@"<p>never closed"]);

	/* Unknown or broken entities stay as they were */
	XCTAssertEqualObjects([ICLHelpers plainTextFromHTMLFragment:@"a &bogus; b &#xD800; c & d"], @"a &bogus; b &#xD800; c & d");
}

/* A page's title and Open Graph values from its head, however the tags are
 written; nothing after </head> counts */
- (void)testPageMetadataFromHead
{
	NSString *html = @"<html><head><TITLE>Plain &amp; title</TITLE>"
					  "<meta property=\"og:title\" content=\"box, by GGG &quot;Blanstein&quot;\">"
					  "<meta content='https://f4.bcbits.com/img/a1_5.jpg' property='og:image'/>"
					  "<meta property=\"og:image\" content=\"https://example.com/second.jpg\">"
					  "<meta name=\"twitter:card\" content=\"summary\">"
					  "<meta name=\"Twitter:Title\" content=\"The twitter title\">"
					  "<meta name=\"description\" content=\"The page&#39;s description\">"
					  "<meta xproperty=\"og:site_name\" content=\"not a property attribute\">"
					  "</head><body><meta property=\"og:description\" content=\"in the body\"></body></html>";

	NSDictionary<NSString *, NSString *> *metadata = [ICLHelpers metadataInHTML:html];

	XCTAssertEqualObjects(metadata[@"title"], @"Plain & title");
	XCTAssertEqualObjects(metadata[@"og:title"], @"box, by GGG \"Blanstein\"");
	XCTAssertEqualObjects(metadata[@"og:image"], @"https://f4.bcbits.com/img/a1_5.jpg");
	XCTAssertEqualObjects(metadata[@"twitter:title"], @"The twitter title");
	/* Only the names a card uses are kept */
	XCTAssertNil(metadata[@"twitter:card"]);
	XCTAssertEqualObjects(metadata[@"description"], @"The page's description");
	XCTAssertNil(metadata[@"og:site_name"]);
	XCTAssertNil(metadata[@"og:description"]);
}

/* A page's start is cut anywhere and comes in its own charset */
- (void)testPageTextDecoding
{
	NSMutableData *cutUTF8 = [[@"<title>Café ü" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];

	[cutUTF8 appendBytes:"\xc3" length:1]; // the first half of "é"

	XCTAssertEqualObjects([ICLHelpers stringFromHTMLData:cutUTF8 textEncodingName:nil], @"<title>Café ü");

	NSMutableData *shiftJIS = [[@"<meta charset=\"Shift_JIS\"><title>" dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];

	[shiftJIS appendData:[@"日本語" dataUsingEncoding:NSShiftJISStringEncoding]];

	XCTAssertTrue([[ICLHelpers stringFromHTMLData:shiftJIS textEncodingName:nil] hasSuffix:@"日本語"]);

	NSData *latin1 = [@"<title>Grüße</title>" dataUsingEncoding:NSISOLatin1StringEncoding];

	XCTAssertEqualObjects([ICLHelpers stringFromHTMLData:latin1 textEncodingName:@"iso-8859-1"], @"<title>Grüße</title>");
}

- (void)testWebPageCard
{
	NSURL *pageURL = [NSURL URLWithString:@"https://www.example.com/articles/42"]; // after a redirect
	NSURL *linkURL = [NSURL URLWithString:@"https://example.com/a/42"];

	/* Open Graph first, a relative picture, the site from the address */
	ICMPreviewCardContent *card =
	[ICMWebPage cardForPageMetadata:@{@"title" : @"Page title", @"og:title" : @"Article", @"description" : @"Plain description", @"twitter:description" : @"Twitter description", @"og:image" : @"/images/42.jpg"}
							  atURL:pageURL
							linkURL:linkURL];

	XCTAssertEqualObjects(card.title, @"Article");
	XCTAssertEqualObjects(card.text, @"Twitter description");
	XCTAssertEqualObjects(card.imageURL.absoluteString, @"https://www.example.com/images/42.jpg");
	XCTAssertEqualObjects(card.details, @[@"example.com"]);
	XCTAssertEqualObjects(card.targetURL, linkURL);
	XCTAssertEqual(card.style, ICMPreviewCardStylePage);

	/* Only a <title>: a card with the title; a description that repeats it is left out */
	card = [ICMWebPage cardForPageMetadata:@{@"title" : @"Example Domain", @"description" : @"Example Domain", @"og:site_name" : @"Example"} atURL:pageURL linkURL:linkURL];

	XCTAssertEqualObjects(card.title, @"Example Domain");
	XCTAssertNil(card.text);
	XCTAssertNil(card.imageURL);
	XCTAssertEqualObjects(card.details, @[@"Example"]);

	/* No title: no card */
	card = [ICMWebPage cardForPageMetadata:@{@"og:description" : @"Text", @"og:image" : @"https://example.com/a.jpg"} atURL:pageURL linkURL:linkURL];

	XCTAssertNil(card);
}

/* A saved image opens as what it is: its content type's extension is added
 unless it has one of that type's, and it can't be hidden */
- (void)testSavedImageFileName
{
	NSString * (^fileName)(NSString *, NSString * _Nullable) = ^NSString *(NSString *address, NSString * _Nullable contentType) {
		return [ICLImageViewer fileNameForImageAtURL:[NSURL URLWithString:address] contentType:contentType];
	};

	XCTAssertEqualObjects(fileName(@"https://i.example.com/cat.jpg", @"image/jpeg"), @"cat.jpg");
	XCTAssertEqualObjects(fileName(@"https://example.com/photo.JPEG", @"image/jpeg"), @"photo.JPEG");
	XCTAssertEqualObjects(fileName(@"https://example.com/id/237/600/400", @"image/jpeg"), @"400.jpeg");
	XCTAssertEqualObjects(fileName(@"https://example.com/evil.command", @"image/png"), @"evil.command.png");
	XCTAssertEqualObjects(fileName(@"https://example.com/.hidden.png", @"image/png"), @"hidden.png");
	XCTAssertEqualObjects(fileName(@"https://example.com/", @"image/webp"), @"image.webp");
	XCTAssertEqualObjects(fileName(@"https://example.com/x.png", nil), @"x.png");
}

/* The player only takes a YouTube video ID from the chat view's script, and
 only ever loads YouTube's embed address */
- (void)testYouTubePlayerAddress
{
	XCTAssertTrue([ICLYouTubePlayer isValidVideoIdentifier:@"dQw4w9WgXcQ"]);
	XCTAssertTrue([ICLYouTubePlayer isValidVideoIdentifier:@"jNQXAC9IVRw"]);
	XCTAssertFalse([ICLYouTubePlayer isValidVideoIdentifier:@"dQw4w9WgXc"]);
	XCTAssertFalse([ICLYouTubePlayer isValidVideoIdentifier:@"../../evil?"]);
	XCTAssertFalse([ICLYouTubePlayer isValidVideoIdentifier:@"dQw4w9WgX/Q"]);

	NSURL *url = [ICLYouTubePlayer embedURLForVideo:@"jNQXAC9IVRw" startTime:5.7];

	XCTAssertEqualObjects(url.absoluteString, @"https://www.youtube-nocookie.com/embed/jNQXAC9IVRw?autoplay=1&rel=0&start=5");

	url = [ICLYouTubePlayer embedURLForVideo:@"dQw4w9WgXcQ" startTime:0];

	XCTAssertEqualObjects(url.absoluteString, @"https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?autoplay=1&rel=0");
}

- (void)testDurations
{
	XCTAssertEqualObjects([ICMPreviewCard formattedDuration:62], @"1:02");
	XCTAssertEqualObjects([ICMPreviewCard formattedDuration:3723], @"1:02:03");
	XCTAssertEqualObjects([ICMPreviewCard formattedDuration:9.6], @"0:10");
}

@end

NS_ASSUME_NONNULL_END
