# Wool App Features

Wool is a privacy-first, on-device task manager
for iOS, macOS, and watchOS. The app keeps everyday task data local to the
user's Apple devices and uses CloudKit private database sync when available.

## Core task organization Structure

- **Inbox** — a fast capture point for unprocessed thoughts and tasks.
- **Next Actions** — concrete tasks that are ready to do.
- **Waiting For** — delegated or blocked tasks, including what the user is
  waiting on.
- **Someday/Maybe** — ideas and tasks that are not currently actionable.
- **Projects** — multi-step outcomes linked to their next actions; archived
  outcomes preserve their linked tasks and can be restored later.
- **Areas** — cross-cutting context tags such as Work, Personal, Health, and
  Finance.
- **Weekly Review** — a structured checklist and workflow for maintaining the
  system.

Each task supports a title, notes, creation and update dates, an optional due
date, an optional project, zero or more Areas, context tags, task status, sort
order, and completion time. Completed and cancelled tasks are excluded from
open-work surfaces.

Projects carry a desired outcome, notes, status, and linked tasks. Archiving is
reversible and preserves the project's previous status; completing a project
is blocked while it still has Next Actions or Waiting For tasks. Areas are
named, normalized, case/diacritic-insensitive tags. Deleting an Area
unlinks it from tasks without deleting those tasks or their other Areas.

## App Navigation

The primary iOS workspace uses five tabs:

1. **Today** — daily briefing, due Next Actions, overdue Waiting For items,
   and calendar context.
2. **Inbox** — unprocessed captures, search, quick capture, and triage.
3. **Projects** — active outcomes and their linked actions, with a reversible
   archive for projects that are set aside.
4. **Focus** — Pomodoro timer connected to the task being worked on.
5. **Review** — Weekly Review, Someday/Maybe, Areas overview, and review
   streaks.

Areas are available as filters across Today, Inbox, and Projects rather than
as a separate workflow tab. Settings and integrations are accessed from the
navigation bar.

## Quick Capture

Quick Capture is designed to remove friction. A user can save a thought to
Inbox without deciding its category first.

- Capture is available from the app and through Siri/Shortcuts.
- New captures are saved as **Inbox** items until explicitly triaged.
- The save path is local-first and does not wait for Foundation Models.
- Empty titles are rejected and blank items cannot be saved.
- Duplicate text is allowed; each capture remains a separate item.
- Very long text is preserved in full in SwiftData.
- Foundation Models input is bounded to 4,000 characters during triage to
  protect prompt limits; the stored capture is not truncated.
- Captures may include notes, due dates, projects, areas, and context tags.

The shared capture service is `CaptureService`. In-app capture and the
`AddCaptureIntent` use the same Inbox capture workflow and persistence service.

## Triage and On-Device Intelligence

When the user starts triage, Wool attempts to use Foundation Models on
supported devices to suggest:

- task status: Inbox, Next Action, Waiting For, or Someday/Maybe.
- An Area tag.
- A due date when the capture explicitly mentions one.

If Foundation Models is unavailable, Wool falls back to local heuristics
for action verbs, waiting language, area names, and simple dates. Triage does
not require a server or remote AI service. The in-app capture flow persists the
raw item in Inbox first, then presents an editable confirmation screen with
status, Area, due date, project, and tags pre-filled from the best available
classification. Users can manually override every suggestion before confirming.

Confirmation is immediate: users may confirm without editing, or cancel/back
out and leave the item as an uncategorized Inbox capture. Foundation Models
timeouts and failures fall back to heuristics without blocking the screen.
Single captures always show confirmation. Inbox triage reuses the same
classifier for existing captures and persists the resulting status, tags, and
due date when the caller saves. Batch-import bypass remains intended for large
imports.

## Daily Briefing

The Today view is intended as the default landing surface and can summarize:

- Next Actions due today, with up to five undated Next Actions shown as “Up
  next.”
- All overdue open tasks, including overdue Waiting For follow-ups.
- If nothing is due today, an explicit Waiting For count (or positive empty
  state) is shown instead of a blank briefing.
- Relevant calendar overlap when EventKit access is enabled; unavailable,
  denied, or malformed calendar data is omitted without blocking the briefing.
- Calendar context is read-only and live-fetched for the current briefing; all-day
  events appear separately from timed events, with the initial timed list capped
  at ten events and an explicit way to reveal more.
- A short AI-generated framing of the day's work when on-device inference is
  available. Any unavailable, failed, or blank response falls back to
  deterministic plain lists for due today, overdue, Waiting For, and Up next.

## Weekly Review

Weekly Review is a persisted guided workflow rather than a reminder. A review
contains six ordered steps:

1. Collect loose ends.
2. Process the Inbox.
3. Review stale Someday/Maybe and Waiting For items.
4. Review projects for missing Next Actions.
5. Review Waiting For follow-ups.
6. Look ahead and plan.

Each step can be completed or skipped. Progress is saved immediately, the
first incomplete step is restored after relaunch, and opening the flow again
reuses the current week's in-progress review. A completed review cannot be
silently reopened; a new review is created after the prior one is complete.

The stale-item step snapshots items older than 30 days. It offers Promote to
Next Action, Keep, and Delete decisions, removes items that were completed or
cancelled elsewhere, and does not inject newly stale items into an existing
review. An empty stale set is marked complete automatically. Unresolved stale
items or skipped steps produce a partial review; otherwise the review is fully
complete. Review history and a consecutive-week streak are retained, with
duplicate reviews in one week counted once.

The Review screen also shows completion counts, Waiting For count, streak,
project health, and an optional on-device reflection prompt. Local
notifications route to `wool://daily-briefing`, `wool://weekly-review`, and
`wool://inbox`. The Start weekly review App Intent creates or resumes the
same persisted flow.

## Focus and Work Sessions

Focus is an iOS Pomodoro timer with Work, short Break, and Long Break phases.
The default durations are 25, 5, and 15 minutes, with a four-work-session
cycle. Users can start without selecting a task, or link a session to an open
task; the task title is snapshotted into the session record. Pause, resume,
reset, automatic next-session start, completion notifications, sound, haptics,
and background/foreground time reconciliation are supported.

Focus sessions are stored locally with task identity and duration history.
Today’s Focus surface shows productive time, session count, cycle progress, the
current task, and up to four Up next tasks. Focus history can be cleared from
Settings. Timer state and actions can be synchronized across configured Apple
devices, with queued actions, timestamp conflict handling, exponential retry
backoff, and Watch Connectivity support.

## Projects, Areas, and Task History

The Projects surface separates active, completed, cancelled, and archived
outcomes, reports progress, and supports linked-task editing. The Review
surface includes an Areas overview; Areas can filter Today, Inbox, and
Projects, including an Uncategorized view. Task details support editing
status, notes, due date, project, Areas, and context tags without changing the
task identity.

## Settings

Settings provides Focus duration controls, Sound & Haptics, Appearance
(system/light/dark), Integrations, Account & Sync, Support & About, and Data &
Privacy. Data & Privacy also includes exporting all data as JSON or tasks as CSV and restoring from a JSON backup. Sign in with Apple is available for account-backed synchronization;
signing out leaves local data on the device. Debug builds can expose a Feature
Flags screen. Known remote flags are namespaced, default to disabled, cached
with version metadata, and take effect on the next launch.

## Siri, Shortcuts, and Spotlight

Wool exposes App Intents through `AppShortcutsProvider`:

- **Capture an item** — save text directly to Inbox.
- **Add a next action** — save a task directly to Next Actions.
- **Start weekly review** — create and open a structured review flow.
- **Start focus** — open Focus and start a work session.
- **Complete task** — fuzzy-match an open task and mark it complete.
- **Show next actions** — read today's open Next Actions.
- **Daily briefing** — read today's briefing through Siri/Shortcuts.

Capture and Next Action intents use the shared capture service and persist
locally. Intent setup errors report when the app or iCloud account needs
configuration. The review and focus intents open the app at their destination;
the remaining read/write intents run without opening it where possible.

## Persistence and Sync

- SwiftData is the source of truth for task, project, area, and review models.
- CloudKit uses the private database for per-user synchronization.
- Captures remain available from the local store while offline.
- CloudKit synchronizes local changes when connectivity returns.
- Keychain is reserved for local secrets and credentials.
- UI tests use an isolated local SwiftData store with CloudKit disabled.

## Authentication and Privacy

- Sign in with Apple is the supported authentication flow.
- No Spring Boot backend, PostgreSQL database, custom JWT service, or REST
  task API is required for the task organization workflow.
- AI classification and summaries are designed to run on-device.
- Private CloudKit data belongs to the signed-in user's private database.

## Integrations

Planned or available integration surfaces include:

- **EventKit** — calendar awareness for the Daily Briefing.
- **Gmail** — on-device OAuth and actionable email capture.
- **GitHub Projects** — map issues/cards to Next Actions or Waiting For.
- **Apple Reminders** — one-time import for migration.

Integrations should be opt-in and should not prevent core local capture,
triage, focus, or review workflows from working offline. EventKit and Gmail
have implemented integration surfaces; GitHub Projects and Apple Reminders
remain planned/flagged surfaces rather than completed integrations.

### Gmail Integration

Gmail is currently iOS-only and is guarded by the
`features.gmailIntegration` feature flag. The integration uses read-only OAuth,
stores credentials in Keychain, and imports Inbox messages from the last 30
days. Imported messages are persisted locally as Inbox items before any
classification is applied; uncertain messages remain available for manual
triage. Stable Gmail message IDs prevent duplicate imports, and persisted page
checkpoints allow interrupted syncs to resume safely.

Gmail access can be paused when authorization expires or is revoked. Existing
local Inbox items are retained when the account is disconnected. Live OAuth
requires the iOS build to provide `GMAIL_OAUTH_CLIENT_ID` and
`GMAIL_OAUTH_REDIRECT_URI` Info.plist values. Automated UI tests use deterministic
fixtures and never require a live Gmail account.

## In-App Voice Capture

The capture sheet supports English voice entry through native iOS speech
recognition. Transcription is shown live, remains editable, and flows through
the same raw Inbox persistence and confirmation workflow as typed capture.

- Voice drafts are never persisted until the user submits the capture.
- Recording stops manually; a five-second no-speech timeout offers retry or
  text entry.
- Permission failures, audio interruptions, and backgrounding preserve any
  visible partial transcript and leave text entry available.
- Long speech is preserved in full; the existing 4,000-character Foundation
  Models prompt bound still applies during triage.
- Malayalam is gated by `features.malayalamVoice`. The app has an injectable
  bridge contract and reports “Voice bridge offline” with English/text fallback
  until the Pi/IndicWhisper wire protocol is supplied.

## Supported Apple Platforms

- iOS 17+
- macOS 14+
- watchOS 10+
- Foundation Models enhancements on supported iOS/macOS releases

The full task organization workspace and current guided-review UI are implemented for iOS.
macOS and watchOS targets remain in the project; Watch Connectivity currently
supports timer state/actions, while watch-specific task organization workflows are not
implemented.

## Verification Coverage

Quick Capture is covered at multiple levels:

- Unit tests for classification, Inbox preservation, long text, dates, and
  notes.
- Persistence tests for App Intent and in-app parity.
- Duplicate-capture tests confirming separate records.
- UI tests for empty-submit prevention, capture-to-Inbox navigation, editable
  confirmation, visible category choices, and cancel/back preservation.
- UI verification on an iOS Simulator.

The broader test suite also covers:

- Weekly Review service behavior, stale-item decisions, streaks, reminders,
  persistence, same-week reuse, and relaunch resume.
- Daily Briefing composition, calendar authorization/failure handling,
  malformed events, local persistence, and deterministic AI fallback.
- Projects and Areas relationships, archive/restore, progress, filtering,
  validation, and deletion semantics.
- Focus timer phases, durations, task linking, session logging, persistence,
  queued sync actions, retry backoff, conflict ordering, and Watch payloads.
- Gmail import idempotency, checkpoints, disconnect behavior, OAuth/Keychain
  handling, and feature-flag defaults/cache/remote refresh behavior.
- App Intents for capture, review, briefing, task completion, and Next Actions.

UI test instructions are documented in
[`ios-ui-tests-on-simulator.md`](ios-ui-tests-on-simulator.md); the optional
physical-device workflow stays in
[`ios-ui-tests-on-iphone-15-pro.md`](ios-ui-tests-on-iphone-15-pro.md).

### Latest Test Run Status

Verified on the physical iPhone 15 Pro (`00008130-000629D90A13803A`):

- Weekly Review service and SwiftData persistence tests: **31 passed, 0
  failed**.
- Weekly Review physical-device UI tests: **5 passed, 0 failed**. Covered
  checklist start, skipping/partial completion, empty stale state, relaunch
  resume, and unresolved stale-item completion.

- Quick-capture unit and persistence tests: **13 passed, 0 failed**.
- Capture App Intent tests: **3 passed, 0 failed**.
- Focused physical-device confirmation UI test: **1 passed, 0 failed**.
- Focused physical-device cancel/back preservation UI test: **1 passed, 0 failed**.
- Voice capture unit/service tests: **6 passed, 0 failed**.
- Voice capture SwiftData/integration tests: **8 passed, 0 failed**.
- Focused physical-device voice UI tests: **4 passed, 0 failed**.
- App target `build-for-testing`: **passed**.

The complete `WorkspaceUITests` suite remains pending. Focused Weekly Review
and voice tests passed on the physical iPhone 15 Pro; the full suite should be
run later to cover batch import and the remaining workspace scenarios. Xcode
27 emitted intermittent DeviceSupport/LLDB snapshot warnings during the
physical runs, but the result bundles reported no test failures.
