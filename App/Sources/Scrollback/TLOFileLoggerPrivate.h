/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

NS_ASSUME_NONNULL_BEGIN

@class IRCClient, IRCChannel, IRCTreeItem, TVCLogLine;

TEXTUAL_EXTERN NSString * const TLOFileLoggerConsoleDirectoryName;
TEXTUAL_EXTERN NSString * const TLOFileLoggerChannelDirectoryName;
TEXTUAL_EXTERN NSString * const TLOFileLoggerPrivateMessageDirectoryName;

TEXTUAL_EXTERN NSString * const TLOFileLoggerUndefinedNicknameFormat;
TEXTUAL_EXTERN NSString * const TLOFileLoggerActionNicknameFormat;
TEXTUAL_EXTERN NSString * const TLOFileLoggerNoticeNicknameFormat;

TEXTUAL_EXTERN NSString * const TLOFileLoggerISOStandardClockFormat;

@interface TLOFileLogger : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithClient:(IRCClient *)client NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithChannel:(IRCChannel *)channel NS_DESIGNATED_INITIALIZER;

- (void)open;
- (void)reopen;
- (void)reopenIfNeeded;
- (void)close;

- (void)reset; // does nothing if file isn't open

- (void)writeLogLine:(TVCLogLine *)logLine;
- (void)writePlainText:(NSString *)string;

#pragma mark -
#pragma mark Paths

/* All path information is nullable because path information
 is not cached until log file is opened */

/* File path is the path to the log file for the day */
/* At the time of a write after midnight, this path can be to a
 log file for the previous date. TLOFileLogger will correct that
 before writing. Be aware this is the case though if you access
 this property after midnight and before another write occurs.
 Unless a specific reason is needed to access this property,
 it may be better to use -writePath instead. */
@property (readonly, copy, nullable) NSString *filePath;

/* The last path component (file name) of file path */
@property (readonly, copy, nullable) NSString *fileName;

/* Write path is the path to the folder in which log files
 for the channel or client are written to. */
@property (readonly, copy, nullable) NSString *writePath;

/* -writePathForItem: only returns nil when there is no
 log location configured in Preferences. */
+ (nullable NSString *)writePathForItem:(IRCTreeItem *)item;
@end

NS_ASSUME_NONNULL_END
