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

import Foundation

/// One IRC connection: the send queue, flood control and the socket.
/// Everything runs on `queue`, the connection's only queue; the delegate
/// (IRCConnection) is called on the main queue, in order.
@objc(IRCConnectionTransport)
public final class ConnectionTransport: NSObject, ConnectionSocketDelegate
{
	fileprivate let config: IRCConnectionConfig

	fileprivate let queue: DispatchQueue

	fileprivate let socket: ConnectionSocket & ConnectionSocketProtocol

	fileprivate weak var delegate: IRCConnectionTransportDelegate?

	fileprivate var sendQueue: [Data] = []

	fileprivate lazy var floodControlTimer: TLOTimer =
	{
		return TLOTimer(actionBlock: { [weak self] _ in
			self?.onFloodControlTimer()
		}, on: queue)
	}()

	/// Lines given to the main queue and not worked through yet. A server
	/// sending faster than that is held back by no longer reading from it.
	fileprivate var linesOnMainQueue = 0

	fileprivate var readingPaused = false

	fileprivate let linesOnMainQueueHighWater = 5000

	fileprivate let linesOnMainQueueLowWater = 1000

	/// When the client batch being written began: nothing goes in between
	fileprivate var clientBatchStartDate: Date?

	/// A PONG waits at most this long for a batch to end: late is a disconnect
	fileprivate let maximumPongHoldInterval: TimeInterval = 10

	fileprivate var floodControlCurrentMessageCount = 0
	fileprivate var floodControlEnforced = false

	/// Gives up on a connection (including the TLS handshake) that isn't
	/// ready after this long; paused while the user decides on a certificate
	fileprivate let connectTimeout: TimeInterval = 30

	fileprivate var connectTimeoutWorkItem: DispatchWorkItem?

	enum ConnectionError : Error
	{
		/// socketError are errors returned by the connection library.
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

	@objc(initWithConfig:delegate:)
	public init (with config: IRCConnectionConfig, delegate: IRCConnectionTransportDelegate)
	{
		self.config = config

		self.delegate = delegate

		let socket = ConnectionSocketNWF(with: config)

		queue = DispatchQueue(label: "Textual.IRCConnection.\(socket.uniqueIdentifier)")

		socket.queue = queue

		self.socket = socket

		super.init()

		socket.delegate = self
	}

	// MARK: - Delegate

	/// Calls the delegate on the main queue
	fileprivate func notifyDelegate(_ block: @escaping (IRCConnectionTransportDelegate) -> Void)
	{
		DispatchQueue.main.async { [weak self] in
			guard let delegate = self?.delegate else {
				return
			}

			block(delegate)
		}
	}

	// MARK: - Open/Close

	@objc
	final func open()
	{
		queue.async {
			Logging.defaultSubsystem?.debug("Opening connection \(self.socket.uniqueIdentifier, privacy: .public)...")

			if (self.socket.disconnected == false) {
				Logging.defaultSubsystem?.error("Already connected")

				return
			}

			/* Never without the proxy that was asked for */
			if (ProxySettings.addressIsMissing(type: self.config.proxyType, address: self.config.proxyAddress, port: self.config.proxyPort)) {
				let error = ConnectionError(otherError: LocalizedString("Proxy without an address", table: "CommonErrors")) as NSError

				self.notifyDelegate { $0.ircConnectionDidDisconnectWithError(error) }

				return
			}

			self.startFloodControlTimer()

			self.startConnectTimeout()

			self.socket.open()
		}
	}

	@objc
	final func close()
	{
		queue.async {
			Logging.defaultSubsystem?.debug("Closing connection \(self.socket.uniqueIdentifier, privacy: .public)...")

			if (self.socket.disconnected) {
				Logging.defaultSubsystem?.error("Not connected")

				return
			}

			self.socket.close()
		}
	}

	/// Called on every disconnect, requested or not
	fileprivate func resetState()
	{
		floodControlEnforced = false

		floodControlCurrentMessageCount = 0

		sendQueue.removeAll()

		clientBatchStartDate = nil

		linesOnMainQueue = 0

		readingPaused = false

		stopFloodControlTimer()

		cancelConnectTimeout()
	}

	// MARK: - Connect Timeout

	fileprivate func startConnectTimeout()
	{
		cancelConnectTimeout()

		let workItem = DispatchWorkItem { [weak self] in
			guard let self = self else {
				return
			}

			if (self.socket.connected) {
				return
			}

			Logging.defaultSubsystem?.error("Connection \(self.socket.uniqueIdentifier, privacy: .public) timed out")

			self.socket.close(with: ConnectionError(otherError: LocalizedString("Connection timed out", table: "CommonErrors")))
		}

		connectTimeoutWorkItem = workItem

		queue.asyncAfter(deadline: .now() + connectTimeout, execute: workItem)
	}

	fileprivate func cancelConnectTimeout()
	{
		connectTimeoutWorkItem?.cancel()

		connectTimeoutWorkItem = nil
	}

	// MARK: - Send Queue

	@objc
	final func clearSendQueue()
	{
		queue.async {
			self.sendQueue.removeAll()

			self.clientBatchStartDate = nil
		}
	}

	fileprivate func lineIsPong(_ line: Data) -> Bool
	{
		return line.starts(with: Array("PONG".utf8))
	}

	/// Whether a line, after any tags, starts with this text
	fileprivate func line(_ line: Data, startsWith text: String) -> Bool
	{
		var command = line[line.startIndex...]

		if (command.first == UInt8(ascii: "@")) {
			guard let space = command.firstIndex(of: UInt8(ascii: " ")) else {
				return false
			}

			command = command[command.index(after: space)...]
		}

		return command.starts(with: Array(text.utf8))
	}

	/// Where a PONG goes: first, or right after a client batch being written
	/// (one in the middle of it is a protocol error), for a limited time
	fileprivate var pongInsertionIndex: Int
	{
		guard let startDate = clientBatchStartDate, Date().timeIntervalSince(startDate) < maximumPongHoldInterval else {
			return 0
		}

		if let batchEnd = sendQueue.firstIndex(where: { line($0, startsWith: "BATCH -") }) {
			return (batchEnd + 1)
		}

		return sendQueue.count
	}

	/// Writes the next line if the socket is free and flood control allows it.
	/// A PONG ignores the limit, whenever it gets to the head of the queue.
	@discardableResult
	fileprivate func tryToSend() -> Bool
	{
		if (socket.sending || socket.connected == false) {
			return false
		}

		guard let line = sendQueue.first else {
			return false
		}

		if (floodControlEnforced && lineIsPong(line) == false) {
			if (floodControlCurrentMessageCount >= config.floodControlMaximumMessages) {
				return false
			}
		}

		floodControlCurrentMessageCount += 1

		sendQueue.removeFirst()

		if (self.line(line, startsWith: "BATCH +")) {
			clientBatchStartDate = Date()
		} else if (self.line(line, startsWith: "BATCH -")) {
			clientBatchStartDate = nil
		}

		socket.write(line)

		return true
	}

	@objc(sendData:priority:)
	final func send(_ data: Data, priority: Bool)
	{
		queue.async {
			if (self.socket.disconnected) {
				Logging.defaultSubsystem?.error("Cannot send data while disconnected")

				return
			}

			if (priority) {
				/* One late reply is enough: a server that stopped reading can't pile these up */
				self.sendQueue.removeAll { self.lineIsPong($0) }

				self.sendQueue.insert(data, at: self.pongInsertionIndex)

				self.tryToSend()
			} else {
				self.sendQueue.append(data)

				self.tryToSend()
			}
		}
	}

	// MARK: - Flood Control

	@objc
	final func enforceFloodControl()
	{
		queue.async {
			self.floodControlEnforced = true
		}
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

		tryToSend()
	}

	// MARK: - Secure Connection Information

	/// Called on the main queue; reads the TLS state on the connection's queue
	@objc(exportSecureConnectionInformation:)
	final func exportSecureConnectionInformation(to receiver: @escaping IRCConnectionSecureInformationBlock)
	{
		var information: (String?, tls_protocol_version_t, tls_ciphersuite_t, [Data])?

		queue.sync {
			information = socket.secureConnectionInformation
		}

		guard let (policyName, protocolType, cipherSuite, certificateChain) = information else {
			return
		}

		receiver(policyName, protocolType, cipherSuite, certificateChain)
	}

	// MARK: - Socket Delegate (called on the connection's queue)

	final func connection(_ connection: ConnectionSocket, willConnectToProxy address: String, on port: UInt16)
	{
		notifyDelegate { $0.ircConnectionWillConnect(toProxy: address, port: port) }
	}

	final func connection(_ connection: ConnectionSocket, willConnectTo address: String, on port: UInt16)
	{

	}

	final func connection(_ connection: ConnectionSocket, didConnectTo address: String?)
	{
		cancelConnectTimeout()

		notifyDelegate { $0.ircConnectionDidConnect(toHost: address) }

		/* Lines queued before the connection was ready */
		tryToSend()
	}

	final func connection(_ connection: ConnectionSocket, securedWith protocol: tls_protocol_version_t, cipherSuite: tls_ciphersuite_t)
	{
		notifyDelegate { $0.ircConnectionDidSecureConnection(withProtocolType: `protocol`, cipherSuite: cipherSuite) }
	}

	final func connection(_ connection: ConnectionSocket, requiresTrust response: @escaping (Bool) -> Void)
	{
		/* The user may take longer than the timeout to decide */
		cancelConnectTimeout()

		let queue = self.queue

		notifyDelegate { [weak self] delegate in
			delegate.ircConnectionRequestInsecureCertificateTrust { trusted in
				response(trusted)

				if (trusted) {
					queue.async {
						self?.startConnectTimeout()
					}
				}
			}
		}
	}

	final func connectionClosedReadStream(_ connection: ConnectionSocket)
	{
		notifyDelegate { $0.ircConnectionDidCloseReadStream() }
	}

	final func connectionDisconnected(_ connection: ConnectionSocket)
	{
		resetState()

		notifyDelegate { $0.ircConnectionDidDisconnectWithError(nil) }
	}

	final func connection(_ connection: ConnectionSocket, disconnectedWith error: ConnectionError)
	{
		resetState()

		let nsError = error as NSError

		notifyDelegate { $0.ircConnectionDidDisconnectWithError(nsError) }
	}

	final func connection(_ connection: ConnectionSocket, received data: Data)
	{
		linesOnMainQueue += 1

		if (readingPaused == false && linesOnMainQueue >= linesOnMainQueueHighWater) {
			readingPaused = true

			socket.pauseReading()
		}

		DispatchQueue.main.async { [weak self] in
			guard let self = self, let delegate = self.delegate else {
				return
			}

			delegate.ircConnectionDidReceive(data)

			self.queue.async {
				self.lineWorkedThrough()
			}
		}
	}

	fileprivate func lineWorkedThrough()
	{
		if (linesOnMainQueue > 0) {
			linesOnMainQueue -= 1
		}

		if (readingPaused && linesOnMainQueue <= linesOnMainQueueLowWater) {
			readingPaused = false

			socket.resumeReading()
		}
	}

	final func connection(_ connection: ConnectionSocket, willSend data: Data)
	{
		notifyDelegate { $0.ircConnectionWillSend(data) }
	}

	final func connectionDidSend(_ connection: ConnectionSocket)
	{
		notifyDelegate { $0.ircConnectionDidSendData() }

		tryToSend()
	}
}

// MARK: - Extensions

typealias ConnectionError = ConnectionTransport.ConnectionError

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
