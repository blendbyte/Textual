/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
* Copyright (c) 2018, 2019 Codeux Software, LLC & respective contributors.
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

final class ConnectionSocketClassic: ConnectionSocket, ConnectionSocketProtocol, GCDAsyncSocketDelegate
{
	fileprivate enum Tag : Int
	{
		case none = 0

		case socksProxyOpen = 10100
		case socksProxyConnect = 10200
		case socksProxyConnectReplyOne = 10300
		case socksProxyAuthenticateUser = 10500
	}

	fileprivate enum Timeout : Double
	{
		case normal = 30.0
		case none = -1.0
	}

	fileprivate let httpHeaderResponseStatusRegularExpression = "^HTTP\\/([1-2]{1})(\\.([0-2]{1}))?\\s([0-9]{3,4})\\s(.*)$"

	fileprivate var socketDelegateQueue: DispatchQueue?
	fileprivate var socketReadWriteQueue: DispatchQueue?
	fileprivate var workerQueue: DispatchQueue?

	fileprivate var connection: GCDAsyncSocket?

	fileprivate let readDelimiter = Data([0x0a]) // \n

	// MARK: - Grand Central Dispatch

	fileprivate func destroyDispatchQueues()
	{
		socketDelegateQueue = nil

		socketReadWriteQueue = nil
	}

	fileprivate func createDispatchQueues()
	{
		let socketDelegateQueueName = "Textual.ConnectionSocket.socketDelegateQueue.\(uniqueIdentifier)"

		socketDelegateQueue = DispatchQueue(label: socketDelegateQueueName)

		let socketReadWriteQueueName = "Textual.ConnectionSocket.socketReadWriteQueue.\(uniqueIdentifier)"

		socketReadWriteQueue = DispatchQueue(label: socketReadWriteQueueName)
	}

	// MARK: - Open/Close Socket

	func open()
	{
		if (disconnected == false || disconnecting) {
			return
		}

		createDispatchQueues()

		let connection = GCDAsyncSocket(delegate: self,
										delegateQueue: socketDelegateQueue,
										socketQueue: socketReadWriteQueue)

		connection.useStrictTimers = true

		switch config.addressType {
			case .v4:
				connection.isIPv6Enabled = false
			case .v6:
				connection.isIPv4Enabled = false
			default:
				connection.isIPv4PreferredOverIPv6 = false
		}

		self.connection = connection

		if (proxyConfigured) {
			/* populateSystemSocksProxy() does not assign an error for non-fatal
			 failures which means this value should be treated as optional. */
			var proxyPopulateError: String?

			if (populateSystemSocksProxy(failureReason: &proxyPopulateError) == false) {
				if let error = proxyPopulateError {
					Logging.defaultSubsystem?.error("\(error, privacy: .public)")
				}
			} else {
				let proxyAddress = config.proxyAddress!
				let proxyPort = config.proxyPort

				delegate?.connection(self, willConnectToProxy: proxyAddress, on: proxyPort)

				connect(to: proxyAddress, on: proxyPort)

				return
			}
		}

		let serverAddress = config.serverAddress
		let serverPort = config.serverPort

		delegate?.connection(self, willConnectTo: serverAddress, on: serverPort)

		connect(to: serverAddress, on: serverPort)
	}

	fileprivate func connect(to host: String, on port: UInt16)
	{
		connecting = true

		do {
			try connection?.connect(toHost: host, onPort: port, withTimeout: Timeout.normal.rawValue)
		} catch {
			let socketError = ConnectionError(socketError: error)

			close(with: socketError)
		}
	}

	func close()
	{
		if (disconnected || disconnecting) {
			return
		}

		disconnecting = true

		connection?.disconnect()
	}

	override func resetState()
	{
		super.resetState()

		connection = nil

		destroyDispatchQueues()
	}

	// MARK: - Socket Read & Write

	func write(_ data: Data)
	{
		if (connected == false || disconnecting) {
			return
		}

		/* We only allow one write a time */
		if (sending) {
			return
		}

		sending = true

		delegate?.connection(self, willSend: data)

		connection?.write(data, withTimeout: Timeout.none.rawValue, tag: Tag.none.rawValue)
	}

	func read()
	{
		if (connected == false || disconnecting) {
			return
		}

		connection?.readData(to: readDelimiter,
							 withTimeout: Timeout.none.rawValue,
							 maxLength: UInt(maximumLineLength),
							 tag: Tag.none.rawValue)
	}

	func readIn(_ data: Data)
	{
		if (disconnected || disconnecting) {
			return
		}

		/* We read until \n appears.
		 Data returned by socket will include the \n
		 and \r if it's present. We therefore trim the
		 data of \r and \n when we read it in. */
		let trimmedData = data.withoutNewlinesAtEnd

		delegate?.connection(self, received: trimmedData)
	}

	// MARK: - Properties

	final var connectedHost: String?
	{
		if (proxyInUse) {
			return nil
		}

		return connection?.connectedHost
	}

	fileprivate func beginTLSNegotiation()
	{
		if (config.connectionPrefersSecuredConnection == false) {
			return
		}

		/* This makes me cry */
		var settings:[String : NSObject] = [
			GCDAsyncSocketManuallyEvaluateTrust : NSNumber(value: true),
			GCDAsyncSocketSSLProtocolVersionMin : NSNumber(value: RCMSecureTransport.minimumDeprecatedProtocol.rawValue),
			kCFStreamSSLIsServer as String : NSNumber(value: false),
			kCFStreamSSLPeerName as String : config.serverAddress as NSString
		]

		if (config.cipherSuites != .none) {
			settings[GCDAsyncSocketSSLCipherSuites] =
				RCMSecureTransport.cipherSuites(in: config.cipherSuites, includeDeprecated:
													(config.connectionPrefersModernCiphersOnly == false)) as NSArray
		}

		if let certificate = clientSideCertificate {
			settings[kCFStreamSSLCertificates as String] = NSArray(objects: certificate.identity, certificate.certificate)

			connectedWithClientSideCertificate = true
		}

		connection?.startTLS(settings)
	}

	fileprivate func onConnect()
	{
		beginTLSNegotiation()

		connecting = false
		connected = true

		read()

		delegate?.connection(self, didConnectTo: connectedHost)
	}

	fileprivate func onSecured()
	{
		secured = true

		let protocolType = tlsNegotiatedProtocol ?? tls_protocol_version_unknown

		let cipherSuite = tlsNegotiatedCipherSuite ?? tls_ciphersuite_unknown

		delegate?.connection(self, securedWith: protocolType, cipherSuite: cipherSuite)
	}

	fileprivate func onDisconnect(with error: Error?)
	{
		defer {
			resetState()
		}

		var errorPayload: ConnectionError?

		if let alternateError = alternateDisconnectError {
			errorPayload = alternateError
		} else if let err = error {
			let nsError = err as NSError

			/* Reached maxLength of read() without a line break */
			if (nsError.domain == GCDAsyncSocketErrorDomain && nsError.code == GCDAsyncSocketError.readMaxedOutError.rawValue) {
				errorPayload = .lineTooLong
			} else if let tlsError = ConnectionError(tlsError: err) {
				errorPayload = tlsError
			} else if (err.code != errSSLClosedGraceful) {
				errorPayload = ConnectionError(socketError: err)
			}
		}

		if (errorPayload == nil) {
			delegate?.connectionDisconnected(self)
		} else {
			delegate?.connection(self, disconnectedWith: errorPayload!)
		}
	}

	// MARK: - GCDAsyncSocketDelegate

	final func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void)
	{
		tlsVerify(trust) { (underlyingResponse) in
			completionHandler(underlyingResponse)
		}
	}

	final func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16)
	{
		if (proxyInUse) {
			do {
				try openProxy()
			} catch let error as ConnectionError {
				close(with: error)
			} catch {
				fatalError("Unexpected error: \(error)")
			}

			return
		}

		onConnect()
	}

	final func socketDidCloseReadStream(_ sock: GCDAsyncSocket)
	{
		EOFReceived = true

		delegate?.connectionClosedReadStream(self)
	}

	final func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?)
	{
		onDisconnect(with: err)
	}

	final func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int)
	{
		if (proxyInUse) {
			do {
				/* proxyRead() returns true if it swallows the data such as
				 when it is talking directly to the proxy during negotiations. */
				if (try proxyRead(data, with: Tag(rawValue: tag) ?? .none)) {
					return
				}
			} catch let error as ConnectionError {
				close(with: error)

				return
			} catch {
				fatalError("Unexpected error: \(error)")
			}
		}

		readIn(data)

		read()
	}

	final func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int)
	{
		sending = false

		delegate?.connectionDidSend(self)
	}

	final func socketDidSecure(_ sock: GCDAsyncSocket)
	{
		onSecured()
	}

	// MARK: - Security

	var tlsNegotiatedProtocol: tls_protocol_version_t?
	{
		return connection?.tlsNegotiatedProtocol
	}

	var tlsNegotiatedCipherSuite: tls_ciphersuite_t?
	{
		return connection?.tlsNegotiatedCipherSuite
	}

	var tlsCertificateChainData: [Data]?
	{
		return connection?.tlsCertificateChainData
	}

	var tlsPolicyName: String?
	{
		return connection?.tlsPolicyName
	}

	// MARK: - SOCKS Proxy Support

	fileprivate var proxyConfigured: Bool
	{
		let proxyType = config.proxyType

		return (proxyType == .automatic		||
				proxyType == .socks4		||
				proxyType == .socks5		||
				proxyType == .tor			||
				proxyType == .HTTP)
	}

	fileprivate var proxyInUse: Bool
	{
		let proxyType = config.proxyType

		return (proxyType == .socks4		||
				proxyType == .socks5		||
				proxyType == .HTTP)
	}

	fileprivate var proxyCanAuthenticate: Bool
	{
		return (config.proxyUsername?.isEmpty == false &&
				config.proxyPassword?.isEmpty == false)
	}

	fileprivate func populateSystemSocksProxy(failureReason: inout String?) -> Bool
	{
		let proxyType = config.proxyType

		if (proxyType == .automatic)
		{
			/* Being unable to read proxy values is considered non-fatal
			 error which why an failure reason is never assigned. */
			guard let proxySettings = SCDynamicStoreCopyProxies(nil) as? [String : AnyObject] else {
				return false
			}

			if (proxySettings.bool(for: "SOCKSEnable") == false) {
				return false
			}

			guard let proxyHost = proxySettings.string(for: "SOCKSProxy") else {
				return false
			}

			if (proxyHost.isEmpty) {
				return false
			}

			let proxyPort = proxySettings.integer(for: "SOCKSPort")

			if (proxyPort.isValidInternetPort == false) {
				return false
			}

			var proxyPassword: String?

			let proxyUsername = proxySettings.string(for: "SOCKSUser")

			if proxyUsername?.isEmpty == false {
				let queryParameters:[CFString : CFTypeRef] = [
					kSecClass : kSecClassInternetPassword,
					kSecAttrServer : proxyHost as CFString,
					kSecAttrProtocol : kSecAttrProtocolSOCKS,
					kSecReturnData : kCFBooleanTrue,
					kSecMatchLimit : kSecMatchLimitOne
				]

				var queryResultRef: CFTypeRef?

				let queryStatus = SecItemCopyMatching(queryParameters as CFDictionary, &queryResultRef)

				if (queryStatus != noErr) {
					failureReason = "SOCKS Error: Textual encountered a problem trying to retrieve the SOCKS proxy password from System Settings"

					return false
				}

				let proxyPasswordData = queryResultRef as! Data

				proxyPassword = String(data: proxyPasswordData, encoding: .utf8)
			} // proxyUsername

			changeProxy(to: .socks5,
						at: proxyHost,
						on: UInt16(proxyPort),
						username: proxyUsername,
						password: proxyPassword)
		}
		else if (proxyType == .tor)
		{
			changeProxyToTor()
		}

		return true
	}

	fileprivate func openProxy() throws
	{
		let proxyType = config.proxyType

		switch proxyType {
			case .socks4:
				try socks4ProxyOpen()
			case .socks5:
				socks5ProxyOpen()
			case .HTTP:
				httpProxyOpen()
			default:
				return
		} // switch()
	}

	/* Boolean return value indicates whether the data was successfully
	 read as data related to the proxy. When false is returned, the data
	 is passed upstream as normal data to read. */
	fileprivate func proxyRead(_ data: Data, with tag: Tag = .none) throws -> Bool
	{
		let proxyType = config.proxyType

		switch proxyType {
			case .socks4:
				return try socks4ProxyRead(data, with: tag)
			case .socks5:
				return try socks5ProxyRead(data, with: tag)
			case .HTTP:
				return try httpProxyRead(data, with: tag)
			default:
				return false
		} // switch()
	}

	// MARK: - SOCKS4 and SOCKS5

	fileprivate func socksProxyConnect() throws
	{
		//
		// Packet layout for SOCKS4 connect:
		//
		// 	    +----+----+---------+-------------------+---------+....+----+
		// NAME | VN | CD | DSTPORT |      DSTIP        | USERID       |NULL|
		//      +----+----+---------+-------------------+---------+....+----+
		// SIZE	   1    1      2              4           variable       1
		//
		// ---------------------------------------------------------------------------
		//
		// Packet layout for SOCKS5 connect:
		//
		//      +-----+-----+-----+------+------+------+
		// NAME | VER | CMD | RSV | ATYP | ADDR | PORT |
		//      +-----+-----+-----+------+------+------+
		// SIZE |  1  |  1  |  1  |  1   | var  |  2   |
		//      +-----+-----+-----+------+------+------+
		//

		var destination = ""

		let socksVersion = config.proxyType

		if (socksVersion == .socks4) {
			guard let resolvedAddress = socks4ConnectAddress else {
				throw ConnectionError(otherError: "SOCKS4 Error: Unable to resolve an IPv4 address to connect to")
			}

			destination = resolvedAddress
		} else {
			destination = config.serverAddress
		}

		/* "...big-endian byte order is also referred to as network byte order... */
		let destinationPortBytes = config.serverPort.bigEndian.data

		/* Assemble the packet of data that will be sent */
		var packetData = Data()

		/* SOCKS version to use */
		if (socksVersion == .socks5) {
			packetData.append([0x05], count: 1)
		} else {
			packetData.append([0x04], count: 1)
		}

		/* Type of connection (the command) */
		packetData.append([0x01], count: 1)

		if (socksVersion == .socks5)
		{
			/* Reserved value that must be 0 for SOCKS5 */
			packetData.append([0x00], count: 1)

			/* The address */
			if let IPv4Bytes = destination.IPv6AddressBytes
			{
				packetData.append([0x04], count: 1)

				packetData.append(IPv4Bytes)
			}
			else if let IPv6Bytes = destination.IPv4AddressBytes
			{
				packetData.append([0x01], count: 1)

				packetData.append(IPv6Bytes)
			}
			else
			{
				packetData.append([0x03], count: 1)

				guard let addressBytes = destination.data(using: .ascii) else {
					throw ConnectionError(otherError: "SOCKS5 Error: Unable to convert address into a ASCII fragment")
				}

				let addressBytesLength = addressBytes.count

				if (addressBytesLength > UINT8_MAX) {
					throw ConnectionError(otherError: "SOCKS5 Error: Connection address length cannot exceed \(UINT8_MAX) characters")
				}

				packetData.append([UInt8(addressBytesLength)], count: 1)

				packetData.append(addressBytes)
			} // Address

			packetData.append(destinationPortBytes)
		}
		else // .socks5
		{
			packetData.append(destinationPortBytes)

			guard let addressBytes = destination.IPv4AddressBytes else {
				throw ConnectionError(otherError: "SOCKS4 Error: Unable to convert address into network bytes")
			}

			packetData.append(addressBytes)

			packetData.append([0x00], count: 1)
		}

		/* Write the packet to the socket */
		connection?.write(packetData, withTimeout: Timeout.none.rawValue, tag: Tag.socksProxyConnect.rawValue)

		//
		// Packet layout for SOCKS4 connect response:
		//
		//	    +----+----+----+----+----+----+----+----+
		// NAME | VN | CD | DSTPORT |      DSTIP        |
		//      +----+----+----+----+----+----+----+----+
		// SIZE    1    1      2              4
		//
		// Packet layout for SOCKS5 connect response:
		//
		//      +-----+-----+-----+------+------+------+
		// NAME | VER | REP | RSV | ATYP | ADDR | PORT |
		//      +-----+-----+-----+------+------+------+
		// SIZE |  1  |  1  |  1  |  1   | var  |  2   |
		//      +-----+-----+-----+------+------+------+
		//

		/* Wait for a response from the SOCKS server */
		connection?.readData(withTimeout: Timeout.normal.rawValue, tag: Tag.socksProxyConnectReplyOne.rawValue)
	}

	// MARK: - SOCKS5

	fileprivate func socks5ProxyOpen()
	{
		socks5ProxySendGreeting()
	}

	fileprivate func socks5ProxyRead(_ data: Data, with tag: Tag = .none) throws -> Bool
	{
		if (tag == .socksProxyOpen)
		{
			if (data.count != 2) {
				throw ConnectionError(otherError: "SOCKS5 Error: Server responded with a malformed packet")
			}

			let version = data[0]
			let method = data[1]

			if (version != 5) {
				throw ConnectionError(otherError: "SOCKS5 Error: Server greeting reply contained incorrect version number")
			}

			switch method {
				case 0:
					try socksProxyConnect()
				case 2:
					if (proxyCanAuthenticate) {
						try socks5ProxyUserAuthentication()
					} else {
						throw ConnectionError(otherError: "SOCKS5 Error: Server requested that we authenticate but a username and/or password is not configured")
					}
				default:
					throw ConnectionError(otherError: "SOCKS5 Error: Server requested authentication method that is not supported")
			}

			return true
		}
		else if (tag == .socksProxyConnectReplyOne)
		{
			if (data.count <= 8) { // first 4 bytes + 2 for port
				throw ConnectionError(otherError: "SOCKS5 Error: Server responded with a malformed packet")
			}

			let version = data[0]
			let reply = data[1]

			if (version == 5 && reply == 0)
			{
				onConnect()
			}
			else
			{
				switch reply {
					case 1:
						throw ConnectionError(otherError: "SOCKS5 Error: General SOCKS server failure")
					case 2:
						throw ConnectionError(otherError: "SOCKS5 Error: Connection not allowed by ruleset")
					case 3:
						throw ConnectionError(otherError: "SOCKS5 Error: Network unreachable")
					case 4:
						throw ConnectionError(otherError: "SOCKS5 Error: Host unreachable")
					case 5:
						throw ConnectionError(otherError: "SOCKS5 Error: Connection refused")
					case 6:
						throw ConnectionError(otherError: "SOCKS5 Error: Time to live (TTL) expired")
					case 7:
						throw ConnectionError(otherError: "SOCKS5 Error: Command not supported")
					case 8:
						throw ConnectionError(otherError: "SOCKS5 Error: Address type not supported")
					default:
						throw ConnectionError(otherError: "SOCKS5 Error: Unknown SOCKS error")
				}
			}

			return true
		}
		else if (tag == .socksProxyAuthenticateUser)
		{
			//
			// Server response for username/password authentication:
			//
			// field 1: version, 1 byte
			// field 2: status code, 1 byte.
			// 0x00 = success
			// any other value = failure, connection must be closed
			//

			if (data.count != 2) {
				throw ConnectionError(otherError: "SOCKS5 Error: Server responded with a malformed packet")
			}

			let status = data[1]

			if (status == 0x00) {
				try socksProxyConnect()
			} else {
				throw ConnectionError(otherError: "SOCKS5 Error: Authentication failed for unknown reason")
			}

			return true
		}

		return false /* Read not handled here */
	}

	fileprivate func socks5ProxySendGreeting()
	{
		//
		// Packet layout for SOCKS5 greeting:
		//
		//      +-----+-----------+---------+
		// NAME | VER | NMETHODS  | METHODS |
		//      +-----+-----------+---------+
		// SIZE |  1  |    1      | 1 - 255 |
		//      +-----+-----------+---------+
		//

		/* Assemble the packet of data that will be sent */
		var packetData = Data()

		if (proxyCanAuthenticate == false) {
			/* Send instructions that we are asking for version 5 of the SOCKS protocol
			 with one authentication method: anonymous access */

			packetData.append([0x05, 0x01, 0x00], count: 3)
		} else {
			/* Send instructions that we are asking for version 5 of the SOCKS protocol
			 with two authentication methods: anonymous access and password based. */

			packetData.append([0x05, 0x02, 0x00, 0x02], count: 4)
		}

		/* Write the packet to the socket */
		connection?.write(packetData, withTimeout: Timeout.none.rawValue, tag: Tag.socksProxyOpen.rawValue)

		//
		// Packet layout for SOCKS5 greeting response:
		//
		//      +-----+--------+
		// NAME | VER | METHOD |
		//      +-----+--------+
		// SIZE |  1  |   1    |
		//      +-----+--------+
		//

		/* Wait for a response from the SOCKS server */
		connection?.readData(withTimeout: Timeout.normal.rawValue, tag: Tag.socksProxyOpen.rawValue)
	}

	//
	// For username/password authentication the client's authentication request is
	//
	// field 1: version number, 1 byte (must be 0x01)
	// field 2: username length, 1 byte
	// field 3: username
	// field 4: password length, 1 byte
	// field 5: password
	//

	fileprivate func socks5ProxyUserAuthentication() throws
	{
		/* Assemble the packet of data that will be sent */
		guard let usernameData = config.proxyUsername!.data(using: .utf8) else {
			throw ConnectionError(otherError: "SOCKS5 Error: Unable to convert username into a UTF-8 fragment")
		}

		let usernameLength = usernameData.count

		if (usernameLength > UINT8_MAX) {
			throw ConnectionError(otherError: "SOCKS5 Error: Username length cannot exceed \(UINT8_MAX) characters")
		}

		guard let passwordData = config.proxyPassword!.data(using: .utf8) else {
			throw ConnectionError(otherError: "SOCKS5 Error: Unable to convert password into a UTF-8 fragment")
		}

		let passwordLength = passwordData.count

		if (passwordLength > UINT8_MAX) {
			throw ConnectionError(otherError: "SOCKS5 Error: Password length cannot exceed \(UINT8_MAX) characters")
		}

		var authData = Data(capacity: 1 + 1 + usernameLength + 1 + passwordLength)

		authData.append([0x01], count: 1)
		authData.append([UInt8(usernameLength)], count: 1)
		authData.append(usernameData)
		authData.append([UInt8(passwordLength)], count: 1)
		authData.append(passwordData)

		/* Write the packet to the socket */
		connection?.write(authData, withTimeout: Timeout.none.rawValue, tag: Tag.socksProxyAuthenticateUser.rawValue)

		/* Wait for a response from the SOCKS server */
		connection?.readData(withTimeout: Timeout.none.rawValue, tag: Tag.socksProxyAuthenticateUser.rawValue)
	}

	// MARK: - SOCKS4

	fileprivate func socks4ProxyOpen() throws
	{
		try socksProxyConnect()
	}

	fileprivate func socks4ProxyRead(_ data: Data, with tag: Tag = .none) throws -> Bool
	{
		if (tag != .socksProxyConnectReplyOne) {
			return false /* Read not handled here */
		}

		if (data.count != 8) {
			throw ConnectionError(otherError: "SOCKS4 Error: Server responded with a malformed packet")
		}

		let reply = data[1]

		switch reply {
			case 0x5a:
				onConnect()
			case 0x5b:
				throw ConnectionError(otherError: "SOCKS4 Error: Request rejected or failed")
			case 0x5c:
				throw ConnectionError(otherError: "SOCKS4 Error: Request failed because client is not running an identd (or not reachable from server)")
			case 0x5d:
				throw ConnectionError(otherError: "SOCKS4 Error: Request failed because client's identd could not confirm the user ID string in the request")
			default:
				throw ConnectionError(otherError: "SOCKS4 Error: Server replied with unknown status code")
		}

		return true
	}

	fileprivate var socks4ConnectAddress: String?
	{
		/* SOCKS4 proxies do not support anything other than IPv4 addresses
		 (unless you support SOCKS4a, which Textual does not) which means we
		 perform manual DNS lookup for SOCKS4 and rely on end-point proxy to
		 perform lookup when using other proxy types. */
		let serverAddress = config.serverAddress

		if (serverAddress.isIPv4Address) {
			return serverAddress
		} else if (serverAddress.isIPv6Address) {
			return nil
		}

		guard let resolvedAddresses = try? GCDAsyncSocket.lookupHost(serverAddress, port: config.serverPort) as? [Data] else {
			return nil
		}

		let resolvedAddress4 = resolvedAddresses.first {
			GCDAsyncSocket.isIPv4Address($0)
		}

		if (resolvedAddress4 == nil) {
			return nil
		}

		return GCDAsyncSocket.host(fromAddress: resolvedAddress4!)
	}

	// MARK: - HTTP Proxy

	fileprivate func httpProxyOpen()
	{
		let connectionAddress = config.serverAddress

		let connectionPort = config.serverPort

		var connectionAddressCombined = ""

		if (connectionAddress.isIPv6Address) {
			connectionAddressCombined = "[\(connectionAddress)]:\(connectionPort)" // IPv6 requires brackets
		} else {
			connectionAddressCombined = "\(connectionAddress):\(connectionPort)"
		}

		let connectCommand = "CONNECT \(connectionAddressCombined) HTTP/1.1\r\n\r\n"

		/* Pass the data along to the HTTP server */
		let connectCommandData = connectCommand.data(using: .ascii)

		connection?.write(connectCommandData!, withTimeout: Timeout.none.rawValue, tag: Tag.socksProxyOpen.rawValue)

		/* Read until the end of the HTTP header response */
		let responseTerminatorData = "\r\n\r\n".data(using: .ascii)

		connection?.readData(to: responseTerminatorData!, withTimeout: Timeout.normal.rawValue, tag: Tag.socksProxyOpen.rawValue)
	}

	fileprivate func httpProxyRead(_ data: Data, with tag: Tag = .none) throws -> Bool
	{
		if (tag != .socksProxyOpen) {
			return false /* Read not handled here */
		}

		/* Given data, turn it into string and perform basic validation */
		guard let dataAsString = String(data: data, encoding: .utf8) else {
			throw ConnectionError(otherError: "HTTP Error: Unable to read data")
		}

		let headerComponents = dataAsString.components(separatedBy: "\r\n")

		if (headerComponents.count <= 2) {
			throw ConnectionError(otherError: "HTTP Error: Server responded with a malformed packet")
		}

		/* Try our best to extract the status code from the response */
		let statusResponse = headerComponents[0]

		// It is possible to split the response into its components using
		// the space character but by using regular expression we are not
		// only getting the components, we are also validating its format.
		let statusResponseRegexRange = NSMakeRange(0, statusResponse.count)

		let statusResponseRegex = try! NSRegularExpression(pattern: httpHeaderResponseStatusRegularExpression, options: [])

		let statusResponseRegexResult = statusResponseRegex.firstMatch(in: statusResponse, options: [], range: statusResponseRegexRange)

		if (statusResponseRegexResult?.numberOfRanges != 6) {
			throw ConnectionError(otherError: "HTTP Error: Server responded with a malformed packet")
		}

		//
		// Index values:
		//
		// Complete Line		(0): HTTP/1.1 200 Connection established
		// Major Version		(1): 1
		// Minor Version		(2): .1
		// Minor Version		(3): 1
		// Status Code			(4): 200
		// Status Message		(5): Connection established
		//

		let statusCodeRange = statusResponseRegexResult?.range(at: 4)
		let statusCode = statusResponse.substring(with: statusCodeRange!)!

		if (Int(statusCode) == 200) {
			onConnect()
		} else {
			let statusMessageRange = statusResponseRegexResult?.range(at: 5)
			let statusMessage = statusResponse.substring(with: statusMessageRange!)!

			throw ConnectionError(otherError: "HTTP Error: HTTP proxy server returned status code \(statusCode) with the message “\(statusMessage)”")
		}

		return true
	}
}
