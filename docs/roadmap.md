# Wool Roadmap

Product-level roadmap for Wool. Dates are intentionally not committed; phases are
ordered and gated by the signals listed below. Anything marked undecided is a
real open decision, not a disguised default.

## Vision reference

Wool's one-line promise, principles, non-goals, and the decision rule for
feature requests are owned by `docs/vision.md`. This roadmap assumes that
vision and does not widen it.

## Current baseline

- App version: 1.0.0, build 1.
- Privacy-first and local-first: SwiftData locally, CloudKit private database
  when signed in to iCloud, no custom backend for tasks.
- iOS is the complete task workspace today. macOS and watchOS targets exist
  for companion surfaces. The Apple Watch ships the Focus timer.
- Feature flags default to disabled: Gmail, GitHub Projects, Malayalam voice.

## v1.0 MVP: "Calm iPhone GTD"

Tier legend: MUST = ship in v1.0; SHOULD = ship in v1.0 if capacity, else
v1.1; CUT = not in v1.0.

### Product and workflow

| Tier | Capability |
| --- | --- |
| MUST | Core GTD lists: Inbox, Next Actions, Waiting For, Someday/Maybe, Projects, Areas |
| MUST | Quick Capture: typed plus English voice, plus Siri and Shortcuts capture |
| MUST | On-device triage: status, Area, due date; Foundation Models with heuristic fallback; manual override; no auto-modify |
| MUST | Today daily briefing: due and overdue, up to five up next, calendar context, AI framing with deterministic fallback |
| MUST | Weekly Review: persisted six-step flow, skip or complete per step, same-week reuse, resume, stale over 30 days, streak and history, weekly notification |
| MUST | Focus: Pomodoro 25/5/15, four-cycle, task link, pause/resume/reset, auto-next, notifications, sound, haptics, background reconciliation, Watch sync |
| MUST | Project and Area progress, archive, and restore |
| MUST | Task history |
| MUST | Settings: focus durations, sound and haptics, appearance, integrations, account and sync, support and about, data and privacy, optional Sign in with Apple, debug flags |
| SHOULD | Guided first capture and first Weekly Review walkthrough |
| SHOULD | App Store review prompts at good moments |
| SHOULD | Conflict-aware offline sync UI; never silently drop data |
| SHOULD | Watch complication reliability and widget tests |
| SHOULD | AI triage accuracy note |
| CUT | Full Mac task workspace |
| CUT | Full watchOS task organization beyond the timer |
| CUT | Public API |

### Platform, sync, and data

| Tier | Capability |
| --- | --- |
| MUST | Local SwiftData plus CloudKit private sync; offline capture; isolated local UI test store |
| MUST | iPhone-first wording; Mac and Watch described as companions |
| MUST | No custom backend; local mode by default |
| MUST | Privacy accuracy note: CloudKit keys, on-device triage, Advanced Data Protection caveat |
| SHOULD | Data export and backup with restore (strongly recommended before launch) |
| SHOULD | Recurring tasks without a paywall |
| MUST | Reliable notifications, end to end |
| MUST | Stable update discipline: TestFlight, changelogs, iOS compatibility |

### Integrations, voice, and AI

| Tier | Capability |
| --- | --- |
| MUST | EventKit read-only calendar context, capped |
| CUT | Gmail import |
| CUT | GitHub Projects |
| CUT | Apple Reminders import and migration in v1 (candidate for v1.1) |
| CUT | Malayalam voice |
| CUT | AI auto-scheduling or time-blocking |
| CUT | Team, collaboration, or sharing beyond iCloud private database |

### v1.0 exit criteria

- Physical-device UI tests green for Quick Capture and Weekly Review.
- No forced-continuity trials and no paywall in v1.0.
- Export may be deferred to v1.1 only with explicit approval; preferred
  pre-launch for trust.
- TestFlight beta completes before any launch announcement.

## v1.1 - "Trust and switching"

Expected after v1.0 launch; gated on TestFlight feedback requesting
portability and migration, or reliability gaps.

- Apple Reminders import.
- JSON and CSV export and restore (shipped in v1.0).
- Robust recurring tasks.
- Guided onboarding.
- Conflict-aware sync UI.
- Watch complication reliability.
- AI triage accuracy note.
- macOS companion minimum: Inbox capture plus Today read.

Signal to proceed: v1.0 retains users and feedback shows migration and
reliability needs outweigh new features.

## v1.2 - "Platform honesty upgrades"

- macOS full task workspace, or explicit permanent companion positioning.
- Watch capture complication.
- Widgets.
- Scholarship pricing if a paid model ships.

Signal to proceed: macOS upgrade requests exceed a clear share of feedback, or
a paid model is confirmed.

## v1.3 - "Pro boundaries"

Only after the pricing decision.

- Monetisation wiring for the chosen model (one-time purchase vs free core
  plus Pro).
- Gmail and GitHub imports.
- Malayalam and other non-English voice.
- Advanced review analytics.
- API and export for power users.

Rules: never gate recurring tasks or core calendar views; keep privacy-first
messaging consistent; keep non-core integrations as the natural paid
boundary.

## Pivots (each needs its trigger signal)

| Pivot | Trigger signal |
| --- | --- |
| Paid one-time Apple purchase | TestFlight willingness-to-pay data |
| Free core plus optional Pro subscription | Demand for Gmail, GitHub, and non-English voice; avoid paywalling basics |
| Android client | Validated waitlist or feature-request threshold; blockers are CloudKit sync and AI parity; heuristic triage only on Android at first |
| Privacy-first daily planner with auto-scheduling | Evidence users want auto-scheduling and calendaring; otherwise reject |
| API and public export | Power-user demand after core stability |

No pivot ships without its trigger evidence and an explicit decision.

## Android track

- Wool is Apple-only at the data layer today: SwiftData plus CloudKit. That is
  the Android blocker, not UI work.
- Do not expand platform promises in v1 marketing.
- Sequence if demand validates: export and backup first, then an
  encrypted-sync pilot, with sync provider and monetisation decided later.
- Implementation preference if pursued: native Kotlin and Compose, local
  database, heuristic triage labelled as where-supported.
- Heuristics-only triage on Android at first. Do not promise end-to-end
  encryption until client-side keys ship.
- Android is a pivot (above), not a v1.0 item.

## Launch plan

### Beta

- Closed TestFlight first, with physical iPhone 15 Pro end-to-end coverage of
  Quick Capture and Weekly Review.
- Invite 20 to 50 GTD and weekly-review practitioners from GTD, Things, and
  indie communities, plus ADHD creators and Watch users.
- Collect structured feedback on privacy copy accuracy, onboarding clarity,
  notification reliability, and platform scope honesty.
- Then public TestFlight, Product Hunt upcoming beta, and a Show HN privacy
  story.
- Pitch an Apple editorial feature with a one-pager focused on on-device AI,
  Watch sync, and Weekly Review.
- Prompt for App Store reviews after Weekly Review completion or task
  completion.

### Product identity and ASO

- Store title: "Wool - GTD Task Manager".
- The name Wool alone collides with games in search, so use the qualified
  title and long-tail queries such as "gtd todo app for iphone" and "weekly
  review template app".
- Subtitle and keyword field are undecided; see Undecided below.

### Pricing

- v1.0 ships free first. Pricing is decided after TestFlight.
- No payment or StoreKit code in v1.0.
- Run a willingness-to-pay survey during TestFlight across one-time purchase,
  annual, and free-core-plus-Pro options.
- If Wool becomes paid, prefer a universal Apple purchase and avoid charging
  per platform. Never gate recurring tasks or core calendar views.
- Keep any future monetisation behind feature flags so the chosen model can
  change later.

## What to measure

- Activation: time to first capture; percent completing a first Weekly Review
  within seven days.
- Retention: day 7 and day 30; weekly review completion; streak distribution.
- Engagement: focus sessions per week; triage override rate; captures per
  active user.
- Quality: crash-free sessions; notification delivery; sync conflicts; data-loss
  reports targeted at zero.
- Trust: export and restore success once shipped; support response time.
- Discovery: rank for "gtd todo app for iphone" and "weekly review template
  app"; conversion from search.
- Sentiment: App Store review themes for paywall, platform, sync, and bugs.
- Pivot signals: Android waitlist share, willingness-to-pay distribution,
  macOS request share.

## Undecided

- Pricing model and willingness-to-pay thresholds.
- Whether macOS becomes first-class later or remains a companion.
- Timing of export and backup before launch (recommended pre-launch).
- Level of Android commitment, sync provider, and Android monetisation if
  validated.
- Exact scope of macOS and Watch companion features.
- Exact boundary of any future paid tier.
- App Store subtitle and keyword field.
