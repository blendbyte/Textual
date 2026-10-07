/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *    Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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

#import "NSObjectHelperPrivate.h"
#import "TVCErrorMessagePopoverPrivate.h"
#import "TVCErrorMessagePopoverControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCErrorMessagePopoverController ()
@property (nonatomic, strong, nullable) TVCErrorMessagePopover *visiblePopover;
@end

@implementation TVCErrorMessagePopoverController

#pragma mark -
#pragma mark Public

+ (TVCErrorMessagePopoverController *)sharedController
{
	static TVCErrorMessagePopoverController *sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedSelf = [self new];
	});

	return sharedSelf;
}

- (void)showMessage:(NSString *)message forView:(NSView *)view
{
	NSParameterAssert(message != nil);
	NSParameterAssert(view != nil);

	TVCErrorMessagePopover *popover = self.visiblePopover;

	BOOL popoverIsSame =
	(popover && popover.view == view && [popover.message isEqualToString:message]);

	if (popoverIsSame == NO) {
		/* Close message already on screen being tracked */
		if (popover) {
			[popover close];
		}

		/* Show message */
		popover = [[TVCErrorMessagePopover alloc] initWithMessage:message relativeToView:view];
	}

	[popover showRelativeToRect:view.bounds];

	if (popoverIsSame == NO) {
		self.visiblePopover = popover;
	}
}

- (void)closeMessage
{
	[self _closePopoverForView:nil];
}

- (void)closeMessageForView:(NSView *)view
{
	[self _closePopoverForView:view];
}

#pragma mark -
#pragma mark Private

- (void)_closePopoverForView:(nullable NSView *)view
{
	TVCErrorMessagePopover *popover = self.visiblePopover;

	if (popover == nil || (view && view != popover.view)) {
		return;
	}

	[popover close];

	self.visiblePopover = nil;
}

@end

NS_ASSUME_NONNULL_END
