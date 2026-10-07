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

/* ************************************************** */
/*                                                    */
/* DO NOT OVERRIDE ANYTHING BELOW THIS LINE           */
/*                                                    */
/* ************************************************** */

var app = {};
var appInternal = {};
var appPrivate = {};

/* ************************************************** */
/*                   Internal                         */
/* ************************************************** */

appInternal.promiseIndex = 1;
appInternal.promisedCallbacks = {};

appInternal.promiseKept = function(promiseIndex, returnValue)
{
	/* Check to see if an array entry exists for given index. */
	var callbackFunction = appInternal.promisedCallbacks[promiseIndex];

	/* If an array entry did exist, then perform it as a function. */
	if (typeof callbackFunction !== "undefined") {
		callbackFunction(returnValue);

		delete appInternal.promisedCallbacks[promiseIndex];
	}
};

appInternal.makePromise = function(callbackFunction)
{
	/* Best to be safe about the data we take in. */
	if (appInternal.isValidCallbackFunction(callbackFunction) === false) {
		throw "Invalid callback function";
	}

	/* Insert the promise then return its index (count minus one) */
	var promiseIndex = appInternal.promiseIndex;

	appInternal.promiseIndex += 1;
	appInternal.promisedCallbacks[promiseIndex] = callbackFunction;

	return promiseIndex;
};

appInternal.isValidCallbackFunction = function(callbackFunction)
{
	if (callbackFunction && typeof callbackFunction === "function") {
		return true;
	} else {
		return false;
	}
};

/* ************************************************** */
/*                   Private                          */
/* ************************************************** */

appPrivate.finishedLayingOutView = function()
{
	window.webkit.messageHandlers.finishedLayingOutView.postMessage(null);
};

appPrivate.setAutomaticScrollingEnabled = function(enabled)
{
	TextualScroller.setAutomaticScrollingEnabled(enabled);
};

appPrivate.setURLAddress = function(object)
{
	window.webkit.messageHandlers.setURLAddress.postMessage(object);
};

appPrivate.setSelection = function(object)
{
	window.webkit.messageHandlers.setSelection.postMessage(object);
};

appPrivate.setChannelName = function(object)
{
	window.webkit.messageHandlers.setChannelName.postMessage(object);
};

appPrivate.setNickname = function(object)
{
	window.webkit.messageHandlers.setNickname.postMessage(object);
};

appPrivate.channelNameDoubleClicked = function()
{
	window.webkit.messageHandlers.channelNameDoubleClicked.postMessage(null);
};

appPrivate.nicknameDoubleClicked = function()
{
	window.webkit.messageHandlers.nicknameDoubleClicked.postMessage(null);
};

appPrivate.topicBarDoubleClicked = function()
{
	window.webkit.messageHandlers.topicBarDoubleClicked.postMessage(null);
};

appPrivate.copySelectionWhenPermitted = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.copySelectionWhenPermitted.postMessage(dataValue);
};

appPrivate.displayContextMenu = function()
{
	window.webkit.messageHandlers.displayContextMenu.postMessage(null);
};

appPrivate.renderMessagesBefore = function(lineNumber, maximumNumberOfLines, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumber, maximumNumberOfLines]};

	window.webkit.messageHandlers.renderMessagesBefore.postMessage(dataValue);
};

appPrivate.renderMessagesAfter = function(lineNumber, maximumNumberOfLines, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumber, maximumNumberOfLines]};

	window.webkit.messageHandlers.renderMessagesAfter.postMessage(dataValue);
};

appPrivate.renderMessagesInRange = function(lineNumberAfter, lineNumberBefore, maximumNumberOfLines, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumberAfter, lineNumberBefore, maximumNumberOfLines]};

	window.webkit.messageHandlers.renderMessagesInRange.postMessage(dataValue);
};

appPrivate.renderMessageWithSiblings = function(lineNumber, numberOfLinesBefore, numberOfLinesAfter, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumber, numberOfLinesBefore, numberOfLinesAfter]};

	window.webkit.messageHandlers.renderMessageWithSiblings.postMessage(dataValue);
};

appPrivate.renderTemplate = function(templateName, templateAttributes, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [templateName, templateAttributes]};

	window.webkit.messageHandlers.renderTemplate.postMessage(dataValue);
};

appPrivate.notifyJumpToLineCallback = function(lineNumber, successful, scrolledToBottom)
{
	var dataValue = {"values" : [lineNumber, successful, scrolledToBottom]};

	window.webkit.messageHandlers.notifyJumpToLineCallback.postMessage(dataValue);
};

appPrivate.notifyLinesAddedToView = function(lineNumbers)
{
	window.webkit.messageHandlers.notifyLinesAddedToView.postMessage(lineNumbers);
};

appPrivate.notifyLinesRemovedFromView = function(lineNumbers)
{
	window.webkit.messageHandlers.notifyLinesRemovedFromView.postMessage(lineNumbers);
};

appPrivate.loadInlineMedia = function(address, uniqueIdentifier, lineNumber, index)
{
	var dataValue = {"values" : [address, uniqueIdentifier, lineNumber, index]};

	window.webkit.messageHandlers.loadInlineMedia.postMessage(dataValue);
};

/* ************************************************** */
/*                   Public                           */
/* ************************************************** */

/* Always true: Textual uses only WebKit2. Kept for styles that test it. */
app.isWebKit2 = function()
{
	return true;
};

app.channelMemberCount = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.channelMemberCount.postMessage(dataValue);
};

app.serverChannelCount = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.serverChannelCount.postMessage(dataValue);
};

app.serverIsConnected = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.serverIsConnected.postMessage(dataValue);
};

app.channelIsActive = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.channelIsActive.postMessage(dataValue);
};

app.channelIsJoined = function(callbackFunction)
{
	console.warn("app.channelIsJoined() is deprecated. Use app.channelIsActive() instead.");

	app.channelIsActive(callbackFunction);
};

app.channelName = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.channelName.postMessage(dataValue);
};

app.serverAddress = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.serverAddress.postMessage(dataValue);
};

app.networkName = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.networkName.postMessage(dataValue);
};

app.localUserNickname = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.localUserNickname.postMessage(dataValue);
};

app.localUserHostmask = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.localUserHostmask.postMessage(dataValue);
};

app.logToConsole = function(message)
{
	window.webkit.messageHandlers.logToConsole.postMessage(message);
};

app.printDebugInformationToConsole = function(message)
{
	window.webkit.messageHandlers.printDebugInformationToConsole.postMessage(message);
};

app.printDebugInformation = function(message)
{
	window.webkit.messageHandlers.printDebugInformation.postMessage(message);
};

app.inlineMediaEnabledForView = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.inlineMediaEnabledForView.postMessage(dataValue);
};

app.sidebarInversionIsEnabled = function(callbackFunction)
{
	console.warn("app.sidebarInversionIsEnabled() is deprecated. Use app.appearance() instead.");

	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.sidebarInversionIsEnabled.postMessage(dataValue);
};

app.appearance = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	window.webkit.messageHandlers.appearance.postMessage(dataValue);
};

app.nicknameColorStyleHash = function(nickname, nicknameColorStyle, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [nickname, nicknameColorStyle]};

	window.webkit.messageHandlers.nicknameColorStyleHash.postMessage(dataValue);
};

app.sendPluginPayload = function(payloadLabel, payloadContent)
{
	var dataValue = {"values" : [payloadLabel, payloadContent]};

	window.webkit.messageHandlers.sendPluginPayload.postMessage(dataValue);
};

app.styleSettingsRetrieveValue = function(key, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [key]};

	window.webkit.messageHandlers.styleSettingsRetrieveValue.postMessage(dataValue);
};

app.styleSettingsSetValue = function(key, value, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [key, value]};

	window.webkit.messageHandlers.styleSettingsSetValue.postMessage(dataValue);
};

/* Reads one of these preferences (any other name is an error):
   appearance, autoAddScrollbackMark, channelViewArrangement,
   conversationTrackingIncludesUserModeSymbol, copyOnSelect, developerModeEnabled,
   disableNicknameColorHashing, displayServerMOTD, highlightCurrentNickname,
   mainWindowTransparency, memberListDisplayNoModeSymbol, removeAllFormatting,
   rightToLeftFormatting, scrollbackVisibleLimit, showDateChanges, showInlineMedia,
   showJoinLeave, themeChannelViewFontName, themeChannelViewFontPreferenceUserConfigurable,
   themeChannelViewFontSize, themeChannelViewUsesCustomScrollers, themeName,
   themeNicknameFormat, themeNicknameFormatPreferenceUserConfigurable,
   themeTimestampFormat, themeTimestampFormatPreferenceUserConfigurable */
app.retrievePreferencesWithMethodName = function(name, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [name]};

	window.webkit.messageHandlers.retrievePreferencesWithMethodName.postMessage(dataValue);
};
