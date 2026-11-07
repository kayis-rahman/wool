# User Stories with Edge Cases

## 1. Quick Capture

*As a user, I want to quickly add anything to Inbox without deciding its category yet, so my mind stays clear.*

- Edge: empty text submitted → block save, no blank items
- Edge: app offline → capture saves locally, syncs when CloudKit reachable
- Edge: duplicate text captured twice quickly → both save, no dedup (user decides during triage)
- Edge: very long text (paragraph) → capture accepts it, AI triage may need truncation for prompt limits

## 2. AI Auto-Triage

*As a user, I want captured items auto-categorized into task organization buckets, so I don't manually sort everything.*

- Edge: device lacks Apple Intelligence → falls back to heuristic rules, user sees no visible difference in flow
- Edge: AI miscategorizes → user can override with one tap, correction doesn't retrain AI (no learning loop initially)
- Edge: ambiguous text ("mom") → AI defaults to Inbox uncategorized rather than guessing wrong bucket
- Edge: Foundation Models times out/fails → falls back to heuristic silently, no error shown to user

## 3. Next Actions

*As a user, I want a clear list of single concrete tasks I can act on right now.*

- Edge: task has no due date → shows in list unordered/by creation date, not hidden
- Edge: task marked complete → moves to completed log, removed from active list, undo available for 10s
- Edge: task linked to a Project that gets deleted → task orphaned, becomes standalone Next Action, not deleted

## 4. Waiting For

*As a user, I want to track what I'm blocked on and who owes me a response.*

- Edge: no "who" specified → still allowed, field optional, shown as "Waiting For: [unspecified]"
- Edge: waiting item becomes overdue → surfaces in Today briefing, doesn't auto-escalate to Next Action
- Edge: user marks Waiting For as resolved → prompts to convert to Next Action or complete outright

## 5. Someday/Maybe

*As a user, I want to park non-actionable ideas without losing them or cluttering active lists.*

- Edge: Someday item never reviewed → surfaces in Weekly Review as "stale" after 30+ days, not auto-deleted
- Edge: user promotes Someday to Next Action → date fields reset, treated as newly created

## 6. Projects

*As a user, I want to group related Next Actions under a multi-step outcome.*

- Edge: project has zero Next Actions → flagged in Weekly Review as "needs next action defined"
- Edge: project marked complete with open Next Actions inside → warns user, asks to complete/reassign children first
- Edge: project deleted → prompts: delete all linked tasks, or orphan them to standalone

## 7. Areas (filter/tag)

*As a user, I want to filter everything by life context (Work, Health, etc.).*

- Edge: item has no Area assigned → shows under "Uncategorized" filter, not hidden from "all" view
- Edge: Area deleted while items still tagged → items fall back to "Uncategorized," Area removed from filter list
- Edge: user creates duplicate Area name → blocked, case-insensitive uniqueness check
- Edge: duplicate differs only by leading/trailing whitespace → blocked after trimming
- Edge: Area name is blank or whitespace-only → creation blocked with an actionable validation message
- Edge: Area has multiple linked items across Inbox, Next Actions, Waiting For, Someday/Maybe, completed, and cancelled lists → all retain visibility after deletion
- Edge: item has multiple Areas and one Area is deleted → only the deleted relationship is removed; remaining Areas continue to filter the item
- Edge: item has only a deleted Area → becomes Uncategorized
- Edge: a selected Area is deleted → filter resets to All areas instead of showing an empty or stale selection
- Edge: item has a stale `area:` context tag but no live Area relationship → remains Uncategorized and never appears under a deleted Area
- Edge: Area name is renamed → linked items remain linked and filter labels update
- Edge: Area is renamed only by case → allowed without creating a duplicate
- Edge: Area has no linked items → remains selectable and shows a clear empty state
- Edge: multiple Areas exist → filtering matches items assigned to any selected Area and never duplicates an item in All areas
- Edge: Area filter combined with search, status, Inbox, Projects, or Today → filters compose without hiding unrelated matches
- Edge: Area created or deleted offline → local filtering and relationships remain correct; sync reconciles later
- Edge: same Area is created on two devices offline → synchronization resolves the duplicate without silently losing linked tasks
- Edge: Area detail or edit screen is open during deletion → navigation exits safely and task data is preserved
- Edge: long, Unicode, emoji, or diacritic names → display, filtering, and uniqueness checks remain stable and accessible

### Area acceptance tests

- Unit/service: normalize names, reject blank values, reject case/whitespace/diacritic duplicates, and validate stale-tag and multi-Area filtering.
- SwiftData/integration: persist assignments, unlink deleted Areas, preserve remaining assignments, keep unassigned items queryable, and verify deterministic offline/conflict fixtures.
- Simulator UI: create an Area, reject a duplicate, use All areas and Uncategorized filters, filter seeded tasks, delete a linked Area, and verify the resulting Uncategorized state on an iOS Simulator.

## 8. Weekly Review

*As a user, I want a guided flow to review all buckets and keep the system trustworthy.*

- Edge: user exits, backgrounds, force-quits, or crashes mid-review → each completed/skipped step is saved immediately and the review resumes at the first incomplete step
- Edge: user opens the same review repeatedly → one review record is reused for the week; no duplicate checklist or streak entry is created
- Edge: review crosses into a new week → the original in-progress review remains resumable instead of being silently discarded
- Edge: review has been in progress for several weeks → the user can finish the original review while a new week remains available after it is finalized
- Edge: no stale items found → the full checklist remains visible, the stale step says "Nothing stale," and that step is automatically completed without making the review partial
- Edge: stale items are found but user makes no decision → review can finish as "partial complete" and unresolved stale IDs remain saved
- Edge: stale item is completed, cancelled, deleted, or no longer stale elsewhere → it disappears from the current decision list without crashing
- Edge: stale item appears after the review begins → it is deferred to the next review rather than injected into the current snapshot
- Edge: duplicate stale IDs exist → each stale task appears once
- Edge: user chooses Promote, Keep, or Delete on a stale item → the task status changes atomically with removal from the review queue
- Edge: user skips a checklist step → allowed, review marked "partial complete," skipped count saved, and streak still counts
- Edge: user skips every step → review finishes as partial, remains in history, and contributes one streak entry
- Edge: user taps Complete, Skip, or Finish repeatedly → only one state transition and one streak contribution are applied
- Edge: user completes all steps without skipping or unresolved stale items → review is fully complete
- Edge: same-week review exists on another device → newest saved review state is used; no duplicate review is created
- Edge: CloudKit is unavailable or sync is delayed → local review remains usable and sync retries later
- Edge: no prior reviews exist → streak displays zero, not an error
- Edge: a week is missed → current streak resets while historical review records remain intact
- Edge: duplicate reviews exist for one week from legacy data → streak calculation counts that week once
- Edge: device timezone, locale, or first weekday changes → week boundaries are recalculated consistently for new reviews; the original review identity remains stable
- Edge: AI prompt is unavailable, times out, returns empty text, or responds after the user advances → deterministic prompt is used and late AI output cannot overwrite review state
- Edge: Dynamic Type, VoiceOver, Reduce Motion, phone call, Siri interruption, or app suspension → progress controls remain accessible and persisted state is preserved

### Weekly Review acceptance tests

- Unit/service: verify resume selection, same-week reuse, step transitions, skip/partial status, empty-stale auto-completion, stale snapshot refresh, unresolved stale partial completion, idempotent finish, duplicate-week streak handling, date boundaries, and deterministic AI fallback.
- SwiftData/integration: verify progress survives save/reload, same-week review uniqueness, stale-task removal after external completion, local/offline operation, and unique UUID fixtures.
- Simulator UI: on an iOS Simulator, verify starting the checklist, empty-stale completion, resuming after relaunch, skipping steps, unresolved stale partial completion, visible progress, and accessible controls.

## 9. Daily Briefing

*As a user, I want a morning summary of what matters today.*

- Edge: no Next Actions due today → briefing shows "nothing due, X items in Waiting For" instead of empty state
- Edge: no due items and no Waiting For items → briefing shows a positive "all clear" state, not a blank screen
- Edge: undated Next Actions exist → briefing includes an "Up next" section capped at five items, ordered by user sort order
- Edge: overdue Waiting For item exists → it appears in both Overdue and Waiting For context without being duplicated in the count
- Edge: calendar integration is off, denied, unavailable, throws, or returns malformed events → calendar section is omitted and the briefing still renders
- Edge: AI generation fails, times out, is unavailable, or returns blank text → falls back to deterministic plain lists (due today, overdue, Waiting For, Up next) without narrative framing
- Edge: first run with no captured items → briefing offers a capture prompt instead of implying the day is complete

## 10. Siri / App Intents

*As a user, I want to add tasks or start review via Siri without opening the app.*

- Edge: Siri mishears input → intent still saves raw text to Inbox, user corrects later during triage (never silently discard)
- Edge: app not yet launched once (no CloudKit container initialized) → intent fails gracefully, prompts user to open app first
- Edge: multiple intents chained in a Shortcut → each runs independently, no shared state between calls

## 11. Voice Capture — English

*As a user, I want to speak a capture directly in the app, review the live
transcription, and send it through AI Auto-Triage.*

- Edge: dictation permission denied → falls back to text input, offers Settings, and never crashes
- Edge: microphone permission denied or restricted → same text fallback; no partial item is created
- Edge: background noise garbles transcription → live text remains visible and editable before triage
- Edge: user stops after speaking → final transcript flows into editable triage confirmation
- Edge: no speech detected → five-second timeout shows “I didn’t catch that,” with retry/type actions
- Edge: user cancels mid-recording → audio and draft are discarded; no partial item is saved
- Edge: app is backgrounded or interrupted by a call → recording stops gracefully and visible partial text is preserved
- Edge: very long speech → full transcript is preserved; triage uses the existing bounded prompt

## 12. Voice Capture — Malayalam

*As a user, I want to speak in Malayalam and have it captured accurately.*

- Edge: Pi/Tailscale bridge unreachable → clear "voice bridge offline" message, falls back to English dictation or text
- Edge: code-switched speech (Malayalam + English mixed) → bridge receives the full utterance, user reviews/edits before save
- Edge: Pi is asleep/powered off → same offline fallback as above, no silent failure

## 13. CloudKit Sync

*As a user, I want my data synced across iPhone/iPad/Mac automatically.*

- Edge: sync conflict (edited same item on two devices offline) → CloudKit's last-write-wins applies, no manual merge UI initially
- Edge: iCloud account not signed in → app functions fully local-only, sync disabled with a visible banner
- Edge: CloudKit quota/error → app continues working locally, retries sync silently in background

## 14. Gmail Integration

*As a user, I want actionable emails pulled into Inbox.*

- Edge: OAuth token expires → integration pauses, user notified to re-auth, existing items remain available, and sync resumes from the last successful checkpoint after re-authentication
- Edge: user cancels OAuth consent → no partial connection is created and existing Gmail connections remain unchanged
- Edge: required OAuth scopes are missing → integration remains inactive and explains which permission is required
- Edge: user revokes Gmail access externally → app detects the authorization failure on the next sync attempt, marks the integration disconnected, and preserves previously imported items
- Edge: Gmail account is disconnected in Wool → no future imports occur; existing items are retained unless the user explicitly chooses to delete them
- Edge: multiple Gmail accounts are connected → each item records its source account and disconnecting one account does not affect the others
- Edge: email has no clear action → still imported to Inbox as a raw item, without inventing an action, and user triages manually
- Edge: email is informational, promotional, a newsletter, spam, or in Trash → import behavior follows explicit user rules; excluded messages are not silently treated as actionable
- Edge: email is in a thread, reply, or forwarded chain → deduplicate using stable Gmail message/thread identifiers and avoid importing quoted content as a new action
- Edge: email changes after import → update source metadata or content where appropriate without overwriting the user's local triage decisions
- Edge: email is deleted or archived in Gmail → do not silently delete the local Inbox item; preserve its local state and indicate when the source is no longer available
- Edge: email contains attachments, images only, malformed content, or unsupported formatting → import available metadata and do not allow one malformed message to fail the whole sync
- Edge: email is written in an unsupported language or classification is uncertain → import as a raw item rather than guessing
- Edge: network is unavailable or Gmail API returns a temporary error → retain existing data, mark sync as deferred, retry with bounded backoff, and avoid noisy repeated notifications
- Edge: Gmail rate-limits the app → honor retry guidance, resume safely, and avoid duplicate imports
- Edge: sync is interrupted during pagination → persist a checkpoint and continue from it on the next attempt
- Edge: Gmail incremental history is unavailable or expired → fall back to a safe re-scan and deduplicate by stable message ID
- Edge: the same email appears in overlapping sync windows → idempotently ignore duplicates
- Edge: local storage is full → pause sync safely, preserve the remote checkpoint, and explain how the user can recover
- Edge: imported content contains sensitive data → request minimum scopes, secure tokens, redact content from logs and notifications, and avoid sensitive lock-screen previews by default
- Edge: sync repeatedly fails → show connection state, last successful sync time, error category, and a manual retry action

### Gmail acceptance tests

- Unit/service: verify OAuth error mapping, token refresh, retryable failures,
  pagination, checkpoint advancement, message normalization, empty/malformed
  content, and stable deduplication.
- SwiftData/integration: verify imported tasks remain in Inbox, source records
  and tasks persist together, repeated syncs are idempotent, checkpoints resume
  safely, disconnect preserves local items, and unique UUID fixtures isolate
  test data.
- Simulator UI: on an iOS Simulator, verify the feature-flagged
  Gmail settings section, connected/paused/disconnected states, manual sync,
  imported raw Inbox content, and disconnect confirmation using deterministic
  fixtures. Live OAuth, token expiry, and external revocation remain manual
  verification scenarios.

## 15. GitHub Projects Integration

*As a user, I want GitHub issues to appear as Next Actions or Waiting For.*

- Edge: issue closed on GitHub while open in Wool → next sync marks it complete
- Edge: same issue linked in multiple Wool items (edge case from re-import) → dedup by GitHub issue ID

## 16. EventKit / Calendar

*As a user, I want calendar events to inform today's briefing.*

- Edge: calendar permission is not yet determined → request access at the appropriate point, explain the value clearly, and never block or repeatedly interrupt the briefing
- Edge: calendar permission denied or restricted by Screen Time/MDM → briefing runs without a calendar section and offers a settings path where iOS allows recovery
- Edge: user grants access after a denied request → the next briefing reflects the new permission without requiring a reinstall or stale app restart
- Edge: calendar access is revoked while the briefing is open → preserve the task sections, remove calendar data safely, and avoid displaying stale events as current
- Edge: no calendars are available or all calendars are hidden → omit the calendar section and keep the briefing useful
- Edge: user has multiple calendars, including subscribed, shared, birthday, holiday, or read-only calendars → include only events returned by the selected access policy and identify the source when needed to disambiguate them
- Edge: an event is all-day → show it in a separate All-day section, never in timed events and never as a "due today" task
- Edge: an all-day event spans multiple days → show it on each covered briefing day, with a clear multi-day indicator, without fabricating a timed start
- Edge: a timed event starts before today and ends today, or starts today and ends after midnight → include it as an active/spanning event with its actual time context, not as a newly starting event
- Edge: an event starts exactly at today's boundary or ends exactly at tomorrow's boundary → apply a consistent half-open day interval so it appears on the correct day once
- Edge: event crosses a daylight-saving transition, timezone change, or locale/calendar boundary → classify it using the user's current calendar and timezone without shifting it to the wrong day
- Edge: recurring event has an occurrence today → show the occurrence for today, not the series as an unbounded duplicate; canceled or excluded occurrences are omitted
- Edge: duplicate-looking events exist across calendars or are returned more than once by EventKit → retain distinct events only when their stable identifiers differ, and deduplicate repeated identifiers
- Edge: event has no title, only whitespace, invalid dates, an end before its start, or an unsupported payload → omit that event and continue rendering the remaining briefing
- Edge: event has a long title, notes, URL, location, emoji, or sensitive attendee information → truncate or sanitize display text, show useful location only when available, and never expose private notes or attendees unnecessarily
- Edge: event is marked canceled, declined, or tentative → apply the defined visibility policy consistently and communicate status when it remains visible; never present a declined event as a commitment without context
- Edge: event is busy/free or the user has overlapping events → preserve chronological ordering, show overlaps without double-counting time, and avoid implying that one event is a task
- Edge: there are many events in a day → cap the initial list with an explicit way to reveal more, keep the briefing responsive, and do not silently discard events without indicating that more exist
- Edge: more than 10 timed events are returned → show the first 10 initially with a Show all/Show less control; all-day events remain visible separately
- Edge: calendar data changes while the briefing is being generated → use one coherent snapshot for the current result; a later refresh may update it without mixing old and new rows
- Edge: EventKit returns an error, times out, or the device is offline → omit only the calendar section, keep locally stored task data and the rest of the briefing available, and avoid repeated error alerts
- Edge: the briefing is generated repeatedly or the app is offline → fetch calendar data live for the current briefing only; do not persist calendar event snapshots in SwiftData
- Edge: calendar data is unavailable to the AI narrative → the deterministic calendar section still renders, and the narrative must not invent event titles, times, or commitments
- Edge: the briefing is invoked by Siri/App Intents or while the device is locked → respect calendar authorization and privacy rules; do not read private event details aloud or expose them in notifications unless explicitly allowed
- Edge: user taps a calendar event → v1 remains read-only; it does not modify EventKit, create a Wool task, or silently link existing tasks
- Edge: the user has no tasks but has calendar events → show the calendar context without implying that events are Wool tasks; a positive empty-task state remains visible
- Edge: calendar events and Wool tasks have similar titles or times → keep their identities and actions distinct; never auto-link, complete, or create a task from an event without an explicit user action

### EventKit acceptance tests

- Unit/service: verify permission/error fallbacks, all-day versus timed sections, multi-day and recurring occurrences, exact day-boundary inclusion, timezone/DST behavior, stable-ID deduplication, malformed-event filtering, ordering, event caps, and separation from task due dates.
- SwiftData/integration: verify the briefing remains usable offline, calendar failures do not affect local task persistence, repeated briefing generation is idempotent, and one coherent event snapshot is used per result.
- Simulator UI: on an iOS Simulator, verify the permitted flow with timed, all-day, multi-day, overlapping, and empty-task fixtures; verify denied/revoked access omits the section and that the briefing remains navigable.

## 17. Apple Reminders Import

*As a user, I want to migrate my existing Reminders into Wool once.*

- Edge: import run twice → duplicate detection by title+date, second run skips existing matches
- Edge: Reminders list has 1000+ items (matches your actual Database list) → import runs in background, progress indicator, doesn't block UI

## 18. Focus/Pomodoro Timer

*As a user, I want to start a focus session tied to a specific task.*

- Edge: session interrupted (app backgrounded/call) → timer continues via background task/notification, resumes state on return
- Edge: user starts session with no task selected → allowed, generic "Focus Session" logged, not blocked

## 19. Subscription (Pro)

*As a user, I want to upgrade for AI-assisted review, unlimited integrations, Malayalam voice.*

- Edge: subscription lapses → Pro features lock gracefully, data not deleted, free tier limits apply
- Edge: restore purchase on new device → StoreKit restore flow, no re-purchase required
- Edge: trial period ends mid-Weekly-Review → current session allowed to finish, next session locked if not converted
