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

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCClientConfig, IRCChannel, IRCChannelConfig, IRCTreeItem;

TEXTUAL_EXTERN NSString * const IRCWorldClientListDefaultsKey;

TEXTUAL_EXTERN NSNotificationName const IRCWorldClientListWasModifiedNotification;

TEXTUAL_EXTERN NSNotificationName const IRCWorldDateHasChangedNotification;

TEXTUAL_EXTERN NSNotificationName const IRCWorldWillDestroyClientNotification;
TEXTUAL_EXTERN NSNotificationName const IRCWorldWillDestroyChannelNotification;

@interface IRCWorld : NSObject
@property (readonly) NSUInteger messagesSent;
@property (readonly) NSUInteger messagesReceived;
@property (readonly) uint64_t bandwidthIn;
@property (readonly) uint64_t bandwidthOut;
@property (readonly, copy) NSArray<IRCClient *> *clientList;
@property (readonly) NSUInteger clientCount;

- (void)save;
- (void)savePeriodically;

- (NSArray<__kindof IRCTreeItem *> *)findItemsWithIds:(NSArray<NSString *> *)itemIds;

- (nullable IRCTreeItem *)findItemWithId:(NSString *)itemId;

- (nullable IRCClient *)findClientWithId:(NSString *)clientId;
- (nullable IRCChannel *)findChannelWithId:(NSString *)channelId onClientWithId:(NSString *)clientId;

- (nullable IRCClient *)findClientWithServerAddress:(NSString *)serverAddress;

- (IRCClient *)createClientWithConfig:(IRCClientConfig *)config;
- (IRCChannel *)createChannelWithConfig:(IRCChannelConfig *)config onClient:(IRCClient *)client;
- (IRCChannel *)createPrivateMessage:(NSString *)nickname onClient:(IRCClient *)client;

- (void)destroyClient:(IRCClient *)client;
- (void)destroyChannel:(IRCChannel *)channel;

- (void)evaluateFunctionOnAllViews:(NSString *)function arguments:(nullable NSArray *)arguments; // Defaults to onQueue YES
- (void)evaluateFunctionOnAllViews:(NSString *)function arguments:(nullable NSArray *)arguments onQueue:(BOOL)onQueue;
@end

NS_ASSUME_NONNULL_END
