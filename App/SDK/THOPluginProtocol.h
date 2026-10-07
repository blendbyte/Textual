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

#import "THOPluginManager.h"
#import "IRCCommandIndex.h"
#import "TVCLogLine.h"

NS_ASSUME_NONNULL_BEGIN

@class AHHyperlinkScannerResult;
@class IRCClient, IRCChannel, IRCChannelUser, IRCPrefix, IRCMessage;
@class TVCLogController;

@class THOPluginDidPostNewMessageConcreteObject;
@class THOPluginDidReceiveServerInputConcreteObject;
@class THOPluginOutputSuppressionRule;
@class THOPluginWebViewJavaScriptPayloadConcreteObject;

#pragma mark -
#pragma mark Localization

#define TPILocalizedString(k, ...)		TXLocalizedStringAlternative(TPIBundleFromClass(), k, ##__VA_ARGS__)

/**
 * @brief Returns the NSBundle that owns the calling class.
 */
#define TPIBundleFromClass()				[NSBundle bundleForClass:[self class]]

/**
 * A plugin must declare the minimum version of Textual that it is compatible with.
 *
 * Textual declares the constant named THOPluginProtocolCompatibilityMinimumVersion.
 * This constant is compared against the minimum version that a plugin specifies.
 * If the plugin's value is equal to or greater than this constant, then the plugin
 * is considered safe to load. 
 *
 * Unlike the version information that visible to the end user, this constant does
 * not change often. It only changes when modifications have been made to Textual’s
 * codebase that may result in crashes when loading existing plugins.
 *
 * For example, even though Textual’s visible version number is “5.0.4”, the value
 * of this constant is “5.0.0”
 *
 * To declare compatibility, add a new entry to a plugin's Info.plist file with 
 * the key named: "MinimumTextualVersion" - Set the value of this entry, as a 
 * String, to the return value of THOPluginProtocolCompatibilityMinimumVersion.
 *
 * @return "7.2.4" as of June 30, 2024
 */
extern NSString * const THOPluginProtocolCompatibilityMinimumVersion;

/**
 * The `THOPluginProtocol` protocol defines methods and properties that the 
 * primary class of a plugin can inherit from.
 */
@protocol THOPluginProtocol <NSObject>

@optional

#pragma mark -
#pragma mark Initialization

/** @name Initialization */

/**
 * @brief Method invoked during initialization of a plugin.
 *
 * @discussion This method is invoked very early on. It occurs once the principal 
 *  class of the plugin has been allocated and is guaranteed to be the first call
 *  home that a plugin will receive.
 */
- (void)pluginLoadedIntoMemory;

/**
 * @brief Method invoked prior to deallocation of a plugin.
 */
- (void)pluginWillBeUnloadedFromMemory;

#pragma mark -
#pragma mark Input Manipulation

/** @name Input Manipulation */

/**
 * @brief Method invoked to inform the plugin that a plain text message was received
 *  (*PRIVMSG*, *ACTION*, or *NOTICE*)
 *
 * @discussion This method is invoked on the main thread which means that slow code
 *  can lockup the user interface of Textual. If you have no intent to ignore content,
 *  then do work in the background and immediately return `YES`.
 *
 * @param text The message contents
 * @param textAuthor The author (sender) of the message
 * @param textDestination The channel that the message is destined for
 * @param lineType The line type of the message
 *
 *    Possible values: `TVCLogLineTypePrivateMessage`, `TVCLogLineTypeAction`,
 *           `TVCLogLineTypeNotice`
 * @param client The client the message was received on
 * @param receivedAt The date & time of the message. Depending on whether a custom
 *    value was specified using the server-time IRCv3 capability, this `NSDate`
 *    object may be very far in the past, or even possibly in the future.
 * @param wasEncrypted Whether or not the message was encrypted
 *
 * @return `YES` to display the contents of the message to the user, `NO` otherwise.
 */
- (BOOL)receivedText:(NSString *)text
	      authoredBy:(IRCPrefix *)textAuthor
	     destinedFor:(nullable IRCChannel *)textDestination
	      asLineType:(TVCLogLineType)lineType
	        onClient:(IRCClient *)client
	      receivedAt:(NSDate *)receivedAt
	    wasEncrypted:(BOOL)wasEncrypted;

/**
 * @brief Method used to modify and/or completely ignore incoming data from the server.
 *
 * @warning This method is invoked on each plugin in the order loaded. This method
 *  does not stop for the first result returned which means that value being passed may
 *  have been modified by a plugin above the one being talked to.
 *
 * @warning Textual does not perform validation against the instance of `IRCMessage` that
 *  is returned which means that if Textual tries to access specific information which
 *  has been improperly modified or removed, then the entire application may crash.
 *
 * @param input An instance of `IRCMessage`
 * @param client The client responsible for the event
 *
 * @return The original and/or modified copy of `IRCMessage` or `nil` to prevent the data
 *  from being processed altogether.
 */
- (nullable IRCMessage *)interceptServerInput:(IRCMessage *)input for:(IRCClient *)client;

/**
 * @brief Method used to modify and/or completely ignore text entered into the main text
 *  field of Textual.
 *
 * @warning This method is invoked on each plugin in the order loaded. This method
 *  does not stop for the first result returned which means that value being passed may
 *  have been modified by a plugin above the one being talked to.
 *
 * @param input The value of the text field as either an instance of `NSString` or
 *  `NSAttributedString`.
 * @param command Textual allows the end user to send text entered into the text field as
 *  an action without using the `/me` command. When this occurs, Textual informs lower-level
 *  APIs of this intent by changing the value of this parameter from “privmsg” to “action” —
 *  In most cases a plugin should disregard this parameter and pass it untouched.
 *
 * @return The original and/or modified copy of input or `nil` to prevent the data from
 *  being processed altogether.
 */
- (nullable id)interceptUserInput:(id)input command:(IRCRemoteCommand)command;

#pragma mark -
#pragma mark Preferences Pane

/** @name Preferences */

/**
 * @brief Defines an `NSView` used by the Preferences window of Textual to
 *  allow user-interactive configuration of the plugin.
 *
 * @return An instance of NSView with a width of at least 590.
 */
@property (nonatomic, readonly, strong) NSView *pluginPreferencesPaneView;

/**
 * @brief Defines an `NSString` which is used by the Preferences window of
 *  Textual to create a new entry in its navigation list.
 */
@property (nonatomic, readonly, copy) NSString *pluginPreferencesPaneMenuItemName;

#pragma mark -
#pragma mark Renderer Events

/** @name Renderer Events */

/**
 * @brief Method invoked prior to a message being converted to its HTML equivalent.
 *
 * @discussion This methods can be used to modify the text that will be displayed for a 
 *  certain message by replacing one or more segments of it.
 * 
 * Considerations:
 *
 * 1. `nil` or a string with zero length indicates that there is no interest in modifying 
 *  `newMessage`
 * 2. There is no way to inform the renderer that you do not want a specific value of 
 *  `newMessage` shown to the end user. Use the various other methods provided by the 
 *  `THOPluginProtocol` to accomplish that task.
 *
 * @warning This method is invoked on each plugin in the order loaded. This method does not 
 *  stop for the first result returned which means that value being passed may have been
 *  modified by a plugin above the one being talked to.
 *
 * @warning Under no circumstances should you insert HTML at this point. Doing so will result 
 *  in undefined behavior.
 *
 * @param newMessage An unedited copy of the message being rendered
 * @param viewController The view responsible for the event
 * @param lineType The line type of `newMessage`
 * @param memberType The member type of `newMessage`
 *
 * @return The original and/or modified copy of `newMessage`
 */
- (NSString *)willRenderMessage:(NSString *)newMessage
			  forViewController:(TVCLogController *)viewController
					   lineType:(TVCLogLineType)lineType
					 memberType:(TVCLogLineMemberType)memberType;

#pragma mark -
#pragma mark Subscribed Events

/** @name Subscribed Events */

/**
 * @brief Defines a list of commands that the plugin will support as user input
 *  from the main text field.
 *
 * @discussion Considerations:
 *
 * 1. If a command is a number, then insert it into the array as an `NSString`
 * 2. If a plugin tries to add a command already built into Textual onto
 *  this list, it will not work.
 * 3. It is possible, but unlikely, that another plugin the end user has
 *  loaded is subscribed to the same command. When that occurs, all plugins
 *  subscribed to the command will be informed of when the command is performed.
 * 4. To avoid conflicts, a plugin cannot subscribe to a command already
 *  defined by a script. If a script and a plugin both share the same command,
 *  then neither will be executed and an error will be printed to the console.
 *
 * @return An `NSArray` containing a lowercase list of commands that the plugin
 *  will support as user input from the main text field.
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *subscribedUserInputCommands;

/**
 * @brief Method invoked when a subscribed user input command requires processing.
 *
 * @param client The client responsible for the event
 * @param commandString The name of the command
 * @param messageString Data that follows `commandString`
 */
- (void)userInputCommandInvokedOnClient:(IRCClient *)client commandString:(NSString *)commandString messageString:(NSString *)messageString;

/**
 * @brief Defines a list of commands that the plugin will support as server input.
 *
 * @return An `NSArray` containing a lowercase list of commands that the plugin
 *  will support as server input.
 *
 * @discussion If a command is a number, then insert it into the array as an `NSString`
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *subscribedServerInputCommands;

/**
 * @brief Method invoked when a subscribed server input command requires processing.
 *
 * @param inputObject An instance of THOPluginDidReceiveServerInputConcreteObject
 * @param client The client responsible for the event
 *
 * @see THOPluginDidReceiveServerInputConcreteObject
 */
- (void)didReceiveServerInput:(THOPluginDidReceiveServerInputConcreteObject *)inputObject onClient:(IRCClient *)client;

#pragma mark -
#pragma mark WebView Events

/** @name WebView Events */

/**
 * @brief Method invoked when the Document Object Model (DOM) of a view has been modified.
 *
 * @discussion This method is invoked when a message has been added to the Document Object
 *  Model (DOM) of viewController
 *
 * @warning Do not do any heavy work when the
 *  [isProcessedInBulk]([THOPluginDidPostNewMessageConcreteObject isProcessedInBulk]) property 
 *  of `messageObject` is set to `YES` because thousand of other messages may be processing at 
 *  the same time.
 *
 * @warning This method is invoked on an asynchronous background dispatch queue. Not the
 *  main thread. If you interact with WebKit when this method is invoked, then make sure
 *  that you do so on the main thread. If you don't, WebKit will throw an exception.
 *
 * @param messageObject An instance of THOPluginDidPostNewMessageConcreteObject
 * @param viewController The view responsible for the event
 *
 * @see THOPluginDidPostNewMessageConcreteObject
 */
- (void)didPostNewMessage:(THOPluginDidPostNewMessageConcreteObject *)messageObject forViewController:(TVCLogController *)viewController;

/**
 * @brief Method invoked when the JavaScript function `app.sendPluginPayload()` is executed.
 *
 * @discussion A plugin that injects JavaScript into Textual's WebView can use this method
 *  to send data back to the plugin.
 * 
 * A payload can be passed by invoking the JavaScript function 
 *  `app.sendPluginPayload(payloadLabel, payloadContent)`
 *
 * @warning This method is invoked on an asynchronous background dispatch queue. Not the
 *  main thread. If you interact with WebKit when this method is invoked, then make sure
 *  that you do so on the main thread. If you don't, WebKit will throw an exception.
 *
 * @param payloadObject An instance of THOPluginWebViewJavaScriptPayloadConcreteObject
 * @param viewController The view responsible for the event
 *
 * @see THOPluginWebViewJavaScriptPayloadConcreteObject
 */
- (void)didReceiveJavaScriptPayload:(THOPluginWebViewJavaScriptPayloadConcreteObject *)payloadObject fromViewController:(TVCLogController *)viewController;

#pragma mark -
#pragma mark Reserved Calls

/* The behavior of this method call is undefined. It exists for internal
 purposes for the plugins packaged with Textual by default. It is not
 recommended to use it, or try to understand it. */
@property (nonatomic, readonly, copy) NSArray<THOPluginOutputSuppressionRule *> *pluginOutputSuppressionRules;
@end

#pragma mark -

/**
 * This object is a container for values related to
 * [THOPluginProtocol didPostNewMessage:forViewController:]
 */
@interface THOPluginDidPostNewMessageConcreteObject : NSObject
/**
 * @brief Whether the message was posted as a result of a bulk operation
 */
@property (readonly) BOOL isProcessedInBulk;

/**
 * @brief The contents of the message visible to the end user
 */
@property (readonly, copy) NSString *messageContents;

/**
 * @brief The ID of the message that can be used to access it using `getElementByID()`
 */
@property (readonly, copy) NSString *lineNumber;

/**
 * @brief The nickname of the person and/or server responsible for producing the 
 *  message.
 *
 * @discussion This value may be empty.
 */
@property (readonly, copy, nullable) NSString *senderNickname;

/**
 * @brief The line type of the message
 */
@property (readonly) TVCLogLineType lineType;

/**
 * @brief The member type of the message
 */
@property (readonly) TVCLogLineMemberType memberType;

/**
 * @brief The date & time displayed left of the message in the WebView
 */
@property (readonly, copy) NSDate *receivedAt;

/**
 * @brief Array of URLs found in the message body
 */
@property (readonly, copy) NSArray<AHHyperlinkScannerResult *> *listOfHyperlinks;

/**
 * @brief List of users from the channel that appear in the message
 */
@property (readonly, copy) NSSet<IRCChannelUser *> *listOfUsers;

/**
 * @brief Whether or not a highlight word was matched
 */
@property (readonly) BOOL keywordMatchFound;
@end

#pragma mark -

/**
 * This object is a container for values related to
 * [THOPluginProtocol didReceiveServerInput:onClient:]
 */
@interface THOPluginDidReceiveServerInputConcreteObject : NSObject
/**
 * @brief Whether the input was from a regular user or from a server
 */
@property (readonly) BOOL senderIsServer;

/**
 * @brief The nickname section of the sender's hostmask
 *
 * @discussion The value of this property is the server address if senderIsServer is `YES`
 */
@property (readonly, copy) NSString *senderNickname;

/**
 * @brief The username (ident) section of the sender's hostmask
 */
@property (readonly, copy, nullable) NSString *senderUsername;

/**
 * @brief The address section of the sender's hostmask
 */
@property (readonly, copy, nullable) NSString *senderAddress;

/**
 * @brief The combined hostmask of the sender
 */
@property (readonly, copy) NSString *senderHostmask;

/**
 * @brief The date & time during which the input was received
 *
 * @discussion If the original message specifies a custom value using the server-time
 *  capability, then the value of this property will reflect the value defined by the
 *  server-time capability; not the exact date & time it was received on the socket.
 */
@property (readonly, copy) NSDate *receivedAt;

/**
 * @brief The input itself
 */
@property (readonly, copy) NSString *messageSequence;

/**
 * @brief The input, split up into sections
 */
@property (readonly, copy) NSArray<NSString *> *messageParameters;

/**
 * @brief The input's command
 */
@property (readonly, copy) NSString *messageCommand;

/**
 * @brief The value of -messageCommand as an integer
 */
@property (readonly) NSUInteger messageCommandNumeric;

/**
 * @brief The server address of the IRC network
 *
 * @discussion The value of this attribute is the address of the server that 
 *  Textual is currently connected to and may differ from senderNickname even
 *  if senderIsServer is `YES`
 */
@property (readonly, copy, nullable) NSString *networkAddress;

/**
 * @brief The name of the IRC network
 */
@property (readonly, copy, nullable) NSString *networkName;
@end

#pragma mark -

/**
 * This object is a container for values related to 
 * [THOPluginProtocol didReceiveJavaScriptPayload:fromViewController:]
 */
@interface THOPluginWebViewJavaScriptPayloadConcreteObject : NSObject
/**
 * @brief A description of the payload
 */
@property (readonly, copy) NSString *payloadLabel;

/**
 * @brief The payload contents
 */
@property (readonly, copy, nullable) id <NSCopying> payloadContents;
@end

#pragma mark -

@interface THOPluginOutputSuppressionRule : NSObject
@property (nonatomic, copy) NSString *match;
@property (nonatomic, assign) BOOL restrictConsole;
@property (nonatomic, assign) BOOL restrictChannel;
@property (nonatomic, assign) BOOL restrictPrivateMessage;
@end

NS_ASSUME_NONNULL_END
