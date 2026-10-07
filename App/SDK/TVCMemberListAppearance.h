/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2018 - 2020Codeux Software, LLC & respective contributors.
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

#import "IRCChannelUser.h"
#import "TVCMainWindowAppearance.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMemberListAppearance : TVCApplicationAppearance
@property (readonly) CGFloat defaultWidth;
@property (readonly) CGFloat minimumWidth;
@property (readonly) CGFloat maximumWidth;

@property (readonly, copy, nullable) NSColor *rowSelectionColorActiveWindow;
@property (readonly, copy, nullable) NSColor *rowSelectionColorInactiveWindow;

#pragma mark -
#pragma mark Member Cell

@property (readonly) BOOL cellRowEmphasized;
@property (readonly, copy, nullable) NSColor *cellTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *cellTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *cellAwayTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *cellAwayTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *cellSelectedTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *cellSelectedTextColorInactiveWindow;
@property (readonly, copy, nullable) NSFont *cellFont;
@property (readonly, copy, nullable) NSFont *cellFontSelected;

#pragma mark -
#pragma mark Mark Badge

@property (readonly) CGFloat markBadgeLeftMargin;
@property (readonly, copy, nullable) NSColor *markBadgeBackgroundColorActiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeBackgroundColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeSelectedBackgroundColorActiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeSelectedBackgroundColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeSelectedTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *markBadgeSelectedTextColorInactiveWindow;
@property (readonly, copy, nullable) NSFont *markBadgeFont;
@property (readonly, copy, nullable) NSFont *markBadgeFontSelected;

#pragma mark -
#pragma mark Mark Badge Modes

/* These will never be nil because default is stored in preferences. */
@property (readonly, copy) NSColor *markBadgeBackgroundColor_Y;
@property (readonly, copy) NSColor *markBadgeBackgroundColor_A;
@property (readonly, copy) NSColor *markBadgeBackgroundColor_H;
@property (readonly, copy) NSColor *markBadgeBackgroundColor_O;
@property (readonly, copy) NSColor *markBadgeBackgroundColor_Q;
@property (readonly, copy) NSColor *markBadgeBackgroundColor_V;

/* -markBadgeBackgroundColorByUser is the no mode ("x") background color
 defined by user. This value can be nil. Use the activeWindow or inactiveWindow
 background colors defined above when this is nil. */
@property (readonly, copy, nullable) NSColor *markBadgeBackgroundColorByUser;

#pragma mark -
#pragma mark Accessors

- (nullable NSImage *)cachedUserMarkBadgeForSymbol:(NSString *)modeSymbol rank:(IRCUserRank)rank;
- (void)cacheUserMarkBadge:(NSImage *)badgeImage forSymbol:(NSString *)modeSymbol rank:(IRCUserRank)rank;

- (void)invalidateUserMarkBadgeCacheForSymbol:(NSString *)modeSymbol rank:(IRCUserRank)rank;
- (void)invalidateUserMarkBadgeCaches;
@end

NS_ASSUME_NONNULL_END
