/* Defined in: "Textual.app -> Contents -> Resources -> JavaScript -> API -> core.js" */

Textual.viewBodyDidLoad = function()
{
	Textual.fadeOutLoadingScreen(1.00, 0.95);
}

Textual.messageAddedToView = function(line, fromBuffer)
{
	var element = document.getElementById("line-" + line);

	ConversationTracking.updateNicknameWithNewMessage(element);
}

Textual.nicknameSingleClicked = function(e)
{
	ConversationTracking.nicknameSingleClickEventCallback(e);
}
