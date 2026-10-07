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

@class IRCClient, IRCChannel;
@class TVCLogLine, TVCLogView, TVCMainWindow;

TEXTUAL_EXTERN NSNotificationName const TVCLogControllerViewFinishedLoadingNotification;

@interface TVCLogController : NSObject
@property (readonly) TVCLogView *backingView;
@property (readonly, getter=viewIsEncrypted) BOOL encrypted TEXTUAL_DEPRECATED("Textual no longer encrypts messages. Always NO");
@property (readonly, getter=viewIsLoaded) BOOL loaded;
@property (readonly, getter=viewIsSelected) BOOL selected;
@property (readonly, getter=viewIsVisible) BOOL visible;
@property (readonly) NSUInteger numberOfLines;
@property (readonly, weak) IRCClient *associatedClient;
@property (readonly, weak) IRCChannel *associatedChannel;
@property (readonly, weak) TVCMainWindow *attachedWindow;
@property (readonly, copy, nullable) NSString *newestLineNumberFromPreviousSession;
@property (readonly, copy, nullable) NSString *oldestLineNumber;
@property (readonly, copy, nullable) NSString *newestLineNumber;

- (instancetype)init NS_UNAVAILABLE;

- (void)nextHighlight;
- (void)previousHighlight;

- (BOOL)highlightAvailable:(BOOL)previous;

@property (readonly, copy) NSString *uniqueIdentifier;

- (void)moveToTop;
- (void)moveToBottom;

- (void)jumpToCurrentSession;
- (void)jumpToPresent;

- (void)jumpToLine:(NSString *)lineNumber;
- (void)jumpToLine:(NSString *)lineNumber completionHandler:(void (^ _Nullable)(BOOL result))completionHandler;

- (void)setTopic:(nullable NSString *)topic;

@property (readonly) BOOL inlineMediaEnabledForView;

- (void)mark;
- (void)unmark;

- (void)goToMark;

- (void)clear;

- (void)changeTextSize:(BOOL)bigger;

- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments; // Defaults to onQueue YES
- (void)evaluateFunction:(NSString *)function withArguments:(nullable NSArray *)arguments onQueue:(BOOL)onQueue;
@end

#pragma mark -

@interface TVCLogControllerPrintOperationContext : NSObject
@property (readonly, weak) IRCClient *client;
@property (readonly, weak) IRCChannel *channel;
@property (readonly, getter=isHighlight) BOOL highlight;
@property (readonly, copy) TVCLogLine *logLine;
@property (readonly, copy) NSString *lineNumber;
@end

typedef void (^TVCLogControllerPrintOperationCompletionBlock)(TVCLogControllerPrintOperationContext *context);

NS_ASSUME_NONNULL_END
