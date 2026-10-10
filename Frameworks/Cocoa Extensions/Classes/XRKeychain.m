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

#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

@implementation XRKeychain

/* The data protection keychain doesn't ask before an app with another
 signature reads an item (Textual 8 is signed by another team than Textual 7)
 and keeps items available after the first unlock, for connecting at login.
 It needs a signature with an application identifier, which only builds with a
 provisioning profile have; elsewhere the file-based keychain is used. */
+ (BOOL)dataProtectionKeychainAvailable
{
	static BOOL available = NO;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSDictionary *query = @{
			(id)kSecClass : (id)kSecClassGenericPassword,
			(id)kSecAttrService : @"XRKeychain data protection keychain check",
			(id)kSecUseDataProtectionKeychain : (id)kCFBooleanTrue
		};

		/* Reads of a missing item answer errSecItemNotFound either way; deleting
		 one (it never exists) reports the missing entitlement */
		available = (SecItemDelete((__bridge CFDictionaryRef)query) != errSecMissingEntitlement);
	});

	return available;
}

+ (NSMutableDictionary *)searchDictionary:(NSString *)itemName
							 withItemKind:(NSString *)itemKind
							  forUsername:(nullable NSString *)username
							  serviceName:(NSString *)service
{
	return [self searchDictionary:itemName
					 withItemKind:itemKind
					  forUsername:username
					  serviceName:service
				  legacyKeychain:NO];
}

+ (NSMutableDictionary *)searchDictionary:(NSString *)itemName
							 withItemKind:(NSString *)itemKind
							  forUsername:(nullable NSString *)username
							  serviceName:(NSString *)service
						   legacyKeychain:(BOOL)legacyKeychain
{
	NSMutableDictionary *searchDictionary = [NSMutableDictionary dictionary];

	if ([itemKind isEqualToString:@"internet password"]) {
		searchDictionary[(id)kSecClass] = (id)kSecClassInternetPassword;

		searchDictionary[(id)kSecAttrServer] = service;
	} else {
		searchDictionary[(id)kSecClass] = (id)kSecClassGenericPassword;

		searchDictionary[(id)kSecAttrService] = service;
	}

	/* Not the label: it isn't part of what makes an item unique, so an item
	 saved under another label would not be found, and adding a new one then
	 fails as a duplicate. The label is only set when saving. */
	searchDictionary[(id)kSecAttrDescription] = itemKind;

	/* Without an account, a search matches items with any account: an empty
	 one only matches items saved without one */
	searchDictionary[(id)kSecAttrAccount] = ((username.length > 0) ? username : @"");

	if (legacyKeychain == NO && [self dataProtectionKeychainAvailable]) {
		searchDictionary[(id)kSecUseDataProtectionKeychain] = (id)kCFBooleanTrue;
	}

	return searchDictionary;
}

#pragma mark -

+ (BOOL)deleteKeychainItem:(NSString *)itemName
			  withItemKind:(NSString *)itemKind
			   forUsername:(nullable NSString *)username
			   serviceName:(NSString *)service
{
	return [self deleteKeychainItem:itemName
					   withItemKind:itemKind
						forUsername:username
						serviceName:service
						  fromCloud:NO];
}

+ (BOOL)deleteKeychainItem:(NSString *)itemName
			  withItemKind:(NSString *)itemKind
			   forUsername:(nullable NSString *)username
			   serviceName:(NSString *)service
				 fromCloud:(BOOL)deleteFromCloud
{
	NSParameterAssert(itemName != nil);
	NSParameterAssert(itemKind != nil);
	NSParameterAssert(service != nil);

	NSMutableDictionary *dictionary = [self searchDictionary:itemName
												withItemKind:itemKind
												 forUsername:username
												 serviceName:service];
	
	if (deleteFromCloud) {
		dictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}
	
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)dictionary);

	/* Reads fall back to the file-based keychain, so its copy would come back */
	if (deleteFromCloud == NO && [self dataProtectionKeychainAvailable]) {
		NSDictionary *legacyDictionary = [self searchDictionary:itemName
												   withItemKind:itemKind
													forUsername:username
													serviceName:service
												 legacyKeychain:YES];

		OSStatus legacyStatus = SecItemDelete((__bridge CFDictionaryRef)legacyDictionary);

		if (status == errSecSuccess || status == errSecItemNotFound) {
			status = legacyStatus;
		}
	}

	return (status == errSecSuccess || status == errSecItemNotFound);
}

+ (BOOL)modifyOrAddKeychainItem:(NSString *)itemName
				   withItemKind:(NSString *)itemKind
					forUsername:(nullable NSString *)username
				withNewPassword:(nullable NSString *)newPassword
					serviceName:(NSString *)service
{
	return [self modifyOrAddKeychainItem:itemName
							withItemKind:itemKind
							 forUsername:username
						 withNewPassword:newPassword
							 serviceName:service
								forCloud:NO];
}

+ (BOOL)modifyOrAddKeychainItem:(NSString *)itemName
				   withItemKind:(NSString *)itemKind
					forUsername:(nullable NSString *)username
				withNewPassword:(nullable NSString *)newPassword
					serviceName:(NSString *)service
					   forCloud:(BOOL)modifyForCloud
{
	OSStatus status = [self modifyOrAddKeychainItemReturningStatus:itemName
													  withItemKind:itemKind
													   forUsername:username
												   withNewPassword:newPassword
													   serviceName:service
														  forCloud:modifyForCloud];

	return (status == errSecSuccess);
}

+ (OSStatus)modifyOrAddKeychainItemReturningStatus:(NSString *)itemName
									  withItemKind:(NSString *)itemKind
									   forUsername:(nullable NSString *)username
								   withNewPassword:(nullable NSString *)newPassword
									   serviceName:(NSString *)service
										  forCloud:(BOOL)modifyForCloud
{
	NSParameterAssert(itemName != nil);
	NSParameterAssert(itemKind != nil);
	NSParameterAssert(service != nil);

	NSMutableDictionary *oldDictionary = [self searchDictionary:itemName
												   withItemKind:itemKind
												    forUsername:username
													serviceName:service];

	if (modifyForCloud) {
		oldDictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}

	/* The label is refreshed on every update, so items saved under another one are adopted */
	NSMutableDictionary *newDictionary = [NSMutableDictionary dictionary];

	newDictionary[(id)kSecAttrLabel] = itemName;

	if (newPassword) {
		NSData *encodedPassword = [newPassword dataUsingEncoding:NSUTF8StringEncoding];

		newDictionary[(id)kSecValueData] = encodedPassword;
	}

	if (modifyForCloud) {
		newDictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}

	OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)oldDictionary,
									(__bridge CFDictionaryRef)newDictionary);

	if (status != errSecItemNotFound) {
		return status;
	}

	if (newPassword.length == 0) {
		return errSecSuccess; // Nothing to save
	}

	status = [self _addKeychainItem:itemName
					   withItemKind:itemKind
						forUsername:username
					   withPassword:newPassword
						serviceName:service
						  ontoCloud:modifyForCloud];

	/* An item for this service and account exists with another kind (description):
	 the Keychain still treats it as the same item, so update that one */
	if (status == errSecDuplicateItem) {
		[oldDictionary removeObjectForKey:(id)kSecAttrDescription];

		newDictionary[(id)kSecAttrDescription] = itemKind;

		status = SecItemUpdate((__bridge CFDictionaryRef)oldDictionary,
							   (__bridge CFDictionaryRef)newDictionary);
	}

	return status;
}

+ (BOOL)addKeychainItem:(NSString *)itemName
		   withItemKind:(NSString *)itemKind
			forUsername:(nullable NSString *)username
		   withPassword:(NSString *)password
			serviceName:(NSString *)service
{
	return [self addKeychainItem:itemName
					withItemKind:itemKind
					 forUsername:username
					withPassword:password
					 serviceName:service
					   ontoCloud:NO];
}

+ (BOOL)addKeychainItem:(NSString *)itemName
		   withItemKind:(NSString *)itemKind
			forUsername:(nullable NSString *)username
		   withPassword:(NSString *)password
			serviceName:(NSString *)service
			  ontoCloud:(BOOL)addToCloud
{
	NSParameterAssert(itemName != nil);
	NSParameterAssert(itemKind != nil);
	NSParameterAssert(password != nil);
	NSParameterAssert(service != nil);

	OSStatus status = [self _addKeychainItem:itemName
								withItemKind:itemKind
								 forUsername:username
								withPassword:password
								 serviceName:service
								   ontoCloud:addToCloud];

	return (status == errSecSuccess);
}

+ (OSStatus)_addKeychainItem:(NSString *)itemName
				withItemKind:(NSString *)itemKind
				 forUsername:(nullable NSString *)username
				withPassword:(NSString *)password
				 serviceName:(NSString *)service
				   ontoCloud:(BOOL)addToCloud
{
	NSMutableDictionary *dictionary = [self searchDictionary:itemName
												withItemKind:itemKind
												 forUsername:username
												 serviceName:service];

	dictionary[(id)kSecAttrLabel] = itemName;

	if (addToCloud) {
		dictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}

	/* Only the data protection keychain knows this; servers connect at login */
	if (dictionary[(id)kSecUseDataProtectionKeychain] != nil) {
		dictionary[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleAfterFirstUnlock;
	}
	
	NSData *encodedPassword = [password dataUsingEncoding:NSUTF8StringEncoding];

	dictionary[(id)kSecValueData] = encodedPassword;

	return SecItemAdd((__bridge CFDictionaryRef)dictionary, NULL);
}

+ (nullable NSString *)getPasswordFromKeychainItem:(NSString *)itemName
									  withItemKind:(NSString *)itemKind
									   forUsername:(nullable NSString *)username
									   serviceName:(NSString *)service
{
	return [self getPasswordFromKeychainItem:itemName
								withItemKind:itemKind
								 forUsername:username
								 serviceName:service
								   fromCloud:NO
						  returnedStatusCode:NULL];
}

+ (nullable NSString *)getPasswordFromKeychainItem:(NSString *)itemName
									  withItemKind:(NSString *)itemKind
									   forUsername:(nullable NSString *)username
									   serviceName:(NSString *)service
										 fromCloud:(BOOL)searchForOnCloud
								returnedStatusCode:(OSStatus * _Nullable)statusCode
{
	NSParameterAssert(itemName != nil);
	NSParameterAssert(itemKind != nil);
	NSParameterAssert(service != nil);

	NSMutableDictionary *dictionary = [self searchDictionary:itemName
												withItemKind:itemKind
												 forUsername:username
												 serviceName:service];

	if (searchForOnCloud) {
		dictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}

	OSStatus status = errSecSuccess;

	NSData *passwordData = [self passwordDataMatchingDictionary:dictionary status:&status];

	/* Items saved before the data protection keychain could be used (by Textual 7,
	 or a build without a provisioning profile) are copied over on first use. The
	 original stays for the version that saved it. */
	if (status == errSecItemNotFound && searchForOnCloud == NO && [self dataProtectionKeychainAvailable]) {
		NSDictionary *legacyDictionary = [self searchDictionary:itemName
												   withItemKind:itemKind
													forUsername:username
													serviceName:service
												 legacyKeychain:YES];

		passwordData = [self passwordDataMatchingDictionary:legacyDictionary status:&status];

		NSString *password = [NSString stringWithData:passwordData encoding:NSUTF8StringEncoding];

		if (password.length > 0) {
			(void)[self _addKeychainItem:itemName
							withItemKind:itemKind
							 forUsername:username
							withPassword:password
							 serviceName:service
							   ontoCloud:NO];
		}
	}
	
	if ( statusCode) {
		*statusCode = status;
	}

	if (passwordData == nil) {
		return nil;
	} else {
		return [NSString stringWithData:passwordData encoding:NSUTF8StringEncoding];
	}
}

+ (nullable NSData *)passwordDataMatchingDictionary:(NSDictionary *)searchDictionary status:(OSStatus *)status
{
	NSMutableDictionary *dictionary = [searchDictionary mutableCopy];

	dictionary[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;
	dictionary[(id)kSecReturnData] = (id)kCFBooleanTrue;

	CFTypeRef result = NULL;

	*status = SecItemCopyMatching((__bridge CFDictionaryRef)dictionary, &result);

	id resultObject = CFBridgingRelease(result);

	if ([resultObject isKindOfClass:[NSData class]] == NO) {
		return nil;
	}

	return resultObject;
}

@end

NS_ASSUME_NONNULL_END
