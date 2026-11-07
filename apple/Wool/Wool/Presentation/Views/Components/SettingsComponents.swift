import SwiftUI

// MARK: - Toggle Row with Liquid Glass

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 27/255, green: 67/255, blue: 50/255))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
            }
        }
        .tint(Color(red: 86/255, green: 197/255, blue: 150/255))
        .padding(.vertical, 8)
        .glassEffectCardConditional(cornerRadius: 12, tint: Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.3))
    }
}

// MARK: - Duration Selector Row with Liquid Glass

struct DurationSelectorRow: View {
    let title: String
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 27/255, green: 67/255, blue: 50/255))

            HStack(spacing: 16) {
                Button(action: { value = max(range.lowerBound, value - step) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(value > range.lowerBound ? Color(red: 86/255, green: 197/255, blue: 150/255) : Color.secondary.opacity(0.3))
                }
                .disabled(value <= range.lowerBound)
                .glassEffectInteractiveConditional(tint: Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.3), in: .capsule)

                Spacer()

                Text("\(value) \(unit)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 27/255, green: 67/255, blue: 50/255))
                    .frame(minWidth: 80)

                Spacer()

                Button(action: { value = min(range.upperBound, value + step) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(value < range.upperBound ? Color(red: 86/255, green: 197/255, blue: 150/255) : Color.secondary.opacity(0.3))
                }
                .disabled(value >= range.upperBound)
                .glassEffectInteractiveConditional(tint: Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.3), in: .capsule)
            }
        }
        .padding(.vertical, 8)
        .glassEffectCardConditional(cornerRadius: 12, tint: Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.3))
    }
}

// MARK: - Section Header with Liquid Glass

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color.secondary.opacity(0.6))
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffectCardConditional(cornerRadius: 8, tint: Color(red: 168/255, green: 230/255, blue: 207/255).opacity(0.2))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        SectionHeader(title: "Timer Settings")

        DurationSelectorRow(
            title: "Focus Duration",
            range: 15...60,
            step: 5,
            unit: "min",
            value: .constant(25)
        )

        ToggleRow(
            title: "Auto-start next session",
            subtitle: "Automatically begin the next timer when one completes",
            isOn: .constant(true)
        )

        ToggleRow(
            title: "Sound & Haptics",
            subtitle: nil,
            isOn: .constant(false)
        )
    }
    .padding()
    .background(Color(red: 247/255, green: 253/255, blue: 251/255))
}
