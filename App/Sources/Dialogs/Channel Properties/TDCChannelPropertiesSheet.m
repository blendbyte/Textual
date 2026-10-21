/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
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

#import "IRCClient.h"
#import "IRCChannel.h"
#import "TLOLocalization.h"
#import "TDCAlert.h"
#import "TDCChannelPropertiesSheetInternal.h"
#import "TDCChannelPropertiesWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCChannelPropertiesSheet () <NSWindowDelegate>
@property (nonatomic, strong, readwrite, nullable) IRCClient *client;
@property (nonatomic, strong, readwrite, nullable) IRCChannel *channel;
@property (nonatomic, copy, readwrite, nullable) NSString *clientId;
@property (nonatomic, copy, readwrite, nullable) NSString *channelId;
@property (nonatomic, strong) TDCChannelPropertiesWindow *windowContent;
@end

@implementation TDCChannelPropertiesSheet

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)initWithWindow:(nullable NSWindow *)window
{
	if ((self = [super initWithWindow:window])) {
		self.config = [IRCChannelConfigMutable new];

		[self prepareInitialState];

		return self;
	}

	return nil;
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

- (instancetype)initWithClient:(IRCClient *)client
{
	return [self initWithConfig:nil onClient:client];
}

- (instancetype)initWithClientId:(NSString *)clientId
{
	return [self initWithConfig:nil onClientWithId:clientId];
}

- (instancetype)initWithChannel:(IRCChannel *)channel
{
	NSParameterAssert(channel != nil);

	if ((self = [super initWithWindow:nil])) {
		self.client = channel.associatedClient;
		self.clientId = channel.associatedClient.uniqueIdentifier;

		self.channel = channel;
		self.channelId = channel.uniqueIdentifier;

		self.config = [channel.config mutableCopy];

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (instancetype)initWithConfig:(nullable IRCChannelConfig *)config
{
	return [self initWithConfig:config onClientWithId:nil];
}

- (instancetype)initWithConfig:(nullable IRCChannelConfig *)config onClient:(nullable IRCClient *)client
{
	if ((self = [super initWithWindow:nil])) {
		self.client = client;
		self.clientId = client.uniqueIdentifier;

		if (config) {
			self.config = [config mutableCopy];
		} else {
			self.config = [IRCChannelConfigMutable new];
		}

		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (instancetype)initWithConfig:(nullable IRCChannelConfig *)config onClientWithId:(nullable NSString *)clientId
{
	/* Through the designated initializer: calling our -initWithWindow: and then
	 loading again built the window and loaded the config twice */
	if ((self = [self initWithConfig:config onClient:nil])) {
		self.clientId = clientId;

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	__weak TDCChannelPropertiesSheet *weakSelf = self;

	self.windowContent =
	[[TDCChannelPropertiesWindow alloc] initWithConfig:self.config
												client:self.client
												  save:^{
													  [weakSelf ok:nil];
												  }
												cancel:^{
													[weakSelf cancel:nil];
												}];

	NSWindow *window = self.windowContent.window;

	window.delegate = self;

	self.sheet = window;

	[self addConfigurationDidChangeObserver];
}

- (void)start
{
	[self startSheet];
}

- (void)addConfigurationDidChangeObserver
{
	if (self.channel == nil) {
		return;
	}

	[RZNotificationCenter() addObserver:self
							   selector:@selector(underlyingConfigurationChanged:)
								   name:IRCChannelConfigurationWasUpdatedNotification
								 object:self.channel];
}

- (void)removeConfigurationDidChangeObserver
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)underlyingConfigurationChanged:(NSNotification *)notification
{
	NSWindow *window = self.sheet;
	
	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCChannelPropertiesSheet[qby-hi]")
							 title:TXTLS(@"TDCChannelPropertiesSheet[mvl-r5]")
					 defaultButton:TXTLS(@"Prompts[mvh-ms]")
				   alternateButton:TXTLS(@"Prompts[99q-gg]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked != TDCAlertResponseDefault) {
						   return;
					   }

					   /* A new sheet, as for Server Properties */
					   id delegate = self.delegate;

					   if ([delegate respondsToSelector:@selector(channelPropertiesSheetWantsReload:)]) {
						   [delegate channelPropertiesSheetWantsReload:self];
					   }
				   }];
}

#pragma mark -
#pragma mark Actions

- (void)cancel:(nullable id)sender
{
	[self removeConfigurationDidChangeObserver];

	[super cancel:sender];
}

- (void)ok:(nullable id)sender
{
	/* Problems show under their fields */
	if ([self.windowContent applyChanges] == NO) {
		return;
	}

	[self removeConfigurationDidChangeObserver];

	if ([self.delegate respondsToSelector:@selector(channelPropertiesSheet:onOk:)]) {
		[self.delegate channelPropertiesSheet:self onOk:[self.config copy]];
	}

	[super ok:nil];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.sheet makeFirstResponder:nil];

	if ([self.delegate respondsToSelector:@selector(channelPropertiesSheetWillClose:)]) {
		[self.delegate channelPropertiesSheetWillClose:self];
	}

	[super windowWillClose:note];
}

@end

NS_ASSUME_NONNULL_END
