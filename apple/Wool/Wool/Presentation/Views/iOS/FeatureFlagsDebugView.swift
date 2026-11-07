import SwiftUI

struct FeatureFlagsDebugView: View {
    @Environment(FeatureFlags.self) private var featureFlags

    var body: some View {
        List {
            Section("Active configuration") {
                metadataRow("Source", value: featureFlags.source.rawValue.capitalized)
                metadataRow("Config version", value: featureFlags.configVersion.map(String.init) ?? "Defaults")
                metadataRow("Fetched", value: featureFlags.fetchedAt.map(Self.dateFormatter.string) ?? "Never")
                if let pending = featureFlags.pendingConfigVersion {
                    metadataRow("Pending next launch", value: String(pending))
                }
                if let error = featureFlags.lastRefreshError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Flags") {
                ForEach(featureFlags.statuses) { status in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(status.flag.rawValue)
                                .font(.body.monospaced())
                            Spacer()
                            Text(status.isEnabled ? "ON" : "OFF")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(status.isEnabled ? .green : .secondary)
                        }
                        Text("Owner: \(status.owner) · Default: \(status.defaultValue ? "on" : "off")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Removal target: \(status.intendedRemovalDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("feature-flag-\(status.flag.rawValue)")
                }
            }
        }
        .navigationTitle("Feature Flags")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func metadataRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
