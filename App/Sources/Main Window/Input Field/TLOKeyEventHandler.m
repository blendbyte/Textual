/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import <objc/objc-runtime.h>

#import "NSObjectHelperPrivate.h"
#import "TLOKeyEventHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface TLOKeyEventHandler ()
@property (nonatomic, unsafe_unretained) id target;
@property (nonatomic, strong) NSMutableDictionary *codeHandlerMap;
@property (nonatomic, strong) NSMutableDictionary *characterHandlerMap;
@end

@implementation TLOKeyEventHandler

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithTarget:(id)target
{
	if ((self = [super init])) {
		[self setKeyHandlerTarget:target];

		[self prepareInitialState];
	}

	return self;
}

- (void)prepareInitialState
{
	self.characterHandlerMap = [NSMutableDictionary new];

	self.codeHandlerMap = [NSMutableDictionary new];
}

- (void)dealloc
{
	self.target = nil;
}

- (void)setKeyHandlerTarget:(id)target
{
	NSParameterAssert(target != nil);

	self.target = target;
}

- (void)registerSelector:(SEL)selector key:(NSUInteger)keyCode modifiers:(NSUInteger)modifiers
{
	NSParameterAssert(selector != NULL);
	NSParameterAssert(keyCode != 0);

	NSNumber *modifierKeys = @(modifiers);

	NSMutableDictionary *map = self.codeHandlerMap[modifierKeys];

	if (map == nil) {
		map = [NSMutableDictionary dictionary];

		self.codeHandlerMap[modifierKeys] = map;
	}

	map[@(keyCode)] = NSStringFromSelector(selector);
}

- (void)registerSelector:(SEL)selector character:(UniChar)character modifiers:(NSUInteger)modifiers
{
	NSParameterAssert(selector != NULL);
	NSParameterAssert(character != 0);

	NSNumber *modifierKeys = @(modifiers);

	NSMutableDictionary *map = self.characterHandlerMap[modifierKeys];

	if (map == nil) {
		map = [NSMutableDictionary dictionary];

		self.characterHandlerMap[modifierKeys] = map;
	}

	map[@(character)] = NSStringFromSelector(selector);
}

- (void)registerSelector:(SEL)selector characters:(NSRange)characterRange modifiers:(NSUInteger)modifiers
{
	NSParameterAssert(selector != NULL);

	NSNumber *modifierKeys = @(modifiers);

	NSMutableDictionary *map = self.characterHandlerMap[modifierKeys];

	if (map == nil) {
		map = [NSMutableDictionary dictionary];

		self.characterHandlerMap[modifierKeys] = map;
	}

	NSUInteger from = characterRange.location;

	NSUInteger to = NSMaxRange(characterRange);

	for (NSInteger i = from; i < to; ++i) {
		map[@(i)] = NSStringFromSelector(selector);
	}
}

- (BOOL)processKeyEvent:(NSEvent *)e
{
	NSParameterAssert(e != nil);

	NSTextInputContext *inputContext = [NSTextInputContext currentInputContext];

	if (inputContext && [inputContext.client markedRange].length > 0) {
		return NO;
	}

	NSUInteger modifiers = (e.modifierFlags & (NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand));

	NSNumber *modifierKeys = @(modifiers);

	NSMutableDictionary *codeMap = self.codeHandlerMap[modifierKeys];

	if (codeMap) {
		NSString *selectorName = codeMap[@(e.keyCode)];

		if (selectorName) {
			SEL selector = NSSelectorFromString(selectorName);

			NSMethodSignature *signature = [self.target methodSignatureForSelector:selector];

			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setTarget:self.target];
			[invocation setSelector:selector];

			[invocation setArgument:&e atIndex:2];

			[invocation invoke];

			return YES;
		}
	}

	NSMutableDictionary *characterMap = self.characterHandlerMap[modifierKeys];

	if (characterMap) {
		NSString *characterString = e.charactersIgnoringModifiers.lowercaseString;

		if (characterString.length > 0) {
			NSString *selectorName = characterMap[@([characterString characterAtIndex:0])];

			if (selectorName) {
				SEL selector = NSSelectorFromString(selectorName);

				NSMethodSignature *signature = [self.target methodSignatureForSelector:selector];

				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

				[invocation setTarget:self.target];
				[invocation setSelector:selector];

				[invocation setArgument:&e atIndex:2];

				[invocation invoke];

				return YES;
			}
		}
	}

	return NO;
}

@end

NS_ASSUME_NONNULL_END
