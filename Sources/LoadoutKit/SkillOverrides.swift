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
    case conflict(path: String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let path, let reason):
            return "Claude settings at \(path) are not valid JSON: \(reason). The file was not changed."
        case .invalidSkillOverrides(let path):
            return "Claude settings at \(path) contain a skillOverrides value that is not an object. The file was not changed."
        case .serializationFailed(let path):
            return "Claude settings at \(path) could not be serialized. The file was not changed."
        case .conflict(let path):
            return "Claude settings at \(path) changed during three write attempts. Refresh and try again."
        }
    }
}

/// Reads and changes Claude Code's sanctioned per-skill overrides without
/// decoding or discarding unrelated settings.
public struct ClaudeSettingsStore: Sendable {
    private static let mutationCoordinator = SettingsMutationCoordinator()
    private let settingsFileURL: URL

    public init(settingsFileURL: URL) {
        self.settingsFileURL = settingsFileURL
    }

    /// Current overrides. Missing files and keys produce an empty map;
    /// values unknown to this Loadout version are ignored.
    public func overrides() throws -> [String: SkillOverrideState] {
        guard case .present = try POSIXFile.state(at: settingsFileURL) else { return [:] }
        let data = try Data(contentsOf: settingsFileURL)
        let object = try ClaudeSettingsPatcher.object(from: data, path: settingsFileURL.path)
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
        let path = settingsFileURL.standardizedFileURL.path
        try Self.mutationCoordinator.withMutation(at: path) { isFirstWrite in
            for _ in 0..<3 {
                let initialState = try POSIXFile.state(at: settingsFileURL)
                let sourceData: Data?
                switch initialState {
                case .missing:
                    sourceData = nil
                case .present:
                    do {
                        sourceData = try Data(contentsOf: settingsFileURL)
                    } catch {
                        let currentState = try POSIXFile.state(at: settingsFileURL)
                        if currentState.contentRevision != initialState.contentRevision {
                            continue
                        }
                        throw error
                    }
                }

                let patched = try ClaudeSettingsPatcher.patch(
                    sourceData,
                    state: state,
                    forSkill: skillName,
                    path: settingsFileURL.path
                )
                let wrote = try AtomicFileWriter.write(
                    patched,
                    to: settingsFileURL,
                    permissions: initialState.permissions
                ) {
                    let currentState = try POSIXFile.state(at: settingsFileURL)
                    guard currentState.contentRevision == initialState.contentRevision else {
                        return false
                    }
                    if isFirstWrite, initialState.exists {
                        try createBackupIfNeeded()
                    }
                    return true
                }
                if wrote { return }
            }

            throw ClaudeSettingsError.conflict(path: settingsFileURL.path)
        }
    }

    private func createBackupIfNeeded() throws {
        let fileManager = FileManager.default
        let backupURL = settingsFileURL.appendingPathExtension("loadout.bak")
        // A backup made under the app's previous name still counts.
        let legacyBackupURL = settingsFileURL.appendingPathExtension("skillbox.bak")
        guard !fileManager.fileExists(atPath: backupURL.path),
              !fileManager.fileExists(atPath: legacyBackupURL.path) else { return }
        try fileManager.copyItem(at: settingsFileURL, to: backupURL)
    }
}

enum ClaudeSettingsPatcher {
    static func patch(
        _ source: Data?,
        state: SkillOverrideState?,
        forSkill skillName: String,
        path: String
    ) throws -> Data {
        var object = try source.map { try Self.object(from: $0, path: path) } ?? [:]

        var rawOverrides: [String: Any]
        if let existing = object["skillOverrides"] {
            guard let dictionary = existing as? [String: Any] else {
                throw ClaudeSettingsError.invalidSkillOverrides(path: path)
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
            throw ClaudeSettingsError.serializationFailed(path: path)
        }
        return data
    }

    static func object(from data: Data, path: String) throws -> [String: Any] {
        do {
            let value = try JSONSerialization.jsonObject(with: data)
            guard let object = value as? [String: Any] else {
                throw ClaudeSettingsError.invalidJSON(
                    path: path,
                    reason: "the top-level value must be an object"
                )
            }
            return object
        } catch let error as ClaudeSettingsError {
            throw error
        } catch {
            throw ClaudeSettingsError.invalidJSON(
                path: path,
                reason: error.localizedDescription
            )
        }
    }
}

private final class SettingsMutationCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var writtenPaths: Set<String> = []

    func withMutation<T>(at path: String, operation: (Bool) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }

        let isFirstWrite = !writtenPaths.contains(path)
        let result = try operation(isFirstWrite)
        writtenPaths.insert(path)
        return result
    }
}
