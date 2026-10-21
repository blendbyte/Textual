/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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
#import "NSStringHelper.h"
#import "TLOKeychainPrivate.h"
#import "IRC.h"
#import "IRCConnectionConfig.h"
#import "IRCServerPrivate.h"
#import "IRCBouncerAccountPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCBouncerAccount ()
{
@protected
	NSString *_name;
	IRCBouncerKind _kind;
	NSString *_serverAddress;
	uint16_t _serverPort;
	BOOL _prefersSecuredConnection;
	NSString *_username;
	NSString *_password;
	NSData *_identityClientSideCertificate;
	BOOL _checksForNetworkChanges;
	NSArray<NSString *> *_ignoredNetworks;

@private
	NSString *_uniqueIdentifier;
	NSDictionary *_defaults;
}
@end

@implementation IRCBouncerAccount

- (instancetype)init
{
	return [super initWithDictionary:@{}];
}

- (void)populateDefaultsPreflight
{
	if (self.initializedAsCopy) {
		return;
	}

	self->_defaults = @{
		@"checksForNetworkChanges" : @(YES),
		@"prefersSecuredConnection" : @(YES),
		@"serverPort" : @(IRCConnectionDefaultSecureServerPort)
	};
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy) {
		return;
	}

	SetVariableIfNil(self->_serverAddress, @"")
	SetVariableIfNil(self->_username, @"")
	SetVariableIfNil(self->_ignoredNetworks, @[])

	SetVariableIfNil(self->_uniqueIdentifier, [NSString stringWithUUID])
}

- (void)populateDictionaryValues:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(dic != nil);

	NSMutableDictionary<NSString *, id> *defaultsMutable = [self->_defaults mutableCopy];

	[defaultsMutable addEntriesFromDictionary:dic];

	[defaultsMutable assignArrayTo:&self->_ignoredNetworks forKey:@"ignoredNetworks"];

	[defaultsMutable assignBoolTo:&self->_checksForNetworkChanges forKey:@"checksForNetworkChanges"];
	[defaultsMutable assignBoolTo:&self->_prefersSecuredConnection forKey:@"prefersSecuredConnection"];

	[defaultsMutable assignObjectTo:&self->_identityClientSideCertificate forKey:@"identityClientSideCertificate"];

	[defaultsMutable assignStringTo:&self->_name forKey:@"name"];
	[defaultsMutable assignStringTo:&self->_serverAddress forKey:@"serverAddress"];
	[defaultsMutable assignStringTo:&self->_uniqueIdentifier forKey:@"uniqueIdentifier"];
	[defaultsMutable assignStringTo:&self->_username forKey:@"username"];

	[defaultsMutable assignUnsignedIntegerTo:&self->_kind forKey:@"kind"];

	[defaultsMutable assignUnsignedShortTo:&self->_serverPort forKey:@"serverPort"];

	/* Only the strings: a damaged list loses its odd entries, not the account */
	NSMutableArray<NSString *> *ignoredNetworks = [NSMutableArray array];

	for (id network in self->_ignoredNetworks) {
		if ([network isKindOfClass:[NSString class]]) {
			[ignoredNetworks addObject:network];
		}
	}

	self->_ignoredNetworks = [ignoredNetworks copy];

	if (self->_kind > IRCBouncerKindSoju) {
		self->_kind = IRCBouncerKindUnknown;
	}
}

- (NSDictionary<NSString *, id> *)dictionaryValueForTarget:(XRPortablePropertyDictTarget)target
{
	NSMutableDictionary<NSString *, id> *dic = [NSMutableDictionary dictionary];

	[dic setBool:self.checksForNetworkChanges forKey:@"checksForNetworkChanges"];
	[dic setBool:self.prefersSecuredConnection forKey:@"prefersSecuredConnection"];

	[dic maybeSetObject:self.identityClientSideCertificate forKey:@"identityClientSideCertificate"];
	[dic maybeSetObject:self.ignoredNetworks forKey:@"ignoredNetworks"];
	[dic maybeSetObject:self.name forKey:@"name"];
	[dic maybeSetObject:self.serverAddress forKey:@"serverAddress"];
	[dic maybeSetObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];
	[dic maybeSetObject:self.username forKey:@"username"];

	[dic setUnsignedInteger:self.kind forKey:@"kind"];

	[dic setUnsignedShort:self.serverPort forKey:@"serverPort"];

	return [dic copy];
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	IRCBouncerAccount *account = [self allocForCopyAsMutable:mutableCopy];

	account->_defaults = self->_defaults;

	account->_password = self->_password;

	account = [account initWithDictionary:self.dictionaryValueForCopy];

	/* After initialization: the password comes along to be saved under the new identifier */
	if (uniquing) {
		account->_password = self.password;

		account->_uniqueIdentifier = [NSString stringWithUUID];
	}

	return account;
}

- (__kindof XRPortablePropertyDict *)mutableClass
{
	return [IRCBouncerAccountMutable self];
}

- (NSString *)displayName
{
	NSString *name = self.name;

	if (name.length > 0) {
		return name;
	}

	return self.serverAddress;
}

- (IRCServer *)serverForNetwork:(nullable NSString *)network
{
	IRCServerMutable *server = [IRCServerMutable new];

	server.serverAddress = self.serverAddress;
	server.serverPort = self.serverPort;
	server.prefersSecuredConnection = self.prefersSecuredConnection;

	NSString *password = self.password;

	/* In memory only: the account's Keychain item is the one kept */
	if (self.kind == IRCBouncerKindZNC && password.length > 0) {
		NSString *login = self.username;

		if (network.length > 0) {
			login = [NSString stringWithFormat:@"%@/%@", login, network];
		}

		server.serverPassword = [NSString stringWithFormat:@"%@:%@", login, password];
	}

	return [server copy];
}

#pragma mark -
#pragma mark Keychain

- (nullable NSString *)password
{
	if (self->_password) {
		return ((self->_password.length > 0) ? self->_password : nil);
	}

	return [TLOKeychain passwordOfKind:TLOKeychainItemKindBouncerPassword forIdentifier:self.uniqueIdentifier];
}

- (void)writePasswordToKeychain
{
	if (self->_password == nil) {
		return;
	}

	/* An empty password removes it */
	if (self->_password.length == 0) {
		[self destroyPasswordKeychainItem];

		return;
	}

	/* Kept in memory if the Keychain refuses it */
	if ([TLOKeychain setPassword:self->_password ofKind:TLOKeychainItemKindBouncerPassword forIdentifier:self.uniqueIdentifier]) {
		self->_password = nil;
	}
}

- (void)destroyPasswordKeychainItem
{
	[TLOKeychain deletePasswordOfKind:TLOKeychainItemKindBouncerPassword forIdentifier:self.uniqueIdentifier];

	self->_password = nil;
}

@end

#pragma mark -

@implementation IRCBouncerAccountMutable

@dynamic name;
@dynamic kind;
@dynamic serverAddress;
@dynamic serverPort;
@dynamic prefersSecuredConnection;
@dynamic username;
@dynamic password;
@dynamic identityClientSideCertificate;
@dynamic checksForNetworkChanges;
@dynamic ignoredNetworks;

+ (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [IRCBouncerAccount self];
}

- (void)setName:(nullable NSString *)name
{
	if (self->_name != name) {
		self->_name = [name copy];
	}
}

- (void)setKind:(IRCBouncerKind)kind
{
	self->_kind = kind;
}

- (void)setServerAddress:(NSString *)serverAddress
{
	NSParameterAssert(serverAddress != nil);

	if (self->_serverAddress != serverAddress) {
		self->_serverAddress = [serverAddress copy];
	}
}

- (void)setServerPort:(uint16_t)serverPort
{
	self->_serverPort = serverPort;
}

- (void)setPrefersSecuredConnection:(BOOL)prefersSecuredConnection
{
	self->_prefersSecuredConnection = prefersSecuredConnection;
}

- (void)setUsername:(NSString *)username
{
	NSParameterAssert(username != nil);

	if (self->_username != username) {
		self->_username = [username copy];
	}
}

- (void)setPassword:(nullable NSString *)password
{
	if (self->_password != password) {
		self->_password = [password copy];
	}
}

- (void)setIdentityClientSideCertificate:(nullable NSData *)identityClientSideCertificate
{
	if (self->_identityClientSideCertificate != identityClientSideCertificate) {
		self->_identityClientSideCertificate = [identityClientSideCertificate copy];
	}
}

- (void)setChecksForNetworkChanges:(BOOL)checksForNetworkChanges
{
	self->_checksForNetworkChanges = checksForNetworkChanges;
}

- (void)setIgnoredNetworks:(NSArray<NSString *> *)ignoredNetworks
{
	NSParameterAssert(ignoredNetworks != nil);

	if (self->_ignoredNetworks != ignoredNetworks) {
		self->_ignoredNetworks = [ignoredNetworks copy];
	}
}

@end

#pragma mark -

@implementation IRCBouncerNetwork

- (instancetype)initWithIdentifier:(NSString *)networkIdentifier attributes:(NSDictionary<NSString *, NSString *> *)attributes
{
	NSParameterAssert(networkIdentifier != nil);
	NSParameterAssert(attributes != nil);

	if ((self = [super init])) {
		self->_networkIdentifier = [networkIdentifier copy];
		self->_attributes = [attributes copy];

		return self;
	}

	return nil;
}

- (NSString *)name
{
	NSString *name = self.attributes[@"name"];

	if (name.length == 0) {
		name = self.attributes[@"host"];
	}

	if (name.length == 0) {
		name = self.networkIdentifier;
	}

	return name;
}

- (nullable NSString *)state
{
	return self.attributes[@"state"];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@ (%@)", self.networkIdentifier, self.name, self.state];
}

@end

#pragma mark -

@interface IRCBouncerNetworkList ()
@property (nonatomic, strong) NSMutableArray<IRCBouncerNetwork *> *networksMutable;
@end

@implementation IRCBouncerNetworkList

- (instancetype)init
{
	if ((self = [super init])) {
		self.networksMutable = [NSMutableArray array];

		return self;
	}

	return nil;
}

- (NSArray<IRCBouncerNetwork *> *)networks
{
	return [self.networksMutable copy];
}

- (NSUInteger)indexOfNetworkWithIdentifier:(NSString *)networkIdentifier
{
	return [self.networksMutable indexOfObjectPassingTest:^BOOL(IRCBouncerNetwork *network, NSUInteger index, BOOL *stop) {
		return [network.networkIdentifier isEqualToString:networkIdentifier];
	}];
}

- (nullable IRCBouncerNetwork *)networkWithIdentifier:(NSString *)networkIdentifier
{
	NSParameterAssert(networkIdentifier != nil);

	NSUInteger index = [self indexOfNetworkWithIdentifier:networkIdentifier];

	if (index == NSNotFound) {
		return nil;
	}

	return self.networksMutable[index];
}

- (IRCBouncerNetworkChange)updateNetwork:(NSString *)networkIdentifier attributes:(NSString *)attributes
{
	NSParameterAssert(networkIdentifier != nil);
	NSParameterAssert(attributes != nil);

	if (networkIdentifier.length == 0) {
		return IRCBouncerNetworkChangeNone;
	}

	NSUInteger index = [self indexOfNetworkWithIdentifier:networkIdentifier];

	if ([attributes isEqualToString:@"*"]) {
		if (index == NSNotFound) {
			return IRCBouncerNetworkChangeNone;
		}

		[self.networksMutable removeObjectAtIndex:index];

		return IRCBouncerNetworkChangeRemoved;
	}

	NSMutableDictionary *merged = [NSMutableDictionary dictionary];

	if (index != NSNotFound) {
		[merged addEntriesFromDictionary:self.networksMutable[index].attributes];
	}

	[[self.class attributesFromString:attributes] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		if (value.length == 0) {
			[merged removeObjectForKey:key];
		} else {
			merged[key] = value;
		}
	}];

	IRCBouncerNetwork *network = [[IRCBouncerNetwork alloc] initWithIdentifier:networkIdentifier attributes:merged];

	if (index == NSNotFound) {
		[self.networksMutable addObject:network];

		return IRCBouncerNetworkChangeAdded;
	}

	self.networksMutable[index] = network;

	return IRCBouncerNetworkChangeChanged;
}

+ (NSDictionary<NSString *, NSString *> *)attributesFromString:(NSString *)attributes
{
	NSParameterAssert(attributes != nil);

	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	/* An escaped ";" is "\:", so splitting at ";" is safe */
	for (NSString *attribute in [attributes componentsSeparatedByString:@";"]) {
		NSRange equalSign = [attribute rangeOfString:@"="];

		NSString *key = attribute;
		NSString *value = @"";

		if (equalSign.location != NSNotFound) {
			key = [attribute substringToIndex:equalSign.location];
			value = [attribute substringFromIndex:NSMaxRange(equalSign)].decodedMessageTagString;
		}

		if (key.length == 0) {
			continue;
		}

		dictionary[key] = value;
	}

	return [dictionary copy];
}

@end

NS_ASSUME_NONNULL_END
