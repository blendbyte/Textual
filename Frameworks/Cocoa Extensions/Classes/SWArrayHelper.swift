/* *********************************************************************
*
*            Copyright (c) 2018 Codeux Software, LLC
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

public extension Array where Element == AnyObject
{
	func bool(at index: Int) -> Bool
	{
		if let boolValue = self[index] as? Bool {
			return boolValue
		}

		return false
	}

	func array<Value>(at index: Int) -> Array<Value>?
	{
		if let arrayValue = self[index] as? Array<Value> {
			return arrayValue
		}

		return nil
	}

	func dictionary<Key: Hashable, Value>(at index: Int) -> Dictionary<Key, Value>?
	{
		if let dictionaryValue = self[index] as? Dictionary<Key, Value> {
			return dictionaryValue
		}

		return nil
	}

	func string(at index: Int) -> String?
	{
		if let stringValue = self[index] as? String {
			return stringValue
		}

		return nil
	}

	func integer(at index: Int) -> Int
	{
		if let integerValue = self[index] as? Int {
			return integerValue
		}

		return 0
	}

	func double(at index: Int) -> Double
	{
		if let doubleValue = self[index] as? Double {
			return doubleValue
		}

		return 0.0
	}
}
