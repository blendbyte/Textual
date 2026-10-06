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

+ (NSMutableDictionary *)searchDictionary:(NSString *)itemName
							 withItemKind:(NSString *)itemKind
							  forUsername:(nullable NSString *)username
							  serviceName:(NSString *)service
{
	NSMutableDictionary *searchDictionary = [NSMutableDictionary dictionary];

	if ([itemKind isEqualToString:@"internet password"]) {
		searchDictionary[(id)kSecClass] = (id)kSecClassInternetPassword;
	} else {
		searchDictionary[(id)kSecClass] = (id)kSecClassGenericPassword;
	}

	searchDictionary[(id)kSecAttrLabel] = itemName;
	searchDictionary[(id)kSecAttrDescription] = itemKind;

	if (username.length > 0) {
		searchDictionary[(id)kSecAttrAccount] = username;
	}

	searchDictionary[(id)kSecAttrService] = service;

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

	return (status == errSecSuccess);
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
	
	NSMutableDictionary *newDictionary = [NSMutableDictionary dictionary];

	if (newPassword) {
		NSData *encodedPassword = [newPassword dataUsingEncoding:NSUTF8StringEncoding];

		newDictionary[(id)kSecValueData] = encodedPassword;
	}

	if (modifyForCloud) {
		newDictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}

	OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)oldDictionary,
									(__bridge CFDictionaryRef)newDictionary);

	if (status == errSecItemNotFound) {
		if (newPassword && newPassword.length > 0) {
			return [self addKeychainItem:itemName
							withItemKind:itemKind
							 forUsername:username
							withPassword:newPassword
							 serviceName:service];
		}
	}

	return (status == errSecSuccess);
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

	NSMutableDictionary *dictionary = [self searchDictionary:itemName
												withItemKind:itemKind
												 forUsername:username
												 serviceName:service];

	if (addToCloud) {
		dictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}
	
	NSData *encodedPassword = [password dataUsingEncoding:NSUTF8StringEncoding];

	dictionary[(id)kSecValueData] = encodedPassword;

	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)dictionary, NULL);

	return (status == errSecSuccess);
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

	dictionary[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;
	dictionary[(id)kSecReturnData] = (id)kCFBooleanTrue;

	if (searchForOnCloud) {
		dictionary[(id)kSecAttrSynchronizable] = (id)kCFBooleanTrue;
	}
	
	CFDataRef result = nil;
	
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)dictionary, (CFTypeRef *)&result);
	
	if ( statusCode) {
		*statusCode = status;
	}
	
	NSData *passwordData = (__bridge_transfer NSData *)result;

	if (passwordData == nil) {
		return nil;
	} else {
		return [NSString stringWithData:passwordData encoding:NSUTF8StringEncoding];
	}
}

@end

NS_ASSUME_NONNULL_END
