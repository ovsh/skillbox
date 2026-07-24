import Foundation

// MARK: - Skills & catalog

/// A skill as discovered in a registry checkout (not necessarily installed).
public struct CatalogSkill: Identifiable, Hashable, Sendable {
    /// Qualified identity: "<space>/<dirName>", e.g. "everyone/code-review".
    public var id: String { "\(space)/\(dirName)" }
    /// Directory name of the skill — also the name of the installed folder.
    public let dirName: String
    /// Display name from SKILL.md frontmatter, falling back to dirName.
    public let name: String
    /// Description from SKILL.md frontmatter, may be empty.
    public let description: String
    /// Space folder this skill belongs to ("." for a top-level skills/ dir).
    public let space: String
    /// Path of the skill directory relative to the checkout root.
    public let relativePath: String
    /// Playground skills are opt-in; regular skills are installed by default.
    public let isPlayground: Bool

    public init(
        dirName: String,
        name: String,
        description: String,
        space: String,
        relativePath: String,
        isPlayground: Bool
    ) {
        self.dirName = dirName
        self.name = name
        self.description = description
        self.space = space
        self.relativePath = relativePath
        self.isPlayground = isPlayground
    }
}

/// A rules directory discovered in a registry checkout.
public struct CatalogRuleSet: Identifiable, Hashable, Sendable {
    public var id: String { relativePath }
    /// Space folder this rule set belongs to ("." for a top-level rules/ dir).
    public let space: String
    /// Path of the rules directory relative to the checkout root.
    public let relativePath: String

    public init(space: String, relativePath: String) {
        self.space = space
        self.relativePath = relativePath
    }
}

/// A space is a top-level folder in the registry that groups skills and rules
/// (e.g. "everyone", "engineering"). A registry with top-level skills/ and
/// rules/ dirs gets a single implicit space named ".".
public struct SpaceInfo: Identifiable, Hashable, Sendable {
    public var id: String { folderName }
    public let folderName: String
    public let displayName: String
    public let description: String
    public let hasPlayground: Bool

    public init(folderName: String, displayName: String, description: String, hasPlayground: Bool) {
        self.folderName = folderName
        self.displayName = displayName
        self.description = description
        self.hasPlayground = hasPlayground
    }
}

/// Everything Loadout knows about a registry checkout.
public struct Catalog: Sendable {
    public let spaces: [SpaceInfo]
    public let skills: [CatalogSkill]
    public let ruleSets: [CatalogRuleSet]

    public init(spaces: [SpaceInfo], skills: [CatalogSkill], ruleSets: [CatalogRuleSet]) {
        self.spaces = spaces
        self.skills = skills
        self.ruleSets = ruleSets
    }

    public static let empty = Catalog(spaces: [], skills: [], ruleSets: [])
}

// MARK: - Lockfile

/// Record of one sync: every file Loadout wrote, as home-relative paths.
/// This is what makes uninstall, prune, and previews possible.
public struct Lockfile: Codable, Sendable {
    public var version: Int
    /// Home-relative paths of every file Loadout manages, e.g.
    /// ".claude/skills/code-review/SKILL.md".
    public var files: [String]
    /// Qualified skill ids that were installed on the last sync.
    public var installedSkills: [String]
    public var lastSyncCommit: String?
    public var lastSyncAt: Date?

    public init(
        version: Int = 1,
        files: [String] = [],
        installedSkills: [String] = [],
        lastSyncCommit: String? = nil,
        lastSyncAt: Date? = nil
    ) {
        self.version = version
        self.files = files
        self.installedSkills = installedSkills
        self.lastSyncCommit = lastSyncCommit
        self.lastSyncAt = lastSyncAt
    }

    public static let empty = Lockfile()
}

// MARK: - Settings

public struct AppSettings: Codable, Equatable, Sendable {
    public var remoteGitURL: String
    public var checkoutPath: String
    public var autoSyncEnabled: Bool
    public var autoSyncIntervalMinutes: Int
    /// Qualified skill ids ("space/dirName") the user switched off.
    /// Regular skills are on by default.
    public var disabledSkills: Set<String>
    /// Qualified playground skill ids the user opted into.
    /// Playground skills are off by default.
    public var enabledPlaygroundSkills: Set<String>
    /// Target ids the user switched off (targets are otherwise auto-detected).
    public var disabledTargets: Set<String>
    /// Target ids the user force-enabled even though they weren't detected.
    public var extraTargets: Set<String>

    public init(
        remoteGitURL: String,
        checkoutPath: String,
        autoSyncEnabled: Bool,
        autoSyncIntervalMinutes: Int,
        disabledSkills: Set<String> = [],
        enabledPlaygroundSkills: Set<String> = [],
        disabledTargets: Set<String> = [],
        extraTargets: Set<String> = []
    ) {
        self.remoteGitURL = remoteGitURL
        self.checkoutPath = checkoutPath
        self.autoSyncEnabled = autoSyncEnabled
        self.autoSyncIntervalMinutes = autoSyncIntervalMinutes
        self.disabledSkills = disabledSkills
        self.enabledPlaygroundSkills = enabledPlaygroundSkills
        self.disabledTargets = disabledTargets
        self.extraTargets = extraTargets
    }

    enum CodingKeys: String, CodingKey {
        case remoteGitURL
        case checkoutPath
        case autoSyncEnabled
        case autoSyncIntervalMinutes
        case disabledSkills
        case enabledPlaygroundSkills
        case disabledTargets
        case extraTargets
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remoteGitURL = try c.decodeIfPresent(String.self, forKey: .remoteGitURL) ?? ""
        checkoutPath = try c.decodeIfPresent(String.self, forKey: .checkoutPath)
            ?? Self.defaultCheckoutPath
        autoSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoSyncEnabled) ?? true
        autoSyncIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .autoSyncIntervalMinutes) ?? 60
        disabledSkills = try c.decodeIfPresent(Set<String>.self, forKey: .disabledSkills) ?? []
        enabledPlaygroundSkills = try c.decodeIfPresent(Set<String>.self, forKey: .enabledPlaygroundSkills) ?? []
        disabledTargets = try c.decodeIfPresent(Set<String>.self, forKey: .disabledTargets) ?? []
        extraTargets = try c.decodeIfPresent(Set<String>.self, forKey: .extraTargets) ?? []
    }

    public static var defaultCheckoutPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Loadout/registry"
    }

    public static func defaults() -> AppSettings {
        AppSettings(
            remoteGitURL: "",
            checkoutPath: defaultCheckoutPath,
            autoSyncEnabled: true,
            autoSyncIntervalMinutes: 60
        )
    }
}

// MARK: - Sync status

public enum SyncStatus: Sendable {
    case idle
    case syncing
    case succeeded
    case failed
}

public enum LogLevel: String, Sendable {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

public typealias Logger = @Sendable (LogLevel, String) -> Void

// MARK: - Helpers

extension String {
    public var expandingTildePath: String {
        (self as NSString).expandingTildeInPath
    }

    public var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
