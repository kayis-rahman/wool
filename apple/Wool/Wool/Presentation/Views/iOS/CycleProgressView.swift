import SwiftUI

struct CycleProgressView: View {
    let timer: PomodoroTimer

    init(timer: PomodoroTimer) {
        self.timer = timer
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<timer.cycleSize, id: \.self) { index in
                Capsule()
                    .fill(index < timer.shortBreaksCompleted ? Color.themeAccent : Color.themeTextSecondary.opacity(0.22))
                    .frame(width: index == timer.shortBreaksCompleted ? 24 : 14, height: 5)
            }
        }
        .animation(.easeOut(duration: 0.18), value: timer.shortBreaksCompleted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle \(timer.shortBreaksCompleted + 1) of \(timer.cycleSize)")
    }
}
