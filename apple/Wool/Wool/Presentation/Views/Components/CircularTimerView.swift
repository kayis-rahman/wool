import SwiftUI

struct CircularTimerView: View {
    @Environment(PomodoroTimer.self) var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sandglassRotation = 0.0

    let size: CGFloat
    let showSessionProgress: Bool

    init(size: CGFloat = 280, showSessionProgress: Bool = true) {
        self.size = size
        self.showSessionProgress = showSessionProgress
    }

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 30.0,
                    paused: reduceMotion || !timer.isRunning
                )
            ) { context in
                SandglassView(
                    progress: visualProgress(at: context.date),
                    isRunning: timer.isRunning,
                    streamPhase: streamPhase(at: context.date),
                    color: phaseColor
                )
            }
            .frame(width: size * 0.38, height: size * 0.54)
            .rotationEffect(.degrees(sandglassRotation))

            VStack(alignment: .center, spacing: size * 0.025) {
                Text(timer.remainingSeconds.mmss)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.themeTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .layoutPriority(1)

                Text(statusText)
                    .font(.system(size: size * 0.04, weight: .medium, design: .rounded))
                    .foregroundColor(.themeTextSecondary.opacity(0.62))
                    .multilineTextAlignment(.center)

                if showSessionProgress {
                    SandglassCycleProgress(
                        completedCount: timer.shortBreaksCompleted,
                        totalCount: timer.cycleSize,
                        isLongBreak: timer.phase == .longBreak,
                        currentColor: phaseColor,
                        reduceMotion: reduceMotion
                    )
                }

            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: size * 0.62)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue("\(timer.remainingSeconds.mmss) remaining, \(timer.phase.displayName), \(timer.isRunning ? "running" : "paused"), \(cycleAccessibilityValue)")
        .onChange(of: timer.phase) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.55)) {
                sandglassRotation += 360
            }
        }
    }

    private var phaseColor: Color {
        switch timer.phase {
        case .work:      .focusWork
        case .break:     .focusBreak
        case .longBreak: .focusLongBreak
        }
    }

    private var statusText: String {
        if timer.isRunning { return "Sand is flowing" }
        if timer.progress > 0 { return "Paused" }
        return "Ready when you are"
    }

    private var cycleAccessibilityValue: String {
        let completed = min(max(timer.shortBreaksCompleted, 0), timer.cycleSize)
        if timer.phase == .longBreak, completed == timer.cycleSize {
            return "four focus cycles completed"
        }
        return "cycle \(min(completed + 1, timer.cycleSize)) of \(timer.cycleSize)"
    }

    private func visualProgress(at date: Date) -> Double {
        let duration = Double(max(timer.currentDuration, 1))
        let remaining: Double

        if timer.isRunning, let endAt = timer.endAt {
            remaining = max(0, endAt.timeIntervalSince(date))
        } else {
            remaining = Double(max(timer.remainingSeconds, 0))
        }

        return min(max((duration - remaining) / duration, 0), 1)
    }

    private func streamPhase(at date: Date) -> Double {
        guard timer.isRunning, !reduceMotion else { return 0 }
        let cycleDuration = 0.72
        return date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
    }

}

private struct SandglassCycleProgress: View {
    let completedCount: Int
    let totalCount: Int
    let isLongBreak: Bool
    let currentColor: Color
    let reduceMotion: Bool

    var body: some View {
        let total = max(totalCount, 1)
        let completed = min(max(completedCount, 0), total)
        let currentIndex = min(completed, total - 1)
        let isComplete = completed == total

        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(segmentColor(at: index, completed: completed, currentIndex: currentIndex, isComplete: isComplete))
                        .frame(
                            width: index == currentIndex && !isComplete ? 24 : 14,
                            height: 5
                        )
                }
            }

            Text(isLongBreak && isComplete ? "Long break · 4 cycles complete" : "Cycle \(currentIndex + 1) of \(total)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(isLongBreak && isComplete ? currentColor : .themeTextSecondary.opacity(0.54))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: completed)
        .accessibilityHidden(true)
    }

    private func segmentColor(
        at index: Int,
        completed: Int,
        currentIndex: Int,
        isComplete: Bool
    ) -> Color {
        if index < completed { return .themeAccent.opacity(0.72) }
        if index == currentIndex, !isComplete { return currentColor }
        return .themeTextSecondary.opacity(0.14)
    }
}

private struct SandglassView: View {
    let progress: Double
    let isRunning: Bool
    let streamPhase: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let chamberHeight = proxy.size.height * 0.44
            let chamberWidth = proxy.size.width * 0.82
            let grainSize = max(3, proxy.size.width * 0.055)
            let filledFraction = CGFloat(min(max(progress, 0), 1))
            let remainingFraction = CGFloat(1 - min(max(progress, 0), 1))
            let moundHeight = min(
                min(chamberHeight * 0.075, chamberHeight * filledFraction * 0.45),
                chamberHeight * remainingFraction
            )
            let dropDistance = max(
                grainSize,
                (chamberHeight * remainingFraction) - moundHeight
            )

            ZStack {
                SandLevelShape(fraction: 1 - progress, chamber: .upper)
                    .fill(color.opacity(0.92))
                    .frame(width: chamberWidth, height: chamberHeight)
                    .offset(y: -proxy.size.height * 0.22)

                SandLevelShape(fraction: progress, chamber: .lower)
                    .fill(color.opacity(0.78))
                    .frame(width: chamberWidth, height: chamberHeight)
                    .offset(y: proxy.size.height * 0.22)

                if isRunning, progress < 1 {
                    SandStreamShape()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.92), color.opacity(0.48)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: grainSize * 0.7, height: dropDistance)
                        .offset(y: dropDistance / 2)

                    ForEach(0..<3, id: \.self) { index in
                        let phase = (streamPhase + (Double(index) / 3))
                            .truncatingRemainder(dividingBy: 1)
                        let fallProgress = phase * phase
                        let drift = sin((phase * .pi * 2) + Double(index)) * Double(grainSize * 0.32)
                        let size = grainSize * CGFloat(0.52 + (Double(index) * 0.1))
                        let impactProgress = min(max((phase - 0.86) / 0.14, 0), 1)

                        Circle()
                            .fill(color.opacity(0.88))
                            .frame(width: size, height: size)
                            .offset(
                                x: CGFloat(drift),
                                y: dropDistance * CGFloat(fallProgress)
                            )

                        Capsule()
                            .fill(color.opacity(0.48))
                            .frame(
                                width: grainSize * CGFloat(1 + impactProgress),
                                height: max(1.2, grainSize * 0.2)
                            )
                            .offset(x: CGFloat(drift * 0.2), y: dropDistance)
                            .opacity(sin(impactProgress * .pi) * 0.55)
                    }
                }

                HourglassOutline()
                    .stroke(
                        Color.themeTextPrimary.opacity(0.46),
                        style: StrokeStyle(lineWidth: max(1.5, proxy.size.width * 0.018), lineCap: .round, lineJoin: .round)
                    )

                VStack {
                    Capsule()
                        .fill(Color.themeTextPrimary.opacity(0.55))
                        .frame(height: max(2, proxy.size.height * 0.025))
                    Spacer()
                    Capsule()
                        .fill(Color.themeTextPrimary.opacity(0.55))
                        .frame(height: max(2, proxy.size.height * 0.025))
                }
                .padding(.horizontal, proxy.size.width * 0.05)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SandStreamShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topHalfWidth = rect.width * 0.22
        let bottomHalfWidth = rect.width * 0.46

        var path = Path()
        path.move(to: CGPoint(x: rect.midX - topHalfWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + topHalfWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + bottomHalfWidth, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - bottomHalfWidth, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct HourglassOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.10
        let neckHalfWidth = rect.width * 0.055
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: center.x + neckHalfWidth, y: center.y),
            control: CGPoint(x: rect.maxX - inset, y: rect.height * 0.30)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.maxY),
            control: CGPoint(x: rect.maxX - inset, y: rect.height * 0.70)
        )
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: center.x - neckHalfWidth, y: center.y),
            control: CGPoint(x: rect.minX + inset, y: rect.height * 0.70)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.minY),
            control: CGPoint(x: rect.minX + inset, y: rect.height * 0.30)
        )
        return path
    }
}

private struct SandLevelShape: Shape {
    enum Chamber {
        case upper
        case lower
    }

    var fraction: Double
    let chamber: Chamber

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amount = CGFloat(min(max(fraction, 0), 1))
        guard amount > 0 else { return Path() }

        let edgeHalfWidth = rect.width * 0.48
        let neckHalfWidth = rect.width * 0.07
        let levelY = rect.maxY - (rect.height * amount)
        let levelProgress = levelY / max(rect.height, 1)
        let levelHalfWidth: CGFloat

        switch chamber {
        case .upper:
            levelHalfWidth = edgeHalfWidth + ((neckHalfWidth - edgeHalfWidth) * levelProgress)
        case .lower:
            levelHalfWidth = neckHalfWidth + ((edgeHalfWidth - neckHalfWidth) * levelProgress)
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.midX - levelHalfWidth, y: levelY))

        switch chamber {
        case .upper:
            let funnelDepth = min(
                rect.height * 0.06,
                max(0, rect.maxY - levelY) * (1 - amount) * 0.5
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: levelY + funnelDepth),
                control: CGPoint(x: rect.midX - (levelHalfWidth * 0.35), y: levelY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX + levelHalfWidth, y: levelY),
                control: CGPoint(x: rect.midX + (levelHalfWidth * 0.35), y: levelY)
            )
            path.addLine(to: CGPoint(x: rect.midX + neckHalfWidth, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - neckHalfWidth, y: rect.maxY))
        case .lower:
            let moundHeight = min(
                min(rect.height * 0.075, rect.height * amount * 0.45),
                max(0, levelY - rect.minY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: levelY - moundHeight),
                control: CGPoint(x: rect.midX - (levelHalfWidth * 0.35), y: levelY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX + levelHalfWidth, y: levelY),
                control: CGPoint(x: rect.midX + (levelHalfWidth * 0.35), y: levelY)
            )
            path.addLine(to: CGPoint(x: rect.midX + edgeHalfWidth, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - edgeHalfWidth, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    CircularTimerView()
        .environment(PomodoroTimer())
}
