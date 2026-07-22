import AppKit
import SwiftUI

// MARK: - App icon view

/// Renders the bundled app icon at a given size, with a drawn fallback.
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let data = IconGenerator.renderAppIconPNG(), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.22))
        } else {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Theme.accent)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(.white)
                )
        }
    }
}

// MARK: - Chip

/// Tiny rounded metadata chip: tool names, frontmatter facts, states.
struct Chip: View {
    let text: String
    var tint: Color = Theme.inkSecondary

    var body: some View {
        Text(text)
            .font(Theme.meta)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

// MARK: - Status dot

/// 7pt presence dot: accent-green when on, hollow when off.
struct StatusDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Theme.live : .clear)
            .overlay(Circle().strokeBorder(isOn ? .clear : Theme.inkTertiary, lineWidth: 1))
            .frame(width: 7, height: 7)
    }
}

// MARK: - Card

/// Floating surface: card color, hairline border, 12pt radius.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Theme.panel, in: .rect(cornerRadius: Theme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Hover row container

/// Row chrome shared by list rows: hover wash, selection wash, press scale.
struct RowChrome: ViewModifier {
    var isSelected = false
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .frame(minHeight: Theme.rowHeight)
            .background(
                isSelected ? Theme.selection : (isHovered ? Theme.hover : .clear),
                in: .rect(cornerRadius: Theme.radiusSmall)
            )
            .contentShape(.rect(cornerRadius: Theme.radiusSmall))
            .onHover { hovering in
                withAnimation(Theme.fade) { isHovered = hovering }
            }
    }
}

extension View {
    func rowChrome(isSelected: Bool = false) -> some View {
        modifier(RowChrome(isSelected: isSelected))
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let systemImage: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.inkTertiary)
            Text(title)
                .font(Theme.bodyMedium)
                .foregroundStyle(Theme.inkSecondary)
            if let message {
                Text(message)
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.inkTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.gutter)
    }
}

// MARK: - Quiet button style

/// Text button that only reveals chrome on hover — for secondary actions.
/// Hover state lives in an inner View: @State inside a ButtonStyle struct has
/// no view identity and silently never updates.
struct QuietButtonStyle: ButtonStyle {
    var role: Role = .normal

    enum Role { case normal, destructive }

    func makeBody(configuration: Configuration) -> some View {
        QuietButtonBody(role: role, configuration: configuration)
    }

    private struct QuietButtonBody: View {
        let role: Role
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(Theme.secondary)
                .foregroundStyle(
                    role == .destructive && isHovered ? .red : (isHovered ? Theme.ink : Theme.inkSecondary)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHovered ? Theme.hover : .clear, in: .rect(cornerRadius: 5))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.fade, value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Graphite checkbox

/// 14pt square checkbox for multi-select with a generous 28×36 hit target.
/// Fades in on hover so selection is discoverable without ⌘-click knowledge.
/// `isMixed` renders the "some selected" dash for the select-all master.
struct GraphiteCheckbox: View {
    let isOn: Bool
    let isVisible: Bool
    var isMixed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3.5)
                .fill(isOn || isMixed ? Theme.ink : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5)
                        .strokeBorder(isOn || isMixed ? Theme.ink : Theme.inkTertiary, lineWidth: 1)
                )
                .overlay {
                    if isMixed {
                        Image(systemName: "minus")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Theme.canvas)
                    } else if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Theme.canvas)
                    }
                }
                .frame(width: 14, height: 14)
                .frame(width: 28, height: 36)   // hit target, not visual size
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isVisible || isOn || isMixed ? 1 : 0)
        .animation(Theme.fade, value: isVisible || isOn || isMixed)
        .accessibilityLabel(isOn ? "Deselect" : "Select")
    }
}

// MARK: - Big action button

/// Bulk-pane action: 40pt, icon + label, tinted fill with hairline border.
/// The one place buttons get to be big.
struct BigActionButton: View {
    let title: String
    let systemImage: String
    var style: Style = .neutral
    var isEnabled = true
    let action: () -> Void
    @State private var isHovered = false

    enum Style { case affirm, neutral, destructive }

    private var tint: Color {
        switch style {
        case .affirm: Theme.switchOn
        case .neutral: Theme.ink
        case .destructive: Theme.danger
        }
    }

    private var fill: Color {
        switch style {
        case .affirm: Theme.switchOn.opacity(isHovered ? 0.28 : 0.16)
        case .neutral: isHovered ? Theme.hover : Theme.raised
        case .destructive: Theme.danger.opacity(isHovered ? 0.22 : 0.10)
        }
    }

    private var border: Color {
        switch style {
        case .affirm: Theme.switchOn.opacity(0.4)
        case .neutral: Theme.border
        case .destructive: Theme.danger.opacity(0.35)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize()
            }
            .foregroundStyle(style == .neutral ? Theme.ink : tint)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(fill, in: .rect(cornerRadius: Theme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(border, lineWidth: 0.5)
            )
            .contentShape(.rect(cornerRadius: Theme.radius))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering in
            withAnimation(Theme.fade) { isHovered = hovering }
        }
    }
}

// MARK: - Morph toggle (Graphite signature)

/// A status dot that crossfades into a switch while its row is hovered —
/// one-click toggling without a wall of always-on switches.
struct MorphToggle: View {
    let isOn: Bool
    let isHovered: Bool
    let isEnabled: Bool
    let action: (Bool) -> Void

    var body: some View {
        ZStack {
            StatusDot(isOn: isOn)
                .opacity(isHovered ? 0 : 1)
            AccentToggle(isOn: isOn, action: action)
                .opacity(isHovered ? 1 : 0)
                .disabled(!isEnabled)
                .allowsHitTesting(isHovered)
        }
        .frame(width: 34, height: 20)
        .animation(Theme.fade, value: isHovered)
    }
}

// MARK: - Ghost icon button

/// 26pt hairline square icon button for detail-header actions.
struct GhostIconButton: View {
    let systemImage: String
    let help: String
    var isDestructive = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(
                    isHovered ? (isDestructive ? Theme.danger : Theme.ink) : Theme.inkSecondary
                )
                .frame(width: 26, height: 26)
                .background(isHovered ? Theme.hover : .clear, in: .rect(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isHovered && isDestructive ? Theme.danger.opacity(0.4) : Theme.border,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Accent switch

/// Standard switch in graphite — dark ON track, never the accent color.
struct AccentToggle: View {
    let isOn: Bool
    let action: (Bool) -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: action))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .tint(Theme.switchOn)
    }
}

// MARK: - Relative date text

/// "2h ago" / "Mar 4" — compact recency for rows and detail metadata.
struct RelativeDateText: View {
    let date: Date?

    var body: some View {
        Text(Self.string(for: date))
            .font(Theme.meta)
            .foregroundStyle(Theme.inkTertiary)
            .monospacedDigit()
    }

    static func string(for date: Date?) -> String {
        guard let date else { return "—" }
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 86400 * 7 { return "\(Int(interval / 86400))d ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
