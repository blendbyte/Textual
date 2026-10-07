/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

TEXTUAL_EXTERN NSString * const TPCResourceManagerBundleDocumentTypeExtension;
TEXTUAL_EXTERN NSString * const TPCResourceManagerBundleDocumentTypeExtensionWithoutPeriod;

TEXTUAL_EXTERN NSString * const TPCResourceManagerScriptDocumentTypeExtension;
TEXTUAL_EXTERN NSString * const TPCResourceManagerScriptDocumentTypeExtensionWithoutPeriod;

@interface TPCResourceManager : NSObject
/* Open a property list file in the Resources folder of Textual named `name` in optional
 subdirectory `subpath`. If `key` is specified, then the object value of `key` is returned
 from the root object of the property list as long as that object is a dictionary.
 The root object is returned if `key` is not specified if it is a dictionary.
 The value of this returned object is cached unless `cacheValue` is NO.
 Cache is also bypassed when `cacheValue` is NO. */
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name cacheValue:(BOOL)cacheValue;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath cacheValue:(BOOL)cacheValue;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name key:(nullable NSString *)key;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name key:(nullable NSString *)key cacheValue:(BOOL)cacheValue;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key;
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key cacheValue:(BOOL)cacheValue;

/* Open a property list file in the Resources folder of Textual named `name` in optional
 subdirectory `subpath`. If `key` is specified, then the object value of `key` is returned
 from the root object of the property list as long as that object is an array.
 The root object is returned if `key` is not specified if it is an array.
 The value of this returned object is cached unless `cacheValue` is NO.
 Cache is also bypassed when `cacheValue` is NO. */
+ (nullable NSArray *)arrayFromResources:(NSString *)name;
+ (nullable NSArray *)arrayFromResources:(NSString *)name cacheValue:(BOOL)cacheValue;
+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath;
+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath cacheValue:(BOOL)cacheValue;
+ (nullable NSArray *)arrayFromResources:(NSString *)name key:(nullable NSString *)key;
+ (nullable NSArray *)arrayFromResources:(NSString *)name key:(nullable NSString *)key cacheValue:(BOOL)cacheValue;
+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key;
+ (nullable NSArray *)arrayFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key cacheValue:(BOOL)cacheValue;

/* Open a property list file in the Resources folder of Textual named `name` in optional
 subdirectory `subpath`. If `key` is specified, then the object value of `key` is returned
 from the root object of the property list as long as that object is kind of `class`.
 The root object is returned if `key` is not specified if it is kind of `class`.
 The value of this returned object is cached unless `cacheValue` is NO.
 Cache is also bypassed when `cacheValue` is NO. */
+ (nullable id)objectFromResources:(NSString *)name inDirectory:(nullable NSString *)subpath key:(nullable NSString *)key kindOf:(Class)class cacheValue:(BOOL)cacheValue;

/* This cache object is used for loading resources using the methods above.
 The key used for each cache entry is an implementation detail and is subject to change. */
@property (class, strong, readonly) NSCache *sharedResourcesCache;
@end

NS_ASSUME_NONNULL_END
