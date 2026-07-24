import Foundation
import Testing
@testable import LoadoutKit

@Suite("ClaudeSettingsStore")
struct SkillOverridesTests {
    @Test("Mutating one override preserves unknown values on other skills")
    func preservesUnrelatedSettings() throws {
        let fixture = try Fixture(name: "overrides-preserve")
        defer { fixture.cleanup() }

        let settingsURL = try fixture.write(
            ".claude/settings.json",
            """
            {
              "env": {"API_MODE": "strict", "COUNT": "3"},
              "permissions": {
                "allow": ["Bash(git:*)", "Read(**)"],
                "deny": ["Read(.env)"]
              },
              "hooks": {
                "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "check"}]}]
              },
              "statusLine": {"type": "command", "command": "status"},
              "enabledPlugins": {"example@plugin": true},
              "skillOverrides": {
                "known": "off",
                "future": "experimental-state",
                "nonString": 42
              }
            }
            """
        )
        let before = try jsonObject(at: settingsURL)

        let store = ClaudeSettingsStore(settingsFileURL: settingsURL)
        try store.setOverride(.nameOnly, forSkill: "added")

        let after = try jsonObject(at: settingsURL)
        #expect(try jsonData(removingOverridesFrom: before) == jsonData(removingOverridesFrom: after))

        let rawOverrides = try #require(after["skillOverrides"] as? [String: Any])
        #expect(rawOverrides["added"] as? String == "name-only")
        #expect(rawOverrides["known"] as? String == "off")
        #expect(rawOverrides["future"] as? String == "experimental-state")
        #expect(rawOverrides["nonString"] as? Int == 42)

        let typedOverrides = try store.overrides()
        #expect(typedOverrides == ["added": .nameOnly, "known": .off])
    }

    @Test("Raw-tree patch changes only the requested override leaf")
    func rawTreeLeafPatch() throws {
        let original = Data(
            """
            {
              "env": {"MODE": "strict"},
              "skillOverrides": {
                "known": "off",
                "future": "experimental-state"
              }
            }
            """.utf8
        )

        let patched = try ClaudeSettingsPatcher.patch(
            original,
            state: .userInvocableOnly,
            forSkill: "added",
            path: "/tmp/settings.json"
        )
        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        let overrides = try #require(object["skillOverrides"] as? [String: Any])

        #expect((object["env"] as? [String: String]) == ["MODE": "strict"])
        #expect(overrides["known"] as? String == "off")
        #expect(overrides["future"] as? String == "experimental-state")
        #expect(overrides["added"] as? String == "user-invocable-only")
    }

    @Test("Writes preserve 0600 settings permissions")
    func preservesPrivatePermissions() throws {
        let fixture = try Fixture(name: "overrides-permissions")
        defer { fixture.cleanup() }

        let settingsURL = try fixture.write(".claude/settings.json", "{\"env\": {}}")
        #expect(chmod(settingsURL.path, 0o600) == 0)

        try ClaudeSettingsStore(settingsFileURL: settingsURL)
            .setOverride(.off, forSkill: "review")

        let attributes = try FileManager.default.attributesOfItem(atPath: settingsURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test("Set, clear, and set a different state")
    func setClearAndChangeState() throws {
        let fixture = try Fixture(name: "overrides-roundtrip")
        defer { fixture.cleanup() }

        let settingsURL = try fixture.write(".claude/settings.json", "{\"env\": {\"MODE\": \"test\"}}")
        let store = ClaudeSettingsStore(settingsFileURL: settingsURL)

        try store.setOverride(.off, forSkill: "review")
        #expect(try store.overrides()["review"] == .off)

        try store.setOverride(nil, forSkill: "review")
        #expect(try store.overrides().isEmpty)
        #expect(try jsonObject(at: settingsURL)["skillOverrides"] == nil)

        try store.setOverride(.userInvocableOnly, forSkill: "review")
        #expect(try store.overrides()["review"] == .userInvocableOnly)
        #expect(try jsonObject(at: settingsURL)["env"] != nil)
    }

    @Test("Invalid JSON throws and leaves the file untouched")
    func invalidJSONIsUntouched() throws {
        let fixture = try Fixture(name: "overrides-invalid")
        defer { fixture.cleanup() }

        let settingsURL = try fixture.write(".claude/settings.json", "{ invalid json")
        let originalData = try Data(contentsOf: settingsURL)
        let store = ClaudeSettingsStore(settingsFileURL: settingsURL)

        #expect(throws: ClaudeSettingsError.self) {
            try store.setOverride(.off, forSkill: "review")
        }
        #expect(try Data(contentsOf: settingsURL) == originalData)
        #expect(!fixture.exists(".claude/settings.json.loadout.bak"))

        do {
            _ = try store.overrides()
            Issue.record("Expected invalid JSON to throw")
        } catch {
            #expect(error.localizedDescription.contains("not valid JSON"))
            #expect(error.localizedDescription.contains("was not changed"))
        }
    }

    @Test("Backup captures the original file exactly once")
    func backupCreatedOnce() throws {
        let fixture = try Fixture(name: "overrides-backup")
        defer { fixture.cleanup() }

        let original = "{\n  \"env\": {\"ORIGINAL\": \"yes\"}\n}\n"
        let settingsURL = try fixture.write(".claude/settings.json", original)
        let backupURL = fixture.root.appendingPathComponent(".claude/settings.json.loadout.bak")
        let store = ClaudeSettingsStore(settingsFileURL: settingsURL)

        try store.setOverride(.off, forSkill: "review")
        #expect(try String(contentsOf: backupURL, encoding: .utf8) == original)

        try "sentinel".write(to: backupURL, atomically: true, encoding: .utf8)
        try store.setOverride(.nameOnly, forSkill: "review")
        #expect(try String(contentsOf: backupURL, encoding: .utf8) == "sentinel")
    }

    @Test("Missing file bootstraps without ever backing up store-created content")
    func missingFileBootstrap() throws {
        let fixture = try Fixture(name: "overrides-bootstrap")
        defer { fixture.cleanup() }

        let settingsURL = fixture.root.appendingPathComponent("missing/.claude/settings.json")
        let backupURL = settingsURL.appendingPathExtension("loadout.bak")
        let store = ClaudeSettingsStore(settingsFileURL: settingsURL)
        let secondStore = ClaudeSettingsStore(settingsFileURL: settingsURL)

        #expect(try store.overrides().isEmpty)
        try store.setOverride(.off, forSkill: "review")
        #expect(FileManager.default.fileExists(atPath: settingsURL.path))
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))

        try secondStore.setOverride(.nameOnly, forSkill: "review")
        #expect(try secondStore.overrides()["review"] == .nameOnly)
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))

        let root = try jsonObject(at: settingsURL)
        #expect(Set(root.keys) == ["skillOverrides"])
        let attributes = try FileManager.default.attributesOfItem(atPath: settingsURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test("An existing backup is never overwritten")
    func existingBackupSurvivesFirstWrite() throws {
        let fixture = try Fixture(name: "overrides-existing-backup")
        defer { fixture.cleanup() }

        let settingsURL = try fixture.write(".claude/settings.json", "{\"env\": {}}")
        try fixture.write(".claude/settings.json.loadout.bak", "keep me")

        try ClaudeSettingsStore(settingsFileURL: settingsURL)
            .setOverride(.on, forSkill: "review")

        #expect(fixture.read(".claude/settings.json.loadout.bak") == "keep me")
    }

    private func jsonObject(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func jsonData(removingOverridesFrom object: [String: Any]) throws -> Data {
        var copy = object
        copy.removeValue(forKey: "skillOverrides")
        return try JSONSerialization.data(withJSONObject: copy, options: [.sortedKeys])
    }
}

@Suite("Frontmatter all fields")
struct FrontmatterAllFieldsTests {
    @Test("Returns every flat field and lets the last duplicate win")
    func allFields() {
        let content = """
        ---
        name: First
        description: "Quoted description"
        model: opus
        disable-model-invocation: 'true'
        name: Final
        ---
        model: body-value
        """

        let fields = Frontmatter.parseAllFields(content)

        #expect(fields == [
            "name": "Final",
            "description": "Quoted description",
            "model": "opus",
            "disable-model-invocation": "true",
        ])
        let metadata = Frontmatter.parseSkillMetadata(content, fallbackName: "fallback")
        #expect(metadata.name == "Final")
        #expect(metadata.description == "Quoted description")
    }

    @Test("Content without an opening fence has no fields")
    func missingFence() {
        #expect(Frontmatter.parseAllFields("name: Body only").isEmpty)
    }
}
