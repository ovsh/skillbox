import LoadoutKit
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
        VStack(alignment: .leading, spacing: 16) {
            Text("\(skills.count) skills selected")
                .font(Theme.title())
                .foregroundStyle(Theme.ink)

            Text(summary)
                .font(Theme.secondary)
                .foregroundStyle(Theme.inkSecondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(skills.prefix(8)) { skill in
                    HStack(spacing: 7) {
                        StatusDot(isOn: library.isClaudeAvailable(skill) && library.isActiveForClaude(skill))
                        Text(skill.name)
                            .font(Theme.body)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                    }
                }
                if skills.count > 8 {
                    Text("and \(skills.count - 8) more…")
                        .font(Theme.meta)
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.leading, 14)
                }
            }

            HStack(spacing: 10) {
                BigActionButton(
                    title: "Turn On",
                    systemImage: "power",
                    style: .affirm,
                    isEnabled: !toggleable.isEmpty
                ) {
                    library.setActiveBulk(toggleable, true)
                }
                BigActionButton(
                    title: "Turn Off",
                    systemImage: "moon",
                    style: .neutral,
                    isEnabled: !toggleable.isEmpty
                ) {
                    library.setActiveBulk(toggleable, false)
                }
                BigActionButton(
                    title: "Delete…",
                    systemImage: "trash",
                    style: .destructive
                ) {
                    confirmingDelete = true
                }
            }
            .frame(maxWidth: 460)
            .padding(.top, 6)

            Text("Turn Off hides skills from Claude; files stay on disk. Delete moves folders to the Trash (links are removed link-only).")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460, alignment: .leading)

            if let error = library.lastError {
                Text(error)
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.danger)
            }

            Spacer()
        }
        .padding(EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            return "All \(skills.count) are links. Only the links are removed; the original files stay where they are. Claude settings are cleared."
        }
        if links > 0 {
            return "Skill folders move to the Trash; \(links) symlinked \(links == 1 ? "skill loses only its link" : "skills lose only their links"); originals stay. Claude settings are cleared."
        }
        return "The skill folders move to the Trash and their Claude settings are cleared. You can restore them from the Trash."
    }
}
