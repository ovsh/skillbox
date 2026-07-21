import Darwin
import Foundation

public enum SkillOverrideState: String, Codable, Sendable, CaseIterable {
    case on
    case nameOnly = "name-only"
    case userInvocableOnly = "user-invocable-only"
    case off
}

public enum ClaudeSettingsError: LocalizedError, Sendable {
    case invalidJSON(path: String, reason: String)
    case invalidSkillOverrides(path: String)
    case serializationFailed(path: String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let path, let reason):
            return "Claude settings at \(path) are not valid JSON: \(reason). The file was not changed."
        case .invalidSkillOverrides(let path):
            return "Claude settings at \(path) contain a skillOverrides value that is not an object. The file was not changed."
        case .serializationFailed(let path):
            return "Claude settings at \(path) could not be serialized. The file was not changed."
        }
    }
}

/// Reads and changes Claude Code's sanctioned per-skill overrides without
/// decoding or discarding unrelated settings.
public struct ClaudeSettingsStore: Sendable {
    private let settingsFileURL: URL
    private let backupLedger: SettingsBackupLedger

    public init(settingsFileURL: URL) {
        self.settingsFileURL = settingsFileURL
        self.backupLedger = SettingsBackupLedger()
    }

    /// Current overrides. Missing files and keys produce an empty map;
    /// values unknown to this Skillbox version are ignored.
    public func overrides() throws -> [String: SkillOverrideState] {
        guard FileManager.default.fileExists(atPath: settingsFileURL.path) else { return [:] }
        let object = try loadObject()
        guard let rawOverrides = object["skillOverrides"] else { return [:] }
        guard let rawOverrides = rawOverrides as? [String: Any] else {
            throw ClaudeSettingsError.invalidSkillOverrides(path: settingsFileURL.path)
        }

        return rawOverrides.reduce(into: [:]) { result, entry in
            guard let rawValue = entry.value as? String,
                  let state = SkillOverrideState(rawValue: rawValue) else { return }
            result[entry.key] = state
        }
    }

    /// Sets one override, or removes it to restore Claude's default `on`
    /// behavior. All other JSON values retain their original value.
    public func setOverride(_ state: SkillOverrideState?, forSkill skillName: String) throws {
        try backupLedger.withLock { hasWritten in
            let fileManager = FileManager.default
            let existed = fileManager.fileExists(atPath: settingsFileURL.path)
            var object = existed ? try loadObject() : [:]

            var rawOverrides: [String: Any]
            if let existing = object["skillOverrides"] {
                guard let dictionary = existing as? [String: Any] else {
                    throw ClaudeSettingsError.invalidSkillOverrides(path: settingsFileURL.path)
                }
                rawOverrides = dictionary
            } else {
                rawOverrides = [:]
            }

            if let state {
                rawOverrides[skillName] = state.rawValue
            } else {
                rawOverrides.removeValue(forKey: skillName)
            }

            if rawOverrides.isEmpty {
                object.removeValue(forKey: "skillOverrides")
            } else {
                object["skillOverrides"] = rawOverrides
            }

            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(
                    withJSONObject: object,
                    options: [.prettyPrinted, .sortedKeys]
                  ) else {
                throw ClaudeSettingsError.serializationFailed(path: settingsFileURL.path)
            }

            if !hasWritten, existed {
                let backupURL = settingsFileURL.appendingPathExtension("skillbox.bak")
                if !fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.copyItem(at: settingsFileURL, to: backupURL)
                }
            }

            try AtomicFileWriter.write(data, to: settingsFileURL)
            hasWritten = true
        }
    }

    private func loadObject() throws -> [String: Any] {
        let data: Data
        do {
            data = try Data(contentsOf: settingsFileURL)
        } catch {
            throw error
        }

        do {
            let value = try JSONSerialization.jsonObject(with: data)
            guard let object = value as? [String: Any] else {
                throw ClaudeSettingsError.invalidJSON(
                    path: settingsFileURL.path,
                    reason: "the top-level value must be an object"
                )
            }
            return object
        } catch let error as ClaudeSettingsError {
            throw error
        } catch {
            throw ClaudeSettingsError.invalidJSON(
                path: settingsFileURL.path,
                reason: error.localizedDescription
            )
        }
    }
}

private final class SettingsBackupLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var hasWritten = false

    func withLock<T>(_ operation: (inout Bool) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation(&hasWritten)
    }
}

enum AtomicFileWriter {
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
