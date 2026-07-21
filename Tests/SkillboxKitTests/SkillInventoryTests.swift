import Foundation
import Testing
@testable import SkillboxKit

@Suite("SkillInventoryScanner")
struct SkillInventoryTests {
    @Test("Merges tools, shelves, overrides, lockfile state, and dates")
    func unifiedInventory() throws {
        let fixture = try Fixture(name: "inventory-unified")
        defer { fixture.cleanup() }

        try fixture.write(
            ".agents/skills/shared/SKILL.md",
            skillMarkdown(name: "Agents Name", description: "Agents metadata")
        )
        try fixture.write(
            ".claude/skills/shared/SKILL.md",
            """
            ---
            name: Claude Name
            description: Claude metadata
            model: opus
            ---
            """
        )
        try fixture.write(
            ".cursor/skills/cursor-only/SKILL.md",
            skillMarkdown(name: "Cursor Only", description: "Cursor metadata")
        )
        try fixture.write(
            ".agents/skills/archived/SKILL.md",
            skillMarkdown(name: "Archived", description: "Shelf metadata")
        )
        try fixture.write(".claude/skills/README.md", "not a directory")
        try fixture.write(
            ".claude/skills/.hidden/SKILL.md",
            skillMarkdown(name: "Hidden", description: "Ignored")
        )

        let registry = TargetRegistry(targets: [
            Target(
                id: "agents",
                displayName: "Agents",
                skillsPath: ".agents/skills",
                rulesPath: nil,
                detectionPaths: []
            ),
            Target(
                id: "cursor",
                displayName: "Cursor",
                skillsPath: ".cursor/skills",
                rulesPath: nil,
                detectionPaths: []
            ),
            Target(
                id: "claude",
                displayName: "Claude Code",
                skillsPath: ".claude/skills",
                rulesPath: nil,
                detectionPaths: []
            ),
        ])
        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        try shelf.shelve(
            dirName: "archived",
            from: fixture.root.appendingPathComponent(".agents/skills"),
            targetID: "agents"
        )

        let settingsStore = ClaudeSettingsStore(
            settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
        )
        try settingsStore.setOverride(.userInvocableOnly, forSkill: "shared")

        let lockfileDirectory = fixture.root.appendingPathComponent("app-support")
        let lockfileStore = LockfileStore(directory: lockfileDirectory)
        try lockfileStore.save(Lockfile(installedSkills: ["everyone/shared"]))

        let skills = SkillInventoryScanner(
            registry: registry,
            shelf: shelf,
            settingsStore: settingsStore,
            lockfileStore: lockfileStore
        ).scan(home: fixture.root)

        #expect(skills.map(\.name) == ["Archived", "Claude Name", "Cursor Only"])
        #expect(skills.allSatisfy { $0.name != "Hidden" })

        let shared = try #require(skills.first { $0.dirName == "shared" })
        #expect(shared.name == "Claude Name")
        #expect(shared.description == "Claude metadata")
        #expect(shared.frontmatterFields["model"] == "opus")
        #expect(shared.presences.map(\.targetID) == ["agents", "claude"])
        #expect(shared.presences.allSatisfy { !$0.isShelved })
        #expect(shared.addedAt != nil)
        #expect(shared.touchedAt != nil)
        #expect(shared.isManagedByRegistry)
        #expect(shared.claudeOverride == .userInvocableOnly)

        let cursor = try #require(skills.first { $0.dirName == "cursor-only" })
        #expect(cursor.presences.map(\.targetID) == ["cursor"])
        #expect(!cursor.isManagedByRegistry)
        #expect(cursor.claudeOverride == nil)

        let archived = try #require(skills.first { $0.dirName == "archived" })
        let archivedPresence = try #require(archived.presences.first)
        #expect(archivedPresence.targetID == "agents")
        #expect(archivedPresence.isShelved)
        #expect(
            URL(fileURLWithPath: archivedPresence.path).resolvingSymlinksInPath()
                == fixture.root.appendingPathComponent("shelf/agents/archived").resolvingSymlinksInPath()
        )
        #expect(archived.addedAt == nil)
        #expect(archived.touchedAt != nil)
    }

    @Test("Live metadata wins over shelved Claude metadata")
    func liveMetadataPrecedesShelved() throws {
        let fixture = try Fixture(name: "inventory-live-priority")
        defer { fixture.cleanup() }

        try fixture.write(
            ".claude/skills/shared/SKILL.md",
            skillMarkdown(name: "Shelved Claude", description: "Shelved")
        )
        try fixture.write(
            ".agents/skills/shared/SKILL.md",
            skillMarkdown(name: "Live Agents", description: "Live")
        )

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        try shelf.shelve(
            dirName: "shared",
            from: fixture.root.appendingPathComponent(".claude/skills"),
            targetID: "claude"
        )
        let lockfileStore = LockfileStore(
            directory: fixture.root.appendingPathComponent("app-support")
        )
        let settingsStore = ClaudeSettingsStore(
            settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
        )

        let skills = SkillInventoryScanner(
            registry: testRegistry(),
            shelf: shelf,
            settingsStore: settingsStore,
            lockfileStore: lockfileStore
        ).scan(home: fixture.root)

        let skill = try #require(skills.first)
        #expect(skill.name == "Live Agents")
        #expect(skill.description == "Live")
        #expect(skill.presences.count == 2)
    }

    @Test("Unreadable settings do not prevent inventory scans")
    func settingsFailureIsTolerated() throws {
        let fixture = try Fixture(name: "inventory-invalid-settings")
        defer { fixture.cleanup() }

        try fixture.write(
            ".claude/skills/local/SKILL.md",
            skillMarkdown(name: "Local", description: "Still visible")
        )
        try fixture.write(".claude/settings.json", "{ invalid")

        let skills = SkillInventoryScanner(
            registry: testRegistry(),
            shelf: SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf")),
            settingsStore: ClaudeSettingsStore(
                settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
            ),
            lockfileStore: LockfileStore(
                directory: fixture.root.appendingPathComponent("app-support")
            )
        ).scan(home: fixture.root)

        let skill = try #require(skills.first)
        #expect(skill.name == "Local")
        #expect(skill.claudeOverride == nil)
    }

    @Test("Plain directories, relative symlinks, and broken symlinks are classified")
    func symlinkClassification() throws {
        let fixture = try Fixture(name: "inventory-symlinks")
        defer { fixture.cleanup() }

        let targetDirectory = fixture.root.appendingPathComponent("targets/linked")
        try fixture.write(
            "targets/linked/SKILL.md",
            skillMarkdown(name: "Linked metadata", description: "Read through target")
        )
        try fixture.write(
            ".claude/skills/plain/SKILL.md",
            skillMarkdown(name: "Plain metadata", description: "Plain directory")
        )
        let skillsDirectory = fixture.root.appendingPathComponent(".claude/skills")
        try FileManager.default.createSymbolicLink(
            atPath: skillsDirectory.appendingPathComponent("linked").path,
            withDestinationPath: "../../targets/linked"
        )
        try FileManager.default.createSymbolicLink(
            atPath: skillsDirectory.appendingPathComponent("broken").path,
            withDestinationPath: "../../targets/missing"
        )
        let expectedTargetCreatedAt = try targetDirectory.resourceValues(
            forKeys: [.creationDateKey]
        ).creationDate

        let skills = SkillInventoryScanner(
            registry: testRegistry(),
            shelf: SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf")),
            settingsStore: ClaudeSettingsStore(
                settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
            ),
            lockfileStore: LockfileStore(
                directory: fixture.root.appendingPathComponent("app-support")
            )
        ).scan(home: fixture.root)

        #expect(Set(skills.map(\.dirName)) == ["plain", "linked", "broken"])

        let plain = try #require(skills.first { $0.dirName == "plain" })
        let plainPresence = try #require(plain.presences.first)
        #expect(!plainPresence.isSymlink)
        #expect(!plainPresence.isBroken)

        let linked = try #require(skills.first { $0.dirName == "linked" })
        let linkedPresence = try #require(linked.presences.first)
        #expect(linked.name == "Linked metadata")
        #expect(linked.description == "Read through target")
        #expect(linkedPresence.isSymlink)
        #expect(!linkedPresence.isBroken)
        #expect(
            try FileManager.default.destinationOfSymbolicLink(atPath: linkedPresence.path)
                == "../../targets/linked"
        )
        let linkedAddedAt = try #require(linked.addedAt)
        let targetCreatedAt = try #require(expectedTargetCreatedAt)
        #expect(abs(linkedAddedAt.timeIntervalSince(targetCreatedAt)) < 0.000_001)
        #expect(linked.touchedAt != nil)

        let broken = try #require(skills.first { $0.dirName == "broken" })
        let brokenPresence = try #require(broken.presences.first)
        #expect(broken.name == "broken")
        #expect(broken.description == "Broken link → ../../targets/missing")
        #expect(brokenPresence.isSymlink)
        #expect(brokenPresence.isBroken)
        #expect(broken.addedAt == nil)
        #expect(broken.touchedAt == nil)
    }
}
