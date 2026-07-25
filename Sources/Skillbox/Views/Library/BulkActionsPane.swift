import SkillboxKit
import SwiftUI

/// Detail-pane replacement when several skills are selected: what's in the
/// selection, and the three bulk actions.
struct BulkActionsPane: View {
    @Environment(SkillLibraryModel.self) private var library
    let skills: [InstalledSkill]
    let clearSelection: () -> Void
    @State private var confirmingDelete = false

    private var toggleable: [InstalledSkill] {
        skills.filter { library.isClaudeAvailable($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(skills.count) skills")
                    .font(Theme.display)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Theme.snap, value: skills.count)
                Spacer(minLength: 8)
                Button("Clear", action: clearSelection)
                    .buttonStyle(QuietButtonStyle())
            }

            Text(summary)
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .padding(.top, 6)

            selectionList
                .padding(.top, 20)

            actions
                .padding(.top, 24)

            Text("Turn Off hides skills from Claude — files stay on disk. Delete moves folders to the Trash (links are removed link-only).")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

            if let error = library.lastError {
                Text(error)
                    .font(Theme.body)
                    .foregroundStyle(Theme.danger)
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: Theme.readingWidth, alignment: .leading)
        .padding(.horizontal, Theme.paneInset)
        .padding(.top, Theme.titleBar)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
        .confirmationDialog(
            "Delete \(skills.count) skills?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                library.deleteSkills(skills)
                clearSelection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    /// The same state language as the list: a colored rail segment, the name,
    /// and the state's own word — so a bulk action is never taken blind.
    private var selectionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(skills.prefix(9)) { skill in
                let available = library.isClaudeAvailable(skill)
                let style = StateStyle.of(skill.claudeOverride ?? .on)
                HStack(spacing: 10) {
                    Capsule()
                        .fill(available ? style.color : Theme.separator)
                        .frame(width: 3, height: style.isLive ? 16 : 8)
                        .frame(height: 16)
                    Text(skill.name)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    Text(available ? style.label : "not in Claude")
                        .font(Theme.meta)
                        .foregroundStyle(available ? style.color : Theme.inkTertiary)
                }
                .opacity(available && style.isLive ? 1 : 0.65)
                .frame(height: 26)
            }
            if skills.count > 9 {
                Text("and \(skills.count - 9) more")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.leading, 13)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            ActionButton(
                title: "Turn On",
                systemImage: "checkmark",
                style: .affirm,
                isEnabled: !toggleable.isEmpty
            ) {
                library.setActiveBulk(toggleable, true)
            }
            ActionButton(
                title: "Turn Off",
                systemImage: "minus",
                style: .neutral,
                isEnabled: !toggleable.isEmpty
            ) {
                library.setActiveBulk(toggleable, false)
            }
            ActionButton(
                title: "Delete…",
                systemImage: "trash",
                style: .destructive
            ) {
                confirmingDelete = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var summary: String {
        let active = skills.count { library.isClaudeAvailable($0) && library.isActiveForClaude($0) }
        let links = skills.count { $0.presences.contains(where: \.isSymlink) }
        var parts = ["\(active) active"]
        if links > 0 { parts.append("\(links) symlinked") }
        let notClaude = skills.count - toggleable.count
        if notClaude > 0 { parts.append("\(notClaude) not in Claude") }
        return parts.joined(separator: " · ")
    }

    private var deleteMessage: String {
        let links = skills.count { $0.presences.contains(where: \.isSymlink) }
        if links == skills.count {
            return "All \(skills.count) are links — only the links are removed; the original files stay where they are. Claude settings are cleared."
        }
        if links > 0 {
            return "Skill folders move to the Trash; \(links) symlinked \(links == 1 ? "skill loses only its link" : "skills lose only their links") — originals stay. Claude settings are cleared."
        }
        return "The skill folders move to the Trash and their Claude settings are cleared. You can restore them from the Trash."
    }
}
