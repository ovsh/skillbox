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
        let fields = parseAllFields(content)
        return SkillMetadata(
            name: fields["name"] ?? fallbackName,
            description: fields["description"] ?? ""
        )
    }

    /// Reads the head of the file at `path` (up to `readLimit` bytes) so large
    /// skills don't cost a full file read during catalog scans.
    public static func readHead(of path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: readLimit) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Extracts all top-level key/value pairs from a frontmatter fence,
    /// including literal (`|`) and folded (`>`) block scalars, which real
    /// skills use for multiline descriptions. Later duplicate keys win.
    /// Returns an empty map without an opening fence.
    public static func parseAllFields(_ content: String) -> [String: String] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmed == "---" else { return [:] }

        var result: [String: String] = [:]
        var index = lines.index(after: lines.startIndex)

        while index < lines.endIndex {
            let line = lines[index]
            if line.trimmed == "---" { break }
            index = lines.index(after: index)

            // Top-level keys only — indented lines belong to a block value.
            guard let first = line.first, first != " ", first != "\t" else { continue }
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)

            let blockMarker = value.first.map { $0 == "|" || $0 == ">" } ?? false
            if blockMarker {
                var blockLines: [String] = []
                while index < lines.endIndex {
                    let blockLine = lines[index]
                    if blockLine.trimmed == "---" { break }
                    if blockLine.trimmed.isEmpty {
                        blockLines.append("")
                        index = lines.index(after: index)
                        continue
                    }
                    guard let firstChar = blockLine.first, firstChar == " " || firstChar == "\t" else { break }
                    blockLines.append(blockLine.trimmed)
                    index = lines.index(after: index)
                }
                while blockLines.last?.isEmpty == true { blockLines.removeLast() }
                // Folded (>) joins with spaces; literal (|) keeps line breaks.
                value = value.hasPrefix(">")
                    ? blockLines.joined(separator: " ")
                    : blockLines.joined(separator: "\n")
            } else if (value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2) ||
                      (value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }
}

extension Substring {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
