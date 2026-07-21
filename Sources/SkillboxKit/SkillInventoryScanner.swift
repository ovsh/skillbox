import Foundation

public struct SkillToolPresence: Hashable, Sendable {
    public let targetID: String
    /// Absolute live or shelf directory path.
    public let path: String
    public let isShelved: Bool
}

public struct InstalledSkill: Identifiable, Sendable {
    public var id: String { dirName }
    public let dirName: String
    public let name: String
    public let description: String
    public let frontmatterFields: [String: String]
    public let presences: [SkillToolPresence]
    public let addedAt: Date?
    public let touchedAt: Date?
    public let isManagedByRegistry: Bool
    public let claudeOverride: SkillOverrideState?
}

/// Builds one local inventory across every configured tool and its shelf.
public struct SkillInventoryScanner: Sendable {
    private let registry: TargetRegistry
    private let shelf: SkillShelf
    private let settingsStore: ClaudeSettingsStore
    private let lockfileStore: LockfileStore

    public init(
        registry: TargetRegistry,
        shelf: SkillShelf,
        settingsStore: ClaudeSettingsStore,
        lockfileStore: LockfileStore
    ) {
        self.registry = registry
        self.shelf = shelf
        self.settingsStore = settingsStore
        self.lockfileStore = lockfileStore
    }

    /// Scans local directories only. Individual unreadable roots or files are
    /// skipped so one damaged tool installation cannot hide the rest.
    public func scan(home: URL) -> [InstalledSkill] {
        let overrides = (try? settingsStore.overrides()) ?? [:]
        let managedNames = Set(lockfileStore.load().installedSkills.compactMap { id in
            id.split(separator: "/").last.map(String.init)
        })

        var grouped: [String: [PresenceSnapshot]] = [:]
        for target in registry.targets {
            if let skillsPath = target.skillsPath {
                appendSnapshots(
                    at: home.appendingPathComponent(skillsPath, isDirectory: true),
                    targetID: target.id,
                    isShelved: false,
                    to: &grouped
                )
            }
            appendSnapshots(
                at: shelf.targetDirectory(for: target.id),
                targetID: target.id,
                isShelved: true,
                to: &grouped
            )
        }

        return grouped.map { dirName, snapshots in
            let metadata = metadata(for: dirName, snapshots: snapshots)
            let presences = snapshots.map(\.presence).sorted {
                if $0.targetID != $1.targetID { return $0.targetID < $1.targetID }
                if $0.isShelved != $1.isShelved { return !$0.isShelved }
                return $0.path < $1.path
            }
            let addedAt = snapshots
                .filter { !$0.presence.isShelved }
                .compactMap(\.creationDate)
                .min()
            let touchedAt = snapshots.flatMap { snapshot in
                [snapshot.directoryModifiedAt, snapshot.skillModifiedAt].compactMap { $0 }
            }.max()

            return InstalledSkill(
                dirName: dirName,
                name: metadata.name,
                description: metadata.description,
                frontmatterFields: metadata.fields,
                presences: presences,
                addedAt: addedAt,
                touchedAt: touchedAt,
                isManagedByRegistry: managedNames.contains(dirName),
                claudeOverride: overrides[dirName]
            )
        }
        .sorted {
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            return comparison == .orderedSame ? $0.dirName < $1.dirName : comparison == .orderedAscending
        }
    }

    private func appendSnapshots(
        at parent: URL,
        targetID: String,
        isShelved: Bool,
        to grouped: inout [String: [PresenceSnapshot]]
    ) {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .creationDateKey,
            .contentModificationDateKey,
        ]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        for entry in entries {
            let dirName = entry.lastPathComponent
            guard !dirName.hasPrefix("."),
                  let values = try? entry.resourceValues(forKeys: keys),
                  values.isDirectory == true else { continue }

            let skillFile = entry.appendingPathComponent("SKILL.md")
            let skillKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
            let skillValues = try? skillFile.resourceValues(forKeys: skillKeys)
            let readableSkillFile = skillValues?.isRegularFile == true ? skillFile : nil

            let snapshot = PresenceSnapshot(
                presence: SkillToolPresence(
                    targetID: targetID,
                    path: entry.path,
                    isShelved: isShelved
                ),
                creationDate: values.creationDate,
                directoryModifiedAt: values.contentModificationDate,
                skillModifiedAt: skillValues?.contentModificationDate,
                skillFile: readableSkillFile
            )
            grouped[dirName, default: []].append(snapshot)
        }
    }

    private func metadata(
        for dirName: String,
        snapshots: [PresenceSnapshot]
    ) -> (name: String, description: String, fields: [String: String]) {
        let candidates = snapshots.sorted(by: metadataPrecedes)
        for candidate in candidates {
            guard let skillFile = candidate.skillFile,
                  let head = Frontmatter.readHead(of: skillFile.path) else { continue }
            let fields = Frontmatter.parseAllFields(head)
            let metadata = Frontmatter.parseSkillMetadata(head, fallbackName: dirName)
            return (
                metadata.name,
                metadata.description,
                fields
            )
        }
        return (dirName, "", [:])
    }

    private func metadataPrecedes(_ lhs: PresenceSnapshot, _ rhs: PresenceSnapshot) -> Bool {
        if lhs.presence.isShelved != rhs.presence.isShelved {
            return !lhs.presence.isShelved
        }
        let lhsIsClaude = lhs.presence.targetID == "claude"
        let rhsIsClaude = rhs.presence.targetID == "claude"
        if lhsIsClaude != rhsIsClaude { return lhsIsClaude }
        if lhs.presence.targetID != rhs.presence.targetID {
            return lhs.presence.targetID < rhs.presence.targetID
        }
        return lhs.presence.path < rhs.presence.path
    }
}

private struct PresenceSnapshot {
    let presence: SkillToolPresence
    let creationDate: Date?
    let directoryModifiedAt: Date?
    let skillModifiedAt: Date?
    let skillFile: URL?
}
