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

/* Selection */
Textual.currentSelection = function() /* PUBLIC */
{
	return window.getSelection().toString();
};

Textual.clearSelection = function() /* PUBLIC */
{
	window.getSelection().empty();
};

_Textual.clearSelectionAndPreventDefault = function() /* PRIVATE */
{
	Textual.clearSelection();

	event.preventDefault();
};

_Textual.recordSelection = function() /* PRIVATE */
{
	var selectedText = Textual.currentSelection();

	appPrivate.setSelection(selectedText);
};

_Textual._selectionChangedCallback = function() /* PRIVATE */
{
	_Textual.recordSelection();
};

_Textual.copySelectionOnMouseUpEvent = function() /* PRIVATE */
{
	if (window.event.metaKey || window.event.altKey) {
		return;
	}

	appPrivate.copySelectionWhenPermitted(
	   function(returnValue) {
			if (returnValue) {
				Textual.clearSelection();
			}
	   }
	);
};

_Textual._openGenericContextualMenu = function() /* PRIVATE */
{

};

Textual.openChannelNameContextualMenu = function() /* PUBLIC */
{
	_Textual.setPolicyChannelName();
};

Textual.openURLManagementContextualMenu = function() /* PUBLIC */
{
	_Textual.setPolicyURLAddress();
};

Textual.openStandardNicknameContextualMenu = function() /* PUBLIC */
{
	_Textual.setPolicyStandardNickname();
};

Textual.openInlineNicknameContextualMenu = function() /* PUBLIC */
{
	_Textual.setPolicyInlineNickname();
};

_Textual.setPolicyStandardNickname = function() /* PRIVATE */
{
	var userNickname = event.target.dataset.nickname;

	appPrivate.setNickname(userNickname);
};

_Textual.setPolicyInlineNickname = function() /* PRIVATE */
{
	var userNickname = event.target.textContent;

	var userMode = event.target.dataset.mode;

	if (userMode && userMode.length > 0 && userNickname.indexOf(userMode) === 0) {
		appPrivate.setNickname(userNickname.substring(1));
	} else {
		appPrivate.setNickname(userNickname);
	}
};

_Textual.setPolicyURLAddress = function() /* PRIVATE */
{
	appPrivate.setURLAddress(event.target.getAttribute("href"));
};

_Textual.setPolicyChannelName = function() /* PRIVATE */
{
	appPrivate.setChannelName(event.target.textContent);
};

/* Double click actions */
Textual._nicknameDoubleClickTimer = null;

Textual.nicknameMaybeWasDoubleClicked = function(e) /* PUBLIC */
{
	if (Textual._nicknameDoubleClickTimer) {
		clearTimeout(Textual._nicknameDoubleClickTimer);

		Textual._nicknameDoubleClickTimer = null;

		Textual.nicknameDoubleClicked(e);
	} else {
		Textual._nicknameDoubleClickTimer = setTimeout(function() {
			Textual._nicknameDoubleClickTimer = null;

			Textual.nicknameSingleClicked(e);
		}, 250);
	}
};

Textual.nicknameSingleClicked = function(e) /* PUBLIC */
{
	// API does not handle this action by default...
};

Textual.channelNameDoubleClicked = function() /* PUBLIC */
{
	_Textual.clearSelectionAndPreventDefault();

	_Textual.setPolicyChannelName();

	appPrivate.channelNameDoubleClicked();
};

Textual.nicknameDoubleClicked = function() /* PUBLIC */
{
	_Textual.clearSelectionAndPreventDefault();

	_Textual.setPolicyStandardNickname();

	appPrivate.nicknameDoubleClicked();
};

Textual.inlineNicknameDoubleClicked = function() /* PUBLIC */
{
	_Textual.clearSelectionAndPreventDefault();

	_Textual.setPolicyInlineNickname();

	appPrivate.nicknameDoubleClicked();
};

/* Bind to events */
document.addEventListener("contextmenu", _Textual._openGenericContextualMenu, false);

document.addEventListener("selectionchange", _Textual._selectionChangedCallback, false);
