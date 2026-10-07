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

/* TVCAlert acts as a non-blocking substitute to NSAlert
 which can be used to show messages that aren't important. */
typedef NS_ENUM(NSUInteger, TVCAlertResponseButton) {
	TVCAlertResponseButtonFirst = 1000,
	TVCAlertResponseButtonSecond = 1001,
	TVCAlertResponseButtonThird = 1002
};

typedef NS_ENUM(NSUInteger, TVCAlertType)
{
	/* Standard alert */
	TVCAlertTypeInformational = 0,

	/* Warning icon appears above icon. No other difference. */
	TVCAlertTypeWarning
};

@class TVCAlert;

typedef void (^TVCAlertCompletionBlock)(TVCAlert *sender, TVCAlertResponseButton buttonClicked);
typedef BOOL (^TVCAlertButtonClickedBlock)(TVCAlert *sender, TVCAlertResponseButton buttonClicked);

@interface TVCAlert : NSObject
/* All properties are immutable once alert is visible */
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, copy) NSString *informativeText;

@property (nonatomic, strong, null_resettable) NSImage *icon;

@property (nonatomic, assign) TVCAlertType type;

- (NSButton *)setTitle:(NSString *)title forButton:(TVCAlertResponseButton)button;
- (NSButton *)setTitle:(NSString *)title forButtonAtIndex:(NSUInteger)index;

@property (copy, readonly) NSArray<NSButton *> *buttons;

@property (nonatomic, assign) BOOL showsSuppressionButton;

@property (readonly, weak) NSButton *suppressionButton;

@property (nonatomic, strong, nullable) NSView *accessoryView;

@property (readonly, strong) NSWindow *window;

- (void)showAlert;
- (void)showAlertWithCompletionBlock:(nullable TVCAlertCompletionBlock)completionBlock;

- (void)showAlertInWindow:(NSWindow *)window;
- (void)showAlertInWindow:(NSWindow *)window withCompletionBlock:(nullable TVCAlertCompletionBlock)completionBlock;

- (TVCAlertResponseButton)runModal;

/* A block that is called when a button is clicked.

 If the block returns YES, then the alert is dismissed.
 If the block returns NO, then no action is taken.

 This feature allows you to take action when a button is clicked,
 while keeping it visible to the user, without the need to override
 the target / action of the button in question. */
/* Changing a button clicked block is permitted with an alert visible. */
/* An exception is thrown for out-of-bounds access so call this AFTER
 a button at the index is added. */
- (void)setButtonClickedBlock:(nullable TVCAlertButtonClickedBlock)block forButton:(TVCAlertResponseButton)button;
- (void)setButtonClickedBlock:(nullable TVCAlertButtonClickedBlock)block forButtonAtIndex:(NSUInteger)index;

/* End alert */
- (void)endAlert; // TVCAlertResponseButtonFirst
- (void)endAlertWithResponse:(TVCAlertResponseButton)response;
@end

NS_ASSUME_NONNULL_END
