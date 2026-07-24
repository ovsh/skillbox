import Foundation
import Testing
@testable import LoadoutKit

@Suite("PromptFileStore")
struct PromptFilesTests {
    @Test("Discovers canonical prompts first and optional prompts only when present")
    func discoveryOrderAndExistence() throws {
        let fixture = try Fixture(name: "prompts-discovery")
        defer { fixture.cleanup() }
        let store = PromptFileStore(home: fixture.root)

        let canonical = store.discover()
        #expect(canonical.map(\.displayName) == [
            "CLAUDE.md — Claude Code",
            "AGENTS.md — Codex CLI",
        ])
        #expect(canonical.map(\.exists) == [false, false])
        #expect(canonical.map(\.path) == [
            fixture.root.appendingPathComponent(".claude/CLAUDE.md").path,
            fixture.root.appendingPathComponent(".codex/AGENTS.md").path,
        ])

        try fixture.write(".claude/CLAUDE.md", "claude")
        try fixture.write(".config/opencode/AGENTS.md", "opencode")
        try fixture.write("AGENTS.md", "generic")

        let discovered = store.discover()
        #expect(discovered.map(\.displayName) == [
            "CLAUDE.md — Claude Code",
            "AGENTS.md — Codex CLI",
            "AGENTS.md — OpenCode",
            "AGENTS.md — Generic",
        ])
        #expect(discovered.map(\.exists) == [true, false, true, true])
        #expect(discovered[0].modifiedAt != nil)
    }

    @Test("Reads and atomically writes prompt content")
    func readWriteRoundTrip() throws {
        let fixture = try Fixture(name: "prompts-roundtrip")
        defer { fixture.cleanup() }
        try fixture.write(".codex/AGENTS.md", "before")
        let store = PromptFileStore(home: fixture.root)
        let file = try #require(store.discover().first { $0.path.hasSuffix(".codex/AGENTS.md") })

        #expect(try store.read(file) == "before")
        try store.write("after\n", to: file, expectedModifiedAt: file.modifiedAt)
        #expect(try store.read(file) == "after\n")
    }

    @Test("Creates one backup and never changes its original content")
    func backupExactlyOnce() throws {
        let fixture = try Fixture(name: "prompts-backup")
        defer { fixture.cleanup() }
        try fixture.write(".claude/CLAUDE.md", "original")
        let store = PromptFileStore(home: fixture.root)
        var file = try #require(store.discover().first)

        try store.write("first", to: file, expectedModifiedAt: file.modifiedAt)
        #expect(fixture.read(".claude/CLAUDE.md.loadout.bak") == "original")

        file = try #require(store.discover().first)
        try store.write("second", to: file, expectedModifiedAt: file.modifiedAt)
        #expect(fixture.read(".claude/CLAUDE.md") == "second")
        #expect(fixture.read(".claude/CLAUDE.md.loadout.bak") == "original")
    }

    @Test("Creating a canonical prompt never backs up app-created content")
    func missingCanonicalBootstrap() throws {
        let fixture = try Fixture(name: "prompts-bootstrap")
        defer { fixture.cleanup() }
        let store = PromptFileStore(home: fixture.root)
        var file = try #require(store.discover().first)

        try store.write("created", to: file, expectedModifiedAt: file.modifiedAt)
        file = try #require(store.discover().first)
        try store.write("updated", to: file, expectedModifiedAt: file.modifiedAt)

        #expect(fixture.read(".claude/CLAUDE.md") == "updated")
        #expect(!fixture.exists(".claude/CLAUDE.md.loadout.bak"))
        let createdURL = fixture.root.appendingPathComponent(".claude/CLAUDE.md")
        let attributes = try FileManager.default.attributesOfItem(atPath: createdURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test("A stale revision throws changedOnDisk and leaves the file untouched")
    func staleRevisionIsRejected() throws {
        let fixture = try Fixture(name: "prompts-stale")
        defer { fixture.cleanup() }

        let destination = try fixture.write(".claude/CLAUDE.md", "loaded")
        let store = PromptFileStore(home: fixture.root)
        let file = try #require(store.discover().first)
        let externalModifiedAt = try #require(file.modifiedAt).addingTimeInterval(5)
        try "external".write(to: destination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: externalModifiedAt],
            ofItemAtPath: destination.path
        )

        do {
            try store.write("editor", to: file, expectedModifiedAt: file.modifiedAt)
            Issue.record("Expected changedOnDisk")
        } catch let error as PromptFileError {
            guard case .changedOnDisk(let path) = error else {
                Issue.record("Expected changedOnDisk, got \(error)")
                return
            }
            #expect(path == destination.path)
        }

        #expect(fixture.read(".claude/CLAUDE.md") == "external")
        #expect(!fixture.exists(".claude/CLAUDE.md.loadout.bak"))
    }

    @Test("A matching revision writes and preserves file permissions")
    func matchingRevisionWrites() throws {
        let fixture = try Fixture(name: "prompts-matching")
        defer { fixture.cleanup() }

        let destination = try fixture.write(".claude/CLAUDE.md", "loaded")
        #expect(chmod(destination.path, 0o640) == 0)
        let store = PromptFileStore(home: fixture.root)
        let file = try #require(store.discover().first)

        try store.write("saved", to: file, expectedModifiedAt: file.modifiedAt)

        #expect(fixture.read(".claude/CLAUDE.md") == "saved")
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o640)
    }
}
