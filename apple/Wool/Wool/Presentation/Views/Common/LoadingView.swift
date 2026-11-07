import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // App logo/icon
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.themePrimary)

                // Loading text
                Text("Wool")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.themeTextPrimary)

                Text("Setting up your workspace...")
                    .font(.system(size: 16))
                    .foregroundColor(Color.themeTextSecondary)

                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.themePrimary))
                    .scaleEffect(1.2)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}
