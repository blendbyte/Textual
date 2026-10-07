/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2018 Codeux Software, LLC & respective contributors.
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

var _ICMInlineImagePrototypeParent = InlineMediaPrototype;

var _ICMInlineImagePrototype = function() {  
	_ICMInlineImagePrototypeParent.call(this);
}

_ICMInlineImagePrototype.prototype = Object.create(InlineMediaPrototype.prototype);
_ICMInlineImagePrototype.prototype.constructor = _ICMInlineImagePrototype;
_ICMInlineImagePrototype.prototype.superClass = _ICMInlineImagePrototypeParent.prototype;

var _ICMInlineImage = new _ICMInlineImagePrototype();

_ICMInlineImagePrototype.prototype.willShowMedia = function(mediaId, mediaElement) /* PUBLIC */
{
	/* Do not allow user to show the image if this attribute is set. */
	if (mediaElement.dataset.disabled === "true") {
		return false;
	}

	return this.superClass.willShowMedia.call(this, mediaId, mediaElement);
};

_ICMInlineImagePrototype.prototype.entrypoint = function(payload, insertHTMLCallback)
{
	/* Call super to insert the HTML for us. */
	this.superClass.entrypoint.call(this, payload, insertHTMLCallback);

	/* Show the image when finishes loading. */
	this.showImageWhenLoadedWithPayload(payload);
};

_ICMInlineImagePrototype.prototype.showImageWhenLoadedWithPayload = function(payload)
{
	this.showImageWhenLoaded(payload.uniqueIdentifier);
};

_ICMInlineImagePrototype.prototype.showImageWhenLoaded = function(mediaId)
{
	var imageContainer = document.getInlineMediaById(mediaId);

	if (!imageContainer) {		
		console.error("Failed to find inline media element that matches ID: " + mediaId);

		return;
	}

	/* If the image is not already loaded, then we observe 
	changes to that so that we only reveal once it is. */
	var imageElement = imageContainer.querySelector("a .content");

	var imageComplete = imageElement.complete;

	var imageCompleteCallback = (function() {
		/* Textual doesn't decode images itself, so their size is checked
		here, once WebKit has loaded them. Images that are too large stay
		hidden and can't be shown. A maximum height of 0 means no limit. */
		if (this.imageExceedsMaximumSize(imageElement)) {
			imageContainer.dataset.disabled = "true";

			return;
		}

		if (imageContainer.dataset.disabled) {
			delete imageContainer.dataset.disabled;
		}

		imageElement.addEventListener("mousedown", InlineImageLiveResize.onMouseDown, false);

		this.show(mediaId);
	}).bind(this);

	if (imageComplete && imageElement.naturalWidth > 0) {
		imageCompleteCallback();
	} else {
		imageContainer.dataset.disabled = "true";

		imageElement.addEventListener("load", { handleEvent: imageCompleteCallback }, false);
	}
};

_ICMInlineImagePrototype.prototype.imageExceedsMaximumSize = function(imageElement)
{
	var maximumWidth = parseInt(imageElement.dataset.maximumWidth, 10);
	var maximumHeight = parseInt(imageElement.dataset.maximumHeight, 10);

	if (maximumWidth > 0 && imageElement.naturalWidth > maximumWidth) {
		return true;
	}

	if (maximumHeight > 0 && imageElement.naturalHeight > maximumHeight) {
		return true;
	}

	return false;
};

var _ICMInlineImage = new _ICMInlineImagePrototype();
