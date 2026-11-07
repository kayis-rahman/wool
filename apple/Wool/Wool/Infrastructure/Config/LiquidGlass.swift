import SwiftUI

// MARK: - Liquid Glass Utilities

/// Liquid Glass design system for Wool
/// Provides reusable glass effect modifiers using native .glassEffect()
struct LiquidGlass {
    private init() {}

    // MARK: - Theme-Aware Tints (using hex values directly)

    static var primaryTint: Color {
        Color(red: 168/255, green: 230/255, blue: 207/255)
    }

    static var activeTint: Color {
        Color(red: 86/255, green: 197/255, blue: 150/255)
    }

    static var secondaryTint: Color {
        Color.secondary.opacity(0.3)
    }

    static var warningTint: Color {
        Color(red: 255/255, green: 159/255, blue: 28/255)
    }

    static var errorTint: Color {
        Color.red.opacity(0.8)
    }
}

// MARK: - View Modifiers (iOS 26+ / macOS 26+)

/// Apply glass effect to any view (iOS 26+ / macOS 26+)
@available(iOS 26, macOS 26, *)
extension View {
    /// Apply glass effect with tint and interactivity
    func glassEffectInteractive(tint: Color? = nil, in shape: some Shape = Capsule()) -> some View {
        if let tint = tint {
            return self.glassEffect(.regular.tint(tint).interactive(), in: shape)
        }
        return self.glassEffect(.regular.interactive(), in: shape)
    }

    /// Apply card-style glass effect
    func glassEffectCard(cornerRadius: CGFloat = 12, tint: Color? = nil) -> some View {
        if let tint = tint {
            return self.glassEffect(.regular.tint(tint.opacity(0.3)), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        return self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Conditional View Modifiers (all iOS/macOS versions)

extension View {
    /// Apply glass effect conditionally based on availability (iOS 26+ / macOS 26+)
    @ViewBuilder
    func glassEffectInteractiveConditional(tint: Color? = nil, in shape: some Shape = Capsule()) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffectInteractive(tint: tint, in: shape)
        } else {
            self.background(.ultraThinMaterial)
        }
    }

    /// Apply card-style glass effect conditionally based on availability (iOS 26+ / macOS 26+)
    @ViewBuilder
    func glassEffectCardConditional(cornerRadius: CGFloat = 12, tint: Color? = nil) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffectCard(cornerRadius: cornerRadius, tint: tint)
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}

// MARK: - Glass Effect Container

/// Container for multiple glass elements to enable morphing
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}
