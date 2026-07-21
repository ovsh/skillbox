import Foundation
@testable import SkillboxKit

/// Temp-dir fixture builder for engine tests.
struct Fixture {
    let root: URL

    init(name: String) throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skillbox-tests-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func write(_ relativePath: String, _ content: String = "content") throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func mkdir(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(relativePath),
            withIntermediateDirectories: true
        )
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    func read(_ relativePath: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

let nullLogger: Logger = { _, _ in }

func skillMarkdown(name: String, description: String) -> String {
    """
    ---
    name: \(name)
    description: \(description)
    ---

    # \(name)

    Body.
    """
}

/// Two-target registry used across planner/installer tests: one skills+rules
/// tool and one skills-only tool.
func testRegistry() -> TargetRegistry {
    TargetRegistry(targets: [
        Target(
            id: "claude",
            displayName: "Claude Code",
            skillsPath: ".claude/skills",
            rulesPath: ".claude/rules",
            detectionPaths: [".claude"]
        ),
        Target(
            id: "agents",
            displayName: "Agents",
            skillsPath: ".agents/skills",
            rulesPath: nil,
            detectionPaths: [".agents"],
            alwaysOn: true
        ),
    ])
}

func testSettings() -> AppSettings {
    AppSettings(
        remoteGitURL: "https://github.com/example/registry.git",
        checkoutPath: "/tmp/unused",
        autoSyncEnabled: false,
        autoSyncIntervalMinutes: 60
    )
}
