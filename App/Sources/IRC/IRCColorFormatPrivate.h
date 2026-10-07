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

#import "TVCLogLine.h"
#import "IRCColorFormat.h"

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCChannel;

@interface NSAttributedString (IRCTextFormatterPrivate)
/* Given contextual information (client, channel, lineType), the original
 attributed string is converted to use appropriate formatting characters,
 but this method does not allow the result to exceed TXMaximumIRCBodyLength. */
/* The only valid lineType value is PRIVMSG, ACTION, or NOTICE. */
/* effectiveRange is the range of the result in the attributed string.
 Use this value to delete those characters during enumeration.  */
- (NSString *)stringFormattedForChannel:(NSString *)channelName
							   onClient:(IRCClient *)client
						   withLineType:(TVCLogLineType)lineType
						 effectiveRange:(NSRange * _Nullable)effectiveRange;
@end

@interface NSMutableAttributedString (IRCTextFormatterPrivate)
/* This method truncates self to the effective range */
- (NSString *)stringFormattedForChannel:(NSString *)channelName
							   onClient:(IRCClient *)client
						   withLineType:(TVCLogLineType)lineType;
@end

NS_ASSUME_NONNULL_END
