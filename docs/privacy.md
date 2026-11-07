# Wool Privacy Policy

Effective date: 2026-10-28

Wool is a privacy-first task manager. This policy describes how the iOS app handles information for Wool v1.

## Local-first task data

Wool stores tasks, projects, areas, review history, focus sessions, and settings on your device using the local database. Your task data belongs to you.

## Sync

Wool uses Apple CloudKit private database sync when you are signed in to iCloud. Wool app data belongs to your private CloudKit database. The developer does not operate a custom backend for task data and cannot read your private database.

## Calendar

If you enable calendar access, Wool reads calendar events to prepare the daily briefing. Calendar data is used locally for read-only display and planning. It is not sent to the developer.

## Voice capture

English voice capture uses Apple's on-device speech recognition. Audio is handled by Apple's speech framework. The developer does not receive or store recordings or transcriptions on a server.

## Sign in with Apple

Sign in with Apple is optional. If you use it, Apple provides the app with an account token needed for CloudKit access. Wool does not use Sign in with Apple for tracking.

## Optional integrations not in v1

Gmail import, GitHub Projects mapping, Apple Reminders migration, and Malayalam voice capture are not part of the v1 App Store release. If enabled in a future version, they remain opt-in and require explicit permission.

## Data collection

Wool v1 does not collect personal data on a developer-operated server. Analytics, if present in older code, is not the operational data path for v1. The app contains no advertising SDK and no cross-app tracking.

## Your choices

You can leave your data on device by staying offline or not signing in to iCloud. Sign out leaves local task data on your device. You can clear focus history and local session records in Settings.

## Contact

Questions about this policy can be filed at the Wool issue tracker: https://github.com/kayis-rahman/wool/issues
