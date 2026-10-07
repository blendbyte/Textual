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

#import "IRCCommandIndex.h"
#import "TVCLogLine.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCChannel, IRCPrefix, IRCMessage;
@class TVCLogController;

@class THOPluginDidPostNewMessageConcreteObject;
@class THOPluginWebViewJavaScriptPayloadConcreteObject;

@interface THOPluginDispatcher : NSObject
+ (dispatch_queue_t)dispatchQueue;

+ (BOOL)receivedCommand:(NSString *)command withText:(nullable NSString *)text authoredBy:(IRCPrefix *)textAuthor destinedFor:(nullable IRCChannel *)textDestination onClient:(IRCClient *)client receivedAt:(NSDate *)receivedAt referenceMessage:(nullable IRCMessage *)referenceMessage;
+ (BOOL)receivedText:(NSString *)text authoredBy:(IRCPrefix *)textAuthor destinedFor:(nullable IRCChannel *)textDestination asLineType:(TVCLogLineType)lineType onClient:(IRCClient *)client receivedAt:(NSDate *)receivedAt wasEncrypted:(BOOL)wasEncrypted;
+ (nullable IRCMessage *)interceptServerInput:(IRCMessage *)inputObject for:(IRCClient *)client;
+ (nullable id)interceptUserInput:(id)inputObject command:(IRCRemoteCommand)commandString;
+ (NSString *)willRenderMessage:(NSString *)newMessage forViewController:(TVCLogController *)viewController lineType:(TVCLogLineType)lineType memberType:(TVCLogLineMemberType)memberType;
+ (void)userInputCommandInvokedOnClient:(IRCClient *)client commandString:(NSString *)commandString messageString:(NSString *)messageString;
+ (void)didReceiveJavaScriptPayload:(THOPluginWebViewJavaScriptPayloadConcreteObject *)payloadObject fromViewController:(TVCLogController *)viewController;
+ (void)didReceiveServerInput:(IRCMessage *)inputObject onClient:(IRCClient *)client;
+ (void)enqueueDidPostNewMessage:(THOPluginDidPostNewMessageConcreteObject *)messageObject;
+ (void)dequeueDidPostNewMessageWithLineNumber:(NSString *)messageLineNumber forViewController:(TVCLogController *)viewController;
@end

NS_ASSUME_NONNULL_END
