import Foundation
import Observation
import SkillboxKit

/// The library's source of truth: the unified skill inventory plus the
/// operations the UI can perform on it (Claude override, per-tool shelving).
///
/// All mutations re-scan the inventory; scans run off-main and publish results
/// back here. The list renders instantly from the last scan while a refresh
/// runs — no spinners for sub-100ms work.
@MainActor
@Observable
final class SkillLibraryModel {
    private(set) var skills: [InstalledSkill] = []
    private(set) var isRefreshing = false
    private(set) var lastError: String?
    /// Skills with a mutation in flight — their controls disable until the
    /// post-mutation re-scan publishes disk truth.
    private(set) var mutatingSkillIDs: Set<String> = []

    var searchText = ""

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let registry = TargetRegistry()
    private let shelf: SkillShelf
    private let settingsStore: ClaudeSettingsStore
    private let scanner: SkillInventoryScanner
    private var monitor: DirectoryMonitor?

    init() {
        let appSupport = AppPaths.appSupportDirectory()
        shelf = SkillShelf(rootDirectory: appSupport.appendingPathComponent("shelf"))
        settingsStore = ClaudeSettingsStore(
            settingsFileURL: home.appendingPathComponent(".claude/settings.json")
        )
        scanner = SkillInventoryScanner(
            registry: registry,
            shelf: shelf,
            settingsStore: settingsStore,
            lockfileStore: LockfileStore()
        )
        startMonitoring()
    }

    /// Live-refresh when a tool, Claude Code, or the user touches a skills
    /// dir or ~/.claude (settings.json) behind our back.
    private func startMonitoring() {
        var watched = registry.targets.compactMap { target in
            target.skillsPath.map { home.appendingPathComponent($0) }
        }
        watched.append(home.appendingPathComponent(".claude"))
        monitor = DirectoryMonitor(directories: watched) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: - Derived

    var filteredSkills: [InstalledSkill] {
        let query = searchText.trimmed
        guard !query.isEmpty else { return skills }
        return skills.filter {
            $0.name.localizedStandardContains(query)
                || $0.description.localizedStandardContains(query)
                || $0.dirName.localizedStandardContains(query)
        }
    }

    var activeCount: Int {
        skills.filter { isActiveForClaude($0) }.count
    }

    /// Five most recently touched skills — the menu bar popover's quick list.
    var recentSkills: [InstalledSkill] {
        skills
            .sorted { ($0.touchedAt ?? .distantPast) > ($1.touchedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    func skill(withID id: String) -> InstalledSkill? {
        skills.first { $0.id == id }
    }

    /// "Active" in the primary sense: Claude Code + Agent SDK will invoke it.
    func isActiveForClaude(_ skill: InstalledSkill) -> Bool {
        (skill.claudeOverride ?? .on) != .off
    }

    // MARK: - Refresh

    private var refreshQueuedWhileBusy = false

    func refresh() {
        // Coalesce: a refresh requested mid-scan runs once the scan lands, so
        // the UI never settles on stale data after rapid toggles.
        guard !isRefreshing else {
            refreshQueuedWhileBusy = true
            return
        }
        isRefreshing = true
        let scanner = scanner
        let home = home
        Task.detached(priority: .userInitiated) {
            let result = scanner.scan(home: home)
            await MainActor.run {
                self.skills = result
                self.isRefreshing = false
                if self.refreshQueuedWhileBusy {
                    self.refreshQueuedWhileBusy = false
                    self.refresh()
                }
            }
        }
    }

    // MARK: - Activation

    /// The list switch: on ↔ off via Claude's skillOverrides. Optimistic —
    /// the UI flips immediately; a scan follows to confirm reality.
    func setActive(_ skill: InstalledSkill, _ active: Bool) {
        setClaudeOverride(skill, active ? nil : .off)
        Analytics.track(.skillToggled(skill: skill.dirName, enabled: active))
    }

    /// The detail pane's 4-state control. nil clears the entry (default on).
    func setClaudeOverride(_ skill: InstalledSkill, _ state: SkillOverrideState?) {
        performMutation(on: skill) { [settingsStore] in
            try settingsStore.setOverride(state, forSkill: skill.dirName)
        }
    }

    /// Per-tool folder shelving for tools without an override mechanism.
    func setToolPresence(_ skill: InstalledSkill, targetID: String, enabled: Bool) {
        guard let target = registry.targets.first(where: { $0.id == targetID }),
              let skillsPath = target.skillsPath else { return }
        let skillsDir = home.appendingPathComponent(skillsPath)
        performMutation(on: skill) { [shelf] in
            if enabled {
                try shelf.restore(dirName: skill.dirName, to: skillsDir, targetID: targetID)
            } else {
                try shelf.shelve(dirName: skill.dirName, from: skillsDir, targetID: targetID)
            }
        }
    }

    /// Runs a disk mutation off-main with the skill's controls disabled, then
    /// re-scans so published state is always what's actually on disk.
    private func performMutation(on skill: InstalledSkill, _ operation: @escaping @Sendable () throws -> Void) {
        guard !mutatingSkillIDs.contains(skill.id) else { return }
        mutatingSkillIDs.insert(skill.id)
        Task.detached(priority: .userInitiated) {
            let failure: String?
            do {
                try operation()
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run {
                self.mutatingSkillIDs.remove(skill.id)
                self.lastError = failure
                self.refresh()
            }
        }
    }

    // MARK: - Presentation helpers

    func toolDisplayName(_ targetID: String) -> String {
        registry.targets.first { $0.id == targetID }?.displayName ?? targetID
    }

    struct ToolFilter: Identifiable {
        let id: String
        let shortName: String
        let systemImage: String
        let count: Int
    }

    /// Sidebar filter rows: only tools that actually hold at least one skill.
    var toolFilters: [ToolFilter] {
        registry.targets.compactMap { target in
            let count = skills.count { skill in
                skill.presences.contains { $0.targetID == target.id }
            }
            guard count > 0 else { return nil }
            return ToolFilter(
                id: target.id,
                shortName: Self.shortToolNames[target.id] ?? target.displayName,
                systemImage: Self.toolSymbols[target.id] ?? "wrench.and.screwdriver",
                count: count
            )
        }
    }

    private static let shortToolNames: [String: String] = [
        "claude": "Claude Code",
        "agents": "Agents",
        "cursor": "Cursor",
        "opencode": "OpenCode",
    ]

    private static let toolSymbols: [String: String] = [
        "claude": "asterisk",
        "agents": "square.grid.2x2",
        "cursor": "cursorarrow",
        "opencode": "terminal",
    ]
}
