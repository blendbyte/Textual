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

var ConversationTracking = {};

/* State tracking */
ConversationTracking.trackedNicknames = [];

/* Core functions */
ConversationTracking.nicknameSingleClickEventCallback = function(senderElement)
{
	/* This is called when .sender is clicked */
	var nickname = senderElement.dataset.nickname;

	/* Toggle status for nickname */
	var trackingIndex = ConversationTracking.trackedNicknames.indexOf(nickname);

	if (trackingIndex >= 0) {
		ConversationTracking.trackedNicknames.splice(trackingIndex, 1);
	} else {
		ConversationTracking.trackedNicknames.push(nickname);
	}

	/* Gather basic information */
	var documentBody = Textual.documentBodyElement();

	var plainTextLines = documentBody.querySelectorAll('div[data-line-type="privmsg"], div[data-line-type="action"]');

	/* Update all elements of the DOM matching conditions */
	for (var i = 0; i < plainTextLines.length; i++) {
		var lineSender = plainTextLines[i].querySelector(".sender");

		if (lineSender && lineSender.dataset.nickname === nickname) {
			ConversationTracking.toggleSelectionStatusForSenderElement(lineSender);
		}
	}
};

ConversationTracking.updateNicknameWithNewMessage = function(lineElement)
{
	var elementType = lineElement.dataset.lineType;

	/* We only want to target plain text messages */
	if (elementType !== "privmsg" &&
		elementType !== "action" &&
		elementType !== "notice") 
	{
		return;
	}

	var senderElement = lineElement.querySelector(".sender");

	if (senderElement) {
		/* Is this a tracked nickname? */
		var nickname = senderElement.dataset.nickname;

		if (ConversationTracking.isNicknameTracked(nickname) === false) {
			return;
		}

		/* Toggle status on for new message */
		ConversationTracking.toggleSelectionStatusForSenderElement(senderElement);
	}
};

ConversationTracking.toggleSelectionStatusForSenderElement = function(senderElement)
{
	var line = senderElement.lineContainer();

	line.classList.toggle("selectedUser");
};

/* Helper functions */
ConversationTracking.isNicknameTracked = function(nickname)
{
	if (ConversationTracking.trackedNicknames.indexOf(nickname) >= 0) {
		return true;
	} else {
		return false;
	}
};
