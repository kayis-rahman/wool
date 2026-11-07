#if os(iOS)
import ActivityKit
import Foundation

struct FocusLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let phase: String
        let endDate: Date?
        let remainingSeconds: Int
        let isPaused: Bool
        let cycleNumber: Int
        let cycleSize: Int
        let taskTitle: String?
    }

    let sessionID: String
}
#endif
