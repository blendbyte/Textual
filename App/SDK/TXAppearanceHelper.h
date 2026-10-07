/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *     Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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

@interface NSView (TXAppearance)
/* Posted when the application appearance changes */
/* The default implementation does nothing nor is super required */
- (void)applicationAppearanceChanged;

/* Can return YES to change default implementation of
 -applicationAppearanceChanged to set needsDisplay to YES. */
@property (readonly) BOOL needsDisplayWhenApplicationAppearanceChanges;

/* Returns YES by default. If NO, -applicationAppearanceChanged
 will not be sent beyond the view that returned NO. */
@property (readonly) BOOL sendApplicationAppearanceChangedToSubviews;

/* Performs -applicationAppearanceChanged on view and all subviews
 if -sendApplicationAppearanceChangedToSubviews doesn't return NO. */
- (void)notifyApplicationAppearanceChanged;

/* Posted when the system appearance changes */
/* The default implementation does nothing nor is super required */
- (void)systemAppearanceChanged;

/* Can return YES to change default implementation of
 -systemAppearanceChanged to set needsDisplay to YES. */
@property (readonly) BOOL needsDisplayWhenSystemAppearanceChanges;

/* Returns YES by default. If NO, -systemAppearanceChanged
 will not be sent beyond the view that returned NO. */
@property (readonly) BOOL sendSystemAppearanceChangedToSubviews;

/* Performs -systemAppearanceChanged on view and all subviews
 if -sendSystemAppearanceChangedToSubviews doesn't return NO. */
- (void)notifySystemAppearanceChanged;
@end

@interface NSWindow (TXApplication)
/* Performs -applicationAppearanceChanged on window beginning
 with the window frame which contains title and content view. */
- (void)notifyApplicationAppearanceChanged;

/* Performs -systemAppearanceChanged on window beginning
 with the window frame which contains title and content view. */
- (void)notifySystemAppearanceChanged;
@end

NS_ASSUME_NONNULL_END
