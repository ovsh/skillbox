import AppKit

/// The menu bar glyph: the app icon's mark, redrawn for 18pt monochrome.
///
/// It is drawn rather than loaded so it stays crisp at every scale factor and
/// so macOS can tint it — the menu bar owns the color, and a template image is
/// the only way to let it. That rules out the app icon PNG, whose green would
/// survive into a surface that must be black or white.
///
/// The mark keeps the icon's proportions exactly (derived from
/// `design/brand/loadout-icon.svg`: rail 108 wide, body 780, row 224, gap 144
/// on a 960 block) so the two read as the same object at two sizes. What can't
/// survive is hue — live vs. off is carried by alpha here, which is the one
/// channel a template image keeps.
@MainActor
enum MenuBarIcon {

    /// 18pt is the menu bar's standard glyph box; 15pt of mark inside it
    /// leaves the same optical margin as Apple's own items.
    private static let box: CGFloat = 18
    private static let inset: CGFloat = 1.5

    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: box, height: box), flipped: false) { _ in
            draw()
            return true
        }
        // The menu bar tints template images for light, dark, and the
        // highlighted state; without this the glyph would render as flat black
        // on a dark menu bar.
        image.isTemplate = true
        return image
    }()

    /// The block is 960 units square in the source icon; every dimension below
    /// is that unit scaled to the 15pt drawing area.
    private static func draw() {
        let unit = (box - inset * 2) / 960

        let railWidth = 108 * unit
        let bodyStart = 172 * unit   // 720 - 548: rail origin to body origin
        let bodyWidth = 780 * unit
        let rowHeight = 224 * unit
        let rowStride = 368 * unit   // row height plus the 144 gap

        // Rows are drawn bottom-up because AppKit's origin is bottom-left,
        // while the icon numbers rows from the top. Row 3 (index 2) is the
        // off one, so it is the bottom-most drawn here.
        let rows: [(rail: CGFloat, body: CGFloat)] = [
            (rail: 0.42, body: 0.18),   // off
            (rail: 1.00, body: 0.38),   // live
            (rail: 1.00, body: 0.38),   // live
        ]

        for (index, alpha) in rows.enumerated() {
            let y = inset + CGFloat(index) * rowStride

            fill(
                NSRect(x: inset, y: y, width: railWidth, height: rowHeight),
                radius: railWidth / 2,
                alpha: alpha.rail
            )
            fill(
                NSRect(x: inset + bodyStart, y: y, width: bodyWidth, height: rowHeight),
                radius: 76 * unit,
                alpha: alpha.body
            )
        }
    }

    private static func fill(_ rect: NSRect, radius: CGFloat, alpha: CGFloat) {
        NSColor.black.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
}
