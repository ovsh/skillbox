import LoadoutKit
import SwiftUI

/// The middle column: search + the skill rows for the focused sidebar slice.
struct SkillList: View {
    @Environment(SkillLibraryModel.self) private var library
    let selection: SidebarSelection
    @Binding var selectedSkillIDs: Set<InstalledSkill.ID>
    @Binding var anchorSkillID: InstalledSkill.ID?
    @FocusState private var searchFocused: Bool

    private var visibleSkills: [InstalledSkill] {
        let base = library.filteredSkills
        guard case .tool(let targetID) = selection else { return base }
        return base.filter { skill in
            skill.presences.contains { $0.targetID == targetID }
        }
    }

    var body: some View {
        @Bindable var library = library

        VStack(spacing: 0) {
            SearchField(text: $library.searchText, isFocused: $searchFocused)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            selectAllHeader

            if library.skills.isEmpty && !library.isRefreshing {
                EmptyState(
                    systemImage: "shippingbox",
                    title: "No skills yet",
                    message: "Skills you add to ~/.claude/skills or ~/.agents/skills appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(visibleSkills) { skill in
                            SkillRow(
                                skill: skill,
                                isSelected: selectedSkillIDs.contains(skill.id),
                                multiSelectActive: selectedSkillIDs.count > 1,
                                select: { handleClick(on: skill) },
                                toggleChecked: { toggleMembership(of: skill) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(Theme.canvas)
    }

    /// Checkbox path into the same selection set: toggling never collapses
    /// what's already selected.
    private func toggleMembership(of skill: InstalledSkill) {
        if selectedSkillIDs.contains(skill.id) {
            selectedSkillIDs.remove(skill.id)
        } else {
            selectedSkillIDs.insert(skill.id)
            anchorSkillID = skill.id
        }
    }

    /// Select-all master row: operates on exactly the VISIBLE rows, so an
    /// active search or tool filter scopes the selection with it.
    private var selectAllHeader: some View {
        let visibleIDs = Set(visibleSkills.map(\.id))
        let selectedVisible = visibleIDs.intersection(selectedSkillIDs)
        let allSelected = !visibleIDs.isEmpty && selectedVisible.count == visibleIDs.count

        return HStack(spacing: 0) {
            GraphiteCheckbox(
                isOn: allSelected,
                isVisible: true,
                isMixed: !allSelected && !selectedVisible.isEmpty,
                action: toggleSelectAll
            )
            Button(action: toggleSelectAll) {
                Text("Select all")
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            if !selectedVisible.isEmpty {
                Text("\(selectedVisible.count) of \(visibleIDs.count)")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 28)
    }

    private func toggleSelectAll() {
        let visibleIDs = Set(visibleSkills.map(\.id))
        if visibleIDs.isSubset(of: selectedSkillIDs) {
            selectedSkillIDs.subtract(visibleIDs)
        } else {
            selectedSkillIDs.formUnion(visibleIDs)
            anchorSkillID = visibleSkills.first?.id
        }
    }

    /// Finder-style selection: plain click focuses one skill, ⌘-click toggles
    /// membership, ⇧-click extends from the anchor through the clicked row.
    private func handleClick(on skill: InstalledSkill) {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        if modifiers.contains(.command) {
            if selectedSkillIDs.contains(skill.id) {
                selectedSkillIDs.remove(skill.id)
            } else {
                selectedSkillIDs.insert(skill.id)
                anchorSkillID = skill.id
            }
        } else if modifiers.contains(.shift),
                  let anchor = anchorSkillID,
                  let from = visibleSkills.firstIndex(where: { $0.id == anchor }),
                  let to = visibleSkills.firstIndex(where: { $0.id == skill.id }) {
            let range = min(from, to)...max(from, to)
            selectedSkillIDs.formUnion(visibleSkills[range].map(\.id))
        } else {
            selectedSkillIDs = [skill.id]
            anchorSkillID = skill.id
        }
    }
}

// MARK: - Search field

private struct SearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)
            TextField("Search skills", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .focused(isFocused)
            if text.isEmpty {
                Text("⌘K")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Theme.border, lineWidth: 0.5)
                    )
            } else {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(Theme.raised, in: .rect(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .strokeBorder(isFocused.wrappedValue ? Theme.accent.opacity(0.6) : Theme.border, lineWidth: 0.5)
        )
        .background(
            // Invisible ⌘K target that focuses the field.
            Button("") { isFocused.wrappedValue = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        )
    }
}

// MARK: - Row

struct SkillRow: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill
    let isSelected: Bool
    let multiSelectActive: Bool
    let select: () -> Void
    let toggleChecked: () -> Void
    @State private var isHovered = false

    // Interactive controls are SIBLINGS of the select button — never nested
    // inside it, so a checkbox click can never also dispatch row selection
    // and the detail/bulk panes never churn on membership changes.
    var body: some View {
        HStack(spacing: 8) {
            GraphiteCheckbox(
                isOn: isSelected,
                isVisible: isHovered || multiSelectActive,
                action: toggleChecked
            )

            if library.isClaudeAvailable(skill) {
                MorphToggle(
                    isOn: library.isActiveForClaude(skill),
                    isHovered: isHovered,
                    isEnabled: library.canToggleClaude(skill)
                ) { newValue in
                    library.setActive(skill, newValue)
                }
            } else {
                // Not loadable by Claude: a hollow dot that never morphs.
                StatusDot(isOn: false)
                    .frame(width: 34, height: 20)
                    .help("No live copy in ~/.claude/skills")
                    .opacity(0.5)
            }

            Button(action: select) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(skill.name)
                            .font(Theme.bodyMedium)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(skill.description.isEmpty ? skill.dirName : skill.description)
                            .font(Theme.secondary)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    RelativeDateText(date: skill.touchedAt)
                }
                // Fill the row's full 44pt height so clicks in the row's
                // vertical padding still select.
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .opacity(rowOpacity)
        .animation(Theme.fade, value: rowOpacity)
        .padding(.horizontal, 10)
        .frame(height: Theme.rowHeight)
        .background(
            isSelected ? Theme.selection : (isHovered ? Theme.hover : .clear),
            in: .rect(cornerRadius: Theme.radiusSmall)
        )
        .onHover { hovering in
            withAnimation(Theme.fade) { isHovered = hovering }
        }
    }

    private var rowOpacity: Double {
        guard library.isClaudeAvailable(skill) else { return 1 }
        return library.isActiveForClaude(skill) ? 1 : 0.5
    }
}
