import Foundation

/**
 * Timer state change event for cross-device synchronization
 * Represents timer state changes like start, pause, resume, reset
 */
struct TimerStateChangeEvent: Codable {
    let userId: UUID
    let sourceDeviceId: String
    let previousState: TimerStateDto?
    let newState: TimerStateDto
    let phase: String
    let action: String
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case userId, sourceDeviceId, previousState, newState
        case phase, action, timestamp
    }
}
