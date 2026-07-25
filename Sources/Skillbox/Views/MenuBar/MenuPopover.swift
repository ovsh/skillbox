import AppKit
import SkillboxKit
import SwiftUI

/// The always-on surface: active count, the five most recently touched skills
/// with live switches, and one button into the library. It floats, so it uses
/// the elevated tone rather than the window's canvas.
struct MenuPopover: View {
    @Environment(SkillLibraryModel.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 14)

            if library.recentSkills.isEmpty {
                Text("Skills you add to your tools appear here.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                VStack(spacing: 1) {
                    ForEach(library.recentSkills) { skill in
                        recentRow(skill)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)

            HStack {
                Button("Open Loadout") {
                    WindowCoordinator.shared.showLibraryWindow()
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut("o", modifiers: .command)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(QuietButtonStyle(role: .destructive))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: 312)
        .background(Theme.elevated)
        .task {
            library.refresh()
        }
    }

    /// Identity on the left, the one number that matters on the right — the
    /// two-second answer this popover exists to give.
    private var header: some View {
        HStack(spacing: 10) {
            AppIconView(size: 22)
            Text("Loadout")
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.live)
                    .frame(width: 6, height: 6)
                Text("\(library.activeCount) of \(library.skills.count) active")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Theme.snap, value: library.activeCount)
            }
        }
    }

    private func recentRow(_ skill: InstalledSkill) -> some View {
        let available = library.isClaudeAvailable(skill)
        let style = StateStyle.of(skill.claudeOverride ?? .on)
        return HStack(spacing: 9) {
            Capsule()
                .fill(available ? style.color : Theme.separator)
                .frame(width: 3, height: style.isLive ? 18 : 8)
                .frame(height: 18)
            Text(skill.name)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            RelativeDateText(date: skill.touchedAt)
            if available {
                LoadoutToggle(isOn: style.isLive) { newValue in
                    library.setActive(skill, newValue)
                }
                .disabled(!library.canToggleClaude(skill))
            }
        }
        .opacity(available && style.isLive ? 1 : 0.68)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(height: 32)
    }
}
