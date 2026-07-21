import Foundation
import Testing
@testable import SkillboxKit

@Suite("CatalogScanner")
struct CatalogScannerTests {
    @Test("Top-level skills/ and rules/ form the implicit space")
    func topLevelLayout() throws {
        let fixture = try Fixture(name: "scan-toplevel")
        defer { fixture.cleanup() }

        try fixture.write("skills/code-review/SKILL.md", skillMarkdown(name: "Code Review", description: "Reviews code"))
        try fixture.write("skills/code-review/references/guide.md")
        try fixture.write("rules/team-rules.md")

        let catalog = try CatalogScanner().scan(checkout: fixture.root)

        #expect(catalog.spaces.map(\.folderName) == ["."])
        #expect(catalog.skills.count == 1)
        let skill = try #require(catalog.skills.first)
        #expect(skill.id == "./code-review")
        #expect(skill.name == "Code Review")
        #expect(skill.description == "Reviews code")
        #expect(skill.relativePath == "skills/code-review")
        #expect(!skill.isPlayground)
        #expect(catalog.ruleSets.map(\.relativePath) == ["rules"])
    }

    @Test("Space folders are discovered with metadata and playground")
    func spaceLayout() throws {
        let fixture = try Fixture(name: "scan-spaces")
        defer { fixture.cleanup() }

        try fixture.write("everyone/skills/writing/SKILL.md", skillMarkdown(name: "Writing", description: "Write well"))
        try fixture.write("everyone/rules/rules.md")
        try fixture.write("everyone/playground/skills/experimental/SKILL.md", skillMarkdown(name: "Experimental", description: "Try me"))
        try fixture.write("engineering/skills/deploy/SKILL.md", skillMarkdown(name: "Deploy", description: "Ship it"))
        try fixture.write("engineering/team.yaml", "name: Engineering Team\ndescription: \"Builders\"\n")
        try fixture.write("docs/readme.md") // top-level dir without skills/rules — ignored

        let catalog = try CatalogScanner().scan(checkout: fixture.root)

        #expect(catalog.spaces.map(\.folderName) == ["everyone", "engineering"])
        let engineering = try #require(catalog.spaces.first { $0.folderName == "engineering" })
        #expect(engineering.displayName == "Engineering Team")
        #expect(engineering.description == "Builders")

        let everyone = try #require(catalog.spaces.first { $0.folderName == "everyone" })
        #expect(everyone.hasPlayground)

        #expect(catalog.skills.count == 3)
        let playground = try #require(catalog.skills.first { $0.isPlayground })
        #expect(playground.id == "everyone/experimental")
        #expect(catalog.ruleSets.map(\.relativePath) == ["everyone/rules"])
    }

    @Test("Skill without SKILL.md falls back to directory name")
    func missingFrontmatter() throws {
        let fixture = try Fixture(name: "scan-nofm")
        defer { fixture.cleanup() }

        try fixture.write("skills/bare-skill/notes.txt")

        let catalog = try CatalogScanner().scan(checkout: fixture.root)
        let skill = try #require(catalog.skills.first)
        #expect(skill.name == "bare-skill")
        #expect(skill.description.isEmpty)
    }

    @Test("Empty repo throws noContent")
    func emptyRepo() throws {
        let fixture = try Fixture(name: "scan-empty")
        defer { fixture.cleanup() }
        try fixture.mkdir("docs")

        #expect(throws: CatalogScannerError.self) {
            try CatalogScanner().scan(checkout: fixture.root)
        }
    }

    @Test("Missing checkout throws checkoutMissing")
    func missingCheckout() {
        let missing = URL(fileURLWithPath: "/tmp/skillbox-definitely-missing-\(UUID().uuidString)")
        #expect(throws: CatalogScannerError.self) {
            try CatalogScanner().scan(checkout: missing)
        }
    }
}

@Suite("Frontmatter")
struct FrontmatterTests {
    @Test("Parses quoted values and ignores body")
    func parsing() {
        let meta = Frontmatter.parseSkillMetadata(
            "---\nname: \"Quoted Name\"\ndescription: 'Single quoted'\nextra: ignored\n---\nname: Body Name\n",
            fallbackName: "fallback"
        )
        #expect(meta.name == "Quoted Name")
        #expect(meta.description == "Single quoted")
    }

    @Test("Content without frontmatter falls back")
    func noFrontmatter() {
        let meta = Frontmatter.parseSkillMetadata("# Just a title", fallbackName: "dir-name")
        #expect(meta.name == "dir-name")
        #expect(meta.description.isEmpty)
    }
}
