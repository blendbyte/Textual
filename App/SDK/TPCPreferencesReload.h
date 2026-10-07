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

#import "TPCPreferences.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, TPCPreferencesReloadAction) {
	TPCPreferencesReloadActionAppearance							= 1 << 0,
	TPCPreferencesReloadActionChannelViewArrangement				= 1 << 1,
	TPCPreferencesReloadActionDockIconBadges						= 1 << 2,
	TPCPreferencesReloadActionHighlightKeywords						= 1 << 3,
	TPCPreferencesReloadActionHighlightLogging						= 1 << 4,
	TPCPreferencesReloadActionIRCCommandCache						= 1 << 5,
	TPCPreferencesReloadActionInputHistoryScope						= 1 << 6,
	TPCPreferencesReloadActionLogTranscripts						= 1 << 7,
	TPCPreferencesReloadActionMainWindowTransparencyLevel			= 1 << 8,
	TPCPreferencesReloadActionMemberList							= 1 << 9,
	TPCPreferencesReloadActionMemberListSortOrder					= 1 << 10,
	TPCPreferencesReloadActionMemberListUserBadges					= 1 << 11,
	TPCPreferencesReloadActionPreferencesChanged					= 1 << 12,
	TPCPreferencesReloadActionScrollbackSaveLimit					= 1 << 13,
	TPCPreferencesReloadActionScrollbackVisibleLimit				= 1 << 14,
	TPCPreferencesReloadActionServerList							= 1 << 15,
	TPCPreferencesReloadActionServerListUnreadBadges				= 1 << 16,
	TPCPreferencesReloadActionStyle									= 1 << 17,
//	TPCPreferencesReloadActionStyleWithTableViews					= 1 << 18,
	TPCPreferencesReloadActionTextDirection							= 1 << 19,
	TPCPreferencesReloadActionTextFieldFontSize						= 1 << 20,
	TPCPreferencesReloadActionTextFieldSegmentedControllerOrigin	= 1 << 21,

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	TPCPreferencesReloadActionSparkleFrameworkFeedURL				= 1 << 23,
#endif
};

@interface TPCPreferences (TPCPreferencesReload)
+ (void)performReloadActionForKeys:(NSArray<NSString *> *)keys;
+ (void)performReloadAction:(TPCPreferencesReloadAction)reloadAction;
+ (void)performReloadAction:(TPCPreferencesReloadAction)reloadAction forKey:(nullable NSString *)key; // key is only used for context
@end

NS_ASSUME_NONNULL_END
