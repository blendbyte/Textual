/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2018 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

COCOA_EXTENSIONS_EXTERN NSString * const NSWindowAutosaveFrameMovesToActiveDisplay;

@interface NSWindow (CSWindowHelper)
@property (getter=isOccluded, readonly) BOOL occluded;
@property (getter=isInactive, readonly) BOOL inactive;
@property (getter=isActiveForDrawing, readonly) BOOL activeForDrawing;

- (void)exactlyCenterWindow;

+ (nullable NSWindow *)windowBeneathMouse;

@property (readonly) BOOL isBeneathMouse;

@property (readonly) BOOL runningInHighResolutionMode;

@property (getter=isInFullscreenMode, readonly) BOOL inFullscreenMode;

@property (readonly) NSWindow *deepestWindow;

@property (readonly) NSRect titlebarFrame;

- (void)saveWindowStateUsingKeyword:(NSString *)keyword;
- (void)restoreWindowStateUsingKeyword:(NSString *)keyword;

- (void)saveWindowStateForClass:(Class)owner;
- (void)restoreWindowStateForClass:(Class)owner;

/* Save the current size of the window as the default size */
- (void)saveSizeAsDefault;
@property (nonatomic, assign) NSSize defaultSize;

/* Returns the current frame, adjusted to the default size */
/* Returns NSZeroRect if no default size is saved */
@property (readonly) NSRect defaultFrame;

/* Does nothing if no default size is saved */
- (void)restoreDefaultSize; // display = YES
- (void)restoreDefaultSizeAndDisplay:(BOOL)display;
@end

NS_ASSUME_NONNULL_END
