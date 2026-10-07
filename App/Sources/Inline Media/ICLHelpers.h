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
+ (void)requestJSONDataFromURL:(NSURL *)url completionBlock:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable data))completionBlock;
+ (void)requestJSONDataFromAddress:(NSString *)address completionBlock:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable data))completionBlock;

+ (void)requestJSONObject:(NSString *)objectKey ofType:(Class)objectType inHierarchy:(nullable NSArray<NSString *> *)hierarchy fromURL:(NSURL *)url completionBlock:(void (^)(id _Nullable object))completionBlock;
+ (void)requestJSONObject:(NSString *)objectKey ofType:(Class)objectType inHierarchy:(nullable NSArray<NSString *> *)hierarchy fromAddress:(NSString *)address completionBlock:(void (^)(id _Nullable object))completionBlock;
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
