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

#import "NSStringHelper.h"
#import "IRCChannelConfig.h"
#import "IRCClientConfig.h"
#import "IRCNetworkList.h"
#import "IRCServer.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"
#import "TVCBasicTableView.h"
#import "TVCValidatedComboBox.h"
#import "TVCValidatedTextField.h"
#import "TDCWelcomeSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCWelcomeSheet ()
@property (nonatomic, weak) IBOutlet NSButton *autoConnectCheck;
@property (nonatomic, weak) IBOutlet NSButton *addChannelButton;
@property (nonatomic, weak) IBOutlet NSButton *deleteChannelButton;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *nicknameTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedComboBox *serverAddressComboBox;
@property (nonatomic, weak) IBOutlet TVCBasicTableView *channelTable;
@property (nonatomic, strong) NSMutableArray<NSString *> *channelList;
@property (nonatomic, strong) IRCNetworkList *networkList;

- (IBAction)onAddChannel:(id)sender;
- (IBAction)onDeleteChannel:(id)sender;
@end

@implementation TDCWelcomeSheet

#pragma mark -
#pragma mark Init.

- (instancetype)initWithWindow:(nullable NSWindow *)window
{
	if ((self = [super initWithWindow:window])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCWelcomeSheet" owner:self topLevelObjects:nil];

	/* Populate server list combo box */
	self.networkList = [IRCNetworkList new];

	NSArray *listOfNetworks = self.networkList.listOfNetworks;

	for (IRCNetwork *network in listOfNetworks) {
		[self.serverAddressComboBox addItemWithObjectValue:network.networkName];
	}

	/* Nickname */
	self.nicknameTextField.textDidChangeCallback = self;

	self.nicknameTextField.stringValueIsInvalidOnEmpty = YES;
	self.nicknameTextField.stringValueIsTrimmed = YES;
	self.nicknameTextField.stringValueUsesOnlyFirstToken = YES;

	self.nicknameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isHostmaskNickname == NO) {
			return TXTLS(@"CommonErrors[och-j5]");
		}

		return nil;
	};

	/* Server address */
	self.serverAddressComboBox.textDidChangeCallback = self;

	self.serverAddressComboBox.stringValueIsInvalidOnEmpty = YES;
	self.serverAddressComboBox.stringValueIsTrimmed = YES;
	self.serverAddressComboBox.stringValueUsesOnlyFirstToken = YES;

	self.serverAddressComboBox.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isValidInternetAddress == NO) {
			return TXTLS(@"CommonErrors[yyx-l3]");
		}

		return nil;
	};

	/* Setup others */
	self.channelList = [NSMutableArray new];

	self.channelTable.textEditingDelegate = self;

	[self updateDeleteChannelButton];

	self.nicknameTextField.stringValue = [TPCPreferences defaultNickname];
}

#pragma mark -
#pragma mark Controls

- (void)start
{
	[self startSheet];
}

- (void)close
{
	[super cancel:nil];
}

- (void)ok:(id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	IRCClientConfigMutable *config = nil;

	NSString *serverAddress = self.serverAddressComboBox.value;

	IRCNetwork *serverAddressNetwork = [self.networkList networkNamed:serverAddress];

	if (serverAddressNetwork == nil) {
		serverAddressNetwork = [self.networkList networkWithServerAddress:serverAddress];
	}

	if (serverAddressNetwork) {
		config = [IRCClientConfigMutable newConfigWithNetwork:serverAddressNetwork];
	} else {
		serverAddress = serverAddress.lowercaseString;

		config = [IRCClientConfigMutable new];

		config.connectionName = serverAddress;

		IRCServerMutable *server = [IRCServerMutable new];

		server.serverAddress = serverAddress;

		config.serverList = @[[server copy]];
	}

	config.autoConnect = (self.autoConnectCheck.state == NSControlStateValueOn);

	config.nickname = self.nicknameTextField.value;

	NSMutableArray<IRCChannelConfig *> *channelList = [NSMutableArray array];

	NSMutableArray<NSString *> *channelsAdded = [NSMutableArray array];

	for (NSString *channel in self.channelList) {
		NSString *channelName = channel.trim;

		if (channelName.length == 0) {
			continue;
		}

		if ([channelsAdded containsObjectIgnoringCase:channelName] == NO) {
			[channelsAdded addObject:channelName];
		} else {
			continue;
		}

		if (channelName.isChannelName == NO) {
			channelName = [@"#" stringByAppendingString:channelName];
		}

		IRCChannelConfig *channelConfig = [IRCChannelConfig seedWithName:channelName];

		[channelList addObject:channelConfig];
	}

	config.channelList = channelList;

	if ([self.delegate respondsToSelector:@selector(welcomeSheet:onOk:)]) {
		[self.delegate welcomeSheet:self onOk:[config copy]];
	}

	[super ok:nil];
}

- (BOOL)okOrError
{
	if ([self okOrErrorForComboBox:self.serverAddressComboBox] == NO) {
		return NO;
	}

	if ([self okOrErrorForTextField:self.nicknameTextField] == NO) {
		return NO;
	}

	return YES;
}

- (void)onAddChannel:(id)sender
{
	[self.channelList addObject:@""];

	[self.channelTable reloadData];

	NSInteger rowToEdit = (self.channelList.count - 1);

	[self.channelTable selectItemAtIndex:rowToEdit];

	[self.channelTable editColumn:0 row:rowToEdit withEvent:nil select:YES];
}

- (void)onDeleteChannel:(id)sender
{
	NSInteger selectedRow = self.channelTable.selectedRow;

	if (selectedRow < 0) {
		return;
	}

	[self.channelList removeObjectAtIndex:selectedRow];

	[self.channelTable reloadData];

	NSInteger channelListCount = self.channelList.count;

	if (selectedRow > channelListCount) {
		selectedRow = (channelListCount - 1);
	}

	if (channelListCount >= 0) {
		[self.channelTable selectItemAtIndex:selectedRow];
	}

	[self updateDeleteChannelButton];
}

- (void)updateDeleteChannelButton
{
	self.deleteChannelButton.enabled = (self.channelTable.numberOfSelectedRows > 0);
}

#pragma mark -
#pragma mark NSTableView Delegate

- (void)textDidEndEditing:(NSNotification *)note
{
	NSInteger editedRow = self.channelTable.editedRow;

	if (editedRow < 0) {
		return;
	}

	NSString *editedString = [note.object textStorage].string;

	self.channelList[editedRow] = [editedString copy];

	[self.channelTable reloadData];

	[self.channelTable selectItemAtIndex:editedRow];

	[self updateDeleteChannelButton];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)sender
{
	return self.channelList.count;
}

- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	return self.channelList[row];
}

- (void)tableViewSelectionIsChanging:(NSNotification *)note
{
	[self updateDeleteChannelButton];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	self.channelTable.dataSource = nil;
	self.channelTable.delegate = nil;

	if ([self.delegate respondsToSelector:@selector(welcomeSheetWillClose:)]) {
		[self.delegate welcomeSheetWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
