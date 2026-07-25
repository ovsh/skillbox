import Foundation

/// A skill folder found in a tool's skills directory that Loadout does not
/// manage — created by the user or another tool.
public struct LocalSkill: Identifiable, Hashable, Sendable {
    /// Identity is the absolute directory path.
    public var id: String { path }
    public let dirName: String
    public let name: String
    public let description: String
    /// Absolute path of the skill directory.
    public let path: String
    /// Target ids whose skills dir contains this folder name.
    public let targetIDs: [String]
}

/// Finds unmanaged (local) skills across all target skills directories.
public struct LocalSkillScanner: Sendable {
    private let registry: TargetRegistry

    public init(registry: TargetRegistry) {
        self.registry = registry
    }

    public func scan(home: URL, lockfile: Lockfile) -> [LocalSkill] {
        let fileManager = FileManager.default

        // Skill dir names the lockfile manages, per skills root.
        var managedDirNames = Set<String>()
        for file in lockfile.files {
            for target in registry.targets {
                guard let skillsPath = target.skillsPath,
                      file.hasPrefix("\(skillsPath)/") else { continue }
                let remainder = file.dropFirst(skillsPath.count + 1)
                if let dirName = remainder.split(separator: "/").first {
                    managedDirNames.insert(String(dirName))
                }
            }
        }

        var found: [String: (path: String, targets: [String])] = [:]
        for target in registry.targets {
            guard let skillsPath = target.skillsPath else { continue }
            let root = home.appendingPathComponent(skillsPath)
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                let dirName = entry.lastPathComponent
                guard !managedDirNames.contains(dirName) else { continue }

                if var existing = found[dirName] {
                    existing.targets.append(target.id)
                    found[dirName] = existing
                } else {
                    found[dirName] = (entry.path, [target.id])
                }
            }
        }

        return found
            .map { dirName, info in
                let head = Frontmatter.readHead(of: "\(info.path)/SKILL.md") ?? ""
                let metadata = Frontmatter.parseSkillMetadata(head, fallbackName: dirName)
                return LocalSkill(
                    dirName: dirName,
                    name: metadata.name,
                    description: metadata.description,
                    path: info.path,
                    targetIDs: info.targets
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
