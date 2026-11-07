import SwiftUI

struct SyncStatusBanner: View {
    let alertManager: SyncFailureAlertManager

    var body: some View {
        if alertManager.isActive {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync paused")
                            .font(.system(.body, design: .default))
                            .fontWeight(.semibold)

                        Text("\(alertManager.failureCount) consecutive failures")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await alertManager.retryAction?()
                            alertManager.dismissAlert()
                        }
                    }) {
                        Text("Retry")
                            .font(.system(.caption, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(.regularMaterial)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var alertManager = SyncFailureAlertManager.shared

    VStack {
        SyncStatusBanner(alertManager: alertManager)
        Spacer()
    }
    .onAppear {
        alertManager.showAlert(consecutiveFailures: 3)
    }
}
