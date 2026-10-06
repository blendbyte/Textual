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

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSMenu (CSMenuHelper)
@end

@implementation NSMenuItem (CSMenuItemHelper)

- (nullable NSString *)archivedKeyEquivalent
{
	return objc_getAssociatedObject(self, @selector(archivedKeyEquivalent));
}

- (void)setArchivedKeyEquivalent:(nullable NSString *)archivedKeyEquivalent
{
	objc_setAssociatedObject(self, @selector(archivedKeyEquivalent), archivedKeyEquivalent, OBJC_ASSOCIATION_COPY);
}

- (NSEventModifierFlags)archivedKeyEquivalentModifierMask
{
	NSNumber *active = [self _archivedKeyEquivalentModifierMask];

	if (active) {
		return active.doubleValue;
	}

	return 0.0;
}

- (nullable NSNumber *)_archivedKeyEquivalentModifierMask
{
	return objc_getAssociatedObject(self, @selector(archivedKeyEquivalentModifierMask));
}

- (void)setArchivedKeyEquivalentModifierMask:(NSEventModifierFlags)archivedKeyEquivalentModifierMask
{
	objc_setAssociatedObject(self, @selector(archivedKeyEquivalentModifierMask), @(archivedKeyEquivalentModifierMask), OBJC_ASSOCIATION_COPY);
}

- (void)archiveKeyboardShortcut
{
	self.archivedKeyEquivalent = self.keyEquivalent;
	self.archivedKeyEquivalentModifierMask = self.keyEquivalentModifierMask;
}

- (void)archiveKeyboardShortcutAndUnset
{
	[self archiveKeyboardShortcut];

	[self unsetKeyboardShortcut];
}

- (void)restoreKeyboardShortcut
{
	NSString *keyEquivalent = self.archivedKeyEquivalent;

	if (keyEquivalent == nil) {
		return;
	}

	self.keyEquivalent = keyEquivalent;
	self.keyEquivalentModifierMask = self.archivedKeyEquivalentModifierMask;
}

- (void)unsetKeyboardShortcut
{
	self.keyEquivalent = @"";
	self.keyEquivalentModifierMask = 0;
}

- (void)unsetArchivedKeyboardShortcut
{
	self.archivedKeyEquivalent = nil;
	self.archivedKeyEquivalentModifierMask = 0;
}

- (BOOL)isKeyboardShortcutArchived
{
	return (self.archivedKeyEquivalent != nil);
}

- (nullable NSString *)userInfo
{
	return objc_getAssociatedObject(self, @selector(userInfo));
}

- (void)setUserInfo:(nullable NSString *)userInfo
{
	objc_setAssociatedObject(self, @selector(userInfo), userInfo, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setUserInfo:(nullable NSString *)userInfo recursively:(BOOL)recursively
{
	if (recursively) {
		if (self.hasSubmenu) {
			NSArray *subItems = self.submenu.itemArray;

			for (NSMenuItem *subItem in subItems) {
				[subItem setUserInfo:userInfo recursively:YES];
			}
		}
	}

	self.userInfo = userInfo;
}

+ (instancetype)menuItemWithTitle:(NSString *)aString target:(id)aTarget action:(SEL)aSelector
{
	return [self menuItemWithTitle:aString target:aTarget action:aSelector keyEquivalent:@"" keyEquivalentMask:0];
}

+ (instancetype)menuItemWithTitle:(NSString *)aString target:(id)aTarget action:(SEL)aSelector keyEquivalent:(NSString *)charCode keyEquivalentMask:(NSUInteger)mask
{
	id menuItem = [[self alloc] initWithTitle:aString action:aSelector keyEquivalent:charCode];

	[menuItem setKeyEquivalentModifierMask:mask];
	[menuItem setTarget:aTarget];

	return menuItem;
}

@end

NS_ASSUME_NONNULL_END
