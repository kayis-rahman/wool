# CloudKit Production Notes for Wool v1

Wool uses the iCloud private database for per-user synchronization; release feature flags are stored in the public database. Before submitting v1:

1. Confirm the CloudKit container `iCloud.com.sparkage.wool` is configured for Production.
2. Promote the Development schema to Production if any schema changes were made during development.
3. Verify the `FeatureFlagsConfig` record exists in Production with all v1 flags disabled by default:
   - `features.malayalamVoice` = false
   - `features.gmailIntegration` = false
   - `features.githubProjectsIntegration` = false
4. Verify a clean install can sync an offline capture after network restoration.
5. Verify two-device capture sync in Production.
6. Keep Gmail, GitHub Projects, Apple Reminders migration, and Malayalam voice documented as unavailable in v1.

Do not ship macOS or watchOS as part of the first iOS App Store record.
