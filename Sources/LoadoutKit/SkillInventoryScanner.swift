import Darwin
import Foundation

public struct SkillToolPresence: Hashable, Sendable {
    public let targetID: String
    /// Absolute live or shelf directory path.
    public let path: String
    public let isShelved: Bool
    public let isSymlink: Bool
    public let isBroken: Bool
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
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for entry in entries {
            let dirName = entry.lastPathComponent
            guard !dirName.hasPrefix("."),
                  let snapshot = snapshot(
                    for: entry,
                    targetID: targetID,
                    isShelved: isShelved
                  ) else { continue }
            grouped[dirName, default: []].append(snapshot)
        }
    }

    private func snapshot(
        for entry: URL,
        targetID: String,
        isShelved: Bool
    ) -> PresenceSnapshot? {
        guard let entryInfo = fileInfo(at: entry, followingSymlinks: false) else { return nil }
        let isSymlink = fileType(entryInfo.st_mode) == S_IFLNK

        if isSymlink {
            guard let rawTarget = try? FileManager.default.destinationOfSymbolicLink(
                atPath: entry.path
            ) else { return nil }
            let target = resolvedTarget(rawTarget, for: entry)
            guard let targetInfo = fileInfo(at: target, followingSymlinks: true) else {
                guard errno == ENOENT || errno == ENOTDIR else { return nil }
                return PresenceSnapshot(
                    presence: SkillToolPresence(
                        targetID: targetID,
                        path: entry.path,
                        isShelved: isShelved,
                        isSymlink: true,
                        isBroken: true
                    ),
                    creationDate: nil,
                    directoryModifiedAt: nil,
                    skillModifiedAt: nil,
                    skillFile: nil,
                    brokenLinkTarget: rawTarget
                )
            }
            guard fileType(targetInfo.st_mode) == S_IFDIR else { return nil }
            return readableSnapshot(
                presencePath: entry.path,
                metadataDirectory: target,
                directoryInfo: targetInfo,
                targetID: targetID,
                isShelved: isShelved,
                isSymlink: true
            )
        }

        guard fileType(entryInfo.st_mode) == S_IFDIR else { return nil }
        return readableSnapshot(
            presencePath: entry.path,
            metadataDirectory: entry,
            directoryInfo: entryInfo,
            targetID: targetID,
            isShelved: isShelved,
            isSymlink: false
        )
    }

    private func readableSnapshot(
        presencePath: String,
        metadataDirectory: URL,
        directoryInfo: stat,
        targetID: String,
        isShelved: Bool,
        isSymlink: Bool
    ) -> PresenceSnapshot {
        let skillFile = metadataDirectory.appendingPathComponent("SKILL.md")
        let skillInfo = fileInfo(at: skillFile, followingSymlinks: true)
        let readableSkillFile = skillInfo.map { fileType($0.st_mode) == S_IFREG } == true
            ? skillFile
            : nil

        return PresenceSnapshot(
            presence: SkillToolPresence(
                targetID: targetID,
                path: presencePath,
                isShelved: isShelved,
                isSymlink: isSymlink,
                isBroken: false
            ),
            creationDate: date(from: directoryInfo.st_birthtimespec),
            directoryModifiedAt: date(from: directoryInfo.st_mtimespec),
            skillModifiedAt: skillInfo.flatMap { date(from: $0.st_mtimespec) },
            skillFile: readableSkillFile,
            brokenLinkTarget: nil
        )
    }

    private func fileInfo(at url: URL, followingSymlinks: Bool) -> stat? {
        var info = stat()
        let result = url.path.withCString { path in
            followingSymlinks ? stat(path, &info) : lstat(path, &info)
        }
        return result == 0 ? info : nil
    }

    private func fileType(_ mode: mode_t) -> mode_t {
        mode & S_IFMT
    }

    private func resolvedTarget(_ rawTarget: String, for link: URL) -> URL {
        if rawTarget.hasPrefix("/") {
            return URL(fileURLWithPath: rawTarget, isDirectory: true).standardizedFileURL
        }
        return link.deletingLastPathComponent()
            .appendingPathComponent(rawTarget, isDirectory: true)
            .standardizedFileURL
    }

    private func date(from timespec: timespec) -> Date? {
        guard timespec.tv_sec > 0 else { return nil }
        return Date(
            timeIntervalSince1970: TimeInterval(timespec.tv_sec)
                + TimeInterval(timespec.tv_nsec) / 1_000_000_000
        )
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
        if let rawTarget = candidates.compactMap(\.brokenLinkTarget).first {
            return (dirName, "Broken link → \(rawTarget)", [:])
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
    let brokenLinkTarget: String?
}
