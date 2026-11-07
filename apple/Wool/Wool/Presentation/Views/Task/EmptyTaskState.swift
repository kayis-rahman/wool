#if os(iOS)
import SwiftUI

struct EmptyTaskState: View {
    @Binding var showingCreateTask: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.themePrimary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checklist")
                    .font(.system(size: 48))
                    .foregroundColor(.themePrimary)
            }

            VStack(spacing: 8) {
                Text("No tasks yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Create your first task to get started with time management")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showingCreateTask = true
            } label: {
                Text("Create Task")
                    .font(.headline)
                    .foregroundColor(Color.themeButtonForeground)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.themeButtonBackground)
                    .clipShape(Capsule())
                    .shadow(color: Color.themeButtonBackground.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
#endif
