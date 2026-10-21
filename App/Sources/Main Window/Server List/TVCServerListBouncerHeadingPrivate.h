/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

@class IRCBouncerAccount, IRCClient;

/* A bouncer's section heading in the server list: the servers going through
 it follow it, at the server level as any server (they aren't its children,
 so everything that expects a server at the top keeps working). It can't be
 selected; a click folds it, which hides its servers. */
@interface TVCServerListBouncerHeading : NSObject
- (instancetype)initWithAccountIdentifier:(NSString *)accountIdentifier NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, copy) NSString *accountIdentifier;
@property (readonly, nullable) IRCBouncerAccount *account;
@property (readonly, copy) NSArray<IRCClient *> *clients; // in the order of the server list

/* Not a server or channel: code that walks the rows can ask */
@property (readonly) BOOL isClient;
@property (readonly) BOOL isChannel;
@property (readonly) BOOL isPrivateMessage;
@property (readonly) NSUInteger numberOfChildren;
@end

/* A little space after a bouncer's section, where a normal server follows it
 (the user: mixed order, a gap marks where a section ends) */
@interface TVCServerListSectionGap : NSObject
@property (readonly) BOOL isClient;
@property (readonly) BOOL isChannel;
@property (readonly) BOOL isPrivateMessage;
@property (readonly) NSUInteger numberOfChildren;
@end

/* A heading or a gap: rows that aren't a server or channel, never selected */
TEXTUAL_EXTERN BOOL TVCServerListItemIsDecoration(id _Nullable item);

/* The heading's row: the bouncer's name, its kind small after it, and a chevron */
@interface TVCServerListBouncerHeadingView : NSTableCellView
+ (NSString *)viewIdentifier;

- (void)showHeading:(TVCServerListBouncerHeading *)heading folded:(BOOL)folded;

@property (nonatomic, copy, nullable) void (^toggleFolding)(void);
@end

NS_ASSUME_NONNULL_END
