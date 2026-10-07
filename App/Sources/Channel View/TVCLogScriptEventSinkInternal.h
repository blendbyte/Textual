/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import "TVCLogScriptEventSinkPrivate.h"

@class IRCChannel, IRCClient, TVCLogController, TVCLogPolicy, TVCLogView;

NS_ASSUME_NONNULL_BEGIN

/* Shared by TVCLogScriptEventSink.m, its category files and the context class only */

@interface TVCLogScriptEventSinkContext : NSObject
@property (nonatomic, weak) TVCLogView *webView;
@property (readonly) TVCLogPolicy *webViewPolicy;
@property (readonly) TVCLogController *viewController;
@property (readonly) IRCClient *associatedClient;
@property (readonly, nullable) IRCChannel *associatedChannel;
@property (nonatomic, copy) NSString *caller;
@property (nonatomic, copy, nullable) NSArray *arguments;
@property (nonatomic, copy, nullable) void (^completionBlock)(id _Nullable returnValue);
@end

@interface TVCLogScriptEventSink ()
+ (nullable id)objectValueToCommon:(id)object;
+ (NSString *)standardizeLineNumber:(NSString *)lineNumber;
+ (NSArray<NSString *> *)standardizeLineNumbers:(NSArray<NSString *> *)lineNumbers;
+ (void)throwJavaScriptException:(NSString *)message forCaller:(nullable NSString *)caller inWebView:(TVCLogView *)webView, ...;
- (void)processInputData:(id)inputData forCaller:(NSString *)caller inWebView:(id)webView withSelector:(SEL)selector;
- (void)processInputData:(id)inputData forCaller:(NSString *)caller inWebView:(id)webView withSelector:(SEL)selector minimumArgumentCount:(NSUInteger)minimumArgumentCount withValidation:(BOOL (NS_NOESCAPE ^ _Nullable)(NSUInteger argumentIndex, id argument))validateArgumentBlock;
@end

@interface TVCLogScriptEventSink (QueriesInternal)
@end

@interface TVCLogScriptEventSink (RenderingInternal)
@end

@interface TVCLogScriptEventSink (ActionsInternal)
@end

@interface TVCLogScriptEventSink (StylesInternal)
@end

NS_ASSUME_NONNULL_END
