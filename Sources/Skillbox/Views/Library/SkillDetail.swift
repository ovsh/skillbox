import MarkdownUI
import SkillboxKit
import SwiftUI

/// Right column: everything about one skill — state controls, provenance,
/// and the rendered SKILL.md.
struct SkillDetail: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gutter) {
                header
                controls
                Divider().foregroundStyle(Theme.border)
                document
            }
            .padding(Theme.gutter + 4)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.canvas)
        .toolbar {
            ToolbarItem {
                Button {
                    revealInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .help("Show in Finder")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(skill.name)
                    .font(Theme.title(22))
                    .foregroundStyle(Theme.ink)
                if skill.isManagedByRegistry {
                    Chip(text: "Managed", tint: Theme.accent)
                }
            }

            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                metaItem("Added", RelativeDateText.string(for: skill.addedAt))
                metaItem("Touched", RelativeDateText.string(for: skill.touchedAt))
                if let model = skill.frontmatterFields["model"] {
                    metaItem("Model", model)
                }
                if skill.frontmatterFields["disable-model-invocation"] == "true" {
                    Chip(text: "Manual-only", tint: Theme.inkSecondary)
                }
            }
        }
    }

    private func metaItem(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(Theme.meta)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: Controls

    private var controls: some View {
        let isMutating = library.mutatingSkillIDs.contains(skill.id)
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                // Claude Code + Agent SDK: the sanctioned override, 4 states.
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SectionLabel(text: "Claude Code & Agent SDK")
                        Spacer()
                        StatusDot(isOn: library.isClaudeAvailable(skill) && library.isActiveForClaude(skill))
                    }
                    if library.isClaudeAvailable(skill) {
                        OverridePicker(skill: skill)
                            .disabled(!library.canToggleClaude(skill))
                        Text(library.overridesUnreadable
                             ? "~/.claude/settings.json can't be parsed — fix it (or restore the .skillbox.bak) to re-enable switches."
                             : overrideCaption)
                            .font(Theme.meta)
                            .foregroundStyle(library.overridesUnreadable ? Theme.accent : Theme.inkTertiary)
                    } else {
                        Text("No live copy in ~/.claude/skills — Claude Code can't load this skill, so there's nothing to switch.")
                            .font(Theme.meta)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                // Other tools: folder shelving per tool. If ANY copy of this
                // skill is a symlink, every copy stays put — moving the real
                // directory would dangle the links pointing at it.
                let otherPresences = skill.presences.filter { $0.targetID != "claude" }
                let groupHasSymlink = skill.presences.contains { $0.isSymlink }
                if !otherPresences.isEmpty {
                    Divider().foregroundStyle(Theme.border)
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Other Tools")
                        ForEach(otherPresences, id: \.self) { presence in
                            HStack(spacing: 8) {
                                Text(library.toolDisplayName(presence.targetID))
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.ink)
                                if presence.isBroken {
                                    Chip(text: "Broken link", tint: .red)
                                } else if presence.isSymlink {
                                    Chip(text: "Symlinked", tint: Theme.inkSecondary)
                                }
                                Spacer()
                                AccentToggle(isOn: !presence.isShelved) { enabled in
                                    library.setToolPresence(skill, targetID: presence.targetID, enabled: enabled)
                                }
                                .disabled(groupHasSymlink || presence.isBroken)
                            }
                        }
                        Text(groupHasSymlink
                             ? "This skill is linked between tools — moving any copy would break those links, so shelving is disabled. Use the Claude switch to control Claude Code."
                             : "Off moves this folder to Skillbox's shelf and this tool stops reading this copy. Other copies of the same skill are unaffected.")
                            .font(Theme.meta)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                if let error = library.lastError {
                    Text(error)
                        .font(Theme.secondary)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .disabled(isMutating)
        }
    }

    private var overrideCaption: String {
        switch skill.claudeOverride ?? .on {
        case .on: "Claude can invoke this skill and you can run it with /\(skill.dirName)."
        case .nameOnly: "Claude sees only the name — it won't auto-invoke. /\(skill.dirName) still works."
        case .userInvocableOnly: "Hidden from Claude; you can still run /\(skill.dirName)."
        case .off: "Fully hidden from Claude, the / menu, and Agent SDK apps."
        }
    }

    // MARK: Document

    @ViewBuilder
    private var document: some View {
        if let presence = primaryPresence {
            SkillDocument(directoryPath: presence.path, revision: skill.touchedAt)
        } else {
            Text("No readable SKILL.md.")
                .font(Theme.secondary)
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    private var primaryPresence: SkillToolPresence? {
        skill.presences.first { !$0.isShelved } ?? skill.presences.first
    }

    private func revealInFinder() {
        guard let presence = primaryPresence else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: presence.path)])
    }
}

// MARK: - Override picker

/// Segmented 4-state control for skillOverrides.
private struct OverridePicker: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill

    var body: some View {
        Picker("", selection: Binding(
            get: { skill.claudeOverride ?? .on },
            set: { newState in
                library.setClaudeOverride(skill, newState == .on ? nil : newState)
            }
        )) {
            Text("On").tag(SkillOverrideState.on)
            Text("Name only").tag(SkillOverrideState.nameOnly)
            Text("Manual only").tag(SkillOverrideState.userInvocableOnly)
            Text("Off").tag(SkillOverrideState.off)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
    }
}

// MARK: - Markdown document

/// Renders SKILL.md asynchronously; plain text above the render limit.
/// Load identity includes the content revision so edits re-render, and the
/// cancellation check keeps a canceled read from clobbering a newer one.
private struct SkillDocument: View {
    let directoryPath: String
    let revision: Date?
    @State private var content: String?

    private struct LoadKey: Hashable {
        let path: String
        let revision: Date?
    }

    private static let renderLimit = 120 * 1024

    var body: some View {
        Group {
            if let content {
                if content.utf8.count > Self.renderLimit {
                    Text(content)
                        .font(Theme.mono)
                        .textSelection(.enabled)
                } else {
                    Markdown(MarkdownContent(stripFrontmatter(content)))
                        .markdownTheme(.skillbox)
                        .textSelection(.enabled)
                }
            } else {
                Text("No SKILL.md in this skill.")
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .task(id: LoadKey(path: directoryPath, revision: revision)) {
            let path = directoryPath + "/SKILL.md"
            let loaded = await Task.detached(priority: .userInitiated) {
                try? String(contentsOfFile: path, encoding: .utf8)
            }.value
            guard !Task.isCancelled else { return }
            content = loaded
        }
    }

    private func stripFrontmatter(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return text }
        if let closing = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) {
            return lines[(closing + 1)...].joined(separator: "\n")
        }
        return text
    }
}

// MARK: - Markdown theme

extension MarkdownUI.Theme {
    /// DocC-derived theme recolored to the Skillbox palette. MainActor because
    /// MarkdownUI.Theme is not Sendable; it's only ever touched from views.
    @MainActor static let skillbox = MarkdownUI.Theme.docC
        .text {
            ForegroundColor(Skillbox.Theme.ink)
            FontSize(13)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(11.5)
        }
        .link {
            ForegroundColor(Skillbox.Theme.accent)
        }
}
