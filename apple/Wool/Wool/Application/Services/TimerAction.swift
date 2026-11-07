import Foundation

public enum TimerAction: String, Codable {
    case start = "START"
    case pause = "PAUSE"
    case reset = "RESET"
    case stop = "STOP"
    case advance = "ADVANCE"
}
