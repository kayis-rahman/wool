import SwiftUI

//
//  AboutView.swift
//  Wool
//
//  Created by Wool Team on 02/12/2025.
//

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.themePrimary)

            // App Name and Version
            VStack(spacing: 8) {
                Text("Wool")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.themeTextPrimary)

                Text("Version \(Bundle.main.displayVersion)")
                    .font(.system(size: 16))
                    .foregroundColor(Color.themeTextSecondary)
            }

            // Description
            Text("A privacy-first task and focus manager for iOS, macOS, and watchOS.")
                .font(.system(size: 14))
                .foregroundColor(Color.themeTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .lineSpacing(4)

            Spacer()

            // Links
            VStack(spacing: 12) {
                Button("Privacy Policy") {
                    openPrivacyPolicy()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.themePrimary)

                Button("Help & Support") {
                    openHelpAndSupport()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.themePrimary)
            }

            Spacer()

            // Copyright
            Text("© 2025 Wool. All rights reserved.")
                .font(.system(size: 12))
                .foregroundColor(Color.themeTextSecondary.opacity(0.7))
        }
        .padding(40)
        .frame(width: 400, height: 500)
        .background(Color.themeBackground)
    }

    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://github.com/kayis-rahman/wool/blob/main/docs/privacy.md") else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(watchOS)
        WKExtension.shared().openSystemURL(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func openHelpAndSupport() {
        guard let url = URL(string: "https://github.com/kayis-rahman/wool/blob/main/docs/support.md") else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(watchOS)
        WKExtension.shared().openSystemURL(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

#Preview {
    AboutView()
}
