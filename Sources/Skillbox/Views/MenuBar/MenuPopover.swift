import AppKit
import SkillboxKit
import SwiftUI

/// The always-on surface: active count, the five most recently touched skills
/// with live switches, and one button into the library.
struct MenuPopover: View {
    @Environment(SkillLibraryModel.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)

            if library.recentSkills.isEmpty {
                Text("Skills you add to your tools appear here.")
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 2) {
                    ForEach(library.recentSkills) { skill in
                        recentRow(skill)
                    }
                }
                .padding(.bottom, 12)
            }

            Divider()
                .padding(.bottom, 8)

            HStack {
                Button("Open Skillbox") {
                    WindowCoordinator.shared.showLibraryWindow()
                }
                .buttonStyle(QuietButtonStyle())

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(QuietButtonStyle(role: .destructive))
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Theme.canvas)
        .task {
            library.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppIconView(size: 20)
            Text("Skillbox")
                .font(Theme.bodyMedium)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("\(library.activeCount) of \(library.skills.count) active")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func recentRow(_ skill: InstalledSkill) -> some View {
        HStack(spacing: 8) {
            StatusDot(isOn: library.isClaudeAvailable(skill) && library.isActiveForClaude(skill))
            Text(skill.name)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 6)
            RelativeDateText(date: skill.touchedAt)
            if library.isClaudeAvailable(skill) {
                AccentToggle(isOn: library.isActiveForClaude(skill)) { newValue in
                    library.setActive(skill, newValue)
                }
                .disabled(!library.canToggleClaude(skill))
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
    }
}
