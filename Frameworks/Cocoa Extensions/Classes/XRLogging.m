/* *********************************************************************
 *
 *         Copyright (c) 2016 - 2020 Codeux Software, LLC
 *     Please see ACKNOWLEDGEMENT for additional information.
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
 *  * Neither the name of "Codeux Software, LLC", nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#import "XRLoggingDeprecatedPrivate.h"

NS_ASSUME_NONNULL_BEGIN

static os_log_t XRLogToConsoleDefaultSubsystem = nil;

os_log_t _Nullable _CSFrameworkInternalLogSubsystem(void)
{
	__block os_log_t subsystem = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		subsystem = os_log_create("com.codeux.frameworks.CocoaExtensions", "Framework");
	});

	return subsystem;
}

os_log_t _LogToConsoleDefaultSubsystem(void)
{
	return ((XRLogToConsoleDefaultSubsystem) ?: OS_LOG_DEFAULT);
}

void _LogToConsoleSetDefaultSubsystem(os_log_t _Nullable subsystem)
{
	XRLogToConsoleDefaultSubsystem = subsystem;

	XRLoggingProxy.defaultSubsystem = subsystem;
}

void _LogToConsoleSetDefaultSubsystemToMainBundle(NSString *category)
{
	NSCParameterAssert(category != nil);

	NSBundle *mainBundle = [NSBundle mainBundle];

	NSString *identifier = mainBundle.bundleIdentifier;

	os_log_t subsystem = os_log_create(identifier.UTF8String, category.UTF8String);

	_LogToConsoleSetDefaultSubsystem(subsystem);
}

NSString * _LogToConsoleFormattedStackTrace(NSArray<NSString *> *trace)
{
	NSCParameterAssert(trace != nil);

	return [trace componentsJoinedByString:@"\n"];
}

COCOA_EXTENSIONS_IGNORE_DEPRECATION_BEGIN
void _LogToConsoleBridged_v1(XRLoggingType type, os_log_t _Nullable subsystem, const char *file, unsigned long line, unsigned long column, const char *function, const char *message, ...)
{
	NSCParameterAssert(file != NULL);
	NSCParameterAssert(function != NULL);
	NSCParameterAssert(message != NULL);

	COCOA_EXTENSIONS_DEPRECATED_WARNING;

	va_list arguments;
	va_start(arguments, message);

	NSString *formattedMessage = [[NSString alloc] initWithFormat:@(message) arguments:arguments];

	va_end(arguments);

	[XRLoggingDeprecated logMessage:formattedMessage asType:type inSubsystem:subsystem file:@(file) line:line column:column function:@(function)];
}

void _LogStackTraceBridged_v1(XRLoggingType type, os_log_t _Nullable subsystem, NSArray<NSString *> *trace)
{
	NSCParameterAssert(trace != nil);

	COCOA_EXTENSIONS_DEPRECATED_WARNING;

	[XRLoggingDeprecated logStackTraceSymbols:trace asType:type inSubsystem:subsystem];
}
COCOA_EXTENSIONS_IGNORE_DEPRECATION_END

NS_ASSUME_NONNULL_END
