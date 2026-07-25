import Foundation

/// A tool that can receive skills and/or rules — e.g. Claude Code, Cursor.
/// All paths are relative to the user's home directory.
public struct Target: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    /// Directory that receives skills, e.g. ".claude/skills". Nil if the tool has no skills dir.
    public let skillsPath: String?
    /// Directory that receives rules, e.g. ".claude/rules". Nil if the tool has no rules dir.
    public let rulesPath: String?
    /// Existence of any of these home-relative dirs marks the tool as installed.
    public let detectionPaths: [String]
    /// Always-on targets are enabled even when not detected (the cross-tool
    /// ~/.agents standard, which any agent can read).
    public let alwaysOn: Bool

    public init(
        id: String,
        displayName: String,
        skillsPath: String?,
        rulesPath: String?,
        detectionPaths: [String],
        alwaysOn: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.skillsPath = skillsPath
        self.rulesPath = rulesPath
        self.detectionPaths = detectionPaths
        self.alwaysOn = alwaysOn
    }
}

public struct TargetRegistry: Sendable {
    public let targets: [Target]

    public init(targets: [Target] = TargetRegistry.builtinTargets) {
        self.targets = targets
    }

    /// The tools Loadout knows how to configure. Add a new tool here.
    public static let builtinTargets: [Target] = [
        Target(
            id: "agents",
            displayName: "Agents standard (Codex, Windsurf, Gemini CLI, …)",
            skillsPath: ".agents/skills",
            rulesPath: nil,
            detectionPaths: [".agents"],
            alwaysOn: true
        ),
        Target(
            id: "claude",
            displayName: "Claude Code",
            skillsPath: ".claude/skills",
            rulesPath: ".claude/rules",
            detectionPaths: [".claude"]
        ),
        Target(
            id: "cursor",
            displayName: "Cursor",
            skillsPath: ".cursor/skills",
            rulesPath: ".cursor/rules",
            detectionPaths: [".cursor"]
        ),
        Target(
            id: "opencode",
            displayName: "OpenCode",
            skillsPath: ".config/opencode/skills",
            rulesPath: nil,
            detectionPaths: [".config/opencode"]
        ),
    ]

    /// Home-relative prefixes Loadout is ever allowed to write under.
    public var allowedPrefixes: [String] {
        var prefixes: Set<String> = []
        for target in targets {
            for path in [target.skillsPath, target.rulesPath].compactMap({ $0 }) {
                prefixes.insert(path)
            }
        }
        return prefixes.sorted()
    }

    /// Targets whose detection dirs exist under `home`.
    public func detected(home: URL, fileManager: FileManager = .default) -> [Target] {
        targets.filter { target in
            target.alwaysOn || target.detectionPaths.contains { path in
                fileManager.fileExists(atPath: home.appendingPathComponent(path).path)
            }
        }
    }

    /// Effective targets after applying user overrides from settings.
    public func enabled(
        settings: AppSettings,
        home: URL,
        fileManager: FileManager = .default
    ) -> [Target] {
        let detectedIDs = Set(detected(home: home, fileManager: fileManager).map(\.id))
        return targets.filter { target in
            guard !settings.disabledTargets.contains(target.id) else { return false }
            return detectedIDs.contains(target.id) || settings.extraTargets.contains(target.id)
        }
    }
}
