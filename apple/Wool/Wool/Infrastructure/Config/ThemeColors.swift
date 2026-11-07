import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

extension Color {
    // Primary Green Scheme
    static let themePrimary = Color(hex: "#A8E6CF")
    static let themeSecondary = Color(hex: "#FFD7A8") // Orange secondary
    static let themeAccent = Color(hex: "#56C596")

    // Dedicated action colors keep button labels readable in both appearances.
    // The existing pastel themePrimary remains useful for decorative surfaces.
    static let themeButtonBackground = Color(hex: "#176B46")
    static let themeButtonForeground = Color.white

    // Focus timer phase colors: intentionally saturated for quick recognition.
    static let focusWork = Color(hex: "#4F7CFF")
    static let focusBreak = Color(hex: "#FFB547")
    static let focusLongBreak = Color(hex: "#A66CFF")
    static let themeTextPrimary: Color = {
        #if canImport(UIKit)
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.659, green: 0.902, blue: 0.812, alpha: 1)
                : UIColor(red: 0.106, green: 0.263, blue: 0.196, alpha: 1)
        })
        #else
        Color(nsColor: NSColor(name: nil, dynamicProvider: { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.659, green: 0.902, blue: 0.812, alpha: 1)
                : NSColor(red: 0.106, green: 0.263, blue: 0.196, alpha: 1)
        }))
        #endif
    }()

    static let themeBackground: Color = {
        #if canImport(UIKit)
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.053, green: 0.098, blue: 0.078, alpha: 1)
                : UIColor(red: 0.969, green: 0.992, blue: 0.980, alpha: 1)
        })
        #else
        Color(nsColor: NSColor(name: nil, dynamicProvider: { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.053, green: 0.098, blue: 0.078, alpha: 1)
                : NSColor(red: 0.969, green: 0.992, blue: 0.980, alpha: 1)
        }))
        #endif
    }()

    // Alternative Warm Orange Scheme (can be toggled)
    static let themeOrangePrimary = Color(hex: "#FFD7A8")
    static let themeOrangeAccent = Color(hex: "#FF9F1C")
    static let themeOrangeDeep = Color(hex: "#D2691E")
    static let themeOrangeBackground = Color(hex: "#FFF8ED")

    // Neutral colors
    static let themeTextSecondary = Color.secondary
    static let themeBorder = Color.gray.opacity(0.2)
    static let themeCardBackground: Color = {
        #if canImport(UIKit)
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.20, blue: 0.16, alpha: 0.85)
                : UIColor(white: 1.0, alpha: 0.8)
        })
        #else
        Color(nsColor: NSColor(name: nil, dynamicProvider: { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.12, green: 0.20, blue: 0.16, alpha: 0.85)
                : NSColor(white: 1.0, alpha: 0.8)
        }))
        #endif
    }()

    // Semantic colors
    static let themeSuccess = Color.green.opacity(0.8)
    static let themeWarning = Color.orange.opacity(0.8)
    static let themeError = Color.red.opacity(0.8)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
