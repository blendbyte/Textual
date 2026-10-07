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

#import "ICLPayload.h"
#import "ICLMediaType.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const ICLInlineContentErrorDomain;

@class ICLInlineContentModule;

/* See description for -actionBlockForURL: */
typedef void (^ICLInlineContentModuleActionBlock)(ICLInlineContentModule *module);

/**
 * Modules are always a subclass, instead of a protocol, to give us
 * greater flexibility when adding private components to the parent.
 *
 * Modules are compiled into the app and listed in ICPCoreMedia.
 * All of their work happens on the main thread.
 */
@interface ICLInlineContentModule : NSObject
/**
 * Mutable copy of the payload this module has access to modify.
 * This payload includes the address and the unique identifier.
 */
@property (readonly, strong) ICLPayloadMutable *payload;

/**
 * Modules are created by the loader.
 */
- (instancetype)init NS_UNAVAILABLE;

#pragma mark -
#pragma mark Rules

/**
 An optional array of domains that the module is specific to.

 If this array is non-nil and the domain does not appear in the
 array, then the module is skipped over. One of the action methods
 defined below is never called.
 */
@property (readonly, copy, nullable, class) NSArray<NSString *> *domains;

#pragma mark -
#pragma mark Action

/**
 * Returns a block to perform if the module is interested in the URL.
 *
 * The block is passed one argument: a new instance of the module.
 * The block can then use that to do stateful work, or it can
 * disregard the argument and do whatever else it wants.
 *
 * The return value of -actionBlockForURL: is favored over -actionForURL:
 * The latter is never called if -actionBlockForURL: returns a value.
 *
 * nil is returned if this method is not implemented.
 */
+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url;

/**
 * Returns a selector to perform if the module is interested in the URL.
 *
 * The selector is performed on a new instance of the module which means
 * the selector returned must be one for an instance method.
 *
 * The selector:
 *   1. Does not return a value (void)
 *   2. Does not take arguments
 *
 * Example:
 *
 * 		- (void)performAction
 * 		{
 *
 * 		}
 *
 * NULL is returned if this method is not implemented.
 */
+ (nullable SEL)actionForURL:(NSURL *)url;

#pragma mark -
#pragma mark Context

/**
 Whether the module's content is an image or video.
 This can include video services, not just video files.
 */
@property (readonly, class) BOOL contentImageOrVideo;

/**
 Whether the module's content is a regular file,
 such as an image or video. Not an iframe, embedded,
 or dynamic content (such as JavaScript).
 */
@property (readonly, class) BOOL contentIsFile;

/**
 Whether the module might add content to the DOM which
 is not trusted such as HTML downloaded from some website.
 A module that loads remote JavaScript libraries is also
 considered untrusted.
 */
@property (readonly, class) BOOL contentUntrusted;

/**
 Whether module might load content that is not safe for work.
 */
@property (readonly, class) BOOL contentNotSafeForWork;

#pragma mark -
#pragma mark Resources

/* If a non-nil value is returned for any of these properties,
 then that value is inserted into the payload. */
/* See ICLPayload.h for a description of each property. */
@property (copy, readonly, nullable) NSArray<NSURL *> *styleResources;
@property (copy, readonly, nullable) NSArray<NSURL *> *scriptResources;
@property (copy, readonly, nullable) NSString *entrypoint;

/**
 URL to a file that is a mustache template.

 Given a URL, the -template property automatically returns
 a reference to the template.

 It is possible to render HTML multiple ways which means you
 do not need a template unless you want one.
 */
@property (readonly, nullable) NSURL *templateURL;

/**
 Reference to mustache template found at -templateURL
 */
@property (readonly, nullable) GRMustacheTemplate *template;
@end

#pragma mark -
#pragma mark Completion

@interface ICLInlineContentModule (Completion)
/**
 Called by module to inform the media handler that no
 more modifications will be made to the payload and that
 the contents of it should now be processed.

 - Warnings

 This method will throw an exception if the module has
 already been finalized by calling this method or a sibling.
*/
- (void)finalize;

/**
 Called by module to inform the media handler that no
 more modifications will be made to the payload and that
 the contents of it should now be processed.

 - Warnings

 This method will throw an exception if the module has
 already been finalized by calling this method or a sibling.

 - Arguments

 @param error
  nil to inform the media handler that the media should be
  inlined or an error describing why that cannot happen.
 */
- (void)finalizeWithError:(nullable NSError *)error;

/**
 Called by the module to inform the media handler that
 the module wants to cancel performing any work.

 - Warnings

 This method will throw an exception if the module has
 already been finalized by calling this method or a sibling.
 */
- (void)cancel;

/**
 A module that is capable of performing work on more than
 one type of media (such as images and videos) can call
 this method when it is sure what type of media it has.

 The media will be checked by performing a web request
 to ensure that it is in fact the type described.

 - See also

 See -deferAsType:performCheck: for a detailed description.
*/
- (void)deferAsType:(ICLMediaType)type; // performCheck = YES

/**
 A module that is capable of performing work on more than
 one type of media (such as images and videos) can call
 this method when it is sure what type of media it has.

 - Examples

 For example, if the module has the URL "example.com"
 and believes it is a regular image, then it can call
 this method with the type ICLMediaTypeImage to inform
 the media handler to inline the URL as an image.

 - Notes

 Calling this method to inline images or other media
 types is only required if the module is not already
 a subclass of one of the root classes responsible for
 handling these types of media.

 - Warnings

 This method will throw an exception if the module has
 already been finalized by calling this method or a sibling.

 - Arguments

 @param type
  The type of media that the content should be treated as.
  The types supported are:
  • ICLMediaTypeImage for images,
  • ICLMediaTypeVideo for videos,
  • ICLMediaTypeVideoGif for videos presented as a gif

 @param performCheck
  Whether to perform a web request to ensure that
  it is in fact the type described.
 */
- (void)deferAsType:(ICLMediaType)type performCheck:(BOOL)performCheck;

/**
 Returns YES if a type is supported by -deferAsType:
 */
+ (BOOL)isTypeDeferrable:(ICLMediaType)type;
@end

NS_ASSUME_NONNULL_END
