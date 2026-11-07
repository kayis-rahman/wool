import SwiftUI

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let isDestructive: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: WorkspaceStyle.controlHeight)
            .padding(.horizontal, 16)
            .foregroundColor(isDestructive ? Color.themeError : Color.themeTextPrimary)
            .background(
                    RoundedRectangle(cornerRadius: WorkspaceStyle.cardCornerRadius, style: .continuous)
                    .fill(Color.themeCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkspaceStyle.cardCornerRadius, style: .continuous)
                            .stroke(isDestructive ? Color.themeError : Color.themeBorder, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PressFeedbackButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: "Reset Timer", icon: "arrow.counterclockwise") {}
        SecondaryButton(title: "Delete Data", icon: "trash", isDestructive: true) {}
        SecondaryButton(title: "Settings", icon: "gear") {}
    }
    .padding()
    .background(Color.themeBackground)
}
