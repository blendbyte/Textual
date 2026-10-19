/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

@class IRCClient, IRCChannel, TVCMainWindow;

/* Suggestions while typing: a list opens for a word that
 starts with @ (nicknames), # (channels), / at the start of the message
 (commands) or : and two letters (emoji). Each kind can be turned off. */
typedef NS_ENUM(NSUInteger, TVCInputCompletionKind) {
	TVCInputCompletionKindNickname = 0,
	TVCInputCompletionKindChannel,
	TVCInputCompletionKindCommand,
	TVCInputCompletionKindEmoji
};

/* The word being completed: range covers the trigger character */
@interface TVCInputCompletionQuery : NSObject
@property (readonly) TVCInputCompletionKind kind;
@property (readonly) NSRange range;
@property (readonly, copy) NSString *text; // without the trigger
@end

@interface TVCInputCompletionItem : NSObject
@property (readonly) TVCInputCompletionKind kind;
@property (readonly, copy) NSString *value; // nickname, channel name, command or emoji
@property (readonly, copy) NSString *title;
@property (readonly, copy, nullable) NSString *detail;

+ (instancetype)itemWithKind:(TVCInputCompletionKind)kind value:(NSString *)value title:(NSString *)title detail:(nullable NSString *)detail;
@end

@interface TVCInputCompletion : NSObject
/* The word at the insertion point that opens a list, or nil (a selection,
 a word that goes on after the insertion point, or no trigger). Kinds that
 are turned off give nil too when enabledKinds is given (NSNumber kinds). */
+ (nullable TVCInputCompletionQuery *)queryInString:(NSString *)string selectedRange:(NSRange)selectedRange;

/* What replaces the query's range: a nickname without the @, with
 the completion suffix at the start of the message; then a space unless one
 follows already */
+ (NSString *)replacementForItem:(TVCInputCompletionItem *)item query:(TVCInputCompletionQuery *)query inString:(NSString *)string nicknameSuffix:(nullable NSString *)nicknameSuffix;

/* Candidates whose name starts with text first (in their order), then those
 that contain it; case-insensitive */
+ (NSArray<NSString *> *)names:(NSArray<NSString *> *)names matching:(NSString *)text limit:(NSUInteger)limit;

/* Emoji whose name starts with text, then contains it, then with a tag that
 starts with it; from gemoji's names */
+ (NSArray<TVCInputCompletionItem *> *)emojiMatching:(NSString *)text limit:(NSUInteger)limit;

/* Every local command has a one-line description */
+ (nullable NSString *)descriptionForCommand:(NSString *)command;
@end

/* The list next to the input field of the main window */
@interface TVCInputCompletionController : NSObject
- (instancetype)initWithWindow:(TVCMainWindow *)window;

@property (readonly, getter=isVisible) BOOL visible;

/* After an edit or a move of the insertion point */
- (void)update;

- (void)close;

/* ↑ ↓ Tab Return Enter Esc while the list is open; YES when handled */
- (BOOL)handleKeyEvent:(NSEvent *)event;
@end

NS_ASSUME_NONNULL_END
