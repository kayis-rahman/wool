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
    
    init(userId: UUID, sourceDeviceId: String, previousState: TimerStateDto?, newState: TimerStateDto, phase: String, action: String, timestamp: Date) {
        self.userId = userId
        self.sourceDeviceId = sourceDeviceId
        self.previousState = previousState
        self.newState = newState
        self.phase = phase
        self.action = action
        self.timestamp = timestamp
    }
}