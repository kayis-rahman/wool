import SwiftUI

// MARK: - Int Extension

//
//  AppExtensions.swift
//  Wool
//
//  Created by Kayis Rahman on 03/11/25.
//

extension Int {
    var mmss: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Double {
    var mmss: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Bundle Extension
extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildVersion: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var displayVersion: String {
        return "\(appVersion) (\(buildVersion))"
    }
}
