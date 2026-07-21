import Foundation

public struct PromptFile: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let displayName: String
    /// Absolute candidate file path.
    public let path: String
    public let exists: Bool
    public let modifiedAt: Date?
}

public enum PromptFileError: LocalizedError, Sendable {
    case changedOnDisk(path: String)

    public var errorDescription: String? {
        switch self {
        case .changedOnDisk(let path):
            return "The prompt file at \(path) changed on disk. Reload it before saving."
        }
    }
}

/// Discovers and safely edits global agent prompt files.
public struct PromptFileStore: Sendable {
    private static let backupLedger = PromptBackupLedger()
    private let home: URL

    public init(home: URL) {
        self.home = home
    }

    /// Returns canonical prompts first. Optional OpenCode and generic prompts
    /// appear only when they already exist.
    public func discover() -> [PromptFile] {
        let candidates = [
            Candidate(
                relativePath: ".claude/CLAUDE.md",
                displayName: "CLAUDE.md — Claude Code",
                alwaysInclude: true
            ),
            Candidate(
                relativePath: ".codex/AGENTS.md",
                displayName: "AGENTS.md — Codex CLI",
                alwaysInclude: true
            ),
            Candidate(
                relativePath: ".config/opencode/AGENTS.md",
                displayName: "AGENTS.md — OpenCode",
                alwaysInclude: false
            ),
            Candidate(
                relativePath: "AGENTS.md",
                displayName: "AGENTS.md — Generic",
                alwaysInclude: false
            ),
        ]

        return candidates.compactMap { candidate in
            let url = home.appendingPathComponent(candidate.relativePath)
            let state = try? POSIXFile.state(at: url)
            let exists = state?.exists == true
            guard candidate.alwaysInclude || exists else { return nil }
            return PromptFile(
                displayName: candidate.displayName,
                path: url.path,
                exists: exists,
                modifiedAt: state?.modifiedAt
            )
        }
    }

    public func read(_ file: PromptFile) throws -> String {
        try String(contentsOfFile: file.path, encoding: .utf8)
    }

    /// Writes only when the current revision matches `expectedModifiedAt`.
    /// A nil expectation requires the file to be absent. Existing modes and
    /// the first pre-write contents are preserved.
    public func write(
        _ content: String,
        to file: PromptFile,
        expectedModifiedAt: Date?
    ) throws {
        let destination = URL(fileURLWithPath: file.path)
        let data = Data(content.utf8)
        try Self.backupLedger.withPath(file.path) { isFirstWrite in
            let initialState = try POSIXFile.state(at: destination)
            try validate(
                initialState,
                expectedModifiedAt: expectedModifiedAt,
                path: file.path
            )

            let fileManager = FileManager.default
            try AtomicFileWriter.write(
                data,
                to: destination,
                permissions: initialState.permissions
            ) {
                let currentState = try POSIXFile.state(at: destination)
                guard currentState.contentRevision == initialState.contentRevision else {
                    throw PromptFileError.changedOnDisk(path: file.path)
                }
                if isFirstWrite, initialState.exists {
                    let backup = destination.appendingPathExtension("skillbox.bak")
                    if !fileManager.fileExists(atPath: backup.path) {
                        try fileManager.copyItem(at: destination, to: backup)
                    }
                }
                return true
            }
        }
    }

    @available(
        *,
        deprecated,
        message: "Use write(_:to:expectedModifiedAt:) to guard against stale revisions."
    )
    public func write(_ content: String, to file: PromptFile) throws {
        try write(content, to: file, expectedModifiedAt: file.modifiedAt)
    }

    private func validate(
        _ state: FileState,
        expectedModifiedAt: Date?,
        path: String
    ) throws {
        switch (state, expectedModifiedAt) {
        case (.missing, nil):
            return
        case (.present(let snapshot), .some(let expected))
            where snapshot.modifiedAt == expected:
            return
        default:
            throw PromptFileError.changedOnDisk(path: path)
        }
    }
}

private struct Candidate {
    let relativePath: String
    let displayName: String
    let alwaysInclude: Bool
}

private final class PromptBackupLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var writtenPaths: Set<String> = []

    func withPath<T>(_ path: String, operation: (Bool) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        let isFirstWrite = !writtenPaths.contains(path)
        let result = try operation(isFirstWrite)
        writtenPaths.insert(path)
        return result
    }
}
