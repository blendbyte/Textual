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

#import "IRCPrefixInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCPrefix

- (void)populateDefaultsPostflight
{
	SetVariableIfNil(self->_nickname, @"")
	SetVariableIfNil(self->_hostmask, @"")
}

- (void)populateDuringCopy:(__kindof XRPortablePropertyObject *)newObject mutableCopy:(BOOL)mutableCopy
{
	IRCPrefix *object = (IRCPrefix *)newObject;

	object->_isServer = self->_isServer;
	object->_hostmask = self->_hostmask;
	object->_nickname = self->_nickname;
	object->_username = self->_username;
	object->_address = self->_address;
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [IRCPrefixMutable self];
}

- (BOOL)isEqual:(id)object
{
	if (object == nil) {
		return NO;
	}

	if (object == self) {
		return YES;
	}

	if ([object isKindOfClass:[IRCPrefix class]] == NO) {
		return NO;
	}

	IRCPrefix *objectCast = (IRCPrefix *)object;

	return (self.isServer == objectCast.isServer &&

			((self.nickname == nil && objectCast.nickname == nil) ||
			 [self.nickname isEqualToString:objectCast.nickname]) &&

			((self.username == nil && objectCast.username == nil) ||
			 [self.username isEqualToString:objectCast.username]) &&

			((self.address == nil && objectCast.address == nil) ||
			 [self.address isEqualToString:objectCast.address]) &&

			((self.hostmask == nil && objectCast.hostmask == nil) ||
			 [self.hostmask isEqualToString:objectCast.hostmask]));
}

@end

#pragma mark -

@implementation IRCPrefixMutable

@dynamic isServer;
@dynamic nickname;
@dynamic username;
@dynamic address;
@dynamic hostmask;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyObject *)immutableClass
{
	return [IRCPrefix self];
}

- (void)setIsServer:(BOOL)isServer
{
	if (self->_isServer != isServer) {
		self->_isServer = isServer;
	}
}

- (void)setNickname:(NSString *)nickname
{
	NSParameterAssert(nickname != nil);

	if (self->_nickname != nickname) {
		self->_nickname = [nickname copy];
	}
}

- (void)setUsername:(nullable NSString *)username
{
	if (self->_username != username) {
		self->_username = [username copy];
	}
}

- (void)setAddress:(nullable NSString *)address
{
	if (self->_address != address) {
		self->_address = [address copy];
	}
}

- (void)setHostmask:(NSString *)hostmask
{
	NSParameterAssert(hostmask != nil);

	if (self->_hostmask != hostmask) {
		self->_hostmask = [hostmask copy];
	}
}

@end

NS_ASSUME_NONNULL_END
