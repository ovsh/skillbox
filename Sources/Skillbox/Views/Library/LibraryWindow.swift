import SkillboxKit
import SwiftUI

/// Which slice of the library the sidebar has focused.
enum LibrarySection: Hashable {
    case allSkills
    case tool(String)      // Target.id
    case prompts
}

/// The main window: sidebar → skill list (or prompt list) → detail.
struct LibraryWindow: View {
    @Environment(SkillLibraryModel.self) private var library
    @Environment(PromptEditorModel.self) private var prompts

    @State private var section: LibrarySection = .allSkills
    @State private var selectedSkillID: InstalledSkill.ID?

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(section: $section)
                .navigationSplitViewColumnWidth(min: 176, ideal: 196)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            detailColumn
        }
        .task {
            library.refresh()
            prompts.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            library.refresh()
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch section {
        case .allSkills, .tool:
            SkillList(section: section, selectedSkillID: $selectedSkillID)
        case .prompts:
            PromptFileList()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch section {
        case .allSkills, .tool:
            if let id = selectedSkillID, let skill = library.skill(withID: id) {
                SkillDetail(skill: skill)
            } else {
                EmptyState(
                    systemImage: "sparkles",
                    title: "Select a skill",
                    message: "See what it does, and where it's installed."
                )
            }
        case .prompts:
            PromptEditor()
        }
    }
}

// MARK: - Sidebar

private struct LibrarySidebar: View {
    @Environment(SkillLibraryModel.self) private var library
    @Binding var section: LibrarySection

    var body: some View {
        List(selection: $section) {
            Section {
                Label("All Skills", systemImage: "shippingbox")
                    .badge(library.skills.count)
                    .tag(LibrarySection.allSkills)
            }

            Section("Tools") {
                ForEach(library.toolFilters, id: \.id) { filter in
                    Label(filter.shortName, systemImage: filter.systemImage)
                        .badge(filter.count)
                        .tag(LibrarySection.tool(filter.id))
                }
            }

            Section("Setup") {
                Label("Prompts", systemImage: "text.alignleft")
                    .tag(LibrarySection.prompts)
            }
        }
        .listStyle(.sidebar)
    }
}
