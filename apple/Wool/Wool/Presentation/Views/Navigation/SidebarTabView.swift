import SwiftUI

struct SidebarTabView: View {
    @Binding var selectedTab: Int
    @Environment(PomodoroTimer.self) var timer

    private let tabs: [(icon: String, label: String, badge: String?)] = [
        (icon: "house.fill", label: "Home", badge: nil),
        (icon: "checklist", label: "Tasks", badge: nil),
        (icon: "chart.bar.fill", label: "Status", badge: nil),
        (icon: "person.circle", label: "Profile", badge: nil)
    ]

    var body: some View {
        VStack(spacing: 16) {
            appLogoSection
            tabButtonsSection
            Spacer()
            quickActionsSection
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 8)
        .padding(.leading, 8)
    }

    // MARK: - Computed Views

    private var appLogoSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color(red: 168/255, green: 230/255, blue: 207/255))
                .padding(6)
                .background(
                    Circle()
                        .fill(Color(red: 255, green: 255, blue: 255, opacity: 0.8))
                )

            Text("Wool")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.6))
        }
        .padding(.bottom, 24)
    }

    private var tabButtonsSection: some View {
        VStack(spacing: 4) {
            ForEach(0..<tabs.count, id: \.self) { index in
                SidebarTabButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    badge: badgeForTab(index),
                    hasActiveIndicator: hasActiveIndicator(for: index)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            if timer.isRunning {
                Circle()
                    .fill(Color(red: 168/255, green: 230/255, blue: 207/255))
                    .frame(width: 8, height: 8)
                    .opacity(timer.isRunning ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: timer.isRunning)
            }

            Button {
                // Quick settings or help
                withAnimation {
                    // Could show a quick menu or navigate to settings
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.bottom, 20)
    }

    private func badgeForTab(_ index: Int) -> String? {
        switch index {
        case 1: // Tasks
            return nil
        case 2: // Status
            return timer.isRunning ? "●" : nil
        default:
            return nil
        }
    }

    private func hasActiveIndicator(for index: Int) -> Bool {
        switch index {
        case 0: // Home
            return timer.currentTaskId != nil
        case 1: // Tasks
            return false
        default:
            return false
        }
    }
}
