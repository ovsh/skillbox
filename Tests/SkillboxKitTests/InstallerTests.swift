import Foundation
import Testing
@testable import SkillboxKit

@Suite("Installer")
struct InstallerTests {
    /// Builds checkout + fake home, returns both fixtures.
    private func makeWorld() throws -> (checkout: Fixture, home: Fixture) {
        let checkout = try Fixture(name: "inst-checkout")
        try checkout.write("everyone/skills/alpha/SKILL.md", skillMarkdown(name: "Alpha", description: "A"))
        try checkout.write("everyone/skills/alpha/scripts/run.sh", "echo hi")
        try checkout.write("everyone/rules/team.md", "be kind")
        let home = try Fixture(name: "inst-home")
        return (checkout, home)
    }

    private func sync(
        checkout: Fixture,
        home: Fixture,
        settings: AppSettings = testSettings(),
        lockfile: Lockfile = .empty
    ) throws -> (SyncPlan, InstallSummary) {
        let catalog = try CatalogScanner().scan(checkout: checkout.root)
        let registry = testRegistry()
        let plan = Planner().plan(
            catalog: catalog,
            settings: settings,
            targets: registry.targets,
            lockfile: lockfile,
            checkout: checkout.root,
            logger: nullLogger
        )
        let summary = try Installer(registry: registry).apply(
            plan: plan, checkout: checkout.root, home: home.root, logger: nullLogger
        )
        return (plan, summary)
    }

    @Test("Fresh sync installs skills and rules into every target")
    func freshInstall() throws {
        let (checkout, home) = try makeWorld()
        defer { checkout.cleanup(); home.cleanup() }

        let (plan, summary) = try sync(checkout: checkout, home: home)

        #expect(home.exists(".claude/skills/alpha/SKILL.md"))
        #expect(home.exists(".claude/skills/alpha/scripts/run.sh"))
        #expect(home.exists(".agents/skills/alpha/SKILL.md"))
        #expect(home.exists(".claude/rules/team.md"))
        #expect(summary.added == plan.desiredFiles.count)
        #expect(summary.updated == 0)
        #expect(summary.removed == 0)
    }

    @Test("Second sync refreshes files in place")
    func refresh() throws {
        let (checkout, home) = try makeWorld()
        defer { checkout.cleanup(); home.cleanup() }

        let (plan1, _) = try sync(checkout: checkout, home: home)
        try checkout.write("everyone/skills/alpha/SKILL.md", skillMarkdown(name: "Alpha v2", description: "A"))

        let lockfile = Lockfile(files: plan1.desiredFiles.map(\.destination))
        let (_, summary) = try sync(checkout: checkout, home: home, lockfile: lockfile)

        #expect(summary.updated == plan1.desiredFiles.count)
        #expect(summary.added == 0)
        #expect(home.read(".claude/skills/alpha/SKILL.md")?.contains("Alpha v2") == true)
    }

    @Test("Removing a skill deletes its files and prunes empty dirs, keeping unmanaged files")
    func uninstallAndPrune() throws {
        let (checkout, home) = try makeWorld()
        defer { checkout.cleanup(); home.cleanup() }

        // A skill the user made locally — Skillbox must never touch it.
        try home.write(".claude/skills/my-local-skill/SKILL.md", "mine")

        let (plan1, _) = try sync(checkout: checkout, home: home)
        let lockfile = Lockfile(files: plan1.desiredFiles.map(\.destination))

        // Skill disappears from the registry.
        try FileManager.default.removeItem(at: checkout.root.appendingPathComponent("everyone/skills/alpha"))
        try checkout.write("everyone/skills/gamma/SKILL.md", skillMarkdown(name: "Gamma", description: "G"))

        let (_, summary) = try sync(checkout: checkout, home: home, lockfile: lockfile)

        #expect(!home.exists(".claude/skills/alpha/SKILL.md"))
        #expect(!home.exists(".claude/skills/alpha")) // pruned
        #expect(!home.exists(".agents/skills/alpha"))
        #expect(home.exists(".claude/skills")) // prefix root kept
        #expect(home.exists(".claude/skills/my-local-skill/SKILL.md")) // untouched
        #expect(home.exists(".claude/skills/gamma/SKILL.md"))
        #expect(summary.removed > 0)
    }

    @Test("Disabling a skill in settings uninstalls it on next sync")
    func disableSkill() throws {
        let (checkout, home) = try makeWorld()
        defer { checkout.cleanup(); home.cleanup() }

        let (plan1, _) = try sync(checkout: checkout, home: home)
        let lockfile = Lockfile(files: plan1.desiredFiles.map(\.destination))

        var settings = testSettings()
        settings.disabledSkills = ["everyone/alpha"]
        try sync(checkout: checkout, home: home, settings: settings, lockfile: lockfile)

        #expect(!home.exists(".claude/skills/alpha"))
        #expect(!home.exists(".agents/skills/alpha"))
        #expect(home.exists(".claude/rules/team.md")) // rules unaffected
    }

    @Test("Plan with a destination outside allowed prefixes is rejected")
    func destinationGuard() throws {
        let (checkout, home) = try makeWorld()
        defer { checkout.cleanup(); home.cleanup() }

        let evilPlan = SyncPlan(
            desiredFiles: [DesiredFile(source: "everyone/rules/team.md", destination: ".ssh/authorized_keys")],
            filesToRemove: [],
            installedSkillIDs: [],
            skippedCollisions: [],
            targets: testRegistry().targets
        )

        #expect(throws: InstallerError.self) {
            try Installer(registry: testRegistry()).apply(
                plan: evilPlan, checkout: checkout.root, home: home.root, logger: nullLogger
            )
        }
        #expect(!home.exists(".ssh/authorized_keys"))
    }

    @Test("Stale entries outside allowed prefixes are skipped, not deleted")
    func removalGuard() throws {
        let (checkout, home) = try makeWorld()
        defer { checkout.cleanup(); home.cleanup() }
        try home.write("Documents/precious.txt", "do not delete")

        let evilPlan = SyncPlan(
            desiredFiles: [],
            filesToRemove: ["Documents/precious.txt", "../outside.txt"],
            installedSkillIDs: [],
            skippedCollisions: [],
            targets: testRegistry().targets
        )

        let summary = try Installer(registry: testRegistry()).apply(
            plan: evilPlan, checkout: checkout.root, home: home.root, logger: nullLogger
        )

        #expect(home.exists("Documents/precious.txt"))
        #expect(summary.removed == 0)
    }
}
