import SkillboxKit
import SwiftUI

/// Full-width editor for the selected system prompt file. File selection
/// lives in the sidebar; this pane is all editing surface.
struct PromptEditor: View {
    @Environment(PromptEditorModel.self) private var prompts

    var body: some View {
        @Bindable var prompts = prompts

        Group {
            if let file = prompts.selectedFile {
                VStack(alignment: .leading, spacing: 0) {
                    editorHeader(file)

                    if prompts.hasDiskConflict {
                        conflictBanner
                    }

                    TextEditor(text: $prompts.text)
                        .font(Theme.editor)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .background(Theme.raised, in: .rect(cornerRadius: Theme.radius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(Theme.border, lineWidth: 0.5)
                        )
                        .padding(EdgeInsets(top: 0, leading: Theme.gutter + 8, bottom: Theme.gutter, trailing: Theme.gutter + 8))
                        .disabled(prompts.readFailed)
                }
            } else {
                EmptyState(
                    systemImage: "text.alignleft",
                    title: "Select a system prompt",
                    message: "Your global agent instructions, editable in place."
                )
            }
        }
        .background(Theme.canvas)
        .onDisappear {
            prompts.flushPendingSave()
        }
    }

    private func editorHeader(_ file: PromptFile) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayShortName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text(abbreviatedPath(file))
                        .font(Theme.mono)
                        .foregroundStyle(Theme.inkTertiary)
                    Text("·")
                        .foregroundStyle(Theme.inkTertiary)
                    Text(file.readerDescription)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            Spacer()

            Text("\(prompts.text.count) chars")
                .font(Theme.meta)
                .foregroundStyle(Theme.inkTertiary)
                .monospacedDigit()

            Text(saveStatus)
                .font(Theme.meta)
                .foregroundStyle(prompts.isDirty ? Theme.accent : Theme.inkTertiary)
                .animation(Theme.fade, value: prompts.isDirty)

            Button("Save") { prompts.save() }
                .keyboardShortcut("s", modifiers: .command)
                .controlSize(.small)
                .disabled(!prompts.isDirty || !prompts.canSave)
        }
        .padding(EdgeInsets(top: 22, leading: Theme.gutter + 8, bottom: 14, trailing: Theme.gutter + 8))
    }

    private var conflictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text("This file changed on disk while you were editing.")
                .font(Theme.secondary)
                .foregroundStyle(Theme.ink)
            Spacer()
            Button("Reload File") { prompts.reloadFromDisk() }
                .controlSize(.small)
            Button("Keep Mine") { prompts.overwriteDisk() }
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.09), in: .rect(cornerRadius: Theme.radiusSmall))
        .padding(EdgeInsets(top: 0, leading: Theme.gutter + 8, bottom: 10, trailing: Theme.gutter + 8))
    }

    private var saveStatus: String {
        if let error = prompts.lastError { return error }
        if prompts.hasDiskConflict { return "Conflict — resolve above" }
        if prompts.isDirty { return "Unsaved — autosaves shortly" }
        if let saved = prompts.lastSavedAt { return "Saved \(RelativeDateText.string(for: saved))" }
        return prompts.selectedFile?.exists == true ? "Saved" : "Not created yet — saving creates it"
    }

    private func abbreviatedPath(_ file: PromptFile) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return file.path.hasPrefix(home) ? "~" + file.path.dropFirst(home.count) : file.path
    }
}

extension PromptFile {
    /// "CLAUDE.md — Claude Code" → "Claude Code & Agent SDK read this file."
    var readerDescription: String {
        let owner = displayName.components(separatedBy: " — ").last ?? ""
        return owner == "Claude Code" ? "Read by Claude Code & Agent SDK" : "Read by \(owner)"
    }
}
