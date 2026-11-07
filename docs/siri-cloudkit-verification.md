# Verify Siri/Shortcuts and CloudKit Capture Sync

Use a normal Wool build for this check. Do not launch with `-ui-testing`:
that mode intentionally uses a unique local SwiftData SQLite store with
CloudKit disabled and cannot verify sync.

## Automated two-device CloudKit integration test

The repository includes an opt-in physical-device test that runs the real
`AddCaptureIntent` on a writer device and waits for the exact SwiftData item on
a reader device. It is disabled in ordinary test runs and requires both devices
to be signed in to the **same dedicated test Apple Account**. Do not run it
against a personal private CloudKit database.

With both devices unlocked and connected, run from the repository root:

```sh
./scripts/run-cloudkit-capture-integration.sh <writer-udid> <reader-udid>
```

The script creates a unique UUID-marked capture, uses deterministic heuristic
classification so its expected fields are stable, waits up to two minutes for
CloudKit delivery, and deletes the marker after the reader verifies it. It
requires an explicit `DEDICATED_TEST_APPLE_ACCOUNT` confirmation internally;
that gate prevents accidental inclusion in normal unit or UI test commands.

## Prerequisites

- Wool is installed with `./scripts/run-on-iphone15pro.sh`.
- The iPhone is signed in to the Apple Account that will own the private
  CloudKit database.
- The app has been given a few moments to initialize after first launch.
- For the cross-device check, a second device is signed in to the same Apple
  Account and runs a normal Wool build with the same CloudKit container.

## Verify the App Shortcuts registration

1. Open **Shortcuts** on the iPhone and create a shortcut.
2. Tap **Add Action**, search for **Wool**, and confirm these actions are
   available:

   - **Capture item** (the underlying App Intent is named **Capture an item**)
   - **Add next action**
   - **Start review**

3. Add **Capture item**, set its Capture value to:

   ```text
   Email the client tomorrow about the work plan
   ```

4. Run the shortcut, then open Wool. The new item should have this
   structure (UUID and timestamps will naturally differ from an in-app item):

   | Field | Expected value |
   | --- | --- |
   | Title | Email the client tomorrow about the work plan |
   | Status | Next Action |
   | Area tag | `area:Work` |
   | Due date | Tomorrow |
   | Project | None |

5. Create the same capture in Wool’s in-app capture sheet. Compare title,
   notes, status, area tag, due date, and project. The two entries should
   match for all of those fields.

6. Optionally invoke the same action through Siri using the shortcut’s name.
   Siri needs to be enabled for Shortcuts on the device; direct assistant
   discovery can take a few minutes after installing a new development build.

## Verify the weekly-review shortcut

1. Run **Start review** from Shortcuts.
2. Open Wool’s **Weekly Review** tab.
3. Confirm one review is in progress and contains these five ordered steps:

   1. Collect loose ends
   2. Process your Inbox
   3. Review projects
   4. Review waiting-for
   5. Look ahead

## Verify private CloudKit sync

1. On the first device, add a capture through **Capture item** in Shortcuts.
2. Keep Wool open briefly, then open Wool on the second device.
3. Confirm the item appears with the same title, status, area tag, due date,
   and project relationship.
4. On the second device, add an in-app capture and confirm it appears on the
   first device with the same fields.

If an item does not appear, first verify both builds use
`iCloud.com.sparkage.wool` and that both devices are signed in to the same
Apple Account. Then relaunch Wool on both devices and retry. CloudKit
private-database delivery is asynchronous, so allow a short delay before
calling the run failed.

## Evidence to record

Record the Shortcuts action names you saw, screenshots of both entries on the
two devices, and the approximate time between creating and receiving each
item. That is enough evidence to distinguish an App Intents registration
problem from a CloudKit delivery problem.
