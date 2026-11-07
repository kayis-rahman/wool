import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: WorkspaceStyle.controlHeight)
            .padding(.horizontal, 16)
        }
        .foregroundStyle(Color.themeButtonForeground)
        .background(Color.themeButtonBackground, in: RoundedRectangle(cornerRadius: WorkspaceStyle.cardCornerRadius, style: .continuous))
        .glassEffectInteractiveConditional(tint: .themeButtonBackground, in: .rect(cornerRadius: WorkspaceStyle.cardCornerRadius))
        .buttonStyle(PressFeedbackButtonStyle())
        .disabled(isLoading)
    }
}

struct PressFeedbackButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Start Timer", icon: "play.fill") {}
        PrimaryButton(title: "Loading...", isLoading: true) {}
        PrimaryButton(title: "Sign In", icon: "person.fill") {}
    }
    .padding()
}
