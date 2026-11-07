# Run Wool UI Tests on a Physical iPhone 15 Pro

This optional guide runs the Wool iOS UI tests on the connected iPhone 15 Pro
for device-specific validation. Standard iOS builds, unit tests, and UI tests
run on an iOS Simulator instead (`docs/ios-ui-tests-on-simulator.md`). The test
runner uses the device currently configured in
`scripts/run-on-iphone15pro.sh`.

The entire workflow can run from Terminal. Opening the Xcode app is not
required once signing is configured.

## Prerequisites

- macOS with Xcode installed.
- The iPhone connected by USB or available over the configured network link.
- The iPhone unlocked during build, installation, and test execution.
- Developer Mode enabled on the iPhone: **Settings → Privacy & Security →
  Developer Mode**.
- The iPhone trusted by this Mac.
- A valid Apple development team selected for the `Wool iOS` target.
- The iPhone’s iOS version supported by the installed Xcode version.

Check that Xcode can see the device:

```sh
xcrun devicectl list devices
```

If this command fails, stop here and use the **CoreDeviceService recovery**
procedure below. Running `xcodebuild test` while `devicectl` cannot enumerate
the phone will not repair the connection and can leave a misleading test
result.

Resolve the connected physical iPhone 15 Pro identifier at the start of each
test session. Do not copy or retain a stale UUID:

```sh
DEVICE_LIST_OUTPUT="$(xcrun devicectl list devices)" || exit 1
DEVICE_ID="$(print -r -- "$DEVICE_LIST_OUTPUT" \
  | grep -F 'available (paired)' \
  | grep -F 'iPhone 15 Pro' \
  | grep -Eo '([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})' \
  | head -n 1)"
test -n "$DEVICE_ID" || {
  echo "No available paired physical iPhone 15 Pro found; stopping."
  exit 1
}
echo "Using physical iPhone 15 Pro: $DEVICE_ID"
```

Confirm that `xcodebuild` sees the same identifier before starting a test:

```sh
xcodebuild \
  -project apple/Wool/Wool.xcodeproj \
  -scheme "Wool iOS" \
  -showdestinations
```

The output must contain an entry like this, using the identifier returned by
`devicectl`:

```text
{ platform:iOS, arch:arm64, id:<DEVICE_ID>, name:iPhone }
```

Seeing the phone in `devicectl` alone is not sufficient. `devicectl` and
`xcodebuild` maintain separate device-service state, so both checks are part of
the physical-device preflight.

## Build, install, and launch the app

From the repository root:

```sh
./scripts/run-on-iphone15pro.sh
```

The script checks the iPhone lock state before building. If it reports that
the device is locked or CoreDevice cannot be reached, fix that connection first
and rerun the script.

The script builds the `Wool iOS` scheme, installs the resulting app, and
launches bundle identifier `com.sparkage.wool.ios` on the iPhone.

The build output is placed in:

```text
/private/tmp/wool-iphone15pro-derived/Build/Products/Debug-iphoneos/Wool iOS.app
```

If signing or provisioning is requested, accept the Xcode prompts and rerun
the script with the phone unlocked.

## Run all UI tests on the iPhone

The preferred command uses the repository script, which repeats both device
preflight checks:

```sh
./scripts/run-on-iphone15pro.sh --test
```

The equivalent direct command is:

```sh
xcodebuild test \
  -project apple/Wool/Wool.xcodeproj \
  -scheme "Wool iOS" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /private/tmp/wool-iphone15pro-ui-tests \
  -only-testing:WoolUITests/WorkspaceUITests \
  -enableCodeCoverage NO \
  -allowProvisioningUpdates
```

The UI test launch configuration adds `-ui-testing`. This bypasses normal
auth startup and uses a local SwiftData test store with CloudKit
disabled. Each `XCTestCase` generates its own store id and passes it via
`WOOL_UI_TEST_STORE_ID` on every launch it performs, so the store is
isolated between test methods but stable across a mid-test relaunch (needed by
tests that verify persistence survives `app.terminate()`/`app.launch()`); a
process launched without that env var (e.g. manually) falls back to a fresh
store id cached for that process's lifetime.

### Running several tests without rebuilding between them

Each `xcodebuild test` invocation re-checks the build graph even when nothing
changed, which adds up when iterating one test at a time. `--test-each` builds
once with `build-for-testing`, then runs each given identifier with
`test-without-building`, printing a PASS/FAIL line per test:

```sh
./scripts/run-on-iphone15pro.sh --test-each \
  WoolUITests/WorkspaceUITests/testHomeTaskOpensDetailsAndSaves \
  WoolUITests/WorkspaceUITests/testDeletingAreaMovesItsTaskToUncategorized
```

`--test` itself also accepts multiple identifiers to run together in one
`xcodebuild test` invocation (faster than `--test-each` when you don't need
per-test isolation from a build-graph check, e.g. confirming a batch of fixes
at once):

```sh
./scripts/run-on-iphone15pro.sh --test \
  WoolUITests/WorkspaceUITests/testHomeTaskOpensDetailsAndSaves \
  WoolUITests/WorkspaceUITests/testDeletingAreaMovesItsTaskToUncategorized
```

The iOS app scheme contains UI tests only. Run Weekly Review service and
SwiftData integration tests with the separate unit-test scheme:

```sh
xcodebuild test \
  -project apple/Wool/Wool.xcodeproj \
  -scheme "Wool iOS Unit Tests" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /private/tmp/wool-weekly-review-tests \
  -only-testing:WoolTests/WeeklyReviewAcceptanceTests \
  -only-testing:WoolTests/WeeklyReviewPersistenceTests \
  -enableCodeCoverage NO \
  -allowProvisioningUpdates
```

## Run one focused UI test

For example, to verify capture → Home → task details → save:

```sh
./scripts/run-on-iphone15pro.sh --test \
  WoolUITests/WorkspaceUITests/testHomeTaskOpensDetailsAndSaves
```

Or invoke `xcodebuild` directly:

```sh
xcodebuild test \
  -project apple/Wool/Wool.xcodeproj \
  -scheme "Wool iOS" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath /private/tmp/wool-iphone15pro-ui-tests-focused \
  -only-testing:WoolUITests/WorkspaceUITests/testHomeTaskOpensDetailsAndSaves \
  -enableCodeCoverage NO \
  -allowProvisioningUpdates
```

To run the Daily Briefing physical UI test:

```sh
./scripts/run-on-iphone15pro.sh --test \
  WoolUITests/WorkspaceUITests/testDailyBriefingShowsPositiveEmptyStateOnDevice
```

The physical test validates capture → Home → task details → save. Swift-level
behavior tests cover editing the title and preserving the task identity.

Other useful test names are visible in:

```text
apple/Wool/WoolUITests/iOS/WorkspaceUITests.swift
```

Use the same command and replace the value passed to `-only-testing` with the
test method you want to run.

### Physical-device text-entry note

The connected phone reports iOS 27 build `24A5418b`, and the CLI is configured
for Xcode 27 Beta 6 (`27A5252f`). The capture navigation/detail tests still use
the explicit
`WOOL_UI_TEST_CAPTURE_TITLE` fixture set by the test itself. This keeps the
physical UI test deterministic; capture classification, persistence, and
editor mutation are verified independently by `CaptureServiceTests` and
`CaptureIntentBehaviorTests`.

For the live Siri/Shortcuts and two-device CloudKit checks, follow
[Siri and CloudKit verification](siri-cloudkit-verification.md).

## Inspect failures

Test results are stored below the derived-data directory, for example:

```text
/private/tmp/wool-iphone15pro-ui-tests/Logs/Test/*.xcresult
```

Print a concise summary:

```sh
xcrun xcresulttool get test-results summary \
  --path /private/tmp/wool-iphone15pro-ui-tests/Logs/Test/<result>.xcresult \
  --compact
```

Print test-level failures:

```sh
xcrun xcresulttool get test-results tests \
  --path /private/tmp/wool-iphone15pro-ui-tests/Logs/Test/<result>.xcresult \
  --compact
```

Export screenshots, UI hierarchies, recordings, and action attachments without
opening Xcode:

```sh
xcrun xcresulttool export attachments \
  --path /private/tmp/wool-iphone15pro-ui-tests/Logs/Test/<result>.xcresult \
  --output-path /private/tmp/wool-iphone15pro-attachments
```

The test report records the destination. Verify that its device has
`modelName: iPhone 15 Pro`, `platform: iOS`, and the expected physical UDID
before reporting the run as physical-device validation.

## Common issues

### Automation or agent reports `Operation not permitted`

A physical-device run still initializes Xcode platform services and reads from
the current user’s `~/Library/Developer` and `~/Library/Logs` directories. A
sandboxed automation process may therefore print messages such as:

```text
Error opening log file ... Operation not permitted
CoreSimulatorService connection became invalid
Unable to find a device matching the provided destination specifier
```

The `CoreSimulatorService` text does not prove that a simulator destination was
used. Check the original `-destination` argument and the `.xcresult` device
metadata. In this failure mode, rerun the same command with permission to access
Xcode/CoreDevice services outside the workspace sandbox, or run the repository
script from an unrestricted Terminal session.

### `devicectl` sees the phone but `xcodebuild` does not

First compare both live views:

```sh
xcrun devicectl list devices

xcodebuild \
  -project apple/Wool/Wool.xcodeproj \
  -scheme "Wool iOS" \
  -showdestinations
```

If the phone is `available (paired)` in the first command but its identifier is
absent from the second, the test has not started. Recover in this order:

1. Confirm the selected CLI toolchain:

   ```sh
   xcode-select -p
   xcodebuild -version
   ```

2. Select and initialize the matching Xcode installation:

   ```sh
   sudo xcode-select --switch \
     /Applications/Xcode-27.0.0-Beta.6.app/Contents/Developer
   xcodebuild -runFirstLaunch
   ```

3. Disconnect and reconnect the phone, unlock it, keep it awake, and rerun both
   enumeration commands.
4. If the mismatch persists, restart the iPhone. Restart the Mac only if the
   device-service mismatch remains after the phone restart.

Once both commands show the same identifier, use the explicit physical
destination form:

```text
platform=iOS,id=<DEVICE_ID>
```

### Build failure before XCTest starts

Compiler and signing failures occur before the UI test can launch and are not
physical-device test failures. Typical output ends with `Testing cancelled
because the build failed`. Fix the first compiler error, rerun the same physical
command, and only report a test result after XCTest prints `Testing started`.

For Xcode 27’s CloudKit SDK, account status is named `CKAccountStatus`; using
`CKContainer.AccountStatus` fails compilation because it is not a nested type.

### XCTest starts but a UI assertion fails

This is a real physical-device test result. Use `xcresulttool` to locate the
source line and export attachments. For example, a failure in
`WorkspaceUITests.setUpWithError()` while waiting for
`home-capture-ui-testing` means the app launched but did not expose the expected
test UI. Inspect the exported UI hierarchy and screen recording before changing
the feature assertion. If the hierarchy contains a presented sheet container
but no title or content, check for presentation driven by separate Boolean and
optional-result state. Use an item-backed sheet so the content and presentation
value change atomically instead of briefly presenting an empty sheet.

### Device is locked

Unlock the iPhone and rerun the command. Keep it unlocked for the full test
run; long UI tests can fail if the device auto-locks. The corresponding
`devicectl` error is:

```text
Unable to launch com.sparkage.wool.ios because the device was not, or could not, be unlocked.
```

Installation may succeed while launch and XCTest execution are still denied;
unlocking the phone is required for both steps.

### Device is not available

Reconnect the phone, unlock it, and check:

```sh
xcrun devicectl list devices
```

If it appears as unavailable, restart the device connection and ensure
Developer Mode remains enabled.

### `CoreDeviceService` timed out or the connection was invalidated

If `xcrun devicectl list devices` reports an XPC connection error, a
`CoreDeviceService` timeout, or says that the provisioning parameter list could
not be loaded, XCTest has not started yet. Do not diagnose this as a Wool
test failure.

Recover in this order:

1. Stop any active Xcode test/build and close any open Simulator windows.
2. Disconnect and reconnect the iPhone directly to the Mac.
3. Unlock the iPhone, keep it awake, and accept **Trust This Computer** if it
   appears.
4. Confirm Developer Mode is still enabled.
5. Wait a few seconds, then retry:

   ```sh
   xcrun devicectl list devices
   ```

6. If the same timeout occurs, quit Xcode completely and retry the command
   from a fresh Terminal window. Xcode owns part of the device-services
   lifecycle, so closing its windows is not sufficient.
7. If the timeout still occurs, restart the iPhone, reconnect it after it has
   fully booted, unlock it, and repeat the check.
8. Once the phone is listed as `available (paired)`, rerun the build script and
   the UI-test command.

If CoreDevice still times out after the iPhone restart, restart the Mac and
reconnect the phone before trying again. Do not use the
`devicectl manage create` suggestion printed by this error: it creates a
device-management record and does not restore the unavailable CoreDevice
service. A successful `devicectl list devices` check is required before the
physical UI-test command can run.

For the exact error below, the short recovery sequence is therefore:

```text
Failed to load provisioning parameter list …
ERROR: Timed out waiting for CoreDeviceService to fully initialize
```

```sh
# Quit Xcode first, then reconnect and unlock the iPhone.
xcrun devicectl list devices

# Only after the iPhone appears as available (paired):
./scripts/run-on-iphone15pro.sh
```

### `DeviceSupport` or debugger-version warnings

These can occur when the iPhone is running a newer beta iOS build than the
installed Xcode supports. Update Xcode to the matching release/beta, then
rerun the test. A normal app build/install may still work while XCTest device
execution fails.

### Signing or provisioning errors

Open `apple/Wool/Wool.xcodeproj` in Xcode, select the `Wool iOS`
target, choose the correct **Team**, and confirm the bundle identifier is
registered. Then rerun:

```sh
./scripts/run-on-iphone15pro.sh
```
