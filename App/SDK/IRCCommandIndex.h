/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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

NS_ASSUME_NONNULL_BEGIN

/* Local commands are client-local commands */
typedef NS_ENUM(NSUInteger, IRCLocalCommand) {
	IRCLocalCommandAdchat = 5001,
	IRCLocalCommandAme = 5002,
	IRCLocalCommandAmsg = 5003,
	IRCLocalCommandAquote = 5095,
	IRCLocalCommandAraw = 5096,
	IRCLocalCommandAutojoin = 5101,
	IRCLocalCommandAway = 5004,
	IRCLocalCommandBack = 5105,
	IRCLocalCommandBan = 5005,
	IRCLocalCommandCap = 5006,
	IRCLocalCommandCaps = 5007,
	IRCLocalCommandChatops = 5009,
	IRCLocalCommandClear = 5010,
	IRCLocalCommandClearall = 5011,
	IRCLocalCommandClose = 5012,
	IRCLocalCommandConn = 5013,
	IRCLocalCommandCtcp = 5014,
	IRCLocalCommandCtcpreply = 5015,
	IRCLocalCommandCycle = 5016,
	IRCLocalCommandDcc = 5017,
	IRCLocalCommandDebug = 5018,
	IRCLocalCommandDefaults = 5092,
	IRCLocalCommandDehalfop = 5019,
	IRCLocalCommandDeop = 5020,
	IRCLocalCommandDevoice = 5021,
	IRCLocalCommandEcho = 5022,
	IRCLocalCommandGline = 5023,
	IRCLocalCommandGlobops = 5024,
	IRCLocalCommandGoto = 5099,
	IRCLocalCommandGzline = 5025,
	IRCLocalCommandHalfop = 5026,
	IRCLocalCommandHop = 5027,
	IRCLocalCommandIgnore = 5029,
	IRCLocalCommandInvite = 5030,
	IRCLocalCommandIson = 5100,
	IRCLocalCommandJ = 5031,
	IRCLocalCommandJoin = 5032,
	IRCLocalCommandJoinRandom = 5109,
	IRCLocalCommandKb = 5083,
	IRCLocalCommandKick = 5033,
	IRCLocalCommandKickban = 5034,
	IRCLocalCommandKill = 5035,
	IRCLocalCommandLagcheck = 5084,
	IRCLocalCommandLeave = 5036,
	IRCLocalCommandList = 5037,
	IRCLocalCommandLocops = 5039,
	IRCLocalCommandM = 5040,
	IRCLocalCommandMe = 5041,
	IRCLocalCommandMode = 5042,
	IRCLocalCommandMonitor = 5106,
	IRCLocalCommandMsg = 5043,
	IRCLocalCommandMute = 5044,
	IRCLocalCommandMylag = 5045,
	IRCLocalCommandMyversion = 5046,
	IRCLocalCommandNachat = 5047,
	IRCLocalCommandNames = 5094,
	IRCLocalCommandNick = 5048,
	IRCLocalCommandNotice = 5050,
	IRCLocalCommandNotifybubble = 5112,
	IRCLocalCommandNotifysound = 5113,
	IRCLocalCommandNotifyspeak = 5114,
	IRCLocalCommandOmsg = 5051,
	IRCLocalCommandOnotice = 5052,
	IRCLocalCommandOp = 5053,
	IRCLocalCommandPart = 5054,
	IRCLocalCommandPass = 5055,
	IRCLocalCommandQuery = 5056,
	IRCLocalCommandQuiet = 5107,
	IRCLocalCommandQuit = 5057,
	IRCLocalCommandQuote = 5058,
	IRCLocalCommandRaw = 5059,
	IRCLocalCommandRecv = 5087,
	IRCLocalCommandRejoin = 5060,
	IRCLocalCommandRemove = 5061,
	IRCLocalCommandServer = 5062,
	IRCLocalCommandSetcolor = 5103,
	IRCLocalCommandSetqueryname = 5117,
	IRCLocalCommandShun = 5063,
	IRCLocalCommandSme = 5064,
	IRCLocalCommandSmsg = 5065,
	IRCLocalCommandSslcontext = 5066,
	IRCLocalCommandT = 5067,
	IRCLocalCommandTage = 5093,
	IRCLocalCommandTempshun = 5068,
	IRCLocalCommandTimer = 5069,
	IRCLocalCommandTopic = 5070,
	IRCLocalCommandUmode = 5071,
	IRCLocalCommandUnban = 5072,
	IRCLocalCommandUnignore = 5073,
	IRCLocalCommandUnmute = 5075,
	IRCLocalCommandUnquiet = 5108,
	IRCLocalCommandVoice = 5076,
	IRCLocalCommandWallops = 5077,
	IRCLocalCommandWatch = 5097,
	IRCLocalCommandWeights = 5118,
	IRCLocalCommandWho = 5079,
	IRCLocalCommandWhois = 5080,
	IRCLocalCommandWhowas = 5081,
	IRCLocalCommandZline = 5082
};

/* Remote commands are server-side commands */
typedef NS_ENUM(NSUInteger, IRCRemoteCommand) {
	IRCRemoteCommandAdchat = 1003,
	IRCRemoteCommandAuthenticate = 1005,
	IRCRemoteCommandAway = 1050,
	IRCRemoteCommandBatch = 1054,
	IRCRemoteCommandCap = 1004,
	IRCRemoteCommandCertinfo = 1055,
	IRCRemoteCommandChatops = 1006,
	IRCRemoteCommandChghost = 1057,
	IRCRemoteCommandError = 1016,
	IRCRemoteCommandGline = 1047,
	IRCRemoteCommandGlobops = 1017,
	IRCRemoteCommandGzline = 1048,
	IRCRemoteCommandInvite = 1018,
	IRCRemoteCommandIson = 1019,
	IRCRemoteCommandJoin = 1020,
	IRCRemoteCommandKick = 1021,
	IRCRemoteCommandKill = 1022,
	IRCRemoteCommandList = 1023,
	IRCRemoteCommandLocops = 1024,
	IRCRemoteCommandMode = 1026,
	IRCRemoteCommandMonitor = 1056,
	IRCRemoteCommandNachat = 1027,
	IRCRemoteCommandNames = 1028,
	IRCRemoteCommandNick = 1029,
	IRCRemoteCommandNotice = 1030,
	IRCRemoteCommandPart = 1031,
	IRCRemoteCommandPass = 1032,
	IRCRemoteCommandPing = 1033,
	IRCRemoteCommandPong = 1034,
	IRCRemoteCommandPrivmsg = 1035,
	IRCRemoteCommandPrivmsgAction = 1002,
	IRCRemoteCommandQuit = 1036,
	IRCRemoteCommandShun = 1045,
	IRCRemoteCommandTempshun = 1046,
	IRCRemoteCommandTime = 1012,
	IRCRemoteCommandTopic = 1039,
	IRCRemoteCommandUser = 1037,
	IRCRemoteCommandWallops = 1038,
	IRCRemoteCommandWatch = 1053,
	IRCRemoteCommandWho = 1040,
	IRCRemoteCommandWhois = 1042,
	IRCRemoteCommandWhowas = 1041,
	IRCRemoteCommandZline = 1049
};

/* Controlling class */
@interface IRCCommandIndex : NSObject
+ (NSArray<NSString *> *)localCommandList;

+ (NSUInteger)indexOfRemoteCommand:(NSString *)command;
+ (NSUInteger)indexOfLocalCommand:(NSString *)command;

+ (NSUInteger)colonPositionForRemoteCommand:(NSString *)command TEXTUAL_DEPRECATED("IRCSendingMessage decides where the trailing parameter goes; this returns the position of a command's free-text parameter, or NSNotFound");

+ (nullable NSString *)syntaxForLocalCommand:(NSString *)command;
@end

NS_ASSUME_NONNULL_END
