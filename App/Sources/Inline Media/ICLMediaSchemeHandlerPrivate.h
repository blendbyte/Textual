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

#import <WebKit/WebKit.h>

#import "ICLMediaType.h"

NS_ASSUME_NONNULL_BEGIN

/* Images, videos and audio reach the chat view only through Textual: the
 page gets a textual-media: address, and Textual fetches the media with
 the server's preview session and every rule of ICLURLSession (HTTPS, no
 local-network addresses, re-checked on each of at most 5 redirects, the
 proxy) plus a content type and size check, then hands WebKit the bytes.
 WebKit decodes them in its own process, never Textual. Range
 requests pass through, so video can seek. Main thread only. */

TEXTUAL_EXTERN NSString * const ICLMediaSchemeHandlerScheme; // "textual-media"

TEXTUAL_EXTERN NSErrorDomain const ICLMediaFetchErrorDomain;

typedef NS_ENUM(NSInteger, ICLMediaFetchErrorCode) {
	ICLMediaFetchErrorCodeNotAllowed = 1, // local, unresolvable or not HTTPS, here or after a redirect
	ICLMediaFetchErrorCodeUnexpectedResponse = 2, // not HTTP, or a status other than 200 (206 for a range)
	ICLMediaFetchErrorCodeUnexpectedType = 3, // not a content type of the expected kind
	ICLMediaFetchErrorCodeTooLarge = 4, // larger than the limit, by its headers or its body
	ICLMediaFetchErrorCodeFailed = 5 // the request failed
};

/* One fetch of a piece of media. The blocks are called on the main thread,
 none after -cancel. */
@interface ICLMediaFetch : NSObject <NSURLSessionDataDelegate>
- (instancetype)init NS_UNAVAILABLE;

/* maximumLength 0: no limit (media you chose to play). rangeHeader is the
 Range header WebKit sent, passed on as it is. */
- (instancetype)initWithURL:(NSURL *)url session:(NSURLSession *)session type:(ICLMediaType)type maximumLength:(unsigned long long)maximumLength rangeHeader:(nullable NSString *)rangeHeader NS_DESIGNATED_INITIALIZER;

/* The status (200 or 206) and the headers to give WebKit: Content-Type,
 and Content-Length, Content-Range and Accept-Ranges when the server sent them */
@property (nonatomic, copy, nullable) void (^responseBlock)(NSInteger statusCode, NSDictionary<NSString *, NSString *> *headerFields);
@property (nonatomic, copy, nullable) void (^dataBlock)(NSData *data);
@property (nonatomic, copy, nullable) void (^completionBlock)(NSError * _Nullable error);

- (void)start;
- (void)cancel;

/* The MIME types a kind of media may have */
+ (NSArray<NSString *> *)contentTypesForMediaType:(ICLMediaType)type;
@end

/* What a textual-media: address stands for */
@interface ICLMediaSchemeEntry : NSObject
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) ICLMediaType type;
@property (nonatomic, assign) unsigned long long maximumLength;
@end

@interface ICLMediaSchemeHandler : NSObject <WKURLSchemeHandler>
@property (readonly, class) ICLMediaSchemeHandler *sharedHandler;

/* The address the chat view loads instead of url. Images and GIF-style
 clips use the image size limit; video you play has none (0). */
- (NSURL *)URLForMediaAtURL:(NSURL *)url session:(NSURLSession *)session type:(ICLMediaType)type maximumLength:(unsigned long long)maximumLength;

/* nil for an address this handler didn't hand out (or has forgotten) */
- (nullable ICLMediaSchemeEntry *)entryForMediaURL:(NSURL *)mediaURL;
@end

NS_ASSUME_NONNULL_END
