import SwiftUI

/// Skillbox design language — "Graphite".
/// An instrument next to Codex: near-black neutrals, hairlines, monochrome
/// iconography. Color appears only where state lives — dim green for active,
/// one rationed terracotta accent. No system blue anywhere.
enum Theme {
    // MARK: Ink (text hierarchy)

    static let ink = Color(light: .init(hex: 0x1D1D20), dark: .init(hex: 0xE9EAEC))
    static let inkSecondary = Color(light: .init(hex: 0x6B6E76), dark: .init(hex: 0x9A9DA4))
    static let inkTertiary = Color(light: .init(hex: 0xA2A5AD), dark: .init(hex: 0x5C5F66))

    // MARK: Surfaces

    /// Window canvas.
    static let canvas = Color(light: .init(hex: 0xF7F7F8), dark: .init(hex: 0x101012))
    /// Sidebar / secondary panel.
    static let panel = Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x151518))
    /// Raised wells: search field, editor surface, code.
    static let raised = Color(light: .init(hex: 0xF1F1F3), dark: .init(hex: 0x1B1B1F))
    /// Hover wash.
    static let hover = Color(light: .init(hex: 0x000000, alpha: 0.04), dark: .init(hex: 0xFFFFFF, alpha: 0.05))
    /// Selection wash — soft neutral, never blue.
    static let selection = Color(light: .init(hex: 0x000000, alpha: 0.05), dark: .init(hex: 0xFFFFFF, alpha: 0.06))
    /// Fill for the selected segment of the state pill.
    static let segmentFill = Color(light: .init(hex: 0x000000, alpha: 0.09), dark: .init(hex: 0xFFFFFF, alpha: 0.13))
    /// Hairline borders.
    static let border = Color(light: .init(hex: 0x000000, alpha: 0.08), dark: .init(hex: 0xFFFFFF, alpha: 0.07))

    // MARK: State color

    /// Active-for-Claude state. The only green in the app.
    static let live = Color(light: .init(hex: 0x3E8B55), dark: .init(hex: 0x58A56E))
    /// The one accent — terracotta. Off segment, dirty text, selection tint.
    static let accent = Color(light: .init(hex: 0xC2593A), dark: .init(hex: 0xD4795A))
    /// Switch ON track — muted green, quieter than the status dot. Never accent.
    static let switchOn = Color(light: .init(hex: 0x47804F), dark: .init(hex: 0x4C7F5F))
    /// Destructive hover tint.
    static let danger = Color(light: .init(hex: 0xC94F42), dark: .init(hex: 0xE5695A))

    // MARK: Type

    static func title(_ size: CGFloat = 21) -> Font { .system(size: size, weight: .semibold) }
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let secondary = Font.system(size: 11.5)
    static let meta = Font.system(size: 10.5)
    static let label = Font.system(size: 10, weight: .bold)     // small-caps section labels
    static let segment = Font.system(size: 10.5, weight: .semibold)
    static let mono = Font.system(size: 11, design: .monospaced)
    static let editor = Font.system(size: 12.5, design: .monospaced)

    // MARK: Metrics

    static let radius: CGFloat = 10
    static let radiusSmall: CGFloat = 8
    static let rowHeight: CGFloat = 44
    static let gutter: CGFloat = 20
    static let sidebarWidth: CGFloat = 218
    static let listWidth: CGFloat = 356

    // MARK: Motion

    /// The one spring for state changes — snappy, never bouncy.
    static let spring = Animation.spring(response: 0.28, dampingFraction: 0.86)
    /// Quick fades for hover/morph (the dot→switch crossfade).
    static let fade = Animation.easeOut(duration: 0.12)
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
            .tracking(0.9)
            .foregroundStyle(Theme.inkTertiary)
    }
}
