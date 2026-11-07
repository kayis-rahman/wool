//
//  SessionRecordDto.swift
//  Wool
//
//  Created by Kayis Rahman on 02/01/26.
//

import Foundation

public struct SessionRecordDto: Codable, Identifiable {
    public let id: UUID
    public let userId: UUID?
    public let startedAt: Date
    public let durationSeconds: Int
    public let kind: String
    public let taskId: UUID?
    public let taskTitleSnapshot: String?

    public init(
        id: UUID,
        startedAt: Date,
        duration: TimeInterval,
        kind: String,
        taskId: UUID? = nil,
        taskTitleSnapshot: String? = nil
    ) {
        self.id = id
        self.userId = nil // Will be set by server
        self.startedAt = startedAt
        self.durationSeconds = Int(duration)
        self.kind = kind.uppercased()
        self.taskId = taskId
        self.taskTitleSnapshot = taskTitleSnapshot
    }

    public var isProductive: Bool {
        kind.uppercased() == "WORK"
    }
}
