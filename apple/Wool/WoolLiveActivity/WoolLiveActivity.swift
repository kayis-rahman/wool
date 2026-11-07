import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WoolLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WoolLiveActivity()
    }
}

struct WoolLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusLiveActivityAttributes.self) { context in
            lockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.05, green: 0.10, blue: 0.08))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Wool")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.mint)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(state: context.state)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(width: 58, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.center) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(phaseColor(context.state.phase))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 7) {
                        HStack {
                            Text(context.state.phase)
                            Spacer()
                            Text("Cycle \(context.state.cycleNumber)/\(context.state.cycleSize)")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                        if let taskTitle = context.state.taskTitle, !taskTitle.isEmpty {
                            Text(taskTitle)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "hourglass")
                    .foregroundStyle(phaseColor(context.state.phase))
            } compactTrailing: {
                timerText(state: context.state)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: 42, alignment: .trailing)
            } minimal: {
                Image(systemName: "hourglass")
                    .foregroundStyle(phaseColor(context.state.phase))
            }
            .keylineTint(phaseColor(context.state.phase))
        }
    }

    @ViewBuilder
    private func lockScreenView(state: FocusLiveActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "hourglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(phaseColor(state.phase))

            VStack(alignment: .leading, spacing: 3) {
                Text(state.phase)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let taskTitle = state.taskTitle, !taskTitle.isEmpty {
                    Text(taskTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                } else {
                    Text("Focus session")
                        .font(.subheadline.weight(.medium))
                }
            }

            Spacer()
            timerText(state: state)
                .font(.title3.monospacedDigit().weight(.bold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func timerText(state: FocusLiveActivityAttributes.ContentState) -> some View {
        if !state.isPaused, let endDate = state.endDate {
            Text(timerInterval: Date()...endDate, countsDown: true)
        } else {
            Text(format(seconds: state.remainingSeconds))
        }
    }

    private func format(seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    private func phaseColor(_ phase: String) -> Color {
        switch phase {
        case "Break": .orange
        case "Long Break": .purple
        default: .blue
        }
    }
}
