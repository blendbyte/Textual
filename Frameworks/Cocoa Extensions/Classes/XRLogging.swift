/* *********************************************************************
*
*           Copyright (c) 2024 Codeux Software, LLC
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

import CocoaExtensions_Private

public class Logging
{
	///
	/// Logger used for logging
	///
	/// Generally speaking, app or service will have set this
	/// very early on during initialization so while it is possible
	/// for it to be nil, it is very unlikely. Assume it's not.
	///
	public static var defaultSubsystem: Logger?

	///
	/// Set default subsystem to identifier of main bundle
	/// with category.
	///
	@inlinable
	public static func setDefaultSubsystem(toMainBundleCategory category: String)
	{
		_LogToConsoleSetDefaultSubsystemToMainBundle(category)
	}

	///
	/// Log stack trace of type in optional subsystem
	///
	@inlinable
	public static func logStackTrace(ofType type: OSLogType = .default, inSubsystem subsystem: OSLog? = nil)
	{
		_LogStackTraceOfTypeSwiftShim(type, subsystem);
	}

	///
	/// Subsystem used by Cocoa Extensions
	///
	internal static var frameworkSubsystem: Logger? =
	{
		let subsystem = _CSFrameworkInternalLogSubsystem()

		return Logger(subsystem!)
	}()
}

///
/// Proxy class for C API for setting logging subsystem
///
@objc(XRLoggingProxy)
internal class LoggingProxy : NSObject
{
	@objc
	static var defaultSubsystem: OSLog?
	{
		get {
			fatalError("Access default logging subsystem through C API")
		}
		set {
			if let newValue {
				Logging.defaultSubsystem = Logger(newValue)
			} else {
				Logging.defaultSubsystem = Logger() // Default
			}
		}
	}
}
