import Foundation

public enum AppPaths {
    /// ~/Library/Application Support/Loadout — settings, lockfile, logs, registry.
    /// A directory left behind by the app's previous name (Skillbox) is moved
    /// over once so shelved skills and settings survive the rebrand.
    public static func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let current = base.appendingPathComponent("Loadout")
        let legacy = base.appendingPathComponent("Skillbox")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: current.path),
           fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.moveItem(at: legacy, to: current)
        }
        return current
    }
}

// MARK: - Settings

public final class SettingsStore: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "loadout.settings")
    private var cached: AppSettings

    public init(directory: URL = AppPaths.appSupportDirectory()) {
        self.fileURL = directory.appendingPathComponent("settings.json")
        self.cached = Self.load(from: fileURL) ?? .defaults()
    }

    public var settings: AppSettings {
        queue.sync { cached }
    }

    public func replace(with settings: AppSettings) {
        queue.sync {
            cached = settings
            Self.save(settings, to: fileURL)
        }
    }

    public func update(_ mutate: (inout AppSettings) -> Void) {
        queue.sync {
            mutate(&cached)
            Self.save(cached, to: fileURL)
        }
    }

    private static func load(from url: URL) -> AppSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppSettings.self, from: data)
    }

    private static func save(_ settings: AppSettings, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(settings) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Lockfile

public struct LockfileStore: Sendable {
    private let fileURL: URL

    public init(directory: URL = AppPaths.appSupportDirectory()) {
        self.fileURL = directory.appendingPathComponent("lockfile.json")
    }

    public func load() -> Lockfile {
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Lockfile.self, from: data)) ?? .empty
    }

    public func save(_ lockfile: Lockfile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(lockfile)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Logs

public struct LogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
}

/// Appends to an in-memory ring (for the UI) and a log file on disk.
public final class LogStore: @unchecked Sendable {
    public static let maxEntries = 500

    private let queue = DispatchQueue(label: "loadout.logs")
    private let fileURL: URL
    private var buffer: [LogEntry] = []

    public init(directory: URL = AppPaths.appSupportDirectory()) {
        self.fileURL = directory.appendingPathComponent("sync.log")
    }

    public var logFileURL: URL { fileURL }

    public var entries: [LogEntry] {
        queue.sync { buffer }
    }

    public func append(_ level: LogLevel, _ message: String) {
        let entry = LogEntry(id: UUID(), timestamp: Date(), level: level, message: message)
        queue.sync {
            buffer.append(entry)
            if buffer.count > Self.maxEntries {
                buffer.removeFirst(buffer.count - Self.maxEntries)
            }
            appendToFile(entry)
        }
    }

    private func appendToFile(_ entry: LogEntry) {
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? data.write(to: fileURL)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}
