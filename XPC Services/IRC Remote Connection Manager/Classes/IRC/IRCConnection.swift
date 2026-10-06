/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
* Copyright (c) 2018 - 2020 Codeux Software, LLC & respective contributors.
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

@objc(IRCConnection)
final class Connection: NSObject, ConnectionSocketDelegate
{
	fileprivate let config: IRCConnectionConfig

	fileprivate let socket: ConnectionSocket & ConnectionSocketProtocol

	fileprivate let serviceConnection: NSXPCConnection

	fileprivate var sendQueue: [Data] = []

	fileprivate lazy var floodControlTimer: TLOTimer =
	{
		return TLOTimer(actionBlock: { [weak self] _ in
			self?.onFloodControlTimer()
		}, on: DispatchQueue.global(qos: .default))
	}()

	fileprivate var floodControlCurrentMessageCount = 0
	fileprivate var floodControlEnforced = false

	fileprivate var workerQueue: DispatchQueue?

	fileprivate var disconnectingManually = false

	enum ConnectionError : Error
	{
		/// socketError are errors returned by the connection library.
		/// For example: GCDAsyncSocket, Network.framework, etc.
		case socket(error: Error)

		// otherError are errors returned by ConnectionSocket instances.
		case other(message: String)

		/// invalidCertificate are errors returned when the connection
		/// cannot be secured because of problem with certificate.
		case badCertificate(failureReason: String)

		/// unableToSecure are errors returned when the connection
		/// cannot be secured for some reason. e.g. handshake failure
		case unableToSecure(failureReason: String)
	} // ConnectionError

	// MARK: - Initialization

	@objc(initWithConfig:onConnection:)
	init (with config: IRCConnectionConfig, on connection: NSXPCConnection)
	{
		self.config = config

		socket = ConnectionSocket.socket(with: config)

		serviceConnection = connection

		super.init()

		socket.delegate = self
	}

	// MARK: - Grand Central Dispatch

	fileprivate func destroyWorkerDispatchQueue()
	{
		workerQueue = nil
	}

	fileprivate func createWorkerDispatchQueue()
	{
		let workerQueueName = "Textual.IRCConnection.workerQueue.\(socket.uniqueIdentifier)"

		workerQueue = DispatchQueue(label: workerQueueName)
	}

	// MARK: - Open/Close

	@objc
	final func open()
	{
		Logging.defaultSubsystem?.debug("Opening connection \(self.socket.uniqueIdentifier, privacy: .public)...")

		if (socket.disconnected == false) {
			Logging.defaultSubsystem?.error("Already connected")

			return
		}

		createWorkerDispatchQueue()

		startFloodControlTimer()

		disconnectingManually = true

		socket.open()
	}

	@objc
	final func close()
	{
		Logging.defaultSubsystem?.debug("Closing connection \(self.socket.uniqueIdentifier, privacy: .public)...")

		if (socket.disconnected) {
			Logging.defaultSubsystem?.error("Not connected")

			return
		}

		floodControlEnforced = false

		clearSendQueue()

		stopFloodControlTimer()

		disconnectingManually = true

		socket.close()
	}

	final func resetState()
	{
		/* Method invoked when a disconnect occurs. */
		/* disconnectingManually prevents us doing redundant work. */
		if (disconnectingManually) {
			disconnectingManually = false
		} else {
			floodControlEnforced = false

			clearSendQueue()

			stopFloodControlTimer()
		}

		destroyWorkerDispatchQueue()
	}

	// MARK: - Send Queue

	fileprivate var sendQueueCount: Int
	{
		var sendQueueCount = 0

		workerQueue?.sync {
			sendQueueCount = sendQueue.count
		}

		return sendQueueCount
	}

	fileprivate func nextEntryInSendQueue() -> Data?
	{
		var nextEntry: Data?

		workerQueue?.sync {
			nextEntry = sendQueue.first
		}

		return nextEntry
	}

	fileprivate func sendQueue(add data: Data)
	{
		workerQueue?.sync {
			sendQueue.append(data)
		}
	}

	fileprivate func sendQueue(remove data: Data)
	{
		workerQueue?.sync {
			if let index = sendQueue.firstIndex(of: data) {
				sendQueue.remove(at: index)
			}
		}
	}

	@objc
	final func clearSendQueue()
	{
		workerQueue?.sync {
			sendQueue.removeAll()
		}
	}

	@discardableResult
	fileprivate func tryToSend() -> Bool
	{
		if (socket.sending) {
			return false
		}

		if (sendQueueCount == 0) {
			return false
		}

		if (floodControlEnforced) {
			if (floodControlCurrentMessageCount >= config.floodControlMaximumMessages) {
				return false
			}
		}

		floodControlCurrentMessageCount += 1

		sendNextLine()

		return true
	}

	fileprivate func sendNextLine()
	{
		guard let line = nextEntryInSendQueue() else {
			return
		}

		send(line, removeFromQueue: true)
	}

	@objc(sendData:bypassQueue:)
	final func send(_ data: Data, bypassQueue: Bool = false)
	{
		if (socket.disconnected) {
			Logging.defaultSubsystem?.error("Cannot send data while disconnected")

			return
		}

		if (bypassQueue) {
			send(data, removeFromQueue: false)

			return
		}

		sendQueue(add: data)

		tryToSend()
	}

	fileprivate func send(_ data: Data, removeFromQueue: Bool = false)
	{
		if (removeFromQueue) {
			sendQueue(remove: data)
		}

		socket.write(data)
	}

	// MARK: - Flood Control

	@objc
	final func enforceFloodControl()
	{
		floodControlEnforced = true
	}

	fileprivate func startFloodControlTimer()
	{
		if (floodControlTimer.timerIsActive) {
			return
		}

		let timerInterval = Double(config.floodControlDelayInterval)

		floodControlTimer.start(timerInterval, onRepeat: true)
	}

	fileprivate func stopFloodControlTimer()
	{
		if (floodControlTimer.timerIsActive == false) {
			return
		}

		floodControlTimer.stop()
	}

	fileprivate func onFloodControlTimer()
	{
		floodControlCurrentMessageCount = 0

		while (tryToSend()) {

		}
	}

	// MARK: - Socket Proxy

	@objc(exportSecureConnectionInformation:error:)
	final func exportSecureConnectionInformation(to receiver: RCMSecureConnectionInformationCompletionBlock) throws
	{
		try socket.exportSecureConnectionInformation(to: receiver)
	}

	// MARK: - Socket Delegate

	final var remoteObjectProxy: RCMConnectionManagerClientProtocol
	{
		return serviceConnection.remoteObjectProxy as! RCMConnectionManagerClientProtocol
	}

	final func connection(_ connection: ConnectionSocket, willConnectToProxy address: String, on port: UInt16)
	{
		remoteObjectProxy.ircConnectionWillConnect(toProxy: address, port: port)
	}

	final func connection(_ connection: ConnectionSocket, willConnectTo address: String, on port: UInt16)
	{

	}

	final func connection(_ connection: ConnectionSocket, didConnectTo address: String?)
	{
		remoteObjectProxy.ircConnectionDidConnect(toHost: address)
	}

	final func connection(_ connection: ConnectionSocket, securedWith protocol: tls_protocol_version_t, cipherSuite: tls_ciphersuite_t)
	{
		remoteObjectProxy.ircConnectionDidSecureConnection(withProtocolType: `protocol`, cipherSuite: cipherSuite)
	}

	final func connection(_ connection: ConnectionSocket, requiresTrust response: @escaping (Bool) -> Void)
	{
		remoteObjectProxy.ircConnectionRequestInsecureCertificateTrust(response)
	}

	final func connectionClosedReadStream(_ connection: ConnectionSocket)
	{
		remoteObjectProxy.ircConnectionDidCloseReadStream()
	}

	final func connectionDisconnected(_ connection: ConnectionSocket)
	{
		resetState()

		remoteObjectProxy.ircConnectionDidDisconnectWithError(nil)
	}

	final func connection(_ connection: ConnectionSocket, disconnectedWith error: ConnectionError)
	{
		resetState()

		remoteObjectProxy.ircConnectionDidDisconnectWithError(error as NSError)
	}

	final func connection(_ connection: ConnectionSocket, received data: Data)
	{
		remoteObjectProxy.ircConnectionDidReceive(data)
	}

	final func connection(_ connection: ConnectionSocket, willSend data: Data)
	{
		remoteObjectProxy.ircConnectionWillSend(data)
	}

	final func connectionDidSend(_ connection: ConnectionSocket)
	{
		remoteObjectProxy.ircConnectionDidSendData()

		tryToSend()
	}
}

// MARK: - Extensions

typealias ConnectionError = Connection.ConnectionError

extension ConnectionError: CustomNSError
{
	/* Error domain and codes are defined in IRCConnectionErrors.h/m */
	static let errorDomain = ConnectionErrorDomain

	var errorCode: Int
	{
		let errorCode: ConnectionErrorCode

		switch self {
			case .socket(_):
				errorCode = .socket
			case .other(_):
				errorCode = .other
			case .badCertificate(_):
				errorCode = .badCertificate
			case .unableToSecure(_):
				errorCode = .unableToSecure
		}

		return Int(errorCode.rawValue)
	}

	var errorUserInfo: [String : Any]
	{
		var userInfo: [String : Any] = [:]

		if let errorDescription = errorDescription {
			userInfo[NSLocalizedDescriptionKey] = errorDescription
		}

		// While we don't make use of it right now, pass the original
		// error object inside the user info dictionary because at
		// a later time, we may be interested in its contents.
		if case let .socket(error) = self {
			userInfo["UnderlyingSocketError"] = error
		}

		return userInfo
	}
}

extension ConnectionError: LocalizedError
{
	var errorDescription: String?
	{
		switch self {
			case .socket(let error):
				/* The underlying socket error is almost always an NSError
				 which means we can just ask for its localized description. */
				return error.localizedDescription
			case .other(let message),
				 .badCertificate(let message),
				 .unableToSecure(let message):
				return message
		}
	}
}

fileprivate extension ConnectionSocket
{
	static func socket(with config: IRCConnectionConfig) -> ConnectionSocket & ConnectionSocketProtocol
	{
		if #available(macOS 10.14, *) {
			if (config.connectionPrefersModernSockets) {
				return ConnectionSocketNWF(with: config)
			}
		}

		return ConnectionSocketClassic(with: config)
	}
}
