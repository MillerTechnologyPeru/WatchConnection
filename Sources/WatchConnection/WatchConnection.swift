//
//  WatchConnectivity.swift
//
//
//  Created by Alsey Coleman Miller on 5/7/23.
//

#if canImport(WatchConnectivity)
import Foundation
import Combine
@_exported import WatchConnectivity

/// Apple Watch Connection
@available(macOS, unavailable)
@available(tvOS, unavailable)
public actor WatchConnection: ObservableObject {
    
    // MARK: - Properties
    
    internal var delegate: Delegate?
    
    @Published
    private var internalState = State()
    
    let sleepTimeInterval: TimeInterval = 0.2
    
    /// Returns a Boolean value indicating whether the current iOS device is able to use a session object.
    ///
    /// Before retrieving the default session object, call this method to verify that the current device supports watch connectivity.
    /// Session objects are always available on Apple Watch. They are also available on iPhones that support pairing with an Apple Watch.
    /// For all other devices, this method returns false to indicate that you cannot use the classes and methods of this framework.
    public nonisolated var isSupported: Bool {
        WCSession.isSupported()
    }
    
    /// The current activation state of the session.
    public var state: WCSessionActivationState {
        get throws {
            return try session.activationState
        }
    }
    
    /// A Boolean value indicating whether the counterpart app is available for live messaging.
    ///
    /// This property is true when the WatchKit extension and the iOS app can communicate with each other.
    /// Specifically:
    /// - WatchKit extension:The iOS device is within range, so communication can occur and the WatchKit extension is running in the foreground, or is running with a high priority in the background (for example, during a workout session or when a complication is loading its initial timeline data).
    /// - iOS app: A paired and active Apple Watch is in range, the corresponding WatchKit extension is running, and the WatchKit extension’s isReachable property is true.
    ///
    /// In all other cases, the value is false.
    public var isReachable: Bool {
        get throws {
            try validateActive().isReachable
        }
    }
    
    /// A Boolean value that indicates whether the session has more content to deliver.
    @available(watchOS, unavailable)
    public var isPaired: Bool {
        get throws {
            try validateActive().isPaired
        }
    }
    
    /// A Boolean value indicating whether the currently paired and active Apple Watch has installed the app.
    @available(watchOS, unavailable)
    public var isWatchAppInstalled: Bool {
        get throws {
            try validateActive().isWatchAppInstalled
        }
    }
    
    /// A Boolean value indicating whether the Watch app’s complication is in use on the currently paired and active Apple Watch.
    @available(watchOS, unavailable)
    public var isComplicationEnabled: Bool {
        get throws {
            try validateActive().isComplicationEnabled
        }
    }
    
    /// Boolean value indicating whether the paired iPhone must be in an unlocked state to be reachable.
    ///
    /// When the isReachable property is false, use this property to determine if the iPhone is unreachable because it needs to be unlocked first.
    /// A recently rebooted iPhone remains unreachable until the user unlocks it for the first time. Until the user unlocks the iPhone, the value of this property is true.
    /// When the value is true, you might display an alert from your Watch app asking the user to unlock the iPhone to continue.
    ///
    /// After the user unlocks the iPhone, the value of the property changes to false.
    @available(iOS, unavailable)
    public var deviceNeedsUnlockAfterRebootForReachability: Bool {
        get throws {
            try validateActive().iOSDeviceNeedsUnlockAfterRebootForReachability
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
    
    /// A Boolean value that indicates whether the session has more content to deliver.
    public var hasContentPending: Bool {
        get throws {
            try session.hasContentPending
        }
    }
    
    /// An array of in-progress data transfers.
    public var outstandingUserInfoTransfers: [WCSessionUserInfoTransfer] {
        get throws {
            try session.outstandingUserInfoTransfers
        }
    }
    
    /// An array of in-progress file transfers.
    public var outstandingFileTransfers: [WCSessionFileTransfer] {
        get throws {
            try session.outstandingFileTransfers
        }
    }
    
    // MARK: - Initialization
    
    /// Defailt
    private init() { }
    
    /// The singleton session object for the current device.
    public static let shared = WatchConnection()
    
    // MARK: - Methods
    
    /// Activates the session asynchronously.
    @discardableResult
    public func activate() async throws -> WCSessionActivationState {
        let session = try self.session
        while self.internalState.continuation.activate != nil {
            try await Task.sleep(timeInterval: sleepTimeInterval)
        }
        guard session.activationState != .activated else {
            return session.activationState
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.internalState.continuation.activate = continuation
            session.activate()
        }
    }
    
    /// Sends a dictionary of values that a paired and active device can use to synchronize its state.
    public func updateApplicationContext(_ applicationContext: PropertyList) throws {
        let session = try validateActive()
        try session.updateApplicationContext(applicationContext)
        objectWillChange.send()
    }
    
    /// Sends complication-related data from the iOS app to the WatchKit extension.
    ///
    /// Call this method when you have new data to send to your complication.
    /// Your WatchKit extension can use the data to replace or extend its current timeline entries.
    @available(watchOS, unavailable)
    public func transferCurrentComplicationUserInfo(_ userInfo: PropertyList) throws {
        let session = try validateActive()
        session.transferCurrentComplicationUserInfo(userInfo)
    }
    
    /// Sends the specified data dictionary to the counterpart.
    public func transfer(userInfo: PropertyList) async throws {
        let session = try validateActive()
        defer { objectWillChange.send() }
        return try await withCheckedThrowingContinuation { continuation in
            let transfer = session.transferUserInfo(userInfo)
            self.internalState.continuation.transferUserInfo.updateValue(continuation, forKey: transfer)
            objectWillChange.send()
        }
    }
    
    /// Wait for pending incoming messages.
    public func recieveUserInfo() async throws -> PropertyList {
        while internalState.recievedUserInfo.isEmpty {
            try await Task.sleep(timeInterval: sleepTimeInterval)
        }
        return internalState.recievedUserInfo.removeFirst()
    }
    
    /// Sends the specified data dictionary to the counterpart.
    public func transfer(file: URL, metadata: [String: Any]? = nil) async throws {
        let session = try validateActive()
        defer { objectWillChange.send() }
        return try await withCheckedThrowingContinuation { continuation in
            let transfer = session.transferFile(file, metadata: metadata)
            self.internalState.continuation.transferFile.updateValue(continuation, forKey: transfer)
            objectWillChange.send()
        }
    }
    
    /// Wait for pending incoming files.
    public func recieveFiles() async throws -> WCSessionFile {
        while internalState.recievedFiles.isEmpty {
            try await Task.sleep(timeInterval: sleepTimeInterval)
        }
        return internalState.recievedFiles.removeFirst()
    }
    
    /// Sends a message immediately to the paired and active device.
    public func send(_ data: Data) throws {
        let session = try validateActive()
        session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        objectWillChange.send()
    }
    
    /// Wait for pending incoming data.
    public func receiveData() async throws -> Data {
        while internalState.recievedData.isEmpty {
            try await Task.sleep(timeInterval: sleepTimeInterval)
        }
        return internalState.recievedData.removeFirst()
    }
    
    /// Sends a message immediately to the paired and active device.
    public func send(_ dictionary: PropertyList) throws {
        let session = try validateActive()
        session.sendMessage(dictionary, replyHandler: nil, errorHandler: nil)
        objectWillChange.send()
    }
    
    /// Wait for pending incoming messages.
    public func recieveMessage() async throws -> PropertyList {
        while internalState.recievedMessages.isEmpty {
            try await Task.sleep(timeInterval: sleepTimeInterval)
        }
        return internalState.recievedMessages.removeFirst()
    }
    
    /// Sends a data object immediately to the paired and active device and waits for a response.
    public func sendWithResponse(_ data: Data) async throws -> Data {
        let session = try validateActive()
        defer { objectWillChange.send() }
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessageData(data, replyHandler: { reply in
                continuation.resume(returning: reply)
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    /// Sends a message immediately to the paired and active device and waits for a response.
    public func sendWithResponse(_ dictionary: PropertyList) async throws -> PropertyList {
        let session = try validateActive()
        defer { objectWillChange.send() }
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(dictionary, replyHandler: { reply in
                continuation.resume(returning: reply as! [String: NSObject])
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
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
        self.internalState.continuation.activate?.resume(with: result)
        self.internalState.continuation.activate = nil
    }
    
    func didTransfer(_ transfer: WCSessionUserInfoTransfer, with result: Result<Void, Error>) {
        self.internalState.continuation.transferUserInfo[transfer]?.resume(with: result)
        self.internalState.continuation.transferUserInfo[transfer] = nil
    }
    
    func didTransfer(_ transfer: WCSessionFileTransfer, with result: Result<Void, Error>) {
        self.internalState.continuation.transferFile[transfer]?.resume(with: result)
        self.internalState.continuation.transferFile[transfer] = nil
    }
    
    func didRecieve(userInfo: PropertyList) {
        self.internalState.recievedUserInfo.append(userInfo)
    }
    
    func didRecieve(file: WCSessionFile) {
        self.internalState.recievedFiles.append(file)
    }
    
    func didRecieve(data: Data) {
        self.internalState.recievedData.append(data)
    }
    
    func didRecieve(message: PropertyList) {
        self.internalState.recievedMessages.append(message)
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
    #elseif os(watchOS)
    func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        willChange()
    }
    #endif
    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        willChange()
        Task {
            await connection.didRecieve(message: message as! [String: NSObject])
        }
    }
    
    /** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        willChange()
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message data caused the receiver to launch. */
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        willChange()
        Task {
            await connection.didRecieve(data: messageData)
        }
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
        let result: Result<Void, Error>
        if let error = error {
            result = .failure(error)
        } else {
            result = .success(())
        }
        Task {
            await connection.didTransfer(userInfoTransfer, with: result)
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the user info finished transferring when the receiver was not running. */
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        willChange()
        Task {
            await connection.didRecieve(userInfo: userInfo as! [String: NSObject])
        }
    }
    
    /** Called on the sending side after the file transfer has successfully completed or failed with an error. Will be called on next launch if the sender was not running when the transfer finished. */
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        willChange()
        let result: Result<Void, Error>
        if let error = error {
            result = .failure(error)
        } else {
            result = .success(())
        }
        Task {
            await connection.didTransfer(fileTransfer, with: result)
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the file finished transferring when the receiver was not running. The incoming file will be located in the Documents/Inbox/ folder when being delivered. The receiver must take ownership of the file by moving it to another location. The system will remove any content that has not been moved when this delegate method returns. */
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        willChange()
        Task {
            await connection.didRecieve(file: file)
        }
    }
}

// MARK: - Supporting Types

public extension WatchConnection {
    
    typealias PropertyList = [String: NSObject]
}

internal extension WatchConnection {
    
    final class Delegate: NSObject {
        
        private unowned let connection: WatchConnection
        
        fileprivate init(_ connection: WatchConnection) {
            self.connection = connection
        }
        
        private func willChange() {
            connection.objectWillChange.send()
        }
    }
}

internal extension WatchConnection {
    
    struct State {
        
        var continuation = Continuation()
        
        var recievedMessages = [PropertyList]()
        
        var recievedData = [Data]()
        
        var recievedUserInfo = [PropertyList]()
        
        var recievedFiles = [WCSessionFile]()
    }
    
    struct Continuation {
        
        var activate: CheckedContinuation<WCSessionActivationState, Error>?
        
        var transferUserInfo = [WCSessionUserInfoTransfer: CheckedContinuation<Void, Error>]()
        
        var transferFile = [WCSessionFileTransfer: CheckedContinuation<Void, Error>]()
    }
}

#endif
