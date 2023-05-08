//
//  WatchConnectivity.swift
//
//
//  Created by Alsey Coleman Miller on 5/7/23.
//

#if canImport(WatchConnectivity)
import Foundation
import Combine
import WatchConnectivity

/// Apple Watch Connection
@available(macOS, unavailable)
@available(tvOS, unavailable)
public actor WatchConnection: ObservableObject {
    
    // MARK: - Properties
    
    private var delegate: Delegate?
    
    private var internalState = State()
    
    /// Returns a Boolean value indicating whether the current iOS device is able to use a session object.
    ///
    /// Before retrieving the default session object, call this method to verify that the current device supports watch connectivity.
    /// Session objects are always available on Apple Watch. They are also available on iPhones that support pairing with an Apple Watch.
    /// For all other devices, this method returns false to indicate that you cannot use the classes and methods of this framework.
    public var isSupported: Bool {
        WCSession.isSupported()
    }
    
    /// The current activation state of the session.
    public var state: WCSessionActivationState {
        get throws {
            return try session.activationState
        }
    }
    
    /// A Boolean value indicating whether the counterpart app is available for live messaging.
    public var isReachable: Bool {
        get throws {
            try session.isReachable
        }
    }
    
    /// A Boolean value that indicates whether the session has more content to deliver.
    @available(watchOS, unavailable)
    public var isPaired: Bool {
        get throws {
            try session.isPaired
        }
    }
    
    /// A Boolean value indicating whether the currently paired and active Apple Watch has installed the app.
    @available(watchOS, unavailable)
    public var isWatchAppInstalled: Bool {
        get throws {
            try session.isWatchAppInstalled
        }
    }
    
    /// A Boolean value indicating whether the Watch app’s complication is in use on the currently paired and active Apple Watch.
    @available(watchOS, unavailable)
    public var isComplicationEnabled: Bool {
        get throws {
            try session.isComplicationEnabled
        }
    }
    
    /// Boolean value indicating whether the paired iPhone must be in an unlocked state to be reachable.
    @available(iOS, unavailable)
    public var deviceNeedsUnlockAfterRebootForReachability: Bool {
        get throws {
            try session.iOSDeviceNeedsUnlockAfterRebootForReachability
        }
    }
    
    /// The most recent contextual data sent to the paired and active device.
    public var applicationContext: PropertyList {
        get throws {
            try session.applicationContext as! [String: NSObject]
        }
    }
    
    /// A dictionary containing the last update data received from a paired and active device.
    public var receivedApplicationContext: PropertyList {
        get throws {
            try session.receivedApplicationContext as! [String: NSObject]
        }
    }
    
    // MARK: - Initialization
    
    /// Defailt
    private init() { }
    
    public static let shared = WatchConnection()
    
    // MARK: - Methods
    
    /// Activates the session asynchronously.
    @discardableResult
    func activate() async throws -> WCSessionActivationState {
        let session = try self.session
        return try await withCheckedThrowingContinuation { continuation in
            self.internalState.activate = continuation
            session.activate()
        }
    }
    
    func send(_ message: Message) throws {
        switch message {
        case let .data(data):
            try send(data)
        case let .propertyList(dictionary):
            try send(dictionary)
        }
    }
    
    /// Sends a message immediately to the paired and active device.
    func send(_ data: Data) throws {
        let session = try validateActive()
        session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
    }
    
    /// Sends a message immediately to the paired and active device.
    func send(_ dictionary: PropertyList) throws {
        let session = try validateActive()
        session.sendMessage(dictionary, replyHandler: nil, errorHandler: nil)
    }
}

internal extension WatchConnection {
    
    var session: WCSession {
        get throws {
            // validate if supported (false on iPad)
            guard isSupported else {
                throw WCError(.sessionNotSupported)
            }
            let session = WCSession.default
            // create and set delegate
            if delegate == nil {
                self.delegate = Delegate(self)
            }
            if session.delegate !== self.delegate {
                session.delegate = self.delegate
            }
            return session
        }
    }
    
    @discardableResult
    func validateActive() throws -> WCSession {
        let session = try self.session
        guard session.activationState == .activated else {
            throw WCError(.sessionNotActivated)
        }
        return session
    }
    
    func activationDidComplete(with result: Result<WCSessionActivationState, Error>) {
        self.internalState.activate?.resume(with: result)
        self.internalState.activate = nil
    }
}

// MARK: - WCSessionDelegate

extension WatchConnection.Delegate: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        willChange()
        let result: Result<WCSessionActivationState, Error>
        if let error = error {
            result = .failure(error)
        } else {
            result = .success(activationState)
        }
        Task {
            await connection.activationDidComplete(with: result)
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        willChange()
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        willChange()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        willChange()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        willChange()
    }
    #endif
    
    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        willChange()
    }

    
    /** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        willChange()
    }

    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message data caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        willChange()
    }

    
    /** Called on the delegate of the receiver when the sender sends message data that expects a reply. Will be called on startup if the incoming message data caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        willChange()
    }
    
    /** -------------------------- Background Transfers ------------------------- */
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        willChange()
    }
    
    /** Called on the sending side after the user info transfer has successfully completed or failed with an error. Will be called on next launch if the sender was not running when the user info finished. */
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        willChange()
    }

    
    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        willChange()
    }

    
    /** Called on the sending side after the file transfer has successfully completed or failed with an error. Will be called on next launch if the sender was not running when the transfer finished. */
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        willChange()
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the file finished transferring when the receiver was not running. The incoming file will be located in the Documents/Inbox/ folder when being delivered. The receiver must take ownership of the file by moving it to another location. The system will remove any content that has not been moved when this delegate method returns. */
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        willChange()
    }
}

// MARK: - Supporting Types

public extension WatchConnection {
    
    typealias PropertyList = [String: NSObject]
    
    enum Message: Equatable, Hashable {
        
        case data(Data)
        case propertyList(PropertyList)
    }
}

internal extension WatchConnection {
    
    final class Delegate: NSObject {
        
        private unowned let connection: WatchConnection
        
        fileprivate init(_ connection: WatchConnection) {
            self.connection = connection
        }
        
        func willChange() {
            connection.objectWillChange.send()
        }
    }
}

internal extension WatchConnection {
    
    struct State {
        
        var activate: CheckedContinuation<WCSessionActivationState, Error>?
    }
}

#endif
