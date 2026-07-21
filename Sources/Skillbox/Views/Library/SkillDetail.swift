import MarkdownUI
import SkillboxKit
import SwiftUI

/// Right pane: one skill — slim header controls, provenance, rendered SKILL.md.
struct SkillDetail: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                caption
                    .padding(.top, 10)
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }
                metaLine
                    .padding(.top, 12)
                otherTools
                document
                    .padding(.top, 20)
            }
            .padding(EdgeInsets(top: 24, leading: 28, bottom: 40, trailing: 28))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.canvas)
    }

    // MARK: Header — title · slim state pill · ghost actions
    // ViewThatFits: one line when there's room; title row + controls row when
    // narrow, so the pill never wraps mid-word.

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                titleText
                Spacer(minLength: 12)
                statePill
                ghostActions
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    titleText
                    Spacer(minLength: 12)
                    ghostActions
                }
                statePill
            }
        }
    }

    private var titleText: some View {
        Text(skill.name)
            .font(Theme.title())
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
    }

    @ViewBuilder
    private var statePill: some View {
        if library.isClaudeAvailable(skill) {
            SlimStatePill(skill: skill)
                .disabled(!library.canToggleClaude(skill))
        }
    }

    private var ghostActions: some View {
        HStack(spacing: 6) {
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

    private var caption: some View {
        Text(captionText)
            .font(Theme.meta)
            .foregroundStyle(library.overridesUnreadable ? Theme.accent : Theme.inkTertiary)
    }

    private var captionText: String {
        guard library.isClaudeAvailable(skill) else {
            return "No live copy in ~/.claude/skills — Claude Code can't load this skill."
        }
        if library.overridesUnreadable {
            return "~/.claude/settings.json can't be parsed — fix it (or restore the .skillbox.bak) to re-enable switching."
        }
        switch skill.claudeOverride ?? .on {
        case .on: return "On — Claude can invoke this skill, and /\(skill.dirName) runs it directly. Off hides it from Claude; files stay on disk."
        case .nameOnly: return "Name only — Claude sees the name but won't auto-invoke. /\(skill.dirName) still works."
        case .userInvocableOnly: return "Manual only — hidden from Claude; you can still run /\(skill.dirName) yourself."
        case .off: return "Off — hidden from Claude, the / menu, and Agent SDK apps. Files stay on disk; Delete removes them."
        }
    }

    // Meta facts: one line when they fit, two stacked groups when narrow.
    // Every item is fixedSize so nothing ever wraps inside itself.
    private var metaLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { datesGroup; provenanceGroup }
            VStack(alignment: .leading, spacing: 6) { datesGroup; provenanceGroup }
        }
    }

    private var datesGroup: some View {
        HStack(spacing: 14) {
            metaItem("Added", RelativeDateText.string(for: skill.addedAt))
            metaItem("Updated", RelativeDateText.string(for: skill.touchedAt))
        }
        .fixedSize()
    }

    private var provenanceGroup: some View {
        HStack(spacing: 14) {
            metaItem("In", skill.presences.map { library.toolDisplayName($0.targetID) }.joined(separator: " · "))
            if skill.isManagedByRegistry {
                Chip(text: "Managed", tint: Theme.accent).fixedSize()
            }
            if skill.frontmatterFields["disable-model-invocation"] == "true" {
                Chip(text: "Manual-only", tint: Theme.inkSecondary).fixedSize()
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
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(Theme.meta)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: Other tools (shelving)

    @ViewBuilder
    private var otherTools: some View {
        let otherPresences = skill.presences.filter { $0.targetID != "claude" }
        let groupHasSymlink = skill.presences.contains { $0.isSymlink }
        if !otherPresences.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
                    .padding(.vertical, 8)
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
                        Spacer()
                        AccentToggle(isOn: !presence.isShelved) { enabled in
                            library.setToolPresence(skill, targetID: presence.targetID, enabled: enabled)
                        }
                        .disabled(groupHasSymlink || presence.isBroken)
                    }
                }
                Text(groupHasSymlink
                     ? "This skill is linked between tools — moving any copy would break those links, so shelving is disabled."
                     : "Off moves this folder to Skillbox's shelf and this tool stops reading this copy. Other copies are unaffected.")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(.top, 14)
        }
    }

    // MARK: Document

    @ViewBuilder
    private var document: some View {
        if let presence = primaryPresence {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
                SkillDocument(directoryPath: presence.path, revision: skill.touchedAt, dropTitle: skill.name)
                    .padding(.top, 18)
            }
        } else {
            Text("No readable SKILL.md.")
                .font(Theme.secondary)
                .foregroundStyle(Theme.inkTertiary)
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

// MARK: - Slim state pill

/// The header activation control: On / Name / Manual / Off in one hairline
/// pill. Selected segment fills neutral; a selected Off fills terracotta.
private struct SlimStatePill: View {
    @Environment(SkillLibraryModel.self) private var library
    let skill: InstalledSkill

    private static let states: [(SkillOverrideState, String)] = [
        (.on, "On"), (.nameOnly, "Name"), (.userInvocableOnly, "Manual"), (.off, "Off"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.states, id: \.0) { state, label in
                let isCurrent = (skill.claudeOverride ?? .on) == state
                Button {
                    library.setClaudeOverride(skill, state == .on ? nil : state)
                } label: {
                    Text(label)
                        .font(Theme.segment)
                        .fixedSize()
                        .foregroundStyle(isCurrent ? (state == .off ? .white : Theme.ink) : Theme.inkTertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            isCurrent ? (state == .off ? Theme.accent : Theme.segmentFill) : .clear
                        )
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if state != .off {
                    Rectangle().fill(Theme.border).frame(width: 0.5, height: 16)
                }
            }
        }
        .background(Theme.raised.opacity(0.5))
        .clipShape(.rect(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
        .animation(Theme.fade, value: skill.claudeOverride)
        .accessibilityLabel("Claude state")
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
                        .textSelection(.enabled)
                } else {
                    Markdown(MarkdownContent(prepared(content)))
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
