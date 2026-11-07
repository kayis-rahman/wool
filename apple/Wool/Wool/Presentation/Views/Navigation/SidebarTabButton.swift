#if os(iOS)
import SwiftUI

struct SidebarTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let badge: String?
    let hasActiveIndicator: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    ZStack {
                        // Icon with background
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(iconColor)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? primaryTint.opacity(0.15) : Color.clear)
                                    .frame(width: 32, height: 32)
                            )
                            .scaleEffect(isPressed ? 0.9 : 1.0)

                        // Active indicator
                        if hasActiveIndicator {
                            Circle()
                                .fill(primaryTint)
                                .frame(width: 6, height: 6)
                                .offset(x: 8, y: -8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(label)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(labelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(isSelected ? 1.0 : 0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
                .glassEffectCardConditional(cornerRadius: 12, tint: isSelected ? primaryTint : secondaryTint)

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryTint)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .pressAction(onPress: { isPressed in
            withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                self.isPressed = isPressed
            }
        }, perform: action)
    }

    private var primaryTint: Color {
        Color.themeButtonBackground
    }

    private var secondaryTint: Color {
        Color.secondary.opacity(0.3)
    }

    private var iconColor: Color {
        if isSelected {
            return Color.themeTextPrimary
        } else if hasActiveIndicator {
            return Color.themeTextPrimary.opacity(0.8)
        } else {
            return .secondary
        }
    }

    private var labelColor: Color {
        if isSelected {
            return Color.themeTextPrimary
        } else if hasActiveIndicator {
            return Color.themeTextPrimary.opacity(0.7)
        } else {
            return .secondary
        }
    }
}
#elseif os(macOS)
import SwiftUI

struct SidebarTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let badge: String?
    let hasActiveIndicator: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                contentArea
                    .scaleEffect(isHovered ? 1.05 : 1.0)

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryTint)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var contentArea: some View {
        contentAreaBody
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var contentAreaBody: some View {
        HStack(spacing: 12) {
            ZStack {
                // Icon with background
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? primaryTint.opacity(0.15) : Color.clear)
                            .frame(width: 32, height: 32)
                    )

                // Active indicator
                if hasActiveIndicator {
                    Circle()
                        .fill(primaryTint)
                        .frame(width: 6, height: 6)
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(isSelected ? 1.0 : 0.8)
        }
    }

    private var primaryTint: Color {
        Color(red: 168/255, green: 230/255, blue: 207/255)
    }

    private var secondaryTint: Color {
        Color.secondary.opacity(0.3)
    }

    private var iconColor: Color {
        if isSelected {
            return primaryTint
        } else if hasActiveIndicator {
            return primaryTint.opacity(0.8)
        } else {
            return .secondary
        }
    }

    private var labelColor: Color {
        if isSelected {
            return primaryTint
        } else if hasActiveIndicator {
            return primaryTint.opacity(0.7)
        } else {
            return .secondary
        }
    }
}
#endif
