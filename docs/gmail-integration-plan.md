# Gmail Integration Implementation Plan

## Current status

The iOS implementation baseline is in the repository, but the feature is not
yet production-ready or fully verified.

Implemented in code:

- Feature-flagged Gmail Settings UI.
- PKCE OAuth flow with configurable client ID and redirect URI.
- Keychain access-token, refresh-token, expiry, and scope storage.
- Gmail REST profile and Inbox message retrieval.
- SwiftData account, imported-message, and checkpoint models.
- Local Inbox import with stable message-ID deduplication.
- Bounded body excerpts, sender/source metadata, attachment markers, and empty
  subject fallbacks.
- Retry/backoff for selected temporary API failures.
- Deterministic Gmail fixtures.
- Unit, SwiftData integration, and UI test code.

Not yet verified or complete:

- CoreDevice reports the configured iPhone as `connected`, not
  `available (paired)`, so the optional physical-device workflow is blocked.
- Automated tests have not been run for this implementation slice.
- The Gmail OAuth client ID is still empty in `Info.plist`.
- Incremental Gmail History API sync is not implemented; subsequent syncs
  currently re-read the configured Inbox window.
- Background lifecycle sync and notifications are not wired.
- Multi-account OAuth credential isolation is not implemented.

## Purpose

Implement Gmail as an opt-in, local-first integration that imports email into
Wool's Inbox without silently losing data or moving items out of Inbox
without user confirmation.

The implementation must support the edge cases documented in
[`USER-STORIES-EDGE-CASES.md`](USER-STORIES-EDGE-CASES.md#14-gmail-integration),
including token expiry, external access revocation, uncertain classification,
duplicate messages, interrupted sync, and temporary Gmail/API failures.

## Scope

### Implemented MVP baseline

- Connect one Gmail account through OAuth.
- Request the minimum read-only Gmail permissions required for import.
- Import eligible messages into Inbox.
- Preserve messages with uncertain or absent actions as raw Inbox items.
- Deduplicate imported messages using stable Gmail identifiers.
- Support paged initial sync and resumable page checkpoints.
- Refresh expired access tokens when a refresh token and OAuth configuration are
  available.
- Mark authorization failures as reauthentication or disconnected states.
- Provide manual sync, reconnect, and disconnect actions.
- Preserve existing local Inbox items when Gmail is disconnected.
- Keep capture, triage, and Inbox usable offline.
- Keep the feature behind `features.gmailIntegration`.

### Remaining MVP work

- Implement Gmail History API incremental sync using the stored `historyID`.
- Reconcile changed, deleted, archived, or inaccessible source messages without
  deleting local Inbox items.
- Wire foreground lifecycle sync and coalesced per-account sync execution.
- Add live OAuth configuration and manually verify the complete flow.
- Execute all three test layers on an iOS Simulator.

### Deferred

- Sending, replying to, archiving, deleting, or marking Gmail messages read.
- Editing Gmail labels from Wool.
- Downloading or previewing attachments.
- Gmail push notifications.
- Automatic project or Area assignment.
- Automatic movement from Inbox to another task organization bucket without confirmation.
- Multiple connected Gmail accounts and account-scoped Keychain namespaces.
- Background refresh scheduling.
- Deleting imported tasks as part of disconnect, beyond retaining them safely.
- Production notification policy and operational dashboards.

## Existing architecture to extend

The current app uses SwiftData as its local source of truth, CloudKit private
database sync when enabled, and a shared capture pipeline:

- `CaptureService` classifies captures.
- `CapturePersistenceService` inserts and saves `TaskItem` records.
- `InboxTriageService` processes existing Inbox items.
- `KeychainStore` stores local secrets.
- `FeatureFlags` already exposes `gmailIntegrationEnabled`.
- `SettingsView` is the existing integration/settings entry point.
- UI tests use an isolated local SwiftData store.
- Physical-device testing is optional and targets the configured iPhone 15 Pro.

Gmail-specific networking and source metadata should remain separate from the
generic capture service. The Gmail flow should call the shared persistence
boundary after it has normalized a message into an Inbox item.

## Proposed components

### `GmailOAuthService`

Responsibilities:

- Start the provider authorization flow using PKCE.
- Receive the authorization callback.
- Exchange the authorization code for tokens.
- Refresh expired access tokens.
- Validate the authenticated Gmail account and granted scopes.
- Detect invalid, expired, or revoked credentials.
- Report cancellation and missing-permission errors distinctly.

The service should expose protocols for OAuth behavior so unit tests can use a
fake provider without opening a browser or requiring live credentials.

### `GmailAPIClient` — partially implemented

Responsibilities:

- Fetch authenticated account identity.
- List eligible messages.
- Fetch message metadata and supported body content.
- Fetch incremental history changes. **Deferred; current client lists the
  configured Inbox window on every sync.**
- Follow pagination tokens.
- Classify HTTP/API failures into retryable and permanent errors.
- Honor provider rate-limit and retry guidance.

The client should use `URLSession` behind an injectable transport boundary. It
must not write to SwiftData or Keychain directly.

### `GmailSyncService` — implemented baseline

Responsibilities:

- Coordinate account state, token acquisition, API calls, checkpoints, and
  persistence.
- Run paged Inbox syncs.
- Persist progress after bounded pages or batches.
- Resume after interruption.
- Fall back to a safe re-scan if incremental history is unavailable.
- Persist account status for the settings UI.

Per-account serialization, true incremental history processing, and
notifications remain deferred.

Manual sync and lifecycle-triggered sync should coalesce into one operation if
an account is already syncing.

### `GmailMessageMapper` — implemented inline baseline

Responsibilities:

- Convert provider responses into a normalized internal message.
- Extract sender, subject, received date, thread ID, message ID, body text, and
  Gmail URL.
- Decode Gmail URL-safe Base64 body data.
- Detect attachment presence.
- Handle empty subjects, empty bodies, image-only messages, malformed content,
  and unsupported formatting.
- Preserve attachment presence as metadata without downloading attachments in
  the MVP.

### `GmailImportService` — implemented inline in `GmailSyncService`

Responsibilities:

- Check whether an account/message pair has already been imported.
- Create a `TaskItem` in `.inbox` status.
- Store source metadata alongside the task.
- Persist the task and import record as one logical operation.
- Leave classification as editable triage information.

The invariant is: Gmail import persists to Inbox first. Classification must not
silently discard an email or move it out of Inbox without an explicit product
decision and user confirmation.

## Persistence design

Add Gmail metadata as separate SwiftData models rather than placing provider
fields directly on `TaskItem`. This keeps generic captures independent of Gmail
and allows the integration to be disconnected without destroying local tasks.

### `GmailAccount` — implemented as `GmailAccountRecord`

Suggested fields:

- `id: UUID`
- `accountIdentifier: String`
- `displayName: String?`
- `statusRawValue: String`
- `isEnabled: Bool`
- `connectedAt: Date`
- `lastSyncAttemptAt: Date?`
- `lastSuccessfulSyncAt: Date?`
- `lastErrorCode: String?`
- `lastErrorMessage: String?`

Suggested statuses:

- `connected`
- `syncing`
- `paused`
- `reauthorizationRequired`
- `temporarilyUnavailable`
- `disconnected`

### `GmailImportedMessage` — implemented as `GmailImportedMessageRecord`

Suggested fields:

- `id: UUID`
- `accountIdentifier: String`
- `gmailMessageID: String`
- `gmailThreadID: String?`
- `taskID: UUID`
- `sourceURL: String?`
- `receivedAt: Date?`
- `subject: String`
- `sender: String?`
- `sourceStateRawValue: String`
- `lastSyncedAt: Date`

The deduplication key is `(accountIdentifier, gmailMessageID)`. SwiftData
queries should verify this key before insertion; do not use title, sender, or
received date as identity.

### `GmailSyncCheckpoint` — implemented as `GmailSyncCheckpointRecord`

Suggested fields:

- `accountIdentifier: String`
- `historyID: String?`
- `pageToken: String?`
- `syncModeRawValue: String`
- `updatedAt: Date`

Checkpoint values must only advance after the corresponding page or batch has
been persisted successfully.

### Schema migration

- Gmail models are currently added to the existing `WoolSchemaV1` baseline.
- A separate migration stage has not yet been added.
- Existing-store migration and CloudKit compatibility remain pending validation.
- Ensure no OAuth token or refresh token is present in any SwiftData model.

## Secure credential handling

Extend `KeychainStore.Item` with Gmail credential entries for:

- Access token.
- Refresh token.
- Token expiration date.
- Granted scopes.

Credentials must not be stored in:

- SwiftData.
- UserDefaults.
- CloudKit.
- Logs or analytics.
- Notifications.
- UI-test fixtures.

Connection flow:

1. User taps **Connect Gmail**.
2. App starts the PKCE authorization flow.
3. User grants read-only access.
4. App exchanges the code for tokens.
5. App verifies account identity and scopes.
6. App writes credentials to Keychain.
7. App creates or activates `GmailAccount`.
8. App starts initial sync.

Failure rules:

- OAuth cancellation leaves the integration disconnected.
- Missing scopes prevent activation and explain the missing permission.
- A failed Keychain write prevents the account from being marked connected.
- A refresh failure caused by invalid authorization changes the account to
  `reauthorizationRequired`.
- Disconnect clears the current MVP Gmail credential entries.

The current MVP supports one Gmail account and uses shared Gmail Keychain slots.
Account-scoped key names are deferred until multi-account support is enabled.

## Sync behavior

### Initial sync — implemented baseline

1. Select the configured historical window and import query.
2. Request one bounded page of messages.
3. Fetch and normalize each message.
4. Skip messages already present in `GmailImportedMessage`.
5. Persist new Inbox tasks and import records.
6. Persist the next page token.
7. Repeat until complete or interrupted.
8. Store checkpoint metadata. The current REST implementation does not yet
   return or consume a real Gmail History cursor.
9. Mark the account connected and update `lastSuccessfulSyncAt`.

The current sync runs from a user-triggered Settings action. Background
execution and progress reporting beyond the status label remain deferred.

### Incremental sync — deferred

- Start from the stored history cursor. **Not yet implemented.**
- Fetch newly added or changed messages.
- Reconcile source metadata where appropriate.
- Preserve local triage decisions.
- Do not delete local Inbox items when Gmail messages are deleted or archived.
- Mark source metadata as unavailable when the original message can no longer
  be fetched.
- Advance the cursor only after all returned pages are safely persisted.

### Recovery and interruption — partially implemented

The service must tolerate app termination, device lock, network loss, expired
tokens, background execution ending, and pagination interruption.

If the incremental cursor is invalid or expired:

- Mark the sync as recovery mode.
- Perform a bounded re-scan.
- Deduplicate by account plus Gmail message ID.
- Replace the cursor only after recovery completes successfully. **The current
  implementation has checkpoint storage but not History API cursor recovery.**

If a sync is interrupted, restart from the last persisted page checkpoint. A
restarted sync must neither duplicate completed imports nor skip an uncommitted
page.

## Import and classification rules

For each eligible message:

1. Normalize the provider response.
2. Check the stable deduplication key.
3. Create a `TaskItem` with `.inbox` status.
4. Use the subject as the title, with a fallback for empty subjects.
5. Store sender, received date, source URL, and readable body content in notes
   or source metadata.
6. Persist the task and `GmailImportedMessage` together.
7. Make the item available to ordinary Inbox triage.

Classification behavior:

- Clear action: provide an editable recommendation.
- No clear action: preserve the email as a raw Inbox item.
- Informational or promotional: follow the configured import policy.
- Spam or Trash: exclude by default.
- Unsupported language: import as raw content rather than guessing.
- Uncertain classification: default to Inbox.
- Reply or forward: avoid treating quoted content as a new action.
- Thread: use stable message/thread identifiers to prevent confusing duplicates.
- Attachment present: indicate its presence without downloading it in MVP.

Reuse `CapturePersistenceService` for the final local write and keep
`InboxTriageService` responsible for later user-driven processing.

## Settings and status UI

Add a Gmail section to `SettingsView`, shown only when
`featureFlags.gmailIntegrationEnabled` is true.

Connected state:

- Connected Gmail address.
- Current status.
- Last successful sync.
- **Sync Now** action.
- **Reconnect** action where relevant.
- **Disconnect** action.

Reauthorization state:

- Clearly state that sync is paused.
- Explain that existing Inbox items are safe.
- Provide **Reconnect Gmail**.
- Show the last successful sync time.

Temporary failure state:

- Show a human-readable error category.
- Show the last successful sync time.
- Provide manual retry.
- Do not expose tokens, raw API responses, or email contents.

Disconnect flow:

1. Explain that future imports will stop.
2. Offer to retain existing imported items.
3. Make deletion of existing imported items a separate, explicit action.
4. Clear Keychain credentials.
5. Mark the account disconnected.
6. Cancel pending sync work.

The UI must support Dynamic Type, VoiceOver, reduced motion, and safe behavior
when the app is backgrounded during a sync.

## Lifecycle, retry, and notification behavior

Current implementation supports manual Settings sync and bounded retry/backoff
for selected network, temporary server, and rate-limit errors. Foreground
activation sync, background refresh, coalescing concurrent triggers, and Gmail
notifications are deferred.

Planned triggers:

- App becomes active.
- User opens Gmail settings.
- User taps **Sync Now**.
- OAuth reauthentication succeeds.

Only one sync should run per account. Concurrent triggers should coalesce.
**Not yet wired.**

Retry policy:

- Use bounded exponential backoff for network and temporary server errors.
- Respect provider retry guidance.
- Stop retrying automatically on permanent authorization errors.
- Avoid repeated notifications for the same failure.

Notify the user only for meaningful state changes:

- Reauthentication required.
- Gmail access revoked.
- Persistent sync failure requiring attention.
- Initial sync completed, if completion feedback is desired.

Notifications must not include subject lines, sender names, body text, tokens,
or other sensitive email content. Sensitive lock-screen previews should be
disabled by default.

## Testing plan

### Unit and service tests

Implemented test file: `GmailSyncServiceTests.swift`. These tests currently
cover Inbox persistence, empty-subject fallback, attachment markers, and
idempotent repeated syncs. The broader cases below remain planned.

Add deterministic tests for:

- OAuth success and cancellation.
- Missing scopes.
- Successful token refresh.
- Invalid or revoked authorization.
- API error classification.
- Rate-limit retry behavior.
- Pagination and checkpoint advancement.
- Interrupted sync.
- Expired incremental history recovery.
- Stable message deduplication.
- Multiple-account isolation.
- Empty subject or body.
- Plain-text and HTML extraction.
- Image-only and malformed content.
- Thread, reply, and forward handling.
- Unsupported language fallback.
- Informational email handling.
- Classification uncertainty.
- Guarantee that imported messages remain in Inbox.
- Idempotent repeated imports.

Use fake OAuth and Gmail API clients. No live Gmail credentials should be
required for unit tests.

### SwiftData and integration tests

Implemented test file: `GmailSyncPersistenceTests.swift`. These tests currently
cover paged persistence, checkpoint clearing, replay without duplicates, and
disconnect preservation. CloudKit execution remains pending.

Verify:

- Gmail account persistence.
- Tokens remain outside SwiftData.
- Atomic persistence of imported task and source record.
- Duplicate prevention.
- Checkpoint persistence after each bounded page.
- Resume after simulated interruption.
- Recovery from an expired history cursor.
- Local preservation after remote deletion or archiving.
- Account isolation.
- Disconnect preservation behavior.
- Reconnect without historical duplication.
- Offline operation.
- CloudKit schema compatibility where applicable.
- Deterministic fixtures with unique UUID markers.

### UI tests

Implemented test file: `GmailIntegrationUITests.swift`. It uses
`WOOL_GMAIL_UI_TESTING=1` to enable the feature and seed deterministic Gmail
data without live OAuth.

Automated iOS validation runs on an iOS Simulator
(`docs/ios-ui-tests-on-simulator.md`).

Use a deterministic UI-test mode that injects a fake Gmail account and messages
so the tests do not depend on browser OAuth or live mail.

Cover:

- Gmail section hidden when the feature flag is disabled.
- Connected state and account display.
- Initial sync status.
- Imported raw email visible in Inbox.
- Uncertain-action email remains manually triageable.
- Repeated sync does not create duplicates.
- Token-expired reauthentication state.
- Revoked-access disconnected state.
- Manual retry.
- Disconnect confirmation.
- Existing item remains after disconnect.
- Accessibility labels and Dynamic Type layout.
- Relaunch during sync preserves the expected state.

The UI test code has not yet executed because the configured iPhone is not
reported as `available (paired)`. Live OAuth, real token expiry, and external
revocation remain manual physical-device verification scenarios.

## Feature flag and rollout

Use the existing `FeatureFlag.gmailIntegration` and
`FeatureFlags.gmailIntegrationEnabled` values.

Rollout sequence:

1. Implement models and fake-client tests while the flag remains disabled.
2. Enable the feature only in local development.
3. Enable it for dedicated internal Gmail test accounts.
4. Validate OAuth, token expiry, revocation, and disconnect manually on a
   physical iPhone.
5. Enable for a small production cohort.
6. Monitor authorization failures, sync failures, duplicate rates, migration
   errors, and crashes.
7. Expand rollout after data integrity is confirmed.

When disabled, the feature must add no Gmail UI or sync work and must not alter
existing Inbox data.

## Documentation updates

Update the following documents as implementation progresses:

- `docs/USER-STORIES-EDGE-CASES.md` — acceptance behavior and edge cases.
- `docs/app-feature.md` — Gmail scope, privacy, local-first behavior, and
  limitations.
- `docs/feature-flags-cloudkit.md` — Gmail flag and rollout behavior.
- `docs/ios-ui-tests-on-iphone-15-pro.md` — physical-device Gmail test flow.
- Privacy documentation — OAuth scopes, token handling, content processing,
  retention, and disconnect behavior.
- Release checklist — OAuth, revocation, migration, offline, and data-integrity
  checks.

## Current completion checklist

Completed baseline:

- Gmail models, OAuth boundary, REST client, Inbox import, deduplication, and
  feature-flagged Settings UI are implemented.
- Deterministic unit, SwiftData integration, and UI test code exists.
- Credentials are kept out of SwiftData, CloudKit, logs, and notifications.
- The feature is disabled by default and harmless when its flag is disabled.

Remaining before production release:

- OAuth connection works on the physical iPhone with a real configured client
  ID.
- Expired tokens pause sync and request reauthentication.
- External revocation marks the account disconnected.
- Gmail History API incremental sync is implemented and verified.
- Changed, deleted, archived, and inaccessible source messages are reconciled
  without deleting local Inbox items.
- Initial sync is resumable and idempotent.
- Emails without clear actions remain raw Inbox items.
- Duplicate Gmail imports are prevented.
- Existing Inbox data survives disconnects and sync failures.
- Unit, SwiftData/integration, and UI tests pass on an iOS Simulator.
- Documentation and privacy behavior match the implementation.
