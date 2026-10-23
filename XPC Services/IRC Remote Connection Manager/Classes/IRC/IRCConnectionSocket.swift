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

/* ConnectionSocket is subclassed to implement the connection logic.
 One subclass uses GCDAsyncSocket which isn't designed for Swift.
 To accommodate some of its features, we must have our base class
 inherit from NSObject or all hell will break loose. */
class ConnectionSocket: NSObject
{
	weak var delegate: ConnectionSocketDelegate?

	final private(set) var config: IRCConnectionConfig

	final let uniqueIdentifier: String

	var connecting = false
	var connected = false
	var connectedWithClientSideCertificate = false
	var disconnecting = false
	var disconnected: Bool
	{
		return (connecting == false && connected == false)
	}
	var secured = false
	var sending = false
	var EOFReceived = false

	var alternateDisconnectError: ConnectionError?

	final let torProxyTypeAddress = "127.0.0.1"
	final let torProxyTypePort: UInt16 = 9150

	/* IRC lines, tags included, stay under 9 KB. A server that sends
	 more than this without a line break is broken or hostile. */
	final let maximumLineLength = (64 * 1024) // 64 KiB

	init (with config: IRCConnectionConfig)
	{
		self.config = config

		uniqueIdentifier = UUID().uuidString

		super.init()
	}

	func resetState()
	{
		connecting = false
		connected = false
		connectedWithClientSideCertificate = false
		disconnecting = false
		secured = false

		sending = false

		EOFReceived = false

		alternateDisconnectError = nil
	}

	func tlsVerify(_ trust: SecTrust, response: @escaping RCMTrustResponse)
	{
		if (config.connectionShouldValidateCertificateChain == false) {
			response(true)

			return
		}

		var evaluationResult: SecTrustResultType = .invalid

		let evaluationStatus = SecTrustEvaluate(trust, &evaluationResult)

		if (evaluationStatus == errSecSuccess) {
			if (evaluationResult == .unspecified || evaluationResult == .proceed) {
				response(true)

				return
			} else if (evaluationResult == .recoverableTrustFailure) {
				delegate?.connection(self, requiresTrust: response)

				return
			}
		}

		response(false)
	}

	final var clientSideCertificate: (identity: SecIdentity, certificate: SecCertificate)?
	{
		guard let certificateDataIn = config.identityClientSideCertificate else {
			return nil
		}

		/* ====================================== */

		var keychainRef: SecKeychainItem?

		let certificateDataInRef = certificateDataIn as CFData

		var status = SecKeychainItemCopyFromPersistentReference(certificateDataInRef, &keychainRef)

		if (status != noErr) {
			Logging.defaultSubsystem?.error("Operation Failed (1): \(status, privacy: .public)")

			return nil
		}

		/* "A SecKeychainItem object for a certificate that is stored
		 in a keychain can be safely cast to a SecCertificate for use
		 with Certificate, Key, and Trust Services." */
		/* Contrary to the statement above, as stated in documentation,
		 casting was crashing. This is a workaround until that's fixed. */
		let certificateRef = unsafeBitCast(keychainRef, to: SecCertificate.self)

		/* ====================================== */

		var identityRef: SecIdentity?

		status = SecIdentityCreateWithCertificate(nil, certificateRef, &identityRef)

		if (status != noErr) {
			Logging.defaultSubsystem?.error("Operation Failed (2): \(status, privacy: .public)")

			return nil
		}

		/* ====================================== */

		return (identity: identityRef!, certificate: certificateRef)
	}

	final func changeProxy(to type: IRCConnectionProxyType = .none, at host: String? = nil, on port: UInt16 = 0, username: String? = nil, password: String? = nil)
	{
		let mutableConfig: IRCConnectionConfigMutable = config.mutableCopy() as! IRCConnectionConfigMutable

		mutableConfig.proxyAddress = host
		mutableConfig.proxyPort = port

		mutableConfig.proxyType = type

		mutableConfig.proxyUsername = username
		mutableConfig.proxyPassword = password

		config = mutableConfig
	}

	final func changeProxyToTor()
	{
		changeProxy(to: .socks5, at: torProxyTypeAddress, on: torProxyTypePort)
	}

	final func changeProxyToNone()
	{
		changeProxy()
	}
}

extension ConnectionError
{
	init (socketError: Error)
	{
		self = .socket(error: socketError)
	}

	init (otherError message: String)
	{
		self = .other(message: message)
	}

	static let lineTooLong = ConnectionError(otherError: "The server sent more than 64 KiB without a line break")

	init? (tlsError error: Error)
	{
		if (RCMSecureTransport.isTLSError(error) == false) {
			return nil
		}

		self.init(tlsError: error.code)
	}

	/// init(tlsError:) returns .unableToSecure("Unknown") for out of range error codes
	init (tlsError errorCode: Int)
	{
		if let certError = RCMSecureTransport.description(forBadCertificateErrorCode: errorCode) {
			self = .badCertificate(failureReason: certError)

			return
		}

		let tlsError = RCMSecureTransport.description(forErrorCode: errorCode)

		self = .unableToSecure(failureReason: tlsError)
	}
}

protocol ConnectionSocketDelegate: AnyObject
{
	func connection(_ connection: ConnectionSocket, willConnectToProxy address: String, on port: UInt16)
	func connection(_ connection: ConnectionSocket, willConnectTo address: String, on port: UInt16)
	func connection(_ connection: ConnectionSocket, didConnectTo address: String?) // address is nil when connecting to proxy
	func connection(_ connection: ConnectionSocket, securedWith protocol: tls_protocol_version_t, cipherSuite: tls_ciphersuite_t)
	func connection(_ connection: ConnectionSocket, requiresTrust response: @escaping (Bool) -> Void)
	func connectionClosedReadStream(_ connection: ConnectionSocket)
	func connectionDisconnected(_ connection: ConnectionSocket)
	func connection(_ connection: ConnectionSocket, disconnectedWith error: ConnectionError)
	func connection(_ connection: ConnectionSocket, received data: Data)
	func connection(_ connection: ConnectionSocket, willSend data: Data)
	func connectionDidSend(_ connection: ConnectionSocket)
}

protocol ConnectionSocketProtocol
{
	/// Logic for opening socket
	func open()

	/// Logic for closing socket
	func close()
	func close(with error: String)
	func close(with error: ConnectionError)

	/// Logic for writing data (sending)
	func write(_ data: Data)

	/// Logic for waiting for data (receiving)
	func read()

	/// Logic for reading data from socket (receiving)
	func readIn(_ data: Data)

	/// Logic for providing upstream with information
	/// about the secured connection including policy name,
	/// protocol version, cipher suite, and certificates.
	func exportSecureConnectionInformation(to receiver: RCMSecureConnectionInformationCompletionBlock) throws

	/// TLS Information
	var tlsNegotiatedProtocol: tls_protocol_version_t? { get }
	var tlsNegotiatedCipherSuite: tls_ciphersuite_t? { get }
	var tlsCertificateChainData: [Data]? { get }
	var tlsPolicyName: String? { get }
}

extension ConnectionSocketProtocol where Self: ConnectionSocket
{
	func close(with error: String)
	{
		let errorEnum = ConnectionError.other(message: error)

		close(with: errorEnum)
	}

	func close(with error: ConnectionError)
	{
		if (disconnected || disconnecting) {
			return
		}

		alternateDisconnectError = error

		close()
	}

	func exportSecureConnectionInformation(to receiver: RCMSecureConnectionInformationCompletionBlock) throws
	{
		let policyName = tlsPolicyName

		let protocolType = tlsNegotiatedProtocol ?? tls_protocol_version_unknown

		let cipherSuite = tlsNegotiatedCipherSuite ?? tls_ciphersuite_unknown

		let certificateChain = tlsCertificateChainData ?? []

		receiver(policyName, protocolType, cipherSuite, certificateChain)
	}
}
