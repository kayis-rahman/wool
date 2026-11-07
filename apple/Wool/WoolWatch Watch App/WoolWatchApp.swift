import SwiftUI

//  WoolWatchApp.swift
//  WoolWatch Watch App
//
//  Created by automated assistant.

@main
struct WoolWatchApp: App {
    @StateObject private var timer = PomodoroTimer()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(timer)
        }
    }
}
