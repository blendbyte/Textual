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

#import "IRCServer.h"
#import "NSStringHelper.h"
#import "TLOLocalization.h"
#import "TDCServerEndpointListSheetTablePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerEndpointListSheetTableCellView ()
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, copy) NSString *serverPort;
@property (nonatomic, copy) NSNumber *prefersSecuredConnection;
@property (nonatomic, copy) NSString *serverPassword;
@property (nonatomic, assign) BOOL observersRegistered;
@end

@implementation TDCServerEndpointListSheetTableCellView

- (BOOL)validateValue:(inout id *)ioValue forKeyPath:(NSString *)inKeyPath error:(out NSError **)outError
{
	if ([inKeyPath isEqualToString:@"serverAddress"]) {
		if (((NSString *)*ioValue).isValidInternetAddress == NO) {
			if (outError) {
				*outError = [NSError errorWithDomain:TXErrorDomain
												 code:71013
											userInfo:@{
					NSLocalizedDescriptionKey : TXTLS(@"TDCServerEndpointListSheet[iis-gr]"),
					NSLocalizedRecoverySuggestionErrorKey : TXTLS(@"TDCServerEndpointListSheet[k0c-3u]")}
							 ];
			}

			return NO;
		}
	} else if ([inKeyPath isEqualToString:@"serverPort"]) {
		if (((NSString *)*ioValue).isValidInternetPort == NO) {
			if (outError) {
				*outError = [NSError errorWithDomain:TXErrorDomain
												code:71014
											userInfo:@{
						NSLocalizedDescriptionKey : TXTLS(@"TDCServerEndpointListSheet[qeb-ip]"),
						NSLocalizedRecoverySuggestionErrorKey : TXTLS(@"TDCServerEndpointListSheet[ox2-od]")}
							 ];
			}

			return NO;
		}
	}

	return YES;
}

- (NSString *)serverAddress
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return @"";
	}

	return objectValue.serverAddress;
}

- (void)setServerAddress:(NSString *)serverAddress
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return;
	}

	objectValue.serverAddress = serverAddress;
}

- (NSString *)serverPort
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return @"";
	}

	return [NSString stringWithUnsignedShort:objectValue.serverPort];
}

- (void)setServerPort:(NSString *)serverPort
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return;
	}

	objectValue.serverPort = (uint16_t)serverPort.integerValue;
}

- (NSNumber *)prefersSecuredConnection
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return @(NSControlStateValueOff);
	}

	if (objectValue.prefersSecuredConnection) {
		return @(NSControlStateValueOn);
	} else {
		return @(NSControlStateValueOff);
	}
}

- (void)setPrefersSecuredConnection:(NSNumber *)prefersSecuredConnection
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return;
	}

	BOOL l_prefersSecuredConnection =
	(prefersSecuredConnection.unsignedIntegerValue == NSControlStateValueOn);

	if (l_prefersSecuredConnection) {
		objectValue.prefersSecuredConnection = YES;

		if (objectValue.serverPort == 6667) {
			objectValue.serverPort = 6697;
		}
	} else {
		objectValue.prefersSecuredConnection = NO;

		if (objectValue.serverPort == 6697) {
			objectValue.serverPort = 6667;
		}
	}
}

- (NSString *)serverPassword
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return @"";
	}

	NSString *serverPassword = objectValue.serverPassword;

	if (serverPassword == nil) {
		return @"";
	}

	return serverPassword;
}

- (void)setServerPassword:(NSString *)serverPassword
{
	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return;
	}

	objectValue.serverPassword = serverPassword;
}

- (void)setObjectValue:(nullable id)objectValue
{
	[self stopObservingObjectValue];

	super.objectValue = objectValue;

	[self startObservingObjectValue];
}

- (void)startObservingObjectValue
{
	NSString *keyPath = self.identifier;

	[self willChangeValueForKey:keyPath];
	[self didChangeValueForKey:keyPath];

	IRCServerMutable *objectValue = self.objectValue;

	if (objectValue == nil) {
		return;
	}

	[objectValue addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];

	self.observersRegistered = YES;
}

- (void)stopObservingObjectValue
{
	if (self.observersRegistered == NO) {
		return;
	}

	NSString *keyPath = self.identifier;

	IRCServerMutable *objectValue = self.objectValue;

	[objectValue removeObserver:self forKeyPath:keyPath];

	self.observersRegistered = NO;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString *, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"serverPort"]) {
		[self willChangeValueForKey:@"serverPort"];
		[self didChangeValueForKey:@"serverPort"];
	}
}

@end

NS_ASSUME_NONNULL_END
