import Foundation

enum WatchConnectivityKeys {
    case deviceInfo
    case timerState
    case taskList

    var key: String {
        switch self {
        case .deviceInfo: return "deviceInfo"
        case .timerState: return "timerState"
        case .taskList: return "taskList"
        }
    }
}
