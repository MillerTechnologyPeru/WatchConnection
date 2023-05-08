//
//  WatchConnectivity.swift
//
//
//  Created by Alsey Coleman Miller on 5/7/23.
//

import Foundation
import Combine
import WatchConnectivity

/// Apple Watch Connection
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
            return try session.isReachable
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
    
    func send(_ data: Data) async throws {
        let session = try validateActive()
        session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
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
        notiyStateChanged()
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
        notiyStateChanged()
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        notiyStateChanged()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        notiyStateChanged()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        notiyStateChanged()
    }
    #endif
    
    
}

// MARK: - Supporting Types

internal extension WatchConnection {
    
    final class Delegate: NSObject {
        
        private unowned let connection: WatchConnection
        
        fileprivate init(_ connection: WatchConnection) {
            self.connection = connection
        }
        
        func notiyStateChanged() {
            connection.objectWillChange.send()
        }
    }
}

internal extension WatchConnection {
    
    struct State {
        
        var activate: CheckedContinuation<WCSessionActivationState, Error>?
    }
}

internal extension WatchConnection {
    
    struct PendingOperation <Success, Failure> where Failure: Error {
        
        let continuation: CheckedContinuation<Success, Failure>
    }
}

