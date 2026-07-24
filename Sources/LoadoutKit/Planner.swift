import Foundation

/// One file the next sync wants on disk.
public struct DesiredFile: Hashable, Sendable {
    /// Path relative to the checkout root, e.g. "everyone/skills/foo/SKILL.md".
    public let source: String
    /// Path relative to home, e.g. ".claude/skills/foo/SKILL.md".
    public let destination: String
}

/// Full reconciliation plan: what to write, and which previously-installed
/// files are now stale and get removed.
public struct SyncPlan: Sendable {
    public let desiredFiles: [DesiredFile]
    /// Home-relative paths from the lockfile that no desired file claims.
    public let filesToRemove: [String]
    /// Qualified ids of the skills included in this plan.
    public let installedSkillIDs: [String]
    /// Skills skipped because another space already provides the same dirName.
    public let skippedCollisions: [CatalogSkill]
    /// Targets this plan writes to.
    public let targets: [Target]
}

public struct Planner: Sendable {
    public init() {}

    /// A skill is included when it's a regular skill the user hasn't disabled,
    /// or a playground skill the user opted into.
    public static func isSkillEnabled(_ skill: CatalogSkill, settings: AppSettings) -> Bool {
        if skill.isPlayground {
            return settings.enabledPlaygroundSkills.contains(skill.id)
        }
        return !settings.disabledSkills.contains(skill.id)
    }

    public func plan(
        catalog: Catalog,
        settings: AppSettings,
        targets: [Target],
        lockfile: Lockfile,
        checkout: URL,
        logger: Logger
    ) -> SyncPlan {
        var desired: [DesiredFile] = []
        var desiredDestinations = Set<String>()
        var installedSkillIDs: [String] = []
        var skippedCollisions: [CatalogSkill] = []

        // Installed folder names are flat per tool, so a dirName can only be
        // provided by one space. Catalog order (implicit space, everyone,
        // then alphabetical) decides the winner.
        var claimedDirNames = Set<String>()

        let skillTargets = targets.filter { $0.skillsPath != nil }
        let ruleTargets = targets.filter { $0.rulesPath != nil }

        for skill in catalog.skills where Self.isSkillEnabled(skill, settings: settings) {
            guard claimedDirNames.insert(skill.dirName).inserted else {
                skippedCollisions.append(skill)
                logger(.warn, "Skipping \(skill.id): another space already provides '\(skill.dirName)'")
                continue
            }

            let files = enumerateFiles(
                under: checkout.appendingPathComponent(skill.relativePath),
                relativePrefix: skill.relativePath
            )
            guard !files.isEmpty else {
                logger(.warn, "Skipping \(skill.id): skill directory is empty")
                continue
            }

            installedSkillIDs.append(skill.id)
            for target in skillTargets {
                guard let skillsPath = target.skillsPath else { continue }
                for file in files {
                    let relativeToSkill = String(file.dropFirst(skill.relativePath.count + 1))
                    let destination = "\(skillsPath)/\(skill.dirName)/\(relativeToSkill)"
                    if desiredDestinations.insert(destination).inserted {
                        desired.append(DesiredFile(source: file, destination: destination))
                    }
                }
            }
        }

        for ruleSet in catalog.ruleSets {
            let files = enumerateFiles(
                under: checkout.appendingPathComponent(ruleSet.relativePath),
                relativePrefix: ruleSet.relativePath
            )
            for target in ruleTargets {
                guard let rulesPath = target.rulesPath else { continue }
                for file in files {
                    let relativeToRules = String(file.dropFirst(ruleSet.relativePath.count + 1))
                    let destination = "\(rulesPath)/\(relativeToRules)"
                    if desiredDestinations.insert(destination).inserted {
                        desired.append(DesiredFile(source: file, destination: destination))
                    } else {
                        logger(.warn, "Rules collision: \(ruleSet.relativePath)/\(relativeToRules) already provided by another space")
                    }
                }
            }
        }

        let filesToRemove = lockfile.files
            .filter { !desiredDestinations.contains($0) }
            .sorted()

        return SyncPlan(
            desiredFiles: desired,
            filesToRemove: filesToRemove,
            installedSkillIDs: installedSkillIDs,
            skippedCollisions: skippedCollisions,
            targets: targets
        )
    }

    // MARK: - Private

    private static let ignoredNames: Set<String> = [".DS_Store", ".git", ".gitkeep"]

    /// All regular files under `directory`, as checkout-relative paths.
    private func enumerateFiles(under directory: URL, relativePrefix: String) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let rootPath = directory.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var files: [String] = []

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if Self.ignoredNames.contains(name) {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { enumerator.skipDescendants() }
                continue
            }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard !isDir else { continue }

            let full = url.standardizedFileURL.path
            guard full.hasPrefix(prefix) else { continue }
            files.append("\(relativePrefix)/\(String(full.dropFirst(prefix.count)))")
        }
        return files.sorted()
    }
}
