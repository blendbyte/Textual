/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

TEXTUAL_EXTERN NSString * const TVCLogViewCommonUserAgentString;

@interface TVCLogView : NSObject
@property (readonly) BOOL hasSelection;
- (void)clearSelection;
@property (readonly, copy, nullable) NSString *selection;

/* Textual uses only WebKit2: both always return YES */
@property (readonly, class) BOOL webKit2Enabled TEXTUAL_DEPRECATED("Always YES");
@property (readonly) BOOL isUsingWebKit2 TEXTUAL_DEPRECATED("Always YES");

@property (readonly) NSView *webView;

@property (readonly, getter=isLayingOutView) BOOL layingOutView;

- (instancetype)init NS_UNAVAILABLE;
@end

@interface TVCLogView (TVCLogViewJavaScriptHandler)
- (void)evaluateJavaScript:(NSString *)code;
- (void)evaluateJavaScript:(NSString *)code completionHandler:(void (^ _Nullable)(id _Nullable result))completionHandler;

- (void)evaluateFunction:(NSString *)function;
- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments;
- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(id _Nullable result))completionHandler;

- (void)booleanByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(BOOL result))completionHandler;
- (void)booleanByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(BOOL result))completionHandler;

- (void)stringByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(NSString * _Nullable result))completionHandler;
- (void)stringByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(NSString * _Nullable result))completionHandler;

- (void)arrayByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(NSArray * _Nullable result))completionHandler;
- (void)arrayByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(NSArray * _Nullable result))completionHandler;

- (void)dictionaryByEvaluatingFunction:(NSString *)function completionHandler:(void (^ _Nullable)(NSDictionary<NSString *, id> * _Nullable result))completionHandler;
- (void)dictionaryByEvaluatingFunction:(NSString *)function withArguments:(nullable NSArray *)arguments completionHandler:(void (^ _Nullable)(NSDictionary<NSString *, id> * _Nullable result))completionHandler;

+ (NSString *)escapeJavaScriptString:(NSString *)string;

+ (NSString *)descriptionOfJavaScriptResult:(id)scriptResult;

- (void)logToJavaScriptConsole:(NSString *)message, ...;
@end

NS_ASSUME_NONNULL_END
