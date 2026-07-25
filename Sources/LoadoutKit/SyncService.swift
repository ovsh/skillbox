import Foundation

public struct SyncOutcome: Sendable {
    public let catalog: Catalog
    public let summary: InstallSummary
    public let plan: SyncPlan
    public let checkoutPath: String
    public let commit: String?
}

/// Orchestrates one full sync:
/// git pull → scan catalog → plan against lockfile → apply → save lockfile.
///
/// DORMANT IN v2: no UI path invokes registry sync — Loadout is single-player
/// for now. Before team mode revives this, the Planner/Installer must become
/// shelf-aware (a sync could otherwise resurrect a skill the user shelved via
/// SkillShelf). See PLAN.md §8, review finding #13.
public struct SyncService: Sendable {
    private let gitClient = GitClient()
    private let scanner = CatalogScanner()
    private let planner = Planner()
    private let registry: TargetRegistry
    private let lockfileStore: LockfileStore

    public init(
        registry: TargetRegistry = TargetRegistry(),
        lockfileStore: LockfileStore = LockfileStore()
    ) {
        self.registry = registry
        self.lockfileStore = lockfileStore
    }

    public func run(
        settings: AppSettings,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        logger: Logger
    ) throws -> SyncOutcome {
        let checkout = try gitClient.prepareCheckout(
            remote: settings.remoteGitURL,
            checkoutPath: settings.checkoutPath,
            logger: logger
        )

        let catalog = try scanner.scan(checkout: checkout)
        logger(.info, "Catalog: \(catalog.skills.count) skills, \(catalog.ruleSets.count) rule sets across \(catalog.spaces.count) spaces")

        let targets = registry.enabled(settings: settings, home: home)
        guard !targets.isEmpty else {
            logger(.warn, "No targets enabled; nothing to install.")
            return SyncOutcome(
                catalog: catalog,
                summary: InstallSummary(added: 0, updated: 0, removed: 0, managedFileCount: 0),
                plan: SyncPlan(desiredFiles: [], filesToRemove: [], installedSkillIDs: [], skippedCollisions: [], targets: []),
                checkoutPath: checkout.path,
                commit: gitClient.headCommit(checkout: checkout)
            )
        }
        logger(.info, "Targets: \(targets.map(\.id).joined(separator: ", "))")

        let lockfile = lockfileStore.load()
        let plan = planner.plan(
            catalog: catalog,
            settings: settings,
            targets: targets,
            lockfile: lockfile,
            checkout: checkout,
            logger: logger
        )

        let installer = Installer(registry: registry)
        let summary = try installer.apply(plan: plan, checkout: checkout, home: home, logger: logger)

        let commit = gitClient.headCommit(checkout: checkout)
        try lockfileStore.save(Lockfile(
            files: plan.desiredFiles.map(\.destination).sorted(),
            installedSkills: plan.installedSkillIDs.sorted(),
            lastSyncCommit: commit,
            lastSyncAt: Date()
        ))

        logger(.info, "Sync applied: \(summary.added) added, \(summary.updated) refreshed, \(summary.removed) removed")

        return SyncOutcome(
            catalog: catalog,
            summary: summary,
            plan: plan,
            checkoutPath: checkout.path,
            commit: commit
        )
    }

    /// Scan the existing checkout without touching git or writing anything.
    /// Used by the browser to show the catalog between syncs.
    public func loadCatalog(settings: AppSettings) -> Catalog {
        let checkout = URL(fileURLWithPath: settings.checkoutPath.expandingTildePath)
        return (try? scanner.scan(checkout: checkout)) ?? .empty
    }
}
