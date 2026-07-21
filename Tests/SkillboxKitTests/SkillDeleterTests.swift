import Foundation
import Testing
@testable import SkillboxKit

@Suite("SkillDeleter")
struct SkillDeleterTests {
    private func makeSkill(dirName: String, presences: [SkillToolPresence]) -> InstalledSkill {
        InstalledSkill(
            dirName: dirName,
            name: dirName,
            description: "",
            frontmatterFields: [:],
            presences: presences,
            addedAt: nil,
            touchedAt: nil,
            isManagedByRegistry: false,
            claudeOverride: .off
        )
    }

    @Test("Real directory leaves its original location; symlink target survives")
    func deleteMixedPresences() throws {
        let fixture = try Fixture(name: "deleter-mixed")
        defer { fixture.cleanup() }

        // Real skill folder in "claude", symlink to a shared target in "agents".
        try fixture.write(".claude/skills/doomed/SKILL.md", skillMarkdown(name: "Doomed", description: "x"))
        try fixture.write("shared/target/SKILL.md", skillMarkdown(name: "Target", description: "kept"))
        let linkDir = fixture.root.appendingPathComponent(".agents/skills")
        try FileManager.default.createDirectory(at: linkDir, withIntermediateDirectories: true)
        let link = linkDir.appendingPathComponent("doomed")
        try FileManager.default.createSymbolicLink(
            atPath: link.path, withDestinationPath: "../../shared/target"
        )

        let claudePath = fixture.root.appendingPathComponent(".claude/skills/doomed").path
        let skill = makeSkill(dirName: "doomed", presences: [
            SkillToolPresence(targetID: "claude", path: claudePath, isShelved: false, isSymlink: false, isBroken: false),
            SkillToolPresence(targetID: "agents", path: link.path, isShelved: false, isSymlink: true, isBroken: false),
        ])

        let settings = ClaudeSettingsStore(
            settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
        )
        try settings.setOverride(.off, forSkill: "doomed")

        let deletions = try SkillDeleter(settingsStore: settings).delete(skill)

        let fm = FileManager.default
        #expect(deletions.count == 2)
        #expect(!fm.fileExists(atPath: claudePath))
        // The link is gone but its target is untouched.
        #expect((try? fm.destinationOfSymbolicLink(atPath: link.path)) == nil)
        #expect(fm.fileExists(atPath: fixture.root.appendingPathComponent("shared/target/SKILL.md").path))
        // Override entry cleared.
        #expect(try settings.overrides()["doomed"] == nil)
    }

    @Test("Nothing on disk throws nothingToDelete")
    func deleteMissing() throws {
        let fixture = try Fixture(name: "deleter-missing")
        defer { fixture.cleanup() }
        let settings = ClaudeSettingsStore(
            settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
        )
        let skill = makeSkill(dirName: "ghost", presences: [
            SkillToolPresence(
                targetID: "claude",
                path: fixture.root.appendingPathComponent(".claude/skills/ghost").path,
                isShelved: false, isSymlink: false, isBroken: false
            ),
        ])
        #expect(throws: SkillDeleteError.self) {
            try SkillDeleter(settingsStore: settings).delete(skill)
        }
    }

    @Test("Broken symlink is removed as a link")
    func deleteBrokenLink() throws {
        let fixture = try Fixture(name: "deleter-broken")
        defer { fixture.cleanup() }
        let dir = fixture.root.appendingPathComponent(".cursor/skills")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent("dangling")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../../nowhere")

        let settings = ClaudeSettingsStore(
            settingsFileURL: fixture.root.appendingPathComponent(".claude/settings.json")
        )
        let skill = makeSkill(dirName: "dangling", presences: [
            SkillToolPresence(targetID: "cursor", path: link.path, isShelved: false, isSymlink: true, isBroken: true),
        ])

        let deletions = try SkillDeleter(settingsStore: settings).delete(skill)
        #expect(deletions.count == 1 && deletions[0].wasLink)
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == nil)
    }
}
