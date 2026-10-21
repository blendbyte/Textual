/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
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

NS_ASSUME_NONNULL_BEGIN

@class IRCBouncerAccount, IRCBouncerNetwork, IRCBouncerNetworkList, IRCClient;

/* The Edit Bouncer sheet (TDCEditBouncerSheet.swift): the account's name,
 address, port, TLS and login, its networks (networks: from a connected
 network of the bouncer, or nil to ask the bouncer), whether to tell about
 changes, and Remove Bouncer…. It hands the edited account to save, a
 network to add to addNetwork, and Keep Servers (YES) or Remove Servers Too
 (NO) to remove. */
@interface TDCEditBouncerSheet : NSObject
- (instancetype)initWithAccount:(IRCBouncerAccount *)account
					   networks:(nullable IRCBouncerNetworkList *)networks
				 existingClient:(IRCClient * _Nullable (^)(IRCBouncerNetwork *network, IRCBouncerAccount *account))existingClientBlock
						   save:(void (^)(IRCBouncerAccount *account))saveBlock
					 addNetwork:(void (^)(IRCBouncerNetwork *network))addNetworkBlock
						 remove:(void (^)(BOOL keepServers))removeBlock;

- (instancetype)init NS_UNAVAILABLE;

@property (readonly) NSWindow *window;

@property (nonatomic, assign) BOOL showsNetworksFirst; // opened to add networks: their list in view

- (void)beginInWindow:(NSWindow *)window;
@end

NS_ASSUME_NONNULL_END
