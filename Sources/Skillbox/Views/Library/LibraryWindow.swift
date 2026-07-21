import SkillboxKit
import SwiftUI

/// What the sidebar has focused.
enum SidebarSelection: Hashable {
    case promptFile(String)     // PromptFile.id (path)
    case allSkills
    case tool(String)           // Target.id
}

/// The main window — one custom HStack (no NavigationSplitView, no system-blue
/// selection): sidebar, then either list+detail (skills) or a full-width
/// editor (system prompts).
struct LibraryWindow: View {
    @Environment(SkillLibraryModel.self) private var library
    @Environment(PromptEditorModel.self) private var prompts

    @State private var selection: SidebarSelection = .allSkills
    @State private var selectedSkillIDs: Set<InstalledSkill.ID> = []
    @State private var anchorSkillID: InstalledSkill.ID?

    var body: some View {
        HStack(spacing: 0) {
            LibrarySidebar(selection: $selection)
                .frame(width: Theme.sidebarWidth)

            Rectangle().fill(Theme.border).frame(width: 0.5)

            switch selection {
            case .promptFile:
                PromptEditor()
            case .allSkills, .tool:
                SkillList(
                    selection: selection,
                    selectedSkillIDs: $selectedSkillIDs,
                    anchorSkillID: $anchorSkillID
                )
                .frame(minWidth: 280, idealWidth: Theme.listWidth, maxWidth: Theme.listWidth)
                Rectangle().fill(Theme.border).frame(width: 0.5)
                skillDetail
                    .layoutPriority(1)
            }
        }
        .background(Theme.canvas)
        .frame(minWidth: 900, minHeight: 560)
        .task {
            library.refresh()
            prompts.refresh()
        }
        .onChange(of: selection) { _, newValue in
            if case .promptFile(let id) = newValue {
                prompts.select(prompts.files.first { $0.id == id })
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            library.refresh()
            prompts.handleExternalChange()
        }
    }

    @ViewBuilder
    private var skillDetail: some View {
        // Sort for deterministic display — Set iteration order isn't stable
        // across renders, and the bulk pane's list must not shuffle.
        let selected = selectedSkillIDs
            .compactMap { library.skill(withID: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if selected.count > 1 {
            BulkActionsPane(skills: selected) {
                selectedSkillIDs.removeAll()
            }
        } else if let skill = selected.first {
            SkillDetail(skill: skill)
        } else {
            EmptyState(
                systemImage: "sparkles",
                title: "Select a skill",
                message: "See what it does, where it's installed, and switch it for Claude. ⌘-click or ⇧-click to select several."
            )
        }
    }
}

// MARK: - Sidebar

private struct LibrarySidebar: View {
    @Environment(SkillLibraryModel.self) private var library
    @Environment(PromptEditorModel.self) private var prompts
    @Binding var selection: SidebarSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            SectionLabel(text: "System Prompts")
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 5)

            ForEach(prompts.files) { file in
                SidebarItem(
                    title: file.displayShortName,
                    systemImage: "text.alignleft",
                    isSelected: selection == .promptFile(file.id)
                ) {
                    selection = .promptFile(file.id)
                }
            }

            SectionLabel(text: "Skills")
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 5)

            SidebarItem(
                title: "All Skills",
                systemImage: "shippingbox",
                count: library.skills.count,
                isSelected: selection == .allSkills
            ) {
                selection = .allSkills
            }

            ForEach(library.toolFilters) { filter in
                SidebarItem(
                    title: filter.shortName,
                    systemImage: filter.systemImage,
                    count: filter.count,
                    isSelected: selection == .tool(filter.id)
                ) {
                    selection = .tool(filter.id)
                }
            }

            Spacer(minLength: 12)
            footer
        }
        .padding(.horizontal, 8)
        .background(Theme.panel)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            StatusDot(isOn: true)
            Text("\(library.activeCount) of \(library.skills.count) active")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .monospacedDigit()
            Spacer()
            GhostIconButton(systemImage: "gearshape", help: "Settings") {
                WindowCoordinator.shared.showSettingsWindow()
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }
}

private struct SidebarItem: View {
    let title: String
    let systemImage: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary)
                    .frame(width: 16)
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count {
                    Text("\(count)")
                        .font(Theme.mono)
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                isSelected ? Theme.selection : (isHovered ? Theme.hover : .clear),
                in: .rect(cornerRadius: 7)
            )
            .contentShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

extension PromptFile {
    /// "CLAUDE.md — Claude Code" → sidebar-length "CLAUDE.md".
    var displayShortName: String {
        displayName.components(separatedBy: " — ").first ?? displayName
    }
}
