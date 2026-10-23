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

#import "TLOKeychainPrivate.h"
#import "NSObjectHelperPrivate.h"
#import "IRC.h"
#import "IRCConnectionConfig.h"
#import "IRCServerInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IRCServer

- (instancetype)init
{
	return [super initWithDictionary:@{}];
}

- (void)initializedClassHealthCheck
{
	if (self.initializedAsCopy) {
		return;
	}

	/* Health checks are disabled because Server Properties might
	write an empty server address to the class then perform a
	copy on the object which would throw an exception. */
	/* TODO: Modify Server Properties to be more friendly. */

#if 0
	if (self.mutable) {
		return;
	}

	NSParameterAssert(self->_serverAddress.length > 0);
	NSParameterAssert(self->_serverPort > 0 && self->_serverPort <= TXMaximumTCPPort);
#endif
}

- (void)populateDefaultsPreflight
{
	if (self.initializedAsCopy) {
		return;
	}

	self->_defaults = @{
		@"serverPort" : @(IRCConnectionDefaultServerPort)
	};
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy) {
		return;
	}

	SetVariableIfNil(self->_serverAddress, @"")

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])
}

- (void)populateDictionaryValues:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	NSMutableDictionary<NSString *, id> *defaultsMutable = [self->_defaults mutableCopy];

	[defaultsMutable addEntriesFromDictionary:dic];

	[defaultsMutable assignBoolTo:&self->_prefersSecuredConnection forKey:@"prefersSecuredConnection"];

	[defaultsMutable assignStringTo:&self->_serverAddress forKey:@"serverAddress"];
	[defaultsMutable assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];

	[defaultsMutable assignUnsignedShortTo:&self->_serverPort forKey:@"serverPort"];
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	[dic setBool:self.prefersSecuredConnection forKey:@"prefersSecuredConnection"];

	[dic maybeSetObject:self.serverAddress forKey:@"serverAddress"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	[dic setUnsignedShort:self.serverPort forKey:@"serverPort"];

	return [dic copy];
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCServer *config = [self allocForCopyAsMutable:mutableCopy];

	config->_defaults = self->_defaults;

	config->_serverPassword = self->_serverPassword;

	config->_destroyKeychainItemsDuringDealloc = self->_destroyKeychainItemsDuringDealloc;

	config = [config initWithDictionary:self.dictionaryValueForCopy];

	/* After initialization (see IRCChannelConfig, R2.2): the password comes
	 along to be saved under the new identifier */
	if (uniquing) {
		config->_serverPassword = self.serverPassword;

		config->_destroyKeychainItemsDuringDealloc = NO;

		config->_uniqueIdentifier = [NSString stringWithUUID];
	}

	return config;
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [IRCServerMutable self];
}

- (void)dealloc
{
	if (self.destroyKeychainItemsDuringDealloc) {
		[self destroyServerPasswordKeychainItem];
	}
}

#pragma mark -
#pragma mark Keychain Management

- (nullable NSString *)serverPassword
{
	if (self->_serverPassword) {
		return self->_serverPassword;
	}

	return self.serverPasswordFromKeychain;
}

- (nullable NSString *)serverPasswordFromKeychain
{
	return [TLOKeychain passwordOfKind:TLOKeychainItemKindServerPassword forIdentifier:self.uniqueIdentifier];
}

- (void)writeServerPasswordToKeychain
{
	if (self->_serverPassword == nil) {
		return;
	}

	/* Kept in memory if the Keychain refuses it */
	if ([TLOKeychain setPassword:self->_serverPassword ofKind:TLOKeychainItemKindServerPassword forIdentifier:self.uniqueIdentifier]) {
		self->_serverPassword = nil;
	}
}

- (void)destroyServerPasswordKeychainItem
{
	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindServerPassword forIdentifier:self.uniqueIdentifier];

	self->_serverPassword = nil;
}

@end

#pragma mark -

@implementation IRCServerMutable

@dynamic prefersSecuredConnection;
@dynamic serverAddress;
@dynamic serverPassword;
@dynamic serverPort;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [IRCServer self];
}

- (void)setPrefersSecuredConnection:(BOOL)prefersSecuredConnection
{
	if (self->_prefersSecuredConnection != prefersSecuredConnection) {
		self->_prefersSecuredConnection = prefersSecuredConnection;
	}
}

- (void)setServerAddress:(NSString *)serverAddress
{
	NSParameterAssert(serverAddress != nil);

	if (self->_serverAddress != serverAddress) {
		self->_serverAddress = [serverAddress copy];
	}
}

- (void)setServerPassword:(nullable NSString *)serverPassword
{
	if (self->_serverPassword != serverPassword) {
		self->_serverPassword = [serverPassword copy];
	}
}

- (void)setServerPort:(uint16_t)serverPort
{
	if (self->_serverPort != serverPort) {
		self->_serverPort = serverPort;
	}
}

@end

NS_ASSUME_NONNULL_END
