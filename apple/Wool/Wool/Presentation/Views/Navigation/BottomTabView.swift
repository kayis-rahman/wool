import SwiftUI

struct BottomTabView: View {
    @Binding var selectedTab: Int
    @Environment(PomodoroTimer.self) var timer

    @Namespace private var selectionNamespace

    private let tabs: [(icon: String, label: String, badge: String?)] = [
        (icon: "house.fill", label: "Home", badge: nil),
        (icon: "checklist", label: "Tasks", badge: nil),
        (icon: "chart.bar.fill", label: "Status", badge: nil),
        (icon: "person.circle", label: "Profile", badge: nil)
    ]

    var body: some View {
        HStack(spacing: 0) {
            GlassEffectContainer(spacing: 24) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    tabView(for: index)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 1, green: 1, blue: 1, opacity: 0.4))
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabView(for index: Int) -> some View {
        BottomTabButton(
            icon: tabs[index].icon,
            label: tabs[index].label,
            isSelected: selectedTab == index,
            badge: badgeForTab(index)
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }
        .background {
            if selectedTab == index {
                Capsule()
                    .fill(Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.18))
                    .matchedGeometryEffect(id: "tabSelection", in: selectionNamespace)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
            }
        }
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
}

#Preview {
    VStack {
        BottomTabView(selectedTab: .constant(0))
    }
    .environment(PomodoroTimer())
    .background(Color(red: 247/255, green: 253/255, blue: 251/255))
}
