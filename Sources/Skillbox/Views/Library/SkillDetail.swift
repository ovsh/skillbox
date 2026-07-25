import MarkdownUI
import SkillboxKit
import SwiftUI

/// Right pane: one skill. Title, the four-state control with the sentence that
/// explains what that state actually does, provenance, then the skill's own
/// SKILL.md rendered in full.
struct SkillDetail: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }

                stateCard
                    .padding(.top, 22)

                metaLine
                    .padding(.top, 20)

                otherTools

                document
                    .padding(.top, 30)
            }
            // A reading column, not a wall. The pane can be 1200pt wide; the
            // document inside it never is.
            .frame(maxWidth: Theme.readingWidth, alignment: .leading)
            .padding(.horizontal, Theme.paneInset)
            .padding(.top, Theme.titleBar)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Theme.canvas)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(skill.name)
                .font(Theme.display)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            ghostActions
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 7 }
        }
    }

    private var ghostActions: some View {
        HStack(spacing: 4) {
            GhostIconButton(systemImage: "folder", help: "Reveal in Finder") {
                revealInFinder()
            }
            GhostIconButton(systemImage: "trash", help: "Delete skill…", isDestructive: true) {
                confirmingDelete = true
            }
            .confirmationDialog(
                "Delete “\(skill.name)”?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Move to Trash", role: .destructive) {
                    library.deleteSkill(skill)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var deleteMessage: String {
        let links = skill.presences.filter(\.isSymlink).count
        let folders = skill.presences.count - links
        switch (folders > 0, links > 0) {
        case (true, true):
            return "The skill folder moves to the Trash and \(links == 1 ? "its link is" : "\(links) links are") removed — the linked originals stay where they are. Its Claude setting is cleared."
        case (true, false):
            return "The skill folder moves to the Trash and its Claude setting is cleared. You can restore it from the Trash."
        default:
            return "Only the link\(links == 1 ? "" : "s") to this skill \(links == 1 ? "is" : "are") removed — the original files stay where they are. Its Claude setting is cleared."
        }
    }

    // MARK: State
    //
    // The one card in the window. State is the thing this app exists to change,
    // so it gets a surface of its own — control on top, the plain sentence for
    // the current state underneath, never more than two lines.

    private var stateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    SectionLabel(text: "In Claude Code")
                    Spacer(minLength: 12)
                    if library.isClaudeAvailable(skill) {
                        StateControl(
                            state: skill.claudeOverride ?? .on,
                            isEnabled: library.canToggleClaude(skill)
                        ) { newState in
                            library.setClaudeOverride(skill, newState == .on ? nil : newState)
                        }
                    } else {
                        Chip(text: "Not installed", tint: Theme.inkSecondary)
                    }
                }
                Text(captionText)
                    .font(Theme.meta)
                    .foregroundStyle(library.overridesUnreadable ? Theme.danger : Theme.inkSecondary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var captionText: String {
        guard library.isClaudeAvailable(skill) else {
            return "No live copy in ~/.claude/skills — Claude Code can't load this skill."
        }
        if library.overridesUnreadable {
            return "~/.claude/settings.json can't be parsed — fix it (or restore the .skillbox.bak) to re-enable switching."
        }
        switch skill.claudeOverride ?? .on {
        case .on: return "Claude can invoke this skill on its own, and /\(skill.dirName) runs it directly."
        case .nameOnly: return "Claude sees the name but won't auto-invoke it. /\(skill.dirName) still works."
        case .userInvocableOnly: return "Hidden from Claude — you can still run /\(skill.dirName) yourself."
        case .off: return "Hidden from Claude, the / menu, and Agent SDK apps. Files stay on disk; Delete removes them."
        }
    }

    // MARK: Meta
    //
    // One line when the facts fit, two stacked groups when narrow. Every item
    // is fixedSize so nothing ever wraps inside itself.

    private var metaLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { datesGroup; provenanceGroup }
            VStack(alignment: .leading, spacing: 8) { datesGroup; provenanceGroup }
        }
    }

    private var datesGroup: some View {
        HStack(spacing: 18) {
            metaItem("Added", RelativeDateText.string(for: skill.addedAt))
            metaItem("Updated", RelativeDateText.string(for: skill.touchedAt))
        }
        .fixedSize()
    }

    private var provenanceGroup: some View {
        HStack(spacing: 10) {
            metaItem("In", skill.presences.map { library.toolDisplayName($0.targetID) }
                .joined(separator: " · "))
            if skill.isManagedByRegistry {
                Chip(text: "Managed", tint: Theme.live).fixedSize()
            }
            if skill.frontmatterFields["disable-model-invocation"] == "true" {
                Chip(text: "Manual-only", tint: Theme.partial).fixedSize()
            }
            if let error = library.lastError {
                Text(error)
                    .font(Theme.meta)
                    .foregroundStyle(Theme.danger)
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }

    private func metaItem(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(Theme.metaMedium)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: Other tools (shelving)

    @ViewBuilder
    private var otherTools: some View {
        let otherPresences = skill.presences.filter { $0.targetID != "claude" }
        let groupHasSymlink = skill.presences.contains { $0.isSymlink }
        if !otherPresences.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Other Tools")
                ForEach(otherPresences, id: \.self) { presence in
                    HStack(spacing: 8) {
                        Text(library.toolDisplayName(presence.targetID))
                            .font(Theme.body)
                            .foregroundStyle(Theme.ink)
                        if presence.isBroken {
                            Chip(text: "Broken link", tint: Theme.danger)
                        } else if presence.isSymlink {
                            Chip(text: "Symlinked", tint: Theme.inkSecondary)
                        }
                        Spacer(minLength: 12)
                        LoadoutToggle(isOn: !presence.isShelved) { enabled in
                            library.setToolPresence(skill, targetID: presence.targetID, enabled: enabled)
                        }
                        .disabled(groupHasSymlink || presence.isBroken)
                    }
                    .frame(height: 26)
                }
                Text(groupHasSymlink
                     ? "This skill is linked between tools — moving any copy would break those links, so shelving is disabled."
                     : "Off moves this folder to Loadout's shelf and this tool stops reading this copy. Other copies are unaffected.")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)
        }
    }

    // MARK: Document

    @ViewBuilder
    private var document: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SectionLabel(text: "SKILL.md")
                Rectangle()
                    .fill(Theme.separator)
                    .frame(height: 1)
            }
            if let presence = primaryPresence {
                SkillDocument(
                    directoryPath: presence.path,
                    revision: skill.touchedAt,
                    dropTitle: skill.name
                )
            } else {
                Text("No readable SKILL.md.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
    }

    private var primaryPresence: SkillToolPresence? {
        skill.presences.first { !$0.isShelved && !$0.isBroken } ?? skill.presences.first
    }

    private func revealInFinder() {
        guard let presence = primaryPresence else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: presence.path)])
    }
}

// MARK: - Markdown document

/// Renders SKILL.md asynchronously; plain text above the render limit.
/// Load identity includes the content revision so edits re-render, and the
/// cancellation check keeps a canceled read from clobbering a newer one.
private struct SkillDocument: View {
    let directoryPath: String
    let revision: Date?
    var dropTitle: String? = nil
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
                        .foregroundStyle(Theme.inkSecondary)
                        .textSelection(.enabled)
                } else {
                    Markdown(MarkdownContent(prepared(content)))
                        .markdownTheme(.loadout)
                        .textSelection(.enabled)
                }
            } else {
                Text("No SKILL.md in this skill.")
                    .font(Theme.body)
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

    /// Strips frontmatter, and drops a leading H1 that just repeats the title.
    private func prepared(_ text: String) -> String {
        var lines = Array(text.split(separator: "\n", omittingEmptySubsequences: false))
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let closing = lines.dropFirst().firstIndex(where: {
               $0.trimmingCharacters(in: .whitespaces) == "---"
           }) {
            lines = Array(lines[(closing + 1)...])
        }
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeFirst()
        }
        if let dropTitle,
           let first = lines.first?.trimmingCharacters(in: .whitespaces),
           first.hasPrefix("# "),
           first.dropFirst(2).trimmingCharacters(in: .whitespaces)
               .caseInsensitiveCompare(dropTitle) == .orderedSame {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Markdown theme

extension MarkdownUI.Theme {
    /// DocC-derived theme recolored to Loadout's palette. MainActor because
    /// MarkdownUI.Theme is not Sendable; it's only ever touched from views.
    @MainActor static let loadout = MarkdownUI.Theme.docC
        .text {
            ForegroundColor(Skillbox.Theme.ink)
            FontSize(13.5)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(11.5)
            ForegroundColor(Skillbox.Theme.inkSecondary)
        }
        .link {
            ForegroundColor(Skillbox.Theme.live)
        }
        // DocC's headings are sized for a full documentation page and come out
        // bigger than the pane title. Nothing inside the document is allowed to
        // outrank the skill's own name.
        .heading1 { heading($0, size: 19, top: 30) }
        .heading2 { heading($0, size: 16, top: 26) }
        .heading3 { heading($0, size: 14, top: 22) }
        .heading4 { heading($0, size: 13, top: 18) }

    @MainActor private static func heading(
        _ configuration: BlockConfiguration,
        size: CGFloat,
        top: CGFloat
    ) -> some View {
        configuration.label
            .markdownMargin(top: top, bottom: 8)
            .markdownTextStyle {
                FontSize(size)
                FontWeight(.semibold)
                ForegroundColor(Skillbox.Theme.ink)
            }
    }
}
