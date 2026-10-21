/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *    Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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

#import "TextualPrivate.h"

// TLOpenLink.swift
#import "TDCAlert.h"
#import "TPCPreferencesUserDefaults.h"
#import "TLOLocalization.h"
#import "TPCPreferencesLocal.h"

// TDCSettingsWindow.swift, TDCSettingsSections.swift
#import "TDCSettingsBridgePrivate.h"
#import "TVCMainWindow.h"

// TDCServerPropertiesWindow.swift, TDCServerPropertiesServerPane.swift, TDCServerPropertiesAccountPanes.swift, TDCServerPropertiesListPages.swift
#import "IRCClientPrivate.h"
#import "NSStringHelper.h"
#import "IRCNetworkList.h"
#import "IRCServerPrivate.h"
#import "IRCStrictTransportSecurityPrivate.h"
#import "TDCServerPropertiesPanePrivate.h"
#import "IRCClientConfigPrivate.h"
#import "TXWebsiteLinks.h"
#import "IRCAddressBook.h"
#import "IRCChannelConfig.h"
#import "TDCAddressBookSheetPrivate.h"
#import "TDCChannelPropertiesSheetPrivate.h"
#import "TLOMessageArchivePrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TLOUploadDestinationPrivate.h"
#import "TDCUploadDestinationSheetPrivate.h"
#import "IRCISupportInfo.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCFileTransferDialogTransferControllerPrivate.h"
#import "TDCServerChannelListDialogPrivate.h"

// TLOLinkParser.swift
#import "TVCLogLine.h"

// IRCConnectionTransport.swift, IRCConnectionSocket(NWF).swift
#import "IRCClientConfig.h"
#import "IRCConnectionConfig.h"
#import "IRCConnectionErrors.h"
#import "IRCConnectionTransportPrivate.h"
#import "TLOKeychainPrivate.h"
#import "TLOTimer.h"
