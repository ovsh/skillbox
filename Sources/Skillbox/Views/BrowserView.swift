import MarkdownUI
import SkillboxKit
import SwiftUI

// MARK: - Navigation model

enum SidebarItem: Hashable {
    case all
    case space(String)
    case playground
    case local
}

enum SkillSelection: Hashable {
    case catalog(String)  // CatalogSkill.id
    case local(String)    // LocalSkill.id (path)
}

// MARK: - Browser

struct BrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var sidebarSelection: SidebarItem? = .all
    @State private var skillSelection: SkillSelection?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            skillList
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            detail
        }
        .navigationTitle("Skillbox")
        .onAppear {
            appState.refreshCatalog()
            presentOnboardingIfNeeded()
        }
        .onChange(of: appState.onboardingPresentationRequestID) {
            showOnboarding = true
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            appState.deferOnboardingIfNeeded()
        }) {
            OnboardingView()
                .environmentObject(appState)
        }
    }

    @State private var showOnboarding = false

    private func presentOnboardingIfNeeded() {
        if appState.requiresOnboarding {
            appState.beginOnboarding()
            showOnboarding = true
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $sidebarSelection) {
                Section {
                    Label("All Skills", systemImage: "shippingbox")
                        .tag(SidebarItem.all)
                }

                if appState.catalog.spaces.count > 1 {
                    Section("Spaces") {
                        ForEach(appState.catalog.spaces) { space in
                            Label(space.displayName, systemImage: "folder")
                                .tag(SidebarItem.space(space.folderName))
                        }
                    }
                }

                Section {
                    if appState.catalog.skills.contains(where: \.isPlayground) {
                        Label("Playground", systemImage: "testtube.2")
                            .tag(SidebarItem.playground)
                    }
                    if !appState.localSkills.isEmpty {
                        Label("Local", systemImage: "internaldrive")
                            .tag(SidebarItem.local)
                    }
                }
            }
            .listStyle(.sidebar)

            syncBar
        }
    }

    private var syncBar: some View {
        VStack(spacing: 6) {
            Divider().opacity(0.4)
            HStack(spacing: 8) {
                Button {
                    switch appState.manualSyncAction {
                    case .onboarding:
                        appState.requestOnboardingPresentation()
                    case .settings:
                        WindowCoordinator.shared.showSettingsWindow()
                    case .sync:
                        appState.syncNow(trigger: "manual")
                    }
                } label: {
                    HStack(spacing: 5) {
                        if appState.isSyncing {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(appState.isSyncing ? "Syncing…" : "Sync")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .disabled(appState.isSyncing)

                Spacer()

                if let lastSyncAt = appState.lastSyncAt {
                    Text(lastSyncAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: Skill list

    private var visibleCatalogSkills: [CatalogSkill] {
        var skills = appState.catalog.skills
        switch sidebarSelection {
        case .space(let folderName):
            skills = skills.filter { $0.space == folderName && !$0.isPlayground }
        case .playground:
            skills = skills.filter(\.isPlayground)
        case .local, .none:
            skills = []
        case .all:
            skills = skills.filter { !$0.isPlayground }
        }
        guard !searchText.trimmed.isEmpty else { return skills }
        let query = searchText.trimmed
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
                || $0.dirName.localizedCaseInsensitiveContains(query)
        }
    }

    private var visibleLocalSkills: [LocalSkill] {
        guard sidebarSelection == .local else { return [] }
        guard !searchText.trimmed.isEmpty else { return appState.localSkills }
        let query = searchText.trimmed
        return appState.localSkills.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private var skillList: some View {
        if appState.catalog.skills.isEmpty && appState.localSkills.isEmpty {
            emptyCatalogPlaceholder
        } else {
            List(selection: $skillSelection) {
                ForEach(visibleCatalogSkills) { skill in
                    CatalogSkillRow(skill: skill)
                        .tag(SkillSelection.catalog(skill.id))
                }
                ForEach(visibleLocalSkills) { skill in
                    LocalSkillRow(skill: skill)
                        .tag(SkillSelection.local(skill.id))
                }
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search skills")
        }
    }

    private var emptyCatalogPlaceholder: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "shippingbox")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(appState.settings.remoteGitURL.trimmed.isEmpty
                 ? "Connect a registry repo to browse skills"
                 : "No skills yet — hit Sync to load your registry")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button(appState.settings.remoteGitURL.trimmed.isEmpty ? "Get Started" : "Sync Now") {
                if appState.settings.remoteGitURL.trimmed.isEmpty {
                    appState.requestOnboardingPresentation()
                } else {
                    appState.syncNow(trigger: "manual")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch skillSelection {
        case .catalog(let id):
            if let skill = appState.catalog.skills.first(where: { $0.id == id }) {
                CatalogSkillDetail(skill: skill)
            } else {
                detailPlaceholder
            }
        case .local(let id):
            if let skill = appState.localSkills.first(where: { $0.id == id }) {
                LocalSkillDetail(skill: skill)
            } else {
                detailPlaceholder
            }
        case .none:
            detailPlaceholder
        }
    }

    private var detailPlaceholder: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Select a skill to see what it does")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rows

private struct CatalogSkillRow: View {
    @EnvironmentObject var appState: AppState
    let skill: CatalogSkill

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if skill.isPlayground {
                        TagBadge(text: "Playground", color: .orange)
                    }
                }
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { appState.isSkillEnabled(skill) },
                set: { appState.setSkillEnabled(skill, $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.vertical, 3)
    }
}

private struct LocalSkillRow: View {
    let skill: LocalSkill

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    TagBadge(text: "Local", color: .secondary)
                }
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detail views

private struct CatalogSkillDetail: View {
    @EnvironmentObject var appState: AppState
    let skill: CatalogSkill

    private var spaceDisplayName: String {
        appState.catalog.spaces.first { $0.folderName == skill.space }?.displayName ?? skill.space
    }

    private var skillDirectory: URL {
        URL(fileURLWithPath: appState.settings.checkoutPath.expandingTildePath)
            .appendingPathComponent(skill.relativePath)
    }

    var body: some View {
        SkillDocumentView(
            title: skill.name,
            markdownFile: skillDirectory.appendingPathComponent("SKILL.md")
        ) {
            HStack(spacing: Space.sm) {
                if skill.space != "." {
                    TagBadge(text: spaceDisplayName)
                }
                if skill.isPlayground {
                    TagBadge(text: "Playground", color: .orange)
                }
                if appState.isSkillInstalled(skill) {
                    TagBadge(text: "Installed", color: .green)
                }

                Spacer()

                Toggle(appState.isSkillEnabled(skill) ? "On" : "Off", isOn: Binding(
                    get: { appState.isSkillEnabled(skill) },
                    set: { appState.setSkillEnabled(skill, $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if appState.isSkillEnabled(skill) {
                Text("Installs to " + appState.enabledTargets
                    .compactMap { $0.skillsPath.map { path in "~/\(path)" } }
                    .joined(separator: "  ·  "))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([skillDirectory])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .help("Show in Finder")
            }
        }
    }
}

private struct LocalSkillDetail: View {
    let skill: LocalSkill

    var body: some View {
        SkillDocumentView(
            title: skill.name,
            markdownFile: URL(fileURLWithPath: skill.path).appendingPathComponent("SKILL.md")
        ) {
            HStack(spacing: Space.sm) {
                TagBadge(text: "Local", color: .secondary)
                Text("Unmanaged — lives in \(skill.targetIDs.map { "~/.\($0)" }.joined(separator: ", "))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: skill.path)])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .help("Show in Finder")
            }
        }
    }
}

// MARK: - Markdown document

/// Renders a skill's SKILL.md with a metadata header block.
private struct SkillDocumentView<Header: View>: View {
    let title: String
    let markdownFile: URL
    @ViewBuilder let header: Header

    @State private var content: String?

    /// Above this size, skip MarkdownUI and show plain text — rendering cost
    /// grows sharply with document size.
    private static var markdownRenderLimit: Int { 120 * 1024 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))

                header

                Divider().opacity(0.4)

                if let content {
                    if content.utf8.count > Self.markdownRenderLimit {
                        Text(content)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Markdown(stripFrontmatter(content))
                            .markdownTheme(.docC)
                            .textSelection(.enabled)
                    }
                } else {
                    Text("No SKILL.md in this skill.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: markdownFile) {
            content = try? String(contentsOf: markdownFile, encoding: .utf8)
        }
    }

    /// The frontmatter fence is metadata, already surfaced in the header.
    private func stripFrontmatter(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return text }
        if let closing = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) {
            return lines[(closing + 1)...].joined(separator: "\n")
        }
        return text
    }
}
