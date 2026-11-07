import Observation
import Foundation

#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif

//
//  WatchConnectivityManager.swift
//  Wool
//
//  Created by Kayis Rahman on 03/11/25.
//

#if os(iOS) || os(watchOS)

@MainActor
@Observable
final class WatchConnectivityManager {
    static var shared: WatchConnectivityManager? = WatchConnectivityManager()

    private enum Keys {
        static let timerState = "timerState"
        static let authTokens = "authTokens"
        static let signInRequest = "signInRequest"
    }

    private var session: WCSession?
    
    // MARK: - Timer Sync Methods
    func broadcastTimerState() {
        guard let timer = TimerSyncManager.shared.getTimer() else { return }
        let state = [
            "startTimestamp": timer.startTimestamp as Any,
            "pauseTimestamp": timer.pauseTimestamp as Any,
            "totalDuration": timer.currentDuration,
            "remainingSeconds": Int(timer.remainingSeconds),
            "phase": timer.phase.rawValue,
            "isRunning": timer.isRunning,
            "workDuration": timer.workDuration,
            "breakDuration": timer.breakDuration,
            "longBreakDuration": timer.longBreakDuration,
            "autoStartNextSession": timer.autoStartNextSession,
            "shortBreaksCompleted": timer.shortBreaksCompleted,
            "lastModifiedTimestamp": timer.lastModifiedTimestamp
        ] as [String : Any]
        
        sendMessage([Keys.timerState: state])
    }
    
    func requestSignIn() {
        sendMessage([Keys.signInRequest: true])
    }
    
    func sendAuthTokens() {
        // TODO: Implement secure token transfer
    }
    
    // MARK: - Incoming Messages
    func handleIncomingMessage(_ message: [String: Any]) {
        if let timerState = message[Keys.timerState] as? [String: Any] {
            TimerSyncManager.shared.applyIncomingState(timerState)
        }
        
        if let signInRequest = message[Keys.signInRequest] as? Bool, signInRequest {
            handleSignInRequest()
        }
        
        if let authTokens = message[Keys.authTokens] as? [String: String] {
            handleAuthTokens(authTokens)
        }
    }
    
    private func handleSignInRequest() {
        // iOS should trigger the Sign in with Apple flow
        #if os(iOS)
        // TODO: Present sign-in flow
        print("Sign-in requested from watch")
        #endif
    }
    
    private func handleAuthTokens(_ tokens: [String: String]) {
        // watchOS should store tokens in Keychain
        #if os(watchOS)
        if let idToken = tokens["idToken"], let accessToken = tokens["accessToken"] {
            try? KeychainStore.save(.idToken, value: idToken)
            try? KeychainStore.save(.accessToken, value: accessToken)
        }
        #endif
    }

    private func sendMessage(_ message: [String: Any]) {
        #if os(iOS)
        guard let session = session, session.isReachable else {
            print("Watch not reachable, message not sent")
            return
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send message: \(error.localizedDescription)")
        }
        #elseif os(watchOS)
        guard WCSession.default.isReachable else {
            // watchOS doesn't have LoggerStore, use print for now
            print("iOS not reachable, message not sent")
            return
        }

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send message: \(error.localizedDescription)")
        }
        #endif
    }

    #if os(iOS)
    private func presentSignInFlowFromConnectivity() {
        // TODO: Locate a presentation anchor and call:
                // Task { try await authManager.signInWithApple() }
    }
    #endif
}

#if os(iOS)
// MARK: - WatchConnectivity Delegate
final class WatchConnectivityDelegate: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityDelegate()
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WC Session did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WC Session did deactivate")
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WC Session activation failed: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            WatchConnectivityManager.shared?.handleIncomingMessage(message)
        }
    }
}
#endif

#endif
