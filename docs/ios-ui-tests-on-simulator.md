# Run Wool UI Tests on an iOS Simulator

Use the simulator runner for standard Wool UI-test runs. It boots the
configured iPhone 18 Pro simulator, builds the UI-test bundle once, and then
reuses that build for each requested test identifier.

From the repository root:

```sh
./scripts/run-on-simulator.sh
```

Run selected tests without rebuilding between them:

```sh
./scripts/run-on-simulator.sh \
  WoolUITests/iOSSettingsUITests/testNotificationsSettingsShowsMasterAndWeeklyReviewToggles \
  WoolUITests/iOSSettingsUITests/testDisablingNotificationsDisablesWeeklyReviewToggle
```

The physical-device workflow remains available as an optional extra for
signing, CloudKit, Siri/Shortcuts, notification delivery, and final release
confidence; see `docs/ios-ui-tests-on-iphone-15-pro.md`.
