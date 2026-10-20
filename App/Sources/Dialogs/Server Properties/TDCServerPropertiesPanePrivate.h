/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TDCServerEndpointListSheetPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCAddressBookEntry, IRCChannelConfig, IRCClientConfig, IRCClientConfigMutable, IRCServer;
@class TVCBasicTableView;
@class TDCServerPropertiesClientCertificatePane;

/* One part of the Server Properties sheet: its view and the controls in it,
 in the sheet's nib (an object whose outlets and actions go to it). The sheet
 loads every pane from the configuration, asks each for an invalid field
 before saving, then saves through each. */
@interface TDCServerPropertiesPane : NSObject
@property (nonatomic, weak) IBOutlet TDCServerPropertiesSheet *propertiesSheet;
@property (nonatomic, strong) IBOutlet NSView *view;

/* Its item in the sheet's navigation list */
@property (nonatomic, assign) TDCServerPropertiesSheetSelection selection;

/* After the nib loaded, before -loadFromConfig: */
- (void)prepareInitialState;

- (void)loadFromConfig:(IRCClientConfig *)config;
- (void)saveToConfig:(IRCClientConfigMutable *)config;

/* A validated text field or combo box whose value can't be saved, or nil */
- (nullable NSControl *)firstInvalidField;

/* Something can't be saved (by default: there is a -firstInvalidField) */
@property (readonly) BOOL hasInvalidField;

/* Points it out, once the pane is shown (by default: the field's popover) */
- (void)showInvalidField;

/* Sheets this pane opened on the Server Properties sheet */
- (void)closeChildSheets;

/* The sheet's window is closing */
- (void)tearDown;
@end

/* A pane with a table of items, Add, Edit and Delete buttons, rows that can be
 dragged into another order, and a sheet that adds or edits one item. The
 table's rows come from an array controller (its arranged objects). */
@interface TDCServerPropertiesListPane : TDCServerPropertiesPane <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, weak) IBOutlet TVCBasicTableView *table;
@property (nonatomic, strong) IBOutlet NSArrayController *arrayController;
@property (nonatomic, weak) IBOutlet NSButton *addButton;
@property (nonatomic, weak) IBOutlet NSButton *editButton;
@property (nonatomic, weak) IBOutlet NSButton *deleteButton;

/* The sheet that adds or edits an item while it is open */
@property (nonatomic, strong, nullable) TDCSheetBase *childSheet;

/* The items as the table shows them */
@property (readonly, copy) NSArray *items;

- (IBAction)addItem:(nullable id)sender;
- (IBAction)editItem:(nullable id)sender;
- (IBAction)deleteItem:(nullable id)sender;

/* For each kind of list: */

/* Opens the sheet that adds an item (nil) or edits one */
- (void)showSheetForItem:(nullable id)item;

- (nullable id)valueForColumn:(NSString *)columnId ofItem:(id)item;

/* An edit made in the table itself (none by default) */
- (void)setValue:(nullable id)value forColumn:(NSString *)columnId ofItem:(id)item;

/* The item from the sheet replaces the one with its unique identifier, or is added */
- (void)addOrReplaceItem:(id)item;
- (void)removeItem:(id)item;

/* NO when nothing moved */
- (BOOL)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
@end

@interface TDCServerPropertiesChannelsPane : TDCServerPropertiesListPane
@end

@interface TDCServerPropertiesAddressBookPane : TDCServerPropertiesListPane
@property (nonatomic, strong) IBOutlet NSMenu *addMenu;

/* From the sheet's -startWithSelection:context: */
- (void)addIgnoreEntryWithHostmask:(nullable NSString *)hostmask;
- (void)editEntry:(IRCAddressBookEntry *)entry;
@end

/* The pane with the servers (TDCServerPropertiesServerPane, in Swift) */
@protocol TDCServerPropertiesSecuredConnection <NSObject>
/* A client certificate is only sent on a secured connection */
- (void)turnOnSecuredConnection;
@end

/* Nicknames, user and real name, NickServ and the login key */
@interface TDCServerPropertiesIdentityPane : TDCServerPropertiesPane
@property (nonatomic, weak) IBOutlet TDCServerPropertiesClientCertificatePane *clientCertificatePane;
@end

@interface TDCServerPropertiesClientCertificatePane : TDCServerPropertiesPane
@property (nonatomic, weak, nullable) id <TDCServerPropertiesSecuredConnection> serverPane;

/* One is set, even when it is no longer in the Keychain */
@property (readonly) BOOL hasCertificate;
@end

@interface TDCServerPropertiesConnectCommandsPane : TDCServerPropertiesPane
@end

@interface TDCServerPropertiesEncodingPane : TDCServerPropertiesPane
@end

/* Quit messages */
@interface TDCServerPropertiesMessagesPane : TDCServerPropertiesPane
@end

@interface TDCServerPropertiesZncBouncerPane : TDCServerPropertiesPane
@end

@interface TDCServerPropertiesFloodControlPane : TDCServerPropertiesPane
@end

/* Address type, ping timeouts, certificate checks and cipher suites */
@interface TDCServerPropertiesNetworkSocketPane : TDCServerPropertiesPane
@end

@interface TDCServerPropertiesUploadsPane : TDCServerPropertiesPane
@end

@interface TDCServerPropertiesProxyServerPane : TDCServerPropertiesPane
@end

/* What panes need from the sheet */
@interface TDCServerPropertiesSheet (Panes)
/* The channels of the Autojoin pane, as shown */
@property (readonly, copy) NSArray<IRCChannelConfig *> *channelList;
@end

NS_ASSUME_NONNULL_END
