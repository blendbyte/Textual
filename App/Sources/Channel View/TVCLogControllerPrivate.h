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

#import "TVCLogController.h"

NS_ASSUME_NONNULL_BEGIN

@class ICLPayload;

@interface TVCLogController ()

/* Typing notifications: "… is typing" as the last line of the view */
- (void)setTypingIndicatorText:(NSString *)text;
- (void)removeTypingIndicator;

- (instancetype)initWithClient:(IRCClient *)client inWindow:(TVCMainWindow *)window NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithChannel:(IRCChannel *)channel inWindow:(TVCMainWindow *)window NS_DESIGNATED_INITIALIZER;

- (void)notifyDidBecomeHidden;
- (void)notifyDidBecomeVisible;
- (void)notifySelectionChanged;

- (void)changeScrollbackLimit;

- (void)clearBackingView;

- (void)reloadTheme;

- (void)print:(TVCLogLine *)logLine;
- (void)print:(TVCLogLine *)logLine completionBlock:(nullable TVCLogControllerPrintOperationCompletionBlock)completionBlock;

- (void)renderLogLineAtLineNumber:(NSString *)lineNumber
			  numberOfLinesBefore:(NSUInteger)numberOfLinesBefore
			   numberOfLinesAfter:(NSUInteger)numberOfLinesAfter
				  completionBlock:(void (^)(NSArray<NSDictionary<NSString *,id> *> * _Nonnull))completionBlock;

- (void)renderLogLinesBeforeLineNumber:(NSString *)lineNumber
				  maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
					   completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock;

- (void)renderLogLinesAfterLineNumber:(NSString *)lineNumber
				 maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
					  completionBlock:(void (^)(NSArray<NSDictionary<NSString *, id> *> *))completionBlock;

- (void)renderLogLinesAfterLineNumber:(NSString *)lineNumberAfter
					 beforeLineNumber:(NSString *)lineNumberBefore
				 maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
					  completionBlock:(void (^)(NSArray<NSDictionary<NSString *,id> *> * _Nonnull))completionBlock;

- (void)notifyLinesAddedToView:(NSArray<NSString *> *)lineNumbers;
- (void)notifyLinesRemovedFromView:(NSArray<NSString *> *)lineNumbers;

- (void)notifyJumpToLine:(NSString *)lineNumber successful:(BOOL)successful scrolledToBottom:(BOOL)scrolledToBottom;

- (void)notifyHistoricLogWillDeleteLines:(NSArray<NSString *> *)lineNumbers;

- (void)processInlineMediaAtAddress:(NSString *)address withUniqueIdentifier:(NSString *)uniqueIdentifier atLineNumber:(NSString *)lineNumber index:(NSUInteger)index;

- (void)processingInlineMediaPayloadSucceeded:(ICLPayload *)payload;
- (void)processingInlineMediaPayload:(ICLPayload *)payload failedWithError:(NSError *)error;

- (void)logViewWebViewClosedUnexpectedly;
- (void)logViewWebViewFinishedLoading;
- (void)logViewWebViewKeyDown:(NSEvent *)e;
- (void)logViewWebViewReceivedDropWithFile:(NSString *)filename;

- (nullable TVCLogLine *)lastLine;
@end

NS_ASSUME_NONNULL_END
