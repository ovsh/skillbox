import Darwin
import Foundation

public enum SkillShelfError: LocalizedError, Sendable {
    case invalidDirectoryName(String)
    case sourceMissing(String)
    case sourceNotDirectory(String)
    case destinationExists(String)
    case crossVolume(source: String, destination: String)
    case moveFailed(source: String, destination: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidDirectoryName(let name):
            return "Skill directory name '\(name)' must not be empty, start with '.', or contain '/'."
        case .sourceMissing(let path):
            return "Skill folder not found at \(path). Refresh the skill list and try again."
        case .sourceNotDirectory(let path):
            return "The item at \(path) is not a skill folder and cannot be moved."
        case .destinationExists(let path):
            return "A skill folder already exists at \(path). Move or rename it before trying again."
        case .crossVolume(let source, let destination):
            return "Cannot move \(source) to \(destination) because they are on different volumes."
        case .moveFailed(let source, let destination, let reason):
            return "Could not move \(source) to \(destination): \(reason)."
        }
    }
}

/// Losslessly deactivates skills by moving their folders to a per-tool shelf.
public struct SkillShelf: Sendable {
    private let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    /// Moves a live skill to its target shelf with one same-volume rename.
    public func shelve(dirName: String, from skillsDir: URL, targetID: String) throws {
        try validate(dirName)
        let source = skillsDir.appendingPathComponent(dirName, isDirectory: true)
        let destination = targetDirectory(for: targetID)
            .appendingPathComponent(dirName, isDirectory: true)
        try moveDirectory(from: source, to: destination)
    }

    /// Restores a shelved skill without replacing an existing live folder.
    public func restore(dirName: String, to skillsDir: URL, targetID: String) throws {
        try validate(dirName)
        let source = targetDirectory(for: targetID)
            .appendingPathComponent(dirName, isDirectory: true)
        let destination = skillsDir.appendingPathComponent(dirName, isDirectory: true)
        try moveDirectory(from: source, to: destination)
    }

    /// Lists shelved directory names and their directory modification dates.
    public func shelved(targetID: String) -> [(dirName: String, shelvedAt: Date?)] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: targetDirectory(for: targetID),
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { entry in
            guard let values = try? entry.resourceValues(forKeys: keys),
                  values.isDirectory == true else { return nil }
            return (entry.lastPathComponent, values.contentModificationDate)
        }
        .sorted { $0.0 < $1.0 }
    }

    func targetDirectory(for targetID: String) -> URL {
        rootDirectory.appendingPathComponent(targetID, isDirectory: true)
    }

    private func validate(_ dirName: String) throws {
        guard !dirName.isEmpty, !dirName.hasPrefix("."), !dirName.contains("/") else {
            throw SkillShelfError.invalidDirectoryName(dirName)
        }
    }

    private func moveDirectory(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw SkillShelfError.sourceMissing(source.path)
        }
        guard isDirectory.boolValue else {
            throw SkillShelfError.sourceNotDirectory(source.path)
        }
        if fileManager.fileExists(atPath: destination.path) {
            throw SkillShelfError.destinationExists(destination.path)
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let result = source.path.withCString { sourcePath in
            destination.path.withCString { destinationPath in
                Darwin.renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            switch errno {
            case EEXIST:
                throw SkillShelfError.destinationExists(destination.path)
            case ENOENT:
                throw SkillShelfError.sourceMissing(source.path)
            case EXDEV:
                throw SkillShelfError.crossVolume(
                    source: source.path,
                    destination: destination.path
                )
            default:
                let reason = String(cString: strerror(errno))
                throw SkillShelfError.moveFailed(
                    source: source.path,
                    destination: destination.path,
                    reason: reason
                )
            }
        }
    }
}
