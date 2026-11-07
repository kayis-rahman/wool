import SwiftUI
import SwiftData

struct GmailIntegrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GmailAccountRecord.connectedAt, order: .reverse) private var accounts: [GmailAccountRecord]
    @State private var isSyncing = false
    @State private var isConnecting = false
    @State private var alertMessage: String?
    @State private var accountToDisconnect: GmailAccountRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if accounts.isEmpty {
                Label("Bring actionable email into Inbox", systemImage: "envelope.badge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(isConnecting ? "Connecting…" : "Connect Gmail") {
                    connectGmail()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
            } else {
                ForEach(accounts, id: \.id) { account in
                    accountRow(account)
                }
            }
        }
        .alert("Gmail", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog("Disconnect Gmail?", item: $accountToDisconnect) { account in
            Button("Disconnect", role: .destructive) { disconnect(account) }
            Button("Cancel", role: .cancel) { accountToDisconnect = nil }
        } message: { _ in
            Text("Future email imports will stop. Existing Inbox items will remain.")
        }
    }

    @ViewBuilder
    private func accountRow(_ account: GmailAccountRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName.isEmpty ? account.accountIdentifier : account.displayName)
                        .font(.headline)
                    Text(statusDescription(for: account))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(statusColor(for: account))
                    .frame(width: 9, height: 9)
                    .accessibilityLabel(statusDescription(for: account))
            }

            if let lastSync = account.lastSuccessfulSyncAt {
                Text("Last synced \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if account.status == .reauthorizationRequired || account.status == .disconnected {
                    Button("Reconnect") { connectGmail() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(isSyncing ? "Syncing…" : "Sync Now") { sync(account) }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSyncing)
                }
                Button("Disconnect", role: .destructive) { accountToDisconnect = account }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func statusDescription(for account: GmailAccountRecord) -> String {
        switch account.status {
        case .connected: "Connected"
        case .syncing: "Syncing Gmail"
        case .paused: "Sync paused"
        case .reauthorizationRequired: "Reauthentication required"
        case .temporarilyUnavailable: "Gmail temporarily unavailable"
        case .disconnected: "Disconnected"
        }
    }

    private func statusColor(for account: GmailAccountRecord) -> Color {
        switch account.status {
        case .connected: .green
        case .syncing: .blue
        case .reauthorizationRequired: .orange
        case .temporarilyUnavailable: .yellow
        case .paused, .disconnected: .secondary
        }
    }

    private func connectGmail() {
        isConnecting = true
        Task { @MainActor in
            defer { isConnecting = false }
            do {
                let profile = try await GmailOAuthService().connect()
                let existing = accounts.first(where: { $0.accountIdentifier.caseInsensitiveCompare(profile.email) == .orderedSame })
                let account = existing ?? GmailAccountRecord(accountIdentifier: profile.email, displayName: profile.displayName)
                account.displayName = profile.displayName
                account.status = .connected
                account.isEnabled = true
                if existing == nil { modelContext.insert(account) }
                try modelContext.save()
                sync(account)
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    private func sync(_ account: GmailAccountRecord) {
        isSyncing = true
        Task { @MainActor in
            defer { isSyncing = false }
            do {
                let client: any GmailAPIClient
                let token: String
                if WoolModelContainer.isTestingProcess {
                    token = "fixture"
                    client = FixtureGmailAPIClient(
                        profile: GmailProfile(email: account.accountIdentifier, displayName: account.displayName),
                        pages: [[GmailMessage(
                            id: "ui-fixture-message",
                            threadID: "ui-fixture-thread",
                            subject: "UI Test Gmail Review",
                            sender: "fixture@example.com",
                            body: "Review this imported email.",
                            receivedAt: .now,
                            webURL: "https://mail.google.com/mail/u/0/#inbox/ui-fixture-message",
                            hasAttachments: false
                        )]]
                    )
                } else {
                    token = try await GmailOAuthService().validAccessToken()
                    client = LiveGmailAPIClient()
                }
                let result = try await GmailSyncService(apiClient: client).sync(
                    accountIdentifier: account.accountIdentifier,
                    accessToken: token,
                    in: modelContext
                )
                alertMessage = "Imported \(result.imported) email(s)."
            } catch {
                if (error as? GmailServiceError) == .reauthorizationRequired {
                    account.status = .reauthorizationRequired
                    try? modelContext.save()
                } else if (error as? GmailServiceError) == .authorizationRequired {
                    account.status = .disconnected
                    try? modelContext.save()
                }
                alertMessage = error.localizedDescription
            }
        }
    }

    private func disconnect(_ account: GmailAccountRecord) {
        account.status = .disconnected
        account.isEnabled = false
        try? KeychainStore.clear(.gmailAccessToken)
        try? KeychainStore.clear(.gmailRefreshToken)
        try? KeychainStore.clear(.gmailTokenExpiry)
        try? KeychainStore.clear(.gmailGrantedScopes)
        try? modelContext.save()
    }
}
