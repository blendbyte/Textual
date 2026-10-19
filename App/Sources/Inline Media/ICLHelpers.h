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

NS_ASSUME_NONNULL_BEGIN

/* A module's template, style or script in the app's "Inline Media" folder */
FOUNDATION_EXPORT NSURL * _Nullable ICLResourceURL(NSString *name, NSString *extension);

@interface ICLHelpers : NSObject
/* nil unless the address is an HTTP(S) URL with a host.
 Addresses that begin with "//" are treated as HTTPS. */
+ (nullable NSURL *)URLWithString:(NSString *)address;
@end

/* Requests go through the shared inline media session (ICLURLSession):
 local addresses are refused and responses are capped at 1 MB.
 Completion blocks are called on the main thread. */
@interface ICLHelpers (JSON)
/* Any JSON value (dictionary, array, ...); check its class before use.
 Answers are remembered for 30 minutes (at most 500), so a re-rendered line
 (scrollback, style change) doesn't fetch again. */
+ (void)requestJSONFromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(id _Nullable json))completionBlock;

/* session is the payload's (-[ICLPayload session]) */
+ (void)requestJSONDataFromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable data))completionBlock;
+ (void)requestJSONDataFromAddress:(NSString *)address session:(NSURLSession *)session completionBlock:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable data))completionBlock;

+ (void)requestJSONObject:(NSString *)objectKey ofType:(Class)objectType inHierarchy:(nullable NSArray<NSString *> *)hierarchy fromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(id _Nullable object))completionBlock;
+ (void)requestJSONObject:(NSString *)objectKey ofType:(Class)objectType inHierarchy:(nullable NSArray<NSString *> *)hierarchy fromAddress:(NSString *)address session:(NSURLSession *)session completionBlock:(void (^)(id _Nullable object))completionBlock;
@end

/* Text out of HTML without an HTML parser (no parsing of untrusted
 markup beyond a bounded string search) */
@interface ICLHelpers (HTML)
/* Tags removed, <br> as line breaks, entities decoded, trimmed */
+ (NSString *)plainTextFromHTMLFragment:(NSString *)fragment;
+ (NSString *)stringByDecodingHTMLEntities:(NSString *)string;

/* The page's <title> ("title"), its description <meta> ("description") and
 its og:… and twitter:… <meta> values (property or name lowercased), from
 the part before </head> */
+ (NSDictionary<NSString *, NSString *> *)metadataInHTML:(NSString *)html;

/* The start of a page as text: in the response's charset, else that of a
 <meta> near the top, else UTF-8 (a character cut off at the end dropped),
 else Latin-1 */
+ (nullable NSString *)stringFromHTMLData:(NSData *)data textEncodingName:(nullable NSString *)textEncodingName;

/* text/html or application/xhtml+xml */
+ (BOOL)responseIsHTML:(NSHTTPURLResponse *)response;

/* The metadata of an HTML page, read up to </head> and at most 512 KB; nil
 when the request fails, it isn't HTML or nothing was found. Remembered for
 30 minutes like JSON. responseBlock, when given, sees the response first
 and returns NO to stop there (a link that turns out to be an image, say).
 pageURL is the address after redirects, for relative addresses in it. */
+ (void)requestPageMetadataFromURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(NSDictionary<NSString *, NSString *> * _Nullable metadata))completionBlock;
+ (void)requestPageMetadataFromURL:(NSURL *)url session:(NSURLSession *)session responseBlock:(nullable BOOL (^)(NSHTTPURLResponse *response))responseBlock completionBlock:(void (^)(NSDictionary<NSString *, NSString *> * _Nullable metadata, NSURL * _Nullable pageURL))completionBlock;
@end

@interface ICLHelpers (Errors)
@property (copy, readonly, class) NSError *genericValidationFailedError;
@end

@interface NSString (ICLHelpers)
/* Given "youtube.com" as input, returns if string is
 equal to "youtube.com" or has suffix ".youtube.com" */
- (BOOL)isDomain:(NSString *)domain;
- (BOOL)isDomainOrSubdomain:(NSString *)domain;
@end

NS_ASSUME_NONNULL_END
