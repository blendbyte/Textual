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

#import "TVCMainWindowAppearance.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCServerListAppearance : TVCApplicationAppearance
@property (readonly) CGFloat defaultWidth;
@property (readonly) CGFloat minimumWidth;
@property (readonly) CGFloat maximumWidth;

@property (readonly, copy, nullable) NSColor *rowSelectionColorActiveWindow;
@property (readonly, copy, nullable) NSColor *rowSelectionColorInactiveWindow;

#pragma mark -
#pragma mark Server Cell

@property (readonly) BOOL serverRowEmphasized;
@property (readonly) CGFloat serverLabelLeftMargin;
@property (readonly, copy, nullable) NSColor *serverTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *serverTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *serverDisabledTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *serverDisabledTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *serverSelectedTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *serverSelectedTextColorInactiveWindow;
@property (readonly, copy, nullable) NSFont *serverFont;
@property (readonly, copy, nullable) NSFont *serverFontSelected;

#pragma mark -
#pragma mark Channel Cell

@property (readonly) BOOL channelRowEmphasized;
@property (readonly, copy, nullable) NSColor *channelTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *channelTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *channelDisabledTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *channelDisabledTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *channelSelectedTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *channelSelectedTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *channelErroneousTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *channelErroneousTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *channelHighlightTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *channelHighlightTextColorInactiveWindow;
@property (readonly, copy, nullable) NSFont *channelFont;
@property (readonly, copy, nullable) NSFont *channelFontSelected;

#pragma mark -
#pragma mark Message Count Badge

@property (readonly, copy, nullable) NSColor *unreadBadgeBackgroundColorActiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeBackgroundColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeSelectedBackgroundColorActiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeSelectedBackgroundColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeHighlightBackgroundColorActiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeHighlightBackgroundColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeHighlightBackgroundColorByUser;
@property (readonly, copy, nullable) NSColor *unreadBadgeTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeSelectedTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeSelectedTextColorInactiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeHighlightTextColorActiveWindow;
@property (readonly, copy, nullable) NSColor *unreadBadgeHighlightTextColorInactiveWindow;
@property (readonly, copy, nullable) NSFont *unreadBadgeFont;
@property (readonly, copy, nullable) NSFont *unreadBadgeFontSelected;
@property (readonly) CGFloat unreadBadgeMinimumWidth;
@property (readonly) CGFloat unreadBadgeHeight;
@property (readonly) CGFloat unreadBadgePadding;

#pragma mark -
#pragma mark Accessors

- (nullable NSString *)statusIconForActiveChannel:(BOOL)isActive
										 selected:(BOOL)isSelected
									 activeWindow:(BOOL)isActiveWindow
								  treatAsTemplate:(BOOL *)treatAsTemplate;

- (nullable NSString *)statusIconForActiveQuery:(BOOL)isActive
									   selected:(BOOL)isSelected
								   activeWindow:(BOOL)isActiveWindow
								treatAsTemplate:(BOOL *)treatAsTemplate;
@end

NS_ASSUME_NONNULL_END
