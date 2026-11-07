import Foundation
import Observation

@MainActor
@Observable
final class SyncFailureAlertManager {
    static let shared = SyncFailureAlertManager()

    var isActive: Bool = false
    var failureCount: Int = 0
    var retryAction: (() async -> Void)?

    private init() {}

    func showAlert(consecutiveFailures: Int, retryAction: (() async -> Void)? = nil) {
        isActive = true
        failureCount = consecutiveFailures
        self.retryAction = retryAction
    }

    func dismissAlert() {
        isActive = false
        failureCount = 0
        retryAction = nil
    }

    func getBackoffInterval(for failureCount: Int) -> TimeInterval {
        switch failureCount {
        case 1:
            return 30
        case 2:
            return 60
        case 3:
            return 120
        default:
            return 300  // Cap at 5 minutes
        }
    }
}
