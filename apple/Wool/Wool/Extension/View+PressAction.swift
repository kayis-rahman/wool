import SwiftUI

// Extension for press action support
extension View {
    func pressAction(onPress: @escaping (Bool) -> Void, perform action: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress(true) }
                .onEnded { _ in
                    onPress(false)
                    action()
                }
        )
    }
}
