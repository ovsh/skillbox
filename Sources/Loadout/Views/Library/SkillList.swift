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
            // Traffic-light air, then the search well sits in the title band.
            Color.clear.frame(height: Theme.titleBar - 30)

            SearchField(text: $library.searchText, isFocused: $searchFocused)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            selectAllHeader

            if library.skills.isEmpty && !library.isRefreshing {
                EmptyState(
                    systemImage: "square.stack.3d.up.slash",
                    title: "No skills yet",
                    message: "Skills you add to ~/.claude/skills or ~/.agents/skills show up here."
                )
            } else if visibleSkills.isEmpty {
                EmptyState(
                    title: "No matches",
                    message: "Nothing here matches “\(library.searchText)”."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
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
                    .padding(.bottom, 14)
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
            SelectionCheckbox(
                isOn: allSelected,
                isVisible: true,
                isMixed: !allSelected && !selectedVisible.isEmpty,
                action: toggleSelectAll
            )
            Button(action: toggleSelectAll) {
                Text("Select all")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Spacer()

            if !selectedVisible.isEmpty {
                Text("\(selectedVisible.count) selected")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.live)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .animation(Theme.snap, value: selectedVisible.count)
        .padding(.leading, 12)
        .padding(.trailing, 22)
        .frame(height: 30)
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

/// A well sunk into the canvas, not a raised chip on top of it.
private struct SearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFocused.wrappedValue ? Theme.live : Theme.inkTertiary)
            TextField("Search skills", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .focused(isFocused)
            if text.isEmpty {
                Text("⌘K")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkTertiary)
            } else {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Theme.raised, in: .rect(cornerRadius: Theme.radiusSmall))
        .overlay {
            if isFocused.wrappedValue {
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .strokeBorder(Theme.live.opacity(0.55), lineWidth: 1.5)
            }
        }
        .animation(Theme.fade, value: isFocused.wrappedValue)
        .background(
            // Invisible ⌘K target that focuses the field.
            Button("") { isFocused.wrappedValue = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        )
    }
}

// MARK: - Row

/// One skill. The state rail carries the leading edge; the name and its state
/// word carry the rest. Everything below "live" also dims, so a glance down
/// the column reads as light and shade before it reads as words.
struct SkillRow: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill
    let isSelected: Bool
    let multiSelectActive: Bool
    let select: () -> Void
    let toggleChecked: () -> Void
    @State private var isHovered = false

    private var isAvailable: Bool { library.isClaudeAvailable(skill) }
    private var state: SkillOverrideState { skill.claudeOverride ?? .on }
    private var style: StateStyle { StateStyle.of(state) }

    // Interactive controls are SIBLINGS of the select button — never nested
    // inside it, so a checkbox click can never also dispatch row selection
    // and the detail/bulk panes never churn on membership changes.
    var body: some View {
        HStack(spacing: 0) {
            StateRail(state: isAvailable ? state : nil, isAvailable: isAvailable)
                .padding(.trailing, 9)
                .animation(Theme.snap, value: state)

            SelectionCheckbox(
                isOn: isSelected,
                isVisible: isHovered || multiSelectActive,
                action: toggleChecked
            )

            Button(action: select) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skill.name)
                            .font(Theme.rowTitle)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(skill.description.isEmpty ? skill.dirName : skill.description)
                            .font(Theme.rowDetail)
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                    }
                    // The text column absorbs the slack itself. A Spacer here
                    // would bargain width away from it and truncate names with
                    // the row half empty.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    trailing
                        .fixedSize()
                }
                // Fill the row's full height so clicks in the vertical padding
                // still select.
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .opacity(isAvailable && !style.isLive ? 0.62 : 1)
        .animation(Theme.fade, value: style.isLive)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(height: Theme.rowHeight)
        .background(
            isSelected ? Theme.selection : (isHovered ? Theme.hover : .clear),
            in: .rect(cornerRadius: Theme.radius)
        )
        .onHover { hovering in
            withAnimation(Theme.fade) { isHovered = hovering }
        }
    }

    /// Idle: the relative date. Hovered: the switch, plus the state's own word
    /// for anything that isn't a plain on/off — so the four states are never
    /// only a color.
    @ViewBuilder
    private var trailing: some View {
        if !isAvailable {
            Text("not in Claude")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .help("No live copy in ~/.claude/skills")
        } else {
            HStack(spacing: 8) {
                if !style.isLive && state != .off {
                    Text(style.shortLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.partial)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.partial.opacity(0.15), in: Capsule())
                }
                if isHovered {
                    LoadoutToggle(isOn: style.isLive) { newValue in
                        library.setActive(skill, newValue)
                    }
                    .disabled(!library.canToggleClaude(skill))
                    .transition(.opacity)
                } else {
                    RelativeDateText(date: skill.touchedAt)
                        .transition(.opacity)
                }
            }
            .animation(Theme.fade, value: isHovered)
        }
    }
}
