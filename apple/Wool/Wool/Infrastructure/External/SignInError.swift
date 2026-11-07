import Foundation

public enum SignInError: Error, LocalizedError {
    case notConfigured
    case cancelled
    case failed(Error)
    case invalidRequest
    case invalidResponse
    case appleSignInNotAvailable
    case appleSignInFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sign in with Apple is not configured"
        case .cancelled:
            return "Sign-in was cancelled"
        case .failed(let error):
            return "Sign-in failed: \(error.localizedDescription)"
        case .invalidRequest:
            return "Invalid request to authentication server"
        case .invalidResponse:
            return "Invalid response from authentication server"
        case .appleSignInNotAvailable:
            return "Sign in with Apple is not available on this device"
        case .appleSignInFailed(let error):
            return "Sign in with Apple failed: \(error.localizedDescription)"
        }
    }
}
