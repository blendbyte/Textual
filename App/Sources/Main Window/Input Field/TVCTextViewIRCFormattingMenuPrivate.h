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

NS_ASSUME_NONNULL_BEGIN

#define TVCTextViewIRCFormattingMenuFormatterMenuTag			53037

@interface TVCTextViewIRCFormattingMenu : NSObject
@property (readonly, weak) NSMenuItem *formatterMenu;
@property (readonly, weak) NSMenu *foregroundColorMenu;
@property (readonly, weak) NSMenu *backgroundColorMenu;

@property (readonly) BOOL firstResponderSupportsFormatting;

@property (readonly) BOOL textIsBold;
@property (readonly) BOOL textIsItalicized;
@property (readonly) BOOL textIsMonospace;
@property (readonly) BOOL textIsStruckthrough;
@property (readonly) BOOL textIsUnderlined;
@property (readonly) BOOL textHasForegroundColor;
@property (readonly) BOOL textHasBackgroundColor;
@property (readonly) BOOL textHasSpoiler;

- (IBAction)insertBoldCharIntoTextBox:(id)sender;
- (IBAction)insertItalicCharIntoTextBox:(id)sender;
- (IBAction)insertMonospaceCharIntoTextBox:(id)sender;
- (IBAction)insertStrikethroughCharIntoTextBox:(id)sender;
- (IBAction)insertUnderlineCharIntoTextBox:(id)sender;
- (IBAction)insertForegroundColorCharIntoTextBox:(id)sender;
- (IBAction)insertBackgroundColorCharIntoTextBox:(id)sender;
- (IBAction)insertSpoilerCharIntoTextBox:(id)sender;

- (IBAction)removeBoldCharFromTextBox:(id)sender;
- (IBAction)removeItalicCharFromTextBox:(id)sender;
- (IBAction)removeMonospaceCharFromTextBox:(id)sender;
- (IBAction)removeStrikethroughCharFromTextBox:(id)sender;
- (IBAction)removeUnderlineCharFromTextBox:(id)sender;
- (IBAction)removeForegroundColorCharFromTextBox:(id)sender;
- (IBAction)removeBackgroundColorCharFromTextBox:(id)sender;
- (IBAction)removeSpoilerCharFromTextBox:(id)sender;
@end

NS_ASSUME_NONNULL_END
