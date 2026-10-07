/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2020 Codeux Software, LLC & respective contributors.
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

#pragma mark -
#pragma mark Immutable Object

@interface ICLPayload : XRPortablePropertyObject
/**
 Payload objects are not allowed to be allocated by a plugin.
 Each new instance of ICLContentLoaderModule is given a mutable payload.
 Modify that, then the loader will create an immutable copy when appropriate.
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 The URL associated with this payload.
 */
@property (copy, readonly) NSURL *url;

/**
 String value of -url property.
 */
@property (copy, readonly) NSString *address;

/**
 The URL of the content to inline, such as an image, can be
 different than the value of -url because of redirects or API
 requests. The -urlToInline property can be used to get and set
 this different URL.

 If left unchanged, the value of this property mirrors -url
 */
@property (copy, readonly) NSURL *urlToInline;

/**
 String value of the -urlToInline property.
 */
@property (copy, readonly) NSString *addressToInline;

/**
 The unique identifier associated with this payload.
 */
@property (copy, readonly) NSString *uniqueIdentifier;

/**
 The view responsible for this payload.
 */
@property (copy, readonly) NSString *viewIdentifier;

/**
 The line number associated with this payload.
 */
@property (copy, readonly) NSString *lineNumber;

/**
 Position of payload in relation to others with same line number.
 */
@property (readonly) NSUInteger index;

/**
 The length of the content. This value is optional.
 */
@property (readonly) unsigned long long contentLength;

/**
 The size of the content. This value is optional.
 */
@property (readonly) NSSize contentSize;

/**
 A collection of paths for .css files that need to be loaded to allow the
 rendered HTML to appear correct.
 */
@property (copy, readonly) NSArray<NSURL *> *styleResources;

/**
 A collection of paths for .js files that need to be loaded to allow the
 rendered HTML to appear correct.

 */
@property (copy, readonly) NSArray<NSURL *> *scriptResources;

/**
 Rendered HTML or an empty string

 - Discussion:

 A module does not need to render the HTML through Objective-C.
 It can render it in JavaScript or by some other means.

 If a module renders HTML using Objective-C, then the final result
 can be assigned to this property.
 */
@property (copy, readonly) NSString *html;

#pragma mark -
#pragma mark Advanced

/**
 The name of a JavaSript object that a function named entrypoint()
 is called on for the purpose of inlining this payload.

 - Inheritance

 Textual offers a prototype named InlineMediaPrototype that your
 object can inherit from. This prototype already contains an
 entrypoint() function which you can override.

 - Function Arguments:

 The entrypoint function takes two arguments:

 1. The value of the -entrypointPayload property defined below.
 2. A callback function which itself takes one argument:
    The HTML that the entrypoint function wants to insert.

 - Requirements:

 • If the `html` property of this payload is empty:
     1. An entrypoint function is REQUIRED.
 • If the `html` property of this payload is NOT empty:
     1. An entrypoint function is OPTIONAL.
     2. If an entrypoint function is NOT set, then the value of
        the `html` property is inserted without assitance.
     3. If an entrypoin function is set, then the value of
        the contents of the payload are passed to it without
        inserting the value of the `html` property.
        The entrypoint function can then decide to insert the
        HTML when it wants by calling a callback function.

 - Example:

 ````
    MyObject.entrypoint = function(payload, callbackFunction)
    {
        // Do work here...

        callbackFunction("some HTML to display");
    }
 ````

 */
@property (copy, readonly, nullable) NSString *entrypoint;

/**
 A dictionary that is passed as the first argument to -entrypoint.

 - Dictionary Contents:

 This dictionary is guaranteed to always contain the following keys:

  1. "html" (string)
  2. "url" (string)
  3. "urlToInline" (string)
  4. "lineNumber" (string)
  5. "uniqueIdentifier" (string)

 The value of these keys mirror the payload's.

 ICLPayload will not allow you to override the value of these keys.

 - Types:

 Types are translated as such:

 ````
 Objective-C          JavaScript
 -----------          ----------
 NSArray         =>   array
 BOOL            =>   boolean
 NSNumber        =>   number
 NSDictionary    =>   object
 NSString        =>   string
 NSURL           =>   string
 ````

 Custom types are treated as "undefined"
 */
@property (copy, readonly) NSDictionary<NSString *, id <NSCopying>> *entrypointPayload;

/**
 An optional class that is appended to the inlined media.

 - Examples

 • inlineStreamable is used for Streamable,
 • inlineVimeo is used for Vimeo,
 • inlineYouTube is used for YouTube
 */
@property (copy, readonly) NSString *classAttribute;
@end

#pragma mark -
#pragma mark Mutable Object

@interface ICLPayloadMutable : ICLPayload
@property (nonatomic, copy, readwrite) NSURL *urlToInline;
@property (nonatomic, assign, readwrite) unsigned long long contentLength;
@property (nonatomic, assign, readwrite) NSSize contentSize;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *styleResources;
@property (nonatomic, copy, readwrite) NSArray<NSURL *> *scriptResources;
@property (nonatomic, copy, readwrite) NSString *html;
@property (nonatomic, copy, nullable, readwrite) NSString *entrypoint;
@property (nonatomic, copy, null_resettable, readwrite) NSDictionary<NSString *, id <NSCopying>> *entrypointPayload;
@property (nonatomic, copy, readwrite) NSString *classAttribute;

- (instancetype)init;
@end

NS_ASSUME_NONNULL_END
