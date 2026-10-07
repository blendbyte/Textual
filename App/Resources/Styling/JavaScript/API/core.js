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

"use strict";

var Textual = {};

/* *********************************************************************** */
/*                              View Callbacks                             */
/* *********************************************************************** */

/*  Callbacks for each WebView in Textual. */

/*  These callbacks are limited to the context of this view. The view can represent either
    a server console, a channel, or a private message. See viewInitiated() for information
    about determining which type of view this is. */

/*  In the context of these callbacks, "client" or "associated client" is an abstract concept.
    When you create a new connection in Textual, you set it up by entering where to connect to
    and what your identity will be (nickname, username, etc.). You also choose channels to join.
    You may configure it other ways as well. Client is an encapsulation of this.
    Client is the stateful part of the connection that keeps track of everything. */

/*
    viewInitiated():

    @viewType:      Type of view: Server console, channel, or private message.
                    Possible values: "server", "channel", "query" — query = private message.
    @clientHash:    A unique identifier for the client.
    @viewHash:	    A unique identifier for the view. null for server console (use clientHash for that).
    @viewName:      Name of view: Channel name, nickname for a private message, or null for server console.
*/
Textual.viewInitiated 					= function(viewType, clientHash, viewHash, viewName) {};

Textual.messageAddedToView 				= function(lineNumber, fromBuffer) {};
Textual.messageRemovedFromView 			= function(lineNumber) {};

Textual.historyIndicatorAddedToView			= function() {};
Textual.historyIndicatorRemovedFromView 	= function() {};

Textual.topicBarValueChanged 				= function(newTopic) {};

Textual.viewFinishedLoading 					= function() {};
Textual.viewFinishedLoadingHistory				= function() {};
Textual.viewFinishedReload 						= function() {};
Textual.viewFontSizeChanged						= function(bigger) {};
Textual.viewPositionMovedToBottom				= function() {};
Textual.viewPositionMovedToHistoryIndicator 	= function() {};
Textual.viewPositionMovedToLine 				= function(lineNumber) {};
Textual.viewPositionMovedToTop 					= function() {};

/*  This function is called when one of two conditions are met:
    1. The day has changed by reaching midnight (00:00)
    2. The system clock changes

    For the second condition, Textual does not make an effort
    to compare if the day has in-fact changed. It merely passes
    the change down to the style to let it know.  */
Textual.dateChanged						= function(dayYear, dayMonth, dayDay) {};

/*  This function is not called by Textual itself, but by WebKit.
    It is appended to <body> as the function to call during onload phase.
    It is used by the newer templates to replace viewDidFinishLoading()
    as the function responsible for fading out the loading screen. */
Textual.viewBodyDidLoad					= function() {};

/* *********************************************************************** */
/*						         Appearance								   */
/* *********************************************************************** */

/*  app.appearance() can be used to determine the current appearance of Textual.
    The return value is a string. For example: "light" or "dark" */
/*  Textual.appearanceDidChange() can be used to observe changes to the appearance. */
// app.appearance(callbackFunction);

/*  A boolean entry named "Post Textual.appearanceDidChange() Notifications" must
    be added to the settings.plist file in order to enable use of this callback. */
/*  A style that has a variety for each appearance type will never receive a callback.
    Those styles will have the best variety automatically selected by Textual and the
    style will be reloaded to refresh the view. */
Textual.appearanceDidChange					= function(changedTo) {};

/* *********************************************************************** */
/*                             Event Handling                              */
/* *********************************************************************** */

/*
    handleEvent() allows a style to receive status information about
    several actions going on behind the scenes. The following event
    tokens are currently supported:

    serverConnecting                - Connecting to IRC
    serverConnected                 - Connected to IRC
    serverDisconnecting             - Disconnecting from IRC
    serverDisconnected              - Disconnected from IRC
    channelJoined                   - Channel joined
    channelParted                   — Channel parted
    channelMemberAdded              — Member added to the channel (joined)
    channelMemberRemoved            — Member removed from the channel (parted)
    nicknameChanged					— Nickname of local user (you) changed

    THESE EVENTS ARE PUSHED WHEN THEY OCCUR. When a style is reloaded,
    these events are not sent again. Use sessionStorage or some other
    means to save them if they are important.
*/

/*  A boolean entry named "Post Textual.handleEvent() Notifications" must be
    added to the settings.plist file in order to enable use of this callback. */
Textual.handleEvent                            = function(eventToken) {};

/* *********************************************************************** */
/*						Application Object								   */
/* *********************************************************************** */

/* 
    The "app" object provides a communication channel between the style and Textual.

    Functions are performed asynchronously which means a callback function is required
    to receive return values. If a callback function is required, then the callback
    function should take one argument, which is a variable defining the return value.
    The type of the return value will vary depending on what the function does.

    Example:
        app.inlineMediaEnabledForView(
            function(returnValue) {
                console.log(returnValue);
            }
        )
*/

/* 
    app.inlineMediaEnabledForView(callbackFunction)

    Is inline media enabled?

    Return: boolean
*/

/* 
    app.serverIsConnected(callbackFunction)

    Is the client connected?

    Return: boolean
*/

/* 
    app.channelIsActive(callbackFunction)

    Is the channel or private message active?

    For channel: 			Is the channel joined?
    For private message: 	Is the user online?

    Return: boolean
*/

/*
    app.serverChannelCount(callbackFunction)

    Number of channels associated with the client.

    Notice: This number includes private messages.

    Return: integer
*/

/*
    app.channelName(callbackFunction)
	
    Name of the channel, nickname for a private message, or null for server console.

    Return: nullable string
*/

/* 
    app.networkName(callbackFunction)

    Name of the network connected to.

    User configurable connection name is returned if the client isn't connected.

    Example: "freenode IRC Network" or "My Connection"

    Return: string
*/

/*
    app.serverAddress(callbackFunction)

    Address of the server connected to.

    User configurable server address is returned if the client isn't connected.

    Example: "chat.freenode.net"

    Return: string
*/

/*
    app.localUserNickname(callbackFunction)

    Nickname of the local user (you).

    Return: string
*/

/* 
    app.localUserHostmask(callbackFunction)
	
    Hostmask of the local user (you).
	
    Notice: Hostmask is not available until at least one channel is joined.
	
    Return: nullable string
*/

/* *********************************************************************** */
/*	                         Print Debug Messages                          */
/* *********************************************************************** */

// app.logToConsole(<input>)		- Log a message to the macOS system-wide console.

/*  The app.printDebugInformation* functions documented below also call messageAddedToView()
    which means calling them from within it will create an infinite loop. */

// app.printDebugInformationToConsole(message)		— Show a debug message to the user in the server console.
// app.printDebugInformation(message)				— Show a debug message to the user in this view.

/* *********************************************************************** */
/*	                            Style Settings                             */
/* *********************************************************************** */

/*
    Textual provides styles the ability to store values within a key-value store
    which is shared amongst all views. This store is saved in Textual's preference
    file and will persist even if the style is renamed, removed, or replaced.

    - Enabling:
        A string entry named "Key-value Store Name" must be added to the
        settings.plist file in order to enable use of this feature.
	
        The value of this entry is the name to save the store under.

        Preferably, this will be the name of the style, but a different name can
        be entered so that multiple varieties of a style can share the same store.

    - Notice:
        • null (not undefined) is returned when a value does not exist for a key.
        • To remove the value of a key from the store, set null as its value.
 */

// app.styleSettingsRetrieveValue(key, callbackFunction)	— Retrieve value of /key/ from the key-value store.
// app.styleSettingsSetValue(key, value, callbackFunction)	— Set /value/ to /key/ in the key-value store.

/*  This function is performed when a style setting changed. It is performed on
    all views, including the one that was responsible for changing the value. */
Textual.styleSettingDidChange                       = function(changedKey) {};

/* *********************************************************************** */
/*                          Textual Preferences                            */
/* *********************************************************************** */

/*  A boolean entry named "Post Textual.preferencesDidChange() Notifications" must
    be added to the settings.plist file in order to enable use of this callback. */
/*  This callback is rate-limit at one call per-second, per-view. */
/*  This callback exists for extremely specific use cases. In general, if you need
    something that doesn't exist above, then it's better to ask for it to be added
    and not rely on this callback. */
Textual.preferencesDidChange			= function() {};
