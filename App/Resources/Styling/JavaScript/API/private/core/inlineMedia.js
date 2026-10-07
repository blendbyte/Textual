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

"use strict";

/* ************************************************** */
/*                                                    */
/* DO NOT OVERRIDE ANYTHING BELOW THIS LINE           */
/*                                                    */
/* ************************************************** */

/* ************************************************** */
/*              Document Prototypes                   */
/* ************************************************** */

HTMLDocument.prototype.getInlineMediaById = function(mediaId) /* PUBLIC */
{
	if (mediaId.indexOf("inlineMedia-") !== 0) {
		mediaId = ("inlineMedia-" + mediaId);
	}

	return this.getElementById(mediaId);
};

HTMLDocument.prototype.getInlineMediaAnchorById = function(mediaId) /* PUBLIC */
{
	return document.body.querySelector("a[data-ilm-anchor=\"" + mediaId + "\"]");
};

/* ************************************************** */
/*                 Media Prototype                    */
/* ************************************************** */

var InlineMediaPrototype = function() {

};

InlineMediaPrototype.prototype._isSubclass = function()
{
	return (Object.getPrototypeOf(this) !== InlineMediaPrototype.prototype);
};

InlineMediaPrototype.prototype.showOnClick = function(mediaId) /* PUBLIC */
{
	this.show(mediaId);

	return false; // Do not perform navigation
};

InlineMediaPrototype.prototype.hideOnClick = function(mediaId) /* PUBLIC */
{
	this.hide(mediaId);

	return false; // Do not perform navigation
};

InlineMediaPrototype.prototype.toggleOnClick = function(mediaId) /* PUBLIC */
{
	if (this.isSafeToPerformToggle() === false) {
		console.log("Cancelled toggling inline media because of isSafeToPerformToggle() condition.");

		return true; // Perform navigation
	}

	this.toggle(mediaId);

	return false; // Do not perform navigation
};

InlineMediaPrototype.prototype.show = function(mediaId) /* PUBLIC */
{
	this.changeVisibility(mediaId, "show");
};

InlineMediaPrototype.prototype.hide = function(mediaId) /* PUBLIC */
{
	this.changeVisibility(mediaId, "hide");
};

InlineMediaPrototype.prototype.toggle = function(mediaId) /* PUBLIC */
{
	this.changeVisibility(mediaId, "toggle");
};

InlineMediaPrototype.prototype.changeVisibility = function(mediaId, display) /* PRIVATE */
{
	var mediaElement = document.getInlineMediaById(mediaId);

	/* Determine whether we will hide the media or show it */
	var displayNone;

	if (display === "hide") {
		displayNone = true;
	} else if (display === "show") {
		displayNone = false;
	} else if (display === "toggle") {
		displayNone = (	mediaElement && 
						mediaElement.style.display !== "none");
	} else {
		throw "Invalid 'display' value";
	}

	/* ********************************************* */

	/* The logic for each type of action is defined below as a
	self contained function. This makes it easier to maintain. */

	/* Remove media */
	var _changeVisibilityByRemoving = (function()
	{
		if (this.willRemoveMedia(mediaId, mediaElement) === false) {
			return;
		}

		mediaElement.remove();

		this.didRemoveMedia(mediaId);
	}).bind(this);

	/* Show media */
	var _changeVisibilityByDisplaying = (function()
	{
		if (this.willShowMedia(mediaId, mediaElement) === false) {
			return;
		}

		mediaElement.style.display = "";

		this.didShowMedia(mediaId, mediaElement);
	}).bind(this);

	/* Load media */
	var _changeVisibilityByLoading = (function()
	{
		var anchor = document.getInlineMediaAnchorById(mediaId);

		if (!anchor) {
			console.error("Failed to find inline media anchor that matches ID: " + mediaId);

			return;
		}

		if (!anchor.dataset.ilmLoading) {
			anchor.dataset.ilmLoading = "true";
		} else {
			return;
		}

		if (this.willLoadMedia(mediaId) === false) {
			return;
		}

		var address = anchor.href;

		var lineNumber = anchor.lineNumberContents();

		var index = this.indexOfMediaAnchor(anchor);

		appPrivate.loadInlineMedia(address, mediaId, lineNumber, index);
	}).bind(this);

	/* ********************************************* */

	if (displayNone) 
	{
		/* When hiding media, we remove it completely from the DOM. 
		The onclick event for toggling media will always exist in
		the anchor which means the user can shift click that to load 
		the media again if they so choose. */

		_changeVisibilityByRemoving();
	}
	else if (mediaElement)
	{
		/* If the media already exists, then we have nothing
		to do here other than set the display property. */

		_changeVisibilityByDisplaying();
	}
	else 
	{
		/* We aren't hiding the media and the media does not 
		already exist in the DOM, which means we need to fire
		off a request to load it. */

		_changeVisibilityByLoading();
	}
};

InlineMediaPrototype.prototype.isSafeToPerformToggle = function() /* PUBLIC */
{
	/* This logic is placed in a function to leave room for expansion. */

	return (window.event.shiftKey === true);
};

InlineMediaPrototype.prototype.willLoadMedia = function(mediaId) /* PUBLIC */
{
	return true;
};

InlineMediaPrototype.prototype.didLoadMedia = function(mediaId, mediaElement)
{

};

InlineMediaPrototype.prototype.didLoadMediaWithPayload = function(payload) /* PUBLIC */
{
	var mediaId = payload.uniqueIdentifier;

	this._didLoadMediaModifyAnchor(mediaId);

	var mediaElement = document.getInlineMediaById(mediaId);

	this.didLoadMedia(mediaId, mediaElement);
};

InlineMediaPrototype.prototype._didLoadMediaModifyAnchor = function(mediaId) /* PRIVATE */
{
	var anchor = document.getInlineMediaAnchorById(mediaId);

	if (!anchor) {
		console.error("Failed to find inline media anchor that matches ID: " + mediaId);

		return;
	}

	/* Modify attributes */
	if (anchor.dataset.ilmLoading) {
		delete anchor.dataset.ilmLoading;
	}

	/* Replace onclick event with one for current class */
	if (this._isSubclass()) {
		anchor.onclick = (function() {
			return this.toggleOnClick(mediaId);
		}).bind(this);
	}
};

InlineMediaPrototype.prototype.willShowMedia = function(mediaId, mediaElement) /* PUBLIC */
{
	mediaElement.prepareForMutation();

	return true;
};

InlineMediaPrototype.prototype.didShowMedia = function(mediaId, mediaElement) /* PUBLIC */
{

};

InlineMediaPrototype.prototype.willRemoveMedia = function(mediaId, mediaElement) /* PUBLIC */
{
	mediaElement.prepareForMutation();

	return true;
};

InlineMediaPrototype.prototype.didRemoveMedia = function(mediaId) /* PUBLIC */
{

};

InlineMediaPrototype.prototype.entrypoint = function(payload, insertHTMLCallback)
{
	document.prepareForMutation();

	insertHTMLCallback(payload.html);
};

InlineMediaPrototype.prototype.indexOfMedia = function(mediaId)
{
	var anchor = document.getInlineMediaAnchorById(mediaId);

	if (!anchor) {
		console.error("Failed to find inline media anchor that matches ID: " + mediaId);

		return undefined;
	}
	
	return this.indexOfMediaAnchor(anchor);
};

InlineMediaPrototype.prototype.indexOfMediaAnchor = function(anchor)
{
	var allAnchors = anchor.parentElement.getElementsByTagName("a");

	var index = Array.prototype.indexOf.call(allAnchors, anchor);

	return index;
};

/* ************************************************** */
/*                Media Public Interface              */
/* ************************************************** */

var InlineMedia = Object.create(InlineMediaPrototype.prototype);

/* ************************************************** */
/*                Media Private Interface             */
/* ************************************************** */

var _InlineMediaLoader = {};

_InlineMediaLoader._loadedStyleResources = new Array(); /* PRIVATE */
_InlineMediaLoader._loadedScriptResources = new Array(); /* PRIVATE */

_InlineMediaLoader.processPayload = function(payload) /* PRIVATE */
{
	/* Load CSS resources */
	var styleResources = payload.styleResources;

	if (Array.isArray(styleResources)) {
		for (var i = 0; i < styleResources.length; i++) {
			var file = styleResources[i];

			if (_InlineMediaLoader._loadedStyleResources.indexOf(file) < 0) {
				_InlineMediaLoader._loadedStyleResources.push(file);

				Textual.includeStyleResourceFile(file);
			}
		}
	}

	/* Load JavaScript resources */
	var scriptResources = payload.scriptResources;

	if (Array.isArray(scriptResources)) {
		for (var i = 0; i < scriptResources.length; i++) {
			var file = scriptResources[i];

			if (_InlineMediaLoader._loadedScriptResources.indexOf(file) < 0) {
				_InlineMediaLoader._loadedScriptResources.push(file);

				Textual.includeScriptResourceFile(file);
			}
		}
	}

	/* Insert HTML */
	var entrypoint = payload.entrypoint;

	if (typeof entrypoint === "string" && 
		entrypoint.length > 0 &&
		entrypoint !== "InlineMedia") /* Don't allow module to use this */
	{
		_InlineMediaLoader.ppStep2WithEntrypoint(payload);
	} else {
		_InlineMediaLoader.ppStep2WithoutEntrypoint(payload);
	}
};

_InlineMediaLoader.ppStep2WithoutEntrypoint = function(payload) /* PRIVATE */
{
	_InlineMediaLoader.ppStep3(InlineMedia, payload, null);
};

_InlineMediaLoader.ppStep2WithEntrypoint = function(payload) /* PRIVATE */
{
	var callToEntrypoint = (function(i) {
		try {
			var entrypoint = window[payload.entrypoint];
		} catch (error) {

		}

		/* If the entrypoint exists as an object already, 
		 then we call out to it and exit. */
		if (entrypoint && typeof entrypoint === "object") {
			entrypoint.entrypoint(
				payload.entrypointPayload, 

				(function(html) {
					_InlineMediaLoader.ppStep3(entrypoint, payload, html);
				})
			);

			return;
		}

		/* If the entrypoint does not exist as an object yet,
		 then we loop this function several times until it is
		 one (script resource is loading), or until we exhaust
		 the tries we are willing to take. */
		if (i === 100) { // 10 seconds
			console.error("Failed to process payload because entrypoint is not an object.");

			return;
		}

		setTimeout((function() {
			callToEntrypoint(i + 1);
		}), 100); // ms
	});

	callToEntrypoint(0);
};

_InlineMediaLoader.ppStep3 = function(entrypoint, payload, html) /* PRIVATE */
{
	/* The entrypoint function for subclasses is expected
	to call prepareForMutation() when it thinks is best.
	When the entrypoint is InlineMedia, the entrypoint 
	function is never called. We therefore call it here
	when that is the entrypoint. */
	if (entrypoint === InlineMedia) {
		document.prepareForMutation();
	}

	/* Insert HTML */
	_InlineMediaLoader.insertPayload(payload, html);

	/* Inform delegate */
	entrypoint.didLoadMediaWithPayload(payload);
};

_InlineMediaLoader.insertPayload = function(payload, html) /* PRIVATE */
{
	var lineNumber = payload.lineNumber;

	var line = document.getElementByLineNumber(lineNumber);

	if (!line) {
		console.error("Failed to find line that matches ID: " + lineNumber);

		return;
	}

	var mediaContainer = line.querySelector(".inlineMediaContainer");

	if (!mediaContainer) {
		console.warning("The template for this style appears to be missing a span with the class" +
						"'inlineMediaContainer' — please fix this to support inline media.");

		return;
	}

	/* Validate HTML */
	if (html === null) {
		html = payload.html;
	}

	if (html.length === 0) {
		console.error("HTML is empty");

		return;
	}

	/* Given index of this item, find item before that index
	to insert the HTML at, or insert at end of container. */
	var index = payload.index;

	if (index === 0) {
		/* Insert at beginning */
		mediaContainer.insertAdjacentHTML("afterbegin", html);
	} else {
		var childIndex = (index - 1);
		var childNode = null;
		var childNodes = mediaContainer.children;

		if (childNodes.length > childIndex) {
			childNode = childNodes[childIndex];
		}

		if (childNode) {
			childNode.insertAdjacentHTML("afterend", html);

			return;
		}

		/* Insert at end */
		mediaContainer.insertAdjacentHTML("beforeend", html);
	}
};
