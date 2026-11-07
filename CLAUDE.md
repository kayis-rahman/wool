# Wool UI Guidance

## iOS validation

All iOS builds, installs, launches, and UI-test runs use an iOS Simulator: unit
tests with the `Wool iOS Unit Tests` scheme and
`-destination "platform=iOS Simulator,name=iPhone 18 Pro"`, and UI tests with
the `Wool iOS` scheme through `scripts/run-on-simulator.sh`. See
`docs/ios-ui-tests-on-simulator.md`. The physical-device workflow remains
available as an optional extra (`docs/ios-ui-tests-on-iphone-15-pro.md`).

For every UI change—SwiftUI layout, styling, interaction, motion, navigation,
accessibility, or UI tests—read and apply the installed `emil-design-eng`
skill from `emilkowalski/skills` before implementation:

`/Users/kayisrahman/.agents/skills/anthropic-skills/skills/emil-design-eng/SKILL.md`

This applies to iOS, macOS, watchOS, and shared UI code. Use `write-swift` as
well for Swift implementation or concurrency work.

For Quick Capture, Inbox persistence, triage, or App Intent changes, require
three test layers: unit/service tests, SwiftData/integration tests, and
UI tests on an iOS Simulator. Use unique UUID
fixtures for persisted data and document manual-only cases such as low storage
or account sign-out.
