import AVFoundation
import SwiftUI
import UserNotifications

#if os(macOS)
import AppKit

struct macOSContentView: View {
    @Environment(PomodoroTimer.self) var timer
    @Environment(SessionLogger.self) var logger
    @Environment(AuthManager.self) var authManager
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var audioPlayer: AVAudioPlayer?
    @State private var lastPhase: Phase = .work
    @State private var didRequestNotificationPermission: Bool = UserDefaults.standard.bool(forKey: "didRequestNotificationPermission")
    @State private var showingAbout: Bool = false

    var body: some View {
        let ringSize: CGFloat = 280
        let ringLineWidth = max(10, ringSize * 0.065)
        let buttonSize: CGFloat = 54

        return VStack(spacing: 10) {
            timerRing(ringSize: ringSize, ringLineWidth: ringLineWidth, buttonSize: buttonSize)

            HStack {
                resetButton(buttonSize: buttonSize)
                Spacer()
                optionsControl(buttonSize: buttonSize)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .frame(width: ringSize + 60)
        .glassEffectOrMaterial()
        .onAppear {
            TimerSyncManager.shared.configure(with: timer)
            lastPhase = timer.phase
        }
        .onChange(of: timer.phase) { oldPhase, newPhase in
            if newPhase != oldPhase {
                playChime()
                lastPhase = newPhase
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    // MARK: - Bindings for macOS Menu Pickers
    private var workDurationBinding: Binding<Int> {
        Binding<Int>(
            get: { timer.workDuration / 60 },
            set: { newValue in
                updateTimerDurations(workMinutes: newValue, shortBreakMinutes: timer.breakDuration / 60, longBreakMinutes: timer.longBreakDuration / 60)
            }
        )
    }

    private var shortBreakDurationBinding: Binding<Int> {
        Binding<Int>(
            get: { timer.breakDuration / 60 },
            set: { newValue in
                updateTimerDurations(workMinutes: timer.workDuration / 60, shortBreakMinutes: newValue, longBreakMinutes: timer.longBreakDuration / 60)
            }
        )
    }

    private var longBreakDurationBinding: Binding<Int> {
        Binding<Int>(
            get: { timer.longBreakDuration / 60 },
            set: { newValue in
                updateTimerDurations(workMinutes: timer.workDuration / 60, shortBreakMinutes: timer.breakDuration / 60, longBreakMinutes: newValue)
            }
        )
    }

    private func updateTimerDurations(workMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int) {
        let work = workMinutes * 60
        let short = shortBreakMinutes * 60
        let long = longBreakMinutes * 60

        // Keep the rest of the state unchanged, only swap the durations
        timer.applySyncedState(
            phase: timer.phase,
            remainingSeconds: min(timer.remainingSeconds, {
                switch timer.phase {
                case .work: return work
                case .break: return short
                case .longBreak: return long
                }
            }()),
            isRunning: timer.isRunning,
            workDuration: work,
            breakDuration: short,
            longBreakDuration: long,
            autoStartNextSession: timer.autoStartNextSession,
            shortBreaksCompleted: timer.shortBreaksCompleted,
            startTimestamp: timer.startTimestamp,
            pauseTimestamp: timer.pauseTimestamp,
            lastModifiedTimestamp: Date().timeIntervalSince1970
        )
    }

    private func timerRing(ringSize: CGFloat, ringLineWidth: CGFloat, buttonSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color.themeTextSecondary.opacity(0.3), lineWidth: ringLineWidth)

            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    angularGradient(for: timer.phase),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: ringSize * 0.0) {
                Text(timer.remainingSeconds.mmss)
                    .font(.system(size: ringSize * 0.22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.themeTextPrimary)
                    .padding(.top, 10)

                Text(timer.phase == .work ? "just focus " : "break time!")
                    .font(.system(size: ringSize * 0.08, weight: .regular))
                    .foregroundStyle(Color.themeTextSecondary)
                    .padding(.bottom, 10)

                // Inline cycle progress (macOS-specific implementation)
                HStack(spacing: 8) {
                    ForEach(0..<timer.cycleSize, id: \.self) { index in
                        Circle()
                            .fill(index < timer.shortBreaksCompleted ? Color.themePrimary : Color.themeTextSecondary.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: ringSize * 0.5)
                .padding(.bottom, 15)

                playPauseButton(buttonSize: buttonSize)
            }
        }
        .frame(width: ringSize, height: ringSize)
    }

    @ViewBuilder
    private func optionsControl(buttonSize: CGFloat) -> some View {
        let minutesRange = Array(stride(from: 5, to: 121, by: 5))
        Menu {
            Picker("Focus Duration", selection: workDurationBinding) {
                ForEach(minutesRange, id: \.self) { Text("\($0) minutes").tag($0) }
            }

            Picker("Short Break", selection: shortBreakDurationBinding) {
                ForEach(minutesRange, id: \.self) { Text("\($0) minutes").tag($0) }
            }

            Picker("Long Break", selection: longBreakDurationBinding) {
                ForEach(minutesRange, id: \.self) { Text("\($0) minutes").tag($0) }
            }

            Divider()

            Toggle("Auto-start next session", isOn: Binding(
                get: { timer.autoStartNextSession },
                set: { timer.autoStartNextSession = $0 }
            ))

            Divider()

            Toggle("Sound", isOn: $soundEnabled)
            Toggle("Haptics", isOn: $hapticsEnabled)

            Divider()

            Button("About Wool") {
                showingAbout = true
            }

            Divider()

            if authManager.isSignedIn {
                if let name = authManager.displayName, !name.isEmpty {
                    Text(name)
                }
                Button("Sign Out", role: .destructive) {
                    _Concurrency.Task { await authManager.signOut() }
                }
            } else {
                Button("Sign In with Apple") {
                    _Concurrency.Task {
                        do {
                            try await authManager.signInWithApple()
                        } catch {
                            print("Sign-in failed: \(error)")
                        }
                    }
                }
            }

            Divider()

            Button("Reset to Defaults", role: .destructive) {
                timer.reset()
                soundEnabled = true
                hapticsEnabled = true
            }

        } label: {
            if #available(macOS 26, *) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: buttonSize * 0.45))
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundStyle(Color.themeTextSecondary)
                    .glassEffect(.regular.interactive(), in: .circle)
            } else {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: buttonSize * 0.45))
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundStyle(Color.themeTextSecondary)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Options")
    }

    private func playPauseButton(buttonSize: CGFloat) -> some View {
        Button {
            if timer.isRunning {
                Task {
                    await TimerSyncManager.shared.syncTimerAction(.pause)
                }
            } else {
                startWithPermission()  // Will also be updated to use TimerSyncManager
            }
        } label: {
            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: buttonSize * 0.5, weight: .bold))
                .frame(width: buttonSize * 1.2, height: buttonSize * 1.2)
                .glassEffectInteractiveConditional(tint: .themePrimary, in: .circle)
                .foregroundStyle(Color.themeAccent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timer.isRunning ? "Pause" : "Start")
    }

    private func resetButton(buttonSize: CGFloat) -> some View {
        Button {
            Task {
                await TimerSyncManager.shared.syncTimerAction(.reset)
            }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: buttonSize * 0.45))
                .frame(width: buttonSize, height: buttonSize)
                .glassEffectInteractiveConditional(in: .circle)
                .foregroundStyle(Color.themeTextSecondary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset")
    }

    private func angularGradient(for phase: Phase) -> AngularGradient {
        switch phase {
        case .work:
            AngularGradient(
                gradient: Gradient(colors: [
                    Color(red: 168/255, green: 230/255, blue: 207/255),
                    Color(red: 86/255, green: 197/255, blue: 150/255)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        case .break:
            AngularGradient(
                gradient: Gradient(colors: [
                    Color(red: 255/255, green: 179/255, blue: 102/255),
                    Color(red: 255/255, green: 159/255, blue: 28/255)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        case .longBreak:
            AngularGradient(
                gradient: Gradient(colors: [
                    Color(red: 255/255, green: 159/255, blue: 28/255),
                    Color(red: 255/255, green: 128/255, blue: 0/255)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        }
    }

    private func startWithPermission() {
        if !didRequestNotificationPermission {
            NotificationManager.shared.requestPermission { _ in }
            didRequestNotificationPermission = true
            UserDefaults.standard.set(true, forKey: "didRequestNotificationPermission")
        }
        Task {
            await TimerSyncManager.shared.syncTimerAction(.start)
        }
    }

    private func playChime() {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        guard let soundURL = Bundle.main.url(forResource: "chime-sound", withExtension: "mp3") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            // ignore
        }
    }
}

// Extension to provide conditional glassEffect for macOS < 26
extension View {
    @ViewBuilder
    func glassEffectOrMaterial() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        } else {
            self.background(.regularMaterial)
        }
    }
}

#endif

#if os(macOS)
#Preview {
    macOSContentView()
        .environment(PomodoroTimer())
        .environment(SessionLogger())
        .environment(AuthManager())
}
#endif

// All PomodoroTimer methods are now properly implemented - no shims needed
