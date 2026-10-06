/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TLOKeychainPrivate.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const _keychainItemKind = @"application password";

#ifdef DEBUG
static NSNumber * _Nullable _simulatedWriteStatus = nil;
static BOOL _reportsFailures = YES;
#endif

@implementation TLOKeychain

/* Names used since Textual 5; the label is only a display name */
+ (NSString *)labelForKind:(TLOKeychainItemKind)kind
{
	switch (kind) {
		case TLOKeychainItemKindServerPassword:
			return @"Textual (Server Password)";
		case TLOKeychainItemKindNicknamePassword:
			return @"Textual (NickServ)";
		case TLOKeychainItemKindProxyPassword:
			return @"Textual (Proxy Server Password)";
		case TLOKeychainItemKindChannelKey:
			return @"Textual (Channel JOIN Key)";
	}
}

+ (NSString *)serviceForKind:(TLOKeychainItemKind)kind identifier:(NSString *)identifier
{
	NSParameterAssert(identifier != nil);

	NSString *prefix = nil;

	switch (kind) {
		case TLOKeychainItemKindServerPassword:
			prefix = @"textual.server";
			break;
		case TLOKeychainItemKindNicknamePassword:
			prefix = @"textual.nickserv";
			break;
		case TLOKeychainItemKindProxyPassword:
			prefix = @"textual.proxy-server";
			break;
		case TLOKeychainItemKindChannelKey:
			prefix = @"textual.cjoinkey";
			break;
	}

	return [NSString stringWithFormat:@"%@.%@", prefix, identifier];
}

+ (nullable NSString *)passwordOfKind:(TLOKeychainItemKind)kind forIdentifier:(NSString *)identifier
{
	return [XRKeychain getPasswordFromKeychainItem:[self labelForKind:kind]
									  withItemKind:_keychainItemKind
									   forUsername:nil
									   serviceName:[self serviceForKind:kind identifier:identifier]];
}

+ (BOOL)setPassword:(NSString *)password ofKind:(TLOKeychainItemKind)kind forIdentifier:(NSString *)identifier
{
	NSParameterAssert(password != nil);

	OSStatus status = errSecSuccess;

#ifdef DEBUG
	if (_simulatedWriteStatus) {
		status = (OSStatus)_simulatedWriteStatus.intValue;
	} else
#endif
	{
		status = [XRKeychain modifyOrAddKeychainItemReturningStatus:[self labelForKind:kind]
													   withItemKind:_keychainItemKind
														forUsername:nil
													withNewPassword:password
														serviceName:[self serviceForKind:kind identifier:identifier]
														   forCloud:NO];
	}

	if (status == errSecSuccess) {
		return YES;
	}

	LogToConsoleError("Keychain refused the %{public}@ for %{public}@: %{public}d", [self labelForKind:kind], identifier, (int)status);

	[self reportFailureToSaveKind:kind status:status];

	return NO;
}

+ (void)reportFailureToSaveKind:(TLOKeychainItemKind)kind status:(OSStatus)status
{
#ifdef DEBUG
	if (_reportsFailures == NO) {
		return;
	}
#endif

	NSString *reason = CFBridgingRelease(SecCopyErrorMessageString(status, NULL));

	if (reason == nil) {
		reason = @"";
	}

	NSString *kindName = nil;

	switch (kind) {
		case TLOKeychainItemKindServerPassword:
			kindName = TXTLS(@"Prompts[k3y-n1]");
			break;
		case TLOKeychainItemKindNicknamePassword:
			kindName = TXTLS(@"Prompts[k3y-n2]");
			break;
		case TLOKeychainItemKindProxyPassword:
			kindName = TXTLS(@"Prompts[k3y-n3]");
			break;
		case TLOKeychainItemKindChannelKey:
			kindName = TXTLS(@"Prompts[k3y-n4]");
			break;
	}

	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[TDCAlert alertWithMessage:TXTLS(@"Prompts[k3y-m1]", reason, status)
							 title:TXTLS(@"Prompts[k3y-t1]", kindName)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil];
	});
}

+ (void)deletePasswordOfKind:(TLOKeychainItemKind)kind forIdentifier:(NSString *)identifier
{
	[XRKeychain deleteKeychainItem:[self labelForKind:kind]
					  withItemKind:_keychainItemKind
					   forUsername:nil
					   serviceName:[self serviceForKind:kind identifier:identifier]];
}

@end

#ifdef DEBUG
@implementation TLOKeychain (Testing)

+ (nullable NSNumber *)simulatedWriteStatus
{
	return _simulatedWriteStatus;
}

+ (void)setSimulatedWriteStatus:(nullable NSNumber *)simulatedWriteStatus
{
	_simulatedWriteStatus = [simulatedWriteStatus copy];
}

+ (BOOL)reportsFailures
{
	return _reportsFailures;
}

+ (void)setReportsFailures:(BOOL)reportsFailures
{
	_reportsFailures = reportsFailures;
}

@end
#endif

NS_ASSUME_NONNULL_END
