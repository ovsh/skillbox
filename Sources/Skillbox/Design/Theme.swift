import SwiftUI

/// Skillbox design language — "quiet desk".
/// Warm paper neutrals, one terracotta accent, hairline borders, soft motion.
/// Everything adapts to light/dark; nothing is pure white or pure black.
enum Theme {
    // MARK: Ink (text hierarchy)

    /// Primary text. Warm near-black / warm off-white.
    static let ink = Color(light: .init(hex: 0x2A2622), dark: .init(hex: 0xEDE9E3))
    /// Secondary text.
    static let inkSecondary = Color(light: .init(hex: 0x6E675E), dark: .init(hex: 0xA39C91))
    /// Tertiary / metadata text.
    static let inkTertiary = Color(light: .init(hex: 0x9B948A), dark: .init(hex: 0x736D64))

    // MARK: Surfaces

    /// Window canvas — warm paper.
    static let canvas = Color(light: .init(hex: 0xFAF9F6), dark: .init(hex: 0x201E1B))
    /// Raised card / detail pane surface.
    static let card = Color(light: .init(hex: 0xFFFFFE), dark: .init(hex: 0x2A2723))
    /// Sunken well (editors, code).
    static let well = Color(light: .init(hex: 0xF3F1EC), dark: .init(hex: 0x191714))
    /// Hover wash over rows.
    static let hover = Color(light: .init(hex: 0x54432E, alpha: 0.05), dark: .init(hex: 0xEDE9E3, alpha: 0.05))
    /// Selected row wash.
    static let selection = Color(light: .init(hex: 0xC2593A, alpha: 0.10), dark: .init(hex: 0xD9714F, alpha: 0.16))
    /// Hairline borders.
    static let border = Color(light: .init(hex: 0x54432E, alpha: 0.10), dark: .init(hex: 0xEDE9E3, alpha: 0.09))

    // MARK: Accent

    /// The one accent — terracotta. Active switches, selection tint, links.
    static let accent = Color(light: .init(hex: 0xC2593A), dark: .init(hex: 0xD9714F))
    static let accentDeep = Color(light: .init(hex: 0xA84A2F), dark: .init(hex: 0xC2593A))
    /// Positive state (active badge).
    static let active = Color(light: .init(hex: 0x4A7C59), dark: .init(hex: 0x6FA97F))

    // MARK: Type

    static func title(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .semibold) }
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let secondary = Font.system(size: 11)
    static let meta = Font.system(size: 10.5)
    static let label = Font.system(size: 10, weight: .semibold)   // small-caps section labels
    static let mono = Font.system(size: 11, design: .monospaced)
    static let editor = Font.system(size: 12.5, design: .monospaced)

    // MARK: Metrics

    static let radius: CGFloat = 12       // cards, panes
    static let radiusSmall: CGFloat = 7   // rows, chips
    static let rowHeight: CGFloat = 44
    static let gutter: CGFloat = 20

    // MARK: Motion

    /// The one spring for state changes — snappy, never bouncy.
    static let spring = Animation.spring(response: 0.28, dampingFraction: 0.86)
    /// Quick fades for hover/appear.
    static let fade = Animation.easeOut(duration: 0.15)
}

// MARK: - Adaptive color helper

extension Color {
    /// Light/dark adaptive color from explicit NSColor components.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Section label

/// Small-caps tracking label used above sidebar and detail sections.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.label)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.inkTertiary)
    }
}
