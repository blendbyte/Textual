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

#import "IRCChannelConfigPrivate.h"
#import "IRCWorld.h"

NS_ASSUME_NONNULL_BEGIN

@interface IRCWorld ()
@property (nonatomic, assign, readwrite) NSUInteger messagesSent;
@property (nonatomic, assign, readwrite) NSUInteger messagesReceived;
@property (nonatomic, assign, readwrite) uint64_t bandwidthIn;
@property (nonatomic, assign, readwrite) uint64_t bandwidthOut;
@property (nonatomic, assign) BOOL isImportingConfiguration;
@property (nonatomic, copy, readwrite) NSArray<IRCClient *> *clientList;

- (void)setupConfiguration;

- (nullable IRCTreeItem *)findItemWithPasteboardString:(NSString *)string;
- (NSString *)pasteboardStringForItem:(IRCTreeItem *)item;

- (void)autoConnectAfterWakeup:(BOOL)afterWakeUp;

- (void)prepareForSleep;

- (void)prepareForScreenSleep;
- (void)wakeFromScreenSleep;

- (void)noteReachabilityChanged:(BOOL)reachable;

- (IRCClient *)createClientWithConfig:(IRCClientConfig *)config reload:(BOOL)reload;
- (IRCChannel *)createChannelWithConfig:(IRCChannelConfig *)config onClient:(IRCClient *)client add:(BOOL)add adjust:(BOOL)adjust reload:(BOOL)reload;

- (IRCChannel *)createPrivateMessage:(NSString *)nickname onClient:(IRCClient *)client asType:(IRCChannelType)type;

- (void)destroyClient:(IRCClient *)client;

- (void)destroyChannel:(IRCChannel *)channel reload:(BOOL)reload;
- (void)destroyChannel:(IRCChannel *)channel reload:(BOOL)reload part:(BOOL)partChannel;
@end

NS_ASSUME_NONNULL_END
