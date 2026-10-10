/* *********************************************************************
 *
 *           Copyright (c) 2024 Codeux Software, LLC
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

#import <XCTest/XCTest.h>

#import <CocoaExtensions/NSFileManagerHelper.h>

#import <XCTest/XCTest.h>

#import <CocoaExtensions/XRKeychain.h>

@interface CSKeychainTests : XCTestCase
@end

@implementation CSKeychainTests

/* Passwords were silently lost when an item already existed for the service
 under another label (older Textual, a localised label): the update found
 nothing and the add failed as a duplicate. */
- (void)testItemSavedUnderAnotherLabelIsUpdated
{
	NSString *service = [NSString stringWithFormat:@"textual.test.%@", [NSUUID UUID].UUIDString];

	NSDictionary *oldItem = @{
		(id)kSecClass : (id)kSecClassGenericPassword,
		(id)kSecAttrService : service,
		(id)kSecAttrLabel : @"Textual (NickServ, older label)",
		(id)kSecAttrDescription : @"application password",
		(id)kSecValueData : [@"old" dataUsingEncoding:NSUTF8StringEncoding]
	};

	OSStatus setupStatus = SecItemAdd((__bridge CFDictionaryRef)oldItem, NULL);

	if (setupStatus != errSecSuccess) {
		XCTSkip(@"No usable Keychain here (%d)", (int)setupStatus);
	}

	OSStatus status = [XRKeychain modifyOrAddKeychainItemReturningStatus:@"Textual (NickServ)"
															 withItemKind:@"application password"
															  forUsername:nil
														  withNewPassword:@"new"
															  serviceName:service
																 forCloud:NO];

	XCTAssertEqual(status, errSecSuccess);

	XCTAssertEqualObjects([XRKeychain getPasswordFromKeychainItem:@"Textual (NickServ)"
													 withItemKind:@"application password"
													  forUsername:nil
													  serviceName:service], @"new");

	/* Still one item, now under the current label */
	NSDictionary *query = @{
		(id)kSecClass : (id)kSecClassGenericPassword,
		(id)kSecAttrService : service,
		(id)kSecMatchLimit : (id)kSecMatchLimitAll,
		(id)kSecReturnAttributes : @YES
	};

	CFTypeRef items = NULL;

	XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)query, &items), errSecSuccess);

	NSArray *itemList = CFBridgingRelease(items);

	XCTAssertEqual(itemList.count, 1);
	XCTAssertEqualObjects(itemList.firstObject[(id)kSecAttrLabel], @"Textual (NickServ)");

	[XRKeychain deleteKeychainItem:@"Textual (NickServ)" withItemKind:@"application password" forUsername:nil serviceName:service];
}

/* Without an account, deleting matched every item for the service, whatever
 its account. Deleting what is already gone counts as done. */
- (void)testDeletingItemWithoutAccountKeepsOtherAccounts
{
	NSString *service = [NSString stringWithFormat:@"textual.test.%@", [NSUUID UUID].UUIDString];

	if ([XRKeychain addKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:@"someone" withPassword:@"theirs" serviceName:service] == NO) {
		XCTSkip(@"No usable Keychain here");
	}

	XCTAssertTrue([XRKeychain addKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:nil withPassword:@"ours" serviceName:service]);

	XCTAssertEqualObjects([XRKeychain getPasswordFromKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:nil serviceName:service], @"ours");

	XCTAssertTrue([XRKeychain deleteKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:nil serviceName:service]);

	XCTAssertNil([XRKeychain getPasswordFromKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:nil serviceName:service]);

	XCTAssertEqualObjects([XRKeychain getPasswordFromKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:@"someone" serviceName:service], @"theirs");

	XCTAssertTrue([XRKeychain deleteKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:nil serviceName:service]);

	[XRKeychain deleteKeychainItem:@"Textual (Test)" withItemKind:@"application password" forUsername:@"someone" serviceName:service];
}

@end
