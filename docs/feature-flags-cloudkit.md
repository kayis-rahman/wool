# Feature Flags CloudKit Configuration

Wool reads release flags from the public CloudKit database in the
`iCloud.com.sparkage.wool` container.

## Development record

In CloudKit Dashboard, select the Wool container and the **Development**
environment. Create this record in the public database:

```text
Record type: FeatureFlagsConfig
Record name: production-v1
```

Add these fields:

| Field | Type | Initial value |
| --- | --- | --- |
| `configVersion` | Int(64) | `1` |
| `updatedAt` | Date/Time | current UTC time |
| `flags` | String | JSON below |

```json
{
  "features.malayalamVoice": false,
  "features.gmailIntegration": false,
  "features.githubProjectsIntegration": false
}
```

The record name and field names must match the client implementation exactly.
Unknown flag keys are ignored by the app, so adding a new key is safe for old
app versions as long as existing keys retain their meaning.

## Development verification

Before promotion, verify that the record can be read from a signed-in test
device. The opt-in integration test is:

```sh
WOOL_CLOUDKIT_FEATURE_FLAGS_INTEGRATION=1 \
xcodebuild test \
  -project apple/Wool/Wool.xcodeproj \
  -scheme "Wool iOS Unit Tests" \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro" \
  -only-testing:WoolTests/FeatureFlagsCloudKitIntegrationTests
```

The test must run against a dedicated test Apple Account. Do not use a
personal production database for this check.

## Production promotion

After Development verification:

1. Review the record fields and JSON one more time.
2. Deploy the Development schema to **Production** in CloudKit Dashboard.
3. Confirm `FeatureFlagsConfig` and its fields appear in Production.
4. Create or update the Production `production-v1` record with the intended
   values.
5. Increment `configVersion` for every later rollout.
6. Update `updatedAt` whenever the flag payload changes.

Remote changes are cached by the app and become active on the next app launch.
The active flag snapshot does not change during an existing session.

## Rollout example

To enable Malayalam voice, update only the Development/Production record:

```json
{
  "features.malayalamVoice": true,
  "features.gmailIntegration": false,
  "features.githubProjectsIntegration": false
}
```

Set `configVersion` to the next integer, save the record, and verify the new
state in the diagnostics view after relaunching the app.
