import Foundation
import os
import SwiftUI
import Observation
import _Concurrency

enum Phase: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case work = "work"
    case `break` = "short_break"
    case longBreak = "long_break"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .break: return "Break"
        case .longBreak: return "Long Break"
        }
    }
}

@MainActor
@Observable
class PomodoroTimer {
    var phase: Phase = .work
    var remainingSeconds: Int = 25 * 60
    var isRunning: Bool = false
    var shortBreaksCompleted: Int = 0
    var autoStartNextSession: Bool = true
    private(set) var currentTaskId: UUID?
    private(set) var currentTaskTitleSnapshot: String?
    private(set) var activeSessionId: UUID?
    private(set) var sessionStartedAt: Date?
    private(set) var accumulatedElapsedSeconds: Int = 0
    private(set) var runStartedAt: Date?
    private(set) var lastReconciledAt: Date?
    private(set) var endAt: Date?

    private(set) var workDuration: Int = 25 * 60
    private(set) var breakDuration: Int = 5 * 60
    private(set) var longBreakDuration: Int = 15 * 60
    let cycleSize: Int = 4
    var onSessionCompleted: ((Phase, Int) -> Void)?
    var onFocusSessionCompleted: ((SessionRecord) -> Void)?

    private var timerTask: _Concurrency.Task<Void, Never>?
    var startTimestamp: Double?
    var pauseTimestamp: Double?
    private(set) var lastModifiedTimestamp: Double

    init() {
        self.workDuration = 25 * 60
        self.breakDuration = 5 * 60
        self.longBreakDuration = 15 * 60
        self.remainingSeconds = 25 * 60
        self.phase = .work
        self.isRunning = false
        self.autoStartNextSession = false
        self.shortBreaksCompleted = 0
        self.currentTaskId = nil
        self.currentTaskTitleSnapshot = nil
        self.activeSessionId = nil
        self.sessionStartedAt = nil
        self.accumulatedElapsedSeconds = 0
        self.runStartedAt = nil
        self.lastReconciledAt = nil
        self.endAt = nil
        self.startTimestamp = nil
        self.pauseTimestamp = nil
        self.lastModifiedTimestamp = Date().timeIntervalSince1970
    }

    // Internal constructor for tests with custom durations
    internal init(workDuration: Int, breakDuration: Int, longBreakDuration: Int = 15 * 60) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.remainingSeconds = workDuration
        self.phase = .work
        self.isRunning = false
        self.autoStartNextSession = false
        self.shortBreaksCompleted = 0
        self.currentTaskId = nil
        self.currentTaskTitleSnapshot = nil
        self.activeSessionId = nil
        self.sessionStartedAt = nil
        self.accumulatedElapsedSeconds = 0
        self.runStartedAt = nil
        self.lastReconciledAt = nil
        self.endAt = nil
        self.startTimestamp = nil
        self.pauseTimestamp = nil
        self.lastModifiedTimestamp = Date().timeIntervalSince1970
    }

    var progress: Double {
        let current = Double(currentDuration) - Double(remainingSeconds)
        let total = Double(currentDuration)
        return total > 0 ? current / total : 0
    }

    var currentDuration: Int {
        switch phase {
        case .work: return workDuration
        case .break: return breakDuration
        case .longBreak: return longBreakDuration
        }
    }

    func start() {
        guard !isRunning else { return }
        let now = Date()
        if activeSessionId == nil {
            activeSessionId = UUID()
            sessionStartedAt = now
            accumulatedElapsedSeconds = 0
        }
        isRunning = true
        runStartedAt = now
        lastReconciledAt = now
        startTimestamp = now.timeIntervalSince1970
        endAt = now.addingTimeInterval(TimeInterval(max(0, remainingSeconds)))
        lastModifiedTimestamp = startTimestamp!
        persistLifecycle(status: .running, now: now)
        persistState(now: now)
        scheduleCompletionNotification()
        #if os(iOS)
        FocusLiveActivityManager.shared.sync(with: self)
        #endif
        startTimer()
    }

    func pause() {
        guard isRunning else { return }
        reconcile(now: Date(), completeExpired: false)
        isRunning = false
        pauseTimestamp = Date().timeIntervalSince1970
        lastModifiedTimestamp = pauseTimestamp!
        endAt = nil
        persistLifecycle(status: .paused)
        persistState()
        cancelCompletionNotification()
        stopTimer()
        #if os(iOS)
        FocusLiveActivityManager.shared.sync(with: self)
        #endif
    }

    func reset() {
        if activeSessionId != nil {
            persistLifecycle(status: .abandoned)
        }
        stopTimer()
        remainingSeconds = currentDuration
        phase = .work
        isRunning = false
        shortBreaksCompleted = 0
        startTimestamp = nil
        pauseTimestamp = nil
        currentTaskId = nil
        currentTaskTitleSnapshot = nil
        activeSessionId = nil
        sessionStartedAt = nil
        accumulatedElapsedSeconds = 0
        runStartedAt = nil
        lastReconciledAt = nil
        endAt = nil
        lastModifiedTimestamp = Date().timeIntervalSince1970
        FocusTimerPersistence.clear()
        cancelCompletionNotification()
        #if os(iOS)
        FocusLiveActivityManager.shared.end()
        #endif
    }

    func advance() {
        let previousPhase = phase
        let previousDuration = currentDuration
        let completedSession = activeSessionId.map {
            SessionRecord(
                id: $0,
                startedAt: sessionStartedAt ?? Date(),
                duration: TimeInterval(max(0, accumulatedElapsedSeconds)),
                kind: sessionKind(for: previousPhase),
                taskId: currentTaskId,
                taskTitleSnapshot: currentTaskTitleSnapshot
            )
        }
        switch previousPhase {
        case .work:
            shortBreaksCompleted += 1
            if shortBreaksCompleted >= cycleSize {
                phase = .longBreak
                remainingSeconds = longBreakDuration
            } else {
                phase = .break
                remainingSeconds = breakDuration
            }
        case .break:
            phase = .work
            remainingSeconds = workDuration
        case .longBreak:
            phase = .work
            remainingSeconds = workDuration
        }

        lastModifiedTimestamp = Date().timeIntervalSince1970
        if let completedSession {
            persistLifecycle(status: .completed)
            onFocusSessionCompleted?(completedSession)
        }
        onSessionCompleted?(previousPhase, previousDuration)
        activeSessionId = nil
        sessionStartedAt = nil
        accumulatedElapsedSeconds = 0
        runStartedAt = nil
        lastReconciledAt = nil
        endAt = nil
        persistState()
        cancelCompletionNotification()
        #if os(iOS)
        FocusLiveActivityManager.shared.sync(with: self)
        #endif
    }

    /// Handle timer reaching zero — advance phase and optionally auto-start
    func handleTimerCompletion() {
        guard isRunning else { return }
        reconcile(now: Date(), completeExpired: false)
        isRunning = false
        advance()
        if autoStartNextSession {
            start()
        }
    }

    var snapshot: FocusTimerSnapshot {
        FocusTimerSnapshot(
            activeSessionId: activeSessionId,
            phase: phase,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            shortBreaksCompleted: shortBreaksCompleted,
            autoStartNextSession: autoStartNextSession,
            currentTaskId: currentTaskId,
            taskTitleSnapshot: currentTaskTitleSnapshot,
            sessionStartedAt: sessionStartedAt,
            accumulatedElapsedSeconds: accumulatedElapsedSeconds,
            runStartedAt: runStartedAt,
            lastReconciledAt: lastReconciledAt,
            endAt: endAt,
            savedAt: Date()
        )
    }

    func persistState(now: Date = Date()) {
        let current = snapshot
        FocusTimerPersistence.save(FocusTimerSnapshot(
            activeSessionId: current.activeSessionId,
            phase: current.phase,
            remainingSeconds: current.remainingSeconds,
            isRunning: current.isRunning,
            shortBreaksCompleted: current.shortBreaksCompleted,
            autoStartNextSession: current.autoStartNextSession,
            currentTaskId: current.currentTaskId,
            taskTitleSnapshot: current.taskTitleSnapshot,
            sessionStartedAt: current.sessionStartedAt,
            accumulatedElapsedSeconds: current.accumulatedElapsedSeconds,
            runStartedAt: current.runStartedAt,
            lastReconciledAt: current.lastReconciledAt,
            endAt: current.endAt,
            savedAt: now
        ))
    }

    func restorePersistedState(now: Date = Date()) {
        guard let saved = FocusTimerPersistence.load() else { return }
        phase = saved.phase
        remainingSeconds = max(0, saved.remainingSeconds)
        isRunning = saved.isRunning
        shortBreaksCompleted = saved.shortBreaksCompleted
        autoStartNextSession = saved.autoStartNextSession
        currentTaskId = saved.currentTaskId
        currentTaskTitleSnapshot = saved.taskTitleSnapshot
        activeSessionId = saved.activeSessionId
        sessionStartedAt = saved.sessionStartedAt
        accumulatedElapsedSeconds = max(0, saved.accumulatedElapsedSeconds)
        runStartedAt = saved.runStartedAt
        lastReconciledAt = saved.lastReconciledAt
        endAt = saved.endAt
        if isRunning {
            reconcile(now: now)
            if isRunning {
                startTimer()
                scheduleCompletionNotification()
            }
        }
        #if os(iOS)
        FocusLiveActivityManager.shared.sync(with: self)
        #endif
    }

    @discardableResult
    func reconcile(now: Date = Date(), completeExpired: Bool = true) -> Int {
        guard isRunning, let endAt else { return remainingSeconds }
        let remaining = max(0, Int(ceil(endAt.timeIntervalSince(now))))
        remainingSeconds = min(currentDuration, remaining)
        if let lastReconciledAt {
            accumulatedElapsedSeconds += max(0, Int(now.timeIntervalSince(lastReconciledAt)))
        } else if let runStartedAt {
            accumulatedElapsedSeconds += max(0, Int(now.timeIntervalSince(runStartedAt)))
        }
        self.lastReconciledAt = now
        lastModifiedTimestamp = now.timeIntervalSince1970
        if remainingSeconds == 0 && completeExpired {
            handleTimerCompletion()
        } else {
            persistState(now: now)
        }
        return remainingSeconds
    }

    /// Internal setter for lastModifiedTimestamp (tests only)
    internal func setLastModifiedTimestamp(_ value: Double) {
        lastModifiedTimestamp = value
    }

    func applySyncedState(
        phase: Phase,
        remainingSeconds: Int,
        isRunning: Bool,
        workDuration: Int,
        breakDuration: Int,
        longBreakDuration: Int,
        autoStartNextSession: Bool,
        shortBreaksCompleted: Int,
        startTimestamp: Double?,
        pauseTimestamp: Double?,
        lastModifiedTimestamp: Double
    ) {
        // Backend recomputes liveRemaining server-side against its own clock
        // (TimerSyncService.applyLiveElapsed + PushNotificationService),
        // so trust the value as-is. Doing a second elapsed subtraction here
        // would double-count and make remote devices show wrong remaining.
        self.phase = phase
        self.remainingSeconds = max(0, remainingSeconds)
        self.isRunning = isRunning
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.autoStartNextSession = autoStartNextSession
        self.shortBreaksCompleted = shortBreaksCompleted
        self.startTimestamp = startTimestamp
        self.pauseTimestamp = pauseTimestamp
        self.lastModifiedTimestamp = lastModifiedTimestamp

        if isRunning {
            startTimer()
        } else {
            stopTimer()
        }
        #if os(iOS)
        FocusLiveActivityManager.shared.sync(with: self)
        #endif
    }

    /// Selects the task for the current or next session. Task attribution is
    /// immutable once a session is running; the next session can use a new
    /// selection after pause/reset/completion.
    @discardableResult
    func selectTask(id: UUID?, title: String?) -> Bool {
        guard !isRunning else { return false }
        currentTaskId = id
        currentTaskTitleSnapshot = title
        persistState()
        return true
    }

    private func startTimer() {
        stopTimer()
        timerTask = _Concurrency.Task {
            while self.isRunning && remainingSeconds > 0 {
                try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    if self.isRunning && remainingSeconds > 0 {
                        self.reconcile(now: Date())
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    func updateDurations(workMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int) {
        guard !isRunning else { return }
        self.workDuration = workMinutes * 60
        self.breakDuration = shortBreakMinutes * 60
        self.longBreakDuration = longBreakMinutes * 60
        self.remainingSeconds = 25 * 60
        self.phase = .work
        self.isRunning = false
        self.autoStartNextSession = false
        self.shortBreaksCompleted = 0
        self.currentTaskId = nil
        self.currentTaskTitleSnapshot = nil
        self.activeSessionId = nil
        self.sessionStartedAt = nil
        self.accumulatedElapsedSeconds = 0
        self.runStartedAt = nil
        self.lastReconciledAt = nil
        self.endAt = nil
        self.startTimestamp = nil
        self.pauseTimestamp = nil
        self.lastModifiedTimestamp = Date().timeIntervalSince1970
        FocusTimerPersistence.clear()
        cancelCompletionNotification()
    }

    func resetDurationsToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(workDuration / 60, forKey: "workDuration")
        defaults.set(breakDuration / 60, forKey: "breakDuration")
        defaults.set(longBreakDuration / 60, forKey: "longBreakDuration")
    }

    private func sessionKind(for phase: Phase) -> SessionRecord.Kind {
        switch phase {
        case .work: return .work
        case .break: return .shortBreak
        case .longBreak: return .longBreak
        }
    }

    private func scheduleCompletionNotification() {
        guard let endAt else { return }
        NotificationManager.shared.scheduleSessionDoneNotification(
            phase: phase.rawValue,
            taskTitle: currentTaskTitleSnapshot,
            at: endAt
        )
    }

    private func persistLifecycle(status: FocusSessionStatus, now: Date = Date()) {
        guard let activeSessionId, let sessionStartedAt else { return }
        FocusSessionLifecycleStore.save(FocusSessionLifecycleRecord(
            id: activeSessionId,
            phase: phase,
            status: status,
            startedAt: sessionStartedAt,
            lastUpdatedAt: now,
            accumulatedElapsedSeconds: max(0, accumulatedElapsedSeconds),
            taskId: currentTaskId,
            taskTitleSnapshot: currentTaskTitleSnapshot
        ))
    }

    private func cancelCompletionNotification() {
        NotificationManager.shared.cancelSessionDoneNotification()
    }
  }
