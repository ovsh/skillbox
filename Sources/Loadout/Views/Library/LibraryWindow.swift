import LoadoutKit
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
///
/// The window hides its title bar, so every pane reserves `Theme.titleBar` at
/// the top: the traffic lights get their own air instead of landing on top of
/// the first control.
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

            // Panes cross-fade rather than cut. The ZStack is what lets the
            // outgoing and incoming pane overlap for the length of the fade.
            ZStack {
                switch selection {
                case .promptFile:
                    PromptEditor()
                        .transition(.opacity)
                case .allSkills, .tool:
                    HStack(spacing: 0) {
                        SkillList(
                            selection: selection,
                            selectedSkillIDs: $selectedSkillIDs,
                            anchorSkillID: $anchorSkillID
                        )
                        .frame(minWidth: 300, idealWidth: Theme.listWidth, maxWidth: Theme.listWidth)

                        // The one seam in the window: list and detail share a
                        // tone, so they need a hairline to stay two panes
                        // rather than one field.
                        Rectangle().fill(Theme.separator).frame(width: 1)

                        skillDetail
                            .layoutPriority(1)
                    }
                    .transition(.opacity)
                }
            }
            // Keyed to the mode, not the selection: moving between two prompt
            // files, or two tool filters, is navigation inside one pane and
            // shouldn't blink.
            .animation(Theme.fade, value: isEditingPrompt)
        }
        .background(Theme.canvas)
        .frame(minWidth: 940, minHeight: 580)
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

    private var isEditingPrompt: Bool {
        if case .promptFile = selection { return true }
        return false
    }

    /// Which of the three right-hand panes is showing. Named so the cross-fade
    /// fires on the pane changing, not on the selection set churning.
    private enum DetailMode { case empty, single, bulk }

    @ViewBuilder
    private var skillDetail: some View {
        // Sort for deterministic display — Set iteration order isn't stable
        // across renders, and the bulk pane's list must not shuffle.
        let selected = selectedSkillIDs
            .compactMap { library.skill(withID: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let mode: DetailMode = selected.count > 1 ? .bulk : (selected.isEmpty ? .empty : .single)

        ZStack {
            if selected.count > 1 {
                BulkActionsPane(skills: selected) {
                    selectedSkillIDs.removeAll()
                }
                .transition(.opacity)
            } else if let skill = selected.first {
                SkillDetail(skill: skill)
                    .transition(.opacity)
            } else {
                EmptyState(
                    title: "Nothing selected",
                    message: "Pick a skill to see what it does, where it lives, and how Claude sees it."
                )
                .background(Theme.canvas)
                .transition(.opacity)
            }
        }
        .animation(Theme.fade, value: mode)
    }
}

// MARK: - Sidebar

private struct LibrarySidebar: View {
    @Environment(SkillLibraryModel.self) private var library
    @Environment(PromptEditorModel.self) private var prompts
    @Binding var selection: SidebarSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Traffic-light air.
            Color.clear.frame(height: Theme.titleBar)

            SectionLabel(text: "System Prompts")
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            ForEach(prompts.files) { file in
                SidebarItem(
                    title: file.displayShortName,
                    systemImage: "doc.text",
                    isSelected: selection == .promptFile(file.id)
                ) {
                    selection = .promptFile(file.id)
                }
            }

            SectionLabel(text: "Skills")
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 6)

            SidebarItem(
                title: "All Skills",
                systemImage: "square.stack.3d.up",
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

            Spacer(minLength: 16)
            footer
        }
        .padding(.horizontal, 10)
        .background {
            // Real behind-window vibrancy with the chassis tone over it. The
            // sidebar is the one pane that lets the desktop through.
            ZStack {
                VisualEffect(material: .sidebar)
                Theme.chassis.opacity(0.5)
            }
            .ignoresSafeArea()
        }
    }

    /// Live tally, then the gear. No rule above it — the sidebar's own bottom
    /// edge and 20pt of air are the separation.
    private var footer: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.live)
                .frame(width: 7, height: 7)
            Text("\(library.activeCount) of \(library.skills.count) active")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Theme.snap, value: library.activeCount)
            Spacer(minLength: 4)
            GhostIconButton(systemImage: "gearshape", help: "Settings") {
                WindowCoordinator.shared.showSettingsWindow()
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 2)
        .padding(.bottom, 12)
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
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.live : Theme.inkSecondary)
                    .frame(width: 18)
                Text(title)
                    .font(isSelected ? Theme.bodyMedium : Theme.body)
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count {
                    Text("\(count)")
                        .font(Theme.meta)
                        .monospacedDigit()
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                isSelected ? Theme.selection : (isHovered ? Theme.hover : .clear),
                in: .rect(cornerRadius: 7)
            )
            .contentShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.fade) { isHovered = hovering }
        }
    }
}

extension PromptFile {
    /// "CLAUDE.md — Claude Code" → sidebar-length "CLAUDE.md".
    var displayShortName: String {
        displayName.components(separatedBy: " — ").first ?? displayName
    }
}
