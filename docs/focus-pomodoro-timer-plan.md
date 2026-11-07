# Focus/Pomodoro Timer Implementation Plan

## Summary

As a user, I want to start a focus session associated with a task, see reliable remaining time, and have the session recorded accurately if the app is backgrounded, interrupted, offline, or relaunched.

A task is optional. If no task is selected, the session starts normally and is recorded as a generic `Focus Session`.

The repository already contains most of the Apple-project timer foundation: `PomodoroTimer`, task selection, session logging, notification support, timer synchronization, and analytics. The implementation should strengthen session identity, lifecycle recovery, persistence, and task attribution.

## Current implementation status

### Test coverage added

- Unit tests now cover generic no-task sessions, selected-task retention, reset cleanup, duplicate starts, and task metadata preservation during DTO conversion.
- Swift integration tests now cover local generic-session persistence, task-linked session persistence, active timer snapshot restoration, deterministic UUID fixtures, and an isolated SwiftData task fixture with CloudKit disabled.
- UI tests now cover the no-task start flow, pause/resume, explicit `No Task` selection, and background/foreground recovery.

### Supporting fixes included

- `SessionRecord` and `SessionRecordDto` now carry `taskId` and `taskTitleSnapshot`.
- `SessionLogger` preserves task metadata when converting domain records to DTOs.
- `SessionLogger` ignores duplicate session IDs so repeated completion callbacks do not duplicate history.
- Resetting the timer clears the current task association.
- Active timer state now persists a session ID, task metadata, phase, remaining time, absolute end time, and reconciliation timestamps.
- Foreground/background lifecycle hooks reconcile and persist the timer.
- Focus completion notifications are scheduled and cancelled through a stable request identifier.
- Completed phases emit a task-aware `SessionRecord` callback for local logging.

### Validation status

- Static whitespace validation passes with `git diff --check`.
- The repository `back-end` directory is no longer in the workspace; this feature is scoped to the Apple project.
- Automated execution remains pending; the UI tests can run on an iOS Simulator (`docs/ios-ui-tests-on-simulator.md`).
- The Mac test-host attempt is blocked by the project’s iOS test-host/signing configuration: the available Mac provisioning profile lacks Push Notifications, Sign in with Apple, and iCloud entitlements.
- No simulator UI-test result has been reported for this feature yet.

### Remaining implementation and test work

The tests establish the currently supported task/session behavior, but the full lifecycle plan is not complete yet. Remaining work includes durable lifecycle-record persistence beyond the active snapshot, pause-aware actual-duration accounting, idempotent completion/upload handling, richer interruption status, task-change locking while running, and simulator execution of the new UI tests.

## Product behavior

### Starting

- Allow starting with a selected task or with no task.
- Create a stable session UUID immediately when starting.
- Snapshot the task ID and, preferably, the task title at start time.
- Persist the active session before or atomically with starting the countdown.
- Do not require notification permission in order to start.
- Ignore or disable repeated start taps while already running.

### Running, pausing, and resetting

- Calculate remaining time from an absolute end timestamp, not only from an in-memory one-second decrement loop.
- Keep the active task visible throughout the session.
- Prevent changing task attribution while running; a task change applies to the next session.
- Pause preserves the same session ID and task association.
- Resume continues the same session.
- Reset abandons the current session and excludes it from completed productive totals.
- Confirm reset once meaningful time has elapsed.
- Clear the task association when resetting the timer so stale task IDs cannot leak into a later session.

### Completion

Complete each session exactly once and record:

- session UUID;
- optional task ID and task-title snapshot;
- phase/kind;
- planned duration;
- actual focused duration;
- start and end timestamps;
- completion status; and
- interruption metadata, when applicable.

After completion, advance to the next phase and schedule the completion notification. If auto-start is enabled, persist the completed state before starting the next phase.

### No-task behavior

- Start normally with `taskId == nil`.
- Display `Focus Session` in the active UI and history.
- Count the duration toward total focus time.
- Exclude it from task-specific breakdowns.
- Do not show an error or block the user.

## Edge cases

### Lifecycle and interruptions

- Backgrounding while running: continue elapsed time using timestamps.
- Returning from background: reconcile immediately before rendering the timer.
- Remaining backgrounded until completion: deliver a local notification at the expected end time.
- Incoming phone call: keep the timer running unless the user explicitly pauses or stops it.
- App suspension, force-quit, or termination: recover persisted state on the next launch.
- Device reboot: recover the active session when persisted state is available.
- Notification permission denied or later revoked: timer continues without notifications.
- Device clock changes: clamp invalid elapsed/remaining values and record a diagnostic event.
- Time-zone or DST changes: calculate elapsed time in seconds rather than calendar units.

iOS background tasks are not precise enough for second-by-second timing. Persist `endAt` and schedule a local notification. Use background tasks only for best-effort reconciliation and upload retry.

### Timer state

- Double-tap start.
- Pause, reset, or completion occurring at the same boundary.
- Timer expiring while the app is inactive.
- Foreground reconciliation and notification handling both attempting completion.
- Resume after a partial session.
- Relaunch with a paused, running, or already-expired session.
- Corrupt or partially written state.
- Negative remaining time after reconciliation.
- Duration settings changing during an active session.
- Very short test durations.
- Auto-start enabled or disabled.
- Short-break cycle reaching the long-break threshold.
- Completion callback firing more than once.

Completion must be idempotent using the session UUID.

### Task association

- Task deleted, archived, completed, edited, or unavailable during a session.
- Local task is unavailable when the session is restored.
- Task changed while paused.
- No task selected at start, then a task selected before completion.
- Same task modified on multiple devices.

Task association is immutable for a running session. Preserve the original task ID and title snapshot so history remains readable after deletion or renaming.

### Persistence, sync, and authentication

- Start, pause, resume, completion, and reset while offline.
- Upload succeeds but the response is lost.
- Upload retries after a network or authentication failure.
- Duplicate upload or duplicate completion.
- User signs out with an active session.
- CloudKit sync returns an older timer state.
- Multiple devices modify the timer concurrently.
- Session history is imported repeatedly.

Use the session UUID as the idempotency key. Local persistence is authoritative for the immediate UI; synchronization is retryable and must not duplicate records or resurrect completed/abandoned state.

### Analytics

- Generic sessions count toward total focus time but not task breakdowns.
- Paused sessions count only active elapsed time.
- Abandoned sessions do not count as completed productive sessions.
- Partially completed sessions remain distinguishable from completed sessions.
- Sessions crossing midnight follow one documented attribution rule, preferably start-date attribution.
- Deleted tasks retain historical task-title snapshots.
- Duplicate sync responses do not double-count analytics.

## Data model changes

Expand the current session model toward:

```swift
struct FocusSession: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let taskID: UUID?
    let taskTitleSnapshot: String?
    let kind: SessionKind
    let plannedDurationSeconds: Int
    let startedAt: Date
    var endedAt: Date?
    var accumulatedDurationSeconds: Int
    var status: Status
    var interruptionReason: InterruptionReason?
}
```

Use statuses `running`, `paused`, `completed`, and `abandoned`. Use interruption reasons such as `userStopped`, `appTerminated`, `phoneCall`, `systemInterruption`, and `unknown`.

Backgrounding must not automatically mark a session interrupted. A call can be recorded as metadata while the timer continues.

Persist active timer state containing:

- active session UUID;
- task ID and title snapshot;
- phase;
- remaining seconds;
- absolute `endAt`;
- accumulated elapsed seconds;
- running/paused state;
- last reconciliation timestamp;
- notification request ID; and
- state version.

## Implementation phases

### 1. Reconcile the persistence contract

- Choose one canonical client model name and lifecycle representation.
- Add task ID, completion state, interruption fields, planned duration, and actual duration semantics consistently across client models and DTOs.
- Define whether break records inherit a task ID.
- Define start-date attribution for sessions crossing midnight.

### 2. Build a deterministic timer state machine

Implement explicit transitions:

`idle → running`, `running → paused`, `paused → running`, `running → completed`, `running/paused → abandoned`, and `completed → next phase`.

Add pure logic for elapsed-time calculation, timestamp reconciliation, expiry handling, state validation, clock anomalies, and idempotent completion. Keep UI-facing state on the main actor and use value-type snapshots for persisted state.

### 3. Add durable local persistence

Persist active timer state, sessions, and pending uploads using the app’s durable persistence layer. The active timer snapshot is currently persisted through versioned `UserDefaults`; move lifecycle records and pending uploads to the app’s durable model layer before shipping.

### 4. Correct session logging

Update `SessionLogger` to preserve `taskId`, task-title snapshots, actual duration, lifecycle status, and interruption metadata. Add duplicate-ID protection, pending-upload retry, and merging that does not overwrite newer local changes.

### 5. Implement lifecycle and notifications

Add a lifecycle coordinator that persists state on backgrounding, schedules one end-of-phase local notification, removes stale notification requests, reconciles on foreground, and completes expired sessions exactly once. Notification text should use the task title when available and `Focus Session` otherwise.

### 6. Integrate the Focus UI

- Make the no-task state intentional rather than error-like.
- Disable task changes while running.
- Show reset confirmation after meaningful elapsed time.
- Display offline/sync status without blocking timer controls.
- Add accessible labels and stable UI-test identifiers.
- Use monospaced countdown digits.
- Animate only meaningful state changes: press feedback, task selection confirmation, completion transition, and banner/notification appearance.

Keep one-second countdown updates visually stable; do not animate every tick. Use restrained press feedback and short ease-out transitions for occasional state changes.

### 7. Extend synchronization

Include active session UUID, task association, `endAt`, accumulated duration, lifecycle status, and a version/last-modified value in timer synchronization payloads.

Use newest-valid-state resolution. Completed or abandoned state must not be resurrected by a stale device. Equal-timestamp completion should win over running state.

## Test plan

### Unit tests

Cover start with/without a task, task immutability, pause/resume duration, reset/abandonment, completion idempotency, foreground reconciliation, expired background sessions, clock changes, notification denial, auto-start, phase transitions, deleted-task snapshots, generic-session display, and duplicate upload prevention.

Extend:

- `PomodoroTimerSessionTests.swift`
- `SessionLoggerTests.swift`

### SwiftData and integration tests

Verify active and paused state across relaunch, expired-session completion exactly once, generic sessions with null task IDs, task-linked sessions, deleted-task history, offline queue/retry, duplicate upload handling, CloudKit conflict resolution, and deterministic multi-device state resolution.

### Simulator UI tests

Run on an iOS Simulator. Verify:

- start with a task;
- start without a task;
- `Focus Session` history display;
- pause and resume;
- reset confirmation;
- background and foreground recovery;
- completion notification;
- relaunch with an active session;
- notification permission denial;
- task deletion/archive during a session; and
- task-change behavior while running.

Use `docs/ios-ui-tests-on-simulator.md` and `scripts/run-on-simulator.sh`.

## Current repository gaps to address

- `SessionRecord` still lacks planned duration, completion status, and interruption metadata.
- `PomodoroTimer` now reconciles from an absolute end timestamp, but lifecycle records are not yet durable.
- Session completion does not yet persist a durable lifecycle record.

## Definition of done

- Sessions start with or without tasks.
- Task association survives start, pause, completion, history, and sync.
- Generic sessions display as `Focus Session`.
- Timer state survives backgrounding, suspension, termination, and relaunch.
- Completion notifications are scheduled without blocking timer use when unavailable.
- Pauses do not inflate focused duration.
- Abandoned sessions are excluded from completed productive totals.
- Completion and upload operations are idempotent.
- Local persistence, CloudKit synchronization, and analytics agree.
- Unit, integration, and UI tests pass on an iOS Simulator.
