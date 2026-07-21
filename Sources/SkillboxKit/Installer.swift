import Foundation

public struct InstallSummary: Sendable {
    public var added: Int
    public var updated: Int
    public var removed: Int
    public var managedFileCount: Int
}

public enum InstallerError: LocalizedError {
    case sourceMissing(String)
    case destinationEscapesHome(String)
    case destinationOutsideAllowedScopes(String)
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sourceMissing(let path):
            return "Source file disappeared during sync: \(path)"
        case .destinationEscapesHome(let path):
            return "Destination escapes home directory: \(path)"
        case .destinationOutsideAllowedScopes(let path):
            return "Destination must be under a supported agent directory. Invalid path: \(path)"
        case .copyFailed(let reason):
            return "Failed applying sync plan: \(reason)"
        }
    }
}

/// Applies a SyncPlan: writes every desired file, deletes stale managed files,
/// and prunes directories that emptied out. Never touches a path outside the
/// registry's allowed prefixes, and never deletes a file the lockfile doesn't own.
public struct Installer: Sendable {
    private let registry: TargetRegistry

    public init(registry: TargetRegistry) {
        self.registry = registry
    }

    public func apply(
        plan: SyncPlan,
        checkout: URL,
        home: URL,
        logger: Logger
    ) throws -> InstallSummary {
        let fileManager = FileManager.default
        var summary = InstallSummary(added: 0, updated: 0, removed: 0, managedFileCount: plan.desiredFiles.count)

        for file in plan.desiredFiles {
            let source = checkout.appendingPathComponent(file.source).standardizedFileURL
            guard fileManager.fileExists(atPath: source.path) else {
                throw InstallerError.sourceMissing(source.path)
            }

            let destination = home.appendingPathComponent(file.destination).standardizedFileURL
            try ensureDestinationAllowed(home: home, destination: destination)

            do {
                let parent = destination.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: parent.path) {
                    try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                    summary.updated += 1
                } else {
                    summary.added += 1
                }
                try fileManager.copyItem(at: source, to: destination)
            } catch let error as InstallerError {
                throw error
            } catch {
                throw InstallerError.copyFailed(error.localizedDescription)
            }
        }

        for stale in plan.filesToRemove {
            let target = home.appendingPathComponent(stale).standardizedFileURL
            // A path that fails the guard was never legitimately installed by
            // us — skip it rather than failing the whole sync.
            guard (try? ensureDestinationAllowed(home: home, destination: target)) != nil else {
                logger(.warn, "Refusing to remove path outside managed scopes: \(stale)")
                continue
            }
            if fileManager.fileExists(atPath: target.path) {
                try? fileManager.removeItem(at: target)
                summary.removed += 1
                logger(.info, "Removed stale file ~/\(stale)")
            }
            pruneEmptyParents(of: target, homeRelativePath: stale, home: home, fileManager: fileManager)
        }

        return summary
    }

    // MARK: - Private

    /// Deletes now-empty parent directories, walking up but never past the
    /// allowed prefix root (e.g. never removes ".claude/skills" itself).
    private func pruneEmptyParents(
        of file: URL,
        homeRelativePath: String,
        home: URL,
        fileManager: FileManager
    ) {
        guard let prefix = registry.allowedPrefixes.first(where: {
            homeRelativePath.hasPrefix("\($0)/")
        }) else { return }

        let prefixRoot = home.appendingPathComponent(prefix).standardizedFileURL.path
        var current = file.deletingLastPathComponent()

        while current.standardizedFileURL.path != prefixRoot,
              current.standardizedFileURL.path.hasPrefix(prefixRoot) {
            let contents = (try? fileManager.contentsOfDirectory(atPath: current.path)) ?? []
            let meaningful = contents.filter { $0 != ".DS_Store" }
            guard meaningful.isEmpty else { return }
            try? fileManager.removeItem(at: current)
            current = current.deletingLastPathComponent()
        }
    }

    private func ensureDestinationAllowed(home: URL, destination: URL) throws {
        let homePath = home.path.hasSuffix("/") ? home.path : home.path + "/"
        let destinationPath = destination.path

        guard destinationPath.hasPrefix(homePath) else {
            throw InstallerError.destinationEscapesHome(destinationPath)
        }

        let relativePath = String(destinationPath.dropFirst(homePath.count))
        let isAllowed = registry.allowedPrefixes.contains { prefix in
            relativePath.hasPrefix("\(prefix)/")
        }
        guard isAllowed else {
            throw InstallerError.destinationOutsideAllowedScopes(destinationPath)
        }
    }
}
