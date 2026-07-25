import SwiftUI

// DIRECTION CONTRACT — Loadout in-app design system
//
// THESIS: A Mac-native instrument in the Things / Fantastical school. It refuses
//   the near-black-plus-hairline-grid arrangement every AI utility ships:
//   separation comes from material, tone and space, almost never from borders.
// OWN-WORLD: Warm graphite chassis, one true vibrancy sidebar, opaque content
//   panes. Color is a state code with named roles — live green, partial amber,
//   off neutral — and every state also carries its word, so state survives a
//   grayscale screenshot. Green is the identity, used at window scale. SF at
//   real optical sizes, tabular digits, generous inset.
// STORY: Open it, see at a glance what is live, flip one thing, close it.
// FIRST VIEWPORT: Reserved titlebar band. Vibrant sidebar, system prompts above
//   skills. List rows carried on a state rail. Detail: large title, a sliding
//   four-state control, then the skill's own document.
// FORM: The category canon, played straight — the user's standing exit, taken
//   over roll 5b5c2aa4. Craft bar: Things, Fantastical. Dark is primary.

/// Loadout's design tokens.
enum Theme {

    // MARK: - Ink

    static let ink = Color(light: .init(hex: 0x1E1C19), dark: .init(hex: 0xF2F0EC))
    static let inkSecondary = Color(light: .init(hex: 0x635F58), dark: .init(hex: 0xA8A49C))
    /// Meta and captions. Verified ≥4.5:1 on `canvas` in both appearances.
    static let inkTertiary = Color(light: .init(hex: 0x797469), dark: .init(hex: 0x8A857C))

    // MARK: - Surfaces
    //
    // Four tones, warm graphite. Panes are told apart by tone and material,
    // not by rules; a separator is the exception, never the grammar.

    /// Behind the sidebar's vibrancy — the deepest tone.
    static let chassis = Color(light: .init(hex: 0xEAE8E3), dark: .init(hex: 0x151412))
    /// List and detail ground.
    static let canvas = Color(light: .init(hex: 0xFBFAF8), dark: .init(hex: 0x1C1B19))
    /// Wells sunk into the canvas: search field, editor, code.
    static let raised = Color(light: .init(hex: 0xF1EFEA), dark: .init(hex: 0x252320))
    /// Floating above the canvas: popover, cards, sheets.
    static let elevated = Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x2B2926))

    static let hover = Color(light: .init(hex: 0x000000, alpha: 0.045), dark: .init(hex: 0xFFFFFF, alpha: 0.05))
    /// Selected row. Tinted from `live` rather than gray — the app's own hue.
    static let selection = Color(light: .init(hex: 0x1E6B41, alpha: 0.10), dark: .init(hex: 0x8FE0AC, alpha: 0.10))
    /// Used only where two panes genuinely need a seam. Not decoration.
    static let separator = Color(light: .init(hex: 0x000000, alpha: 0.08), dark: .init(hex: 0xFFFFFF, alpha: 0.07))

    /// Soft, offset shadow for anything that actually floats.
    static let shadow = Color(light: .init(hex: 0x000000, alpha: 0.13), dark: .init(hex: 0x000000, alpha: 0.42))

    // MARK: - State

    /// Live for Claude. The identity hue — rails, switches, selection, focus.
    static let live = Color(light: .init(hex: 0x26794A), dark: .init(hex: 0x57B87A))
    /// In between — not live, not off, not broken. Four uses, no others:
    /// the name-only and manual-only override states, the "Manual-only"
    /// frontmatter fact, unsaved edits, and the disk-conflict notice. All
    /// four mean the same thing to the eye: this isn't settled yet.
    static let partial = Color(light: .init(hex: 0x9A6511), dark: .init(hex: 0xE0A340))
    /// Destructive.
    static let danger = Color(light: .init(hex: 0xA33228), dark: .init(hex: 0xE97F71))

    /// Brighter live, for fills that need to read against the hue itself.
    static let liveVivid = Color(light: .init(hex: 0x2E9159), dark: .init(hex: 0x6ECB8F))
    /// What sits ON a `live` fill. Dark mode's green is light, so white would
    /// land near 2:1 — this is near-black there and white in light mode.
    /// Measured: 8.6:1 dark, 5.3:1 light.
    static let onLive = Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x0D2114))

    // MARK: - Type
    //
    // System SF at real optical sizes. Tracking is negative only where the size
    // earns it; small text is left alone.

    static let display = Font.system(size: 26, weight: .semibold)
    static let heading = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 13.5)
    static let bodyMedium = Font.system(size: 13.5, weight: .medium)
    static let rowTitle = Font.system(size: 13.5, weight: .medium)
    static let rowDetail = Font.system(size: 12)
    static let meta = Font.system(size: 11.5)
    static let metaMedium = Font.system(size: 11.5, weight: .medium)
    /// Uppercase section labels. Small, but weight carries them.
    static let sectionLabel = Font.system(size: 11, weight: .semibold)
    static let control = Font.system(size: 12, weight: .medium)
    static let mono = Font.system(size: 11.5, design: .monospaced)
    static let editor = Font.system(size: 13, design: .monospaced)

    // MARK: - Metrics

    /// Everything is a multiple of 4.
    static let unit: CGFloat = 4

    static let radius: CGFloat = 10
    static let radiusSmall: CGFloat = 7
    static let radiusLarge: CGFloat = 14

    static let rowHeight: CGFloat = 56
    static let sidebarWidth: CGFloat = 240
    static let listWidth: CGFloat = 400
    /// Height reserved across the top of the window for the traffic lights.
    static let titleBar: CGFloat = 40
    /// Detail-pane horizontal inset. Generous on purpose.
    static let paneInset: CGFloat = 32
    /// Widest a column of prose is ever allowed to get, inset included. The
    /// detail pane can be 1200pt wide; the SKILL.md inside it cannot.
    static let readingWidth: CGFloat = 680
    /// Same idea for the editable column. Mono runs narrower per character, so
    /// it earns more room than prose — but never the whole window.
    static let editorWidth: CGFloat = 860

    // MARK: - Motion
    //
    // One authored moment: the four-state control's capsule, which springs
    // between positions and lands wearing that state's color. Everything else
    // is a short, flat fade that stays out of the way.

    /// The signature spring — a little life, never a bounce.
    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.78)
    /// State commits: switches, rails, counts.
    static let snap = Animation.spring(response: 0.26, dampingFraction: 0.9)
    /// Hover and reveal.
    static let fade = Animation.easeOut(duration: 0.13)
}

// MARK: - Adaptive color helpers

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
