/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import "NSObjectHelperPrivate.h"
#import "IRCClient.h"
#import "IRCISupportInfo.h"
#import "IRCModeInfoInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCModeInfo

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initWithModeSymbol:(NSString *)modeSymbol
{
	return [self initWithModeSymbol:modeSymbol modeIsSet:NO modeParameter:nil];
}

- (instancetype)initWithModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet
{
	return [self initWithModeSymbol:modeSymbol modeIsSet:modeIsSet modeParameter:nil];
}

- (instancetype)initWithModeSymbol:(NSString *)modeSymbol modeIsSet:(BOOL)modeIsSet modeParameter:(nullable NSString *)modeParameter
{
	NSParameterAssert(modeSymbol.length == 1);

	if ((self = [super init])) {
		self->_modeSymbol = [modeSymbol copy];
		self->_modeIsSet = modeIsSet;
		self->_modeParameter = [modeParameter copy];

		return self;
	}

	return nil;
}

- (void)populateDuringCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy
{
	IRCModeInfo *object = (IRCModeInfo *)newObject;

	object->_modeSymbol = self->_modeSymbol;
	object->_modeIsSet = self->_modeIsSet;
	object->_modeParameter = self->_modeParameter;
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [IRCModeInfoMutable self];
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[IRCModeInfo class]] == NO) {
		return NO;
	}

	IRCModeInfo *objectCast = (IRCModeInfo *)object;

	return (self.modeIsSet == objectCast.modeIsSet &&
			
			((self.modeSymbol == nil && objectCast.modeSymbol == nil) ||
			 [self.modeSymbol isEqualToString:objectCast.modeSymbol]) &&

			((self.modeParameter == nil && objectCast.modeParameter == nil) ||
			 [self.modeParameter isEqualToString:objectCast.modeParameter]));
}

- (BOOL)isModeForChangingMemberModeOn:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if (self.modeParameter.length == 0) {
		return NO;
	}

	return [client.supportInfo modeSymbolIsUserPrefix:self.modeSymbol];
}

@end

#pragma mark -

@implementation IRCModeInfoMutable

@dynamic modeIsSet;
@dynamic modeSymbol;
@dynamic modeParameter;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [IRCModeInfo self];
}

- (void)setModeIsSet:(BOOL)modeIsSet
{
	if (self->_modeIsSet != modeIsSet) {
		self->_modeIsSet = modeIsSet;
	}
}

- (void)setModeSymbol:(NSString *)modeSymbol
{
	NSParameterAssert(modeSymbol.length == 1);

	if (self->_modeSymbol != modeSymbol) {
		self->_modeSymbol = [modeSymbol copy];
	}
}

- (void)setModeParameter:(nullable NSString *)modeParameter
{
	if (self->_modeParameter != modeParameter) {
		self->_modeParameter = [modeParameter copy];
	}
}

@end

NS_ASSUME_NONNULL_END
