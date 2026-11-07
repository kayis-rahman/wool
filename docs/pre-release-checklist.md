# Wool Pre-Release Checklist

Use this checklist before tagging a Wool `1.0.x` release. The full release
process lives in `docs/RELEASING.md`.

## Metadata

- [ ] Confirm MAJOR, MINOR, or PATCH release type.
- [ ] iOS, macOS, and watchOS marketing versions match the release version.
- [ ] Build number increments for the uploaded build.
- [ ] `CHANGELOG.md` includes version, build, CloudKit container, and schema.
- [ ] Feature-flag defaults and rollback behavior confirmed.

## Build and tests

- [ ] `Wool iOS Unit Tests` scheme builds successfully.
- [ ] iOS unit/service/SwiftData test suite is green.
- [ ] `ci_scripts/ci_post_clone.sh` passes in Xcode Cloud.
- [ ] UI test suite passes on an iOS Simulator.

## SwiftData and CloudKit

- [ ] Existing schema version remains in use when the model does not change.
- [ ] CloudKit container `iCloud.com.sparkage.wool` is verified.
- [ ] New installs and existing stores launch and persist offline.
- [ ] CloudKit sync is verified after reconnect and across devices.

## Rollout

- [ ] Release notes and `CHANGELOG.md` are updated.
- [ ] Internal TestFlight build is validated.
- [ ] App Store submission metadata is final.
- [ ] Tag `vX.Y.Z` is pushed only after all gates are green.
