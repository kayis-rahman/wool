# Wool Vision

Wool is the calm, Apple-native GTD app that plans your week and ties it to a
Focus timer - on device, with no account, and your data in your iCloud.

Wool is the product formerly known as Synapse. This vision note exists to
triage feature requests: every proposal is tested against it before it is
accepted into a release.

## Who Wool is for

- GTD practitioners who want a guided Weekly Review rather than a reminder.
- iPhone-first users who want calm, reliable next actions and a Focus timer.
- Knowledge workers with ADHD who benefit from low-friction capture and
  explicit daily planning.
- Privacy-conscious users who do not want an account or a server holding
  their tasks.
- Apple Watch users who want a timer that stays in sync with what they are
  working on.

Wool is not for users who need team collaboration, web access, or a
cross-platform database today. Those needs are respected but are not part of
the v1 product.

## Principles

1. Privacy by default. Task data is local-first. No account is required to
   use Wool. Sync uses the private CloudKit database that belongs to the
   user's Apple account. Wool does not operate a custom backend for tasks and
   cannot read a user's private database. Integrations are opt-in and
   permission-gated.
2. Honest about CloudKit and Advanced Data Protection. CloudKit private data
   is protected by Apple's keys by default. End-to-end encryption applies only
   when a user enables Apple Advanced Data Protection. Wool never claims more
   protection than the platform provides.
3. Calm. Capture must take seconds, not decisions. AI suggests and never
   silently changes tasks. Triage falls back to local heuristics without
   blocking the user. The daily view stays readable and does not guilt.
4. No paywalling basics. If Wool ever has paid features, recurring tasks,
   core calendar views, capture, triage, and the weekly review stay free.
   Pricing stays clear, without forced-continuity trials or subscription
   traps that monetize trust.
5. Never silently drop data. Captures survive offline. Conflicts are shown,
   not swallowed. Updates do not regress stored data. Export and restore paths
   are first-class once they ship. A data-loss report is treated as a
   critical issue.
6. Ship the core first. The five-tab iPhone core and the Weekly Review are
   the product. Mac, web, Android, and deep integrations wait until the iPhone
   core retains users.

## Explicit non-goals for v1

- No full Mac task workspace. Mac starts as a companion surface.
- No full watchOS task organization. The Apple Watch ships the Focus timer.
- No Android client. Android remains a later pivot gated by demand.
- No team, sharing, or collaboration features.
- No AI auto-scheduling or time-blocking. Wool plans; it does not schedule
  for you.
- No third-party integrations in v1: Gmail, GitHub Projects, Apple Reminders
  import, and non-English voice capture are excluded.
- No advertising, tracking, or developer-operated analytics on the task path.
- No custom backend or account system.

Later phases and pivots are described in `docs/roadmap.md`.

## Decision rule for a feature request

A feature request fits Wool only if all of the following are true:

1. It strengthens capture, triage, daily planning, Focus, or Weekly Review on
   iPhone.
2. It works offline and without an account.
3. It does not require a custom backend or shared data.
4. It does not paywall a basic capability.
5. It never modifies user data without an explicit user action.
6. It does not delay or weaken privacy accuracy, reliability, or data safety
   work.

If every item is true, and the size is small enough to ship without
widening scope, accept it. If one item fails, defer it to a later phase or
reject it, and record the reason. When in doubt, prefer deletion and polish
over new surface area.
