import Foundation
import Testing
@testable import SkillboxKit

@Suite("SkillShelf")
struct SkillShelfTests {
    @Test("Shelve and restore preserve nested contents")
    func roundTrip() throws {
        let fixture = try Fixture(name: "shelf-round-trip")
        defer { fixture.cleanup() }
        try fixture.write("live/example/SKILL.md", "metadata")
        try fixture.write("live/example/scripts/run.sh", "echo preserved")

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        let skillsDirectory = fixture.root.appendingPathComponent("live")

        try shelf.shelve(dirName: "example", from: skillsDirectory, targetID: "agents")

        #expect(!fixture.exists("live/example"))
        #expect(fixture.read("shelf/agents/example/SKILL.md") == "metadata")
        #expect(fixture.read("shelf/agents/example/scripts/run.sh") == "echo preserved")

        try FileManager.default.removeItem(at: skillsDirectory)
        try shelf.restore(dirName: "example", to: skillsDirectory, targetID: "agents")

        #expect(!fixture.exists("shelf/agents/example"))
        #expect(fixture.read("live/example/SKILL.md") == "metadata")
        #expect(fixture.read("live/example/scripts/run.sh") == "echo preserved")
    }

    @Test("Shelving collision preserves both folders")
    func shelvingCollision() throws {
        let fixture = try Fixture(name: "shelf-shelve-collision")
        defer { fixture.cleanup() }
        try fixture.write("live/example/SKILL.md", "live")
        try fixture.write("shelf/agents/example/SKILL.md", "shelved")

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))

        #expect(throws: SkillShelfError.self) {
            try shelf.shelve(
                dirName: "example",
                from: fixture.root.appendingPathComponent("live"),
                targetID: "agents"
            )
        }
        #expect(fixture.read("live/example/SKILL.md") == "live")
        #expect(fixture.read("shelf/agents/example/SKILL.md") == "shelved")
    }

    @Test("Restore collision preserves both folders")
    func restoreCollision() throws {
        let fixture = try Fixture(name: "shelf-restore-collision")
        defer { fixture.cleanup() }
        try fixture.write("live/example/SKILL.md", "live")
        try fixture.write("shelf/agents/example/SKILL.md", "shelved")

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))

        #expect(throws: SkillShelfError.self) {
            try shelf.restore(
                dirName: "example",
                to: fixture.root.appendingPathComponent("live"),
                targetID: "agents"
            )
        }
        #expect(fixture.read("live/example/SKILL.md") == "live")
        #expect(fixture.read("shelf/agents/example/SKILL.md") == "shelved")
    }

    @Test("Missing sources throw without disturbing other folders")
    func missingSources() throws {
        let fixture = try Fixture(name: "shelf-missing")
        defer { fixture.cleanup() }
        try fixture.write("live/kept/SKILL.md", "kept live")
        try fixture.write("shelf/agents/kept/SKILL.md", "kept shelved")

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        let skillsDirectory = fixture.root.appendingPathComponent("live")

        #expect(throws: SkillShelfError.self) {
            try shelf.shelve(dirName: "missing", from: skillsDirectory, targetID: "agents")
        }
        #expect(throws: SkillShelfError.self) {
            try shelf.restore(dirName: "missing", to: skillsDirectory, targetID: "agents")
        }
        #expect(fixture.read("live/kept/SKILL.md") == "kept live")
        #expect(fixture.read("shelf/agents/kept/SKILL.md") == "kept shelved")
    }

    @Test("Invalid directory names are rejected")
    func invalidDirectoryNames() throws {
        let fixture = try Fixture(name: "shelf-invalid-name")
        defer { fixture.cleanup() }
        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        let skillsDirectory = fixture.root.appendingPathComponent("live")

        for name in ["nested/example", ".hidden", ""] {
            #expect(throws: SkillShelfError.self) {
                try shelf.shelve(dirName: name, from: skillsDirectory, targetID: "agents")
            }
        }
    }

    @Test("Listing is sorted and includes modification dates")
    func listing() throws {
        let fixture = try Fixture(name: "shelf-listing")
        defer { fixture.cleanup() }
        try fixture.write("shelf/agents/zebra/SKILL.md")
        try fixture.write("shelf/agents/alpha/nested/file.txt")
        try fixture.write("shelf/agents/README.md")
        try fixture.write("shelf/agents/.hidden/SKILL.md")
        try fixture.write("shelf/claude/other/SKILL.md")

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        let entries = shelf.shelved(targetID: "agents")

        #expect(entries.map(\.dirName) == ["alpha", "zebra"])
        #expect(entries.allSatisfy { $0.shelvedAt != nil })
    }

    @Test("Shelving refuses valid and broken symlinks without moving them")
    func symlinksAreUntouched() throws {
        let fixture = try Fixture(name: "shelf-symlinks")
        defer { fixture.cleanup() }

        try fixture.write("targets/valid/SKILL.md", "target")
        try fixture.mkdir("live")
        let live = fixture.root.appendingPathComponent("live")
        let links = [
            (name: "valid-link", target: "../targets/valid"),
            (name: "broken-link", target: "../targets/missing"),
        ]
        for link in links {
            try FileManager.default.createSymbolicLink(
                atPath: live.appendingPathComponent(link.name).path,
                withDestinationPath: link.target
            )
        }

        let shelf = SkillShelf(rootDirectory: fixture.root.appendingPathComponent("shelf"))
        for link in links {
            do {
                try shelf.shelve(dirName: link.name, from: live, targetID: "agents")
                Issue.record("Expected shelving \(link.name) to fail")
            } catch let error as SkillShelfError {
                guard case .symlinkedSkill = error else {
                    Issue.record("Expected symlinkedSkill, got \(error)")
                    continue
                }
                #expect(
                    error.localizedDescription
                        == "Symlinked skills can't be shelved — toggle them for Claude instead."
                )
            }

            let rawTarget = try FileManager.default.destinationOfSymbolicLink(
                atPath: live.appendingPathComponent(link.name).path
            )
            #expect(rawTarget == link.target)
            #expect(!fixture.exists("shelf/agents/\(link.name)"))
        }
    }
}
