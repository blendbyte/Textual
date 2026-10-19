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

#import "ICLInlineContentModule.h"

NS_ASSUME_NONNULL_BEGIN

/* What a preview card shows: a video (a large picture with
 ▶, the title, details such as the channel and length), a post (author,
 text, an image, details) or a page (a small picture, title, description,
 details). Providers fill it from a service's metadata; nothing in it is
 HTML: the card's own template escapes every value, and its pictures load
 through Textual (ICLMediaSchemeHandler) like any image. */
typedef NS_ENUM(NSUInteger, ICMPreviewCardStyle) {
	ICMPreviewCardStyleVideo = 0,
	ICMPreviewCardStylePost,
	ICMPreviewCardStylePage
};

@interface ICMPreviewCardContent : NSObject
@property (nonatomic, assign) ICMPreviewCardStyle style;
@property (nonatomic, copy) NSURL *targetURL; // opened when the card is clicked
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *text; // a post's text or a page's description
@property (nonatomic, copy, nullable) NSString *authorName;
@property (nonatomic, copy, nullable) NSString *authorHandle;
@property (nonatomic, copy, nullable) NSURL *avatarURL;
@property (nonatomic, copy, nullable) NSURL *imageURL; // thumbnail, post image or page image
@property (nonatomic, copy, nullable) NSArray<NSString *> *details; // shown joined with " · "
@property (nonatomic, assign) NSTimeInterval duration; // a video's length, 0 if unknown
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *dataAttributes; // data-… on the card, for its script
@property (nonatomic, assign) BOOL playsInWindow; // a video card's picture opens Textual's player (YouTube); the rest opens the link
@end

/* The root class of card providers */
@interface ICMPreviewCard : ICLInlineContentModule
- (void)performActionForCard:(ICMPreviewCardContent *)card;

- (void)notifyUnableToPresentCard;

/* "4:12", "1:02:03" */
+ (NSString *)formattedDuration:(NSTimeInterval)duration;
@end

NS_ASSUME_NONNULL_END
