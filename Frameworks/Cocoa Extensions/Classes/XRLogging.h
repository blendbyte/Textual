/* *********************************************************************
 *
 *         Copyright (c) 2015 - 2020 Codeux Software, LLC
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

#import <os/log.h>

NS_ASSUME_NONNULL_BEGIN

#define LogToConsoleTypeDefault 	OS_LOG_TYPE_DEFAULT
#define LogToConsoleTypeInfo 		OS_LOG_TYPE_DEBUG
#define LogToConsoleTypeDebug 		OS_LOG_TYPE_INFO
#define LogToConsoleTypeError 		OS_LOG_TYPE_ERROR
#define LogToConsoleTypeFault 		OS_LOG_TYPE_FAULT

/* LogToConsole() */
#define LogToConsole(_message, ...)	\
	LogToConsoleWithSubsystem(NULL, _message, ##__VA_ARGS__)

#define LogToConsoleWithSubsystem(_subsystem, _message, ...)	\
	_LogToConsole(LogToConsoleTypeDefault, _subsystem, _message, ##__VA_ARGS__)	\

/* LogToConsoleDebug() */
#define LogToConsoleDebug(_message, ...)	\
	LogToConsoleDebugWithSubsystem(NULL, _message, ##__VA_ARGS__)

#define LogToConsoleDebugWithSubsystem(_subsystem, _message, ...)	\
	_LogToConsole(LogToConsoleTypeDebug, _subsystem, _message, ##__VA_ARGS__)	\

/* LogToConsoleInfo() */
#define LogToConsoleInfo(_message, ...)	\
	LogToConsoleInfoWithSubsystem(NULL, _message, ##__VA_ARGS__)

#define LogToConsoleInfoWithSubsystem(_subsystem, _message, ...)	\
	_LogToConsole(LogToConsoleTypeInfo, _subsystem, _message, ##__VA_ARGS__)

/* LogToConsoleError() */
#define LogToConsoleError(_message, ...)	\
	LogToConsoleErrorWithSubsystem(NULL, _message, ##__VA_ARGS__)

#define LogToConsoleErrorWithSubsystem(_subsystem, _message, ...)	\
	_LogToConsole(LogToConsoleTypeError, _subsystem, _message, ##__VA_ARGS__)	\

/* LogToConsoleFault() */
#define LogToConsoleFault(_message, ...)	\
	LogToConsoleFaultWithSubsystem(NULL, _message, ##__VA_ARGS__)

#define LogToConsoleFaultWithSubsystem(_subsystem, _message, ...)	\
	_LogToConsole(LogToConsoleTypeFault, _subsystem, _message, ##__VA_ARGS__)	\

/* LogToConsoleDefaultSubsystem() */
#define LogToConsoleDefaultSubsystem()	\
	_LogToConsoleDefaultSubsystem()

/* LogToConsoleSetDefaultSubsystem() */
#define LogToConsoleSetDefaultSubsystem(_subsystem)		\
	_LogToConsoleSetDefaultSubsystem(_subsystem)

/* LogToConsoleSetDefaultSubsystem() */
#define LogToConsoleSetDefaultSubsystemToMainBundle(_category)		\
	_LogToConsoleSetDefaultSubsystemToMainBundle(_category)

/* LogToConsoleCurrentStackTrace() */
#define LogStackTrace() 	\
	LogStackTraceWithSubsystem(NULL);

#define LogStackTraceWithSubsystem(_subsystem) 	\
	_LogStackTrace(LogToConsoleTypeDefault, _subsystem)

#define LogStackTraceWithType(_type) 	\
	_LogStackTrace(_type, NULL)

#define LogStackTraceWithArguments(_type, _subsystem) 	\
	_LogStackTrace(_type, _subsystem)

/* Helper functions (private) */
#define _LogToConsole(_type, _subsystem, _message, ...)		\
	{	\
		os_log_t _defaultSubsystem = ((_subsystem) ?: _LogToConsoleDefaultSubsystem());	\
		os_log_with_type(_defaultSubsystem, _type, _message, ##__VA_ARGS__);	\
	}

#define _LogStackTrace(_type, _subsystem) 	\
	_LogToConsole(_type, _subsystem, "Stack trace:\n%{private}@", _LogToConsoleFormattedStackTrace([NSThread callStackSymbols]))

os_log_t _LogToConsoleDefaultSubsystem(void);
void _LogToConsoleSetDefaultSubsystem(os_log_t _Nullable subsystem);
void _LogToConsoleSetDefaultSubsystemToMainBundle(NSString *category);
NSString * _LogToConsoleFormattedStackTrace(NSArray<NSString *> *trace);

NS_ASSUME_NONNULL_END
