/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2020 Codeux Software, LLC
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

#import <objc/message.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSThemeFrame ()
@property NSRect _maxTitlebarTitleRect;
@property (copy) NSArray<__kindof NSTitlebarAccessoryViewController *> *titlebarAccessoryViewControllers;
@end

@implementation NSThemeFrame (CSThemeFrameHelper)

+ (void)load
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		XRExchangeInstanceMethod(@"NSThemeFrame", @"_defaultTitlebarTitleRect", @"ce_priv_defaultTitlebarTitleRect");
	});
}

/* -ce_priv_defaultTitlebarTitleRect is an extremely dirty bug fix. */
/* This fix will break titles if the titlebar contains an autosave button
 or a document icon so do not use this method unless you know its purpose. */
- (NSRect)ce_priv_defaultTitlebarTitleRect
{
	/* Return default value depending on configuration */
	NSRect defaultTitlebarTitleRect = [self ce_priv_defaultTitlebarTitleRect];

	if (self.usesCustomTitlebarTitlePositioning == NO) {
		return defaultTitlebarTitleRect;
	}

	if (NSIsEmptyRect(defaultTitlebarTitleRect)) {
		return defaultTitlebarTitleRect;
	}

	/* Use private method to calculate the maximum possible size for rect */
	NSRect maximumTitleRect = self._maxTitlebarTitleRect;

	if (NSIsEmptyRect(maximumTitleRect)) {
		return defaultTitlebarTitleRect;
	}

	/* Given a maximum frame and the default, we fudge the values a bit. */
	NSRect finalTitleRect = NSZeroRect;

	finalTitleRect.size = defaultTitlebarTitleRect.size;

	finalTitleRect.origin.x = (NSMidX(maximumTitleRect) - (defaultTitlebarTitleRect.size.width / 2.0)); // Center the point

	finalTitleRect.origin.y = defaultTitlebarTitleRect.origin.y;

	return finalTitleRect;
}

- (BOOL)usesCustomTitlebarTitlePositioning
{
	/* This fix is not necessary unless we have custom views */
	NSArray *viewControllers = self.titlebarAccessoryViewControllers;

	if (viewControllers && [viewControllers isKindOfClass:[NSArray class]]) {
		BOOL allViewControllersHidden = YES;

		for (NSViewController *viewController in viewControllers) {
			if (viewController.view.hidden == NO) {
				allViewControllersHidden = NO;

				break;
			}
		}

		if (allViewControllersHidden) {
			return NO;
		}
	}

	/* Assigned object is an NSNumber which means we have to translate to BOOL */
	NSNumber *customPositioning = objc_getAssociatedObject(self, @selector(usesCustomTitlebarTitlePositioning));

	if (customPositioning) {
		return customPositioning.boolValue;
	}

	return NO;
}

- (void)setUsesCustomTitlebarTitlePositioning:(BOOL)usesCustomTitlebarTitlePositioning
{
	/* Assigned as an NSNumber that is copied. */
	objc_setAssociatedObject(self,
		@selector(usesCustomTitlebarTitlePositioning),
		@(usesCustomTitlebarTitlePositioning),
		OBJC_ASSOCIATION_COPY);
}

@end

NS_ASSUME_NONNULL_END
