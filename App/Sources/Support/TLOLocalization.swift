/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
*    Copyright (c) 2018 Codeux Software, LLC & respective contributors.
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

///
/// Given an input string, table, and bundle; these helpers perform localization.
///
/// • "BasicLanguage" is the default localization table.
/// • The main bundle is the default localization bundle.
///
/// When the "specialKey" argument is false, the input string is not treated special.
/// It and the other arguments are handed directly to NSLocalizedString().
///
/// Textual has a unique localization system, which is enabled by setting "specialKey" to true.
/// When set to true, the input string is expected to be in the format: "<table>[<key>]"
///
/// Everything left of the first open bracket ("[") is treated as the table name.
/// Everything inside of the first open bracket ("[") and first close bracket ("]")
/// is treated as the "key" - The key is typically just a random combination of characters.
///
/// For example: "'7r2-4h' = 'Some text'"; in Common.strings is accessed with "Common[7r2-4h]"
///
/// When the key is assigned in the strings file, it is not prefaced by the table name.
///

///
/// Performs localization with a special key
///
public func LocalizedKey(_ key: String, _ arguments: CVarArg..., table: String = "BasicLanguage", bundle: Bundle = Bundle.main) -> String
{
	return localize(string: key, arguments: arguments, table: table, bundle: bundle, specialKey: true)
}

///
/// Performs localization with input string
///
public func LocalizedString(_ string: String, _ arguments: CVarArg..., table: String = "BasicLanguage", bundle: Bundle = Bundle.main) -> String
{
	return localize(string: string, arguments: arguments, table: table, bundle: bundle, specialKey: false)
}

@inline(__always)
fileprivate func localize(string: String, arguments: [CVarArg], table: String, bundle: Bundle, specialKey: Bool) -> String
{
	let formatter = String(localized: string, table: table, bundle: bundle, specialKey: specialKey)

	if (arguments.isEmpty) {
		return formatter
	}

	return String(format: formatter, arguments: arguments)
}

fileprivate extension String
{
	init (localized string: String, table: String, bundle: Bundle, specialKey: Bool)
	{
		guard specialKey,
			let openBracket = string.firstIndex(of: "["),
			let closeBracket = string.firstIndex(of: "]") else
		{
			self = bundle.localizedString(forKey: string, value: nil, table: table)

			return
		}

		/* Given keys in the format "<table>[<key>]",
		extract the two values and lookup the result. */
		let tableName = String(string[string.startIndex ..< openBracket])
		let tableKey = String(string[(string.index(openBracket, offsetBy: 1)) ..< closeBracket])

		/* Backwards compatibility for plugins */
		//
		// The format of key assignments changed in version 7.1.0.
		// In prior versions, the table name was included in the assignment.
		//
		// Assignment in 7.1.0:
		//     "7r2-4h" = "Some text";
		//
		// Assignment before 7.1.0:
		//     "Common[0001]" = "Some text";
		//
		// To support plugins that still have the old format compiled in,
		// we check whether the key we have contains a dash.
		//
		// Keys prior to version 7.0.10 /should/ not ever contain a dash.
		//
		// If a dash is present, then we use the original input string as key.
		//
		if (tableKey.contains("-")) {
			self = bundle.localizedString(forKey: tableKey, value: nil, table: tableName)
		} else {
			self = bundle.localizedString(forKey: string, value: nil, table: tableName)
		}
	}
}

//
// This extension gives TXTLS() and its sister C functions access
// to the logic needed to pluck out a localized string.
// Those functions will perform argument formatting on their end
// given the result because you can't pass arguments from C -> Swift.
//
extension NSString
{
	@objc(_swift_localizedKey:bundle:)
	class func localize(key: String, bundle: Bundle) -> NSString
	{
		return String(localized: key, table: "BasicLanguage", bundle: bundle, specialKey: true) as NSString
	}
}
