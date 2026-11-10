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

var _ICMInlineVideoPrototypeParent = InlineMediaPrototype;

var _ICMInlineVideoPrototype = function() {  
	_ICMInlineVideoPrototypeParent.call(this);
}

_ICMInlineVideoPrototype.prototype = Object.create(InlineMediaPrototype.prototype);
_ICMInlineVideoPrototype.prototype.constructor = _ICMInlineVideoPrototype;
_ICMInlineVideoPrototype.prototype.superClass = _ICMInlineVideoPrototypeParent.prototype;

var _ICMInlineVideo = new _ICMInlineVideoPrototype();

_ICMInlineVideo.metadataLoadedCallback = function()
{
	var video = event.target;

	/* Video start time */
	var startTime = parseFloat(video.dataset.start);

	if (startTime > 0.0) {
		video.currentTime = startTime;
	}

	/* Video playback speed (rate) */
	var playbackSpeed = parseFloat(video.dataset.speed);

	if (playbackSpeed !== 1.0) {
		video.playbackRate = playbackSpeed;
	}

	/* A clip that plays by itself (like a GIF) pauses while it is scrolled out of view */
	if (video.dataset.playsByItself === "true") {
		_ICMInlineVideo.clipVisibilityObserver().observe(video);
	}
};

_ICMInlineVideo._clipVisibilityObserver = null;

_ICMInlineVideo.clipVisibilityObserver = function()
{
	if (_ICMInlineVideo._clipVisibilityObserver === null) {
		_ICMInlineVideo._clipVisibilityObserver = new IntersectionObserver(function(entries) {
			entries.forEach(function(entry) {
				var clip = entry.target;

				if (entry.isIntersecting) {
					clip.play().catch(function() {});
				} else {
					clip.pause();
				}
			});
		});
	}

	return _ICMInlineVideo._clipVisibilityObserver;
};

/* Until it is played, a video loads only what shows its first frame: played,
 it switches to the address that loads the rest */
_ICMInlineVideo.playStartedCallback = function()
{
	var video = event.target;

	_ICMInlineVideo._switchToPlayAddress(video, true);
};

_ICMInlineVideo._switchToPlayAddress = function(video, play)
{
	var playSource = video.dataset.playSrc;

	if (!playSource) {
		return false;
	}

	delete video.dataset.playSrc;

	video.src = playSource;

	if (play) {
		video.play().catch(function() {});
	} else {
		video.preload = "none";
	}

	return true;
};

/* Refused by Textual (too large, wrong type, a local address) or unplayable:
 the empty player goes, the link stays */
_ICMInlineVideo.loadFailedCallback = function()
{
	var video = event.target;

	/* Its first frame needed more than may load before playing: it waits,
	 loading nothing, until played */
	if (_ICMInlineVideo._switchToPlayAddress(video, false)) {
		return;
	}

	var media = video.closest(".inlineVideo");

	if (media) {
		media.prepareForMutation();

		media.remove();
	}
};

_ICMInlineVideo.dataLoadedCallback = function()
{
	/* Loading data can change the height of the video once 
	we know what it truly will be. We therefore have to tell
	the scroller to restore the scroll position. */

	TextualScroller.restoreScrolledToBottom();
};
