
// -- Sulaco -------------------------------------------------------------------

var Sulaco;

Sulaco = {
	coalesceMessages: function (line) 
	{
		var previousLine = Sulaco.getPreviousLine(line);
		var previousSender = Sulaco.getSenderNickname(previousLine);

		var sender = Sulaco.getSenderNickname(line);

		if (sender === null || previousSender === null) {
			return;
		}

		if (sender === previousSender &&
			Sulaco.getLineType(line) === 'privmsg' &&
			Sulaco.getLineType(previousLine) === 'privmsg')
		{
			line.classList.add('coalesced');

			Sulaco.getSenderElement(line).innerHTML = '';
		}
	},

	getPreviousLine: function (line)
	{
		var previousLine = line.previousElementSibling;

		if (previousLine &&
			previousLine.classList &&
			previousLine.classList.contains('line'))
		{
			return previousLine;
		}

		return null;
	},

	getLineType: function (line)
	{
		return ((line) ? line.dataset.lineType : null);
	},

	getMessage: function (line)
	{
		return ((line) ? line.querySelector('.message').textContent.trim() : null);
	},

	getSenderElement: function (line)
	{
		return ((line) ? line.querySelector('.sender') : null);
	},

	getSenderNickname: function (line)
	{
		var sender = Sulaco.getSenderElement(line);

		return ((sender) ? sender.dataset.nickname : null);
	}
};

// -- Textual ------------------------------------------------------------------

/* Defined in: "Textual.app -> Contents -> Resources -> JavaScript -> API -> core.js" */

Textual.viewBodyDidLoad = function()
{
	Textual.fadeOutLoadingScreen(1.00, 0.90);
}

Textual.messageAddedToView = function(line, fromBuffer)
{
	var element = document.getElementById("line-" + line);

	Sulaco.coalesceMessages(element);

	ConversationTracking.updateNicknameWithNewMessage(element);
}

Textual.nicknameSingleClicked = function(e)
{
	ConversationTracking.nicknameSingleClickEventCallback(e);
}
