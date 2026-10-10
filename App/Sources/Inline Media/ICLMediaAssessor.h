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

#import "ICLMediaType.h"
#import "ICLMediaAssessment.h"

/* Given a URL, the assessor requests it and reads the response headers
 to determine what type of media it is: image, video, or other.
 It also checks the Content-Length against the user's limit for images.
 The body is never downloaded: Textual does not decode untrusted media.
 Images and videos are only loaded by WebKit, which checks their
 dimensions once they have loaded. */

NS_ASSUME_NONNULL_BEGIN

/* Both values will never be nil together.
 There will either be an assessment or an error for why there isn't.
 The completion block is called on the main thread. */
typedef void (^ICLMediaAssessorCompletionBlock)(ICLMediaAssessment * _Nullable assessment, NSError * _Nullable error);

@interface ICLMediaAssessor : NSObject
- (instancetype)init NS_UNAVAILABLE;

/* Use the following two methods to determine what type of media a URL is. */
/* session is the payload's (-[ICLPayload session]) */
+ (instancetype)assessorForURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock;
+ (instancetype)assessorForAddress:(NSString *)address session:(NSURLSession *)session completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock;

/* Use the following two methods to determine whether the URL is the type of media. */
/* If you are expecting the URL to be a specific type of media, these methods are better. */
+ (instancetype)assessorForURL:(NSURL *)url session:(NSURLSession *)session withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock;
+ (instancetype)assessorForAddress:(NSString *)address session:(NSURLSession *)session withType:(ICLMediaType)type completionBlock:(ICLMediaAssessorCompletionBlock)completionBlock;

/* Suspend assessment */
- (void)suspend;

/* Resume assessment */
- (void)resume;

/* Logging */
+ (void)logError:(NSError *)error;
@end

/* Error codes */
typedef NS_ENUM(NSUInteger, ICLMediaAssessorErrorCode)
{
	/* Catch all */
	ICLMediaAssessorErrorCodeAssessmentFailed = 0,

	/* Endpoint did not respond with OK (200) */
	ICLMediaAssessorErrorCodeUnexpectedStatusCode = 1001,

	/* Content-Type header is improperly formatted */
	ICLMediaAssessorErrorCodeMalformedContentType = 1002,

	/* Content-Length header is improperly formatted */
	ICLMediaAssessorErrorCodeMalformedContentLength = 1003,

	/* Unexpected media type */
	ICLMediaAssessorErrorCodeUnexpectedType = 1004,

	/* Unexpected response type (not HTTP) */
	ICLMediaAssessorErrorCodeUnexpectedResponse = 1005,

	/* Maximum response size exceeded */
	ICLMediaAssessorErrorCodeContentLengthExceeded = 1006,

	/* Address is on the local network or not HTTP(S) */
	ICLMediaAssessorErrorCodeAddressNotAllowed = 1009,
};

NS_ASSUME_NONNULL_END
