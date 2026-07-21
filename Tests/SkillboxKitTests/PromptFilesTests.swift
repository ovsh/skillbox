import Foundation
import Testing
@testable import SkillboxKit

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
        try store.write("after\n", to: file)
        #expect(try store.read(file) == "after\n")
    }

    @Test("Creates one backup and never changes its original content")
    func backupExactlyOnce() throws {
        let fixture = try Fixture(name: "prompts-backup")
        defer { fixture.cleanup() }
        try fixture.write(".claude/CLAUDE.md", "original")
        let store = PromptFileStore(home: fixture.root)
        let file = try #require(store.discover().first)

        try store.write("first", to: file)
        #expect(fixture.read(".claude/CLAUDE.md.skillbox.bak") == "original")

        try store.write("second", to: file)
        #expect(fixture.read(".claude/CLAUDE.md") == "second")
        #expect(fixture.read(".claude/CLAUDE.md.skillbox.bak") == "original")
    }

    @Test("Creating a canonical prompt never backs up app-created content")
    func missingCanonicalBootstrap() throws {
        let fixture = try Fixture(name: "prompts-bootstrap")
        defer { fixture.cleanup() }
        let store = PromptFileStore(home: fixture.root)
        let file = try #require(store.discover().first)

        try store.write("created", to: file)
        try store.write("updated", to: file)

        #expect(fixture.read(".claude/CLAUDE.md") == "updated")
        #expect(!fixture.exists(".claude/CLAUDE.md.skillbox.bak"))
    }
}
