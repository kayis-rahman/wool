# Wool

Wool is a privacy-first task and focus manager for iOS, macOS, and watchOS.
Everyday task data stays on the user's Apple devices and syncs through the
private CloudKit database when available.

## Release status

- App version: `1.0.0`
- Build: `1`
- CloudKit container: `iCloud.com.sparkage.wool`
- SwiftData schema: `1` (`WoolSchemaV1`)
- Feature flags default to disabled: Malayalam voice, Gmail integration, GitHub
  Projects integration

## Permanent identifiers

These identifiers are registered in the Apple Developer portal and cannot be
renamed once published; do not change them without a migration:

- iOS app bundle identifier: `com.sparkage.wool.ios`
- macOS/watchOS/live-activity bundle identifiers under `com.sparkage.wool...`
- Test bundle identifiers: `com.sparkage.woolTests`, `com.sparkage.woolUITests`,
  and the watch test bundles under `com.sparkage.wool.watchkitapp...`
- CloudKit container: `iCloud.com.sparkage.wool`
- App/keychain access group: `425MSY8FLG.com.sparkage.wool`
- Gmail OAuth callback scheme: `com.sparkage.wool.gmail`
- Local notification deep-link URL scheme: `wool`

The OS logger subsystem (`com.sparkage.wool`), the Keychain service name
(`com.wool.keychain`), and the local `wool.*` UserDefaults and `WOOL_*`
environment keys follow the same naming.

The source repository and issue tracker still live at
`github.com/kayis-rahman/wool`; the repository was renamed from
`synapse` to `wool`.

## Build and test

Open `apple/Wool/Wool.xcodeproj` in Xcode. The shared schemes are:

- `Wool iOS` - iOS app
- `Wool iOS Unit Tests` - unit/service/SwiftData tests
- `Wool macOS` - macOS app
- `WoolWatchOs Watch App` - watchOS app

Run iOS unit tests from the command line:

```sh
cd apple/Wool
xcodebuild -scheme "Wool iOS Unit Tests" \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro" test
```

## Continuous integration

GitHub Actions (`.github/workflows/ci.yml`) runs the `Wool iOS Unit Tests` suite
on every pull request and push to `develop` on a self-hosted macOS runner.
Xcode Cloud is configured manually and is not wired to automatic pushes or PRs;
see `docs/xcode-cloud-setup.md`. It archives `Wool iOS` for TestFlight internal
testing through the manual "Wool iOS archive (manual)" workflow (or a `v*.*.*`
tag once the captain authorizes tag-triggered builds). UI tests run on an iOS Simulator with
`scripts/run-on-simulator.sh`; the optional physical-device workflow stays
available for device-specific checks in
`docs/ios-ui-tests-on-iphone-15-pro.md`. See `docs/xcode-cloud-setup.md` for the
Xcode Cloud workflows.

## Documentation

- `docs/RELEASING.md` - versioning, schema, CloudKit, and rollout process
- `docs/pre-release-checklist.md` - pre-release gate checklist
- `docs/app-feature.md` - feature inventory
- `docs/data-export-restore.md` - exporting and restoring data
- `docs/feature-flags-cloudkit.md` - feature flag setup
- `docs/vision.md` - product vision and feature request decision rule
- `docs/roadmap.md` - phased roadmap, pivots, and launch plan
- `CHANGELOG.md` - release history and schema state

## Contributing

Follow `AGENTS.md` and the installed `write-swift` skill for Swift changes. Run
the iOS unit tests and keep changes inside the repository worktree.
