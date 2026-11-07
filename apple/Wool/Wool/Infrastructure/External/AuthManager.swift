import Foundation
import Observation
import AuthenticationServices

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    var isSignedIn = false
    var displayName: String?
    var email: String?

    private var appleAuthorizationDelegate: AppleAuthorizationDelegate?
    private var isSigningIn = false

    func restoreSession() async {
        displayName = try? KeychainStore.loadString(.userDisplayName)
        email = try? KeychainStore.loadString(.userEmail)

        guard let userID = try? KeychainStore.loadString(.appleUserID),
              !userID.isEmpty else {
            isSignedIn = false
            return
        }

        let state = await credentialState(for: userID)
        switch state {
        case .authorized:
            isSignedIn = true
        case .revoked, .notFound:
            try? KeychainStore.clear(.appleUserID)
            isSignedIn = false
        default:
            isSignedIn = false
        }
    }

    func signInWithApple() async throws {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let credential = try await performAuthorization(request)

        try KeychainStore.saveString(credential.user, for: .appleUserID)

        if let email = credential.email, !email.isEmpty {
            self.email = email
            try KeychainStore.saveString(email, for: .userEmail)
        }

        if let fullName = credential.fullName {
            let name = PersonNameComponentsFormatter().string(from: fullName)
            if !name.isEmpty {
                displayName = name
                try KeychainStore.saveString(name, for: .userDisplayName)
            }
        }

        isSignedIn = true
    }

    func signOut() async {
        try? KeychainStore.clear(.appleUserID)
        try? KeychainStore.clear(.idToken)
        try? KeychainStore.clear(.accessToken)
        try? KeychainStore.clear(.refreshToken)
        isSignedIn = false
        displayName = nil
        email = nil
    }

    private func performAuthorization(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            let delegate = AppleAuthorizationDelegate(continuation: continuation)
            appleAuthorizationDelegate = delegate
            let controller = ASAuthorizationController(authorizationRequests: [request])
            delegate.controller = controller
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    private func credentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

}

private final class AppleAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    var controller: ASAuthorizationController?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: SignInError.invalidResponse)
            return
        }
        continuation.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            continuation.resume(throwing: SignInError.cancelled)
        } else {
            continuation.resume(throwing: SignInError.appleSignInFailed(error))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window
        }
        fatalError("Unable to find a presentation anchor for Sign in with Apple")
        #elseif os(macOS)
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
            return window
        }
        return NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        #endif
    }
}
