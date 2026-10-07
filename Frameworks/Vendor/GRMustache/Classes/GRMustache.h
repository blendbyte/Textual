// The MIT License
// 
// Copyright (c) 2014 Gwendal Roué
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <GRMustache/GRMustacheAvailabilityMacros.h>

@protocol GRMustacheRendering;
@class GRMustacheTag;
@class GRMustacheContext;

/**
 * A C struct that hold GRMustache version information
 * 
 * @since v1.0
 */
typedef struct {
    int major;    /**< The major component of the version. */
    int minor;    /**< The minor component of the version. */
    int patch;    /**< The patch-level component of the version. */
} GRMustacheVersion;


/**
 * The GRMustache class provides with global-level information and configuration
 * of the GRMustache library.
 *
 * @since v1.0
 */
@interface GRMustache: NSObject

////////////////////////////////////////////////////////////////////////////////
/// @name Getting the GRMustache version
////////////////////////////////////////////////////////////////////////////////

/**
 * @return The version of GRMustache as a GRMustacheVersion struct.
 *
 * @since v7.0
 */
+ (GRMustacheVersion)libraryVersion AVAILABLE_GRMUSTACHE_VERSION_7_0_AND_LATER;


////////////////////////////////////////////////////////////////////////////////
/// @name Standard Library
////////////////////////////////////////////////////////////////////////////////

/**
 * @return The GRMustache standard library.
 *
 * **Companion guide:** https://github.com/groue/GRMustache/blob/master/Guides/standard_library.md
 *
 * @since v6.4
 */
+ (NSObject *)standardLibrary AVAILABLE_GRMUSTACHE_VERSION_7_0_AND_LATER;


////////////////////////////////////////////////////////////////////////////////
/// @name Building rendering objects
////////////////////////////////////////////////////////////////////////////////

/**
 * This method is deprecated. Use
 * `+[GRMustacheRendering renderingObjectForObject:]` instead.
 *
 * @see GRMustacheRendering class
 *
 * @since v6.0
 * @deprecated v7.0
 */
+ (id<GRMustacheRendering>)renderingObjectForObject:(id)object AVAILABLE_GRMUSTACHE_VERSION_7_0_AND_LATER_BUT_DEPRECATED;

/**
 * This method is deprecated. Use
 * `+[GRMustacheRendering renderingObjectWithBlock:]` instead.
 *
 * @see GRMustacheRendering class
 *
 * @since v6.0
 * @deprecated v7.0
 */
+ (id<GRMustacheRendering>)renderingObjectWithBlock:(NSString *(^)(GRMustacheTag *tag, GRMustacheContext *context, BOOL *HTMLSafe, NSError **error))block AVAILABLE_GRMUSTACHE_VERSION_7_0_AND_LATER_BUT_DEPRECATED;

@end

#import <GRMustache/GRMustacheTemplate.h>
#import <GRMustache/GRMustacheTagDelegate.h>
#import <GRMustache/GRMustacheTemplateRepository.h>
#import <GRMustache/GRMustacheFilter.h>
#import <GRMustache/GRMustacheError.h>
#import <GRMustache/GRMustacheVersion.h>
#import <GRMustache/GRMustacheContentType.h>
#import <GRMustache/GRMustacheContext.h>
#import <GRMustache/GRMustacheRendering.h>
#import <GRMustache/GRMustacheTag.h>
#import <GRMustache/GRMustacheConfiguration.h>
#import <GRMustache/GRMustacheLocalizer.h>
#import <GRMustache/GRMustacheSafeKeyAccess.h>
