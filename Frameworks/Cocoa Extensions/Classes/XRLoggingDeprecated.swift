/* *********************************************************************
*
*        Copyright (c) 2018 - 2020 Codeux Software, LLC
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

import os.log

///
/// Logging acts as a facility for logging messages, regardless of macOS version.
/// Because it's designed to be backwards compatible, it isn't as technical savvy
/// as something such as os_log which allows much more powerful formatters.
/// At worst, assume NSLog() is used; so design the log message around that.
///
@available(*, deprecated, message: "Use OSLog instead")
@objc(XRLoggingDeprecated)
public class LoggingDeprecated : NSObject
{
	///
	/// Subsystems are favored in this order:
	///
	/// 1. "subsystem" argument of function
	/// 2. defaultSubsystem value (default = nil)
	/// 3. OSLog.default (on macOS 10.12 and later)
	///
	@objc
	public static var defaultSubsystem: OSLog?

	///
	/// Flag to enable debug log type
	///
	@objc
	public static var debugLogging = false

	@objc
	public enum `Type` : Int
	{
		case `default` = 0

		case debug = 1
		case info = 2
		case error = 3
		case fault = 4

		fileprivate var systemType:OSLogType
		{
			switch self {
				case .debug:
					return OSLogType.debug
				case .info:
					return OSLogType.info
				case .error:
					return OSLogType.error
				case .fault:
					return OSLogType.fault
				default:
					return OSLogType.default
			}
		} // systemType

		public var description: String
		{
			switch self {
				case .debug:
					return "Debug"
				case .info:
					return "Info"
				case .error:
					return "Error"
				case .fault:
					return "Fault"
				default:
					return "Default"
			}
		} // description
	}

	fileprivate struct Context
	{
		var subsystem: OSLog?
		var type: `Type` = .`default`
		var file: String
		var line: Int
		var column: Int
		var function: String
	}

	@objc(logMessage:asType:inSubsystem:file:line:column:function:)
	public static func log(_ message: String, type: `Type`, subsystem: OSLog?, file: String, line: Int, column: Int, function: String)
	{
		let context = Context(subsystem: subsystem, type: type, file: file, line: line, column: column, function: function)

		log(message, in: context)
	}

	@objc(logStackTraceSymbols:asType:inSubsystem:)
	public static func logStackTrace(trace: [String], type: `Type`, subsystem: OSLog?)
	{
		/* Details such as file, line, column, and function are useless
		 when logging symbols but so I don't have to spend a day modifying
		 the facility to accept those as optional, just give it defaults. */
		log("Current Stack: \(trace)", type: type, subsystem: subsystem, file: #file, line: #line, column: #column, function: #function)
	}

	fileprivate static func log(_ message: String, in context: Context)
	{
		let messageToLog = "\(context.function) [\(context.line):\(context.column)]: \(message)"

		let subsystem = (context.subsystem ?? defaultSubsystem ?? OSLog.default)

		/* os_log wants a StaticString (compile-time string) which we cannot offer.
		 We therefore have to use a formatter to format the already formatted string. */
		os_log("%{public}@", dso: #dsohandle, log: subsystem, type: context.type.systemType, messageToLog)
	}
}

// MARK - Convenience Functions

/// We can't use macros in Swift which is why all the extra arguments exist.
/// Unless there is a very, very, very specific to do so, don't set anything
/// after subsystem as you will just be lying to your own logs.
@available(*, deprecated, message: "Use OSLog instead")
public func LogToConsole(_ message: String, type: LoggingDeprecated.`Type` = .`default`, subsystem: OSLog? = nil, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function)
{
	LoggingDeprecated.log(message, type: type, subsystem: subsystem, file: file, line: line, column: column, function: function)
}

@available(*, deprecated, message: "Use OSLog instead")
public func LogToConsoleDebug(_ message: String, subsystem: OSLog? = nil, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function)
{
	LoggingDeprecated.log(message, type: .debug, subsystem: subsystem, file: file, line: line, column: column, function: function)
}

@available(*, deprecated, message: "Use OSLog instead")
public func LogToConsoleInfo(_ message: String, subsystem: OSLog? = nil, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function)
{
	LoggingDeprecated.log(message, type: .info, subsystem: subsystem, file: file, line: line, column: column, function: function)
}

@available(*, deprecated, message: "Use OSLog instead")
public func LogToConsoleError(_ message: String, subsystem: OSLog? = nil, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function)
{
	LoggingDeprecated.log(message, type: .error, subsystem: subsystem, file: file, line: line, column: column, function: function)
}

@available(*, deprecated, message: "Use OSLog instead")
public func LogToConsoleFault(_ message: String, subsystem: OSLog? = nil, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function)
{
	LoggingDeprecated.log(message, type: .fault, subsystem: subsystem, file: file, line: line, column: column, function: function)
}

@available(*, deprecated, message: "Use OSLog instead")
public func LogStackTrace(type: LoggingDeprecated.`Type` = .`default`, subsystem: OSLog? = nil, trace: [String] = Thread.callStackSymbols)
{
	LoggingDeprecated.logStackTrace(trace: trace, type: type, subsystem: subsystem)
}
