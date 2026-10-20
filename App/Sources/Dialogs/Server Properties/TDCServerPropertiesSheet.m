/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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

#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCAddressBook.h"
#import "IRCChannel.h"
#import "TLOLocalization.h"
#import "TVCValidatedTextField.h"
#import "TDCAlert.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TDCServerPropertiesPanePrivate.h"
#import "TDCServerPropertiesWindowPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerPropertiesSheet () <NSWindowDelegate>
@property (nonatomic, strong, readwrite, nullable) IRCClient *client;
@property (nonatomic, copy, readwrite, nullable) NSString *clientId;
@property (nonatomic, strong) IRCClientConfigMutable *config;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesAddressBookPane *addressBookPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesChannelsPane *channelsPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *connectCommandsPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *encodingPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *identityPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *messagesPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *zncBouncerPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *clientCertificatePane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *floodControlPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *networkSocketPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesPane *proxyServerPane;
@property (nonatomic, strong) TDCServerPropertiesUploadsPane *uploadsPane; // built in code
@property (nonatomic, strong) TDCServerPropertiesServerPane *serverPane; // in Swift
@property (nonatomic, strong) TDCServerPropertiesWindow *windowContent;
@property (nonatomic, copy) NSArray<TDCServerPropertiesPane *> *panes;
@end

@implementation TDCServerPropertiesSheet

- (instancetype)initWithClient:(nullable IRCClient *)client
{
	if ((self = [super initWithWindow:nil])) {
		if (client) {
			self.client = client;
			self.clientId = client.uniqueIdentifier;

			[client updateStoredConfiguration];

			self.config = [client.config mutableCopy];
		} else {
			self.config = [IRCClientConfigMutable new];
		}

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[self loadNib];

	[self addConfigurationDidChangeObserver];

	[self setUpPanes];

	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane prepareInitialState];
	}

	[self setUpWindow];
}

/* The panes in the order of the sidebar: Save checks them for an
 invalid field in this order (after the visible one) */
- (void)setUpPanes
{
	self.serverPane = [TDCServerPropertiesServerPane new];

	self.uploadsPane = [TDCServerPropertiesUploadsPane new];

#define _pane(_pane_, _identifier_) 	\
	(_pane_).selection = TDCServerPropertiesSheetSelection ##_identifier_;

	_pane(self.serverPane, General)
	_pane(self.identityPane, Identity)
	_pane(self.channelsPane, Autojoin)
	_pane(self.addressBookPane, AddressBook)
	_pane(self.messagesPane, DisconnectMessages)
	_pane(self.connectCommandsPane, ConnectCommands)
	_pane(self.networkSocketPane, NetworkSocket)
	_pane(self.encodingPane, Encoding)
	_pane(self.floodControlPane, FloodControl)
	_pane(self.clientCertificatePane, ClientCertificate)
	_pane(self.proxyServerPane, ProxyServer)
	_pane(self.uploadsPane, Uploads)
	_pane(self.zncBouncerPane, ZncBouncer)

#undef _pane

	self.panes = @[
		self.serverPane,
		self.identityPane,
		self.channelsPane,
		self.addressBookPane,
		self.messagesPane,
		self.connectCommandsPane,
		self.networkSocketPane,
		self.encodingPane,
		self.floodControlPane,
		self.clientCertificatePane,
		self.proxyServerPane,
		self.uploadsPane,
		self.zncBouncerPane
	];

	for (TDCServerPropertiesPane *pane in self.panes) {
		pane.propertiesSheet = self;
	}

	((TDCServerPropertiesClientCertificatePane *)self.clientCertificatePane).serverPane = self.serverPane;
}

- (void)setUpWindow
{
	__weak TDCServerPropertiesSheet *weakSelf = self;

	self.windowContent =
	[[TDCServerPropertiesWindow alloc] initWithPanes:self.panes
										 serverPane:self.serverPane
											   save:^{
												   [weakSelf ok:nil];
											   }
											 cancel:^{
												 [weakSelf cancel:nil];
											 }];

	NSWindow *window = self.windowContent.window;

	window.delegate = self;

	self.sheet = window;
}

#pragma mark -
#pragma mark Initialization Handler

- (void)start
{
	[self startWithSelection:TDCServerPropertiesSheetSelectionDefault context:nil];
}

- (void)startWithSelection:(TDCServerPropertiesSheetSelection)selection context:(nullable id)context
{
	[self startSheet];

	[self navigateToSelection:selection];

	switch (selection) {
		case TDCServerPropertiesSheetSelectionNewIgnoreEntry:
		{
			if ([context isKindOfClass:[NSString class]]) {
				[self.addressBookPane addIgnoreEntryWithHostmask:context];
			} else if ([context isKindOfClass:[IRCAddressBookEntry class]]) {
				[self.addressBookPane editEntry:context];
			}

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)navigateToSelection:(TDCServerPropertiesSheetSelection)selection
{
	if (selection == TDCServerPropertiesSheetSelectionDefault) {
		selection = TDCServerPropertiesSheetSelectionGeneral;
	} else if (selection == TDCServerPropertiesSheetSelectionNewIgnoreEntry) {
		selection = TDCServerPropertiesSheetSelectionAddressBook;
	}

	self.windowContent.selection = selection;
}

- (void)closeChildSheets
{
	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane closeChildSheets];
	}
}

- (void)ok:(nullable id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	[self removeConfigurationDidChangeObserver];

	[self closeChildSheets];

	[self saveConfig];

	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(serverPropertiesSheet:onOk:)]) {
		[delegate serverPropertiesSheet:self onOk:[self.config copy]];
	}

	[super ok:nil];
}

- (BOOL)okOrError
{
	TDCServerPropertiesSheetSelection selection = self.windowContent.selection;

	/* We want to show the error for the visible pane first so that
	 the user isn't jerked around. */
	NSMutableArray<TDCServerPropertiesPane *> *panes = [self.panes mutableCopy];

	NSUInteger visiblePaneIndex =
	[panes indexOfObjectPassingTest:^BOOL(TDCServerPropertiesPane *pane, NSUInteger index, BOOL *stop) {
		return (pane.selection == selection);
	}];

	if (visiblePaneIndex != NSNotFound) {
		TDCServerPropertiesPane *visiblePane = panes[visiblePaneIndex];

		[panes removeObjectAtIndex:visiblePaneIndex];

		[panes insertObject:visiblePane atIndex:0];
	}

	for (TDCServerPropertiesPane *pane in panes) {
		if (pane.hasInvalidField == NO) {
			continue;
		}

		[self navigateToSelection:pane.selection];

		[pane showInvalidField];

		return NO;
	}

	return YES;
}

- (void)cancel:(nullable id)sender
{
	[self removeConfigurationDidChangeObserver];

	[self closeChildSheets];

	[super cancel:nil];
}

- (void)addConfigurationDidChangeObserver
{
	if (self.client == nil) {
		return;
	}

	[RZNotificationCenter() addObserver:self
							   selector:@selector(underlyingConfigurationChanged:)
								   name:IRCClientConfigurationWasUpdatedNotification
								 object:self.client];
}

- (void)removeConfigurationDidChangeObserver
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)underlyingConfigurationChanged:(NSNotification *)notification
{
	NSWindow *window = self.sheet.deepestWindow;
	
	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCServerPropertiesSheet[oz4-kb]")
							 title:TXTLS(@"TDCServerPropertiesSheet[bzh-il]")
					 defaultButton:TXTLS(@"Prompts[mvh-ms]")
				   alternateButton:TXTLS(@"Prompts[99q-gg]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked != TDCAlertResponseDefault) {
						   return;
					   }

					   /* A new sheet: this one, closed and started again, lost its
						observers and table data, and loaded every list twice */
					   id delegate = self.delegate;

					   if ([delegate respondsToSelector:@selector(serverPropertiesSheetWantsReload:)]) {
						   [delegate serverPropertiesSheetWantsReload:self];
					   }
				   }];
}

- (void)loadConfig
{
	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane loadFromConfig:self.config];
	}
}

- (void)saveConfig
{
	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane saveToConfig:self.config];
	}
}

#pragma mark -
#pragma mark Properties

- (NSArray<IRCChannelConfig *> *)channelList
{
	return self.channelsPane.items;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane tearDown];
	}

	[self.sheet makeFirstResponder:nil];

	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(serverPropertiesSheetWillClose:)]) {
		[delegate serverPropertiesSheetWillClose:self];
	}

	[super windowWillClose:note];
}

@end

NS_ASSUME_NONNULL_END
