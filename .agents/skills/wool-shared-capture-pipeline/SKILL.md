---
name: wool-shared-capture-pipeline
description: >
  Load before changes to Quick Capture, Inbox triage, capture intents, Siri
  capture, or persistence of captured data.
user-invocable: true
---

# wool-shared-capture-pipeline

Trigger: load before changes to Quick Capture, Inbox triage, capture intents,
Siri capture, or persistence of captured data.

In scope: `CaptureService`, `CapturePersistenceService`, `InboxTriageService`,
`WoolAppIntents`, shared tests, and three-layer test coverage.

Out of scope: unrelated task service/backend APIs, view styling, and deployment.

## Core rules

1. Keep one shared capture pipeline for app UI and App Intents.
2. Keep classification, triage mutation, and final persistence as separate
   services.
3. Keep ingestion fast by allowing raw Inbox preservation; classify through
   triage later.
4. Add or update unit/service, SwiftData/integration, and simulator UI tests
   together.
5. Use unique UUID markers in persisted test data.
