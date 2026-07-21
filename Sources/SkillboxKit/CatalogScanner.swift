import Foundation

public enum CatalogScannerError: LocalizedError {
    case checkoutMissing(String)
    case noContent

    public var errorDescription: String? {
        switch self {
        case .checkoutMissing(let path):
            return "Registry checkout not found at \(path). Sync to clone it first."
        case .noContent:
            return "No skills/ or rules/ directories found in this repository."
        }
    }
}

/// Scans a registry checkout for spaces, skills, and rule sets.
///
/// Supported layout — either top-level content:
///
///     skills/<skill>/SKILL.md
///     rules/*.md
///
/// or space folders (any top-level directory holding skills/ or rules/):
///
///     everyone/skills/<skill>/SKILL.md
///     everyone/rules/*.md
///     everyone/playground/skills/<skill>/SKILL.md
///     engineering/skills/…
public struct CatalogScanner: Sendable {
    public init() {}

    public func scan(checkout: URL) throws -> Catalog {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: checkout.path) else {
            throw CatalogScannerError.checkoutMissing(checkout.path)
        }

        var spaces: [SpaceInfo] = []
        var skills: [CatalogSkill] = []
        var ruleSets: [CatalogRuleSet] = []

        // Top-level skills/ and rules/ form the implicit "." space.
        let topSkills = checkout.appendingPathComponent("skills")
        let topRules = checkout.appendingPathComponent("rules")
        let hasTopSkills = directoryExists(topSkills, fileManager)
        let hasTopRules = directoryExists(topRules, fileManager)

        if hasTopSkills || hasTopRules {
            spaces.append(SpaceInfo(
                folderName: ".",
                displayName: "Skills",
                description: "",
                hasPlayground: directoryExists(checkout.appendingPathComponent("playground/skills"), fileManager)
            ))
            if hasTopSkills {
                skills += scanSkillsDirectory(topSkills, space: ".", relativePrefix: "skills", isPlayground: false, fileManager: fileManager)
            }
            if hasTopRules {
                ruleSets.append(CatalogRuleSet(space: ".", relativePath: "rules"))
            }
            let topPlayground = checkout.appendingPathComponent("playground/skills")
            if directoryExists(topPlayground, fileManager) {
                skills += scanSkillsDirectory(topPlayground, space: ".", relativePrefix: "playground/skills", isPlayground: true, fileManager: fileManager)
            }
        }

        // Space folders: top-level dirs containing skills/ or rules/.
        let children = (try? fileManager.contentsOfDirectory(
            at: checkout,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let folderName = child.lastPathComponent
            guard folderName != "skills", folderName != "rules", folderName != "playground" else { continue }

            let spaceSkills = child.appendingPathComponent("skills")
            let spaceRules = child.appendingPathComponent("rules")
            let spacePlayground = child.appendingPathComponent("playground/skills")
            let hasSkills = directoryExists(spaceSkills, fileManager)
            let hasRules = directoryExists(spaceRules, fileManager)
            let hasPlayground = directoryExists(spacePlayground, fileManager)
            guard hasSkills || hasRules || hasPlayground else { continue }

            let (displayName, description) = spaceMetadata(at: child, fallback: folderName)
            spaces.append(SpaceInfo(
                folderName: folderName,
                displayName: displayName,
                description: description,
                hasPlayground: hasPlayground
            ))

            if hasSkills {
                skills += scanSkillsDirectory(
                    spaceSkills, space: folderName,
                    relativePrefix: "\(folderName)/skills",
                    isPlayground: false, fileManager: fileManager
                )
            }
            if hasRules {
                ruleSets.append(CatalogRuleSet(space: folderName, relativePath: "\(folderName)/rules"))
            }
            if hasPlayground {
                skills += scanSkillsDirectory(
                    spacePlayground, space: folderName,
                    relativePrefix: "\(folderName)/playground/skills",
                    isPlayground: true, fileManager: fileManager
                )
            }
        }

        // "everyone" first, then alphabetical; the implicit "." space leads.
        spaces.sort { a, b in
            rank(of: a.folderName) == rank(of: b.folderName)
                ? a.folderName < b.folderName
                : rank(of: a.folderName) < rank(of: b.folderName)
        }

        guard !skills.isEmpty || !ruleSets.isEmpty else {
            throw CatalogScannerError.noContent
        }

        return Catalog(spaces: spaces, skills: skills, ruleSets: ruleSets)
    }

    // MARK: - Private

    private func rank(of folderName: String) -> Int {
        if folderName == "." { return 0 }
        if folderName == "everyone" { return 1 }
        return 2
    }

    private func scanSkillsDirectory(
        _ directory: URL,
        space: String,
        relativePrefix: String,
        isPlayground: Bool,
        fileManager: FileManager
    ) -> [CatalogSkill] {
        let children = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var result: [CatalogSkill] = []
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let dirName = child.lastPathComponent
            let skillFile = child.appendingPathComponent("SKILL.md").path
            let head = Frontmatter.readHead(of: skillFile) ?? ""
            let metadata = Frontmatter.parseSkillMetadata(head, fallbackName: dirName)

            result.append(CatalogSkill(
                dirName: dirName,
                name: metadata.name,
                description: metadata.description,
                space: space,
                relativePath: "\(relativePrefix)/\(dirName)",
                isPlayground: isPlayground
            ))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Reads optional space.yaml (or legacy-named team.yaml) metadata.
    private func spaceMetadata(at spaceDir: URL, fallback: String) -> (String, String) {
        for fileName in ["space.yaml", "team.yaml"] {
            let path = spaceDir.appendingPathComponent(fileName).path
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            var name = fallback.capitalized
            var description = ""
            for (key, value) in simpleYamlFields(content) {
                switch key {
                case "name": name = value
                case "description": description = value
                default: break
                }
            }
            return (name, description)
        }
        return (fallback.capitalized, "")
    }

    private func simpleYamlFields(_ content: String) -> [(String, String)] {
        var result: [(String, String)] = []
        for line in content.split(separator: "\n") {
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

    private func directoryExists(_ url: URL, _ fileManager: FileManager) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
