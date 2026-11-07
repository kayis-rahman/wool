//
//  TaskModelUnitTests.swift
//  WoolTests
//
//  Created by Wool Team
//  Comprehensive unit tests for Task model following Cline and Kilo code rules
//  Testing domain model validation, business logic, and state transitions

import XCTest
@testable import Wool

final class TaskModelUnitTests: XCTestCase {

    // MARK: - Task Creation Tests

    func testTaskCreationWithValidData() throws {
        // Given
        let id = UUID()
        let userId = UUID()
        let title = "Valid Task Title"
        let description = "Valid task description"
        let status = TaskStatus.todo
        let createdAt = Date()
        let updatedAt = Date()

        // When
        let task = Task(id: id, userId: userId, title: title, description: description,
                       status: status, createdAt: createdAt, updatedAt: updatedAt)

        // Then
        XCTAssertEqual(task.id, id)
        XCTAssertEqual(task.userId, userId)
        XCTAssertEqual(task.title, title)
        XCTAssertEqual(task.description, description)
        XCTAssertEqual(task.status, status)
        XCTAssertEqual(task.createdAt, createdAt)
        XCTAssertEqual(task.updatedAt, updatedAt)
    }

    func testTaskCreationWithMinimalData() throws {
        // Given
        let id = UUID()
        let userId = UUID()
        let title = "Minimal Task"

        // When
        let task = Task(id: id, userId: userId, title: title, description: nil,
                       status: .todo, createdAt: Date(), updatedAt: Date())

        // Then
        XCTAssertEqual(task.title, title)
        XCTAssertNil(task.description)
        XCTAssertEqual(task.status, .todo)
    }

    // MARK: - Validation Tests

    func testTaskCreationFailsWithEmptyTitle() throws {
        // Given
        let emptyTitle = ""

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: emptyTitle,
                                    description: nil, status: .todo,
                                    createdAt: Date(), updatedAt: Date())) { error in
            XCTAssertEqual(error as? TaskValidationError, .invalidTitle)
        }
    }

    func testTaskCreationFailsWithWhitespaceOnlyTitle() throws {
        // Given
        let whitespaceTitle = "   \t\n  "

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: whitespaceTitle,
                                    description: nil, status: .todo,
                                    createdAt: Date(), updatedAt: Date())) { error in
            XCTAssertEqual(error as? TaskValidationError, .invalidTitle)
        }
    }

    func testTaskCreationFailsWithTitleTooLong() throws {
        // Given
        let longTitle = String(repeating: "A", count: 256) // Exceeds 255 character limit

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: longTitle,
                                    description: nil, status: .todo,
                                    createdAt: Date(), updatedAt: Date())) { error in
            XCTAssertEqual(error as? TaskValidationError, .titleTooLong)
        }
    }

    func testTaskCreationFailsWithDescriptionTooLong() throws {
        // Given
        let longDescription = String(repeating: "A", count: 1001) // Exceeds 1000 character limit

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: "Valid Title",
                                    description: longDescription, status: .todo,
                                    createdAt: Date(), updatedAt: Date())) { error in
            XCTAssertEqual(error as? TaskValidationError, .descriptionTooLong)
        }
    }

    func testTaskCreationFailsWithFutureCreatedAt() throws {
        // Given
        let futureDate = Date().addingTimeInterval(86400) // Tomorrow

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: "Valid Title",
                                    description: nil, status: .todo,
                                    createdAt: futureDate, updatedAt: Date())) { error in
            XCTAssertEqual(error as? TaskValidationError, .invalidCreatedAt)
        }
    }

    func testTaskCreationFailsWithUpdatedAtBeforeCreatedAt() throws {
        // Given
        let createdAt = Date()
        let updatedAt = createdAt.addingTimeInterval(-3600) // 1 hour before

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: "Valid Title",
                                    description: nil, status: .todo,
                                    createdAt: createdAt, updatedAt: updatedAt)) { error in
            XCTAssertEqual(error as? TaskValidationError, .invalidUpdatedAt)
        }
    }

    func testTaskCreationFailsWithFutureUpdatedAt() throws {
        // Given
        let createdAt = Date().addingTimeInterval(-3600)
        let futureDate = Date().addingTimeInterval(86400)

        // When/Then
        XCTAssertThrowsError(try Task(id: UUID(), userId: UUID(), title: "Valid Title",
                                    description: nil, status: .todo,
                                    createdAt: createdAt, updatedAt: futureDate)) { error in
            XCTAssertEqual(error as? TaskValidationError, .invalidUpdatedAt)
        }
    }

    // MARK: - Business Logic Tests

    func testTaskIsActive() throws {
        // Given
        let todoTask = try Task(id: UUID(), userId: UUID(), title: "Todo Task",
                               description: nil, status: .todo,
                               createdAt: Date(), updatedAt: Date())

        let inProgressTask = try Task(id: UUID(), userId: UUID(), title: "In Progress Task",
                                     description: nil, status: .inProgress,
                                     createdAt: Date(), updatedAt: Date())

        let completedTask = try Task(id: UUID(), userId: UUID(), title: "Completed Task",
                                    description: nil, status: .completed,
                                    createdAt: Date(), updatedAt: Date())

        // Then
        XCTAssertTrue(todoTask.isActive)
        XCTAssertTrue(inProgressTask.isActive)
        XCTAssertFalse(completedTask.isActive)
    }

    func testTaskIsCompleted() throws {
        // Given
        let todoTask = try Task(id: UUID(), userId: UUID(), title: "Todo Task",
                               description: nil, status: .todo,
                               createdAt: Date(), updatedAt: Date())

        let inProgressTask = try Task(id: UUID(), userId: UUID(), title: "In Progress Task",
                                     description: nil, status: .inProgress,
                                     createdAt: Date(), updatedAt: Date())

        let completedTask = try Task(id: UUID(), userId: UUID(), title: "Completed Task",
                                    description: nil, status: .completed,
                                    createdAt: Date(), updatedAt: Date())

        // Then
        XCTAssertFalse(todoTask.isCompleted)
        XCTAssertFalse(inProgressTask.isCompleted)
        XCTAssertTrue(completedTask.isCompleted)
    }

    // MARK: - State Transition Tests

    func testTaskStatusTransitionToInProgress() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Test Task",
                           description: nil, status: .todo,
                           createdAt: Date(), updatedAt: Date())

        // When
        let updatedTask = task.withStatus(.inProgress)

        // Then
        XCTAssertEqual(updatedTask.status, .inProgress)
        XCTAssertEqual(updatedTask.id, task.id)
        XCTAssertEqual(updatedTask.title, task.title)
        XCTAssertNotEqual(updatedTask.updatedAt, task.updatedAt) // Should be updated
    }

    func testTaskStatusTransitionToCompleted() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Test Task",
                           description: nil, status: .inProgress,
                           createdAt: Date(), updatedAt: Date())

        // When
        let updatedTask = task.withStatus(.completed)

        // Then
        XCTAssertEqual(updatedTask.status, .completed)
        XCTAssertFalse(updatedTask.isActive)
        XCTAssertTrue(updatedTask.isCompleted)
    }

    func testTaskTitleUpdate() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Original Title",
                           description: nil, status: .todo,
                           createdAt: Date(), updatedAt: Date())

        let newTitle = "Updated Title"

        // When
        let updatedTask = task.withTitle(newTitle)

        // Then
        XCTAssertEqual(updatedTask.title, newTitle)
        XCTAssertEqual(updatedTask.id, task.id)
        XCTAssertEqual(updatedTask.status, task.status)
        XCTAssertNotEqual(updatedTask.updatedAt, task.updatedAt)
    }

    func testTaskDescriptionUpdate() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Test Task",
                           description: "Original description", status: .todo,
                           createdAt: Date(), updatedAt: Date())

        let newDescription = "Updated description"

        // When
        let updatedTask = task.withDescription(newDescription)

        // Then
        XCTAssertEqual(updatedTask.description, newDescription)
        XCTAssertEqual(updatedTask.title, task.title)
        XCTAssertNotEqual(updatedTask.updatedAt, task.updatedAt)
    }

    func testTaskUpdateValidation() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Original Title",
                           description: nil, status: .todo,
                           createdAt: Date(), updatedAt: Date())

        // When/Then - Empty title should fail
        XCTAssertThrowsError(try task.withTitle("")) { error in
            XCTAssertEqual(error as? TaskValidationError, .invalidTitle)
        }

        // When/Then - Long title should fail
        let longTitle = String(repeating: "A", count: 256)
        XCTAssertThrowsError(try task.withTitle(longTitle)) { error in
            XCTAssertEqual(error as? TaskValidationError, .titleTooLong)
        }

        // When/Then - Long description should fail
        let longDescription = String(repeating: "A", count: 1001)
        XCTAssertThrowsError(try task.withDescription(longDescription)) { error in
            XCTAssertEqual(error as? TaskValidationError, .descriptionTooLong)
        }
    }

    // MARK: - Equality and Hashing Tests

    func testTaskEquality() throws {
        // Given
        let id = UUID()
        let userId = UUID()
        let task1 = try Task(id: id, userId: userId, title: "Task 1",
                            description: nil, status: .todo,
                            createdAt: Date(), updatedAt: Date())

        let task2 = try Task(id: id, userId: userId, title: "Task 2", // Different title
                            description: nil, status: .todo,
                            createdAt: Date(), updatedAt: Date())

        let task3 = try Task(id: UUID(), userId: userId, title: "Task 1", // Different ID
                            description: nil, status: .todo,
                            createdAt: Date(), updatedAt: Date())

        // Then
        XCTAssertEqual(task1, task2) // Same ID means equal
        XCTAssertNotEqual(task1, task3) // Different ID means not equal
    }

    func testTaskHashing() throws {
        // Given
        let id = UUID()
        let userId = UUID()
        let task1 = try Task(id: id, userId: userId, title: "Task 1",
                            description: nil, status: .todo,
                            createdAt: Date(), updatedAt: Date())

        let task2 = try Task(id: id, userId: userId, title: "Task 2", // Different title
                            description: nil, status: .todo,
                            createdAt: Date(), updatedAt: Date())

        // Then
        XCTAssertEqual(task1.hashValue, task2.hashValue) // Same ID means same hash
    }

    // MARK: - Description and Debugging Tests

    func testTaskDescription() throws {
        // Given
        let id = UUID()
        let userId = UUID()
        let title = "Test Task"
        let createdAt = Date()
        let updatedAt = Date()

        let task = try Task(id: id, userId: userId, title: title,
                           description: "Test description", status: .inProgress,
                           createdAt: createdAt, updatedAt: updatedAt)

        // When
        let description = task.description

        // Then
        XCTAssertTrue(description.contains("Task"))
        XCTAssertTrue(description.contains(id.uuidString))
        XCTAssertTrue(description.contains(userId.uuidString))
        XCTAssertTrue(description.contains(title))
        XCTAssertTrue(description.contains("in_progress"))
    }

    func testTaskDebugDescription() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Debug Task",
                           description: nil, status: .todo,
                           createdAt: Date(), updatedAt: Date())

        // When
        let debugDescription = task.debugDescription

        // Then
        XCTAssertTrue(debugDescription.contains("Task"))
        XCTAssertTrue(debugDescription.contains("id:"))
        XCTAssertTrue(debugDescription.contains("title:"))
        XCTAssertTrue(debugDescription.contains("status:"))
    }

    // MARK: - Codable Tests

    func testTaskEncoding() throws {
        // Given
        let task = try Task(id: UUID(), userId: UUID(), title: "Encodable Task",
                           description: "Test description", status: .completed,
                           createdAt: Date(), updatedAt: Date())

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        // Then
        XCTAssertNotNil(data)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("Encodable Task"))
        XCTAssertTrue(jsonString!.contains("completed"))
    }

    func testTaskDecoding() throws {
        // Given
        let jsonString = """
        {
            "id": "\(UUID())",
            "userId": "\(UUID())",
            "title": "Decoded Task",
            "description": "Decoded description",
            "status": "in_progress",
            "createdAt": "\(ISO8601DateFormatter().string(from: Date()))",
            "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """

        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try decoder.decode(Task.self, from: data)

        // Then
        XCTAssertEqual(task.title, "Decoded Task")
        XCTAssertEqual(task.description, "Decoded description")
        XCTAssertEqual(task.status, .inProgress)
    }

    func testTaskDecodingWithMissingOptionalFields() throws {
        // Given
        let jsonString = """
        {
            "id": "\(UUID())",
            "userId": "\(UUID())",
            "title": "Minimal Task",
            "status": "todo",
            "createdAt": "\(ISO8601DateFormatter().string(from: Date()))",
            "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """

        let data = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try decoder.decode(Task.self, from: data)

        // Then
        XCTAssertEqual(task.title, "Minimal Task")
        XCTAssertNil(task.description)
        XCTAssertEqual(task.status, .todo)
    }

    func testTaskDecodingFailsWithInvalidData() throws {
        // Given
        let invalidJsonString = """
        {
            "id": "invalid-uuid",
            "userId": "\(UUID())",
            "title": "",
            "status": "invalid_status",
            "createdAt": "invalid-date",
            "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """

        let data = invalidJsonString.data(using: .utf8)!

        // When/Then
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertThrowsError(try decoder.decode(Task.self, from: data))
    }

    // MARK: - Performance Tests

    func testTaskCreationPerformance() throws {
        // Given
        let id = UUID()
        let userId = UUID()
        let title = "Performance Test Task"

        // When/Then
        measure {
            for _ in 0..<1000 {
                let task = try? Task(id: id, userId: userId, title: title,
                                    description: nil, status: .todo,
                                    createdAt: Date(), updatedAt: Date())
                XCTAssertNotNil(task)
            }
        }
    }

    func testTaskEqualityPerformance() throws {
        // Given
        let tasks = try (0..<1000).map { i in
            Task(id: UUID(), userId: UUID(), title: "Task \(i)",
                description: nil, status: .todo, createdAt: Date(), updatedAt: Date())
        }

        // When/Then
        measure {
            for i in 0..<tasks.count {
                for j in (i+1)..<min(i+10, tasks.count) { // Compare with next 10 tasks
                    _ = tasks[i] == tasks[j]
                }
            }
        }
    }

    // MARK: - Edge Cases

    func testTaskWithUnicodeCharacters() throws {
        // Given
        let unicodeTitle = "任务 📋"
        let unicodeDescription = "描述 📝 with émojis 🎯 and spëcial chärs"

        // When
        let task = try Task(id: UUID(), userId: UUID(), title: unicodeTitle,
                           description: unicodeDescription, status: .todo,
                           createdAt: Date(), updatedAt: Date())

        // Then
        XCTAssertEqual(task.title, unicodeTitle)
        XCTAssertEqual(task.description, unicodeDescription)
    }

    func testTaskWithBoundaryValues() throws {
        // Given - Maximum allowed lengths
        let maxTitle = String(repeating: "A", count: 255)
        let maxDescription = String(repeating: "B", count: 1000)

        // When
        let task = try Task(id: UUID(), userId: UUID(), title: maxTitle,
                           description: maxDescription, status: .completed,
                           createdAt: Date().addingTimeInterval(-1), // 1 second ago
                           updatedAt: Date())

        // Then
        XCTAssertEqual(task.title.count, 255)
        XCTAssertEqual(task.description?.count, 1000)
        XCTAssertEqual(task.status, .completed)
    }

    func testTaskImmutableUpdates() throws {
        // Given
        let originalTask = try Task(id: UUID(), userId: UUID(), title: "Original",
                                   description: "Original desc", status: .todo,
                                   createdAt: Date(), updatedAt: Date())

        // When
        let titleUpdated = originalTask.withTitle("Updated Title")
        let statusUpdated = originalTask.withStatus(.completed)
        let descriptionUpdated = originalTask.withDescription("Updated desc")

        // Then - Original task should be unchanged
        XCTAssertEqual(originalTask.title, "Original")
        XCTAssertEqual(originalTask.status, .todo)
        XCTAssertEqual(originalTask.description, "Original desc")

        // Updated tasks should have new values
        XCTAssertEqual(titleUpdated.title, "Updated Title")
        XCTAssertEqual(statusUpdated.status, .completed)
        XCTAssertEqual(descriptionUpdated.description, "Updated desc")

        // All should have same ID
        XCTAssertEqual(titleUpdated.id, originalTask.id)
        XCTAssertEqual(statusUpdated.id, originalTask.id)
        XCTAssertEqual(descriptionUpdated.id, originalTask.id)
    }
}

// MARK: - Test Extensions

private extension Task {
    var description: String {
        return "Task(id: \(id), title: \(title), status: \(status.rawValue))"
    }

    var debugDescription: String {
        return description
    }
}

// MARK: - Error Types

enum TaskValidationError: Error, Equatable {
    case invalidTitle
    case titleTooLong
    case descriptionTooLong
    case invalidCreatedAt
    case invalidUpdatedAt
}
