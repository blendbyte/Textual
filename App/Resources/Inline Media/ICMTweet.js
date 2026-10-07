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

window.twttr = (function() { /* cancer */
	var t = window.twttr;

	if (t) {
		return t;
	}

	t = {};

	t._e = [];

	t.ready = function(f) {
		t._e.push(f);
	};

	return t;
}());

var _ICMTweetPrototypeParent = _ICMInlineHTMLPrototype;

var _ICMTweetPrototype = function() {
	_ICMTweetPrototypeParent.call(this);
}

_ICMTweetPrototype.prototype = Object.create(_ICMInlineHTMLPrototype.prototype);
_ICMTweetPrototype.prototype.constructor = _ICMTweetPrototype;
_ICMTweetPrototype.prototype.superClass = _ICMTweetPrototypeParent.prototype;

_ICMTweetPrototype.prototype.didLoadMedia = function(mediaId, mediaElement)
{
	/* We do not have enough context in the module itself to set 
	the appearance of it, but we do once we reach the entrypoint. */
	var themeAppearance = document.body.dataset.appearance;

	if (themeAppearance === "dark") {
		var tweet = mediaElement.querySelector("blockquote.twitter-tweet");

		tweet.dataset.theme = "dark";
	}

	twttr.widgets.load(mediaElement);
};

_ICMTweetPrototype.prototype.tweetRendered = function(event)
{
	TextualScroller.restoreScrolledToBottom();
};

var _ICMTweet = null;

twttr.ready(
	function(twttr) {
		_ICMTweet = new _ICMTweetPrototype();

		twttr.events.bind("rendered", _ICMTweet.tweetRendered);
	}
);
