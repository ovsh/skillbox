import AppKit
import SwiftUI

// MARK: - Brand Colors

enum Brand {
    static let indigo = Color(red: 0.29, green: 0.29, blue: 0.96)       // #4A4AF4
    static let indigoDim = Color(red: 0.18, green: 0.18, blue: 0.76)    // #2F2FC1
    static let indigoMid = Color(red: 0.66, green: 0.66, blue: 0.99)    // #A8A9FC
    static let indigoLight = Color(red: 0.90, green: 0.90, blue: 0.99)  // #E6E6FC
    static let darkBg = Color(red: 0.051, green: 0.051, blue: 0.086)     // #0D0D16
    static let darkBgAlt = Color(red: 0.086, green: 0.086, blue: 0.165)  // #16162A
}

// MARK: - Surface System

enum Surface {
    /// Main content area — deep royal indigo
    static let content = Color(red: 0.067, green: 0.067, blue: 0.098)   // #111119
    /// Header/toolbar bar — subtle lift over content
    static let header = Color(red: 0.078, green: 0.078, blue: 0.125)    // #141420
    /// Cards/elevated elements — cool indigo tint
    static let card = Color(red: 0.18, green: 0.18, blue: 0.30).opacity(0.12)
}

// MARK: - Spacing Scale

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let hero: CGFloat = 48
}

// MARK: - Corner Radius

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
}

// MARK: - Visual Effect Bridge

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - App Icon View

/// Renders the bundled app icon at a given size, with a rounded-rect fallback.
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let data = IconGenerator.renderAppIconPNG(), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(LinearGradient(
                    colors: [Brand.indigo, Brand.indigoDim],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(.white)
                )
        }
    }
}
