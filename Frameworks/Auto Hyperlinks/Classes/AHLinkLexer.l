%{
	
/*
 * The AutoHyperlinks Framework is the legal property of its developers (DEVELOPERS), 
 * whose names are listed in the copyright file included with this source distribution.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the AutoHyperlinks Framework nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ITS DEVELOPERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ITS DEVELOPERS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "AHLinkLexer.h"

%}

%{
#pragma clang diagnostic ignored "-Wunreachable-code"
%}

ccTLD           (ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cu|cv|cx|cy|cz|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|sk|sl|sm|sn|so|sr|st|sv|sy|sz|tc|td|tf|tg|th|tj|tk|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|um|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw)
sTLD            (com|edu|gov|int|mil|net|org|biz|info|name|pro)
uTLD            (aero|coop|museum|mobi|cat|jobs|travel)

TLDs            ({ccTLD}|{sTLD}|{uTLD}|arpa|local)

userAndPass     [^:@[:space:]]+(:[^:@[:space:]]+)?
singleDomain    [_[:alnum:]\x80-\xf4-]+

urlScheme		([a-z]{1})([a-z0-9\-\+\.]+)?
urlPath         \/[^[:space:]]*
urlQuery        \?.*
urlSpec         ({singleDomain}\.)+{TLDs}(:[0-9]+)?({urlPath}|{urlQuery})?
urlCSpec        {singleDomain}(\.{singleDomain})*(:[0-9]+)?({urlPath}|{urlQuery})?

ipv4address     ([0-9]{1,3}\.){3}([0-9]{1,3})
ipURL           {ipv4address}(:[0-9]+)?{urlPath}?

hex4            [0-9A-Fa-f]{1,4}
ipv6HexSeq      {hex4}?(::?{hex4}){1,7}
ipv6HexPart     ({ipv6HexSeq})|(::{ipv6HexSeq})
ipv6Address     {ipv6HexPart}({ipv4address})?
ipv6URL         \[{ipv6Address}](:[0-9]+)?{urlPath}?

userAtDomain	[^:@\/[:space:]]+\@{singleDomain}(\.{singleDomain})*
mailSpec        {userAtDomain}\.{TLDs}

jabberSpec      xmpp:{mailSpec}{urlPath}?(\?[[:alnum:]]+[;&][^[:space:]]*)?
aolIMSpec       aim:goim\?screenname=[^\ \t\n&]+(&message=.+)?
aolChatSpec     aim:gochat\?roomname=[^\ \t\n&]+
yahooIMSpecOld  (ymsgr|yahoo):sendim\?.+
yahooIMSpecNew	(ymsgr|yahoo):(\/\/)?im\?to=.+
yahooIMSpec     {yahooIMSpecOld}|{yahooIMSpecNew}
rdarSpec        (rdar|radr|radar|x-radar):\/\/(problems?\/)?[0-9]+(&[0-9]+)*
spotifySpec     spotify:(track|album|artist|search|playlist|user|radio):[^<>]+
gtalkSpec       gtalk:(chat|call|gtalk)\?jid={mailSpec}(&from_jid={mailSpec})?
myimSpec        myim:(addContact|sendIM)\?(((uID|cID)=[0-9]*&?)|(auto=(true|false)&?))+
msnSpec         msnim:(chat|add|voice|video)\?contact={mailSpec}
dictSpec		dict:{urlPath}
magnetSpec		magnet:\?xt\=urn:(bitprint|btih|ed2k|md5|sha1|tree\:tiger):([A-Fa-f0-9]{20,80})[^[:space:]]*
redditSpec		\/r\/([A-Za-z0-9])([A-Za-z0-9_]{2,20})
messageSpec		message:(\/\/)?(%3[Cc]).+(%3[Ee])

%option noyywrap nounput noinput 8bit caseless align never-interactive reentrant warn prefix="AH"

%x CANONICAL
%%

<CANONICAL>({userAndPass}@)?{urlCSpec}|{ipURL}|{ipv6URL} {	yyleng += yyextra;
														 	BEGIN INITIAL;
															return AHParserURLWithScheme; 	}

<CANONICAL>.*                                            { 	BEGIN INITIAL;
															return AHParserURLInvalid; 	}

{urlSpec}               { return AHParserURLWithoutScheme; }

{redditSpec}			{ return AHParserURLSpecialCaseReddit; }

{myimSpec}              |
{jabberSpec}            |
{gtalkSpec}             |
{aolIMSpec}             |
{aolChatSpec}           |
{yahooIMSpec}           |
{rdarSpec}              |
{msnSpec}               |
{dictSpec}				|
{magnetSpec}			|
{messageSpec}			|
{spotifySpec}           { return AHParserURLPreconfigured; }

{urlScheme}:\/\/\/?     { yyextra = yyleng; BEGIN CANONICAL; }

.                       { return AHParserURLInvalid; }
%%
