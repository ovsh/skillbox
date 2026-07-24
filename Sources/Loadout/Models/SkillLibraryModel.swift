import Foundation
import Observation
import LoadoutKit

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
    /// True when ~/.claude/settings.json can't be parsed: Claude switches
    /// disable rather than fabricating "on" states.
    private(set) var overridesUnreadable = false
    /// Optimistic Claude-active state, keyed by skill id, shown while the
    /// write + re-scan round-trips so switches respond instantly instead of
    /// snapping back for a frame. Cleared when disk truth publishes.
    private var optimisticActive: [String: Bool] = [:]

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
        skills.filter { isClaudeAvailable($0) && isActiveForClaude($0) }.count
    }

    /// Claude Code can only load skills with a live, non-broken copy in
    /// ~/.claude/skills — everything else gets no Claude switch.
    func isClaudeAvailable(_ skill: InstalledSkill) -> Bool {
        skill.presences.contains { $0.targetID == "claude" && !$0.isShelved && !$0.isBroken }
    }

    /// The Claude switch is interactable: skill is loadable, settings are
    /// parseable, and no mutation is in flight.
    func canToggleClaude(_ skill: InstalledSkill) -> Bool {
        isClaudeAvailable(skill) && !overridesUnreadable && !mutatingSkillIDs.contains(skill.id)
    }

    /// Five most recently touched skills — the menu bar popover's quick list.
    var recentSkills: [InstalledSkill] {
        skills
            .sorted { ($0.touchedAt ?? .distantPast) > ($1.touchedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var skillIndex: [String: Int] = [:]

    func skill(withID id: String) -> InstalledSkill? {
        guard let index = skillIndex[id], skills.indices.contains(index) else { return nil }
        return skills[index]
    }

    /// "Active" in the primary sense: Claude Code + Agent SDK will invoke it.
    func isActiveForClaude(_ skill: InstalledSkill) -> Bool {
        optimisticActive[skill.id] ?? ((skill.claudeOverride ?? .on) != .off)
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
        let settingsStore = settingsStore
        let home = home
        Task.detached(priority: .userInitiated) {
            let result = scanner.scan(home: home)
            // The scanner tolerates unreadable settings by reporting no
            // overrides — probe separately so the UI can say so instead of
            // fabricating "on" for every skill.
            let overridesReadable = (try? settingsStore.overrides()) != nil
            await MainActor.run {
                self.skills = result
                self.skillIndex = Dictionary(
                    uniqueKeysWithValues: result.enumerated().map { ($0.element.id, $0.offset) }
                )
                self.overridesUnreadable = !overridesReadable
                self.isRefreshing = false
                self.rebuildSkillDirWatchers()
                if self.refreshQueuedWhileBusy {
                    self.refreshQueuedWhileBusy = false
                    self.refresh()
                } else if self.mutatingSkillIDs.isEmpty {
                    // Disk truth is current and no writes are in flight —
                    // optimistic states have served their purpose.
                    self.optimisticActive.removeAll()
                }
            }
        }
    }

    /// Skill content edits happen inside skill folders, which the root
    /// watchers can't see — watch each live skill dir so touchedAt and
    /// rendered SKILL.md stay honest. Rebuilt only when the path set changes.
    private var skillDirMonitor: DirectoryMonitor?
    private var watchedSkillPaths: Set<String> = []

    private func rebuildSkillDirWatchers() {
        let paths = Set(
            skills
                .flatMap(\.presences)
                .filter { !$0.isBroken && !$0.isShelved }
                .map(\.path)
                .prefix(400)
        )
        guard paths != watchedSkillPaths else { return }
        watchedSkillPaths = paths
        skillDirMonitor = DirectoryMonitor(
            directories: paths.map { URL(fileURLWithPath: $0) }
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: - Activation

    /// The list switch: on ↔ off via Claude's skillOverrides. Optimistic —
    /// the UI flips immediately; a scan follows to confirm reality.
    func setActive(_ skill: InstalledSkill, _ active: Bool) {
        // A second click during the round-trip would be silently dropped by
        // performMutation — refuse it before the optimistic state lies.
        guard canToggleClaude(skill) else { return }
        optimisticActive[skill.id] = active
        setClaudeOverride(skill, active ? nil : .off)
        Analytics.track(.skillToggled(skill: skill.dirName, enabled: active))
    }

    /// The detail pane's 4-state control. nil clears the entry (default on).
    func setClaudeOverride(_ skill: InstalledSkill, _ state: SkillOverrideState?) {
        performMutation(on: skill) { [settingsStore] in
            try settingsStore.setOverride(state, forSkill: skill.dirName)
        }
    }

    /// Deletes a skill from disk: real folders to the Trash, symlinks remove
    /// the link only, override entry cleared. The UI confirms before calling.
    func deleteSkill(_ skill: InstalledSkill) {
        deleteSkills([skill])
    }

    // MARK: - Bulk operations (multi-select)

    /// Turns many skills on/off in one pass: one settings write per skill
    /// (the store serializes them), one re-scan at the end.
    func setActiveBulk(_ skills: [InstalledSkill], _ active: Bool) {
        let eligible = skills.filter { canToggleClaude($0) }
        guard !eligible.isEmpty else { return }

        for skill in eligible { optimisticActive[skill.id] = active }
        mutatingSkillIDs.formUnion(eligible.map(\.id))
        let store = settingsStore
        let batch = eligible.map { (id: $0.id, dirName: $0.dirName) }

        Task.detached(priority: .userInitiated) {
            var failure: String?
            for item in batch {
                do {
                    try store.setOverride(active ? nil : .off, forSkill: item.dirName)
                } catch {
                    failure = error.localizedDescription
                }
            }
            await MainActor.run {
                self.mutatingSkillIDs.subtract(batch.map(\.id))
                self.lastError = failure
                self.refresh()
            }
        }
        Analytics.track(.skillToggled(skill: "bulk:\(eligible.count)", enabled: active))
    }

    /// Deletes many skills: folders to the Trash, links removed link-only,
    /// override entries cleared. One re-scan at the end.
    func deleteSkills(_ skills: [InstalledSkill]) {
        let targets = skills.filter { !mutatingSkillIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        mutatingSkillIDs.formUnion(targets.map(\.id))
        let deleter = SkillDeleter(settingsStore: settingsStore)

        Task.detached(priority: .userInitiated) {
            var failures: [String] = []
            for skill in targets {
                do {
                    try deleter.delete(skill)
                } catch {
                    failures.append(error.localizedDescription)
                }
            }
            let failure = failures.isEmpty ? nil : failures.joined(separator: " · ")
            await MainActor.run {
                self.mutatingSkillIDs.subtract(targets.map(\.id))
                self.lastError = failure
                self.refresh()
            }
        }
        for skill in targets {
            Analytics.track(.skillDeleted(skill: skill.dirName))
        }
    }

    /// Per-tool folder shelving for tools without an override mechanism.
    func setToolPresence(_ skill: InstalledSkill, targetID: String, enabled: Bool) {
        // Never move any copy of a skill that participates in symlinks:
        // shelving the real directory would dangle the other tools' links.
        guard !skill.presences.contains(where: \.isSymlink) else {
            lastError = "\(skill.name) is linked between tools. Shelving is disabled to keep those links intact."
            return
        }
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
