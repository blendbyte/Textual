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

/* Preview cards (ICMPreviewCard): clicking one opens its link like any link
 in the chat view, except a YouTube card's picture, which plays the video in
 Textual's player window (⌘-click still opens the link). */

var _ICMPreviewCardPrototypeParent = InlineMediaPrototype;

var _ICMPreviewCardPrototype = function() {
	_ICMPreviewCardPrototypeParent.call(this);
}

_ICMPreviewCardPrototype.prototype = Object.create(InlineMediaPrototype.prototype);
_ICMPreviewCardPrototype.prototype.constructor = _ICMPreviewCardPrototype;
_ICMPreviewCardPrototype.prototype.superClass = _ICMPreviewCardPrototypeParent.prototype;

var _ICMPreviewCard = new _ICMPreviewCardPrototype();

_ICMPreviewCard.playClicked = function(event)
{
	if (event.metaKey) {
		return true;
	}

	var card = event.currentTarget.closest(".inlinePreviewCard");

	var link = event.currentTarget.closest("a");

	if (!card || !link || !card.dataset.youtubeVideo) {
		return true;
	}

	var title = card.querySelector(".previewCardTitle");

	var startTime = parseFloat(card.dataset.youtubeStart);

	appPrivate.openVideoPlayer(card.dataset.youtubeVideo, ((startTime > 0) ? startTime : 0), link.href, ((title) ? title.textContent : ""));

	event.preventDefault();

	return false;
};

/* A page's picture fills the card's narrow column and is cropped to it. A
 wide one (a social card such as GitHub's, a site's banner) would lose its
 sides, so it is shown whole instead, centred in the column. */
_ICMPreviewCard.pageImageLoaded = function(image)
{
	if (image.naturalWidth > (image.naturalHeight * 1.3)) {
		image.parentNode.dataset.wide = "true";
	}
};
