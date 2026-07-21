import Foundation

public enum SkillDeleteError: LocalizedError, Sendable {
    case nothingToDelete(skill: String)
    case partialFailure(skill: String, failures: [String])

    public var errorDescription: String? {
        switch self {
        case .nothingToDelete(let skill):
            return "\(skill) has no files on disk to delete."
        case .partialFailure(let skill, let failures):
            return "Deleting \(skill) partly failed: \(failures.joined(separator: "; "))"
        }
    }
}

/// The outcome of one presence's removal, for honest reporting.
public struct SkillDeletion: Sendable {
    public let path: String
    /// True when a symlink was removed (target untouched); false when a real
    /// folder was moved to the Trash.
    public let wasLink: Bool
}

/// Deletes a skill from disk. The contract:
/// - Real directories move to the **Trash** — never unlinked in place.
/// - Symlinks: only the link is removed; the target is never followed.
/// - The skill's `skillOverrides` entry is cleared afterwards so a future
///   skill with the same name starts fresh.
public struct SkillDeleter: Sendable {
    private let settingsStore: ClaudeSettingsStore

    public init(settingsStore: ClaudeSettingsStore) {
        self.settingsStore = settingsStore
    }

    @discardableResult
    public func delete(_ skill: InstalledSkill) throws -> [SkillDeletion] {
        let fm = FileManager.default
        var deletions: [SkillDeletion] = []
        var failures: [String] = []

        for presence in skill.presences {
            let url = URL(fileURLWithPath: presence.path)
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            let isLink = presence.isSymlink || values?.isSymbolicLink == true

            do {
                if isLink {
                    // Remove the link itself. trashItem would also work, but
                    // removeItem is unambiguous about not touching the target.
                    try fm.removeItem(at: url)
                    deletions.append(SkillDeletion(path: presence.path, wasLink: true))
                } else if fm.fileExists(atPath: presence.path) {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                    deletions.append(SkillDeletion(path: presence.path, wasLink: false))
                }
                // Already gone: nothing to record, not an error.
            } catch {
                failures.append("\(presence.path): \(error.localizedDescription)")
            }
        }

        guard failures.isEmpty else {
            throw SkillDeleteError.partialFailure(skill: skill.name, failures: failures)
        }
        guard !deletions.isEmpty else {
            throw SkillDeleteError.nothingToDelete(skill: skill.name)
        }

        // Clear the override entry; a stale "off" shouldn't haunt a reinstall.
        // Best-effort: the files are already gone, so don't fail the delete
        // over a settings hiccup — the scanner tolerates orphan entries.
        try? settingsStore.setOverride(nil, forSkill: skill.dirName)

        return deletions
    }
}
