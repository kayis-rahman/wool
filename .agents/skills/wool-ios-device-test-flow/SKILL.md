---
name: wool-ios-device-test-flow
description: >
  Load immediately before any iOS build, install, launch, simulator/device
  decision, or physical-device UI test run.
user-invocable: true
---

# wool-ios-device-test-flow

Trigger: load immediately before any iOS build, install, launch,
simulator/device decision, or physical-device UI test run.

In scope: device discovery, lock-state, destination checks, xcodebuild flags,
derived-data paths, `-focus-test-reset`, store env vars, and `--test-each`.

Out of scope: source changes, model/schema conventions, and deployment
decisions.

## Core rules

1. Use an iOS Simulator for Wool iOS app validation.
2. Verify `xcrun simctl list devices available` reports the configured
   simulator before a run.
3. Use `scripts/run-on-simulator.sh` for standard UI-test runs.
4. Keep physical-device UI test commands from
   `docs/ios-ui-tests-on-iphone-15-pro.md` for the optional device workflow.
