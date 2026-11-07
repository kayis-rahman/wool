import SwiftUI

struct BottomTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                contentArea

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.themeButtonBackground)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var contentArea: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                .foregroundColor(iconColor)
                .frame(height: 28)

            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(isSelected ? 1.0 : 0.8)
        }
        .frame(height: 62)
        .padding(.vertical, 6)
        .glassEffectInteractiveConditional(tint: tint, in: .capsule)
    }

    private var tint: Color {
        isSelected ? Color.themeButtonBackground.opacity(0.18) : Color.secondary.opacity(0.3)
    }

    private var iconColor: Color {
        isSelected ? Color.themeTextPrimary : Color.secondary
    }

    private var labelColor: Color {
        isSelected ? Color.themeTextPrimary : Color.secondary
    }
}

#Preview {
    VStack(spacing: 20) {
        BottomTabButton(icon: "house.fill", label: "Home", isSelected: true, badge: nil) {}
        BottomTabButton(icon: "checklist", label: "Tasks", isSelected: false, badge: "3") {}
        BottomTabButton(icon: "person.fill", label: "Profile", isSelected: false, badge: nil) {}
    }
    .padding()
    .background(Color(red: 247/255, green: 253/255, blue: 251/255))
}
