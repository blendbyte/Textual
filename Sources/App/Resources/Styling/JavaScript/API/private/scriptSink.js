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
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.finishedLayingOutView.postMessage(null);
	} else {
		TextualScriptSink.finishedLayingOutView();
	}
};

appPrivate.setAutomaticScrollingEnabled = function(enabled)
{
	if (app.isWebKit2()) {
		TextualScroller.setAutomaticScrollingEnabled(enabled);
	} else {
		TextualScriptSink.setAutomaticScrollingEnabled(enabled);
	}
};

appPrivate.setURLAddress = function(object)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.setURLAddress.postMessage(object);
	} else {
		TextualScriptSink.setURLAddress(object);
	}
};

appPrivate.setSelection = function(object)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.setSelection.postMessage(object);
	} else {
		TextualScriptSink.setSelection(object);
	}
};

appPrivate.setChannelName = function(object)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.setChannelName.postMessage(object);
	} else {
		TextualScriptSink.setChannelName(object);
	}
};

appPrivate.setNickname = function(object)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.setNickname.postMessage(object);
	} else {
		TextualScriptSink.setNickname(object);
	}
};

appPrivate.channelNameDoubleClicked = function()
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.channelNameDoubleClicked.postMessage(null);
	} else {
		TextualScriptSink.channelNameDoubleClicked();
	}
};

appPrivate.nicknameDoubleClicked = function()
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.nicknameDoubleClicked.postMessage(null);
	} else {
		TextualScriptSink.nicknameDoubleClicked();
	}
};

appPrivate.topicBarDoubleClicked = function()
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.topicBarDoubleClicked.postMessage(null);
	} else {
		TextualScriptSink.topicBarDoubleClicked();
	}
};

appPrivate.copySelectionWhenPermitted = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.copySelectionWhenPermitted.postMessage(dataValue);
	} else {
		TextualScriptSink.copySelectionWhenPermitted(dataValue);
	}
};

appPrivate.displayContextMenu = function()
{
	window.webkit.messageHandlers.displayContextMenu.postMessage(null);
};

appPrivate.renderMessagesBefore = function(lineNumber, maximumNumberOfLines, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumber, maximumNumberOfLines]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.renderMessagesBefore.postMessage(dataValue);
	} else {
		TextualScriptSink.renderMessagesBefore(dataValue);
	}
};

appPrivate.renderMessagesAfter = function(lineNumber, maximumNumberOfLines, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumber, maximumNumberOfLines]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.renderMessagesAfter.postMessage(dataValue);
	} else {
		TextualScriptSink.renderMessagesAfter(dataValue);
	}
};

appPrivate.renderMessagesInRange = function(lineNumberAfter, lineNumberBefore, maximumNumberOfLines, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumberAfter, lineNumberBefore, maximumNumberOfLines]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.renderMessagesInRange.postMessage(dataValue);
	} else {
		TextualScriptSink.renderMessagesInRange(dataValue);
	}
};

appPrivate.renderMessageWithSiblings = function(lineNumber, numberOfLinesBefore, numberOfLinesAfter, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [lineNumber, numberOfLinesBefore, numberOfLinesAfter]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.renderMessageWithSiblings.postMessage(dataValue);
	} else {
		TextualScriptSink.renderMessageWithSiblings(dataValue);
	}
};

appPrivate.renderTemplate = function(templateName, templateAttributes, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [templateName, templateAttributes]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.renderTemplate.postMessage(dataValue);
	} else {
		TextualScriptSink.renderTemplate(dataValue);
	}
};

appPrivate.notifyJumpToLineCallback = function(lineNumber, successful, scrolledToBottom)
{
	var dataValue = {"values" : [lineNumber, successful, scrolledToBottom]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.notifyJumpToLineCallback.postMessage(dataValue);
	} else {
		TextualScriptSink.notifyJumpToLineCallback(dataValue);
	}
};

appPrivate.notifyLinesAddedToView = function(lineNumbers)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.notifyLinesAddedToView.postMessage(lineNumbers);
	} else {
		TextualScriptSink.notifyLinesAddedToView(lineNumbers);
	}
};

appPrivate.notifyLinesRemovedFromView = function(lineNumbers)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.notifyLinesRemovedFromView.postMessage(lineNumbers);
	} else {
		TextualScriptSink.notifyLinesRemovedFromView(lineNumbers);
	}
};

appPrivate.loadInlineMedia = function(address, uniqueIdentifier, lineNumber, index)
{
	var dataValue = {"values" : [address, uniqueIdentifier, lineNumber, index]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.loadInlineMedia.postMessage(dataValue);
	} else {
		TextualScriptSink.loadInlineMedia(dataValue);
	}
};

/* ************************************************** */
/*                   Public                           */
/* ************************************************** */

app.isWebKit2 = function()
{
	if (window.webkit && typeof window.webkit.messageHandlers !== "undefined") {
		return true;
	} else {
		return false;
	}
};

app.channelMemberCount = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.channelMemberCount.postMessage(dataValue);
	} else {
		TextualScriptSink.channelMemberCount(dataValue);
	}
};

app.serverChannelCount = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.serverChannelCount.postMessage(dataValue);
	} else {
		TextualScriptSink.serverChannelCount(dataValue);
	}
};

app.serverIsConnected = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.serverIsConnected.postMessage(dataValue);
	} else {
		TextualScriptSink.serverIsConnected(dataValue);
	}
};

app.channelIsActive = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.channelIsActive.postMessage(dataValue);
	} else {
		TextualScriptSink.channelIsActive(dataValue);
	}
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

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.channelName.postMessage(dataValue);
	} else {
		TextualScriptSink.channelName(dataValue);
	}
};

app.serverAddress = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.serverAddress.postMessage(dataValue);
	} else {
		TextualScriptSink.serverAddress(dataValue);
	}
};

app.networkName = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.networkName.postMessage(dataValue);
	} else {
		TextualScriptSink.networkName(dataValue);
	}
};

app.localUserNickname = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.localUserNickname.postMessage(dataValue);
	} else {
		TextualScriptSink.localUserNickname(dataValue);
	}
};

app.localUserHostmask = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.localUserHostmask.postMessage(dataValue);
	} else {
		TextualScriptSink.localUserHostmask(dataValue);
	}
};

app.logToConsole = function(message)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.logToConsole.postMessage(message);
	} else {
		TextualScriptSink.logToConsole(message);
	}
};

app.printDebugInformationToConsole = function(message)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.printDebugInformationToConsole.postMessage(message);
	} else {
		TextualScriptSink.printDebugInformationToConsole(message);
	}
};

app.printDebugInformation = function(message)
{
	if (app.isWebKit2()) {
		window.webkit.messageHandlers.printDebugInformation.postMessage(message);
	} else {
		TextualScriptSink.printDebugInformation(message);
	}
};

app.inlineMediaEnabledForView = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.inlineMediaEnabledForView.postMessage(dataValue);
	} else {
		TextualScriptSink.inlineMediaEnabledForView(dataValue);
	}
};

app.sidebarInversionIsEnabled = function(callbackFunction)
{
	console.warn("app.sidebarInversionIsEnabled() is deprecated. Use app.appearance() instead.");

	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.sidebarInversionIsEnabled.postMessage(dataValue);
	} else {
		TextualScriptSink.sidebarInversionIsEnabled(dataValue);
	}
};

app.appearance = function(callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.appearance.postMessage(dataValue);
	} else {
		TextualScriptSink.appearance(dataValue);
	}
};

app.nicknameColorStyleHash = function(nickname, nicknameColorStyle, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [nickname, nicknameColorStyle]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.nicknameColorStyleHash.postMessage(dataValue);
	} else {
		TextualScriptSink.nicknameColorStyleHash(dataValue);
	}
};

app.sendPluginPayload = function(payloadLabel, payloadContent)
{
	var dataValue = {"values" : [payloadLabel, payloadContent]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.sendPluginPayload.postMessage(dataValue);
	} else {
		TextualScriptSink.sendPluginPayload(dataValue);
	}
};

app.styleSettingsRetrieveValue = function(key, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [key]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.styleSettingsRetrieveValue.postMessage(dataValue);
	} else {
		TextualScriptSink.styleSettingsRetrieveValue(dataValue);
	}
};

app.styleSettingsSetValue = function(key, value, callbackFunction)
{
	var promiseIndex = appInternal.makePromise(callbackFunction);

	var dataValue = {"promiseIndex" : promiseIndex, "values" : [key, value]};

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.styleSettingsSetValue.postMessage(dataValue);
	} else {
		TextualScriptSink.styleSettingsSetValue(dataValue);
	}
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

	if (app.isWebKit2()) {
		window.webkit.messageHandlers.retrievePreferencesWithMethodName.postMessage(dataValue);
	} else {
		TextualScriptSink.retrievePreferencesWithMethodName(dataValue);
	}
};
