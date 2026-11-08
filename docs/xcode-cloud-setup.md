# Xcode Cloud Setup

Xcode Cloud workflows are configured in Xcode/App Store Connect, not as a
YAML file in the repo. This doc records the one-time setup and what's already
committed to support it.

## What's in the repo

`apple/Wool/ci_scripts/ci_post_clone.sh` — Xcode Cloud runs this after it
clones the repo and before the Xcode action. It runs SwiftLint with `--strict`
when SwiftLint is installed on the Xcode Cloud image and otherwise skips lint
with a message. Wool has no generated code, .NET toolchain, or Swift Package
dependencies that need bootstrap, so `ci_post_clone.sh` is the only hook the
project needs. Add `ci_pre_xcodebuild.sh` / `ci_post_xcodebuild.sh` in the same
directory only if a future step needs version stamping, signing/notarization, or
notifications.

## One-time setup (do this in Xcode / App Store Connect)

1. Open `apple/Wool/Wool.xcodeproj` in Xcode.
2. Product → Xcode Cloud → Create Workflow. Sign in with the Apple ID that
   has App Store Connect access, select team `425MSY8FLG`, and let Xcode create
   the Xcode Cloud App Store Connect API integration for `Wool - GTD`.
3. Create this workflow:

   **"Wool iOS archive (manual)"**
   - Scheme: `Wool iOS`
   - Start condition: manual start (or a tag matching `v*.*.*` once the captain
     authorizes tag-triggered builds)
   - Environment: latest release Xcode
   - Actions: Archive for iOS
   - Post-action: TestFlight internal testing only

   Do not add a broad `main` or PR trigger. Do not configure external TestFlight
   or App Store submission in this workflow.

   Optionally add a **"Wool iOS Unit Tests"** workflow (scheme
   `Wool iOS Unit Tests`, action Test on the iOS Simulator) and a
   **"Wool macOS"** workflow (scheme `Wool macOS`, action Archive) later; neither
   is required for the first TestFlight build. Unit tests may also be enabled as
   a required check via Xcode Cloud branch protection on `main` if the captain
   wants PR gating.

4. Confirm signing: Xcode Cloud manages certificates/profiles automatically
   once access is granted during workflow creation. The App Store Connect app
   record for `Wool - GTD` must already exist with bundle ID
   `com.sparkage.wool.ios`.

## iPhone-only first build

The first TestFlight build targets iPhone only. The `Wool iOS` scheme archives
the `Wool iOS` app target, whose bundle ID is `com.sparkage.wool.ios`; that
identifier already has iCloud, App Group, Push and Sign in with Apple configured
in the Apple developer portal. The Watch app target (`WoolWatchOs Watch App`) has
its own scheme and is not part of this archive. The `Wool Live Activity`
extension is embedded in the `Wool iOS` target, so its identifier
(`com.sparkage.wool.ios.liveactivity`) must also be provisioned before archiving;
until the captain completes that portal work it blocks the archive rather than
the Watch app.

## Why the physical-device workflow is NOT in Xcode Cloud

Per `CLAUDE.md`, iOS builds, unit tests, and UI tests run on an iOS Simulator,
so the CI picture is simple:

- Xcode Cloud can run `Wool iOS Unit Tests` (unit/service/SwiftData tests) on
  every push if that optional workflow is enabled.
- Run the `WoolUITests` suite locally on a simulator with
  `scripts/run-on-simulator.sh` before tagging a release.
- Xcode Cloud only provisions simulators/cloud Macs, it cannot attach to a
  specific paired physical device, so the optional device-specific workflow in
  `docs/ios-ui-tests-on-iphone-15-pro.md` would need a self-hosted Mac runner
  permanently tethered to that phone to be automated.

## Triggering a release

1. Run the UI test suite locally on an iOS Simulator, confirm green.
2. Bump the marketing version and build number, and update `CHANGELOG.md` per
   `docs/RELEASING.md`.
3. Confirm the unit test suite passes (locally and/or via the optional Xcode
   Cloud test workflow).
4. Start "Wool iOS archive (manual)" from Xcode or App Store Connect, or push a
   tag matching `v*.*.*` once tag-triggered builds are authorized.
5. Xcode Cloud archives, signs, and uploads to TestFlight internal testing.
   Check progress in the App Store Connect build list or the Xcode Cloud report
   tab in Xcode.
