import AppKit
import LoadoutKit
import SwiftUI

// MARK: - Skill state presentation
//
// One place decides how a state looks and what it is called. Every surface —
// row rail, segmented control, popover, bulk pane — reads from here, so the
// four states can never drift apart between panes.

/// How a `SkillOverrideState` presents itself.
struct StateStyle {
    let label: String
    let shortLabel: String
    let color: Color
    let symbol: String
    /// Rail and switch read as "on" for these.
    let isLive: Bool

    static func of(_ state: SkillOverrideState) -> StateStyle {
        switch state {
        case .on:
            StateStyle(label: "On", shortLabel: "On", color: Theme.live,
                       symbol: "checkmark", isLive: true)
        case .nameOnly:
            StateStyle(label: "Name only", shortLabel: "Name", color: Theme.partial,
                       symbol: "eye", isLive: false)
        case .userInvocableOnly:
            StateStyle(label: "Manual only", shortLabel: "Manual", color: Theme.partial,
                       symbol: "hand.point.up.left", isLive: false)
        case .off:
            StateStyle(label: "Off", shortLabel: "Off", color: Theme.inkTertiary,
                       symbol: "minus", isLive: false)
        }
    }
}

// MARK: - State rail

/// The leading edge of a list row: a 3pt vertical bar in the state's color,
/// full-height when live, short and hollow when not, absent when Claude can't
/// load the skill at all. Position, height and color all encode state, so it
/// survives grayscale — and it reads from six feet away.
struct StateRail: View {
    let state: SkillOverrideState?
    /// nil state + this false means "no live copy in ~/.claude/skills".
    let isAvailable: Bool

    private var style: StateStyle { StateStyle.of(state ?? .on) }

    var body: some View {
        Capsule()
            .fill(isAvailable ? style.color : .clear)
            .opacity(isAvailable ? (style.isLive ? 1 : 0.85) : 0)
            .frame(width: 3, height: railHeight)
            .frame(height: Theme.rowHeight - 12, alignment: .center)
    }

    private var railHeight: CGFloat {
        guard isAvailable else { return 0 }
        switch state ?? .on {
        case .on: return Theme.rowHeight - 16
        case .nameOnly, .userInvocableOnly: return 18
        case .off: return 0
        }
    }
}

// MARK: - App icon

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
                .fill(Theme.live)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(.white)
                )
        }
    }
}

// MARK: - Vibrancy

/// Behind-window blur — the real thing, not a translucent fill pretending.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Section label

/// Uppercase section label. Weight carries it, not tracking gymnastics.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.sectionLabel)
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(Theme.inkTertiary)
    }
}

// MARK: - Chip

/// Small metadata token: tool names, link status, frontmatter facts.
struct Chip: View {
    let text: String
    var tint: Color = Theme.inkSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.13), in: Capsule())
    }
}

// MARK: - Card

/// A surface that genuinely floats: elevated tone, real offset shadow.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Theme.elevated, in: .rect(cornerRadius: Theme.radius))
            .shadow(color: Theme.shadow, radius: 8, y: 2)
    }
}

// MARK: - Empty state

struct EmptyState: View {
    var systemImage: String? = nil
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.bottom, 2)
            }
            Text(title)
                .font(Theme.heading)
                .foregroundStyle(Theme.inkSecondary)
            if let message {
                Text(message)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Four-state control (the signature)

/// On / Name / Manual / Off as one segmented control with a capsule that
/// springs between positions and lands wearing that state's color. The one
/// authored motion moment in the app.
struct StateControl: View {
    let state: SkillOverrideState
    var isEnabled = true
    let select: (SkillOverrideState) -> Void

    @Namespace private var capsule
    @State private var hovered: SkillOverrideState?

    private static let order: [SkillOverrideState] = [.on, .nameOnly, .userInvocableOnly, .off]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.order, id: \.self) { candidate in
                segment(candidate)
            }
        }
        .padding(2)
        .background(Theme.raised, in: .rect(cornerRadius: Theme.radiusSmall + 2))
        .opacity(isEnabled ? 1 : 0.45)
        .animation(Theme.spring, value: state)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Claude state")
    }

    private func segment(_ candidate: SkillOverrideState) -> some View {
        let style = StateStyle.of(candidate)
        let isCurrent = candidate == state
        return Button {
            select(candidate)
        } label: {
            Text(style.shortLabel)
                .font(Theme.control)
                .fixedSize()
                .foregroundStyle(foreground(candidate, isCurrent: isCurrent))
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .fill(fill(candidate))
                            .matchedGeometryEffect(id: "capsule", in: capsule)
                    } else if hovered == candidate {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .fill(Theme.hover)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(Theme.fade) { hovered = hovering ? candidate : nil }
        }
        .help(StateStyle.of(candidate).label)
    }

    /// The selected segment carries its state's hue as a wash, not a slab:
    /// the label stays ink so contrast never depends on the fill.
    private func fill(_ candidate: SkillOverrideState) -> Color {
        switch candidate {
        case .on: Theme.live.opacity(0.22)
        case .nameOnly, .userInvocableOnly: Theme.partial.opacity(0.22)
        case .off: Theme.inkSecondary.opacity(0.16)
        }
    }

    private func foreground(_ candidate: SkillOverrideState, isCurrent: Bool) -> Color {
        guard isCurrent else { return hovered == candidate ? Theme.ink : Theme.inkTertiary }
        switch candidate {
        case .on: return Theme.live
        case .nameOnly, .userInvocableOnly: return Theme.partial
        case .off: return Theme.ink
        }
    }
}

// MARK: - Switch

/// The plain on/off switch, tinted to the app's own hue.
struct LoadoutToggle: View {
    let isOn: Bool
    /// MainActor-isolated so the binding's setter is well-formed under strict
    /// concurrency — every caller mutates a MainActor model anyway.
    let action: @MainActor (Bool) -> Void

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { action($0) }))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .tint(Theme.live)
    }
}

// MARK: - Checkbox

/// Multi-select checkbox: 15pt square, 30×40 hit target, fades in on hover so
/// selection is discoverable without knowing ⌘-click.
struct SelectionCheckbox: View {
    let isOn: Bool
    let isVisible: Bool
    var isMixed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isOn || isMixed ? Theme.live : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isOn || isMixed ? .clear : Theme.inkTertiary, lineWidth: 1.2)
                )
                .overlay {
                    if isMixed || isOn {
                        Image(systemName: isMixed ? "minus" : "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Theme.onLive)
                    }
                }
                .frame(width: 15, height: 15)
                .frame(width: 30, height: 40)   // hit target, not visual size
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isVisible || isOn || isMixed ? 1 : 0)
        .animation(Theme.fade, value: isVisible || isOn || isMixed)
        .accessibilityLabel(isOn ? "Deselect" : "Select")
    }
}

// MARK: - Buttons

/// Text button that only takes chrome on hover — secondary actions.
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
                .font(Theme.metaMedium)
                .foregroundStyle(
                    role == .destructive && isHovered
                        ? Theme.danger
                        : (isHovered ? Theme.ink : Theme.inkSecondary)
                )
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isHovered ? Theme.hover : .clear, in: .rect(cornerRadius: 6))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.fade, value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

/// The bulk pane's actions: 38pt, icon + label. Filled for the affirmative
/// one, quiet for the rest — a screen with three equal buttons has no primary.
/// `isWide: false` and no icon give the same button inline, at label width.
struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var style: Style = .neutral
    var isEnabled = true
    var isWide = true
    let action: () -> Void
    @State private var isHovered = false

    enum Style { case affirm, neutral, destructive }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize()
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: isWide ? .infinity : nil)
            .padding(.horizontal, isWide ? 0 : 13)
            .frame(height: isWide ? 38 : 28)
            .background(background, in: .rect(cornerRadius: Theme.radiusSmall + 1))
            .contentShape(.rect(cornerRadius: Theme.radiusSmall + 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering in
            withAnimation(Theme.fade) { isHovered = hovering }
        }
    }

    private var foreground: Color {
        switch style {
        case .affirm: Theme.onLive
        case .neutral: Theme.ink
        case .destructive: Theme.danger
        }
    }

    private var background: Color {
        switch style {
        case .affirm: isHovered ? Theme.liveVivid : Theme.live
        case .neutral: isHovered ? Theme.elevated : Theme.raised
        case .destructive: Theme.danger.opacity(isHovered ? 0.22 : 0.13)
        }
    }
}

/// 28pt icon button for header actions. Idle icons carry no chrome.
struct GhostIconButton: View {
    let systemImage: String
    let help: String
    var isDestructive = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(
                    isHovered ? (isDestructive ? Theme.danger : Theme.ink) : Theme.inkSecondary
                )
                .frame(width: 28, height: 28)
                .background(
                    isHovered ? (isDestructive ? Theme.danger.opacity(0.14) : Theme.hover) : .clear,
                    in: .rect(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.fade) { isHovered = hovering }
        }
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Relative date

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
