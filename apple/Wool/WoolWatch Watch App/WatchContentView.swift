import SwiftUI
import UserNotifications

//
//  WatchContentView.swift
//  WoolWatch Watch App
//

struct WatchContentView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @State private var lastPhase: Phase = .work
    @State private var didRequestNotificationPermission: Bool = UserDefaults.standard.bool(forKey: "didRequestNotificationPermission")

    private let ringSize: CGFloat = 120
    private let ringLineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 16) {
                // Timer ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: ringLineWidth)
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [
                                timer.phase == .work ? Color.accentColor : Color.green,
                                timer.phase == .work ? Color.accentColor.opacity(0.6) : Color.green.opacity(0.6)
                            ]), center: .center),
                            style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)

                    VStack(spacing: 4) {
                        Text(timer.remainingSeconds.mmss)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Color.primary)

                        Text(timer.phase == .work ? "focus" : "break")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }

                // Play/Pause button
                Button {
                    timer.isRunning ? timer.pause() : startWithPermission()
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear { lastPhase = timer.phase }
        .onChange(of: timer.phase) { newPhase in
            if newPhase != lastPhase {
                NotificationManager.shared.sendSessionDoneNotification(phase: lastPhase.rawValue)
                lastPhase = newPhase
            }
        }
    }

    private func startWithPermission() {
        if !didRequestNotificationPermission {
            NotificationManager.shared.requestPermission { _ in }
            didRequestNotificationPermission = true
            UserDefaults.standard.set(true, forKey: "didRequestNotificationPermission")
        }
        timer.start()
    }
}

#Preview {
    WatchContentView()
        .environmentObject(PomodoroTimer())
}
