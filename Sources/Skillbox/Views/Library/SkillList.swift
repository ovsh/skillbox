import SkillboxKit
import SwiftUI

/// The middle column: searchable list of skills for the focused section.
struct SkillList: View {
    @Environment(SkillLibraryModel.self) private var library
    let section: LibrarySection
    @Binding var selectedSkillID: InstalledSkill.ID?

    private var visibleSkills: [InstalledSkill] {
        let base = library.filteredSkills
        guard case .tool(let targetID) = section else { return base }
        return base.filter { skill in
            skill.presences.contains { $0.targetID == targetID }
        }
    }

    var body: some View {
        @Bindable var library = library

        Group {
            if library.skills.isEmpty && !library.isRefreshing {
                EmptyState(
                    systemImage: "shippingbox",
                    title: "No skills yet",
                    message: "Skills you add to ~/.claude/skills or ~/.agents/skills appear here."
                )
            } else {
                List(selection: $selectedSkillID) {
                    ForEach(visibleSkills) { skill in
                        SkillRow(skill: skill, isSelected: selectedSkillID == skill.id)
                            .tag(skill.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(Theme.spring, value: visibleSkills.map(\.id))
            }
        }
        .background(Theme.canvas)
        .searchable(text: $library.searchText, placement: .toolbar, prompt: "Search skills")
        .navigationTitle(navigationTitle)
    }

    private var navigationTitle: String {
        switch section {
        case .allSkills: return "Skills"
        case .tool(let id): return library.toolFilters.first { $0.id == id }?.shortName ?? "Skills"
        case .prompts: return "Prompts"
        }
    }
}

// MARK: - Row

struct SkillRow: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill
    var isSelected = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(Theme.bodyMedium)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if skill.claudeOverride == .nameOnly || skill.claudeOverride == .userInvocableOnly {
                        Chip(text: "Partial", tint: Theme.accent)
                    }
                    if skill.presences.contains(where: \.isShelved) {
                        Chip(text: "Shelved elsewhere", tint: Theme.inkSecondary)
                    }
                }
                Text(skill.description.isEmpty ? skill.dirName : skill.description)
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            RelativeDateText(date: skill.touchedAt)

            AccentToggle(isOn: library.isActiveForClaude(skill)) { newValue in
                library.setActive(skill, newValue)
            }
            .disabled(library.mutatingSkillIDs.contains(skill.id))
            .help("Active for Claude Code & Agent SDK")
        }
        .rowChrome(isSelected: isSelected)
        .opacity(library.isActiveForClaude(skill) ? 1 : 0.55)
        .animation(Theme.spring, value: library.isActiveForClaude(skill))
    }
}
