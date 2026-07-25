import Foundation
import Testing
@testable import LoadoutKit

@Suite("Planner")
struct PlannerTests {
    private func makeCheckout() throws -> Fixture {
        let fixture = try Fixture(name: "planner")
        try fixture.write("everyone/skills/alpha/SKILL.md", skillMarkdown(name: "Alpha", description: "A"))
        try fixture.write("everyone/skills/alpha/scripts/run.sh", "echo hi")
        try fixture.write("everyone/rules/team.md", "be kind")
        try fixture.write("everyone/playground/skills/beta/SKILL.md", skillMarkdown(name: "Beta", description: "B"))
        return fixture
    }

    private func plan(
        fixture: Fixture,
        settings: AppSettings,
        lockfile: Lockfile = .empty
    ) throws -> SyncPlan {
        let catalog = try CatalogScanner().scan(checkout: fixture.root)
        return Planner().plan(
            catalog: catalog,
            settings: settings,
            targets: testRegistry().targets,
            lockfile: lockfile,
            checkout: fixture.root,
            logger: nullLogger
        )
    }

    @Test("Skills fan out to all skill targets, rules only to rule targets")
    func fanOut() throws {
        let fixture = try makeCheckout()
        defer { fixture.cleanup() }

        let result = try plan(fixture: fixture, settings: testSettings())
        let destinations = Set(result.desiredFiles.map(\.destination))

        #expect(destinations.contains(".claude/skills/alpha/SKILL.md"))
        #expect(destinations.contains(".claude/skills/alpha/scripts/run.sh"))
        #expect(destinations.contains(".agents/skills/alpha/SKILL.md"))
        #expect(destinations.contains(".claude/rules/team.md"))
        // agents target has no rulesPath
        #expect(!destinations.contains(".agents/rules/team.md"))
        // playground not opted in
        #expect(!destinations.contains(".claude/skills/beta/SKILL.md"))
        #expect(result.installedSkillIDs == ["everyone/alpha"])
    }

    @Test("Disabled skills are excluded; opted-in playground skills included")
    func selection() throws {
        let fixture = try makeCheckout()
        defer { fixture.cleanup() }

        var settings = testSettings()
        settings.disabledSkills = ["everyone/alpha"]
        settings.enabledPlaygroundSkills = ["everyone/beta"]

        let result = try plan(fixture: fixture, settings: settings)
        let destinations = Set(result.desiredFiles.map(\.destination))

        #expect(!destinations.contains(".claude/skills/alpha/SKILL.md"))
        #expect(destinations.contains(".claude/skills/beta/SKILL.md"))
        #expect(result.installedSkillIDs == ["everyone/beta"])
    }

    @Test("dirName collisions across spaces: first space wins")
    func collision() throws {
        let fixture = try makeCheckout()
        defer { fixture.cleanup() }
        try fixture.write("zeta/skills/alpha/SKILL.md", skillMarkdown(name: "Alpha Clone", description: "dup"))

        let result = try plan(fixture: fixture, settings: testSettings())

        #expect(result.installedSkillIDs == ["everyone/alpha"])
        #expect(result.skippedCollisions.map(\.id) == ["zeta/alpha"])

        // Winner's content is the one installed
        let alphaSources = result.desiredFiles
            .filter { $0.destination == ".claude/skills/alpha/SKILL.md" }
            .map(\.source)
        #expect(alphaSources == ["everyone/skills/alpha/SKILL.md"])
    }

    @Test("Lockfile entries not desired anymore are marked for removal")
    func staleRemoval() throws {
        let fixture = try makeCheckout()
        defer { fixture.cleanup() }

        let lockfile = Lockfile(
            files: [
                ".claude/skills/alpha/SKILL.md",           // still desired
                ".claude/skills/removed-skill/SKILL.md",   // gone from catalog
                ".agents/skills/removed-skill/SKILL.md",
            ],
            installedSkills: ["everyone/alpha", "everyone/removed-skill"]
        )

        let result = try plan(fixture: fixture, settings: testSettings(), lockfile: lockfile)

        #expect(result.filesToRemove == [
            ".agents/skills/removed-skill/SKILL.md",
            ".claude/skills/removed-skill/SKILL.md",
        ])
    }

    @Test("Disabling a target removes its lockfile entries and adds nothing")
    func targetDisabled() throws {
        let fixture = try makeCheckout()
        defer { fixture.cleanup() }

        let catalog = try CatalogScanner().scan(checkout: fixture.root)
        let claudeOnly = testRegistry().targets.filter { $0.id == "claude" }
        let lockfile = Lockfile(files: [".agents/skills/alpha/SKILL.md"])

        let result = Planner().plan(
            catalog: catalog,
            settings: testSettings(),
            targets: claudeOnly,
            lockfile: lockfile,
            checkout: fixture.root,
            logger: nullLogger
        )

        #expect(result.filesToRemove == [".agents/skills/alpha/SKILL.md"])
        #expect(!result.desiredFiles.contains { $0.destination.hasPrefix(".agents/") })
    }
}
