//
// SessionLogger.swift
// Wool
//
// Created by Kayis Rahman on 03/11/25.
//

import Foundation
import Observation

// Domain models and infrastructure
// (Types should be available in the same module)

@MainActor
@Observable
final class SessionLogger {
    private(set) var records: [SessionRecordDto] = []

    private let storageKey = "SessionLogger.records.v1"

    init() {
        load()
    }

    func add(record: SessionRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }

        // Convert the domain model to its persisted session record.
        let dto = SessionRecordDto(
            id: record.id,
            startedAt: record.startedAt,
            duration: record.duration,
            kind: record.kind.rawValue,
            taskId: record.taskId,
            taskTitleSnapshot: record.taskTitleSnapshot
        )
        records.append(dto)
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Handle error
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([SessionRecordDto].self, from: data) {
            records = decoded
        }
    }

}
