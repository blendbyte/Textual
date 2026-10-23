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

@interface NSMenu (CSMenuHelper)
@end

@interface NSMenuItem ()
@property (nonatomic, copy, nullable) NSString *userInfo;
@end

@interface NSMenuItem (CSMenuItemHelper)
@property (nonatomic, copy, nullable) NSString *archivedKeyEquivalent;
@property (nonatomic, assign) NSEventModifierFlags archivedKeyEquivalentModifierMask;

- (void)archiveKeyboardShortcut; // archive keyboard shortcut
- (void)archiveKeyboardShortcutAndUnset; // archive keyboard shortcut and unset current
- (void)restoreKeyboardShortcut; // restore archived keyboard shortcut (if it's archived)
- (void)unsetKeyboardShortcut; // unset current keyboard shortcut
- (void)unsetArchivedKeyboardShortcut; // unset archived keyboard shortcut

@property (readonly, getter=isKeyboardShortcutArchived) BOOL keyboardShortcutArchived;

- (void)setUserInfo:(nullable NSString *)userInfo recursively:(BOOL)recursively; // Setting recursively to YES will apply userInfo to this menu item as well as all items within its submenu if it has one

+ (instancetype)menuItemWithTitle:(NSString *)aString
				 target:(id)aTarget
				 action:(SEL)aSelector;

+ (instancetype)menuItemWithTitle:(NSString *)aString
				 target:(id)aTarget
				 action:(SEL)aSelector
		  keyEquivalent:(NSString *)charCode
	  keyEquivalentMask:(NSUInteger)mask;
@end

NS_ASSUME_NONNULL_END
