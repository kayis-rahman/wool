# Wool Release Process

## Versioning policy

Wool application versions use Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

- **MAJOR** — incompatible user-facing, data, API, or synchronization changes.
- **MINOR** — backward-compatible features and optional capabilities.
- **PATCH** — backward-compatible fixes, performance improvements, and small
  reliability or UI changes.

The marketing version is the user-visible App Store/TestFlight version. The
build number increments for every uploaded build and may change without a
marketing-version change.

SwiftData schema versions are tracked independently and recorded in
`CHANGELOG.md`. A schema version changes only when the persisted model changes.

## Release checklist

### Prepare

- [ ] Confirm MAJOR, MINOR, or PATCH release type.
- [ ] Update iOS, macOS, and watchOS marketing versions as applicable.
- [ ] Increment the build number.
- [ ] Update `CHANGELOG.md` with app version, build, schema version, and notes.
- [ ] Confirm feature-flag defaults and rollback behavior.

### SwiftData schema and migrations

When the persisted model changes:

- [ ] Add a new `VersionedSchema`.
- [ ] Update `SchemaMigrationPlan`.
- [ ] Classify the migration as lightweight or custom.
- [ ] Add deterministic migration tests using a previous-version store.
- [ ] Verify offline launch, local persistence, and CloudKit synchronization.
- [ ] Document the minimum app version compatible with the new schema.

When the model does not change:

- [ ] Confirm the existing schema version remains in use.
- [ ] Record that schema version in `CHANGELOG.md`.

### CloudKit Development → Production

- [ ] Confirm container `iCloud.com.sparkage.wool`.
- [ ] Verify record types, fields, indexes, relationships, and permissions in
  Development.
- [ ] Test new installs, existing stores, offline writes, reconnect sync, and
  cross-device behavior.
- [ ] Test the previous app version against the candidate schema.
- [ ] Review and remove development-only data or fields.
- [ ] Deploy the Development schema to Production in CloudKit Dashboard.
- [ ] Confirm the Production schema and feature-flag configuration record.
- [ ] Record promotion date, schema version, and operator.
- [ ] Never make destructive Production schema changes without a migration and
  rollback plan.

### Backward compatibility

- [ ] Install the previous App Store version.
- [ ] Create representative local and CloudKit-backed data.
- [ ] Upgrade to the candidate build.
- [ ] Verify old data remains readable and editable.
- [ ] Verify the previous app can launch against the promoted schema.
- [ ] Verify offline operation before and after upgrade.
- [ ] Verify sync across old and new app versions.
- [ ] Test interrupted migration and relaunch recovery.

### TestFlight and App Store rollout

#### Internal

- [ ] Upload the candidate build.
- [ ] Test core workflows, sync, integrations, migrations, and flag states.
- [ ] Monitor crashes, sync errors, and migration failures.

#### External

- [ ] Submit for Beta App Review when required.
- [ ] Start with a limited external tester group.
- [ ] Expand gradually while monitoring crashes, sync, onboarding, and feature
  adoption.
- [ ] Keep high-risk features disabled unless explicitly approved.

#### App Store

- [ ] Confirm final version/build, notes, and Production schema promotion.
- [ ] Submit the App Store build.
- [ ] Use phased release when appropriate.
- [ ] Monitor production health and record the rollout outcome.

## Feature flags

New features should ship disabled when practical. Flags use namespaced keys,
safe defaults, central evaluation, local caching, and a documented owner and
removal date. The active snapshot is stable for the current session; remote
changes take effect on the next launch.

CloudKit feature-flag setup is documented in
[`feature-flags-cloudkit.md`](feature-flags-cloudkit.md).

## Rollback

- [ ] Disable affected features remotely where possible.
- [ ] Pause staged distribution.
- [ ] Record affected app and schema versions.
- [ ] Preserve diagnostic logs and representative data.
- [ ] Decide whether to ship a patch or use a server-side mitigation.
- [ ] Never destructively roll back a CloudKit Production schema.
