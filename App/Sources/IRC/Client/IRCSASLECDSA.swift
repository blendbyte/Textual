/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

import CryptoKit
import Foundation
import Security

/* A P-256 key for SASL ECDSA-NIST256P-CHALLENGE (declared in IRCSASLECDSAPrivate.h) */
@objc(IRCSASLECDSAKey)
final class IRCSASLECDSAKey: NSObject
{
	private let privateKey: P256.Signing.PrivateKey

	private init(privateKey: P256.Signing.PrivateKey)
	{
		self.privateKey = privateKey
	}

	@objc(generatedKey)
	static func generatedKey() -> IRCSASLECDSAKey
	{
		return IRCSASLECDSAKey(privateKey: P256.Signing.PrivateKey())
	}

	/* The value kept in the Keychain: the private key's 32 bytes in base64 */
	@objc(keyWithStoredValue:)
	static func key(storedValue: String) -> IRCSASLECDSAKey?
	{
		guard let data = Data(base64Encoded: storedValue),
			  let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: data) else {
			return nil
		}

		return IRCSASLECDSAKey(privateKey: privateKey)
	}

	/* A PEM file from `openssl ecparam -genkey -name prime256v1` or ecdsatool (SEC1,
	 maybe after its EC PARAMETERS) or `openssl genpkey` (PKCS #8); not encrypted */
	@objc(keyWithPEM:)
	static func key(pem: String) -> IRCSASLECDSAKey?
	{
		for label in ["EC PRIVATE KEY", "PRIVATE KEY"] {
			guard let start = pem.range(of: "-----BEGIN \(label)-----"),
				  let end = pem.range(of: "-----END \(label)-----", range: start.upperBound..<pem.endIndex) else {
				continue
			}

			if let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: String(pem[start.lowerBound..<end.upperBound])) {
				return IRCSASLECDSAKey(privateKey: privateKey)
			}
		}

		return nil
	}

	@objc var storedValue: String
	{
		return privateKey.rawRepresentation.base64EncodedString()
	}

	/* The compressed public key in base64, as NickServ's SET PUBKEY takes it */
	@objc var publicKey: String
	{
		return privateKey.publicKey.compressedRepresentation.base64EncodedString()
	}

	/* The server's 32 random bytes are signed as they are, as a SHA-256 digest (CryptoKit
	 only signs digests it computed itself); a DER signature, nil for any other length */
	@objc(signatureForChallenge:)
	func signature(challenge: Data) -> Data?
	{
		guard challenge.count == 32 else {
			return nil
		}

		let attributes: [CFString: Any] = [
			kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
			kSecAttrKeyClass: kSecAttrKeyClassPrivate
		]

		guard let key = SecKeyCreateWithData(privateKey.x963Representation as CFData, attributes as CFDictionary, nil),
			  let signature = SecKeyCreateSignature(key, .ecdsaSignatureDigestX962SHA256, challenge as CFData, nil) else {
			return nil
		}

		return signature as Data
	}
}
