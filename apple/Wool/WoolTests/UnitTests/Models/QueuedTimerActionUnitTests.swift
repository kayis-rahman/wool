import XCTest
@testable import Wool

final class QueuedTimerActionUnitTests: XCTestCase {

    // Test 1: QueuedTimerAction encodes to JSON with all fields present
    func test_encodeToJSON_containsAllFields() throws {
        let action = QueuedTimerAction(
            action: "start",
            timestamp: 1000.0,
            phase: "work",
            remainingSeconds: 1500,
            isRunning: true,
            workDuration: 1500,
            breakDuration: 300,
            longBreakDuration: 900,
            autoStartNextSession: true,
            shortBreaksCompleted: 2
        )

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: encoded)

        XCTAssertEqual(decoded["action"]?.stringValue, "start")
        XCTAssertEqual(decoded["timestamp"]?.doubleValue, 1000.0)
        XCTAssertEqual(decoded["phase"]?.stringValue, "work")
        XCTAssertEqual(decoded["remainingSeconds"]?.intValue, 1500)
        XCTAssertEqual(decoded["isRunning"]?.boolValue, true)
        XCTAssertEqual(decoded["workDuration"]?.intValue, 1500)
        XCTAssertEqual(decoded["breakDuration"]?.intValue, 300)
        XCTAssertEqual(decoded["longBreakDuration"]?.intValue, 900)
        XCTAssertEqual(decoded["autoStartNextSession"]?.boolValue, true)
        XCTAssertEqual(decoded["shortBreaksCompleted"]?.intValue, 2)
    }

    // Test 2: QueuedTimerAction decodes from JSON back to equivalent values
    func test_decodeFromJSON_preservesAllFields() throws {
        let json = """
        {
            "action": "pause",
            "timestamp": 2000.0,
            "phase": "short_break",
            "remainingSeconds": 250,
            "isRunning": false,
            "workDuration": 1500,
            "breakDuration": 300,
            "longBreakDuration": 900,
            "autoStartNextSession": false,
            "shortBreaksCompleted": 1
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(QueuedTimerAction.self, from: json)

        XCTAssertEqual(decoded.action, "pause")
        XCTAssertEqual(decoded.timestamp, 2000.0)
        XCTAssertEqual(decoded.phase, "short_break")
        XCTAssertEqual(decoded.remainingSeconds, 250)
        XCTAssertEqual(decoded.isRunning, false)
        XCTAssertEqual(decoded.workDuration, 1500)
        XCTAssertEqual(decoded.breakDuration, 300)
        XCTAssertEqual(decoded.longBreakDuration, 900)
        XCTAssertEqual(decoded.autoStartNextSession, false)
        XCTAssertEqual(decoded.shortBreaksCompleted, 1)
    }

    // Test 3: KeychainStore.Item has .actionQueue case that round-trips save/load
    func test_keychainStoreActionQueue_roundTrip() throws {
        let action = QueuedTimerAction(
            action: "reset",
            timestamp: 3000.0,
            phase: "long_break",
            remainingSeconds: 850,
            isRunning: false,
            workDuration: 1500,
            breakDuration: 300,
            longBreakDuration: 900,
            autoStartNextSession: true,
            shortBreaksCompleted: 4
        )

        let queue = [action]
        let encoded = try JSONEncoder().encode(queue)

        // Save to Keychain
        try KeychainStore.save(encoded, for: .actionQueue)

        // Load from Keychain
        let loaded = try KeychainStore.load(.actionQueue)
        XCTAssertNotNil(loaded)

        // Decode and verify
        let decoded = try JSONDecoder().decode([QueuedTimerAction].self, from: loaded!)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].action, "reset")
        XCTAssertEqual(decoded[0].timestamp, 3000.0)

        // Cleanup
        try KeychainStore.clear(.actionQueue)
    }
}

// Helper for JSON decoding in tests
enum AnyCodable: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case .int(let value) = self else { return nil }
        return value
    }

    var doubleValue: Double? {
        guard case .double(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
