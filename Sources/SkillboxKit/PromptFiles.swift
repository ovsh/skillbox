import Darwin
import Foundation

public struct PromptFile: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let displayName: String
    /// Absolute candidate file path.
    public let path: String
    public let exists: Bool
    public let modifiedAt: Date?
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
            let exists = FileManager.default.fileExists(atPath: url.path)
            guard candidate.alwaysInclude || exists else { return nil }
            let modifiedAt = try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            return PromptFile(
                displayName: candidate.displayName,
                path: url.path,
                exists: exists,
                modifiedAt: modifiedAt
            )
        }
    }

    public func read(_ file: PromptFile) throws -> String {
        try String(contentsOfFile: file.path, encoding: .utf8)
    }

    /// Writes atomically and preserves the original file in a non-overwriting
    /// sibling backup before this process first changes that path.
    public func write(_ content: String, to file: PromptFile) throws {
        let destination = URL(fileURLWithPath: file.path)
        let data = Data(content.utf8)
        try Self.backupLedger.withPath(file.path) { isFirstWrite in
            let fileManager = FileManager.default
            if isFirstWrite, fileManager.fileExists(atPath: destination.path) {
                let backup = destination.appendingPathExtension("skillbox.bak")
                if !fileManager.fileExists(atPath: backup.path) {
                    try fileManager.copyItem(at: destination, to: backup)
                }
            }
            try PromptAtomicWriter.write(data, to: destination)
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

private enum PromptAtomicWriter {
    static func write(_ data: Data, to destination: URL) throws {
        let fileManager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        let temporary = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).skillbox-\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: temporary) }
        try data.write(to: temporary)

        let result = temporary.path.withCString { source in
            destination.path.withCString { target in
                Darwin.rename(source, target)
            }
        }
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
