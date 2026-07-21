import Foundation

/// Minimal parser for the YAML frontmatter block at the top of a SKILL.md:
///
///     ---
///     name: My Skill
///     description: What it does
///     ---
///
/// Only flat `key: value` pairs are read; nothing else is needed.
public enum Frontmatter {
    /// Bytes to read from the head of a SKILL.md — frontmatter always fits here.
    public static let readLimit = 16 * 1024

    public struct SkillMetadata: Sendable {
        public let name: String
        public let description: String
    }

    /// Parses metadata from raw file content, falling back to `fallbackName`.
    public static func parseSkillMetadata(_ content: String, fallbackName: String) -> SkillMetadata {
        var name = fallbackName
        var description = ""

        for (key, value) in fields(in: content) {
            switch key {
            case "name": name = value
            case "description": description = value
            default: break
            }
        }
        return SkillMetadata(name: name, description: description)
    }

    /// Reads the head of the file at `path` (up to `readLimit` bytes) so large
    /// skills don't cost a full file read during catalog scans.
    public static func readHead(of path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: readLimit) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Extracts flat key/value pairs from a frontmatter fence. Returns [] when
    /// the content doesn't start with `---`.
    private static func fields(in content: String) -> [(String, String)] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmed == "---" else { return [] }

        var result: [(String, String)] = []
        for line in lines.dropFirst() {
            if line.trimmed == "---" { break }
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2) ||
               (value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2) {
                value = String(value.dropFirst().dropLast())
            }
            result.append((key, value))
        }
        return result
    }
}

extension Substring {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
